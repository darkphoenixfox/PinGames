## TURBO RUN car select showroom (D-122): the three cars stacked down the
## portrait TABLE, each on a turntable, spinning in stepped sprite-like angles,
## with a stats card beside it (D-185). Rendered at the pixel resolution through the same
## palette/dither pass as the race. The game feeds input and reads `selected`.
extends Control

const InstParam = preload("res://core/util/inst_param.gd")

const UI = preload("res://core/ui/ui.gd")
const Sim = preload("res://games/racer/sim.gd")
const PIXEL_POST = preload("res://games/racer/shaders/pixel_post.gdshader")
const INK_FONT = preload("res://assets/fonts/pinpixel.ttf")   # D-542
const WANTED_PRINT = preload("res://games/racer/shaders/wanted_print.gdshader")   # D-527

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
var pursuit := false   # D-460: choosing the speeder to chase (CHOOSE YOUR TARGET), set before build()
## D-255: landscape: the three cars side by side, each card under its car.
var landscape := false
const LAND_X := [-6.6, 0.0, 6.6]


func _car_pos(i: int) -> Vector3:
	if landscape:
		return Vector3(float(LAND_X[i]), 0.0, 0.0)
	return Vector3(CAR_X, float(ROW_Y[i]), 0.0)


func _base() -> Vector2:
	return Vector2(1920, 1080) if landscape else Vector2(1080, 1920)
var _res := RES
## D-280: the showroom is laid out for exactly _base(); this holds it, scaled
## to fit the screen's shape and centred (the sky fills what's left).
var _stage := Control.new()
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
	if landscape:
		_res = Vector2i(_res.y, _res.x)
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
	_stage.size = _base()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	resized.connect(_fit_stage)
	_fit_stage()
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
		var cp := _car_pos(i)
		var y: float = cp.y
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
		table.position = Vector3(cp.x, y - 0.09, 0)
		table.visible = not pursuit   # D-524: in a pursuit the car turns in its poster's photo
		root.add_child(table)
		var ring := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 2.95
		rc.bottom_radius = 2.95
		rc.height = 0.08
		rc.radial_segments = 32
		ring.mesh = rc
		ring.position = Vector3(cp.x, y - 0.16, 0)
		ring.visible = not pursuit
		root.add_child(ring)
		_rings.append(ring)
		var car: Node3D = make_car.call(float(Sim.CARS[i].hue), i)   # each car's own model (D-205)
		car.position = Vector3(cp.x, y, 0)
		root.add_child(car)
		_cars.append(car)
	# Orthographic, looking down from the front: every row is seen from above
	# at the same angle, like a sprite showcase.
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 21.0 if landscape else 9.6
	_cam.position = Vector3(0, 7.0, 14.0)
	root.add_child(_cam)
	# Landscape: the cars in the upper half, the cards below them.
	# (D-524: in a pursuit a little lower, so the posters clear the title.)
	_cam.look_at(Vector3(0, (-0.3 if pursuit else -1.5) if landscape else -0.4, 0), Vector3.UP)
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
		post.set_shader_parameter("low_res", Vector2(_res))
		post.set_shader_parameter("keep_alpha", true)
		post.set_shader_parameter("nes", nes)
		if nes:
			post.set_shader_parameter("low_res", Vector2(_res) * 0.75)
		view.material = post
	_stage.add_child(view)
	# Title + a stats card beside each car (fixed slots: nothing moves, D-096).
	var title := UI.styled_label(tr("RC_CHOOSE_TARGET" if pursuit else "RC_CHOOSE_CAR"), title_font, 2)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30 + (Screens.dmd_cover() if landscape else 0.0)   # D-255: clear of the DMD
	_stage.add_child(title)
	for i in 3:
		_boxes.append(_wanted_poster(i, view) if pursuit else _stats_box(i))
	_refresh()


func _fit_stage() -> void:
	var b := _base()
	var k := minf(size.x / b.x, size.y / b.y)
	if k <= 0.0:
		return
	_stage.scale = Vector2(k, k)
	_stage.position = (size - b * k) * 0.5


func _ring_mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


## D-524 (director): in a pursuit each target has a WANTED poster: aged paper,
## WANTED across the top, a photo frame with the car turning in it, then its
## name and stats. The paper and the photo's backdrop are drawn under the 3D
## view and the frame and print over it, so the car shows in the photo.
## Landscape: an upright poster, the stats under the photo. Portrait TABLE:
## a wide one, the stats beside the photo.
const PAPER := Color(0.86, 0.76, 0.56)
const PAPER_EDGE := Color(0.33, 0.22, 0.12)
const PHOTO_BACK := Color(0.63, 0.56, 0.44)
const INK := Color(0.2, 0.12, 0.07)
const PHOTO := Vector2(430.0, 250.0)
const PHOTO_TALL := Vector2(520.0, 340.0)   # portrait TABLE: the cars are drawn bigger there
const POSTER_PAD := 16.0
const PRINT_DOT := 7.0           # the photo's ink dots, base px apart
const POSTER_HEAD := 84.0        # the WANTED line's height
const POSTER_STATS_H := 356.0    # the name and three stats
const POSTER_STATS_W := 400.0    # portrait: the stats column beside the photo


## D-542: print on a poster. The UI's dot lettering has a dark rim round every
## dot (made for light text over a scene): in dark ink the dots and the rim
## ran together and nothing could be read. Print is the plain pixel font,
## solid, in ink, with no rim. (No "dot_size": the game doesn't swap it.)
func _ink_label(text: String, size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", INK_FONT)
	l.add_theme_font_size_override("font_size", UI.pixel_size(size))
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _wanted_poster(i: int, view: Control) -> Control:
	var spec: Dictionary = Sim.CARS[i]
	var mid := _cam.unproject_position(_car_pos(i) + Vector3(0.0, 0.6 if landscape else 0.4, 0.0)) * (_base().y / _res.y)
	var psize := PHOTO if landscape else PHOTO_TALL
	var photo := Rect2(mid - psize * 0.5, psize)
	# The print: name and stats, in ink.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_ink_label(tr(spec.name), 60))
	_stat_row(box, tr("RC_STAT_SPEED"), speed_pips(i), tr("RC_STAT_MPH") % roundi(float(spec.top) * Sim.MPH), INK, INK)
	_stat_row(box, tr("RC_STAT_CORNER"), corner_pips(i), "", INK, INK)
	var rams := ceili(1.0 / float(Sim.TARGETS[i].dmg))
	_stat_row(box, tr("RC_STAT_RAMS"), clampi(roundi(rams / 4.0), 1, PIPS), str(rams), INK, INK)
	var stats_h := POSTER_STATS_H
	var sheet: Rect2
	if landscape:
		sheet = Rect2(photo.position.x - POSTER_PAD, photo.position.y - POSTER_HEAD,
			psize.x + POSTER_PAD * 2.0, POSTER_HEAD + psize.y + stats_h + POSTER_PAD * 2.0)
		box.position = Vector2(photo.position.x, photo.end.y + POSTER_PAD * 0.5)
		box.size = Vector2(psize.x, stats_h)
	else:
		sheet = Rect2(photo.position.x - POSTER_PAD, photo.position.y - POSTER_HEAD,
			psize.x + POSTER_STATS_W + POSTER_PAD * 3.0, POSTER_HEAD + maxf(psize.y, stats_h - POSTER_HEAD * 0.5) + POSTER_PAD)
		box.position = Vector2(photo.end.x + POSTER_PAD, sheet.position.y + POSTER_HEAD * 0.5)
		box.size = Vector2(POSTER_STATS_W, stats_h)
	# Under the 3D view: the paper and the photo's backdrop.
	var under := Control.new()
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = PAPER
	ps.border_color = PAPER_EDGE
	ps.set_border_width_all(5)
	ps.set_corner_radius_all(4)
	ps.shadow_color = Color(0, 0, 0, 0.45)
	ps.shadow_size = 12
	paper.add_theme_stylebox_override("panel", ps)
	paper.position = sheet.position
	paper.size = sheet.size
	under.add_child(paper)
	var back := ColorRect.new()
	back.color = PHOTO_BACK
	back.position = photo.position
	back.size = photo.size
	under.add_child(back)
	_stage.add_child(under)
	_stage.move_child(under, view.get_index())
	# D-527: the car shows only inside the photo: the 3D view again, cut to
	# the photo's frame (the whole view is hidden in a pursuit).
	view.visible = false
	var cut := Control.new()
	cut.clip_contents = true
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.position = photo.position
	cut.size = photo.size
	var shot := TextureRect.new()
	shot.texture = (view as TextureRect).texture
	shot.texture_filter = view.texture_filter
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_SCALE
	# Printed in black and white: a screen of ink dots on the paper.
	var print_mat := ShaderMaterial.new()
	print_mat.shader = WANTED_PRINT
	print_mat.set_shader_parameter("ink", INK)
	print_mat.set_shader_parameter("paper", PHOTO_BACK.lightened(0.25))
	print_mat.set_shader_parameter("cells", _base() / PRINT_DOT)
	shot.material = print_mat
	shot.position = -photo.position
	shot.size = _base()
	cut.add_child(shot)
	_stage.add_child(cut)
	# Over it: the photo's frame and the print.
	var over := Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = INK
	fs.set_border_width_all(5)
	frame.add_theme_stylebox_override("panel", fs)
	frame.position = photo.position
	frame.size = photo.size
	over.add_child(frame)
	var head := _ink_label(tr("RC_WANTED"), 72)   # (72: the plain font stands taller than the dot lettering did at 84)
	head.position = Vector2(sheet.position.x, sheet.position.y + 2.0)
	head.size = Vector2(psize.x + POSTER_PAD * 2.0 if not landscape else sheet.size.x, POSTER_HEAD)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over.add_child(head)
	over.add_child(box)
	over.set_meta("under", under)
	over.set_meta("cut", cut)
	_stage.add_child(over)
	return over


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
	_stat_row(box, tr("RC_STAT_SPEED"), speed_pips(i), tr("RC_STAT_MPH") % roundi(float(spec.top) * Sim.MPH), col)
	_stat_row(box, tr("RC_STAT_CORNER"), corner_pips(i), "", col)
	if pursuit:   # D-460: how many rams it takes to stop it, not the race clock
		var rams := ceili(1.0 / float(Sim.TARGETS[i].dmg))
		_stat_row(box, tr("RC_STAT_RAMS"), clampi(roundi(rams / 4.0), 1, PIPS), str(rams), col)
	else:
		_stat_row(box, tr("RC_STAT_CLOCK"), time_pips(i), tr("RC_STAT_SECONDS") % roundi(float(spec.time)), col)
	_stage.add_child(panel)
	# Level with its turntable: centre the card on the car's row.
	var mid := _cam.unproject_position(_car_pos(i)) * (_base().y / _res.y)
	var h := panel.get_combined_minimum_size().y
	if landscape:   # under its car (D-255)
		panel.position = Vector2(mid.x - CARD_W * 0.5, mid.y + 120.0)
	else:
		panel.position = Vector2(CARD_X, mid.y - h * 0.5)
	return panel


const STAT_NAME_GAP := -4   # between a stat's name and its bar (the font's line has air under it)
const STAT_GAP := 12        # above each stat


## A stat: its name, then a bar of PIPS segments (n lit) and its value.
func _stat_row(box: VBoxContainer, label: String, n: int, value: String, col: Color, ink: Color = Color(0, 0, 0, 0)) -> void:
	var printed := ink.a > 0.0   # D-524: on a poster's paper: ink for the text, blank boxes for the unlit pips
	# D-522: a stat's name sits right on its own bar, with a gap before the next stat.
	var stat := VBoxContainer.new()
	stat.add_theme_constant_override("separation", STAT_NAME_GAP)
	box.add_child(UI.spacer(STAT_GAP))
	box.add_child(stat)
	var l := _ink_label(label, 36, HORIZONTAL_ALIGNMENT_LEFT) if printed else UI.label(label, 36, Color(0.85, 0.82, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	stat.add_child(l)
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
			ps.bg_color = Color(ink, 0.12) if printed else Color(0.12, 0.1, 0.2, 0.9)
			ps.border_color = Color(ink, 0.55) if printed else Color(0.3, 0.28, 0.4)
		ps.set_border_width_all(2)
		pip.add_theme_stylebox_override("panel", ps)
		row.add_child(pip)
	if not value.is_empty():
		row.add_child(UI.spacer(0))
		var v := _ink_label(value, 36, HORIZONTAL_ALIGNMENT_LEFT) if printed else UI.label(value, 36, UI.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
	stat.add_child(row)


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
				InstParam.set_param(gi, "bright", 1.0 if on or pursuit else 0.55)   # (D-527: a poster is dimmed whole)
		# Dimmed, not see-through (the sunset would wash it out).
		(_boxes[i] as Control).modulate = Color.WHITE if on else Color(0.5, 0.5, 0.56)
		if (_boxes[i] as Control).has_meta("under"):   # D-524: the poster's paper, under the 3D view
			((_boxes[i] as Control).get_meta("under") as Control).modulate = (_boxes[i] as Control).modulate


func _process(delta: float) -> void:
	_t += delta
	if Config.cli.has("rc-wheeltest"):   # dev (D-249): spin every car's wheels to check them
		for car in _cars:
			for m in (car as Node3D).find_children("*", "MeshInstance3D", true, false):
				if (m as MeshInstance3D).material_override != null:
					InstParam.set_param(m, "spin", 1.0)
					InstParam.set_param(m, "wheel_phase", _t * 2.0)
	# Only the chosen car turns (stepped like a sprite set); the others hold
	# their pose (D-123).
	# D-208: 8-BIT steps through SPRITE_ANGLES poses, 16-BIT twice as many, HD turns smoothly.
	var step := TAU / (SPRITE_ANGLES * (1 if nes else 2))
	_angles[selected] += delta * SPIN
	for i in 3:
		var a: float = float(_angles[i]) if hd else roundf(float(_angles[i]) / step) * step
		(_cars[i] as Node3D).rotation = Vector3(0, a, 0)
