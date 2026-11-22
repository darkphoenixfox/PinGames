## DebugTools autoload (D-057): keyboard shortcuts for testing, active only in
## debug builds (any run through the Godot binary / scripts; exported release
## builds ignore them, so cabinets are unaffected).
##   P  pause / resume the whole game (shows PAUSED on the TABLE)
##   I  input monitor: live action states + focus on the TABLE, and a log of
##      every press/release/focus change in user://input_log.txt (D-069)
##   C  game-specific "clear the level" (Tilt Breaker: instant level complete)
##   U  game-specific: Tilt Breaker drops the next power-up capsule over the ship
##   O  game-specific "officer" (Turbo Run: a police car comes from behind, D-138)
##   S  game-specific "skip stage" (Turbo Run: jump to stage 5, night, D-121)
##   F  game-specific debug action (`debug_action` signal, e.g. Tilt Breaker's
##      piercing plasma that destroys everything in a vertical line; Turbo Run
##      freezes the race clock, D-118)
extends Node

const UI = preload("res://core/ui/ui.gd")

## Emitted for game-specific debug keys; games connect while they run.
signal debug_action(action: StringName)

var enabled := false
var _pause_label: Control
var _monitor: Label
var _log: FileAccess
var _log_lines: Array[String] = []


var _log_spikes := false


## With --log-spikes: logs a game event, so a slow frame can be matched to
## what happened just before it (D-179).
func mark(what: String) -> void:
	if _log_spikes:
		print("Event: %s at %.2f s" % [what, Time.get_ticks_msec() / 1000.0])


func _ready() -> void:
	_log_spikes = Config.cli.has("log-spikes")
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Debug builds, and the browser build too (director, D-175).
	enabled = (OS.is_debug_build() or OS.has_feature("web")) and str(Config.cli.get("debug-tools", "on")) != "off"
	if enabled:
		CabinetInput.action_pressed.connect(func(a): _log_event("press   " + String(a)))
		CabinetInput.action_released.connect(func(a): _log_event("release " + String(a)))
		CabinetInput.focus_changed.connect(func(f): _log_event("FOCUS " + ("IN" if f else "OUT (all inputs released)")))


func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_P:
			toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_F:
			if not get_tree().paused:
				debug_action.emit(&"fire_line")
			get_viewport().set_input_as_handled()
		KEY_I:
			toggle_monitor()
			get_viewport().set_input_as_handled()
		KEY_U:
			if not get_tree().paused:
				debug_action.emit(&"powerup")
			get_viewport().set_input_as_handled()
		KEY_O:
			if not get_tree().paused:
				debug_action.emit(&"spawn_police")
			get_viewport().set_input_as_handled()
		KEY_S:
			if not get_tree().paused:
				debug_action.emit(&"skip_stage")
			get_viewport().set_input_as_handled()
		KEY_C:
			if not get_tree().paused:
				debug_action.emit(&"clear_level")
			get_viewport().set_input_as_handled()


func toggle_monitor() -> void:
	if is_instance_valid(_monitor):
		_monitor.queue_free()
		_monitor = null
		return
	_monitor = UI.label("", 36, UI.GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	_monitor.position = Vector2(24, 90)
	_monitor.add_theme_color_override("font_outline_color", Color.BLACK)
	Screens.table.add_child(_monitor)


func _process(delta: float) -> void:
	# --log-spikes (?log-spikes on the web): log frames slower than 80 ms, to
	# find first-time stalls (shader compiles, uploads) (D-178).
	if _log_spikes and delta > 0.08:
		# Script time of the previous frame: low = the time went to rendering
		# (shader compiles, texture uploads), high = to game code.
		print("Spike: %d ms at %.2f s (script %d ms, physics %d ms)" % [int(delta * 1000.0),
			Time.get_ticks_msec() / 1000.0,
			int(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
			int(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)])
	if not is_instance_valid(_monitor):
		return
	var lines: PackedStringArray = ["INPUT MONITOR  focus: %s" % ("YES" if CabinetInput.has_focus else "NO")]
	for a in CabinetInput.ACTIONS:
		lines.append("%-8s %s" % [String(a).to_upper(), "## HELD %.1fs" % CabinetInput.held_time(a) if CabinetInput.is_down(a) else "."])
	lines.append("")
	lines.append_array(_log_lines.slice(-6))
	_monitor.text = "
".join(lines)


## Appends to the on-screen tail and user://input_log.txt (timestamped).
func _log_event(text: String) -> void:
	var line := "%8.3f  %s" % [Time.get_ticks_msec() / 1000.0, text]
	_log_lines.append(line)
	if _log_lines.size() > 50:
		_log_lines.pop_front()
	if _log == null:
		_log = FileAccess.open("user://input_log.txt", FileAccess.WRITE)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	if tree.paused:
		_pause_label = UI.label(tr("DEBUG_PAUSED"), 120, UI.YELLOW)
		_pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Screens.table.add_child(_pause_label)
	elif is_instance_valid(_pause_label):
		_pause_label.queue_free()
