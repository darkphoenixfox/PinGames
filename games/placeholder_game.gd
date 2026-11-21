## Temporary shared placeholder used by the game stubs until each game has real
## content. Shows the title on all three screens, echoes cabinet actions, and has
## fake scoring so the shell flow (game over -> high score entry) can be tested:
##   Launch = +1,000 points, flippers = +10, Start = game over.
## Delete once every game has real content.
extends "res://core/game_module.gd"

const UI = preload("res://core/ui/ui.gd")

var game_id := ""
var title_key := ""
var accent := Color.WHITE
var title_font := ""  # styled title font (D-062)
var score := 0
var _log: Label
var _score_label: Label


func get_info() -> Dictionary:
	return {"id": game_id, "title_key": title_key, "color": accent, "font": title_font, "buttons_min": 3}


func start(_players: int) -> void:
	add_to_table(UI.fill(accent.darkened(0.85)))
	var box := UI.vstack(40)
	add_to_table(box)
	box.add_child(UI.label(tr(title_key), 96, accent))
	box.add_child(UI.label(tr("COMING_SOON"), 56))
	_score_label = UI.label("0", 120, UI.YELLOW)
	box.add_child(_score_label)
	_log = UI.label("", 44, UI.GREY)
	box.add_child(_log)
	var hint := UI.label(tr("PLACEHOLDER_HINT"), 36, UI.GREY)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	add_to_backglass(UI.fill(accent.darkened(0.6)))
	var t := UI.label(tr(title_key), 140)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_to_backglass(t)
	_update_score()


func on_action(action: StringName, pressed: bool) -> void:
	var state := tr("INPUT_DOWN") if pressed else tr("INPUT_UP")
	_log.text = "%s %s" % [String(action).to_upper(), state]
	if not pressed:
		return
	match action:
		&"launch":
			score += 1000
			Dmd.flash("+1,000", 0.6, Dmd.CYAN)
		&"flip_l", &"flip_r", &"magna_l", &"magna_r":
			score += 10
		&"start":
			finished.emit([score])
			return
	_update_score()


func _update_score() -> void:
	_score_label.text = str(score)
	score_changed.emit(0, score)
	Dmd.show_score(score, tr("DMD_PLAYER_1"), tr("DMD_BALL") % 1, accent)
