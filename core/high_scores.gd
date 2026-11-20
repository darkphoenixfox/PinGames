## HighScores autoload: top-10 table per game in user://scores.cfg.
extends Node

const ScoreTable = preload("res://core/util/score_table.gd")
const PATH := "user://scores.cfg"
const SIZE := 10

var _file := ConfigFile.new()


func _ready() -> void:
	var err := _file.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("HighScores: could not read %s (error %d)" % [PATH, err])


func get_table(game_id: String) -> Array:
	var t: Variant = _file.get_value("scores", game_id, []) if _file.has_section_key("scores", game_id) else []
	if not (t is Array) or (t as Array).is_empty():
		return ScoreTable.defaults(SIZE)
	return (t as Array).duplicate(true)


func qualifies(game_id: String, score: int) -> bool:
	return ScoreTable.qualifies(get_table(game_id), score, SIZE)


## Returns the 0-based rank, or -1 if not a high score.
func submit(game_id: String, initials: String, score: int) -> int:
	var t := get_table(game_id)
	var rank := ScoreTable.insert(t, initials, score, SIZE)
	if rank >= 0:
		_file.set_value("scores", game_id, t)
		_save()
	return rank


## Resets one game's table, or all of them when game_id is empty.
func reset(game_id: String = "") -> void:
	if game_id.is_empty():
		if _file.has_section("scores"):
			_file.erase_section("scores")
	elif _file.has_section_key("scores", game_id):
		_file.erase_section_key("scores", game_id)
	_save()


func _save() -> void:
	var err := _file.save(PATH)
	if err != OK:
		push_error("HighScores: failed to save (error %d)" % err)
