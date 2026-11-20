## Tilt Breaker visual effects (D-041): plasma ball + trail, ship engine flames.
## Pure presentation — gameplay never reads anything from here.
extends RefCounted

const PLASMA_SHADER = preload("res://games/breakout/shaders/plasma.gdshader")


## Plasma ball: hot core sphere + billboard halo. Returns the root Node3D.
static func make_plasma_ball(radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "PlasmaBall"
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.8
	sphere.height = radius * 1.6
	core.mesh = sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.9, 0.97, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.8, 0.92, 1.0)
	core_mat.emission_energy_multiplier = 4.0
	core.material_override = core_mat
	root.add_child(core)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 6.0, radius * 6.0)
	halo.mesh = quad
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = PLASMA_SHADER
	halo.material_override = halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	return root


## Ribbon trail that follows a moving point. Call update(pos) every frame and
## clear() when the ball teleports (serve / lost).
class Trail:
	extends MeshInstance3D

	var max_points := 22
	var width := 0.2
	var min_step := 0.04
	var head_color := Color(0.55, 0.75, 1.0, 0.9)
	var tail_color := Color(0.5, 0.25, 1.0, 0.0)
	var _points: Array[Vector3] = []
	var _imesh := ImmediateMesh.new()

	func _init() -> void:
		mesh = _imesh
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = false
		material_override = m

	func clear() -> void:
		_points.clear()
		_imesh.clear_surfaces()

	func update(pos: Vector3) -> void:
		if _points.is_empty() or _points[0].distance_to(pos) >= min_step:
			_points.push_front(pos)
			if _points.size() > max_points:
				_points.pop_back()
		else:
			_points[0] = pos
		_rebuild()

	func _rebuild() -> void:
		_imesh.clear_surfaces()
		if _points.size() < 2:
			return
		_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := _points.size()
		for i in n:
			var p := _points[i]
			var a := _points[maxi(i - 1, 0)]
			var b := _points[mini(i + 1, n - 1)]
			var dir := (a - b)
			dir.y = 0.0
			dir = dir.normalized() if dir.length_squared() > 1e-8 else Vector3.FORWARD
			var perp := Vector3(-dir.z, 0.0, dir.x)
			var t := float(i) / float(n - 1)
			var w := width * (1.0 - t)
			var c := head_color.lerp(tail_color, t)
			_imesh.surface_set_color(c)
			_imesh.surface_add_vertex(p + perp * w + Vector3(0, -0.02, 0))
			_imesh.surface_set_color(c)
			_imesh.surface_add_vertex(p - perp * w + Vector3(0, -0.02, 0))
		_imesh.surface_end()


## One side engine: blue flame particles blowing outward along `dir_x` (-1/+1)
## plus a small blue light on the hull. set_thrust(0..1.5) every frame.
class ShipEngine:
	extends Node3D

	var _particles: GPUParticles3D
	var _process: ParticleProcessMaterial
	var _light: OmniLight3D

	func _init(dir_x: float) -> void:
		_particles = GPUParticles3D.new()
		_particles.amount = 64
		_particles.lifetime = 0.3
		_particles.local_coords = false
		_particles.randomness = 0.4
		_particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 2, 6))
		_process = ParticleProcessMaterial.new()
		_process.direction = Vector3(dir_x, 0.0, 0.0)
		_process.spread = 14.0
		_process.gravity = Vector3.ZERO
		_process.initial_velocity_min = 1.6
		_process.initial_velocity_max = 2.6
		_process.damping_min = 2.0
		_process.damping_max = 4.0
		_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_process.emission_sphere_radius = 0.035
		_process.scale_min = 0.7
		_process.scale_max = 1.1
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.1))
		var curve_tex := CurveTexture.new()
		curve_tex.curve = curve
		_process.scale_curve = curve_tex
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.45, 0.8, 1.0, 0.95),
			Color(0.15, 0.35, 1.0, 0.55), Color(0.05, 0.1, 0.6, 0.0)])
		var grad_tex := GradientTexture1D.new()
		grad_tex.gradient = grad
		_process.color_ramp = grad_tex
		_particles.process_material = _process

		var quad := QuadMesh.new()
		quad.size = Vector2(0.2, 0.2)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		var dot := GradientTexture2D.new()
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(1.0, 0.5)
		var dg := Gradient.new()
		dg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		dot.gradient = dg
		m.albedo_texture = dot
		quad.material = m
		_particles.draw_pass_1 = quad
		add_child(_particles)

		_light = OmniLight3D.new()
		_light.light_color = Color(0.35, 0.6, 1.0)
		_light.omni_range = 1.4
		_light.light_energy = 0.6
		_light.position = Vector3(-dir_x * 0.25, 0.35, 0.0)
		add_child(_light)

	func set_thrust(t: float) -> void:
		var k := clampf(t, 0.0, 1.5)
		_particles.amount_ratio = clampf(0.35 + k * 0.65, 0.0, 1.0)
		_process.initial_velocity_min = 1.2 + k * 2.2
		_process.initial_velocity_max = 2.0 + k * 3.0
		_light.light_energy = 0.5 + k * 1.6
