## TURBO RUN roadside sprites (D-107): pixel-art billboards in the 3D world,
## super-scaler style. Each kind is a quad (base at the origin) textured with a
## Qwen-Image sprite from assets/sprites/racer/, drawn unshaded (the sunset light
## is painted in), alpha-scissored, nearest-filtered, and turned to face the
## camera around its vertical axis. The gantry spans the road instead.
extends RefCounted

const DIR := "res://assets/sprites/racer/"
## kind -> [file, height in metres, billboard?, flip u?]
const KINDS := {
	"palm_1": ["palm_1", 11.0, true, false],
	"palm_2": ["palm_2", 9.5, true, false],
	"bush_1": ["bush_1", 2.6, true, false],
	"bush_2": ["bush_2", 2.0, true, false],
	"sign_curve": ["sign_curve", 3.6, true, false],     # arrow turns right
	"sign_curve_l": ["sign_curve", 3.6, true, true],    # mirrored: turns left
	"sign_green": ["sign_green", 5.5, true, false],
	"gantry": ["gantry", 12.9, false, false],
	"nitro": ["nitro", 2.6, true, false],               # pick-up (D-115)
	"speedtrap": ["speedtrap", 4.2, true, false],       # speed camera (D-135)
}

static var _meshes := {}
## Moonlit tint for the pre-lit sprites at night (D-113).
const NIGHT_TINT := Color(0.3, 0.34, 0.58)
static var _night := 0.0
## Kinds that stay bright at night (pick-ups must stay readable).
const UNTINTED := ["nitro"]


## Darkens every sprite towards the night tint (0 = day, 1 = night).
static func set_night(k: float) -> void:
	_night = k
	for kind in _meshes:
		if kind in UNTINTED:
			continue
		var m: StandardMaterial3D = (_meshes[kind] as QuadMesh).material
		m.albedo_color = Color.WHITE.lerp(NIGHT_TINT, k)


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var spec: Array = KINDS[kind]
	var tex: Texture2D = load(DIR + spec[0] + ".png")
	var h: float = spec[1]
	var w := h * tex.get_width() / float(tex.get_height())
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if spec[2]:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
	if spec[3]:
		m.uv1_scale = Vector3(-1, 1, 1)
		m.uv1_offset = Vector3(1, 0, 0)
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	m.albedo_color = Color.WHITE if kind in UNTINTED else Color.WHITE.lerp(NIGHT_TINT, _night)
	q.material = m
	_meshes[kind] = q
	return q
