## Dev model viewer (D-038): shows a .glb on the TABLE screen, auto-framed and
## turning, so the director can review models without the Godot editor.
##   scripts/run.ps1 --mode=viewer --model=res://assets/models/breakout/paddle.glb
## Flippers: rotate faster left/right. Launch: toggle auto-spin. Start: next view
## preset (3/4, front, top, side). Exit: back to picker.
extends "res://shell/modes/mode.gd"

const VIEWS := [Vector3(25, 35, 0), Vector3(0, 0, 0), Vector3(89, 0, 0), Vector3(0, 90, 0)]

var model_path := ""
var _pivot: Node3D
var _camera: Camera3D
var _spin := true
var _view := 0
var _info: Label


func _init(p_model_path: String) -> void:
	model_path = p_model_path


func enter() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.1, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_table(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.4
	add_table(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.6
	add_table(rim)

	_pivot = Node3D.new()
	add_table(_pivot)
	var scene := load(model_path) as PackedScene
	var aabb := AABB()
	if scene == null:
		push_error("Viewer: cannot load %s" % model_path)
	else:
		var inst := scene.instantiate()
		_pivot.add_child(inst)
		aabb = _scene_aabb(inst)
		inst.position = -aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.1)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	add_table(_camera)
	# Fit the object's bounding sphere in the narrow (horizontal) field of view.
	var hfov := 2.0 * atan(tan(deg_to_rad(_camera.fov) * 0.5) * (9.0 / 16.0))
	_camera.position = Vector3(0, 0, radius / sin(hfov * 0.5) * 1.05)
	_camera.near = radius * 0.05
	_camera.far = radius * 50.0
	_camera.current = true
	_apply_view()

	_info = UI.label("", 34, UI.GREY)
	_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_top = -200
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_table(_info)
	_info.text = "%s\n%.2f x %.2f x %.2f  —  %d tris" % [model_path.get_file(),
		aabb.size.x, aabb.size.y, aabb.size.z, _triangles(_pivot)]
	Dmd.show_text("MODEL VIEWER", model_path.get_file().get_basename().to_upper(), Dmd.CYAN, Dmd.WHITE)


func _process(delta: float) -> void:
	if _spin:
		_pivot.rotate_y(delta * 0.6)
	if CabinetInput.is_down(&"flip_l"):
		_pivot.rotate_y(-delta * 2.0)
	if CabinetInput.is_down(&"flip_r"):
		_pivot.rotate_y(delta * 2.0)


func on_action(action: StringName, pressed: bool) -> void:
	if not pressed:
		return
	match action:
		&"launch":
			_spin = not _spin
		&"start":
			_view = (_view + 1) % VIEWS.size()
			_pivot.rotation = Vector3.ZERO
			_apply_view()
		&"exit":
			shell.goto_picker()


func _apply_view() -> void:
	var v: Vector3 = VIEWS[_view]
	var dist := _camera.position.length()
	var basis := Basis.from_euler(Vector3(deg_to_rad(-v.x), deg_to_rad(v.y), 0))
	_camera.position = basis * Vector3(0, 0, dist)
	_camera.look_at(Vector3.ZERO)


static func _scene_aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "VisualInstance3D", true, false) + ([root] if root is VisualInstance3D else []):
		var vi := n as VisualInstance3D
		var box := vi.global_transform * vi.get_aabb() if vi.is_inside_tree() else vi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _triangles(root: Node) -> int:
	var t := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			t += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t
