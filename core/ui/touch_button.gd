## The face of an on-screen touch button (D-279): a shaded glass disc
## (touch_button.gdshader) with a white icon on it, which sinks and lights up
## while held. It fills its parent, which does the hit-testing
## (core/touch_controls.gd); the button's label sits under the icon.
extends Control

const SHADER := preload("res://core/ui/touch_button.gdshader")
const GROW := 0.3          # room round the disc for its shadow and glow
const ICON_Y := -0.16      # the icon's centre, in button radii from the middle
const ICON_R := 0.4        # the icon's half size, in button radii

var color := Color.WHITE
## left | right | launch | start | exit | magna | brake | shift
var icon := "":
	set(v):
		icon = v
		queue_redraw()
var _body := ColorRect.new()
var _mat := ShaderMaterial.new()
var _press := 0.0
var _tween: Tween


func _init(p_color: Color, p_icon: String) -> void:
	color = p_color
	icon = p_icon
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat.shader = SHADER
	_mat.set_shader_parameter("tint", color)
	_mat.set_shader_parameter("grow", GROW)
	_body.material = _mat
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.show_behind_parent = true   # the icon is drawn over it
	add_child(_body)
	resized.connect(_fit)


func _fit() -> void:
	var d := minf(size.x, size.y)
	_body.size = Vector2(d, d) * (1.0 + 2.0 * GROW)
	_body.position = size * 0.5 - _body.size * 0.5
	pivot_offset = size * 0.5
	queue_redraw()


func set_down(on: bool) -> void:
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		_set_press(1.0 if on else 0.0)
		return
	_tween = create_tween()
	_tween.tween_method(_set_press, _press, 1.0 if on else 0.0, 0.05 if on else 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_press(k: float) -> void:
	_press = k
	_mat.set_shader_parameter("press", k)
	scale = Vector2.ONE * (1.0 - 0.07 * k)
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	if r <= 1.0:
		return
	# A soft dark copy first (a shadow), then the icon in white.
	for pass_i in 2:
		var c := Color(0, 0, 0, 0.35) if pass_i == 0 else Color(1, 1, 1, lerpf(0.92, 1.0, _press))
		var o := size * 0.5 + Vector2(0, r * (ICON_Y + (0.045 if pass_i == 0 else 0.0)))
		_draw_icon(o, r * ICON_R, c)


func _poly(o: Vector2, s: float, pts: Array, c: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(o + (p as Vector2) * s)
	draw_colored_polygon(out, c)
	out.append(out[0])
	draw_polyline(out, c, 1.0, true)   # smooths the polygon's edge


func _draw_icon(o: Vector2, s: float, c: Color) -> void:
	var w := maxf(2.0, s * 0.26)   # stroke width
	match icon:
		"left", "right":
			var k := -1.0 if icon == "left" else 1.0
			# A fat arrowhead with a notch at its back.
			_poly(o, s, [Vector2(0.85 * k, 0.0), Vector2(-0.45 * k, -0.95), Vector2(-0.1 * k, 0.0),
				Vector2(-0.45 * k, 0.95)], c)
			_poly(o, s, [Vector2(-0.35 * k, 0.0), Vector2(-0.95 * k, -0.7), Vector2(-0.72 * k, 0.0),
				Vector2(-0.95 * k, 0.7)], Color(c, c.a * 0.55))
		"launch":
			# An arrow shooting up from a base line.
			_poly(o, s, [Vector2(0.0, -1.0), Vector2(0.72, -0.15), Vector2(0.26, -0.15), Vector2(0.26, 0.5),
				Vector2(-0.26, 0.5), Vector2(-0.26, -0.15), Vector2(-0.72, -0.15)], c)
			draw_line(o + Vector2(-0.7, 0.88) * s, o + Vector2(0.7, 0.88) * s, c, w, true)
		"start":
			_poly(o, s, [Vector2(-0.6, -0.9), Vector2(0.9, 0.0), Vector2(-0.6, 0.9)], c)
		"exit":
			draw_line(o + Vector2(-0.68, -0.68) * s, o + Vector2(0.68, 0.68) * s, c, w * 1.15, true)
			draw_line(o + Vector2(-0.68, 0.68) * s, o + Vector2(0.68, -0.68) * s, c, w * 1.15, true)
		"brake":
			# The brake lamp sign: a disc in a ring, between two brackets.
			draw_arc(o, s * 0.58, 0.0, TAU, 40, c, w * 0.8, true)
			draw_circle(o, s * 0.22, c)
			draw_arc(o, s * 1.0, -0.75, 0.75, 16, c, w * 0.8, true)
			draw_arc(o, s * 1.0, PI - 0.75, PI + 0.75, 16, c, w * 0.8, true)
		"shift":
			# A gear lever: a knob on a stick, with up and down chevrons.
			draw_line(o + Vector2(-0.35, 0.95) * s, o + Vector2(-0.35, -0.35) * s, c, w, true)
			draw_circle(o + Vector2(-0.35, -0.55) * s, s * 0.36, c)
			draw_polyline(PackedVector2Array([o + Vector2(0.3, -0.25) * s, o + Vector2(0.65, -0.7) * s,
				o + Vector2(1.0, -0.25) * s]), c, w * 0.8, true)
			draw_polyline(PackedVector2Array([o + Vector2(0.3, 0.3) * s, o + Vector2(0.65, 0.75) * s,
				o + Vector2(1.0, 0.3) * s]), Color(c, c.a * 0.55), w * 0.8, true)
		_:
			# Magna save: a four-point spark.
			_poly(o, s, [Vector2(0, -1), Vector2(0.24, -0.24), Vector2(1, 0), Vector2(0.24, 0.24),
				Vector2(0, 1), Vector2(-0.24, 0.24), Vector2(-1, 0), Vector2(-0.24, -0.24)], c)
