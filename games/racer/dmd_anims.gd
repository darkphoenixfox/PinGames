## TURBO RUN DMD pixel animations (D-115). Short event animations drawn with a
## Dmd.Painter in logical 128x32 dots; the game plays them with
## Dmd.play(Callable(anims, name).bind(args...), DURATIONS[name]).
## Pure drawing: texts arrive already translated.
extends RefCounted

const DURATIONS := {
	"near_miss": 1.0,
	"nitro": 1.1,
	"shift": 0.7,
	"crash": 1.9,
	"checkpoint": 1.6,
	"drift": 1.0,
	"perfect": 1.1,
	"fine": 3.2,
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


## D-243: the player's own car as a dot sprite (from the director's pictures,
## nose right), set by the game for the chosen car; null = the 13x5 dot car.
var player_sprite: Image
## D-245: the police car (from its 3D model, rendered side-on), drawn the same way.
var police_sprite: Image


# --- helpers ------------------------------------------------------------------------
## The player's car at the 13x5 car's spot (x, y = its top-left): the sprite,
## standing on the same ground row and centred on the same spot.
func _player(p, x: float, y: float, flip: bool = false, upside_down: bool = false) -> void:
	if player_sprite == null:
		_car(p, x, y, RED, flip)
		return
	var w := player_sprite.get_width()
	var h := player_sprite.get_height()
	var x0 := x + 6.5 - w * 0.5
	var y0 := y + 5 - h
	for r in h:
		for c in w:
			var px := player_sprite.get_pixel(c, r)
			if px.a < 0.5:
				continue
			var dc := (w - 1 - c) if flip else c
			var dr := (h - 1 - r) if upside_down else r
			p.dot(x0 + dc, y0 + dr, Color(px.r, px.g, px.b))


## The police car at the 13x5 car's spot, its roof light bar flashing red and
## blue (`flash` = time; < 0 = lights off).
func _police(p, x: float, y: float, flash: float) -> void:
	if police_sprite == null:
		return
	var w := police_sprite.get_width()
	var h := police_sprite.get_height()
	var x0 := x + 6.5 - w * 0.5
	var y0 := y + 5 - h
	var roof_l := w
	var roof_r := -1
	for c in w:
		if police_sprite.get_pixel(c, 0).a > 0.5:
			roof_l = mini(roof_l, c)
			roof_r = maxi(roof_r, c)
	for r in h:
		for c in w:
			var px := police_sprite.get_pixel(c, r)
			if px.a >= 0.5:
				p.dot(x0 + c, y0 + r, Color(px.r, px.g, px.b))
	if flash >= 0.0 and roof_r >= roof_l:
		var mid := (roof_l + roof_r) / 2
		var red_on := fmod(flash, 0.3) < 0.15
		p.block(x0 + mid - 2, y0 - 1, 2, 1, RED if red_on else Color(0.25, 0.05, 0.05))
		p.block(x0 + mid + 1, y0 - 1, 2, 1, Color("3f6bff") if not red_on else Color(0.05, 0.05, 0.25))


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
	_player(p, 24, 24)
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
	_player(p, x, 23)
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


## Crash (D-125): the car races into a rock, the impact bursts, it cartwheels
## through the air in stepped poses shedding debris, lands on its roof and
## smokes, while CRASH! blinks.
const ROCK := [
	"..kkkk..",
	".kggggk.",
	"kgGggggk",
	"kggggggk",
	"kkkkkkkk",
]


func _car_pose(p, pose: int, x: float, y: float) -> void:
	# 0 upright, 1 nose down (vertical), 2 on its roof, 3 nose up (vertical)
	match pose:
		0:
			_player(p, x, y)
		2:
			if player_sprite != null:
				_player(p, x, y, false, true)
				return
			for r in CAR.size():
				for c in CAR[r].length():
					var k: String = CAR[r][c]
					if k != "0":
						p.dot(x + c, y + 4 - r, RED if k == "1" else (CYAN if k == "2" else DARK.lightened(0.3)))
		_:
			# Side-on vertical: a tall narrow body, wheels on one side.
			for r in 12:
				var rr: int = r if pose == 1 else 11 - r
				p.block(x + 4, y - 6 + rr, 4, 1, RED)
				p.dot(x + 3, y - 6 + rr, CYAN if rr > 3 and rr < 8 else RED)
			for w in [1, 9]:
				var wy: int = w if pose == 1 else 11 - w
				p.dot(x + 8, y - 6 + wy, DARK.lightened(0.3))
				p.dot(x + 8, y - 5 + wy, DARK.lightened(0.3))


func crash(p, t: float, title: String) -> void:
	var rock_x := 70.0
	for r in ROCK.size():
		var row: String = ROCK[r]
		for c in row.length():
			var k := row[c]
			if k == "k":
				p.dot(rock_x + c, 24 + r, DARK.lightened(0.15))
			elif k == "g":
				p.dot(rock_x + c, 24 + r, DIM)
			elif k == "G":
				p.dot(rock_x + c, 24 + r, WHITE * 0.7)
	p.line(0, 29, 127, 29, DARK.lightened(0.1))   # the ground
	const HIT := 0.35
	if t < HIT:
		# Racing in from the left with speed lines.
		var x := lerpf(-14.0, rock_x - 12.0, t / HIT)
		for i in 5:
			var ly := 22.0 + i
			p.line(x - 10 - (i * 7) % 12, ly, x - 2, ly, DIM)
		_player(p, x, 23)
		return
	var tt := t - HIT
	_burst(p, rock_x, 24, clampf(tt / 0.5, 0.0, 1.0), 30, 40.0)
	# Cartwheel: a ballistic arc over the rock, 4 poses per turn, ~10 fps.
	const AIR := 0.9
	var k := clampf(tt / AIR, 0.0, 1.0)
	var cx := lerpf(rock_x - 10.0, 104.0, k)
	var cy := 23.0 - 20.0 * 4.0 * k * (1.0 - k)
	var pose := (int(tt * 10.0) % 4) if k < 1.0 else 2
	_car_pose(p, pose, cx, cy)
	# Debris flying off.
	for i in 8:
		var dk := clampf(tt / 0.8, 0.0, 1.0)
		var dx := rock_x + (i - 3.5) * 7.0 * dk + i
		var dy := 24.0 - 14.0 * 4.0 * dk * (1.0 - dk) * (0.5 + (i % 3) * 0.3)
		if dk < 1.0:
			p.dot(dx, dy, ORANGE if i % 2 == 0 else WHITE)
	# Landed upside down: smoke curls up.
	if k >= 1.0:
		for i in 6:
			var sy := 22.0 - fmod(tt * 12.0 + i * 3.0, 18.0)
			var sx := cx + 6 + sin(tt * 4.0 + i) * 2.0
			p.dot(sx, sy, DIM if i % 2 == 0 else Color(0.5, 0.5, 0.55))
	if tt > 0.1:
		var shake := 0.0 if tt > 0.5 else (2.0 if int(tt * 30.0) % 2 == 0 else -2.0)
		p.text(title, 4 + shake, 2, 2, RED if _blink(tt, 0.15) else WHITE)


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


## Busted (D-135): a police car pulls up beside ours with its light bar
## flashing, then a ticket slides out with the fine.
func fine(p, t: float, title: String, label: String, amount: String) -> void:
	p.line(0, 29, 127, 29, DARK.lightened(0.1))
	_player(p, 10, 24)
	# Police car rolls in from the left and stops behind ours.
	var px := lerpf(-16.0, 30.0, clampf(t / 0.6, 0.0, 1.0))   # D-243: clear of the bigger player sprite
	_police(p, px, 24, t)   # D-245
	# Title, then the ticket.
	if t > 0.5:
		p.text(title, maxf(40.0, 127.0 - p.text_width(title, 2)), 1, 2, RED if _blink(t, 0.3) else WHITE)
	if t > 1.1:
		var k := clampf((t - 1.1) / 0.4, 0.0, 1.0)
		var ty := lerpf(32.0, 16.0, k)
		p.block(50, ty, 76, 14, WHITE)
		p.block(50, ty, 76, 1, DIM)
		p.text(label, 53, ty + 4, 1, DARK)
		p.text(amount, 124 - p.text_width(amount), ty + 4, 1, RED)
