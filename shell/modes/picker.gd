## Game picker. Flippers choose, Launch/Start play, Exit quits the app.
## Start/Launch/Exit act on *release* and only after a short press, so holding
## Start+Exit (or Exit) for the operator menu never triggers them (D-024).
## When the app was launched with --game, the picker is locked to that game
## (play again / quit to the frontend).
extends "res://shell/modes/mode.gd"

const ScoreTable = preload("res://core/util/score_table.gd")
const TAP_MAX_MS := 900

var locked_game := ""
var _ids: Array = []
var _index := 0
var _labels: Array[Label] = []
var _hiscore: Label
var _credits: Label
var _bg_title: Label
var _bg_fill: ColorRect
var _press_ms := {}
var _idle := 0.0


func _init(p_locked_game: String = "", start_index: int = 0) -> void:
	locked_game = p_locked_game
	_index = start_index


func allows_operator_combo() -> bool:
	return true


func enter() -> void:
	_ids = [locked_game] if not locked_game.is_empty() else Registry.ids()
	_index = clampi(_index, 0, _ids.size() - 1)
	add_table(UI.fill(UI.DARK))
	var col := UI.vstack(40)
	add_table(col)
	col.add_child(UI.label(tr("APP_TITLE"), 130, UI.YELLOW))
	col.add_child(UI.label(tr("PICKER_TITLE") if locked_game.is_empty() else tr("PICKER_PLAY_AGAIN"), 60))
	col.add_child(UI.spacer(30))
	_labels.clear()
	for id in _ids:
		var l := UI.label(tr(Registry.info(id).title_key), 78)
		col.add_child(l)
		_labels.append(l)
	col.add_child(UI.spacer(30))
	_hiscore = UI.label("", 46, UI.WHITE)
	col.add_child(_hiscore)
	col.add_child(UI.spacer(60))
	_credits = UI.label("", 52, UI.GREEN)
	col.add_child(_credits)
	var hint := UI.label(tr("PICKER_HINT"), 36, UI.GREY)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	_bg_fill = add_backglass(UI.fill(UI.DARK)) as ColorRect
	_bg_title = UI.label("", 170, UI.YELLOW)
	_bg_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bg_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_backglass(_bg_title)

	Credits.changed.connect(_refresh)
	_refresh()


func on_action(action: StringName, pressed: bool) -> void:
	_idle = 0.0
	if pressed:
		_press_ms[action] = Time.get_ticks_msec()
		match action:
			&"flip_l", &"magna_l":
				_move(-1)
			&"flip_r", &"magna_r":
				_move(1)
		return
	# Release: only short taps count, and not while the other combo button is held.
	var held := Time.get_ticks_msec() - int(_press_ms.get(action, 0))
	_press_ms.erase(action)
	if held > TAP_MAX_MS or (action == &"start" and CabinetInput.is_down(&"exit")) \
			or (action == &"exit" and CabinetInput.is_down(&"start")):
		return
	match action:
		&"launch", &"start":
			shell.start_game(_ids[_index])
		&"exit":
			get_tree().quit()


func _process(delta: float) -> void:
	_idle += delta
	if locked_game.is_empty() and _idle >= float(Config.get_value("operator", "attract_delay")):
		shell.goto_attract()


func _move(d: int) -> void:
	if _ids.size() <= 1:
		return
	_index = posmod(_index + d, _ids.size())
	Audio.sfx("move")
	_refresh()


func selected_index() -> int:
	return _index


func _refresh() -> void:
	var id: String = _ids[_index]
	var info := Registry.info(id)
	var accent: Color = info.get("color", UI.CYAN)
	for i in _labels.size():
		UI.set_color(_labels[i], accent if i == _index else UI.GREY)
		_labels[i].text = ("> %s <" if i == _index else "%s") % tr(Registry.info(_ids[i]).title_key)
	var best: Array = HighScores.get_table(id)[0]
	_hiscore.text = tr("PICKER_HISCORE") % [best[0], ScoreTable.format_score(int(best[1]))]
	_credits.text = Credits.status_text()
	_bg_title.text = tr(info.title_key)
	UI.set_color(_bg_title, accent)
	_bg_fill.color = accent.darkened(0.85)
	Dmd.show_text(tr(info.title_key), Credits.status_text(), accent, Dmd.DIM)
