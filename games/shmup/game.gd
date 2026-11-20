## Game module: shmup. M0 stub — see docs/GDD.md for the design.
extends "res://games/placeholder_game.gd"


func _init() -> void:
	title_key = "GAME_SHMUP_TITLE"
	accent = Color("ff4f6d")


func get_info() -> Dictionary:
	return {"id": "shmup", "title_key": "GAME_SHMUP_TITLE", "buttons_min": 3}
