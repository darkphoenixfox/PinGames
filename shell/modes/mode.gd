## Base for shell modes (picker, attract, game, initials, operator). The shell
## (shell/main.gd) owns exactly one active mode and forwards cabinet actions to it.
## Visuals must be added via add_table / add_backglass so they are freed with the mode.
extends Node

const UI = preload("res://core/ui/ui.gd")
const Registry = preload("res://shell/game_registry.gd")

var shell: Node
var _owned: Array[Node] = []


## Called after the mode is added to the tree.
func enter() -> void:
	pass


func on_action(_action: StringName, _pressed: bool) -> void:
	pass


## Whether the operator-menu button combos are active in this mode.
func allows_operator_combo() -> bool:
	return false


## D-255: a mode built for the 1080x1920 TABLE. On a single screen of another
## shape its nodes go into a 1080x1920 frame, scaled to fit and centred. Modes
## that lay themselves out for any shape set this false.
var portrait_only := true
var _frame: Control


func add_table(node: Node) -> Node:
	var parent: Node = Screens.table
	if portrait_only and Screens.table_base() != Screens.TABLE_BASE:
		if _frame == null:
			_frame = Control.new()
			_frame.size = Vector2(Screens.TABLE_BASE)
			_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Screens.table.add_child(_frame)
			_owned.append(_frame)
			_fit_frame()
			Screens.table_shape_changed.connect(_fit_frame)
		parent = _frame
	parent.add_child(node)
	_owned.append(node)
	return node


func _fit_frame() -> void:
	if _frame == null:
		return
	var b := Vector2(Screens.table_base())
	var s := minf(b.x / 1080.0, b.y / 1920.0)
	_frame.scale = Vector2(s, s)
	_frame.position = (b - Vector2(1080, 1920) * s) * 0.5


func add_backglass(node: Node) -> Node:
	Screens.backglass.add_child(node)
	_owned.append(node)
	return node


func _exit_tree() -> void:
	if _frame != null and Screens.table_shape_changed.is_connected(_fit_frame):
		Screens.table_shape_changed.disconnect(_fit_frame)
	for n in _owned:
		if is_instance_valid(n):
			n.queue_free()
	_owned.clear()
