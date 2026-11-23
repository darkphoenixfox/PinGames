## The touch overlay's flipper areas (D-282): the bottom half of the screen,
## its left half the LEFT flipper and its right half the RIGHT one. Nothing is
## drawn there in play except a faint light under a held side. When a game
## starts, `show_hint()` marks the two areas for a few seconds: tinted panels
## with an arrow and the flipper's name, and a line of text above them.
extends Control

const UI = preload("res://core/ui/ui.gd")

const HINT_SECONDS := 4.0
const FADE := 0.5
const TINT := Color(0.2, 0.55, 1.0)

var hint := 0.0:              # 0 hidden .. 1 shown
	set(v):
		hint = v
		_place()
		queue_redraw()
var _held := [0.0, 0.0]       # left, right: 0..1
var _want := [false, false]
var _labels: Array[Label] = []
var _message: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["TOUCH_LEFT", "TOUCH_RIGHT"]:
		var l := UI.label(tr(key), 48, UI.WHITE)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_labels.append(l)
	_message = UI.label(tr("TOUCH_HINT"), 24, UI.WHITE)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	resized.connect(_place)
	_place()


## Shows the areas for a few seconds, then fades them out.
func show_hint() -> void:
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		return
	_tween = create_tween()
	_tween.tween_property(self, "hint", 1.0, 0.25)
	_tween.tween_interval(HINT_SECONDS)
	_tween.tween_property(self, "hint", 0.0, FADE)


## A side is held (0 left, 1 right): it glows faintly, and the hint goes.
func set_held(side: int, on: bool) -> void:
	_want[side] = on
	set_process(true)
	if on and hint > 0.0 and (_tween == null or not _tween.is_running() or hint >= 1.0):
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_interval(0.6)
		_tween.tween_property(self, "hint", 0.0, FADE)


func _process(delta: float) -> void:
	var busy := false
	for i in 2:
		var to := 1.0 if _want[i] else 0.0
		if not is_equal_approx(_held[i], to):
			_held[i] = move_toward(_held[i], to, delta / (0.05 if _want[i] else 0.2))
			busy = true
	queue_redraw()
	if not busy:
		set_process(false)


func _side(i: int) -> Rect2:
	return Rect2(size.x * 0.5 * i, size.y * 0.5, size.x * 0.5, size.y * 0.5)


func _place() -> void:
	if _message == null:
		return
	var short := minf(size.x, size.y)
	var big := UI.pixel_size(int(short * 0.07))
	var small := UI.pixel_size(int(short * 0.035))
	for i in 2:
		var r := _side(i)
		var l := _labels[i]
		l.add_theme_font_override("font", UI.DotText.font(big))
		l.add_theme_font_size_override("font_size", big)
		l.size = Vector2(r.size.x, big * 1.4)
		l.position = Vector2(r.position.x, r.get_center().y + short * 0.07)
		l.modulate.a = hint
	_message.add_theme_font_override("font", UI.DotText.font(small))
	_message.add_theme_font_size_override("font_size", small)
	_message.size = Vector2(size.x * 0.9, small * 3.0)
	_message.position = Vector2(size.x * 0.05, size.y * 0.5 - small * 3.4)
	_message.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_message.modulate.a = hint


func _draw() -> void:
	var short := minf(size.x, size.y)
	if hint > 0.0:   # a dark band behind the message
		var band := Rect2(_message.position, _message.size).grow_individual(0, -_message.size.y * 0.45, 0, short * 0.012)
		draw_rect(band, Color(0.0, 0.0, 0.05, 0.6 * hint))
	for i in 2:
		var r := _side(i)
		# In play: only a faint light rising from the bottom of a held side.
		if _held[i] > 0.0:
			var h := r.size.y * 0.45
			var pts := PackedVector2Array([Vector2(r.position.x, r.end.y - h), Vector2(r.end.x, r.end.y - h),
				r.end, Vector2(r.position.x, r.end.y)])
			var clear := Color(TINT, 0.0)
			var lit := Color(TINT, 0.16 * _held[i])
			draw_polygon(pts, PackedColorArray([clear, clear, lit, lit]))
		if hint <= 0.0:
			continue
		var gap := short * 0.012
		var box := r.grow(-gap)
		draw_rect(box, Color(0.03, 0.08, 0.22, 0.5 * hint))   # dark glass, so the white reads on any scene
		draw_rect(box, Color(TINT, 0.12 * hint))
		draw_rect(box, Color(TINT.lightened(0.4), 0.75 * hint), false, maxf(2.0, short * 0.006))
		# A big arrowhead pointing outwards.
		var k := -1.0 if i == 0 else 1.0
		var o := r.get_center() - Vector2(0, short * 0.04)
		var s := short * 0.07
		var arrow := PackedVector2Array([o + Vector2(0.9 * k, 0.0) * s, o + Vector2(-0.5 * k, -1.0) * s,
			o + Vector2(-0.12 * k, 0.0) * s, o + Vector2(-0.5 * k, 1.0) * s])
		draw_colored_polygon(arrow, Color(1, 1, 1, 0.9 * hint))
