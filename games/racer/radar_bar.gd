## TURBO RUN radar detector (D-137), styled like a police light bar: five blue
## balls on the left, a black block in the middle, five red balls on the right.
## The balls light from the centre outwards as the next speed camera gets
## closer; lit balls flash brighter with each beep. Fixed size (D-096).
extends Control

const BALLS := 5
const R := 17.0
const GAP := 6.0
const BLOCK := Vector2(70, 34)
const BLUE := Color(0.25, 0.5, 1.0)
const RED := Color(1.0, 0.18, 0.15)

var level := 0.0       # 0..1 radar closeness
var flash := false     # a beep is sounding


func _init() -> void:
	var w := BLOCK.x + 2.0 * BALLS * (2.0 * R + GAP) + 2.0 * GAP
	custom_minimum_size = Vector2(w, 2.0 * R + 8.0)


func set_state(lvl: float, fl: bool) -> void:
	if is_equal_approx(lvl, level) and fl == flash:
		return
	level = lvl
	flash = fl
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	# Housing + centre block
	draw_rect(Rect2(0, c.y - R - 4.0, size.x, 2.0 * R + 8.0), Color(0.03, 0.03, 0.05, 0.85))
	draw_rect(Rect2(c - BLOCK * 0.5, BLOCK), Color(0.0, 0.0, 0.0))
	draw_rect(Rect2(c - BLOCK * 0.5, BLOCK), Color(0.3, 0.3, 0.35), false, 2.0)
	var lit := ceili(level * BALLS) if level > 0.0 else 0
	for i in BALLS:
		var off := BLOCK.x * 0.5 + GAP + R + i * (2.0 * R + GAP)
		var on := i < lit
		for side in [-1.0, 1.0]:
			var col: Color = BLUE if side < 0.0 else RED
			var p := Vector2(c.x + side * off, c.y)
			if on:
				var k := 1.0 if flash else 0.7
				draw_circle(p, R, col * k, true, -1.0, false)
				draw_circle(p - Vector2(R * 0.3, R * 0.3), R * 0.35, Color(1, 1, 1, 0.75 if flash else 0.4), true, -1.0, false)
			else:
				draw_circle(p, R, col.darkened(0.8), true, -1.0, false)
			draw_arc(p, R, 0.0, TAU, 20, Color(0, 0, 0), 2.0, false)
