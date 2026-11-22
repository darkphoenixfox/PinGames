## The list of games in the bundle (picker order) and helpers to query them.
extends RefCounted

const GAMES := [
	["breakout", "res://games/breakout/game.gd"],
	["shmup", "res://games/shmup/game.gd"],
	["racer", "res://games/racer/game.gd"],
]
## Games left out of the picker, attract and operator menu until they have
## something to show (D-184). --game=<id> still opens them for development.
const HIDDEN := ["shmup"]

static var _info_cache := {}


## The games players see, in picker order.
static func ids() -> Array:
	return all_ids().filter(func(id): return not HIDDEN.has(id))


## Every game in the bundle, hidden ones included.
static func all_ids() -> Array:
	return GAMES.map(func(g): return g[0])


static func has(id: String) -> bool:
	return all_ids().has(id)


static func instantiate(id: String) -> Node:
	for g in GAMES:
		if g[0] == id:
			return load(g[1]).new()
	return null


## Backglass art for shell screens (D-088): the game's lit backglass, or its
## `_2screen` version when the DMD sits inside the backglass. Null if none.
static func backglass_art(id: String) -> Texture2D:
	var path: String = info(id).get("backglass", "")
	if path.is_empty():
		return null
	if Screens.dmd_in_backglass:
		var two := path.get_basename() + "_2screen." + path.get_extension()
		if ResourceLoader.exists(two):
			path = two
	return load(path) if ResourceLoader.exists(path) else null


## A full-screen TextureRect showing `tex` (cover), or null if tex is null.
static func backglass_rect(tex: Texture2D) -> TextureRect:
	if tex == null:
		return null
	var r := TextureRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return r


## {id, title_key, color, buttons_min} from the module's get_info().
static func info(id: String) -> Dictionary:
	if not _info_cache.has(id):
		var probe := instantiate(id)
		_info_cache[id] = probe.get_info() if probe else {}
		if probe:
			probe.free()
	return _info_cache[id]
