## The list of games in the bundle (picker order) and helpers to query them.
extends RefCounted

const GAMES := [
	["breakout", "res://games/breakout/game.gd"],
	["shmup", "res://games/shmup/game.gd"],
	["racer", "res://games/racer/game.gd"],
]

static var _info_cache := {}


static func ids() -> Array:
	return GAMES.map(func(g): return g[0])


static func has(id: String) -> bool:
	return ids().has(id)


static func instantiate(id: String) -> Node:
	for g in GAMES:
		if g[0] == id:
			return load(g[1]).new()
	return null


## {id, title_key, color, buttons_min} from the module's get_info().
static func info(id: String) -> Dictionary:
	if not _info_cache.has(id):
		var probe := instantiate(id)
		_info_cache[id] = probe.get_info() if probe else {}
		if probe:
			probe.free()
	return _info_cache[id]
