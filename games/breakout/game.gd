## TILT BREAKER (D-037): block breaker for pinball cabinets. This module renders the
## pure simulation (sim.gd) in 3D on the TABLE, shows status on DMD + BACKGLASS, and
## maps cabinet actions (D-007):
##   flippers (hold) = move paddle   Launch = serve   magna saves = paddle dash
## Step 1 of M2: controls feel. Flippers in stages, multi-paddle, multi-floor,
## brick types and power-ups come in later steps (GDD §5.1).
extends "res://core/game_module.gd"

const Sim = preload("res://games/breakout/sim.gd")
const UI = preload("res://core/ui/ui.gd")
const Synth = preload("res://core/util/synth.gd")
const ScoreTable = preload("res://core/util/score_table.gd")

const ACCENT := Color("3ec7ff")
const PADDLE_MODEL := "res://assets/models/breakout/paddle.glb"
const MODEL_PADDLE_WIDTH := 1.9  # paddle.glb's native length along X
const ROW_COLORS := [Color("ff4f6d"), Color("ff9a3e"), Color("ffd23e"), Color("4fff7a"), Color("3ec7ff"), Color("b36bff")]
const GAME_OVER_SECONDS := 2.5
## Camera lean towards the player (0 = straight down). Shows the sides of the 3D
## paddle and bricks while keeping the playfield readable (D-040).
const CAMERA_TILT_DEG := 20.0

const SOUNDS := {
	"tb_paddle": [[520.0, 780.0, 0.05, "square", 0.22]],
	"tb_wall": [[300.0, 300.0, 0.025, "triangle", 0.25]],
	"tb_brick": [[880.0, 1320.0, 0.06, "square", 0.2]],
	"tb_lost": [[440.0, 110.0, 0.5, "square", 0.25]],
	"tb_dash": [[200.0, 900.0, 0.08, "noise", 0.15]],
	"tb_serve": [[660.0, 990.0, 0.08, "triangle", 0.3]],
	"tb_rack": [[523.0, 523.0, 0.08], [784.0, 784.0, 0.08], [1047.0, 1047.0, 0.08], [1568.0, 1568.0, 0.3]],
}

var sim: Sim
var _root: Node3D
var _paddle: Node3D
var _ball: MeshInstance3D
var _brick_nodes: Array[MeshInstance3D] = []
var _brick_mats: Array[StandardMaterial3D] = []
var _hud_score: Label
var _hud_balls: Label
var _hint: Label
var _bg_score: Label
var _bg_balls: Label
var _launch := false
var _dash := 0
var _over_left := -1.0
var _shown_score := -1


func get_info() -> Dictionary:
	return {"id": "breakout", "title_key": "GAME_BREAKOUT_TITLE", "color": ACCENT, "buttons_min": 3}


func start(_players: int) -> void:
	for s in SOUNDS:
		Audio.register_sfx(s, Synth.make(SOUNDS[s]))
	_make_materials()
	sim = Sim.new()
	sim.setup(int(Config.get_value("operator", "balls_per_game")))
	_build_world()
	_build_bricks()
	_build_hud()
	_build_backglass()
	_refresh_status()


func on_action(action: StringName, pressed: bool) -> void:
	if not pressed:
		return
	match action:
		&"launch":
			_launch = true
		&"magna_l":
			_dash = -1
		&"magna_r":
			_dash = 1


func _process(delta: float) -> void:
	if sim == null:
		return
	if _over_left > 0.0:
		_over_left -= delta
		if _over_left <= 0.0:
			finished.emit([sim.score])
		return
	sim.step(minf(delta, 0.05), CabinetInput.is_down(&"flip_l"), CabinetInput.is_down(&"flip_r"), _launch, _dash)
	_launch = false
	_dash = 0
	_handle_events()
	_sync_visuals()


# --- events ------------------------------------------------------------------------
func _handle_events() -> void:
	for e in sim.events:
		match e[0]:
			"paddle":
				Audio.sfx("tb_paddle")
			"wall":
				Audio.sfx("tb_wall")
			"brick":
				_brick_nodes[e[1]].visible = false
				Audio.sfx("tb_brick")
			"serve":
				Audio.sfx("tb_serve")
				_hint.visible = false
			"dash":
				Audio.sfx("tb_dash")
			"rack_clear":
				Audio.sfx("tb_rack")
				Dmd.flash(tr("DMD_RACK_CLEAR"), 2.0, Dmd.GREEN)
				for n in _brick_nodes:
					n.visible = true
				_hint.visible = true
			"lost":
				Audio.sfx("tb_lost")
				if sim.state != Sim.State.OVER:
					Dmd.flash(tr("DMD_BALL_LOST"), 1.5, Dmd.RED)
					_hint.visible = true
				_refresh_status()
			"over":
				Dmd.flash(tr("DMD_GAME_OVER"), GAME_OVER_SECONDS, Dmd.RED)
				_over_left = GAME_OVER_SECONDS
	if sim.score != _shown_score:
		_refresh_status()


func _refresh_status() -> void:
	_shown_score = sim.score
	score_changed.emit(0, sim.score)
	var ball_no := clampi(int(Config.get_value("operator", "balls_per_game")) - sim.balls_left + 1, 1, 99)
	var score_txt := ScoreTable.format_score(sim.score)
	_hud_score.text = score_txt
	_hud_balls.text = tr("HUD_BALLS") % sim.balls_left
	_bg_score.text = score_txt
	_bg_balls.text = tr("HUD_BALLS") % sim.balls_left
	Dmd.show_score(sim.score, tr("DMD_PLAYER_1"), tr("DMD_BALL") % ball_no, ACCENT)


# --- visuals -----------------------------------------------------------------------
func _sync_visuals() -> void:
	_paddle.position = Vector3(sim.paddle_x, 0.0, Sim.PADDLE_Y)
	# Slight bank when moving fast — reads as motion on a top-down view.
	_paddle.rotation.z = clampf(-sim.paddle_vx * 0.012, -0.15, 0.15)
	_ball.position = Vector3(sim.ball_pos.x, 0.0, sim.ball_pos.y)


func _make_materials() -> void:
	_brick_mats.clear()
	for c in ROW_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.12
		m.roughness = 0.55
		m.metallic = 0.0
		m.metallic_specular = 0.15
		_brick_mats.append(m)


func _build_world() -> void:
	_root = Node3D.new()
	_root.name = "TiltBreakerWorld"
	add_to_table(_root)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.025, 0.05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.environment.ambient_light_energy = 0.45
	# Linear keeps arcade colours saturated (filmic washes bright albedo to pastel).
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.35
	env.environment.glow_hdr_threshold = 1.2
	_root.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_energy = 0.9
	_root.add_child(sun)

	# Orthographic camera, leaning CAMERA_TILT_DEG towards the player. size 16 on a
	# 9:16 TABLE = 9 units wide (the playfield); tilt leaves spare height for the HUD.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 16.0
	var t := deg_to_rad(CAMERA_TILT_DEG)
	var target := Vector3(0, 0, 0.6)
	cam.position = target + Vector3(0, cos(t), sin(t)) * 20.0
	cam.near = 1.0
	cam.far = 60.0
	_root.add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true

	# Floor and walls
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.015, 0.02, 0.05)
	floor_mat.roughness = 1.0
	# Orthographic camera + directional light = uniform specular sheen on flat
	# surfaces (looks like grey fog), so the floor has no specular at all.
	floor_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_root.add_child(_box(Vector3(10, 0.1, 17), Vector3(0, -0.5, 0.3), floor_mat))
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.15, 0.2, 0.3)
	wall_mat.emission_enabled = true
	wall_mat.emission = ACCENT
	wall_mat.emission_energy_multiplier = 0.45
	wall_mat.albedo_color = Color(0.05, 0.08, 0.12)
	wall_mat.metallic_specular = 0.1
	var f := Sim.FIELD
	var wall_len := Sim.DRAIN_Y - f.position.y + 1.0
	var wall_cz := f.position.y + wall_len * 0.5
	_root.add_child(_box(Vector3(0.3, 0.5, wall_len), Vector3(f.position.x - 0.15, 0, wall_cz), wall_mat))
	_root.add_child(_box(Vector3(0.3, 0.5, wall_len), Vector3(f.end.x + 0.15, 0, wall_cz), wall_mat))
	_root.add_child(_box(Vector3(f.size.x + 0.6, 0.5, 0.3), Vector3(0, 0, f.position.y - 0.15), wall_mat))

	# Paddle: director's model, scaled to the gameplay width.
	_paddle = Node3D.new()
	_root.add_child(_paddle)
	var scene := load(PADDLE_MODEL) as PackedScene
	if scene:
		var model := scene.instantiate() as Node3D
		var s := Sim.PADDLE_W / MODEL_PADDLE_WIDTH
		model.scale = Vector3(s, s, s)
		_paddle.add_child(model)
	else:
		_paddle.add_child(_box(Vector3(Sim.PADDLE_W, 0.3, Sim.PADDLE_H), Vector3.ZERO, wall_mat))

	# Ball
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Sim.BALL_R
	sphere.height = Sim.BALL_R * 2.0
	_ball.mesh = sphere
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color.WHITE
	ball_mat.emission_enabled = true
	ball_mat.emission = Color(0.8, 0.95, 1.0)
	ball_mat.emission_energy_multiplier = 2.5
	_ball.material_override = ball_mat
	_root.add_child(_ball)
	_sync_visuals()


func _build_bricks() -> void:
	_brick_nodes.clear()
	for b in sim.bricks:
		var r: Rect2 = b.rect
		var n := _box(Vector3(r.size.x, 0.3, r.size.y), Vector3(r.get_center().x, 0, r.get_center().y),
			_brick_mats[b.row % _brick_mats.size()])
		_root.add_child(n)
		_brick_nodes.append(n)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m


func _build_hud() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 40
	bar.offset_right = -40
	bar.offset_top = 14
	add_to_table(bar)
	_hud_score = UI.label("0", 56, UI.YELLOW, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_hud_score)
	_hud_balls = UI.label("", 44, UI.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	bar.add_child(_hud_balls)
	_hint = UI.label(tr("TB_PRESS_LAUNCH"), 52, UI.WHITE)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -560
	_hint.offset_left = -400
	_hint.offset_right = 400
	add_to_table(_hint)


func _build_backglass() -> void:
	add_to_backglass(UI.fill(ACCENT.darkened(0.85)))
	var col := UI.vstack(30)
	add_to_backglass(col)
	col.add_child(UI.label(tr("GAME_BREAKOUT_TITLE"), 150, ACCENT))
	_bg_score = UI.label("0", 130, UI.YELLOW)
	col.add_child(_bg_score)
	_bg_balls = UI.label("", 64, UI.WHITE)
	col.add_child(_bg_balls)
