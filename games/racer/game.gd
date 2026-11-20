## Game module: racer. M0 stub — see docs/GDD.md for the design.
extends "res://games/placeholder_game.gd"


func _init() -> void:
	title_key = "GAME_RACER_TITLE"
	accent = Color("ffd23e")


func get_info() -> Dictionary:
	return {"id": "racer", "title_key": "GAME_RACER_TITLE", "buttons_min": 3}
