"""VR cabinet model (D-166): the director's pinball cabinet, whose three screen
areas are painted pink, prepared for the game.

- Finds the pink faces (sampled from the texture at each face's UV centre),
  splits them into the playfield, backglass and DMD (by height and facing).
- Turns the cabinet so the backglass faces the player (Godot +Z), centres it
  on X, puts its feet on the floor and its front edge at Z = 0.
- Writes assets/models/vr/pinball_cabinet.glb (texture scaled to 2048) and
  a first pinball_cabinet_screens.json. The final placement is measured in
  Godot's own space by scripts/tools/measure_vr_cabinet.gd: run it after this,
  once Godot has imported the model.
Usage: blender --background --python scripts/tools/prepare_vr_cabinet.py -- <in.glb> <out_dir>
"""
import bpy, sys, os, json, math
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
src, out_dir = args[0], args[1]
os.makedirs(out_dir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.data.objects if o.type == 'MESH'][0]
me = obj.data
me.transform(obj.matrix_world)
obj.matrix_world = Matrix.Identity(4)

mat = me.materials[0]
img = [n for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE'][0].image
W, H = img.size
px = list(img.pixels)
uvl = me.uv_layers.active.data


def color_at(u, v):
    x = min(W - 1, max(0, int((u % 1.0) * W)))
    y = min(H - 1, max(0, int((v % 1.0) * H)))
    i = (y * W + x) * 4
    return px[i], px[i + 1], px[i + 2]


def is_pink(c):
    r, g, b = c
    return r > 0.45 and b > 0.45 and g < 0.3 and abs(r - b) < 0.35


pink = []
for f in me.polygons:
    u = sum(uvl[li].uv.x for li in f.loop_indices) / f.loop_total
    v = sum(uvl[li].uv.y for li in f.loop_indices) / f.loop_total
    if is_pink(color_at(u, v)):
        pink.append(f)
print("PINK faces", len(pink))

# Facing: the backglass/DMD faces are near-vertical; the playfield is near-flat.
flat = [f for f in pink if abs(f.normal.z) > 0.6]
upright = [f for f in pink if abs(f.normal.z) <= 0.6]
front_dir = Vector((0, 0, 0))
for f in upright:
    front_dir += f.normal * f.area
front_dir.z = 0
front_dir.normalize()
print("FRONT", front_dir)

# Turn so the screens face Blender -Y (= Godot +Z, towards the player).
ang = -math.atan2(front_dir.x, -front_dir.y)   # rotate the front onto -Y
rot = Matrix.Rotation(ang, 4, 'Z')
me.transform(rot)
me.update()
xs = [v.co.x for v in me.vertices]
ys = [v.co.y for v in me.vertices]
zs = [v.co.z for v in me.vertices]
me.transform(Matrix.Translation((-(max(xs) + min(xs)) / 2, -min(ys), -min(zs))))
me.update()


class Face:
    """A face with its normal/centre/area computed from the moved vertices
    (Blender's cached polygon normals can be stale after mesh.transform)."""
    def __init__(self, poly):
        self.index = poly.index
        self.vertices = list(poly.vertices)
        co = [me.vertices[i].co for i in self.vertices]
        self.center = sum(co, Vector((0, 0, 0))) / len(co)
        n = Vector((0, 0, 0))
        for k in range(1, len(co) - 1):
            n += (co[k] - co[0]).cross(co[k + 1] - co[0])
        self.area = n.length * 0.5
        self.normal = n.normalized() if n.length > 0 else Vector((0, 0, 1))

# After the turn: front-facing faces (normal towards -Y) are the backglass and
# DMD; the playfield is the tilted, upward-facing pink in the lower half. Stray
# pink on edges and the head top is ignored.
idx = [f.index for f in pink]
polys = [Face(me.polygons[i]) for i in idx]
hz = max(v.co.z for v in me.vertices)
flat = [f for f in polys if f.normal.z > 0.6 and f.center.z < hz * 0.65]
depth = max(v.co.y for v in me.vertices)
front = [f for f in polys if f.normal.y < -0.7 and f.center.y > depth * 0.5]   # in the head, at the back
# Group front faces into height bands (a new band where there's a vertical gap
# of more than 3 cm); the biggest band by area is the backglass, the second the
# DMD. Small stray pink patches end up in bands of their own and are ignored.
spans = sorted(((min(me.vertices[i].co.z for i in f.vertices), max(me.vertices[i].co.z for i in f.vertices), f) for f in front),
               key=lambda t: t[0])
bands, top = [], -1e9
for lo, hi, f in spans:
    if not bands or lo - top > 0.03:
        bands.append([])
    bands[-1].append(f)
    top = max(top, hi)
bands.sort(key=lambda b: sum(f.area for f in b), reverse=True)
print("BANDS", [(round(min(f.center.z for f in b), 2), round(sum(f.area for f in b), 4)) for b in bands[:4]])
regions = {"playfield": flat, "backglass": bands[0], "dmd": bands[1]}


def to_godot(v):
    return [round(v.x, 5), round(v.z, 5), round(-v.y, 5)]


out = {}
for name, faces in regions.items():
    n = Vector((0, 0, 0))
    for f in faces:
        n += f.normal * f.area
    n.normalize()
    if name == "playfield":
        up_hint = Vector((0, 1, 0))      # towards the back (Blender +Y)
    else:
        up_hint = Vector((0, 0, 1))
    up = (up_hint - n * up_hint.dot(n)).normalized()
    right = up.cross(n).normalized()
    # Keep only faces on the dominant plane (area-weighted median along the
    # normal): stray pink elsewhere (head insides, edges) would skew it.
    fd = sorted(((f.center.dot(n), f.area) for f in faces), key=lambda t: t[0])
    tot = sum(a for _, a in fd)
    acc, plane = 0.0, fd[0][0]
    for dval, a in fd:
        acc += a
        if acc >= tot * 0.5:
            plane = dval
            break
    # Extents from all the region's faces (the plane filter trims the ends of a
    # slightly curved/stepped screen area), outliers trimmed below.
    pts = [me.vertices[i].co for f in faces for i in f.vertices]
    rs = sorted(p.dot(right) for p in pts)
    us = sorted(p.dot(up) for p in pts)
    k = max(1, len(rs) // 500)          # trim 0.2 % outliers each side
    rs, us = rs[k:-k], us[k:-k]
    c = right * ((max(rs) + min(rs)) / 2) + up * ((max(us) + min(us)) / 2) + n * plane
    out[name] = {"centre": to_godot(c), "right": to_godot(right), "up": to_godot(up),
                 "normal": to_godot(n), "size": [round(max(rs) - min(rs), 4), round(max(us) - min(us), 4)]}
    print("REGION", name, len(faces), out[name]["size"], out[name]["centre"])

out["bounds"] = {"width": round(max(xs) - min(xs), 3), "depth": round(max(ys) - min(ys), 3), "height": round(max(zs) - min(zs), 3)}
with open(os.path.join(out_dir, "pinball_cabinet_screens.json"), "w") as fh:
    json.dump(out, fh, indent=1)

img.scale(2048, 2048)
# Also as a PNG: Godot didn't decode the glb's embedded JPEG (as with the car).
img.filepath_raw = os.path.abspath(os.path.join(out_dir, "pinball_cabinet_albedo.png"))
img.file_format = 'PNG'
img.save()
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "pinball_cabinet.glb"), export_format='GLB',
                          export_image_format='JPEG', export_jpeg_quality=90)
print("DONE")
