## TURBO RUN simulation (D-089): pure race logic, no nodes (headless-tested).
## The car lives in road coordinates: s = metres along the track, x = metres
## right of the centre line. Curves push the car to their outside (centrifugal);
## steering, drifting and braking fight it.
##
## Controls (D-007, D-089):
##   2+1 buttons: flippers steer; throttle AND braking are automatic (the car
##                lifts/brakes by itself when a corner would throw it off).
##   4+1 buttons: magna_r = accelerate, magna_l = brake (manual mode).
##   Both flippers held 0.5 s = shift gear L <-> H (D-103). L pulls hard but
##   tops out early; H is slow off the line but reaches top speed.
## NITRO: drive through a canister on the road for 5 s of boost (D-103).
## Drifting: steer INTO a corner at speed (or brake + steer in manual mode).
## A drift keeps almost all the speed through the corner and scores points.
## Not drifting at speed in a tight corner = auto-brake.
## Events (cleared each step): [name, args...]
extends RefCounted

const Track = preload("res://games/racer/track.gd")

enum State { COUNTDOWN, RACE, OVER }

const MAX_SPEED := 80.0        # m/s (288 km/h)
const NITRO_SPEED := 100.0     # m/s while nitro burns (normal car; see CARS)
## Selectable cars (D-122): top speed (m/s, H gear; L tops out at 62.5 % of it)
## and grip (x steering authority, and the bend push is divided by it).
## Easy = slower but sticks to the road; hard = fastest but slides wide.
const CARS := [
	{"name": "RC_CAR_EASY", "hue": 0.0, "top": 72.0, "grip": 1.25},     # red
	{"name": "RC_CAR_NORMAL", "hue": 0.16, "top": 80.0, "grip": 1.0},   # yellow
	{"name": "RC_CAR_HARD", "hue": 0.62, "top": 88.0, "grip": 0.8},     # blue
]
const DEFAULT_CAR := 1
const ACCEL := 13.0
const BRAKE := 22.0
const COAST_DRAG := 4.0
const H_SLIDE := 1.3            # D-120: H gear's extra push to the outside of bends
const L_PUSH := 0.85            # L gear's reduced push
const L_GRIP := 1.3             # L gear's extra steering authority
const STEER_FULL_V := 40.0      # m/s for full steering authority (D-119; was 25 with a 0.3 floor)
const LAT_RESPONSE := 30.0      # m/s^2: how fast sideways speed builds (D-124)
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
## Nitro pick-ups on the road (D-103)
const NITRO_TIME := 5.0          # s of boost per canister
const PICKUP_GAP_MIN := 700.0    # m between canisters
const PICKUP_GAP_MAX := 1200.0
const PICKUP_DX := 1.7           # lateral reach to collect
## Gears (D-103): L = strong pull, low top speed; H = weak pull, full speed.
## rpm 0..1 is v / the gear's top speed; the tachometer's red zone is >= REDLINE.
enum Gear { LOW, HIGH }
const GEAR_L_TOP := 50.0         # m/s (180 km/h), the rev limiter in L
const GEAR_L_PULL := 1.25        # x ACCEL off the line in L
const GEAR_H_PULL_MIN := 0.3     # x ACCEL at 0 rpm in H (lugging) ...
const GEAR_H_PULL_MAX := 1.05    # ... rising to this at 60 % rpm
const SHIFT_HOLD := 0.5          # s both flippers held to shift
const REDLINE := 0.88
## Perfect shift window on the tachometer (D-116): upshift from L in this rpm
## band, just before the redline, for a small boost.
const PERFECT_FROM := 0.69      # D-117: doubled (was 0.78-0.87)
const PERFECT_TO := 0.87
const PERFECT_KICK := 3.0         # m/s added at once
const PERFECT_TIME := 0.8         # s of extra pull after it
const PERFECT_PULL := 0.6         # x ACCEL extra during that time
const PERFECT_POINTS := 2000.0
## The perfect-start window is wider than the shift one, and the revs move
## slower on the grid, so it can be held (D-128).
const START_FROM := 0.58
const START_TO := 0.93
const START_KICK := 12.0          # m/s at GO after a perfect rev (D-118)
const START_PULL_TIME := 1.5      # s of perfect-shift pull after it
const REV_UP := 1.5               # rpm/s while revving on the grid (D-112; slower D-128)
const REV_DOWN := 1.0
## After the clock runs out the car coasts (D-103): reaching a checkpoint
## before it stops extends the time and the race goes on.
const COAST_OVER := 7.0          # m/s^2 decel while coasting out
## Race clock
const START_TIME := 45.0
const CHECKPOINT_EVERY := 2300.0   # D-101 (was 1800)
const CHECKPOINT_BONUS := 34.0   # minus 2 s per checkpoint passed, never below 20
## Traffic
const CAR_LEN := 4.4
const CAR_W := 1.95
const SPIN_TIME := 1.3           # spin-out animation
## Every crash ends with the car stopped dead for CRASH_STOP s (D-101).
const CRASH_STOP := 1.5
const CRASH_GRACE := 5.0         # s immune to traffic once moving again (D-125; 5 s D-126)
const RECOVER_X := Track.ROAD_HALF - 1.9   # outer lane: where an off-road crash is put back
## Hitting a big roadside object (D-098) rolls the car over sideways instead.
const FLIP_TIME := 1.33          # roll-over animation (D-105: 1.5x faster than 2.0)
## A roll-over keeps tumbling down the road (D-105), then lands on its side and
## keeps sliding until friction stops it (D-106), and only then the CRASH_STOP.
const FLIP_SPEED := 30.0
const FLIP_ROLL_DECEL := 6.0     # m/s^2 while rolling
const FLIP_SLIDE_DECEL := 11.0   # m/s^2 sliding on its side after the roll
const FLIP_KINDS := ["palm", "rock", "lamp", "truck", "portal"]
const SCRAPE_DRAG := 9.0        # m/s^2 lost scraping a tunnel wall (D-127)
const NEAR_MISS_DX := 3.3
const TRUCK_LEN := 10.0
const TRUCK_W := 2.66
const TRUCK_SHARE := 0.25       # of spawns (D-099)
const MAX_TRUCKS := 4
const ONCOMING_SHARE := 0.4
const HIGHBEAM_RANGE := 170.0   # m ahead an oncoming driver starts flashing (D-105)
const HIGHBEAM_DX := 2.6        # lateral overlap that counts as "in my lane"
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
var lat_v := 0.0               # m/s sideways (+ = right), for the view's nose angle
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
var boost_t := 0.0             # s of nitro boost left
var boosting := false          # boost_t > 0 this step
var pickups: Array = []        # nitro canisters on the road: {id, s, x}
var _next_pickup_s := 300.0      # the first canister sits on the start straight
var car := DEFAULT_CAR           # index into CARS (D-122)
var gear := Gear.LOW
var _rev_lock_l := false       # flipper held through GO (revving), not steering yet (D-131)
var _rev_lock_r := false
var freeze_time := false       # debug cheat (F in debug builds, D-118)
var perfect_t := 0.0           # s of perfect-shift pull left (D-116)
var rpm := 0.0                 # 0..1 (tachometer)
var shift_hold := 0.0          # s both flippers held (for the shift)
var _shift_lock := false       # shifted: release both before shifting again
var in_tunnel := false         # D-127
var _scrape_t := 0.0
var grace_t := 0.0             # s of traffic immunity left after a crash (D-125)
var spin_t := 0.0              # crash timer (spin-out or flip)
var flipping := false          # this crash is a roll-over (big obstacle)
var crash_anim := 0.0          # animation length of the current crash (s)
var crash_slide := false       # a rolled car sliding to a stop (D-106)
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
	track.avoid_every = CHECKPOINT_EVERY
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
		_autoshift()
	track.ensure(s + 1500.0)
	match state:
		State.COUNTDOWN:
			# Flippers rev the engine on the grid (D-112).
			var rev := left or right
			rpm = move_toward(rpm, 1.0 if rev else 0.0, dt * (REV_UP if rev else REV_DOWN))
			throttle = 1.0 if rev else 0.0
			var before := ceili(countdown)
			countdown -= dt
			if ceili(countdown) < before and countdown > 0.0:
				events.append(["count", ceili(countdown)])
			if countdown <= 0.0:
				state = State.RACE
				events.append(["go"])
				# Flippers held for revving don't steer once the race starts:
				# each one is ignored until it is released (D-131).
				_rev_lock_l = left
				_rev_lock_r = right
				# Perfect start (D-118): revs held in the perfect-shift band at GO
				# launch the car with a kick and extra pull.
				if rpm >= START_FROM and rpm < START_TO:
					v = START_KICK
					perfect_t = START_PULL_TIME
					_add_score(PERFECT_POINTS)
					events.append(["perfect_start"])
			_update_traffic(dt)
			return
		State.OVER:
			over_t += dt
			# Coasting out: still steerable; a checkpoint reached on momentum
			# puts the time back and the race goes on (D-103).
			if left and right:
				left = false
				right = false
			_drive(dt, left, right, false, false)
			_update_traffic(dt)
			_collide_objects()
			if s >= next_checkpoint and not done:
				state = State.RACE
				over_t = 0.0
				_pass_checkpoint(true)
				return
			if v < 1.0 and over_t > 1.5:
				done = true
			return
	if not left:
		_rev_lock_l = false
	if not right:
		_rev_lock_r = false
	left = left and not _rev_lock_l
	right = right and not _rev_lock_r
	if not freeze_time:
		time_left -= dt
	if time_left <= 0.0:
		time_left = 0.0
		state = State.OVER
		_end_drift()
		events.append(["time_up"])
		return
	_shift_input(dt, left and right)
	if left and right:
		left = false
		right = false
	_drive(dt, left, right, gas, brake)
	_update_boost(dt)
	_update_grace(dt)
	_update_traffic(dt)
	_update_pickups()
	_collide_objects()
	if s >= next_checkpoint:
		_pass_checkpoint(false)
	_add_score(v * dt * 10.0)


## `saved` = reached on momentum after the clock had run out (D-103).
func _pass_checkpoint(saved: bool) -> void:
	checkpoints += 1
	var bonus := checkpoint_bonus()
	time_left += bonus
	next_checkpoint += CHECKPOINT_EVERY
	_add_score(20000.0)
	events.append(["checkpoint", checkpoints, bonus, saved])


func _add_score(p: float) -> void:
	_score_f += p
	score = int(_score_f)


# --- gears + nitro (D-103) -------------------------------------------------------------
func _shift_input(dt: float, both: bool) -> void:
	if not both:
		shift_hold = 0.0
		_shift_lock = false
		return
	shift_hold += dt
	if shift_hold >= SHIFT_HOLD and not _shift_lock:
		_shift_lock = true
		shift(Gear.HIGH if gear == Gear.LOW else Gear.LOW)


func shift(g: int) -> void:
	if g == gear:
		return
	var perfect := g == Gear.HIGH and state == State.RACE and spin_t <= 0.0 		and rpm >= PERFECT_FROM and rpm < PERFECT_TO
	gear = g
	events.append(["shift", gear])
	if perfect:
		# Perfect shift (D-116): a kick of speed and a moment of extra pull.
		v += PERFECT_KICK
		perfect_t = PERFECT_TIME
		_add_score(PERFECT_POINTS)
		events.append(["perfect_shift"])


## Autopilot (attract demo): shift up near the redline, down when slow.
func _autoshift() -> void:
	if state != State.RACE:
		return
	if gear == Gear.LOW and rpm >= REDLINE:
		shift(Gear.HIGH)
	elif gear == Gear.HIGH and v < l_top() * 0.45:
		shift(Gear.LOW)


func gear_top() -> float:
	return l_top() if gear == Gear.LOW else top_speed()


## This car's top speed in H, in L, and with nitro (D-122).
func top_speed() -> float:
	return float(CARS[car].top)


func l_top() -> float:
	return top_speed() * GEAR_L_TOP / MAX_SPEED


func nitro_speed() -> float:
	return top_speed() + NITRO_SPEED - MAX_SPEED


func grip() -> float:
	return float(CARS[car].grip)


## Engine pull at the current speed, as a multiple of ACCEL (before drag).
func gear_pull() -> float:
	if gear == Gear.LOW:
		return GEAR_L_PULL
	return lerpf(GEAR_H_PULL_MIN, GEAR_H_PULL_MAX, clampf(rpm / 0.6, 0.0, 1.0))


func _update_grace(dt: float) -> void:
	grace_t = maxf(0.0, grace_t - dt)


func _update_boost(dt: float) -> void:
	if boost_t <= 0.0:
		return
	boost_t -= dt
	if boost_t <= 0.0:
		boost_t = 0.0
		boosting = false
		events.append(["nitro_end"])


func _update_pickups() -> void:
	while _next_pickup_s < s + 900.0:
		var lane := _rng.randi_range(0, Track.LANES.size() - 1)
		pickups.append({"id": _next_id, "s": _next_pickup_s, "x": Track.LANES[lane]})
		_next_id += 1
		_next_pickup_s += _rng.randf_range(PICKUP_GAP_MIN, PICKUP_GAP_MAX)
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		var ds: float = p.s - s
		if ds < -10.0:
			pickups.remove_at(i)
		elif absf(ds) < CAR_LEN * 0.6 and absf(p.x - x) < PICKUP_DX and spin_t <= 0.0:
			pickups.remove_at(i)
			boost_t = NITRO_TIME
			if not boosting:
				boosting = true
				events.append(["nitro", p.id])
			else:
				events.append(["nitro_refill", p.id])


func _drive(dt: float, left: bool, right: bool, gas: bool, brake: bool) -> void:
	var want := (1.0 if right else 0.0) - (1.0 if left else 0.0)
	if spin_t > 0.0:
		# After the roll, the car slides on until it stops; the stop timer
		# only runs once it has (D-106).
		crash_slide = flipping and spin_t <= CRASH_STOP and v > 0.5
		if not crash_slide:
			spin_t = maxf(spin_t - dt, 0.0)
			if spin_t <= 0.0:
				grace_t = CRASH_GRACE   # back on the move: traffic can't hit us yet
			crash_slide = flipping and spin_t > 0.0 and spin_t <= CRASH_STOP and v > 0.5
		want = 0.0
		if stalled():
			v = 0.0
			# A crash that ends off the road is put back on it (D-114): during the
			# stop the car slides over to the outer lane, arriving as it ends.
			var on_road := clampf(x, -RECOVER_X, RECOVER_X)
			if x != on_road:
				x = move_toward(x, on_road, absf(x - on_road) * dt / maxf(spin_t, dt))
	steer = move_toward(steer, want, dt * 6.0)
	var c := track.curvature(s)
	var push := c * v * v * CENTRIFUGAL           # to the outside: +x on a left curve
	# Gears change the handling (D-120): H slides wide in bends, L grips, so
	# downshifting is how you hold the inside line.
	push *= (H_SLIDE if gear == Gear.HIGH else L_PUSH) / grip()
	# Sideways speed grows with forward speed (D-119): slow cars barely move
	# across the road; full authority from STEER_FULL_V.
	var authority := clampf(v / STEER_FULL_V, 0.0, 1.0) * STEER * (L_GRIP if gear == Gear.LOW else 1.0) * grip()
	_update_drift(dt, want, c, brake)
	var vmax := nitro_speed() if boosting else gear_top()
	rpm = clampf(v / gear_top(), 0.0, 1.0)
	var pull := gear_pull()
	# Throttle and brakes
	var accel := 0.0
	auto_braking = false
	if state == State.OVER or spin_t > 0.0:
		throttle = 0.0
		braking = false
		accel = -(COAST_OVER if state == State.OVER else ((FLIP_SLIDE_DECEL if crash_slide else FLIP_ROLL_DECEL) if flipping else COAST_DRAG * 3.0))
	elif manual:
		throttle = 1.0 if gas else 0.0
		braking = brake
		accel = (ACCEL * pull * (1.0 - pow(minf(v / vmax, 1.2), 2.0)) if gas else -COAST_DRAG) - (BRAKE if brake else 0.0)
	else:
		throttle = 1.0
		braking = false
		accel = ACCEL * pull * (1.0 - pow(minf(v / vmax, 1.2), 2.0))
		# Auto-brake: a corner would throw the car off and it isn't drifting.
		if not drifting and absf(push) > authority * 0.95 and push * x > 0.0 and absf(x) > Track.ROAD_HALF * 0.35:
			auto_braking = true
			braking = true
			throttle = 0.0
			accel = -BRAKE * 0.8
	if perfect_t > 0.0:
		perfect_t = maxf(0.0, perfect_t - dt)
		if spin_t <= 0.0 and state == State.RACE:
			accel += ACCEL * PERFECT_PULL
	if boosting and spin_t <= 0.0:
		accel = maxf(accel, ACCEL * 1.8 * (1.0 - v / nitro_speed()))
	if drifting:
		accel -= DRIFT_DRAG
	if v > vmax and not (state == State.OVER or spin_t > 0.0):
		accel = minf(accel, -6.0)
	offroad = absf(x) > Track.ROAD_HALF + Track.RUMBLE
	if offroad and v > OFFROAD_SPEED:
		accel = minf(accel, -OFFROAD_DRAG)
	# Gravity on hills: a little slower uphill, faster downhill.
	accel -= track.slope(s) * 9.8 * 0.5
	v = maxf(0.0, v + accel * dt)
	if stalled():
		v = 0.0
	# Lateral motion
	var lat := want * authority
	if drifting:
		lat = want * authority * DRIFT_STEER + push * DRIFT_GRIP
	else:
		lat += push
	if spin_t > 0.0:
		lat = push * 0.5
	# Sideways speed eases towards its target instead of jumping (D-124), so
	# the car steers into a lane change rather than skating across.
	lat_v = move_toward(lat_v, lat, dt * (LAT_RESPONSE * (1.6 if drifting else 1.0)))
	if spin_t > 0.0:
		lat_v = lat
	x = clampf(x + lat_v * dt, -WALL, WALL)
	var was_in := track.in_tunnel(s)
	s += v * dt
	_tunnel_walls(dt, was_in)


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
	var target := drift_dir * DRIFT_ANGLE if drifting else 0.0
	drift_angle = move_toward(drift_angle, target, dt * (120.0 if drifting else 90.0))


## Tunnel walls stand on the road's edges (D-127). Driving in off the road hits
## the portal; inside, the car is held between the walls and scrapes along them.
func _tunnel_walls(dt: float, was_in: bool) -> void:
	in_tunnel = track.in_tunnel(s)
	if not in_tunnel:
		return
	var limit := Track.TUNNEL_HALF - CAR_W * 0.5
	if not was_in and absf(x) > limit + 0.8 and spin_t <= 0.0 and state == State.RACE:
		_crash("portal", -x)   # rolls away from... the wall it hit
	if absf(x) > limit:
		var side := signf(x)
		x = side * limit
		if lat_v * side > 0.0:
			lat_v = -lat_v * 0.3
		if v > 8.0 and spin_t <= 0.0:
			v = maxf(0.0, v - SCRAPE_DRAG * dt)
			_scrape_t -= dt
			if _scrape_t <= 0.0:
				_scrape_t = 0.25
				events.append(["scrape", side])


func _end_drift() -> void:
	if not drifting:
		return
	drifting = false
	var pts := int(drift_points / 10.0) * 10
	_add_score(pts)
	events.append(["drift_end", pts])
	drift_points = 0.0


## 0..1 through the current crash animation (1 while stopped after it).
func crash_progress() -> float:
	if spin_t <= 0.0 or crash_anim <= 0.0:
		return 1.0
	return clampf(1.0 - (spin_t - CRASH_STOP) / crash_anim, 0.0, 1.0)


## Stopped dead at the end of a crash.
func stalled() -> bool:
	return spin_t > 0.0 and spin_t <= CRASH_STOP and not crash_slide


## `slide` = false for head-on hits: the car stops there instead of tumbling on.
func _crash(kind: String, side: float = 0.0, slide: bool = true) -> void:
	_end_drift()
	flipping = kind in FLIP_KINDS
	# Rolls away from the obstacle: one on the right (+side) rolls it left.
	flip_dir = -signf(side) if side != 0.0 else 1.0
	crash_anim = FLIP_TIME if flipping else SPIN_TIME
	spin_t = crash_anim + CRASH_STOP
	v = minf(v, (FLIP_SPEED if slide else 6.0) if flipping else 14.0)
	crash_slide = false
	shift(Gear.LOW)   # a crash drops to low gear by itself (D-112)
	if boosting:
		boosting = false
		boost_t = 0.0
		events.append(["nitro_end"])
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
	return mini(7 + 2 * checkpoints, 16)   # D-101 (was min(4 + n, 11))


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
		# Oncoming drivers flash their high beams (and honk once) at a car
		# coming at them in their lane (D-105).
		t.flash = state == State.RACE and t.v < 0.0 and ds > 8.0 and ds < HIGHBEAM_RANGE 			and absf(t.x - x) < HIGHBEAM_DX
		if t.flash and not t.get("flashed", false):
			t.flashed = true
			events.append(["high_beams", t.id])
		if state == State.RACE and prev_ds > 0.0 and ds <= 0.0:
			if absf(t.x - x) < NEAR_MISS_DX + (tw - CAR_W) * 0.5 and spin_t <= 0.0:
				_add_score(5000.0)
				events.append(["near_miss", t.id])
			else:
				_add_score(500.0)
				events.append(["pass", t.id])
		if state == State.RACE and spin_t <= 0.0 and grace_t <= 0.0 and absf(ds) < (CAR_LEN + tlen) * 0.5 				and absf(t.x - x) < (CAR_W + tw) * 0.5:
			var rel: float = v - t.v
			var big: bool = t.get("kind", "car") == "truck"
			if t.v < 0.0 or (ds > 0.0 and rel > 22.0):
				# Head-on, or rear-ending at speed: a truck rolls the car over.
				_crash("truck" if big else "car", t.x - x, t.v >= 0.0)
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
