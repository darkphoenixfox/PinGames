## Base script for every game module (D-010). A game lives in games/<id>/game.gd and
## extends this file by path:   extends "res://core/game_module.gd"
## (no class_name: keeps the project runnable without an editor-built class cache).
##
## Lifecycle: the shell instantiates the module, adds it to the tree, calls start(),
## forwards logical cabinet actions to on_action(), and frees it on exit/finish.
## Visual nodes must be added through add_to_table / add_to_backglass so they are
## cleaned up automatically.
extends Node

signal score_changed(player: int, score: int)
## Emitted when the game is over; scores is an Array of ints, one per player.
signal finished(scores: Array)

var _owned: Array[Node] = []


## Metadata used by the picker. Override.
func get_info() -> Dictionary:
	return {"id": "", "title_key": "", "buttons_min": 3}


## Called once after the module enters the tree. Override.
func start(_players: int) -> void:
	pass


## Logical cabinet actions (see core/cabinet_input.gd). Override.
func on_action(_action: StringName, _pressed: bool) -> void:
	pass


func add_to_table(node: Node) -> Node:
	return _own(Screens.table, node)


func add_to_backglass(node: Node) -> Node:
	return _own(Screens.backglass, node)


func _own(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	_owned.append(node)
	return node


func _exit_tree() -> void:
	for n in _owned:
		if is_instance_valid(n):
			n.queue_free()
	_owned.clear()
