## Operator (service) menu, opened with Start+Exit held 3 s or Exit held 5 s on the
## picker/attract (D-024). Fully button-driven: no keyboard or mouse needed.
## Settings are written to Config as they change and saved on leaving.
## Display changes are applied with a keep/revert countdown so a wrong monitor
## choice can never leave the cabinet unusable.
extends "res://shell/modes/mode.gd"

const Menu = preload("res://core/ui/menu.gd")
const Bindings = preload("res://core/util/bindings.gd")

const CONFIRM_SECONDS := 15.0
const CAPTURE_SECONDS := 6.0
const DISPLAY_KEYS := ["layout", "windowed_monitor", "table_monitor", "table_rotation",
	"backglass_monitor", "backglass_rotation", "dmd_sink", "dmd_monitor", "dmd_rotation",
	"render_scale"]

var _stack: Array[Control] = []
var _overlay: Control
var _overlay_label: Label
# Display apply/confirm state
var _pending_display := {}
var _revert_display := {}
var _confirm_left := 0.0
# Remap capture state
var _capture_action := StringName()
var _capture_left := 0.0
# Two-step confirmation for destructive actions
var _armed_reset := ""


func enter() -> void:
	add_table(UI.fill(Color(0.03, 0.05, 0.1)))
	add_backglass(UI.fill(Color(0.03, 0.05, 0.1)))
	var bg := UI.label(tr("OP_TITLE"), 150, UI.YELLOW)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_backglass(bg)
	Dmd.show_text(tr("OP_TITLE"), tr("OP_DMD_HINT"), Dmd.YELLOW, Dmd.DIM)
	Audio.sfx("select")
	_push("OP_TITLE", _main_items())


func on_action(action: StringName, pressed: bool) -> void:
	if not pressed:
		return
	if action == &"back":
		action = &"exit"   # D-260: BACK steps back like EXIT does here
	if _confirm_left > 0.0:
		match action:
			&"launch", &"start":
				_keep_display()
			&"exit":
				_revert_display_now()
		return
	if _capture_left > 0.0:
		return
	_stack.back().handle(action)


func _process(delta: float) -> void:
	if _confirm_left > 0.0:
		_confirm_left -= delta
		_overlay_label.text = tr("OP_DISPLAY_CONFIRM") % ceili(_confirm_left)
		if _confirm_left <= 0.0:
			_revert_display_now()
	elif _capture_left > 0.0:
		_capture_left -= delta
		_overlay_label.text = tr("OP_REMAP_PRESS") % [tr(_action_key(_capture_action)), ceili(_capture_left)]
		if _capture_left <= 0.0:
			CabinetInput.cancel_capture()
			CabinetInput.mute_until_release()
			_hide_overlay()
			Audio.sfx("error")


# --- menu stack --------------------------------------------------------------------
func _push(title_key: String, items: Array) -> void:
	if not _stack.is_empty():
		_stack.back().visible = false
	var m: Control = Menu.new().setup(title_key, items)
	m.back_requested.connect(_pop)
	add_table(m)
	_stack.append(m)


func _pop() -> void:
	_armed_reset = ""
	if _stack.size() <= 1:
		_leave()
		return
	var m: Control = _stack.pop_back()
	m.queue_free()
	_stack.back().visible = true
	_stack.back().refresh()


func _refresh_all() -> void:
	for m in _stack:
		m.refresh()


func _leave() -> void:
	Config.save()
	Audio.apply_volumes()
	shell.goto_picker()


# --- item builders -----------------------------------------------------------------
func _submenu(key: String, builder: Callable) -> Dictionary:
	return {"key": key, "type": "submenu", "run": func(): _push(key, builder.call())}


func _action(key: String, run: Callable, getter: Variant = null) -> Dictionary:
	var d := {"key": key, "type": "action", "run": run}
	if getter != null:
		d["getter"] = getter
	return d


func _cfg_choice(key: String, section: String, setting: String, options: Array,
		labels: Array = [], on_change: Variant = null) -> Dictionary:
	return {"key": key, "type": "choice", "options": options, "labels": labels,
		"getter": func(): return Config.get_value(section, setting),
		"setter": func(v):
			Config.set_value(section, setting, v)
			if on_change != null:
				(on_change as Callable).call(v)}


func _info(key: String, getter: Callable) -> Dictionary:
	return {"key": key, "type": "info", "getter": getter}


func _on_off() -> Array:
	return [tr("VAL_ON"), tr("VAL_OFF")]


# --- pages ----------------------------------------------------------------------------
func _main_items() -> Array:
	return [
		_submenu("OP_DISPLAY", _display_items),
		_submenu("OP_CONTROLS", _controls_items),
		_submenu("OP_GAMEPLAY", _gameplay_items),
		_submenu("OP_AUDIO", _audio_items),
		_submenu("OP_LANGUAGE", _language_items),
		_submenu("OP_SCORES", _scores_items),
		_submenu("OP_INFO", _info_items),
		_action("OP_SAVE_EXIT", _leave),
	]


func _display_items() -> Array:
	_pending_display.clear()
	for k in DISPLAY_KEYS:
		_pending_display[k] = Config.get_value("display", k)
	var mons: Array = range(Screens.monitor_count())
	var mon_labels: Array = mons.map(func(i):
		var s: Vector2i = Screens.monitor_size(i)
		return "%d  (%dx%d)" % [i + 1, s.x, s.y])
	var rot := [0, 90, 180, 270]
	var rot_labels := ["0", "90", "180", "270"]
	return [
		_pending("OP_LAYOUT", "layout", ["windowed", "2screen", "3screen", "single"],
			[tr("LAYOUT_WINDOWED"), tr("LAYOUT_2SCREEN"), tr("LAYOUT_3SCREEN"), tr("LAYOUT_SINGLE")]),
		_pending("OP_TABLE_MONITOR", "table_monitor", mons, mon_labels),
		_pending("OP_TABLE_ROTATION", "table_rotation", [-1] + rot, [tr("VAL_AUTO")] + rot_labels),
		_pending("OP_BACKGLASS_MONITOR", "backglass_monitor", mons, mon_labels),
		_pending("OP_BACKGLASS_ROTATION", "backglass_rotation", rot, rot_labels),
		_pending("OP_DMD_OUTPUT", "dmd_sink", ["window", "backglass", "hardware"],
			[tr("SINK_WINDOW"), tr("SINK_BACKGLASS"), tr("SINK_HARDWARE")]),
		_pending("OP_DMD_MONITOR", "dmd_monitor", mons, mon_labels),
		_pending("OP_DMD_ROTATION", "dmd_rotation", rot, rot_labels),
		_pending("OP_WINDOWED_MONITOR", "windowed_monitor", mons, mon_labels),
		_pending("OP_RENDER_SCALE", "render_scale", ["auto", "0.5", "0.75", "1.0", "1.5", "2.0"],
			[tr("VAL_AUTO"), "0.5x", "0.75x", "1x", "1.5x", "2x"]),
		_action("OP_IDENTIFY", func(): Screens.identify_monitors(4.0)),
		_action("OP_APPLY", _apply_display),
	]


func _pending(key: String, setting: String, options: Array, labels: Array) -> Dictionary:
	return {"key": key, "type": "choice", "options": options, "labels": labels,
		"getter": func(): return _pending_display[setting],
		"setter": func(v): _pending_display[setting] = v}


func _controls_items() -> Array:
	var items: Array = []
	for a in CabinetInput.ACTIONS:
		var action: StringName = a
		items.append(_action(_action_key(action), func(): _start_capture(action),
			func(): return CabinetInput.describe_bindings(action)))
	items.append(_action("OP_RESET_CONTROLS", func():
		CabinetInput.reset_bindings()
		Dmd.flash(tr("DMD_DONE"))
		_refresh_all()))
	return items


func _gameplay_items() -> Array:
	return [
		_cfg_choice("OP_FREE_PLAY", "operator", "free_play", [true, false], _on_off(),
			func(_v): Credits.changed.emit()),
		_cfg_choice("OP_BALLS", "operator", "balls_per_game", [1, 2, 3, 4, 5]),
		_cfg_choice("OP_CABINET_BUTTONS", "operator", "cabinet_buttons", ["auto", "2", "4"],
			[tr("VAL_AUTO"), "2 + 1", "4 + 1"]),
		_cfg_choice("OP_ATTRACT_DELAY", "operator", "attract_delay", [30, 60, 120, 300],
			["30 s", "60 s", "120 s", "300 s"]),
		_cfg_choice("OP_DMD_STYLE", "dmd", "mono", [false, true],
			[tr("VAL_DMD_COLOR"), tr("VAL_DMD_MONO")], func(v): _set_dmd_mono(v)),
	]


func _audio_items() -> Array:
	var vols: Array = range(11)
	var apply := func(_v):
		Audio.apply_volumes()
	return [
		_cfg_choice("OP_VOLUME_MASTER", "operator", "volume_master", vols, [], apply),
		_cfg_choice("OP_VOLUME_MUSIC", "operator", "volume_music", vols, [], apply),
		_cfg_choice("OP_VOLUME_SFX", "operator", "volume_sfx", vols, [], apply),
		_cfg_choice("OP_ATTRACT_SOUNDS", "operator", "attract_sounds", [true, false], _on_off()),
	]


func _language_items() -> Array:
	var locales: Array = Array(I18n.available_locales())
	if locales.is_empty():
		locales = ["en"]
	var labels: Array = locales.map(func(l): return TranslationServer.get_locale_name(l).to_upper())
	return [
		_cfg_choice("OP_LANGUAGE", "operator", "language", locales, labels, func(v):
			TranslationServer.set_locale(v)
			_refresh_all()),
	]


func _scores_items() -> Array:
	# D-224: ALL GAMES first, showing RESET like the others (press twice).
	var items: Array = [_action("OP_RESET_ALL_SCORES", func(): _reset_scores("*"),
		func(): return tr("OP_PRESS_AGAIN") if _armed_reset == "*" else tr("OP_RESET"))]
	for id in Registry.ids():
		var gid: String = id
		items.append(_action(Registry.info(gid).title_key, func(): _reset_scores(gid),
			func(): return tr("OP_PRESS_AGAIN") if _armed_reset == gid else tr("OP_RESET")))
	return items


func _info_items() -> Array:
	var v := Engine.get_version_info()
	return [
		_info("INFO_ENGINE", func(): return "Godot %s" % v.string),
		_info("INFO_LAYOUT", func(): return Screens.current_layout),
		_info("INFO_MONITORS", func(): return str(Screens.monitor_count())),
		_info("INFO_TABLE_RES", func(): return "%dx%d" % [Screens.table.size.x, Screens.table.size.y]),
		_info("INFO_DMD", func(): return "%dx%d" % [Dmd.size.x, Dmd.size.y]),
		_info("INFO_CONFIG", func(): return ProjectSettings.globalize_path("user://")),
		_info("INFO_KEYS_CHECK", func():
			var w: Array = load("res://core/system_checks.gd").warnings()
			return tr("VAL_OK") if w.is_empty() else ", ".join(w.map(func(k): return tr(k)))),
	]


# --- actions -------------------------------------------------------------------------
func _reset_scores(id: String) -> void:
	if _armed_reset != id:
		_armed_reset = id
		Audio.sfx("error")
		return
	_armed_reset = ""
	HighScores.reset("" if id == "*" else id)
	Dmd.flash(tr("DMD_DONE"))


func _set_dmd_mono(v: bool) -> void:
	Dmd.mono = v
	Screens.setup(Screens.current_layout)  # rebuild DMD views with the new shader setting


func _apply_display() -> void:
	_revert_display.clear()
	for k in DISPLAY_KEYS:
		_revert_display[k] = Config.get_value("display", k)
		Config.set_value("display", k, _pending_display[k])
	Screens.setup(Config.layout())
	_confirm_left = CONFIRM_SECONDS
	_show_overlay()


func _keep_display() -> void:
	_confirm_left = 0.0
	_hide_overlay()
	Config.save()
	Audio.sfx("select")
	Dmd.flash(tr("DMD_SAVED"))


func _revert_display_now() -> void:
	_confirm_left = 0.0
	for k in _revert_display:
		Config.set_value("display", k, _revert_display[k])
		_pending_display[k] = _revert_display[k]
	Screens.setup(Config.layout())
	_hide_overlay()
	Audio.sfx("back")
	_refresh_all()


func _start_capture(action: StringName) -> void:
	_capture_action = action
	_capture_left = CAPTURE_SECONDS
	_show_overlay()
	CabinetInput.capture_next(func(binding: String):
		_capture_left = 0.0
		_hide_overlay()
		CabinetInput.set_binding(_capture_action, binding)
		Audio.sfx("select")
		Dmd.flash(Bindings.describe(binding), 1.2)
		_refresh_all())


static func _action_key(action: StringName) -> String:
	return "ACTION_" + String(action).to_upper()


# --- overlay --------------------------------------------------------------------------
func _show_overlay() -> void:
	if _overlay == null:
		_overlay = add_table(UI.fill(Color(0, 0, 0, 0.85))) as Control
		_overlay_label = UI.label("", 64, UI.YELLOW)
		_overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_overlay.add_child(_overlay_label)
	_overlay.move_to_front()
	_overlay.visible = true


func _hide_overlay() -> void:
	if _overlay:
		_overlay.visible = false
