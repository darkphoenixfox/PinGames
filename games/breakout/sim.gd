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
]
const COLOUR_POINTS := {"R": 120, "Y": 100, "G": 80, "B": 60}
## Brick letters (D-073): UPPERCASE = 1 hit, lowercase = 2-hit armoured
## (1.5x points), X = indestructible metal (doesn't count for clearing).
const ARMOURED_MULT := 1.5
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
const POWERUP_EVERY := 10            # every 10th brick destroyed...
const POWERUP_CHANCE := 0.7          # ...has a 70% chance to drop one
const POWERUP_FALL := 2.2
const POWERUP_R := 0.28
const POWERUP_KINDS := ["T", "P", "B", "I", "L", "S"]
const TRIPLE_ANGLE := 20.0           # T: side bolts at +-20 degrees (D-078)
const POWER_CHARGE_MULT := 3.0       # P: charges 3x faster (one phase)
const ION_BEAM_W := 0.7              # I: width of the beam
const LIGHTSPEED_MULT := 1.3         # L: ship speed (assumption, D-072)
const GHOST_DELAYS := [0.09, 0.18]   # L: afterimages trail by these delays
const GHOST_MIN_GAP := 0.3           # afterimages only exist while moving
const SHIELD_Y := PADDLE_Y + 0.85    # S: barrier line (above the horizon)

enum State { SERVE, PLAY, LEVEL_CLEAR, OVER }

var state := State.SERVE
var score := 0
var balls_left := 3
var level := 1

var paddle_x := 0.0
var paddle_vx := 0.0
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
var powerup := ""
var powerups: Array = []
var shield_active := false
var _next_powerup_id := 1
var _broken_count := 0
var _time := 0.0
var _paddle_hist: Array = []  # [time, x], newest last
var _held_time := 0.0
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


func setup(balls: int) -> void:
	balls_left = maxi(1, balls)
	score = 0
	level = 1
	build_rack()
	_reset_serve()


## Builds the bricks of the current level from its text file.
func build_rack() -> void:
	bricks.clear()
	var layout := level_layout(level)
	var w := FIELD.size.x / BRICK_COLS
	for row in mini(layout.size(), BRICK_ROWS):
		var line: String = layout[row]
		for col in mini(line.length(), BRICK_COLS):
			var raw := line[col]
			var ch := raw.to_upper()
			var metal := ch == "X"
			if not metal and not COLOUR_POINTS.has(ch):
				continue
			var armoured := not metal and raw != ch  # lowercase
			var rect := Rect2(FIELD.position.x + col * w + BRICK_GAP * 0.5,
				BRICK_TOP + row * BRICK_H + BRICK_GAP * 0.5, w - BRICK_GAP, BRICK_H - BRICK_GAP)
			var pts := 0 if metal else int(COLOUR_POINTS[ch] * (ARMOURED_MULT if armoured else 1.0))
			bricks.append({"rect": rect, "hp": -1 if metal else (2 if armoured else 1), "alive": true,
				"row": row, "col": col, "colour": ch, "points": pts,
				"metal": metal, "armoured": armoured})


## Rows of level n (1-based; loops over LEVEL_FILES). Comment lines start with #.
static func level_layout(n: int) -> Array:
	var path: String = LEVEL_FILES[(n - 1) % LEVEL_FILES.size()]
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
	blast_charge = 0.0
	_enemy_timer = ENEMY_FIRST_SPAWN / (1.0 + ENEMY_TIER_RATE * enemy_tier())
	power = 1.0  # full power bar at the start of each level (D-076)
	powerups.clear()
	_end_powerup()
	extra_balls.clear()
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
	return Rect2(paddle_x - PADDLE_W * 0.5, PADDLE_Y - PADDLE_H * 0.5, PADDLE_W, PADDLE_H)


## Advances the simulation. left/right: flipper buttons held. launch: pressed this
## frame. dash: -1/+1 if a magna save was pressed this frame, else 0.
func step(dt: float, left: bool, right: bool, launch: bool, dash: int) -> void:
	events.clear()
	if state == State.OVER or state == State.LEVEL_CLEAR:
		return
	_time += dt
	_update_power_and_blast(dt, left and right)
	_move_paddle(dt, left, right, dash)
	_update_enemies(dt)
	if state == State.OVER:
		return
	_update_powerups(dt)  # capsules keep falling while waiting to fire
	if state == State.SERVE:
		ball_pos = Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BALL_R - 0.01)
		_held_time += dt
		if launch or _held_time >= AUTO_SERVE_SECONDS:
			_serve()
		return
	if state != State.PLAY or freeze_ball:
		return
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
	match powerup:
		"L", "S":
			return 0
		"B":
			return 1 if power >= 1.0 - 0.0001 else 0
		"I":
			return BLAST_MAX_LEVEL if power >= 1.0 - 0.0001 else 0
	return clampi(int(floor(power / BLAST_COST + 0.0001)), 0, BLAST_MAX_LEVEL)


## The highest level the current mode can reach (Bounce = 1, otherwise 3).
func max_level() -> int:
	return 1 if powerup == "B" else BLAST_MAX_LEVEL


## Whether the current power-up allows charging at all.
func blasts_enabled() -> bool:
	return powerup != "L" and powerup != "S"


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
			# Power laser charges straight to level 3: only its effects (D-076).
			events.append(["charge_start", BLAST_MAX_LEVEL if powerup == "P" else 1])
		var before := blast_charge
		var rate := POWER_CHARGE_MULT if powerup == "P" else 1.0
		blast_charge = minf(blast_charge + rate * dt / BLAST_CHARGE_TIME, float(cap))
		var reached := int(floor(blast_charge + 0.0001))
		if reached > int(floor(before + 0.0001)) and (powerup != "P" or reached >= max_level()):
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
		if can_charge and lvl >= (BLAST_MAX_LEVEL if powerup == "I" else 1):
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
	return pos.y - BLAST_H * 0.5 < FIELD.position.y or pos.x < FIELD.position.x or pos.x > FIELD.end.x


## Fires the charged shot at level `lvl`, shaped by the current power-up (D-072).
func _fire(lvl: int) -> void:
	_since_blast = 0.0
	var start := Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BLAST_H * 0.5)
	match powerup:
		"I":  # Ion cannon: instant beam that fries the whole column
			power = 0.0
			events.append(["ion_beam", paddle_x])
			_ion_beam(paddle_x)
		"B":  # Bounce plasma: an extra plasma ball
			power = 0.0
			var nose := Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BALL_R - 0.05)
			var ang := deg_to_rad(randf_range(-12.0, 12.0))
			extra_balls.append({"pos": nose, "vel": Vector2(sin(ang), -cos(ang)) * BALL_START_SPEED,
				"speed": BALL_START_SPEED})
			events.append(["bounce_ball", nose])
		_:
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
	var beam := Rect2(x - ION_BEAM_W * 0.5, FIELD.position.y, ION_BEAM_W, PADDLE_Y - FIELD.position.y)
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
	var start := Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BLAST_H * 0.5)
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
	if b.hp > 0:
		events.append(["brick_hit", i])
		return false
	b.alive = false
	score += b.points
	events.append(["brick", i])
	_broken_count += 1
	if _broken_count % POWERUP_EVERY == 0 and randf() < POWERUP_CHANCE and bricks_alive() > 0:
		spawn_powerup(POWERUP_KINDS[randi() % POWERUP_KINDS.size()], b.rect.get_center())
	if bricks_alive() == 0:
		score += RACK_BONUS
		# Level complete (D-068): every enemy left explodes; play pauses until
		# the game runs its outro and calls next_level().
		while not enemies.is_empty():
			_destroy_enemy(0, false)
		blasts.clear()
		powerups.clear()
		extra_balls.clear()
		blast_charge = 0.0
		state = State.LEVEL_CLEAR
		events.append(["rack_clear", level])
		return true
	return false


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
		var boost := LIGHTSPEED_MULT if powerup == "L" else 1.0
		var target := (float(right) - float(left)) * PADDLE_MAX_SPEED * boost
		if target == 0.0:
			paddle_vx = move_toward(paddle_vx, 0.0, PADDLE_DECEL * dt)
		else:
			var rate := PADDLE_REVERSE if signf(target) != signf(paddle_vx) and paddle_vx != 0.0 else PADDLE_ACCEL
			paddle_vx = move_toward(paddle_vx, target, rate * boost * dt)
	paddle_x += paddle_vx * dt
	var limit := FIELD.size.x * 0.5 - PADDLE_W * 0.5
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
	if powerup != "L" or _paddle_hist.is_empty():
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
	var angle := deg_to_rad(randf_range(-15.0, 15.0)) + clampf(paddle_vx * 0.02, -0.25, 0.25)
	ball_vel = Vector2(sin(angle), -cos(angle)) * ball_speed
	events.append(["serve", null])


func _reset_serve() -> void:
	state = State.SERVE
	_held_time = 0.0
	ball_speed = BALL_START_SPEED
	ball_vel = Vector2.ZERO
	ball_pos = Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BALL_R - 0.01)


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
	if pos.x - BALL_R < FIELD.position.x:
		pos.x = FIELD.position.x + BALL_R
		vel.x = absf(vel.x)
		events.append(["wall", ["l", Vector2(FIELD.position.x, pos.y)]])
	elif pos.x + BALL_R > FIELD.end.x:
		pos.x = FIELD.end.x - BALL_R
		vel.x = -absf(vel.x)
		events.append(["wall", ["r", Vector2(FIELD.end.x, pos.y)]])
	if pos.y - BALL_R < FIELD.position.y:
		pos.y = FIELD.position.y + BALL_R
		vel.y = absf(vel.y)
		events.append(["wall", ["t", Vector2(pos.x, FIELD.position.y)]])
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
		if _damage_brick(best):
			return BALL_STOP
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
	if vel.y > 0.0 and pos.y < PADDLE_Y:
		var pr := paddle_rect()
		if not BP.collide_circle_rect(pos, BALL_R, pr).is_empty():
			speed = minf(speed + SPEEDUP_PER_PADDLE_HIT, BALL_MAX_SPEED)
			vel = BP.paddle_bounce(pos.x, paddle_x, PADDLE_W * 0.5, speed, paddle_vx)
			pos.y = pr.position.y - BALL_R
			events.append(["paddle", null])
		else:
			for gx in ghost_xs():
				var gr := Rect2(gx - PADDLE_W * 0.5, pr.position.y, PADDLE_W, PADDLE_H)
				if not BP.collide_circle_rect(pos, BALL_R, gr).is_empty():
					speed = minf(speed + SPEEDUP_PER_PADDLE_HIT, BALL_MAX_SPEED)
					vel = BP.paddle_bounce(pos.x, gx, PADDLE_W * 0.5, speed, 0.0)
					pos.y = gr.position.y - BALL_R
					events.append(["ghost", gx])
					break
	# Shield barrier: saves one sinking ball, then breaks.
	if shield_active and vel.y > 0.0 and prev_y + BALL_R < SHIELD_Y and pos.y + BALL_R >= SHIELD_Y:
		pos.y = SHIELD_Y - BALL_R
		vel.y = -absf(vel.y)
		shield_active = false
		events.append(["shield_used", pos.x])
	vel = BP.enforce_min_vertical(vel, speed, MIN_VERTICAL)
	b.pos = pos
	b.vel = vel
	b.speed = speed
	# Drain
	if pos.y - BALL_R > DRAIN_Y:
		return BALL_DRAINED
	return BALL_OK


# --- power-ups (D-072) ------------------------------------------------------------------
## Spawns a falling power-up capsule (public for tests / debug).
func spawn_powerup(kind: String, pos: Vector2) -> int:
	var id := _next_powerup_id
	_next_powerup_id += 1
	powerups.append({"id": id, "pos": pos, "kind": kind})
	events.append(["powerup_spawn", [id, pos, kind]])
	return id


func _update_powerups(dt: float) -> void:
	var pr := paddle_rect()
	for i in range(powerups.size() - 1, -1, -1):
		var p: Dictionary = powerups[i]
		p.pos += Vector2(0.0, POWERUP_FALL * dt)
		if not BP.collide_circle_rect(p.pos, POWERUP_R, pr).is_empty() and state != State.OVER:
			powerups.remove_at(i)
			apply_powerup(p.kind)
			power = minf(1.0, power + 1.0 / BLAST_MAX_LEVEL)  # +1 bar level (D-078)
			events.append(["powerup_collect", [p.id, p.kind]])
		elif p.pos.y - POWERUP_R > DRAIN_Y:
			powerups.remove_at(i)
			events.append(["powerup_lost", p.id])


## Only one power-up at a time: a new one replaces the current one.
func apply_powerup(kind: String) -> void:
	if not powerup.is_empty():
		_end_powerup()
	powerup = kind
	shield_active = kind == "S"
	if not blasts_enabled():
		blast_charge = 0.0


## Power-ups last until the end of the level or death.
func _end_powerup() -> void:
	if powerup.is_empty():
		return
	events.append(["powerup_end", powerup])
	powerup = ""
	shield_active = false


# --- enemies (D-052) ------------------------------------------------------------------
## Spawns a tetrahedron through a wormhole at x (random if NAN). Public for tests.
func spawn_enemy(x: float = NAN) -> int:
	var lim := FIELD.size.x * 0.5 - ENEMY_R - 0.2
	if is_nan(x):
		x = randf_range(-lim, lim)
	var id := _next_enemy_id
	_next_enemy_id += 1
	var pos := Vector2(clampf(x, -lim, lim), ENEMY_SPAWN_Y)
	enemies.append({"id": id, "pos": pos, "state": "wormhole", "t": 0.0,
		"phase": asin(clampf(pos.x / ENEMY_SWEEP_AMP, -1.0, 1.0)),
		"dir": 1.0 if randf() < 0.5 else -1.0, "center": Vector2.ZERO, "angle": 0.0})
	events.append(["enemy_spawn", [id, pos]])
	return id


func _update_enemies(dt: float) -> void:
	ship_invulnerable = maxf(0.0, ship_invulnerable - dt)
	if state == State.PLAY:
		_enemy_timer -= dt
		if _enemy_timer <= 0.0:
			_enemy_timer = randf_range(ENEMY_INTERVAL.x, ENEMY_INTERVAL.y) / (1.0 + ENEMY_TIER_RATE * enemy_tier())
			if enemies.size() < ENEMY_MAX + enemy_tier():
				spawn_enemy()
	var lim := FIELD.size.x * 0.5 - ENEMY_R
	for i in range(enemies.size() - 1, -1, -1):
		var en: Dictionary = enemies[i]
		en.t += dt
		match en.state:
			"wormhole":
				if en.t >= WORMHOLE_TIME:
					en.state = "sweep"
					events.append(["enemy_ready", en.id])
				continue
			"sweep":
				var pos: Vector2 = en.pos
				# Wide horizontal sine sweep; reverse when bricks block the way.
				var spd := enemy_speed_mult()
				var ph: float = en.phase + ENEMY_SWEEP_SPEED * spd * en.dir * dt
				var nx := clampf(sin(ph) * ENEMY_SWEEP_AMP, -lim, lim)
				if _enemy_blocked(Vector2(nx, pos.y)):
					en.dir = -en.dir
				else:
					en.phase = ph
					pos.x = nx
				# Descend only where the way down is clear of bricks.
				var ny := pos.y + ENEMY_DESCENT * spd * dt
				if not _enemy_blocked(Vector2(pos.x, ny)):
					pos.y = ny
				en.pos = pos
				if pos.y >= ENEMY_ORBIT_START_Y:
					en.state = "orbit"
					en.center = Vector2(clampf(pos.x, -lim + ENEMY_ORBIT_R.x, lim - ENEMY_ORBIT_R.x),
						pos.y + ENEMY_ORBIT_R.y)
					en.angle = asin(clampf((pos.x - en.center.x) / ENEMY_ORBIT_R.x, -1.0, 1.0))
					en.dir = 1.0 if pos.x <= en.center.x else -1.0
			"orbit":
				# Wide circles around the bottom (may or may not cross the ship).
				en.angle += ENEMY_ORBIT_SPEED * enemy_speed_mult() * en.dir * dt
				# More aggressive tiers steer their orbit towards the ship (D-073).
				if enemy_tier() >= 1:
					var c: Vector2 = en.center
					var lim2 := lim - ENEMY_ORBIT_R.x
					c.x = move_toward(c.x, clampf(paddle_x, -lim2, lim2), 0.8 * enemy_tier() * dt)
					en.center = c
				var target: Vector2 = en.center + Vector2(sin(en.angle) * ENEMY_ORBIT_R.x, -cos(en.angle) * ENEMY_ORBIT_R.y)
				en.pos = en.pos.lerp(target, 1.0 - exp(-6.0 * dt))
		# Ship collision: the ship is destroyed and the enemy self-destructs.
		if en.state != "wormhole" and ship_invulnerable <= 0.0 \
				and not BP.collide_circle_rect(en.pos, ENEMY_R * 0.85, paddle_rect()).is_empty():
			_destroy_enemy(i, false)
			_destroy_ship()
			if state == State.OVER:
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
	events.append(["ship_destroyed", Vector2(paddle_x, PADDLE_Y)])
	_end_powerup()
	extra_balls.clear()
	blasts.clear()
	blast_charge = 0.0
	ship_invulnerable = SHIP_INVULNERABLE
	balls_left -= 1
	if balls_left <= 0:
		state = State.OVER
		events.append(["over", score])
	else:
		_reset_serve()


func _lose_ball() -> void:
	_end_powerup()
	balls_left -= 1
	events.append(["lost", ball_pos.x])
	if balls_left <= 0:
		state = State.OVER
		events.append(["over", score])
	else:
		_reset_serve()
