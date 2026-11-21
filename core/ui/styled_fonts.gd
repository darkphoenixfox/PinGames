## Per-game styled pixel title fonts (D-062). Builds a fixed-size bitmap FontFile
## from assets/fonts/title_<name>.png + .json (made by scripts/tools/
## gen_title_fonts.py). Colours are baked into the RGBA atlas; the font only
## scales by whole multiples (crisp pixels). Use UI.styled_label().
extends RefCounted

static var _cache := {}


static func get_font(style: String) -> FontFile:
	if _cache.has(style):
		return _cache[style]
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
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.set_texture_image(0, key, 0, img)
	f.set_cache_ascent(0, size, float(meta.ascent))
	f.set_cache_descent(0, size, float(meta.descent))
	var space := 32
	f.set_glyph_advance(0, size, space, Vector2(float(meta.space), 0))
	f.set_glyph_size(0, key, space, Vector2.ZERO)
	f.set_glyph_texture_idx(0, key, space, -1)
	for g in meta.glyphs:
		var code := int(g.code)
		f.set_glyph_advance(0, size, code, Vector2(float(g.adv), 0))
		f.set_glyph_offset(0, key, code, Vector2(0, -float(meta.ascent)))
		f.set_glyph_size(0, key, code, Vector2(float(g.w), float(g.h)))
		f.set_glyph_uv_rect(0, key, code, Rect2(float(g.x), float(g.y), float(g.w), float(g.h)))
		f.set_glyph_texture_idx(0, key, code, 0)
	_cache[style] = f
	return f
