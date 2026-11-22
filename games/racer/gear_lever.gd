## TURBO RUN gear lever (D-110): a top-down shift gate on the dashboard with
## H at the top and L at the bottom. The knob slides along the slot in a few
## stepped frames when the gear changes (sprite-like, D-098). Flat pixel HUD
## drawing; the lit position's letter is bright, the other dim.
extends Control

const UI = preload("res://core/ui/ui.gd")

const W := 150.0
const H := 210.0
const SLOT_TOP := 50.0
const SLOT_BOTTOM := 160.0
const KNOB_R := 26.0
const STEPS := 3.0            # frames of knob travel
const TRAVEL_TIME := 0.12     # s

var high := false             # current gear
var _pos := 1.0               # 0 = H (top), 1 = L (bottom)
var _h_label: Label
var _l_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _ready() -> void:
	_h_label = _letter(tr("RC_GEAR_H"), SLOT_TOP)
	_l_label = _letter(tr("RC_GEAR_L"), SLOT_BOTTOM)
	_refresh_letters()


func _letter(text: String, y: float) -> Label:
	var l := UI.label(text, 36, UI.GREY)
	l.position = Vector2(W * 0.5 + 34.0, y - 22.0)
	add_child(l)
	return l


func set_gear(is_high: bool) -> void:
	if is_high != high:
		high = is_high
		_refresh_letters()


func _refresh_letters() -> void:
	if _h_label == null:
		return
	UI.set_color(_h_label, UI.WHITE if high else UI.GREY)
	UI.set_color(_l_label, UI.YELLOW if not high else UI.GREY)


func _process(delta: float) -> void:
	var target := 0.0 if high else 1.0
	if _pos != target:
		_pos = move_toward(_pos, target, delta / TRAVEL_TIME)
		queue_redraw()


func _draw() -> void:
	# No plate (D-149): just the gate slot, outlined so it reads on the road.
	var cx := W * 0.5 - 10.0
	draw_rect(Rect2(cx - 12, SLOT_TOP - 12, 24, SLOT_BOTTOM - SLOT_TOP + 24), UI.GREY)
	draw_rect(Rect2(cx - 9, SLOT_TOP - 9, 18, SLOT_BOTTOM - SLOT_TOP + 18), Color(0.0, 0.0, 0.02))
	for y in [SLOT_TOP, SLOT_BOTTOM]:
		draw_rect(Rect2(cx + 16, y - 3, 14, 6), UI.GREY)
	# Knob: stepped travel between the two positions
	var p := roundf(_pos * STEPS) / STEPS
	var ky := lerpf(SLOT_TOP, SLOT_BOTTOM, p)
	var col := UI.YELLOW if not high else UI.WHITE
	draw_circle(Vector2(cx, ky + 4), KNOB_R, Color(0, 0, 0, 0.5), true, -1.0, false)
	draw_circle(Vector2(cx, ky), KNOB_R, col.darkened(0.45), true, -1.0, false)
	draw_circle(Vector2(cx - 3, ky - 3), KNOB_R - 6, col, true, -1.0, false)
	draw_circle(Vector2(cx - 9, ky - 9), 6, Color(1, 1, 1, 0.9), true, -1.0, false)
