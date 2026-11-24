## Tilt Breaker visual effects (D-041): plasma ball + trail, ship engine flames.
## Pure presentation — gameplay never reads anything from here.
extends RefCounted

const PLASMA_SHADER = preload("res://games/breakout/shaders/plasma.gdshader")
const WORMHOLE_SHADER = preload("res://games/breakout/shaders/wormhole.gdshader")


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


## Tetrahedron enemy body (D-052, D-053): circumradius `radius`; each face shows
## a random texel-snapped crop of ONE circuit texture (a single colour per enemy),
## chunky nearest-filtered pixels with glowing LEDs, plus glowing edges.
static func make_tetrahedron(radius: float, texture: Texture2D, edge_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Tetrahedron"
	var k := radius / sqrt(3.0)
	var v := [Vector3(1, 1, 1) * k, Vector3(1, -1, -1) * k, Vector3(-1, 1, -1) * k, Vector3(-1, -1, 1) * k]
	var faces := [[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]]
	var crop := 72.0 / 512.0
	for f in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		var n := ((a + b + c) / 3.0).normalized()  # outward for a centred tetrahedron
		var off := Vector2(randi() % 440, randi() % 440) / 512.0
		var uvs := [off + Vector2(0.0, 1.0) * crop, off + Vector2(0.5, 0.0) * crop, off + Vector2(1.0, 1.0) * crop]
		var pts := [a, b, c]
		for i in 3:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(pts[i])
		var mesh := st.commit()
		var tex: Texture2D = texture
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 1.4
		m.roughness = 0.45
		m.metallic = 0.35
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		root.add_child(mi)
	# Glowing edges
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]:
		lines.surface_add_vertex(v[e[0]] * 1.01)
		lines.surface_add_vertex(v[e[1]] * 1.01)
	lines.surface_end()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	root.add_child(li)
	return root


## D-323: the cube enemy: same look as the tetrahedron (one circuit texture,
## a random texel-snapped crop per face, glowing edges); circumradius `radius`.
static func make_cube(radius: float, texture: Texture2D, edge_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Cube"
	var h := radius / sqrt(3.0)
	var crop := 72.0 / 512.0
	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for n in normals:
		var u: Vector3 = Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		var w: Vector3 = n.cross(u)
		var c: Vector3 = n * h
		var corners := [c - u * h - w * h, c - u * h + w * h, c + u * h + w * h, c + u * h - w * h]
		var off := Vector2(randi() % 440, randi() % 440) / 512.0
		var uvs := [off + Vector2(0, 1) * crop, off + Vector2(1, 1) * crop, off + Vector2(1, 0) * crop, off]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.emission_enabled = true
		m.emission_texture = texture
		m.emission_energy_multiplier = 1.4
		m.roughness = 0.45
		m.metallic = 0.35
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		root.add_child(mi)
	# Glowing edges: the 12 between corners differing in one axis.
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var p := Vector3(x, y, z) * h * 1.01
				for d in [Vector3(x, 0, 0), Vector3(0, y, 0), Vector3(0, 0, z)]:
					if d.x + d.y + d.z > 0.0:   # each edge once
						lines.surface_add_vertex(p)
						lines.surface_add_vertex(p - d * 2.0 * h * 1.01)
	lines.surface_end()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	root.add_child(li)
	return root


## D-335: the boss body: an icosahedron (circumradius `radius`) of see-through
## circuit panels (one random crop per face) with glowing edges, so the eye
## inside shows.
static func make_icosahedron(radius: float, texture: Texture2D, edge_color: Color, alpha: float = 0.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Icosahedron"
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var raw := []
	for a in [-1.0, 1.0]:
		for b in [-phi, phi]:
			raw.append(Vector3(0, a, b))
			raw.append(Vector3(a, b, 0))
			raw.append(Vector3(b, 0, a))
	var v := []
	for p in raw:
		v.append((p as Vector3).normalized() * radius)
	var edge := INF
	for i in v.size():
		for j in range(i + 1, v.size()):
			edge = minf(edge, (v[i] as Vector3).distance_to(v[j]))
	var near := func(a: Vector3, b: Vector3) -> bool: return absf(a.distance_to(b) - edge) < edge * 0.01
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = Color(1, 1, 1, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.emission_enabled = true
	m.emission_texture = texture
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.4
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var crop := 96.0 / 512.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in v.size():
		for j in range(i + 1, v.size()):
			if not near.call(v[i], v[j]):
				continue
			for k in range(j + 1, v.size()):
				if not (near.call(v[i], v[k]) and near.call(v[j], v[k])):
					continue
				var a: Vector3 = v[i]
				var b: Vector3 = v[j]
				var c: Vector3 = v[k]
				var n := (b - a).cross(c - a).normalized()
				if n.dot(a + b + c) < 0.0:   # outwards
					var t := b
					b = c
					c = t
					n = -n
				var off := Vector2(randi() % 410, randi() % 410) / 512.0
				var uvs := [off + Vector2(0.0, 1.0) * crop, off + Vector2(0.5, 0.0) * crop, off + Vector2(1.0, 1.0) * crop]
				var pts := [a, b, c]
				for q in 3:
					st.set_normal(n)
					st.set_uv(uvs[q])
					st.add_vertex(pts[q])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.name = "Faces"
	root.add_child(mi)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in v.size():
		for j in range(i + 1, v.size()):
			if near.call(v[i], v[j]):
				lines.surface_add_vertex(v[i] * 1.01)
				lines.surface_add_vertex(v[j] * 1.01)
	lines.surface_end()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	li.name = "Edges"
	root.add_child(li)
	return root


## D-342: the level-20 boss body: a dodecahedron (circumradius `radius`), the
## icosahedron's style: see-through circuit panels and glowing edges.
static func make_dodecahedron(radius: float, texture: Texture2D, edge_color: Color, alpha: float = 0.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Dodecahedron"
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var ip := 1.0 / phi
	var raw := []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				raw.append(Vector3(x, y, z))
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			raw.append(Vector3(0, a * ip, b * phi))
			raw.append(Vector3(a * ip, b * phi, 0))
			raw.append(Vector3(a * phi, 0, b * ip))
	var v := []
	for p in raw:
		v.append((p as Vector3).normalized() * radius)
	# Face normals = the icosahedron's vertices; each face = the 5 nearest corners.
	var normals := []
	for a in [-1.0, 1.0]:
		for b in [-phi, phi]:
			normals.append(Vector3(0, a, b).normalized())
			normals.append(Vector3(a, b, 0).normalized())
			normals.append(Vector3(b, 0, a).normalized())
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = Color(1, 1, 1, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.emission_enabled = true
	m.emission_texture = texture
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.4
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var crop := 96.0 / 512.0
	for n in normals:
		var corners := v.duplicate()
		corners.sort_custom(func(p, q): return (p as Vector3).dot(n) > (q as Vector3).dot(n))
		corners = corners.slice(0, 5)
		var cen := Vector3.ZERO
		for c in corners:
			cen += c
		cen /= 5.0
		var ax: Vector3 = ((corners[0] as Vector3) - cen).normalized()
		var ay: Vector3 = (n as Vector3).cross(ax)
		corners.sort_custom(func(p, q): return atan2((p - cen).dot(ay), (p - cen).dot(ax)) < atan2((q - cen).dot(ay), (q - cen).dot(ax)))
		var off := Vector2(randi() % 410, randi() % 410) / 512.0
		for i in 5:
			var a: Vector3 = corners[i]
			var b: Vector3 = corners[(i + 1) % 5]
			var tri := [cen, a, b]
			var uvs := [off + Vector2(0.5, 0.5) * crop, off + Vector2(0.5 + 0.5 * cos(i * TAU / 5.0), 0.5 + 0.5 * sin(i * TAU / 5.0)) * crop,
				off + Vector2(0.5 + 0.5 * cos((i + 1) * TAU / 5.0), 0.5 + 0.5 * sin((i + 1) * TAU / 5.0)) * crop]
			for q in 3:
				st.set_normal(n)
				st.set_uv(uvs[q])
				st.add_vertex(tri[q])
			lines.surface_add_vertex(a * 1.01)
			lines.surface_add_vertex(b * 1.01)
	lines.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	root.add_child(mi)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	root.add_child(li)
	return root


## D-331: the Homing Missile: a thin metal rocket, nose along -Z, a coloured
## band behind the nose, four tail fins and a particle thruster (world-space
## sparks and smoke that trail behind it). Call `restart()` on the "Thruster"
## child once it's in the tree.
static func make_missile(band: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Missile"
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.78, 0.8, 0.84)
	metal.metallic = 0.9
	metal.roughness = 0.28
	metal.emission_enabled = true   # readable against space
	metal.emission = Color(0.25, 0.27, 0.3)
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.4
	cyl.radial_segments = 10
	body.mesh = cyl
	body.material_override = metal
	body.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(body)
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.035
	cone.height = 0.11
	cone.radial_segments = 10
	nose.mesh = cone
	nose.material_override = metal
	nose.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # tip towards -Z
	nose.position = Vector3(0.0, 0.0, -0.255)
	root.add_child(nose)
	var ring := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.038
	rc.bottom_radius = 0.038
	rc.height = 0.05
	rc.radial_segments = 10
	ring.mesh = rc
	var bm := StandardMaterial3D.new()
	bm.albedo_color = band
	bm.emission_enabled = true
	bm.emission = band
	bm.emission_energy_multiplier = 1.5
	ring.material_override = bm
	ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	ring.position = Vector3(0.0, 0.0, -0.13)
	root.add_child(ring)
	for k in 4:   # tail fins
		var fin := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.012, 0.09, 0.1)
		fin.mesh = bx
		fin.material_override = metal
		var piv := Node3D.new()
		piv.rotation.z = k * PI * 0.5 + PI * 0.25
		piv.position = Vector3(0.0, 0.0, 0.15)
		fin.position = Vector3(0.0, 0.06, 0.0)
		piv.add_child(fin)
		root.add_child(piv)
	# Thruster: hot sparks shooting back, cooling to smoke, left behind in the world.
	var p := CPUParticles3D.new()
	p.name = "Thruster"
	p.amount = 96
	p.lifetime = 0.35
	p.local_coords = false
	p.position = Vector3(0.0, 0.0, 0.21)
	p.direction = Vector3(0.0, 0.0, 1.0)
	p.spread = 14.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	grad.set_color(1, Color(0.5, 0.5, 0.55, 0.0))
	grad.add_point(0.2, Color(1.0, 0.85, 0.3, 0.95))
	grad.add_point(0.45, Color(1.0, 0.45, 0.1, 0.7))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = pm
	p.mesh = q
	root.add_child(p)
	return root


## Charge-up particles (D-053): glowing square pixels that spawn on a ring around
## the emitter and are pulled into its centre, shrinking as they arrive.
## Toggle `emitting` while charging.
static func make_charge_particles(ring_radius: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 36
	p.lifetime = 0.35
	p.local_coords = true
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = ring_radius
	p.emission_ring_inner_radius = ring_radius * 0.7
	p.emission_ring_height = 0.1
	p.direction = Vector3.ZERO
	p.spread = 0.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	# Reach the centre at about the end of the lifetime: r = 0.5 * a * t^2.
	var pull := 2.0 * ring_radius * 0.85 / (p.lifetime * p.lifetime)
	p.radial_accel_min = -pull * 1.1
	p.radial_accel_max = -pull * 0.9
	p.tangential_accel_min = 2.0  # slight swirl
	p.tangential_accel_max = 4.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.6, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1.2, 1.2, 1.2, 1.0)])
	p.color_ramp = fade
	p.color = color  # tint (set per charge level by the game)
	var px := QuadMesh.new()
	px.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.25, 1.25, 1.25, 1.0)  # mild HDR: glows but keeps its colour
	px.material = m
	p.mesh = px
	return p


## Power-up capsule (D-072): a coloured glowing sphere with its letter in the
## middle and two "electrons" orbiting like an atom. Call spin(t) every frame.
class PowerupCapsule:
	extends Node3D

	var _orbits: Array[Node3D] = []
	var _pill: Node3D = null

	## `letter` is the text on the capsule (scaled down to fit when longer);
	## an `icon` texture replaces it (D-326). `pill`: a paddle upgrade's
	## capsule, a spinning two-tone pill without electrons (D-327).
	func _init(letter: String, color: Color, radius: float, icon: Texture2D = null, pill: bool = false) -> void:
		var core := MeshInstance3D.new()
		if pill:
			var cm := CapsuleMesh.new()
			cm.radius = radius * 0.72
			cm.height = radius * 2.9
			core.mesh = cm
			core.rotation_degrees = Vector3(0.0, 0.0, 90.0)   # lying across the field
			_pill = Node3D.new()
			add_child(_pill)
		else:
			var sphere := SphereMesh.new()
			sphere.radius = radius
			sphere.height = radius * 2.0
			core.mesh = sphere
		# Volume (D-075): low self-glow so the scene light shades the sphere, a
		# glossy highlight and a rim light around the edge.
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.3
		m.roughness = 0.18
		m.metallic = 0.15
		m.metallic_specular = 0.9
		m.rim_enabled = true
		m.rim = 0.8
		m.rim_tint = 0.3
		core.material_override = m
		if _pill != null:
			_pill.add_child(core)
			# The pill's lighter half and the seam between the halves.
			var half := MeshInstance3D.new()
			var hm := CapsuleMesh.new()
			hm.radius = radius * 0.74
			hm.height = radius * 1.55
			half.mesh = hm
			half.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			half.position = Vector3(radius * 0.72, 0.0, 0.0)
			var m2 := m.duplicate() as StandardMaterial3D
			m2.albedo_color = color.lerp(Color.WHITE, 0.65)
			m2.emission = m2.albedo_color
			half.material_override = m2
			_pill.add_child(half)
		else:
			add_child(core)
		var key := OmniLight3D.new()  # small key light: lit top-left, shaded bottom-right
		key.position = Vector3(-radius * 2.2, radius * 3.0, -radius * 1.5)
		key.omni_range = radius * 7.0
		key.light_energy = 1.6
		key.light_color = color.lerp(Color.WHITE, 0.6)
		add_child(key)
		if icon != null:
			for sh in [true, false]:
				var sp := Sprite3D.new()
				sp.texture = icon
				sp.pixel_size = radius * 1.5 / float(icon.get_width())
				sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sp.no_depth_test = true
				sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				sp.render_priority = 1 if sh else 2
				if sh:   # drop shadow (D-075)
					sp.modulate = Color(0, 0, 0, 0.7)
					sp.position = Vector3(radius * 0.14, -radius * 0.1, radius * 0.14)
				add_child(sp)
			letter = ""
		var label := Label3D.new()
		label.text = letter
		label.font = load("res://assets/fonts/pinpixel.ttf")
		label.font_size = 96
		label.pixel_size = radius * 0.012 / maxf(1.0, letter.length() * 0.6)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color.WHITE if color.get_luminance() < 0.75 else Color(0.1, 0.1, 0.15)
		label.outline_size = 16
		label.outline_modulate = Color(0, 0, 0, 0.8)
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.render_priority = 2
		# Drop shadow under the letter so it reads as raised (D-075).
		var shadow := label.duplicate() as Label3D
		shadow.modulate = Color(0, 0, 0, 0.7)
		shadow.outline_modulate = Color(0, 0, 0, 0.0)
		shadow.render_priority = 1
		shadow.position = Vector3(radius * 0.14, -radius * 0.1, radius * 0.14)
		add_child(shadow)
		add_child(label)
		for tilt in ([] if pill else [Vector3(1.1, 0.0, 0.5), Vector3(-1.0, 0.0, -0.6)]):
			var pivot := Node3D.new()
			pivot.rotation = tilt
			var e := MeshInstance3D.new()
			var dot := SphereMesh.new()
			dot.radius = radius * 0.17
			dot.height = radius * 0.34
			e.mesh = dot
			var em := StandardMaterial3D.new()
			em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			em.albedo_color = color.lerp(Color.WHITE, 0.6) * 2.0
			e.material_override = em
			e.position = Vector3(radius * 1.7, 0.0, 0.0)
			pivot.add_child(e)
			add_child(pivot)
			_orbits.append(pivot)

	func spin(delta: float) -> void:
		if _pill != null:
			_pill.rotate_y(delta * 2.4)
		for i in _orbits.size():
			_orbits[i].rotate_object_local(Vector3.UP, delta * (5.0 if i == 0 else -6.5))


## Wormhole vortex billboard (D-052). Drive "open" (0..1) as an instance uniform.
static func make_wormhole(size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	m.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = WORMHOLE_SHADER
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Recolours a plasma ball made by make_plasma_ball (core + halo + arcs).
static func tint_plasma(ball: Node3D, color: Color) -> void:
	var core := ball.get_child(0) as MeshInstance3D
	var cm := core.material_override as StandardMaterial3D
	cm.albedo_color = color.lerp(Color.WHITE, 0.6)
	cm.emission = color.lerp(Color.WHITE, 0.5)
	var halo := ball.get_child(1) as MeshInstance3D
	var hm := halo.material_override as ShaderMaterial
	hm.set_shader_parameter("core_color", color.lerp(Color.WHITE, 0.7))
	hm.set_shader_parameter("halo_color", color)
	hm.set_shader_parameter("arc_color", color.lerp(Color.WHITE, 0.3))


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

	func _init(dir: Vector3) -> void:
		_particles = CPUParticles3D.new()
		_particles.amount = 40
		_particles.lifetime = 0.26
		_particles.local_coords = true  # the flame stays attached to the nozzle
		_particles.emitting = false
		_particles.direction = dir.normalized()
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
		_light.position = dir.normalized() * 0.15 + Vector3(0.0, 0.35, 0.0)
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
		_haze_mat = haze_mat

	var _haze_mat: ShaderMaterial

	## D-343: overrides the surface shader's values (colours, detail_scale,
	## cloud_amount...) and the halo's colour and strength.
	func restyle(params: Dictionary, haze: Color, haze_intensity: float) -> void:
		for k in params:
			_mat.set_shader_parameter(k, params[k])
		_haze_mat.set_shader_parameter("haze_color", haze)
		_haze_mat.set_shader_parameter("intensity", haze_intensity)

	## D-343: places the centre at (x right, y up) in view units from `target`,
	## `depth` behind it (orthographic, so depth only sorts).
	func place_at(cam_basis: Basis, target: Vector3, view: Vector2, depth: float) -> void:
		position = target + cam_basis.x * view.x + cam_basis.y * view.y - cam_basis.z * depth

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
