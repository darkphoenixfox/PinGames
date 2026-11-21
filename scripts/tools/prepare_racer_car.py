"""PS2-style car model for Turbo Run (D-089): decimate, 256 px base colour,
no normal/ORM maps, length along -Z in Godot, 4.4 m long, origin at the wheels.
Also writes <out>_albedo.png (the 256 px texture the game samples).
Usage: blender --background --python scripts/tools/prepare_racer_car.py -- <in.glb> <out.glb> [tris]
"""
import bpy, sys, math, os
from mathutils import Vector, Matrix
args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
target = int(args[2]) if len(args) > 2 else 4000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.data.objects if o.type == 'MESH'][0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
mod = obj.modifiers.new("dec", 'DECIMATE')
mod.ratio = min(1.0, target / max(1, tris))
bpy.ops.object.modifier_apply(modifier="dec")
# Length along Blender X -> along +Y (glTF -Z = Godot forward). Mesh data is
# transformed directly (transform_apply left stale bounds in background mode).
me = obj.data
me.transform(Matrix.Rotation(math.radians(90), 4, 'Z'))
ys = [v.co.y for v in me.vertices]
s = 4.4 / (max(ys) - min(ys))
me.transform(Matrix.Scale(s, 4))
xs = [v.co.x for v in me.vertices]
ys = [v.co.y for v in me.vertices]
zs = [v.co.z for v in me.vertices]
me.transform(Matrix.Translation((-(max(xs) + min(xs)) / 2, -(max(ys) + min(ys)) / 2, -min(zs))))
me.update()
# 16-bit look: small base colour, nothing else.
mat = obj.data.materials[0]
nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'][0]
for inp in ("Normal", "Metallic", "Roughness"):
    for l in list(bsdf.inputs[inp].links):
        nt.links.remove(l)
bsdf.inputs["Metallic"].default_value = 0.2
bsdf.inputs["Roughness"].default_value = 0.45
for n in list(nt.nodes):
    if n.type == 'TEX_IMAGE' and not any(l.to_socket == bsdf.inputs["Base Color"] for l in n.outputs[0].links):
        nt.nodes.remove(n)
for n in nt.nodes:
    if n.type == 'TEX_IMAGE':
        n.interpolation = 'Closest'
        n.image.scale(256, 256)
        # Also saved as a separate PNG: the game samples it directly (nearest).
        n.image.filepath_raw = os.path.abspath(dst).replace(".glb", "_albedo.png")
        n.image.file_format = 'PNG'
        n.image.save()
print("TRIS", sum(len(p.vertices) - 2 for p in obj.data.polygons), "DIM", [round(max(v.co[i] for v in me.vertices) - min(v.co[i] for v in me.vertices), 2) for i in range(3)])
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=92)
