## CabinetInput autoload: the only place that knows about physical inputs.
## Gameplay code listens to `action_pressed` / `action_released` with logical
## action names and never reads keys/buttons directly (D-007).
## Polls the global Input singleton, so it works whichever window has focus.
## Also provides hold timing (operator combos, bomb charge) and remap capture.
extends Node

signal action_pressed(action: StringName)
signal action_released(action: StringName)

const Bindings = preload("res://core/util/bindings.gd")

## Logical actions. 2+1 baseline: flip_l, flip_r, launch. Guaranteed: start, exit.
## Optional (4+1 cabinets): magna_l, magna_r. Optional: coin.
const ACTIONS: Array[StringName] = [
	&"flip_l", &"flip_r", &"magna_l", &"magna_r", &"launch", &"start", &"coin", &"exit",
	&"back",   # D-260: cancel / go back in menus (a pad's Circle); never quits
]

## Director-specified defaults (D-019; flippers moved off Shift in D-075). Godot joypad indices use SDL layout:
## joy:0 = Cross/A, joy:1 = Circle/B, joy:2 = Square/X, joy:9 = L1, joy:10 = R1,
## axis:4 = L2, axis:5 = R2.
const DEFAULT_BINDINGS := {
	"flip_l": ["key:Left", "joy:9"],            # L1  (left arrow, D-077)
	"flip_r": ["key:Right", "joy:10"],          # R1  (right arrow, D-077)
	"magna_l": ["key:Ctrl@left", "axis:4+"],    # L2
	"magna_r": ["key:Ctrl@right", "axis:5+"],   # R2
	"launch": ["key:Space", "joy:0"],           # Cross
	"start": ["key:Enter", "key:Kp Enter", "joy:1"],  # Circle
	"coin": ["key:5"],
	"exit": ["key:Backspace", "joy:2"],         # Square
	"back": ["key:Escape"],                     # D-260
}

## D-256: the single-screen version's gamepad (director): D-pad and left stick
## move in menus (the flipper actions; in the race the stick steers analog,
## D-252), Cross accepts, Circle goes back, Start quits (D-257); L1 brakes and R1
## shifts (the magna actions); R2 is the analog accelerator (read directly).
## Replaces the pad bindings (keys stay) when the layout is "single".
const SINGLE_PAD := {
	"flip_l": ["joy:13", "axis:0-"],
	"flip_r": ["joy:14", "axis:0+"],
	"magna_l": ["joy:9"],
	"magna_r": ["joy:10"],
	"launch": ["joy:0"],
	"start": [],
	"coin": [],
	"exit": ["joy:6"],            # D-260: Start (asks before quitting)
	"back": ["joy:1"],            # D-260: Circle cancels, never quits
}

## D-284: local 2-player (single-screen landscape only). Player 2 has its own
## actions; when 2P is on (`set_two_player`), each gamepad is a player (pad 1 =
## P1, pad 2 = P2), one pad alone is P2 with the keyboard as P1, and with no
## pad the keyboard splits: P1 arrows / Space / Ctrl, P2 A D / W / Q E.
const P2_ACTIONS: Array[StringName] = [&"p2_flip_l", &"p2_flip_r", &"p2_launch", &"p2_magna_l", &"p2_magna_r"]
const P2_KEYS := {
	"p2_flip_l": ["key:A"], "p2_flip_r": ["key:D"], "p2_launch": ["key:W"],
	"p2_magna_l": ["key:Q"], "p2_magna_r": ["key:E"],
}
## Per-player actions: each pad only drives its own player's.
const PLAYER_ACTIONS: Array[StringName] = [&"flip_l", &"flip_r", &"launch", &"magna_l", &"magna_r"]
var two_player := false
var devices := [-1, -1]   # each player's gamepad (-1 = keyboard)


## 2P is offered only on a landscape single screen, with keys or two pads.
func two_player_possible() -> bool:
	if Screens.current_layout != "single":
		return false
	var win := Vector2(get_viewport().get_visible_rect().size) if is_inside_tree() else Vector2(1, 0)
	if win.y > win.x:
		return false
	var touch_only := (OS.has_feature("android") or OS.has_feature("web")) and DisplayServer.is_touchscreen_available()
	return not touch_only or Input.get_connected_joypads().size() >= 2


func set_two_player(on: bool) -> void:
	two_player = on
	apply_bindings()
	if on and not Input.joy_connection_changed.is_connected(_on_joy):
		Input.joy_connection_changed.connect(_on_joy)


func _on_joy(_device: int, _connected: bool) -> void:
	if two_player:
		apply_bindings()


## "launch" -> "p2_launch" for player 1 (0-based: 0 is player 1).
static func for_player(action: StringName, player: int) -> StringName:
	return action if player == 0 else StringName("p2_" + String(action))

## Emitted on focus loss/gain (D-069), e.g. for the input monitor.
signal focus_changed(has_focus: bool)

var _down_since := {}  # action -> ticks msec when pressed
var has_focus := true
var _muted := false
var _capture := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_bindings()


func apply_bindings() -> void:
	if two_player:
		var pads := Input.get_connected_joypads()
		if pads.size() >= 2:
			devices = [pads[0], pads[1]]
		elif pads.size() == 1:
			devices = [-1, pads[0]]
		else:
			devices = [-1, -1]
	else:
		devices = [-1, -1]
	for action in P2_ACTIONS:   # D-284
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.5)
		if not two_player:
			continue
		for b in P2_KEYS[String(action)]:
			InputMap.action_add_event(action, Bindings.to_event(str(b)))
		if devices[1] >= 0:
			for b in SINGLE_PAD.get(String(action).trim_prefix("p2_"), []):
				var ev := Bindings.to_event(str(b))
				if ev != null:
					ev.device = devices[1]
					InputMap.action_add_event(action, ev)
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.5)
		var binds := get_bindings(action)
		if Config.layout() == "single":   # D-256
			binds = binds.filter(func(b): return Bindings.kind(str(b)) == "key")
			binds.append_array(SINGLE_PAD.get(String(action), []))
		if two_player and action in PLAYER_ACTIONS:
			# D-284: player 1's pad (if any) only; the keyboard stays.
			binds = binds.filter(func(b): return Bindings.kind(str(b)) == "key")
			if devices[0] >= 0:
				binds.append_array(SINGLE_PAD.get(String(action), []))
		for b in binds:
			var ev := Bindings.to_event(str(b))
			if ev == null:
				push_warning("CabinetInput: bad binding '%s' for %s" % [b, action])
				continue
			if two_player and action in PLAYER_ACTIONS and Bindings.kind(str(b)) != "key":
				ev.device = devices[0]
			InputMap.action_add_event(action, ev)


func get_bindings(action: StringName) -> Array:
	var list: Variant = Config.get_value("input", String(action), DEFAULT_BINDINGS[String(action)])
	return (list as Array).duplicate() if list is Array else []


## Adds a binding to an action, replacing that action's bindings of the same kind
## (keyboard vs joypad) and removing it from any other action that used it.
func set_binding(action: StringName, binding: String) -> void:
	var kind := Bindings.kind(binding)
	for a in ACTIONS:
		if a == action:
			continue
		var other := get_bindings(a)
		if binding in other:
			other.erase(binding)
			Config.set_value("input", String(a), other)
	var list := get_bindings(action).filter(func(b): return Bindings.kind(str(b)) != kind)
	list.append(binding)
	Config.set_value("input", String(action), list)
	apply_bindings()


func reset_bindings() -> void:
	for a in ACTIONS:
		Config.set_value("input", String(a), (DEFAULT_BINDINGS[String(a)] as Array).duplicate())
	apply_bindings()


func describe_bindings(action: StringName) -> String:
	var parts: PackedStringArray = []
	for b in get_bindings(action):
		parts.append(Bindings.describe(str(b)))
	return ", ".join(parts)


## Seconds the action has been held (0 if up).
func held_time(action: StringName) -> float:
	if not Input.is_action_pressed(action) or not _down_since.has(action):
		return 0.0
	return (Time.get_ticks_msec() - int(_down_since[action])) / 1000.0


## Analog gamepad input (D-252), from any connected pad. Left stick X with a
## deadzone (-1 left .. 1 right, rescaled past the deadzone); triggers 0..1.
const STICK_DEAD := 0.18
const TRIGGER_DEAD := 0.06


func steer_axis(player: int = -1) -> float:
	var best := 0.0
	for dev in _pads_of(player):
		var v := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		if absf(v) > absf(best):
			best = v
	if absf(best) < STICK_DEAD:
		return 0.0
	return signf(best) * (absf(best) - STICK_DEAD) / (1.0 - STICK_DEAD)


func trigger(right: bool, player: int = -1) -> float:
	var best := 0.0
	for dev in _pads_of(player):
		best = maxf(best, Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT if right else JOY_AXIS_TRIGGER_LEFT))
	return 0.0 if best < TRIGGER_DEAD else best


## The pads whose sticks count for a player (-1 = anyone, D-284).
func _pads_of(player: int) -> Array:
	if player < 0 or not two_player:
		return Input.get_connected_joypads()
	return [] if devices[player] < 0 else [devices[player]]


func is_down(action: StringName) -> bool:
	return Input.is_action_pressed(action)


## Suppresses action signals until every action is released (used after mode
## switches and remap capture so the triggering press does not leak).
func mute_until_release() -> void:
	_muted = true


## Calls `callback(binding: String)` with the next physical press.
func capture_next(callback: Callable) -> void:
	_capture = callback
	_muted = true


func cancel_capture() -> void:
	_capture = Callable()


func is_capturing() -> bool:
	return _capture.is_valid()


## If the window loses keyboard focus (e.g. a Windows Sticky Keys / Filter Keys
## prompt after repeated Shift presses), key-up events never arrive and actions
## would stay "held". Release everything on focus loss (D-069).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			has_focus = false
			for a in ACTIONS + P2_ACTIONS:
				if InputMap.has_action(a) and Input.is_action_pressed(a):
					Input.action_release(a)
			focus_changed.emit(false)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			has_focus = true
			focus_changed.emit(true)


func _input(event: InputEvent) -> void:
	if not _capture.is_valid():
		return
	var b := Bindings.from_event(event)
	if b.is_empty():
		return
	var cb := _capture
	_capture = Callable()
	get_viewport().set_input_as_handled()
	cb.call(b)


func _process(_delta: float) -> void:
	var any_down := false
	for action in (ACTIONS + P2_ACTIONS) if two_player else ACTIONS:
		if Input.is_action_pressed(action):
			any_down = true
		if Input.is_action_just_pressed(action):
			_down_since[action] = Time.get_ticks_msec()
			if not _muted:
				action_pressed.emit(action)
		elif Input.is_action_just_released(action):
			_down_since.erase(action)
			if not _muted:
				action_released.emit(action)
	if _muted and not any_down and not _capture.is_valid():
		_muted = false
