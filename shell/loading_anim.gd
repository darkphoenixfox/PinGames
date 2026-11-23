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
## The driver and his car (D-240, D-241), as dots on a 128x32 grid: he walks up
## to the director's yellow sports car, gets in, the lights come on and it
## pulls away, then again. Drawn on the DMD and, as a big dot panel, on the TABLE.
const SCENE_LOOP := 6.5
## The driver, 9x19 dots (D-242: a person is taller than a supercar, about 1.8
## to 1.25 m, so 19 dots against the car's 14), walking right: legs apart with
## arms swinging, then passing.
const GUY_A := [
	"...HHH...", "..HHHHH..", "..HSSSS..", "..SSSSS..", "...SSS...", "....S....",
	"..JJJJJ..", ".JJJJJJJ.", "SJJJJJJJ.", "S.JJJJJ.S", "..JJJJJ.S", "..JJJJJ..",
	"..PPPPP..", "..PP.PP..", ".PP...PP.", ".PP...PP.", "PP.....PP", "PP.....PP", "BB.....BBB",
]
const GUY_B := [
	"...HHH...", "..HHHHH..", "..HSSSS..", "..SSSSS..", "...SSS...", "....S....",
	"..JJJJJ..", ".JJJJJJJ.", ".JJJJJJS.", ".JJJJJJ.S", "..JJJJJ..", "..JJJJJ..",
	"..PPPPP..", "...PPP...", "...PPP...", "...PP....", "...PP....", "...PP....", "...BBB...",
]
const SCENE_COLS := {"R": Color(0.95, 0.12, 0.12), "r": Color(0.5, 0.05, 0.05), "W": Color(0.35, 0.65, 1.0),
	"T": Color(1.0, 0.3, 0.3), "Y": Color(1.0, 0.95, 0.6), "K": Color(0.12, 0.12, 0.14), "G": Color(0.65, 0.65, 0.7),
	"H": Color(0.3, 0.18, 0.08), "S": Color(1.0, 0.78, 0.6), "J": Color(0.9, 0.9, 0.95), "P": Color(0.2, 0.35, 0.85),
	"B": Color(0.15, 0.12, 0.1)}


const CAR_DMD := "res://assets/textures/racer/loading_car_dmd.png"   # D-241: the director's car, as dots
static var _car_img: Image


## Calls put(x, y, colour) for every lit dot of the scene at time t.
static func racer_scene(put: Callable, t: float) -> void:
	if _car_img == null:
		var tex := load(CAR_DMD) as Texture2D
		if tex != null:
			_car_img = tex.get_image()
			if _car_img.is_compressed():
				_car_img.decompress()
	var lt := fmod(t, SCENE_LOOP)
	for x in range(0, 128, 2):   # the kerb line
		put.call(x, 29, Color(0.3, 0.3, 0.35))
	var cw := _car_img.get_width() if _car_img != null else 46
	var ch_ := _car_img.get_height() if _car_img != null else 14
	var car_y := 29 - ch_
	var car_x := 76.0
	var lights := lt > 4.0
	if lt > 4.6:   # pulling away, faster and faster
		var d := lt - 4.6
		car_x += d * d * 40.0
		for k in 4:   # exhaust puffs
			put.call(int(car_x) - 2 - k * 3 - int(fmod(lt * 20.0, 3.0)), car_y + ch_ - 3 - k / 2, Color(0.55, 0.55, 0.6))
	if _car_img != null:
		for r in ch_:
			for c in cw:
				var px := _car_img.get_pixel(c, r)
				if px.a > 0.5:
					put.call(int(car_x) + c, car_y + r, Color(px.r, px.g, px.b))
	if lights:   # headlight at the nose, tail light at the back, a beam ahead
		put.call(int(car_x) + cw - 1, car_y + 8, Color(1.0, 1.0, 0.85))
		put.call(int(car_x) + cw - 2, car_y + 8, Color(1.0, 1.0, 0.85))
		put.call(int(car_x), car_y + 6, Color(1.0, 0.15, 0.15))
		put.call(int(car_x) + 1, car_y + 6, Color(1.0, 0.15, 0.15))
		for k in range(1, 8):
			put.call(int(car_x) + cw - 1 + k, car_y + 8 + k / 3, Color(1.0, 0.95, 0.6, 0.65 - k * 0.07))
	# The driver walks in from the left to the door, then he's gone (in).
	var door := int(car_x) + 20
	if lt < 3.6:
		var gx := -9.0 + minf(lt / 3.4, 1.0) * float(door - 7 + 9)
		var walking := lt < 3.4
		var stride := walking and fmod(lt, 0.3) < 0.15
		var frame: Array = GUY_B if stride else GUY_A
		var bob := 1 if stride else 0
		for r in frame.size():
			var row2: String = frame[r]
			for c in row2.length():
				if row2[c] != ".":
					put.call(int(gx) + c, 10 + r - bob, SCENE_COLS[row2[c]])   # feet on the kerb line
	if lt >= 3.4 and lt < 3.9:   # the door swings open for him
		for r in 5:
			put.call(door - r / 2, car_y + 5 + r, Color(0.98, 0.78, 0.15))


func _draw_racer() -> void:
	# D-240: the driver-and-car scene on a dot-matrix panel.
	var pitch := 7.0
	var panel := Rect2(540.0 - 64.0 * pitch, 1040.0, 128.0 * pitch, 32.0 * pitch)
	draw_rect(panel.grow(10.0), Color(0.12, 0.1, 0.1))
	draw_rect(panel, Color(0.03, 0.02, 0.02))
	for yy in 32:   # unlit dots
		for xx in 128:
			draw_circle(panel.position + Vector2(xx + 0.5, yy + 0.5) * pitch, pitch * 0.32, Color(0.09, 0.06, 0.05))
	racer_scene(func(x: int, y: int, c: Color) -> void:
		if x >= 0 and x < 128 and y >= 0 and y < 32:
			draw_circle(panel.position + Vector2(x + 0.5, y + 0.5) * pitch, pitch * 0.42, c), _t)
	_draw_track_bar(1360.0)


## The first loading scene (D-238): a car on a scrolling road. Kept for reference.
func _draw_racer_road() -> void:
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
				# D-240: the driver walks up to the red car and drives off.
				racer_scene(func(x: int, y: int, c: Color) -> void: p.dot(x, y, c), t)
				p.text("LOADING", 2, 2, 1, Color(1.0, 0.82, 0.24) if fmod(t, 1.0) < 0.7 else Color(0.5, 0.4, 0.12))
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
