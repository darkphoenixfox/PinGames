## Shell: boots the screens, shows the game picker (attract placeholder) and runs
## game modules. `--game=<id>` launches a game directly; Exit then quits the app,
## so cabinet frontends (PinUP Popper, PinballX) get control back (D-003).
extends Node

## Order shown in the picker. id -> module script.
const GAMES := [
	["breakout", "res://games/breakout/game.gd"],
	["shmup", "res://games/shmup/game.gd"],
	["racer", "res://games/racer/game.gd"],
]

var _game: Node
var _direct_launch := false
var _picker_index := 0
var _picker_root: Control
var _picker_labels: Array[Label] = []
var _backglass_root: Control


func _ready() -> void:
	Screens.setup(Config.layout())
	CabinetInput.action_pressed.connect(_on_action.bind(true))
	CabinetInput.action_released.connect(_on_action.bind(false))
	if Config.cli.has("screenshot"):
		_capture_and_quit(str(Config.cli["screenshot"]))
	var requested := Config.requested_game()
	if not requested.is_empty():
		_direct_launch = true
		if not start_game(requested):
			push_error("Unknown game '%s'" % requested)
			get_tree().quit(2)
		return
	show_picker()


func _on_action(action: StringName, pressed: bool) -> void:
	if _game != null:
		if action == &"exit" and pressed:
			end_game()
		else:
			_game.on_action(action, pressed)
		return
	if not pressed:
		return
	match action:
		&"flip_l", &"magna_l":
			_select(_picker_index - 1)
		&"flip_r", &"magna_r":
			_select(_picker_index + 1)
		&"launch", &"start":
			start_game(GAMES[_picker_index][0])
		&"exit":
			get_tree().quit()


# --- picker ---------------------------------------------------------------------
func show_picker() -> void:
	_picker_root = VBoxContainer.new()
	_picker_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_picker_root as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	_picker_root.add_theme_constant_override("separation", 48)
	Screens.table.add_child(_picker_root)
	_picker_root.add_child(_label(tr("APP_TITLE"), 120, Color("ffd23e")))
	_picker_root.add_child(_label(tr("PICKER_TITLE"), 64, Color.WHITE))
	_picker_labels.clear()
	for g in GAMES:
		var probe: Node = load(g[1]).new()
		var info: Dictionary = probe.get_info()
		probe.free()
		var l := _label(tr(info.title_key), 72, Color.WHITE)
		_picker_root.add_child(l)
		_picker_labels.append(l)
	_picker_root.add_child(_label(tr("PICKER_HINT"), 40, Color(0.7, 0.7, 0.7)))

	_backglass_root = _label(tr("APP_TITLE"), 220, Color("ffd23e"))
	_backglass_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_backglass_root as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Screens.backglass.add_child(_backglass_root)

	var credit_key := "DMD_FREE_PLAY" if Config.get_value("operator", "free_play") else "DMD_INSERT_COIN"
	Dmd.show_text(tr("APP_TITLE"), tr(credit_key))
	_select(_picker_index)


func hide_picker() -> void:
	if _picker_root:
		_picker_root.queue_free()
		_picker_root = null
	if _backglass_root:
		_backglass_root.queue_free()
		_backglass_root = null
	_picker_labels.clear()


func _select(i: int) -> void:
	_picker_index = posmod(i, GAMES.size())
	for j in _picker_labels.size():
		var on := j == _picker_index
		_picker_labels[j].add_theme_color_override("font_color", Color("3ec7ff") if on else Color(0.5, 0.5, 0.5))
		_picker_labels[j].scale = Vector2.ONE


# --- game lifecycle -------------------------------------------------------------
func start_game(id: String) -> bool:
	for g in GAMES:
		if g[0] == id:
			hide_picker()
			_game = load(g[1]).new()
			_game.name = "Game_" + id
			add_child(_game)
			_game.finished.connect(func(_scores): end_game())
			_game.start(1)
			print("Shell: started game '%s'" % id)
			return true
	return false


func end_game() -> void:
	if _game:
		_game.queue_free()
		_game = null
	if _direct_launch:
		get_tree().quit()
	else:
		show_picker()


## Dev aid (--screenshot=<dir>): after a short warm-up, saves TABLE, BACKGLASS, DMD
## content and the TABLE window as PNGs, then quits. Lets sessions verify visuals.
func _capture_and_quit(dir: String) -> void:
	for i in 30:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(dir)
	Screens.table.get_texture().get_image().save_png(dir.path_join("table.png"))
	Screens.backglass.get_texture().get_image().save_png(dir.path_join("backglass.png"))
	Dmd.texture().get_image().save_png(dir.path_join("dmd.png"))
	get_viewport().get_texture().get_image().save_png(dir.path_join("window_table.png"))
	print("Shell: screenshots saved to %s" % dir)
	get_tree().quit()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
