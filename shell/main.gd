## Shell: boots the screens and runs exactly one mode at a time:
##   picker <-> attract, picker -> game -> (initials) -> picker, picker/attract -> operator
## `--game=<id>` launches a game directly; the picker is then locked to that game.
## Quitting the app always needs a confirmation (D-003, D-028, D-031).
## Coin is handled globally. Operator menu combos are checked here (D-024).
extends Node

const Registry = preload("res://shell/game_registry.gd")
const Picker = preload("res://shell/modes/picker.gd")
const Attract = preload("res://shell/modes/attract.gd")
const GameMode = preload("res://shell/modes/game_mode.gd")
const Initials = preload("res://shell/modes/initials.gd")
const Operator = preload("res://shell/modes/operator.gd")
const Viewer = preload("res://shell/modes/viewer.gd")
const Dev = preload("res://shell/dev.gd")
const FocusPause = preload("res://shell/focus_pause.gd")

const COMBO_SECONDS := 3.0
const EXIT_HOLD_SECONDS := 5.0

var mode: Node
var direct_game := ""
var _picker_index := 0


func _ready() -> void:
	Screens.setup(Config.layout())
	CabinetInput.action_pressed.connect(_on_pressed)
	CabinetInput.action_released.connect(_on_released)
	add_child(Dev.new())
	if FocusPause.wanted():
		add_child(FocusPause.new())   # browser: stop while the page has no focus (D-178)
	# D-272: the installed web app applies a new version by itself: the page
	# otherwise keeps running the cached one until every tab is closed.
	if OS.has_feature("web"):
		JavaScriptBridge.pwa_update_available.connect(_on_pwa_update)
		if JavaScriptBridge.pwa_needs_update():
			_on_pwa_update()

	var requested := Config.requested_game()
	if not requested.is_empty():
		if not Registry.has(requested):
			push_error("Unknown game '%s'" % requested)
			get_tree().quit(2)
			return
		direct_game = requested
		start_game(requested)
		return
	match str(Config.cli.get("mode", "")):
		"operator":
			open_operator()
		"attract":
			goto_attract()
		"viewer":
			switch_to(Viewer.new(str(Config.cli.get("model", ""))))
		"initials":
			switch_to(Initials.new(Registry.ids()[0], 123456))
		_:
			goto_picker()


func switch_to(new_mode: Node) -> void:
	var first := mode == null
	if mode != null:
		if mode.has_method("selected_index"):
			_picker_index = mode.selected_index()
		mode.queue_free()
	mode = new_mode
	mode.shell = self
	add_child(mode)
	mode.enter()
	if not first:
		_fade_in()


## D-278: every change of screen (menu, game, initials, operator) comes up
## from black instead of popping in: a black cover over the TABLE and the
## BACKGLASS fades away. The new screen is already live under it, so input and
## timing are unchanged, and its first frames (the slowest) are out of sight.
const FADE_IN := 0.3
var _covers: Array[ColorRect] = []


func _fade_in() -> void:
	for c in _covers:
		if is_instance_valid(c):
			c.queue_free()
	_covers.clear()
	if Screens.is_headless():
		return
	for vp in [Screens.table, Screens.backglass]:
		var c := ColorRect.new()
		c.color = Color.BLACK
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.z_index = 200   # over a mode's own overlays (loading 100, quit box 120)
		vp.add_child(c)
		_covers.append(c)
		var tw := c.create_tween()
		tw.tween_property(c, "modulate:a", 0.0, FADE_IN)
		tw.tween_callback(c.queue_free)


func _on_pressed(action: StringName) -> void:
	if action == &"coin":
		Credits.add_coin()
		Audio.sfx("coin")
		Dmd.flash(Credits.status_text(), 1.2, Dmd.GREEN)
		return
	if mode:
		mode.on_action(action, true)


func _on_released(action: StringName) -> void:
	if mode:
		mode.on_action(action, false)


func _process(_delta: float) -> void:
	if mode == null or not mode.allows_operator_combo():
		return
	var combo := CabinetInput.held_time(&"start") >= COMBO_SECONDS \
		and CabinetInput.held_time(&"exit") >= COMBO_SECONDS
	if combo or CabinetInput.held_time(&"exit") >= EXIT_HOLD_SECONDS:
		open_operator()


# --- transitions -------------------------------------------------------------------
var _pwa_pending := false


## Updates now unless a game is running; then at the next menu (D-272).
func _on_pwa_update() -> void:
	_pwa_pending = true
	if mode == null or not (mode is GameMode):
		print("Shell: new web version, reloading")
		JavaScriptBridge.pwa_update()


func goto_picker() -> void:
	if _pwa_pending:
		JavaScriptBridge.pwa_update()
		return
	switch_to(Picker.new(direct_game, _picker_index))


func goto_attract() -> void:
	switch_to(Attract.new())


func open_operator() -> void:
	CabinetInput.mute_until_release()
	switch_to(Operator.new())


func start_game(id: String) -> bool:
	if not Credits.try_start():
		Audio.sfx("error")
		Dmd.flash(tr("DMD_INSERT_COIN"), 1.5, Dmd.RED)
		return false
	CabinetInput.mute_until_release()
	switch_to(GameMode.new(id))
	return true


## Player pressed Exit during a game. With --game, go to the locked picker with
## the quit confirmation already open (D-031).
func abort_game() -> void:
	CabinetInput.mute_until_release()
	if not direct_game.is_empty():
		switch_to(Picker.new(direct_game, 0, true))
		return
	goto_picker()


## Called by GameMode when the module reports game over.
func game_finished(id: String, best_score: int) -> void:
	CabinetInput.mute_until_release()
	if HighScores.qualifies(id, best_score):
		switch_to(Initials.new(id, best_score))
	else:
		Dmd.flash(tr("DMD_GAME_OVER"), 2.0, Dmd.RED)
		return_to_game(id)


## D-277: after a game (and its initials), back to that game's own PRESS START
## screen, not the game picker. Its START plays straight away, so the next
## game's credit is taken here; with none left, the picker (INSERT COIN).
func return_to_game(id: String) -> void:
	CabinetInput.mute_until_release()
	if not Credits.can_start():
		goto_picker()
		return
	Credits.try_start()
	switch_to(GameMode.new(id))
