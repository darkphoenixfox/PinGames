## Loading-screen animations (D-238), in the spirit of PS2-era loading screens:
## a small looping scene per game on the TABLE, drawn with plain 2D shapes, and
## a matching dot animation on the DMD. Pure drawing code: no assets, so it is
## ready before anything has loaded.
##   racer:    a retro sports car driving a scrolling road (speed lines, puffs);
##             a mini car runs along a track bar to a chequered flag.
##   breakout: a plasma ball bouncing off a paddle, breaking a row of bricks
##             that empties as loading goes on.
##   others:   a pinball bouncing across.
extends Control

const UI = preload("res://core/ui/ui.gd")

var game_id := ""
var accent := Color("ffd23e")
var progress := 0.0          # 0..1
var _t := 0.0


func _init(p_game_id: String, p_accent: Color) -> void:
	game_id = p_game_id
	accent = p_accent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += minf(delta, 0.1)   # loading can stall a frame; don't jump ahead
	queue_redraw()


func _draw() -> void:
	match game_id:
		"racer":
			_draw_racer()
		"breakout":
			_draw_breakout()
		_:
			_draw_pinball()


# --- Turbo Run ---------------------------------------------------------------------------
func _draw_racer() -> void:
	var cy := 1180.0
	# Sky glow and the road band.
	draw_rect(Rect2(90, cy - 170, 900, 260), Color(0.1, 0.05, 0.18))
	for i in 6:
		draw_rect(Rect2(90, cy - 170 + i * 26, 900, 26), Color(1.0, 0.35, 0.5, 0.05 * (6 - i)))
	draw_rect(Rect2(90, cy + 40, 900, 50), Color(0.2, 0.2, 0.24))
	# Kerbs and dashes scroll by fast.
	var scroll := fmod(_t * 900.0, 120.0)
	for i in 10:
		var x := 90.0 + i * 120.0 - scroll
		if x > 60.0 and x < 990.0:
			draw_rect(Rect2(maxf(x, 90.0), cy + 62, minf(60.0, 990.0 - x), 6), Color(0.95, 0.95, 0.9))
	var kerb := fmod(_t * 900.0, 40.0)
	for i in 25:
		var x := 90.0 + i * 40.0 - kerb
		if x >= 90.0 and x + 20.0 <= 990.0:
			draw_rect(Rect2(x, cy + 40, 20, 6), Color(0.9, 0.15, 0.15))
	# Speed lines.
	for i in 7:
		var ly := cy - 150.0 + i * 24.0
		var lx := 990.0 - fmod(_t * (1300.0 + i * 170.0) + i * 211.0, 1100.0)
		draw_line(Vector2(maxf(lx, 90.0), ly), Vector2(clampf(lx + 120.0, 90.0, 990.0), ly), Color(1, 1, 1, 0.18), 3.0)
	# The car, bobbing on its suspension.
	var bob := sin(_t * 22.0) * 2.5
	var x0 := 400.0
	var y0 := cy + 34.0 + bob
	var body := PackedVector2Array([
		Vector2(x0 - 10, y0 - 22), Vector2(x0 + 6, y0 - 46), Vector2(x0 + 80, y0 - 52),
		Vector2(x0 + 130, y0 - 84), Vector2(x0 + 220, y0 - 86), Vector2(x0 + 268, y0 - 56),
		Vector2(x0 + 300, y0 - 50), Vector2(x0 + 304, y0 - 22),
	])
	draw_colored_polygon(body, accent.darkened(0.15))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.05, 0.03, 0.1), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + 96, y0 - 54), Vector2(x0 + 136, y0 - 78),
		Vector2(x0 + 176, y0 - 78), Vector2(x0 + 176, y0 - 54)]), Color(0.35, 0.65, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + 186, y0 - 54), Vector2(x0 + 186, y0 - 78),
		Vector2(x0 + 214, y0 - 78), Vector2(x0 + 246, y0 - 54)]), Color(0.35, 0.65, 0.95))
	draw_rect(Rect2(x0 - 6, y0 - 40, 26, 8), Color(1.0, 0.2, 0.2))          # tail light
	draw_rect(Rect2(x0 + 284, y0 - 44, 16, 8), Color(1.0, 0.95, 0.7))       # headlight
	draw_line(Vector2(x0 + 8, y0 - 46), Vector2(x0 - 22, y0 - 56), Color(0.05, 0.03, 0.1), 6.0)   # spoiler
	for wx in [x0 + 52.0, x0 + 236.0]:
		draw_circle(Vector2(wx, y0 - 14), 28.0, Color(0.06, 0.06, 0.08))
		draw_circle(Vector2(wx, y0 - 14), 15.0, Color(0.7, 0.7, 0.75))
		for k in 4:   # spinning spokes
			var a := -_t * 30.0 + k * PI * 0.5
			draw_line(Vector2(wx, y0 - 14), Vector2(wx, y0 - 14) + Vector2(cos(a), sin(a)) * 14.0, Color(0.25, 0.25, 0.3), 3.0)
	# Exhaust puffs drifting back.
	for k in 4:
		var age := fmod(_t * 2.0 + k * 0.25, 1.0)
		draw_circle(Vector2(x0 - 20 - age * 160.0, y0 - 20 - age * 20.0), 6.0 + age * 18.0, Color(0.8, 0.8, 0.85, 0.35 * (1.0 - age)))
	_draw_track_bar(1360.0)


## Progress as a little race: a track line, a chequered flag at the end and a
## mini car moving along it.
func _draw_track_bar(y: float) -> void:
	var a := 160.0
	var b := 920.0
	draw_line(Vector2(a, y), Vector2(b, y), Color(0.3, 0.3, 0.38), 10.0)
	draw_line(Vector2(a, y), Vector2(lerpf(a, b, progress), y), accent, 10.0)
	for r in 3:
		for c in 3:
			draw_rect(Rect2(b + 8 + c * 10, y - 34 + r * 10, 10, 10), Color.WHITE if (r + c) % 2 == 0 else Color.BLACK)
	draw_line(Vector2(b + 8, y - 34), Vector2(b + 8, y + 10), Color(0.8, 0.8, 0.85), 3.0)
	var mx := lerpf(a, b, progress)
	draw_rect(Rect2(mx - 18, y - 22, 36, 14), accent)
	draw_circle(Vector2(mx - 10, y - 6), 5.0, Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(mx + 10, y - 6), 5.0, Color(0.1, 0.1, 0.12))


# --- Tilt Breaker ------------------------------------------------------------------------
func _draw_breakout() -> void:
	var box := Rect2(140, 960, 800, 420)
	draw_rect(box, Color(0.03, 0.02, 0.08))
	draw_rect(box, accent.darkened(0.3), false, 4.0)
	# Bricks: they go as loading goes on.
	var cols := 10
	var left := cols - int(progress * cols)
	for i in cols:
		if i >= left:
			continue
		var hue := float(i) / cols
		var bc := Color.from_hsv(0.55 + hue * 0.45, 0.7, 0.95)
		draw_rect(Rect2(box.position.x + 20 + i * 76, box.position.y + 30, 70, 30), bc)
		draw_rect(Rect2(box.position.x + 20 + i * 76, box.position.y + 30, 70, 8), bc.lightened(0.4))
	# The ball: a bounce pattern inside the box (two incommensurate speeds).
	var w := box.size.x - 60.0
	var h := box.size.y - 150.0
	var bx := box.position.x + 30.0 + absf(fmod(_t * 520.0, w * 2.0) - w)
	var by := box.position.y + 80.0 + absf(fmod(_t * 430.0, h * 2.0) - h)
	for k in 5:   # trail
		var tt := _t - k * 0.025
		var tx := box.position.x + 30.0 + absf(fmod(tt * 520.0, w * 2.0) - w)
		var ty := box.position.y + 80.0 + absf(fmod(tt * 430.0, h * 2.0) - h)
		draw_circle(Vector2(tx, ty), 14.0 - k * 2.0, Color(0.4, 0.8, 1.0, 0.25 - k * 0.04))
	draw_circle(Vector2(bx, by), 15.0, Color(0.55, 0.9, 1.0))
	draw_circle(Vector2(bx - 4, by - 4), 6.0, Color.WHITE)
	# The paddle follows the ball.
	var px := clampf(bx, box.position.x + 90.0, box.end.x - 90.0)
	draw_rect(Rect2(px - 80, box.end.y - 40, 160, 18), accent)
	draw_rect(Rect2(px - 80, box.end.y - 40, 160, 6), accent.lightened(0.4))
	_draw_plain_bar(1440.0)


func _draw_plain_bar(y: float) -> void:
	draw_rect(Rect2(236, y, 608, 28), Color(0.15, 0.15, 0.2))
	draw_rect(Rect2(240, y + 4, 600 * progress, 20), accent)


# --- any other game ----------------------------------------------------------------------
func _draw_pinball() -> void:
	var bx := 540.0 + sin(_t * 2.1) * 300.0
	var by := 1180.0 - absf(sin(_t * 4.2)) * 200.0
	draw_circle(Vector2(bx, by + 6), 30.0, Color(0, 0, 0, 0.4))
	draw_circle(Vector2(bx, by), 30.0, Color(0.75, 0.78, 0.82))
	draw_circle(Vector2(bx - 9, by - 9), 10.0, Color.WHITE)
	_draw_plain_bar(1440.0)


# --- DMD ---------------------------------------------------------------------------------
## The matching DMD animation, for Dmd.play: (painter, seconds) -> void.
static func dmd_anim(id: String, color: Color) -> Callable:
	match id:
		"racer":
			return func(p, t: float) -> void:
				var w: int = p.width
				# Road: two rows of dashes scrolling left.
				var s := fmod(t * 60.0, 8.0)
				for i in 20:
					var x := i * 8.0 - s
					p.block(x, 29, 4, 1, Color(0.6, 0.6, 0.6))
				# A dot car, bobbing, wheels flickering.
				var cx := 10.0 + fmod(t * 25.0, float(w + 40)) - 30.0
				var cy := 22.0 + (1.0 if fmod(t * 8.0, 1.0) < 0.5 else 0.0)
				p.block(cx, cy, 18, 3, color)
				p.block(cx + 5, cy - 3, 8, 3, color)
				p.block(cx + 7, cy - 2, 2, 1, Color(0.4, 0.7, 1.0))
				p.dot(cx + 17, cy, Color.WHITE)
				p.dot(cx, cy, Color(1, 0.2, 0.2))
				p.disc(cx + 4, cy + 4, 1.5, Color(0.8, 0.8, 0.8))
				p.disc(cx + 14, cy + 4, 1.5, Color(0.8, 0.8, 0.8))
				for k in 3:   # puffs
					p.dot(cx - 2 - k * 3 - fmod(t * 20.0, 3.0), cy + 1 - k, Color(0.5, 0.5, 0.5))
				p.text_center("LOADING", 2, 1, Color(1.0, 0.82, 0.24) if fmod(t, 1.0) < 0.7 else Color(0.5, 0.4, 0.12))
		"breakout":
			return func(p, t: float) -> void:
				var w: float = p.width
				var bricks := 12
				var gone := int(fmod(t * 1.5, bricks + 4))
				for i in bricks:
					if i < gone:
						continue
					p.block(4 + i * 10, 1, 8, 2, Color.from_hsv(0.55 + i * 0.035, 0.7, 1.0))
				var bx := 2.0 + absf(fmod(t * 60.0, (w - 4.0) * 2.0) - (w - 4.0))
				var by := 5.0 + absf(fmod(t * 40.0, 44.0) - 22.0)
				p.disc(bx, by, 1.2, Color(0.55, 0.9, 1.0))
				var px := clampf(bx - 7.0, 0.0, w - 14.0)
				p.block(px, 30, 14, 1, color)
				p.text_center("LOADING", 12, 1, Color(1.0, 1.0, 1.0, 0.85 if fmod(t, 1.0) < 0.7 else 0.35))
	return func(p, t: float) -> void:
		p.text_center("LOADING", 12, 1, color)
		p.disc(64.0 + sin(t * 3.0) * 50.0, 25.0, 2.0, Color(0.8, 0.8, 0.85))
