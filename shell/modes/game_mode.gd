## Runs one game module. Exit aborts the game (no high-score entry); when the module
## emits `finished`, the shell checks for a high score.
##
## Loading screen (D-175): before a game's first start, its assets (models,
## textures, sprites, music, shaders) load behind a progress bar
## and stay cached, so nothing loads mid-game (the stutter in the browser
## build). After the game starts, its first frames render behind the bar for a
## moment, which also compiles most of its shaders before the player sees them.
extends "res://shell/modes/mode.gd"

const ASSET_EXT := ["png", "jpg", "webp", "glb", "ogg", "wav", "mp3", "gdshader", "tres", "res", "ttf"]
const WARMUP_FRAMES := 20

## Loaded resources per game, kept so later load() calls hit the cache.
static var _cache := {}

var game_id := ""
var module: Node
var _overlay: Control
var _bar: ColorRect
var _bar_w := 600.0


func _init(p_game_id: String) -> void:
	game_id = p_game_id


func enter() -> void:
	Audio.stop_music(0.6)  # games start their own music
	if not _cache.has(game_id):
		await _preload()
	if not is_inside_tree():
		return
	module = Registry.instantiate(game_id)
	module.name = "Game_" + game_id
	add_child(module)
	module.finished.connect(_on_finished)
	Audio.sfx("start")
	module.start(1)
	print("Shell: started game '%s'" % game_id)
	if is_instance_valid(_overlay):
		var warm := _warmup_nodes()
		for i in WARMUP_FRAMES:
			await get_tree().process_frame
			if not is_inside_tree():
				return
		for n in warm:
			if is_instance_valid(n):
				n.queue_free()
		_overlay.queue_free()


## Draws everything the game loaded once, hidden behind the loading bar (D-178):
## each model and each spatial shader in front of the game's camera, each
## texture and canvas shader on the TABLE. Shaders compile and textures upload
## to the GPU the first time they are drawn, which in WebGL stalls for a
## noticeable moment, so this moves those stalls into the loading screen.
func _warmup_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var cam: Camera3D = null
	for c in module.find_children("*", "Camera3D", true, false):
		if (c as Camera3D).current:
			cam = c
			break
	var holder3d := Node3D.new()
	var holder2d := Control.new()
	holder2d.modulate.a = 0.02          # drawn, but invisible even if peeked at
	holder2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := 0
	for r in _cache.get(game_id, []):
		if r is PackedScene and cam != null:
			var inst: Node = (r as PackedScene).instantiate()
			if inst is Node3D:
				(inst as Node3D).position = Vector3(float(i % 5) - 2.0, 0.0, 0.0)
				holder3d.add_child(inst)
			else:
				inst.free()
		elif r is Texture2D:
			var tr_ := TextureRect.new()
			tr_.texture = r
			tr_.size = Vector2(32, 32)
			tr_.position = Vector2(float(i % 30) * 34.0, 0.0)
			tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			holder2d.add_child(tr_)
			if cam != null:   # also as a 3D material (mipmaps / 3D sampling)
				holder3d.add_child(_quad(i, _std_mat(r)))
		elif r is Shader:
			var sm := ShaderMaterial.new()
			sm.shader = r
			if (r as Shader).get_mode() == Shader.MODE_CANVAS_ITEM:
				var cr := ColorRect.new()
				cr.material = sm
				cr.size = Vector2(32, 32)
				cr.position = Vector2(float(i % 30) * 34.0, 40.0)
				holder2d.add_child(cr)
			elif (r as Shader).get_mode() == Shader.MODE_SPATIAL and cam != null:
				holder3d.add_child(_quad(i, sm))
		i += 1
	# Every mesh + material the game built at start, hidden ones included
	# (pooled cars, night lights, flashers): one copy each (D-178).
	if cam != null:
		var seen := {}
		for g in module.find_children("*", "GeometryInstance3D", true, false):
			for pair in _mesh_materials(g):
				var key := "%d:%d" % [pair[0].get_instance_id(), pair[1].get_instance_id() if pair[1] != null else 0]
				if seen.has(key) or seen.size() >= 300:
					continue
				seen[key] = true
				var mi := MeshInstance3D.new()
				mi.mesh = pair[0]
				if pair[1] != null:
					mi.material_override = pair[1]
				mi.position = Vector3(float(i % 9) * 0.5 - 2.0, float(i / 9 % 6) * 0.5 - 1.2, -1.0)
				mi.scale = Vector3.ONE * 0.1
				holder3d.add_child(mi)
				i += 1
	# Effects the game builds only when they happen (its optional hook).
	if module.has_method("warmup_nodes"):
		for n in module.warmup_nodes():
			out.append(n)
	if cam != null and holder3d.get_child_count() > 0:
		holder3d.position = Vector3(0, 0, -6)   # in front of the camera
		cam.add_child(holder3d)
		out.append(holder3d)
	else:
		holder3d.free()
	# Under the loading overlay (which is on top of the TABLE).
	Screens.table.add_child(holder2d)
	Screens.table.move_child(holder2d, _overlay.get_index())
	out.append(holder2d)
	return out


## [mesh, material or null] pairs a geometry node draws with.
func _mesh_materials(g: GeometryInstance3D) -> Array:
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	if mesh == null:
		return []
	if g.material_override != null:
		return [[mesh, g.material_override]]
	var out := []
	for si in mesh.get_surface_count():
		var m: Material = null
		if g is MeshInstance3D:
			m = (g as MeshInstance3D).get_active_material(si)
		else:
			m = mesh.surface_get_material(si)
		out.append([mesh, m])
	return out


func _quad(i: int, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	m.mesh = q
	m.material_override = mat
	m.position = Vector3(float(i % 9) * 0.35 - 1.4, float(i / 9 % 5) * 0.35 - 0.7, 0.5)
	return m


func _std_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	return m


## The game's own asset folders (assets/<kind>/<id>, games/<id>).
func _asset_paths() -> Array[String]:
	var out: Array[String] = []
	var roots := ["res://games/" + game_id]
	for kind in ["models", "sprites", "textures", "audio/music", "audio/sfx"]:
		roots.append("res://assets/%s/%s" % [kind, game_id])
	for r in roots:
		_scan(r, out)
	return out


func _scan(dir: String, out: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_scan(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		# Exported builds list imported files as name.ext.import / name.ext.remap.
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension().to_lower() in ASSET_EXT:
			var p := dir.path_join(name)
			if not out.has(p) and ResourceLoader.exists(p):
				out.append(p)


func _preload() -> void:
	var paths := _asset_paths()
	_build_overlay()
	Dmd.show_text(tr("LOADING"), "", Dmd.YELLOW)
	var kept: Array = []
	var t0 := Time.get_ticks_msec()
	for i in paths.size():
		var r := load(paths[i])
		if r != null:
			kept.append(r)
		_bar.size.x = _bar_w * float(i + 1) / maxf(1.0, paths.size())
		# Yield to draw the bar only every ~100 ms, not after every asset: a
		# slow or throttled browser gives few frames, and waiting one per asset
		# made loading take far longer than the loading itself.
		if Time.get_ticks_msec() - t0 > 100:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			t0 = Time.get_ticks_msec()
	_cache[game_id] = kept
	print("Shell: preloaded %d assets for '%s'" % [kept.size(), game_id])


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	var label := UI.label(tr("LOADING"), 72, UI.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_left = -400
	label.offset_right = 400
	label.offset_top = -120
	label.offset_bottom = -40
	_overlay.add_child(label)
	var frame := ColorRect.new()
	frame.color = Color(0.15, 0.15, 0.2)
	frame.position = Vector2((1080.0 - _bar_w) * 0.5 - 4, 960.0 - 4)
	frame.size = Vector2(_bar_w + 8, 40)
	_overlay.add_child(frame)
	_bar = ColorRect.new()
	_bar.color = UI.CYAN
	_bar.position = Vector2((1080.0 - _bar_w) * 0.5, 960.0)
	_bar.size = Vector2(0, 32)
	_overlay.add_child(_bar)
	_overlay.z_index = 100
	add_table(_overlay)


func on_action(action: StringName, pressed: bool) -> void:
	if module == null:
		return   # still loading
	if action == &"exit" and pressed:
		shell.abort_game()
		return
	module.on_action(action, pressed)


func _on_finished(scores: Array) -> void:
	var best := 0
	for s in scores:
		best = maxi(best, int(s))
	shell.call_deferred("game_finished", game_id, best)
