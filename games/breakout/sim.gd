## Tilt Breaker gameplay simulation — pure logic, no nodes (D-040). The game module
## renders it; tests drive it headless. Coordinates: x right, y = world z, +y
## towards the player. All tuning values are constants here (see GDD §5.1 tuning).
extends RefCounted

const BP = preload("res://games/breakout/ball_physics.gd")

# --- playfield -----------------------------------------------------------------
## Invisible rebound boundaries (D-049), kept a little inside the screen edges
## (screen is 9 units wide); rebounds there show an energy-shield flash.
const FIELD := Rect2(-4.1, -7.1, 8.2, 15.1)  # left, top, width, height
## The plasma is lost once it passes the planet's horizon line (D-043).
const DRAIN_Y := 7.3
# --- paddle --------------------------------------------------------------------
const PADDLE_Y := 5.9
const PADDLE_W := 1.5
const PADDLE_H := 0.42
const PADDLE_MAX_SPEED := 11.0
const PADDLE_ACCEL := 70.0
const PADDLE_DECEL := 90.0
const PADDLE_REVERSE := 160.0  # extra grip when changing direction
const DASH_SPEED := 26.0
const DASH_TIME := 0.12
const DASH_COOLDOWN := 0.6
# --- ball ----------------------------------------------------------------------
const BALL_R := 0.16
const BALL_START_SPEED := 8.5
const BALL_MAX_SPEED := 13.5          # reasonable cap, reached after ~20 returns
## Difficulty (D-182): the plasma's start speed and cap, and lives added to the
## operator's balls per game (at least 1). Normal is the original tuning.
const DIFFICULTIES := {
	"easy": {"start": 6.8, "max": 11.5, "balls": 2},
	"normal": {"start": BALL_START_SPEED, "max": BALL_MAX_SPEED, "balls": 0},
	"hard": {"start": 10.0, "max": 15.5, "balls": -1},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]
const SPEEDUP_PER_PADDLE_HIT := 0.25  # noticeable speed-up per ship hit (D-054)
const MIN_VERTICAL := 0.28
const AUTO_SERVE_SECONDS := 6.0
const MAX_SUBSTEP := 0.05  # world units per collision substep (no tunnelling)
# --- bricks --------------------------------------------------------------------
const BRICK_ROWS := 10   # max rows a level may use
const BRICK_COLS := 11
## Levels (D-068): text grids, one char per brick (R/Y/G/B = colour, . = empty).
## After the last file the levels loop.
const LEVEL_FILES := [
	"res://games/breakout/levels/level_01.txt",
	"res://games/breakout/levels/level_02.txt",
	"res://games/breakout/levels/level_03.txt",
	"res://games/breakout/levels/level_04.txt",
	"res://games/breakout/levels/level_05.txt",
	"res://games/breakout/levels/level_06.txt",
	"res://games/breakout/levels/level_07.txt",
	"res://games/breakout/levels/level_08.txt",
	"res://games/breakout/levels/level_09.txt",
	"res://games/breakout/levels/level_10.txt",
	"res://games/breakout/levels/level_11.txt",
	"res://games/breakout/levels/level_12.txt",
	"res://games/breakout/levels/level_13.txt",
	"res://games/breakout/levels/level_14.txt",
	"res://games/breakout/levels/level_15.txt",
	"res://games/breakout/levels/level_16.txt",
	"res://games/breakout/levels/level_17.txt",
	"res://games/breakout/levels/level_18.txt",
	"res://games/breakout/levels/level_19.txt",
	"res://games/breakout/levels/level_20.txt",
]
## D-285: 2-player levels, 19 columns on a wider field (generated from the
## 1-player ones; the director may edit them).
const LEVEL_FILES_2P := [
	"res://games/breakout/levels/level2p_01.txt", "res://games/breakout/levels/level2p_02.txt",
	"res://games/breakout/levels/level2p_03.txt", "res://games/breakout/levels/level2p_04.txt",
	"res://games/breakout/levels/level2p_05.txt", "res://games/breakout/levels/level2p_06.txt",
	"res://games/breakout/levels/level2p_07.txt", "res://games/breakout/levels/level2p_08.txt",
	"res://games/breakout/levels/level2p_09.txt", "res://games/breakout/levels/level2p_10.txt",
	"res://games/breakout/levels/level2p_11.txt",
	"res://games/breakout/levels/level2p_12.txt",
	"res://games/breakout/levels/level2p_13.txt",
	"res://games/breakout/levels/level2p_14.txt",
	"res://games/breakout/levels/level2p_15.txt",
	"res://games/breakout/levels/level2p_16.txt",
	"res://games/breakout/levels/level2p_17.txt",
	"res://games/breakout/levels/level2p_18.txt",
	"res://games/breakout/levels/level2p_19.txt",
	"res://games/breakout/levels/level2p_20.txt",
]
const BRICK_COLS_2P := 19
const FIELD_2P := Rect2(-7.08, -7.1, 14.16, 15.1)   # 19 bricks at the 1P brick width
const P2_LIFT := 0.6    # player 2's ship flies this much higher, so the ships pass (D-285)
const COLOUR_POINTS := {"R": 120, "Y": 100, "G": 80, "B": 60}
## Brick letters (D-073): UPPERCASE = 1 hit, lowercase = 2-hit armoured
## (1.5x points), X = indestructible metal (doesn't count for clearing).
const ARMOURED_MULT := 1.5
const CHARGED_POINTS := 200   # D-342
const PLASMA_POINTS := 150    # D-342
## D-342: torpedoes (the boss's ray, D-335, generalised): {id, pos, vel, r, len}.
## They pass through bricks; a plasma ball stops them; they cost the ship a charge.
const TORP_BRICK := {"speed": 4.0, "r": 0.1, "len": 0.6}     # from a charged brick, straight down
const TORP_MINI := {"speed": 4.25, "r": 0.08, "len": 0.5}    # from a mini-icosahedron
## D-342: the mini-icosahedron enemy (from level 11): moves like the others,
## charges MINI_CHARGE s and fires a small torpedo at the ship every MINI_FIRE s.
const ICO_FROM_LEVEL := 11
const ICO_CHANCE := 0.3
const MINI_FIRE := Vector2(6.0, 10.0)
const MINI_CHARGE := 0.9
## D-347: mini-icosahedrons stay in the top 20% of the field: they never sink
## below this (their centre), never orbit the ship and never circle to get unstuck.
const ICO_TOP_FRAC := 0.2
## D-342: the corrupted paddle (from level 15): a dark copy of the ship that
## warps in DARK_Y_FRAC down the field (only where no brick is in the way),
## slides side to side and blocks the plasma. 10 HP: a ball hit 1, a weapon 2.
const DARK_FROM_LEVEL := 15
const DARK_Y_FRAC := 0.35
const DARK_HP := 10
const DARK_SPEED := 3.0               # D-347: top speed chasing the ball (was 4.5; the player's is 11)
const DARK_ACCEL := 25.0
const DARK_WARP := 0.8
const DARK_POINTS := 1500
const DARK_INTERVAL := Vector2(18.0, 28.0)
const DARK_FIRST := 12.0
const BRICK_TOP := -5.55  # leaves the top 10% free for enemies (D-052)
const BRICK_H := 0.4
const BRICK_GAP := 0.05
const RACK_BONUS := 1000
# --- energy blast (D-051) ---------------------------------------------------------
const BLAST_CHARGE_TIME := 0.68    # per charge level (director: -20% D-054, then -15% D-056)
const BLAST_MAX_LEVEL := 3         # levels 1..3, each needs one more power cell
const BLAST_COST := 1.0 / 3.0      # per level; a full power bar = 3 levels
const POWER_RECHARGE_DELAY := 1.0  # after the last blast
const POWER_RECHARGE_RATE := 1.0 / 15.0  # per second (full bar in 15 s)
## D-330: the plasma refills the bar too, on top of the recharge over time:
## each brick it hits (for the ship that last hit it) and each hit off the ship.
const BRICK_HIT_POWER := 0.02
const PADDLE_HIT_POWER := 0.05
const BLAST_SPEED := 20.0
const BLAST_W := 0.36
const BLAST_H := 0.7
# --- tetrahedron enemy (D-052) -----------------------------------------------------
const ENEMY_R := 0.31                # hitbox radius (director: 50% smaller, D-053)
const ENEMY_POINTS := 500
const ENEMY_FIRST_SPAWN := 10.0      # seconds of play before the first one
const ENEMY_INTERVAL := Vector2(14.0, 22.0)
const ENEMY_MAX := 2
const WORMHOLE_TIME := 1.2           # emerging: not collidable yet
const ENEMY_SPAWN_Y := -6.4          # top 10% of the screen
const ENEMY_SWEEP_AMP := 3.2         # wide horizontal sine sweeps
const ENEMY_SWEEP_SPEED := 0.6       # rad/s
const ENEMY_DESCENT := 0.45          # units/s when the way down is clear
const ENEMY_ORBIT_START_Y := PADDLE_Y - 1.1
const ENEMY_ORBIT_R := Vector2(2.6, 0.9)
const ENEMY_ORBIT_SPEED := 0.9       # rad/s
const SHIP_INVULNERABLE := 2.0       # after the ship is destroyed and respawns
## Enemy difficulty tiers (D-073): every 5 levels enemies get faster/more aggressive.
const ENEMY_TIER_SPEED := 0.4        # +40% movement per tier
const ENEMY_TIER_RATE := 0.5         # spawn interval / (1 + 0.5 * tier)
# --- power-ups (D-072) ----------------------------------------------------------------
const POWERUP_EVERY := 8             # every 8th brick destroyed (D-329, was 10)...
const POWERUP_CHANCE := 0.7          # ...has a 70% chance to drop one
const DROP_PITY := 15                # D-333: 15 bricks with no drop: the 16th drops one
const POWERUP_FALL := 2.2
const POWERUP_R := 0.28
const POWERUP_REACH_UP := 0.55       # D-329: the catch hitbox reaches this far above the capsule
const POWERUP_KINDS := ["T", "P", "B", "I", "W", "H", "L", "S", "K", "U", "N"]
## D-335: the boss of level 10 (every 10th level): an icosahedron with a red
## eye that roams the top of the field, never lower than BOSS_Y.y, and every
## 10-15 s charges (BOSS_CHARGE s) and fires a slow ray at the ship. The ray
## passes through bricks; only a plasma ball stops it. The level is clear when
## its bricks are gone AND the boss is destroyed.
const BOSS_EVERY := 10
const BOSS_R := 1.2                  # hitbox (about 5 cubes across)
const BOSS_HP := 45                  # D-340: 150% of D-335's 30
const BOSS_POINTS := 5000
const BOSS_Y := Vector2(-5.3, -4.85)    # its centre's top and bottom limits (its top edge clear of the rail)
const BOSS_SPEED := 0.35             # rad/s along its Lissajous path
const BOSS_FIRE := Vector2(10.0, 15.0)
const BOSS_CHARGE := 1.5
const RAY_SPEED := 4.25              # m/s: slow enough to see coming (D-338: +25%)
const RAY_LEN := 0.88                # m, head to tail (D-338: -20%)
const RAY_R := 0.128                 # half its thickness (D-338: -20%)
const DODECA_HP := 60                # D-342: the level-20 boss
const DODECA_SHOT_SPEED := 0.7       # x RAY_SPEED for its three torpedoes
const BOSS_DROP_EVERY := 4           # D-339: every 4 damage to the boss drops a capsule
const BOSS_HITS := {"ball": 1, "missile": 3, "ion": 3, "wave": 2}

## D-327: two slots. Blaster upgrades (atom capsules) replace the plasma cannon:
## they charge to level 1 only (one BLAST_CHARGE_TIME) and each shot uses
## UPGRADE_COST of the 3-cell power bar. Paddle upgrades (pill capsules) change
## the ship and use no energy. One of each can be held at once.
const BLASTER_KINDS := ["T", "P", "B", "I", "W", "H"]
const PADDLE_KINDS := ["S", "L", "K"]
const UPGRADE_COST := {"T": 1.0 / 3.0, "P": 1.0 / 3.0, "B": 1.0, "I": 1.0, "W": 1.0, "H": 1.0}
const SIDEKICK_W := PADDLE_W / 3.0   # K: each sidekick (a third of the ship, D-332) adds this much reach per side
## W: a wave shot that snakes up, hitting each brick in its way once, never stopped.
const WAVE_SPEED := 10.0
const WAVE_AMP := 1.1                # m either side of where it was fired
const WAVE_RATE := 6.0               # rad/s of its side-to-side swing
const WAVE_SIZE := Vector2(0.7, 0.5)
## H: a homing missile at the nearest enemy or brick; its blast hits everything
## in a 3x3-brick area three times.
const MISSILE_SPEED := 11.0
const MISSILE_TURN := 7.0            # rad/s
const MISSILE_R := 0.15
const MISSILE_AREA := Vector2(3.0, 3.0)   # in bricks (columns x rows)
const MISSILE_HITS := 3
## D-326: instant power-ups, used on the catch (never held): U = 1UP (an extra
## charge), N = Nuclear (every brick on screen goes). Rarer: INSTANT_CHANCE of all drops
## between them (D-329).
const INSTANT_KINDS := ["U", "N"]
const INSTANT_CHANCE := 0.04         # D-341: of drops, 1UP or Nuclear (2% each; was 8%, D-329)
const TRIPLE_ANGLE := 20.0           # T: side bolts at +-20 degrees (D-078)
const ION_BEAM_W := 0.7              # I: width of the beam
const LIGHTSPEED_MULT := 1.3         # L: ship speed (assumption, D-072)
const GHOST_DELAYS := [0.09, 0.18]   # L: afterimages trail by these delays
const GHOST_MIN_GAP := 0.3           # afterimages only exist while moving
const SHIELD_Y := PADDLE_Y + 0.85    # S: barrier line (above the horizon)

enum State { SERVE, PLAY, LEVEL_CLEAR, OVER }

var state := State.SERVE
var score := 0
var balls_left := 3
var balls_total := 3   # lives at the start of the game (DMD status dots)
var _nuking := false
var _last_drop_group := "" if randf() < 0.5 else "blaster"   # D-329: "blaster" / "paddle"; the next drop is the other   # D-326: no capsules from the bricks a nuke destroys
## D-321: an extra life at each of these scores (once each, per game).
const EXTRA_LIFE_AT := [20000, 50000]
var extra_lives_given := 0
var difficulty := "normal"
var ball_start_speed := BALL_START_SPEED
var ball_max_speed := BALL_MAX_SPEED
var level := 1

## D-285: local 2-player. The field and its columns can widen; each player's
## ship state lives in PLAYER_FIELDS, swapped in by _use(i) so the 1-player
## code runs unchanged for whichever ship is current.
var two_player := false
var field := FIELD
var cols := BRICK_COLS
var server := 0        # the player whose ship holds the ball before a serve
var _last_hitter := 0  # D-330: the ship that last sent the plasma up (its brick hits refill its bar)
var cur := 0           # the player whose fields are live
var _pl := [{}, {}]
const PLAYER_FIELDS := ["paddle_x", "paddle_vx", "paddle_y", "_dash_time", "_dash_cd", "_dash_dir",
	"powerup", "padup", "shield_active", "_paddle_hist", "power", "blast_charge", "_since_blast", "_both_held",
	"_await_release", "_both_hold_t", "_fail_reported", "ship_invulnerable", "charge_held", "paddle_axis"]

var paddle_x := 0.0
var paddle_vx := 0.0
var paddle_y := PADDLE_Y
var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := 0

var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_speed := BALL_START_SPEED
## Extra plasma balls from the Bounce power-up: {pos, vel, speed}. A charge is
## only lost when the main ball AND all extras are gone (D-072).
var extra_balls: Array = []

## Power-ups (D-072): current one ("" = none), falling capsules {id, pos, kind},
## the Shield barrier, and the ship's position history (Lightspeed afterimages).
var powerup := ""     # the blaster slot (D-327)
var padup := ""       # the paddle slot (D-327)
var powerups: Array = []
## D-327: live wave shots {id, x0, pos, t, hit: {brick index: true}} and
## missiles {id, pos, vel, target: ["enemy", id] | ["brick", index]}.
var waves: Array = []
var missiles: Array = []
var _next_shot_id := 1
var shield_active := false
var _next_powerup_id := 1
var _broken_count := 0
var _since_drop := 0
## D-335: boss state (boss_hp 0 = no boss), its rays {id, pos, vel}.
var boss_hp := 0
var boss_pos := Vector2.ZERO
var boss_t := 0.0
var boss_fire_in := 0.0
var boss_charging := false
var rays: Array = []
var _boss_aim := 0
var _boss_drop_count := 0
var boss_kind := "ico"   # D-342: "ico" (level 10, 30...) or "dodeca" (level 20, 40...)
var boss_max_hp := BOSS_HP
var darks: Array = []    # D-342: corrupted paddles {id, pos, vx, hp, state ("warp"|"live"), t}
var _dark_timer := DARK_FIRST   # D-339: damage since its last capsule   # 2P: the ship the next ray goes for (alternates)   # D-333: bricks destroyed since the last capsule drop
var _time := 0.0
var _paddle_hist: Array = []  # [time, x], newest last
var _held_time := 0.0
## D-344: seconds before the plasma can be launched again after a lost charge.
const SERVE_LOCK := 2.0
var serve_lock := 0.0
## Test hook: keeps the plasma in place (used by headless tests of long holds).
var freeze_ball := false

## Energy blast power 0..1 and the charge of the held flippers in levels
## (0..BLAST_MAX_LEVEL, fractional while charging).
var power := 1.0
var blast_charge := 0.0
var _since_blast := 99.0
var _both_held := false
var _await_release := false  # after an automatic max-charge shot (D-074)
var _both_hold_t := 0.0       # how long both flippers have been held
var _fail_reported := false   # LOW POWER reported for this hold (D-075)
const LOW_POWER_HOLD := 0.5   # only warn if both flippers are held this long
## Live blasts: {pos: Vector2, level: int, hits_left: int}. A level-n blast hits
## up to n bricks/enemies (one plasma hit each), then dissolves; otherwise it
## dissolves at the top boundary.
var blasts: Array = []

## Tetrahedron enemies: {id, pos, state ("wormhole"|"sweep"|"orbit"), t, phase,
## dir, center: Vector2 (orbit), angle (orbit)}.
var enemies: Array = []
var ship_invulnerable := 0.0
var _enemy_timer := ENEMY_FIRST_SPAWN
var _next_enemy_id := 1

## Each brick: {rect: Rect2, hp: int, alive: bool, row: int, points: int}
var bricks: Array = []
## Events produced by the last step(): [name, data]. Names: serve, paddle, wall,
## wall (data = [side "l"|"r"|"t", hit position]), brick (data = index),
## rack_clear (data = cleared level; state becomes LEVEL_CLEAR until the game
## calls next_level()), lost (data = x where the plasma left), over, dash,
## charge_start (data = level being charged), charged (data = level reached),
## blast (data = [start pos, level]), blast_fail (low power),
## blast_end (data = [pos, brick index or -1, level]),
## enemy_spawn (data = [id, pos]), enemy_ready (id),
## enemy_destroyed (data = [id, pos, shot_down]), ship_destroyed (data = ship pos),
## brick_hit (data = index; armoured brick cracked), powerup_spawn ([id, pos, kind]),
## powerup_collect ([id, kind]), powerup_lost (id), powerup_end (kind),
## ion_beam (x), bounce_ball (pos), extra_lost (x), ball_promoted, ghost (x),
## shield_used (x).
var events: Array = []


func setup(balls: int, diff: String = "normal") -> void:
	set_difficulty(diff, balls)
	score = 0
	extra_lives_given = 0
	level = 1
	build_rack()
	_reset_serve()


## D-285: a 2-player game on the wide field: two ships, shared lives and score.
func setup_two(balls: int, diff: String = "normal") -> void:
	two_player = true
	field = FIELD_2P
	cols = BRICK_COLS_2P
	for i in 2:
		var d := {}
		for f in PLAYER_FIELDS:
			d[f] = get(f)
		d.paddle_x = _start_x(i)
		d.paddle_y = PADDLE_Y - (P2_LIFT if i == 1 else 0.0)
		d.paddle_vx = 0.0
		d._paddle_hist = []
		d.power = 1.0
		d.powerup = ""
		d.padup = ""
		d.shield_active = false
		_pl[i] = d
	cur = 0
	for f in PLAYER_FIELDS:
		set(f, _pl[0][f])
	server = 0
	setup(balls, diff)


func _start_x(i: int) -> float:
	return field.size.x * (-0.22 if i == 0 else 0.22)


## Makes player i's ship state the live one (2P, D-285).
func _use(i: int) -> void:
	if not two_player or i == cur:
		return
	for f in PLAYER_FIELDS:
		_pl[cur][f] = get(f)
	for f in PLAYER_FIELDS:
		set(f, _pl[i][f])
	cur = i


## A player's value of a ship field, whichever is live.
func player_get(i: int, f: String) -> Variant:
	if not two_player or i == cur:
		return get(f)
	return _pl[i][f]


## D-286: in 2P, the ship each event of the last step came from (by index;
## missing = not a ship's own event).
var event_ship: Array = []


## 2-player step (D-285): each player's controls as [left, right, launch, dash].
func step_two(dt: float, a: Array, b: Array) -> void:
	events.clear()
	event_ship.clear()
	_check_extra_life()
	while event_ship.size() < events.size():
		event_ship.append(0)
	if state == State.OVER or state == State.LEVEL_CLEAR:
		return
	_time += dt
	var inp := [a, b]
	for i in 2:
		_use(i)
		var c: Array = inp[i]
		_update_power_and_blast(dt, (c[0] and c[1]) or charge_held)
		_move_paddle(dt, c[0], c[1], c[3])
		while event_ship.size() < events.size():
			event_ship.append(i)
	_use(0)
	_update_shots(dt)   # D-327
	if state == State.OVER or state == State.LEVEL_CLEAR:
		return
	_update_boss(dt)   # D-335
	if state == State.OVER:
		return
	_update_enemies(dt)
	if state == State.OVER:
		return
	_update_powerups(dt)
	if state == State.SERVE:
		_use(server)
		ball_pos = Vector2(paddle_x, paddle_y - PADDLE_H * 0.5 - BALL_R - 0.01)
		_held_time += dt
		serve_lock = maxf(0.0, serve_lock - dt)
		var go: bool = (inp[server][2] or _held_time >= AUTO_SERVE_SECONDS) and serve_lock <= 0.0
		if go:
			_serve()
		_use(0)
		return
	if state != State.PLAY or freeze_ball:
		return
	_step_balls(dt)


## Picks the difficulty before play starts (D-182): ball speeds and lives from
## the operator's balls per game. Doesn't touch the level or the score.
func set_difficulty(diff: String, operator_balls: int) -> void:
	if not DIFFICULTIES.has(diff):
		diff = "normal"
	difficulty = diff
	var d: Dictionary = DIFFICULTIES[diff]
	ball_start_speed = d.start
	ball_max_speed = d.max
	balls_left = maxi(1, operator_balls + int(d.balls))
	balls_total = balls_left
	if state == State.SERVE:
		ball_speed = ball_start_speed


## Builds the bricks of the current level from its text file.
func build_rack() -> void:
	_setup_boss()   # D-335
	bricks.clear()
	var layout := level_layout(level, two_player)
	var w := field.size.x / cols
	for row in mini(layout.size(), BRICK_ROWS):
		var line: String = layout[row]
		for col in mini(line.length(), cols):
			var raw := line[col]
			var ch := raw.to_upper()
			var metal := ch == "X"
			# D-342: C = charged (red, 2 hits; the first fires a torpedo down),
			# P = plasma (holds a ball that's set free when it breaks).
			var charged := raw == "C"
			var plasma := raw == "P"
			if charged or plasma:
				var rect2 := Rect2(field.position.x + col * w + BRICK_GAP * 0.5,
					BRICK_TOP + row * BRICK_H + BRICK_GAP * 0.5, w - BRICK_GAP, BRICK_H - BRICK_GAP)
				bricks.append({"rect": rect2, "hp": 2 if charged else 1, "alive": true,
					"row": row, "col": col, "colour": "R" if charged else "B",
					"points": CHARGED_POINTS if charged else PLASMA_POINTS,
					"metal": false, "armoured": false, "charged": charged, "plasma": plasma})
				continue
			if not metal and not COLOUR_POINTS.has(ch):
				continue
			var armoured := not metal and raw != ch  # lowercase
			var rect := Rect2(field.position.x + col * w + BRICK_GAP * 0.5,
				BRICK_TOP + row * BRICK_H + BRICK_GAP * 0.5, w - BRICK_GAP, BRICK_H - BRICK_GAP)
			var pts := 0 if metal else int(COLOUR_POINTS[ch] * (ARMOURED_MULT if armoured else 1.0))
			bricks.append({"rect": rect, "hp": -1 if metal else (2 if armoured else 1), "alive": true,
				"row": row, "col": col, "colour": ch, "points": pts,
				"metal": metal, "armoured": armoured})


## Rows of level n (1-based; loops over LEVEL_FILES). Comment lines start with #.
static func level_layout(n: int, wide: bool = false) -> Array:
	var files: Array = LEVEL_FILES_2P if wide else LEVEL_FILES
	var path: String = files[(n - 1) % files.size()]
	var rows := []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var l := line.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		rows.append(l)
	return rows


## Loads the next level after LEVEL_CLEAR (the game calls this once its
## level-complete sequence has faded out).
func next_level() -> void:
	level += 1
	build_rack()
	enemies.clear()
	blasts.clear()
	_clear_shots()   # D-327
	blast_charge = 0.0
	_enemy_timer = ENEMY_FIRST_SPAWN / (1.0 + ENEMY_TIER_RATE * enemy_tier())
	power = 1.0  # full power bar at the start of each level (D-076)
	powerups.clear()
	_end_powerup()
	extra_balls.clear()
	# D-275: the ship always rises into the middle of the new level (2P: each
	# ship in the middle of its half, D-285).
	if two_player:
		for i in 2:
			_use(i)
			paddle_x = _start_x(i)
			paddle_vx = 0.0
			power = 1.0
			blast_charge = 0.0
			_end_powerup()
		_use(0)
	else:
		paddle_x = field.get_center().x
		paddle_vx = 0.0
	_reset_serve()


## 0 for levels 1-5, 1 for 6-10, 2 for 11-15... (D-073)
func enemy_tier() -> int:
	return (level - 1) / 5


func enemy_speed_mult() -> float:
	return 1.0 + ENEMY_TIER_SPEED * enemy_tier()


## Destructible bricks still standing (metal X never counts).
func bricks_alive() -> int:
	var n := 0
	for b in bricks:
		if b.alive and not b.get("metal", false):
			n += 1
	return n


func paddle_rect() -> Rect2:
	return Rect2(paddle_x - PADDLE_W * 0.5, paddle_y - PADDLE_H * 0.5, PADDLE_W, PADDLE_H)


## D-327: half the ship's catching width: wider with the Sidekicks.
func catch_half_w() -> float:
	return PADDLE_W * 0.5 + (SIDEKICK_W if padup == "K" else 0.0)


## D-327: what bounces the plasma and catches capsules (the ship plus any sidekicks).
func catch_rect() -> Rect2:
	var h := catch_half_w()
	return Rect2(paddle_x - h, paddle_y - PADDLE_H * 0.5, h * 2.0, PADDLE_H)


## A player's ship field, set whichever ship is live (2P, D-286).
func player_set(i: int, f: String, v: Variant) -> void:
	if not two_player or i == cur:
		set(f, v)
	else:
		_pl[i][f] = v


## Advances the simulation. left/right: flipper buttons held. launch: pressed this
## frame. dash: -1/+1 if a magna save was pressed this frame, else 0.
func step(dt: float, left: bool, right: bool, launch: bool, dash: int) -> void:
	events.clear()
	_check_extra_life()
	if state == State.OVER or state == State.LEVEL_CLEAR:
		return
	_time += dt
	_update_power_and_blast(dt, (left and right) or charge_held)
	_move_paddle(dt, left, right, dash)
	_update_shots(dt)   # D-327
	if state == State.OVER or state == State.LEVEL_CLEAR:
		return
	_update_boss(dt)   # D-335
	if state == State.OVER:
		return
	_update_enemies(dt)
	if state == State.OVER:
		return
	_update_powerups(dt)  # capsules keep falling while waiting to fire
	if state == State.SERVE:
		ball_pos = Vector2(paddle_x, paddle_y - PADDLE_H * 0.5 - BALL_R - 0.01)
		_held_time += dt
		serve_lock = maxf(0.0, serve_lock - dt)
		if (launch or _held_time >= AUTO_SERVE_SECONDS) and serve_lock <= 0.0:   # D-344
			_serve()
		return
	if state != State.PLAY or freeze_ball:
		return
	_step_balls(dt)


## D-321: a life for each EXTRA_LIFE_AT score passed (shared in 2 players).
## Checked at the start of a step, so points from the last step count; the
## DMD's life dots grow with it.
func _check_extra_life() -> void:
	if state == State.OVER:
		return
	while extra_lives_given < EXTRA_LIFE_AT.size() and score >= int(EXTRA_LIFE_AT[extra_lives_given]):
		extra_lives_given += 1
		balls_left += 1
		balls_total = maxi(balls_total, balls_left)
		events.append(["extra_life", balls_left])


func _step_balls(dt: float) -> void:
	var main := {"pos": ball_pos, "vel": ball_vel, "speed": ball_speed}
	var r := _move_ball(main, dt)
	ball_pos = main.pos
	ball_vel = main.vel
	ball_speed = main.speed
	if r == BALL_STOP or state != State.PLAY:
		return
	for i in range(extra_balls.size() - 1, -1, -1):
		var e: Dictionary = extra_balls[i]
		var r2 := _move_ball(e, dt)
		if r2 == BALL_STOP or state != State.PLAY:
			return
		if r2 == BALL_DRAINED:
			extra_balls.remove_at(i)
			events.append(["extra_lost", e.pos.x])
	if r == BALL_DRAINED:
		if extra_balls.is_empty():
			_lose_ball()
		else:  # an extra ball becomes the main one: no charge lost
			var e: Dictionary = extra_balls.pop_front()
			ball_pos = e.pos
			ball_vel = e.vel
			ball_speed = e.speed
			events.append(["ball_promoted", null])


## Highest charge level the current power allows (0..BLAST_MAX_LEVEL). Power-ups
## change it (D-072): Bounce = 1 level for a full bar, Ion = only level 3 with a
## full bar, Lightspeed/Shield = no charged shot at all.
func affordable_level() -> int:
	if UPGRADE_COST.has(powerup):   # D-327: a blaster upgrade: level 1 if its cost is there
		return 1 if power >= float(UPGRADE_COST[powerup]) - 0.0001 else 0
	return clampi(int(floor(power / BLAST_COST + 0.0001)), 0, BLAST_MAX_LEVEL)


## The highest level the current blaster can reach: 1 with an upgrade (D-327).
func max_level() -> int:
	return 1 if UPGRADE_COST.has(powerup) else BLAST_MAX_LEVEL


## D-327: what one shot of the current blaster uses (the plain cannon: per level).
func shot_cost() -> float:
	return float(UPGRADE_COST.get(powerup, BLAST_COST))


## Whether charging is allowed: always, since paddle upgrades are a separate slot (D-327).
func blasts_enabled() -> bool:
	return true


## Holding both flippers charges level by level (BLAST_CHARGE_TIME each, up to
## what the power bar allows); releasing fires the reached level. Only while the
## plasma is in play (not while waiting to fire it). Power recharges slowly.
func _update_power_and_blast(dt: float, both: bool) -> void:
	_since_blast += dt
	if _since_blast >= POWER_RECHARGE_DELAY:
		power = minf(1.0, power + POWER_RECHARGE_RATE * dt)
	var can_charge := state == State.PLAY and blasts_enabled()
	if not both:
		_await_release = false
		_both_hold_t = 0.0
		_fail_reported = false
	else:
		_both_hold_t += dt
	if both and can_charge and _await_release:
		pass  # just auto-fired: release the flippers before charging again
	elif both and can_charge:
		var cap := affordable_level()
		if cap == 0:
			# Empty bar: stay silent unless the player keeps holding (D-075).
			if _both_hold_t >= LOW_POWER_HOLD and not _fail_reported:
				_fail_reported = true
				events.append(["blast_fail", null])
		elif not _both_held:
			events.append(["charge_start", 1])
		var before := blast_charge
		blast_charge = minf(blast_charge + dt / BLAST_CHARGE_TIME, float(cap))
		var reached := int(floor(blast_charge + 0.0001))
		if reached > int(floor(before + 0.0001)):
			events.append(["charged", reached])
			if reached >= max_level():
				# Maximum charge fires automatically (D-074).
				_fire(reached)
				blast_charge = 0.0
				_await_release = true
			elif reached < cap:
				events.append(["charge_start", reached + 1])
	elif _both_held:
		var lvl := int(floor(blast_charge + 0.0001))
		if can_charge and lvl >= 1:
			_fire(lvl)
		blast_charge = 0.0
	if not can_charge:
		blast_charge = 0.0
	_both_held = both and can_charge
	# Move blasts and resolve their hits.
	for i in range(blasts.size() - 1, -1, -1):
		var b: Dictionary = blasts[i]
		var pos: Vector2 = b.pos
		var dir: Vector2 = b.get("dir", Vector2.UP)
		var travel := BLAST_SPEED * dt
		var n := maxi(1, ceili(travel / MAX_SUBSTEP))
		var last_hit := -1
		var done := false
		var w := blast_width(int(b.level))
		for k in n:
			pos += dir * travel / n
			var rect := Rect2(pos - Vector2(w, BLAST_H) * 0.5, Vector2(w, BLAST_H))
			# D-335: a bolt that reaches the boss spends itself on it.
			if boss_hp > 0 and not BP.collide_circle_rect(boss_pos, BOSS_R, rect).is_empty():
				var dmg := int(b.hits_left)
				b.hits_left = 0
				if _hurt_boss(dmg, pos):
					return
				break
			# D-342: a corrupted paddle stops a bolt (a weapon hit).
			var dk := _dark_hit_by_rect(rect)
			if dk != -1:
				b.hits_left = 0
				_hurt_dark(dk, 2)
				break
			# Each brick/enemy touched uses one hit; the blast pierces until spent.
			var foe := _enemy_hit_by_rect(rect)
			if foe != -1:
				_destroy_enemy(foe)
				b.hits_left -= 1
				last_hit = -1
			else:
				for j in bricks.size():
					if bricks[j].alive and rect.intersects(bricks[j].rect):
						b.hits_left -= 1
						last_hit = j
						if _damage_brick(j):
							done = true  # new rack: blasts were cleared
						break
			if done:
				return
			if b.hits_left <= 0 or _blast_out(pos):
				break
		b.pos = pos
		if b.hits_left <= 0 or _blast_out(pos):
			blasts.remove_at(i)
			events.append(["blast_end", [pos, last_hit, int(b.level)]])


func _blast_out(pos: Vector2) -> bool:
	return pos.y - BLAST_H * 0.5 < field.position.y or pos.x < field.position.x or pos.x > field.end.x


## Fires the charged shot at level `lvl`, shaped by the current power-up (D-072).
func _fire(lvl: int) -> void:
	_since_blast = 0.0
	var start := Vector2(paddle_x, paddle_y - PADDLE_H * 0.5 - BLAST_H * 0.5)
	if UPGRADE_COST.has(powerup):   # D-327: an upgrade's shot uses its cost
		power = maxf(0.0, power - float(UPGRADE_COST[powerup]))
	match powerup:
		"I":  # Ion cannon: instant beam that fries the whole column
			events.append(["ion_beam", paddle_x])
			_ion_beam(paddle_x)
		"W":  # D-327: wave beam
			var wid := _next_shot_id
			_next_shot_id += 1
			waves.append({"id": wid, "x0": paddle_x, "pos": start, "t": 0.0, "hit": {}})
			events.append(["wave_fire", start])
		"H":  # D-327: homing missile
			var mid := _next_shot_id
			_next_shot_id += 1
			missiles.append({"id": mid, "pos": start, "vel": Vector2.UP * MISSILE_SPEED,
				"target": _missile_target(start)})
			events.append(["missile_fire", start])
		"P":  # D-327: Power laser: a level-3 bolt for one cell
			blasts.append({"pos": start, "level": 3, "hits_left": 3, "dir": Vector2.UP})
			events.append(["blast", [start, 3, Vector2.UP]])
		"B":  # Bounce plasma: an extra plasma ball
			var nose := Vector2(paddle_x, paddle_y - PADDLE_H * 0.5 - BALL_R - 0.05)
			var ang := deg_to_rad(randf_range(-12.0, 12.0))
			extra_balls.append({"pos": nose, "vel": Vector2(sin(ang), -cos(ang)) * ball_start_speed,
				"speed": ball_start_speed})
			events.append(["bounce_ball", nose])
		_:
			if not UPGRADE_COST.has(powerup):
				power = maxf(0.0, power - BLAST_COST * lvl)
			var dirs := [Vector2.UP]
			if powerup == "T":  # Triple laser: + two bolts at +-45 degrees
				var a := deg_to_rad(TRIPLE_ANGLE)
				dirs.append(Vector2(-sin(a), -cos(a)))
				dirs.append(Vector2(sin(a), -cos(a)))
			for d in dirs:
				blasts.append({"pos": start, "level": lvl, "hits_left": lvl, "dir": d})
				events.append(["blast", [start, lvl, d]])


func _ion_beam(x: float) -> void:
	var beam := Rect2(x - ION_BEAM_W * 0.5, field.position.y, ION_BEAM_W, paddle_y - field.position.y)
	if boss_hp > 0 and not BP.collide_circle_rect(boss_pos, BOSS_R, beam).is_empty():
		if _hurt_boss(int(BOSS_HITS["ion"]), boss_pos + Vector2(0.0, BOSS_R)):   # D-335
			return
	for k2 in range(darks.size() - 1, -1, -1):   # D-342
		if darks[k2].state == "live" and beam.intersects(_dark_rect(darks[k2])):
			_hurt_dark(k2, 2)
	for k in range(enemies.size() - 1, -1, -1):
		if enemies[k].state != "wormhole" and not BP.collide_circle_rect(enemies[k].pos, ENEMY_R, beam).is_empty():
			_destroy_enemy(k)
	# Only one brick column burns: the one closest to the beam centre (D-078).
	var col_x := INF
	for b in bricks:
		if b.alive and not b.metal and beam.intersects(b.rect) \
				and absf(b.rect.get_center().x - x) < absf(col_x - x):
			col_x = b.rect.get_center().x
	for j in bricks.size():
		var b: Dictionary = bricks[j]
		if b.alive and not b.metal and absf(b.rect.get_center().x - col_x) < 0.01:
			b.hp = 1
			if _damage_brick(j):
				return


## Debug (D-057): a free piercing level-3 plasma bolt from the ship that destroys
## everything in its vertical line. Works in any state except game over.
func debug_fire_line() -> void:
	if state == State.OVER:
		return
	var start := Vector2(paddle_x, paddle_y - PADDLE_H * 0.5 - BLAST_H * 0.5)
	blasts.append({"pos": start, "level": 3, "hits_left": 9999, "dir": Vector2.UP})


## Debug (D-068): destroys every remaining brick (triggers level complete).
func debug_clear_level() -> void:
	if state != State.PLAY and state != State.SERVE:
		return
	events.clear()
	for i in bricks.size():
		if bricks[i].alive and not bricks[i].metal:
			bricks[i].hp = 1
			if _damage_brick(i):
				return


## Blast hitbox width by level (bigger blasts are wider).
static func blast_width(level: int) -> float:
	return BLAST_W * [0.75, 1.0, 1.3][clampi(level, 1, 3) - 1]


## One hit on a brick (plasma or blast). Returns true if a new rack was built.
func _damage_brick(i: int) -> bool:
	var b: Dictionary = bricks[i]
	if b.get("metal", false):
		return false  # indestructible
	b.hp -= 1
	if b.get("charged", false) and b.hp == 1:   # D-342: the first hit fires it
		var bottom := Vector2(b.rect.get_center().x, b.rect.end.y + 0.1)
		_spawn_torpedo(bottom, Vector2.DOWN, TORP_BRICK)
		events.append(["brick_torpedo", [i, bottom]])
	if b.hp > 0:
		events.append(["brick_hit", i])
		return false
	b.alive = false
	if b.get("plasma", false):   # D-342: its captured ball goes free
		var ang := deg_to_rad(randf_range(-30.0, 30.0))
		var c: Vector2 = b.rect.get_center()
		extra_balls.append({"pos": c, "vel": Vector2(sin(ang), cos(ang)) * ball_start_speed, "speed": ball_start_speed})
		events.append(["plasma_free", c])
	score += b.points
	events.append(["brick", i])
	_broken_count += 1
	_since_drop += 1
	# D-333: after DROP_PITY bricks without a drop, the next one always drops.
	var due := _broken_count % POWERUP_EVERY == 0 and randf() < POWERUP_CHANCE
	if not _nuking and (due or _since_drop > DROP_PITY) and bricks_alive() > 0:
		_since_drop = 0
		spawn_powerup(random_powerup_kind(), b.rect.get_center())
	if bricks_alive() == 0 and boss_hp <= 0:   # D-335: and the boss is down
		score += RACK_BONUS
		# Level complete (D-068): every enemy left explodes; play pauses until
		# the game runs its outro and calls next_level().
		while not enemies.is_empty():
			_destroy_enemy(0, false)
		darks.clear()   # D-342
		blasts.clear()
		_clear_shots()   # D-327
		powerups.clear()
		extra_balls.clear()
		blast_charge = 0.0
		state = State.LEVEL_CLEAR
		events.append(["rack_clear", level])
		return true
	return false


## D-264: a charge button held (a pad's Cross on a single screen), as both flippers.
var charge_held := false
## D-252: analog stick (0 = use the flippers).
var paddle_axis := 0.0


func _move_paddle(dt: float, left: bool, right: bool, dash: int) -> void:
	_dash_cd = maxf(0.0, _dash_cd - dt)
	if dash != 0 and _dash_cd <= 0.0:
		_dash_time = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		_dash_dir = dash
		events.append(["dash", dash])
	if _dash_time > 0.0:
		_dash_time -= dt
		paddle_vx = _dash_dir * DASH_SPEED
	else:
		var boost := LIGHTSPEED_MULT if padup == "L" else 1.0
		var dir := float(right) - float(left)
		if paddle_axis != 0.0:
			dir = clampf(paddle_axis, -1.0, 1.0)   # D-252: the stick, proportional
		var target := dir * PADDLE_MAX_SPEED * boost
		if target == 0.0:
			paddle_vx = move_toward(paddle_vx, 0.0, PADDLE_DECEL * dt)
		else:
			var rate := PADDLE_REVERSE if signf(target) != signf(paddle_vx) and paddle_vx != 0.0 else PADDLE_ACCEL
			paddle_vx = move_toward(paddle_vx, target, rate * boost * dt)
	paddle_x += paddle_vx * dt
	var limit := field.size.x * 0.5 - catch_half_w()
	if absf(paddle_x) > limit:
		paddle_x = clampf(paddle_x, -limit, limit)
		paddle_vx = 0.0
	_paddle_hist.append([_time, paddle_x])
	while _paddle_hist.size() > 2 and _time - float(_paddle_hist[1][0]) > 0.4:
		_paddle_hist.pop_front()


## Lightspeed afterimages (D-072): ship x positions GHOST_DELAYS ago, only while
## moving (each must be at least GHOST_MIN_GAP away from the ship).
func ghost_xs() -> Array:
	var out := []
	if padup != "L" or _paddle_hist.is_empty():
		return out
	for d in GHOST_DELAYS:
		var gx: float = _paddle_hist[0][1]
		for h in _paddle_hist:
			if float(h[0]) <= _time - d:
				gx = h[1]
		if absf(gx - paddle_x) >= GHOST_MIN_GAP:
			out.append(gx)
	return out


func _serve() -> void:
	state = State.PLAY
	_last_hitter = server
	var angle := deg_to_rad(randf_range(-15.0, 15.0)) + clampf(paddle_vx * 0.02, -0.25, 0.25)
	ball_vel = Vector2(sin(angle), -cos(angle)) * ball_speed
	events.append(["serve", null])


func _reset_serve() -> void:
	if two_player:
		var keep := cur
		_use(server)
		ball_pos = Vector2(paddle_x, paddle_y - PADDLE_H * 0.5 - BALL_R - 0.01)
		_use(keep)
	state = State.SERVE
	_held_time = 0.0
	ball_speed = ball_start_speed
	ball_vel = Vector2.ZERO
	ball_pos = Vector2(paddle_x, paddle_y - PADDLE_H * 0.5 - BALL_R - 0.01)


const BALL_OK := 0
const BALL_DRAINED := 1
const BALL_STOP := 2  # level cleared mid-step


func _move_ball(b: Dictionary, dt: float) -> int:
	var dist: float = (b.vel as Vector2).length() * dt
	var n := maxi(1, ceili(dist / MAX_SUBSTEP))
	var h := dt / n
	for i in n:
		var r := _ball_substep(b, h)
		if r != BALL_OK:
			return r
	return BALL_OK


## One collision substep for a ball {pos, vel, speed} (main or extra).
func _ball_substep(b: Dictionary, h: float) -> int:
	var pos: Vector2 = b.pos
	var vel: Vector2 = b.vel
	var speed: float = b.speed
	var prev_y := pos.y
	pos += vel * h
	# Walls
	if pos.x - BALL_R < field.position.x:
		pos.x = field.position.x + BALL_R
		vel.x = absf(vel.x)
		events.append(["wall", ["l", Vector2(field.position.x, pos.y)]])
	elif pos.x + BALL_R > field.end.x:
		pos.x = field.end.x - BALL_R
		vel.x = -absf(vel.x)
		events.append(["wall", ["r", Vector2(field.end.x, pos.y)]])
	if pos.y - BALL_R < field.position.y:
		pos.y = field.position.y + BALL_R
		vel.y = absf(vel.y)
		events.append(["wall", ["t", Vector2(pos.x, field.position.y)]])
	# Bricks: resolve the deepest contact only (one bounce per substep).
	var best := -1
	var best_c := {}
	for i in bricks.size():
		var br: Dictionary = bricks[i]
		if not br.alive:
			continue
		var c := BP.collide_circle_rect(pos, BALL_R, br.rect)
		if not c.is_empty() and (best == -1 or c.depth > best_c.depth):
			best = i
			best_c = c
	if best != -1:
		pos += best_c.normal * best_c.depth
		vel = BP.reflect(vel, best_c.normal)
		b.pos = pos
		b.vel = vel
		_gain_power(_last_hitter, BRICK_HIT_POWER)   # D-330
		if _damage_brick(best):
			return BALL_STOP
	# D-335: the boss: the plasma bounces off it and hurts it; it stops rays.
	if boss_hp > 0 and pos.distance_to(boss_pos) < BOSS_R + BALL_R:
		var bn := (pos - boss_pos).normalized()
		if vel.dot(bn) < 0.0:
			vel = BP.reflect(vel, bn)
		pos = boss_pos + bn * (BOSS_R + BALL_R + 0.01)
		b.pos = pos
		b.vel = vel
		if _hurt_boss(int(BOSS_HITS["ball"]), pos):
			return BALL_STOP
	# D-342: corrupted paddles: the plasma bounces off them like off a brick.
	for k in darks.size():
		var dkk: Dictionary = darks[k]
		if dkk.state != "live":
			continue
		var dc := BP.collide_circle_rect(pos, BALL_R, _dark_rect(dkk))
		if not dc.is_empty():
			pos += dc.normal * dc.depth
			vel = BP.reflect(vel, dc.normal)
			b.pos = pos
			b.vel = vel
			_hurt_dark(k, 1, (pos.x - float(dkk.pos.x)) / (PADDLE_W * 0.5), signf(pos.y - float(dkk.pos.y)))
			break
	for k in range(rays.size() - 1, -1, -1):
		if _ray_touches(rays[k], pos, BALL_R):
			events.append(["ray_blocked", rays[k].pos])
			rays.remove_at(k)
	# Enemies: the plasma destroys them and rebounds.
	for k in enemies.size():
		var en: Dictionary = enemies[k]
		if en.state == "wormhole":
			continue
		var dv: Vector2 = pos - en.pos
		if dv.length() < ENEMY_R + BALL_R:
			var nrm := dv.normalized() if dv.length_squared() > 1e-8 else Vector2.UP
			vel = BP.reflect(vel, nrm)
			pos = en.pos + nrm * (ENEMY_R + BALL_R + 0.01)
			_destroy_enemy(k)
			break
	# Ship (and Lightspeed afterimages): only bounces balls coming DOWN onto it;
	# a ball coming back up from below passes through (D-072).
	# 2P (D-285): each ship in turn (P1 first).
	var keep := cur
	for ship in (2 if two_player else 1):
		_use(ship)
		if not (vel.y > 0.0 and pos.y < paddle_y):
			continue
		var pr := catch_rect()
		if not BP.collide_circle_rect(pos, BALL_R, pr).is_empty():
			speed = minf(speed + SPEEDUP_PER_PADDLE_HIT, ball_max_speed)
			vel = BP.paddle_bounce(pos.x, paddle_x, catch_half_w(), speed, paddle_vx)
			pos.y = pr.position.y - BALL_R
			events.append(["paddle", ship])
			_last_hitter = ship
			power = minf(1.0, power + PADDLE_HIT_POWER)   # D-330 (this ship is live)
			break
		var ghosted := false
		for gx in ghost_xs():
			var gr := Rect2(gx - PADDLE_W * 0.5, pr.position.y, PADDLE_W, PADDLE_H)
			if not BP.collide_circle_rect(pos, BALL_R, gr).is_empty():
				speed = minf(speed + SPEEDUP_PER_PADDLE_HIT, ball_max_speed)
				vel = BP.paddle_bounce(pos.x, gx, PADDLE_W * 0.5, speed, 0.0)
				pos.y = gr.position.y - BALL_R
				events.append(["ghost", gx])
				ghosted = true
				break
		if ghosted:
			break
	# Shield barrier: saves one sinking ball, then breaks (either ship's, D-285).
	for ship in (2 if two_player else 1):
		_use(ship)
		if shield_active and vel.y > 0.0 and prev_y + BALL_R < SHIELD_Y and pos.y + BALL_R >= SHIELD_Y:
			pos.y = SHIELD_Y - BALL_R
			vel.y = -absf(vel.y)
			events.append(["shield_used", pos.x])
			_end_padup()  # the shield's slot empties (D-084, D-327)
			break
	_use(keep)
	vel = BP.enforce_min_vertical(vel, speed, MIN_VERTICAL)
	b.pos = pos
	b.vel = vel
	b.speed = speed
	# Drain
	if pos.y - BALL_R > DRAIN_Y:
		return BALL_DRAINED
	return BALL_OK


# --- power-ups (D-072) ------------------------------------------------------------------
## D-330: adds energy to ship i's bar (whichever ship is live).
func _gain_power(i: int, amount: float) -> void:
	if not two_player or i == cur:
		power = minf(1.0, power + amount)
	else:
		player_set(i, "power", minf(1.0, float(player_get(i, "power")) + amount))


## Spawns a falling power-up capsule (public for tests / debug).
## D-275: any power-up but the one the ship already has.
func random_powerup_kind() -> String:
	var held := [powerup, padup] if not two_player else [player_get(0, "powerup"), player_get(1, "powerup"),
		player_get(0, "padup"), player_get(1, "padup")]
	var kinds: Array = POWERUP_KINDS.filter(func(k): return not (k in held))
	# D-329: a rare instant one now and then (it doesn't break the alternation)...
	var instants: Array = kinds.filter(func(k): return k in INSTANT_KINDS)
	if not instants.is_empty() and randf() < INSTANT_CHANCE:
		return instants[randi() % instants.size()]
	# ...otherwise blaster and paddle upgrades take turns, caught or not.
	var group: Array = PADDLE_KINDS if _last_drop_group == "blaster" else BLASTER_KINDS
	var pick: Array = kinds.filter(func(k): return k in group)
	if pick.is_empty():   # (every one of the group held)
		pick = kinds.filter(func(k): return not (k in INSTANT_KINDS))
	var k: String = pick[randi() % pick.size()]
	_last_drop_group = "paddle" if k in PADDLE_KINDS else "blaster"
	return k


func spawn_powerup(kind: String, pos: Vector2) -> int:
	var id := _next_powerup_id
	_next_powerup_id += 1
	powerups.append({"id": id, "pos": pos, "kind": kind})
	events.append(["powerup_spawn", [id, pos, kind]])
	return id


func _update_powerups(dt: float) -> void:
	var keep := cur
	for i in range(powerups.size() - 1, -1, -1):
		var p: Dictionary = powerups[i]
		p.pos += Vector2(0.0, POWERUP_FALL * dt)
		var caught := -1
		for ship in (2 if two_player else 1):   # D-285: whichever ship catches it
			_use(ship)
			var hit := Rect2(p.pos.x - POWERUP_R, p.pos.y - POWERUP_R - POWERUP_REACH_UP, POWERUP_R * 2.0,
				POWERUP_R * 2.0 + POWERUP_REACH_UP)   # D-329: caught even just under the ship
			if hit.intersects(catch_rect()) and state != State.OVER:
				caught = ship
				break
		if caught >= 0:
			powerups.remove_at(i)
			power = minf(1.0, power + 1.0 / BLAST_MAX_LEVEL)  # +1 bar level (D-078)
			events.append(["powerup_collect", [p.id, p.kind, caught, p.pos]])
			if p.kind in INSTANT_KINDS:   # D-326
				_use_instant(p.kind)
				if state != State.PLAY and state != State.SERVE:
					break   # the nuke cleared the level
			else:
				apply_powerup(p.kind)
		elif p.pos.y - POWERUP_R > DRAIN_Y:
			powerups.remove_at(i)
			events.append(["powerup_lost", p.id])
	_use(keep)


## D-326: 1UP adds a charge; Nuclear destroys every destructible brick (with
## their points), which clears the level. Metal stays.
func _use_instant(kind: String) -> void:
	if kind == "U":
		balls_left += 1
		balls_total = maxi(balls_total, balls_left)
		events.append(["extra_life", balls_left])
	elif kind == "N":
		events.append(["nuke", 0])
		_nuking = true
		for i in bricks.size():
			if bricks[i].alive and not bricks[i].get("metal", false):
				bricks[i].hp = 1
				if _damage_brick(i):
					break
		_nuking = false


## Only one power-up at a time: a new one replaces the current one.
## D-327: a blaster upgrade replaces the blaster slot's, a paddle upgrade the
## paddle slot's; the other slot is kept.
func apply_powerup(kind: String) -> void:
	if kind in PADDLE_KINDS:
		_end_padup()
		padup = kind
		shield_active = kind == "S"
	else:
		_end_blaster()
		powerup = kind
		blast_charge = 0.0


## Power-ups last until the end of the level or death: both slots end.
func _end_powerup() -> void:
	_end_blaster()
	_end_padup()


func _end_blaster() -> void:
	if powerup.is_empty():
		return
	events.append(["powerup_end", powerup])
	powerup = ""


func _end_padup() -> void:
	if padup.is_empty():
		return
	events.append(["powerup_end", padup])
	padup = ""
	shield_active = false


# --- corrupted paddles (D-342) ---------------------------------------------------------
func _dark_y() -> float:
	return field.position.y + field.size.y * DARK_Y_FRAC


func _dark_rect(d: Dictionary) -> Rect2:
	return Rect2(Vector2(d.pos) - Vector2(PADDLE_W, PADDLE_H) * 0.5, Vector2(PADDLE_W, PADDLE_H))


## Whether the corrupted paddles' band (DARK_Y_FRAC down) is clear of bricks.
func dark_band_clear() -> bool:
	var band := Rect2(field.position.x, _dark_y() - PADDLE_H, field.size.x, PADDLE_H * 2.0)
	for b in bricks:
		if b.alive and band.intersects(b.rect):
			return false
	return true


func spawn_dark(x: float = NAN) -> void:
	var lim := field.size.x * 0.5 - PADDLE_W * 0.5
	if is_nan(x):
		x = randf_range(-lim, lim)
	var id := _next_enemy_id
	_next_enemy_id += 1
	darks.append({"id": id, "pos": Vector2(clampf(x, -lim, lim), _dark_y()), "vx": DARK_SPEED * (1.0 if randf() < 0.5 else -1.0),
		"hp": DARK_HP, "state": "warp", "t": 0.0})
	events.append(["dark_spawn", [id, darks[-1].pos]])


func _update_darks(dt: float) -> void:
	if state == State.PLAY and level >= DARK_FROM_LEVEL and not is_boss_level():
		_dark_timer -= dt
		if _dark_timer <= 0.0:
			_dark_timer = randf_range(DARK_INTERVAL.x, DARK_INTERVAL.y)
			if darks.is_empty() and dark_band_clear():
				spawn_dark()
	var lim := field.size.x * 0.5 - PADDLE_W * 0.5
	for d in darks:
		d.t = float(d.t) + dt
		if d.state == "warp":
			if d.t >= DARK_WARP:
				d.state = "live"
				events.append(["dark_ready", d.id])
			continue
		# D-346: it chases the plasma like a player would (the nearest ball;
		# the middle while none is in play), but slower.
		var p: Vector2 = d.pos
		var tx := 0.0
		if state == State.PLAY:
			tx = ball_pos.x
			var best := absf(ball_pos.y - p.y)
			for e in extra_balls:
				if absf(float(e.pos.y) - p.y) < best:
					best = absf(float(e.pos.y) - p.y)
					tx = e.pos.x
		var top := DARK_SPEED * enemy_speed_mult()
		var want := clampf((tx - p.x) * 4.0, -top, top)
		d.vx = move_toward(float(d.vx), want, DARK_ACCEL * dt)
		p.x += float(d.vx) * dt
		if absf(p.x) > lim:
			p.x = clampf(p.x, -lim, lim)
			d.vx = 0.0
		d.pos = p


func _dark_hit_by_rect(rect: Rect2) -> int:
	for k in darks.size():
		if darks[k].state == "live" and rect.intersects(_dark_rect(darks[k])):
			return k
	return -1


## `rel_x` -1..1 across it and `side` (+1 below, -1 above) place its shield's flash.
func _hurt_dark(k: int, n: int, rel_x: float = 0.0, side: float = 1.0) -> void:
	var d: Dictionary = darks[k]
	d.hp = int(d.hp) - n
	events.append(["dark_hit", [d.id, d.hp, clampf(rel_x, -1.0, 1.0), side if side != 0.0 else 1.0]])
	if d.hp <= 0:
		score += DARK_POINTS
		events.append(["dark_dead", [d.id, d.pos]])
		darks.remove_at(k)


# --- the boss (D-335) ------------------------------------------------------------------
func is_boss_level() -> bool:
	return level % BOSS_EVERY == 0


func _setup_boss() -> void:
	rays.clear()
	boss_charging = false
	boss_kind = "dodeca" if (level / BOSS_EVERY) % 2 == 0 else "ico"   # D-342: 10 ico, 20 dodeca, 30 ico...
	boss_max_hp = DODECA_HP if boss_kind == "dodeca" else BOSS_HP
	boss_hp = boss_max_hp if is_boss_level() else 0
	darks.clear()
	_dark_timer = DARK_FIRST
	boss_t = 0.0
	boss_pos = _boss_path(0.0)
	boss_fire_in = randf_range(BOSS_FIRE.x, BOSS_FIRE.y)
	_boss_drop_count = 0


## A slow Lissajous over the top of the field, never below BOSS_Y.y.
func _boss_path(t: float) -> Vector2:
	var span := field.size.x * 0.5 - BOSS_R - 0.45   # its drawn edge (1.35 m) clear of the walls
	var mid := (BOSS_Y.x + BOSS_Y.y) * 0.5
	var amp := (BOSS_Y.y - BOSS_Y.x) * 0.5
	return Vector2(sin(t * BOSS_SPEED) * span, mid + sin(t * BOSS_SPEED * 2.3 + 1.0) * amp)


func _update_boss(dt: float) -> void:
	# Rays fly on, through the bricks, until a ball, a ship or the edge stops them.
	for k in range(rays.size() - 1, -1, -1):
		var r: Dictionary = rays[k]
		r.pos = Vector2(r.pos) + Vector2(r.vel) * dt
		var blocked := _ray_touches(r, ball_pos, BALL_R) and state == State.PLAY
		for e in extra_balls:
			blocked = blocked or _ray_touches(r, e.pos, BALL_R)
		if blocked:
			events.append(["ray_blocked", r.pos])
			rays.remove_at(k)
			continue
		var hit_ship := -1
		for ship in (2 if two_player else 1):
			_use(ship)
			if ship_invulnerable <= 0.0 and not BP.collide_circle_rect(r.pos, float(r.get("r", RAY_R)), catch_rect()).is_empty():
				hit_ship = ship
				break
		if hit_ship >= 0:
			rays.remove_at(k)
			events.append(["ray_hit", r.pos])
			_destroy_ship()
			_use(0)
			if state == State.OVER:
				return
			continue
		_use(0)
		if not field.grow(1.0).has_point(r.pos):
			rays.remove_at(k)
	if boss_hp <= 0:
		return
	boss_t += dt * enemy_speed_mult()
	boss_pos = _boss_path(boss_t)
	if state != State.PLAY:
		return
	boss_fire_in -= dt
	if not boss_charging and boss_fire_in <= BOSS_CHARGE:
		boss_charging = true
		events.append(["boss_charge", null])
	if boss_fire_in <= 0.0:
		boss_charging = false
		boss_fire_in = randf_range(BOSS_FIRE.x, BOSS_FIRE.y)
		var dir := (_aim_point() - boss_pos).normalized()
		var start := boss_pos + dir * (BOSS_R * 0.6)
		if boss_kind == "dodeca":   # D-342: three, fanned like the Triple Laser, slower
			for a in [-TRIPLE_ANGLE, 0.0, TRIPLE_ANGLE]:
				_spawn_torpedo(start, dir.rotated(deg_to_rad(a)), {"speed": RAY_SPEED * DODECA_SHOT_SPEED, "r": RAY_R, "len": RAY_LEN})
		else:
			_spawn_torpedo(start, dir, {"speed": RAY_SPEED, "r": RAY_R, "len": RAY_LEN})
		events.append(["boss_fire", start])


## Whether a ray (its head and the length behind it) touches a circle.
func _ray_touches(r: Dictionary, c: Vector2, rad: float) -> bool:
	var head: Vector2 = r.pos
	var tail: Vector2 = head - Vector2(r.vel).normalized() * float(r.get("len", RAY_LEN))
	return Geometry2D.get_closest_point_to_segment(c, tail, head).distance_to(c) < rad + float(r.get("r", RAY_R))


## D-342: launches a torpedo from `at` along `dir` with a size/speed spec.
func _spawn_torpedo(at: Vector2, dir: Vector2, spec: Dictionary) -> void:
	var id := _next_shot_id
	_next_shot_id += 1
	rays.append({"id": id, "pos": at, "vel": dir.normalized() * float(spec.speed),
		"r": float(spec.r), "len": float(spec.len)})


## D-342: where the boss aims: the ship (2P: alternating ships).
func _aim_point() -> Vector2:
	if two_player:
		_boss_aim = 1 - _boss_aim
		return Vector2(player_get(_boss_aim, "paddle_x"), player_get(_boss_aim, "paddle_y"))
	return Vector2(paddle_x, paddle_y)


## Damages the boss; true if that cleared the level (its bricks were already gone).
func _hurt_boss(n: int, at: Vector2 = Vector2.INF) -> bool:
	if boss_hp <= 0:
		return false
	boss_hp = maxi(0, boss_hp - n)
	events.append(["boss_hit", [boss_hp, at if at != Vector2.INF else boss_pos + Vector2(0.0, BOSS_R)]])
	if boss_hp > 0:
		# D-339: hurting it shakes capsules loose, like breaking bricks.
		_boss_drop_count += n
		if _boss_drop_count >= BOSS_DROP_EVERY:
			_boss_drop_count = 0
			_since_drop = 0
			spawn_powerup(random_powerup_kind(), boss_pos + Vector2(0.0, BOSS_R * 0.8))
		return false
	score += BOSS_POINTS
	rays.clear()
	boss_charging = false
	events.append(["boss_dead", boss_pos])
	if bricks_alive() == 0:
		score += RACK_BONUS
		while not enemies.is_empty():
			_destroy_enemy(0, false)
		darks.clear()   # D-342
		blasts.clear()
		_clear_shots()
		powerups.clear()
		extra_balls.clear()
		blast_charge = 0.0
		state = State.LEVEL_CLEAR
		events.append(["rack_clear", level])
		return true
	return false


# --- wave beam and homing missiles (D-327) --------------------------------------------
func _clear_shots() -> void:
	waves.clear()
	missiles.clear()


func _brick_w() -> float:
	return field.size.x / float(cols)


## Moves the wave shots and missiles; once per step (both ships' shots).
func _update_shots(dt: float) -> void:
	for i in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		var travel := WAVE_SPEED * dt
		var n := maxi(1, ceili(travel / MAX_SUBSTEP))
		for k in n:
			w.t = float(w.t) + dt / n
			var p := Vector2(clampf(float(w.x0) + sin(float(w.t) * WAVE_RATE) * WAVE_AMP,
				field.position.x + 0.2, field.end.x - 0.2), w.pos.y - travel / n)
			w.pos = p
			var rect := Rect2(p - WAVE_SIZE * 0.5, WAVE_SIZE)
			if boss_hp > 0 and not w.hit.has("boss") and not BP.collide_circle_rect(boss_pos, BOSS_R, rect).is_empty():
				w.hit["boss"] = true   # D-335
				if _hurt_boss(int(BOSS_HITS["wave"]), p):
					return
			for k2 in darks.size():   # D-342
				if darks[k2].state == "live" and not w.hit.has("dark%d" % darks[k2].id) and rect.intersects(_dark_rect(darks[k2])):
					w.hit["dark%d" % darks[k2].id] = true
					_hurt_dark(k2, 2)
					break
			var foe := _enemy_hit_by_rect(rect)
			while foe != -1:
				_destroy_enemy(foe)
				foe = _enemy_hit_by_rect(rect)
			for j in bricks.size():
				if bricks[j].alive and not w.hit.has(j) and rect.intersects(bricks[j].rect):
					w.hit[j] = true
					if _damage_brick(j):
						return   # new rack: shots were cleared
		if w.pos.y < field.position.y:
			waves.remove_at(i)
	for i in range(missiles.size() - 1, -1, -1):
		var m: Dictionary = missiles[i]
		var tp = _target_pos(m.target)
		if tp == null:
			m.target = _missile_target(m.pos)
			tp = _target_pos(m.target)
		var vel: Vector2 = m.vel
		if tp != null:
			var want: float = (tp - Vector2(m.pos)).angle()
			var ang := vel.angle()
			ang += clampf(wrapf(want - ang, -PI, PI), -MISSILE_TURN * dt, MISSILE_TURN * dt)
			vel = Vector2.from_angle(ang) * MISSILE_SPEED
		m.vel = vel
		var p: Vector2 = m.pos + vel * dt
		m.pos = p
		var boom := not field.grow(0.5).has_point(p) or (tp != null and p.distance_to(tp) < 0.35) \
			or _enemy_hit_by_rect(Rect2(p - Vector2.ONE * MISSILE_R, Vector2.ONE * MISSILE_R * 2.0)) != -1 \
			or (boss_hp > 0 and p.distance_to(boss_pos) < BOSS_R + MISSILE_R)
		if not boom:
			for b in bricks:
				if b.alive and not BP.collide_circle_rect(p, MISSILE_R, b.rect).is_empty():
					boom = true
					break
		if boom:
			missiles.remove_at(i)
			if _missile_blast(p):
				return


## The nearest live enemy or destructible brick to `from` (null target: none).
func _missile_target(from: Vector2) -> Array:
	var best := []
	var best_d := INF
	if boss_hp > 0:   # D-335: the boss first, if it's nearest
		best = ["boss", 0]
		best_d = from.distance_to(boss_pos) - BOSS_R
	for en in enemies:
		if en.state != "wormhole" and from.distance_to(en.pos) < best_d:
			best_d = from.distance_to(en.pos)
			best = ["enemy", en.id]
	for j in bricks.size():
		var b: Dictionary = bricks[j]
		if b.alive and not b.get("metal", false) and from.distance_to(b.rect.get_center()) < best_d:
			best_d = from.distance_to(b.rect.get_center())
			best = ["brick", j]
	return best


func _target_pos(t: Array) -> Variant:
	if t.is_empty():
		return null
	if t[0] == "boss":
		return boss_pos if boss_hp > 0 else null
	if t[0] == "enemy":
		for en in enemies:
			if en.id == t[1] and en.state != "wormhole":
				return en.pos
		return null
	var b: Dictionary = bricks[int(t[1])]
	return b.rect.get_center() if b.alive else null


## The missile's blast: everything in a 3x3-brick area takes MISSILE_HITS hits.
## True if it cleared the level.
func _missile_blast(p: Vector2) -> bool:
	var size := Vector2(MISSILE_AREA.x * _brick_w(), MISSILE_AREA.y * BRICK_H)
	var area := Rect2(p - size * 0.5, size)
	events.append(["missile_blast", [p, size]])
	if boss_hp > 0 and not BP.collide_circle_rect(boss_pos, BOSS_R, area).is_empty():
		if _hurt_boss(int(BOSS_HITS["missile"]), p):   # D-335
			return true
	for k2 in range(darks.size() - 1, -1, -1):   # D-342
		if darks[k2].state == "live" and area.intersects(_dark_rect(darks[k2])):
			_hurt_dark(k2, 2)
	for k in range(enemies.size() - 1, -1, -1):
		if enemies[k].state != "wormhole" and not BP.collide_circle_rect(enemies[k].pos, ENEMY_R, area).is_empty():
			_destroy_enemy(k)
	for j in bricks.size():
		if not area.intersects(bricks[j].rect):
			continue
		for h in MISSILE_HITS:
			if bricks[j].alive and _damage_brick(j):
				return true
	return false


# --- enemies (D-052) ------------------------------------------------------------------
## D-322: true while an enemy (out of its wormhole) is in the bottom
## DANGER_FRAC of the field. `margin` lowers the line (hysteresis: the alert
## stays on while an orbit's top dips just above it).
const DANGER_FRAC := 0.2
func enemy_in_danger(margin: float = 0.0) -> bool:
	var line := field.end.y - field.size.y * DANGER_FRAC - margin
	for en in enemies:
		if en.state != "wormhole" and float(en.pos.y) >= line:
			return true
	return false


## D-323: the cube, a more aggressive enemy: CUBE_CHANCE of the spawns from
## level CUBE_FROM_LEVEL on (D-324).
const CUBE_CHANCE := 0.35
const CUBE_FROM_LEVEL := 3
const CUBE_DESCENT := 1.3            # x the tetra's descent
const CUBE_SWEEP_PULL := 0.9         # units/s its sweep's centre drifts towards the ship
const CUBE_ORBIT_PULL := 1.1         # units/s its orbit's centre follows the ship (+ tier steering)
## D-323: unstuck. An enemy that hasn't got any lower for STUCK_TIME starts
## circling: it heads up (12 o'clock) and round, over the bricks that stop it,
## and goes back to its sweep once it is lower than it had ever been.
const STUCK_TIME := 10.0
const STUCK_GAIN := 0.05             # m lower that counts as progress
const CIRCLE_R := 1.0                # m, the loop's radius (it turns at CIRCLE_SPEED / CIRCLE_R)
const CIRCLE_SPEED := 2.2            # m/s along the loop
const CIRCLE_GIVE_UP := 8.0          # s each way round before going back to the sweep


## Spawns an enemy through a wormhole at x (random if NAN); kind "tetra" or
## "cube" ("" = random, D-323). Public for tests.
func spawn_enemy(x: float = NAN, kind: String = "") -> int:
	var lim := field.size.x * 0.5 - ENEMY_R - 0.2
	if is_nan(x):
		x = randf_range(-lim, lim)
	if kind.is_empty():
		var roll := randf()
		if level >= ICO_FROM_LEVEL and roll < ICO_CHANCE:   # D-342
			kind = "ico"
		elif level >= CUBE_FROM_LEVEL and roll < ICO_CHANCE + CUBE_CHANCE:
			kind = "cube"
		else:
			kind = "tetra"
	var id := _next_enemy_id
	_next_enemy_id += 1
	var pos := Vector2(clampf(x, -lim, lim), ENEMY_SPAWN_Y)
	enemies.append({"id": id, "kind": kind, "pos": pos, "state": "wormhole", "t": 0.0,
		"phase": asin(clampf(pos.x / ENEMY_SWEEP_AMP, -1.0, 1.0)), "sweep_x": 0.0,
		"dir": 1.0 if randf() < 0.5 else -1.0, "center": Vector2.ZERO, "angle": 0.0,
		"best_y": pos.y, "stuck_t": 0.0, "loop": 0.0, "tries": 0,
		"fire_in": randf_range(MINI_FIRE.x, MINI_FIRE.y), "charging": false})
	events.append(["enemy_spawn", [id, pos, kind]])
	return id


## The x an aggressive enemy heads for: the nearest ship (either, in 2P).
func _ship_x_near(x: float) -> float:
	if not two_player:
		return paddle_x
	var a: float = player_get(0, "paddle_x")
	var b: float = player_get(1, "paddle_x")
	return a if absf(a - x) <= absf(b - x) else b


## D-323: unstuck circling. The enemy starts heading straight up (12 o'clock)
## and keeps turning (a loop of radius CIRCLE_R), towards the nearer gap in the
## bricks below. When its way is blocked it turns back towards up, so it hugs
## the bricks and goes over them; once it is lower than it had ever been, it
## goes back to its sweep. CIRCLE_GIVE_UP seconds each way round, then the sweep.
func _start_circle(en: Dictionary, lim: float) -> void:
	en.state = "circle"
	en.angle = 0.0   # heading as a clock angle: 0 = up, PI/2 = right
	en.loop = 0.0    # seconds this way round
	en.tries = 0
	en.dir = _gap_side(en.pos, lim)
	events.append(["enemy_unstuck", en.id])


## +1 if the nearest x with a clear way down is to the right, -1 if left.
func _gap_side(p: Vector2, lim: float) -> float:
	var dx := 0.3
	while dx < field.size.x:
		for side in ([1.0, -1.0] if p.x <= 0.0 else [-1.0, 1.0]):
			var x: float = p.x + side * dx
			if absf(x) <= lim and not _enemy_blocked(Vector2(x, p.y + 0.6)) 					and not _enemy_blocked(Vector2(x, p.y + 1.2)):
				return side
		dx += 0.3
	return 1.0 if p.x <= 0.0 else -1.0


func _circle_free(p: Vector2, lim: float) -> bool:
	return not _enemy_blocked(p) and absf(p.x) <= lim and p.y >= field.position.y + ENEMY_R


func _step_circle(en: Dictionary, dt: float, lim: float) -> void:
	var p: Vector2 = en.pos
	var v := CIRCLE_SPEED * enemy_speed_mult()
	var dir: float = en.dir
	var h: float = float(en.angle) + dir * v / CIRCLE_R * dt
	var moved := false
	for k in 8:   # blocked: turn back towards up, a bit at a time
		var next := p + Vector2(sin(h), -cos(h)) * v * dt
		if _circle_free(next, lim):
			p = next
			moved = true
			break
		h -= dir * 0.4
	en.angle = wrapf(h, -PI, PI)
	en.pos = p
	en.loop = float(en.loop) + dt
	if p.y > float(en.best_y) + STUCK_GAIN * 4.0:   # got lower: back to the sweep
		en.state = "sweep"
		en.best_y = p.y
		en.stuck_t = 0.0
		en.sweep_x = p.x - sin(float(en.phase)) * ENEMY_SWEEP_AMP   # the sweep carries on from here
		en.dir = 1.0 if randf() < 0.5 else -1.0
	elif en.loop >= CIRCLE_GIVE_UP or not moved:
		if int(en.tries) == 0:   # the other way round
			en.tries = 1
			en.loop = 0.0
			en.angle = 0.0
			en.dir = -dir
		else:   # back to the sweep, to try again later
			en.state = "sweep"
			en.stuck_t = 0.0
			en.sweep_x = p.x - sin(float(en.phase)) * ENEMY_SWEEP_AMP


func _update_enemies(dt: float) -> void:
	for ship in (2 if two_player else 1):
		_use(ship)
		ship_invulnerable = maxf(0.0, ship_invulnerable - dt)
	_use(0)
	_update_darks(dt)   # D-342
	if state == State.PLAY:   # D-342: mini-icosahedrons charge and fire
		for en in enemies:
			if en.get("kind", "") != "ico" or en.state == "wormhole":
				continue
			en.fire_in = float(en.fire_in) - dt
			if not en.charging and en.fire_in <= MINI_CHARGE:
				en.charging = true
				events.append(["mini_charge", en.id])
			if en.fire_in <= 0.0:
				en.charging = false
				en.fire_in = randf_range(MINI_FIRE.x, MINI_FIRE.y)
				var dir: Vector2 = (_aim_point() - Vector2(en.pos)).normalized()
				_spawn_torpedo(Vector2(en.pos) + dir * ENEMY_R, dir, TORP_MINI)
				events.append(["mini_fire", [en.id, en.pos]])
	if state == State.PLAY:
		_enemy_timer -= dt
		if _enemy_timer <= 0.0:
			_enemy_timer = randf_range(ENEMY_INTERVAL.x, ENEMY_INTERVAL.y) / (1.0 + ENEMY_TIER_RATE * enemy_tier())
			if enemies.size() < ENEMY_MAX + enemy_tier():
				spawn_enemy()
	var lim := field.size.x * 0.5 - ENEMY_R
	for i in range(enemies.size() - 1, -1, -1):
		var en: Dictionary = enemies[i]
		en.t += dt
		match en.state:
			"wormhole":
				if en.t >= WORMHOLE_TIME:
					en.state = "sweep"
					events.append(["enemy_ready", en.id])
				continue
			"circle":   # D-323: going round the bricks it was stuck on
				_step_circle(en, dt, lim)
			"sweep":
				var pos: Vector2 = en.pos
				var cube: bool = en.get("kind", "tetra") == "cube"
				# Wide horizontal sine sweep; reverse when bricks block the way.
				# A cube's sweep drifts towards the nearest ship (D-323).
				var spd := enemy_speed_mult()
				if cube:
					var want := clampf(_ship_x_near(pos.x), -lim, lim)
					en.sweep_x = move_toward(float(en.sweep_x), want, CUBE_SWEEP_PULL * spd * dt)
				var ph: float = en.phase + ENEMY_SWEEP_SPEED * spd * en.dir * dt
				var nx := clampf(float(en.sweep_x) + sin(ph) * ENEMY_SWEEP_AMP, -lim, lim)
				if _enemy_blocked(Vector2(nx, pos.y)):
					en.dir = -en.dir
				else:
					en.phase = ph
					pos.x = nx
				# Descend only where the way down is clear of bricks.
				var ny := pos.y + ENEMY_DESCENT * spd * (CUBE_DESCENT if cube else 1.0) * dt
				if en.get("kind", "") == "ico":   # D-347: it stays up top
					ny = minf(ny, field.position.y + field.size.y * ICO_TOP_FRAC - ENEMY_R)
				if not _enemy_blocked(Vector2(pos.x, ny)):
					pos.y = ny
				en.pos = pos
				# D-323: no lower for STUCK_TIME: circle round the bricks.
				if pos.y > float(en.best_y) + STUCK_GAIN:
					en.best_y = pos.y
					en.stuck_t = 0.0
				else:
					en.stuck_t = float(en.stuck_t) + dt
					if en.stuck_t >= STUCK_TIME and en.get("kind", "") != "ico":   # D-347: icos stay up top
						_start_circle(en, lim)
				if pos.y >= ENEMY_ORBIT_START_Y:
					en.state = "orbit"
					en.center = Vector2(clampf(pos.x, -lim + ENEMY_ORBIT_R.x, lim - ENEMY_ORBIT_R.x),
						pos.y + ENEMY_ORBIT_R.y)
					en.angle = asin(clampf((pos.x - en.center.x) / ENEMY_ORBIT_R.x, -1.0, 1.0))
					en.dir = 1.0 if pos.x <= en.center.x else -1.0
			"orbit":
				# Wide circles around the bottom (may or may not cross the ship).
				en.angle += ENEMY_ORBIT_SPEED * enemy_speed_mult() * en.dir * dt
				# More aggressive tiers steer their orbit towards the ship (D-073);
				# a cube always does, harder (D-323).
				var pull := 0.8 * enemy_tier() + (CUBE_ORBIT_PULL if en.get("kind", "tetra") == "cube" else 0.0)
				if pull > 0.0:
					var c: Vector2 = en.center
					var lim2 := lim - ENEMY_ORBIT_R.x
					c.x = move_toward(c.x, clampf(_ship_x_near(c.x), -lim2, lim2), pull * dt)
					en.center = c
				var target: Vector2 = en.center + Vector2(sin(en.angle) * ENEMY_ORBIT_R.x, -cos(en.angle) * ENEMY_ORBIT_R.y)
				en.pos = en.pos.lerp(target, 1.0 - exp(-6.0 * dt))
		# Ship collision: the ship is destroyed and the enemy self-destructs.
		var hit_ship := false
		for ship in (2 if two_player else 1):
			_use(ship)
			if en.state != "wormhole" and ship_invulnerable <= 0.0 \
					and not BP.collide_circle_rect(en.pos, ENEMY_R * 0.85, paddle_rect()).is_empty():
				_destroy_enemy(i, false)
				_destroy_ship()
				hit_ship = true
				break
		_use(0)
		if hit_ship and state == State.OVER:
			return


func _enemy_blocked(pos: Vector2) -> bool:
	for b in bricks:
		if b.alive and not BP.collide_circle_rect(pos, ENEMY_R, b.rect).is_empty():
			return true
	return false


func _enemy_hit_by_rect(rect: Rect2) -> int:
	for k in enemies.size():
		var en: Dictionary = enemies[k]
		if en.state != "wormhole" and not BP.collide_circle_rect(en.pos, ENEMY_R, rect).is_empty():
			return k
	return -1


func _destroy_enemy(i: int, award: bool = true) -> void:
	var en: Dictionary = enemies[i]
	enemies.remove_at(i)
	if award:
		score += ENEMY_POINTS
	events.append(["enemy_destroyed", [en.id, en.pos, award]])  # award = shot down


func _destroy_ship() -> void:
	events.append(["ship_destroyed", Vector2(paddle_x, paddle_y)])
	_end_powerup()
	extra_balls.clear()
	blasts.clear()
	_clear_shots()   # D-327
	blast_charge = 0.0
	ship_invulnerable = SHIP_INVULNERABLE
	balls_left -= 1
	if balls_left <= 0:
		state = State.OVER
		events.append(["over", score])
	else:
		power = 1.0  # a new life starts with a full power bar (D-102)
		_reset_serve()
		serve_lock = SERVE_LOCK   # D-344: no instant relaunch after a lost charge


func _lose_ball() -> void:
	if two_player:   # D-285: a shared life: both ships start over; the serve alternates
		for ship in 2:
			_use(ship)
			_end_powerup()
			power = 1.0
		_use(0)
		server = 1 - server
	else:
		_end_powerup()
	balls_left -= 1
	events.append(["lost", ball_pos.x])
	if balls_left <= 0:
		state = State.OVER
		events.append(["over", score])
	else:
		power = 1.0  # a new life starts with a full power bar (D-102)
		_reset_serve()
		serve_lock = SERVE_LOCK   # D-344: no instant relaunch after a lost charge
