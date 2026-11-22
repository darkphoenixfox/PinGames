## TURBO RUN DMD pixel animations (D-115). Short event animations drawn with a
## Dmd.Painter in logical 128x32 dots; the game plays them with
## Dmd.play(Callable(anims, name).bind(args...), DURATIONS[name]).
## Pure drawing: texts arrive already translated.
extends RefCounted

const DURATIONS := {
	"near_miss": 1.0,
	"nitro": 1.1,
	"shift": 0.7,
	"crash": 2.0,
	"checkpoint": 1.6,
	"drift": 1.0,
	"perfect": 1.1,
}

const WHITE := Color(1, 1, 1)
const YELLOW := Color("ffd23e")
const ORANGE := Color("ff8a2a")
const RED := Color("ff3b4f")
const CYAN := Color("3ec7ff")
const GREEN := Color("4fff7a")
const DIM := Color(0.35, 0.35, 0.4)
const DARK := Color(0.12, 0.12, 0.16)

# 13x5 pixel car seen from the side, nose to the right:
# 1 body, 2 window, 3 light, 4 wheel
const CAR := [
	"0001111110000",
	"0012222221000",
	"1111111111113",
	"1111111111111",
	"0440000000440",
]


# --- helpers ------------------------------------------------------------------------
func _car(p, x: float, y: float, body: Color, flip: bool = false) -> void:
	for r in CAR.size():
		for c in CAR[r].length():
			var k: String = CAR[r][c]
			if k == "0":
				continue
			var col := body
			match k:
				"2": col = CYAN
				"3": col = YELLOW
				"4": col = DARK.lightened(0.3)
			var cx: int = (12 - c) if flip else c
			p.dot(x + cx, y + r, col)


## Horizontal speed streaks rushing left; `k` 0..1 density.
func _speed_lines(p, t: float, k: float, col: Color = DIM) -> void:
	for i in 14:
		var y := float((i * 7) % 30) + 1.0
		var spd := 160.0 + float((i * 37) % 90)
		var len := 6.0 + float((i * 13) % 10)
		var x := 140.0 - fmod(t * spd + i * 23.0, 160.0)
		if float(i) / 14.0 > k:
			continue
		p.line(x, y, x + len, y, col)


## Radial pixel shower; age 0..1 (golden-angle spread, deterministic).
func _burst(p, cx: float, cy: float, age: float, count: int, reach: float) -> void:
	for i in count:
		var ang := i * 2.39996
		var speed := 0.55 + 0.45 * float((i * 7) % 13) / 12.0
		var d := reach * speed * (1.0 - pow(1.0 - age, 2.0))
		var c: Color = WHITE if age < 0.15 else (YELLOW if age < 0.35 else (ORANGE if age < 0.6 else RED))
		if age > 0.8 and (i + int(age * 30.0)) % 2 == 0:
			continue
		p.dot(cx + cos(ang) * d, cy + sin(ang) * d * 0.6, c)


func _blink(t: float, rate: float = 0.25) -> bool:
	return fmod(t, rate) < rate * 0.6


# --- animations -----------------------------------------------------------------------
## Another car whooshes past ours, just missing it.
func near_miss(p, t: float, title: String, bonus: String) -> void:
	var k := t / DURATIONS.near_miss
	_speed_lines(p, t, 1.0)
	_car(p, 24, 24, RED)
	var ox := lerpf(132.0, -20.0, clampf(k / 0.45, 0.0, 1.0))
	_car(p, ox, 18, WHITE * 0.85, true)
	if k > 0.15 and k < 0.5:   # sparks where they nearly touched
		for i in 6:
			p.dot(36 + i * 3 - (k - 0.15) * 40.0, 23 - (i % 2), YELLOW if i % 2 == 0 else ORANGE)
	if k > 0.3 and _blink(t, 0.2):
		p.text_center(title, 2, 1, YELLOW)
	if k > 0.45:
		p.text(bonus, 128 - p.text_width(bonus) - 4, 12, 1, WHITE)


## Nitro: the car lunges forward on a long flame, speed lines everywhere.
func nitro(p, t: float, title: String) -> void:
	var k := t / DURATIONS.nitro
	_speed_lines(p, t * 1.6, 1.0, CYAN * 0.6)
	var x := lerpf(4.0, 40.0, 1.0 - pow(1.0 - clampf(k * 1.5, 0.0, 1.0), 3.0))
	# Flame: a flickering wedge behind the car.
	var flen := 14.0 + 6.0 * sin(t * 40.0)
	for i in int(flen):
		var h := 2.0 * (1.0 - float(i) / flen)
		var c := WHITE if i < 3 else (CYAN if i < flen * 0.5 else ORANGE)
		p.line(x - 1 - i, 26 - h, x - 1 - i, 26 + h * 0.5, c)
	_car(p, x, 23, RED)
	if k > 0.2:
		var c2 := CYAN if _blink(t, 0.16) else WHITE
		p.text(title, 126 - p.text_width(title, 2), 2, 2, c2)


## Gear shift: the knob jumps across the H/L gate in stepped frames.
func shift(p, t: float, high: bool, label: String, h_txt: String, l_txt: String) -> void:
	var gear := h_txt if high else l_txt
	var k := clampf(t / 0.25, 0.0, 1.0)
	var steps := roundf(k * 3.0) / 3.0
	var from_y := 24.0 if high else 8.0
	var to_y := 8.0 if high else 24.0
	var ky := lerpf(from_y, to_y, steps)
	# Gate
	p.block(62, 6, 3, 21, DARK.lightened(0.15))
	p.block(66, 7, 3, 1, DIM)
	p.block(66, 25, 3, 1, DIM)
	p.text(h_txt, 71, 4, 1, WHITE if high else DIM)
	p.text(l_txt, 71, 21, 1, YELLOW if not high else DIM)
	var col := WHITE if high else YELLOW
	p.disc(63.5, ky, 3.2, col.darkened(0.4))
	p.disc(63.0, ky - 0.5, 2.2, col)
	p.dot(62, ky - 2, WHITE)
	p.text(label, 8, 12, 1, DIM)
	var c2 := col if t > 0.25 or _blink(t, 0.1) else DIM
	p.text(gear, 100, 9, 2, c2)


## Crash (D-119): after a quick impact burst, the blond passenger yells at the
## driver, who sits there in his sunglasses, sweating. Original pixel portraits.
## Palette keys: k outline, s skin, S skin shade, y blond, Y blond shade,
## h dark hair, g sunglasses, G lens shine, w white, b eye blue, r lips/mouth,
## p pink top, c white shirt, R red jacket.
const LADY := [
	"....kkkkkkkk....",
	"...kyyyyyyyyk...",
	"..kyyyYyyyyyyk..",
	".kyyyyyyyyyYyyk.",
	".kyyssssssssyyk.",
	".kyskkssssskkyk.",
	"kyysskksskkssyyk",
	"kyysswbsswbssyyk",
	"kyyssssssssssyyk",
	"kyyssssSSssssyyk",
	"kyyyskkkkkksyyyk",
	"kyyyskwwwwksyyyk",
	"kyyyskrrrrksyyyk",
	"kyyyyskkkksyyyyk",
	"kyyyykkssskkyyyk",
	"kYyypppssspppyYk",
	".kpppppppppppppk",
	"kppppppppppppppk",
]
const LADY_SHUT := [   # mouth rows when closed (rows 10-13), still cross
	"kyyysssssssssyyk",
	"kyyysskkkkssyyyk",
	"kyyyyssssssyyyyk",
	"kyyyyysssssyyyyk",
]
const DRIVER := [
	"....kkkkkkk.....",
	"...khhhhhhhk....",
	"..khhhhhhhhhk...",
	"..khhhhhhhhhhk..",
	"..khsshhhhsshk..",
	"..ksssssssssssk.",
	".kgggggggggggggk",
	".kgGggggsgGggggk",
	"..kgggggsgggggk.",
	"..kssssSSsssssk.",
	"..ksssssssssssk.",
	"...ksskkkkkssk..",
	"...ksssssssssk..",
	"....kkssssskk...",
	"...cccksssskccc.",
	"..RRcccwwwcccRR.",
	".RRRRcccwcccRRRR",
	"RRRRRRcccccRRRRR",
]
const FACE_COLS := {
	"k": Color(0.05, 0.04, 0.08), "s": Color("f2b48c"), "S": Color("c98a66"),
	"y": Color("ffe066"), "Y": Color("d9a830"), "h": Color("4a2c1a"),
	"g": Color(0.06, 0.06, 0.1), "G": Color("9fe8ff"), "w": Color(1, 1, 1),
	"b": Color("3f8cff"), "r": Color("e8304a"), "p": Color("ff6fb0"),
	"c": Color(0.95, 0.95, 0.95), "R": Color("d42828"),
}


func _face(p, rows: Array, x: float, y: float) -> void:
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			var k := row[c]
			if k != ".":
				p.dot(x + c, y + r, FACE_COLS[k])


func crash(p, t: float, title: String) -> void:
	if t < 0.3:   # the impact first
		_burst(p, 64, 16, t / 0.3, 40, 60.0)
		return
	var tt := t - 0.3
	# The lady: shaking with rage, mouth snapping open and shut.
	var shake := 1.0 if int(tt * 16.0) % 2 == 0 else -1.0
	var yelling := int(tt * 8.0) % 2 == 0
	var lady := LADY.duplicate()
	if not yelling:
		for i in 4:
			lady[10 + i] = LADY_SHUT[i]
	_face(p, lady, 44 + shake, 8)
	# Anger mark: a red cross-vein popping by her head.
	if int(tt * 6.0) % 2 == 0:
		for d in [Vector2(0, 0), Vector2(2, 0), Vector2(1, -1), Vector2(1, 1), Vector2(0, 2), Vector2(2, 2)]:
			p.dot(40 + d.x, 5 + d.y, RED)
	# Shout lines towards the driver.
	if yelling:
		for i in 3:
			p.line(62, 17 + i * 3 - 3, 66, 16 + i * 4 - 4, WHITE)
	# The driver, unmoved behind his sunglasses, with a sweat drop sliding down.
	_face(p, DRIVER, 70, 8)
	var dy := fmod(tt * 14.0, 10.0)
	p.dot(86, 9 + dy, CYAN)
	p.dot(86, 10 + dy, CYAN)
	p.dot(85, 10 + dy, WHITE)
	if tt > 0.2:
		p.text(title, 2, 12, 1, RED if _blink(tt, 0.2) else WHITE)


## Checkpoint: a waving chequered flag and the time bonus.
func checkpoint(p, t: float, title: String, bonus: String) -> void:
	for c in 10:
		var wave := roundf(sin(t * 10.0 - c * 0.7) * 1.5)
		for r in 6:
			var col := WHITE if (c / 2 + r) % 2 == 0 else DARK
			p.block(8 + c * 2, 6 + r * 2 + wave, 2, 2, col)
	p.block(6, 4, 1, 26, DIM)
	p.text(title, 30, 4, 1, YELLOW)
	if _blink(t, 0.3) or t > 1.0:
		p.text(bonus, maxf(30.0, 126.0 - p.text_width(bonus, 2)), 16, 2, GREEN)


## Drift points banked: the score rises out of a ring of sparkles.
func drift(p, t: float, title: String, pts: String) -> void:
	var k := t / DURATIONS.drift
	for i in 16:
		var a := i * TAU / 16.0 + t * 3.0
		var r := 10.0 + k * 40.0
		if (i + int(t * 20.0)) % 3 != 0:
			p.dot(64 + cos(a) * r, 16 + sin(a) * r * 0.45, YELLOW if i % 2 == 0 else WHITE)
	var y := lerpf(20.0, 12.0, clampf(k * 3.0, 0.0, 1.0))
	p.text_center(title, 2, 1, ORANGE)
	p.text_center(pts, y, 2, YELLOW if _blink(t, 0.2) else WHITE)


## Perfect shift (D-116): a green tach bar sweeps into its sweet spot, then the
## title flashes over a starburst.
func perfect(p, t: float, title: String) -> void:
	var k := t / DURATIONS.perfect
	for i in 13:
		var f := (i + 0.5) / 13.0
		var on := f <= minf(k * 3.0, 0.83)
		var c := DARK
		if on:
			c = GREEN if f > 0.68 else (YELLOW if f > 0.45 else GREEN.darkened(0.3))
		p.block(32 + i * 5, 27, 4, 5, c)
	if k > 0.3:
		for i in 12:
			var a := i * TAU / 12.0
			var r := 6.0 + (k - 0.3) * 50.0
			if (i + int(t * 20.0)) % 2 == 0:
				p.dot(64 + cos(a) * r, 12 + sin(a) * r * 0.45, GREEN if i % 2 == 0 else WHITE)
		p.text_center(title, 8, 1, GREEN if _blink(t, 0.16) else WHITE)
