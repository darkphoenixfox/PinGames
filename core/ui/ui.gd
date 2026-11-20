## Shared UI helpers and palette for shell screens (picker, attract, operator...).
## Text sizes assume base coordinates (TABLE 1080x1920, BACKGLASS 1920x1080) and
## must stay readable at cabinet distance (GDD pillar 4).
extends RefCounted

const YELLOW := Color("ffd23e")
const CYAN := Color("3ec7ff")
const RED := Color("ff4f6d")
const GREEN := Color("4fff7a")
const WHITE := Color("ffffff")
const GREY := Color(0.55, 0.55, 0.6)
const DARK := Color(0.04, 0.04, 0.08)


static func label(text: String, size: int, color: Color = WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(4, size / 10))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l


static func fill(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


## Full-rect vertical stack, content centred.
static func vstack(separation: int = 24) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", separation)
	return v


static func spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func set_color(l: Label, color: Color) -> void:
	l.add_theme_color_override("font_color", color)
