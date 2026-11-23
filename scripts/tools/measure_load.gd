## Times what a game's loading screen loads (the same folders and file types as
## shell/modes/game_mode.gd), slowest first, to find slow assets.
## Run: <godot> --headless --path . --script scripts/tools/measure_load.gd -- <game id> [top N]
extends SceneTree

const EXT := ["png", "jpg", "webp", "glb", "ogg", "wav", "mp3", "gdshader", "tres", "res", "ttf"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := str(args[0]) if args.size() > 0 else "racer"
	var top := int(args[1]) if args.size() > 1 else 25
	var paths: Array[String] = []
	_scan("res://games/" + id, paths)
	for kind in ["models", "sprites", "textures", "audio/music", "audio/sfx"]:
		_scan("res://assets/%s/%s" % [kind, id], paths)
	var rows := []
	var total := 0.0
	var keep := []
	for p in paths:
		var t0 := Time.get_ticks_usec()
		keep.append(load(p))
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		rows.append([ms, p])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("%s: %d assets, %d ms" % [id, rows.size(), int(total)])
	for i in mini(top, rows.size()):
		print("%8.1f ms  %s" % rows[i])
	quit()


func _scan(dir: String, out: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_scan(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension().to_lower() in EXT:
			var p := dir.path_join(name)
			if not out.has(p) and ResourceLoader.exists(p):
				out.append(p)
