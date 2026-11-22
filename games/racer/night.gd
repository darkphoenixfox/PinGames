## TURBO RUN night (D-113): from stage 5 the race fades into night. The lights
## are faked with transparent, additive flat polygons, no real light sources:
##   - cars (player + traffic): a low-beam cone on the road in front, small
##     headlight glows and red tail lights
##   - lamp posts: a pool of light on the road under the head, a faint cone of
##     light from the head down, and a glow at the head
## Every light material is shared and fades in with set_level(night 0..1).
extends RefCounted

const NIGHT_STAGE := 5          # the stage where night falls
const FADE := 8.0               # s for day -> night
const BEAM := Color(1.0, 0.92, 0.65)
const LAMP := Color(1.0, 0.8, 0.45)
const TAIL := Color(1.0, 0.12, 0.08)

static var _mats: Array = []    # [material, base alpha]
static var _lamp_mesh: Mesh
static var _cones := {}
static var _dot_mesh: Mesh
static var _tail_mesh: Mesh
static var level := 0.0


static func _mat(billboard: bool = false, tex: Texture2D = null, base_alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = tex == null
	if tex != null:
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	m.albedo_color = Color(1, 1, 1, 0)
	_mats.append([m, base_alpha])
	return m


## Fades every night light in or out (0 = day, 1 = night).
static func set_level(k: float) -> void:
	level = k
	for e in _mats:
		var m: StandardMaterial3D = e[0]
		var c := m.albedo_color
		c.a = k * float(e[1])
		m.albedo_color = c


# --- meshes ----------------------------------------------------------------------------
## Flat strip on the ground (y up), from z0 to z0 + length along +Z, widening
## from w0 to w1; bright at the near end, fading out at the far end and sides.
static func _cone(z0: float, length: float, w0: float, w1: float, col: Color, a0: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ROWS := 6
	for r in ROWS:
		var t0 := float(r) / ROWS
		var t1 := float(r + 1) / ROWS
		var pts := []
		for t in [t0, t1]:
			var z: float = z0 + length * t
			var w: float = lerpf(w0, w1, t) * 0.5
			var a: float = a0 * (1.0 - t) * (1.0 - t * 0.3)
			pts.append([Vector3(-w, 0, z), Vector3(0, 0, z), Vector3(w, 0, z), a])
		for side in [0, 1]:   # two halves: soft (dim) outer edge, bright centre line
			var na: Vector3 = pts[0][side]
			var nb: Vector3 = pts[0][side + 1]
			var fa: Vector3 = pts[1][side]
			var fb: Vector3 = pts[1][side + 1]
			var an: float = pts[0][3]
			var af: float = pts[1][3]
			var ca := Color(col, an * (0.25 if side == 0 else 1.0))
			var cb := Color(col, an * (1.0 if side == 0 else 0.25))
			var cfa := Color(col, af * (0.25 if side == 0 else 1.0))
			var cfb := Color(col, af * (1.0 if side == 0 else 0.25))
			for v in [[na, ca], [fa, cfa], [nb, cb], [nb, cb], [fa, cfa], [fb, cfb]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	var m := st.commit()
	m.surface_set_material(0, _mat())
	return m


## Ellipse fan: bright centre, transparent rim. `vertical` = in the XY plane.
static func _disc(st: SurfaceTool, c: Vector3, rx: float, ry: float, col: Color, a: float, vertical: bool) -> void:
	const SEG := 16
	for i in SEG:
		var a0 := TAU * i / SEG
		var a1 := TAU * (i + 1) / SEG
		var p0 := Vector3(cos(a0) * rx, sin(a0) * ry, 0) if vertical else Vector3(cos(a0) * rx, 0, sin(a0) * ry)
		var p1 := Vector3(cos(a1) * rx, sin(a1) * ry, 0) if vertical else Vector3(cos(a1) * rx, 0, sin(a1) * ry)
		st.set_color(Color(col, a))
		st.add_vertex(c)
		st.set_color(Color(col, 0))
		st.add_vertex(c + p0)
		st.set_color(Color(col, 0))
		st.add_vertex(c + p1)


## Lamp-post light in the lamp's own space (its arm reaches to -x 2.2 m, head
## at 6.85 m): a pool on the ground, a faint cone down from the head, and a
## glow round the head.
static func lamp_mesh() -> Mesh:
	if _lamp_mesh != null:
		return _lamp_mesh
	var head := Vector3(-2.2, 6.7, 0.0)
	var am := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_disc(st, Vector3(head.x, 0.1, 0.0), 5.5, 4.5, LAMP, 0.55, false)
	st.commit(am)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cone of light: a vertical fan from the head down to the pool's width.
	var g0 := Vector3(head.x - 3.6, 0.1, 0.0)
	var g1 := Vector3(head.x + 3.6, 0.1, 0.0)
	for v in [[head, 0.22], [g0, 0.0], [g1, 0.0]]:
		st.set_color(Color(LAMP, v[1]))
		st.add_vertex(v[0])
	st.commit(am)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_disc(st, head, 1.3, 1.0, LAMP, 0.9, true)
	st.commit(am)
	for i in am.get_surface_count():
		am.surface_set_material(i, _mat())
	_lamp_mesh = am
	return am


## Adds the night lights to a car or truck model (model space: front is +Z,
## origin on the ground). Returns the holder so it can be hidden.
static func add_car_lights(node: Node3D, kind: String, glow_tex: Texture2D) -> Node3D:
	var holder := Node3D.new()
	holder.name = "NightLights"
	node.add_child(holder)
	var front := 2.2 if kind == "car" else 5.05
	var side := 0.62 if kind == "car" else 0.95
	var up := 0.62 if kind == "car" else 0.95
	if not _cones.has(kind):
		_cones[kind] = _cone(front, 22.0, 2.0, 9.0, BEAM, 0.42)
	var cone := MeshInstance3D.new()
	cone.mesh = _cones[kind]
	cone.position.y = 0.07
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cone)
	if _dot_mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.4, 0.4)
		q.material = _mat(true, glow_tex)
		q.material.albedo_color = Color(BEAM, 0)
		_mats[_mats.size() - 1][1] = 1.0
		_dot_mesh = q
		var t := QuadMesh.new()
		t.size = Vector2(0.28, 0.28)
		t.material = _mat(true, glow_tex)
		t.material.albedo_color = Color(TAIL, 0)
		_tail_mesh = t
	# Cars light their own lamp texels (car.gdshader, D-120); trucks (another
	# model) keep glow dots.
	if kind == "car":
		holder.visible = false
		return holder
	for sx in [-side, side]:
		var d := MeshInstance3D.new()
		d.mesh = _dot_mesh
		d.position = Vector3(sx, up, front + 0.05)
		holder.add_child(d)
		var tl := MeshInstance3D.new()
		tl.mesh = _tail_mesh
		tl.position = Vector3(sx * 0.95, up + 0.1, -front - 0.05)
		holder.add_child(tl)
	holder.visible = false
	return holder
