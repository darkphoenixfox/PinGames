## On-screen cabinet buttons for the browser build on touch screens (D-176).
## A strip of five buttons: big LEFT and RIGHT flippers at the outer edges
## (thumbs), and EXIT, START and LAUNCH in the middle. They drive the same
## CabinetInput actions as the keys (D-007), via Input.action_press/release.
## The TABLE itself is a flipper pad too: touching its left or right half
## holds that flipper (set `table_view`).
## Multi-touch: each finger is tracked on its own, so both flippers can be held
## together (gear shift), and a finger sliding off a button releases it.
## --touch shows the strip on any device (mouse clicks work then, for testing).
extends HBoxContainer

const UI = preload("res://core/ui/ui.gd")

## [action, label key, stretch ratio]
const BUTTONS := [
	[&"flip_l", "TOUCH_LEFT", 2.2],
	[&"exit", "TOUCH_EXIT", 1.0],
	[&"start", "TOUCH_START", 1.0],
	[&"launch", "TOUCH_LAUNCH", 1.4],
	[&"flip_r", "TOUCH_RIGHT", 2.2],
]
const COLORS := {
	&"flip_l": Color(0.2, 0.55, 1.0), &"flip_r": Color(0.2, 0.55, 1.0),
	&"launch": Color(1.0, 0.35, 0.2), &"start": Color(0.25, 0.85, 0.35),
	&"exit": Color(0.6, 0.6, 0.66),
}
const MOUSE := -100   # pointer id used for mouse clicks

var table_view: Control  # touches on its halves work the flippers
var _buttons := {}        # action -> Panel
var _fingers := {}        # pointer index -> action held by it
var _font_px := 24
var _down_frame := {}     # action -> frame it was pressed
var _late_release := {}   # action -> true: release once it has been seen held


static func wanted() -> bool:
	if Config.cli.has("touch"):
		return true
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


func _ready() -> void:
	# Delayed releases happen in _process: run before CabinetInput polls, or
	# it never sees the "just released" frame (and the picker acts on release).
	process_priority = -100
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in BUTTONS:
		var panel := Panel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = b[2]
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := UI.label(tr(b[1]), _font_px, Color.WHITE)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		add_child(panel)
		_buttons[b[0]] = panel
		_style(b[0], false)


## Height of the strip for a window of this size, and the label size to match.
func fit(win: Vector2) -> void:
	var h := clampf(minf(win.x, win.y) * 0.16, 56.0, 260.0)
	custom_minimum_size.y = h
	var px := maxi(12, int(h * 0.28 / 12.0) * 12)
	if px != _font_px:
		_font_px = px
		for panel in _buttons.values():
			(panel.get_child(0) as Label).add_theme_font_size_override("font_size", px)


func _style(action: StringName, down: bool) -> void:
	var c: Color = COLORS[action]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c, 0.75) if down else Color(c.darkened(0.6), 0.55)
	sb.border_color = c.lightened(0.3) if down else Color(c, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	(_buttons[action] as Panel).add_theme_stylebox_override("panel", sb)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return   # hidden: no buttons and no flipper pads
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		_finger(t.index, t.position if t.pressed else Vector2(-1e6, -1e6))
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_finger(d.index, d.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			_finger(MOUSE, m.position if m.pressed else Vector2(-1e6, -1e6))


## A finger is now at pos (far away = lifted): release what it held, press what it's on.
func _finger(index: int, pos: Vector2) -> void:
	var now: StringName = &""
	for action in _buttons:
		if (_buttons[action] as Control).get_global_rect().has_point(pos):
			now = action
			break
	if now == &"" and is_instance_valid(table_view):
		var r := table_view.get_global_rect()
		if r.has_point(pos):
			now = &"flip_l" if pos.x < r.get_center().x else &"flip_r"
	var before: StringName = _fingers.get(index, &"")
	if now == before:
		return
	if before != &"":
		_fingers.erase(index)
		if not _fingers.values().has(before):
			_release(before)
	if now != &"":
		_fingers[index] = now
		_late_release.erase(now)
		Input.action_press(now)
		_down_frame[now] = Engine.get_process_frames()
		_style(now, true)
	get_viewport().set_input_as_handled()


## CabinetInput polls actions once per frame, so a tap that presses and
## releases within one frame would never be seen (and the picker acts on
## release). A press is held for at least two frames.
func _release(action: StringName) -> void:
	_style(action, false)
	if Engine.get_process_frames() - int(_down_frame.get(action, -10)) < 2:
		_late_release[action] = true
		return
	Input.action_release(action)


func _process(_delta: float) -> void:
	for action in _late_release.keys():
		if Engine.get_process_frames() - int(_down_frame.get(action, -10)) >= 2:
			_late_release.erase(action)
			Input.action_release(action)


func _exit_tree() -> void:
	for action in _fingers.values():
		Input.action_release(action)
	for action in _late_release:
		Input.action_release(action)
	_fingers.clear()
	_late_release.clear()
