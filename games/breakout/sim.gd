## Tilt Breaker gameplay simulation — pure logic, no nodes (D-040). The game module
## renders it; tests drive it headless. Coordinates: x right, y = world z, +y
## towards the player. All tuning values are constants here (see GDD §5.1 tuning).
extends RefCounted

const BP = preload("res://games/breakout/ball_physics.gd")

# --- playfield -----------------------------------------------------------------
const FIELD := Rect2(-4.3, -7.2, 8.6, 15.2)  # inner walls: left, top, width, height
const DRAIN_Y := 8.3
# --- paddle --------------------------------------------------------------------
const PADDLE_Y := 6.6
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
const BALL_MAX_SPEED := 15.0
const SPEEDUP_PER_PADDLE_HIT := 0.12
const MIN_VERTICAL := 0.28
const AUTO_SERVE_SECONDS := 6.0
const MAX_SUBSTEP := 0.05  # world units per collision substep (no tunnelling)
# --- bricks --------------------------------------------------------------------
const BRICK_ROWS := 6
const BRICK_COLS := 11
const BRICK_TOP := -6.0
const BRICK_H := 0.4
const BRICK_GAP := 0.05
const BRICK_POINTS := [120, 100, 80, 60, 50, 40]  # per row, top row first
const RACK_BONUS := 1000

enum State { SERVE, PLAY, OVER }

var state := State.SERVE
var score := 0
var balls_left := 3
var rack := 1

var paddle_x := 0.0
var paddle_vx := 0.0
var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := 0

var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_speed := BALL_START_SPEED
var _held_time := 0.0

## Each brick: {rect: Rect2, hp: int, alive: bool, row: int, points: int}
var bricks: Array = []
## Events produced by the last step(): [name, data]. Names: serve, paddle, wall,
## brick (data = index), rack_clear, lost, over, dash.
var events: Array = []


func setup(balls: int) -> void:
	balls_left = maxi(1, balls)
	score = 0
	rack = 1
	build_rack()
	_reset_serve()


func build_rack() -> void:
	bricks.clear()
	var w := FIELD.size.x / BRICK_COLS
	for row in BRICK_ROWS:
		for col in BRICK_COLS:
			var rect := Rect2(FIELD.position.x + col * w + BRICK_GAP * 0.5,
				BRICK_TOP + row * BRICK_H + BRICK_GAP * 0.5, w - BRICK_GAP, BRICK_H - BRICK_GAP)
			bricks.append({"rect": rect, "hp": 1, "alive": true, "row": row, "points": BRICK_POINTS[row]})


func bricks_alive() -> int:
	var n := 0
	for b in bricks:
		if b.alive:
			n += 1
	return n


func paddle_rect() -> Rect2:
	return Rect2(paddle_x - PADDLE_W * 0.5, PADDLE_Y - PADDLE_H * 0.5, PADDLE_W, PADDLE_H)


## Advances the simulation. left/right: flipper buttons held. launch: pressed this
## frame. dash: -1/+1 if a magna save was pressed this frame, else 0.
func step(dt: float, left: bool, right: bool, launch: bool, dash: int) -> void:
	events.clear()
	if state == State.OVER:
		return
	_move_paddle(dt, left, right, dash)
	if state == State.SERVE:
		ball_pos = Vector2(paddle_x, PADDLE_Y - PADDLE_H * 0.5 - BALL_R - 0.01)
		_held_time += dt
		if launch or _held_time >= AUTO_SERVE_SECONDS:
			_serve()
		return
	var dist := ball_vel.length() * dt
	var n := maxi(1, ceili(dist / MAX_SUBSTEP))
	var h := dt / n
	for i in n:
		if not _ball_substep(h):
			break


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
		var target := (float(right) - float(left)) * PADDLE_MAX_SPEED
		if target == 0.0:
			paddle_vx = move_toward(paddle_vx, 0.0, PADDLE_DECEL * dt)
		else:
			var rate := PADDLE_REVERSE if signf(target) != signf(paddle_vx) and paddle_vx != 0.0 else PADDLE_ACCEL
			paddle_vx = move_toward(paddle_vx, target, rate * dt)
	paddle_x += paddle_vx * dt
	var limit := FIELD.size.x * 0.5 - PADDLE_W * 0.5
	if absf(paddle_x) > limit:
		paddle_x = clampf(paddle_x, -limit, limit)
		paddle_vx = 0.0


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


## Returns false if the ball left play during this substep.
func _ball_substep(h: float) -> bool:
	ball_pos += ball_vel * h
	# Walls
	if ball_pos.x - BALL_R < FIELD.position.x:
		ball_pos.x = FIELD.position.x + BALL_R
		ball_vel.x = absf(ball_vel.x)
		events.append(["wall", null])
	elif ball_pos.x + BALL_R > FIELD.end.x:
		ball_pos.x = FIELD.end.x - BALL_R
		ball_vel.x = -absf(ball_vel.x)
		events.append(["wall", null])
	if ball_pos.y - BALL_R < FIELD.position.y:
		ball_pos.y = FIELD.position.y + BALL_R
		ball_vel.y = absf(ball_vel.y)
		events.append(["wall", null])
	# Bricks: resolve the deepest contact only (one bounce per substep).
	var best := -1
	var best_c := {}
	for i in bricks.size():
		var b: Dictionary = bricks[i]
		if not b.alive:
			continue
		var c := BP.collide_circle_rect(ball_pos, BALL_R, b.rect)
		if not c.is_empty() and (best == -1 or c.depth > best_c.depth):
			best = i
			best_c = c
	if best != -1:
		ball_pos += best_c.normal * best_c.depth
		ball_vel = BP.reflect(ball_vel, best_c.normal)
		var b: Dictionary = bricks[best]
		b.hp -= 1
		if b.hp <= 0:
			b.alive = false
			score += b.points
			events.append(["brick", best])
			if bricks_alive() == 0:
				score += RACK_BONUS
				rack += 1
				events.append(["rack_clear", rack])
				build_rack()
				_reset_serve()
				return false
	# Paddle
	var pr := paddle_rect()
	var pc := BP.collide_circle_rect(ball_pos, BALL_R, pr)
	if not pc.is_empty():
		if ball_vel.y > 0.0 and ball_pos.y < PADDLE_Y:
			ball_speed = minf(ball_speed + SPEEDUP_PER_PADDLE_HIT, BALL_MAX_SPEED)
			ball_vel = BP.paddle_bounce(ball_pos.x, paddle_x, PADDLE_W * 0.5, ball_speed, paddle_vx)
			ball_pos.y = pr.position.y - BALL_R
			events.append(["paddle", null])
		else:
			ball_pos += pc.normal * pc.depth
			ball_vel = BP.reflect(ball_vel, pc.normal)
	ball_vel = BP.enforce_min_vertical(ball_vel, ball_speed, MIN_VERTICAL)
	# Drain
	if ball_pos.y - BALL_R > DRAIN_Y:
		_lose_ball()
		return false
	return true


func _lose_ball() -> void:
	balls_left -= 1
	events.append(["lost", balls_left])
	if balls_left <= 0:
		state = State.OVER
		events.append(["over", score])
	else:
		_reset_serve()
