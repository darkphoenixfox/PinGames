## TURBO RUN scenery meshes (D-089): PS2-budget low-poly props built in code,
## textured from one tiny procedural 16-bit atlas (nearest filtering).
## Atlas: 5 tiles of 32x32 in a row: trunk, frond, rock, chevron, metal.
## Cel shading (D-091): toon diffuse + an inverted-hull outline surface per mesh.
extends RefCounted

const Toon = preload("res://games/racer/toon.gd")

const TILE := 32
const TILES := 5
enum T { TRUNK, FROND, ROCK, CHEVRON, METAL }

static var _material: StandardMaterial3D
static var _meshes := {}


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_texture = ImageTexture.create_from_image(_atlas())
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.roughness = 0.9
		if Toon.enabled:
			_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _material


static func mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match kind:
			"palm": _palm(st)
			"rock": _rock(st)
			"chevron": _chevron(st, false)
			"chevron_l": _chevron(st, true)
			"lamp": _lamp(st)
		st.generate_normals()
		var m := st.commit()
		m.surface_set_material(0, material())
		if Toon.enabled:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Toon.outline_arrays(m, 0))
			m.surface_set_material(1, Toon.outline_material())
		_meshes[kind] = m
	return _meshes[kind]


# --- atlas -----------------------------------------------------------------------------
static func _atlas() -> Image:
	var img := Image.create(TILE * TILES, TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for y in TILE:
		for x in TILE:
			var n := rng.randf() * 0.12
			# trunk: brown with rings
			var ring := 0.75 if y % 5 == 0 else 1.0
			img.set_pixel(x, y, Color(0.55 - n, 0.38 - n, 0.22 - n) * ring)
			# frond: green, light midrib, dark leaflet slashes
			var fx := x - TILE / 2
			var leaf := Color(0.25 - n, 0.6 - n, 0.18)
			if absi(fx) <= 1:
				leaf = Color(0.6, 0.75, 0.3)
			elif (y + absi(fx)) % 4 == 0:
				leaf = leaf.darkened(0.35)
			if absi(fx) > 13:
				leaf = leaf.darkened(0.2)
			img.set_pixel(TILE + x, y, leaf)
			# rock: grey-brown speckle
			var g := 0.5 + n * 2.0 - (0.15 if rng.randf() < 0.1 else 0.0)
			img.set_pixel(TILE * 2 + x, y, Color(g, g * 0.92, g * 0.85))
			# chevron: yellow arrows (pointing right) on black
			var cx := (x + absi(y - TILE / 2)) % 16
			var chev := Color(1.0, 0.82, 0.1) if cx < 6 else Color(0.08, 0.08, 0.08)
			if y < 2 or y > TILE - 3:
				chev = Color(0.95, 0.95, 0.95)
			img.set_pixel(TILE * 3 + x, y, chev)
			# metal
			var mtl := 0.55 + n
			img.set_pixel(TILE * 4 + x, y, Color(mtl, mtl, mtl * 1.05))
	return img


static func _uv(tile: int, u: float, v: float) -> Vector2:
	return Vector2((tile + clampf(u, 0.02, 0.98)) / TILES, clampf(v, 0.02, 0.98))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int,
		u0: float = 0.0, u1: float = 1.0, v0: float = 0.0, v1: float = 1.0) -> void:
	# a-b top edge, d-c bottom edge
	var ua := _uv(tile, u0, v0)
	var ub := _uv(tile, u1, v0)
	var uc := _uv(tile, u1, v1)
	var ud := _uv(tile, u0, v1)
	for p in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_uv(p[1])
		st.add_vertex(p[0])


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, tile: int) -> void:
	var h := size * 0.5
	var c := center
	var p := [c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z)]
	_quad(st, p[3], p[2], p[6], p[7], tile)  # front +z
	_quad(st, p[1], p[0], p[4], p[5], tile)  # back
	_quad(st, p[0], p[3], p[7], p[4], tile)  # left
	_quad(st, p[2], p[1], p[5], p[6], tile)  # right
	_quad(st, p[0], p[1], p[2], p[3], tile)  # top


# --- props -----------------------------------------------------------------------------
static func _palm(st: SurfaceTool) -> void:
	const H := 8.5
	const SEG := 6
	const SIDES := 6
	var ring_pts: Array = []
	for i in SEG + 1:
		var t := float(i) / SEG
		var c := Vector3(1.4 * t * t, H * t, 0.0)
		var r := lerpf(0.38, 0.2, t)
		var ring: Array = []
		for k in SIDES:
			var a := TAU * k / SIDES
			ring.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
		ring_pts.append(ring)
	for i in SEG:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			_quad(st, ring_pts[i + 1][k], ring_pts[i + 1][k2], ring_pts[i][k2], ring_pts[i][k], T.TRUNK,
				float(k) / SIDES, float(k + 1) / SIDES, 0.0, 1.0)
	var top := Vector3(1.4, H, 0.0)
	for f in 8:
		var a := TAU * f / 8 + 0.3
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var prev := top
		var prev_w := 0.25
		for s in 4:
			var t := float(s + 1) / 4
			var p := top + dir * 4.6 * t + Vector3(0.0, 1.0 * t - 3.2 * t * t, 0.0)
			var w := 0.9 * sin(PI * minf(t + 0.15, 1.0)) + 0.1
			_quad(st, prev - side * prev_w, prev + side * prev_w, p + side * w, p - side * w, T.FROND,
				0.0, 1.0, float(s) / 4, t)
			prev = p
			prev_w = w


static func _rock(st: SurfaceTool) -> void:
	var arr := SphereMesh.new()
	arr.radial_segments = 7
	arr.rings = 4
	var a := arr.get_mesh_arrays()
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for i in idx:
		var v := verts[i]
		var n := 0.8 + 0.35 * sin(v.x * 5.1 + v.z * 3.7) * cos(v.y * 4.3)
		st.set_uv(_uv(T.ROCK, uvs[i].x, uvs[i].y))
		st.add_vertex(Vector3(v.x * 2.2, maxf(v.y, -0.2) * 1.5 + 0.3, v.z * 1.8) * n)


## Arrows point right (+x); mirrored UVs (not a mirrored transform, which would
## flip the outline's culling) for left.
static func _chevron(st: SurfaceTool, left: bool) -> void:
	_box(st, Vector3(0.0, 0.8, 0.0), Vector3(0.14, 1.6, 0.14), T.METAL)
	var y0 := 1.4
	var y1 := 2.6
	_quad(st, Vector3(-1.3, y1, 0.08), Vector3(1.3, y1, 0.08), Vector3(1.3, y0, 0.08), Vector3(-1.3, y0, 0.08), T.CHEVRON,
		1.0 if left else 0.0, 0.0 if left else 1.0)
	_box(st, Vector3(0.0, 2.0, -0.02), Vector3(2.6, 1.2, 0.12), T.METAL)


static func _lamp(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 3.5, 0.0), Vector3(0.22, 7.0, 0.22), T.METAL)
	_box(st, Vector3(-1.1, 7.0, 0.0), Vector3(2.4, 0.16, 0.16), T.METAL)
	_box(st, Vector3(-2.2, 6.85, 0.0), Vector3(0.7, 0.2, 0.4), T.METAL)
