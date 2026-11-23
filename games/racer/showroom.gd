## TURBO RUN car select showroom (D-122): the three cars stacked down the
## portrait TABLE, each on a turntable, spinning in stepped sprite-like angles,
## with a stats card beside it (D-185). Rendered at the pixel resolution through the same
## palette/dither pass as the race. The game feeds input and reads `selected`.
extends Control

const InstParam = preload("res://core/util/inst_param.gd")

const UI = preload("res://core/ui/ui.gd")
const Sim = preload("res://games/racer/sim.gd")
const PIXEL_POST = preload("res://games/racer/shaders/pixel_post.gdshader")

const RES := Vector2i(360, 640)
const HD_RES := Vector2i(1080, 1920)   # D-195: HD graphics renders at the TABLE's size, no pixel pass
const ROW_Y := [5.4, 0.0, -5.4]      # car heights in the showroom (m), top to bottom
const SPIN := 1.2                     # rad/s, the chosen car only
const SPRITE_ANGLES := 32
const START_ANGLE := 0.6
const PIPS := 5
const CAR_X := -1.9                   # turntables sit left of centre (m); the cards go right (D-185)
const CARD_X := 662.0                 # stats card left edge and width (TABLE px)
const CARD_W := 384.0
const PIP_W := 38.0
const ROW_COLS := [Color("4fff7a"), Color("ffd23e"), Color("ff3b4f")]   # easy, normal, hard

var selected := Sim.DEFAULT_CAR
var hd := false        # set before build() (D-195)
var nes := false       # 8-BIT palette (D-207), set before build()
var _res := RES
var _vp: SubViewport
var _cam: Camera3D
var _cars: Array = []
var _rings: Array = []
var _ring_mat_on: StandardMaterial3D
var _ring_mat_off: StandardMaterial3D
var _boxes: Array = []
var _t := 0.0
var _angles := [START_ANGLE, START_ANGLE, START_ANGLE]   # all start alike (D-142)


## make_car: Callable(hue) -> Node3D (the game's car instance with its outline).
func build(make_car: Callable, sky_tex: Texture2D, title_font: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_res = HD_RES if hd else RES
	_vp.size = _res
	if hd:
		_vp.msaa_3d = Viewport.MSAA_4X
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = true
	add_child(_vp)
	# Backdrop: the race's sunset sky, whole, behind the 3D view.
	var sky := TextureRect.new()
	sky.texture = sky_tex
	if hd and ResourceLoader.exists("res://assets/sprites/racer/hd/sky.png"):   # D-195
		sky.texture = load("res://assets/sprites/racer/hd/sky.png")
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if hd else CanvasItem.TEXTURE_FILTER_NEAREST
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
		table.position = Vector3(CAR_X, y - 0.09, 0)
		root.add_child(table)
		var ring := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 2.95
		rc.bottom_radius = 2.95
		rc.height = 0.08
		rc.radial_segments = 32
		ring.mesh = rc
		ring.position = Vector3(CAR_X, y - 0.16, 0)
		root.add_child(ring)
		_rings.append(ring)
		var car: Node3D = make_car.call(float(Sim.CARS[i].hue), i)   # each car's own model (D-205)
		car.position = Vector3(CAR_X, y, 0)
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
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if hd else CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not hd:   # retro: the 16-bit palette/dither pass (HD shows the render as it is)
		var post := ShaderMaterial.new()
		post.shader = PIXEL_POST
		post.set_shader_parameter("low_res", Vector2(RES))
		post.set_shader_parameter("keep_alpha", true)
		post.set_shader_parameter("nes", nes)
		if nes:
			post.set_shader_parameter("low_res", Vector2(RES) * 0.75)
		view.material = post
	add_child(view)
	# Title + a stats card beside each car (fixed slots: nothing moves, D-096).
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


## The car's card (D-185): name, then TOP SPEED, CORNERING and TIME as 5-pip
## bars with their values, framed in the car's colour, level with its turntable.
func _stats_box(i: int) -> Control:
	var spec: Dictionary = Sim.CARS[i]
	var col: Color = ROW_COLS[i]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.12, 0.94)
	sb.border_color = col
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(col, 0.35)
	sb.shadow_size = 14
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(CARD_W, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var name := UI.label(tr(spec.name), 60, col)
	box.add_child(name)
	box.add_child(UI.spacer(4))
	_stat_row(box, tr("RC_STAT_SPEED"), speed_pips(i), tr("RC_STAT_MPH") % roundi(float(spec.top) * Sim.MPH), col)
	_stat_row(box, tr("RC_STAT_CORNER"), corner_pips(i), "", col)
	_stat_row(box, tr("RC_STAT_CLOCK"), time_pips(i), tr("RC_STAT_SECONDS") % roundi(float(spec.time)), col)
	add_child(panel)
	# Level with its turntable: centre the card on the car's row.
	var mid := _cam.unproject_position(Vector3(CAR_X, float(ROW_Y[i]), 0.0))
	var h := panel.get_combined_minimum_size().y
	panel.position = Vector2(CARD_X, mid.y * (1920.0 / _res.y) - h * 0.5)
	return panel


## A stat: its name, then a bar of PIPS segments (n lit) and its value.
func _stat_row(box: VBoxContainer, label: String, n: int, value: String, col: Color) -> void:
	var l := UI.label(label, 36, Color(0.85, 0.82, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for k in PIPS:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(PIP_W, 26)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # same bar height on every row
		var ps := StyleBoxFlat.new()
		ps.set_corner_radius_all(3)
		if k < n:
			ps.bg_color = col
			ps.border_color = col.lightened(0.45)
		else:
			ps.bg_color = Color(0.12, 0.1, 0.2, 0.9)
			ps.border_color = Color(0.3, 0.28, 0.4)
		ps.set_border_width_all(2)
		pip.add_theme_stylebox_override("panel", ps)
		row.add_child(pip)
	if not value.is_empty():
		row.add_child(UI.spacer(0))
		var v := UI.label(value, 36, UI.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
	box.add_child(row)


## Top speed as 2..5 pips (the cars run 72..88 m/s).
static func speed_pips(i: int) -> int:
	return clampi(2 + roundi((float(Sim.CARS[i].top) - 72.0) / 16.0 * 3.0), 1, PIPS)


## Starting clock as 2..5 pips (40..55 s).
static func time_pips(i: int) -> int:
	return clampi(2 + roundi((float(Sim.CARS[i].time) - 40.0) / 15.0 * 3.0), 1, PIPS)


## Cornering as 1..5 pips from the car's grip.
static func corner_pips(i: int) -> int:
	return clampi(roundi(lerpf(1.0, 5.0, (float(Sim.CARS[i].grip) - 0.8) / 0.45)), 1, PIPS)


## Repaints car i (D-236).
func set_hue(i: int, hue: float) -> void:
	for m in (_cars[i] as Node3D).find_children("*", "MeshInstance3D", true, false):
		var gi := m as MeshInstance3D
		if gi.material_override != null:
			InstParam.set_param(gi, "hue", hue)


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
				InstParam.set_param(gi, "bright", 1.0 if on else 0.55)
		# Dimmed, not see-through (the sunset would wash it out).
		(_boxes[i] as Control).modulate = Color.WHITE if on else Color(0.5, 0.5, 0.56)


func _process(delta: float) -> void:
	_t += delta
	# Only the chosen car turns (stepped like a sprite set); the others hold
	# their pose (D-123).
	# D-208: 8-BIT steps through SPRITE_ANGLES poses, 16-BIT twice as many, HD turns smoothly.
	var step := TAU / (SPRITE_ANGLES * (1 if nes else 2))
	_angles[selected] += delta * SPIN
	for i in 3:
		var a: float = float(_angles[i]) if hd else roundf(float(_angles[i]) / step) * step
		(_cars[i] as Node3D).rotation = Vector3(0, a, 0)
