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
		for i in WARMUP_FRAMES:
			await get_tree().process_frame
		_overlay.queue_free()


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
