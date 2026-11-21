## Tilt Breaker backglass light show (D-058). Three light groups on the
## director's art — ENGINES (exhaust flames), SHOTS (plasma comets), IMPACTS
## (hits/lightning) — are driven by game events. Pure logic: call levels(delta)
## every frame and feed the result to backglass_lights.gdshader.
extends RefCounted

const ENGINES := Vector3(1, 0, 0)
const SHOTS := Vector3(0, 1, 0)
const IMPACTS := Vector3(0, 0, 1)
const ALL := Vector3(1, 1, 1)

## 0..1 extra engine glow (the game sets it from the ship's speed).
var engine_drive := 0.0
## 0..1 steady shots glow while a blast is charging.
var charge := 0.0
var _pulses: Array = []  # {groups: Vector3, t, dur, hz, strength}
var _chase_left := 0.0
var _dark := false
var _time := 0.0


## Blink `groups` on/off at `hz` for `dur` seconds, fading out.
func pulse(groups: Vector3, dur: float, hz: float = 12.0, strength: float = 1.0) -> void:
	_pulses.append({"groups": groups, "t": 0.0, "dur": dur, "hz": hz, "strength": strength})


## Light the groups one after another (engines -> shots -> impacts) for `dur` s.
func chase(dur: float) -> void:
	_chase_left = dur


## All lights off (game over) or back to normal.
func set_dark(dark: bool) -> void:
	_dark = dark
	if dark:
		_pulses.clear()
		_chase_left = 0.0


func levels(delta: float) -> Vector3:
	_time += delta
	if _dark:
		return Vector3.ZERO
	var breathe := 0.14 + 0.1 * sin(_time * 2.2)  # idle engines
	var l := Vector3(maxf(breathe, engine_drive), charge * (0.6 + 0.4 * sin(_time * 18.0)), 0.0)
	for i in range(_pulses.size() - 1, -1, -1):
		var p: Dictionary = _pulses[i]
		p.t += delta
		if p.t >= p.dur:
			_pulses.remove_at(i)
			continue
		var on := 1.0 if fmod(p.t * p.hz, 1.0) < 0.5 else 0.0
		var amp: float = p.strength * sqrt(1.0 - p.t / p.dur) * on
		var g: Vector3 = p.groups
		l = Vector3(maxf(l.x, g.x * amp), maxf(l.y, g.y * amp), maxf(l.z, g.z * amp))
	if _chase_left > 0.0:
		_chase_left -= delta
		match int(_time * 7.0) % 3:
			0:
				l.x = 1.0
			1:
				l.y = 1.0
			_:
				l.z = 1.0
	return l.clamp(Vector3.ZERO, Vector3.ONE)
