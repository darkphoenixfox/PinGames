## Credits autoload (D-014): free play by default; in coin mode the coin action adds
## credits and starting a game spends one. Credits are not persisted between runs.
extends Node

signal changed

const MAX_CREDITS := 30

var credits := 0


func free_play() -> bool:
	return bool(Config.get_value("operator", "free_play"))


func add_coin() -> void:
	credits = mini(credits + 1, MAX_CREDITS)
	changed.emit()


func can_start() -> bool:
	return free_play() or credits > 0


## Spends a credit if needed. Returns false if the game may not start.
func try_start() -> bool:
	if free_play():
		return true
	if credits <= 0:
		return false
	credits -= 1
	changed.emit()
	return true


## "FREE PLAY", "CREDITS 3" or "INSERT COIN" (translated).
func status_text() -> String:
	if free_play():
		return tr("DMD_FREE_PLAY")
	if credits > 0:
		return tr("DMD_CREDITS") % credits
	return tr("DMD_INSERT_COIN")
