## Screens autoload: owns the TABLE and BACKGLASS content viewports and places
## them (plus the DMD) on OS windows according to the layout (D-006, D-013):
##   windowed : 3 separate windows tiled on one monitor (current dev default)
##   3screen  : TABLE = main window, BACKGLASS and DMD in their own fullscreen windows
##   2screen  : TABLE = main window, DMD drawn as a region of the BACKGLASS window
## Games add their nodes to `table` / `backglass` (base coordinates, any render scale).
extends Node

const ScreenView = preload("res://core/screen_view.gd")
const DMD_SHADER = preload("res://core/shaders/dmd_dots.gdshader")

const TABLE_BASE := Vector2i(1080, 1920)
const BACKGLASS_BASE := Vector2i(1920, 1080)
const TITLE_BAR := 40  # allowance for OS window decorations in windowed mode

var table: SubViewport
var backglass: SubViewport
var current_layout := ""
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
	if is_headless():
		print("Screens: headless, layout '%s' not shown" % layout_name)
		return
	match layout_name:
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
	var right_w := mini(int((h - TITLE_BAR) * 16.0 / 13.0), area.size.x - table_size.x - 24)
	var bg_size := Vector2i(right_w, right_w * 9 / 16)
	var dmd_size := Vector2i(right_w, right_w / 4)
	var x0 := area.position.x + 4
	var y0 := area.position.y + TITLE_BAR

	_scale_render(table_size)
	var root := get_window()
	root.mode = Window.MODE_WINDOWED
	root.title = "PinGames - TABLE"
	root.size = table_size
	root.position = Vector2i(x0, y0)
	_add_view(root, table.get_texture(), 0, false)

	var right_x := x0 + table_size.x + 12
	var bgw := _make_window("PinGames - BACKGLASS", Rect2i(Vector2i(right_x, y0), bg_size), false)
	_add_view(bgw, backglass.get_texture(), 0, false)
	var dmw := _make_window("PinGames - DMD",
		Rect2i(Vector2i(right_x, y0 + bg_size.y + TITLE_BAR), dmd_size), false)
	_add_view(dmw, Dmd.texture(), 0, true)


# --- cabinet: fullscreen windows on separate monitors -------------------------
func _setup_cabinet(dmd_in_backglass: bool) -> void:
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
	if dmd_in_backglass or sink == "backglass":
		var r := str(Config.get_value("display", "dmd_region")).split_floats(",")
		if r.size() == 4:
			b_view.anchor_bottom = r[1]  # backglass art sits above the DMD strip
			var dv := _add_view(bgw, Dmd.texture(), 0, true)
			dv.anchor_left = r[0]
			dv.anchor_top = r[1]
			dv.anchor_right = r[0] + r[2]
			dv.anchor_bottom = r[1] + r[3]
			dv.offset_left = 0
			dv.offset_top = 0
			dv.offset_right = 0
			dv.offset_bottom = 0
		return
	var d_mon := _clamp_monitor(int(Config.get_value("display", "dmd_monitor")))
	var dmw := _make_window("PinGames DMD", _monitor_rect(d_mon), true)
	_add_view(dmw, Dmd.texture(), int(Config.get_value("display", "dmd_rotation")), true)


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
		v.material = mat
	if win == get_window():
		add_child(v)  # Screens itself lives in the root window
		_outputs.append(v)
	else:
		win.add_child(v)  # freed together with its window
	return v


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
