## Screens autoload: owns the TABLE and BACKGLASS content viewports and places
## them (plus the DMD) on OS windows according to the layout (D-006, D-013):
##   windowed : 3 separate windows on one monitor (dev default): TABLE centred,
##              BACKGLASS + DMD stacked to its left (D-148)
##   3screen  : TABLE = main window, BACKGLASS and DMD in their own fullscreen windows
##   vr       : a 3D pinball cabinet with the three screens on it, OpenXR when
##              available, else a desktop preview camera (D-164)
##   2screen  : TABLE = main window, DMD framed at the bottom centre of the BACKGLASS
##              (games show their *_2screen backglass art, D-080)
## Games add their nodes to `table` / `backglass` (base coordinates, any render scale).
extends Node

const ScreenView = preload("res://core/screen_view.gd")
const VrCabinet = preload("res://core/vr_cabinet.gd")
const DMD_SHADER = preload("res://core/shaders/dmd_dots.gdshader")

const TABLE_BASE := Vector2i(1080, 1920)
const BACKGLASS_BASE := Vector2i(1920, 1080)
const TITLE_BAR := 40  # allowance for OS window decorations in windowed mode

var table: SubViewport
var backglass: SubViewport
var current_layout := ""
## True when the DMD is drawn inside the backglass (2 screens, or DMD output =
## backglass). Games then use art composed with room for it (D-080).
var dmd_in_backglass := false
var _outputs: Array[Node] = []


func _ready() -> void:
	table = _make_viewport("TableViewport", TABLE_BASE)
	backglass = _make_viewport("BackglassViewport", BACKGLASS_BASE)


func _make_viewport(vp_name: String, base: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.size = base
	vp.size_2d_override = base
	vp.size_2d_override_stretch = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Builds the windows for a layout. Safe to call again (e.g. from the Display Setup wizard).
func setup(layout_name: String) -> void:
	for o in _outputs:
		o.queue_free()
	_outputs.clear()
	current_layout = layout_name
	var sink := str(Config.get_value("display", "dmd_sink"))
	dmd_in_backglass = sink != "hardware" and (layout_name == "2screen" or sink == "backglass")
	if layout_name == "vr":
		dmd_in_backglass = false   # the VR head has its own DMD panel (D-164)
	if is_headless():
		print("Screens: headless, layout '%s' not shown" % layout_name)
		return
	match layout_name:
		"vr":
			_setup_vr()
		"3screen":
			_setup_cabinet(false)
		"2screen":
			_setup_cabinet(true)
		_:
			if layout_name != "windowed":
				push_warning("Screens: unknown layout '%s', using windowed" % layout_name)
				current_layout = "windowed"
			_setup_windowed()
	print("Screens: layout '%s' ready" % current_layout)


# --- windowed: 3 separate windows side by side on one monitor -----------------
func _setup_windowed() -> void:
	var mon := _clamp_monitor(int(Config.get_value("display", "windowed_monitor")))
	var area := DisplayServer.screen_get_usable_rect(mon)
	var h := area.size.y - TITLE_BAR - 8
	# TABLE: portrait 9:16 at full height.
	var table_size := Vector2i(h * 9 / 16, h)
	# BACKGLASS (16:9) above DMD (4:1), same width w:  w*9/16 + TITLE_BAR + w/4 = h
	# D-148: TABLE centred on the monitor, BACKGLASS + DMD stacked to its left.
	var left_space := (area.size.x - table_size.x) / 2 - 16
	var right_w := mini(int((h - TITLE_BAR) * 16.0 / 13.0), left_space)
	var bg_size := Vector2i(right_w, right_w * 9 / 16)
	var dmd_size := Vector2i(right_w, right_w / 4)
	var x0 := area.position.x + (area.size.x - table_size.x) / 2
	var y0 := area.position.y + TITLE_BAR

	_scale_render(table_size)
	var root := get_window()
	root.mode = Window.MODE_WINDOWED
	root.title = "PinGames - TABLE"
	root.size = table_size
	root.position = Vector2i(x0, y0)
	_add_view(root, table.get_texture(), 0, false)

	var right_x := x0 - 12 - right_w   # left of the TABLE (name kept for the code below)
	var bgw := _make_window("PinGames - BACKGLASS", Rect2i(Vector2i(right_x, y0), bg_size), false)
	_add_view(bgw, backglass.get_texture(), 0, false)
	if dmd_in_backglass:  # preview of the 2-screen cabinet look (D-080)
		_add_framed_dmd(bgw)
		return
	if str(Config.get_value("display", "dmd_sink")) == "hardware":
		return
	var dmw := _make_window("PinGames - DMD",
		Rect2i(Vector2i(right_x, y0 + bg_size.y + TITLE_BAR), dmd_size), false)
	_add_view(dmw, Dmd.texture(), 0, true)


# --- vr: a 3D cabinet with the screens on it (D-164) ----------------------------
func _setup_vr() -> void:
	table.size = TABLE_BASE   # full resolution: it's read up close
	var root := get_window()
	root.mode = Window.MODE_WINDOWED
	root.title = "PinGames - VR"
	var mon := _clamp_monitor(int(Config.get_value("display", "windowed_monitor")))
	var area := DisplayServer.screen_get_usable_rect(mon)
	root.size = Vector2i(mini(1280, area.size.x - 40), mini(720, area.size.y - 80))
	root.position = area.position + (area.size - root.size) / 2
	var cab := VrCabinet.new()
	cab.name = "VrCabinet"
	add_child(cab)
	_outputs.append(cab)
	cab.build(table.get_texture(), backglass.get_texture(), Dmd.texture())


# --- cabinet: fullscreen windows on separate monitors -------------------------
func _setup_cabinet(_two_screens: bool) -> void:
	var t_mon := _clamp_monitor(int(Config.get_value("display", "table_monitor")))
	var b_mon := _clamp_monitor(int(Config.get_value("display", "backglass_monitor")))
	var t_rect := _monitor_rect(t_mon)
	var t_rot := int(Config.get_value("display", "table_rotation"))
	if t_rot < 0:
		t_rot = 270 if t_rect.size.x > t_rect.size.y else 0
	_scale_render(Vector2i(t_rect.size.y, t_rect.size.x) if t_rot % 180 != 0 else t_rect.size)

	var root := get_window()
	root.mode = Window.MODE_WINDOWED
	root.title = "PinGames"
	root.position = t_rect.position
	root.size = t_rect.size
	root.mode = Window.MODE_FULLSCREEN
	_add_view(root, table.get_texture(), t_rot, false)

	var bgw := _make_window("PinGames Backglass", _monitor_rect(b_mon), true)
	var b_view := _add_view(bgw, backglass.get_texture(),
		int(Config.get_value("display", "backglass_rotation")), false)

	var sink := str(Config.get_value("display", "dmd_sink"))
	if sink == "hardware":
		return
	if dmd_in_backglass:
		_add_framed_dmd(bgw)
		return
	var d_mon := _clamp_monitor(int(Config.get_value("display", "dmd_monitor")))
	var dmw := _make_window("PinGames DMD", _monitor_rect(d_mon), true)
	_add_view(dmw, Dmd.texture(), int(Config.get_value("display", "dmd_rotation")), true)


## The DMD inside the backglass window (D-080): full-screen art behind, the DMD
## at its dot aspect centred in the `dmd_region` box, in a bezel frame.
func _add_framed_dmd(win: Window) -> void:
	var r := str(Config.get_value("display", "dmd_region")).split_floats(",")
	if r.size() != 4:
		r = PackedFloat64Array([0.2, 0.755, 0.6, 0.216])
	var ws := Vector2(win.size)
	var box := Rect2(r[0] * ws.x, r[1] * ws.y, r[2] * ws.x, r[3] * ws.y)
	var aspect := float(Dmd.size.x) / float(Dmd.size.y)
	var dsize := Vector2(box.size.x, box.size.x / aspect)
	if dsize.y > box.size.y:
		dsize = Vector2(box.size.y * aspect, box.size.y)
	var drect := Rect2(box.get_center() - dsize * 0.5, dsize)
	var u := ws.y / 1080.0  # frame sizes in backglass base pixels
	# Outer bezel: gunmetal with a dark drop shadow.
	var bezel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0)
	sb.border_color = Color(0.2, 0.23, 0.29)
	sb.set_border_width_all(int(round(10 * u)))
	sb.set_corner_radius_all(int(round(10 * u)))
	sb.shadow_color = Color(0, 0, 0, 0.75)
	sb.shadow_size = int(round(14 * u))
	sb.anti_aliasing = true
	bezel.add_theme_stylebox_override("panel", sb)
	bezel.position = drect.position - Vector2(16, 16) * u
	bezel.size = drect.size + Vector2(32, 32) * u
	win.add_child(bezel)
	# Bright bevel on the bezel's outer edge.
	var bevel := Panel.new()
	var bv := StyleBoxFlat.new()
	bv.draw_center = false
	bv.border_color = Color(0.55, 0.6, 0.7)
	bv.set_border_width_all(maxi(1, int(round(2 * u))))
	bv.set_corner_radius_all(int(round(10 * u)))
	bv.anti_aliasing = true
	bevel.add_theme_stylebox_override("panel", bv)
	bevel.position = bezel.position
	bevel.size = bezel.size
	win.add_child(bevel)
	# Thin glowing inner trim around the glass.
	var trim := Panel.new()
	var tb := StyleBoxFlat.new()
	tb.draw_center = false
	tb.border_color = Color(0.3, 0.75, 1.0, 0.85)
	tb.set_border_width_all(maxi(1, int(round(2 * u))))
	tb.set_corner_radius_all(int(round(3 * u)))
	tb.shadow_color = Color(0.3, 0.75, 1.0, 0.35)
	tb.shadow_size = int(round(5 * u))
	trim.add_theme_stylebox_override("panel", tb)
	trim.position = drect.position - Vector2(5, 5) * u
	trim.size = drect.size + Vector2(10, 10) * u
	win.add_child(trim)
	var dv := _add_view(win, Dmd.texture(), 0, true)
	dv.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dv.position = drect.position
	dv.size = drect.size


# --- helpers ------------------------------------------------------------------
func _make_window(title: String, rect: Rect2i, borderless: bool) -> Window:
	var w := Window.new()
	w.title = title
	w.position = rect.position
	w.size = rect.size
	w.borderless = borderless
	w.unfocusable = true  # keyboard focus stays on the TABLE window
	w.close_requested.connect(func(): pass)  # only the Exit button quits
	add_child(w)
	_outputs.append(w)
	return w


func _add_view(win: Window, tex: Texture2D, rot: int, dmd: bool) -> Control:
	var v: Control = ScreenView.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.texture = tex
	v.rotation_deg = rot
	if dmd:
		v.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = DMD_SHADER
		mat.set_shader_parameter("dots", Vector2(Dmd.size))
		mat.set_shader_parameter("tint", Dmd.color)
		mat.set_shader_parameter("mono", Dmd.mono)
		v.material = mat
	if win == get_window():
		add_child(v)  # Screens itself lives in the root window
		_outputs.append(v)
	else:
		win.add_child(v)  # freed together with its window
	return v


## Shows a big number on every monitor for a few seconds (Display Setup wizard).
## Numbers are 1-based, matching the operator menu.
func identify_monitors(seconds: float = 4.0) -> void:
	if is_headless():
		return
	for i in DisplayServer.get_screen_count():
		var r := _monitor_rect(i)
		var sz := Vector2i(560, 380)
		var w := Window.new()
		w.title = "PinGames monitor %d" % (i + 1)
		w.borderless = true
		w.always_on_top = true
		w.unfocusable = true
		w.position = r.position + (r.size - sz) / 2
		w.size = sz
		var bg := ColorRect.new()
		bg.color = Color("ffd23e")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		w.add_child(bg)
		var l := Label.new()
		l.text = "%d\n%dx%d" % [i + 1, r.size.x, r.size.y]
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 110)
		l.add_theme_color_override("font_color", Color.BLACK)
		w.add_child(l)
		add_child(w)
		get_tree().create_timer(seconds).timeout.connect(w.queue_free)


func monitor_count() -> int:
	return DisplayServer.get_screen_count()


func monitor_size(i: int) -> Vector2i:
	return DisplayServer.screen_get_size(i)


## Sets the TABLE internal resolution to match the output (render_scale=auto) or a fixed factor.
func _scale_render(output_px: Vector2i) -> void:
	var setting := str(Config.get_value("display", "render_scale"))
	var s := 1.0
	if setting == "auto":
		s = clampf(minf(float(output_px.x) / TABLE_BASE.x, float(output_px.y) / TABLE_BASE.y), 0.5, 2.0)
	elif setting.is_valid_float():
		s = clampf(setting.to_float(), 0.25, 2.0)
	table.size = Vector2i(roundi(TABLE_BASE.x * s), roundi(TABLE_BASE.y * s))


func _monitor_rect(i: int) -> Rect2i:
	return Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i))


func _clamp_monitor(i: int) -> int:
	return clampi(i, 0, DisplayServer.get_screen_count() - 1)
