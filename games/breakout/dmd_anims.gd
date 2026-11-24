## Tilt Breaker DMD pixel animations (D-056). Each function draws one frame at
## time t (seconds) with a Dmd.Painter in logical 128x32 dots; the game plays
## them with Dmd.play(Callable(anims, name), DURATIONS[name]).
## Pure drawing: texts are passed in already translated via `texts`.
extends RefCounted

const DURATIONS := {
	"ship_boost": 1.7,
	"logo": 3.2,
	"tetra_hit": 1.6,
	"incoming": 1.3,
	"charge_lost": 1.5,
	"ship_destroyed": 1.7,
	"rack_clear": 1.8,
	# D-328: power-up pickups
	"pu_T": 1.6, "pu_P": 1.6, "pu_B": 1.6, "pu_I": 1.6, "pu_W": 1.6, "pu_H": 1.6,
	"pu_L": 1.6, "pu_S": 1.6, "pu_K": 1.6, "pu_U": 1.8, "pu_N": 1.8,
}

const WHITE := Color(1, 1, 1)
const YELLOW := Color("ffd23e")
const ORANGE := Color("ff8a2a")
const RED := Color("ff3b4f")
const CYAN := Color("3ec7ff")
const BLUE := Color("2f6bff")
const VIOLET := Color("b36bff")
const DIM := Color(0.35, 0.35, 0.4)

var texts := {}
var logo_tex: Texture2D = preload("res://assets/textures/breakout/dmd_logo.png")
var _logo_alpha: Image
var enemy_color := VIOLET

const TETRA := [Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)]
const TETRA_EDGES := [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]
# 15x5 pixel ship (the paddle): 1 = hull, 2 = cockpit, 3 = engine
const SHIP := [
	"000001111100000",
	"311111222111113",
	"311111222111113",
	"000011111110000",
	"000000101000000",
]


# --- helpers ------------------------------------------------------------------------
func _tetra(p, cx: float, cy: float, s: float, a: float, c: Color) -> void:
	var pts := []
	for v in TETRA:
		var r: Vector3 = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, a * 0.7) * (v as Vector3)
		pts.append(Vector2(cx + r.x * s, cy + r.y * s))
	for e in TETRA_EDGES:
		p.line(pts[e[0]].x, pts[e[0]].y, pts[e[1]].x, pts[e[1]].y, c)


func _ship(p, cx: float, cy: float) -> void:
	for r in SHIP.size():
		for col in SHIP[r].length():
			var k: String = SHIP[r][col]
			if k == "0":
				continue
			var c := WHITE * 0.8 if k == "1" else (CYAN if k == "2" else BLUE)
			p.dot(cx - 7 + col, cy - 2 + r, c)


## Radial pixel shower; age 0..1. Deterministic (golden-angle spread).
func _burst(p, cx: float, cy: float, age: float, count: int, reach: float, base: Color) -> void:
	for i in count:
		var ang := i * 2.39996
		var speed := 0.55 + 0.45 * float((i * 7) % 13) / 12.0
		var d := reach * speed * (1.0 - pow(1.0 - age, 2.0))
		var c: Color = WHITE if age < 0.15 else (YELLOW if age < 0.35 else (ORANGE if age < 0.6 else base))
		if age > 0.8 and (i + int(age * 30.0)) % 2 == 0:
			continue  # dither out
		p.dot(cx + cos(ang) * d, cy + sin(ang) * d * 0.55, c)


func _blink(t: float, rate: float = 0.25) -> bool:
	return fmod(t, rate * 2.0) < rate


func _txt(key: String) -> String:
	return str(texts.get(key, ""))


# --- animations ---------------------------------------------------------------------
## The pixel-art logo (D-063): drops in from the top with a bounce, then a white
## glint sweeps diagonally across the letters, then a few sparkles.
func logo(p, t: float) -> void:
	if _logo_alpha == null:
		_logo_alpha = logo_tex.get_image()
		_logo_alpha.decompress()
	var lw := logo_tex.get_width()
	var lh := logo_tex.get_height()
	var x0 := floorf((p.width - lw) / 2.0)
	var drop := clampf(t / 0.45, 0.0, 1.0)
	var y0 := floorf(-lh * (1.0 - drop) + (sin(drop * PI) * 2.0 if drop < 1.0 else 0.0))
	p.image(logo_tex, x0, y0)
	if t > 0.7 and t < 1.6:
		var band := (t - 0.7) / 0.9 * (lw + lh + 8) - 4.0
		for y in lh:
			for dx in 3:
				var x := int(band - y * 0.6) + dx
				if x >= 0 and x < lw and _logo_alpha.get_pixel(x, y).a > 0.5:
					p.dot(x0 + x, y0 + y, Color(1, 1, 1, 0.85 - dx * 0.25))
	if t > 1.6:
		for i in 4:
			var k := int((t - 1.6) * 10.0) + i * 7
			var sx := (k * 37) % lw
			var sy := (k * 13) % lh
			if _logo_alpha.get_pixel(sx, sy).a > 0.5 and (k + i) % 3 == 0:
				p.dot(x0 + sx, y0 + sy, Color.WHITE)
				p.dot(x0 + sx - 1, y0 + sy, Color(1, 1, 1, 0.5))
				p.dot(x0 + sx + 1, y0 + sy, Color(1, 1, 1, 0.5))



## Level change (D-076): the ship boosts away upwards on its belly flames,
## growing as it comes towards the viewer, stars streaking past, white flash.
func ship_boost(p, t: float) -> void:
	var k := clampf(t / 1.4, 0.0, 1.0)
	# Star streaks rushing down (faster as the boost builds)
	for i in 14:
		var sx := float((i * 53) % 128)
		var len := 2.0 + 6.0 * k
		var sy := fmod(i * 7.0 + t * (40.0 + 140.0 * k), 40.0) - 4.0
		p.line(sx, sy, sx, sy + len, Color(0.5, 0.6, 0.9) * (0.4 + 0.6 * k))
	var s := 1 + int(k * 3.0)                     # pixel scale: 1 -> 4 (towards viewer)
	var cy := lerpf(26.0, -4.0 - 10.0 * s, k * k)  # rises and leaves the top
	var cx := 64.0
	# Belly flames under the ship, flickering
	for f in [-3, 3]:
		var fl := (3.0 + 4.0 * k) * s * (0.7 + 0.3 * sin(t * 47.0 + f))
		for d in int(fl):
			var c := WHITE if d < s else (CYAN if d < 3 * s else BLUE)
			p.block(cx + f * s - floorf(s * 0.5), cy + 3 * s + d, s, 1, c)
	# Ship sprite scaled up
	for r in SHIP.size():
		for col in SHIP[r].length():
			var ch: String = SHIP[r][col]
			if ch == "0":
				continue
			var c := WHITE * 0.85 if ch == "1" else (CYAN if ch == "2" else BLUE)
			p.block(cx + (col - 7) * s, cy + (r - 2) * s, s, s, c)
	if t > 1.4:  # exit flash
		var a := 1.0 - (t - 1.4) / 0.3
		p.block(0, 0, 128, 32, Color(1, 1, 1) * maxf(a, 0.0))


## Tetra hit by the plasma ball and exploding.
func tetra_hit(p, t: float) -> void:
	var cx := 86.0
	var cy := 16.0
	if t < 0.5:
		_tetra(p, cx, cy, 8.0, t * 7.0, enemy_color)
		var bx := lerpf(-4.0, cx - 7.0, t / 0.5)
		for k in 4:  # trail
			p.dot(bx - 3 - k * 3, cy, CYAN * (0.8 - k * 0.18))
		p.disc(bx, cy, 1.6, WHITE)
	elif t < 0.62:
		p.ring(cx, cy, 4.0 + (t - 0.5) * 60.0, WHITE)
		p.disc(cx, cy, 3.0, WHITE)
	else:
		var age := (t - 0.62) / 0.98
		_burst(p, cx, cy, age, 30, 26.0, enemy_color)
		p.ring(cx, cy, 10.0 + age * 30.0, ORANGE * (1.0 - age), 0.6)
		var rise := 20.0 - age * 10.0
		p.text(_txt("plus_enemy"), 8, rise, 2 if age < 0.5 else 1, YELLOW)


## Wormhole opening and a tetra emerging.
func incoming(p, t: float) -> void:
	var cx := 64.0
	var cy := 16.0
	var open := clampf(t / 0.5, 0.0, 1.0)
	for arm in 4:
		for k in 14:
			var r := k * 1.0 * open
			var a := arm * TAU / 4.0 + k * 0.35 - t * 9.0
			p.dot(cx + cos(a) * r * 1.6, cy + sin(a) * r * 0.9, VIOLET if k > 7 else CYAN)
	if t > 0.5:
		var grow := clampf((t - 0.5) / 0.5, 0.0, 1.0)
		_tetra(p, cx, cy, 2.0 + 6.0 * grow, t * 6.0, WHITE)
	if t > 0.7 and _blink(t, 0.12):
		p.text(_txt("incoming"), 2, 12, 1, RED)


## Plasma falls onto the planet: blast dome and "CHARGE LOST".
func charge_lost(p, t: float) -> void:
	# Planet horizon: a shallow arc at the bottom
	for x in 128:
		var y := 29.0 + pow((x - 64.0) / 64.0, 2.0) * 3.0
		p.dot(x, y, BLUE * 0.7)
		p.dot(x, y + 1, BLUE * 0.35)
	if t < 0.45:
		var by := lerpf(0.0, 28.0, t / 0.45)
		for k in 3:
			p.dot(64, by - 3 - k * 3, CYAN * (0.7 - k * 0.2))
		p.disc(64, by, 1.6, WHITE)
	else:
		var age := clampf((t - 0.45) / 1.05, 0.0, 1.0)
		for r in [age * 22.0, age * 15.0, age * 8.0]:
			p.ring(64, 29, r, (YELLOW if r < 10.0 else ORANGE) * (1.0 - age * 0.7), 0.5)
		_burst(p, 64, 28, age, 16, 18.0, RED)
		if t > 0.7:
			p.text_center(_txt("charge_lost"), 4, 1, RED if _blink(t, 0.15) else ORANGE)


## A tetra dives into the ship: both explode, "SHIP DESTROYED".
func ship_destroyed(p, t: float) -> void:
	var sx := 64.0
	var sy := 25.0
	if t < 0.5:
		_ship(p, sx, sy)
		var ty := lerpf(-6.0, sy - 3.0, t / 0.5)
		_tetra(p, sx + (0.5 - t) * 30.0, ty, 4.0, t * 10.0, enemy_color)
	else:
		var age := clampf((t - 0.5) / 1.2, 0.0, 1.0)
		if age < 0.12:
			p.disc(sx, sy, 6.0, WHITE)
		_burst(p, sx, sy, age, 34, 34.0, CYAN)
		if t > 0.8:
			p.text_center(_txt("ship_destroyed"), 3, 1, RED if _blink(t, 0.15) else WHITE)


## A mini brick wall pops apart row by row, then "RACK CLEAR +1000".
func rack_clear(p, t: float) -> void:
	var colors := [RED, YELLOW, Color("4dff6a"), CYAN]
	for row in 4:
		var pop_t := 0.1 + row * 0.12
		for col in 11:
			var x := 4 + col * 11
			var y := 2 + row * 4
			var k := t - pop_t - col * 0.015
			if k < 0.0:
				for dx in 9:
					for dy in 3:
						p.dot(x + dx, y + dy, colors[row] * (0.9 if dy == 0 else 0.6))
			elif k < 0.3:
				var a := k / 0.3
				p.dot(x + 4 - a * 6, y + 1 - a * 3, colors[row])
				p.dot(x + 4 + a * 6, y + 1 - a * 2, colors[row])
				p.dot(x + 4, y + 1 + a * 4, WHITE)
	if t > 0.75:
		p.text_center(_txt("rack_clear"), 6, 1, Color("4dff6a") if _blink(t, 0.2) else WHITE)
		p.text_center(_txt("plus_rack"), 17, 2 if t < 1.3 else 1, YELLOW)


# --- power-up pickups (D-328) ----------------------------------------------------------
## One clip per power-up: a little scene on the left (x 0..40), the name on the
## right in the power-up's colour (`pu_color`, `texts.pu_name`). 1UP and
## Nuclear use the whole panel.
var pu_color := YELLOW
const DotFont = preload("res://core/dmd/dot_font.gd")


## The name, centred in the right panel; flashes white as it lands.
func _pu_name(p, t: float) -> void:
	var s := _txt("pu_name")
	var x := 84.0 - DotFont.measure(s, 1) / 2.0
	var y := 13.0 + maxf(0.0, 0.25 - t) * 40.0   # drops in
	var c := WHITE if t < 0.35 or (t < 0.6 and _blink(t, 0.06)) else pu_color
	p.text(s, maxf(42.0, x), y, 1, c)
	# A frame line under the name, sweeping out
	var w := minf(1.0, t / 0.5) * 80.0
	p.line(84.0 - w / 2.0, 22, 84.0 + w / 2.0, 22, pu_color * 0.6)


## The ship (small), bottom of the art panel.
func _pu_ship(p, x: float, y: float) -> void:
	_ship(p, x, y)


## T: three bolts fan out from the ship, twice.
func pu_T(p, t: float) -> void:
	_pu_ship(p, 20, 28)
	for volley in 2:
		var k := (t - volley * 0.6) / 0.5
		if k < 0.0 or k > 1.0:
			continue
		for d in [-1.0, 0.0, 1.0]:
			var y := 24.0 - k * 26.0
			var x: float = 20.0 + d * (24.0 - y) * 0.36
			p.line(x, y, x - d * 1.4, y + 4.0, pu_color)
			p.dot(x, y, WHITE)
	_pu_name(p, t)


## P: one thick red bolt builds up and fires, with a muzzle flash.
func pu_P(p, t: float) -> void:
	_pu_ship(p, 20, 28)
	if t < 0.45:
		p.disc(20, 23, 1.0 + t * 6.0, RED if _blink(t, 0.05) else ORANGE)
	else:
		var k := minf(1.0, (t - 0.45) / 0.35)
		var top := 23.0 - k * 26.0
		for dx in [-1, 0, 1]:
			p.line(20 + dx, 23, 20 + dx, top, WHITE if dx == 0 else RED)
		if t < 0.6:
			p.disc(20, 23, 4.0, WHITE)
	_pu_name(p, t)


## B: a second plasma ball bounces around the art panel with a trail.
func pu_B(p, t: float) -> void:
	_pu_ship(p, 20, 28)
	for k in 6:
		var tt := t - k * 0.03
		var x := 4.0 + absf(fmod(tt * 60.0, 64.0) - 32.0)
		var y := 2.0 + absf(fmod(tt * 44.0, 40.0) - 20.0)
		if k == 0:
			p.disc(x, y, 1.6, WHITE)
		else:
			p.dot(x, y, pu_color * (1.0 - k * 0.15))
	_pu_name(p, t)


## I: a crackling purple column burns the bricks above the ship.
func pu_I(p, t: float) -> void:
	_pu_ship(p, 20, 28)
	for row in 4:
		var gone := t > 0.4 + row * 0.08
		if not gone:
			p.block(14, 2 + row * 4, 13, 3, CYAN * 0.6)
	if t > 0.3:
		var w := 2.0 + sin(t * 40.0) * 1.0
		p.block(20 - w / 2.0, 0, w, 24, pu_color)
		p.line(20, 0, 20, 24, WHITE)
		for i in 6:   # sparks off the column
			var sy := fmod(i * 5.0 + t * 30.0, 24.0)
			p.dot(20 + (3 if i % 2 == 0 else -3) + sin(t * 30.0 + i) * 2.0, sy, WHITE)
	_pu_name(p, t)


## W: a wave shot snakes up from the ship, leaving its trail.
func pu_W(p, t: float) -> void:
	_pu_ship(p, 20, 28)
	var head := minf(t / 0.9, 1.0) * 28.0
	for i in 40:
		var y := 23.0 - head + i * 0.7
		if y > 23.0:
			break
		var x := 20.0 + sin((23.0 - y) * 0.35 - t * 2.0) * 9.0
		p.dot(x, y, WHITE if i < 2 else pu_color * (1.0 - i / 40.0))
	_pu_name(p, t)


## H: a missile curves from the ship onto a tetra, which blows up.
func pu_H(p, t: float) -> void:
	_pu_ship(p, 8, 28)
	var tx := 28.0
	var ty := 7.0
	if t < 0.7:
		_tetra(p, tx, ty, 4.0, t * 6.0, VIOLET)
		for k in 8:
			var s := clampf((t - k * 0.02) / 0.7, 0.0, 1.0)
			var x := lerpf(8.0, tx, s * s)
			var y := lerpf(24.0, ty, s)
			p.dot(x, y, WHITE if k == 0 else pu_color * (1.0 - k * 0.11))
	else:
		_burst(p, tx, ty, clampf((t - 0.7) / 0.8, 0.0, 1.0), 22, 11.0, pu_color)
	_pu_name(p, t)


## L: the ship darts sideways with two afterimages and speed lines.
func pu_L(p, t: float) -> void:
	var x := 8.0 + absf(fmod(t * 50.0, 48.0) - 24.0)
	var dir := 1.0 if fmod(t * 50.0, 48.0) < 24.0 else -1.0
	for g in [2, 1]:
		var gx: float = x - dir * g * 6.0
		for r in SHIP.size():
			for col in SHIP[r].length():
				if SHIP[r][col] != "0":
					p.dot(gx - 7 + col, 24 + r, CYAN * (0.25 if g == 2 else 0.45))
	_ship(p, x, 26)
	for i in 5:
		var ly := 3.0 + i * 4.0
		var lx := fmod(i * 17.0 - t * 120.0 * dir, 40.0)
		p.line(lx, ly, lx + 6.0, ly, WHITE * 0.5)
	_pu_name(p, t)


## S: a green barrier lights up under the ship and bounces a ball away.
func pu_S(p, t: float) -> void:
	_pu_ship(p, 20, 20)
	var glow := 0.6 + 0.4 * sin(t * 12.0)
	p.line(1, 28, 39, 28, pu_color * glow)
	p.line(1, 29, 39, 29, pu_color * glow * 0.5)
	var k := fmod(t, 0.8) / 0.8
	var bx := 30.0 - k * 4.0
	var by := 6.0 + (1.0 - absf(k * 2.0 - 1.0)) * 20.0   # falls onto the barrier, back up
	p.disc(bx, by, 1.5, WHITE)
	if by > 24.0:
		p.ring(bx, 28, 4.0, WHITE, 0.4)
	_pu_name(p, t)


## K: two mini ships fly up from below and dock at the ship's sides.
func pu_K(p, t: float) -> void:
	_pu_ship(p, 20, 22)
	var k := clampf(t / 0.7, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	for side in [-1.0, 1.0]:
		var x: float = 20.0 + side * (11.0 + (1.0 - e) * 6.0)
		var y := 22.0 + (1.0 - e) * 16.0
		p.block(x - 2, y - 1, 5, 2, WHITE * 0.85)
		p.dot(x, y - 1, CYAN)
		if k < 1.0:
			p.line(x, y + 1, x, y + 4, pu_color)
		elif _blink(t, 0.1) and t < 1.0:
			p.dot(x - side * 3.0, y, WHITE)
	_pu_name(p, t)


## U: a big "1UP" bounces in with sparkles, then "EXTRA CHARGE!".
func pu_U(p, t: float) -> void:
	var s := 3 if t < 0.15 or t > 0.3 else 4
	var y := 3.0 + maxf(0.0, 0.3 - t) * 60.0
	p.text_center("1UP", y, s, WHITE if _blink(t, 0.08) and t < 0.6 else pu_color)
	for i in 10:
		var a := i * 2.4 + t * 3.0
		var r := 22.0 + sin(t * 5.0 + i) * 6.0
		if (i + int(t * 12.0)) % 3 != 0:
			p.dot(64.0 + cos(a) * r * 2.0, 12.0 + sin(a) * r * 0.5, YELLOW)
	if t > 0.7:
		p.text_center(_txt("extra_charge"), 25, 1, YELLOW if _blink(t, 0.15) else WHITE)


## N: a white flash, a shock ring and a mushroom cloud, "NUCLEAR!".
func pu_N(p, t: float) -> void:
	if t < 0.18:
		p.block(0, 0, 128, 32, WHITE * (1.0 - t / 0.18 * 0.5))
		return
	var k := clampf((t - 0.18) / 1.2, 0.0, 1.0)
	p.ring(20, 29, 6.0 + k * 40.0, ORANGE * (1.0 - k), 0.35)
	# Stem and cap of the mushroom cloud, rising (left panel; the name on the right)
	var top := 22.0 - k * 9.0
	p.block(18, top, 5, 31.0 - top, ORANGE * (0.9 - k * 0.4))
	p.disc(20, top, 5.0 + k * 4.0, YELLOW if k < 0.3 else ORANGE)
	p.disc(20, top - 1.0, 2.5 + k * 2.0, WHITE if k < 0.2 else YELLOW)
	_burst(p, 20, 20, k, 20, 16.0, RED)
	_pu_name(p, t - 0.18)
