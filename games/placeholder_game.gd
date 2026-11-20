## Temporary shared placeholder used by the M0 game stubs. Shows the game title on
## all three screens and echoes cabinet actions on the DMD so input can be tested.
## Delete once every game has real content.
extends "res://core/game_module.gd"

var title_key := ""
var accent := Color.WHITE
var _log: Label


func start(_players: int) -> void:
	var bg := ColorRect.new()
	bg.color = accent.darkened(0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_table(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_to_table(box)
	box.add_child(_label(tr(title_key), 96, accent))
	box.add_child(_label(tr("COMING_SOON"), 56, Color.WHITE))
	_log = _label("", 44, Color(0.8, 0.8, 0.8))
	box.add_child(_log)
	box.add_child(_label(tr("PRESS_EXIT_TO_RETURN"), 40, Color(0.6, 0.6, 0.6)))

	var bg2 := ColorRect.new()
	bg2.color = accent.darkened(0.6)
	bg2.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_backglass(bg2)
	var t := _label(tr(title_key), 140, Color.WHITE)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_to_backglass(t)

	Dmd.show_text(tr(title_key), tr("DMD_PLAYER_1"))


func on_action(action: StringName, pressed: bool) -> void:
	var state := tr("INPUT_DOWN") if pressed else tr("INPUT_UP")
	_log.text = "%s %s" % [String(action).to_upper(), state]
	if pressed:
		Dmd.show_text(tr(title_key), String(action).to_upper())


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
