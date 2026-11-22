## Development aids driven by CLI flags, so changes can be verified without a human
## at the cabinet (D-017):
##   --press=flip_r,flip_r,launch   simulate cabinet actions, one every 12 frames
##                                   (click:X.Y clicks the mouse at window pixel X,Y)
##                                  (use "wait" to skip a slot, "hold:start+exit:3.5"
##                                   to hold actions for N seconds; "down:flip_l" /
##                                   "up:flip_l" to press/release without waiting;
##                                   "key:P" to tap a raw keyboard key)
##   --screenshot=<dir>             after presses + 30 frames, save PNGs and quit
##   --screenshot-delay=N           frames to wait before the screenshot (default 30)
extends Node

const STEP_FRAMES := 12


func _ready() -> void:
	if not (Config.cli.has("press") or Config.cli.has("screenshot")):
		queue_free()
		return
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	var presses := str(Config.cli.get("press", ""))
	if not presses.is_empty():
		for step in presses.split(","):
			await _do_step(step.strip_edges())
	if Config.cli.has("screenshot"):
		await _frames(int(str(Config.cli.get("screenshot-delay", "30"))))
		_capture(str(Config.cli["screenshot"]))
		get_tree().quit()


func _do_step(step: String) -> void:
	if step == "wait" or step.is_empty():
		await _frames(STEP_FRAMES)
		return
	if step.begins_with("key:"):  # raw keyboard key, e.g. key:P (debug tools)
		for pressed in [true, false]:
			var ev := InputEventKey.new()
			ev.physical_keycode = OS.find_keycode_from_string(step.trim_prefix("key:"))
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(2)
		await _frames(STEP_FRAMES)
		return
	if step.begins_with("click:"):  # mouse click at window pixels, e.g. click:780,545
		var xy := step.trim_prefix("click:").split(";") if ";" in step else step.trim_prefix("click:").split(".")
		var pos := Vector2(float(xy[0]), float(xy[1]))
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.position = pos
			ev.global_position = pos
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(1)
		await _frames(STEP_FRAMES)
		return
	if step.begins_with("down:"):
		Input.action_press(step.trim_prefix("down:"))
		return
	if step.begins_with("up:"):
		Input.action_release(step.trim_prefix("up:"))
		return
	if step.begins_with("hold:"):
		var parts := step.split(":")
		var actions := parts[1].split("+")
		var seconds := parts[2].to_float() if parts.size() > 2 else 1.0
		for a in actions:
			Input.action_press(a)
		await get_tree().create_timer(seconds).timeout
		for a in actions:
			Input.action_release(a)
		await _frames(STEP_FRAMES)
		return
	Input.action_press(step)
	await _frames(3)
	Input.action_release(step)
	await _frames(STEP_FRAMES)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Screens.table.get_texture().get_image().save_png(dir.path_join("table.png"))
	Screens.backglass.get_texture().get_image().save_png(dir.path_join("backglass.png"))
	Dmd.texture().get_image().save_png(dir.path_join("dmd.png"))
	get_viewport().get_texture().get_image().save_png(dir.path_join("window_table.png"))
	# Secondary OS windows as actually displayed (e.g. DMD with the dot shader).
	for child in Screens.get_children():
		if child is Window:
			var w := child as Window
			var file := "window_" + w.title.get_slice(" - ", 1).to_lower().replace(" ", "_") + ".png"
			w.get_texture().get_image().save_png(dir.path_join(file))
	print("Dev: screenshots saved to %s" % dir)
