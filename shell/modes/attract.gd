## Attract mode: cycles a title page and one high-score page per game on all three
## screens. Any button returns to the picker. Game-specific attract demos will plug
## in here later (GDD §4).
extends "res://shell/modes/mode.gd"

const ScoreTable = preload("res://core/util/score_table.gd")
const PAGE_SECONDS := 6.0
const DMD_LINE_SECONDS := 1.4

var _page := -1
var _page_time := 0.0
var _dmd_time := 0.0
var _dmd_line := 0
var _page_nodes: Array[Node] = []
var _dmd_lines: Array = []  # [text, color]


func allows_operator_combo() -> bool:
	return true


func enter() -> void:
	add_table(UI.fill(Color.BLACK))
	add_backglass(UI.fill(Color.BLACK))
	_next_page()


func on_action(action: StringName, pressed: bool) -> void:
	if pressed and action != &"exit" and action != &"start":
		CabinetInput.mute_until_release()
		shell.goto_picker()
	elif not pressed and (action == &"exit" or action == &"start"):
		# Act on release so Start+Exit / long Exit can still open the operator menu.
		shell.goto_picker()


func _process(delta: float) -> void:
	_page_time += delta
	_dmd_time += delta
	if _page_time >= PAGE_SECONDS:
		_next_page()
	elif _dmd_time >= DMD_LINE_SECONDS and _dmd_lines.size() > 1:
		_dmd_time = 0.0
		_dmd_line = (_dmd_line + 1) % _dmd_lines.size()
		_show_dmd_line()


func _next_page() -> void:
	for n in _page_nodes:
		n.queue_free()
	_page_nodes.clear()
	var ids := Registry.ids()
	_page = (_page + 1) % (ids.size() + 1)
	_page_time = 0.0
	_dmd_time = 0.0
	_dmd_line = 0
	if _page == 0:
		_title_page()
	else:
		_scores_page(ids[_page - 1])
	_show_dmd_line()


func _title_page() -> void:
	var col := UI.vstack(60)
	col.add_child(UI.label(tr("APP_TITLE"), 150, UI.YELLOW))
	for id in Registry.ids():
		var info := Registry.info(id)
		col.add_child(UI.label(tr(info.title_key), 64, info.get("color", UI.CYAN)))
	col.add_child(UI.spacer(80))
	col.add_child(UI.label(tr("ATTRACT_PRESS_START"), 70, UI.WHITE))
	col.add_child(UI.label(Credits.status_text(), 52, UI.GREEN))
	_page_nodes.append(add_table(col))
	var bg := UI.label(tr("APP_TITLE"), 240, UI.YELLOW)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_nodes.append(add_backglass(bg))
	_dmd_lines = [[tr("APP_TITLE"), Dmd.YELLOW], [tr("ATTRACT_PRESS_START"), Dmd.WHITE],
		[Credits.status_text(), Dmd.GREEN]]


func _scores_page(id: String) -> void:
	var info := Registry.info(id)
	var accent: Color = info.get("color", UI.CYAN)
	var table := HighScores.get_table(id)
	var col := UI.vstack(26)
	col.add_child(UI.label(tr(info.title_key), 96, accent))
	col.add_child(UI.label(tr("ATTRACT_HIGH_SCORES"), 60, UI.WHITE))
	col.add_child(UI.spacer(30))
	for i in table.size():
		var row: Array = table[i]
		var text := "%2d.  %s   %s" % [i + 1, row[0], ScoreTable.format_score(int(row[1]))]
		col.add_child(UI.label(text, 56 if i > 0 else 66, UI.YELLOW if i == 0 else UI.WHITE))
	_page_nodes.append(add_table(col))
	var fill := UI.fill(accent.darkened(0.85))
	_page_nodes.append(add_backglass(fill))
	var bg := UI.label(tr(info.title_key), 180, accent)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_nodes.append(add_backglass(bg))
	_dmd_lines = [[tr(info.title_key), accent]]
	for i in mini(3, table.size()):
		_dmd_lines.append(["%d. %s %s" % [i + 1, table[i][0], ScoreTable.format_score(int(table[i][1]))],
			Dmd.YELLOW if i == 0 else Dmd.WHITE])


func _show_dmd_line() -> void:
	if _dmd_lines.is_empty():
		return
	var line: Array = _dmd_lines[_dmd_line]
	Dmd.show_text(line[0], "", line[1])
