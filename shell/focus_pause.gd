## Browser build: the game stops while the page doesn't have focus (D-178).
## When the page loses focus (another tab, another window, the app minimised),
## the whole tree pauses, the sound is muted and PAUSED shows on the TABLE and
## the DMD. Coming back does not resume straight away: the next key, tap or
## click does, so the game never restarts while the player's hands are away.
## That press is not passed to the game (CabinetInput.mute_until_release).
## Cabinets are not affected (a frontend or a Windows prompt can take focus
## there, D-069); --pause-on-blur turns it on anywhere, for testing.
extends Node

const UI = preload("res://core/ui/ui.gd")

var _paused := false
var _focused := true
var _was_muted := false
var _overlay: Control


static func wanted() -> bool:
	if Config.cli.has("no-focus-pause"):   # test runs in a headless browser (never focused)
		return false
	return OS.has_feature("web") or Config.cli.has("pause-on-blur")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_pause()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			if is_instance_valid(_overlay):
				(_overlay.get_meta(&"hint") as Control).modulate.a = 1.0


func _pause() -> void:
	if _paused or get_tree().paused:   # already paused (e.g. the debug P key)
		return
	_paused = true
	get_tree().paused = true
	_was_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 200
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 40)
	_overlay.add_child(col)
	var title := UI.label(tr("FOCUS_PAUSED"), 144, UI.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := UI.label(tr("FOCUS_RESUME_HINT"), 48, UI.WHITE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate.a = 0.0   # shown once the page has focus again (D-096: modulate, not visible)
	col.add_child(hint)
	_overlay.set_meta(&"hint", hint)
	Screens.table.add_child(_overlay)
	Dmd.show_text(tr("FOCUS_PAUSED"), "", Dmd.YELLOW)


func _resume() -> void:
	_paused = false
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	AudioServer.set_bus_mute(0, _was_muted)
	CabinetInput.mute_until_release()   # the resume press is not a game action
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not _paused or not _focused:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if go:
		get_viewport().set_input_as_handled()
		_resume()
