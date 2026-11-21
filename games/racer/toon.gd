## TURBO RUN cel-shading helpers (D-091): inverted-hull outlines.
## An outline is a copy of the mesh drawn front-culled in flat ink and pushed out
## along smoothed normals (averaged per position, so hard edges and UV seams
## don't crack it). outline.gdshader keeps the line width roughly constant on screen.
extends RefCounted

const OUTLINE_SHADER := preload("res://games/racer/shaders/outline.gdshader")

## Off with --rc-no-toon (dev comparison against the plain look).
static var enabled := true
static var _material: ShaderMaterial


static func outline_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = OUTLINE_SHADER
	return _material


## Surface arrays (vertex + smoothed normal [+ index]) for the outline of one surface.
static func outline_arrays(mesh: Mesh, surface: int) -> Array:
	var src := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var sums := {}
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
	var smooth := PackedVector3Array()
	smooth.resize(verts.size())
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		var n: Vector3 = sums[key]
		smooth[i] = n.normalized() if n.length_squared() > 0.000001 else normals[i]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = smooth
	var idx = src[Mesh.ARRAY_INDEX]
	if idx != null and (idx as PackedInt32Array).size() > 0:
		out[Mesh.ARRAY_INDEX] = idx
	return out


## A separate mesh holding the outline of every surface of `mesh`.
static func outline_mesh(mesh: Mesh) -> ArrayMesh:
	var am := ArrayMesh.new()
	for s in mesh.get_surface_count():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, outline_arrays(mesh, s))
		am.surface_set_material(s, outline_material())
	return am
