## TURBO RUN radio (D-301): the music select screen's 90s car stereo, drawn
## flat in 16-bit pixel style (chunky shapes, a small palette, hard edges).
## Speaker grilles left and right; a dark LCD with the song title scrolling in
## dot-matrix text over a 12-band graphic equaliser; a backlit tuning dial with
## a red needle that slides to the station; five preset buttons; VOL and TUNE
## knobs. Drawn in the UI layer, so 8-BIT/16-BIT get real pixels.
## The equaliser follows `spectrum` (12 values 0..1, e.g. from a spectrum
## analyser on the music bus); when that gives nothing (web), it dances on its own.
extends Control

const UI = preload("res://core/ui/ui.gd")

const W := 1000.0
const H := 500.0
const BANDS := 12
const SEGS := 10
const FREQ_MIN := 87.5
const FREQ_MAX := 108.5

# Palette
const OUTLINE := Color("07080a")
const BODY := Color("23262e")
const BODY_HI := Color("3b404c")
const BODY_LO := Color("15171c")
const CHROME := Color("9aa3b3")
const CHROME_HI := Color("d8dee8")
const LCD_BG := Color("0a1317")
const LCD_LINE := Color("0f1d22")
const LCD_TEXT := Color("5ff2ff")
const AMBER := Color("ffb347")
const NEEDLE := Color("ff3b2f")
const DIAL_FACE := Color("e9ddbf")
const DIAL_INK := Color("3a2f25")
const EQ_GREEN := Color("4fff7a")
const EQ_YELLOW := Color("ffd23e")
const EQ_RED := Color("ff3b4f")

# Layout (local coordinates)
const SPEAKER_R := 104.0
const SPEAKERS := [Vector2(130, 250), Vector2(870, 250)]
const LCD := Rect2(260, 34, 480, 196)
const DIAL := Rect2(260, 246, 480, 92)
const PRESETS := Rect2(260, 364, 480, 52)
const KNOB_R := 38.0
const KNOBS := [Vector2(130, 432), Vector2(870, 432)]
const EQ_AREA := Rect2(280, 150, 440, 66)

var titles: Array = []      # scrolling text per station
var freqs: Array = []       # MHz per station
var selected := 0
var spectrum: Callable      # -> PackedFloat32Array (BANDS values 0..1), or empty

var _needle := 88.0
var _eq := PackedFloat32Array()
var _peak := PackedFloat32Array()
var _peak_hold := PackedFloat32Array()
var _t := 0.0
var _clip: Control
var _marquee: Label
var _freq_l: Label
var _labels_built := false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eq.resize(BANDS)
	_peak.resize(BANDS)
	_peak_hold.resize(BANDS)


## Sets the stations (texts and frequencies) and builds the labels.
var _mhz := "%.1f"


func setup(station_titles: Array, station_freqs: Array, vol_text: String, tune_text: String, brand: String, fm: String,
		mhz: String, stereo: String) -> void:
	_mhz = mhz
	titles = station_titles
	freqs = station_freqs
	_needle = float(freqs[0])
	# LCD: FM and the frequency, top row; the scrolling title in a clipped strip.
	_add_label(fm, 24, AMBER, Vector2(LCD.position.x + 18, LCD.position.y + 14))
	_add_label(stereo, 24, AMBER, Vector2(LCD.position.x + 74, LCD.position.y + 14))   # the stereo lamp
	_freq_l = _add_label("", 24, AMBER, Vector2(LCD.end.x - 190, LCD.position.y + 14))
	_freq_l.custom_minimum_size.x = 172
	_freq_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.position = Vector2(LCD.position.x + 14, LCD.position.y + 52)
	_clip.size = Vector2(LCD.size.x - 28, 60)
	add_child(_clip)
	_marquee = UI.label("", 48, LCD_TEXT)
	_clip.add_child(_marquee)
	# Dial numbers under the major ticks.
	for f in [88, 92, 96, 100, 104, 108]:
		var l := _add_label(str(f), 24, DIAL_INK, Vector2(_dial_x(float(f)) - 30, DIAL.position.y + 50))
		l.custom_minimum_size.x = 60
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Preset numbers.
	for i in freqs.size():
		var r := _preset_rect(i)
		var l := _add_label(str(i + 1), 36, CHROME_HI, r.position + Vector2(0, 8))
		l.custom_minimum_size.x = r.size.x
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_meta("preset", i)
	# Knob captions and the brand.
	for k in 2:
		var l := _add_label([vol_text, tune_text][k], 24, CHROME, KNOBS[k] + Vector2(-60, -KNOB_R - 30))
		l.custom_minimum_size.x = 120
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _add_label(brand, 24, AMBER, Vector2(PRESETS.position.x, PRESETS.end.y + 16))
	b.custom_minimum_size.x = PRESETS.size.x
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_labels_built = true
	set_station(selected)


func set_station(i: int) -> void:
	selected = clampi(i, 0, maxi(freqs.size() - 1, 0))
	if not _labels_built:
		return
	_marquee.text = str(titles[selected])
	_marquee.position = Vector2(_clip.size.x, 4)   # scrolls in from the right
	_freq_l.text = _mhz % float(freqs[selected])
	for c in get_children():
		if c.has_meta("preset"):
			var on: bool = int(c.get_meta("preset")) == selected
			(c as Label).position.y = _preset_rect(int(c.get_meta("preset"))).position.y + (12.0 if on else 8.0)
			UI.set_color(c as Label, AMBER if on else CHROME_HI)
	queue_redraw()


func _add_label(text: String, sz: int, col: Color, at: Vector2) -> Label:
	var l := UI.label(text, sz, col)
	l.position = at
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	if freqs.is_empty():
		return
	_needle = move_toward(_needle, float(freqs[selected]), delta * 28.0)
	if _marquee != null:
		_marquee.position.x -= 110.0 * delta
		if _marquee.position.x < -_marquee.size.x - 20.0:
			_marquee.position.x = _clip.size.x
	# Equaliser: the music's spectrum if we have it, else a dance of its own.
	var want := PackedFloat32Array()
	if spectrum.is_valid():
		want = spectrum.call()
	var live := false
	for v in want:
		if v > 0.02:
			live = true
			break
	for b in BANDS:
		var target: float
		if live and b < want.size():
			target = want[b]
		else:
			var beat := pow(maxf(0.0, sin(_t * TAU * 2.0)), 6.0)   # ~120 bpm kick
			var low := 1.0 - float(b) / BANDS
			target = clampf(0.25 + 0.3 * sin(_t * (2.3 + b * 0.7) + b * 1.9) + 0.45 * beat * low
				+ 0.15 * sin(_t * 9.0 + b * 3.1), 0.05, 1.0)
		# Bars jump up and fall back slowly; peaks hold, then drop.
		_eq[b] = target if target > _eq[b] else move_toward(_eq[b], target, delta * 1.8)
		if _eq[b] >= _peak[b]:
			_peak[b] = _eq[b]
			_peak_hold[b] = 0.5
		else:
			_peak_hold[b] -= delta
			if _peak_hold[b] <= 0.0:
				_peak[b] = move_toward(_peak[b], _eq[b], delta * 0.9)
	queue_redraw()


# --- drawing -------------------------------------------------------------------
func _dial_x(f: float) -> float:
	return DIAL.position.x + 16.0 + (DIAL.size.x - 32.0) * (f - FREQ_MIN) / (FREQ_MAX - FREQ_MIN)


func _preset_rect(i: int) -> Rect2:
	var n := maxi(freqs.size(), 1)
	var gap := 14.0
	var w := (PRESETS.size.x - gap * (n - 1)) / n
	return Rect2(PRESETS.position.x + i * (w + gap), PRESETS.position.y, w, PRESETS.size.y)


func _bevel(r: Rect2, fill: Color, hi: Color, lo: Color, edge: float = 4.0) -> void:
	draw_rect(r.grow(4.0), OUTLINE)
	draw_rect(r, lo)
	draw_rect(Rect2(r.position, r.size - Vector2(edge, edge)), hi)
	draw_rect(Rect2(r.position + Vector2(edge, edge), r.size - Vector2(edge * 2.0, edge * 2.0)), fill)


func _draw() -> void:
	# Body: an outlined slab with a lit top edge and a dark lower edge.
	_bevel(Rect2(0, 0, W, H), BODY, BODY_HI, BODY_LO, 10.0)
	draw_rect(Rect2(10, 10, W - 20, 6), Color(BODY_HI, 0.6))
	_draw_speakers()
	_draw_lcd()
	_draw_dial()
	_draw_presets()
	_draw_knobs()


func _draw_speakers() -> void:
	for c in SPEAKERS:
		draw_circle(c, SPEAKER_R + 6.0, OUTLINE)
		draw_circle(c, SPEAKER_R, CHROME)
		draw_circle(c, SPEAKER_R - 8.0, OUTLINE)
		draw_circle(c, SPEAKER_R - 12.0, Color("101216"))
		# Grille holes on a square grid, clipped to the cone.
		var step := 13.0
		var y := -SPEAKER_R
		while y <= SPEAKER_R:
			var x := -SPEAKER_R
			while x <= SPEAKER_R:
				if Vector2(x, y).length() < SPEAKER_R - 20.0:
					draw_rect(Rect2(c + Vector2(x, y) - Vector2(3, 3), Vector2(6, 6)), BODY_HI)
				x += step
			y += step
		# The cone's cap pulses a little with the low end of the music.
		var thump := 1.0 + 0.08 * (_eq[0] if _eq.size() > 0 else 0.0)
		draw_circle(c, 26.0 * thump, OUTLINE)
		draw_circle(c, 22.0 * thump, BODY_HI)
		draw_rect(Rect2(c + Vector2(-12, -14) * thump, Vector2(8, 6)), CHROME_HI)


func _draw_lcd() -> void:
	_bevel(LCD, LCD_BG, BODY_LO, BODY_HI, 4.0)
	# Faint scan lines and the glass's diagonal glint.
	var y := LCD.position.y + 6.0
	while y < LCD.end.y - 6.0:
		draw_rect(Rect2(LCD.position.x + 6, y, LCD.size.x - 12, 2), LCD_LINE)
		y += 6.0
	draw_colored_polygon(PackedVector2Array([LCD.position + Vector2(20, 6), LCD.position + Vector2(90, 6),
		LCD.position + Vector2(40, 60), LCD.position + Vector2(6, 60), LCD.position + Vector2(6, 30)]), Color(1, 1, 1, 0.05))
	# ST lamp (stereo) next to FM.
	# Graphic equaliser: segmented bars, green / yellow / red, peaks held.
	var bw := EQ_AREA.size.x / BANDS
	var sh := EQ_AREA.size.y / SEGS
	for b in BANDS:
		var x := EQ_AREA.position.x + b * bw
		var lit := int(round(_eq[b] * SEGS))
		var pk := clampi(int(round(_peak[b] * SEGS)) - 1, 0, SEGS - 1)
		for k in SEGS:
			var col := EQ_GREEN if k < 6 else (EQ_YELLOW if k < 8 else EQ_RED)
			var on := k < lit or k == pk
			var r := Rect2(x + 3.0, EQ_AREA.end.y - (k + 1) * sh + 1.0, bw - 6.0, sh - 2.0)
			draw_rect(r, col if on else col.darkened(0.82))


func _draw_dial() -> void:
	_bevel(DIAL, DIAL_FACE, BODY_LO, BODY_HI, 4.0)
	# Backlight: warmer in the middle.
	draw_rect(Rect2(DIAL.position.x + 4, DIAL.position.y + 4, DIAL.size.x - 8, 10), Color(1, 1, 1, 0.25))
	for f in range(88, 109):
		var x := _dial_x(float(f))
		var major := f % 4 == 0
		draw_rect(Rect2(x - 1, DIAL.position.y + 14, 2 if not major else 4, 30 if major else 16), DIAL_INK)
	# The stations, as small amber marks along the top.
	for i in freqs.size():
		var x := _dial_x(float(freqs[i]))
		var on := i == selected
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, DIAL.position.y + 4), Vector2(x + 7, DIAL.position.y + 4),
			Vector2(x, DIAL.position.y + 13)]), NEEDLE if on else Color("b86a1e"))
	# The needle.
	var nx := _dial_x(_needle)
	draw_rect(Rect2(nx - 3, DIAL.position.y + 2, 6, DIAL.size.y - 4), OUTLINE)
	draw_rect(Rect2(nx - 2, DIAL.position.y + 2, 4, DIAL.size.y - 4), NEEDLE)


func _draw_presets() -> void:
	for i in freqs.size():
		var r := _preset_rect(i)
		if i == selected:   # pressed in, with its lamp lit
			r.position.y += 4.0
			_bevel(r, BODY_LO, OUTLINE, BODY_HI, 4.0)
			draw_rect(Rect2(r.get_center().x - 8, r.position.y - 14, 16, 6), AMBER)
		else:
			_bevel(r, BODY, BODY_HI, BODY_LO, 4.0)
			draw_rect(Rect2(r.get_center().x - 8, r.position.y - 14, 16, 6), Color(AMBER, 0.2))


func _draw_knobs() -> void:
	for k in 2:
		var c: Vector2 = KNOBS[k]
		draw_circle(c, KNOB_R + 5.0, OUTLINE)
		draw_circle(c, KNOB_R, CHROME)
		draw_circle(c, KNOB_R - 8.0, BODY_HI)
		# Knurled rim: little teeth all round.
		for i in 16:
			var a := TAU * i / 16.0
			draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * (KNOB_R - 3.0) - Vector2(2, 2), Vector2(4, 4)), BODY_LO)
		# The pointer: TUNE turns with the needle; VOL sits near the top end.
		var f := (_needle - FREQ_MIN) / (FREQ_MAX - FREQ_MIN) if k == 1 else 0.8
		var a := deg_to_rad(135.0 + 270.0 * f)
		var tip := c + Vector2(cos(a), sin(a)) * (KNOB_R - 14.0)
		draw_line(c, tip, OUTLINE, 8.0)
		draw_line(c, tip, CHROME_HI, 4.0)
