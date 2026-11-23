## TURBO RUN roadside sprites (D-107, D-196): billboards in the 3D world,
## super-scaler style. Each kind is a quad (base at the origin) with one painted
## high-res cut-out from assets/sprites/racer/hd/, drawn by shaders/sprite.gdshader:
## unshaded, alpha-scissored, turned to the camera around its vertical axis.
## HD shows the art smoothly; RETRO is the shader pixelating it to the old
## sprites' resolution with banded colours. The gantry spans the road instead.
extends RefCounted

const DIR := "res://assets/sprites/racer/hd/"
const SHADER = preload("res://games/racer/shaders/sprite.gdshader")
## kind -> [file, height in metres, billboard?, flip u?, retro texels tall]
const KINDS := {
	"palm_1": ["palm_1", 11.0, true, false, 294],
	"palm_2": ["palm_2", 9.5, true, false, 224],
	"bush_1": ["bush_1", 2.6, true, false, 91],
	"bush_2": ["bush_2", 2.0, true, false, 77],
	"sign_curve": ["sign_curve", 3.6, true, false, 134],     # arrow turns right
	"sign_curve_l": ["sign_curve", 3.6, true, true, 134],    # mirrored: turns left
	"sign_green": ["sign_green", 5.5, true, false, 113],
	"gantry": ["gantry", 12.9, false, false, 151],
	"nitro": ["nitro", 2.6, true, false, 80],                # pick-up (D-115; D-208: as chunky as the other sprites)
	"speedtrap": ["speedtrap", 8.0, true, false, 126],       # speed camera (D-135; oversized like the palms, D-137)
	# Beach stage (D-204): small buildings on the right, a lifeguard tower on the sand.
	"house_1": ["house_1", 5.5, true, false, 132],
	"house_2": ["house_2", 8.0, true, false, 192],
	"house_3": ["house_3", 5.0, true, false, 120],
	"lifeguard": ["lifeguard", 6.5, true, false, 156],
	# Grass fields, stage 2 (D-204): trees instead of palms.
	"tree_oak": ["tree_oak", 10.0, true, false, 240],
	"tree_cypress": ["tree_cypress", 12.0, true, false, 288],
	# Areas (D-216): desert, forest, snowy mountain.
	"cactus_1": ["cactus_1", 5.5, true, false, 120],
	"cactus_2": ["cactus_2", 2.2, true, false, 70],
	"desert_bush": ["desert_bush", 1.6, true, false, 60],
	"mesa": ["mesa", 45.0, true, false, 300],
	"pine_1": ["pine_1", 17.0, true, false, 300],
	"pine_2": ["pine_2", 13.0, true, false, 260],
	"fern": ["fern", 1.4, true, false, 60],
	"pine_snow": ["pine_snow", 13.0, true, false, 260],
	"snow_rock": ["snow_rock", 3.0, true, false, 90],
	# Finish town (D-229): houses and spectators.
	"chalet_1": ["chalet_1", 7.5, true, false, 150],
	"chalet_2": ["chalet_2", 9.0, true, false, 170],
	"townhouse": ["townhouse", 12.0, true, false, 200],
	"crowd_1": ["crowd_1", 2.1, true, false, 70],
	"crowd_2": ["crowd_2", 2.1, true, false, 70],
	"crowd_3": ["crowd_3", 2.3, true, false, 76],
}

static var _meshes := {}
## D-195 HD graphics: smooth art; RETRO (default) pixelates it in the shader.
static var hd := false
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
		_mat(kind).set_shader_parameter("tint", Color.WHITE.lerp(NIGHT_TINT, k))


static func set_hd(on: bool) -> void:
	hd = on
	for kind in _meshes:
		_mat(kind).set_shader_parameter("retro", not hd)


static func _mat(kind: String) -> ShaderMaterial:
	return (_meshes[kind] as QuadMesh).material


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var spec: Array = KINDS[kind]
	var tex: Texture2D = load(DIR + spec[0] + ".png")
	var h: float = spec[1]
	var aspect := tex.get_width() / float(tex.get_height())
	var w := h * aspect
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("retro", not hd)
	var rt := float(spec[4])
	m.set_shader_parameter("retro_size", Vector2(maxf(1.0, roundf(rt * aspect)), rt))
	m.set_shader_parameter("billboard", spec[2])
	m.set_shader_parameter("flip", spec[3])
	m.set_shader_parameter("tint", Color.WHITE if kind in UNTINTED else Color.WHITE.lerp(NIGHT_TINT, _night))
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	q.material = m
	_meshes[kind] = q
	return q
