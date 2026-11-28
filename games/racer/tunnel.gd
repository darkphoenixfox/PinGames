## TURBO RUN tunnels (D-127): the part of each tunnel that falls in a road
## chunk is built here: concrete walls on the road's edges and a flat roof that
## follow the road's curve and hills, sodium ceiling lights with orange pools of
## light on the road (flat additive polygons), and a concrete portal face at each
## end. The walls are pre-lit (unshaded) so the tunnel stays moody in daylight.
extends RefCounted

const Track = preload("res://games/racer/track.gd")

const PANEL := 8.0              # m of wall per texture tile
const LIGHT_EVERY := 24.0       # m between ceiling lights (halved count, D-133)
const PORTAL_W := 42.0          # portal face half width
const PORTAL_H := 18.0
const CITY_PORTAL := Vector2(Track.ROAD_HALF + Track.RUMBLE + Track.SIDEWALK, 10.0)   # D-514: in town it fits between the building lines
const SODIUM := Color(1.0, 0.62, 0.25)

static var _wall_mat: StandardMaterial3D
static var _portal_mat: StandardMaterial3D
static var _light_mesh: Mesh


static func _concrete() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in 32:
		for x in 32:
			var n := rng.randf() * 0.06
			var c := Color(0.46 - n, 0.44 - n, 0.42 - n)
			if x % 16 == 0 or y == 0:
				c = c.darkened(0.35)           # panel seams
			if y >= 26:
				c = c.darkened(0.3 + n)        # grime near the road
			if y == 22 or y == 23:
				c = Color(0.9, 0.72, 0.15)     # yellow guide stripe
			img.set_pixel(x, y, c)
	return img


static func wall_material() -> StandardMaterial3D:
	if _wall_mat == null:
		_wall_mat = StandardMaterial3D.new()
		_wall_mat.albedo_texture = ImageTexture.create_from_image(_concrete())
		_wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_wall_mat.albedo_color = Color(0.75, 0.62, 0.5)   # lit by the sodium lamps
		_wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _wall_mat


static func portal_material() -> StandardMaterial3D:
	if _portal_mat == null:
		_portal_mat = StandardMaterial3D.new()
		_portal_mat.albedo_texture = ImageTexture.create_from_image(_concrete())
		_portal_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_portal_mat.albedo_color = Color(0.85, 0.8, 0.78)
		_portal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_portal_mat.uv1_scale = Vector3(10, 4, 1)
	return _portal_mat


## Ceiling lamp + its pool of light on the road, in a road frame at y = 0.
static func light_mesh() -> Mesh:
	if _light_mesh != null:
		return _light_mesh
	var am := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := Track.TUNNEL_HEIGHT - 0.05
	var q := [Vector3(-0.25, y, -1.0), Vector3(0.25, y, -1.0), Vector3(0.25, y, 1.0), Vector3(-0.25, y, 1.0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(q[i])
	st.commit(am)
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color(1.0, 0.85, 0.55)
	lamp.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(0, lamp)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 16
	for i in SEG:
		var a0 := TAU * i / SEG
		var a1 := TAU * (i + 1) / SEG
		st.set_color(Color(SODIUM, 0.4))
		st.add_vertex(Vector3(0, 0.08, 0))
		st.set_color(Color(SODIUM, 0.0))
		st.add_vertex(Vector3(cos(a0) * 6.0, 0.08, sin(a0) * 5.0))
		st.set_color(Color(SODIUM, 0.0))
		st.add_vertex(Vector3(cos(a1) * 6.0, 0.08, sin(a1) * 5.0))
	st.commit(am)
	var pool := StandardMaterial3D.new()
	pool.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.vertex_color_use_as_albedo = true
	pool.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(1, pool)
	_light_mesh = am
	return am


## Adds the tunnel pieces between s0 and s1 (one road chunk) to `node`.
static func build(node: Node3D, tr_, s0: float, s1: float) -> void:
	for t in tr_.tunnels:
		var tv: Vector2 = t
		var a := maxf(s0, tv.x)
		var b := minf(s1, tv.y)
		if a >= b:
			continue
		_shell(node, tr_, a, b)
		_lights(node, tr_, a, b)
		if tv.x >= s0 and tv.x < s1:
			_portal(node, tr_, tv.x)
		if tv.y >= s0 and tv.y < s1:
			_portal(node, tr_, tv.y)


static func _shell(node: Node3D, tr_, a: float, b: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := Track.TUNNEL_HALF
	var h := Track.TUNNEL_HEIGHT
	var n := maxi(1, ceili((b - a) / Track.SAMPLE))
	for i in n:
		var sa := a + (b - a) * i / n
		var sb := a + (b - a) * (i + 1) / n
		var ua := sa / PANEL
		var ub := sb / PANEL
		# left wall, right wall, roof: [p0, p1] across, at sa and sb
		for piece in [[-w, 0.0, -w, h], [w, 0.0, w, h], [-w, h, w, h]]:
			var p00: Vector3 = tr_.point(sa, piece[0], piece[1])
			var p01: Vector3 = tr_.point(sa, piece[2], piece[3])
			var p10: Vector3 = tr_.point(sb, piece[0], piece[1])
			var p11: Vector3 = tr_.point(sb, piece[2], piece[3])
			var roof: bool = piece[1] == h
			var v0 := 0.0 if roof else 1.0
			var v1 := 1.0 if roof else 0.0
			for vv in [[p00, Vector2(ua, v0)], [p10, Vector2(ub, v0)], [p11, Vector2(ub, v1)],
					[p00, Vector2(ua, v0)], [p11, Vector2(ub, v1)], [p01, Vector2(ua, v1)]]:
				st.set_uv(vv[1])
				st.add_vertex(vv[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = wall_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


static func _lights(node: Node3D, tr_, a: float, b: float) -> void:
	var first := ceilf(a / LIGHT_EVERY) * LIGHT_EVERY
	var list: Array = []
	var s := first
	while s < b:
		list.append(s)
		s += LIGHT_EVERY
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = light_mesh()
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, tr_.frame(list[i], 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mmi)


## A concrete face round the tunnel mouth at s (open where the road goes in).
static func _portal(node: Node3D, tr_, s: float) -> void:
	var w := Track.TUNNEL_HALF
	var h := Track.TUNNEL_HEIGHT
	var city: bool = tr_.area_w(s, "city") > 0.5
	var pw := CITY_PORTAL.x if city else PORTAL_W
	var ph := CITY_PORTAL.y if city else PORTAL_H
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in [Rect2(-pw, 0, pw - w, ph), Rect2(w, 0, pw - w, ph),
			Rect2(-w, h, 2.0 * w, ph - h)]:
		var rr: Rect2 = r
		var c := [Vector3(rr.position.x, rr.position.y - 2.0, 0), Vector3(rr.end.x, rr.position.y - 2.0, 0),
			Vector3(rr.end.x, rr.end.y, 0), Vector3(rr.position.x, rr.end.y, 0)]
		if rr.position.y > 0.0:   # the lintel starts at the roof, not below it
			c[0].y = rr.position.y
			c[1].y = rr.position.y
		for i in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = c[i]
			st.set_uv(Vector2((v.x + pw) / (2.0 * PORTAL_W), 1.0 - v.y / PORTAL_H))
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = portal_material()
	mi.transform = tr_.frame(s, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
