## TURBO RUN nitro gauge (D-098): a half-dial of lit segments with a needle,
## filled from the left as the nitro bar (0..1) fills. Drawn flat and
## unantialiased so it matches the pixel HUD. The percentage sits under the hub
## in a fixed-width slot, so changing digits never move anything (D-096).
extends Control

const UI = preload("res://core/ui/ui.gd")

const SEGMENTS := 14
const R_OUT := 130.0
const R_IN := 92.0
const GAP := 0.035            # radians between segments
const DARK := Color(0.06, 0.09, 0.14, 0.85)
const LOW := Color(0.2, 0.45, 0.6)

var value := 1.0
var burning := false
var _blink := false
var _pct: Label


func _init() -> void:
	custom_minimum_size = Vector2(R_OUT * 2.0 + 8.0, R_OUT + 52.0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	_pct = UI.label("100", 36, UI.WHITE)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.custom_minimum_size = Vector2(120, 0)
	_pct.position = Vector2(_hub().x - 60.0, _hub().y + 6.0)
	add_child(_pct)


func set_state(v: float, burn: bool, blink: bool) -> void:
	if is_equal_approx(v, value) and burn == burning and blink == _blink:
		return
	value = clampf(v, 0.0, 1.0)
	burning = burn
	_blink = blink
	if _pct != null:
		_pct.text = "%d" % roundi(value * 100.0)
	queue_redraw()


func _hub() -> Vector2:
	return Vector2(R_OUT + 4.0, R_OUT + 4.0)


func _draw() -> void:
	var c := _hub()
	var lit := LOW if value < 0.25 else UI.CYAN
	if burning and _blink:
		lit = UI.WHITE
	var span := PI / SEGMENTS
	for i in SEGMENTS:
		# Left (empty end) to right (full end) across the top half.
		var a0 := PI + i * span + GAP * 0.5
		var a1 := PI + (i + 1) * span - GAP * 0.5
		var on := value * SEGMENTS > i + 0.01
		var pts := PackedVector2Array([
			c + Vector2(cos(a0), sin(a0)) * R_IN, c + Vector2(cos(a0), sin(a0)) * R_OUT,
			c + Vector2(cos(a1), sin(a1)) * R_OUT, c + Vector2(cos(a1), sin(a1)) * R_IN])
		draw_colored_polygon(pts, lit if on else DARK)
	# Needle + hub
	var a := PI + PI * value
	var tip := c + Vector2(cos(a), sin(a)) * (R_IN - 6.0)
	draw_line(c, tip, UI.WHITE, 6.0, false)
	draw_rect(Rect2(c - Vector2(10, 10), Vector2(20, 20)), UI.WHITE)
