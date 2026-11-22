## TURBO RUN track (D-089): an endless, seeded road made of sections (straights,
## curves of several radii, hills and dips). Pure data, no nodes, so the sim and
## the headless tests can use it.
##
## The road is sampled every SAMPLE metres: centre position + heading (yaw).
## Yaw 0 drives towards -Z (Godot forward); positive curvature turns left.
## Lateral offset x is metres to the right of the centre line.
extends RefCounted

const SAMPLE := 2.0
const ROAD_HALF := 7.5         # 4 lanes of 3.75 m
const LANES := [-5.625, -1.875, 1.875, 5.625]
const RUMBLE := 1.2            # red/white kerb outside the road edge
const START_STRAIGHT := 400.0
const MAX_TURN := deg_to_rad(110.0)      # per curve section
const MAX_HEADING := deg_to_rad(80.0)    # overall, from the start direction
## Roadside objects: [kind, collision radius]. Kinds are drawn by the view.
const OBJ_RADIUS := {"palm": 0.6, "rock": 1.5, "chevron": 0.5, "lamp": 0.35, "gate": 0.0,
	"bush": 0.0, "sign": 2.5, "gantry": 0.0}   # bushes are scenery: off-road stays as it was
## Roadside dressing (D-107): bushes line the road densely, green direction
## signs stand on straights, and an overhead gantry spans the road now and then.
const SIGN_EVERY := Vector2(350.0, 650.0)
const GANTRY_EVERY := 1400.0

var seed_value := 1
var pos := PackedVector3Array()
var yaw := PackedFloat32Array()
var curv := PackedFloat32Array()
## Roadside objects sorted by s: {s, x, kind, r, dir} (dir: chevron arrow side)
var objects: Array = []
var _rng := RandomNumberGenerator.new()
var _built_to := 0.0   # metres generated so far
var _next_obj_s := 30.0
var _next_sign_s := 300.0
var _next_gantry_s := 700.0
var _next_bush_s := 20.0


func setup(seed_in: int = 1) -> void:
	seed_value = seed_in
	_rng.seed = seed_in
	pos = PackedVector3Array([Vector3.ZERO])
	yaw = PackedFloat32Array([0.0])
	curv = PackedFloat32Array([0.0])
	objects.clear()
	_built_to = 0.0
	_next_obj_s = 30.0
	_next_sign_s = 300.0
	_next_gantry_s = 700.0
	_next_bush_s = 20.0
	_add_section(START_STRAIGHT, 0.0, 0.0)


## Generates road until at least s_max metres exist.
func ensure(s_max: float) -> void:
	while _built_to < s_max:
		_random_section()


func length() -> float:
	return _built_to


func _random_section() -> void:
	var roll := _rng.randf()
	var radius := 0.0
	if roll < 0.22:
		radius = 0.0                                # straight
	elif roll < 0.5:
		radius = _rng.randf_range(260.0, 420.0)     # sweeping
	elif roll < 0.78:
		radius = _rng.randf_range(130.0, 200.0)     # medium
	else:
		radius = _rng.randf_range(75.0, 105.0)      # hairpin-ish: drift or brake
	var c := 0.0 if radius == 0.0 else (1.0 / radius) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var len := _rng.randf_range(180.0, 420.0)
	if c != 0.0:
		# A section turns at most MAX_TURN, and the road's overall heading stays
		# within MAX_HEADING of the start, so the road never loops back over
		# itself (its hillsides would cross the track, D-094). The eased
		# curvature integrates to ~0.7 of c * len.
		len = minf(len, MAX_TURN / (absf(c) * 0.7))
		var y := yaw[yaw.size() - 1]
		if absf(y + c * len * 0.7) > MAX_HEADING:
			c = -c
		if absf(y + c * len * 0.7) > MAX_HEADING:
			len = maxf(60.0, (MAX_HEADING - absf(y)) / (absf(c) * 0.7))
	var dh := 0.0
	if _rng.randf() < 0.7:
		dh = _rng.randf_range(-1.0, 1.0) * len * 0.1
	_add_section(len, c, dh)


## A section eases its curvature in and out (first/last 30 %) and its height
## along a smoothstep, so joins are smooth.
func _add_section(len: float, c: float, dh: float) -> void:
	var n := int(len / SAMPLE)
	var i0 := pos.size() - 1
	var h0 := pos[i0].y
	for k in range(1, n + 1):
		var t := float(k) / n
		var ease := clampf(minf(t, 1.0 - t) / 0.3, 0.0, 1.0)
		ease = ease * ease * (3.0 - 2.0 * ease)
		var ck := c * ease
		var y := yaw[yaw.size() - 1] + ck * SAMPLE
		var fwd := Vector3(-sin(y), 0.0, -cos(y))
		var p := pos[pos.size() - 1] + fwd * SAMPLE
		p.y = h0 + dh * (t * t * (3.0 - 2.0 * t))
		pos.append(p)
		yaw.append(y)
		curv.append(ck)
	var s0 := _built_to
	_built_to = (pos.size() - 1) * SAMPLE
	_place_objects(s0, _built_to)


func _place_objects(s0: float, s1: float) -> void:
	# Objects must stay sorted by s (objects_between binary-searches them):
	# re-sort the stretch this section touches once it is placed.
	var from := _lower_bound(s0 - 60.0)
	_place_dressing(s1)
	_place_props(s1)
	var tail := objects.slice(from)
	tail.sort_custom(func(a, b): return a.s < b.s)
	for i in tail.size():
		objects[from + i] = tail[i]


func _place_props(s1: float) -> void:
	while _next_obj_s < s1:
		var s := _next_obj_s
		var c := curvature(s)
		if absf(c) > 1.0 / 220.0:
			# Chevrons on the outside of the curve, pointing the way it turns.
			var side := 1.0 if c > 0.0 else -1.0   # left turn -> outside is +x
			_add_obj(s, side * (ROAD_HALF + 3.0), "chevron", -side)
			if _rng.randf() < 0.5:
				_add_obj(s + 6.0, -side * (ROAD_HALF + _rng.randf_range(5.0, 14.0)), "palm")
			_next_obj_s += 18.0
			continue
		for side in [-1.0, 1.0]:
			var r := _rng.randf()
			var off := ROAD_HALF + _rng.randf_range(3.5, 16.0)
			if r < 0.55:
				_add_obj(s + _rng.randf_range(0.0, 8.0), side * off, "palm")
			elif r < 0.7:
				_add_obj(s + _rng.randf_range(0.0, 8.0), side * (off + 2.0), "rock")
			elif r < 0.85:
				_add_obj(s, side * (ROAD_HALF + 2.5), "lamp")
		_next_obj_s += _rng.randf_range(22.0, 34.0)


## Bushes, signs and gantries (D-107); _place_objects re-sorts afterwards.
func _place_dressing(s1: float) -> void:
	while _next_bush_s < s1:
		var s := _next_bush_s
		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.7:
				_add_obj(s + _rng.randf_range(0.0, 6.0),
					side * (ROAD_HALF + RUMBLE + _rng.randf_range(2.2, 6.5)), "bush")
		_next_bush_s += _rng.randf_range(9.0, 16.0)
	while _next_sign_s < s1:
		if absf(curvature(_next_sign_s)) < 1.0 / 400.0:
			_add_obj(_next_sign_s, ROAD_HALF + RUMBLE + 5.5, "sign")
		_next_sign_s += _rng.randf_range(SIGN_EVERY.x, SIGN_EVERY.y)
	while _next_gantry_s < s1:
		if absf(curvature(_next_gantry_s)) < 1.0 / 500.0:
			_add_obj(_next_gantry_s, 0.0, "gantry")
			_next_gantry_s += GANTRY_EVERY
		else:
			_next_gantry_s += 60.0   # try a bit further on, out of the bend


func _add_obj(s: float, x: float, kind: String, dir: float = 1.0) -> void:
	objects.append({"s": s, "x": x, "kind": kind, "r": OBJ_RADIUS[kind], "dir": dir})


## Index range [a, b) of objects with s in [s0, s1).
func objects_between(s0: float, s1: float) -> Array:
	var out: Array = []
	var lo := _lower_bound(s0)
	for i in range(lo, objects.size()):
		var o: Dictionary = objects[i]
		if o.s >= s1:
			break
		out.append(o)
	return out


func _lower_bound(s: float) -> int:
	var lo := 0
	var hi := objects.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if objects[mid].s < s:
			lo = mid + 1
		else:
			hi = mid
	return lo


func _idx(s: float) -> Array:
	var f := clampf(s / SAMPLE, 0.0, float(pos.size() - 1) - 0.001)
	var i := int(f)
	return [i, f - i]


func curvature(s: float) -> float:
	var a := _idx(s)
	return lerpf(curv[a[0]], curv[a[0] + 1], a[1])


func heading(s: float) -> float:
	var a := _idx(s)
	return lerpf(yaw[a[0]], yaw[a[0] + 1], a[1])


func center(s: float) -> Vector3:
	var a := _idx(s)
	return pos[a[0]].lerp(pos[a[0] + 1], a[1])


func slope(s: float) -> float:
	var a := _idx(s)
	return (pos[a[0] + 1].y - pos[a[0]].y) / SAMPLE


## Horizontal right vector at s.
func right(s: float) -> Vector3:
	var y := heading(s)
	return Vector3(cos(y), 0.0, -sin(y))


## Point on the road surface at distance s, lateral offset x (+ height above).
func point(s: float, x: float, up: float = 0.0) -> Vector3:
	return center(s) + right(s) * x + Vector3(0.0, up + terrain_rise(x), 0.0)


## Ground rises gently away from the road (embankments), 0 on the road.
static func terrain_rise(x: float) -> float:
	var d := absf(x) - (ROAD_HALF + RUMBLE + 3.0)
	return 0.0 if d <= 0.0 else d * d * 0.0016


## Road-aligned frame at s: basis looking down the road, pitched with the hill.
func frame(s: float, x: float = 0.0, up: float = 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, heading(s)) * Basis(Vector3.RIGHT, atan(slope(s)))
	return Transform3D(b, point(s, x, up))
