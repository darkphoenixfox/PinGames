## Button-driven list menu for the TABLE screen (operator menu and similar).
## Navigation: flippers / magna saves move the cursor, Launch/Start activates,
## Exit goes back. On a "choice" item, Launch enters edit mode, where flippers
## change the value and Launch/Exit leaves edit mode.
##
## Items are Dictionaries:
##   {key: <translation key>, type: "submenu"|"action", run: Callable, getter?: Callable}
##   {key: <translation key>, type: "choice", options: Array, labels?: Array[String],
##    getter: Callable, setter: Callable}
##   {key: <translation key>, type: "info", getter: Callable}
## `key` is a translation key; labels are already-translated strings.
extends Control

const UI = preload("res://core/ui/ui.gd")

signal back_requested

var title_key := ""
var items: Array = []
var index := 0
var editing := false

var _title: Label
var _hint: Label
var _rows: Array = []  # [name_label, value_label]


func setup(p_title_key: String, p_items: Array) -> Control:
	title_key = p_title_key
	items = p_items
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 90)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	margin.add_child(col)
	_title = UI.label("", 72, UI.YELLOW)
	col.add_child(_title)
	col.add_child(UI.spacer(40))
	for it in items:
		var row := HBoxContainer.new()
		var name_l := UI.label("", 48, UI.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		var value_l := UI.label("", 48, UI.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(name_l)
		row.add_child(value_l)
		col.add_child(row)
		_rows.append([name_l, value_l])
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(filler)
	_hint = UI.label("", 34, UI.GREY)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	refresh()


func refresh() -> void:
	if _title == null:
		return
	_title.text = tr(title_key)
	for i in items.size():
		var it: Dictionary = items[i]
		var name_l: Label = _rows[i][0]
		var value_l: Label = _rows[i][1]
		var selected := i == index
		name_l.text = ("> " if selected else "  ") + tr(it.key)
		value_l.text = _value_text(it, selected and editing)
		var col := UI.CYAN if selected else (UI.GREY if it.get("type") == "info" else UI.WHITE)
		UI.set_color(name_l, col)
		UI.set_color(value_l, UI.YELLOW if (selected and editing) else col)
	_hint.text = tr("MENU_HINT_EDIT") if editing else tr("MENU_HINT")


func _value_text(it: Dictionary, edit: bool) -> String:
	var t := ""
	match it.get("type", "action"):
		"choice":
			var opts: Array = it.options
			var v: Variant = it.getter.call()
			var i := opts.find(v)
			if i == -1:
				i = opts.find(str(v))
			var labels: Array = it.get("labels", [])
			t = str(labels[i]) if (i >= 0 and i < labels.size()) else str(v)
			if edit:
				t = "< %s >" % t
		"submenu":
			t = ">"
		_:
			if it.has("getter"):
				t = str(it.getter.call())
	return t


func handle(action: StringName) -> void:
	if items.is_empty():
		if action == &"exit":
			back_requested.emit()
		return
	var it: Dictionary = items[index]
	if editing:
		match action:
			&"flip_l", &"magna_l":
				_cycle(it, -1)
			&"flip_r", &"magna_r":
				_cycle(it, 1)
			&"launch", &"start", &"exit":
				editing = false
				Audio.sfx("select")
		refresh()
		return
	match action:
		&"flip_l", &"magna_l":
			index = posmod(index - 1, items.size())
			Audio.sfx("move")
		&"flip_r", &"magna_r":
			index = posmod(index + 1, items.size())
			Audio.sfx("move")
		&"launch", &"start":
			match it.get("type", "action"):
				"choice":
					editing = true
					Audio.sfx("select")
				"action", "submenu":
					Audio.sfx("select")
					it.run.call()
		&"exit":
			Audio.sfx("back")
			back_requested.emit()
			return
	refresh()


func _cycle(it: Dictionary, d: int) -> void:
	var opts: Array = it.options
	var v: Variant = it.getter.call()
	var i := opts.find(v)
	if i == -1:
		i = opts.find(str(v))
	i = posmod(i + d, opts.size())
	it.setter.call(opts[i])
	Audio.sfx("move")
