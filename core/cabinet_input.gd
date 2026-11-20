## CabinetInput autoload: the only place that knows about physical inputs.
## Gameplay code listens to `action_pressed` / `action_released` with logical
## action names and never reads keys/buttons directly (D-007).
## Polls the global Input singleton, so it works whichever window has focus.
extends Node

signal action_pressed(action: StringName)
signal action_released(action: StringName)

const Bindings = preload("res://core/util/bindings.gd")

## Logical actions. 2+1 baseline: flip_l, flip_r, launch. Guaranteed: start, exit.
## Optional (4+1 cabinets): magna_l, magna_r. Optional: coin.
const ACTIONS: Array[StringName] = [
	&"flip_l", &"flip_r", &"magna_l", &"magna_r", &"launch", &"start", &"coin", &"exit",
]

## Director-specified defaults (D-019). Godot joypad indices use SDL layout:
## joy:0 = Cross/A, joy:1 = Circle/B, joy:2 = Square/X, joy:9 = L1, joy:10 = R1,
## axis:4 = L2, axis:5 = R2.
const DEFAULT_BINDINGS := {
	"flip_l": ["key:Shift@left", "joy:9"],      # L1
	"flip_r": ["key:Shift@right", "joy:10"],    # R1
	"magna_l": ["key:Ctrl@left", "axis:4+"],    # L2
	"magna_r": ["key:Ctrl@right", "axis:5+"],   # R2
	"launch": ["key:Space", "joy:0"],           # Cross
	"start": ["key:Enter", "key:Kp Enter", "joy:1"],  # Circle
	"coin": ["key:5"],
	"exit": ["key:Backspace", "joy:2"],         # Square
}


func _ready() -> void:
	apply_bindings()


func apply_bindings() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.5)
		var list: Array = Config.get_value("input", String(action), DEFAULT_BINDINGS[String(action)])
		for b in list:
			var ev := Bindings.to_event(str(b))
			if ev == null:
				push_warning("CabinetInput: bad binding '%s' for %s" % [b, action])
				continue
			InputMap.action_add_event(action, ev)


func _process(_delta: float) -> void:
	for action in ACTIONS:
		if Input.is_action_just_pressed(action):
			action_pressed.emit(action)
		elif Input.is_action_just_released(action):
			action_released.emit(action)


func is_down(action: StringName) -> bool:
	return Input.is_action_pressed(action)
