## Dmd autoload: owns the DMD content viewport at true dot resolution (default 128x32).
## Full-colour (D-026): every dot shows one colour. Games may draw anything 2D into
## `viewport`, or use the text API below (built-in 5x7 dot font, D-027).
## Output sinks: window/backglass (Screens + dmd_dots.gdshader) or hardware (stub, M5).
extends Node

const HardwareSink = preload("res://core/dmd/hardware_sink.gd")
const DotFont = preload("res://core/dmd/dot_font.gd")
const ScoreTable = preload("res://core/util/score_table.gd")

## Shared DMD palette so all games feel like one machine.
const ORANGE := Color("ff7319")
const YELLOW := Color("ffd23e")
const CYAN := Color("3ec7ff")
const RED := Color("ff3b4f")
const GREEN := Color("4fff7a")
const WHITE := Color("ffffff")
const DIM := Color("8a8a8a")

var viewport: SubViewport
var size := Vector2i(128, 32)
## Default text colour (dmd.color); in mono mode the shader tints everything with it.
var color := ORANGE
var mono := false
var _canvas: Control
var _hardware: RefCounted
var _elements: Array = []  # Dictionaries: text, y, scale, align, color
var _overlay: Array = []
var _overlay_left := 0.0
var _time := 0.0
var _unit := 1  # font scale multiplier for larger DMDs (64 dots high -> 2)
var _anim := Callable()
var _anim_t := 0.0
var _anim_len := 0.0
var _painter: Painter


func _ready() -> void:
	size = Vector2i(int(Config.get_value("dmd", "width")), int(Config.get_value("dmd", "height")))
	color = Color(str(Config.get_value("dmd", "color")))
	mono = bool(Config.get_value("dmd", "mono"))
	_unit = maxi(1, size.y / 32)
	viewport = SubViewport.new()
	viewport.name = "DmdViewport"
	viewport.size = size
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(bg)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_on_draw)
	viewport.add_child(_canvas)
	_painter = Painter.new()
	_painter.canvas = _canvas
	_painter.unit = _unit
	_painter.width = size.x / _unit
	_painter.height = size.y / _unit

	if str(Config.get_value("display", "dmd_sink")) == "hardware":
		_hardware = HardwareSink.new(
			str(Config.get_value("dmd", "hardware_host")),
			int(Config.get_value("dmd", "hardware_port")))


# --- public API ------------------------------------------------------------------
func clear() -> void:
	_elements = []


## One line: big if it fits, otherwise small (scrolling if still too long).
## Two lines: both small. Colours default to the DMD colour.
func show_text(top: String, bottom: String = "", top_color: Variant = null, bottom_color: Variant = null) -> void:
	var c1: Color = top_color if top_color != null else color
	var c2: Color = bottom_color if bottom_color != null else color
	if bottom.is_empty():
		var s := _unit * 2 if DotFont.measure(top, _unit * 2) <= size.x - 4 else _unit
		_elements = [_el(top, (size.y - DotFont.H * s) / 2, s, "center", c1)]
	else:
		var s := _unit
		var gap := 4 * s
		var y1 := (size.y - (DotFont.H * 2 * s + gap)) / 2
		_elements = [_el(top, y1, s, "center", c1), _el(bottom, y1 + DotFont.H * s + gap, s, "center", c2)]


## Big score on top, optional small left/right info on the bottom row.
func show_score(score: int, left: String = "", right: String = "", score_color: Variant = null) -> void:
	var txt := ScoreTable.format_score(score)
	var big := _unit * 2
	var s := big if DotFont.measure(txt, big) <= size.x - 4 else _unit
	var c: Color = score_color if score_color != null else color
	_elements = [_el(txt, 2 * _unit, s, "center", c)]
	var y := size.y - (DotFont.H + 2) * _unit
	if not left.is_empty():
		_elements.append(_el(left, y, _unit, "left", DIM))
	if not right.is_empty():
		_elements.append(_el(right, y, _unit, "right", DIM))


## Shows a pixel-art image (e.g. a game logo, D-063) centred on the DMD,
## optionally with a small text line at the bottom.
func show_image(tex: Texture2D, bottom: String = "", bottom_color: Variant = null) -> void:
	var y := 0
	if not bottom.is_empty():
		y = maxi(0, (size.y - 9 * _unit - tex.get_height() * _unit) / 2)
	_elements = [{"type": "image", "tex": tex, "y": y}]
	if not bottom.is_empty():
		var c: Color = bottom_color if bottom_color != null else color
		_elements.append(_el(bottom, size.y - 8 * _unit, _unit, "center", c))


## Game status for games that keep the TABLE clean (D-051): big score on top;
## bottom row = `lives` plasma dots (out of `max_lives`, spent ones dim) on the
## left, and a segmented power bar (0..1, `segments` cells) on the right.
func show_status(score: int, lives: int, max_lives: int, power: float, segments: int = 3,
		score_color: Variant = null, power_color: Variant = null) -> void:
	show_score(score, "", "", score_color)
	var y := size.y - 7 * _unit
	_elements.append({"type": "lives", "y": y, "lives": lives, "max": max_lives,
		"color": CYAN})
	_elements.append({"type": "bar", "y": y + _unit, "value": clampf(power, 0.0, 1.0),
		"segments": segments, "color": power_color if power_color != null else YELLOW})


## Temporary blinking callout over whatever is shown (e.g. "MULTIBALL!").
func flash(text: String, duration: float = 1.5, flash_color: Variant = null) -> void:
	var c: Color = flash_color if flash_color != null else YELLOW
	var s := _unit * 2 if DotFont.measure(text, _unit * 2) <= size.x - 4 else _unit
	_overlay = [_el(text, (size.y - DotFont.H * s) / 2, s, "center", c)]
	_overlay_left = duration


func texture() -> Texture2D:
	return viewport.get_texture()


## Short pixel animation over everything else (D-056). `anim` is called every
## frame as anim.call(painter: Dmd.Painter, t: float) with t = seconds since start;
## it draws in logical 128x32 dot coordinates. A new animation replaces the
## current one.
func play(anim: Callable, duration: float) -> void:
	_anim = anim
	_anim_t = 0.0
	_anim_len = duration


func is_animating() -> bool:
	return _anim.is_valid()


## Drawing helpers handed to DMD animations (logical dots; scaled for big DMDs).
class Painter:
	extends RefCounted

	var canvas: CanvasItem
	var unit := 1
	var width := 128
	var height := 32

	func dot(x: float, y: float, c: Color) -> void:
		var ix := floori(x)
		var iy := floori(y)
		if ix < 0 or iy < 0 or ix >= width or iy >= height:
			return
		canvas.draw_rect(Rect2(ix * unit, iy * unit, unit, unit), c)

	func line(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
		var steps := maxi(1, ceili(maxf(absf(x1 - x0), absf(y1 - y0))))
		for i in steps + 1:
			var t := float(i) / steps
			dot(roundf(lerpf(x0, x1, t)), roundf(lerpf(y0, y1, t)), c)

	func disc(cx: float, cy: float, r: float, c: Color) -> void:
		var ir := ceili(r)
		for dy in range(-ir, ir + 1):
			for dx in range(-ir, ir + 1):
				if dx * dx + dy * dy <= r * r + 0.3:
					dot(cx + dx, cy + dy, c)

	func ring(cx: float, cy: float, r: float, c: Color, y_scale: float = 1.0) -> void:
		var steps := maxi(8, ceili(r * 7.0))
		for i in steps:
			var a := TAU * i / steps
			dot(roundf(cx + cos(a) * r), roundf(cy + sin(a) * r * y_scale), c)

	func text(s: String, x: float, y: float, scale: int, c: Color) -> void:
		DotFont.draw(canvas, s, Vector2(floorf(x) * unit, floorf(y) * unit), scale * unit, c)

	func text_center(s: String, y: float, scale: int, c: Color) -> void:
		text(s, (width - DotFont.measure(s, scale)) / 2.0, y, scale, c)

	## Draws a pixel-art texture with its top-left at (x, y) dots.
	func image(tex: Texture2D, x: float, y: float, modulate: Color = Color.WHITE) -> void:
		canvas.draw_texture_rect(tex, Rect2(floorf(x) * unit, floorf(y) * unit,
			tex.get_width() * unit, tex.get_height() * unit), false, modulate)

	func text_width(s: String, scale: int = 1) -> int:
		return DotFont.measure(s, scale)


# --- internals ---------------------------------------------------------------------
func _el(text: String, y: int, scale: int, align: String, c: Color) -> Dictionary:
	return {"text": text, "y": y, "scale": scale, "align": align, "color": c}


func _process(delta: float) -> void:
	_time += delta
	if _overlay_left > 0.0:
		_overlay_left -= delta
		if _overlay_left <= 0.0:
			_overlay = []
	if _anim.is_valid():
		_anim_t += delta
		if _anim_t >= _anim_len:
			_anim = Callable()
	_canvas.queue_redraw()
	if _hardware != null:
		_hardware.send_frame(viewport.get_texture().get_image())


func _on_draw() -> void:
	if _anim.is_valid():
		_anim.call(_painter, _anim_t)
		return
	var list := _elements
	if not _overlay.is_empty():
		if fmod(_time, 0.4) < 0.12:
			return  # blink off-phase
		list = _overlay
	for el in list:
		match el.get("type", "text"):
			"lives":
				_draw_lives(el)
				continue
			"bar":
				_draw_bar(el)
				continue
			"image":
				var tex: Texture2D = el.tex
				var sz := tex.get_size() * _unit
				_canvas.draw_texture_rect(tex, Rect2(Vector2(floorf((size.x - sz.x) / 2.0), el.y), sz), false)
				continue
		var w := DotFont.measure(el.text, el.scale)
		var x := 0.0
		if w > size.x - 4:
			# Marquee for text that does not fit (long translations, etc.).
			x = size.x - fmod(_time * 40.0 * _unit, float(w + size.x))
		else:
			match el.align:
				"left":
					x = 2 * _unit
				"right":
					x = size.x - w - 2 * _unit
				_:
					x = floorf((size.x - w) / 2.0)
		DotFont.draw(_canvas, el.text, Vector2(x, el.y), el.scale, el.color)


## Plasma-ball dots: 5x5 rounded pixels with a white core (spent = dim outline).
func _draw_lives(el: Dictionary) -> void:
	var u := _unit
	const DOT := ["01110", "11111", "11111", "11111", "01110"]
	for i in int(el.max):
		var x0 := 2 * u + i * 7 * u
		var alive := i < int(el.lives)
		for r in 5:
			for c in 5:
				if DOT[r][c] == "0":
					continue
				var edge := r == 0 or r == 4 or c == 0 or c == 4
				var col: Color
				if alive:
					col = Color.WHITE if (r == 2 and c == 2) else el.color
				else:
					if not edge:
						continue
					col = el.color * 0.35
				_canvas.draw_rect(Rect2(x0 + c * u, el.y + r * u, u, u), col)


## Segmented power bar anchored to the right edge; the partly filled cell blinks
## while recharging.
func _draw_bar(el: Dictionary) -> void:
	var u := _unit
	var segs := int(el.segments)
	var cell_w := 12 * u
	var gap := 2 * u
	var h := 4 * u
	var total := segs * cell_w + (segs - 1) * gap
	var x0 := size.x - 2 * u - total
	var filled: float = float(el.value) * segs
	for i in segs:
		var x := x0 + i * (cell_w + gap)
		var r := Rect2(x, el.y, cell_w, h)
		_canvas.draw_rect(r, el.color * 0.25)  # empty cell
		var f := clampf(filled - i, 0.0, 1.0)
		if f >= 1.0:
			_canvas.draw_rect(r, el.color)
		elif f > 0.0:
			var w := floorf(cell_w * f / u) * u
			var c: Color = el.color * (0.55 if fmod(_time, 0.6) < 0.3 else 0.8)
			_canvas.draw_rect(Rect2(x, el.y, w, h), c)
