## Per-game styled pixel title fonts (D-062). Builds a fixed-size bitmap FontFile
## from assets/fonts/title_<name>.png + .json (made by scripts/tools/
## gen_title_fonts.py). Colours are baked into the RGBA atlas; the font only
## scales by whole multiples (crisp pixels). Use UI.styled_label().
extends RefCounted

static var _cache := {}


## `tabular` (D-500): the digits 0-9 all take the widest digit's advance, each
## centred in it, so a changing number keeps its width and place.
static func get_font(style: String, tabular: bool = false) -> FontFile:
	var cache_key := style + (":tabular" if tabular else "")
	if _cache.has(cache_key):
		return _cache[cache_key]
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fonts/title_%s.json" % style))
	var tex := load("res://assets/fonts/title_%s.png" % style) as Texture2D
	if meta == null or tex == null:
		push_warning("StyledFonts: missing title font '%s'" % style)
		return null
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)  # RGBA8 = colour glyphs (not tinted by font_color)
	var size := int(meta.size)
	var key := Vector2i(size, 0)
	var f := FontFile.new()
	f.fixed_size = size
	# D-354: a "smooth" font is painted art (not pixels): it scales freely, from
	# mipmaps, and is sized by its "display_size" (styled_label's scale 1).
	var smooth: bool = meta.get("smooth", false)
	if smooth:
		img.generate_mipmaps()
		f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.set_meta("display_size", int(meta.get("display_size", size)))
		f.set_meta("smooth", true)
	elif meta.get("pixel", false):
		# D-384: pixel art drawn 1:1 on a low-resolution canvas whose scale
		# isn't a whole number: sized freely, never filtered.
		f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	else:
		f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	# Marks it lacks come from the game's old pixel font.
	if meta.has("fallback"):
		var fb := get_font(str(meta.fallback))
		if fb != null:
			f.fallbacks = [fb]
	f.set_texture_image(0, key, 0, img)
	f.set_cache_ascent(0, size, float(meta.ascent))
	f.set_cache_descent(0, size, float(meta.descent))
	var space := 32
	f.set_glyph_advance(0, size, space, Vector2(float(meta.space), 0))
	f.set_glyph_size(0, key, space, Vector2.ZERO)
	f.set_glyph_texture_idx(0, key, space, -1)
	var digit_adv := 0.0
	if tabular:
		for g in meta.glyphs:
			if int(g.code) >= 48 and int(g.code) <= 57:
				digit_adv = maxf(digit_adv, float(g.adv))
	for g in meta.glyphs:
		var code := int(g.code)
		var adv := float(g.adv)
		var shift := 0.0
		if tabular and code >= 48 and code <= 57:
			shift = floorf((digit_adv - adv) * 0.5)
			adv = digit_adv
		f.set_glyph_advance(0, size, code, Vector2(adv, 0))
		f.set_glyph_offset(0, key, code, Vector2(shift, -float(meta.ascent) + float(g.get("dy", 0.0))))   # D-536: "dy" moves one glyph up (-) or down
		f.set_glyph_size(0, key, code, Vector2(float(g.w), float(g.h)))
		f.set_glyph_uv_rect(0, key, code, Rect2(float(g.x), float(g.y), float(g.w), float(g.h)))
		f.set_glyph_texture_idx(0, key, code, 0)
	_cache[cache_key] = f
	return f
