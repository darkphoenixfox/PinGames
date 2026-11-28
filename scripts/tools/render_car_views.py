# Orthographic rear, side and top renders of a car model with its texture, unlit,
# to measure lamps and other parts in model space (D-481).
# Run: blender -b --python scripts/tools/render_car_views.py -- <model.glb> <albedo> <out dir> <name>
# Each picture is 2048 x 1536. Rear: 2.6 m wide (787.7 px/m), centre x 0, y 0.85,
# picture right = model -X. Side and top: 5.6 m wide (365.7 px/m; 11 m for
# models longer than 6 m); side: right = rear (-Z), centre y 0.85; top: up = rear.
import bpy, sys, math, mathutils
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
sc = bpy.context.scene
img = bpy.data.images.load(a[1])
length = 0.0
for o in sc.objects:
    if o.type != 'MESH':
        continue
    m = bpy.data.materials.new("flat"); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img
    e = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(t.outputs[0], e.inputs[0]); nt.links.new(e.outputs[0], out.inputs[0])
    o.data.materials.clear(); o.data.materials.append(m)
    bb = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    print("BB %s x %.3f %.3f  z(model) %.3f %.3f  y %.3f %.3f" % (a[3], min(v.x for v in bb), max(v.x for v in bb),
        -max(v.y for v in bb), -min(v.y for v in bb), min(v.z for v in bb), max(v.z for v in bb)))
    length = max(length, max(v.y for v in bb) - min(v.y for v in bb))
    rear = max(v.y for v in bb)
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
sc.render.resolution_x = 2048; sc.render.resolution_y = 1536
sc.render.film_transparent = True
sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'
cd = bpy.data.cameras.new("c"); cd.type = 'ORTHO'
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
R = math.radians
wide = 11.0 if length > 6.0 else 5.6
views = {
    "rear": ((0, rear + 5.0, 0.85), (R(90), 0, R(180)), 2.6),
    "side": ((9, 0, 0.85), (R(90), 0, R(90)), wide),
    "top": ((0, 0, 9), (0, 0, 0), wide),
}
for k, (loc, rot, s) in views.items():
    cam.location = loc; cam.rotation_euler = rot; cd.ortho_scale = s
    sc.render.filepath = a[2] + "/" + a[3] + "_" + k + ".png"
    bpy.ops.render.render(write_still=True)
