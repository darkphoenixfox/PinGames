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


## Temporary blinking callout over whatever is shown (e.g. "MULTIBALL!").
func flash(text: String, duration: float = 1.5, flash_color: Variant = null) -> void:
	var c: Color = flash_color if flash_color != null else YELLOW
	var s := _unit * 2 if DotFont.measure(text, _unit * 2) <= size.x - 4 else _unit
	_overlay = [_el(text, (size.y - DotFont.H * s) / 2, s, "center", c)]
	_overlay_left = duration


func texture() -> Texture2D:
	return viewport.get_texture()


# --- internals ---------------------------------------------------------------------
func _el(text: String, y: int, scale: int, align: String, c: Color) -> Dictionary:
	return {"text": text, "y": y, "scale": scale, "align": align, "color": c}


func _process(delta: float) -> void:
	_time += delta
	if _overlay_left > 0.0:
		_overlay_left -= delta
		if _overlay_left <= 0.0:
			_overlay = []
	_canvas.queue_redraw()
	if _hardware != null:
		_hardware.send_frame(viewport.get_texture().get_image())


func _on_draw() -> void:
	var list := _elements
	if not _overlay.is_empty():
		if fmod(_time, 0.4) < 0.12:
			return  # blink off-phase
		list = _overlay
	for el in list:
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
