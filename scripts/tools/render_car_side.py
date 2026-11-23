import bpy, sys, math
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
sc.render.resolution_x = 1024
sc.render.resolution_y = 576
sc.render.film_transparent = True
sc.render.image_settings.color_mode = 'RGBA'
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.lights.new("sun", 'SUN'); sun.energy = 3.0
so = bpy.data.objects.new("sun", sun); sc.collection.objects.link(so); so.rotation_euler = (math.radians(50), 0, math.radians(60))
cd = bpy.data.cameras.new("c"); cd.type = 'ORTHO'; cd.ortho_scale = 5.6
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
cam.location = (9.0, 0.0, 0.8)
cam.rotation_euler = (math.radians(90), 0, math.radians(90))
sc.view_settings.view_transform = 'Standard'
sc.render.filepath = a[1]
bpy.ops.render.render(write_still=True)
