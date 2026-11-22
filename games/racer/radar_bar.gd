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


## A chunky 16-bit lamp (D-143, D-150): drawn in PX-sized pixels. Off: a dark
## glass ball. On: a pixel glow halo spills round it, and the ball itself burns
## from a near-white core through the full colour to a hot rim, like a lamp.
func _pixel_ball(p: Vector2, col: Color, on: bool) -> void:
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
				c = Color(0.02, 0.02, 0.04) if d > 0.86 else col.darkened(0.78 if (gx + gy) < 0 else 0.84)
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
