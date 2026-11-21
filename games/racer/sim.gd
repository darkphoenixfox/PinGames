## TURBO RUN simulation (D-089): pure race logic, no nodes (headless-tested).
## The car lives in road coordinates: s = metres along the track, x = metres
## right of the centre line. Curves push the car to their outside (centrifugal);
## steering, drifting and braking fight it.
##
## Controls (D-007, D-089):
##   2+1 buttons: flippers steer; throttle AND braking are automatic (the car
##                lifts/brakes by itself when a corner would throw it off).
##   4+1 buttons: magna_r = accelerate, magna_l = brake (manual mode).
##   Both flippers held = NITRO: burns the nitro bar for as long as they are
##   held; the bar recovers by itself when not in use (D-097).
## Drifting: steer INTO a corner at speed (or brake + steer in manual mode).
## A drift keeps almost all the speed through the corner, scores points and
## speeds up nitro recovery. Not drifting at speed in a tight corner = auto-brake.
## Events (cleared each step): [name, args...]
extends RefCounted

const Track = preload("res://games/racer/track.gd")

enum State { COUNTDOWN, RACE, OVER }

const MAX_SPEED := 80.0        # m/s (288 km/h)
const NITRO_SPEED := 100.0     # m/s while nitro burns
const ACCEL := 13.0
const BRAKE := 22.0
const COAST_DRAG := 4.0
const STEER := 12.0            # lateral m/s at full steering authority
const CENTRIFUGAL := 0.21      # lateral push = curvature * v^2 * this
const OFFROAD_SPEED := 36.0
const OFFROAD_DRAG := 26.0
const WALL := Track.ROAD_HALF + 26.0
## Drift
const DRIFT_MIN_SPEED := 42.0
const DRIFT_MIN_CURV := 1.0 / 260.0
const DRIFT_ENTRY_HOLD := 0.12   # s of steering into the corner before it breaks loose
const DRIFT_EXIT_HOLD := 0.25    # s without steering before it grips again
const DRIFT_GRIP := 0.45         # fraction of the centrifugal push felt while drifting
const DRIFT_STEER := 1.25
const DRIFT_DRAG := 2.5
const DRIFT_ANGLE := 32.0        # degrees (visual + score feel)
## Nitro bar (D-097): 0..1, burned while both flippers are held.
const NITRO_ENGAGE := 0.15       # s both held before it burns (ignores a stray double tap)
const NITRO_BURN := 4.0          # s a full bar lasts
const NITRO_RECOVER := 14.0      # s to refill from empty when not in use
const NITRO_RECOVER_DELAY := 1.0 # s after a burn before it starts recovering
const NITRO_DRIFT_RATE := 0.06   # extra bar per second while drifting
const NITRO_CHECKPOINT := 0.3    # bar added at each checkpoint
## Race clock
const START_TIME := 45.0
const CHECKPOINT_EVERY := 1800.0
const CHECKPOINT_BONUS := 34.0   # minus 2 s per checkpoint passed, never below 20
## Traffic
const CAR_LEN := 4.4
const CAR_W := 1.95
const SPIN_TIME := 1.3
## Hitting a big roadside object (D-098) rolls the car over sideways instead.
const FLIP_TIME := 2.0
const FLIP_KINDS := ["palm", "rock", "lamp", "truck"]
const NEAR_MISS_DX := 3.3
const TRUCK_LEN := 10.0
const TRUCK_W := 2.66
const TRUCK_SHARE := 0.25       # of spawns (D-099)
const MAX_TRUCKS := 3
const ONCOMING_SHARE := 0.4
const START_S := 30.0           # leaves road behind the car for the chase camera
const START_LINE := 50.0

var track := Track.new()
var state := State.COUNTDOWN
var countdown := 3.0
var events: Array = []
var manual := false            # 4-button throttle/brake (auto-detected or forced)
var autopilot := false         # attract demo + dev screenshots

var s := START_S
var x := 0.0
var v := 0.0
var steer := 0.0               # -1..1 smoothed steering (for the view)
var throttle := 0.0
var braking := false
var auto_braking := false
var offroad := false
var drifting := false
var drift_dir := 0.0           # +1 = drifting left (nose left), -1 right
var drift_angle := 0.0         # degrees, signed like drift_dir
var drift_points := 0.0
var _drift_entry := 0.0
var _drift_exit := 0.0
var nitro := 1.0               # nitro bar 0..1
var boosting := false          # nitro burning this step
var nitro_hold := 0.0          # seconds both flippers have been held
var _nitro_rest := 99.0        # seconds since the last burn
var _nitro_lock := false       # emptied (or crashed): release both before it burns again
var spin_t := 0.0              # crash timer (spin-out or flip)
var flipping := false          # this crash is a roll-over (big obstacle)
var flip_dir := 1.0            # +1 rolls to the right, -1 to the left
var time_left := START_TIME
var next_checkpoint := CHECKPOINT_EVERY
var checkpoints := 0
var score := 0
var _score_f := 0.0
var traffic: Array = []        # {id, s, x, v, lane, hue, weave, last_ds, kind, len, w}
var _next_id := 0
var _rng := RandomNumberGenerator.new()
var over_t := 0.0
var done := false


func setup(seed_in: int = 7) -> void:
	_rng.seed = seed_in * 31 + 5
	track.setup(seed_in)
	track.ensure(2000.0)


func lane_count() -> int:
	return Track.LANES.size()


func speed_kmh() -> int:
	return int(round(v * 3.6))


func checkpoint_bonus() -> float:
	return maxf(20.0, CHECKPOINT_BONUS - 2.0 * checkpoints)


## left/right = flippers, gas/brake = magna saves (manual mode only).
func step(dt: float, left: bool, right: bool, gas: bool = false, brake: bool = false) -> void:
	events.clear()
	if autopilot:
		var ap := _autopilot()
		left = ap < -0.3
		right = ap > 0.3
	track.ensure(s + 1500.0)
	match state:
		State.COUNTDOWN:
			var before := ceili(countdown)
			countdown -= dt
			if ceili(countdown) < before and countdown > 0.0:
				events.append(["count", ceili(countdown)])
			if countdown <= 0.0:
				state = State.RACE
				events.append(["go"])
			_update_traffic(dt)
			return
		State.OVER:
			over_t += dt
			_drive(dt, false, false, false, true)
			_update_traffic(dt)
			if v < 1.0 and over_t > 1.5:
				done = true
			return
	time_left -= dt
	if time_left <= 0.0:
		time_left = 0.0
		state = State.OVER
		_end_drift()
		events.append(["time_up"])
		return
	_nitro(dt, left and right)
	if left and right:
		left = false
		right = false
	_drive(dt, left, right, gas, brake)
	_update_traffic(dt)
	_collide_objects()
	if s >= next_checkpoint:
		checkpoints += 1
		var bonus := checkpoint_bonus()
		time_left += bonus
		next_checkpoint += CHECKPOINT_EVERY
		_add_score(20000.0)
		nitro = minf(1.0, nitro + NITRO_CHECKPOINT)
		events.append(["checkpoint", checkpoints, bonus])
	_add_score(v * dt * 10.0)


func _add_score(p: float) -> void:
	_score_f += p
	score = int(_score_f)


func _nitro(dt: float, both: bool) -> void:
	var was := boosting
	if not both:
		nitro_hold = 0.0
		_nitro_lock = false
	else:
		nitro_hold += dt
	boosting = both and not _nitro_lock and nitro_hold >= NITRO_ENGAGE and nitro > 0.0 and spin_t <= 0.0
	if boosting:
		nitro = maxf(0.0, nitro - dt / NITRO_BURN)
		_nitro_rest = 0.0
		if nitro <= 0.0:
			boosting = false
			_nitro_lock = true
			events.append(["nitro_empty"])
	else:
		_nitro_rest += dt
		if _nitro_rest >= NITRO_RECOVER_DELAY:
			nitro = minf(1.0, nitro + dt / NITRO_RECOVER)
		if both and nitro_hold >= NITRO_ENGAGE and nitro_hold - dt < NITRO_ENGAGE and nitro <= 0.0:
			events.append(["nitro_empty"])
	if boosting and not was:
		events.append(["nitro"])
	elif was and not boosting:
		events.append(["nitro_end"])


func _drive(dt: float, left: bool, right: bool, gas: bool, brake: bool) -> void:
	var want := (1.0 if right else 0.0) - (1.0 if left else 0.0)
	if spin_t > 0.0:
		spin_t -= dt
		want = 0.0
	steer = move_toward(steer, want, dt * 6.0)
	var c := track.curvature(s)
	var push := c * v * v * CENTRIFUGAL           # to the outside: +x on a left curve
	var authority := clampf(v / 25.0, 0.3, 1.0) * STEER
	_update_drift(dt, want, c, brake)
	var vmax := NITRO_SPEED if boosting else MAX_SPEED
	# Throttle and brakes
	var accel := 0.0
	auto_braking = false
	if state == State.OVER or spin_t > 0.0:
		throttle = 0.0
		braking = state == State.OVER
		accel = -(BRAKE * 0.5 if state == State.OVER else COAST_DRAG * 3.0)
	elif manual:
		throttle = 1.0 if gas else 0.0
		braking = brake
		accel = (ACCEL * (1.0 - pow(v / vmax, 2.0)) if gas else -COAST_DRAG) - (BRAKE if brake else 0.0)
	else:
		throttle = 1.0
		braking = false
		accel = ACCEL * (1.0 - pow(minf(v / vmax, 1.2), 2.0))
		# Auto-brake: a corner would throw the car off and it isn't drifting.
		if not drifting and absf(push) > authority * 0.95 and push * x > 0.0 and absf(x) > Track.ROAD_HALF * 0.35:
			auto_braking = true
			braking = true
			throttle = 0.0
			accel = -BRAKE * 0.8
	if boosting and spin_t <= 0.0:
		accel = maxf(accel, ACCEL * 1.8 * (1.0 - v / NITRO_SPEED))
	if drifting:
		accel -= DRIFT_DRAG
	if v > vmax:
		accel = minf(accel, -6.0)
	offroad = absf(x) > Track.ROAD_HALF + Track.RUMBLE
	if offroad and v > OFFROAD_SPEED:
		accel = minf(accel, -OFFROAD_DRAG)
	# Gravity on hills: a little slower uphill, faster downhill.
	accel -= track.slope(s) * 9.8 * 0.5
	v = maxf(0.0, v + accel * dt)
	if state == State.OVER or spin_t > 0.0:
		v = maxf(0.0, v)
	# Lateral motion
	var lat := want * authority
	if drifting:
		lat = want * authority * DRIFT_STEER + push * DRIFT_GRIP
	else:
		lat += push
	if spin_t > 0.0:
		lat = push * 0.5
	x = clampf(x + lat * dt, -WALL, WALL)
	s += v * dt


func _update_drift(dt: float, want: float, c: float, brake: bool) -> void:
	var into := want != 0.0 and want * c < 0.0     # steering towards the inside
	if not drifting:
		var can := v > DRIFT_MIN_SPEED and spin_t <= 0.0 and state == State.RACE
		if can and into and absf(c) > DRIFT_MIN_CURV:
			_drift_entry += dt
		else:
			_drift_entry = 0.0
		var flick := manual and brake and want != 0.0 and v > DRIFT_MIN_SPEED * 0.85
		if can and (_drift_entry >= DRIFT_ENTRY_HOLD or flick):
			drifting = true
			drift_dir = -want                      # left steer = nose left = +1
			drift_points = 0.0
			_drift_exit = 0.0
			events.append(["drift_start", drift_dir])
	else:
		var holding := want == -drift_dir
		if holding:
			_drift_exit = 0.0
		else:
			_drift_exit += dt * (2.0 if want == drift_dir else 1.0)
		if _drift_exit >= DRIFT_EXIT_HOLD or v < DRIFT_MIN_SPEED * 0.6 or spin_t > 0.0 or state != State.RACE:
			_end_drift()
		else:
			drift_points += v * dt * 25.0
			if not boosting:
				nitro = minf(1.0, nitro + NITRO_DRIFT_RATE * dt)
	var target := drift_dir * DRIFT_ANGLE if drifting else 0.0
	drift_angle = move_toward(drift_angle, target, dt * (120.0 if drifting else 90.0))


func _end_drift() -> void:
	if not drifting:
		return
	drifting = false
	var pts := int(drift_points / 10.0) * 10
	_add_score(pts)
	events.append(["drift_end", pts])
	drift_points = 0.0


func _crash(kind: String, side: float = 0.0) -> void:
	_end_drift()
	flipping = kind in FLIP_KINDS
	# Rolls away from the obstacle: one on the right (+side) rolls it left.
	flip_dir = -signf(side) if side != 0.0 else 1.0
	spin_t = FLIP_TIME if flipping else SPIN_TIME
	v = minf(v, 10.0 if flipping else 14.0)
	if boosting:
		boosting = false
		events.append(["nitro_end"])
	_nitro_lock = true
	events.append(["crash", kind])


func _collide_objects() -> void:
	if spin_t > 0.0:
		return
	for o in track.objects_between(s - 2.0, s + 2.5):
		if o.r <= 0.0:
			continue
		if absf(x - o.x) < o.r + CAR_W * 0.5:
			_crash(o.kind, o.x - x)
			x = move_toward(x, 0.0, 2.5)  # bounce back towards the road
			return


# --- traffic -------------------------------------------------------------------------
## Right-hand traffic (D-099): the two right lanes (x > 0) drive our way and are
## caught up from behind; the two left lanes are oncoming (dir -1, v < 0).
## Trucks are long and slow and count as a big obstacle (a hit rolls the car).
func traffic_target() -> int:
	return mini(4 + checkpoints, 11)


func _update_traffic(dt: float) -> void:
	for i in range(traffic.size() - 1, -1, -1):
		var t: Dictionary = traffic[i]
		var prev_ds: float = t.last_ds
		var tlen: float = t.get("len", CAR_LEN)
		var tw: float = t.get("w", CAR_W)
		t.s += t.v * dt
		t.weave += dt
		t.x = Track.LANES[t.lane] + sin(t.weave * 0.4) * (0.25 if t.get("kind", "car") == "truck" else 0.6)
		var ds: float = t.s - s
		t.last_ds = ds
		if state == State.RACE and prev_ds > 0.0 and ds <= 0.0:
			if absf(t.x - x) < NEAR_MISS_DX + (tw - CAR_W) * 0.5 and spin_t <= 0.0:
				_add_score(5000.0)
				events.append(["near_miss", t.id])
			else:
				_add_score(500.0)
				events.append(["pass", t.id])
		if state == State.RACE and spin_t <= 0.0 and absf(ds) < (CAR_LEN + tlen) * 0.5 				and absf(t.x - x) < (CAR_W + tw) * 0.5:
			var rel: float = v - t.v
			var big: bool = t.get("kind", "car") == "truck"
			if t.v < 0.0 or (ds > 0.0 and rel > 22.0):
				# Head-on, or rear-ending at speed: a truck rolls the car over.
				_crash("truck" if big else "car", t.x - x)
				s = t.s - (CAR_LEN + tlen) * 0.5 - 0.3
			else:
				# Bump: lose speed, get shoved sideways.
				v = minf(v, t.v * 0.85) if ds > 0.0 else v
				x += signf(x - t.x + 0.01) * 1.2
				if not big:
					t.v = minf(t.v + 4.0, 52.0)
				events.append(["bump", t.id])
		if ds < -60.0 or ds > 900.0:
			traffic.remove_at(i)
	if state == State.OVER:
		return
	if traffic.size() < traffic_target():
		_spawn_traffic()


func _spawn_traffic() -> void:
	var oncoming := _rng.randf() < ONCOMING_SHARE
	var trucks := 0
	for t in traffic:
		if t.get("kind", "car") == "truck":
			trucks += 1
	var truck := trucks < MAX_TRUCKS and _rng.randf() < TRUCK_SHARE
	var lane: int
	var v_t: float
	if oncoming:
		# Oncoming drivers keep to their right: the far-left lane for trucks.
		lane = 0 if truck or _rng.randf() < 0.4 else 1
		v_t = -(_rng.randf_range(18.0, 24.0) if truck else _rng.randf_range(22.0, 36.0))
	else:
		lane = 3 if truck or _rng.randf() < 0.4 else 2
		v_t = _rng.randf_range(20.0, 26.0) if truck else _rng.randf_range(28.0, 46.0)
	# Oncoming traffic closes fast, so it appears further out.
	var ahead := (560.0 if oncoming else 380.0) + _rng.randf() * 250.0
	for t in traffic:  # keep spawns apart
		if absf(t.s - (s + ahead)) < 40.0 and t.lane == lane:
			return
	var kind := "truck" if truck else "car"
	traffic.append({"id": _next_id, "s": s + ahead, "x": Track.LANES[lane], "lane": lane,
		"v": v_t, "hue": _rng.randf(), "weave": _rng.randf() * 10.0, "last_ds": ahead,
		"kind": kind, "len": TRUCK_LEN if truck else CAR_LEN, "w": TRUCK_W if truck else CAR_W})
	_next_id += 1


## Attract/dev autopilot: aim for a lane that's free ahead and steer to it.
func _autopilot() -> float:
	var look := s + 25.0
	var c := track.curvature(look)
	var target := -c * 900.0                     # hug the inside a little
	for t in traffic:
		var ds: float = t.s - s
		var window := 60.0 + (maxf(0.0, -t.v) * 2.0)   # oncoming closes fast
		if ds > 0.0 and ds < window and absf(t.x - target) < 3.0:
			target = t.x + (4.5 if t.x < 0.0 else -4.5)
	target = clampf(target, -Track.ROAD_HALF + 1.5, Track.ROAD_HALF - 1.5)
	var predicted := x + c * v * v * CENTRIFUGAL * 0.35
	return clampf((target - predicted) * 0.6, -1.0, 1.0)
