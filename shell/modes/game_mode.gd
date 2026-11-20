## Runs one game module. Exit aborts the game (no high-score entry); when the module
## emits `finished`, the shell checks for a high score.
extends "res://shell/modes/mode.gd"

var game_id := ""
var module: Node


func _init(p_game_id: String) -> void:
	game_id = p_game_id


func enter() -> void:
	module = Registry.instantiate(game_id)
	module.name = "Game_" + game_id
	add_child(module)
	module.finished.connect(_on_finished)
	Audio.sfx("start")
	Audio.stop_music(0.6)  # games start their own music
	module.start(1)
	print("Shell: started game '%s'" % game_id)


func on_action(action: StringName, pressed: bool) -> void:
	if action == &"exit" and pressed:
		shell.abort_game()
		return
	module.on_action(action, pressed)


func _on_finished(scores: Array) -> void:
	var best := 0
	for s in scores:
		best = maxi(best, int(s))
	shell.call_deferred("game_finished", game_id, best)
