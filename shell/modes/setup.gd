## First-run controls setup (D-379): asks for each cabinet button in turn and
## stores what was pressed. Shown once, before the first menu, and again from
## the operator menu (CONTROLS > RUN SETUP AGAIN).
## Pages: intro -> one page per button -> (magna saves skipped: a note) -> done.
## It reads raw presses through CabinetInput's capture, so it works before any
## binding is right. Nothing is stored until the last page is confirmed.
extends "res://shell/modes/mode.gd"

const Bindings = preload("res://core/util/bindings.gd")

## The buttons asked for, in order. START is stored as the launch action:
## every screen accepts LAUNCH wherever it accepts START, so one button does
## both jobs (director: the two are redundant).
const STEPS := [
	{"action": &"flip_l", "name": "ACTION_FLIP_L", "hint": "SETUP_HINT_FLIP_L", "required": true},
	{"action": &"flip_r", "name": "ACTION_FLIP_R", "hint": "SETUP_HINT_FLIP_R", "required": true},
	{"action": &"launch", "name": "ACTION_START", "hint": "SETUP_HINT_START", "required": true},
	{"action": &"magna_l", "name": "ACTION_MAGNA_L", "hint": "SETUP_HINT_MAGNA_L", "required": false},
	{"action": &"magna_r", "name": "ACTION_MAGNA_R", "hint": "SETUP_HINT_MAGNA_R", "required": false},
	{"action": &"exit", "name": "ACTION_EXIT", "hint": "SETUP_HINT_EXIT", "required": true},
]
const SKIP := "key:Escape"
const COOLDOWN := 0.35     # s before a stick or trigger counts again (held, it repeats)

var from_operator := false
## The single-screen layout gives gamepads a fixed layout (D-256), so there
## only keys can be set, and a pad press on the first page skips the setup.
var fixed_pad := false
var stage := "intro"       # intro | step | magna | done
var step := 0
var picked := {}           # action -> binding
var skipped: Array[StringName] = []
var pad_only := false
var _note := ""            # translated message under the prompt
var _cool := 0.0
var _last := ""
var _closed := false
var _title: Label
var _progress: Label
var _body: Label
var _name: Label
var _hint: Label
var _tag: Label
var _msg: Label
var _footer: Label


func _init(p_from_operator: bool = false) -> void:
	from_operator = p_from_operator


## Whether the first-run setup should show at startup.
static func wanted() -> bool:
	if bool(Config.get_value("operator", "setup_done")) or Screens.is_headless():
		return false
	for flag in ["press", "screenshot", "mode", "skip-setup"]:   # automated runs
		if Config.cli.has(flag):
			return false
	if Config.layout() == "vr":
		return false
	# Touch-only devices have no keys or buttons to set.
	var touch := (OS.has_feature("android") or OS.has_feature("web")) and DisplayServer.is_touchscreen_available()
	return not touch or not Input.get_connected_joypads().is_empty()


func enter() -> void:
	portrait_only = false   # D-255: a centred column fits any TABLE shape
	fixed_pad = Config.layout() == "single"
	add_table(UI.fill(Color(0.03, 0.05, 0.1)))
	add_backglass(UI.fill(Color(0.03, 0.05, 0.1)))
	var bg := UI.label(tr("SETUP_TITLE"), 150, UI.YELLOW)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_backglass(bg)
	var col := UI.vstack(36)
	col.offset_left = 72
	col.offset_right = -72
	add_table(col)
	_title = UI.label(tr("SETUP_TITLE"), 84, UI.YELLOW)
	_progress = UI.label("", 36, UI.GREY)
	_body = UI.label("", 48, UI.WHITE)
	_name = UI.label("", 96, UI.CYAN)
	_hint = UI.label("", 36, UI.WHITE)
	_tag = UI.label("", 36, UI.GREY)
	_msg = UI.label("", 36, UI.YELLOW)
	_footer = UI.label("", 48, UI.YELLOW)
	for l in [_title, _progress, _body, _name, _hint, _tag, _msg, _footer]:
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	Audio.sfx("select")
	_refresh()
	CabinetInput.capture_next(_on_input)


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if _footer != null:
		_footer.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.7 else 0.35


func _exit_tree() -> void:
	if not _closed:
		CabinetInput.cancel_capture()
	super()


func _on_input(binding: String) -> void:
	# A stick held over keeps sending the same press: take each one once.
	var axis := binding.begins_with("axis:")
	if not (axis and (_cool > 0.0 or binding == _last)):
		_cool = COOLDOWN
		_last = binding
		feed(binding)
	if not _closed:
		CabinetInput.capture_next(_on_input)


## One press (a binding string). Returns true once the last page is confirmed.
func feed(binding: String) -> bool:
	_note = ""
	match stage:
		"intro":
			if fixed_pad and Bindings.kind(binding) == "joy":
				pad_only = true
				stage = "done"
			else:
				stage = "step"
				step = 0
		"step":
			var s: Dictionary = STEPS[step]
			if binding == SKIP:
				if s.required:
					_note = tr("SETUP_REQUIRED")
				else:
					skipped.append(s.action)
					_next_step()
			elif fixed_pad and Bindings.kind(binding) == "joy":
				_note = tr("SETUP_USE_KEYS")
			elif binding in picked.values():
				_note = tr("SETUP_USED").replace("%s", Bindings.describe(binding))
			else:
				picked[s.action] = binding
				_next_step()
		"magna":
			stage = "done"
		"done":
			_finish()
			return true
	if _title != null:
		Audio.sfx("error" if not _note.is_empty() else "select")
	_refresh()
	return false


func _next_step() -> void:
	step += 1
	if step >= STEPS.size():
		stage = "magna" if (&"magna_l" in skipped or &"magna_r" in skipped) else "done"


func _finish() -> void:
	_closed = true
	if shell == null:
		return   # (tests drive the pages without a shell)
	for action in picked:
		CabinetInput.set_binding(action, str(picked[action]))
	Config.set_value("operator", "setup_done", true)
	Config.save()
	CabinetInput.cancel_capture()
	CabinetInput.mute_until_release()
	Audio.sfx("start")
	if from_operator:
		shell.open_operator()
	else:
		shell.setup_finished()


func _refresh() -> void:
	if _title == null:
		return
	for l in [_progress, _name, _hint, _tag]:
		(l as Label).text = ""
	_msg.text = _note
	match stage:
		"intro":
			_body.text = tr("SETUP_INTRO_AGAIN" if from_operator else "SETUP_INTRO")
			_hint.text = tr("SETUP_PAD_NOTE") if fixed_pad else ""
			_footer.text = tr("SETUP_CONTINUE")
			Dmd.show_text(tr("SETUP_DMD"), tr("SETUP_DMD_ANY"), Dmd.YELLOW, Dmd.WHITE)
		"step":
			var s: Dictionary = STEPS[step]
			_progress.text = tr("SETUP_STEP") % [step + 1, STEPS.size()]
			_body.text = tr("SETUP_PRESS")
			_name.text = tr(s.name)
			_hint.text = tr(s.hint)
			_tag.text = tr("SETUP_TAG_REQUIRED" if s.required else "SETUP_TAG_OPTIONAL")
			_footer.text = ""
			Dmd.show_text(tr(s.name), tr("SETUP_DMD_PRESS" if s.required else "SETUP_DMD_SKIP"), Dmd.YELLOW, Dmd.WHITE)
		"magna":
			_body.text = tr("SETUP_NO_MAGNA")
			_footer.text = tr("SETUP_CONTINUE")
			Dmd.show_text(tr("SETUP_DMD"), tr("SETUP_DMD_ANY"), Dmd.YELLOW, Dmd.WHITE)
		"done":
			_body.text = tr("SETUP_OPERATOR")
			_hint.text = tr("SETUP_PAD_DONE") if pad_only else ""
			_footer.text = tr("SETUP_START")
			Dmd.show_text(tr("SETUP_DMD_DONE"), tr("SETUP_DMD_ANY"), Dmd.GREEN, Dmd.WHITE)
