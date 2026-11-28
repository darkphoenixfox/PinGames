## Turbo Run: the race map (D-502, D-506, D-507). A black line is the whole
## race, start at the bottom and finish at the top, with a red circle at every
## stage border, a chequered bar at the finish and an icon for each car.
## 2P: the line between the two halves, P1's icon on its left and P2's on its
## right. 1P (`solo`): a line down the left side with the player's icon on it.
## Base coordinates.
extends Control

const Sim = preload("res://games/racer/sim.gd")

const LINE_W := 6.0
const TOP := 90.0                # the finish, from the top edge
const BOTTOM := 300.0            # the start, from the bottom edge: above the gauges
const SOLO_X := 36.0             # 1P: the line, from the screen's left edge (D-509)
const CAPTION_PAD := 10.0        # 1P: the clock caption's letters start this far under its top (D-512)
const MARK_R := 9.0              # a stage marker: a red circle ...
const MARK_RIM := 3.0            # ... with a black border
const MARK_RED := Color("e8202a")
const FINISH_SQ := 9.0           # the finish marker: 2 rows of 6 chequers (1P: 4, D-508)
const ICON := Vector2(26.0, 46.0)
const ICON_OFF := 19.0           # 2P: each icon's centre, from the line's centre
const COLORS := [Color("ffd23e"), Color("3ec7ff")]   # P1 yellow, P2 cyan, as on the DMD (D-289)

var game: Node                   # the view it belongs to: its `sim` is the race
var solo := false                # the 1P map (D-507)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	queue_redraw()


## Where `s` metres into the race sits on the map, 0 (start) to 1 (finish).
static func progress(s: float) -> float:
	return clampf(s / (Sim.FINISH_STAGE * Sim.CHECKPOINT_EVERY), 0.0, 1.0)


## 1P (D-509): the map stands on the screen itself, not in the HUD's area, and
## shows with the HUD.
func _solo_shown() -> bool:
	return game != null and is_instance_valid(game._hud) and game._hud.is_visible_in_tree() 		and not game._two and not game._pursuit


## The map's ends: the start's and the finish's heights. 1P (D-512): the finish
## marker's top is level with the top of the clock's caption and the start
## marker's bottom with the top of the tachometer. (The HUD's area and the
## screen share their heights, D-254.)
func _ends() -> Vector2:
	if solo and game != null and is_instance_valid(game._time_caption) and is_instance_valid(game._tacho):
		return Vector2(float(game._tacho.global_position.y) + float(game._tacho.hub().y) - float(game._tacho.radius) - MARK_R - MARK_RIM,
			float(game._time_caption.global_position.y) + CAPTION_PAD + FINISH_SQ + 2.0)
	return Vector2(size.y - BOTTOM, TOP)


func _map_y(k: float) -> float:
	var e := _ends()
	return lerpf(e.x, e.y, k)


func _draw() -> void:
	var cx := SOLO_X if solo else size.x * 0.5
	if solo:
		if not _solo_shown():
			return
		# D-509: from the first marker to the finish marker, no further.
		draw_rect(Rect2(cx - LINE_W * 0.5, _map_y(1.0), LINE_W, _map_y(0.0) - _map_y(1.0)), Color.BLACK)
	else:
		draw_rect(Rect2(cx - LINE_W * 0.5, 0.0, LINE_W, size.y), Color.BLACK)
	for n in range(0, Sim.FINISH_STAGE):   # the start and each stage border
		var at := Vector2(cx, _map_y(float(n) / Sim.FINISH_STAGE))
		draw_circle(at, MARK_R + MARK_RIM, Color.BLACK, true, -1.0, true)
		draw_circle(at, MARK_R, MARK_RED, true, -1.0, true)
	# The finish: a chequered bar.
	var fy := _map_y(1.0)
	var cols := 4 if solo else 6
	draw_rect(Rect2(cx - FINISH_SQ * cols * 0.5 - 2.0, fy - FINISH_SQ - 2.0, FINISH_SQ * cols + 4.0, FINISH_SQ * 2.0 + 4.0), Color.BLACK)
	for row in 2:
		for col in cols:
			if (row + col) % 2 == 0:
				draw_rect(Rect2(cx + (col - cols * 0.5) * FINISH_SQ, fy + (row - 1) * FINISH_SQ, FINISH_SQ, FINISH_SQ), Color.WHITE)
	if game == null or game.sim == null:
		return
	if solo:
		_draw_car(Vector2(cx, _map_y(progress(float(game.sim.player_get(0, "s"))))), COLORS[0])
	elif game.sim.two_player:
		for i in 2:
			var k := progress(float(game.sim.player_get(i, "s")))
			_draw_car(Vector2(cx + (ICON_OFF if i == 1 else -ICON_OFF), _map_y(k)), COLORS[i])


## A little car seen from above, nose up.
func _draw_car(c: Vector2, col: Color) -> void:
	var h := ICON * 0.5
	var body := PackedVector2Array([
		c + Vector2(-h.x * 0.6, -h.y), c + Vector2(h.x * 0.6, -h.y), c + Vector2(h.x, -h.y * 0.55),
		c + Vector2(h.x, h.y * 0.8), c + Vector2(h.x * 0.75, h.y), c + Vector2(-h.x * 0.75, h.y),
		c + Vector2(-h.x, h.y * 0.8), c + Vector2(-h.x, -h.y * 0.55)])
	draw_colored_polygon(body, col)
	var rim := body.duplicate()
	rim.append(body[0])
	draw_polyline(rim, Color.BLACK, 3.0)
	var glass := Color(0.05, 0.06, 0.1)
	draw_colored_polygon(PackedVector2Array([   # windscreen
		c + Vector2(-h.x * 0.62, -h.y * 0.3), c + Vector2(h.x * 0.62, -h.y * 0.3),
		c + Vector2(h.x * 0.5, 0.0), c + Vector2(-h.x * 0.5, 0.0)]), glass)
	draw_rect(Rect2(c.x - h.x * 0.5, c.y + h.y * 0.42, h.x, h.y * 0.2), glass)   # rear window
