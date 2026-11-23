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
}

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
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.5)
		for b in get_bindings(action):
			var ev := Bindings.to_event(str(b))
			if ev == null:
				push_warning("CabinetInput: bad binding '%s' for %s" % [b, action])
				continue
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


func steer_axis() -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var v := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		if absf(v) > absf(best):
			best = v
	if absf(best) < STICK_DEAD:
		return 0.0
	return signf(best) * (absf(best) - STICK_DEAD) / (1.0 - STICK_DEAD)


func trigger(right: bool) -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		best = maxf(best, Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT if right else JOY_AXIS_TRIGGER_LEFT))
	return 0.0 if best < TRIGGER_DEAD else best


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
			for a in ACTIONS:
				if Input.is_action_pressed(a):
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
	for action in ACTIONS:
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
