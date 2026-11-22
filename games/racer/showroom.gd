## TURBO RUN car select showroom (D-122): the three cars stacked down the
## portrait TABLE, each on a turntable, spinning in stepped sprite-like angles,
## with its stats underneath. Rendered at the pixel resolution through the same
## palette/dither pass as the race. The game feeds input and reads `selected`.
extends Control

const UI = preload("res://core/ui/ui.gd")
const Sim = preload("res://games/racer/sim.gd")
const PIXEL_POST = preload("res://games/racer/shaders/pixel_post.gdshader")

const RES := Vector2i(360, 640)
const ROW_Y := [5.4, 0.0, -5.4]      # car heights in the showroom (m), top to bottom
const SPIN := 0.9                     # rad/s (the chosen car spins faster)
const SPRITE_ANGLES := 32
const PIPS := 5
const PANEL_W := 600.0
const ROW_COLS := [Color("4fff7a"), Color("ffd23e"), Color("ff3b4f")]   # easy, normal, hard

var selected := Sim.DEFAULT_CAR
var _vp: SubViewport
var _cam: Camera3D
var _cars: Array = []
var _rings: Array = []
var _ring_mat_on: StandardMaterial3D
var _ring_mat_off: StandardMaterial3D
var _boxes: Array = []
var _t := 0.0
var _angles := [0.6, 2.2, 4.0]


## make_car: Callable(hue) -> Node3D (the game's car instance with its outline).
func build(make_car: Callable, sky_tex: Texture2D, title_font: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.size = RES
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = true
	add_child(_vp)
	# Backdrop: the race's sunset sky, whole, behind the 3D view.
	var sky := TextureRect.new()
	sky.texture = sky_tex
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var root := Node3D.new()
	_vp.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.65, 0.8)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.light_energy = 1.1
	root.add_child(sun)
	_ring_mat_on = _ring_mat(Color(1.0, 0.82, 0.25), 2.0)
	_ring_mat_off = _ring_mat(Color(0.35, 0.35, 0.45), 0.0)
	for i in 3:
		var y: float = ROW_Y[i]
		var table := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.7
		cyl.bottom_radius = 2.8
		cyl.height = 0.18
		cyl.radial_segments = 32
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.22, 0.22, 0.28)
		cyl.material = tm
		table.mesh = cyl
		table.position = Vector3(0, y - 0.09, 0)
		root.add_child(table)
		var ring := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 2.95
		rc.bottom_radius = 2.95
		rc.height = 0.08
		rc.radial_segments = 32
		ring.mesh = rc
		ring.position = Vector3(0, y - 0.16, 0)
		root.add_child(ring)
		_rings.append(ring)
		var car: Node3D = make_car.call(float(Sim.CARS[i].hue))
		car.position = Vector3(0, y, 0)
		root.add_child(car)
		_cars.append(car)
	# Orthographic, looking down from the front: every row is seen from above
	# at the same angle, like a sprite showcase.
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 9.6
	_cam.position = Vector3(0, 7.0, 14.0)
	root.add_child(_cam)
	_cam.look_at(Vector3(0, -0.4, 0), Vector3.UP)
	_cam.current = true
	var view := TextureRect.new()
	view.texture = _vp.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var post := ShaderMaterial.new()
	post.shader = PIXEL_POST
	post.set_shader_parameter("low_res", Vector2(RES))
	post.set_shader_parameter("keep_alpha", true)
	view.material = post
	add_child(view)
	# Title + stats under each car (fixed slots: nothing moves, D-096).
	var title := UI.styled_label(tr("RC_CHOOSE_CAR"), title_font, 2)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	add_child(title)
	for i in 3:
		_boxes.append(_stats_box(i))
	_refresh()


func _ring_mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _stats_box(i: int) -> Control:
	var spec: Dictionary = Sim.CARS[i]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.1, 0.7)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var box := UI.vstack(0)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(box)
	var name := UI.label(tr(spec.name), 36, ROW_COLS[i])
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)
	var top := UI.label(tr("RC_STAT_TOP") % roundi(float(spec.top) * 3.6), 36, UI.WHITE)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(top)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var cl := UI.label(tr("RC_STAT_CORNER"), 36, UI.WHITE)
	row.add_child(cl)
	for k in PIPS:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(36, 28)
		pip.color = ROW_COLS[i] if k < corner_pips(i) else Color(0.15, 0.15, 0.22, 0.85)
		row.add_child(pip)
	box.add_child(row)
	# Under the car: project its base into the TABLE.
	var base := _cam.unproject_position(Vector3(0, float(ROW_Y[i]) - 0.2, 3.0))
	panel.position = Vector2((1080.0 - PANEL_W) * 0.5, base.y * (1920.0 / RES.y) - 24.0)
	add_child(panel)
	return panel


## Cornering as 1..5 pips from the car's grip.
static func corner_pips(i: int) -> int:
	return clampi(roundi(lerpf(1.0, 5.0, (float(Sim.CARS[i].grip) - 0.8) / 0.45)), 1, PIPS)


func move(step: int) -> void:
	selected = clampi(selected + step, 0, 2)
	_refresh()


func _refresh() -> void:
	for i in 3:
		var on := i == selected
		(_rings[i] as MeshInstance3D).material_override = _ring_mat_on if on else _ring_mat_off
		for m in (_cars[i] as Node3D).find_children("*", "MeshInstance3D", true, false):
			var gi := m as MeshInstance3D
			if gi.material_override != null:
				gi.set_instance_shader_parameter("bright", 1.0 if on else 0.55)
		(_boxes[i] as Control).modulate.a = 1.0 if on else 0.5


func _process(delta: float) -> void:
	_t += delta
	var step := TAU / SPRITE_ANGLES
	for i in 3:
		_angles[i] += delta * SPIN * (1.6 if i == selected else 0.6)
		var a := roundf(float(_angles[i]) / step) * step   # stepped like a sprite set
		(_cars[i] as Node3D).rotation = Vector3(0, a, 0)
		var bob := 0.12 if i == selected and fmod(_t, 0.8) < 0.4 else 0.0
		(_cars[i] as Node3D).position.y = float(ROW_Y[i]) + bob
