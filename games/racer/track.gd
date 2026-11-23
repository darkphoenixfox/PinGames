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
const STEEP_CHANCE := 0.17      # sections that are steep hills (D-143)
const STEEP_GRADE := 0.22
const TUNNEL_MIN := 220.0
const TUNNEL_MAX := 520.0
const TUNNEL_GAP := 1200.0       # m between tunnels
const TUNNEL_FIRST := 900.0      # no tunnel before this
const TUNNEL_CHANCE := 0.35      # of eligible sections
const TUNNEL_MAX_CURV := 1.0 / 260.0
const TUNNEL_MAX_GRADE := 0.06   # no tunnel through a steep hill (D-143)
const TUNNEL_HALF := ROAD_HALF + 0.3   # wall distance from the centre line (road edge)
const TUNNEL_HEIGHT := 6.5
const MAX_TURN := deg_to_rad(110.0)      # per curve section
const MAX_HEADING := deg_to_rad(80.0)    # overall, from the start direction
## Roadside objects: [kind, collision radius]. Kinds are drawn by the view.
const OBJ_RADIUS := {"palm": 0.6, "rock": 1.5, "chevron": 0.5, "lamp": 0.35, "gate": 0.0,
	"bush": 0.0, "sign": 2.5, "gantry": 0.0, "speedtrap": 0.4, "house": 0.0, "lifeguard": 0.0,
	"building": 0.0, "tlight": 0.4, "cactus": 0.5, "mesa": 0.0}
## Areas (D-216): stage 1 is the beach, stage 2 the fields, then each area lasts
## two stages: city, desert, forest, snowy mountain, and round again. The look
## cross-fades into the next area over the last AREA_BLEND m of a stage.
const AREA_CYCLE := ["city", "desert", "forest", "snow"]
const AREA_BLEND := 200.0
## City (D-216): buildings stand behind a sidewalk; the car is held off it by
## a barrier at CITY_WALL (it scrapes along, like a tunnel wall). Junctions
## cross the road every so often.
const CITY_WALL := ROAD_HALF + RUMBLE + 2.6
const SIDEWALK := 5.0                          # m from the kerb to the building line
const JUNCTION_HALF := 7.0                     # half width of a cross street
const JUNCTION_GAP := Vector2(260.0, 420.0)
## Beach stage (D-204): sand and sea on the left (with waves), a flat-ish road,
## small buildings on the right, palms. Blends out over AREA_BLEND m at
## the stage's ends.
const SHORE := ROAD_HALF + RUMBLE + 22.0   # m left of the centre line where the sea starts
const SEA_LEVEL := -1.6                    # m below the road   # bushes are scenery: off-road stays as it was
## Roadside dressing (D-107): bushes line the road densely, green direction
## signs stand on straights, and an overhead gantry spans the road now and then.
const SIGN_EVERY := Vector2(350.0, 650.0)
const GANTRY_EVERY := 1400.0
const TRAPS_FROM_STAGE := 3     # speed cameras start after stage 3 (D-135)
const TRAP_GAP := Vector2(1200.0, 2000.0)

var seed_value := 1
var pos := PackedVector3Array()
var yaw := PackedFloat32Array()
var curv := PackedFloat32Array()
## Roadside objects sorted by s: {s, x, kind, r, dir} (dir: chevron arrow side)
var objects: Array = []
var _rng := RandomNumberGenerator.new()
var _built_to := 0.0   # metres generated so far
var _next_obj_s := 30.0
## Tunnels (D-127): Vector2(s_start, s_end), in order.
var tunnels: Array = []
var _force_tunnel := false
var avoid_every := 0.0          # checkpoint spacing to keep tunnels clear of (set by the sim)
var _next_sign_s := 300.0
var _next_trap_s := -1.0
var _next_gantry_s := 700.0
var _next_bush_s := 20.0
## City junctions (D-216): s of each cross street's centre line, in order.
var junctions: Array = []
var _next_junction_s := -1.0
var _next_bld := [0.0, 0.0]   # next free s for a building, left and right


func setup(seed_in: int = 1) -> void:
	seed_value = seed_in
	_rng.seed = seed_in
	pos = PackedVector3Array([Vector3.ZERO])
	yaw = PackedFloat32Array([0.0])
	curv = PackedFloat32Array([0.0])
	objects.clear()
	_built_to = 0.0
	_next_obj_s = 30.0
	tunnels.clear()
	_next_sign_s = 300.0
	_next_trap_s = -1.0
	_next_gantry_s = 700.0
	_next_bush_s = 20.0
	junctions.clear()
	_next_junction_s = -1.0
	_next_bld = [0.0, 0.0]
	_add_section(START_STRAIGHT, 0.0, 0.0)


## Generates road until at least s_max metres exist.
func ensure(s_max: float) -> void:
	while _built_to < s_max:
		_random_section()


func length() -> float:
	return _built_to


func _random_section() -> void:
	# A tunnel is guaranteed before stage 3 (D-132): once the road reaches the
	# middle of stage 2 without one, a gentle tunnel section is laid there.
	if avoid_every > 0.0 and tunnels.is_empty() and _built_to >= avoid_every * 1.25 			and _built_to < avoid_every * 2.0 - TUNNEL_MIN - 200.0:
		_force_tunnel = true
		_add_section(TUNNEL_MIN + 160.0, 0.0, _rng.randf_range(-1.0, 1.0) * 12.0)
		_force_tunnel = false
		return
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
	var hill := _rng.randf()
	var here := area_at(_built_to)
	var there := area_at(_built_to + len)
	if beach_w(_built_to) > 0.0 or beach_w(_built_to + len) > 0.0 or here == "city" or there == "city":
		dh = _rng.randf_range(-1.0, 1.0) * len * 0.015   # flat-ish on the beach and in town (D-204, D-216)
	elif here == "desert":
		dh = _rng.randf_range(-1.0, 1.0) * len * 0.05    # long gentle rises (D-216)
	elif here == "snow" and hill < 0.45 and _built_to > START_STRAIGHT + 300.0:
		# Mountain road (D-216): climbs and drops more often.
		len = minf(len, 300.0)
		dh = (1.0 if _rng.randf() < 0.5 else -1.0) * len * _rng.randf_range(0.1, STEEP_GRADE)
	elif hill < STEEP_CHANCE and _built_to > START_STRAIGHT + 300.0:
		# Steep climb or drop (D-143): up to STEEP_GRADE average over a
		# shorter section, so it reads as a proper hill.
		len = minf(len, 260.0)
		dh = (1.0 if _rng.randf() < 0.5 else -1.0) * len * _rng.randf_range(0.14, STEEP_GRADE)
	elif hill < 0.7:
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
	if absf(dh) <= (_built_to - s0) * TUNNEL_MAX_GRADE and beach_w(s0) <= 0.0 and beach_w(_built_to) <= 0.0 \
			and area_w(s0, "city") <= 0.0 and area_w(_built_to, "city") <= 0.0:
		_maybe_tunnel(s0, _built_to, c)
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
			if _rng.randf() < 0.5 and area_at(s) != "city":   # no trees among the buildings (D-216)
				_add_obj(s + 6.0, -side * (ROAD_HALF + _rng.randf_range(5.0, 14.0)), "palm")
			_next_obj_s += 18.0
			continue
		if beach_w(s) > 0.5:
			_place_beach(s)
			_next_obj_s += _rng.randf_range(22.0, 34.0)
			continue
		var ar := area_at(s)
		if ar == "city":
			_place_city(s)
			_next_obj_s += 30.0
			continue
		if ar == "desert":
			_place_desert(s)
			_next_obj_s += _rng.randf_range(20.0, 32.0)
			continue
		if ar == "forest" or ar == "snow":
			_place_woods(s, ar == "snow")
			_next_obj_s += _rng.randf_range(9.0, 15.0)
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


## Beach dressing (D-204): palms on the sand by the road (and now and then a
## lifeguard tower near the water), small buildings with palms between them
## on the right, lamps along the promenade.
func _place_beach(s: float) -> void:
	if _rng.randf() < 0.6:
		_add_obj(s + _rng.randf_range(0.0, 8.0), -(ROAD_HALF + RUMBLE + _rng.randf_range(3.0, 12.0)), "palm")
	if _rng.randf() < 0.07:
		_add_obj(s + 4.0, -(SHORE - 4.0), "lifeguard")
	var r := _rng.randf()
	if r < 0.45:
		_add_obj(s + _rng.randf_range(0.0, 6.0), ROAD_HALF + RUMBLE + _rng.randf_range(16.0, 26.0), "house")
	elif r < 0.8:
		_add_obj(s + _rng.randf_range(0.0, 8.0), ROAD_HALF + RUMBLE + _rng.randf_range(4.0, 12.0), "palm")
	if _rng.randf() < 0.3:
		_add_obj(s, ROAD_HALF + 2.5, "lamp")


## City (D-216): street lamps on the sidewalk, buildings in a row on each side
## (gaps at junctions), traffic lights at each junction.
func _place_city(s: float) -> void:
	for side in [-1.0, 1.0]:
		_add_obj(s + (0.0 if side < 0.0 else 15.0), side * (ROAD_HALF + RUMBLE + 1.4), "lamp")
	if _next_junction_s < 0.0:
		_next_junction_s = s + 120.0
	while _next_junction_s < s + 30.0:
		var js := _next_junction_s
		if absf(curvature(js)) < 1.0 / 300.0 and area_at(js) == "city" and not in_tunnel(js):
			junctions.append(js)
			for side in [-1.0, 1.0]:
				_add_obj(js - side * (JUNCTION_HALF + 2.0), side * (ROAD_HALF + RUMBLE + 1.0), "tlight", side)
			_next_junction_s += _rng.randf_range(JUNCTION_GAP.x, JUNCTION_GAP.y)
		else:
			_next_junction_s += 40.0
	for si in 2:
		var side := -1.0 if si == 0 else 1.0
		while float(_next_bld[si]) < s + 30.0:
			var b0: float = maxf(float(_next_bld[si]), s - 30.0)
			var w := _rng.randf_range(12.0, 26.0)
			var j := near_junction(b0 + w * 0.5, w * 0.5 + JUNCTION_HALF + 1.0)
			if j >= 0.0:
				_next_bld[si] = maxf(b0 + 1.0, j + JUNCTION_HALF + 1.0)   # leave the cross street open
				continue
			var o := {"s": b0 + w * 0.5, "x": side * (ROAD_HALF + RUMBLE + SIDEWALK), "kind": "building",
				"r": 0.0, "dir": side, "w": w, "d": _rng.randf_range(14.0, 24.0),
				"h": _rng.randf_range(16.0, 70.0) * (1.6 if _rng.randf() < 0.15 else 1.0),
				"style": _rng.randi() % 6}
			if not in_tunnel(o.s):
				objects.append(o)
			_next_bld[si] = b0 + w + _rng.randf_range(0.5, 2.5)


## The junction within `reach` m of s, or -1.
func near_junction(s: float, reach: float) -> float:
	for j in junctions:
		if absf(float(j) - s) <= reach:
			return j
	return -1.0


## Desert (D-216): cacti and dry shrubs, rocks, and big buttes far off.
func _place_desert(s: float) -> void:
	for side in [-1.0, 1.0]:
		var r := _rng.randf()
		var off := ROAD_HALF + _rng.randf_range(4.0, 20.0)
		if r < 0.45:
			_add_obj(s + _rng.randf_range(0.0, 8.0), side * off, "cactus")
		elif r < 0.6:
			_add_obj(s + _rng.randf_range(0.0, 8.0), side * (off + 2.0), "rock")
	if _rng.randf() < 0.22:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		_add_obj(s, side * _rng.randf_range(70.0, 130.0), "mesa")


## Forest and snowy mountain (D-216): trees close and thick on both sides
## (pines; snow-laden spruces up the mountain), rocks now and then.
func _place_woods(s: float, snow: bool) -> void:
	for side in [-1.0, 1.0]:
		var r := _rng.randf()
		var off := ROAD_HALF + RUMBLE + _rng.randf_range(3.0, 22.0)
		if r < (0.6 if snow else 0.75):
			_add_obj(s + _rng.randf_range(0.0, 6.0), side * off, "palm")
		elif r < 0.85:
			_add_obj(s + _rng.randf_range(0.0, 6.0), side * (off + 1.0), "rock")


## Bushes, signs and gantries (D-107); _place_objects re-sorts afterwards.
func _place_dressing(s1: float) -> void:
	while _next_bush_s < s1:
		var s := _next_bush_s
		var bw := beach_w(s)
		var ar := area_at(s)
		for side in [-1.0, 1.0]:
			# On the beach (D-204): no bushes on the sand, fewer on the right.
			# None in town; sparse in the desert and on the snow (D-216).
			var chance := 0.7 * (1.0 - bw) if side < 0.0 else 0.7 * (1.0 - bw * 0.6)
			if ar == "city":
				chance = 0.0
			elif ar == "desert" or ar == "snow":
				chance *= 0.35
			if _rng.randf() < chance:
				_add_obj(s + _rng.randf_range(0.0, 6.0),
					side * (ROAD_HALF + RUMBLE + _rng.randf_range(2.2, 6.5)), "bush")
		_next_bush_s += _rng.randf_range(9.0, 16.0)
	# Speed cameras from stage 4 (D-135): on straights, right-hand verge.
	if _next_trap_s < 0.0 and avoid_every > 0.0:
		_next_trap_s = avoid_every * TRAPS_FROM_STAGE + 300.0
	while _next_trap_s > 0.0 and _next_trap_s < s1:
		if absf(curvature(_next_trap_s)) < 1.0 / 400.0 and not in_tunnel(_next_trap_s):
			_add_obj(_next_trap_s, ROAD_HALF + RUMBLE + 1.6, "speedtrap")
			_next_trap_s += _rng.randf_range(TRAP_GAP.x, TRAP_GAP.y)
		else:
			_next_trap_s += 80.0
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


# --- tunnels (D-127) ---------------------------------------------------------------
## Some gentle sections become tunnels: walls at the road's edges, a roof, no
## roadside objects inside. Kept clear of checkpoints (avoid_every) and the start.
func _maybe_tunnel(s0: float, s1: float, c: float) -> void:
	if s1 - s0 < TUNNEL_MIN + 40.0 or absf(c) > TUNNEL_MAX_CURV or s0 < TUNNEL_FIRST:
		return
	if not tunnels.is_empty() and s0 - (tunnels[-1] as Vector2).y < TUNNEL_GAP:
		return
	if not _force_tunnel and _rng.randf() > TUNNEL_CHANCE:
		return
	var a := s0 + 20.0
	var b := minf(s1 - 20.0, a + TUNNEL_MAX)
	if avoid_every > 0.0:
		# No checkpoint gate inside, or within 60 m of either portal.
		var k := ceilf((a - 60.0) / avoid_every) * avoid_every
		if k <= b + 60.0:
			return
	tunnels.append(Vector2(a, b))


## True when s is inside a tunnel.
func in_tunnel(s: float) -> bool:
	return tunnel_at(s) != Vector2.ZERO


## The tunnel containing s, or Vector2.ZERO.
func tunnel_at(s: float) -> Vector2:
	for t in tunnels:
		var tv: Vector2 = t
		if s >= tv.x and s <= tv.y:
			return tv
		if tv.x > s:
			break
	return Vector2.ZERO


func _add_obj(s: float, x: float, kind: String, dir: float = 1.0) -> void:
	if in_tunnel(s):
		return   # nothing stands inside a tunnel (D-127)
	objects.append({"s": s, "x": x, "kind": kind, "r": OBJ_RADIUS[kind], "dir": dir})


## The next speed camera at or after s, or {} (D-135).
func next_trap(s: float) -> Dictionary:
	for i in range(_lower_bound(s), objects.size()):
		var o: Dictionary = objects[i]
		if o.kind == "speedtrap":
			return o
	return {}


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
	return center(s) + right(s) * x + Vector3(0.0, up + ground_rise(s, x), 0.0)


## 0..1: how much of the beach stage's look applies at s (D-204).
func beach_w(s: float) -> float:
	return area_w(s, "beach")


## The area of stage k (1-based), D-216.
static func stage_area(k: int) -> String:
	if k <= 1:
		return "beach"
	if k == 2:
		return "fields"
	return AREA_CYCLE[((k - 3) / 2) % AREA_CYCLE.size()]


## The stage (1-based) at distance s.
func stage_at(s: float) -> int:
	return 1 if avoid_every <= 0.0 else int(floor(maxf(s, 0.0) / avoid_every)) + 1


## The area whose look dominates at s.
func area_at(s: float) -> String:
	var a := areas(s)
	var best := ""
	var bw := -1.0
	for k in a:
		if float(a[k]) > bw:
			bw = a[k]
			best = k
	return best


## Area weights at s (they sum to 1): the stage's own area, cross-fading into
## the next stage's over the last AREA_BLEND m when it differs (D-216).
func areas(s: float) -> Dictionary:
	if avoid_every <= 0.0:
		return {"fields": 1.0}
	var k := stage_at(s)
	var cur := stage_area(k)
	var nxt := stage_area(k + 1)
	if nxt == cur:
		return {cur: 1.0}
	var t := clampf((s - (k * avoid_every - AREA_BLEND)) / AREA_BLEND, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	if t <= 0.0:
		return {cur: 1.0}
	return {cur: 1.0 - t, nxt: t}


func area_w(s: float, name: String) -> float:
	return float(areas(s).get(name, 0.0))


## Where the car is held at the side of the road at s (D-216): the sidewalk
## barrier in town, else 0 (Sim's open-country wall).
func side_wall(s: float) -> float:
	return CITY_WALL if area_w(s, "city") > 0.5 else 0.0


## Ground height beside the road at s: the embankments, or on the beach the sand
## dipping to the sea on the left and a gentle rise on the right (D-204).
## D-216: each area has its own profile, blended by the area weights: flat in
## town, low dunes in the desert, steep mountainsides on the snow.
func ground_rise(s: float, x: float) -> float:
	var base := terrain_rise(x)
	var a := areas(s)
	if a.size() == 1 and a.has("fields"):
		return base
	var h := 0.0
	for name in a:
		h += _area_rise(name, s, x, base) * float(a[name])
	return h


func _area_rise(name: String, s: float, x: float, base: float) -> float:
	var d := absf(x) - (ROAD_HALF + RUMBLE)
	match name:
		"beach":
			if x < 0.0:
				return SEA_LEVEL * clampf(d / (SHORE - ROAD_HALF - RUMBLE), 0.0, 1.0) if d > 0.0 else 0.0
			return base * 0.25
		"city":
			return 0.0
		"desert":
			var dunes := 1.6 * sin(x * 0.09 + s * 0.013) * sin(s * 0.0045 + x * 0.02)
			return base * 0.5 + dunes * clampf((d - 3.0) / 12.0, 0.0, 1.0)
		"forest":
			return base * 1.3
		"snow":
			return base * 3.2
	return base


## Ground rises gently away from the road (embankments), 0 on the road.
static func terrain_rise(x: float) -> float:
	var d := absf(x) - (ROAD_HALF + RUMBLE + 3.0)
	return 0.0 if d <= 0.0 else d * d * 0.0016


## Road-aligned frame at s: basis looking down the road, pitched with the hill.
func frame(s: float, x: float = 0.0, up: float = 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, heading(s)) * Basis(Vector3.RIGHT, atan(slope(s)))
	return Transform3D(b, point(s, x, up))
