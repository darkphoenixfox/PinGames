## VR cabinet layout (D-164): a virtual pinball cabinet in 3D with the three
## game screens on it: the TABLE under the playfield glass, the BACKGLASS and the
## DMD in the head. The games are unchanged; they keep drawing into the Screens
## viewports, which this scene shows as textures.
##
## With an OpenXR runtime (run with `--xr-mode on`, see scripts/run_vr.ps1) the
## player stands in front of the cabinet and the controllers are the buttons:
##   triggers = flippers, grips = magna saves, right A = launch,
##   left X = start, left Y = coin, right B (hold) = exit.
## Without one it falls back to a fixed player's-eye camera (desktop preview,
## also used for screenshots).
##
## Placeholder cabinet built from boxes: replaceable by a model later. Sizes are
## real-world metres: a 43" 16:9 playfield TV (0.95 x 0.535 m) tilted 6.5
## degrees, a 32" backglass and a 4:1 DMD panel below it.
extends Node3D

const DMD_SHADER = preload("res://core/shaders/dmd_dots_3d.gdshader")

const CAB_W := 0.72               # outer width
const CAB_L := 1.32               # depth front to back
const FRONT_H := 0.88             # playfield glass height at the front edge
const TILT := deg_to_rad(6.5)
const PF := Vector2(0.535, 0.95)  # playfield screen (width, depth)
const BG := Vector2(0.71, 0.40)   # backglass screen
const DMD := Vector2(0.56, 0.14)  # DMD screen
const HEAD_DEPTH := 0.28
const STAND := 0.42               # player stands this far from the front (m)
const EYE := 1.66                 # desktop preview eye height

## Controller buttons -> cabinet actions, per hand.
const MAP := {
	"left": {"trigger_click": &"flip_l", "grip_click": &"magna_l", "ax_button": &"start", "by_button": &"coin"},
	"right": {"trigger_click": &"flip_r", "grip_click": &"magna_r", "ax_button": &"launch", "by_button": &"exit"},
}

var xr_active := false
var _controllers := {}


func build(table_tex: Texture2D, backglass_tex: Texture2D, dmd_tex: Texture2D) -> void:
	_environment()
	_cabinet(table_tex, backglass_tex, dmd_tex)
	xr_active = _start_xr()
	if not xr_active:
		_desktop_camera()


# --- XR ------------------------------------------------------------------------------
func _start_xr() -> bool:
	var xr := XRServer.find_interface("OpenXR")
	if xr == null or not xr.is_initialized():
		print("VR: no OpenXR runtime, desktop preview")
		return false
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # the headset paces frames
	var origin := XROrigin3D.new()
	origin.position = Vector3(0, 0, STAND)
	add_child(origin)
	var cam := XRCamera3D.new()
	origin.add_child(cam)
	for hand in ["left", "right"]:
		var c := XRController3D.new()
		c.tracker = "%s_hand" % hand
		c.button_pressed.connect(_on_button.bind(hand, true))
		c.button_released.connect(_on_button.bind(hand, false))
		origin.add_child(c)
		_controllers[hand] = c
		c.add_child(_hand_marker())
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	print("VR: OpenXR running")
	return true


func _on_button(button: String, hand: String, pressed: bool) -> void:
	var action: StringName = MAP[hand].get(button, &"")
	if action == &"":
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed and (action == &"flip_l" or action == &"flip_r"):
		(_controllers[hand] as XRController3D).trigger_haptic_pulse("haptic", 0.0, 0.35, 0.04, 0.0)


func _hand_marker() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.04, 0.03, 0.1)
	m.mesh = b
	m.material_override = _mat(Color(0.2, 0.2, 0.25))
	return m


func _desktop_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.position = Vector3(0, EYE, STAND + 0.05)
	cam.look_at(Vector3(0, FRONT_H + 0.25, -0.55), Vector3.UP)
	cam.current = true


# --- scene ---------------------------------------------------------------------------
func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.7)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.6, 0.8)
	light.omni_range = 6.0
	light.light_energy = 1.2
	add_child(light)
	var floor_ := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(8, 8)
	floor_.mesh = fm
	floor_.material_override = _mat(Color(0.12, 0.1, 0.12))
	add_child(floor_)


func _cabinet(table_tex: Texture2D, backglass_tex: Texture2D, dmd_tex: Texture2D) -> void:
	var body := _mat(Color(0.08, 0.08, 0.1))
	var trim := _mat(Color(0.55, 0.55, 0.6), 0.6)
	var back_z := -CAB_L
	var back_h := FRONT_H + CAB_L * tan(TILT)
	# Body: a box from the floor to the playfield, plus the sloped top rails.
	_box(Vector3(0, (FRONT_H - 0.06) * 0.5, -CAB_L * 0.5), Vector3(CAB_W, FRONT_H - 0.06, CAB_L), body)
	_box(Vector3(0, (back_h - 0.06) * 0.5 + 0.0, back_z + 0.1), Vector3(CAB_W, back_h - 0.06, 0.2), body)
	# Lockdown bar and side rails (chrome).
	_box(Vector3(0, FRONT_H + 0.02, -0.03), Vector3(CAB_W, 0.04, 0.07), trim)
	for sx in [-1.0, 1.0]:
		var rail := _box(Vector3(sx * (CAB_W * 0.5 - 0.02), (FRONT_H + back_h) * 0.5 + 0.02, -CAB_L * 0.5),
			Vector3(0.04, 0.04, CAB_L / cos(TILT)), trim)
		rail.rotation.x = TILT
	# Legs.
	for corner in [Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]:
		_box(Vector3(corner.x * (CAB_W * 0.5 - 0.05), 0.2, -0.05 - corner.y * (CAB_L - 0.1)), Vector3(0.06, 0.4, 0.06), trim)
	# Playfield screen under the glass: the TABLE, top of the image at the back.
	var pf := _screen(table_tex, PF)
	pf.position = Vector3(0, (FRONT_H + back_h) * 0.5 + 0.005, -CAB_L * 0.5)
	pf.rotation.x = -PI * 0.5 + TILT
	# Black surround between the screen and the rails.
	var surround := _box(Vector3(0, (FRONT_H + back_h) * 0.5 - 0.004, -CAB_L * 0.5),
		Vector3(CAB_W - 0.08, 0.01, CAB_L / cos(TILT) - 0.06), _mat(Color(0.01, 0.01, 0.015)))
	surround.rotation.x = TILT
	# Head: a box on the back with the backglass and the DMD below it.
	var head_h := BG.y + DMD.y + 0.16
	var head_y := back_h + head_h * 0.5 + 0.02
	_box(Vector3(0, head_y, back_z + HEAD_DEPTH * 0.5), Vector3(CAB_W + 0.04, head_h, HEAD_DEPTH), body)
	var front_z := back_z + HEAD_DEPTH + 0.002
	var bg := _screen(backglass_tex, BG)
	bg.position = Vector3(0, head_y + head_h * 0.5 - 0.04 - BG.y * 0.5, front_z)
	var dmd := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = DMD
	dmd.mesh = q
	var dm := ShaderMaterial.new()
	dm.shader = DMD_SHADER
	dm.set_shader_parameter("frame", dmd_tex)
	dmd.material_override = dm
	dmd.position = Vector3(0, bg.position.y - BG.y * 0.5 - 0.03 - DMD.y * 0.5, front_z)
	add_child(dmd)
	# Buttons: flippers + magna saves on the sides, launch on the front.
	var red := _mat(Color(0.85, 0.1, 0.1), 0.3)
	var yel := _mat(Color(0.95, 0.75, 0.1), 0.3)
	for sx in [-1.0, 1.0]:
		_button(Vector3(sx * (CAB_W * 0.5 + 0.012), FRONT_H - 0.1, -0.12), Vector3(0, 0, sx * PI * 0.5), red)
		_button(Vector3(sx * (CAB_W * 0.5 + 0.012), FRONT_H - 0.1, -0.28), Vector3(0, 0, sx * PI * 0.5), yel)
	_button(Vector3(0.2, FRONT_H - 0.12, 0.012), Vector3(PI * 0.5, 0, 0), red)


func _screen(tex: Texture2D, size: Vector2) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _button(pos: Vector3, rot: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.016
	c.bottom_radius = 0.016
	c.height = 0.02
	m.mesh = c
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	add_child(m)


func _mat(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
