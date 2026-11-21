## Game module: racer. Stub — see docs/GDD.md for the design.
extends "res://games/placeholder_game.gd"

## Director's pick: "8-bit Music Pack (Loopable)" by CodeManu, CC BY 3.0 (D-033).
const MUSIC := {
	"menu": "res://assets/audio/music/racer/codemanu_menu.ogg",
	"race": [
		"res://assets/audio/music/racer/codemanu_action_1.ogg",
		"res://assets/audio/music/racer/codemanu_action_2.ogg",
		"res://assets/audio/music/racer/codemanu_action_3.ogg",
		"res://assets/audio/music/racer/codemanu_action_4.ogg",
		"res://assets/audio/music/racer/codemanu_action_5.ogg",
	],
}


func _init() -> void:
	game_id = "racer"
	title_key = "GAME_RACER_TITLE"
	accent = Color("ffd23e")
	title_font = "sunset"


func start(players: int) -> void:
	super(players)
	Audio.play_music(MUSIC.race[0])
