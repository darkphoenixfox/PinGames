## TURBO RUN (D-089): arcade road racer prototype. Race the clock through
## checkpoints on an endless seeded road with curves and hills, traffic and
## roadside obstacles. Emphasis on drifting through corners.
## The pure race logic is in sim.gd / track.gd; this module draws it in 3D on
## the TABLE (low-poly "PS2" props, 16-bit textures), with DMD + BACKGLASS.
## Controls (D-007, D-089):
##   flippers = steer; throttle/brake automatic (2+1 buttons)
##   magna_r = accelerate, magna_l = brake (4+1: switches on at the first press
##   when operator.cabinet_buttons = auto, always on when = 4)
##   hold both flippers 0.5 s = shift gear L <-> H (D-103)
##   NITRO = drive through a canister on the road (5 s boost, D-103)
extends "res://core/game_module.gd"

const Sim = preload("res://games/racer/sim.gd")
const Track = preload("res://games/racer/track.gd")
const Scenery = preload("res://games/racer/scenery.gd")
const Toon = preload("res://games/racer/toon.gd")
const Sprites = preload("res://games/racer/sprites.gd")
const Dial = preload("res://games/racer/dial.gd")
const UI = preload("res://core/ui/ui.gd")
const Synth = preload("res://core/util/synth.gd")
const ScoreTable = preload("res://core/util/score_table.gd")
const ROAD_SHADER = preload("res://games/racer/shaders/road.gdshader")
const CAR_SHADER = preload("res://games/racer/shaders/car.gdshader")
const PIXEL_POST = preload("res://games/racer/shaders/pixel_post.gdshader")
const SKY_SHADER = preload("res://games/racer/shaders/sky_panorama.gdshader")
const LOGO := "res://assets/textures/racer/logo.png"
const BG_DIR := "res://assets/textures/racer/"
## Shared lit-backglass shader (D-058; generic: off art + on art + group masks).
const BACKGLASS_SHADER = preload("res://games/breakout/shaders/backglass_lights.gdshader")
const DMD_LOGO := "res://assets/textures/racer/dmd_logo.png"
const SKY_TEXTURE := "res://assets/sprites/racer/sky.png"
const SKY_RADIUS := 2000.0
const SKY_BELOW := 70.0     # ring bottom below the camera: mountains sit on the horizon
const CAR_MODEL := "res://assets/models/racer/red_car.glb"
## The model's nose points +Z; turn it to face down the road (-Z).
const MODEL_TURN := Basis(Vector3.UP, PI)
## Cars snap to 32 views around the camera, like a sprite set (D-092).
const SPRITE_ANGLES := 32
## Nose turn at full steer (rad): ~1.5 sprite steps, visible on straights.
const STEER_YAW := 0.3
## Crash animations (D-098): stepped at ANIM_FPS; a roll-over shows FLIP_FRAMES
## poses per full turn and hops FLIP_HOP metres.
const ANIM_FPS := 10.0
## Pixel renderer resolution (D-107): 1/3 of the 1080x1920 TABLE.
const PIXEL_RES := Vector2i(360, 640)
const FLIP_FRAMES := 8.0
const FLIP_HOP := 1.6
## TIME UP slide (D-105): 90 degrees in OVER_TURN_TIME s, OVER_TURN_FRAMES steps.
const OVER_TURN_TIME := 0.6
const OVER_TURN_FRAMES := 6.0
const PICKUP_SCALE := 1.8           # nitro canisters read from far away (D-103)
## Roll-over phases (fractions of the animation, D-101): slew 90 degrees by
## FLIP_TURN_END, roll over until FLIP_ROLL_END, then lie still; in the last
## FLIP_UNTURN s of the stop the car turns back to face the road.
const FLIP_TURN_END := 0.25
const FLIP_ROLL_END := 0.8
const FLIP_UNTURN := 0.4
const CAR_TEXTURE := "res://assets/models/racer/red_car_albedo.png"
## Director's truck (D-099): 10 m, same orientation as the car.
const TRUCK_MODEL := "res://assets/models/racer/truck.glb"
const TRUCK_TEXTURE := "res://assets/models/racer/truck_albedo.png"

const ACCENT := Color("ffd23e")
const TITLE_FONT := "sunset"
## Director's pick: "8-bit Music Pack (Loopable)" by CodeManu, CC BY 3.0 (D-033).
## Director's pick (D-093): the five "action" loops for attract and race. Each
## race starts on the next one, and every checkpoint (new stage) moves on again.
## The first race plays action_3 (director's pick).
## Attract mode: "Maximum Overdrive" by Bogart VGM, CC BY 3.0 (D-104).
const MUSIC_STAGES := 4
const MUSIC_ATTRACT := "res://assets/audio/music/racer/bogart_maximum_overdrive.ogg"
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
const TRAFFIC_POOL := 16
const CAM_BACK := 8.0
const CAM_HEIGHT := 2.3            # low, close to the road (D-098; was 3.6)
## The car sits this far below the screen centre (degrees), whatever the
## camera height: the old 3.6 m camera's framing (D-098).
const CAM_CAR_DEG := 15.9
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
	"rc_horn": {"voices": [[{"f": [392.0, 392.0], "t": 0.18, "w": "square", "v": 0.14, "env": "hold", "lp": 0.5}],
		[{"f": [494.0, 494.0], "t": 0.18, "w": "square", "v": 0.14, "env": "hold", "lp": 0.5}]], "echo": [0.26, 0.5, 1.5]},
	"rc_shift": {"voices": [[{"f": [180.0, 90.0], "t": 0.12, "w": "square", "v": 0.25},
		{"f": [900.0, 900.0], "t": 0.04, "w": "noise", "v": 0.2}]]},
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
var _car_mats := {}         # model path -> ShaderMaterial
var _car_outlines := {}     # model path -> outline ArrayMesh
var _beam_mat: StandardMaterial3D
var _pix_vp: SubViewport
var _bg_mat: ShaderMaterial
var _bg_flash := 0.0    # s of backglass light flashing left (D-109)
var _bg_dark := 0.0     # s of crash flicker left
var _sky_h := 0.0
var _over_turn := 0.0   # 0..1 TIME UP sideways slide (D-105)
var _over_dir := 0.0
var _music_i := FIRST_TRACK    # current race song index
var _traffic_pool := {"car": [], "truck": []}   # pools of Node3D per kind
## Tyre smoke / dust (D-100): our own pooled billboard puffs in one MultiMesh.
## CPUParticles3D drew a stray pure-black puff at the emitter when toggled.
const PUFF_MAX := 192
const PUFF_EVERY := 0.016        # s between puffs per wheel
const PUFF_LIFE := 0.6
var _puffs: MultiMesh
var _puff_list: Array = []       # {pos, vel, age, size, col}
var _puff_t := 0.0
var _flames: Array = []          # nitro flame meshes
var _cam_pos := Vector3.ZERO
var _cam_ready := false
var _cam_x := 0.0
var _engine: AudioStreamPlayer
var _skid: AudioStreamPlayer
var _hud: Control
var _time_label: Label
var _score_label: Label
var _stage_label: Label
var _speed_label: Label
var _speedo: Control
var _tacho: Control
var _gear_label: Label
var _shift_label: Label
var _nitro_label: Label
var _nitro_strip: ColorRect
var _pickup_nodes: Array = []   # pooled nitro canisters
var _mode_label: Label
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
	return {"id": "racer", "title_key": "GAME_RACER_TITLE", "color": ACCENT, "font": TITLE_FONT, "buttons_min": 3,
		"logo": LOGO, "dmd_logo": DMD_LOGO,   # director's logo (D-108)
		"backglass": BG_DIR + "backglass_on.png"}   # shell screens (D-088, D-109)


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
	_update_backglass(delta)
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
	_over_turn = 0.0
	_over_dir = 0.0
	_puff_list.clear()
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
	Audio.play_music(MUSIC_ATTRACT)
	_hud.visible = false
	_attract_ui = UI.vstack(60)
	_attract_ui.add_child(UI.spacer(200))
	_attract_ui.add_child(_logo_rect(900))
	_attract_blink = UI.styled_label(tr("RC_PRESS_START"), TITLE_FONT, 2)
	_attract_ui.add_child(_attract_blink)
	var hint := UI.label(tr("RC_HOW_TO"), 36, UI.WHITE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 900
	_attract_ui.add_child(hint)
	_attract_ui.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_to_table(_attract_ui)
	Dmd.show_image(load(DMD_LOGO))


func _attract_tick() -> void:
	# Blink by alpha, not visibility: a hidden label collapses in its VBox and
	# makes the text below it jump (D-096).
	_attract_blink.modulate.a = 1.0 if fmod(_phase_t, 1.0) < 0.6 else 0.0
	var step := int(_phase_t / 3.0) % 3
	if step != int((_phase_t - get_process_delta_time()) / 3.0) % 3 or _phase_t < 0.05:
		match step:
			0: Dmd.show_image(load(DMD_LOGO))
			1: Dmd.show_text(tr("RC_SHIFT_HINT"), tr("RC_NITRO_HINT"), Dmd.CYAN, Dmd.WHITE)
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
	# Stage 1 is always action_3 (D-106; was: each race moved on a song).
	_music_i = FIRST_TRACK
	Audio.play_music(MUSIC_TRACKS[_music_i])
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
				_bg_flash = 1.2
				Audio.sfx("rc_checkpoint")
				# The song changes at stage 5, then every MUSIC_STAGES stages (D-105).
				if int(e[1]) % MUSIC_STAGES == 0:
					_music_i += 1
					Audio.play_music(MUSIC_TRACKS[_music_i % MUSIC_TRACKS.size()])
				# Reached on momentum after TIME UP: the race goes on (D-103).
				var saved: bool = e.size() > 3 and e[3]
				_center_message(tr("RC_JUST_MADE_IT") if saved else tr("RC_CHECKPOINT"), 1.6)
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
			"nitro", "nitro_refill":
				_bg_flash = 0.6
				Audio.sfx("rc_nitro")
				_center_message(tr("RC_NITRO"), 0.8)
				Dmd.flash(tr("RC_NITRO"), 0.6, Dmd.CYAN)
				_shake = 0.3
			"high_beams":
				Audio.sfx("rc_horn")
			"shift":
				Audio.sfx("rc_shift")
				Dmd.flash(tr("RC_GEAR_FLASH") % _gear_text(int(e[1])), 0.5, Dmd.YELLOW)
			"near_miss":
				_bg_flash = 0.4
				Audio.sfx("rc_near_miss")
				Dmd.flash(tr("RC_NEAR_MISS"), 0.8, Dmd.YELLOW)
			"pass":
				pass
			"bump":
				Audio.sfx("rc_bump")
				_shake = maxf(_shake, 0.25)
			"crash":
				_bg_dark = 0.8
				Audio.sfx("rc_crash")
				_shake = 0.8
				Dmd.flash(tr("RC_CRASH"), 1.0, Dmd.RED)


# --- world ---------------------------------------------------------------------------
## Average colour of one row of an image (sky backdrop edges, D-107).
func _row_colour(im: Image, y: int) -> Color:
	var c := Color(0, 0, 0)
	for x in range(0, im.get_width(), 8):
		c += im.get_pixel(x, y)
	return c / ceilf(im.get_width() / 8.0)


func _build_world() -> void:
	_root = Node3D.new()
	_root.name = "TurboRunWorld"
	# Pixel renderer (D-107): the world renders at PIXEL_RES in its own
	# viewport, shown full-screen with nearest upscaling + a palette/dither
	# pass; the HUD on top stays at full resolution.
	_pix_vp = SubViewport.new()
	_pix_vp.size = PIXEL_RES
	_pix_vp.own_world_3d = true
	_pix_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pix_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_to_table(_pix_vp)
	_pix_vp.add_child(_root)
	var view := TextureRect.new()
	view.texture = _pix_vp.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var post := ShaderMaterial.new()
	post.shader = PIXEL_POST
	post.set_shader_parameter("low_res", Vector2(PIXEL_RES))
	view.material = post
	add_to_table(view)
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
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # the painted sun is in the backdrop
	_root.add_child(_sun)

	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = CAM_FOV
	_cam.near = 0.3
	_cam.far = 2600.0
	_root.add_child(_cam)
	_cam.current = true

	# Sky backdrop (D-107): the pixel-art sunset panorama on a tall ring. Above
	# it the sky is the image's top colour; distant ground fogs into the
	# mountains' colour.
	var sky_img: Texture2D = load(SKY_TEXTURE)
	var sky_h := PI * SKY_RADIUS * sky_img.get_height() / float(sky_img.get_width())
	var ring := CylinderMesh.new()
	ring.top_radius = SKY_RADIUS
	ring.bottom_radius = SKY_RADIUS
	ring.height = sky_h
	ring.radial_segments = 96
	ring.cap_top = false
	ring.cap_bottom = false
	var mmat := ShaderMaterial.new()
	mmat.shader = SKY_SHADER
	mmat.set_shader_parameter("sky", sky_img)
	mmat.set_shader_parameter("height", sky_h)
	_sky_h = sky_h
	var im := sky_img.get_image()
	var top := _row_colour(im, 0)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = top
	sky_mat.sky_curve = 1.0
	_env.fog_light_color = _row_colour(im, im.get_height() - 4)
	_env.ambient_light_color = Color(0.85, 0.65, 0.8)
	_mountains = MeshInstance3D.new()
	_mountains.mesh = ring
	_mountains.material_override = mmat
	_mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_mountains)

	_road_mat = ShaderMaterial.new()
	_road_mat.shader = ROAD_SHADER

	_build_cars()


## A car or truck model with the cel car material (+ outline). Materials and
## outline meshes are shared per model.
func _car_instance(hue: float, model: String = CAR_MODEL, texture: String = CAR_TEXTURE) -> Node3D:
	var scene: PackedScene = load(model)
	var node: Node3D = scene.instantiate()
	if not _car_mats.has(model):
		var mat := ShaderMaterial.new()
		mat.shader = CAR_SHADER
		mat.set_shader_parameter("tex", load(texture))
		mat.set_shader_parameter("toon", Toon.enabled)
		_car_mats[model] = mat
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.material_override = _car_mats[model]
		mi.set_instance_shader_parameter("hue", hue)
		if Toon.enabled:
			if not _car_outlines.has(model):
				_car_outlines[model] = Toon.outline_mesh(mi.mesh)
			var ol := MeshInstance3D.new()
			ol.mesh = _car_outlines[model]
			ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(ol)
	return node


func _build_cars() -> void:
	_car = Node3D.new()
	_root.add_child(_car)
	_car_body = _car_instance(0.0)
	_car.add_child(_car_body)
	_build_puffs()
	# Nitro flames.
	for side in [-0.75, 0.75]:
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.1
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
		# On the model's exhaust pipes (model space: rear is -Z, pipes at
		# x +-0.57, 0.28 m up), so they follow the body's yaw (D-097).
		flame.rotation_degrees = Vector3(-90, 0, 0)  # tip points out the back
		flame.position = Vector3(signf(side) * 0.57, 0.28, -2.2 - 0.5)
		flame.visible = false
		_car_body.add_child(flame)
		_flames.append(flame)
	for kind in _traffic_pool:
		for i in (TRAFFIC_POOL if kind == "car" else Sim.MAX_TRUCKS):
			var t := _car_instance(0.0) if kind == "car" else _car_instance(0.0, TRUCK_MODEL, TRUCK_TEXTURE)
			_add_headlights(t, kind)
			t.visible = false
			_root.add_child(t)
			_traffic_pool[kind].append(t)
	for i in 4:
		var pk := _build_pickup()
		pk.visible = false
		_root.add_child(pk)
		_pickup_nodes.append(pk)


func _build_puffs() -> void:
	_puffs = MultiMesh.new()
	_puffs.transform_format = MultiMesh.TRANSFORM_3D
	_puffs.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sm.albedo_texture = _puff_texture()
	q.material = sm
	_puffs.mesh = q
	_puffs.instance_count = PUFF_MAX
	_puffs.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _puffs
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	_root.add_child(mmi)


## Rear-wheel puffs in world space: rise, grow and fade (D-100).
func _update_puffs(delta: float, smoking: bool) -> void:
	if smoking:
		_puff_t += delta
		var col := Color(0.75, 0.6, 0.4, 0.5) if sim.offroad else Color(0.95, 0.95, 0.95, 0.45)
		# Fewer puffs when slow, or they pile up into one opaque cloud.
		var every := PUFF_EVERY * clampf(40.0 / maxf(sim.v, 1.0), 1.0, 4.0)
		while _puff_t >= every:
			_puff_t -= every
			for side in [-0.75, 0.75]:
				if _puff_list.size() >= PUFF_MAX:
					_puff_list.pop_front()
				var pos := _car.global_transform * Vector3(side, 0.3, 1.6)
				var vel := Vector3(randf_range(-1, 1), randf_range(1.0, 2.5), randf_range(-1, 1))
				_puff_list.append({"pos": pos, "vel": vel, "age": 0.0, "size": randf_range(0.8, 1.6), "col": col})
	else:
		_puff_t = 0.0
	for i in range(_puff_list.size() - 1, -1, -1):
		var p: Dictionary = _puff_list[i]
		p.age += delta
		if p.age >= PUFF_LIFE:
			_puff_list.remove_at(i)
			continue
		p.vel.y += 0.6 * delta
		p.pos += p.vel * delta
	_puffs.visible_instance_count = _puff_list.size()
	for i in _puff_list.size():
		var p: Dictionary = _puff_list[i]
		var k: float = p.age / PUFF_LIFE
		var sc: float = p.size * lerpf(0.5, 1.7, k)
		_puffs.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), p.pos))
		var c: Color = p.col
		_puffs.set_instance_color(i, Color(c.r, c.g, c.b, c.a * (1.0 - k)))


## Headlight flares at the model's nose (model space: front is +Z), hidden
## until an oncoming driver flashes the high beams (D-105).
func _add_headlights(node: Node3D, kind: String) -> void:
	if _beam_mat == null:
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_beam_mat.billboard_keep_scale = true
		_beam_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_beam_mat.albedo_texture = _puff_texture()
		_beam_mat.albedo_color = Color(1.0, 0.95, 0.7)
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.95) if kind == "car" else Vector2(1.3, 1.3)
	var front := 2.25 if kind == "car" else 5.05
	var side := 0.62 if kind == "car" else 0.95
	var up := 0.62 if kind == "car" else 0.95
	var beams := []
	for sx in [-side, side]:
		var b := MeshInstance3D.new()
		b.mesh = q
		b.material_override = _beam_mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = Vector3(sx, up, front)
		b.visible = false
		node.add_child(b)
		beams.append(b)
	node.set_meta("beams", beams)


## Nitro canister (D-103): a glowing cyan bottle with white bands, cel
## outlined; it spins and bobs in stepped sprite-like frames.
## Which mesh draws a track object (D-107): palms, bushes and signs are pixel
## sprites (variants picked from the position, so they're stable); rocks and
## lamps stay low-poly 3D.
func _prop_kind(o: Dictionary) -> String:
	var h := int(absf(o.s * 7.13 + o.x * 3.1) * 10.0)
	match o.kind:
		"palm":
			return "palm_1" if h % 3 != 0 else "palm_2"
		"bush":
			return "bush_1" if h % 2 == 0 else "bush_2"
		"chevron":   # curve warning: the arrow turns the way the road does.
			# Track: dir = -1 on a left turn (curvature > 0); the sprite's arrow
			# turns right as drawn.
			return "sign_curve_l" if o.dir < 0.0 else "sign_curve"
		"sign":
			return "sign_green"
	return o.kind


func _build_pickup() -> Node3D:
	var n := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.42
	body.bottom_radius = 0.42
	body.height = 1.3
	body.radial_segments = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = UI.CYAN
	m.emission_enabled = true
	m.emission = UI.CYAN
	m.emission_energy_multiplier = 1.2
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	body.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = body
	n.add_child(mi)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.18
	cap.bottom_radius = 0.3
	cap.height = 0.35
	cap.radial_segments = 8
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color.WHITE
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap.material = wm
	var ci := MeshInstance3D.new()
	ci.mesh = cap
	ci.position.y = 0.82
	n.add_child(ci)
	for y in [-0.3, 0.3]:
		var band := CylinderMesh.new()
		band.top_radius = 0.44
		band.bottom_radius = 0.44
		band.height = 0.12
		band.radial_segments = 8
		band.material = wm
		var bi := MeshInstance3D.new()
		bi.mesh = band
		bi.position.y = y
		n.add_child(bi)
	if Toon.enabled:
		for c in n.get_children():
			var o := MeshInstance3D.new()
			o.mesh = Toon.outline_mesh((c as MeshInstance3D).mesh)
			c.add_child(o)
	return n


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
		var key := _prop_kind(o)
		if not by_kind.has(key):
			by_kind[key] = []
		by_kind[key].append(o)
	for kind in by_kind:
		var list: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Sprites.mesh(kind) if Sprites.has(kind) else Scenery.mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			var o: Dictionary = list[i]
			var f := tr_.frame(o.s, o.x)
			f.basis = Basis(Vector3.UP, tr_.heading(o.s))
			var h := fmod(absf(o.s * 7.13 + o.x * 3.1), 1.0)
			match kind:
				"palm_1", "palm_2":
					f.basis = Basis.from_scale(Vector3.ONE * (0.85 + h * 0.35))
				"bush_1", "bush_2":
					f.basis = Basis.from_scale(Vector3.ONE * (0.8 + h * 0.5))
				"sign_curve", "sign_curve_l", "sign_green":
					f.basis = Basis.IDENTITY
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
## Animation progress t (0..1 over `seconds`) held on ANIM_FPS steps, so crash
## animations play like a few sprite frames instead of smooth motion (D-098).
func _anim_steps(t: float, seconds: float) -> float:
	var n := maxf(1.0, seconds * ANIM_FPS)
	return floorf(clampf(t, 0.0, 1.0) * n) / n


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
	var crash_p := _anim_steps(sim.crash_progress(), sim.crash_anim)
	if sim.spin_t > 0.0 and not sim.flipping:
		# Spin-out: two full turns stepped like sprite frames, ending nose
		# forward, then stopped (D-098, D-101).
		yaw += crash_p * TAU * 2.0
	elif sim.spin_t > 0.0 and sim.flipping:
		# Roll-over, part 1: slew 90 degrees across the road (D-101) ...
		var turn := clampf(crash_p / FLIP_TURN_END, 0.0, 1.0)
		# ... and while stopped at the end, turn back to face the road.
		if sim.spin_t < FLIP_UNTURN:
			turn = _anim_steps(sim.spin_t / FLIP_UNTURN, FLIP_UNTURN)
		yaw += turn * PI * 0.5 * sim.flip_dir
	# TIME UP (D-105): the car swings 90 degrees and slides to a stop sideways,
	# nose towards the inside of the bend. Turns back if a checkpoint saves it.
	if sim.state == Sim.State.OVER:
		if _over_dir == 0.0:
			var c := sim.track.curvature(sim.s)
			_over_dir = signf(c) if absf(c) > 1e-4 else (-1.0 if sim.x > 0.0 else 1.0)
		_over_turn = move_toward(_over_turn, 1.0, delta / OVER_TURN_TIME)
	else:
		_over_turn = move_toward(_over_turn, 0.0, delta / OVER_TURN_TIME)
		if _over_turn == 0.0:
			_over_dir = 0.0
	yaw += roundf(_over_turn * OVER_TURN_FRAMES) / OVER_TURN_FRAMES * PI * 0.5 * _over_dir
	var cam_yaw := _camera_yaw()
	yaw = _sprite_yaw(tr_.heading(sim.s) + yaw, cam_yaw) - tr_.heading(sim.s)
	var bounce := 0.0
	if sim.offroad and sim.v > 5.0:
		bounce = sin(_phase_t * 40.0) * 0.05
	# No lean while driving (a sprite can't lean). A roll-over is the exception:
	# part 2, once sideways, a hop with one full roll about the car's length,
	# so it tumbles towards the front of the road, in FLIP_FRAMES stepped poses
	# (D-098, D-101). Turned +90 (nose left) the right side faces forward, and a
	# positive roll drops the right side: the roll sign follows the turn.
	var roll := 0.0
	var lift := bounce
	if sim.spin_t > 0.0 and sim.flipping:
		var q := clampf((crash_p - FLIP_TURN_END) / (FLIP_ROLL_END - FLIP_TURN_END), 0.0, 1.0)
		roll = roundf(q * FLIP_FRAMES) / FLIP_FRAMES * TAU * sim.flip_dir
		lift += 4.0 * FLIP_HOP * q * (1.0 - q)
	var pivot := Vector3(0, 0.65, 0)             # roll around the body's middle
	var rb := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll)
	_car_body.transform = Transform3D(rb * MODEL_TURN, Vector3(0, lift, 0) + pivot - rb * pivot)
	var sliding_out := sim.state == Sim.State.OVER and sim.v > 3.0
	var smoking := sim.drifting or sliding_out or (sim.spin_t > 0.0 and not sim.stalled()) or (sim.offroad and sim.v > 12.0)
	_update_puffs(delta, smoking)
	var burning := sim.boosting
	for fl in _flames:
		fl.visible = burning
		if burning:
			fl.scale = Vector3(1.0, 0.8 + randf() * 0.7, 1.0)
	# Traffic
	var used := {"car": 0, "truck": 0}
	for t in sim.traffic:
		var kind: String = t.get("kind", "car")
		var pool: Array = _traffic_pool[kind]
		if used[kind] >= pool.size():
			continue
		var node: Node3D = pool[used[kind]]
		used[kind] += 1
		node.visible = true
		node.transform = tr_.frame(t.s, t.x)
		var h := tr_.heading(t.s)
		var wy := h + (PI if t.v < 0.0 else 0.0)     # oncoming faces us (D-099)
		node.basis = node.basis * Basis(Vector3.UP, _sprite_yaw(wy, cam_yaw) - h) * MODEL_TURN
		if kind == "car":
			for m in node.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).set_instance_shader_parameter("hue", t.hue)
		# High beams: flash-flash ... pause (D-105).
		var ph := fmod(_phase_t + t.id * 0.13, 0.7)
		var beam_on: bool = t.get("flash", false) and (ph < 0.1 or (ph > 0.2 and ph < 0.3))
		for b in node.get_meta("beams", []):
			(b as Node3D).visible = beam_on
	for kind in _traffic_pool:
		for i in range(used[kind], _traffic_pool[kind].size()):
			(_traffic_pool[kind][i] as Node3D).visible = false
	# Nitro canisters: spin + bob on stepped frames (D-103).
	for i in _pickup_nodes.size():
		var pk: Node3D = _pickup_nodes[i]
		if i < sim.pickups.size():
			var pd: Dictionary = sim.pickups[i]
			pk.visible = true
			var st := floorf(_phase_t * ANIM_FPS) / ANIM_FPS
			pk.transform = Transform3D(Basis(Vector3.UP, st * 3.0).scaled(Vector3.ONE * PICKUP_SCALE),
				tr_.point(pd.s, pd.x, 1.7 + 0.3 * sin(st * 4.0)))
		else:
			pk.visible = false
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
	# Pitch so the car stays at the same height on screen as before (D-098).
	var to_car := _cam.global_basis.inverse() * (tr_.point(sim.s, sim.x, 0.6) - _cam.position)
	var below := atan2(-to_car.y, -to_car.z)
	_cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(CAM_CAR_DEG) - below)
	_cam.rotate_object_local(Vector3.BACK, deg_to_rad(-sim.drift_angle * 0.12))
	var fov := CAM_FOV + sim.v / Sim.MAX_SPEED * 6.0 + (8.0 if sim.boosting else 0.0)
	_cam.fov = lerpf(_cam.fov, fov, 1.0 - exp(-delta * 4.0))
	_mountains.position = Vector3(_cam.position.x, _cam.position.y - SKY_BELOW + _sky_h * 0.5, _cam.position.z)
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

	# Bottom dashboard (D-103): tachometer | gear + nitro | speedometer, drawn
	# in the director's segmented-dial style. Fixed-size slots: changing values
	# never move anything (D-096).
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -330
	bottom.offset_bottom = -24
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 0)
	_hud.add_child(bottom)
	# Tachometer: 0..8 x1000 rpm, red from 7.
	var tbox := UI.vstack(0)
	tbox.alignment = BoxContainer.ALIGNMENT_END
	_tacho = Dial.new()
	var tl := []
	for i in 9:
		if i % 2 == 0:
			tl.append([i / 8.0, str(i)])
	_tacho.setup(120.0, 16, tl, 7.0 / 8.0, UI.YELLOW)
	tbox.add_child(_tacho)
	var rpm_l := UI.label(tr("RC_RPM"), 24, UI.GREY)
	rpm_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpm_l.custom_minimum_size.x = _tacho.custom_minimum_size.x
	tbox.add_child(rpm_l)
	bottom.add_child(tbox)
	# Gear indicator + shift light + nitro timer.
	var gbox := UI.vstack(6)
	gbox.alignment = BoxContainer.ALIGNMENT_END
	gbox.custom_minimum_size.x = 200
	_shift_label = UI.label(tr("RC_SHIFT"), 36, UI.RED)
	_shift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shift_label.modulate.a = 0.0
	gbox.add_child(_shift_label)
	var gl := UI.label(tr("RC_GEAR"), 24, UI.GREY)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gbox.add_child(gl)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.85)
	sb.border_color = UI.WHITE
	sb.set_border_width_all(6)
	sb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(120, 120)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gear_label = UI.label("", 84, UI.WHITE)
	_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(_gear_label)
	gbox.add_child(frame)
	_nitro_label = UI.label(tr("RC_NITRO"), 24, UI.CYAN)
	_nitro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nitro_label.modulate.a = 0.0
	gbox.add_child(_nitro_label)
	var strip_bg := Control.new()
	strip_bg.custom_minimum_size = Vector2(160, 12)
	strip_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_nitro_strip = ColorRect.new()
	_nitro_strip.color = UI.CYAN
	_nitro_strip.size = Vector2(0, 12)
	strip_bg.add_child(_nitro_strip)
	gbox.add_child(strip_bg)
	bottom.add_child(gbox)
	# Speedometer: 0..360 km/h, digital readout under the hub.
	var sbox := UI.vstack(0)
	sbox.alignment = BoxContainer.ALIGNMENT_END
	_speedo = Dial.new()
	var sl := []
	for k in range(0, 361, 60):
		sl.append([k / 360.0, str(k)])
	_speedo.setup(170.0, 24, sl, 2.0, UI.CYAN)
	sbox.add_child(_speedo)
	_speed_label = UI.label("0", 60, UI.WHITE)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.custom_minimum_size = Vector2(160, 0)
	_speed_label.position = _speedo.hub() + Vector2(-80, 24)
	_speedo.add_child(_speed_label)
	var kmh := UI.label(tr("RC_KMH"), 24, UI.GREY)
	kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kmh.custom_minimum_size.x = _speedo.custom_minimum_size.x
	sbox.add_child(kmh)
	bottom.add_child(sbox)

	_drift_label = UI.label("", 60, UI.YELLOW)
	_drift_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drift_label.offset_top = 300
	_drift_label.offset_left = -500
	_drift_label.offset_right = 500
	_hud.add_child(_drift_label)


## Tachometer needle 0..1: idle at 1/8, the gear's top speed near the end.
func _tach_value() -> float:
	return lerpf(0.11, 1.0, sim.rpm)


func _gear_text(g: int) -> String:
	return tr("RC_GEAR_L") if g == Sim.Gear.LOW else tr("RC_GEAR_H")


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
	UI.set_color(_speed_label, UI.CYAN if sim.boosting else UI.WHITE)
	_speedo.set_value(sim.v * 3.6 / 360.0)
	_tacho.set_value(_tach_value())
	_gear_label.text = _gear_text(sim.gear)
	UI.set_color(_gear_label, UI.YELLOW if sim.gear == Sim.Gear.LOW else UI.WHITE)
	var shift_now := sim.gear == Sim.Gear.LOW and sim.rpm >= Sim.REDLINE
	_shift_label.modulate.a = 1.0 if shift_now and fmod(_phase_t, 0.3) < 0.18 else 0.0
	_nitro_label.modulate.a = 1.0 if sim.boosting else 0.0
	_nitro_strip.size.x = roundf(160.0 * sim.boost_t / Sim.NITRO_TIME)
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
		Dmd.show_custom(_draw_dmd_dash)
	score_changed.emit(0, sim.score)


## DMD dashboard (D-103): segmented speedometer dial (the director's icon
## style) on the left, digital speed + score, gear box and clock on the right,
## and a horizontal tachometer bar along the bottom (red zone = shift up).
func _draw_dmd_dash(p) -> void:
	if sim == null:
		return
	const HUB := Vector2(17, 22)
	const R := 16.0
	const SEGS := 11
	var a_from := Dial.SWEEP_FROM
	var a_to := Dial.SWEEP_TO
	var speed_f := clampf(sim.v * 3.6 / 360.0, 0.0, 1.0)
	for y in range(int(HUB.y - R) - 1, 32):
		for xx in range(0, 36):
			var d := Vector2(xx + 0.5, y + 0.5) - HUB
			var r := d.length()
			var a := atan2(d.y, d.x)
			if a < a_from - 0.01:
				a += TAU
			if a < a_from or a > a_to or r > R:
				continue
			var f := (a - a_from) / (a_to - a_from)
			var i := mini(int(f * SEGS), SEGS - 1)
			var fi := (i + 0.5) / SEGS
			var k := clampf((fi - 0.15) / 0.85, 0.0, 1.0)
			var depth := lerpf(1.6, 5.0, k)
			var seg_pos := f * SEGS - i
			var gap := lerpf(0.5, 0.18, k)
			if r < R - depth or seg_pos < gap * 0.5 or seg_pos > 1.0 - gap * 0.5:
				continue
			var lit := speed_f >= fi
			var c := (Dmd.CYAN if not sim.boosting else Dmd.WHITE) if lit else Color(0.16, 0.18, 0.22)
			p.dot(xx, y, c)
	var na := lerpf(a_from, a_to, speed_f)
	var tip := HUB + Vector2(cos(na), sin(na)) * (R - 2.0)
	p.line(HUB.x, HUB.y, tip.x, tip.y, Dmd.WHITE)
	p.ring(HUB.x, HUB.y, 2.0, Dmd.WHITE)
	p.dot(HUB.x, HUB.y, Color.BLACK)
	# Digital speed + score
	var spd := str(sim.speed_kmh())
	p.text(spd, 72 - p.text_width(spd, 2), 1, 2, Dmd.CYAN if sim.boosting else Dmd.WHITE)
	p.text(tr("RC_KMH"), 74, 8, 1, Dmd.DIM)
	var sc := ScoreTable.format_score(sim.score)
	p.text(sc, 104 - p.text_width(sc), 17, 1, Dmd.YELLOW)
	# Gear box
	var g := _gear_text(sim.gear)
	var gc := Dmd.YELLOW if sim.gear == Sim.Gear.LOW else Dmd.WHITE
	p.block(106, 0, 22, 1, gc)
	p.block(106, 18, 22, 1, gc)
	p.block(106, 0, 1, 19, gc)
	p.block(127, 0, 1, 19, gc)
	p.text(g, 117 - p.text_width(g, 2) / 2.0, 3, 2, gc)
	# Clock
	var low := sim.time_left < 10.0
	var t := str(ceili(sim.time_left))
	p.text(t, 127 - p.text_width(t), 21, 1, Dmd.RED if low and fmod(_phase_t, 0.5) < 0.25 else Dmd.YELLOW)
	# Tachometer bar: 13 cells, red from 7/8; blinks when it's time to shift.
	const CELLS := 13
	var tach := _tach_value()
	var shift_now := sim.gear == Sim.Gear.LOW and sim.rpm >= Sim.REDLINE
	for i in CELLS:
		var f := (i + 0.5) / CELLS
		var red := f >= 7.0 / 8.0
		var on := tach >= f
		var c := Color(0.16, 0.18, 0.22)
		if on:
			c = Dmd.RED if red else (Dmd.YELLOW if f > 0.6 else Dmd.GREEN)
		elif red:
			c = Color(0.35, 0.08, 0.1)
		if shift_now and fmod(_phase_t, 0.24) < 0.12:
			c = Dmd.RED
		p.block(38 + i * 5, 27, 4, 5, c)


func _build_backglass() -> void:
	# Director's backglass art with two light groups (D-109): the logo and the
	# lights (headlights, truck lights, sparks, stars), driven by the race.
	add_to_backglass(UI.fill(Color.BLACK))
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = load(BG_DIR + "backglass_off.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BACKGLASS_SHADER
	_bg_mat.set_shader_parameter("on_tex", load(BG_DIR + "backglass_on.png"))
	_bg_mat.set_shader_parameter("mask_tex", load(BG_DIR + "backglass_mask.png"))
	_bg_mat.set_shader_parameter("logo_mask_tex", load(BG_DIR + "backglass_mask_logo.png"))
	art.material = _bg_mat
	add_to_backglass(art)


## Backglass lights each frame (D-109). Attract: the logo blinks slowly, the
## lights are on. Race: both on; nitro, checkpoints and near misses flash the
## lights; a crash knocks them out briefly. Game over: only the logo stays.
func _update_backglass(delta: float) -> void:
	if _bg_mat == null:
		return
	_bg_flash = maxf(0.0, _bg_flash - delta)
	_bg_dark = maxf(0.0, _bg_dark - delta)
	var lights := 1.0
	var logo := 1.0
	if _phase == "attract":
		logo = 1.0 if fmod(_phase_t, 1.2) < 0.8 else 0.0
	elif _finale_t >= 0.0 or (sim != null and sim.state == Sim.State.OVER):
		lights = 0.0
	if _bg_dark > 0.0:
		lights = 0.0 if fmod(_bg_dark, 0.16) < 0.1 else 0.3
	elif _bg_flash > 0.0:
		lights = 1.0 if fmod(_bg_flash, 0.1) < 0.05 else 0.2
		logo = maxf(logo, lights)
	_bg_mat.set_shader_parameter("levels", Vector4(lights, 0.0, 0.0, logo))


func _logo_rect(width: float) -> TextureRect:
	var tex: Texture2D = load(LOGO)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(width, width * tex.get_height() / tex.get_width())
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


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
	var rpm := sim.rpm
	_engine.pitch_scale = 0.6 + rpm * 1.9 + (0.25 if sim.boosting else 0.0)
	_engine.volume_db = -14.0 + sim.throttle * 4.0 + rpm * 2.0
	var squeal := sim.drifting or (sim.state == Sim.State.OVER and sim.v > 3.0) 		or (sim.spin_t > 0.0 and not sim.stalled()) or sim.auto_braking
	_skid.volume_db = lerpf(_skid.volume_db, -10.0 if squeal else -60.0, 0.2)
