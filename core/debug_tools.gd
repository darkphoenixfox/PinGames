## DebugTools autoload (D-057): keyboard shortcuts for testing, active only in
## debug builds (any run through the Godot binary / scripts; exported release
## builds ignore them, so cabinets are unaffected).
##   P  pause / resume the whole game (shows PAUSED on the TABLE)
##   F  game-specific debug action (`debug_action` signal, e.g. Tilt Breaker's
##      piercing plasma that destroys everything in a vertical line)
extends Node

const UI = preload("res://core/ui/ui.gd")

## Emitted for game-specific debug keys; games connect while they run.
signal debug_action(action: StringName)

var enabled := false
var _pause_label: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.is_debug_build() and str(Config.cli.get("debug-tools", "on")) != "off"


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
