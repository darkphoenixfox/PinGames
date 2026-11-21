## Game picker. Flippers choose, Launch/Start play, Exit asks to quit the app
## (Launch/Start = yes, Exit/flipper/timeout = no — D-031).
## Start/Launch/Exit act on *release* and only after a short press, so holding
## Start+Exit (or Exit) for the operator menu never triggers them (D-024).
## When the app was launched with --game, the picker is locked to that game
## (play again / quit to the frontend).
extends "res://shell/modes/mode.gd"

const ScoreTable = preload("res://core/util/score_table.gd")
const SystemChecks = preload("res://core/system_checks.gd")
const TAP_MAX_MS := 900
const QUIT_CONFIRM_SECONDS := 5.0

var locked_game := ""
var _open_quit := false
var _quit_left := 0.0
var _quit_overlay: Control
var _ids: Array = []
var _index := 0
var _labels: Array[Control] = []  # per game: logo TextureRect, or styled name Label
var _hiscore: Label
var _credits: Label
var _bg_title: Label
var _bg_fill: ColorRect
## Logo sizes in the list (D-063): selected vs other entries.
const LOGO_SELECTED := Vector2(700, 540)
const LOGO_OTHER := Vector2(400, 300)
var _bg_logo: TextureRect
var _press_ms := {}
var _idle := 0.0


func _init(p_locked_game: String = "", start_index: int = 0, open_quit_confirm: bool = false) -> void:
	locked_game = p_locked_game
	_index = start_index
	_open_quit = open_quit_confirm


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
	col.add_child(UI.spacer(10))
	_labels.clear()
	for id in _ids:
		# A game's logo replaces its name in the list; otherwise its styled title.
		var info := Registry.info(id)
		var font: String = info.get("font", "")
		var item: Control
		if info.has("logo"):
			item = _logo_rect(LOGO_OTHER)
			(item as TextureRect).texture = load(info.logo)
		elif not font.is_empty():
			item = UI.styled_label(tr(info.title_key), font, 2)
		else:
			item = UI.label(tr(info.title_key), 78)
		col.add_child(item)
		_labels.append(item)
	col.add_child(UI.spacer(30))
	_hiscore = UI.label("", 46, UI.WHITE)
	col.add_child(_hiscore)
	col.add_child(UI.spacer(60))
	_credits = UI.label("", 52, UI.GREEN)
	col.add_child(_credits)
	# Windows Sticky/Filter Keys shortcuts can freeze the Shift flippers (D-070).
	for w in SystemChecks.warnings():
		var warn := UI.label(tr(w), 36, UI.RED)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	if not SystemChecks.warnings().is_empty():
		var how := UI.label(tr("SYS_WARN_HOWTO"), 24, UI.YELLOW)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(how)
	var hint := UI.label(tr("PICKER_HINT"), 36, UI.GREY)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	_bg_fill = add_backglass(UI.fill(UI.DARK)) as ColorRect
	_bg_logo = _logo_rect(Vector2.ZERO)
	_bg_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_logo.offset_left = 120
	_bg_logo.offset_right = -120
	_bg_logo.offset_top = 60
	_bg_logo.offset_bottom = -60
	add_backglass(_bg_logo)
	_bg_title = UI.label("", 170, UI.YELLOW)
	_bg_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bg_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_backglass(_bg_title)

	Credits.changed.connect(_refresh)
	Audio.play_music(Audio.MUSIC_MAIN)
	_refresh()
	if _open_quit:
		_show_quit_confirm()


func on_action(action: StringName, pressed: bool) -> void:
	_idle = 0.0
	if pressed:
		_press_ms[action] = Time.get_ticks_msec()
		if _quit_left > 0.0:
			if action in [&"flip_l", &"flip_r", &"magna_l", &"magna_r"]:
				_hide_quit_confirm()
			return
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
	if _quit_left > 0.0:
		match action:
			&"launch", &"start":
				Audio.sfx("back")
				get_tree().quit()
			&"exit":
				_hide_quit_confirm()
		return
	match action:
		&"launch", &"start":
			shell.start_game(_ids[_index])
		&"exit":
			_show_quit_confirm()


func _process(delta: float) -> void:
	_idle += delta
	if _quit_left > 0.0:
		_quit_left -= delta
		if _quit_left <= 0.0:
			_hide_quit_confirm()
		return
	if locked_game.is_empty() and _idle >= float(Config.get_value("operator", "attract_delay")):
		shell.goto_attract()


func _show_quit_confirm() -> void:
	_quit_left = QUIT_CONFIRM_SECONDS
	if _quit_overlay == null:
		_quit_overlay = add_table(UI.fill(Color(0, 0, 0, 0.88))) as Control
		var col := UI.vstack(50)
		col.add_child(UI.label(tr("QUIT_CONFIRM"), 110, UI.YELLOW))
		var hint := UI.label(tr("QUIT_HINT"), 56, UI.WHITE)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(hint)
		_quit_overlay.add_child(col)
	_quit_overlay.visible = true
	Audio.sfx("error")
	Dmd.show_text(tr("QUIT_CONFIRM"), tr("DMD_QUIT_HINT"), Dmd.YELLOW, Dmd.WHITE)


func _hide_quit_confirm() -> void:
	_quit_left = 0.0
	if _quit_overlay:
		_quit_overlay.visible = false
	Audio.sfx("back")
	_refresh()


func _move(d: int) -> void:
	if _ids.size() <= 1:
		return
	_index = posmod(_index + d, _ids.size())
	Audio.sfx("move")
	_refresh()


func _logo_rect(min_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = min_size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r


func selected_index() -> int:
	return _index


func _refresh() -> void:
	var id: String = _ids[_index]
	var info := Registry.info(id)
	var accent: Color = info.get("color", UI.CYAN)
	for i in _labels.size():
		var sel := i == _index
		var item := _labels[i]
		if item is TextureRect:
			item.custom_minimum_size = LOGO_SELECTED if sel else LOGO_OTHER
		elif item is Label:
			(item as Label).text = ("> %s <" if sel else "%s") % tr(Registry.info(_ids[i]).title_key)
		item.modulate = Color.WHITE if sel else Color(0.45, 0.45, 0.5)
	var best: Array = HighScores.get_table(id)[0]
	_hiscore.text = tr("PICKER_HISCORE") % [best[0], ScoreTable.format_score(int(best[1]))]
	_credits.text = Credits.status_text()
	_bg_title.text = tr(info.title_key)
	UI.set_color(_bg_title, accent)
	_bg_fill.color = accent.darkened(0.85)
	var logo: Texture2D = load(info.logo) if info.has("logo") else null
	_bg_logo.texture = logo
	_bg_title.visible = logo == null
	if info.has("dmd_logo"):
		Dmd.show_image(load(info.dmd_logo))
	else:
		Dmd.show_text(tr(info.title_key), Credits.status_text(), accent, Dmd.DIM)
