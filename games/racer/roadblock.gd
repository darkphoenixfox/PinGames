## TURBO RUN roadblock props (D-521): the wooden barrier that closes a middle
## lane. Two red and white planks on a pair of A-frame legs, with two orange
## lamps on top that flash in turn. The game places it across the lane, hides
## it when it is driven through and throws its splinters (ContactFx).
## The police cars of the roadblock are the game's own police model.
extends RefCounted

const TEXTURE := "res://assets/textures/racer/barrier.png"
const WIDTH := 3.6
const PLANK_H := 0.32
const PLANK_AT := [0.62, 1.05]    # heights of the two planks' middles
const LEG_H := 1.25
const LAMP_Y := 1.36
const LAMP_X := 1.35
const FLASH := 0.9               # s for both lamps to flash once, in turn
const AMBER := Color(1.0, 0.55, 0.05)

static var _plank_mat: StandardMaterial3D
static var _leg_mat: StandardMaterial3D
static var _lamp_mat: StandardMaterial3D
static var _glow_mat: StandardMaterial3D


## A barrier, across its own X, standing on its origin. `glow_tex`: the game's
## round glow. Its "lamps" meta lists the lit parts of each lamp, to flash.
static func barrier(glow_tex: Texture2D) -> Node3D:
	if _plank_mat == null:
		_plank_mat = StandardMaterial3D.new()
		_plank_mat.albedo_texture = load(TEXTURE)
		_plank_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_plank_mat.uv1_scale = Vector3(3.0, 2.0, 1.0)   # BoxMesh lays its faces out 3 x 2
		_plank_mat.emission_enabled = true              # so it reads at night, as if lit by the lamps
		_plank_mat.emission_texture = _plank_mat.albedo_texture
		_plank_mat.emission_energy_multiplier = 0.25
		_leg_mat = StandardMaterial3D.new()
		_leg_mat.albedo_color = Color(0.5, 0.38, 0.24)
		_lamp_mat = StandardMaterial3D.new()
		_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lamp_mat.albedo_color = AMBER * 3.0   # HDR: the glow picks it up
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_glow_mat.albedo_texture = glow_tex
		_glow_mat.albedo_color = AMBER
	var node := Node3D.new()
	for y in PLANK_AT:
		node.add_child(_box(Vector3(0.0, y, 0.0), Vector3(WIDTH, PLANK_H, 0.07), _plank_mat))
	for x in [-WIDTH * 0.5 + 0.35, WIDTH * 0.5 - 0.35]:
		for lean in [-1.0, 1.0]:
			var leg := _box(Vector3(x, LEG_H * 0.5, lean * 0.22), Vector3(0.09, LEG_H, 0.09), _leg_mat)
			leg.rotation.x = -lean * 0.32
			node.add_child(leg)
	var lamps := []
	for x in [-LAMP_X, LAMP_X]:
		var lamp := Node3D.new()
		lamp.position = Vector3(x, LAMP_Y, 0.0)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		sm.radial_segments = 8
		sm.rings = 4
		sm.material = _lamp_mat
		bulb.mesh = sm
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(bulb)
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		q.material = _glow_mat
		glow.mesh = q
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(glow)
		node.add_child(lamp)
		lamps.append(lamp)
	node.set_meta("lamps", lamps)
	return node


## Flashes a barrier's lamps in turn at time `t` (s).
static func flash(node: Node3D, t: float) -> void:
	var lamps: Array = node.get_meta("lamps", [])
	var ph := fmod(t, FLASH) / FLASH
	for i in lamps.size():
		(lamps[i] as Node3D).visible = (ph < 0.35) if i == 0 else (ph >= 0.5 and ph < 0.85)


static func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = at
	return mi
