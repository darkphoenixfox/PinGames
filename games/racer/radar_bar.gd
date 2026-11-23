## TURBO RUN radar detector (D-137), styled like a police light bar: five blue
## balls on the left, a black block in the middle, five red balls on the right.
## The balls light from the centre outwards as the next speed camera gets
## closer; lit balls flash brighter with each beep. Fixed size (D-096).
extends Control

const BALLS := 5
const R := 24.0
const PX := 4.0          # chunky pixel size (D-143)
const BLOCK := Vector2(110, 44)
const BLUE := Color(0.25, 0.5, 1.0)
const RED := Color(1.0, 0.18, 0.15)

var level := 0.0       # 0..1 radar closeness
var flash := false     # a beep is sounding
## HD graphics (D-212): smooth antialiased lamps instead of chunky pixels.
var smooth := false:
	set(v):
		if v != smooth:
			smooth = v
			queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(1080, 2.0 * R + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(lvl: float, fl: bool) -> void:
	if is_equal_approx(lvl, level) and fl == flash:
		return
	level = lvl
	flash = fl
	queue_redraw()


## Spread across the full width (D-139): the black block in the middle, five
## balls evenly spaced on each side out to the screen edges. No housing.
func _draw() -> void:
	var c := size * 0.5
	draw_rect(Rect2(c - BLOCK * 0.5, BLOCK), Color(0.0, 0.0, 0.0))
	draw_rect(Rect2(c - BLOCK * 0.5, BLOCK), Color(0.3, 0.3, 0.35), false, 2.0)
	var inner := BLOCK.x * 0.5 + R + 14.0
	var outer := size.x * 0.5 - R - 10.0
	var lit := ceili(level * BALLS) if level > 0.0 else 0
	for i in BALLS:
		var off := lerpf(inner, outer, float(i) / (BALLS - 1))
		var on := i < lit
		for side in [-1.0, 1.0]:
			var col: Color = BLUE if side < 0.0 else RED
			_pixel_ball(Vector2(c.x + side * off, c.y), col, on)


## A chunky 16-bit lamp (D-143, D-150): drawn in PX-sized pixels. Off (D-188):
## an unlit lamp: a grey metal bezel, a pale ribbed glass lens barely tinted
## by its colour, the reflector bowl a little darker in the middle, and a
## glint top-left. On: a pixel glow halo spills round it, and the ball itself burns
## from a near-white core through the full colour to a hot rim, like a lamp.
func _pixel_ball(p: Vector2, col: Color, on: bool) -> void:
	if smooth:
		_smooth_ball(p, col, on)
		return
	var n := int(R / PX)
	if on:
		var g := n + (5 if flash else 3)
		for gy in range(-g, g + 1):
			for gx in range(-g, g + 1):
				var d := Vector2(gx + 0.5, gy + 0.5).length()
				if d <= n + 0.5 or d > g + 0.5:
					continue
				var k := 1.0 - (d - n) / float(g - n + 1)
				# Dithered falloff: fewer pixels further out (16-bit glow).
				if (gx + gy) % 2 != 0 and k < 0.6:
					continue
				draw_rect(Rect2(p + Vector2(gx, gy) * PX, Vector2(PX, PX)), Color(col, (0.55 if flash else 0.35) * k))
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var d := Vector2(gx + 0.5, gy + 0.5).length() / (n + 0.5)
			if d > 1.0:
				continue
			var c: Color
			if not on:
				c = _off_pixel(gx, gy, d, n, col)
			else:
				var core := (Vector2(gx, gy) - Vector2(-n * 0.2, -n * 0.25)).length() / n
				if core < (0.45 if flash else 0.3):
					c = Color(1, 1, 1)
				elif core < (0.7 if flash else 0.55):
					c = col.lightened(0.55)
				elif d < 0.86:
					c = col
				else:
					c = col.lightened(0.15)      # hot rim instead of a dark outline
			draw_rect(Rect2(p + Vector2(gx, gy) * PX, Vector2(PX, PX)), c)


## The same lamp drawn smooth for HD (D-212): antialiased circles in layers.
func _smooth_ball(p: Vector2, col: Color, on: bool) -> void:
	if on:
		var g := R + (20.0 if flash else 12.0)
		var steps := 10
		for i in steps:
			var t := float(i) / steps
			draw_circle(p, lerpf(g, R, t), Color(col, (0.07 if flash else 0.045) * (0.4 + t)), true, -1.0, true)
		draw_circle(p, R, col.lightened(0.15), true, -1.0, true)
		draw_circle(p, R * 0.86, col, true, -1.0, true)
		var core := p + Vector2(-R * 0.2, -R * 0.25)
		draw_circle(core, R * (0.7 if flash else 0.55), col.lightened(0.55), true, -1.0, true)
		draw_circle(core, R * (0.45 if flash else 0.3), Color(1, 1, 1), true, -1.0, true)
		return
	# Off: bezel lit top-left, dark lip, pale tinted glass darker in the bowl, glint.
	draw_circle(p, R, Color(0.2, 0.21, 0.23), true, -1.0, true)
	draw_circle(p + Vector2(-1.5, -1.5), R - 1.5, Color(0.72, 0.74, 0.76), true, -1.0, true)
	draw_circle(p, R - 2.5, Color(0.42, 0.44, 0.47), true, -1.0, true)
	draw_circle(p, R * 0.86, Color(0.13, 0.14, 0.16), true, -1.0, true)
	var glass := Color(0.6, 0.63, 0.67).lerp(col, 0.16)
	draw_circle(p, R * 0.74, glass, true, -1.0, true)
	for i in 6:
		var t := float(i + 1) / 6.0
		draw_circle(p, R * 0.74 * (1.0 - t * 0.85), Color(0, 0, 0, 0.05), true, -1.0, true)
	var gl := p + Vector2(-R * 0.38, -R * 0.38) * 0.74 * 1.15
	draw_circle(gl, R * 0.2, glass.lightened(0.35), true, -1.0, true)
	draw_circle(gl, R * 0.11, Color(0.97, 0.98, 1.0), true, -1.0, true)


## One pixel of an unlit lamp (d: 0 centre .. 1 rim).
func _off_pixel(gx: int, gy: int, d: float, n: int, col: Color) -> Color:
	var lit_side := float(-(gx + gy)) / float(2 * n)   # +1 top-left .. -1 bottom-right
	if d > 0.86:   # metal bezel, catching the light top-left
		return Color(0.42, 0.44, 0.47).lerp(Color(0.72, 0.74, 0.76) if lit_side > 0.0 else Color(0.2, 0.21, 0.23), absf(lit_side))
	if d > 0.74:   # dark inner lip where the glass sits
		return Color(0.13, 0.14, 0.16)
	# Glass over a reflector: pale, a hint of the lamp's colour, darker towards
	# the bowl's centre, with vertical ribs.
	var glass := Color(0.6, 0.63, 0.67).lerp(col, 0.16)
	glass = glass.darkened(0.3 * (1.0 - d))
	glass = glass.lightened(0.08) if gx % 2 == 0 else glass.darkened(0.06)
	if gy == 0 or gy == -1:
		glass = glass.darkened(0.08)   # the filament shield's shadow across the middle
	# Glint: a small bright spot up and to the left.
	var glint := Vector2(gx + n * 0.38, gy + n * 0.38).length()
	if glint < 1.2:
		return Color(0.97, 0.98, 1.0)
	if glint < 2.0:
		return glass.lightened(0.35)
	return glass
