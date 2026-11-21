## High-score initials entry (GDD §3): flippers cycle the letter, Launch confirms,
## Exit goes back one letter. Auto-confirms after a timeout.
extends "res://shell/modes/mode.gd"

const ScoreTable = preload("res://core/util/score_table.gd")
const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
const TIMEOUT := 30.0
const DONE_SECONDS := 2.5

var game_id := ""
var score := 0
var _letters := [0, 0, 0]
var _pos := 0
var _left := TIMEOUT
var _done := false
var _slots: Array[Label] = []
var _timer_label: Label


func _init(p_game_id: String, p_score: int) -> void:
	game_id = p_game_id
	score = p_score


func enter() -> void:
	var info := Registry.info(game_id)
	var accent: Color = info.get("color", UI.CYAN)
	add_table(UI.fill(UI.DARK))
	var col := UI.vstack(40)
	add_table(col)
	col.add_child(UI.label(tr("HS_NEW_HIGH_SCORE"), 90, UI.YELLOW))
	col.add_child(UI.label(tr(info.title_key), 60, accent))
	col.add_child(UI.label(ScoreTable.format_score(score), 110, UI.WHITE))
	col.add_child(UI.spacer(40))
	col.add_child(UI.label(tr("HS_ENTER_INITIALS"), 56, UI.WHITE))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	col.add_child(row)
	for i in 3:
		var l := UI.label("", 180, UI.WHITE)
		l.custom_minimum_size = Vector2(160, 0)
		row.add_child(l)
		_slots.append(l)
	col.add_child(UI.spacer(40))
	var hint := UI.label(tr("HS_HINT"), 36, UI.GREY)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	_timer_label = UI.label("", 44, UI.GREY)
	col.add_child(_timer_label)

	add_backglass(UI.fill(accent.darkened(0.85)))
	var art := Registry.backglass_rect(Registry.backglass_art(game_id))  # D-088
	if art:
		add_backglass(art)
	else:
		var bg := UI.label(tr("HS_NEW_HIGH_SCORE"), 150, UI.YELLOW)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_backglass(bg)
	Audio.sfx("fanfare")
	_refresh()


func on_action(action: StringName, pressed: bool) -> void:
	if not pressed or _done:
		return
	_left = TIMEOUT
	match action:
		&"flip_l", &"magna_l":
			_letters[_pos] = posmod(_letters[_pos] - 1, CHARS.length())
			Audio.sfx("letter")
		&"flip_r", &"magna_r":
			_letters[_pos] = posmod(_letters[_pos] + 1, CHARS.length())
			Audio.sfx("letter")
		&"launch", &"start":
			Audio.sfx("select")
			if _pos < 2:
				_letters[_pos + 1] = _letters[_pos]  # start next slot on same letter
				_pos += 1
			else:
				_finish()
				return
		&"exit":
			if _pos > 0:
				_pos -= 1
				Audio.sfx("back")
	_refresh()


func _process(delta: float) -> void:
	if _done:
		return
	_left -= delta
	_timer_label.text = "%d" % ceili(_left)
	if _left <= 0.0:
		_finish()


func _initials() -> String:
	var s := ""
	for i in 3:
		s += CHARS[_letters[i]]
	return s


func _refresh() -> void:
	var blink := ""
	for i in 3:
		var ch: String = CHARS[_letters[i]]
		_slots[i].text = (ch if ch != " " else "-") if i <= _pos else "_"
		UI.set_color(_slots[i], UI.CYAN if i == _pos else UI.WHITE)
		blink += ch if i <= _pos else "_"
	Dmd.show_text(tr("DMD_ENTER_INITIALS"), blink, Dmd.YELLOW, Dmd.WHITE)


func _finish() -> void:
	_done = true
	var initials := _initials().strip_edges()
	if initials.is_empty():
		initials = "???"
	var rank := HighScores.submit(game_id, initials, score)
	_timer_label.text = ""
	if rank >= 0:
		Dmd.show_text(tr("DMD_RANK") % (rank + 1), initials, Dmd.YELLOW, Dmd.WHITE)
	get_tree().create_timer(DONE_SECONDS).timeout.connect(func():
		if is_inside_tree():
			shell.goto_picker())
