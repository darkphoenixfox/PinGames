## Measures the VR cabinet's screen areas (D-166) in Godot's own space: loads
## the imported model and its albedo, finds the pink triangles, splits them into
## playfield / backglass / DMD, and writes their centre, axes and size to
## assets/models/vr/pinball_cabinet_screens.json (read by core/vr_cabinet.gd),
## plus a copy of the albedo with the pink turned to black glass.
## Run: godot --headless --path . --script scripts/tools/measure_vr_cabinet.gd
extends SceneTree

const MODEL := "res://assets/models/vr/pinball_cabinet.glb"
const ALBEDO := "res://assets/models/vr/pinball_cabinet_albedo.png"
const OUT := "res://assets/models/vr/pinball_cabinet_screens.json"
const CLEAN := "res://assets/models/vr/pinball_cabinet_albedo_clean.png"


func _init() -> void:
	var n: Node3D = (load(MODEL) as PackedScene).instantiate()
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var img: Image = (load(ALBEDO) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var aabb := mi.mesh.get_aabb()
	_verts = vs
	var tris: Array = []   # [centre, normal, area, a, b, c]
	for t in range(0, idx.size(), 3):
		var a := vs[idx[t]]
		var b := vs[idx[t + 1]]
		var c := vs[idx[t + 2]]
		var uv := (uvs[idx[t]] + uvs[idx[t + 1]] + uvs[idx[t + 2]]) / 3.0
		var col := img.get_pixel(clampi(int(fposmod(uv.x, 1.0) * w), 0, w - 1), clampi(int(fposmod(uv.y, 1.0) * h), 0, h - 1))
		if not (col.r > 0.45 and col.b > 0.45 and col.g < 0.3 and absf(col.r - col.b) < 0.35):
			continue
		var cr := (c - a).cross(b - a)   # Godot front faces wind clockwise
		if cr.length() < 1e-9:
			continue
		tris.append([(a + b + c) / 3.0, cr.normalized(), cr.length() * 0.5, a, b, c])
		for k in 3:
			_pink[idx[t + k]] = true
	print("pink tris ", tris.size())
	var top_y := aabb.position.y + aabb.size.y
	var back_z := aabb.position.z
	var flat := tris.filter(func(t): return t[1].y > 0.6 and t[0].y < top_y * 0.65)
	var front := tris.filter(func(t): return t[1].z > 0.7 and t[0].z < back_z * 0.5)
	# Height bands of the front faces: biggest = backglass, second = DMD.
	front.sort_custom(func(p, q): return minf(p[3].y, minf(p[4].y, p[5].y)) < minf(q[3].y, minf(q[4].y, q[5].y)))
	var bands: Array = []
	var top := -1e9
	for t in front:
		var lo: float = minf(t[3].y, minf(t[4].y, t[5].y))
		if bands.is_empty() or lo - top > 0.03:
			bands.append([])
		bands[-1].append(t)
		top = maxf(top, maxf(t[3].y, maxf(t[4].y, t[5].y)))
	bands.sort_custom(func(p, q): return _area(p) > _area(q))
	var out := {"bounds": {"width": aabb.size.x, "depth": aabb.size.z, "height": aabb.size.y}}
	out["playfield"] = _region(flat, Vector3(0, 0, -1))
	if bands.size() > 0:
		out["backglass"] = _region(bands[0], Vector3.UP)
	if bands.size() > 1:
		out["dmd"] = _region(bands[1], Vector3.UP)
	for k in ["playfield", "backglass", "dmd"]:
		if out.has(k):
			print(k, " size ", out[k].size, " centre ", out[k].centre)
	# A clean texture for the game: pink (the screen mask) becomes black glass,
	# so any sliver the screens don't cover reads as bezel, not pink.
	var clean := img.duplicate() as Image
	for y in clean.get_height():
		for x in clean.get_width():
			var pc := clean.get_pixel(x, y)
			if pc.r > 0.45 and pc.b > 0.45 and pc.g < 0.3 and absf(pc.r - pc.b) < 0.35:
				clean.set_pixel(x, y, Color(0.02, 0.02, 0.03))
	clean.save_png(CLEAN)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	quit()


## Trimmed extents [rmin, rmax, umin, umax] of 2D points in axes rotated by a.
func _extents(pts: Array, a: float) -> Array:
	var ca := cos(a)
	var sa := sin(a)
	var rs: Array = []
	var us: Array = []
	for p in pts:
		var v: Vector2 = p
		# Same sense as Vector3.rotated(n, a) on (right, up).
		rs.append(v.x * ca + v.y * sa)
		us.append(-v.x * sa + v.y * ca)
	rs.sort()
	us.sort()
	var cut := maxi(1, rs.size() / 500)
	return [rs[cut], rs[rs.size() - 1 - cut], us[cut], us[us.size() - 1 - cut]]


var _verts: PackedVector3Array
var _pink := {}   # vertex indices that belong to pink (screen) triangles


func _area(list: Array) -> float:
	var s := 0.0
	for t in list:
		s += t[2]
	return s


func _region(list: Array, up_hint: Vector3) -> Dictionary:
	var n := Vector3.ZERO
	for t in list:
		n += t[1] * t[2]
	n = n.normalized()
	var up := (up_hint - n * up_hint.dot(n)).normalized()
	var right := up.cross(n).normalized()
	# Plane: area-weighted median along the normal.
	var ds: Array = []
	for t in list:
		ds.append([(t[0] as Vector3).dot(n), t[2]])
	ds.sort_custom(func(p, q): return p[0] < q[0])
	var total := _area(list)
	var acc := 0.0
	var plane: float = ds[0][0]
	for e in ds:
		acc += e[1]
		if acc >= total * 0.5:
			plane = e[0]
			break
	# The screen's own rotation within its plane (D-166): try angles and keep
	# the tightest-fitting rectangle (the model isn't square to the axes).
	var pts: Array = []
	for t in list:
		for k in [3, 4, 5]:
			var p3: Vector3 = t[k]
			pts.append(Vector2(p3.dot(right), p3.dot(up)))
	var best := INF
	var best_a := 0.0
	var a := -0.35
	while a <= 0.35:
		var ext := _extents(pts, a)
		var area: float = (ext[1] - ext[0]) * (ext[3] - ext[2])
		if area < best:
			best = area
			best_a = a
		a += 0.0025
	var r2 := right.rotated(n, best_a)
	var u2 := up.rotated(n, best_a)
	right = r2
	up = u2
	var e := _extents(pts, best_a)
	var r0: float = e[0]
	var r1: float = e[1]
	var u0: float = e[2]
	var u1: float = e[3]
	# Visible opening (D-167): the pink runs under the bezel lips. Cabinet
	# geometry standing above the screen surface near an edge pushes that edge
	# inwards, so the game can fit the picture inside what's actually visible.
	var i0 := r0
	var i1 := r1
	var j0 := u0
	var j1 := u1
	var band_r := (r1 - r0) * 0.15
	var band_u := (u1 - u0) * 0.15
	for vi in _verts.size():
		if _pink.has(vi):
			continue   # the pink itself curves up a little at its edges
		var vv: Vector3 = _verts[vi]
		var dn := vv.dot(n) - plane
		if dn < 0.002 or dn > 0.05:   # bezel lips, not the head overhanging the back
			continue
		var pr := vv.dot(right)
		var pu := vv.dot(up)
		if pr < r0 or pr > r1 or pu < u0 or pu > u1:
			continue
		# A point limits a side only away from the corners, so a rail running the
		# full length of one side doesn't also cut the ends (and vice versa).
		var mid_u := pu > u0 + band_u and pu < u1 - band_u
		var mid_r := pr > r0 + band_r and pr < r1 - band_r
		if mid_u and pr < r0 + band_r:
			i0 = maxf(i0, pr)
		elif mid_u and pr > r1 - band_r:
			i1 = minf(i1, pr)
		if mid_r and pu < u0 + band_u:
			j0 = maxf(j0, pu)
		elif mid_r and pu > u1 - band_u:
			j1 = minf(j1, pu)
	# Lay the screen just above the highest point of its pink area (D-167): the
	# pink rises ~1 cm at its edges, which poked through a screen laid on the
	# average plane and hid the picture's edges.
	var tops: Array = []
	for t in list:
		for k in [3, 4, 5]:
			tops.append((t[k] as Vector3).dot(n))
	tops.sort()
	var top_d: float = tops[tops.size() - 1 - maxi(1, tops.size() / 500)]
	var lift := minf(top_d - plane, 0.025)   # capped: deep stray faces would float it off
	var c := right * (i0 + i1) * 0.5 + up * (j0 + j1) * 0.5 + n * (plane + lift + 0.002)
	print("  raised ", snappedf(lift * 1000.0, 0.1), " mm above the plane")
	print("  opening ", [i1 - i0, j1 - j0], " of ", [r1 - r0, u1 - u0], " insets L R B T ", [i0 - r0, r1 - i1, j0 - u0, u1 - j1])
	return {"centre": [c.x, c.y, c.z], "right": [right.x, right.y, right.z], "up": [up.x, up.y, up.z],
		"normal": [n.x, n.y, n.z], "size": [i1 - i0, j1 - j0]}
