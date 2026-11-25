## TURBO RUN gate art (D-415): paints a start / checkpoint / finish gate as one
## sprite. Two poles with gold finials, a rope between their tops, and a cloth
## banner hanging from the rope with the gate's text. Drawn once into a
## SubViewport (games/racer/game.gd, `_gate_texture`); shaders/banner.gdshader
## makes the cloth sag and wave. All sizes are in metres (PX_PER_M pixels each),
## and the layout constants are shared with the shader through `uv_layout()`.
extends Control

const PX_PER_M := 48.0
const POLE_IN := 0.6          # pole centre, in from each side of the sprite
const POLE_W := 0.42
const POLE_TOP := 9.3         # height of the pole tops (finials sit on them)
const ROPE_Y := 9.0
const BANNER_IN := 1.25       # banner ends, in from each side of the sprite
const BANNER_H := 3.0
const BANNER_H_FINISH := 3.8
const HEIGHT := 10.0

const CLOTH := Color(0.86, 0.1, 0.17)
const CLOTH_FINISH := Color(0.8, 0.05, 0.08)
const CLOTH_DARK := Color(0.52, 0.04, 0.09)
const TRIM := Color(1.0, 0.93, 0.78)
const TEXT := Color(1.0, 0.9, 0.3)
const TEXT_FINISH := Color(1.0, 0.86, 0.1)
const OUTLINE := Color(0.3, 0.02, 0.05)
const POLE := Color(0.82, 0.84, 0.88)
const POLE_SHADE := Color(0.45, 0.47, 0.55)
const STRIPE := Color(0.86, 0.1, 0.17)
const GOLD := Color(1.0, 0.78, 0.2)
const GOLD_SHADE := Color(0.7, 0.45, 0.08)
const ROPE := Color(0.25, 0.2, 0.16)

var text := ""
var finish := false
var width_m := 20.0


static func banner_h(is_finish: bool) -> float:
	return BANNER_H_FINISH if is_finish else BANNER_H


## Sprite size in pixels for a gate `width_m` wide.
static func size_px(w_m: float) -> Vector2i:
	return Vector2i(roundi(w_m * PX_PER_M), roundi(HEIGHT * PX_PER_M))


## The shader's layout in UV (v = 0 at the top): [pole u0, pole u1, banner u0,
## banner u1, rope v, banner bottom v].
static func uv_layout(w_m: float, is_finish: bool) -> Array:
	return [POLE_IN / w_m, 1.0 - POLE_IN / w_m, BANNER_IN / w_m, 1.0 - BANNER_IN / w_m,
		(HEIGHT - ROPE_Y) / HEIGHT, (HEIGHT - ROPE_Y + banner_h(is_finish)) / HEIGHT]


func _px(m: float) -> float:
	return m * PX_PER_M


## Height above the ground (m) to a y pixel.
func _y(h: float) -> float:
	return _px(HEIGHT - h)


func _draw() -> void:
	for side in [POLE_IN, width_m - POLE_IN]:
		_pole(side)
	# The rope, pole top to pole top.
	draw_line(Vector2(_px(POLE_IN), _y(ROPE_Y)), Vector2(_px(width_m - POLE_IN), _y(ROPE_Y)), ROPE, 4.0)
	_banner()


func _pole(cx: float) -> void:
	var x0 := _px(cx - POLE_W * 0.5)
	var w := _px(POLE_W)
	draw_rect(Rect2(x0, _y(POLE_TOP), w, _px(POLE_TOP)), POLE)
	draw_rect(Rect2(x0 + w * 0.62, _y(POLE_TOP), w * 0.38, _px(POLE_TOP)), POLE_SHADE)
	# Red bands down the pole, like a barrier post.
	var h := 0.6
	while h < 5.6:
		draw_rect(Rect2(x0, _y(h + 0.5), w, _px(0.5)), STRIPE)
		draw_rect(Rect2(x0 + w * 0.62, _y(h + 0.5), w * 0.38, _px(0.5)), CLOTH_DARK)
		h += 1.0
	# Base plate and finial.
	draw_rect(Rect2(x0 - w * 0.35, _y(0.25), w * 1.7, _px(0.25)), POLE_SHADE)
	var top := Vector2(_px(cx), _y(POLE_TOP + 0.22))
	draw_circle(top, _px(0.26), GOLD_SHADE)
	draw_circle(top + Vector2(-_px(0.04), -_px(0.04)), _px(0.2), GOLD)


func _banner() -> void:
	var bh := banner_h(finish)
	var x0 := _px(BANNER_IN)
	var w := _px(width_m - 2.0 * BANNER_IN)
	var top := _y(ROPE_Y) + 2.0
	var h := _px(bh)
	draw_rect(Rect2(x0, top, w, h), CLOTH_FINISH if finish else CLOTH)
	# Loops over the rope.
	var n := 14
	for i in n + 1:
		var lx := x0 + w * (i / float(n)) - _px(0.12)
		draw_rect(Rect2(lx, top - _px(0.18), _px(0.24), _px(0.3)), CLOTH_DARK)
	var band := _px(0.34)
	if finish:   # chequered hems (D-223's finish look)
		var sq := band * 0.5
		for row in 2:
			for y0 in [top + _px(0.08), top + h - band - _px(0.08)]:
				var i := 0
				var x := x0
				while x < x0 + w - 0.5:
					var c := Color.WHITE if (i + row) % 2 == 0 else Color(0.08, 0.08, 0.1)
					draw_rect(Rect2(x, y0 + row * sq, minf(sq, x0 + w - x), sq), c)
					x += sq
					i += 1
	else:
		draw_rect(Rect2(x0, top + _px(0.1), w, _px(0.1)), TRIM)
		draw_rect(Rect2(x0, top + h - _px(0.2), w, _px(0.1)), TRIM)
	# Darker hem at the bottom edge.
	draw_rect(Rect2(x0, top + h - _px(0.08), w, _px(0.08)), CLOTH_DARK)
	_text(Rect2(x0, top, w, h), bh)


func _text(r: Rect2, bh: float) -> void:
	var font: Font = load("res://assets/fonts/pinpixel.ttf")
	# Letters as tall as about half the banner, in steps of 12 (crisp PinPixel,
	# D-060), shrunk to fit long translations.
	var fs := int(floorf(_px(bh * (0.62 if finish else 0.6)) / 12.0)) * 12
	while fs > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x * 0.88:
		fs -= 12
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(r.position.x + (r.size.x - sz.x) * 0.5,
		r.position.y + (r.size.y - sz.y) * 0.5 + font.get_ascent(fs))
	var outline := maxi(6, fs / 8)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT_FINISH if finish else TEXT)
