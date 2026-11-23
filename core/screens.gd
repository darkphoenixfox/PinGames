## Screens autoload: owns the TABLE and BACKGLASS content viewports and places
## them (plus the DMD) on OS windows according to the layout (D-006, D-013):
##   windowed : 3 separate windows on one monitor (dev default): TABLE centred,
##              BACKGLASS + DMD stacked to its left (D-148)
##   3screen  : TABLE = main window, BACKGLASS and DMD in their own fullscreen windows
##   vr       : a 3D pinball cabinet with the three screens on it, OpenXR when
##              available, else a desktop preview camera (D-164)
##   web      : one browser canvas: TABLE left, BACKGLASS + DMD right (D-173)
##   2screen  : TABLE = main window, DMD framed at the bottom centre of the BACKGLASS
##              (games show their *_2screen backglass art, D-080)
## Games add their nodes to `table` / `backglass` (base coordinates, any render scale).
extends Node

const UI = preload("res://core/ui/ui.gd")
const TouchControls = preload("res://core/touch_controls.gd")
const ScreenView = preload("res://core/screen_view.gd")
const BEZEL_SHADER = preload("res://core/ui/bezel_frame.gdshader")   # D-276
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
	backglass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var sink := str(Config.get_value("display", "dmd_sink"))
	dmd_in_backglass = sink != "hardware" and (layout_name == "2screen" or sink == "backglass")
	if layout_name == "vr" or layout_name == "web" or layout_name == "single":
		dmd_in_backglass = false   # VR head / web page show their own DMD panel (D-164, D-173)
	if is_headless():
		print("Screens: headless, layout '%s' not shown" % layout_name)
		return
	match layout_name:
		"vr":
			_setup_vr()
		"web":
			_setup_web()
		"single":
			_setup_single()
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
	# D-148: TABLE centred on the monitor, BACKGLASS + DMD stacked beside it;
	# D-197: on its right (was its left).
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

	var right_x := x0 + table_size.x + 12   # right of the TABLE (D-197)
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


# --- web: all three screens on one page (D-173, D-176, D-177) -----------------
## A browser has one canvas. Landscape: the TABLE on the left at full height,
## the BACKGLASS and the DMD stacked on the right. Portrait (phones): the DMD
## above the TABLE, no BACKGLASS. On touch screens the cabinet buttons stand in
## two columns at the left and right edges (core/touch_controls.gd), so the
## screens keep their full height; otherwise the keys are listed.
var _web_page: Control
var _web_portrait := -1
var _touch: TouchControls


func _setup_web() -> void:
	table.size = TABLE_BASE
	var root := get_window()
	if not OS.has_feature("web") and not OS.has_feature("android"):   # desktop preview (--web-preview)
		root.mode = Window.MODE_WINDOWED
		var mon := _clamp_monitor(int(Config.get_value("display", "windowed_monitor")))
		var area := DisplayServer.screen_get_usable_rect(mon)
		var want := Vector2i(1280, 720)
		if Config.cli.has("web-portrait"):
			want = Vector2i(450, 900)
		root.size = Vector2i(mini(want.x, area.size.x - 40), mini(want.y, area.size.y - 80))
		root.position = area.position + (area.size - root.size) / 2
	_web_page = Control.new()
	_web_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_web_page)
	_outputs.append(_web_page)
	_web_portrait = -1
	_web_layout()
	if not root.size_changed.is_connected(_web_layout):
		root.size_changed.connect(_web_layout)


func _web_layout() -> void:
	if not is_instance_valid(_web_page):
		return
	var win := Vector2(get_window().size)
	if is_instance_valid(_touch):
		_touch.fit(win)
	var portrait := 1 if win.y > win.x else 0
	if portrait == _web_portrait:
		return
	_web_portrait = portrait
	for c in _web_page.get_children():
		c.queue_free()
	_touch = null
	var touch := TouchControls.wanted()
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_web_page.add_child(row)
	var content: BoxContainer = VBoxContainer.new() if portrait == 1 else HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	var t := ScreenView.new()
	t.texture = table.get_texture()
	if portrait == 1:
		var top := _web_dmd()
		top.size_flags_vertical = Control.SIZE_EXPAND_FILL
		top.size_flags_stretch_ratio = 0.22
		content.add_child(top)
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(t)
	else:
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_stretch_ratio = 0.9
		content.add_child(t)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_stretch_ratio = 1.6
		right.add_theme_constant_override("separation", 8)
		content.add_child(right)
		var bg := ScreenView.new()
		bg.texture = backglass.get_texture()
		bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bg.size_flags_stretch_ratio = 2.2
		right.add_child(bg)
		var box := _web_dmd()
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.size_flags_stretch_ratio = 0.6
		right.add_child(box)
		if not touch:
			var help := Label.new()
			help.text = tr("WEB_CONTROLS")
			help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			help.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
			help.add_theme_font_size_override("font_size", 16)
			right.add_child(help)
	if not touch:
		row.add_child(content)
		return
	_touch = TouchControls.new()
	_touch.table_view = t
	_web_page.add_child(_touch)
	row.add_child(_touch.left)
	row.add_child(content)
	row.add_child(_touch.right)
	_web_page.add_child(_touch.toggle)   # floats over the top-right corner
	_touch.fit(win)


## The DMD with its dot shader, kept exactly the DMD's shape so the dots never
## cover the margins.
func _web_dmd() -> Control:
	var d := ScreenView.new()
	d.texture = Dmd.texture()
	d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = DMD_SHADER
	mat.set_shader_parameter("dots", Vector2(Dmd.size))
	mat.set_shader_parameter("tint", Dmd.color)
	mat.set_shader_parameter("mono", Dmd.mono)
	d.material = mat
	var box := AspectRatioContainer.new()
	box.ratio = float(Dmd.size.x) / Dmd.size.y
	box.add_child(d)
	return box


# --- single screen: Android and PC (D-251) --------------------------------------
## One screen, no backglass. Portrait: the DMD across the full width at the top,
## the TABLE filling the rest, the touch overlay at the bottom over it.
## Landscape: the DMD centred at the top (half the width of a 16:9 screen), the
## TABLE filling the rest. Touch controls (when wanted and no gamepad is
## connected) are translucent buttons over the game.
var _single_page: Control
var _single_portrait := -1
var _single_touch_on := false
var _single_table: Control
var _single_dmd: Control
var _single_bar: Control
## D-254: a game that can draw at any shape (Turbo Run) asks for a flexible
## TABLE: in the single layout it then takes the exact shape of its area
## (landscape: the whole window, the DMD over its top). `table_shape_changed`
## fires when that shape changes; other games keep the fixed 9:16 TABLE.
signal table_shape_changed
var table_flex := false
## D-262: a flexible game that wants the DMD above it, not over it (landscape).
var dmd_above := false
## D-265: landscape with side panels (Tilt Breaker): the game over the whole
## window (its playfield as tall as possible), the DMD in a box on the left and
## the BACKGLASS in a box on the right.
var side_panels := false
var _single_bgv: Control
## D-266: frames round the side panels, tiled from a game's texture.
var panel_frame: Texture2D
## D-267: the play area's half width as a share of the TABLE's width, reported
## by the game (its edges as seen through its camera); panels stay outside it.
var play_half_w := 0.0
var _frame_d: TextureRect
var _frame_b: TextureRect


func set_flexible(on: bool) -> void:
	table_flex = on
	if current_layout == "single" and is_instance_valid(_single_page):
		_place_single(Vector2(get_window().size))
	elif not on and table.size_2d_override != TABLE_BASE:
		table.size_2d_override = TABLE_BASE
		table_shape_changed.emit()


## D-262: the DMD above the game area instead of over it (Tilt Breaker).
func want_side_panels(on: bool, frame_tex: Texture2D = null) -> void:
	side_panels = on
	panel_frame = frame_tex
	if not on:
		play_half_w = 0.0


## D-267: the game says how wide its play area is (half width / TABLE width).
func set_play_half_width(k: float) -> void:
	if absf(k - play_half_w) > 0.002:
		play_half_w = k
		if current_layout == "single" and is_instance_valid(_single_page):
			_place_single(Vector2(get_window().size))
	if current_layout == "single" and is_instance_valid(_single_page):
		_place_single(Vector2(get_window().size))


func want_dmd_above(on: bool) -> void:
	dmd_above = on
	if current_layout == "single" and is_instance_valid(_single_page):
		_place_single(Vector2(get_window().size))


## D-255: a game that needs the 9:16 TABLE (Tilt Breaker's portrait playfield).
func want_portrait_table(on: bool) -> void:
	if current_layout == "single":
		set_flexible(not on)


## D-255: how much of the TABLE's top the DMD covers (base px), 0 if it doesn't.
func dmd_cover() -> float:
	if current_layout != "single" or not table_flex or dmd_above or side_panels:
		return 0.0
	var b := Vector2(table_base())
	if b.y >= b.x:
		return 0.0   # portrait: the DMD sits above the TABLE
	return minf(b.x, b.y * 16.0 / 9.0) * 0.25 / (float(Dmd.size.x) / Dmd.size.y) + 10.0


## The TABLE's base size (its 2D coordinates): TABLE_BASE, or the flexible shape.
func table_base() -> Vector2i:
	return table.size_2d_override


func _setup_single() -> void:
	table.size = TABLE_BASE
	table_flex = true   # D-255: every screen takes the area's shape; 9:16 games ask
	var root := get_window()
	if not OS.has_feature("android") and not OS.has_feature("web"):   # the page owns the canvas (D-270)
		root.mode = Window.MODE_WINDOWED
		root.title = "PinGames"
		var mon := _clamp_monitor(int(Config.get_value("display", "windowed_monitor")))
		var area := DisplayServer.screen_get_usable_rect(mon)
		var want := Vector2i(1280, 720)
		if Config.cli.has("single-portrait"):
			want = Vector2i(450, 960)
		if Config.cli.has("single-size"):   # dev: --single-size=547x780, any screen shape (D-280)
			var wh := str(Config.cli["single-size"]).split("x")
			if wh.size() == 2:
				want = Vector2i(int(wh[0]), int(wh[1]))
		root.size = Vector2i(mini(want.x, area.size.x - 40), mini(want.y, area.size.y - 80))
		root.position = area.position + (area.size - root.size) / 2
	_single_page = Control.new()
	_single_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_single_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_single_page)
	_outputs.append(_single_page)
	_single_portrait = -1
	_single_layout()
	if not root.size_changed.is_connected(_single_layout):
		root.size_changed.connect(_single_layout)
	if not Input.joy_connection_changed.is_connected(_on_joy_changed):
		Input.joy_connection_changed.connect(_on_joy_changed)


func _on_joy_changed(_device: int, _connected: bool) -> void:
	if current_layout == "single":
		_single_portrait = -1   # rebuild: a gamepad hides the touch overlay
		_single_layout()


func _single_layout() -> void:
	if not is_instance_valid(_single_page):
		return
	var win := Vector2(get_window().size)
	var portrait := 1 if win.y > win.x else 0
	var touch := TouchControls.wanted() and (Input.get_connected_joypads().is_empty() or Config.cli.has("touch"))
	if portrait == _single_portrait and touch == _single_touch_on:
		_place_single(win)
		return
	_single_portrait = portrait
	_single_touch_on = touch
	for c in _single_page.get_children():
		_single_page.remove_child(c)   # gone now, not at the end of the frame
		c.queue_free()
	_touch = null
	_single_bar = null
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_single_page.add_child(bg)
	var t := ScreenView.new()
	t.name = "Table"
	t.texture = table.get_texture()
	_single_page.add_child(t)
	_single_table = t
	for i in 2:   # D-266: frames, behind the panels
		var fr := TextureRect.new()
		fr.stretch_mode = TextureRect.STRETCH_SCALE   # D-276: the bezel shader tiles it
		fr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var fm := ShaderMaterial.new()
		fm.shader = BEZEL_SHADER
		fr.material = fm
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr.visible = false
		_single_page.add_child(fr)
		if i == 0:
			_frame_d = fr
		else:
			_frame_b = fr
	var bgv := ScreenView.new()   # D-265: the BACKGLASS, shown with side panels
	bgv.texture = backglass.get_texture()
	bgv.visible = false
	_single_page.add_child(bgv)
	_single_bgv = bgv
	var d := _web_dmd()
	d.name = "Dmd"
	_single_page.add_child(d)
	_single_dmd = d
	if touch:
		_touch = TouchControls.new()
		_touch.table_view = t
		_touch.overlay = true
		_single_page.add_child(_touch)
		var bar := HBoxContainer.new()
		bar.name = "TouchBar"
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(_touch.left)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(gap)
		bar.add_child(_touch.right)
		_single_page.add_child(bar)
		_single_bar = bar
		_single_page.add_child(_touch.toggle)
		_single_page.add_child(_touch.exit_button)   # D-281: EXIT, top left
	_place_single(win)


## D-254: the flexible TABLE takes its area's shape: base 1080 wide in portrait,
## 1080 high in landscape; rendered at the area's own pixels (at most 2x base).
func _shape_table(area: Vector2) -> void:
	var base := TABLE_BASE
	if table_flex and area.x > 1.0 and area.y > 1.0:
		if area.y >= area.x:
			base = Vector2i(1080, roundi(1080.0 * area.y / area.x))
		else:
			base = Vector2i(roundi(1080.0 * area.x / area.y), 1080)
		table.size = Vector2i(mini(roundi(area.x), base.x * 2), mini(roundi(area.y), base.y * 2))
	else:
		table.size = TABLE_BASE
	if table.size_2d_override != base:
		table.size_2d_override = base
		table_shape_changed.emit()
	if is_instance_valid(_single_table):
		_single_table.queue_redraw()   # draw the TABLE at its new shape


## Positions the DMD, the TABLE and the touch overlay for the window size.
func _place_single(win: Vector2) -> void:
	var d := _single_dmd
	var t := _single_table
	if not is_instance_valid(d) or not is_instance_valid(t):
		return
	var ratio := float(Dmd.size.x) / Dmd.size.y
	if win.y > win.x:
		var dh := win.x / ratio
		d.position = Vector2.ZERO
		d.size = Vector2(win.x, dh)
		t.position = Vector2(0, dh)
		t.size = Vector2(win.x, win.y - dh)
	else:
		# A quarter of the width of a 16:9 screen, centred at the top (D-255: was half).
		var dw := minf(win.x, win.y * 16.0 / 9.0) * 0.25
		var dh := dw / ratio
		d.position = Vector2((win.x - dw) * 0.5, 0)
		d.size = Vector2(dw, dh)
		for n in [_single_bgv, _frame_d, _frame_b]:
			if is_instance_valid(n):
				n.visible = false
		if table_flex and side_panels:
			# D-265/D-266: the game over the whole window. Each panel is centred
			# in the space beside the playfield (9:16 of the height, centred),
			# both on the same middle line, each in a frame.
			t.position = Vector2.ZERO
			t.size = win
			# D-267: the space beside the play area as the game reports it,
			# less a gap; each panel and its frame fit inside it.
			var half := win.x * play_half_w if play_half_w > 0.0 else win.y * 9.0 / 32.0
			var gap := win.x * 0.025
			var th := maxf(8.0, win.y * 0.026)   # D-276: thicker, for the bezel
			var side_w := maxf(win.x * 0.5 - half - gap, 1.0)
			var room := maxf(side_w - th * 2.0 - win.x * 0.02, 1.0)
			var mid_y := win.y * 0.4
			var lw := minf(win.x * 0.26, room)
			var dsz := Vector2(lw, lw / ratio)
			d.position = Vector2(side_w * 0.5 - dsz.x * 0.5, mid_y - dsz.y * 0.5)
			d.size = dsz
			var bw := minf(win.x * 0.27, room)   # 10 % bigger than D-265
			var bsz := Vector2(bw, bw * 9.0 / 16.0)
			var bpos := Vector2(win.x - side_w * 0.5 - bsz.x * 0.5, mid_y - bsz.y * 0.5)
			if is_instance_valid(_single_bgv):
				_single_bgv.position = bpos
				_single_bgv.size = bsz
				_single_bgv.visible = true
			if panel_frame != null:
				for pair in [[_frame_d, Rect2(d.position, dsz)], [_frame_b, Rect2(bpos, bsz)]]:
					var fr: TextureRect = pair[0]
					var r: Rect2 = pair[1]
					fr.texture = panel_frame
					fr.position = r.position - Vector2(th, th)
					fr.size = r.size + Vector2(th, th) * 2.0
					fr.visible = true
					var fmat := fr.material as ShaderMaterial
					fmat.set_shader_parameter("rect_size", fr.size)
					fmat.set_shader_parameter("thickness", th)
					fmat.set_shader_parameter("tile_px", th * 3.0)
		elif table_flex and not dmd_above:   # the game fills the window, the DMD over its top (D-254)
			t.position = Vector2.ZERO
			t.size = win
		else:
			t.position = Vector2(0, dh)
			t.size = Vector2(win.x, win.y - dh)
	_shape_table(t.size)
	# D-278: one screen shows the BACKGLASS only in the side-panel layout;
	# otherwise it isn't drawn at all (a full 1920x1080 pass saved each frame).
	var bg_shown := is_instance_valid(_single_bgv) and _single_bgv.visible
	backglass.render_target_update_mode = SubViewport.UPDATE_ALWAYS if bg_shown else SubViewport.UPDATE_DISABLED
	var bar := _single_bar
	if is_instance_valid(bar) and is_instance_valid(_touch):
		_touch.fit(win)
		var bh := win.y * (0.42 if win.y > win.x else 0.6)
		bar.position = Vector2(0, win.y - bh)
		bar.size = Vector2(win.x, bh)


# --- vr: a 3D cabinet with the screens on it (D-164) ----------------------------
func _setup_vr() -> void:
	table.size = TABLE_BASE   # full resolution: it's read up close
	var root := get_window()
	if OS.has_feature("android"):
		_vr_cabinet()   # the headset owns the display (D-170)
		return
	root.mode = Window.MODE_WINDOWED
	root.title = "PinGames - VR"
	var mon := _clamp_monitor(int(Config.get_value("display", "windowed_monitor")))
	var area := DisplayServer.screen_get_usable_rect(mon)
	root.size = Vector2i(mini(1280, area.size.x - 40), mini(720, area.size.y - 80))
	root.position = area.position + (area.size - root.size) / 2
	_vr_cabinet()


func _vr_cabinet() -> void:
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
