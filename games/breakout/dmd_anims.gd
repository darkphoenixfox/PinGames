## Tilt Breaker DMD pixel animations (D-056). Each function draws one frame at
## time t (seconds) with a Dmd.Painter in logical 128x32 dots; the game plays
## them with Dmd.play(Callable(anims, name), DURATIONS[name]).
## Pure drawing: texts are passed in already translated via `texts`.
extends RefCounted

const DURATIONS := {
	"logo": 3.2,
	"tetra_hit": 1.6,
	"incoming": 1.3,
	"charge_lost": 1.5,
	"ship_destroyed": 1.7,
	"rack_clear": 1.8,
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
