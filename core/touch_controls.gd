## On-screen cabinet buttons for the browser build on touch screens (D-176, D-177).
## Two columns at the sides of the screens, so the play area keeps its full
## height: the left column has EXIT above a big LEFT flipper, the right column
## START and LAUNCH above a big RIGHT flipper (flippers low, under the thumbs).
## They drive the same CabinetInput actions as the keys (D-007), via
## Input.action_press/release. The TABLE itself is a flipper pad too: touching
## its left or right half holds that flipper (set `table_view`).
## Multi-touch: each finger is tracked on its own, so both flippers can be held
## together (gear shift), and a finger sliding off a button releases it.
## A small HIDE / SHOW BUTTONS toggle floats in the top-right corner (`toggle`).
## D-219: the magna saves get a button each (left column: magna_l, right:
## magna_r). A game can rename them for what they do there (set_labels via
## the "touch_controls" group): the racer's BRAKE and SHIFT.
## --touch shows the controls on any device (mouse clicks work then, for testing).
extends Node

const UI = preload("res://core/ui/ui.gd")
const Face = preload("res://core/ui/touch_button.gd")
const Zones = preload("res://core/ui/touch_zones.gd")

## D-279: each button's icon in the overlay (a game can swap them, set_labels).
const ICONS := {
	&"flip_l": "left", &"flip_r": "right", &"launch": "launch", &"start": "start",
	&"exit": "exit", &"magna_l": "magna", &"magna_r": "magna",
}

## Top to bottom: [action, label key, stretch ratio]
## D-220: both columns have the same slots and ratios, so the flippers match
## in size and the two magna buttons line up; an empty slot on the left sits
## level with LAUNCH ("" = no button).
const LEFT_COLUMN := [
	[&"exit", "TOUCH_EXIT", 1.0],
	[&"", "", 1.3],
	[&"magna_l", "TOUCH_MAGNA_L", 1.3],
	[&"flip_l", "TOUCH_LEFT", 3.0],
]
const RIGHT_COLUMN := [
	[&"start", "TOUCH_START", 1.0],
	[&"launch", "TOUCH_LAUNCH", 1.3],
	[&"magna_r", "TOUCH_MAGNA_R", 1.3],
	[&"flip_r", "TOUCH_RIGHT", 3.0],
]
const COLORS := {
	&"flip_l": Color(0.2, 0.55, 1.0), &"flip_r": Color(0.2, 0.55, 1.0),
	&"launch": Color(1.0, 0.35, 0.2), &"start": Color(0.25, 0.85, 0.35),
	&"exit": Color(0.6, 0.6, 0.66),
	&"magna_l": Color(0.85, 0.25, 0.6), &"magna_r": Color(0.95, 0.75, 0.15),
}
const MOUSE := -100   # pointer id used for mouse clicks

var left := VBoxContainer.new()
var right := VBoxContainer.new()
var toggle := Button.new()
var _toggle_space := Control.new()
var _left_space := Control.new()   # the same height on the left (D-220)
var table_view: Control  # touches on its halves work the flippers
## D-251: over the game (single-screen layout): more see-through buttons.
var overlay := false:
	set(v):
		overlay = v
		for act in _buttons:
			(_faces[act] as Control).visible = v
			_style(act, false)
		# D-282: over the game, the bottom half of the screen is the two
		# flippers (`zones`), and the only buttons are EXIT (small, top left)
		# and LAUNCH (right edge, just above the middle), which Screens adds
		# to the page. LAUNCH does everything START does; the magna saves
		# have no touch control (D-007: two flippers and LAUNCH are enough).
		for act in OVERLAY_HIDDEN:
			(_buttons[act] as Control).visible = not v
		_left_blank.visible = not v
		var ex := _buttons[&"exit"] as Control
		if v and ex.get_parent() == left:
			left.remove_child(ex)
			exit_button = ex
			# Too small for a readable label: the cross alone, centred.
			(_labels[&"exit"] as Label).visible = false
			_faces[&"exit"].icon_y = 0.0
			_faces[&"exit"].icon_r = 0.42
		var la := _buttons[&"launch"] as Control
		if v and la.get_parent() == right:
			right.remove_child(la)
			launch_button = la
		if v and zones == null:
			zones = Zones.new()
## D-281 / D-282: the overlay's EXIT and LAUNCH buttons and its flipper areas,
## for Screens to add to the page (null in the side-column layout).
var exit_button: Control
var launch_button: Control
var zones: Control
var _left_blank: Control
const OVERLAY_HIDDEN := [&"start", &"flip_l", &"flip_r", &"magna_l", &"magna_r"]
const EXIT_SIZE := 0.62   # the floating EXIT's diameter, as a share of LAUNCH's
static var _hint_shown := false   # once per run on the menu; then at each game's start


## D-282: marks the flipper areas for a few seconds (GameMode calls it through
## the "touch_controls" group when a game starts).
func show_hint() -> void:
	if overlay and is_instance_valid(zones) and left.visible:
		zones.show_hint()
var _buttons := {}        # action -> Panel
var _labels := {}         # action -> Label
var _faces := {}          # action -> Face (the overlay's look, D-279)
var _fingers := {}        # pointer index -> action held by it
var _font_px := 24
var _down_frame := {}     # action -> frame it was pressed
var _late_release := {}   # action -> true: release once it has been seen held


static func wanted() -> bool:
	if Config.cli.has("touch"):
		return true
	return (OS.has_feature("web") or OS.has_feature("android")) and DisplayServer.is_touchscreen_available()


func _init() -> void:
	add_to_group("touch_controls")
	for col in [left, right]:
		col.add_theme_constant_override("separation", 6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_left_space)
	for b in LEFT_COLUMN:
		if b[0] != &"":
			left.add_child(_make_button(b))
		else:
			_left_blank = _make_blank(b)
			left.add_child(_left_blank)
	right.add_child(_toggle_space)   # the corner toggle sits over this
	for b in RIGHT_COLUMN:
		right.add_child(_make_button(b))
	_make_toggle()


func _ready() -> void:
	# Delayed releases happen in _process: run before CabinetInput polls, or
	# it never sees the "just released" frame (and the picker acts on release).
	process_priority = -100
	set_shown(bool(Config.get_value("display", "touch_controls")))
	if overlay and not _hint_shown:   # the menu needs the flippers too
		_hint_shown = true
		show_hint.call_deferred()


func _make_blank(b: Array) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = b[2]
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _make_button(b: Array) -> Panel:
	var panel := Panel.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = b[2]
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UI.label(tr(b[1]), _font_px, Color.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := Face.new(COLORS[b[0]], ICONS[b[0]])
	face.visible = overlay
	panel.add_child(face)
	panel.add_child(label)
	_buttons[b[0]] = panel
	_labels[b[0]] = label
	_faces[b[0]] = face
	_style(b[0], false)
	return panel


## Small corner button that hides or shows the columns. The choice is saved
## (in the browser's storage on the web).
func _make_toggle() -> void:
	toggle.focus_mode = Control.FOCUS_NONE   # Space/Enter must stay game keys
	toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toggle.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.12, 0.16, 0.7)
		sb.border_color = Color(0.5, 0.5, 0.58, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		toggle.add_theme_stylebox_override(st, sb)
	toggle.pressed.connect(func():
		set_shown(not left.visible)
		Config.set_value("display", "touch_controls", left.visible)
		Config.save())


## Renames buttons for the current game ({action: text}); {} restores the
## default labels (D-219). `icons` ({action: icon name}, D-279) swaps their
## overlay icons the same way.
func set_labels(labels: Dictionary, icons: Dictionary = {}) -> void:
	for b in LEFT_COLUMN + RIGHT_COLUMN:
		if not _buttons.has(b[0]):
			continue
		(_labels[b[0]] as Label).text = str(labels.get(b[0], tr(b[1])))
		_faces[b[0]].icon = str(icons.get(b[0], ICONS[b[0]]))


func set_shown(on: bool) -> void:
	left.visible = on
	right.visible = on
	for n in [exit_button, launch_button, zones]:
		if is_instance_valid(n):
			(n as Control).visible = on
	toggle.text = tr("TOUCH_HIDE") if on else tr("TOUCH_SHOW")
	if not on:
		_release_all()


## Column width and label size for a window of this size.
func fit(win: Vector2) -> void:
	if overlay:
		_fit_round(win)
		return
	var w := clampf(minf(win.x, win.y) * 0.17, 64.0, 240.0)
	left.custom_minimum_size.x = w
	right.custom_minimum_size.x = w
	var px := maxi(12, int(w * 0.24 / 12.0) * 12)
	toggle.add_theme_font_size_override("font_size", px)
	toggle.offset_right = -6
	toggle.offset_top = 6
	_toggle_space.custom_minimum_size.y = px + 16 + 8
	_left_space.custom_minimum_size.y = _toggle_space.custom_minimum_size.y
	if px != _font_px:
		_font_px = px
		for l in _labels.values():
			(l as Label).add_theme_font_size_override("font_size", px)


## D-273: the overlay's buttons: round, all one size, four to a column in the
## bottom bar (its height as Screens sets it: 42 % portrait, 60 % landscape).
var _round_d := 0.0


func _fit_round(win: Vector2) -> void:
	var bar_h := win.y * (0.42 if win.y > win.x else 0.6)
	# D-279: a margin from the screen's edges (rounded corners, gesture areas,
	# and room for each button's shadow and glow) and wider gaps between them.
	var edge := roundf(minf(win.x, win.y) * 0.035)
	var sep := roundf(maxf(10.0, minf(win.x, win.y) * 0.022))
	var d := floorf(minf((bar_h - edge - sep * 3.0) / 4.0, minf(win.x, win.y) * 0.17))
	d = maxf(d, 44.0)
	if is_instance_valid(exit_button):   # D-281: small, in the top left corner
		var de := roundf(d * EXIT_SIZE)
		exit_button.custom_minimum_size = Vector2.ZERO
		exit_button.position = Vector2(edge, edge) * 0.6
		exit_button.size = Vector2(de, de)
	if is_instance_valid(launch_button):   # D-282: right edge, just above the middle
		launch_button.custom_minimum_size = Vector2.ZERO
		launch_button.size = Vector2(d, d)
		launch_button.position = Vector2(win.x - edge - d, win.y * 0.5 - d - edge)
	_toggle_space.custom_minimum_size.y = 0
	_left_space.custom_minimum_size.y = 0
	for col in [left, right]:
		col.alignment = BoxContainer.ALIGNMENT_END
		col.add_theme_constant_override("separation", int(sep))
		col.custom_minimum_size.x = d + edge
		if not _edge_space.has(col):   # the gap under the lowest button
			_edge_space[col] = Control.new()
			(_edge_space[col] as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(_edge_space[col])
		(_edge_space[col] as Control).custom_minimum_size.y = maxf(0.0, edge - sep)
		for c in col.get_children():
			if c == _toggle_space or c == _left_space or c == _edge_space[col]:
				continue
			(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			(c as Control).size_flags_horizontal = Control.SIZE_SHRINK_END if col == left else Control.SIZE_SHRINK_BEGIN
			(c as Control).custom_minimum_size = Vector2(d, d)
	var px := maxi(12, int(d * 0.2 / 12.0) * 12)
	toggle.add_theme_font_size_override("font_size", maxi(12, int(minf(win.x, win.y) * 0.04 / 12.0) * 12))
	toggle.offset_right = -6
	toggle.offset_top = 6
	if d != _round_d or px != _font_px:
		_round_d = d
		_font_px = px
		# D-273 / D-279: the dot font sized so the longest label (6 letters,
		# 6 bits a letter) fits across the button under its icon.
		var bit := maxi(2, int(d * LABEL_W / 36.0))
		var size := int(ceilf(bit * 7.0 / 0.72))
		var f := UI.DotText.font(size)
		for act in _buttons:
			var l := _labels[act] as Label
			l.add_theme_font_override("font", f)
			l.add_theme_font_size_override("font_size", size)
			var bd := d * (EXIT_SIZE if _buttons[act] == exit_button else 1.0)
			# Small buttons: scale the label down so it still fits.
			var k := minf(1.0, bd * LABEL_W / (36.0 * bit))
			# In the lower part of the button, under the icon.
			l.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			l.size = Vector2(bd, bd * 0.3)
			l.position = Vector2(0.0, bd * 0.56)
			l.pivot_offset = l.size * 0.5
			l.scale = Vector2(k, k)
			_style(act, false)


const LABEL_W := 0.6   # the label's width as a share of the button's (D-279)
var _edge_space := {}  # column -> the spacer under its lowest button


func _style(action: StringName, down: bool) -> void:
	if overlay:   # D-279: the face draws the button; the panel only takes touches
		if is_instance_valid(zones) and (action == &"flip_l" or action == &"flip_r"):
			zones.set_held(0 if action == &"flip_l" else 1, down)
		(_buttons[action] as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_faces[action].set_down(down)
		(_labels[action] as Label).modulate = Color(1, 1, 1, 1.0 if down else 0.6)   # D-281: quieter at rest
		return
	var c: Color = COLORS[action]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c, 0.75) if down else Color(c.darkened(0.6), 0.55)
	sb.border_color = c.lightened(0.3) if down else Color(c, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	(_buttons[action] as Panel).add_theme_stylebox_override("panel", sb)


func _input(event: InputEvent) -> void:
	if not left.is_visible_in_tree():
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
	var on_button := false
	if not toggle.get_global_rect().has_point(pos):
		for action in _buttons:
			var bc := _buttons[action] as Control
			if bc.is_visible_in_tree() and bc.get_global_rect().has_point(pos):
				now = action
				on_button = true
				break
		if now == &"" and is_instance_valid(table_view):
			var r := table_view.get_global_rect()
			if overlay:   # D-282: the screen's bottom half is the flippers
				var win := Vector2(get_window().size)
				if pos.y >= win.y * 0.5 and pos.y <= win.y and pos.x >= 0.0 and pos.x <= win.x:
					now = &"flip_l" if pos.x < win.x * 0.5 else &"flip_r"
			elif r.has_point(pos):
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
		if index != MOUSE and on_button:
			Input.vibrate_handheld(12)   # D-279: a tick under the finger
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


func _release_all() -> void:
	for action in _fingers.values():
		Input.action_release(action)
		_style(action, false)
	for action in _late_release:
		Input.action_release(action)
	_fingers.clear()
	_late_release.clear()


func _exit_tree() -> void:
	_release_all()
	for n in [left, right, toggle, exit_button, launch_button, zones]:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
