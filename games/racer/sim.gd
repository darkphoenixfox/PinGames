## TURBO RUN simulation (D-089): pure race logic, no nodes (headless-tested).
## The car lives in road coordinates: s = metres along the track, x = metres
## right of the centre line. Curves push the car to their outside (centrifugal);
## steering, drifting and braking fight it.
##
## Controls (D-007, D-089):
##   2+1 buttons: flippers steer; throttle AND braking are automatic (the car
##                lifts/brakes by itself when a corner would throw it off).
##   4+1 buttons: magna_r = accelerate, magna_l = brake (manual mode).
##   Both flippers held 2 s = NITRO (uses a charge).
## Drifting: steer INTO a corner at speed (or brake + steer in manual mode).
## A drift keeps almost all the speed through the corner, scores points and
## refills nitro. Not drifting at speed in a tight corner = auto-brake.
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
const DRIFT_NITRO_SECONDS := 4.0 # drifting this long refills one nitro charge
## Nitro
const NITRO_HOLD := 2.0
const NITRO_TIME := 3.0
const NITRO_MAX := 3
## Race clock
const START_TIME := 45.0
const CHECKPOINT_EVERY := 1800.0
const CHECKPOINT_BONUS := 34.0   # minus 2 s per checkpoint passed, never below 20
## Traffic
const CAR_LEN := 4.4
const CAR_W := 1.95
const SPIN_TIME := 1.3
const NEAR_MISS_DX := 3.3
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
var _drift_charge := 0.0
var nitro := NITRO_MAX
var nitro_t := 0.0             # seconds of nitro left
var nitro_hold := 0.0          # seconds both flippers have been held
var spin_t := 0.0              # crash spin-out timer
var time_left := START_TIME
var next_checkpoint := CHECKPOINT_EVERY
var checkpoints := 0
var score := 0
var _score_f := 0.0
var traffic: Array = []        # {id, s, x, v, lane, hue, weave}
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
		if nitro < NITRO_MAX:
			nitro += 1
		events.append(["checkpoint", checkpoints, bonus])
	_add_score(v * dt * 10.0)


func _add_score(p: float) -> void:
	_score_f += p
	score = int(_score_f)


func _nitro(dt: float, both: bool) -> void:
	if nitro_t > 0.0:
		nitro_t -= dt
		if nitro_t <= 0.0:
			events.append(["nitro_end"])
	if both and nitro_t <= 0.0:
		if nitro_hold == 0.0:
			events.append(["nitro_hold", nitro > 0])
		nitro_hold += dt
		if nitro_hold >= NITRO_HOLD and nitro_hold - dt < NITRO_HOLD:
			if nitro > 0:
				nitro -= 1
				nitro_t = NITRO_TIME
				events.append(["nitro", nitro])
			else:
				events.append(["nitro_empty"])
	else:
		if nitro_hold > 0.0 and nitro_hold < NITRO_HOLD:
			events.append(["nitro_cancel"])
		nitro_hold = 0.0


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
	var vmax := NITRO_SPEED if nitro_t > 0.0 else MAX_SPEED
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
	if nitro_t > 0.0 and spin_t <= 0.0:
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
			_drift_charge += dt
			if _drift_charge >= DRIFT_NITRO_SECONDS:
				_drift_charge -= DRIFT_NITRO_SECONDS
				if nitro < NITRO_MAX:
					nitro += 1
					events.append(["nitro_gain", nitro])
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


func _crash(kind: String) -> void:
	_end_drift()
	spin_t = SPIN_TIME
	v = minf(v, 14.0)
	nitro_t = 0.0
	events.append(["crash", kind])


func _collide_objects() -> void:
	if spin_t > 0.0:
		return
	for o in track.objects_between(s - 2.0, s + 2.5):
		if o.r <= 0.0:
			continue
		if absf(x - o.x) < o.r + CAR_W * 0.5:
			_crash(o.kind)
			x = move_toward(x, 0.0, 2.5)  # bounce back towards the road
			return


# --- traffic -------------------------------------------------------------------------
func traffic_target() -> int:
	return mini(3 + checkpoints, 9)


func _update_traffic(dt: float) -> void:
	for i in range(traffic.size() - 1, -1, -1):
		var t: Dictionary = traffic[i]
		var prev_ds: float = t.last_ds
		t.s += t.v * dt
		t.weave += dt
		t.x = Track.LANES[t.lane] + sin(t.weave * 0.4) * 0.6
		var ds: float = t.s - s
		t.last_ds = ds
		if state == State.RACE and prev_ds > 0.0 and ds <= 0.0:
			if absf(t.x - x) < NEAR_MISS_DX and spin_t <= 0.0:
				_add_score(5000.0)
				events.append(["near_miss", t.id])
			else:
				_add_score(500.0)
				events.append(["pass", t.id])
		if state == State.RACE and spin_t <= 0.0 and absf(ds) < CAR_LEN and absf(t.x - x) < CAR_W:
			var rel: float = v - t.v
			if ds > 0.0 and rel > 22.0:
				_crash("car")
				s = t.s - CAR_LEN
			else:
				# Bump: lose speed, get shoved sideways.
				v = minf(v, t.v * 0.85) if ds > 0.0 else v
				x += signf(x - t.x + 0.01) * 1.2
				t.v = minf(t.v + 4.0, 52.0)
				events.append(["bump", t.id])
		if ds < -40.0 or ds > 900.0:
			traffic.remove_at(i)
	if state == State.OVER:
		return
	if traffic.size() < traffic_target():
		var ahead := 380.0 + _rng.randf() * 250.0
		var lane := _rng.randi_range(0, Track.LANES.size() - 1)
		for t in traffic:  # keep spawns apart
			if absf(t.s - (s + ahead)) < 30.0 and t.lane == lane:
				return
		traffic.append({"id": _next_id, "s": s + ahead, "x": Track.LANES[lane], "lane": lane,
			"v": _rng.randf_range(28.0, 46.0), "hue": _rng.randf(), "weave": _rng.randf() * 10.0, "last_ds": ahead})
		_next_id += 1


## Attract/dev autopilot: aim for a lane that's free ahead and steer to it.
func _autopilot() -> float:
	var look := s + 25.0
	var c := track.curvature(look)
	var target := -c * 900.0                     # hug the inside a little
	for t in traffic:
		var ds: float = t.s - s
		if ds > 0.0 and ds < 60.0 and absf(t.x - target) < 3.0:
			target = t.x + (4.5 if t.x < 0.0 else -4.5)
	target = clampf(target, -Track.ROAD_HALF + 1.5, Track.ROAD_HALF - 1.5)
	var predicted := x + c * v * v * CENTRIFUGAL * 0.35
	return clampf((target - predicted) * 0.6, -1.0, 1.0)
