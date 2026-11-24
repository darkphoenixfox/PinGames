## TURBO RUN simulation (D-089): pure race logic, no nodes (headless-tested).
## The car lives in road coordinates: s = metres along the track, x = metres
## right of the centre line. Curves push the car to their outside (centrifugal);
## steering, drifting and braking fight it.
##
## Controls (D-007, D-089):
##   2+1 buttons: flippers steer; throttle AND braking are automatic (the car
##                lifts/brakes by itself when a corner would throw it off).
##   4+1 buttons (D-189): throttle stays automatic; magna_r = gear shifter
##   (one press flips L <-> H), magna_l = brake (no auto-brake then).
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
	# time: the starting clock (s); bonus: added to every checkpoint's time and
	# to its floor (D-183), so the easy car gets more time, the hard car less.
	{"name": "RC_CAR_EASY", "hue": 0.13, "top": 72.0, "grip": 1.25, "time": 55.0, "bonus": 10.0},     # the red hot hatch (D-206; was blue, D-202)
	{"name": "RC_CAR_NORMAL", "hue": 0.06, "top": 80.0, "grip": 1.0, "time": START_TIME, "bonus": 0.0},   # green (D-210; the red car's paint rotated)
	{"name": "RC_CAR_HARD", "hue": 10.89, "top": 88.0, "grip": 0.8, "time": 40.0, "bonus": -4.0},     # the supercar's own yellow (D-210)
]
const DEFAULT_CAR := 1
## Shown speeds (D-147): the game's own speeds are arcade-fast; on screen
## they're scaled so the fastest car's flat-out top reads 270 km/h (168 mph),
## and shown in mph to go with the California plates.
const MPH := 2.23694 * (270.0 / 3.6) / 88.0   # game m/s -> displayed mph
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
const LAUNCH_LOCK := 1.0         # s after GO when flippers don't steer (D-137)
const START_KICK := 12.0          # m/s at GO after a perfect rev (D-118)
const START_PULL_TIME := 1.5      # s of perfect-shift pull after it
const REV_UP := 1.5               # rpm/s while revving on the grid (D-112; slower D-128)
const REV_DOWN := 1.0
## After the clock runs out the car coasts (D-103): reaching a checkpoint
## before it stops extends the time and the race goes on.
const COAST_OVER := 14.0         # m/s^2 decel while coasting out (D-231: doubled, half the slide)
## Race clock
const START_TIME := 45.0
const CHECKPOINT_EVERY := 2300.0   # D-101 (was 1800)
## The finish line (D-221): the end of stage FINISH_STAGE. Crossing it ends the
## race: no more time, a finish bonus plus a bonus for every second left, and
## the car coasts to a stop.
const FINISH_STAGE := Track.FINISH_STAGE
## Slow crashes (D-223): below this shown speed a hit only slows the car and
## bounces it off; no spin, no roll-over.
const SOFT_CRASH_MPH := 55.0
const SOFT_CRASH_SLOW := 0.45   # speed kept
## Traffic behind a crash (D-223): same-direction cars this close behind, in
## line with the car, brake and wait STOP_GAP m behind it until it's going again.
const WAIT_BEHIND := 140.0
const WAIT_GAP := 5.0
## Oncoming traffic avoiding a crashed or stopped car (D-271).
const DODGE_AHEAD := 170.0   # m ahead it starts to react
const DODGE_CLEAR := 0.7     # m of clearance it keeps
const DODGE_RATE := 4.5      # m/s it moves across
const FINISH_DECEL := 30.0   # m/s^2: the drift-brake after the line (D-222; D-231: doubled, half the slide)
const FINISH_BONUS := 100000
const TIME_BONUS_PER_S := 2000
const CHECKPOINT_BONUS := 34.0   # minus BONUS_DECAY s per checkpoint passed, never below BONUS_FLOOR
## D-300: a clean stage takes ~30 s in the normal car; the old 2 s decay to a
## 20 s floor ran a crash-free race out of time by stage 6-7.
const BONUS_DECAY := 1.0
const BONUS_FLOOR := 28.0
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
## A big hit at 100 mph or more (shown speed) rolls the car twice (D-206),
## over a longer animation.
const DOUBLE_FLIP_MPH := 100.0
const DOUBLE_FLIP_TIME := 2.1
## A roll-over keeps tumbling down the road (D-105), then lands on its side and
## keeps sliding until friction stops it (D-106), and only then the CRASH_STOP.
const FLIP_SPEED := 30.0
const FLIP_ROLL_DECEL := 6.0     # m/s^2 while rolling
const FLIP_SLIDE_DECEL := 11.0   # m/s^2 sliding on its side after the roll
## Speed traps and police (D-135). Passing a camera faster than 1.5x the
## L-gear limit calls a police car from behind. It chases, pulls alongside and
## swerves into the hero car (a T-bone). Crashing or slowing down while it is
## close means BUSTED: it stops next to you, you're held, and a fine comes off
## the score. Outrun it long enough and it gives up.
const RADAR_RANGE := 450.0      # m at which the detector starts beeping
const TRAP_MPH := 100.0         # shown mph that triggers a chase at a camera (D-156)
const POLICE_BEHIND := 140.0    # m behind the player it appears
const CHASE_CLOSE := 16.0       # m/s faster than the player while closing in (D-137)
const RAM_WINDUP := 1.2         # s alongside before it swerves in
const POLICE_TOP := 0.95        # x the player car's top speed (D-201: was 1.06): flat out you pull away
## Catch-up (D-203): a new chase starts with the police flat out at
## POLICE_CATCH_TOP x the car's top speed and no escape possible, until it
## first gets within CAUGHT_GAP of the player (or CATCH_UP_MAX s pass).
const POLICE_CATCH_TOP := 1.05
const CAUGHT_GAP := 25.0
const CATCH_UP_MAX := 25.0
const POLICE_HITS := 3          # hits to stop the player
const HIT_STREAK := 6.0         # D-198: s between rams before the count starts again
const HIT_RESET_GAP := 40.0     # D-198: m ahead of the police that also clears the count
const RAMMED_SLOW := 0.55       # D-198: speed the police keeps when the player runs into it
const RAMMER_SLOW := 0.92       # D-198: speed the player keeps doing it
const HIT_SLOW := 0.78          # speed kept per hit
const HIT_BOUNCE := 9.0         # m/s sideways shove
const POLICE_BUMP_SLOW := 0.55  # speed the police keeps after hitting traffic
## Losing the police (D-200): stay more than ESCAPE_GAP ahead of it for
## ESCAPE_TIME in a row. Getting closer starts the count again, however long
## the chase has gone on.
const ESCAPE_GAP := 120.0        # m ahead of it
const ESCAPE_TIME := 4.0         # s in a row
const BUST_SPEED := 22.0        # m/s: slower than this with police close = busted
const BUST_NEAR := 12.0         # m: "close" - right on you (D-157; was 40)
const BUST_TIME := 3.5          # s held at the roadside
const LIGHTS_OFF_WAIT := 1.0    # s it sits with its lights off after the fine, before it leaves (D-230)
const BLOCK_AHEAD := 6.5        # m in front of the player where it stops across the lane (D-161)
const PARK_HOLD := 1.5          # s the police stands parked beside you (D-139)
const FINE := 25000
const ESCAPE_BONUS := 10000.0
const FLIP_KINDS := ["palm", "rock", "lamp", "truck", "portal"]
const SCRAPE_DRAG := 9.0        # m/s^2 lost scraping a tunnel wall (D-127)
const NEAR_MISS_DX := 3.3
const YIELD_AHEAD := 350.0      # m ahead of the police where traffic pulls over (D-163)
const YIELD_SLOW := 0.6         # speed traffic slows to while yielding
const SIDE_SLOW := 0.93         # speed kept on a side-swipe
const SIDE_BOUNCE := 7.0        # m/s sideways shove
## Side impacts make both cars turn away from each other a little (D-239):
## a yaw kick of SWAY rad that eases back at SWAY_BACK rad/s. `sway` is a turn
## about the vertical (+ = anticlockwise from above; nose to -x when driving on).
const SWAY := 0.3
const SWAY_BACK := 0.8
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
var manual := false            # 4-button layout: shifter + brake (auto-detected or forced, D-189)
var shift_request := false     # 4-button shifter pressed: flip the gear on the next race step
var autopilot := false         # attract demo + dev screenshots

var s := START_S
var x := 0.0
var v := 0.0
var lat_v := 0.0               # m/s sideways (+ = right), for the view's nose angle
var steer := 0.0               # -1..1 smoothed steering (for the view)
var throttle := 0.0
## Analog gamepad (D-252): stick steering (0 = use the flippers), and the
## accelerator once R2 has been used (< 0 = automatic throttle as before).
var steer_axis := 0.0
var gas_axis := -1.0
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
var _next_id_pickups := 0        # canisters placed so far (the first goes in front, D-197)
var car := DEFAULT_CAR           # index into CARS (D-122)
var gear := Gear.LOW
var _launch_t := 0.0
var _rev_lock_l := false       # flipper held through GO (revving), not steering yet (D-131)
var _rev_lock_r := false
var freeze_time := false       # debug cheat (F in debug builds, D-118)
var perfect_t := 0.0           # s of perfect-shift pull left (D-116)
var rpm := 0.0                 # 0..1 (tachometer)
var shift_hold := 0.0          # s both flippers held (for the shift)
var _shift_lock := false       # shifted: release both before shifting again
var police: Dictionary = {}     # {s, x, v, state: chase|bust|leave, t} or empty (D-135)
var busted_t := 0.0            # s left held by the police
var radar := 0.0               # 0..1 closeness of the next speed camera (0 = none in range)
var _trap_passed := -1.0       # s of the last camera judged
var in_tunnel := false         # D-127
var _scrape_t := 0.0
var grace_t := 0.0             # s of traffic immunity left after a crash (D-125)
var finished := false          # crossed the finish line (D-221)
var sway := 0.0                # D-239: the player's yaw kick from a side impact
var time_bonus := 0            # points for the seconds left at the finish
var spin_t := 0.0              # crash timer (spin-out or flip)
var flipping := false          # this crash is a roll-over (big obstacle)
var crash_anim := 0.0          # animation length of the current crash (s)
var crash_slide := false       # a rolled car sliding to a stop (D-106)
var flip_dir := 1.0            # +1 rolls to the right, -1 to the left
var flip_turns := 1            # full rolls in this roll-over (2 at 100+ mph, D-206)
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


## D-288: local 2-player (split screen). Each player's car state lives in
## PLAYER_FIELDS, swapped in by _use(i), so the 1-player code runs unchanged
## for whichever car is live. Shared: the track, traffic and the random stream.
const PLAYER_FIELDS := ["state", "countdown", "manual", "shift_request", "autopilot", "s", "x", "v",
	"lat_v", "steer", "throttle", "steer_axis", "gas_axis", "braking", "auto_braking", "offroad",
	"drifting", "drift_dir", "drift_angle", "drift_points", "_drift_entry", "_drift_exit", "boost_t",
	"boosting", "pickups", "_next_pickup_s", "_next_id_pickups", "car", "gear", "_launch_t",
	"_rev_lock_l", "_rev_lock_r", "freeze_time", "perfect_t", "rpm", "shift_hold", "_shift_lock",
	"police", "busted_t", "radar", "_trap_passed", "in_tunnel", "_scrape_t", "grace_t", "finished",
	"sway", "time_bonus", "spin_t", "flipping", "crash_anim", "crash_slide", "flip_dir", "flip_turns",
	"time_left", "next_checkpoint", "checkpoints", "score", "_score_f", "over_t", "done"]
const P2_START_X := 1.9          # the two cars start side by side, either side of the line
const RIVAL_SIDE_BOUNCE := 6.0   # m/s sideways when the two players swipe each other
const WIN_WAIT := 8.0            # s the race goes on after the winner crosses the line
var two_player := false
var cur := 0                     # the player whose fields are live
var _pl := [{}, {}]
var event_player: Array = []     # 2P: the player each event of the last step belongs to
var winner := -1                 # 2P: the first player across the finish line
var race_over := false           # 2P: both done, or WIN_WAIT after the winner
var _win_t := 0.0


## Starts a 2-player race: both cars on the grid side by side (cars[i] =
## each player's car), no clock (first to the end of the last stage wins).
func setup_two(seed_in: int, cars: Array) -> void:
	setup(seed_in)
	two_player = true
	for i in 2:
		var d := {}
		for f in PLAYER_FIELDS:
			var val = get(f)
			d[f] = val.duplicate(true) if (val is Array or val is Dictionary) else val
		d.car = int(cars[i])
		d.x = -P2_START_X if i == 0 else P2_START_X
		d.freeze_time = true
		d.time_left = 99.0
		_pl[i] = d
	cur = 0
	for f in PLAYER_FIELDS:
		set(f, _pl[0][f])


## Makes player i's car state the live one (2P).
func _use(i: int) -> void:
	if not two_player or i == cur:
		return
	for f in PLAYER_FIELDS:
		_pl[cur][f] = get(f)
	for f in PLAYER_FIELDS:
		set(f, _pl[i][f])
	cur = i


## A player's value of a car field, whichever is live.
func player_get(i: int, f: String) -> Variant:
	if not two_player or i == cur:
		return get(f)
	return _pl[i][f]


func player_set(i: int, f: String, val: Variant) -> void:
	if not two_player or i == cur:
		set(f, val)
	else:
		_pl[i][f] = val


## Puts every player at stage n's start (2P: side by side).
func start_at_stage(n: int) -> void:
	for i in (2 if two_player else 1):
		_use(i)
		checkpoints = n - 1
		s = (n - 1) * CHECKPOINT_EVERY + 150.0
		next_checkpoint = n * CHECKPOINT_EVERY
	_use(0)
	track.ensure(s + 1500.0)


## 2-player step: inputs[i] = [left, right, brake] for each player.
func step_two(dt: float, inputs: Array) -> void:
	events.clear()
	event_player.clear()
	for i in 2:
		_use(i)
		var c: Array = inputs[i]
		step(dt, c[0], c[1], false, c[2])
		while event_player.size() < events.size():
			event_player.append(i)
	_use(0)
	_rival_contact()
	# The winner (first across the line); the race ends once both are done,
	# or WIN_WAIT after the winner crossed.
	for i in 2:
		if winner < 0 and player_get(i, "finished"):
			winner = i
			events.append(["winner", i])
			event_player.append(-1)
	if winner >= 0 and not race_over:
		_win_t += dt
		if (player_get(0, "done") and player_get(1, "done")) or _win_t >= WIN_WAIT:
			race_over = true


## The two players' cars touching (2P): a side-swipe pushes both apart and
## turns them away from each other; running into the other's back slows the
## one behind to the other's speed and nudges the one in front.
func _rival_contact() -> void:
	var s0: float = player_get(0, "s")
	var s1: float = player_get(1, "s")
	var x0: float = player_get(0, "x")
	var x1: float = player_get(1, "x")
	var ds := s1 - s0
	var dx := x1 - x0
	if absf(ds) >= CAR_LEN or absf(dx) >= CAR_W:
		return
	if float(player_get(0, "spin_t")) > 0.0 or float(player_get(1, "spin_t")) > 0.0:
		return
	var away := signf(dx) if absf(dx) > 0.01 else 1.0   # player 1 is pushed this way
	var along := (CAR_LEN - absf(ds)) / CAR_LEN
	var across := (CAR_W - absf(dx)) / CAR_W
	if across < along:
		# Side by side: both bounce apart.
		for i in 2:
			var dir := away if i == 1 else -away
			player_set(i, "lat_v", dir * RIVAL_SIDE_BOUNCE)
			player_set(i, "x", float(player_get(i, "x")) + dir * across * CAR_W * 0.5)
			player_set(i, "sway", -dir * SWAY)
			player_set(i, "v", float(player_get(i, "v")) * SIDE_SLOW)
			events.append(["bump", -2])
			event_player.append(i)
	else:
		# Nose to tail: the one behind slows to the other's speed.
		var back := 0 if ds > 0.0 else 1
		var front := 1 - back
		var vf: float = player_get(front, "v")
		player_set(back, "v", minf(float(player_get(back, "v")), vf * 0.95))
		player_set(front, "v", vf + 1.5)
		player_set(back, "s", float(player_get(front, "s")) - CAR_LEN)
		for i in [back, front]:
			events.append(["bump", -2])
			event_player.append(i)


func setup(seed_in: int = 7) -> void:
	_rng.seed = seed_in * 31 + 5
	track.avoid_every = CHECKPOINT_EVERY
	track.setup(seed_in)
	track.ensure(2000.0)


func lane_count() -> int:
	return Track.LANES.size()


func speed_kmh() -> int:
	return int(round(v * 3.6))


func speed_mph() -> int:
	return int(round(v * MPH))


func checkpoint_bonus() -> float:
	var extra := float(CARS[car].bonus)
	return maxf(BONUS_FLOOR + extra, CHECKPOINT_BONUS + extra - BONUS_DECAY * checkpoints)


## The starting clock for the chosen car (D-183).
func start_time() -> float:
	return float(CARS[car].time)


## left/right = flippers, brake = left magna save (4-button mode only). `_gas` is
## unused since D-189 (the throttle is automatic in both layouts).
func step(dt: float, left: bool, right: bool, _gas: bool = false, brake: bool = false) -> void:
	if not two_player:
		events.clear()   # (2P: step_two clears them once for both players)
	if autopilot:
		var ap := _autopilot()
		left = ap < -0.3
		right = ap > 0.3
		_autoshift()
	track.ensure(s + 1500.0)
	match state:
		State.COUNTDOWN:
			shift_request = false   # the shifter does nothing on the grid
			# Flippers rev the engine on the grid (D-112).
			var rev := left or right
			# D-258: a gamepad's accelerator revs too, in proportion (so the
			# needle can be held in the start window with the trigger).
			var want := 1.0 if rev else maxf(gas_axis, 0.0)
			rpm = move_toward(rpm, want, dt * (REV_UP if want > rpm else REV_DOWN))
			throttle = want
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
				_launch_t = LAUNCH_LOCK
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
			shift_request = false
			over_t += dt
			# Coasting out: a checkpoint reached on momentum puts the time back
			# and the race goes on (D-103). D-299 (director): no steering while
			# it slides to a stop (time up or past the finish), flippers or stick.
			var axis := steer_axis
			steer_axis = 0.0
			_drive(dt, false, false, false, false)
			steer_axis = axis
			_update_traffic(dt)
			_collide_objects()
			if s >= next_checkpoint and not done and not finished:
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
	# Launch (D-137): for the first moment after GO no flipper steers, so
	# re-pressing one while chasing the perfect revs doesn't throw the car.
	if _launch_t > 0.0:
		_launch_t -= dt
		left = false
		right = false
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
	if manual:
		# 4 buttons (D-189): the shifter button, not both flippers.
		if shift_request:
			shift(Gear.HIGH if gear == Gear.LOW else Gear.LOW)
	else:
		_shift_input(dt, left and right)
	shift_request = false
	if left and right:
		left = false
		right = false
	_drive(dt, left, right, true, brake)
	_update_boost(dt)
	_update_grace(dt)
	_update_traps()
	_update_police(dt)
	_update_traffic(dt)
	_update_pickups()
	_collide_objects()
	if s >= next_checkpoint:
		_pass_checkpoint(false)
	_add_score(v * dt * 10.0)


## `saved` = reached on momentum after the clock had run out (D-103).
func _pass_checkpoint(saved: bool) -> void:
	checkpoints += 1
	if checkpoints >= FINISH_STAGE:
		_finish()
		return
	var bonus := checkpoint_bonus()
	time_left += bonus
	next_checkpoint += CHECKPOINT_EVERY
	_add_score(20000.0)
	events.append(["checkpoint", checkpoints, bonus, saved])


## A slow knock (D-223): speed lost and a little sideways bounce, no crash.
func _soft_bump(from_x: float) -> void:
	_end_drift()
	v *= SOFT_CRASH_SLOW
	lat_v = signf(x - from_x + 0.001) * 3.0
	events.append(["bump", -1])


## Across the finish line (D-221): the bonuses, then coasting out to a stop.
func _finish() -> void:
	if finished:
		return
	finished = true
	_end_drift()
	time_bonus = int(ceilf(time_left)) * TIME_BONUS_PER_S
	_add_score(FINISH_BONUS + time_bonus)
	state = State.OVER
	over_t = 0.0
	if boosting:
		boosting = false
		boost_t = 0.0
		events.append(["nitro_end"])
	events.append(["finish", time_bonus])


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


# --- speed traps + police (D-135) -----------------------------------------------------
func _update_traps() -> void:
	var trap := track.next_trap(s - 2.0)
	radar = 0.0
	if trap.is_empty():
		return
	var d: float = trap.s - s
	if d < RADAR_RANGE:
		radar = clampf(1.0 - d / RADAR_RANGE, 0.0, 1.0)
	if d <= 0.0 and trap.s != _trap_passed:
		_trap_passed = trap.s
		var caught := v * MPH > TRAP_MPH   # D-156: over 100 mph on the speedometer
		events.append(["trap", caught])
		if caught and police.is_empty() and busted_t <= 0.0:
			call_police()


## Calls a police car from behind (D-156; public for the --rc-police dev flag).
func call_police() -> void:
	police = {"s": s - POLICE_BEHIND, "x": x, "v": v, "state": "chase", "t": 0.0}
	events.append(["police_spawn"])


func _update_police(dt: float) -> void:
	if police.is_empty():
		return
	police.t += dt
	var ds: float = police.s - s            # < 0 behind us
	match police.state:
		"chase":
			# Position-keeping (D-137): it closes in, then sits alongside a
			# little behind, matching the player, and swerves in to slam it.
			var side: float = police.get("side", 1.0 if x < 0.0 else -1.0)
			police.side = side
			police.ram_t = float(police.get("ram_t", 0.0))
			var want_ds := -1.0
			var want_x := x + side * 2.8
			if ds < -12.0:
				want_x = x                       # chase down the player's line
				police.ram_t = 0.0
			else:
				police.ram_t += dt
				if police.ram_t > RAM_WINDUP:
					want_x = x + side * 0.4      # slam
					if police.ram_t > RAM_WINDUP + 0.6:
						police.ram_t = 0.0       # missed: line up again
						police.side = -side if absf(x) > 4.0 and signf(x) == side else side
			if ds > -CAUGHT_GAP or police.t > CATCH_UP_MAX:
				police.caught = true
			var catching := not bool(police.get("caught", false))
			_police_follow(dt, want_ds, CHASE_CLOSE, 40.0, 15.0, POLICE_CATCH_TOP if catching else POLICE_TOP)
			police.x = move_toward(police.x, want_x, (9.0 if police.ram_t > RAM_WINDUP else 5.0) * dt)
			police.hit_cd = maxf(0.0, float(police.get("hit_cd", 0.0)) - dt)
			# The rams only count close together (D-198): a pause, or getting
			# well ahead of it, starts the count again.
			if int(police.get("hits", 0)) > 0 and (police.t - float(police.get("last_hit_t", 0.0)) > HIT_STREAK 					or ds < -HIT_RESET_GAP):
				police.hits = 0
				events.append(["police_hits_reset"])
			if spin_t <= 0.0 and grace_t <= 0.0 and police.hit_cd <= 0.0 and absf(ds) < CAR_LEN * 0.9 					and absf(police.x - x) < CAR_W * 0.95:
				if ds > CAR_LEN * 0.3:
					_hit_police()       # we ran into it from behind (D-198)
				else:
					_police_hit()
			var close := ds > -BUST_NEAR
			if close and (spin_t > 0.0 or v < BUST_SPEED):
				_bust()
			else:
				# Losing it (D-200): only once it has caught up (D-203).
				police.lose_t = float(police.get("lose_t", 0.0)) + dt if ds < -ESCAPE_GAP and not catching else 0.0
			if police.state == "chase" and float(police.get("lose_t", 0.0)) >= ESCAPE_TIME:
				police.state = "giveup"   # D-145: falls back, lights off
				_add_score(ESCAPE_BONUS)
				events.append(["police_escape"])
		"bust":
			# Hurry up beside the stopped player, swing across and park there
			# (D-139). The player is held until it has stood parked PARK_HOLD s.
			# D-161: drive round the player and stop across the lane in front,
			# blocking the way. It passes alongside, then cuts in ahead.
			_police_follow(dt, BLOCK_AHEAD, 30.0, 90.0, 18.0)
			var round_side := 3.4 if x < 0.0 else -3.4
			var tx := x + round_side if ds < BLOCK_AHEAD - 2.0 else x
			police.x = move_toward(police.x, tx, 7.0 * dt)
			var parked := absf(ds - BLOCK_AHEAD) < 2.0 and absf(police.v) < 2.0
			police.park_t = float(police.get("park_t", 0.0)) + (dt if parked else 0.0)
			if police.park_t < PARK_HOLD:
				busted_t = maxf(busted_t, 0.05)
			elif not police.get("fined", false):
				# D-230: the fine comes once it's parked; then the lights go off,
				# and it sits dark a moment before it drives away.
				_fine()
				busted_t = maxf(busted_t, LIGHTS_OFF_WAIT)
			elif busted_t <= 0.0 and spin_t <= 0.0 and police.park_t >= PARK_HOLD + LIGHTS_OFF_WAIT:
				police.state = "leave"
		"giveup":
			_check_hit_police(ds, dt)
			# Escaped (D-145): it eases off and drops behind, out of the race.
			police.v = move_toward(police.v, v * 0.5, 14.0 * dt)
			if ds < -300.0:
				police = {}
				return
		"leave":
			_check_hit_police(ds, dt)
			# Drive off ahead (D-139): it overtakes and disappears up the road.
			police.v = move_toward(police.v, maxf(v + 25.0, 40.0), 18.0 * dt)
			police.x = move_toward(police.x, 0.0 if absf(x) > 3.0 else (3.7 if x < 0.0 else -3.7), 3.0 * dt)
			if ds > 350.0 or ds < -350.0:
				police = {}
				return
	if police.state != "bust":
		_police_obstacles(dt)
	police.sway = move_toward(float(police.get("sway", 0.0)), 0.0, SWAY_BACK * dt)   # D-239
	police.s += police.v * dt


## Whether its light bar and siren are on (D-145): only while it's chasing you.
func police_lights() -> bool:
	# On while chasing and through the bust, off once you're fined (D-147,
	# D-230), and after it gives up or drives off.
	return not police.is_empty() and (police.state == "chase" or (police.state == "bust" and not police.get("fined", false)))


## Speed control towards a spot `want_ds` metres from the player (negative =
## behind): match the player, plus a correction capped at `close` m/s ahead
## and 15 m/s back. Police can't get stuck far ahead or overshoot.
func _police_follow(dt: float, want_ds: float, close: float, rate: float = 40.0, back: float = 15.0, top_k: float = POLICE_TOP) -> void:
	var ds: float = police.s - s
	var target := v + clampf((want_ds - ds) * 1.6, -back, close)
	# Its top speed (D-142): a bit over the player car's own, below nitro, so
	# a nitro burst gets away.
	target = minf(target, top_speed() * top_k)
	police.v = move_toward(police.v, maxf(target, -back), rate * dt)


## Running into a police car that isn't ramming us (D-198).
func _check_hit_police(ds: float, dt: float) -> void:
	police.hit_cd = maxf(0.0, float(police.get("hit_cd", 0.0)) - dt)
	if police.hit_cd <= 0.0 and spin_t <= 0.0 and absf(ds) < CAR_LEN * 0.9 and absf(float(police.x) - x) < CAR_W * 0.95:
		_hit_police()


## The player runs into the police car (D-198): it loses most of its speed and
## is shoved aside; the player loses a little.
func _hit_police() -> void:
	police.hit_cd = 0.8
	police.v = minf(float(police.v), v) * RAMMED_SLOW
	var away := signf(float(police.x) - x) if absf(float(police.x) - x) > 0.05 else 1.0
	police.x = float(police.x) + away * 1.4
	v *= RAMMER_SLOW
	lat_v = -away * HIT_BOUNCE * 0.5
	police.sway = -away * SWAY    # D-239: both turn away
	sway = away * SWAY * 0.7
	_end_drift()
	events.append(["police_bumped"])


## The police car slams into the player (D-142): both bounce apart and the
## player loses speed; the third hit spins the player out (then it's a bust).
func _police_hit() -> void:
	police.hits = int(police.get("hits", 0)) + 1
	police.last_hit_t = police.t
	police.hit_cd = 0.8
	police.ram_t = 0.0
	var away := signf(x - float(police.x)) if absf(x - float(police.x)) > 0.05 else -float(police.side)
	if police.hits >= POLICE_HITS:
		_crash("car", police.x - x)
	else:
		v *= HIT_SLOW
		lat_v = away * HIT_BOUNCE
		police.x = float(police.x) - away * 1.2
		sway = -away * SWAY            # D-239: both turn away
		police.sway = away * SWAY * 0.7
		police.v = minf(float(police.v), v) - 4.0
		_end_drift()
	events.append(["police_ram", police.hits])


## Police vs. traffic and tunnel walls (D-142): they slow and shove it too.
func _police_obstacles(dt: float) -> void:
	for t in traffic:
		var tl: float = t.get("len", CAR_LEN)
		var tw: float = t.get("w", CAR_W)
		if absf(float(t.s) - float(police.s)) < (CAR_LEN + tl) * 0.5 				and absf(float(t.x) - float(police.x)) < (CAR_W + tw) * 0.5 				and float(police.get("bump_cd", 0.0)) <= 0.0:
			police.v = float(police.v) * POLICE_BUMP_SLOW
			police.x = float(police.x) + signf(float(police.x) - float(t.x) + 0.01) * 1.5
			police.bump_cd = 0.5
			events.append(["police_bump"])
	police.bump_cd = maxf(0.0, float(police.get("bump_cd", 0.0)) - dt)
	if track.in_tunnel(float(police.s)):
		var lim := Track.TUNNEL_HALF - CAR_W * 0.5
		if absf(float(police.x)) > lim:
			police.x = signf(float(police.x)) * lim
			police.v = maxf(0.0, float(police.v) - SCRAPE_DRAG * 1.5 * dt)


func _bust() -> void:
	police.state = "bust"
	police.swing = -1.0 if x < 0.0 else 1.0   # which way it turns across the lane (D-161)
	busted_t = BUST_TIME + maxf(spin_t, 0.0)
	_end_drift()
	if boosting:
		boosting = false
		boost_t = 0.0
		events.append(["nitro_end"])
	events.append(["bust_start"])


## The fine (D-230: once the police car has parked, not as the bust starts).
func _fine() -> void:
	police.fined = true
	var fine := mini(FINE, score)
	_score_f -= fine
	score = int(_score_f)
	events.append(["busted", fine])


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
		# D-197: the race's first canister sits right in the player's path (the
		# start line's centre), so new players pick it up and find out what it does.
		var px: float = 0.0 if _next_id_pickups == 0 else Track.LANES[lane]
		_next_id_pickups += 1
		pickups.append({"id": _next_id, "s": _next_pickup_s, "x": px})
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
	sway = move_toward(sway, 0.0, SWAY_BACK * dt)   # D-239
	var want := (1.0 if right else 0.0) - (1.0 if left else 0.0)
	if steer_axis != 0.0:
		want = clampf(steer_axis, -1.0, 1.0)   # proportional (D-252)
	if busted_t > 0.0:
		busted_t -= dt
		want = 0.0
		v = move_toward(v, 0.0, BRAKE * 1.5 * dt)
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
	if state == State.OVER or spin_t > 0.0 or busted_t > 0.0:
		throttle = 0.0
		braking = false
		accel = -((FINISH_DECEL if finished else COAST_OVER) if state == State.OVER else ((FLIP_SLIDE_DECEL if crash_slide else FLIP_ROLL_DECEL) if flipping else COAST_DRAG * 3.0))
	elif manual:
		# 4 buttons (D-189): automatic throttle, the player's own brake (no auto-brake).
		# D-252: a gamepad's R2 is the accelerator (proportional) once used.
		var g := 1.0 if gas_axis < 0.0 else gas_axis
		throttle = 0.0 if brake else g
		braking = brake
		accel = -BRAKE if brake else ACCEL * pull * g * (1.0 - pow(minf(v / vmax, 1.2), 2.0))
		if not brake and g < 0.05:
			accel = -COAST_DRAG
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
	var limit := Track.TUNNEL_HALF - CAR_W * 0.5
	if not in_tunnel:
		# Town (D-216): the sidewalk barrier holds the car the same way, but it
		# is always there, so there's no portal to hit.
		var wall := track.side_wall(s)
		if wall <= 0.0:
			return
		limit = wall - CAR_W * 0.5
	elif not was_in and absf(x) > limit + 0.8 and spin_t <= 0.0 and state == State.RACE:
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
	flip_turns = 2 if flipping and v * MPH >= DOUBLE_FLIP_MPH else 1
	crash_anim = (DOUBLE_FLIP_TIME if flip_turns == 2 else FLIP_TIME) if flipping else SPIN_TIME
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
			if v * MPH < SOFT_CRASH_MPH:
				_soft_bump(o.x)
				x = o.x - signf(o.x - x + 0.001) * (o.r + CAR_W * 0.5 + 0.25)
				return
			_crash(o.kind, o.x - x)
			x = move_toward(x, 0.0, 2.5)  # bounce back towards the road
			return


# --- traffic -------------------------------------------------------------------------
## Right-hand traffic (D-099): the two right lanes (x > 0) drive our way and are
## caught up from behind; the two left lanes are oncoming (dir -1, v < 0).
## Trucks are long and slow and count as a big obstacle (a hit rolls the car).
func traffic_target() -> int:
	return mini(7 + checkpoints, 11)   # D-223: gentler (was min(7 + 2n, 16), D-101)


func _update_traffic(dt: float) -> void:
	# D-288: in 2P the traffic moves once (on player 1's pass), reacting to
	# both players; each player's pass handles that player's contacts.
	var move := not two_player or cur == 0
	var pv := _players_view()
	var lk := "last_ds" if cur == 0 else "last_ds1"
	for i in range(traffic.size() - 1, -1, -1):
		var t: Dictionary = traffic[i]
		var prev_ds: float = t.get(lk, t.s - s)
		var tlen: float = t.get("len", CAR_LEN)
		var tw: float = t.get("w", CAR_W)
		if move:
			_move_traffic(t, dt, pv)
		var ds: float = t.s - s
		t[lk] = ds
		# Oncoming drivers flash their high beams (and honk once) at a car
		# coming at them in their lane (D-105).
		var fl: bool = state == State.RACE and t.v < 0.0 and ds > 8.0 and ds < HIGHBEAM_RANGE 			and absf(t.x - x) < HIGHBEAM_DX
		t.flash = fl or (cur == 1 and bool(t.get("flash", false)))
		var fk := "flashed" if cur == 0 else "flashed1"
		if fl and not t.get(fk, false):
			t[fk] = true
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
			# Side contact (D-152): they already overlapped along the road on the
			# previous frame, so the contact came from moving sideways: a
			# side-swipe, not a crash. Both bounce apart and we lose a little.
			var side_hit := absf(prev_ds) < (CAR_LEN + tlen) * 0.5 - 0.05
			if side_hit and float(t.get("swipe_cd", 0.0)) <= 0.0:
				var away := signf(x - t.x + 0.001)
				v *= SIDE_SLOW
				lat_v = away * SIDE_BOUNCE
				# Both turn away from each other (D-239): our nose to our side,
				# theirs to theirs (an oncoming car faces the other way).
				sway = -away * SWAY
				t.sway = (away if t.v >= 0.0 else -away) * SWAY
				x += away * 0.3
				t.shove = float(t.get("shove", 0.0)) - away * (0.8 if big else 1.6)
				t.swipe_cd = 0.4
				_end_drift()
				events.append(["bump", t.id])
			elif side_hit:
				pass
			elif (t.v < 0.0 or (ds > 0.0 and rel > 22.0)) and v * MPH < SOFT_CRASH_MPH:
				# Slow (D-223): just a knock; stop short of it and bounce aside.
				_soft_bump(t.x)
				if ds > 0.0:
					s = t.s - (CAR_LEN + tlen) * 0.5 - 0.3
				x += signf(x - t.x + 0.01) * 1.2
			elif t.v < 0.0 or (ds > 0.0 and rel > 22.0):
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
		t.swipe_cd = maxf(0.0, float(t.get("swipe_cd", 0.0)) - dt)
		t.sway = move_toward(float(t.get("sway", 0.0)), 0.0, SWAY_BACK * dt)
		if (not two_player or cur == 1) and _far_from_all(t.s, pv):
			traffic.remove_at(i)
	if state == State.OVER:
		return
	var near := 0
	for t in traffic:
		if t.s - s >= -60.0 and t.s - s <= 900.0:
			near += 1
	if near < traffic_target():
		_spawn_traffic()


## Moves one traffic car (its speed, lane, yielding, waiting and dodging),
## reacting to every player (D-288; one player outside 2P).
func _move_traffic(t: Dictionary, dt: float, pv: Array) -> void:
	var tlen: float = t.get("len", CAR_LEN)
	var tw: float = t.get("w", CAR_W)
	t.s += t.v * dt
	t.weave += dt
	# Shoved aside by a side bump (D-152): an offset that eases back to the lane.
	t.shove = move_toward(float(t.get("shove", 0.0)), 0.0, 2.0 * dt)
	# Yielding to the police (D-163): near its lights, traffic pulls over
	# to its own right-hand edge, slows and indicates; then rejoins.
	var lane_x: float = Track.LANES[t.lane]
	var yielding := false
	for p in pv:
		if p.lights and t.s > float(p.ps) - 40.0 and t.s < float(p.ps) + YIELD_AHEAD:
			yielding = true
	t.blink = yielding
	var tw2: float = t.get("w", CAR_W)
	var edge := signf(lane_x) * (Track.ROAD_HALF - tw2 * 0.5 - 0.2)
	t.pull = move_toward(float(t.get("pull", 0.0)), (edge - lane_x) if yielding else 0.0, 2.2 * dt)
	if not t.has("v0"):
		t.v0 = t.v
	var waited := false
	for p in pv:
		var behind: float = p.s - t.s
		if p.spin > 0.0 and t.v0 > 0.0 and behind > 0.0 and behind < WAIT_BEHIND \
				and absf(float(t.get("x", lane_x)) - p.x) < (CAR_W + tw) * 0.5 + 0.8:
			# A player crashed in its way (D-223): it brakes and waits behind.
			var room: float = behind - (CAR_LEN + tlen) * 0.5 - WAIT_GAP
			t.v = move_toward(t.v, clampf(room * 0.9, 0.0, float(t.v0)), 16.0 * dt)
			waited = true
			break
	t.waiting = waited
	if not waited:
		t.v = move_toward(t.v, float(t.v0) * (YIELD_SLOW if yielding else 1.0), 6.0 * dt)
	# D-271: oncoming traffic heading at us while we're crashed or stopped
	# swerves round us (keeping clear by a margin), slowing as it passes;
	# if there's no room either side, it stops short of us.
	var dodge_to := 0.0
	for p in pv:
		var ahead: float = t.s - p.s
		if not ((p.spin > 0.0 or p.v < 4.0) and float(t.v0) < 0.0 and ahead > -2.0 and ahead < DODGE_AHEAD):
			continue
		var px: float = p.x
		var need := (CAR_W + tw) * 0.5 + DODGE_CLEAR
		var dx := lane_x - px
		if absf(dx) < need:
			var lim := Track.ROAD_HALF + Track.RUMBLE - tw * 0.5
			var dir := signf(dx) if absf(dx) > 0.01 else -1.0
			var want_x := px + dir * need
			if absf(want_x) > lim:
				want_x = px - dir * need
			if absf(want_x) <= lim:
				dodge_to = want_x - lane_x
				t.v = move_toward(t.v, float(t.v0) * 0.6, 10.0 * dt)
			else:
				var room := ahead - (CAR_LEN + tlen) * 0.5 - WAIT_GAP
				t.v = move_toward(t.v, -clampf(room * 0.9, 0.0, absf(float(t.v0))), 18.0 * dt)
				t.waiting = true
		break
	t.dodge = move_toward(float(t.get("dodge", 0.0)), dodge_to, DODGE_RATE * dt)
	t.x = lane_x + sin(t.weave * 0.4) * (0.25 if t.get("kind", "car") == "truck" else 0.6) * (0.0 if yielding else 1.0) 			+ t.shove + t.pull + float(t.dodge)


## Each player's position and state as the traffic sees them.
func _players_view() -> Array:
	var out := []
	for i in (2 if two_player else 1):
		var pol: Dictionary = player_get(i, "police")
		var lights: bool = not pol.is_empty() and (pol.state == "chase" or (pol.state == "bust" and not pol.get("fined", false)))
		out.append({"s": float(player_get(i, "s")), "x": float(player_get(i, "x")), "v": float(player_get(i, "v")),
			"spin": float(player_get(i, "spin_t")), "lights": lights, "ps": float(pol.get("s", 0.0))})
	return out


func _far_from_all(ts: float, pv: Array) -> bool:
	for p in pv:
		var d: float = ts - float(p.s)
		if d >= -60.0 and d <= 900.0:
			return false
	return true


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
	if two_player:   # D-288: never pop up in sight of the other player
		var other_s: float = player_get(1 - cur, "s")
		var rel := s + ahead - other_s
		if rel > -80.0 and rel < 400.0:
			return
	if s + ahead > FINISH_STAGE * CHECKPOINT_EVERY - 20.0:
		return   # nothing appears past the finish line (D-223)
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
