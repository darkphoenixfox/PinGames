## Dot-matrix lettering for the on-screen UI (D-232): the DMD's 5x7 dot font
## (core/dmd/dot_font.gd) turned into real bitmap fonts at any size, built at
## run time and cached, so every Label can use it.
##
## Each glyph bit is drawn as dots on a grid:
## - small text: one round dot per bit (single-dot strokes);
## - big text (DENSE_FROM and up): 2x2 smaller dots per bit (heavier density);
## - low-resolution canvases (`px` < 1, the 8-BIT/16-BIT UI, D-233): crisp
##   square pixels when a bit is only 1-2 target pixels, dots when there's room.
## Every dot has a dark rim (an outline baked in), so text reads over a bright
## scene; the label's font colour tints the dots and leaves the rim dark.
## Metrics are in base pixels (TABLE 1080x1920 etc.); the glyph images are in
## target pixels (`px` per base pixel), so a low-res font stays pixel-exact.
extends RefCounted

const DotFont = preload("res://core/dmd/dot_font.gd")
const FALLBACK := "res://assets/fonts/pinpixel.ttf"
const CAP := 0.72          # cap height as a share of the font size
const DENSE_FROM := 60     # font sizes from here get 2x2 dots per bit
const RIM := Color(0.02, 0.02, 0.04, 0.85)

## A 3x5 pixel font for the smallest low-resolution text (D-233), where the
## 5x7 at one pixel per bit would be too big for its space.
const MICRO := {
	"A": "010 101 111 101 101", "B": "110 101 110 101 110", "C": "011 100 100 100 011",
	"D": "110 101 101 101 110", "E": "111 100 110 100 111", "F": "111 100 110 100 100",
	"G": "011 100 101 101 011", "H": "101 101 111 101 101", "I": "111 010 010 010 111",
	"J": "001 001 001 101 010", "K": "101 101 110 101 101", "L": "100 100 100 100 111",
	"M": "101 111 111 101 101", "N": "110 101 101 101 101", "O": "010 101 101 101 010",
	"P": "110 101 110 100 100", "Q": "010 101 101 110 011", "R": "110 101 110 101 101",
	"S": "011 100 010 001 110", "T": "111 010 010 010 010", "U": "101 101 101 101 111",
	"V": "101 101 101 101 010", "W": "101 101 111 111 101", "X": "101 101 010 101 101",
	"Y": "101 101 010 010 010", "Z": "111 001 010 100 111",
	"0": "111 101 101 101 111", "1": "010 110 010 010 111", "2": "110 001 010 100 111",
	"3": "110 001 010 001 110", "4": "101 101 111 001 001", "5": "111 100 110 001 110",
	"6": "011 100 111 101 111", "7": "111 001 010 010 010", "8": "111 101 111 101 111",
	"9": "111 101 111 001 110",
	" ": "000 000 000 000 000", ".": "000 000 000 000 010", ",": "000 000 000 010 100",
	":": "000 010 000 010 000", "!": "010 010 010 000 010", "?": "110 001 010 000 010",
	"-": "000 000 111 000 000", "+": "000 010 111 010 000", "/": "001 001 010 100 100",
	"%": "101 001 010 100 101", "'": "010 010 000 000 000", "(": "001 010 010 010 001",
	")": "100 010 010 010 100", "<": "001 010 100 010 001", ">": "100 010 001 010 100",
	"=": "000 111 000 111 000", "#": "101 111 101 111 101", "_": "000 000 000 000 111",
	"*": "000 101 010 101 000", "&": "010 101 010 101 011",
}

static var _cache := {}


## The font for a label of base size `size` on a canvas drawn at `px` target
## pixels per base pixel. Use it with font_size = `size`.
static func font(size: int, px: float = 1.0) -> FontFile:
	var key := "%d@%.3f" % [size, px]
	if _cache.has(key):
		return _cache[key]
	var f := _build(size, px)
	_cache[key] = f
	return f


static func _build(size: int, px: float) -> FontFile:
	var low := px < 0.99
	var cap_px := size * CAP * px                 # cap height in target pixels
	# The glyph set: the DMD's 5x7, or the 3x5 for tiny low-res text (D-233).
	var micro := low and cap_px < 6.3
	var GW := 3 if micro else DotFont.W
	var GH := 5 if micro else DotFont.H
	var GADV := 4 if micro else DotFont.ADVANCE
	var glyph := func(ch: String) -> PackedInt32Array:
		if not micro:
			return DotFont._glyph(ch)
		var rows := PackedInt32Array()
		for r in str(MICRO.get(ch, MICRO[" "])).split(" "):
			rows.append(r.bin_to_int())
		return rows
	var sub := 1                                  # dots per bit, per axis
	var b: int                                    # target pixels per glyph bit
	if not low and size >= DENSE_FROM:
		sub = 2
		b = maxi(4, int(cap_px / 14.0) * 2)
	else:
		# Rounded down, so text is never wider than the old font's (layouts fit).
		b = 1 if micro else maxi(1 if low else 2, int(cap_px / 7.0))
	var pad := 1 if (low and b <= 2) else maxi(1, b / sub / 3)
	var gw := GW * b + pad * 2
	var gh := GH * b + pad * 2
	# All glyphs in one atlas row per 16.
	var chars: Array = MICRO.keys() if micro else DotFont.GLYPHS.keys()
	var cols := 16
	var rows := int(ceil(chars.size() / float(cols)))
	var atlas := Image.create(maxi(1, cols * gw), maxi(1, rows * gh), false, Image.FORMAT_RGBA8)
	var cells := {}
	for i in chars.size():
		var ch: String = chars[i]
		var ox := (i % cols) * gw
		var oy := (i / cols) * gh
		_draw_glyph(atlas, glyph.call(ch), ox + pad, oy + pad, b, sub, low, GW, GH)
		cells[ch] = Rect2(ox, oy, gw, gh)
	var s := 1.0 / px                             # base pixels per target pixel
	var f := FontFile.new()
	f.fixed_size = size
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_DISABLE
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var sz := Vector2i(size, 0)
	var asc := (GH * b + pad) * s + size * 0.12
	var desc := size * 0.28
	f.set_cache_ascent(0, size, asc)
	f.set_cache_descent(0, size, desc)
	f.set_texture_image(0, sz, 0, atlas)
	var adv := (GADV * b) * s
	for ch in chars:
		var r: Rect2 = cells[ch]
		var codes := [ch.unicode_at(0)]
		if ch.to_lower() != ch:
			codes.append(ch.to_lower().unicode_at(0))   # lower case shows as capitals
		for code in codes:
			f.set_glyph_advance(0, size, code, Vector2(adv, 0.0))
			f.set_glyph_offset(0, sz, code, Vector2(-pad * s, -(GH * b + pad) * s))
			f.set_glyph_size(0, sz, code, r.size * s)
			f.set_glyph_uv_rect(0, sz, code, r)
			f.set_glyph_texture_idx(0, sz, code, 0)
	for fold in DotFont.FOLD:   # accented letters fold to their base letter
		var base: String = DotFont.FOLD[fold]
		if cells.has(base):
			var r2: Rect2 = cells[base]
			for code in [fold.unicode_at(0), fold.to_lower().unicode_at(0)]:
				f.set_glyph_advance(0, size, code, Vector2(adv, 0.0))
				f.set_glyph_offset(0, sz, code, Vector2(-pad * s, -(GH * b + pad) * s))
				f.set_glyph_size(0, sz, code, r2.size * s)
				f.set_glyph_uv_rect(0, sz, code, r2)
				f.set_glyph_texture_idx(0, sz, code, 0)
	var fb := load(FALLBACK) as Font
	if fb != null:
		f.fallbacks = [fb]
	return f


## One glyph into the atlas at (x0, y0): its bits as dots (or pixels), with
## the dark rim drawn first underneath.
static func _draw_glyph(img: Image, rows: PackedInt32Array, x0: int, y0: int, b: int, sub: int, low: bool,
		gw: int = 5, gh: int = 7) -> void:
	var on := func(c: int, r: int) -> bool:
		return r >= 0 and r < gh and c >= 0 and c < gw and (rows[r] & (1 << (gw - 1 - c))) != 0
	if low and b <= 2:
		# Crisp pixels: each bit a b x b block, a 1 px dark outline round them.
		for r in gh:
			for c in gw:
				if not on.call(c, r):
					continue
				for yy in range(-1, b + 1):
					for xx in range(-1, b + 1):
						var px := x0 + c * b + xx
						var py := y0 + r * b + yy
						if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height() \
								and img.get_pixel(px, py).a == 0.0:
							img.set_pixel(px, py, RIM)
		for r in gh:
			for c in gw:
				if on.call(c, r):
					img.fill_rect(Rect2i(x0 + c * b, y0 + r * b, b, b), Color.WHITE)
		return
	var d := float(b) / sub                    # dot pitch in target pixels
	for pass_i in 2:                           # rim first, then the dots
		for r in gh:
			for c in gw:
				if not on.call(c, r):
					continue
				for sy in sub:
					for sx in sub:
						var cx := x0 + c * b + (sx + 0.5) * d
						var cy := y0 + r * b + (sy + 0.5) * d
						var rad := d * (0.64 if pass_i == 0 else 0.45)
						if low:
							rad = d * (0.6 if pass_i == 0 else 0.42)
						_disc(img, cx, cy, rad, RIM if pass_i == 0 else Color.WHITE, not low)


## A filled disc, anti-aliased by 4x4 supersampling (or hard-edged).
static func _disc(img: Image, cx: float, cy: float, rad: float, col: Color, smooth: bool) -> void:
	for y in range(int(floor(cy - rad - 1.0)), int(ceil(cy + rad + 1.0))):
		for x in range(int(floor(cx - rad - 1.0)), int(ceil(cx + rad + 1.0))):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var cov := 0.0
			if smooth:
				for sy in 4:
					for sx in 4:
						var dx := x + (sx + 0.5) / 4.0 - cx
						var dy := y + (sy + 0.5) / 4.0 - cy
						if dx * dx + dy * dy <= rad * rad:
							cov += 1.0 / 16.0
			else:
				var dx2 := x + 0.5 - cx
				var dy2 := y + 0.5 - cy
				cov = 1.0 if dx2 * dx2 + dy2 * dy2 <= rad * rad else 0.0
			if cov <= 0.0:
				continue
			var under := img.get_pixel(x, y)
			var a := col.a * cov
			var out_a := a + under.a * (1.0 - a)
			if out_a <= 0.0:
				continue
			var rgb := (Color(col.r, col.g, col.b) * a + Color(under.r, under.g, under.b) * under.a * (1.0 - a)) / out_a
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, out_a))
