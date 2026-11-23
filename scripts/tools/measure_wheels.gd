## Measures each wheel of a Turbo Run car model (D-250) from its rim: vertices
## low at the sides whose texture is light, unsaturated grey (the rim). A rim
## is a symmetric disc, so their centroid is the wheel centre and their reach
## the rim radius; the tyre's bottom (the lowest side vertex) gives the tyre
## radius. Front and rear separately.
## Run: <godot> --headless --path . --script scripts/tools/measure_wheels.gd -- <model.glb> <albedo.png>
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
	for zs in [1.0, -1.0]:
		var sum := Vector2.ZERO
		var n := 0
		var pts: Array = []
		var maxx := 0.0
		for i in verts.size():
			var v := verts[i]
			if absf(v.x) < 0.7 or v.y > 0.85 or signf(v.z) != zs or absf(v.z) < 0.5:
				continue
			var uv := uvs[i]
			var c := img.get_pixel(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1),
				clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
			if c.s < 0.18 and c.v > 0.45:
				sum += Vector2(v.z, v.y)
				n += 1
				pts.append(v)
				maxx = maxf(maxx, absf(v.x))
		if n == 0:
			print("no rim found")
			continue
		var ctr := sum / n
		var rr := 0.0
		for v in pts:
			rr = maxf(rr, Vector2(v.z, v.y).distance_to(ctr))
		print("%s wheel: centre z %.3f y %.3f  rim radius %.3f  rim face |x| %.3f  (%d rim verts)" % [
			"front" if zs > 0 else "rear", ctr.x, ctr.y, rr, maxx, n])
	quit()
