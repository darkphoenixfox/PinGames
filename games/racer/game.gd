## TURBO RUN (D-089): arcade road racer prototype. Race the clock through
## checkpoints on an endless seeded road with curves and hills, traffic and
## roadside obstacles. Emphasis on drifting through corners.
## The pure race logic is in sim.gd / track.gd; this module draws it in 3D on
## the TABLE (low-poly "PS2" props, 16-bit textures), with DMD + BACKGLASS.
## Controls (D-007, D-089):
##   flippers = steer; throttle/brake automatic (2+1 buttons)
##   magna_r = accelerate, magna_l = brake (4+1: switches on at the first press
##   when operator.cabinet_buttons = auto, always on when = 4)
##   hold both flippers 2 s = NITRO
extends "res://core/game_module.gd"

const Sim = preload("res://games/racer/sim.gd")
const Track = preload("res://games/racer/track.gd")
const Scenery = preload("res://games/racer/scenery.gd")
const Toon = preload("res://games/racer/toon.gd")
const UI = preload("res://core/ui/ui.gd")
const Synth = preload("res://core/util/synth.gd")
const ScoreTable = preload("res://core/util/score_table.gd")
const ROAD_SHADER = preload("res://games/racer/shaders/road.gdshader")
const CAR_SHADER = preload("res://games/racer/shaders/car.gdshader")
const MOUNTAIN_SHADER = preload("res://games/racer/shaders/mountains.gdshader")
const CAR_MODEL := "res://assets/models/racer/red_car.glb"
## The model's nose points +Z; turn it to face down the road (-Z).
const MODEL_TURN := Basis(Vector3.UP, PI)
## Cars snap to 32 views around the camera, like a sprite set (D-092).
const SPRITE_ANGLES := 32
## Nose turn at full steer (rad): ~1.5 sprite steps, visible on straights.
const STEER_YAW := 0.3
const CAR_TEXTURE := "res://assets/models/racer/red_car_albedo.png"

const ACCENT := Color("ffd23e")
const TITLE_FONT := "sunset"
## Director's pick: "8-bit Music Pack (Loopable)" by CodeManu, CC BY 3.0 (D-033).
## Director's pick (D-093): the five "action" loops for attract and race. Each
## race starts on the next one, and every checkpoint (new stage) moves on again.
## Attract and the first race play action_3 (director's pick).
const FIRST_TRACK := 2
const MUSIC_TRACKS := [
	"res://assets/audio/music/racer/codemanu_action_1.ogg",
	"res://assets/audio/music/racer/codemanu_action_2.ogg",
	"res://assets/audio/music/racer/codemanu_action_3.ogg",
	"res://assets/audio/music/racer/codemanu_action_4.ogg",
	"res://assets/audio/music/racer/codemanu_action_5.ogg",
]
const CHUNK := 100.0             # metres of road per mesh chunk
const VIEW_AHEAD := 900.0
const VIEW_BEHIND := 60.0
const LATERAL := [-140.0, -70.0, -36.0, -18.0, -11.7, -8.7, -7.5, -3.75, 0.0, 3.75, 7.5, 8.7, 11.7, 18.0, 36.0, 70.0, 140.0]
const TRAFFIC_POOL := 10
const CAM_BACK := 8.0
const CAM_HEIGHT := 3.6
const CAM_LOOK := 30.0
const CAM_FOV := 58.0
const SKY_TOP := Color(0.16, 0.18, 0.5)
const SKY_HORIZON := Color(1.0, 0.55, 0.42)
const FINALE_TEXT_AT := 0.6
const FINALE_SKIP_AT := 1.5
const FINALE_END_AT := 6.0

const SOUNDS := {
	"rc_count": {"voices": [[{"f": [880.0, 880.0], "t": 0.18, "w": "pulse25", "v": 0.3, "env": "hold"}]], "echo": [0.08, 0.2, 0.4]},
	"rc_go": {"voices": [[{"f": [1760.0, 1760.0], "t": 0.6, "w": "pulse25", "v": 0.3, "vib": [8.0, 0.2]}],
		[{"f": [880.0, 880.0], "t": 0.6, "w": "triangle", "v": 0.3}]], "echo": [0.1, 0.3, 0.5]},
	"rc_checkpoint": {"voices": [
		[{"f": [784.0, 784.0], "t": 0.09, "w": "pulse25", "v": 0.22, "env": "hold"},
		 {"f": [988.0, 988.0], "t": 0.09, "w": "pulse25", "v": 0.22, "env": "hold"},
		 {"f": [1175.0, 1175.0], "t": 0.09, "w": "pulse25", "v": 0.22, "env": "hold"},
		 {"f": [1568.0, 1568.0], "t": 0.5, "w": "pulse25", "v": 0.24, "vib": [7.0, 0.3]}],
		[{"f": [196.0, 196.0], "t": 0.27, "w": "triangle", "v": 0.35, "env": "hold"},
		 {"f": [392.0, 392.0], "t": 0.5, "w": "triangle", "v": 0.35}]], "echo": [0.1, 0.3, 0.5]},
	"rc_crash": {"voices": [
		[{"f": [3000.0, 90.0], "t": 0.9, "w": "lfsr", "v": 0.45, "lp": 0.4}],
		[{"f": [120.0, 35.0], "t": 0.5, "w": "sine", "v": 0.6}],
		[{"f": [5200.0, 1800.0], "t": 0.35, "w": "noise", "v": 0.15}]], "reverb": [0.8, 0.3]},
	"rc_bump": {"voices": [[{"f": [160.0, 50.0], "t": 0.2, "w": "sine", "v": 0.6}],
		[{"f": [2400.0, 600.0], "t": 0.12, "w": "lfsr", "v": 0.25}]]},
	"rc_nitro": {"voices": [
		[{"f": [200.0, 3000.0], "t": 0.5, "w": "noise", "v": 0.35, "lp": 0.3, "env": "lin"}],
		[{"f": [70.0, 40.0], "t": 0.7, "w": "sine", "v": 0.55}],
		[{"f": [440.0, 1320.0], "t": 0.4, "w": "saw", "v": 0.12, "lp": 0.5}]], "reverb": [0.7, 0.25]},
	"rc_nitro_hold": {"voices": [[{"f": [220.0, 880.0], "t": 2.0, "w": "pulse25", "v": 0.12, "env": "hold", "vib": [14.0, 0.3]}]]},
	"rc_nitro_empty": {"voices": [[{"f": [300.0, 150.0], "t": 0.3, "w": "square", "v": 0.25}]]},
	"rc_nitro_gain": {"voices": [[{"f": [1320.0, 1320.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		{"f": [1760.0, 1760.0], "t": 0.25, "w": "pulse25", "v": 0.2}]], "echo": [0.08, 0.3, 0.5]},
	"rc_near_miss": {"voices": [[{"f": [3000.0, 500.0], "t": 0.35, "w": "noise", "v": 0.3, "lp": 0.5}],
		[{"f": [900.0, 500.0], "t": 0.3, "w": "saw", "v": 0.1, "lp": 0.6}]]},
	"rc_drift_bank": {"voices": [[{"f": [1047.0, 1047.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		{"f": [1568.0, 1568.0], "t": 0.2, "w": "pulse25", "v": 0.2}]]},
	"rc_tick": {"voices": [[{"f": [1200.0, 1200.0], "t": 0.08, "w": "square", "v": 0.18, "env": "hold"}]]},
	"rc_time_up": {"voices": [[{"f": [660.0, 660.0], "t": 0.3, "w": "pulse25", "v": 0.25, "env": "hold"},
		{"f": [494.0, 494.0], "t": 0.3, "w": "pulse25", "v": 0.25, "env": "hold"},
		{"f": [330.0, 330.0], "t": 0.8, "w": "pulse25", "v": 0.25, "vib": [5.0, 0.3]}]], "echo": [0.12, 0.3, 0.5]},
}

var sim: Sim
var _phase := "attract"          # attract, race, finale
var _phase_t := 0.0
var _manual_locked := false      # operator.cabinet_buttons = 4
var _root: Node3D
var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _mountains: MeshInstance3D
var _road_mat: ShaderMaterial
var _chunks := {}                # chunk index -> Node3D
var _car: Node3D                 # player car (road frame)
var _car_body: Node3D            # model; yaws/rolls/spins
var _car_tex: Texture2D
var _car_mat: ShaderMaterial
var _car_outline: ArrayMesh
var _music_i := FIRST_TRACK - 1    # race track index; _begin_race steps it
var _traffic_nodes: Array = []   # pool of Node3D
var _smoke: Array = []           # CPUParticles3D at the rear wheels
var _flames: Array = []          # nitro flame meshes
var _cam_pos := Vector3.ZERO
var _cam_ready := false
var _cam_x := 0.0
var _engine: AudioStreamPlayer
var _skid: AudioStreamPlayer
var _hold_snd: AudioStreamPlayer
var _hud: Control
var _time_label: Label
var _score_label: Label
var _stage_label: Label
var _speed_label: Label
var _mode_label: Label
var _nitro_pips: Array = []
var _nitro_bar: ColorRect
var _nitro_bar_bg: ColorRect
var _drift_label: Label
var _center: Control             # big centre message (styled font)
var _center_t := 0.0
var _attract_ui: Control
var _attract_blink: Label
var _dmd_t := 0.0
var _last_tick := -1
var _finale_t := -1.0
var _finale_ui: Control
var _shake := 0.0


func get_info() -> Dictionary:
	return {"id": "racer", "title_key": "GAME_RACER_TITLE", "color": ACCENT, "font": TITLE_FONT, "buttons_min": 3}


func start(_players: int) -> void:
	for s in SOUNDS:
		Audio.register_sfx(s, Synth.make(SOUNDS[s]))
	_manual_locked = str(Config.get_value("operator", "cabinet_buttons")) == "4"
	# Cel shading (D-091); --rc-no-toon shows the plain look for comparison.
	Toon.enabled = not Config.cli.has("rc-no-toon")
	_build_world()
	_build_hud()
	_build_backglass()
	_build_audio_loops()
	if Config.cli.has("rc-skip-intro"):
		_begin_race()
	else:
		_enter_attract()


func on_action(action: StringName, pressed: bool) -> void:
	if not pressed:
		return
	if _phase == "attract":
		if action == &"start" or action == &"launch":
			_begin_race()
		return
	if _phase == "finale":
		if _finale_t >= FINALE_SKIP_AT and (action == &"launch" or action == &"start"):
			_finale_t = FINALE_END_AT
		return
	if (action == &"magna_l" or action == &"magna_r") and not sim.manual:
		# 4-button cabinet detected: manual throttle/brake from now on (D-089).
		sim.manual = true
		_show_mode()
		Dmd.flash(tr("RC_MANUAL"), 1.2, Dmd.CYAN)


func _process(delta: float) -> void:
	if sim == null:
		return
	_phase_t += delta
	var dt := minf(delta, 0.05)
	if _phase == "attract":
		sim.time_left = 99.0
		sim.step(dt, false, false)
		_attract_tick()
	elif _phase == "race":
		var l := CabinetInput.is_down(&"flip_l")
		var r := CabinetInput.is_down(&"flip_r")
		sim.step(dt, l, r, CabinetInput.is_down(&"magna_r"), CabinetInput.is_down(&"magna_l"))
		_handle_events()
		_update_hud(delta)
		if sim.done and _finale_t < 0.0:
			_begin_finale()
	elif _phase == "finale":
		sim.step(dt, false, false)
		_finale(delta)
	_update_chunks()
	_animate(delta)
	_update_audio()


# --- phases --------------------------------------------------------------------------
func _new_sim() -> void:
	sim = Sim.new()
	sim.setup(7)
	sim.manual = _manual_locked
	sim.autopilot = Config.cli.has("rc-autopilot")
	if Config.cli.has("rc-time"):  # dev: short clock to test TIME UP
		sim.time_left = float(str(Config.cli["rc-time"]))
	for k in _chunks.keys():
		_chunks[k].queue_free()
	_chunks.clear()
	_cam_ready = false


func _enter_attract() -> void:
	_phase = "attract"
	_phase_t = 0.0
	_new_sim()
	sim.autopilot = true
	sim.state = Sim.State.RACE
	sim.v = 60.0
	Audio.play_music(MUSIC_TRACKS[FIRST_TRACK])
	_hud.visible = false
	_attract_ui = UI.vstack(60)
	_attract_ui.add_child(UI.spacer(200))
	_attract_ui.add_child(UI.styled_label(tr("GAME_RACER_TITLE"), TITLE_FONT, 4))
	_attract_blink = UI.styled_label(tr("RC_PRESS_START"), TITLE_FONT, 2)
	_attract_ui.add_child(_attract_blink)
	var hint := UI.label(tr("RC_HOW_TO"), 36, UI.WHITE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 900
	_attract_ui.add_child(hint)
	_attract_ui.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_to_table(_attract_ui)
	Dmd.show_text(tr("GAME_RACER_TITLE"), tr("RC_PRESS_START"), Dmd.YELLOW, Dmd.WHITE)


func _attract_tick() -> void:
	# Blink by alpha, not visibility: a hidden label collapses in its VBox and
	# makes the text below it jump (D-096).
	_attract_blink.modulate.a = 1.0 if fmod(_phase_t, 1.0) < 0.6 else 0.0
	var step := int(_phase_t / 3.0) % 3
	if step != int((_phase_t - get_process_delta_time()) / 3.0) % 3 or _phase_t < 0.05:
		match step:
			0: Dmd.show_text(tr("GAME_RACER_TITLE"), tr("RC_PRESS_START"), Dmd.YELLOW, Dmd.WHITE)
			1: Dmd.show_text(tr("RC_DRIFT_HINT"), tr("RC_NITRO_HINT"), Dmd.CYAN, Dmd.WHITE)
			2: Dmd.show_text(tr("ATTRACT_HIGH_SCORES"), _top_score_line(), Dmd.YELLOW, Dmd.WHITE)


func _top_score_line() -> String:
	var table: Array = HighScores.get_table("racer")
	if table.is_empty():
		return ""
	var row: Array = table[0]
	return "%s %s" % [row[0], ScoreTable.format_score(int(row[1]))]


func _begin_race() -> void:
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_phase = "race"
	_phase_t = 0.0
	_new_sim()
	_music_i += 1
	Audio.play_music(MUSIC_TRACKS[_music_i % MUSIC_TRACKS.size()])
	Audio.sfx("start")
	_hud.visible = true
	_show_mode()
	_center_message("3", 1.0)
	Audio.sfx("rc_count")
	Dmd.show_text(tr("RC_GET_READY"), "3", Dmd.YELLOW, Dmd.WHITE)
	_last_tick = -1


func _begin_finale() -> void:
	_phase = "finale"
	_finale_t = 0.0


func _finale(delta: float) -> void:
	var before := _finale_t
	_finale_t += delta
	if before < FINALE_TEXT_AT and _finale_t >= FINALE_TEXT_AT:
		_finale_ui = UI.vstack(40)
		var dim := UI.fill(Color(0, 0, 0, 0.55))
		add_to_table(dim)
		_finale_ui.add_child(UI.styled_label(tr("DMD_GAME_OVER"), TITLE_FONT, 3))
		_finale_ui.add_child(UI.spacer(30))
		_finale_ui.add_child(UI.styled_label(tr("RC_FINAL_SCORE"), TITLE_FONT, 2))
		_finale_ui.add_child(UI.styled_label(ScoreTable.format_score(sim.score), TITLE_FONT, 2))
		_finale_ui.add_child(UI.label(tr("RC_DISTANCE") % (sim.s / 1000.0), 48, UI.WHITE))
		add_to_table(_finale_ui)
		Dmd.show_text(tr("DMD_GAME_OVER"), ScoreTable.format_score(sim.score), Dmd.RED, Dmd.YELLOW)
	if _finale_t >= FINALE_END_AT:
		_finale_t = -100.0
		set_process(false)
		finished.emit([sim.score])


# --- events --------------------------------------------------------------------------
func _handle_events() -> void:
	for e in sim.events:
		match e[0]:
			"count":
				_center_message(str(e[1]), 1.0)
				Audio.sfx("rc_count")
				Dmd.show_text(tr("RC_GET_READY"), str(e[1]), Dmd.YELLOW, Dmd.WHITE)
			"go":
				_center_message(tr("RC_GO"), 1.0)
				Audio.sfx("rc_go")
				Dmd.flash(tr("RC_GO"), 1.0, Dmd.GREEN)
			"checkpoint":
				Audio.sfx("rc_checkpoint")
				_music_i += 1
				Audio.play_music(MUSIC_TRACKS[_music_i % MUSIC_TRACKS.size()])
				_center_message(tr("RC_CHECKPOINT"), 1.6)
				Dmd.flash(tr("RC_EXTENDED") % int(e[2]), 1.6, Dmd.GREEN)
			"time_up":
				Audio.sfx("rc_time_up")
				_center_message(tr("RC_TIME_UP"), 3.0)
				Dmd.flash(tr("RC_TIME_UP"), 3.0, Dmd.RED)
			"drift_start":
				pass
			"drift_end":
				if int(e[1]) > 0:
					Audio.sfx("rc_drift_bank")
					_drift_label.text = tr("RC_DRIFT_POINTS") % ScoreTable.format_score(int(e[1]))
					_drift_label.modulate.a = 1.0
			"nitro_hold":
				if e[1]:
					_hold_snd = Audio.sfx("rc_nitro_hold")
			"nitro_cancel":
				Audio.stop_sfx(_hold_snd, "rc_nitro_hold")
			"nitro":
				Audio.sfx("rc_nitro")
				_center_message(tr("RC_NITRO"), 1.0)
				Dmd.flash(tr("RC_NITRO"), 1.0, Dmd.CYAN)
				_shake = 0.4
			"nitro_empty":
				Audio.sfx("rc_nitro_empty")
				Dmd.flash(tr("RC_NO_NITRO"), 1.0, Dmd.RED)
			"nitro_gain":
				Audio.sfx("rc_nitro_gain")
				Dmd.flash(tr("RC_NITRO_PLUS"), 1.0, Dmd.CYAN)
			"near_miss":
				Audio.sfx("rc_near_miss")
				Dmd.flash(tr("RC_NEAR_MISS"), 0.8, Dmd.YELLOW)
			"pass":
				pass
			"bump":
				Audio.sfx("rc_bump")
				_shake = maxf(_shake, 0.25)
			"crash":
				Audio.sfx("rc_crash")
				_shake = 0.8
				Dmd.flash(tr("RC_CRASH"), 1.0, Dmd.RED)


# --- world ---------------------------------------------------------------------------
func _build_world() -> void:
	_root = Node3D.new()
	_root.name = "TurboRunWorld"
	add_to_table(_root)
	var env := WorldEnvironment.new()
	_env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = Color(0.3, 0.25, 0.3)
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.75, 0.65, 0.8)
	_env.ambient_light_energy = 0.7
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = SKY_HORIZON.lerp(Color(0.7, 0.6, 0.8), 0.4)
	_env.fog_depth_begin = 250.0
	_env.fog_depth_end = VIEW_AHEAD - 50.0
	_env.fog_sky_affect = 0.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_hdr_threshold = 1.0
	env.environment = _env
	_root.add_child(env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-28, 160, 0)
	_sun.light_color = Color(1.0, 0.85, 0.7)
	_sun.light_energy = 1.1
	_root.add_child(_sun)

	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = CAM_FOV
	_cam.near = 0.3
	_cam.far = 2600.0
	_root.add_child(_cam)
	_cam.current = true

	var ring := CylinderMesh.new()
	ring.top_radius = 2000.0
	ring.bottom_radius = 2000.0
	ring.height = 700.0
	ring.radial_segments = 64
	ring.cap_top = false
	ring.cap_bottom = false
	var mmat := ShaderMaterial.new()
	mmat.shader = MOUNTAIN_SHADER
	_mountains = MeshInstance3D.new()
	_mountains.mesh = ring
	_mountains.material_override = mmat
	_mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_mountains)

	_road_mat = ShaderMaterial.new()
	_road_mat.shader = ROAD_SHADER

	_build_cars()


func _car_instance(hue: float) -> Node3D:
	var scene: PackedScene = load(CAR_MODEL)
	var node: Node3D = scene.instantiate()
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if _car_tex == null:
			_car_tex = load(CAR_TEXTURE)
		if _car_mat == null:
			_car_mat = ShaderMaterial.new()
			_car_mat.shader = CAR_SHADER
			_car_mat.set_shader_parameter("tex", _car_tex)
			_car_mat.set_shader_parameter("toon", Toon.enabled)
		mi.material_override = _car_mat
		mi.set_instance_shader_parameter("hue", hue)
		if Toon.enabled:
			if _car_outline == null:
				_car_outline = Toon.outline_mesh(mi.mesh)
			var ol := MeshInstance3D.new()
			ol.mesh = _car_outline
			ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(ol)
	return node


func _build_cars() -> void:
	_car = Node3D.new()
	_root.add_child(_car)
	_car_body = _car_instance(0.0)
	_car.add_child(_car_body)
	# Rear-wheel smoke (world space so it trails behind) and nitro flames.
	for side in [-0.75, 0.75]:
		var p := CPUParticles3D.new()
		p.local_coords = false
		p.amount = 40
		p.lifetime = 0.6
		p.emitting = false
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		var sm := StandardMaterial3D.new()
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.vertex_color_use_as_albedo = true
		sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sm.albedo_texture = _puff_texture()
		q.material = sm
		p.mesh = q
		p.direction = Vector3(0, 1, 0.5)
		p.spread = 35.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 3.0
		p.gravity = Vector3(0, 0.6, 0)
		p.scale_amount_min = 0.8
		p.scale_amount_max = 1.6
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 1.7))
		p.scale_amount_curve = curve
		var grad := Gradient.new()
		grad.set_color(0, Color(0.95, 0.95, 0.95, 0.45))
		grad.set_color(1, Color(0.9, 0.9, 0.95, 0.0))
		p.color_ramp = grad
		p.position = Vector3(side, 0.3, 1.6)
		_car.add_child(p)
		_smoke.append(p)
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18
		cone.height = 1.0
		cone.radial_segments = 6
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.5, 0.8, 1.0)
		fm.emission_enabled = true
		fm.emission = Color(0.4, 0.7, 1.0)
		fm.emission_energy_multiplier = 3.0
		cone.material = fm
		flame.mesh = cone
		flame.rotation_degrees = Vector3(90, 0, 0)  # point backwards (+Z)
		flame.position = Vector3(side * 0.55, 0.42, 2.6)
		flame.visible = false
		_car.add_child(flame)
		_flames.append(flame)
	for i in TRAFFIC_POOL:
		var t := _car_instance(0.0)
		t.visible = false
		_root.add_child(t)
		_traffic_nodes.append(t)


## Round pixel puff (16 px, hard steps) for tyre smoke and dust.
func _puff_texture() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			var a := 0.0 if d > 1.0 else (1.0 if d < 0.55 else 0.55)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _update_chunks() -> void:
	var first := int(floor((sim.s - VIEW_BEHIND) / CHUNK))
	var last := int(floor((sim.s + VIEW_AHEAD) / CHUNK))
	sim.track.ensure((last + 1) * CHUNK + Track.SAMPLE)
	for k in _chunks.keys():
		if k < first or k > last:
			_chunks[k].queue_free()
			_chunks.erase(k)
	for k in range(maxi(first, 0), last + 1):
		if not _chunks.has(k):
			_chunks[k] = _build_chunk(k)


func _build_chunk(k: int) -> Node3D:
	var node := Node3D.new()
	_root.add_child(node)
	var tr_ := sim.track
	var s0 := k * CHUNK
	var n := int(CHUNK / Track.SAMPLE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := LATERAL.size()
	for i in n + 1:
		var s := s0 + i * Track.SAMPLE
		# On the inside of a curve the ground stops well short of the centre of
		# the turn, or it would fold back over the road (D-094).
		var c := tr_.curvature(s)
		var inside_max := 1e9 if absf(c) < 1e-5 else 0.75 / absf(c)
		for lx in LATERAL:
			var x: float = lx
			if signf(lx) == -signf(c):   # left turn (c > 0): inside is -x
				x = signf(lx) * minf(absf(lx), maxf(inside_max, Track.ROAD_HALF + Track.RUMBLE + 4.0))
			st.set_uv(Vector2(x, s))
			st.add_vertex(tr_.point(s, x))
	for i in n:
		for j in cols - 1:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = _road_mat
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(road)
	# Props, one MultiMesh per kind.
	var by_kind := {}
	for o in tr_.objects_between(s0, s0 + CHUNK):
		# Chevron arrows point the way the road turns: one mesh per direction.
		var key: String = o.kind if o.kind != "chevron" or o.dir < 0.0 else "chevron_l"
		if not by_kind.has(key):
			by_kind[key] = []
		by_kind[key].append(o)
	for kind in by_kind:
		var list: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Scenery.mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			var o: Dictionary = list[i]
			var f := tr_.frame(o.s, o.x)
			f.basis = Basis(Vector3.UP, tr_.heading(o.s))
			var h := fmod(absf(o.s * 7.13 + o.x * 3.1), 1.0)
			match kind:
				"palm":
					f.basis = f.basis * Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.85 + h * 0.4))
				"rock":
					f.basis = f.basis * Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.8 + h * 0.6))
				"lamp":
					# Arm over the road: turn (not mirror, which would flip the
					# outline's culling) the left-side lamps.
					if o.x < 0.0:
						f.basis = f.basis * Basis(Vector3.UP, PI)
			f.origin.y -= 0.05
			mm.set_instance_transform(i, f)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		node.add_child(mmi)
	# Start line and checkpoint gates.
	var cp := ceilf(s0 / Sim.CHECKPOINT_EVERY) * Sim.CHECKPOINT_EVERY
	if s0 <= Sim.START_LINE and s0 + CHUNK > Sim.START_LINE:
		_build_gate(node, Sim.START_LINE, tr("RC_START"))
	if cp >= Sim.CHECKPOINT_EVERY and cp < s0 + CHUNK:
		_build_gate(node, cp, tr("RC_CHECKPOINT"))
	return node


func _build_gate(parent: Node3D, s: float, text: String) -> void:
	var f := sim.track.frame(s)
	f.basis = Basis(Vector3.UP, sim.track.heading(s))
	var gate := Node3D.new()
	gate.transform = f
	parent.add_child(gate)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.2)
	var w := Track.ROAD_HALF + 2.0
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.8, 8.0, 0.8)
		b.material = mat
		post.mesh = b
		post.position = Vector3(side * w, 4.0, 0.0)
		gate.add_child(post)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(w * 2.0 + 0.8, 2.0, 0.5)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.1, 0.2)
	bm.emission_enabled = true
	bm.emission = Color(0.5, 0.05, 0.1)
	bb.material = bm
	beam.mesh = bb
	beam.position = Vector3(0, 8.0, 0)
	gate.add_child(beam)
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pinpixel.ttf")
	label.font_size = 192
	label.pixel_size = 0.009
	label.modulate = Color(1.0, 0.9, 0.3)
	label.outline_size = 24
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = Vector3(0, 8.0, 0.3)
	gate.add_child(label)


# --- per-frame visuals ----------------------------------------------------------------
## Horizontal yaw of the chase camera's view (same convention as Track: 0 = -Z).
func _camera_yaw() -> float:
	var tr_ := sim.track
	var d := tr_.point(sim.s + CAM_LOOK, _cam_x * 0.9) - tr_.point(sim.s - CAM_BACK, _cam_x * 0.85)
	return atan2(-d.x, -d.z)


## Simulated sprite car (D-092): the 3D model only ever shows one of
## SPRITE_ANGLES views relative to the camera, like a pre-rendered sprite set.
func _sprite_yaw(world_yaw: float, cam_yaw: float) -> float:
	var step := TAU / SPRITE_ANGLES
	return cam_yaw + roundf((world_yaw - cam_yaw) / step) * step


func _animate(delta: float) -> void:
	var tr_ := sim.track
	# Player car on the road frame, yawed by drift/steer, spinning on a crash.
	var f := tr_.frame(sim.s, sim.x)
	_car.transform = f
	# Steering visibly turns the nose even on straights (D-092).
	var yaw := deg_to_rad(sim.drift_angle) - sim.steer * STEER_YAW
	if sim.spin_t > 0.0:
		yaw += (1.0 - sim.spin_t / Sim.SPIN_TIME) * TAU * 1.5
	var cam_yaw := _camera_yaw()
	yaw = _sprite_yaw(tr_.heading(sim.s) + yaw, cam_yaw) - tr_.heading(sim.s)
	var bounce := 0.0
	if sim.offroad and sim.v > 5.0:
		bounce = sin(_phase_t * 40.0) * 0.05
	# No roll: a sprite can't lean.
	_car_body.transform = Transform3D(Basis(Vector3.UP, yaw) * MODEL_TURN, Vector3(0, bounce, 0))
	var smoking := sim.drifting or sim.spin_t > 0.0 or (sim.offroad and sim.v > 12.0)
	for p in _smoke:
		var cp := p as CPUParticles3D
		cp.emitting = smoking
		var col := Color(0.75, 0.6, 0.4, 0.5) if sim.offroad else Color(0.95, 0.95, 0.95, 0.45)
		cp.color_ramp.set_color(0, col)
	var burning := sim.nitro_t > 0.0
	for fl in _flames:
		fl.visible = burning
		if burning:
			fl.scale = Vector3(1.0, 0.8 + randf() * 0.7, 1.0)
	# Traffic
	for i in _traffic_nodes.size():
		var node: Node3D = _traffic_nodes[i]
		if i < sim.traffic.size():
			var t: Dictionary = sim.traffic[i]
			node.visible = true
			node.transform = tr_.frame(t.s, t.x)
			var h := tr_.heading(t.s)
			node.basis = node.basis * Basis(Vector3.UP, _sprite_yaw(h, cam_yaw) - h) * MODEL_TURN
			for m in node.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).set_instance_shader_parameter("hue", t.hue)
		else:
			node.visible = false
	# Chase camera: behind and above, looking down the road; FOV opens with speed.
	# Camera follows the road exactly along s; only its sideways offset lags.
	if not _cam_ready:
		_cam_x = sim.x
		_cam_ready = true
	_cam_x = lerpf(_cam_x, sim.x, 1.0 - exp(-delta * 6.0))
	var target := tr_.point(sim.s - CAM_BACK, _cam_x * 0.85, CAM_HEIGHT)
	var look := tr_.point(sim.s + CAM_LOOK, _cam_x * 0.9, 0.5)
	_cam_pos = target
	_shake = maxf(0.0, _shake - delta)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
	_cam.position = _cam_pos + shake
	_cam.look_at(look, Vector3.UP)
	_cam.rotate_object_local(Vector3.BACK, deg_to_rad(-sim.drift_angle * 0.12))
	var fov := CAM_FOV + sim.v / Sim.MAX_SPEED * 6.0 + (8.0 if sim.nitro_t > 0.0 else 0.0)
	_cam.fov = lerpf(_cam.fov, fov, 1.0 - exp(-delta * 4.0))
	_mountains.position = Vector3(_cam.position.x, _cam.position.y + 120.0, _cam.position.z)
	_sun.rotation = Vector3(deg_to_rad(-25), tr_.heading(sim.s) + PI * 0.92, 0)


# --- HUD -----------------------------------------------------------------------------
func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_table(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 40
	top.offset_left = 40
	top.offset_right = -40
	_hud.add_child(top)
	var left := UI.vstack(4)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(UI.label(tr("RC_SCORE"), 36, UI.CYAN))
	_score_label = UI.label("0", 48)
	left.add_child(_score_label)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	var mid := UI.vstack(0)
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	mid.add_child(UI.label(tr("RC_TIME"), 36, UI.YELLOW))
	_time_label = UI.label("45", 144, UI.YELLOW)
	mid.add_child(_time_label)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	var right := UI.vstack(4)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stage_label = UI.label("", 36, UI.CYAN)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_stage_label)
	_mode_label = UI.label("", 36, UI.GREY)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_mode_label)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)

	# Bottom: speed + nitro.
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -200
	bottom.offset_bottom = -40
	bottom.offset_left = 50
	bottom.offset_right = -50
	_hud.add_child(bottom)
	var nbox := UI.vstack(10)
	nbox.alignment = BoxContainer.ALIGNMENT_END
	nbox.add_child(UI.label(tr("RC_NITRO"), 36, UI.CYAN))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 12)
	for i in Sim.NITRO_MAX:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(60, 36)
		pips.add_child(pip)
		_nitro_pips.append(pip)
	nbox.add_child(pips)
	_nitro_bar_bg = ColorRect.new()
	_nitro_bar_bg.color = Color(0, 0, 0, 0.5)
	_nitro_bar_bg.custom_minimum_size = Vector2(204, 14)
	_nitro_bar = ColorRect.new()
	_nitro_bar.color = UI.CYAN
	_nitro_bar.size = Vector2(0, 14)
	_nitro_bar_bg.add_child(_nitro_bar)
	nbox.add_child(_nitro_bar_bg)
	nbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(nbox)
	var sbox := UI.vstack(0)
	sbox.alignment = BoxContainer.ALIGNMENT_END
	_speed_label = UI.label("0", 120, UI.WHITE)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sbox.add_child(_speed_label)
	var kmh := UI.label(tr("RC_KMH"), 36, UI.GREY)
	kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sbox.add_child(kmh)
	sbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sbox)

	_drift_label = UI.label("", 60, UI.YELLOW)
	_drift_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drift_label.offset_top = 300
	_drift_label.offset_left = -500
	_drift_label.offset_right = 500
	_hud.add_child(_drift_label)


func _show_mode() -> void:
	_mode_label.text = tr("RC_MODE_MANUAL") if sim.manual else tr("RC_MODE_AUTO")


func _center_message(text: String, seconds: float) -> void:
	if is_instance_valid(_center):
		_center.queue_free()
	var l := UI.styled_label(text, TITLE_FONT, 4)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_bottom = -300
	add_to_table(l)
	_center = l
	_center_t = seconds


func _update_hud(delta: float) -> void:
	_time_label.text = str(ceili(sim.time_left))
	var low := sim.time_left < 10.0
	UI.set_color(_time_label, UI.RED if low and fmod(sim.time_left, 0.5) < 0.25 else UI.YELLOW)
	if low and sim.state == Sim.State.RACE and ceili(sim.time_left) != _last_tick:
		_last_tick = ceili(sim.time_left)
		Audio.sfx("rc_tick")
	_score_label.text = ScoreTable.format_score(sim.score)
	_stage_label.text = tr("RC_STAGE") % (sim.checkpoints + 1)
	_speed_label.text = str(sim.speed_kmh())
	UI.set_color(_speed_label, UI.CYAN if sim.nitro_t > 0.0 else UI.WHITE)
	for i in _nitro_pips.size():
		(_nitro_pips[i] as ColorRect).color = UI.CYAN if i < sim.nitro else Color(0.1, 0.15, 0.2, 0.7)
	_nitro_bar.size.x = 204.0 * clampf(sim.nitro_hold / Sim.NITRO_HOLD, 0.0, 1.0)
	if sim.drifting:
		_drift_label.text = tr("RC_DRIFT_POINTS") % ScoreTable.format_score(int(sim.drift_points / 10.0) * 10)
		_drift_label.modulate.a = 1.0
	else:
		_drift_label.modulate.a = maxf(0.0, _drift_label.modulate.a - delta * 0.8)
	if _center_t > 0.0:
		_center_t -= delta
		if _center_t <= 0.0 and is_instance_valid(_center):
			_center.queue_free()
	_dmd_t -= delta
	if _dmd_t <= 0.0 and sim.state != Sim.State.COUNTDOWN:
		_dmd_t = 0.12
		Dmd.show_score(sim.score, tr("RC_DMD_TIME") % ceili(sim.time_left), tr("RC_DMD_SPEED") % sim.speed_kmh(),
			Dmd.RED if low else Dmd.YELLOW)
	score_changed.emit(0, sim.score)


func _build_backglass() -> void:
	add_to_backglass(UI.fill(Color(0.1, 0.06, 0.22)))
	var sun := ColorRect.new()
	sun.color = SKY_HORIZON
	sun.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sun.offset_top = -380
	add_to_backglass(sun)
	var box := UI.vstack(40)
	box.add_child(UI.styled_label(tr("GAME_RACER_TITLE"), TITLE_FONT, 6))
	box.add_child(UI.label(tr("RC_PROTOTYPE"), 48, UI.WHITE))
	add_to_backglass(box)


# --- audio ---------------------------------------------------------------------------
## Looping engine and tyre-squeal streams, generated here (Synth makes one-shots).
func _build_audio_loops() -> void:
	_engine = AudioStreamPlayer.new()
	_engine.bus = "SFX"
	_engine.stream = _loop_wav(func(t: float) -> float:
		var f := 55.0
		var saw := fmod(t * f, 1.0) * 2.0 - 1.0
		var pulse := 1.0 if fmod(t * f * 2.0, 1.0) < 0.3 else -1.0
		return saw * 0.35 + pulse * 0.12 + sin(TAU * f * 0.5 * t) * 0.3, 0.4, 0.0)
	_engine.volume_db = -8.0
	add_child(_engine)
	_skid = AudioStreamPlayer.new()
	_skid.bus = "SFX"
	_skid.stream = _loop_wav(func(t: float) -> float:
		return sin(TAU * 950.0 * t + sin(TAU * 25.0 * t) * 2.0) * 0.25, 0.4, 0.5)
	_skid.volume_db = -80.0
	add_child(_skid)
	_engine.play()
	_skid.play()


func _loop_wav(gen: Callable, seconds: float, noise: float) -> AudioStreamWAV:
	var rate := 32000
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.25)
		var smp := clampf(float(gen.call(t)) + lp * noise, -1.0, 1.0)
		data.encode_s16(i * 2, int(smp * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


func _update_audio() -> void:
	if _engine == null:
		return
	var rpm := clampf(sim.v / Sim.MAX_SPEED, 0.0, 1.3)
	_engine.pitch_scale = 0.6 + rpm * 1.9 + (0.25 if sim.nitro_t > 0.0 else 0.0)
	_engine.volume_db = -14.0 + sim.throttle * 4.0 + rpm * 2.0
	var squeal := sim.drifting or sim.spin_t > 0.0 or sim.auto_braking
	_skid.volume_db = lerpf(_skid.volume_db, -10.0 if squeal else -60.0, 0.2)
