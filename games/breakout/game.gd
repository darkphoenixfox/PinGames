## TILT BREAKER (D-037): block breaker for pinball cabinets. This module renders the
## pure simulation (sim.gd) in 3D on the TABLE, shows status on DMD + BACKGLASS, and
## maps cabinet actions (D-007):
##   flippers (hold) = move ship   Launch/Start = fire plasma   magna saves = dash
## Fiction (D-041): the bricks are a sentient, self-replicating nanomachine swarm.
## The player's ship fires a plasma shot; its energy shield deflects the plasma
## back at the swarm. Lives are the ship's energy charges.
extends "res://core/game_module.gd"

const Sim = preload("res://games/breakout/sim.gd")
const Fx = preload("res://games/breakout/fx.gd")
const UI = preload("res://core/ui/ui.gd")
const Synth = preload("res://core/util/synth.gd")
const ScoreTable = preload("res://core/util/score_table.gd")
const BRICK_SHADER = preload("res://games/breakout/shaders/brick_circuit.gdshader")
const SHIELD_SHADER = preload("res://games/breakout/shaders/shield.gdshader")
const EXPLOSION_SHADER = preload("res://games/breakout/shaders/pixel_explosion.gdshader")
const LIFE_ICON_SHADER = preload("res://games/breakout/shaders/plasma_icon.gdshader")

const ACCENT := Color("3ec7ff")
const PADDLE_MODEL := "res://assets/models/breakout/paddle.glb"
const MODEL_PADDLE_WIDTH := 1.9  # paddle.glb's native length along X
const ENGINE_X := 0.74           # engine nozzles, after scaling to PADDLE_W
## Brick textures (D-045): the director's circuit_<colour>.png, downsampled to
## 512 px (scripts/tools/prepare_circuit_textures.py). Each brick shows its own
## random rectangle. Rows top->bottom: red, red, green, green, blue, blue.
const CIRCUIT_COLOURS := ["red", "red", "green", "green", "blue", "blue"]
const CIRCUIT_GLOW := {"red": Color("ff5a32"), "green": Color("4dff6a"), "blue": Color("3ec7ff")}
const CIRCUIT_TEXELS := 512.0
const BRICK_TEXELS_W := 64.0  # texels across one brick (chunky pixel size)
## Game-over finale (D-044): explosion fills the screen, fade to black, then
## GAME OVER + score; Launch/Start may skip once the score is shown.
const FINALE_FADE_AT := 0.9
const FINALE_FADE_TIME := 0.8
const FINALE_TEXT_AT := 1.9
const FINALE_SKIP_AT := 2.6
const FINALE_END_AT := 6.0
## Camera lean towards the player (0 = straight down) (D-040).
const CAMERA_TILT_DEG := 20.0
## Ship banking (visual only; the hitbox is always the sim's rectangle).
const MAX_BANK_DEG := 18.0
const BANK_RESPONSE := 10.0
const SHIELD_FADE := 0.45
## Firing recoil: the ship kicks back towards the player and shakes (D-042).
const RECOIL_SECONDS := 0.3
const RECOIL_KICK := 0.18
const RECOIL_SHAKE := 0.05
## Backdrop planet (D-043): radius (bigger = flatter horizon), where its horizon
## sits on screen (units above the bottom edge), and depth-of-field focus.
const PLANET_RADIUS := 100.0
const PLANET_RIM_ABOVE_BOTTOM := 1.7
const PLANET_DEPTH_BEHIND := 30.0

const SOUNDS := {
	"tb_shield": [[520.0, 900.0, 0.06, "triangle", 0.3], [900.0, 700.0, 0.05, "noise", 0.08]],
	"tb_wall": [[300.0, 300.0, 0.025, "triangle", 0.25]],
	"tb_brick": [[880.0, 1320.0, 0.05, "square", 0.18], [1400.0, 300.0, 0.08, "noise", 0.12]],
	"tb_explode": [[900.0, 60.0, 0.9, "noise", 0.45]],
	"tb_explode_big": [[1400.0, 40.0, 0.4, "noise", 0.6], [500.0, 25.0, 1.8, "noise", 0.55]],
	"tb_dash": [[200.0, 900.0, 0.08, "noise", 0.15]],
	"tb_fire": [[1600.0, 300.0, 0.18, "square", 0.22], [600.0, 200.0, 0.12, "noise", 0.12]],
	"tb_rack": [[523.0, 523.0, 0.08], [784.0, 784.0, 0.08], [1047.0, 1047.0, 0.08], [1568.0, 1568.0, 0.3]],
}

var sim: Sim
var _root: Node3D
var _cam: Camera3D
var _planet: Fx.Planet
var _paddle: Node3D       # follows the sim position
var _ship: Node3D         # child of _paddle; banks visually
var _engines: Array = []  # [left, right] Fx.ShipEngine
var _shield_mat: ShaderMaterial
var _shield_age := 99.0
var _ball: Node3D
var _halo: MeshInstance3D
var _trail: Fx.Trail
var _brick_nodes: Array[MeshInstance3D] = []
var _brick_mats := {}  # colour -> ShaderMaterial
var _life_icons: Array[ColorRect] = []
var _hud_score: Label
var _hint: Label
var _bg_score: Label
var _bg_charges: Label
var _launch := false
var _dash := 0
var _dash_glow := 0.0
var _fire_flash := 0.0
var _recoil := 0.0
var _finale_t := -1.0
var _finale_black: ColorRect
var _finale_text: Control
var _shown_score := -1


func get_info() -> Dictionary:
	return {"id": "breakout", "title_key": "GAME_BREAKOUT_TITLE", "color": ACCENT, "buttons_min": 3}


func start(_players: int) -> void:
	for s in SOUNDS:
		Audio.register_sfx(s, Synth.make(SOUNDS[s]))
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
	if _finale_t >= FINALE_SKIP_AT and (action == &"launch" or action == &"start"):
		_finale_t = FINALE_END_AT
		return
	match action:
		&"launch", &"start":
			_launch = true
		&"magna_l":
			_dash = -1
		&"magna_r":
			_dash = 1


func _process(delta: float) -> void:
	if sim == null:
		return
	if _finale_t >= 0.0:
		_finale(delta)
		_animate(delta)
		return
	sim.step(minf(delta, 0.05), CabinetInput.is_down(&"flip_l"), CabinetInput.is_down(&"flip_r"), _launch, _dash)
	_launch = false
	_dash = 0
	_handle_events()
	_animate(delta)


# --- events ------------------------------------------------------------------------
func _handle_events() -> void:
	for e in sim.events:
		match e[0]:
			"paddle":
				Audio.sfx("tb_shield")
				_shield_age = 0.0
				_shield_mat.set_shader_parameter("hit_x",
					clampf((sim.ball_pos.x - sim.paddle_x) / (Sim.PADDLE_W * 0.5), -1.0, 1.0))
			"wall":
				Audio.sfx("tb_wall")
			"brick":
				var n := _brick_nodes[e[1]]
				n.visible = false
				_explode_brick(n.position, _row_glow(sim.bricks[e[1]].row))
				Audio.sfx("tb_brick")
			"serve":
				Audio.sfx("tb_fire")
				_fire_flash = 1.0
				_recoil = 1.0
				_trail.clear()
				_hint.visible = false
			"dash":
				Audio.sfx("tb_dash")
				_dash_glow = 1.0
			"rack_clear":
				Audio.sfx("tb_rack")
				Dmd.flash(tr("DMD_RACK_CLEAR"), 2.0, Dmd.GREEN)
				for n in _brick_nodes:
					n.visible = true
					_randomize_crop(n)
				_trail.clear()
				_hint.visible = true
			"lost":
				var last := sim.state == Sim.State.OVER
				Audio.sfx("tb_explode_big" if last else "tb_explode")
				_planet.impact(Vector3(e[1], 0.0, Sim.DRAIN_Y), -_cam.global_transform.basis.z, last)
				_trail.clear()
				if sim.state != Sim.State.OVER:
					Dmd.flash(tr("TB_CHARGE_LOST"), 1.5, Dmd.RED)
					_hint.visible = true
				_refresh_status()
			"over":
				_finale_t = 0.0
				_hint.visible = false
	if sim.score != _shown_score:
		_refresh_status()


func _refresh_status() -> void:
	_shown_score = sim.score
	score_changed.emit(0, sim.score)
	var score_txt := ScoreTable.format_score(sim.score)
	var charges := tr("TB_CHARGES") % sim.balls_left
	_hud_score.text = score_txt
	_update_life_icons()
	_bg_score.text = score_txt
	_bg_charges.text = charges
	Dmd.show_score(sim.score, tr("DMD_PLAYER_1"), charges, ACCENT)


# --- game-over finale (D-044) -----------------------------------------------------------
func _finale(delta: float) -> void:
	var before := _finale_t
	_finale_t += delta
	if before < FINALE_FADE_AT and _finale_t >= FINALE_FADE_AT:
		_finale_black = UI.fill(Color(0, 0, 0, 0))
		add_to_table(_finale_black)
		var tw := _finale_black.create_tween()
		tw.tween_property(_finale_black, "color:a", 1.0, FINALE_FADE_TIME)
	if before < FINALE_TEXT_AT and _finale_t >= FINALE_TEXT_AT:
		var col := UI.vstack(40)
		col.add_child(UI.label(tr("DMD_GAME_OVER"), 140, UI.RED))
		col.add_child(UI.spacer(40))
		col.add_child(UI.label(tr("TB_FINAL_SCORE"), 60, UI.WHITE))
		col.add_child(UI.label(ScoreTable.format_score(sim.score), 130, UI.YELLOW))
		col.modulate.a = 0.0
		add_to_table(col)
		col.create_tween().tween_property(col, "modulate:a", 1.0, 0.5)
		_finale_text = col
		_bg_score.text = tr("DMD_GAME_OVER")
		_bg_charges.text = ScoreTable.format_score(sim.score)
		Dmd.show_text(tr("DMD_GAME_OVER"), ScoreTable.format_score(sim.score), Dmd.RED, Dmd.YELLOW)
	if _finale_t >= FINALE_END_AT:
		_finale_t = -1.0
		finished.emit([sim.score])


# --- per-frame visuals ----------------------------------------------------------------
func _animate(delta: float) -> void:
	_paddle.position = Vector3(sim.paddle_x, 0.0, Sim.PADDLE_Y)
	# Bank into the movement (visual only).
	var target_bank := -sim.paddle_vx / Sim.PADDLE_MAX_SPEED * deg_to_rad(MAX_BANK_DEG)
	target_bank = clampf(target_bank, -deg_to_rad(MAX_BANK_DEG) * 1.4, deg_to_rad(MAX_BANK_DEG) * 1.4)
	_ship.rotation.z = lerp_angle(_ship.rotation.z, target_bank, 1.0 - exp(-BANK_RESPONSE * delta))
	# Afterburners (D-042): off at rest; only the trailing engine burns while moving
	# (moving right = left engine), harder with speed, flaring on a dash.
	_dash_glow = maxf(0.0, _dash_glow - delta * 4.0)
	var push := sim.paddle_vx / Sim.PADDLE_MAX_SPEED
	var burn := absf(push) + _dash_glow * 0.6
	_engines[0].set_thrust(burn if push > 0.0 else 0.0)
	_engines[1].set_thrust(burn if push < 0.0 else 0.0)
	# Shield flash
	_shield_age += delta
	_shield_mat.set_shader_parameter("age", _shield_age)
	_shield_mat.set_shader_parameter("strength", clampf(1.0 - _shield_age / SHIELD_FADE, 0.0, 1.0))
	# Firing recoil: kick back towards the player + decaying shake.
	_recoil = maxf(0.0, _recoil - delta / RECOIL_SECONDS)
	var r := _recoil * _recoil
	_ship.position = Vector3(randf_range(-1.0, 1.0) * RECOIL_SHAKE * r, 0.0,
		RECOIL_KICK * r + randf_range(-1.0, 1.0) * RECOIL_SHAKE * r)
	# Plasma: only exists once fired (hidden while waiting), flies with a trail.
	var flying := sim.state == Sim.State.PLAY
	_ball.visible = flying
	_trail.visible = flying
	var pos := Vector3(sim.ball_pos.x, 0.05, sim.ball_pos.y)
	_ball.position = pos
	_fire_flash = maxf(0.0, _fire_flash - delta * 5.0)
	_halo.scale = Vector3.ONE * (1.0 + _fire_flash * 1.5)
	if flying:
		_trail.update(pos)


# --- construction ----------------------------------------------------------------------
func _build_world() -> void:
	_root = Node3D.new()
	_root.name = "TiltBreakerWorld"
	add_to_table(_root)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.008, 0.01, 0.025)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.environment.ambient_light_energy = 0.6
	# Linear keeps arcade colours saturated (filmic washes bright albedo to pastel).
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.5
	env.environment.glow_bloom = 0.05
	env.environment.glow_hdr_threshold = 1.0
	_root.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_energy = 1.0
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
	cam.far = 260.0
	# Depth of field: the playfield (~20 units away) stays sharp, the planet blurs.
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 26.0
	attrs.dof_blur_far_transition = 8.0
	attrs.dof_blur_amount = 0.12
	cam.attributes = attrs
	_root.add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true
	_cam = cam

	# No floor: the ship flies in orbit above an earth-like planet (D-043).
	_planet = Fx.Planet.new(PLANET_RADIUS)
	_root.add_child(_planet)
	_planet.place(cam.global_transform.basis, target, -cam.size * 0.5 + PLANET_RIM_ABOVE_BOTTOM, PLANET_DEPTH_BEHIND)

	# Walls
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.05, 0.08, 0.12)
	wall_mat.emission_enabled = true
	wall_mat.emission = ACCENT
	wall_mat.emission_energy_multiplier = 0.45
	wall_mat.metallic_specular = 0.1
	var f := Sim.FIELD
	var wall_len := Sim.DRAIN_Y - f.position.y
	var wall_cz := f.position.y + wall_len * 0.5
	_root.add_child(_box(Vector3(0.3, 0.5, wall_len), Vector3(f.position.x - 0.15, 0, wall_cz), wall_mat))
	_root.add_child(_box(Vector3(0.3, 0.5, wall_len), Vector3(f.end.x + 0.15, 0, wall_cz), wall_mat))
	_root.add_child(_box(Vector3(f.size.x + 0.6, 0.5, 0.3), Vector3(0, 0, f.position.y - 0.15), wall_mat))

	_build_ship(wall_mat)

	# Plasma shot + trail
	_ball = Fx.make_plasma_ball(Sim.BALL_R)
	_halo = _ball.get_child(1) as MeshInstance3D
	_root.add_child(_ball)
	_trail = Fx.Trail.new()
	_trail.width = Sim.BALL_R * 1.1
	_root.add_child(_trail)
	_animate(0.0)


func _build_ship(fallback_mat: Material) -> void:
	_paddle = Node3D.new()
	_paddle.name = "Ship"
	_root.add_child(_paddle)
	_ship = Node3D.new()
	_paddle.add_child(_ship)
	var scene := load(PADDLE_MODEL) as PackedScene
	if scene:
		var model := scene.instantiate() as Node3D
		var s := Sim.PADDLE_W / MODEL_PADDLE_WIDTH
		model.scale = Vector3(s, s, s)
		_ship.add_child(model)
	else:
		_ship.add_child(_box(Vector3(Sim.PADDLE_W, 0.3, Sim.PADDLE_H), Vector3.ZERO, fallback_mat))
	# Side engines (left fires outward to -X, right to +X).
	for side in [-1.0, 1.0]:
		var eng := Fx.ShipEngine.new(side)
		eng.position = Vector3(side * ENGINE_X, 0.0, 0.0)
		_ship.add_child(eng)
		_engines.append(eng)
	# Energy shield in front of the ship.
	var shield := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Sim.PADDLE_W * 1.25, 0.55)
	shield.mesh = plane
	_shield_mat = ShaderMaterial.new()
	_shield_mat.shader = SHIELD_SHADER
	shield.material_override = _shield_mat
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.position = Vector3(0.0, 0.08, -Sim.PADDLE_H * 0.5 - 0.2)
	_ship.add_child(shield)
	# A soft blue key light so the white hull reads under the darker scene.
	var key := OmniLight3D.new()
	key.light_color = Color(0.7, 0.85, 1.0)
	key.omni_range = 2.5
	key.light_energy = 1.2
	key.position = Vector3(0.0, 1.2, 0.4)
	_paddle.add_child(key)


func _row_glow(row: int) -> Color:
	return CIRCUIT_GLOW[CIRCUIT_COLOURS[row % CIRCUIT_COLOURS.size()]]


func _brick_material(colour: String, brick_size: Vector3) -> ShaderMaterial:
	if not _brick_mats.has(colour):
		var m := ShaderMaterial.new()
		m.shader = BRICK_SHADER
		m.set_shader_parameter("circuit", load("res://assets/textures/breakout/circuit_%s.png" % colour))
		m.set_shader_parameter("glow_color", CIRCUIT_GLOW[colour])
		m.set_shader_parameter("brick_size", brick_size)
		# Texture footprint of one brick: BRICK_TEXELS_W across, aspect-correct height.
		var w := BRICK_TEXELS_W / CIRCUIT_TEXELS
		m.set_shader_parameter("crop_size", Vector2(w, w * brick_size.z / brick_size.x))
		m.set_shader_parameter("brick_texels", Vector2(BRICK_TEXELS_W, roundf(BRICK_TEXELS_W * brick_size.z / brick_size.x)))
		_brick_mats[colour] = m
	return _brick_mats[colour]


func _build_bricks() -> void:
	_brick_nodes.clear()
	for i in sim.bricks.size():
		var b: Dictionary = sim.bricks[i]
		var r: Rect2 = b.rect
		var col := i % Sim.BRICK_COLS
		var size := Vector3(r.size.x, 0.3, r.size.y)
		var colour: String = CIRCUIT_COLOURS[int(b.row) % CIRCUIT_COLOURS.size()]
		var n := _box(size, Vector3(r.get_center().x, 0, r.get_center().y), _brick_material(colour, size))
		_randomize_crop(n)
		# Pulse ripples diagonally across the swarm, with a little jitter.
		n.set_instance_shader_parameter("phase", -(col * 0.55 + b.row * 0.8) + float((i * 37) % 11) * 0.08)
		_root.add_child(n)
		_brick_nodes.append(n)


## Each brick shows a rectangle cut from a random, texel-snapped spot (D-045).
func _randomize_crop(n: MeshInstance3D) -> void:
	n.set_instance_shader_parameter("crop_offset",
		Vector2(randi() % int(CIRCUIT_TEXELS), randi() % int(CIRCUIT_TEXELS)) / CIRCUIT_TEXELS)


## Pixel-art explosion (D-046): a dithered, stepped-palette blast billboard plus a
## spray of square "pixel" particles in white/yellow/orange/brick colour.
func _explode_brick(pos: Vector3, color: Color) -> void:
	var blast := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)
	blast.mesh = quad
	var bm := ShaderMaterial.new()
	bm.shader = EXPLOSION_SHADER
	bm.set_shader_parameter("tint", color)
	blast.material_override = bm
	blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blast.position = pos + Vector3(0, 0.25, 0)
	blast.set_instance_shader_parameter("seed", randf() * 100.0)
	_root.add_child(blast)
	var tw := blast.create_tween()
	tw.tween_method(func(a: float): blast.set_instance_shader_parameter("age", a), 0.0, 1.0, 0.45)
	tw.tween_callback(blast.queue_free)

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 28
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 85.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -5, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, 0.05, 0.12)
	var palette := Gradient.new()  # each particle picks one flat colour
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	palette.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
	palette.colors = PackedColorArray([Color.WHITE, Color(1.0, 0.9, 0.4), Color(1.0, 0.5, 0.15), color])
	p.color_initial_ramp = palette
	var fade := Gradient.new()
	fade.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	fade.offsets = PackedFloat32Array([0.0, 0.7])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var px := QuadMesh.new()  # hard-edged square = a pixel
	px.size = Vector2(0.075, 0.075)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	px.material = pm
	p.mesh = px
	p.position = pos
	_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m


# --- 2D overlays ---------------------------------------------------------------------
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
	# Lives = plasma charges, shown as plasma-ball icons (D-047).
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 6)
	bar.add_child(icons)
	_life_icons.clear()
	for i in maxi(sim.balls_left, 1):
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		var im := ShaderMaterial.new()
		im.shader = LIFE_ICON_SHADER
		im.set_shader_parameter("time_offset", i * 0.7)
		icon.material = im
		icons.add_child(icon)
		_life_icons.append(icon)
	_hint = UI.label(tr("TB_PRESS_LAUNCH"), 52, UI.WHITE)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -560
	_hint.offset_left = -400
	_hint.offset_right = 400
	add_to_table(_hint)


func _update_life_icons() -> void:
	for i in _life_icons.size():
		(_life_icons[i].material as ShaderMaterial).set_shader_parameter("spent", 0.0 if i < sim.balls_left else 1.0)


func _build_backglass() -> void:
	add_to_backglass(UI.fill(ACCENT.darkened(0.85)))
	var col := UI.vstack(30)
	add_to_backglass(col)
	col.add_child(UI.label(tr("GAME_BREAKOUT_TITLE"), 150, ACCENT))
	_bg_score = UI.label("0", 130, UI.YELLOW)
	col.add_child(_bg_score)
	_bg_charges = UI.label("", 64, UI.CYAN)
	col.add_child(_bg_charges)
