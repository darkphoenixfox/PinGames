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
var _blink: Control   # PRESS START on the title page (blinks with modulate.a, D-096)


func allows_operator_combo() -> bool:
	return true


func enter() -> void:
	portrait_only = false   # D-255
	add_table(UI.fill(Color.BLACK))
	add_backglass(UI.fill(Color.BLACK))
	if Config.get_value("operator", "attract_sounds"):
		Audio.play_music(Audio.MUSIC_MAIN)
	else:
		Audio.stop_music(2.0)
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
	if is_instance_valid(_blink):
		_blink.modulate.a = 1.0 if fmod(_page_time, 1.0) < 0.65 else 0.15
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
	# Shell text in the shell's styled fonts (D-186); the games as their logos.
	var col := UI.vstack(60)
	col.add_child(UI.styled_label(tr("APP_TITLE"), UI.SHELL_TITLE_FONT, 3))
	var land := Screens.table_base().x > Screens.table_base().y   # D-255: side by side
	var list: BoxContainer = col
	col.offset_top = Screens.dmd_cover()
	if land:
		col.add_theme_constant_override("separation", 24)
		list = HBoxContainer.new()
		list.alignment = BoxContainer.ALIGNMENT_CENTER
		list.add_theme_constant_override("separation", 80)
		col.add_child(list)
	for id in Registry.ids():
		list.add_child(_game_title(id, 330.0 if land else 380.0))
	col.add_child(UI.spacer(40))
	_blink = UI.styled_label(tr("ATTRACT_PRESS_START"), UI.SHELL_TITLE_FONT, 2)
	col.add_child(_blink)
	col.add_child(UI.styled_label(Credits.status_text(), UI.SHELL_TEXT_FONT, 1))
	_page_nodes.append(add_table(col))
	var bg := UI.styled_label(tr("APP_TITLE"), UI.SHELL_TITLE_FONT, 5)
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
	col.add_child(_game_title(id, 520.0))
	col.add_child(UI.spacer(10))
	col.add_child(UI.styled_label(tr("ATTRACT_HIGH_SCORES"), UI.SHELL_TITLE_FONT, 2))
	col.add_child(UI.spacer(30))
	for i in table.size():
		var row: Array = table[i]
		var text := "%2d.  %s   %s" % [i + 1, row[0], ScoreTable.format_score(int(row[1]))]
		# The leader in gold, the rest in chrome.
		col.add_child(UI.styled_label(text, UI.SHELL_TITLE_FONT if i == 0 else UI.SHELL_TEXT_FONT, 1))
	_page_nodes.append(add_table(col))
	var fill := UI.fill(accent.darkened(0.85))
	_page_nodes.append(add_backglass(fill))
	var art := Registry.backglass_rect(Registry.backglass_art(id))  # D-088
	if art:
		_page_nodes.append(add_backglass(art))
	else:
		var bg := UI.styled_label(tr(info.title_key), str(info.get("font", UI.SHELL_TITLE_FONT)), 4)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_page_nodes.append(add_backglass(bg))
	_dmd_lines = [[tr(info.title_key), accent]]
	for i in mini(3, table.size()):
		_dmd_lines.append(["%d. %s %s" % [i + 1, table[i][0], ScoreTable.format_score(int(table[i][1]))],
			Dmd.YELLOW if i == 0 else Dmd.WHITE])


## A game's logo (D-088), or its title in its own styled font.
func _game_title(id: String, logo_h: float) -> Control:
	var info := Registry.info(id)
	if info.has("logo") and ResourceLoader.exists(str(info.logo)):
		var r := TextureRect.new()
		r.texture = load(info.logo)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(0, logo_h * 0.5)
		return r
	return UI.styled_label(tr(info.title_key), str(info.get("font", UI.SHELL_TITLE_FONT)), 2)


func _show_dmd_line() -> void:
	if _dmd_lines.is_empty():
		return
	var line: Array = _dmd_lines[_dmd_line]
	Dmd.show_text(line[0], "", line[1])
