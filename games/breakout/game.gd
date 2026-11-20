## Game module: breakout. M0 stub — see docs/GDD.md for the design.
extends "res://games/placeholder_game.gd"


func _init() -> void:
	title_key = "GAME_BREAKOUT_TITLE"
	accent = Color("3ec7ff")


func get_info() -> Dictionary:
	return {"id": "breakout", "title_key": "GAME_BREAKOUT_TITLE", "buttons_min": 3}
