## Pure 2D collision helpers for Tilt Breaker (playfield plane: x right, y = world z,
## +y towards the player). No nodes, fully unit-tested.
extends RefCounted


## Circle vs axis-aligned rect. Returns {} if not touching, else
## {normal: Vector2 (pointing from rect to circle), depth: float}.
static func collide_circle_rect(pos: Vector2, r: float, rect: Rect2) -> Dictionary:
	var closest := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
	var d := pos - closest
	var dist2 := d.length_squared()
	if dist2 > r * r:
		return {}
	if dist2 > 1e-10:
		var dist := sqrt(dist2)
		return {"normal": d / dist, "depth": r - dist}
	# Centre inside the rect: push out along the shallowest side.
	var left := pos.x - rect.position.x
	var right := rect.end.x - pos.x
	var top := pos.y - rect.position.y
	var bottom := rect.end.y - pos.y
	var m := minf(minf(left, right), minf(top, bottom))
	if m == left:
		return {"normal": Vector2.LEFT, "depth": left + r}
	if m == right:
		return {"normal": Vector2.RIGHT, "depth": right + r}
	if m == top:
		return {"normal": Vector2.UP, "depth": top + r}
	return {"normal": Vector2.DOWN, "depth": bottom + r}


## Reflects velocity about a surface normal, only if moving into the surface.
static func reflect(vel: Vector2, normal: Vector2) -> Vector2:
	var into := vel.dot(normal)
	return vel - 2.0 * into * normal if into < 0.0 else vel


## Arkanoid-style paddle return: the hit position along the paddle (-1 left edge ..
## +1 right edge) sets the angle from straight up (up to max_angle_deg), and the
## paddle's sideways speed adds a little "english".
static func paddle_bounce(ball_x: float, paddle_x: float, half_width: float, speed: float,
		paddle_vx: float, max_angle_deg: float = 60.0) -> Vector2:
	var t := clampf((ball_x - paddle_x) / half_width, -1.0, 1.0)
	var angle := deg_to_rad(t * max_angle_deg) + clampf(paddle_vx * 0.012, -0.18, 0.18)
	angle = clampf(angle, deg_to_rad(-max_angle_deg), deg_to_rad(max_angle_deg))
	return Vector2(sin(angle), -cos(angle)) * speed


## Keeps the ball from travelling almost horizontally (endless side-to-side loops).
static func enforce_min_vertical(vel: Vector2, speed: float, min_ratio: float) -> Vector2:
	if vel.length_squared() < 1e-10:
		return Vector2(0.0, -speed)
	var v := vel.normalized()
	if absf(v.y) < min_ratio:
		var sy := -1.0 if v.y <= 0.0 else 1.0
		v = Vector2(signf(v.x) * sqrt(1.0 - min_ratio * min_ratio), sy * min_ratio)
	return v * speed
