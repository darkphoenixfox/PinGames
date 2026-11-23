## Measures a Turbo Run car model (D-205) for its per-model settings: which way
## its nose points, the tail and head lamp areas (bright red / bright white
## texels at each end), the exhaust tips (lowest rear-most geometry) and the
## axles (centres of the low geometry at the sides). Model space, metres.
## Run: <godot> --headless --path . --script scripts/tools/measure_racer_car.gd -- <model.glb> <albedo.png>
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: Node = (load(args[0]) as PackedScene).instantiate()
	var img := (load(args[1]) as Texture2D).get_image()
	img.decompress()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var aabb := mi.mesh.get_aabb()
	print("aabb ", aabb)
	var zmin := aabb.position.z
	var zmax := aabb.end.z
	var len := zmax - zmin
	var red_lo := [Vector3.INF, -Vector3.INF]
	var red_hi := [Vector3.INF, -Vector3.INF]
	var white_lo := [Vector3.INF, -Vector3.INF]
	var white_hi := [Vector3.INF, -Vector3.INF]
	var n_red := [0, 0]
	var n_white := [0, 0]
	for i in verts.size():
		var v := verts[i]
		var end := -1
		if v.z < zmin + len * 0.12:
			end = 0
		elif v.z > zmax - len * 0.12:
			end = 1
		if end < 0:
			continue
		var uv := uvs[i]
		var c := img.get_pixel(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1),
			clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
		var p := Vector3(absf(v.x), v.y, v.z)
		if c.r > 0.55 and c.r > c.g * 2.0 and c.r > c.b * 2.0 and v.y > 0.35:
			n_red[end] += 1
			var b: Array = red_lo if end == 0 else red_hi
			b[0] = b[0].min(p)
			b[1] = b[1].max(p)
		elif c.r > 0.75 and c.g > 0.75 and c.b > 0.7 and v.y > 0.35:
			n_white[end] += 1
			var b: Array = white_lo if end == 0 else white_hi
			b[0] = b[0].min(p)
			b[1] = b[1].max(p)
	print("red lamp texels  at -z end: %d %s   at +z end: %d %s" % [n_red[0], str(red_lo), n_red[1], str(red_hi)])
	print("white lamp texels at -z end: %d %s   at +z end: %d %s" % [n_white[0], str(white_lo), n_white[1], str(white_hi)])
	# Exhaust tips: the lowest rear-most geometry at each end.
	for end in [0, 1]:
		var pts: Array = []
		for v in verts:
			var at_end := v.z < zmin + 0.12 if end == 0 else v.z > zmax - 0.12
			if at_end and v.y < 0.55:
				pts.append(v)
		var xs := {}
		for v in pts:
			var bucket := int(roundf(v.x * 5.0))
			xs[bucket] = int(xs.get(bucket, 0)) + 1
		print("low end-most geometry at %s end: %d verts, by x (0.2 m buckets): %s" % ["-z" if end == 0 else "+z", pts.size(), str(xs)])
	# Axles: low vertices at the sides, split front/back.
	for half in [-1.0, 1.0]:
		var sum := Vector3.ZERO
		var n := 0
		var top := 0.0
		for v in verts:
			if absf(v.x) > aabb.size.x * 0.32 and v.y < 0.75 and signf(v.z) == half and absf(v.z) > len * 0.15:
				sum += Vector3(absf(v.x), v.y, v.z)
				n += 1
				top = maxf(top, v.y)
		if n > 0:
			print("wheel region z%s: centre %s over %d verts, top y %.2f" % ["+" if half > 0 else "-", str(sum / n), n, top])
	quit()
