## Shared UI helpers and palette for shell screens (picker, attract, operator...).
## Text sizes assume base coordinates (TABLE 1080x1920, BACKGLASS 1920x1080) and
## must stay readable at cabinet distance (GDD pillar 4).
extends RefCounted

const StyledFonts = preload("res://core/ui/styled_fonts.gd")
const DotText = preload("res://core/ui/dot_text.gd")

const YELLOW := Color("ffd23e")
const CYAN := Color("3ec7ff")
const RED := Color("ff4f6d")
const GREEN := Color("4fff7a")
const WHITE := Color("ffffff")
const GREY := Color(0.55, 0.55, 0.6)
const DARK := Color(0.04, 0.04, 0.08)


## PinPixel (D-060) has 1 font pixel = size/12 screen pixels; sizes are snapped
## to multiples of 12 so every font pixel lands on whole screen pixels.
static func pixel_size(size: int) -> int:
	return maxi(12, roundi(size / 12.0) * 12)


static func label(text: String, size: int, color: Color = WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	var ps := pixel_size(size)
	# D-232: dot-matrix lettering (the DMD's font as dots; its dark rim is the
	# outline). `dot_size` lets a low-res canvas swap in its own version (D-233).
	l.add_theme_font_override("font", DotText.font(ps))
	l.add_theme_font_size_override("font_size", ps)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.set_meta("dot_size", ps)
	return l


## Label in a per-game styled title font (D-062): colours are baked into the
## font, so no tint/outline; `scale` is the whole-number pixel multiple.
## The shell's own styled fonts (D-186): gold marquee for titles and prompts,
## silver chrome for headings, scores and status lines.
const SHELL_TITLE_FONT := "marquee"
const SHELL_TEXT_FONT := "chrome"
## The shell's own logo (D-490: the director's VPin Games logo), shown where
## the title text was. scripts/tools/prepare_shell_logo.py makes it.
const SHELL_LOGO := "res://assets/textures/shell/logo.png"


## The shell logo `height` px tall (base coordinates), keeping its shape.
static func shell_logo(height: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(SHELL_LOGO)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(0, height)
	return r


## `tabular` (D-500): fixed-width digits, for numbers that change on screen.
static func styled_label(text: String, style: String, scale: int = 2,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, tabular: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	var f: FontFile = StyledFonts.get_font(style, tabular)
	if f == null:
		return label(text, 48 * scale, WHITE, align)
	l.add_theme_font_override("font", f)
	# D-354: smooth (painted) fonts are sized by their display size and filtered.
	var unit: int = int(f.get_meta("display_size", f.fixed_size))
	l.add_theme_font_size_override("font_size", unit * maxi(1, scale))
	if f.has_meta("smooth"):
		l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		l.set_meta("smooth_font", true)   # D-382: a game may redraw it hard-edged
		l.set_meta("styled", [style, maxi(1, scale), tabular])   # D-384: or swap in a pixel version
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 0)
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
