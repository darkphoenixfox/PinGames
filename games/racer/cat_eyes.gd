## TURBO RUN cat's eyes (D-521, director): reflective studs along both edges
## of the road wherever it has no street lighting: everywhere but the city,
## the finish town and the tunnels. They show only in the dark, and only in
## the light of a car: the game passes the spots the cars light up
## (shaders/cat_eye.gdshader). One MultiMesh per road chunk.
extends RefCounted

const Track = preload("res://games/racer/track.gd")
const SHADER := preload("res://games/racer/shaders/cat_eye.gdshader")
const EVERY := 9.0                           # m between studs
const AT_X := Track.ROAD_HALF - 0.12         # on the edge line
const UP := 0.05
const RED := Color(1.0, 0.1, 0.06)           # D-528 (director): red on the sides,
const WHITE := Color(1.0, 0.97, 0.86)        # white on the centre line
const MAX_CARS := 12                         # as the shader's CARS
## The spot a car lights: this far ahead of it, and its reach. The player's
## own headlights reach further (it is what the player is looking down).
const OWN := Vector2(34.0, 62.0)
const OTHER := Vector2(14.0, 30.0)


static func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	return m


## Has the road studs at s?
static func has(tr_, s: float) -> bool:
	return tr_.area_w(s, "city") < 0.5 and not tr_.in_tunnel(s) and not tr_.in_town(s)


## Adds the studs of the road from s0 to s1 to `parent`.
static func build(parent: Node3D, tr_, s0: float, s1: float, mat: ShaderMaterial) -> void:
	var at: Array[Vector3] = []
	var tint: Array[Color] = []
	var s := ceilf(s0 / EVERY) * EVERY
	while s < s1:
		if has(tr_, s):
			for side in [-1.0, 1.0]:
				at.append(tr_.point(s, side * AT_X, UP))
				tint.append(RED)
			at.append(tr_.point(s, 0.0, UP))
			tint.append(WHITE)
		s += EVERY
	if at.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at[i]))
		mm.set_instance_color(i, tint[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves every stud to the camera's plane and may grow it: the
	# mesh's own bounds mean nothing.
	mmi.extra_cull_margin = 16.0
	parent.add_child(mmi)


## D-533 (director): a stud goes dark as soon as it is past the car's bonnet
## (unless another car's lights reach it). The bonnet's place (x, z) and the
## way the car faces (x, z), for the shader's `fronts`.
static func front(tr_, s: float, x: float, dir: float, half_len: float) -> Vector4:
	var p: Vector3 = tr_.point(s + dir * half_len, x, UP)
	var q: Vector3 = tr_.point(s + dir * (half_len + 2.0), x, UP)
	var f := Vector2(q.x - p.x, q.z - p.z).normalized()
	return Vector4(p.x, p.z, f.x, f.y)


## The lit spot of a car at (s, x) driving `dir` (+1 our way, -1 oncoming).
static func spot(tr_, s: float, x: float, dir: float, own: bool) -> Vector4:
	var k: Vector2 = OWN if own else OTHER
	var p: Vector3 = tr_.point(s + dir * k.x, x, UP)
	return Vector4(p.x, p.y, p.z, k.y)
