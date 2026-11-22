## VR cabinet layout (D-164): a virtual pinball cabinet in 3D with the three
## game screens on it: the TABLE under the playfield glass, the BACKGLASS and the
## DMD in the head. The games are unchanged; they keep drawing into the Screens
## viewports, which this scene shows as textures.
##
## With an OpenXR runtime (run with `--xr-mode on`, see scripts/run_vr.ps1) the
## player stands in front of the cabinet and the controllers are the buttons:
##   triggers = flippers, grips = magna saves, right A = launch,
##   left X = start, left Y = coin, right B (hold) = exit.
## Moving around (D-168): the cabinet stands fixed in the middle of the room;
## left stick walks, right stick snap-turns, click the left stick to return to
## the front of the cabinet.
## Without one it falls back to a fixed player's-eye camera (desktop preview,
## also used for screenshots).
##
## Placeholder cabinet built from boxes: replaceable by a model later. Sizes are
## real-world metres: a 43" 16:9 playfield TV (0.95 x 0.535 m) tilted 6.5
## degrees, a 32" backglass and a 4:1 DMD panel below it.
extends Node3D

const DMD_SHADER = preload("res://core/shaders/dmd_dots_3d.gdshader")
## Director's cabinet (D-166) with its screen areas measured by
## scripts/tools/prepare_vr_cabinet.py; the box placeholder is the fallback.
const CABINET_MODEL := "res://assets/models/vr/pinball_cabinet.glb"
const CABINET_TEXTURE := "res://assets/models/vr/pinball_cabinet_albedo_clean.png"   # pink -> black glass
## Width / height of each screen's picture.
const ASPECTS := {"playfield": 1080.0 / 1920.0, "backglass": 1920.0 / 1080.0, "dmd": 4.0}
const CABINET_SCREENS := "res://assets/models/vr/pinball_cabinet_screens.json"
## Posters on the room walls: the games' backglass art.
const POSTERS := ["res://assets/textures/racer/backglass_on.png",
	"res://assets/textures/breakout/backglass_on_2screen.png"]

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
const ROOM := Vector2(5.0, 5.0)   # room width, depth (m)
const ROOM_H := 2.9
const ROOM_BACK := -3.2           # back wall z: the cabinet (z 0 .. -1.4) stands mid-room (D-168)

## Controller buttons -> cabinet actions, per hand.
const MAP := {
	"left": {"trigger_click": &"flip_l", "grip_click": &"magna_l", "ax_button": &"start", "by_button": &"coin"},
	"right": {"trigger_click": &"flip_r", "grip_click": &"magna_r", "ax_button": &"launch", "by_button": &"exit"},
}

var xr_active := false
var _controllers := {}
var _cab: Node3D            # the cabinet (fixed in the middle of the room, D-168)
var _cam: Node3D
var _origin: XROrigin3D
var _turn_ready := true     # snap turn: one step per push of the stick


func build(table_tex: Texture2D, backglass_tex: Texture2D, dmd_tex: Texture2D) -> void:
	_room()
	_cab = Node3D.new()
	add_child(_cab)
	if not _model_cabinet(table_tex, backglass_tex, dmd_tex):
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
	_origin = origin
	var cam := XRCamera3D.new()
	origin.add_child(cam)
	_cam = cam
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


# --- moving around the room (D-168) --------------------------------------------------
## The cabinet stays put in the middle of the room; the sticks move the player.
## Left stick walks (relative to where you look), right stick snap-turns 45
## degrees, clicking the left stick returns you to the spot in front of it.
const WALK_SPEED := 1.4       # m/s
const SNAP_TURN := 45.0       # degrees per push
const DEAD := 0.25


func _process(delta: float) -> void:
	if not xr_active:
		return
	var l: Vector2 = (_controllers["left"] as XRController3D).get_vector2("primary")
	var r: Vector2 = (_controllers["right"] as XRController3D).get_vector2("primary")
	if l.length() > DEAD:
		var fwd := -_cam.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var p := _origin.position + (right * l.x + fwd * l.y) * WALK_SPEED * delta
		# Stay inside the walls.
		var half := ROOM * 0.5 - Vector2(0.3, 0.3)
		var zc := ROOM_BACK + ROOM.y * 0.5
		p.x = clampf(p.x, -half.x, half.x)
		p.z = clampf(p.z, zc - half.y, zc + half.y)
		_origin.position = p
	if absf(r.x) > 0.6 and _turn_ready:
		_turn_ready = false
		_turn_around_head(-signf(r.x) * deg_to_rad(SNAP_TURN))
	elif absf(r.x) < 0.3:
		_turn_ready = true


## Turns the play space about the player's head, so they don't slide sideways.
func _turn_around_head(angle: float) -> void:
	var head := _cam.global_position
	var t := _origin.global_transform
	t.origin -= head
	t = Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO) * t
	t.origin += head
	_origin.global_transform = t


## Back to the spot in front of the cabinet, facing it.
func recenter() -> void:
	_origin.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, STAND))
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)


func _on_button(button: String, hand: String, pressed: bool) -> void:
	if button == "primary_click" and hand == "left":
		if pressed:
			recenter()
		return
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
## A basic arcade room (D-166): carpet, dark walls with pink and cyan neon
## strips, ceiling light panels, and the games' backglass art as posters. The
## cabinet stands against the back wall; the player is near the middle.
func _room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.65)
	e.ambient_light_energy = 0.35
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_hdr_threshold = 0.9
	env.environment = e
	add_child(env)
	var w := ROOM.x
	var d := ROOM.y
	var h := ROOM_H
	var zc := ROOM_BACK + d * 0.5
	_room_box(Vector3(0, -0.01, zc), Vector3(w, 0.02, d), _carpet())
	var wall := _mat(Color(0.09, 0.08, 0.12), 0.9)
	_room_box(Vector3(0, h * 0.5, ROOM_BACK - 0.05), Vector3(w, h, 0.1), wall)
	_room_box(Vector3(0, h * 0.5, ROOM_BACK + d + 0.05), Vector3(w, h, 0.1), wall)
	for sx in [-1.0, 1.0]:
		_room_box(Vector3(sx * (w * 0.5 + 0.05), h * 0.5, zc), Vector3(0.1, h, d), wall)
	_room_box(Vector3(0, h + 0.05, zc), Vector3(w, 0.1, d), _mat(Color(0.05, 0.05, 0.07)))
	# Neon strips near the ceiling: pink back and front, cyan sides.
	var pink := _glow(Color(1.0, 0.25, 0.7))
	var cyan := _glow(Color(0.2, 0.85, 1.0))
	_room_box(Vector3(0, h - 0.25, ROOM_BACK + 0.02), Vector3(w - 0.2, 0.04, 0.03), pink)
	_room_box(Vector3(0, h - 0.25, ROOM_BACK + d - 0.02), Vector3(w - 0.2, 0.04, 0.03), pink)
	for sx in [-1.0, 1.0]:
		_room_box(Vector3(sx * (w * 0.5 - 0.02), h - 0.25, zc), Vector3(0.03, 0.04, d - 0.2), cyan)
	# Ceiling light panels and their lights.
	for z in [ROOM_BACK + 1.2, ROOM_BACK + d - 1.4]:
		_room_box(Vector3(0, h - 0.01, z), Vector3(1.2, 0.02, 0.6), _glow(Color(1.0, 0.95, 0.85), 1.4))
		var l := OmniLight3D.new()
		l.position = Vector3(0, h - 0.3, z)
		l.omni_range = 5.5
		l.light_energy = 0.9
		l.light_color = Color(1.0, 0.92, 0.85)
		add_child(l)
	# Coloured fill from the neon.
	for c in [[Vector3(-w * 0.5 + 0.4, h - 0.4, zc), Color(0.2, 0.8, 1.0)], [Vector3(w * 0.5 - 0.4, h - 0.4, zc), Color(1.0, 0.3, 0.7)]]:
		var nl := OmniLight3D.new()
		nl.position = c[0]
		nl.light_color = c[1]
		nl.omni_range = 4.0
		nl.light_energy = 0.4
		add_child(nl)
	# Posters on the side walls.
	for i in POSTERS.size():
		if not ResourceLoader.exists(POSTERS[i]):
			continue
		var sx := -1.0 if i == 0 else 1.0
		var p := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 0.9)
		p.mesh = q
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = load(POSTERS[i])
		pm.roughness = 0.5
		p.material_override = pm
		p.position = Vector3(sx * (w * 0.5 - 0.01), 1.6, ROOM_BACK + 1.6)
		p.rotation.y = -sx * PI * 0.5
		add_child(p)


func _room_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	add_child(m)


func _glow(c: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Arcade carpet: a dark tile with scattered neon dashes, nearest-filtered.
func _carpet() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.04, 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cols := [Color(0.9, 0.2, 0.6), Color(0.2, 0.8, 0.95), Color(0.95, 0.8, 0.2), Color(0.4, 0.3, 0.9)]
	for i in 40:
		var c: Color = cols[i % cols.size()]
		var x := rng.randi_range(0, 60)
		var y := rng.randi_range(0, 60)
		match i % 3:
			0:
				for k in 4:
					img.set_pixel((x + k) % 64, y, c)
			1:
				for k in 4:
					img.set_pixel(x, (y + k) % 64, c)
			_:
				img.set_pixel(x, y, c)
				img.set_pixel((x + 1) % 64, (y + 1) % 64, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(ROOM.x / 1.2, ROOM.y / 1.2, 1)
	m.roughness = 1.0
	return m


func _fit(box: Vector2, aspect: float) -> Vector2:
	if box.x / box.y > aspect:
		return Vector2(box.y * aspect, box.y)
	return Vector2(box.x, box.x / aspect)


## The director's cabinet model with the live screens laid on its pink areas.
func _model_cabinet(table_tex: Texture2D, backglass_tex: Texture2D, dmd_tex: Texture2D) -> bool:
	if not ResourceLoader.exists(CABINET_MODEL) or not FileAccess.file_exists(CABINET_SCREENS):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(CABINET_SCREENS))
	if not data is Dictionary:
		return false
	# The model sits a few degrees turned (D-166): a holder turns it (and the
	# screens) so the playfield points straight at the player, centred on X.
	var holder := Node3D.new()
	_cab.add_child(holder)
	var pr: Array = data.playfield.right
	holder.rotation.y = atan2(float(pr[2]), float(pr[0]))
	var pc: Array = data.playfield.centre
	var pf_c := holder.basis * Vector3(pc[0], pc[1], pc[2])
	holder.position.x = -pf_c.x
	var model: Node3D = (load(CABINET_MODEL) as PackedScene).instantiate()
	holder.add_child(model)
	if ResourceLoader.exists(CABINET_TEXTURE):
		var cm := StandardMaterial3D.new()
		cm.albedo_texture = load(CABINET_TEXTURE)
		cm.roughness = 0.6
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = cm
	for key in ["playfield", "backglass", "dmd"]:
		if not data.has(key):
			continue
		var r: Dictionary = data[key]
		# Fit the picture inside the visible opening at its own aspect (D-167):
		# nothing cut, black bars where the shapes differ.
		var size := _fit(Vector2(r.size[0], r.size[1]), ASPECTS[key])
		var m: MeshInstance3D
		if key == "dmd":
			m = MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = size
			m.mesh = q
			var dm := ShaderMaterial.new()
			dm.shader = DMD_SHADER
			dm.set_shader_parameter("frame", dmd_tex)
			m.material_override = dm
		else:
			m = _screen(table_tex if key == "playfield" else backglass_tex, size)
			m.get_parent().remove_child(m)
		holder.add_child(m)
		var right := Vector3(r.right[0], r.right[1], r.right[2])
		var up := Vector3(r.up[0], r.up[1], r.up[2])
		var n := Vector3(r.normal[0], r.normal[1], r.normal[2])
		var c := Vector3(r.centre[0], r.centre[1], r.centre[2])   # already lifted clear (D-167)
		m.transform = Transform3D(Basis(right, up, n), c)
	return true


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
	_cab.add_child(dmd)
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
	_cab.add_child(m)
	return m


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	_cab.add_child(m)
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
	_cab.add_child(m)


func _mat(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
