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


func add_table(node: Node) -> Node:
	Screens.table.add_child(node)
	_owned.append(node)
	return node


func add_backglass(node: Node) -> Node:
	Screens.backglass.add_child(node)
	_owned.append(node)
	return node


func _exit_tree() -> void:
	for n in _owned:
		if is_instance_valid(n):
			n.queue_free()
	_owned.clear()
