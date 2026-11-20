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


## One side afterburner (D-042): OFF at rest; when on, a tight cone of blue flame
## attached to the nozzle, pointing outward along `dir_x` (-1/+1): big white-hot
## blobs at the nozzle shrinking to a point, length/brightness scaled by thrust.
## Plus a blue light on the hull while burning. Call set_thrust(0..1.5) every frame.
## (CPU particles: two tiny emitters; GPU particles did not move here.)
class ShipEngine:
	extends Node3D

	const ON_THRESHOLD := 0.08

	var _particles: CPUParticles3D
	var _light: OmniLight3D

	func _init(dir_x: float) -> void:
		_particles = CPUParticles3D.new()
		_particles.amount = 40
		_particles.lifetime = 0.26
		_particles.local_coords = true  # the flame stays attached to the nozzle
		_particles.emitting = false
		_particles.direction = Vector3(dir_x, 0.0, 0.0)
		_particles.spread = 3.0  # narrow: the cone shape comes from shrinking particles
		_particles.gravity = Vector3.ZERO
		_particles.initial_velocity_min = 3.0
		_particles.initial_velocity_max = 3.6
		_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_particles.emission_sphere_radius = 0.015
		var curve := Curve.new()  # wide at the nozzle -> point at the tip
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		_particles.scale_amount_curve = curve
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.1, 0.45, 1.0])
		grad.colors = PackedColorArray([Color(0.9, 0.95, 1.0, 0.7), Color(0.45, 0.8, 1.0, 0.6),
			Color(0.15, 0.4, 1.0, 0.4), Color(0.05, 0.12, 0.7, 0.0)])
		_particles.color_ramp = grad

		var quad := QuadMesh.new()
		quad.size = Vector2(0.26, 0.26)
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
		_particles.mesh = quad
		add_child(_particles)

		_light = OmniLight3D.new()
		_light.light_color = Color(0.35, 0.6, 1.0)
		_light.omni_range = 1.4
		_light.light_energy = 0.0
		_light.position = Vector3(dir_x * 0.15, 0.35, 0.0)
		add_child(_light)

	func set_thrust(t: float) -> void:
		var k := clampf(t, 0.0, 1.5)
		var on := k > ON_THRESHOLD
		if _particles.emitting != on:
			_particles.emitting = on
		if not on:
			_light.light_energy = 0.0
			return
		# Longer, faster flame with more thrust (cone length ~ velocity * lifetime).
		_particles.initial_velocity_min = 2.8 + k * 3.2
		_particles.initial_velocity_max = 3.2 + k * 3.6
		_light.light_energy = 0.4 + k * 1.6


## Backdrop planet (D-043): an earth-like world so large that only a gently curved
## slice of its horizon shows across the bottom of the TABLE, far behind the
## playfield (blurred by the camera's depth of field). impact() lights up the spot
## where a lost plasma shot would hit.
class Planet:
	extends Node3D

	const PLANET_SHADER = preload("res://games/breakout/shaders/planet.gdshader")
	const ATMOSPHERE_SHADER = preload("res://games/breakout/shaders/atmosphere.gdshader")

	var radius := 100.0
	var _mat: ShaderMaterial
	var _impact_age := 99.0

	func _init(p_radius: float) -> void:
		radius = p_radius
		var body := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 192
		sphere.rings = 96
		body.mesh = sphere
		_mat = ShaderMaterial.new()
		_mat.shader = PLANET_SHADER
		body.material_override = _mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
		var haze := MeshInstance3D.new()
		var shell := SphereMesh.new()
		shell.radius = radius * 1.007
		shell.height = radius * 2.014
		shell.radial_segments = 192
		shell.rings = 96
		haze.mesh = shell
		var haze_mat := ShaderMaterial.new()
		haze_mat.shader = ATMOSPHERE_SHADER
		haze.material_override = haze_mat
		haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(haze)
		# A random-ish but fixed orientation so a coastline sits under the playfield.
		rotation = Vector3(0.4, 1.1, 0.2)

	## Orthographic placement: the silhouette's top lands `rim_v` units above the
	## view centre (`target`), with the centre `depth_behind` units further from
	## the camera than the target, so the visible surface is behind the playfield.
	func place(cam_basis: Basis, target: Vector3, rim_v: float, depth_behind: float) -> void:
		var up := cam_basis.y
		var fwd := -cam_basis.z
		position = target + up * (rim_v - radius) + fwd * depth_behind

	## Lights the surface where a ray from `from` along `dir` meets the planet.
	## big = the final, screen-filling explosion (D-044).
	func impact(from: Vector3, dir: Vector3, big: bool = false) -> void:
		var oc := from - position
		var b := oc.dot(dir)
		var c := oc.dot(oc) - radius * radius
		var disc := b * b - c
		var t := -b - sqrt(disc) if disc >= 0.0 else -b
		var hit := from + dir * t
		_mat.set_shader_parameter("impact_point", hit)
		_impact_age = 0.0
		if big:
			_spawn_fireball(hit - dir * 2.0, 18.0, 1.1, 99.0)
		else:
			_spawn_fireball(hit - dir * 2.0, 1.4, 0.5, 0.15)

	## Additive fireball billboard at the impact (reads at the grazing angle).
	## Grows to `max_scale` over `grow` s; starts fading after `hold` s.
	func _spawn_fireball(at: Vector3, max_scale: float, grow: float, hold: float) -> void:
		var fb := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.2, 2.2)
		fb.mesh = quad
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true  # otherwise billboards ignore node scale
		m.no_depth_test = true
		var tex := GradientTexture2D.new()
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		g.colors = PackedColorArray([Color(1, 0.95, 0.8, 1), Color(1, 0.55, 0.15, 0.8), Color(0.8, 0.2, 0.05, 0)])
		tex.gradient = g
		m.albedo_texture = tex
		m.albedo_color = Color(1.6, 1.6, 1.6, 1.0)
		fb.material_override = m
		fb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fb.position = at
		fb.scale = Vector3.ONE * 0.2
		get_parent().add_child(fb)
		var tw := fb.create_tween()
		tw.set_parallel(true)
		tw.tween_property(fb, "scale", Vector3.ONE * max_scale, grow).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if hold < 10.0:
			tw.tween_property(m, "albedo_color:a", 0.0, 0.7).set_delay(hold)
			tw.chain().tween_callback(fb.queue_free)

	func _process(delta: float) -> void:
		if _impact_age < 10.0:
			_impact_age += delta
			_mat.set_shader_parameter("impact_age", _impact_age)
