## TURBO RUN dashboard dial (D-103), in the director's reference style: an
## arc of segments that start as thin dashes and grow into thick blocks, lit up
## to the current value, with a needle from a ring hub. Used for the
## speedometer and the tachometer. Flat, unantialiased, pixel HUD.
## Numbers sit inside the arc; the red zone (from `red_from`) lights red.
extends Control

const UI = preload("res://core/ui/ui.gd")

const SWEEP_FROM := deg_to_rad(155.0)   # lower left (screen angles, y down)
const SWEEP_TO := deg_to_rad(365.0)     # just past the right
const DIM := Color(0.08, 0.1, 0.15, 0.85)
const RED := Color("ff3b4f")

var radius := 160.0
var segments := 24
var value := 0.0              # 0..1
var red_from := 2.0           # 0..1, > 1 = no red zone
var lit := UI.CYAN
## Perfect-shift band (D-116), 0..1 of the dial; drawn green. Empty = none.
var good_from := 2.0:
	set(v):
		if v != good_from:
			good_from = v
			queue_redraw()
var good_to := 2.0:
	set(v):
		if v != good_to:
			good_to = v
			queue_redraw()
const GOOD := Color("4fff7a")
var labels: Array = []        # [[fraction, text], ...]
var _hub := Vector2.ZERO


func setup(r: float, segs: int, label_list: Array, red: float = 2.0, colour: Color = UI.CYAN) -> void:
	radius = r
	segments = segs
	labels = label_list
	red_from = red
	lit = colour
	_hub = Vector2(r + 6.0, r + 6.0)
	custom_minimum_size = Vector2(r * 2.0 + 12.0, r + 6.0 + r * sin(PI - SWEEP_FROM) + 30.0)
	for l in labels:
		var lab := UI.label(str(l[1]), 24, UI.WHITE)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.custom_minimum_size = Vector2(80, 0)
		var a := _angle(float(l[0]))
		var p := _hub + Vector2(cos(a), sin(a)) * (r * 0.64)
		lab.position = p - Vector2(40, 12)
		add_child(lab)


func hub() -> Vector2:
	return _hub


func set_value(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if is_equal_approx(v, value):
		return
	value = v
	queue_redraw()


func _angle(f: float) -> float:
	return lerpf(SWEEP_FROM, SWEEP_TO, f)


func _draw() -> void:
	var step := (SWEEP_TO - SWEEP_FROM) / segments
	for i in segments:
		var f := (i + 0.5) / segments
		# Thin short dashes at the low end, thick long blocks at the top end.
		var k := clampf((f - 0.15) / 0.85, 0.0, 1.0)
		var depth := radius * lerpf(0.06, 0.2, k)
		var gap := step * lerpf(0.55, 0.2, k)
		var a0 := SWEEP_FROM + i * step + gap * 0.5
		var a1 := SWEEP_FROM + (i + 1) * step - gap * 0.5
		var r0 := radius - depth
		var on := value >= (float(i) + 0.5) / segments
		var col := DIM
		var good := f >= good_from and f < good_to
		if on:
			col = RED if f >= red_from else (GOOD if good else lit)
		elif f >= red_from:
			col = RED.darkened(0.7)
		elif good:
			col = GOOD.darkened(0.65)
		draw_colored_polygon(PackedVector2Array([
			_hub + Vector2(cos(a0), sin(a0)) * r0, _hub + Vector2(cos(a0), sin(a0)) * radius,
			_hub + Vector2(cos(a1), sin(a1)) * radius, _hub + Vector2(cos(a1), sin(a1)) * r0]), col)
	# Needle: a tapered blade from the hub, plus the ring hub.
	var a := _angle(value)
	var dir := Vector2(cos(a), sin(a))
	var side := Vector2(-dir.y, dir.x)
	var hr := radius * 0.07
	var tip := _hub + dir * radius * 0.9
	draw_colored_polygon(PackedVector2Array([_hub + side * hr * 0.8, tip, _hub - side * hr * 0.8]), UI.WHITE)
	draw_circle(_hub, hr * 1.4, UI.WHITE, true, -1.0, false)
	draw_circle(_hub, hr * 0.7, Color(0.05, 0.05, 0.08), true, -1.0, false)
