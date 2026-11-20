## Dmd autoload: owns the DMD content viewport at true dot resolution (e.g. 128x32).
## Games draw anything 2D into `viewport` (or use show_text). Outputs ("sinks"):
##   window/backglass -> Screens displays `texture()` through dmd_dots.gdshader
##   hardware         -> HardwareSink streams frames to libdmdutil's dmdserver (stub, M5)
extends Node

const HardwareSink = preload("res://core/dmd/hardware_sink.gd")

var viewport: SubViewport
var size := Vector2i(128, 32)
var color := Color("ff7319")
var _label_top: Label
var _label_bottom: Label
var _content: VBoxContainer
var _hardware: RefCounted


func _ready() -> void:
	size = Vector2i(int(Config.get_value("dmd", "width")), int(Config.get_value("dmd", "height")))
	color = Color(str(Config.get_value("dmd", "color")))
	viewport = SubViewport.new()
	viewport.name = "DmdViewport"
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(bg)

	# Built-in two-line text layer (placeholder until a pixel font asset exists).
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 0)
	viewport.add_child(_content)
	_label_top = _make_label()
	_label_bottom = _make_label()

	if str(Config.get_value("display", "dmd_sink")) == "hardware":
		_hardware = HardwareSink.new(
			str(Config.get_value("dmd", "hardware_host")),
			int(Config.get_value("dmd", "hardware_port")))


func _make_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(8, size.y / 3))
	l.add_theme_color_override("font_color", Color.WHITE)
	_content.add_child(l)
	return l


## Shows one or two lines of (already translated) text.
func show_text(top: String, bottom: String = "") -> void:
	_label_top.text = top
	_label_bottom.text = bottom
	_label_bottom.visible = not bottom.is_empty()


func texture() -> Texture2D:
	return viewport.get_texture()


func _process(_delta: float) -> void:
	if _hardware != null:
		_hardware.send_frame(viewport.get_texture().get_image())
