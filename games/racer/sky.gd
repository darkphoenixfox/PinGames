## TURBO RUN time of day (D-193): race progress -> hour -> sun and moon
## directions -> the sky palette and the scene lighting. Pure functions, so the
## tests can check them; game.gd feeds the result to the sky shader
## (shaders/sky.gdshader), the sun light, the ambient light and the fog.
##
## Stages (the director's spec): 1-3 daylight with the sun coming down, 4-5
## sunset (the sun sets late in stage 5), 6-9 night with the moon and stars,
## dawn in stage 10, then the day goes on.
extends RefCounted

const MAX_ELEVATION := 50.0   # degrees at noon
## Race progress (stages played, fractional) -> hour of the day.
const PROGRESS_HOURS := [
	[0.0, 13.0],   # stage 1 starts in the early afternoon
	[3.0, 16.4],   # stage 4: the sun is getting low
	[5.0, 18.3],   # stage 6: just set, twilight
	[9.0, 29.6],   # stage 10: before sunrise (05:36)
	[10.0, 30.6],  # stage 11: sun up
]
const LATE_HOURS_PER_STAGE := 1.2   # after stage 11 the day goes on at this pace

## Palette keyframes by the sun's elevation (degrees), high to low.
const KEYS := [
	{"el": 45.0, "zenith": Color(0.12, 0.33, 0.8), "horizon": Color(0.62, 0.8, 0.96), "glow": Color(0.85, 0.9, 1.0), "glow_k": 0.2,
		"sun": Color(1.0, 0.98, 0.9), "cloud_lit": Color(1.0, 1.0, 1.0), "cloud_shade": Color(0.72, 0.78, 0.88),
		"ridge_far": Color(0.52, 0.62, 0.74), "ridge_near": Color(0.3, 0.4, 0.46),
		"light": Color(1.0, 0.97, 0.9), "light_e": 1.25, "amb": Color(0.75, 0.8, 0.9), "amb_e": 0.85},
	{"el": 15.0, "zenith": Color(0.16, 0.36, 0.78), "horizon": Color(0.76, 0.82, 0.88), "glow": Color(1.0, 0.86, 0.62), "glow_k": 0.35,
		"sun": Color(1.0, 0.93, 0.75), "cloud_lit": Color(1.0, 0.95, 0.86), "cloud_shade": Color(0.64, 0.66, 0.78),
		"ridge_far": Color(0.52, 0.56, 0.7), "ridge_near": Color(0.28, 0.34, 0.44),
		"light": Color(1.0, 0.9, 0.75), "light_e": 1.15, "amb": Color(0.8, 0.76, 0.82), "amb_e": 0.8},
	{"el": 3.0, "zenith": Color(0.22, 0.24, 0.55), "horizon": Color(1.0, 0.62, 0.38), "glow": Color(1.0, 0.5, 0.25), "glow_k": 0.75,
		"sun": Color(1.0, 0.72, 0.35), "cloud_lit": Color(1.0, 0.62, 0.45), "cloud_shade": Color(0.55, 0.35, 0.5),
		"ridge_far": Color(0.55, 0.35, 0.55), "ridge_near": Color(0.3, 0.18, 0.38),
		"light": Color(1.0, 0.75, 0.55), "light_e": 1.0, "amb": Color(0.85, 0.65, 0.8), "amb_e": 0.7},
	{"el": -3.0, "zenith": Color(0.14, 0.12, 0.36), "horizon": Color(0.8, 0.35, 0.35), "glow": Color(0.95, 0.35, 0.25), "glow_k": 0.7,
		"sun": Color(1.0, 0.45, 0.2), "cloud_lit": Color(0.9, 0.45, 0.45), "cloud_shade": Color(0.35, 0.22, 0.4),
		"ridge_far": Color(0.35, 0.22, 0.42), "ridge_near": Color(0.18, 0.12, 0.26),
		"light": Color(0.9, 0.55, 0.5), "light_e": 0.6, "amb": Color(0.6, 0.45, 0.65), "amb_e": 0.55},
	{"el": -9.0, "zenith": Color(0.05, 0.06, 0.18), "horizon": Color(0.2, 0.16, 0.32), "glow": Color(0.35, 0.18, 0.3), "glow_k": 0.4,
		"sun": Color(1.0, 0.45, 0.2), "cloud_lit": Color(0.3, 0.25, 0.4), "cloud_shade": Color(0.12, 0.12, 0.24),
		"ridge_far": Color(0.12, 0.12, 0.24), "ridge_near": Color(0.06, 0.07, 0.15),
		"light": Color(0.55, 0.65, 1.0), "light_e": 0.25, "amb": Color(0.3, 0.36, 0.62), "amb_e": 0.45},
	{"el": -20.0, "zenith": Color(0.02, 0.03, 0.09), "horizon": Color(0.06, 0.08, 0.18), "glow": Color(0.06, 0.08, 0.18), "glow_k": 0.0,
		"sun": Color(1.0, 0.45, 0.2), "cloud_lit": Color(0.14, 0.16, 0.26), "cloud_shade": Color(0.06, 0.07, 0.14),
		"ridge_far": Color(0.07, 0.08, 0.17), "ridge_near": Color(0.03, 0.04, 0.09),
		"light": Color(0.55, 0.65, 1.0), "light_e": 0.22, "amb": Color(0.3, 0.36, 0.62), "amb_e": 0.4},
]


## Hour of the day (may run past 24) for race progress p (stages played).
static func hour_at(p: float) -> float:
	var keys: Array = PROGRESS_HOURS
	if p <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if p <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], (p - a[0]) / (b[0] - a[0]))
	var last: Array = keys[keys.size() - 1]
	return last[1] + (p - last[0]) * LATE_HOURS_PER_STAGE


## The sun's elevation in degrees: up from 6:00, highest at 12:00, down at 18:00.
static func sun_elevation(hour: float) -> float:
	return MAX_ELEVATION * sin(PI * (fposmod(hour, 24.0) - 6.0) / 12.0)


## Azimuth (degrees from the road's start direction, -Z; positive = right):
## behind at sunrise, to the right at noon, ahead at sunset.
static func sun_azimuth(hour: float) -> float:
	return (18.0 - fposmod(hour, 24.0)) / 12.0 * 180.0


static func direction(az_deg: float, el_deg: float) -> Vector3:
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(el_deg)
	return Vector3(cos(el) * sin(az), sin(el), -cos(el) * cos(az))


static func sun_dir(hour: float) -> Vector3:
	return direction(sun_azimuth(hour), sun_elevation(hour))


## The moon: up while the sun is down, ahead and to the left of the road's
## start (where the player looks), rising to about 30 degrees at midnight.
static func moon_dir(hour: float) -> Vector3:
	var h := fposmod(hour, 24.0)
	var drift := (h - 18.0 if h >= 12.0 else h + 6.0) / 12.0   # 0 at 18:00 .. 1 at 06:00
	return direction(-40.0 + 30.0 * drift, -sun_elevation(hour) * 0.6)


## The palette at a sun elevation: each key blended between its keyframes.
static func palette(el: float) -> Dictionary:
	var keys: Array = KEYS
	if el >= keys[0].el:
		return keys[0].duplicate()
	for i in range(1, keys.size()):
		if el >= keys[i].el:
			var a: Dictionary = keys[i - 1]
			var b: Dictionary = keys[i]
			var t: float = (float(a.el) - el) / (float(a.el) - float(b.el))
			var out := {}
			for k in a:
				out[k] = lerp(a[k], b[k], t)
			return out
	return keys[keys.size() - 1].duplicate()


## 0 day .. 1 night, for the car lights, lamps and night sprites.
static func night_level(el: float) -> float:
	return 1.0 - smoothstep(-8.0, 2.0, el)
