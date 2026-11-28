## TURBO RUN city (D-216): the buildings of the city area, built per road
## chunk: one MultiMesh of unit boxes per chunk, scaled per building and drawn
## by building.gdshader. D-514: the road is an urban motorway: concrete walls
## along both sides and overpasses carrying roads across (the junctions and
## traffic lights of D-216 are gone).
extends RefCounted

const Track = preload("res://games/racer/track.gd")
const BUILDING_SHADER = preload("res://games/racer/shaders/building.gdshader")
const Tunnel = preload("res://games/racer/tunnel.gd")
const DECK_T := 1.3              # m, an overpass deck's thickness
const DECK_REACH := Track.OVERPASS_REACH   # m it runs to each side of the road
const PIER_EVERY := 30.0

static var _bmat: ShaderMaterial
static var _wall_mat: StandardMaterial3D
static var _deck_mat: StandardMaterial3D


static func building_material() -> ShaderMaterial:
	if _bmat == null:
		_bmat = ShaderMaterial.new()
		_bmat.shader = BUILDING_SHADER
	return _bmat


## The walls: the tunnels' concrete panels, lit by the scene.
static func wall_material() -> StandardMaterial3D:
	if _wall_mat == null:
		_wall_mat = StandardMaterial3D.new()
		_wall_mat.albedo_texture = ImageTexture.create_from_image(Tunnel._concrete())
		_wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_mat.albedo_color = Color(1.25, 1.25, 1.27)
		_wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _wall_mat


static func deck_material() -> StandardMaterial3D:
	if _deck_mat == null:
		_deck_mat = StandardMaterial3D.new()
		_deck_mat.albedo_color = Color(0.56, 0.55, 0.53)
	return _deck_mat


## Night level and HD flag for the shared materials.
static func update(night: float, hd: bool, _time: float) -> void:
	building_material().set_shader_parameter("night", night)
	building_material().set_shader_parameter("hd", hd)


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
		# D-514: scaled along its own axes. (scaled() works along the world's:
		# where the road had turned, the boxes were skewed and reached the road.)
		var b := Basis(Vector3.UP, tr_.heading(o.s)).scaled_local(Vector3(float(o.d), float(o.h) + 0.3, float(o.w)))
		mm.set_instance_transform(i, Transform3D(b, base + Vector3(0.0, (float(o.h) + 0.3) * 0.5, 0.0)))
		mm.set_instance_custom_data(i, Color(float(o.style) / 6.0, fmod(absf(float(o.s)) * 0.0137, 1.0), 0.0, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = building_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON   # D-253
	parent.add_child(mmi)


## The motorway walls (D-514) on both sides of the road in [s0, s1): a face
## towards the road and a cap on top, following the road.
static func build_walls(parent: Node3D, tr_, s0: float, s1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var n := maxi(1, ceili((s1 - s0) / Track.SAMPLE))
	const CAP := 0.5
	for i in n:
		var sa := s0 + (s1 - s0) * i / n
		var sb := s0 + (s1 - s0) * (i + 1) / n
		var ha: float = tr_.city_wall_h(sa)
		var hb: float = tr_.city_wall_h(sb)
		if ha <= 0.0 or hb <= 0.0:
			continue
		any = true
		for side in [-1.0, 1.0]:
			var w: float = side * Track.CITY_WALL
			var wo: float = side * (Track.CITY_WALL + CAP)
			var a0: Vector3 = tr_.point(sa, w, -0.3)
			var b0: Vector3 = tr_.point(sb, w, -0.3)
			var a1: Vector3 = tr_.point(sa, w, ha)
			var b1: Vector3 = tr_.point(sb, w, hb)
			var a2: Vector3 = tr_.point(sa, wo, ha)
			var b2: Vector3 = tr_.point(sb, wo, hb)
			var inward: Vector3 = (tr_.point(sa, 0.0) - tr_.point(sa, w))
			inward.y = 0.0
			inward = inward.normalized()
			var ua := sa / Tunnel.PANEL
			var ub := sb / Tunnel.PANEL
			st.set_normal(inward)
			for vv in [[a0, Vector2(ua, 1.0)], [b0, Vector2(ub, 1.0)], [b1, Vector2(ub, 0.0)],
					[a0, Vector2(ua, 1.0)], [b1, Vector2(ub, 0.0)], [a1, Vector2(ua, 0.0)]]:
				st.set_uv(vv[1])
				st.add_vertex(vv[0])
			st.set_normal(Vector3.UP)
			for vv in [a1, b1, b2, a1, b2, a2]:
				st.set_uv(Vector2(0.4, 0.3))   # plain concrete
				st.add_vertex(vv)
	if not any:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = wall_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## The overpasses (D-514) in [s0, s1): a deck with parapets crossing over the
## road at tunnel height, an abutment at each wall and piers further out.
static func build_overpasses(parent: Node3D, tr_, s0: float, s1: float) -> void:
	for j in tr_.overpasses:
		var js: float = j
		if js < s0 or js >= s1:
			continue
		var n := Node3D.new()
		n.transform = Transform3D(Basis(Vector3.UP, tr_.heading(js)), tr_.point(js, 0.0))
		parent.add_child(n)
		var clear: float = Track.TUNNEL_HEIGHT
		var deep: float = Track.OVERPASS_HALF * 2.0
		_box(n, Vector3(0.0, clear + DECK_T * 0.5, 0.0), Vector3(DECK_REACH * 2.0, DECK_T, deep), true)
		for e in [-1.0, 1.0]:
			_box(n, Vector3(0.0, clear + DECK_T + 0.5, e * (Track.OVERPASS_HALF - 0.2)), Vector3(DECK_REACH * 2.0, 1.0, 0.4), false)
			# The abutment stands a little proud of the wall.
			_box(n, Vector3(e * (Track.CITY_WALL + 0.85), clear * 0.5 - 0.5, 0.0), Vector3(2.0, clear + 1.0, deep + 1.0), false)
			var x := Track.CITY_WALL + PIER_EVERY
			while x < DECK_REACH:
				_box(n, Vector3(e * x, clear * 0.5 - 1.0, 0.0), Vector3(1.6, clear + 2.0, deep * 0.6), false)
				x += PIER_EVERY


static func _box(parent: Node3D, at: Vector3, size: Vector3, shadow: bool) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = deck_material()
	mi.mesh = b
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
