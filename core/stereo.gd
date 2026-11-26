## Stereo autoload (D-418): stereoscopic 3D for the single-screen layout, on a
## Leia SR display (eye-tracked, glasses-free) or as dev previews.
##
## Each eye is a stack of layers, back to front, each shifted sideways for its
## depth: what a game registers (its 3D world from a left and a right camera,
## background layers such as stars), then the 2D overlay on top: the whole
## single-screen page (HUD, DMD, panels) drawn once, without the game's world,
## and shifted so it floats in front of the screen.
##   --stereo=sr        weave for the SR display (the default when one is found)
##   --stereo=sbs       side-by-side preview in the window (screenshots)
##   --stereo=anaglyph  red/cyan preview
##   --stereo=off       no stereo
## Depths are in window pixels at a 1920-wide window (scaled to the window),
## positive in front of the screen. The pair is laid out side by side, each
## eye at the window's size, and woven by the LeiaSR GDExtension (native/).
extends Node

const ANAGLYPH_SHADER = preload("res://core/shaders/stereo_anaglyph.gdshader")
const MODES := ["off", "sbs", "anaglyph", "sr"]
const REF_WIDTH := 1920.0
const DXGI_R8G8B8A8_UNORM := 28
## How far the 2D overlay (HUD and DMD) floats in front, at REF_WIDTH.
const UI_DEPTH := 14.0
## Frames from weaving to the picture on screen, for eye prediction (D-420).
const WEAVE_LATENCY_FRAMES := 3

signal toggled(on: bool)

var mode := "off"
var ui_depth := UI_DEPTH
var _layers: Array[Dictionary] = []
var _page: Control              # Screens' single-screen page, moved into _mono
var _page_parent: Node
var _mono: SubViewport          # the 2D overlay, transparent
var _sbs: SubViewport           # left eye | right eye
var _eyes: Array[Control] = []
var _overlays: Array[TextureRect] = []
var _canvas: CanvasLayer
var _out: TextureRect
var _sr: Object                 # LeiaSR (GDExtension), when weaving
var _out_rid := RID()
var _out_size := Vector2i.ZERO
var _sr_display := PackedFloat64Array()


func _ready() -> void:
	process_priority = 1000   # after the games have moved their cameras
	var want := str(Config.cli.get("stereo", "auto"))
	if want == "auto":
		# Dev runs (scripts/dev_run.sh) stay off the director's screens (D-393),
		# so they never take the SR display fullscreen unless asked to.
		if Config.cli.has("dev-offscreen"):
			want = "off"
		else:
			want = "sr" if _sr_available() else "off"
	if want not in MODES:
		want = "off"
	mode = want
	if mode == "sr" and not _open_sr():
		mode = "off"


## True when stereo output is on (games then register their layers).
func active() -> bool:
	return mode != "off" and _page != null


func _sr_available() -> bool:
	if Screens.is_headless() or not ClassDB.class_exists("LeiaSR"):
		return false
	return _open_sr()


func _open_sr() -> bool:
	if _sr != null:
		return true
	if not ClassDB.class_exists("LeiaSR") or RenderingServer.get_rendering_device() == null:
		return false
	var sr: Object = ClassDB.instantiate("LeiaSR")
	if not sr.call("runtime_installed") or not sr.call("open", 0.5):
		print("Stereo: no SR display (%s)" % sr.call("last_error"))
		return false
	_sr = sr
	_sr_display = sr.call("display_info")
	return true


## Called by Screens once the single-screen page exists (and again if rebuilt).
func attach(page: Control) -> void:
	if mode == "off" or page == null or page == _page:
		return
	_page = page
	_page_parent = page.get_parent()
	if _mono == null:
		_build()
	_page_parent.remove_child(page)
	_mono.add_child(page)
	Screens.table.transparent_bg = true
	Screens.set_stereo_page(true)
	if mode == "sr":
		_go_to_sr_display()
		var hwnd := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
		var rd := RenderingServer.get_rendering_device()
		var dev := rd.get_driver_resource(RenderingDevice.DRIVER_RESOURCE_LOGICAL_DEVICE, RID(), 0)
		if not _sr.call("create_weaver", hwnd, dev):
			push_warning("Stereo: weaver failed (%s); showing side by side" % _sr.call("last_error"))
			mode = "sbs"
		else:
			# D-420: the pair holds sRGB-encoded colour, so the weaver's crosstalk
			# cancelling works in linear light. Latency: our weave reads the
			# previous frame's pair, plus Godot's frame queue.
			_sr.call("configure", true, WEAVE_LATENCY_FRAMES)
	toggled.emit(true)


func _build() -> void:
	_mono = SubViewport.new()
	_mono.name = "StereoOverlay"
	_mono.transparent_bg = true
	_mono.disable_3d = true
	_mono.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mono)
	_sbs = SubViewport.new()
	_sbs.name = "StereoPair"
	_sbs.disable_3d = true
	_sbs.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sbs)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sbs.add_child(bg)
	for i in 2:
		var eye := Control.new()
		eye.name = "Left" if i == 0 else "Right"
		eye.clip_contents = true
		_sbs.add_child(eye)
		_eyes.append(eye)
		var ov := TextureRect.new()
		ov.name = "Overlay"
		ov.texture = _mono.get_texture()
		ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ov.stretch_mode = TextureRect.STRETCH_SCALE
		eye.add_child(ov)
		_overlays.append(ov)
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)
	_out = TextureRect.new()
	_out.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_out.stretch_mode = TextureRect.STRETCH_SCALE
	_out.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_out)
	if mode == "anaglyph":
		var m := ShaderMaterial.new()
		m.shader = ANAGLYPH_SHADER
		_out.material = m


# --- layers registered by games ----------------------------------------------------
## Adds a layer under the overlay. `textures` is [left, right] (or one texture
## for both); `rect` is in TABLE base coordinates (null: the whole TABLE);
## `depth` in REF_WIDTH pixels, positive in front. A layer with no texture is a
## ColorRect drawn with `material` (e.g. a shader background). `follow` (a
## CanvasItem) shows the layer only while that node is visible. Returns the
## layer, whose fields can be changed later (call refresh_layer()).
func add_layer(textures: Array, depth: float, material: Material = null, rect: Variant = null,
		follow: CanvasItem = null, filter := CanvasItem.TEXTURE_FILTER_PARENT_NODE) -> Dictionary:
	var layer := {"textures": textures, "depth": depth, "material": material, "rect": rect,
		"follow": follow, "filter": filter, "nodes": []}
	if not active():
		return layer
	for i in 2:
		var n: CanvasItem
		if textures.is_empty():
			n = ColorRect.new()
		else:
			var tr_ := TextureRect.new()
			tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_.stretch_mode = TextureRect.STRETCH_SCALE
			n = tr_
		_eyes[i].add_child(n)
		_eyes[i].move_child(n, _eyes[i].get_child_count() - 2)   # under the overlay
		layer.nodes.append(n)
	_layers.append(layer)
	refresh_layer(layer)
	return layer


## Applies a layer's textures, material and filter again after changing them.
func refresh_layer(layer: Dictionary) -> void:
	var tex: Array = layer.textures
	for i in layer.nodes.size():
		var n: CanvasItem = layer.nodes[i]
		if n is TextureRect:
			(n as TextureRect).texture = tex[mini(i, tex.size() - 1)]
		n.material = layer.material
		n.texture_filter = layer.filter


func remove_layer(layer: Dictionary) -> void:
	for n in layer.nodes:
		if is_instance_valid(n):
			n.queue_free()
	layer.nodes.clear()
	_layers.erase(layer)


## Removes every game layer (a game module calls this when it leaves).
func clear_layers() -> void:
	for layer in _layers.duplicate():
		remove_layer(layer)
	if active():
		Screens.table.disable_3d = false   # a game may have moved its 3D to the eyes


## Window pixels per REF_WIDTH pixel of depth.
func depth_scale() -> float:
	return float(get_window().size.x) / REF_WIDTH


# --- camera pairs ------------------------------------------------------------------
## Perspective pair from `mono`: parallel eyes either side of it, frusta shifted
## so the plane `converge` metres ahead has no parallax (nearer pops out,
## further sinks). `far_frac` sets their spacing: the parallax of infinity as a
## fraction of the image width. No head tracking (D-422).
func perspective_pair(mono: Camera3D, left: Camera3D, right: Camera3D, converge: float, far_frac: float) -> void:
	var w_near := 2.0 * mono.near * tan(deg_to_rad(mono.fov) * 0.5)
	var sep := far_frac * w_near * converge / mono.near
	for i in 2:
		var c: Camera3D = left if i == 0 else right
		var x := (-0.5 if i == 0 else 0.5) * sep
		c.keep_aspect = mono.keep_aspect
		c.projection = Camera3D.PROJECTION_FRUSTUM
		c.near = mono.near
		c.far = mono.far
		c.cull_mask = mono.cull_mask
		c.environment = mono.environment
		c.global_transform = mono.global_transform.translated_local(Vector3(x, 0.0, 0.0))
		c.frustum_offset = Vector2(-x * mono.near / converge, 0.0)
		c.size = w_near


## Orthographic pair from `mono`: each eye turned by half of `angle_deg` about
## the camera's vertical axis through `pivot`, so things in front of the pivot
## pop out and things behind it sink.
func ortho_pair(mono: Camera3D, left: Camera3D, right: Camera3D, pivot: Vector3, angle_deg: float) -> void:
	for i in 2:
		var c: Camera3D = left if i == 0 else right
		var a := deg_to_rad(angle_deg) * (-0.5 if i == 0 else 0.5)   # left eye swings left
		c.projection = Camera3D.PROJECTION_ORTHOGONAL
		c.keep_aspect = mono.keep_aspect
		c.size = mono.size
		c.near = mono.near
		c.far = mono.far
		c.cull_mask = mono.cull_mask
		var t := mono.global_transform
		t.origin -= pivot
		t = Transform3D(Basis(mono.global_basis.y, a), Vector3.ZERO) * t
		t.origin += pivot
		c.global_transform = t


# --- per frame --------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not active():
		return
	var win := get_window().size
	if _mono.size != win:
		_mono.size = win
	if _sbs.size != Vector2i(win.x * 2, win.y):
		_sbs.size = Vector2i(win.x * 2, win.y)
	var k := depth_scale()
	for i in 2:
		var side := 0.5 if i == 0 else -0.5   # left eye moves near things right
		_eyes[i].position = Vector2(win.x * i, 0)
		_eyes[i].size = Vector2(win)
		_overlays[i].position = Vector2(side * ui_depth * k, 0)
		_overlays[i].size = Vector2(win)
	for layer in _layers:
		var r := Screens.table_rect_in_window(layer.rect)
		var shown := true
		var f: CanvasItem = layer.follow
		if f != null:
			shown = is_instance_valid(f) and f.is_visible_in_tree()
		for i in layer.nodes.size():
			var n: Control = layer.nodes[i]
			var side := 0.5 if i == 0 else -0.5
			n.visible = shown
			n.position = r.position + Vector2(side * float(layer.depth) * k, 0)
			n.size = r.size
	match mode:
		"sbs", "anaglyph":
			_out.texture = _sbs.get_texture()
		"sr":
			_weave_frame(win)


func _go_to_sr_display() -> void:
	if _sr_display.size() < 4:
		return
	var r := Rect2i(int(_sr_display[0]), int(_sr_display[1]), int(_sr_display[2]), int(_sr_display[3]))
	for s in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_position(s) == r.position:
			var w := get_window()
			w.current_screen = s
			w.mode = Window.MODE_FULLSCREEN
			return


func _weave_frame(win: Vector2i) -> void:
	var rd := RenderingServer.get_rendering_device()
	if _out_size != win:
		if _out_rid.is_valid():
			rd.free_rid(_out_rid)
		var f := RDTextureFormat.new()
		f.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		f.width = win.x
		f.height = win.y
		f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
		_out_rid = rd.texture_create(f, RDTextureView.new())
		var t := Texture2DRD.new()
		t.texture_rd_rid = _out_rid
		_out.texture = t
		_out_size = win
	var in_rid := RenderingServer.texture_get_rd_texture(_sbs.get_texture().get_rid())
	RenderingServer.call_on_render_thread(_weave_on_render_thread.bind(in_rid, _out_rid, win))


func _weave_on_render_thread(in_rid: RID, out_rid: RID, win: Vector2i) -> void:
	var rd := RenderingServer.get_rendering_device()
	var queue := rd.get_driver_resource(RenderingDevice.DRIVER_RESOURCE_COMMAND_QUEUE, RID(), 0)
	var inp := rd.get_driver_resource(RenderingDevice.DRIVER_RESOURCE_TEXTURE, in_rid, 0)
	var outp := rd.get_driver_resource(RenderingDevice.DRIVER_RESOURCE_TEXTURE, out_rid, 0)
	if queue == 0 or inp == 0 or outp == 0:
		return
	_sr.call("weave", queue, inp, win.x * 2, win.y, DXGI_R8G8B8A8_UNORM, outp, win.x, win.y, DXGI_R8G8B8A8_UNORM)


func _exit_tree() -> void:
	if _sr != null:
		_sr.call("close")
	if _out_rid.is_valid():
		RenderingServer.get_rendering_device().free_rid(_out_rid)
