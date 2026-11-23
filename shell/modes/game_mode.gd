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
const WARMUP_FRAMES := 24   # 4 light phases x 6 frames (D-179)

## Loaded resources per game, kept so later load() calls hit the cache.
static var _cache := {}
## One standard material per feature set, kept while the game runs (D-179).
## Godot frees a standard material's generated shader with the last material
## using it, so an effect that makes a fresh material each time (an explosion,
## a fireball) would compile its shader again every time, a stall in WebGL.
## Holding one material per set of features keeps every such shader compiled.
## Static and per game, so a second play (no loading screen) still has them.
static var _keep := {}     # game id -> {feature key -> Material}
static var _key_of := {}   # material instance id -> feature key (computed once)

var game_id := ""
var module: Node
var _overlay: Control
var _bar: ColorRect
var _bar_w := 600.0
const LoadingAnim = preload("res://shell/loading_anim.gd")
var _anim: Control   # D-238: the loading screen's little scene
const REVEAL_DELAY := 2.0   # s the loading screen stays after loading (D-259)
var _overlay_bg: ColorRect   # D-261


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
	Dmd.stop_anim()   # D-238: the loading animation hands the DMD to the game
	module.start(1)
	print("Shell: started game '%s'" % game_id)
	get_tree().node_added.connect(_on_node_added)
	for r in _game_roots():
		_keep_node(r)
	if is_instance_valid(_overlay):
		var warm := _warmup_nodes()
		# Each material compiles a variant per set of light types touching it:
		# none, point, point + spot, spot (the scene's sun stays on throughout).
		var omni: Light3D = null
		var spot: Light3D = null
		for n in warm:
			if n is OmniLight3D: omni = n
			elif n is SpotLight3D: spot = n
		for i in WARMUP_FRAMES:
			var phase := i * 4 / WARMUP_FRAMES
			if omni: omni.visible = phase == 1 or phase == 2
			if spot: spot.visible = phase == 2 or phase == 3
			await get_tree().process_frame
			if not is_inside_tree():
				return
		for n in warm:
			if is_instance_valid(n):
				n.queue_free()
		# D-259: the warm-up copies go first; the loading screen stays up a
		# little longer, so their last frame never shows and the game starts clean.
		await get_tree().create_timer(REVEAL_DELAY).timeout
		if not is_inside_tree():
			return
		if is_instance_valid(_overlay):
			_overlay.queue_free()
		if is_instance_valid(_overlay_bg):
			_overlay_bg.queue_free()


## Draws everything the game loaded once, hidden behind the loading bar (D-178):
## each model and each spatial shader in front of the game's camera, each
## texture and canvas shader on the TABLE. Shaders compile and textures upload
## to the GPU the first time they are drawn, which in WebGL stalls for a
## noticeable moment, so this moves those stalls into the loading screen.
func _warmup_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var cam: Camera3D = null
	for r in _game_roots():
		for c in r.find_children("*", "Camera3D", true, false):
			if (c as Camera3D).current and cam == null:
				cam = c
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
		var geoms: Array = []
		for r in _game_roots():
			geoms.append_array(r.find_children("*", "GeometryInstance3D", true, false))
		for g in geoms:
			# Particles, multimeshes, labels and sprites draw with their own shader
			# variants (instanced, billboarded, font): copy the node itself, running.
			if not (g is MeshInstance3D):
				var key2 := "%s:%s" % [g.get_class(), str(_mesh_materials(g))]
				if seen.has(key2) or seen.size() >= 300:
					continue
				seen[key2] = true
				var dup := g.duplicate(0) as GeometryInstance3D
				for ch in dup.get_children():
					dup.remove_child(ch)
					ch.free()
				dup.visible = true
				dup.transform = Transform3D(Basis().scaled(Vector3.ONE * 0.2),
					Vector3(float(i % 9) * 0.5 - 2.0, float(i / 9 % 6) * 0.5 - 1.2, -1.0))
				holder3d.add_child(dup)
				# Warm-up copies only compile shaders: local space, since a
				# world-space emitter (the weather, D-217) reads its global
				# transform when it starts, and the holder may not be in the tree.
				if dup is CPUParticles3D:
					(dup as CPUParticles3D).local_coords = true
					(dup as CPUParticles3D).one_shot = false
					(dup as CPUParticles3D).emitting = true
				i += 1
				continue
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
	# Lit materials need a shader variant per light type, compiled the first
	# time such a light touches them (engine glows, capsule key lights, police
	# flashers). A dim point light and spotlight that reach everything the
	# camera sees compile those variants now, for the warm-up copies and the
	# game's own scene.
	if cam != null:
		var omni := OmniLight3D.new()
		omni.omni_range = 4096.0
		omni.light_energy = 0.05
		cam.add_child(omni)
		out.append(omni)
		var spot := SpotLight3D.new()
		spot.spot_range = 4096.0
		spot.spot_angle = 89.0
		spot.light_energy = 0.05
		cam.add_child(spot)
		out.append(spot)
	else:
		holder3d.free()
	# Under the loading overlay (which is on top of the TABLE).
	Screens.table.add_child(holder2d)
	Screens.table.move_child(holder2d, _overlay.get_index())
	out.append(holder2d)
	return out


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	# D-247: left during loading (EXIT): the loading animation stops, and the
	# base class frees what was put on the TABLE (the loading overlay).
	if module == null:
		Dmd.stop_anim()
	super._exit_tree()


func _on_node_added(n: Node) -> void:
	if not (n is GeometryInstance3D):
		return
	for r in _game_roots():
		if r.is_ancestor_of(n):
			_keep_node(n)
			return


## The game's node and everything it added to the screens (its 3D worlds live
## under the TABLE / BACKGLASS viewports, not under the game node).
func _game_roots() -> Array[Node]:
	var out: Array[Node] = []
	if not is_instance_valid(module):
		return out
	out.append(module)
	for n in module.get("_owned"):
		if is_instance_valid(n):
			out.append(n)
	return out


## Keeps the standard materials a node (and its children) draws with, one per
## feature set.
func _keep_node(root: Node) -> void:
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "GeometryInstance3D", true, false))
	for g in nodes:
		if not (g is GeometryInstance3D):
			continue
		var mats: Array = [g.material_override, g.material_overlay]
		for pair in _mesh_materials(g):
			mats.append(pair[1])
		var kept: Dictionary = _keep.get_or_add(game_id, {})
		for m in mats:
			while m is BaseMaterial3D:
				var id: int = m.get_instance_id()
				if not _key_of.has(id):
					_key_of[id] = _feature_key(m)
				if not kept.has(_key_of[id]):
					kept[_key_of[id]] = m
				m = (m as Material).next_pass


## What decides a standard material's generated shader: its switches and
## modes, and which texture slots are filled (colours and numbers don't).
static func _feature_key(m: BaseMaterial3D) -> String:
	var parts := PackedStringArray()
	for p in m.get_property_list():
		if not (p.usage & PROPERTY_USAGE_STORAGE):
			continue
		var v: Variant = m.get(p.name)
		match typeof(v):
			TYPE_BOOL, TYPE_INT:
				parts.append("%s=%s" % [p.name, v])
			TYPE_OBJECT:
				if p.name != "next_pass":
					parts.append("%s=%s" % [p.name, v != null])
	return ",".join(parts)


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
	var info: Dictionary = Registry.info(game_id)
	Dmd.play(LoadingAnim.dmd_anim(game_id, info.get("color", Dmd.YELLOW)), 3600.0)   # D-238
	var kept: Array = []
	var t0 := Time.get_ticks_msec()
	for i in paths.size():
		var r := load(paths[i])
		if r != null:
			kept.append(r)
		_bar.size.x = _bar_w * float(i + 1) / maxf(1.0, paths.size())
		_anim.progress = float(i + 1) / maxf(1.0, paths.size())
		# Yield to draw the bar only every ~50 ms, not after every asset: a
		# slow or throttled browser gives few frames, and waiting one per asset
		# made loading take far longer than the loading itself. (D-238: 50 ms,
		# was 100, so the loading animation moves smoothly enough.)
		if Time.get_ticks_msec() - t0 > 50:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			t0 = Time.get_ticks_msec()
	if Config.cli.has("loading-hold"):   # dev: keep the loading screen up N s (D-238)
		await get_tree().create_timer(float(str(Config.cli["loading-hold"]))).timeout
	_cache[game_id] = kept
	print("Shell: preloaded %d assets for '%s'" % [kept.size(), game_id])


func _build_overlay() -> void:
	# D-261: black over the whole TABLE whatever its shape (the loading
	# content itself may sit in the centred portrait frame), so nothing behind
	# it, the warm-up copies included, shows at the sides.
	_overlay_bg = ColorRect.new()
	_overlay_bg.color = Color.BLACK
	_overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_bg.z_index = 99
	Screens.table.add_child(_overlay_bg)
	_owned.append(_overlay_bg)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	# D-238: the game's logo, a little looping scene, LOADING and progress.
	var info: Dictionary = Registry.info(game_id)
	if info.has("logo") and ResourceLoader.exists(str(info.logo)):
		var logo := TextureRect.new()
		logo.texture = load(str(info.logo))
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.position = Vector2(140, 300)
		logo.size = Vector2(800, 520)
		_overlay.add_child(logo)
	_anim = LoadingAnim.new(game_id, info.get("color", UI.CYAN))
	_overlay.add_child(_anim)
	var label := UI.label(tr("LOADING"), 72, UI.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_left = -400
	label.offset_right = 400
	label.offset_top = 560
	label.offset_bottom = 640
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
	frame.visible = false   # D-238: the scene shows the progress itself
	_bar.visible = false
	_overlay.z_index = 100
	add_table(_overlay)


func on_action(action: StringName, pressed: bool) -> void:
	if module == null:
		# Still loading: EXIT goes back now (D-247); everything else waits.
		if action == &"exit" and pressed:
			shell.abort_game()
		return
	if is_instance_valid(_quit_box):
		_quit_action(action, pressed)
		return
	if action == &"exit" and pressed:
		if Screens.current_layout == "single":
			_open_quit()   # D-260: ask first
		else:
			shell.abort_game()
		return
	if is_instance_valid(_overlay) and not _overlay.is_queued_for_deletion():
		return   # D-259: still behind the loading screen
	module.on_action(action, pressed)


# --- quit confirmation (D-260) -----------------------------------------------------
## Single screen: EXIT (a pad's Start) pauses the game and asks QUIT GAME?
## with OK / CANCEL. The flippers (D-pad, stick) choose, LAUNCH (Cross) picks,
## BACK (Circle) or EXIT again cancels.
var _quit_box: Control
var _quit_sel := 1   # 0 OK, 1 CANCEL (cancel first, so a stray press is safe)
var _quit_items: Array = []


func _open_quit() -> void:
	module.process_mode = Node.PROCESS_MODE_DISABLED
	_quit_sel = 1
	# Over the whole TABLE, whatever its shape (not the portrait frame).
	_quit_box = UI.fill(Color(0, 0, 0, 0.75))
	Screens.table.add_child(_quit_box)
	_owned.append(_quit_box)
	_quit_box.z_index = 120
	var col := UI.vstack(60)
	col.add_child(UI.styled_label(tr("QUIT_GAME_TITLE"), UI.SHELL_TITLE_FONT, 2))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 120)
	_quit_items.clear()
	for k in ["QUIT_OK", "QUIT_CANCEL"]:
		var l := UI.label(tr(k), 72, UI.WHITE)
		row.add_child(l)
		_quit_items.append(l)
	col.add_child(row)
	_quit_box.add_child(col)
	_refresh_quit()
	Audio.sfx("error")
	Dmd.show_text(tr("QUIT_GAME_TITLE"), tr("QUIT_OK") + " / " + tr("QUIT_CANCEL"), Dmd.YELLOW, Dmd.WHITE)


func _refresh_quit() -> void:
	for i in _quit_items.size():
		var l: Label = _quit_items[i]
		var on := i == _quit_sel
		l.text = ("> %s <" if on else "%s") % tr(["QUIT_OK", "QUIT_CANCEL"][i])
		l.add_theme_color_override("font_color", UI.YELLOW if on else UI.GREY)


func _quit_action(action: StringName, pressed: bool) -> void:
	if not pressed:
		return
	match action:
		&"flip_l", &"flip_r":
			_quit_sel = 1 - _quit_sel
			Audio.sfx("move")
			_refresh_quit()
		&"launch":
			if _quit_sel == 0:
				shell.abort_game()
			else:
				_close_quit()
		&"back", &"exit":
			_close_quit()


func _close_quit() -> void:
	if is_instance_valid(_quit_box):
		_quit_box.queue_free()
	_quit_box = null
	module.process_mode = Node.PROCESS_MODE_INHERIT
	CabinetInput.mute_until_release()
	Audio.sfx("back")


func _on_finished(scores: Array) -> void:
	var best := 0
	for s in scores:
		best = maxi(best, int(s))
	shell.call_deferred("game_finished", game_id, best)
