## TURBO RUN city (D-216): the buildings, cross-street junctions and traffic
## lights of the city area, built per road chunk. Buildings are one MultiMesh of
## unit boxes per chunk, scaled per building and drawn by building.gdshader;
## junctions are ground strips (junction.gdshader); traffic lights are small
## low-poly nodes whose lamps cycle green, amber, red.
extends RefCounted

const Track = preload("res://games/racer/track.gd")
const BUILDING_SHADER = preload("res://games/racer/shaders/building.gdshader")
const JUNCTION_SHADER = preload("res://games/racer/shaders/junction.gdshader")
const CYCLE := [7.0, 1.6, 5.0]   # s of green, amber, red

static var _bmat: ShaderMaterial
static var _jmat: ShaderMaterial
static var _lamp_mats: Array = []   # green, amber, red
static var _halo_mats: Array = []   # glow round each lit lamp (D-225)
static var _pole_mat: StandardMaterial3D


static func building_material() -> ShaderMaterial:
	if _bmat == null:
		_bmat = ShaderMaterial.new()
		_bmat.shader = BUILDING_SHADER
	return _bmat


static func junction_material() -> ShaderMaterial:
	if _jmat == null:
		_jmat = ShaderMaterial.new()
		_jmat.shader = JUNCTION_SHADER
		_jmat.set_shader_parameter("road_half", Track.ROAD_HALF)
		_jmat.set_shader_parameter("jhalf", Track.JUNCTION_HALF)
	return _jmat


## Night level and HD flag for the shared materials; the traffic lights' phase.
static func update(night: float, hd: bool, time: float) -> void:
	building_material().set_shader_parameter("night", night)
	building_material().set_shader_parameter("hd", hd)
	junction_material().set_shader_parameter("hd", hd)
	if _lamp_mats.is_empty():
		return
	var t := fmod(time, CYCLE[0] + CYCLE[1] + CYCLE[2])
	var on := 0 if t < CYCLE[0] else (1 if t < CYCLE[0] + CYCLE[1] else 2)
	for i in 3:
		(_lamp_mats[i] as StandardMaterial3D).emission_energy_multiplier = 5.0 if i == on else 0.12
		(_halo_mats[i] as StandardMaterial3D).albedo_color = Color(_lamp_col(i), (0.35 + 0.4 * night) if i == on else 0.0)


static func _lamp_col(i: int) -> Color:
	return [Color(0.2, 1.0, 0.45), Color(1.0, 0.7, 0.1), Color(1.0, 0.15, 0.1)][i]


## Buildings in [s0, s1) as one MultiMesh under `parent`.
static func build_buildings(parent: Node3D, tr_, list: Array) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = list.size()
	for i in list.size():
		var o: Dictionary = list[i]
		# The building's front stands on the building line; it extends away
		# from the road by its depth.
		var side: float = o.dir
		var cx: float = o.x + side * float(o.d) * 0.5
		var base: Vector3 = tr_.point(o.s, cx)
		# Sit on the lower of its two front corners, so it never floats.
		base.y = minf(tr_.point(o.s - float(o.w) * 0.5, o.x).y, tr_.point(o.s + float(o.w) * 0.5, o.x).y) - 0.3
		var b := Basis(Vector3.UP, tr_.heading(o.s)).scaled(Vector3(float(o.d), float(o.h) + 0.3, float(o.w)))
		mm.set_instance_transform(i, Transform3D(b, base + Vector3(0.0, (float(o.h) + 0.3) * 0.5, 0.0)))
		mm.set_instance_custom_data(i, Color(float(o.style) / 6.0, fmod(absf(float(o.s)) * 0.0137, 1.0), 0.0, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = building_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON   # D-253
	parent.add_child(mmi)


## Cross streets with zebra crossings for the junctions in [s0, s1).
static func build_junctions(parent: Node3D, tr_, s0: float, s1: float) -> void:
	for j in tr_.junctions:
		var js: float = j
		if js < s0 or js >= s1:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var reach := Track.JUNCTION_HALF + 3.4
		var rows := int(ceil(reach * 2.0 / Track.SAMPLE)) + 1
		var xs: Array = []
		var x := -110.0
		while x <= 110.0:
			xs.append(x)
			x += 5.0
		for r in rows:
			var dz := -reach + r * (reach * 2.0 / (rows - 1))
			for xv in xs:
				st.set_uv(Vector2(xv, dz))
				st.add_vertex(tr_.point(js + dz, xv, 0.04))
		var cols := xs.size()
		for r in rows - 1:
			for c in cols - 1:
				var a := r * cols + c
				st.add_index(a)
				st.add_index(a + cols)
				st.add_index(a + 1)
				st.add_index(a + 1)
				st.add_index(a + cols)
				st.add_index(a + cols + 1)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = junction_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Traffic lights: a pole on the sidewalk, an arm out over the road and a
## three-lamp head facing the traffic it controls (dir: +1 right side, facing
## the player; -1 left side, facing oncoming traffic).
static func build_lights(parent: Node3D, tr_, list: Array) -> void:
	_ensure_light_mats()
	for o in list:
		var side: float = o.dir
		var f: Transform3D = tr_.frame(o.s, o.x)
		f.basis = Basis(Vector3.UP, tr_.heading(o.s))
		var n := Node3D.new()
		n.transform = f
		parent.add_child(n)
		_box(n, Vector3(0.0, 2.9, 0.0), Vector3(0.22, 5.8, 0.22), _pole_mat)
		_box(n, Vector3(-side * 2.2, 5.6, 0.0), Vector3(4.6, 0.16, 0.16), _pole_mat)
		var hx := -side * 4.1
		_box(n, Vector3(hx, 4.9, 0.0), Vector3(0.5, 1.4, 0.4), _pole_mat)
		var face := 0.22 if side > 0.0 else -0.22   # +Z faces back down the road, at the player
		for i in 3:
			var lamp := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.32, 0.32)
			lamp.mesh = q
			lamp.material_override = _lamp_mats[2 - i]   # red on top, then amber, green
			lamp.position = Vector3(hx, 5.35 - i * 0.42, face)
			if side < 0.0:
				lamp.rotation.y = PI
			n.add_child(lamp)
			# A soft glow round it (D-225), facing the camera.
			var halo := MeshInstance3D.new()
			var hq := QuadMesh.new()
			hq.size = Vector2(1.6, 1.6)
			halo.mesh = hq
			halo.material_override = _halo_mats[2 - i]
			halo.position = lamp.position + Vector3(0.0, 0.0, 0.05 * signf(face))
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(halo)


static func _ensure_light_mats() -> void:
	if not _lamp_mats.is_empty():
		return
	_pole_mat = StandardMaterial3D.new()
	_pole_mat.albedo_color = Color(0.16, 0.17, 0.19)
	var glow := _glow_texture()
	for i in 3:
		# Emissive (D-225), bright enough to bloom in the night.
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.05)
		m.emission_enabled = true
		m.emission = _lamp_col(i)
		_lamp_mats.append(m)
		var h := StandardMaterial3D.new()
		h.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		h.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		h.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		h.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		h.no_depth_test = false
		h.albedo_texture = glow
		h.albedo_color = Color(_lamp_col(i), 0.0)
		_halo_mats.append(h)


## A soft round glow (white centre fading out) for the lamp halos.
static func _glow_texture() -> Texture2D:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
