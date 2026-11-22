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

const InstParam = preload("res://core/util/inst_param.gd")

const Sim = preload("res://games/racer/sim.gd")
const Track = preload("res://games/racer/track.gd")
const Scenery = preload("res://games/racer/scenery.gd")
const Toon = preload("res://games/racer/toon.gd")
const Sprites = preload("res://games/racer/sprites.gd")
const Night = preload("res://games/racer/night.gd")
const DmdAnims = preload("res://games/racer/dmd_anims.gd")
const Showroom = preload("res://games/racer/showroom.gd")
const Tunnel = preload("res://games/racer/tunnel.gd")
const SELECT_TIME := 15.0   # s to choose a car before the highlighted one is taken
## Car colours on the DMD, matching Sim.CARS' hues (red, yellow, blue).
const CAR_COLS := [Color("e8303a"), Color("ffd23e"), Color("3f8cff")]
const NIGHT_GROUP := &"rc_night_lights"
const Dial = preload("res://games/racer/dial.gd")
const GearLever = preload("res://games/racer/gear_lever.gd")
const RadarBar = preload("res://games/racer/radar_bar.gd")
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
const SHIFT_RISE := 36.0    # px the SHIFT word rises each loop (D-158)
const SHIFT_NAG := 3.0      # s at the redline in L before the big SHIFT (D-116)
const DIAL_R := 150.0        # tachometer and speedometer radius (D-149)
const SPEEDO_MAX := 220      # mph on the speedometer dial (D-147; nitro on the fastest car ~206)
const MAX_TRAVEL_YAW := 0.45   # rad: the most the nose follows sideways travel (D-124)
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
## Number plate spot on the red car's rear bumper (model space, D-114).
const PLATE_Y := 0.56     # raised clear of the bumper's bottom edge (D-127)
const PLATE_SIZE := Vector2(0.51, 0.255)   # oversized so TRN reads at pixel scale (15 % smaller, D-127)
const PLATE_Z := -2.215           # nitro canisters read from far away (D-103)
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
## Director's second truck (D-121): a US-style tractor with a striped trailer.
const TRUCK2_MODEL := "res://assets/models/racer/truck2.glb"
## Director's hatchback (D-136), mixed into car traffic.
const HATCH_MODEL := "res://assets/models/racer/hatchback.glb"
const HATCH_TEXTURE := "res://assets/models/racer/hatchback_albedo.png"
const HATCH_POOL := 8
## Indicator spots per model, on its own right side (D-163).
const BLINKERS := {
	"car": [Vector3(-0.85, 0.65, -2.15), Vector3(-0.8, 0.6, 2.15)],
	"hatch": [Vector3(-0.8, 0.85, -1.95), Vector3(-0.78, 0.65, 1.95)],
	"truck": [Vector3(-1.3, 0.9, -4.95), Vector3(-1.2, 1.1, 4.95)],
	"truck2": [Vector3(-1.4, 0.9, -4.95), Vector3(-1.3, 1.1, 4.95)],
}
## Lamp areas per model for car.gdshader (model space, |x|; D-144). The red
## car uses the shader defaults.
const LAMP_BOXES := {
	"res://assets/models/racer/hatchback.glb": {
		"tail_min": Vector3(0.0, 0.35, -9.0), "tail_max": Vector3(0.95, 1.3, -1.6),
		"tail_red_only": true,
		"head_min": Vector3(0.35, 0.45, 1.6), "head_max": Vector3(0.85, 0.82, 9.0),
	},
}
## Director's police car (D-135).
const POLICE_MODEL := "res://assets/models/racer/police2.glb"   # D-140: not modelled on a real car
const POLICE_TEXTURE := "res://assets/models/racer/police2_albedo.png"
const TRUCK2_TEXTURE := "res://assets/models/racer/truck2_albedo.png"

const ACCENT := Color("ffd23e")
const TITLE_FONT := "sunset"
## Director's pick: "8-bit Music Pack (Loopable)" by CodeManu, CC BY 3.0 (D-033).
## Director's pick (D-093): the five "action" loops for attract and race. Each
## race starts on the next one, and every checkpoint (new stage) moves on again.
## The first race plays action_3 (director's pick).
## Attract mode: "Maximum Overdrive" by Bogart VGM, CC BY 3.0 (D-104).
const MUSIC_STAGES := 4
const PASSERS := 2          # traffic engine voices (D-134)
const PASS_RANGE := 45.0    # m: how far a car can be heard
const SOUND_SPEED := 110.0  # m/s, exaggerated so the Doppler shift is obvious
const OPENING_STAGES := 4   # stages played to Maximum Overdrive (D-111, D-129)
## Night (stage 5) crossfades to "Dreamstate" by Bogart VGM, CC BY 3.0 (D-129),
## which plays through stage 9; the CodeManu songs take over from stage 10.
const MUSIC_NIGHT := "res://assets/audio/music/racer/bogart_dreamstate.ogg"
const NIGHT_STAGES := 5
const NIGHT_XFADE := 6.0
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
	# Start lights: a soft sine "boop" with an octave shimmer (D-116).
	"rc_count": {"voices": [[{"f": [440.0, 440.0], "t": 0.28, "w": "sine", "v": 0.45, "a": 0.005, "env": "hold"}],
		[{"f": [880.0, 880.0], "t": 0.22, "w": "triangle", "v": 0.12, "a": 0.005}]], "reverb": [0.5, 0.25]},
	# GO: the high start tone over a brass stab chord and a drum boom.
	"rc_go": {"voices": [[{"f": [880.0, 880.0], "t": 0.7, "w": "sine", "v": 0.4, "a": 0.005, "env": "hold"}],
		[{"f": [220.0, 220.0], "t": 0.6, "w": "saw", "v": 0.14, "lp": 0.6, "a": 0.02}],
		[{"f": [330.0, 330.0], "t": 0.6, "w": "saw", "v": 0.12, "lp": 0.6, "a": 0.02}],
		[{"f": [440.0, 440.0], "t": 0.6, "w": "saw", "v": 0.1, "lp": 0.6, "a": 0.02}],
		[{"f": [90.0, 45.0], "t": 0.4, "w": "sine", "v": 0.5}]], "reverb": [0.9, 0.3]},
	# Checkpoint: a rising brass fanfare over a timpani boom.
	"rc_checkpoint": {"voices": [
		[{"f": [262.0, 262.0], "t": 0.08, "w": "saw", "v": 0.18, "lp": 0.55, "env": "hold"},
		 {"f": [330.0, 330.0], "t": 0.08, "w": "saw", "v": 0.18, "lp": 0.55, "env": "hold"},
		 {"f": [392.0, 392.0], "t": 0.08, "w": "saw", "v": 0.18, "lp": 0.55, "env": "hold"},
		 {"f": [523.0, 523.0], "t": 0.6, "w": "saw", "v": 0.2, "lp": 0.5, "vib": [5.5, 0.15]}],
		[{"f": [131.0, 131.0], "t": 0.24, "w": "saw", "v": 0.14, "lp": 0.7, "env": "hold"},
		 {"f": [196.0, 196.0], "t": 0.6, "w": "saw", "v": 0.14, "lp": 0.7}],
		[{"f": [95.0, 50.0], "t": 0.5, "w": "sine", "v": 0.55}]], "reverb": [1.1, 0.3]},
	# Crash: an impact boom, crunching metal and breaking glass.
	"rc_crash": {"voices": [
		[{"f": [3000.0, 90.0], "t": 0.9, "w": "lfsr", "v": 0.42, "lp": 0.45}],
		[{"f": [110.0, 32.0], "t": 0.6, "w": "sine", "v": 0.65}],
		[{"f": [5200.0, 1800.0], "t": 0.35, "w": "noise", "v": 0.16}],
		[{"f": [3520.0, 3520.0], "t": 0.04, "w": "triangle", "v": 0.08, "gap": 0.03},
		 {"f": [2960.0, 2960.0], "t": 0.04, "w": "triangle", "v": 0.07, "gap": 0.05},
		 {"f": [4186.0, 4186.0], "t": 0.05, "w": "triangle", "v": 0.06, "gap": 0.04},
		 {"f": [3136.0, 3136.0], "t": 0.06, "w": "triangle", "v": 0.05}]], "reverb": [0.9, 0.3]},
	# Bump: a body thud with a metal clank.
	"rc_bump": {"voices": [[{"f": [130.0, 45.0], "t": 0.22, "w": "sine", "v": 0.6}],
		[{"f": [1800.0, 500.0], "t": 0.1, "w": "noise", "v": 0.25, "lp": 0.6}],
		[{"f": [620.0, 540.0], "t": 0.12, "w": "triangle", "v": 0.1}]], "reverb": [0.3, 0.15]},
	# Nitro (D-121): an ignition "fwoomp" - a noise burst falling through a low
	# pass, a growling engine roar and a sub boom; no tonal lead.
	"rc_nitro": {"voices": [
		[{"f": [6000.0, 400.0], "t": 0.55, "w": "noise", "v": 0.45, "lp": 0.35, "a": 0.01}],
		[{"f": [70.0, 140.0], "t": 0.35, "w": "saw", "v": 0.3, "lp": 0.7, "vib": [32.0, 0.8], "env": "hold"},
		 {"f": [140.0, 120.0], "t": 0.5, "w": "saw", "v": 0.25, "lp": 0.75, "vib": [32.0, 0.6]}],
		[{"f": [80.0, 36.0], "t": 0.6, "w": "sine", "v": 0.6}]], "reverb": [0.8, 0.22]},
	# Perfect shift / start (D-121): a rising brass stab with a turbo whoosh.
	"rc_perfect": {"voices": [
		[{"f": [262.0, 262.0], "t": 0.08, "w": "saw", "v": 0.16, "lp": 0.6, "env": "hold"},
		 {"f": [392.0, 392.0], "t": 0.35, "w": "saw", "v": 0.17, "lp": 0.55}],
		[{"f": [131.0, 131.0], "t": 0.08, "w": "saw", "v": 0.14, "lp": 0.7, "env": "hold"},
		 {"f": [196.0, 196.0], "t": 0.35, "w": "saw", "v": 0.14, "lp": 0.7}],
		[{"f": [800.0, 5000.0], "t": 0.35, "w": "noise", "v": 0.22, "lp": 0.4, "env": "lin"}]], "reverb": [0.8, 0.25]},
	# Radar detector chirp (D-135): a short, bright double blip.
	"rc_radar": {"voices": [[{"f": [2900.0, 2900.0], "t": 0.035, "w": "square", "v": 0.12, "env": "hold", "gap": 0.02},
		{"f": [2900.0, 2900.0], "t": 0.035, "w": "square", "v": 0.12, "env": "hold"}]]},
	# Upshift backfire: a crackle and a thump.
	"rc_backfire": {"voices": [[{"f": [1800.0, 300.0], "t": 0.12, "w": "lfsr", "v": 0.4, "lp": 0.3}],
		[{"f": [110.0, 50.0], "t": 0.15, "w": "sine", "v": 0.5}]], "reverb": [0.3, 0.2]},
	# Downshift: a short tyre chirp.
	"rc_chirp": {"voices": [[{"f": [1400.0, 900.0], "t": 0.18, "w": "triangle", "v": 0.18, "vib": [30.0, 0.8]}],
		[{"f": [5000.0, 3000.0], "t": 0.16, "w": "noise", "v": 0.12, "lp": 0.4}]]},
	"rc_horn": {"voices": [[{"f": [392.0, 392.0], "t": 0.18, "w": "square", "v": 0.14, "env": "hold", "lp": 0.5}],
		[{"f": [494.0, 494.0], "t": 0.18, "w": "square", "v": 0.14, "env": "hold", "lp": 0.5}]], "echo": [0.26, 0.5, 1.5]},
	# Gear change: a mechanical clunk.
	"rc_shift": {"voices": [[{"f": [150.0, 60.0], "t": 0.09, "w": "sine", "v": 0.5}],
		[{"f": [2200.0, 900.0], "t": 0.04, "w": "lfsr", "v": 0.18, "lp": 0.4}]]},
	# Near miss: a Doppler pass, engine tone dropping as it whooshes by.
	"rc_near_miss": {"voices": [[{"f": [440.0, 150.0], "t": 0.5, "w": "saw", "v": 0.16, "lp": 0.6}],
		[{"f": [4000.0, 500.0], "t": 0.45, "w": "noise", "v": 0.28, "lp": 0.45, "a": 0.05}]], "reverb": [0.4, 0.2]},
	# Drift points banked (D-121): a short brass stab over a tyre-release swoosh.
	"rc_drift_bank": {"voices": [
		[{"f": [294.0, 294.0], "t": 0.22, "w": "saw", "v": 0.16, "lp": 0.6, "a": 0.01}],
		[{"f": [370.0, 370.0], "t": 0.22, "w": "saw", "v": 0.14, "lp": 0.6, "a": 0.01}],
		[{"f": [440.0, 440.0], "t": 0.22, "w": "saw", "v": 0.12, "lp": 0.6, "a": 0.01}],
		[{"f": [3000.0, 800.0], "t": 0.3, "w": "noise", "v": 0.2, "lp": 0.5}],
		[{"f": [100.0, 55.0], "t": 0.2, "w": "sine", "v": 0.4}]], "reverb": [0.6, 0.22]},
	# Low-time clock: a woodblock "tock" with a soft body (D-112).
	"rc_tick": {"voices": [[{"f": [1900.0, 1600.0], "t": 0.05, "w": "triangle", "v": 0.35}],
		[{"f": [950.0, 900.0], "t": 0.09, "w": "sine", "v": 0.25}],
		[{"f": [7000.0, 7000.0], "t": 0.012, "w": "noise", "v": 0.18, "lp": 0.2}]], "reverb": [0.35, 0.18]},
	# Time up: a falling brass phrase and a low boom.
	"rc_time_up": {"voices": [
		[{"f": [392.0, 392.0], "t": 0.25, "w": "saw", "v": 0.18, "lp": 0.6, "env": "hold"},
		 {"f": [330.0, 330.0], "t": 0.25, "w": "saw", "v": 0.18, "lp": 0.6, "env": "hold"},
		 {"f": [262.0, 220.0], "t": 0.9, "w": "saw", "v": 0.2, "lp": 0.65, "vib": [4.0, 0.25]}],
		[{"f": [131.0, 110.0], "t": 1.4, "w": "saw", "v": 0.12, "lp": 0.75}],
		[{"f": [70.0, 40.0], "t": 0.8, "w": "sine", "v": 0.5}]], "reverb": [1.2, 0.3]},
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
var _police: Node3D          # D-135
var _flashers: Array = []
var _washes: Array = []
var _police_swing := 0.0     # 0..1 of the 90-degree stop turn (D-139)      # red / blue screen-edge glows (D-137)
var _siren: AudioStreamPlayer
var _radar_bar: Control
var _radar_led := 0.0
var _radar_beep_t := 0.0
var _world_view: TextureRect
var _showroom: Control
var _select_hint: Label
var _chosen_car := Sim.DEFAULT_CAR
var _bg_mat: ShaderMaterial
var _anims := DmdAnims.new()
var _night := 0.0           # 0 = day, 1 = night (D-113)
var _night_shown := -1.0
var _tunnel_k := 0.0        # 0 outside .. 1 inside a tunnel (D-127)
var _tunnel_shown := -1.0
var _lamps := 0.0           # car lights level: max(night, tunnel)
var _reverb: AudioEffectReverb
var _sky_mat: ShaderMaterial
var _sky_proc: ProceduralSkyMaterial
var _day_top := Color.BLACK
var _day_fog := Color.BLACK
var _player_lights: Node3D
var _flame_mats: Array = []
var _rev_pop_t := 0.0
var _rev_popped := false
var _last_rpm := 0.0
var _shift_smoke_t := 0.0   # downshift tyre smoke left (D-112)
var _shift_flame_t := 0.0   # upshift exhaust flame left
var _bg_flash := 0.0    # s of backglass light flashing left (D-109)
var _bg_dark := 0.0     # s of crash flicker left
var _sky_h := 0.0
var _wheel_phase := 0.0
var _travel := 0.0         # eased nose angle from sideways travel (D-128)
var _over_turn := 0.0   # 0..1 TIME UP sideways slide (D-105)
var _over_dir := 0.0
var _music_i := FIRST_TRACK    # current race song index
var _traffic_pool := {"car": [], "hatch": [], "truck": [], "truck2": []}   # pools of Node3D per model
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
var _engine_hi: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _passers: Array = []    # AudioStreamPlayers for nearby traffic (D-134)
var _hud: Control
var _time_label: Label
var _score_label: Label
var _stage_label: Label
var _speed_label: Label
var _speedo: Control
var _tacho: Control
var _gear_lever: Control
var _shift_big: Label
var _shift_slot: Control
var _cops_flash := false
var _blink_mesh: QuadMesh
var _shift_armed := true    # SHIFT hint allowed (start of race / after a crash, D-160)
var _shift_shown := false
var _nitro_pop: Label       # NITRO notice above the speedometer (D-159)
var _nitro_pop_t := 0.0
var _nag_lever: Control     # animated shifter next to SHIFT (D-151)
var _frozen_label: Label
var _freeze_time := false   # debug cheat: clock frozen (D-118)
var _redline_t := 0.0       # s held at the redline in L (D-116)
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
	DebugTools.debug_action.connect(_on_debug_action)
	_build_world()
	_build_hud()
	_build_backglass()
	_build_audio_loops()
	# Tunnel reverb on the effects bus (D-127), removed again when the game ends.
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.75
		_reverb.damping = 0.35
		_reverb.spread = 0.8
		_reverb.dry = 1.0
		_reverb.wet = 0.0
		AudioServer.add_bus_effect(bus, _reverb)
	if Config.cli.has("rc-car"):   # dev: race with car 0 (easy) / 1 / 2 (hard), D-122
		_chosen_car = clampi(int(str(Config.cli["rc-car"])), 0, Sim.CARS.size() - 1)
	if Config.cli.has("rc-skip-intro"):
		_begin_race()
	else:
		_enter_attract()


func on_action(action: StringName, pressed: bool) -> void:
	if not pressed:
		return
	if _phase == "attract":
		if action == &"start" or action == &"launch":
			_begin_select()
		return
	if _phase == "select":
		match action:
			&"flip_l":
				_showroom.move(-1)
				Audio.sfx("rc_shift")
			&"flip_r":
				_showroom.move(1)
				Audio.sfx("rc_shift")
			&"launch", &"start":
				_confirm_car()
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
	_update_night(delta)
	var dt := minf(delta, 0.05)
	if _phase == "attract":
		sim.time_left = 99.0
		sim.step(dt, false, false)
		_attract_tick()
	elif _phase == "select":
		var left := ceili(SELECT_TIME - _phase_t)
		_select_hint.text = tr("RC_SELECT_HINT") % maxi(left, 0)
		if _phase_t >= SELECT_TIME:
			_confirm_car()
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
	sim.freeze_time = _freeze_time
	sim.car = _chosen_car
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
	# DMD cycle; music credits (CC BY attribution, D-129) mixed in.
	var step := int(_phase_t / 3.0) % 6
	if step != int((_phase_t - get_process_delta_time()) / 3.0) % 6 or _phase_t < 0.05:
		match step:
			0: Dmd.show_image(load(DMD_LOGO))
			1: Dmd.show_text(tr("RC_SHIFT_HINT"), tr("RC_NITRO_HINT"), Dmd.CYAN, Dmd.WHITE)
			2: Dmd.show_text(tr("RC_CREDIT_MUSIC"), tr("RC_CREDIT_BOGART"), Dmd.DIM, Dmd.YELLOW)
			3: Dmd.show_text(tr("ATTRACT_HIGH_SCORES"), _top_score_line(), Dmd.YELLOW, Dmd.WHITE)
			4: Dmd.show_text(tr("RC_CREDIT_BOGART"), tr("RC_CREDIT_BOGART_URL"), Dmd.YELLOW, Dmd.WHITE)
			5: Dmd.show_text(tr("RC_CREDIT_MUSIC"), tr("RC_CREDIT_CODEMANU"), Dmd.DIM, Dmd.CYAN)


func _top_score_line() -> String:
	var table: Array = HighScores.get_table("racer")
	if table.is_empty():
		return ""
	var row: Array = table[0]
	return "%s %s" % [row[0], ScoreTable.format_score(int(row[1]))]


## Car select (D-122): three cars in a showroom, flippers choose, Launch/Start
## confirms (or the timer picks the highlighted one).
func _begin_select() -> void:
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_phase = "select"
	_phase_t = 0.0
	Audio.sfx("start")
	_world_view.visible = false
	_showroom = Showroom.new()
	add_to_table(_showroom)
	_showroom.selected = _chosen_car
	_showroom.build(func(hue: float) -> Node3D: return _car_instance(hue), load(SKY_TEXTURE), TITLE_FONT)
	_select_hint = UI.label("", 36, UI.WHITE)
	_select_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_select_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_hint.offset_top = -90
	_select_hint.offset_bottom = -40
	_showroom.add_child(_select_hint)
	Dmd.show_custom(_draw_dmd_select)


func _confirm_car() -> void:
	if _phase != "select":
		return
	_chosen_car = _showroom.selected
	_showroom.queue_free()
	_showroom = null
	_world_view.visible = true
	_begin_race()


## DMD while choosing (D-122): the car in its colour, its name, top speed and
## cornering pips, with arrows to the other choices.
func _draw_dmd_select(p) -> void:
	if not is_instance_valid(_showroom):
		return
	var i: int = _showroom.selected
	var spec: Dictionary = Sim.CARS[i]
	var col: Color = CAR_COLS[i]
	_anims._car(p, 5, 13, col)
	p.text(tr(spec.name), 24, 1, 1, Showroom.ROW_COLS[i])
	p.text(tr("RC_DMD_TOP") % roundi(float(spec.top) * Sim.MPH), 24, 12, 1, Dmd.WHITE)
	p.text(tr("RC_DMD_CORNER"), 24, 23, 1, Dmd.DIM)
	var x0: float = 26 + p.text_width(tr("RC_DMD_CORNER"))
	for k in Showroom.PIPS:
		p.block(x0 + k * 6, 23, 5, 5, col if k < Showroom.corner_pips(i) else Color(0.16, 0.18, 0.22))
	if i > 0:
		for d in 4:
			p.line(122 - d, 4 + d, 126 + d, 4 + d, Dmd.WHITE)   # up arrow: the car above
	if i < 2:
		for d in 4:
			p.line(122 - d, 28 - d, 126 + d, 28 - d, Dmd.WHITE)


func _begin_race() -> void:
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_phase = "race"
	_phase_t = 0.0
	_new_sim()
	_shift_armed = true
	_shift_shown = false
	# The hero car in the chosen car's colour (D-122).
	for m in _car_body.find_children("*", "MeshInstance3D", true, false):
		var gi := m as MeshInstance3D
		if gi.material_override != null:
			InstParam.set_param(gi, "hue", float(Sim.CARS[_chosen_car].hue))
	# Stage 1 is always action_3 (D-106; was: each race moved on a song).
	# Stages 1-5 play Maximum Overdrive (D-111), carried on from attract.
	_music_i = FIRST_TRACK
	Audio.play_music(MUSIC_ATTRACT)
	Audio.sfx("start")
	_hud.visible = true
	_show_mode()
	_center_message("3", 1.0)
	Audio.sfx("rc_count")
	Dmd.show_custom(_draw_dmd_revup)   # REV UP! with a live tacho (D-154)
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
		# Distance in the score's styled font, tinted cyan (D-116).
		var dist := UI.styled_label(tr("RC_DISTANCE") % (sim.s / 1609.34), TITLE_FONT, 2)   # miles (D-147)
		dist.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		_finale_ui.add_child(dist)
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
				Dmd.show_custom(_draw_dmd_revup)
			"go":
				_center_message(tr("RC_GO"), 1.0)
				Audio.sfx("rc_go")
				Dmd.flash(tr("RC_GO"), 1.0, Dmd.GREEN)
			"checkpoint":
				_bg_flash = 1.2
				Audio.sfx("rc_checkpoint")
				# Stage 6 starts the CodeManu songs (action_3 first), which then
				# change every MUSIC_STAGES stages (D-105, D-111).
				var stage := int(e[1]) + 1
				var later := OPENING_STAGES + NIGHT_STAGES + 1   # stage 10
				if stage == OPENING_STAGES + 1:
					Audio.play_music(MUSIC_NIGHT, NIGHT_XFADE)   # as the lights go down
				elif stage == later:
					_music_i = FIRST_TRACK
					Audio.play_music(MUSIC_TRACKS[_music_i])
				elif stage > later and (stage - later) % MUSIC_STAGES == 0:
					_music_i += 1
					Audio.play_music(MUSIC_TRACKS[_music_i % MUSIC_TRACKS.size()])
				# Reached on momentum after TIME UP: the race goes on (D-103).
				var saved: bool = e.size() > 3 and e[3]
				# No CHECKPOINT notice mid-TABLE (D-142): the gate, DMD and sound
				# say it; JUST MADE IT! still shows when it saves the race.
				if saved:
					_center_message(tr("RC_JUST_MADE_IT"), 1.6)
				_dmd_anim("checkpoint", [tr("RC_CHECKPOINT"), tr("RC_EXTENDED") % int(e[2])])
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
					_dmd_anim("drift", [tr("RC_DRIFT"), ScoreTable.format_score(int(e[1]))])
					_drift_label.modulate.a = 1.0
			"nitro", "nitro_refill":
				_bg_flash = 0.6
				Audio.sfx("rc_nitro")
				_nitro_pop_t = 0.8   # small notice over the speedometer (D-159)
				_dmd_anim("nitro", [tr("RC_NITRO")])
				_shake = 0.3
			"high_beams":
				Audio.sfx("rc_horn")
			"perfect_start":
				Audio.sfx("rc_perfect")
				Audio.sfx("rc_backfire")
				_dmd_anim("perfect", [tr("RC_PERFECT_START")])
				_bg_flash = 0.6
				_shake = 0.3
			"perfect_shift":
				Audio.sfx("rc_perfect")
				Audio.sfx("rc_backfire")
				_dmd_anim("perfect", [tr("RC_PERFECT_SHIFT")])
				_bg_flash = 0.5
				_shake = 0.25
			"shift":
				Audio.sfx("rc_shift")
				# Upshift: a short exhaust flame + backfire; downshift: tyre smoke
				# + a chirp (D-112).
				if int(e[1]) == Sim.Gear.HIGH:
					_shift_flame_t = 0.16
					Audio.sfx("rc_backfire")
				else:
					_shift_smoke_t = 0.5
					if sim.spin_t <= 0.0:
						Audio.sfx("rc_chirp")
				if sim.spin_t <= 0.0:   # a crash's own downshift shows the crash instead
					_dmd_anim("shift", [int(e[1]) == Sim.Gear.HIGH, tr("RC_GEAR"), tr("RC_GEAR_H"), tr("RC_GEAR_L")])
			"near_miss":
				_bg_flash = 0.4
				Audio.sfx("rc_near_miss")
				_dmd_anim("near_miss", [tr("RC_NEAR_MISS"), "+" + ScoreTable.format_score(5000)])
			"pass":
				pass
			"bump":
				Audio.sfx("rc_bump")
				_shake = maxf(_shake, 0.25)
			"police_spawn":
				_center_message(tr("RC_POLICE"), 1.4)
				_cops_flash = true   # red/blue flashing text (D-158)
				Dmd.flash(tr("RC_POLICE"), 1.4, Dmd.RED)
			"police_ram":
				Audio.sfx("rc_bump")
				_shake = 0.45
				_bg_dark = 0.3
			"busted":
				_center_message(tr("RC_BUSTED"), 2.5)
				_dmd_anim("fine", [tr("RC_BUSTED"), tr("RC_FINE"), "-" + ScoreTable.format_score(int(e[1]))])
				Audio.sfx("rc_time_up")
			"police_escape":
				_center_message(tr("RC_ESCAPED"), 1.4)
				Dmd.flash(tr("RC_ESCAPED"), 1.2, Dmd.GREEN)
				Audio.sfx("rc_perfect")
			"crash":
				_shift_armed = true   # the SHIFT hint may show again (D-160)
				_bg_dark = 0.8
				Audio.sfx("rc_crash")
				_shake = 0.8
				_dmd_anim("crash", [tr("RC_CRASH")])


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
	_world_view = view
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
	# Police light wash (D-137): red and blue glows from the screen edges.
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 2:
		var g := Gradient.new()
		var c: Color = Color(0.15, 0.3, 1.0) if i == 0 else Color(1.0, 0.1, 0.08)   # left blue, right red
		g.set_color(0, c if i == 0 else Color(c, 0.0))
		g.set_color(1, Color(c, 0.0) if i == 0 else c)
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 64
		gt.height = 4
		var wash := TextureRect.new()
		wash.texture = gt
		wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wash.stretch_mode = TextureRect.STRETCH_SCALE
		wash.material = add_mat
		wash.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE if i == 0 else Control.PRESET_RIGHT_WIDE)
		if i == 0:
			wash.offset_right = 540
		else:
			wash.offset_left = -540
		wash.modulate.a = 0.0
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_to_table(wash)
		_washes.append(wash)
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
	_sky_mat = mmat
	mmat.shader = SKY_SHADER
	mmat.set_shader_parameter("sky", sky_img)
	mmat.set_shader_parameter("height", sky_h)
	_sky_h = sky_h
	var im := sky_img.get_image()
	var top := _row_colour(im, 0)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = top
	_sky_proc = sky_mat
	_day_top = top
	sky_mat.sky_curve = 1.0
	_env.fog_light_color = _row_colour(im, im.get_height() - 4)
	_day_fog = _env.fog_light_color
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
		if LAMP_BOXES.has(model):   # where this model's lamps are (D-144)
			var lb: Dictionary = LAMP_BOXES[model]
			for k in lb:
				mat.set_shader_parameter(k, lb[k])
		_car_mats[model] = mat
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.material_override = _car_mats[model]
		InstParam.set_param(mi, "hue", hue)
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
	_player_lights = Night.add_car_lights(_car_body, "car", _puff_texture())
	_add_plate(_car_body)
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
		_flame_mats.append(fm)
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
		var count: int = TRAFFIC_POOL if kind == "car" else (HATCH_POOL if kind == "hatch" else Sim.MAX_TRUCKS)
		for i in count:
			var t: Node3D
			match kind:
				"car": t = _car_instance(0.0)
				"hatch": t = _car_instance(0.0, HATCH_MODEL, HATCH_TEXTURE)
				"truck": t = _car_instance(0.0, TRUCK_MODEL, TRUCK_TEXTURE)
				_: t = _car_instance(0.0, TRUCK2_MODEL, TRUCK2_TEXTURE)
			var light_kind := "truck" if kind.begins_with("truck") else "car"
			_add_headlights(t, light_kind)
			_add_blinkers(t, kind)
			t.set_meta("night", Night.add_car_lights(t, light_kind, _puff_texture()))
			t.visible = false
			_root.add_child(t)
			_traffic_pool[kind].append(t)
	for i in 4:
		var pk := _build_pickup()
		pk.visible = false
		_root.add_child(pk)
		_pickup_nodes.append(pk)
	_build_police()


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


## The hero car's rear number plate, "TRN" (D-114, D-116): California style.
## A cream plate with a red state name, orange stripes and a setting sun, bold
## navy letters and an orange motto, drawn once into a small viewport texture.
func _add_plate(body: Node3D) -> void:
	var plate := MeshInstance3D.new()
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 96)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	plate.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.9, 0.88, 0.8)
	bg.size = Vector2(192, 96)
	vp.add_child(bg)
	var face := ColorRect.new()
	face.color = Color(0.98, 0.97, 0.92)
	face.position = Vector2(4, 4)
	face.size = Vector2(184, 88)
	vp.add_child(face)
	for st in [[30.0, 5.0], [38.0, 3.0]]:
		var stripe := ColorRect.new()
		stripe.color = Color(0.93, 0.6, 0.15)
		stripe.position = Vector2(10, st[0])
		stripe.size = Vector2(172, st[1])
		vp.add_child(stripe)
	var sun := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(96 + cos(a) * 15.0, 22 + sin(a) * 15.0))
	sun.polygon = pts
	sun.color = Color(0.95, 0.62, 0.15)
	vp.add_child(sun)
	var state := _plate_label(tr("RC_PLATE_STATE"), 24, Color(0.85, 0.12, 0.12), 2, 2)
	vp.add_child(state)
	var num := _plate_label(tr("RC_PLATE"), 60, Color(0.08, 0.12, 0.42), 30, 3)
	vp.add_child(num)
	var motto := _plate_label(tr("RC_PLATE_MOTTO"), 12, Color(0.85, 0.52, 0.1), 76, 0)
	vp.add_child(motto)
	var q := QuadMesh.new()
	q.size = PLATE_SIZE
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.6
	q.material = m
	plate.mesh = q
	plate.position = Vector3(0.0, PLATE_Y, PLATE_Z)
	plate.rotation_degrees = Vector3(0, 180, 0)   # face backwards
	body.add_child(plate)


## One centred line of plate text; `bold` adds a same-colour outline.
func _plate_label(text: String, size: int, col: Color, y: float, bold: int) -> Label:
	var l := UI.label(text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(192, size + 8)
	l.add_theme_constant_override("outline_size", bold)
	l.add_theme_color_override("font_outline_color", col)
	return l


## Night light under each lamp post (D-113): pool + cone + head glow, following
## the road's pitch so the pool lies on the road.
func _add_lamp_lights(node: Node3D, lamps: Array) -> void:
	var tr_ := sim.track
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Night.lamp_mesh()
	mm.instance_count = lamps.size()
	for i in lamps.size():
		var o: Dictionary = lamps[i]
		var f := tr_.frame(o.s, o.x)
		if o.x < 0.0:
			f.basis = f.basis * Basis(Vector3.UP, PI)
		mm.set_instance_transform(i, f)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = Night.level > 0.0
	mmi.add_to_group(NIGHT_GROUP)
	node.add_child(mmi)


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


## Police car (D-135): the director's model with a light bar of flashing red
## and blue glows, plus a looping two-tone siren.
func _build_police() -> void:
	_police = _car_instance(0.0, POLICE_MODEL, POLICE_TEXTURE)
	_police.visible = false
	_root.add_child(_police)
	for c in [Color(1.0, 0.1, 0.1), Color(0.15, 0.35, 1.0)]:
		var q := QuadMesh.new()
		q.size = Vector2(1.1, 1.1)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_texture = _puff_texture()
		m.albedo_color = c
		q.material = m
		var f := MeshInstance3D.new()
		f.mesh = q
		# Over the model's painted bar (D-147): seen from behind, red is on the
		# right and blue on the left (model space is turned 180 degrees).
		f.position = Vector3(-0.35 if c.r > 0.5 else 0.35, 1.52, 0.15)
		_police.add_child(f)
		_flashers.append(f)
	_siren = AudioStreamPlayer.new()
	_siren.bus = "SFX"
	_siren.stream = _loop_wav(func(t: float) -> float:
		var f := 700.0 if fmod(t, 1.0) < 0.5 else 960.0
		var ph := fmod(t * f, 1.0)
		return ((1.0 if ph < 0.5 else -1.0) * 0.25 + sin(TAU * f * t) * 0.2), 1.0, 0.0)
	_siren.volume_db = -80.0
	add_child(_siren)
	_siren.play()
	_radar_beep_t = 0.0


func _animate_police(delta: float, cam_yaw: float) -> void:
	var tr_ := sim.track
	if sim.police.is_empty():
		_police.visible = false
		for w in _washes:
			(w as CanvasItem).modulate.a = 0.0
		_siren.volume_db = lerpf(_siren.volume_db, -80.0, 0.1)
		return
	var pd: Dictionary = sim.police
	_police.visible = true
	_police.transform = tr_.frame(pd.s, pd.x)
	var h := tr_.heading(pd.s)
	# Swerving in on the hero car: the nose turns towards it (the T-bone).
	# While chasing, its nose points at the hero car (D-142).
	var lean := 0.0
	if pd.state == "chase":
		var ahead := maxf(sim.s - float(pd.s) + 6.0, 4.0)
		lean = clampf(atan2(sim.x - float(pd.x), ahead), -0.9, 0.9)
	# Busted (D-139): it swings 90 degrees across as it stops beside you, in
	# stepped frames, and straightens again as it drives off.
	var swing_to := 0.0
	if pd.state == "bust":
		swing_to = clampf(1.0 - absf(float(pd.v)) / 12.0, 0.0, 1.0)
	_police_swing = move_toward(_police_swing, swing_to, delta * 2.5)
	# Across the lane in front (D-161): it swings the way it cut in.
	var side: float = pd.get("swing", 1.0)
	lean += roundf(_police_swing * 4.0) / 4.0 * PI * 0.5 * side
	_police.basis = _police.basis * Basis(Vector3.UP, _sprite_yaw(h - lean, cam_yaw) - h) * MODEL_TURN
	var ph := fmod(_phase_t, 0.5)
	var lights := sim.police_lights()   # off once it has given up or is driving off (D-145)
	var red_on := lights and ph < 0.25 and (ph < 0.08 or ph > 0.15)
	var blue_on := lights and ph >= 0.25 and (ph < 0.33 or ph > 0.4)
	(_flashers[0] as Node3D).visible = red_on
	(_flashers[1] as Node3D).visible = blue_on
	# Screen wash while it's close (D-137): up to 45 % within 25 m.
	var near := 1.0 - clampf((absf(pd.s - sim.s) - 25.0) / 100.0, 0.0, 1.0)
	# Same sides as the light bar seen from behind (D-147): blue left, red right.
	(_washes[0] as CanvasItem).modulate.a = 0.45 * near if blue_on else 0.0
	(_washes[1] as CanvasItem).modulate.a = 0.45 * near if red_on else 0.0
	var d: float = absf(pd.s - sim.s)
	var closing: float = (pd.v - sim.v) * (1.0 if pd.s < sim.s else -1.0)
	_siren.pitch_scale = clampf(SOUND_SPEED / maxf(SOUND_SPEED - closing, 20.0), 0.7, 1.5)
	var siren_db := -4.0 - 26.0 * clampf(d / 200.0, 0.0, 1.0) if lights else -80.0
	_siren.volume_db = lerpf(_siren.volume_db, siren_db, 0.2)


## Radar detector (D-135): beeps faster as a speed camera gets closer, with a
## red LED that lights with each beep (HUD and DMD).
func _update_radar(delta: float) -> void:
	_radar_led = maxf(0.0, _radar_led - delta)
	if sim.radar <= 0.0 or sim.state != Sim.State.RACE:
		_radar_beep_t = 0.0
	else:
		_radar_beep_t -= delta
		if _radar_beep_t <= 0.0:
			_radar_beep_t = lerpf(1.1, 0.09, sim.radar)
			_radar_led = minf(0.07, _radar_beep_t * 0.5)
			Audio.sfx("rc_radar")
	if is_instance_valid(_radar_bar):
		_radar_bar.set_state(sim.radar if sim.state == Sim.State.RACE else 0.0, _radar_led > 0.0)


## Right-hand indicators (D-163): amber glows at the vehicle's own right front
## and rear corners (model space: front +Z, the model's right is -X), flashed
## while it pulls over for the police.
func _add_blinkers(node: Node3D, kind: String) -> void:
	if _blink_mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.55, 0.55)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_texture = _puff_texture()
		m.albedo_color = Color(1.0, 0.6, 0.05)
		q.material = m
		_blink_mesh = q
	var spots: Array = BLINKERS.get(kind, BLINKERS["car"])
	var list := []
	for sp in spots:
		var b := MeshInstance3D.new()
		b.mesh = _blink_mesh
		b.position = sp
		b.visible = false
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(b)
		list.append(b)
	node.set_meta("blinkers", list)


## Nitro pick-up (D-103, D-115): the 16-bit nitrous tank sprite (blue bottle
## with a big N), a camera-facing billboard that bobs on stepped frames.
func _build_pickup() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = Sprites.mesh("nitro")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
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
		if kind == "lamp":
			_add_lamp_lights(node, list)
	Tunnel.build(node, tr_, s0, s0 + CHUNK)   # D-127
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
	# The nose points where the car is going (D-124): the angle of its sideways
	# speed against its forward speed, so it never skates sideways while facing
	# straight. Short taps barely build sideways speed, so they don't twitch it.
	# Eased, and faded in with speed, so a flipper held at GO doesn't snap the
	# car sideways (D-128).
	var travel := 0.0
	if not sim.drifting:
		travel = clampf(atan2(sim.lat_v, maxf(sim.v, 12.0)), -MAX_TRAVEL_YAW, MAX_TRAVEL_YAW)
		travel *= clampf(sim.v / 15.0, 0.0, 1.0)
	_travel = move_toward(_travel, travel, delta * 1.8)
	var yaw := deg_to_rad(sim.drift_angle) - _travel
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
	_shift_smoke_t = maxf(0.0, _shift_smoke_t - delta)
	_shift_flame_t = maxf(0.0, _shift_flame_t - delta)
	# Immune after a crash (D-125): the car blinks, arcade style.
	_car_body.visible = sim.grace_t <= 0.0 or fmod(_phase_t, 0.16) < 0.1
	# Hero car's own lamps (D-120): night lights, and brake lights when braking.
	var braking := sim.braking or sim.auto_braking or (sim.state == Sim.State.OVER and sim.v > 1.0)
	# Turning wheels (D-143): the phase follows the road speed (radius 0.32 m),
	# stepped at ANIM_FPS like sprite frames; fast = a blurred disc.
	_wheel_phase = fmod(_wheel_phase + sim.v / 0.32 * delta, TAU * 100.0)
	var phase_step := floorf(_wheel_phase * 3.0) / 3.0
	for m in _car_body.find_children("*", "MeshInstance3D", true, false):
		var gi := m as MeshInstance3D
		if gi.material_override != null:   # the body, not its outline shell
			InstParam.set_param(gi, "spin", 1.0)
			InstParam.set_param(gi, "wheel_phase", phase_step)
			InstParam.set_param(gi, "wheel_blur", clampf((sim.v - 6.0) / 20.0, 0.0, 1.0))
			InstParam.set_param(gi, "lamps", _lamps)
			InstParam.set_param(gi, "overhead", _overhead(sim.s))
			InstParam.set_param(gi, "brake", 1.0 if braking else 0.0)
	if _player_lights != null:
		_player_lights.visible = _lamps > 0.0 and not (sim.spin_t > 0.0 and sim.flipping)
	var smoking := sim.drifting or sliding_out or _shift_smoke_t > 0.0 or (sim.spin_t > 0.0 and not sim.stalled()) or (sim.offroad and sim.v > 12.0)
	_update_puffs(delta, smoking)
	# Revving on the grid spits fire (D-116): pops while held high, and one as
	# the revs drop.
	if sim.state == Sim.State.COUNTDOWN:
		_rev_pop_t -= delta
		var falling := sim.rpm < _last_rpm - 0.005
		if (sim.rpm > 0.7 and not falling and _rev_pop_t <= 0.0) or (falling and _last_rpm > 0.75 and not _rev_popped):
			_shift_flame_t = 0.14
			_rev_pop_t = randf_range(0.18, 0.4)
			_rev_popped = falling
			Audio.sfx("rc_backfire")
		if not falling:
			_rev_popped = false
	_last_rpm = sim.rpm
	# A perfect shift's boost blasts a long orange flame for its whole push (D-117).
	var blast := sim.perfect_t > 0.0 and not sim.boosting
	var burning := sim.boosting or blast or _shift_flame_t > 0.0
	# Nitro burns blue; upshift and rev pops are short and yellow (D-116).
	var pop := not sim.boosting and not blast
	for m in _flame_mats:
		var fm := m as StandardMaterial3D
		if blast:
			fm.albedo_color = Color(1.0, 0.6, 0.2)
			fm.emission = Color(1.0, 0.4, 0.1)
		else:
			fm.albedo_color = Color(1.0, 0.85, 0.3) if pop else Color(0.5, 0.8, 1.0)
			fm.emission = Color(1.0, 0.6, 0.15) if pop else Color(0.4, 0.7, 1.0)
	for fl in _flames:
		fl.visible = burning
		if burning:
			var short := 0.32 if pop else 1.0
			var sy := (0.8 + randf() * 0.7) * short
			fl.scale = Vector3(1.0, sy, 1.0)
			fl.position.z = -2.2 - 0.5 * sy   # keep the cone's base on the pipe
	# Traffic
	var used := {"car": 0, "hatch": 0, "truck": 0, "truck2": 0}
	for t in sim.traffic:
		var kind: String = t.get("kind", "car")
		if kind == "truck" and int(t.id) % 2 == 1:
			kind = "truck2"   # two truck models, fixed per vehicle (D-121)
		elif kind == "car" and int(t.id) % 5 in [1, 3]:
			kind = "hatch"    # the hatchback in the mix (D-136)
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
		if kind == "car" or kind == "hatch":
			for m in node.find_children("*", "MeshInstance3D", true, false):
				InstParam.set_param((m as MeshInstance3D), "hue", t.hue)
				InstParam.set_param((m as MeshInstance3D), "overhead", _overhead(t.s))
				InstParam.set_param((m as MeshInstance3D), "lamps", maxf(_night, 1.0 if sim.track.in_tunnel(t.s) else 0.0))
		(node.get_meta("night") as Node3D).visible = _lamps > 0.0
		var blink_on: bool = t.get("blink", false) and fmod(_phase_t + t.id * 0.17, 0.7) < 0.35
		for bl in node.get_meta("blinkers", []):
			(bl as Node3D).visible = blink_on
		# High beams: flash-flash ... pause (D-105).
		var ph := fmod(_phase_t + t.id * 0.13, 0.7)
		var beam_on: bool = t.get("flash", false) and (ph < 0.1 or (ph > 0.2 and ph < 0.3))
		for b in node.get_meta("beams", []):
			(b as Node3D).visible = beam_on
	for kind in _traffic_pool:
		for i in range(used[kind], _traffic_pool[kind].size()):
			(_traffic_pool[kind][i] as Node3D).visible = false
	_animate_police(delta, cam_yaw)
	_update_radar(delta)
	# Nitro tanks bob on stepped frames (D-103, D-115).
	for i in _pickup_nodes.size():
		var pk: Node3D = _pickup_nodes[i]
		if i < sim.pickups.size():
			var pd: Dictionary = sim.pickups[i]
			pk.visible = true
			var st := floorf(_phase_t * ANIM_FPS) / ANIM_FPS
			pk.transform = Transform3D(Basis.IDENTITY, tr_.point(pd.s, pd.x, 0.35 + 0.3 * absf(sin(st * 4.0))))
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
	var fov := CAM_FOV + sim.v / Sim.MAX_SPEED * 6.0 + (8.0 if sim.boosting else (5.0 if sim.perfect_t > 0.0 else 0.0))
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
	top.offset_top = 62   # below the radar bar (D-139)
	top.offset_left = 40
	top.offset_right = -40
	_hud.add_child(top)
	var left := UI.vstack(4)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(UI.label(tr("RC_SCORE"), 36, UI.CYAN))
	_score_label = UI.label("0", 48)
	left.add_child(_score_label)
	# Drift points under the score (D-146); fades by alpha, so its slot stays.
	_drift_label = UI.label("", 36, UI.YELLOW)
	_drift_label.custom_minimum_size.y = 44
	_drift_label.modulate.a = 0.0
	left.add_child(_drift_label)
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
	bottom.offset_top = -390
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
	_tacho.setup(DIAL_R, 16, tl, 7.0 / 8.0, UI.YELLOW)   # same size as the speedo (D-149)
	# Perfect-shift band, just before the red (D-116).
	_tacho.good_from = _tach_of(Sim.PERFECT_FROM)
	_tacho.good_to = _tach_of(Sim.PERFECT_TO)
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
	# Gear lever in an H/L gate (D-110).
	_gear_lever = GearLever.new()
	gbox.add_child(_gear_lever)
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
	for k in range(0, SPEEDO_MAX + 1, 40):   # mph (D-147)
		sl.append([k / float(SPEEDO_MAX), str(k)])
	_speedo.setup(DIAL_R, 24, sl, 2.0, UI.CYAN)
	sbox.add_child(_speedo)
	_speed_label = UI.label("0", 60, UI.WHITE)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.custom_minimum_size = Vector2(160, 0)
	_speed_label.position = _speedo.hub() + Vector2(-80, 24)
	_speedo.add_child(_speed_label)
	_nitro_pop = UI.styled_label(tr("RC_NITRO"), TITLE_FONT, 1)
	_nitro_pop.custom_minimum_size = Vector2(320, 0)
	_nitro_pop.position = _speedo.hub() + Vector2(-160, -DIAL_R - 70.0)
	_nitro_pop.modulate.a = 0.0
	_speedo.add_child(_nitro_pop)
	var kmh := UI.label(tr("RC_KMH"), 24, UI.GREY)
	kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kmh.custom_minimum_size.x = _speedo.custom_minimum_size.x
	sbox.add_child(kmh)
	bottom.add_child(sbox)

	# SHIFT nag with a little shifter beside it, pushing L -> H (D-151).
	var nag := HBoxContainer.new()
	nag.alignment = BoxContainer.ALIGNMENT_CENTER
	nag.add_theme_constant_override("separation", 24)
	nag.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	nag.offset_left = -500
	nag.offset_right = 500
	nag.offset_top = -330
	nag.offset_bottom = -110
	_shift_big = UI.label(tr("RC_SHIFT"), 144, UI.RED)
	_shift_big.modulate.a = 0.0
	# Fixed slot; the word moves inside it (D-158), so nothing else shifts.
	var slot := Control.new()
	slot.add_child(_shift_big)
	_shift_slot = slot
	_shift_big.position = Vector2(0, SHIFT_RISE)
	nag.add_child(slot)
	_nag_lever = GearLever.new()
	_nag_lever.modulate.a = 0.0
	nag.add_child(_nag_lever)
	_hud.add_child(nag)
	_frozen_label = UI.label(tr("RC_DEBUG_FROZEN"), 24, UI.CYAN)
	_frozen_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_frozen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frozen_label.offset_left = -300
	_frozen_label.offset_right = 300
	_frozen_label.offset_top = 270
	_frozen_label.modulate.a = 1.0 if _freeze_time else 0.0
	_hud.add_child(_frozen_label)
	# Radar detector light bar at the top, under the clock (D-137).
	_radar_bar = RadarBar.new()
	_radar_bar.position = Vector2(0, 2)
	_radar_bar.size = Vector2(1080, _radar_bar.custom_minimum_size.y)
	_hud.add_child(_radar_bar)




## Tunnel lamp light falling on a car at s (D-153): peaks right under each
## ceiling lamp (Tunnel.LIGHT_EVERY apart), fading over a few metres.
func _overhead(s_at: float) -> float:
	if not sim.track.in_tunnel(s_at):
		return 0.0
	var d := absf(fposmod(s_at + Tunnel.LIGHT_EVERY * 0.5, Tunnel.LIGHT_EVERY) - Tunnel.LIGHT_EVERY * 0.5)
	return clampf(1.0 - d / 6.0, 0.0, 1.0)


## Tachometer needle 0..1: idle at 1/8, the gear's top speed near the end.
func _tach_value() -> float:
	return _tach_of(sim.rpm)


func _tach_of(rpm: float) -> float:
	return lerpf(0.11, 1.0, rpm)


func _gear_text(g: int) -> String:
	return tr("RC_GEAR_L") if g == Sim.Gear.LOW else tr("RC_GEAR_H")


func _show_mode() -> void:
	_mode_label.text = tr("RC_MODE_MANUAL") if sim.manual else tr("RC_MODE_AUTO")


func _center_message(text: String, seconds: float) -> void:
	if is_instance_valid(_center):
		_center.queue_free()
	_cops_flash = false
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
	_speed_label.text = str(sim.speed_mph())
	UI.set_color(_speed_label, UI.CYAN if sim.boosting else UI.WHITE)
	_speedo.set_value(sim.v * Sim.MPH / SPEEDO_MAX)
	_tacho.set_value(_tach_value())
	var countdown := sim.state == Sim.State.COUNTDOWN
	_tacho.good_from = _tach_of(Sim.START_FROM if countdown else Sim.PERFECT_FROM)
	_tacho.good_to = _tach_of(Sim.START_TO if countdown else Sim.PERFECT_TO)
	_gear_lever.set_gear(sim.gear == Sim.Gear.HIGH)
	var shift_now := sim.gear == Sim.Gear.LOW and sim.rpm >= Sim.REDLINE
	# Held at the redline in L for SHIFT_NAG s: a big blinking SHIFT in the
	# middle of the screen, in the timer's font (D-116).
	_redline_t = _redline_t + delta if shift_now and sim.state == Sim.State.RACE else 0.0
	# Only the first time after the start or a crash (D-160): once shown and
	# then resolved, it stays off until the next crash.
	var nagging := _shift_armed and _redline_t >= SHIFT_NAG
	if nagging:
		_shift_shown = true
	elif _shift_shown and _redline_t == 0.0:
		_shift_armed = false
		_shift_shown = false
	_shift_big.modulate.a = 1.0 if nagging and fmod(_phase_t, 0.4) < 0.25 else 0.0
	# Looping rise (D-158): up SHIFT_RISE px in 4 stepped frames, then back.
	var rise := floorf(fmod(_phase_t, 0.5) / 0.5 * 4.0) / 4.0
	_shift_big.position.y = SHIFT_RISE * (1.0 - rise)
	var need := _shift_big.get_combined_minimum_size() + Vector2(0, SHIFT_RISE)
	if _shift_slot.custom_minimum_size != need:   # size the slot once the label is laid out
		_shift_slot.custom_minimum_size = need
	_nag_lever.modulate.a = 1.0 if nagging else 0.0
	if nagging:   # demo loop: sit in L, push up to H, hold; restart at L instantly (D-155)
		var ph := fmod(_redline_t, 1.2)
		if ph < 0.5:
			if _nag_lever.high:
				_nag_lever.snap_low()
		else:
			_nag_lever.set_gear(true)
	_nitro_label.modulate.a = 1.0 if sim.boosting else 0.0
	_nitro_strip.size.x = roundf(160.0 * sim.boost_t / Sim.NITRO_TIME)
	if sim.drifting:
		_drift_label.text = tr("RC_DRIFT_POINTS") % ScoreTable.format_score(int(sim.drift_points / 10.0) * 10)
		_drift_label.modulate.a = 1.0
	else:
		_drift_label.modulate.a = maxf(0.0, _drift_label.modulate.a - delta * 0.8)
	_nitro_pop_t = maxf(0.0, _nitro_pop_t - delta)
	_nitro_pop.modulate.a = 1.0 if _nitro_pop_t > 0.0 and fmod(_nitro_pop_t, 0.2) > 0.06 else 0.0
	if _cops_flash and is_instance_valid(_center):
		var red := fmod(_phase_t, 0.24) < 0.12
		_center.self_modulate = Color(1.0, 0.25, 0.2) if red else Color(0.35, 0.5, 1.0)
	if _center_t > 0.0:
		_center_t -= delta
		if _center_t <= 0.0 and is_instance_valid(_center):
			_center.queue_free()
	_dmd_t -= delta
	if _dmd_t <= 0.0 and sim.state != Sim.State.COUNTDOWN:
		_dmd_t = 0.12
		Dmd.show_custom(_draw_dmd_dash)
	score_changed.emit(0, sim.score)


## DMD while the cops chase (D-162): a side view, our car on the right and the
## police car behind at a gap that follows the real distance (up to 150 m),
## its light bar flashing; the road dashes scroll with our speed. Distance in
## feet top left, speed top right.
func _draw_dmd_chase(p) -> void:
	var pd: Dictionary = sim.police
	var d := maxf(0.0, sim.s - float(pd.s))
	var t := _phase_t
	p.line(0, 29, 127, 29, Color(0.3, 0.3, 0.35))
	var scroll := fmod(sim.s * 1.5, 16.0)
	for i in 9:
		var dx := 128.0 - fmod(i * 16.0 + scroll, 144.0)
		p.line(dx, 31, dx + 6, 31, Color(0.5, 0.5, 0.55))
	_anims._car(p, 108, 24, CAR_COLS[_chosen_car])
	var px := 108.0 - 15.0 - clampf(d / 150.0, 0.0, 1.0) * 86.0
	# Police car: white body, dark lower half, flashing bar.
	for r in DmdAnims.CAR.size():
		var row: String = DmdAnims.CAR[r]
		for c in row.length():
			var k := row[c]
			if k == "0":
				continue
			var col := Dmd.WHITE if r < 2 or (r == 2 and c > 2) else Color(0.25, 0.25, 0.3)
			if k == "2":
				col = Color(0.4, 0.55, 0.7)
			elif k == "4":
				col = Color(0.45, 0.45, 0.5)
			p.dot(px + c, 24 + r, col)
	var red := fmod(t, 0.24) < 0.12
	p.block(px + 4, 22, 2, 2, Dmd.RED if red else Color(0.2, 0.05, 0.05))
	p.block(px + 7, 22, 2, 2, Color("3f6bff") if not red else Color(0.05, 0.05, 0.2))
	# Speed lines behind the police car.
	for i in 3:
		p.line(px - 4 - i * 2, 24 + i * 2, px - 8 - i * 4 - fmod(t * 40.0, 4.0), 24 + i * 2, Color(0.35, 0.35, 0.4))
	var ft := roundi(d * 3.281)
	p.text(tr("RC_DMD_FT") % ft, 2, 2, 1, Dmd.RED if d < 30.0 and red else Dmd.YELLOW)
	var spd := tr("RC_DMD_MPH") % sim.speed_mph()
	p.text(spd, 126 - p.text_width(spd), 2, 1, Dmd.WHITE)
	if _radar_led > 0.0:
		p.disc(64, 4, 1.6, Dmd.RED)


## DMD during the countdown (D-154): REV UP! and the count on the left; a
## pixel tachometer on the right whose needle follows the player's revs, with
## the perfect-start window in green (red past it). It wobbles at idle.
func _draw_dmd_revup(p) -> void:
	if sim == null or sim.state != Sim.State.COUNTDOWN:
		return
	var t := _phase_t
	p.text(tr("RC_REV_UP"), 2, 2, 2, Dmd.YELLOW if fmod(t, 0.5) < 0.32 else Dmd.WHITE)
	p.text(str(maxi(1, ceili(sim.countdown))), 2, 19, 1, Dmd.WHITE)
	# Dial: centre bottom right, sweeping 180 degrees.
	const C := Vector2(104, 29)
	const R := 22.0
	for i in 19:
		var f := i / 18.0
		var a := PI + f * PI
		var col := Color(0.25, 0.27, 0.3)
		if f >= Sim.START_FROM and f < Sim.START_TO:
			col = Dmd.GREEN
		elif f >= Sim.START_TO:
			col = Dmd.RED
		for k in 3:
			var r := R - k
			p.dot(C.x + cos(a) * r, C.y + sin(a) * r, col)
	var v := sim.rpm
	if sim.throttle <= 0.0:
		v = 0.08 + 0.03 * sin(t * 25.0)   # idle wobble
	var na := PI + clampf(v, 0.0, 1.0) * PI
	var in_band := sim.rpm >= Sim.START_FROM and sim.rpm < Sim.START_TO
	p.line(C.x, C.y, C.x + cos(na) * (R - 4), C.y + sin(na) * (R - 4), Dmd.GREEN if in_band else Dmd.WHITE)
	p.disc(C.x, C.y, 1.5, Dmd.WHITE)


## DMD dashboard (D-103): segmented speedometer dial (the director's icon
## style) on the left, digital speed + score, gear box and clock on the right,
## and a horizontal tachometer bar along the bottom (red zone = shift up).
func _draw_dmd_dash(p) -> void:
	if sim == null:
		return
	if sim.police_lights():
		_draw_dmd_chase(p)   # D-162
		return
	# Radar detector LED (D-135), top-left corner.
	if _radar_led > 0.0:
		p.disc(2, 2, 1.6, Dmd.RED)
	const HUB := Vector2(17, 22)
	const R := 16.0
	const SEGS := 11
	var a_from := Dial.SWEEP_FROM
	var a_to := Dial.SWEEP_TO
	var speed_f := clampf(sim.v * Sim.MPH / SPEEDO_MAX, 0.0, 1.0)
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
	var spd := str(sim.speed_mph())
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
		var cd := sim.state == Sim.State.COUNTDOWN   # the start window on the grid (D-128)
		var good := f >= _tach_of(Sim.START_FROM if cd else Sim.PERFECT_FROM) 			and f < _tach_of(Sim.START_TO if cd else Sim.PERFECT_TO)
		if on:
			c = Dmd.RED if red else (Dmd.WHITE if good else (Dmd.YELLOW if f > 0.6 else Dmd.GREEN))
		elif red:
			c = Color(0.35, 0.08, 0.1)
		elif good:
			c = Color(0.1, 0.35, 0.15)   # perfect-shift band (D-116)
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


## Night falls at stage 5 (D-113) over Night.FADE seconds: the backdrop,
## light, fog and the pre-lit sprites darken to moonlit blue, and the fake
## lights (car beams, tail lights, lamp pools) fade in. --rc-night forces it.
func _update_night(delta: float) -> void:
	var target := 0.0
	if Config.cli.has("rc-night"):
		target = 1.0
	elif _phase != "attract" and sim != null and sim.checkpoints >= Night.NIGHT_STAGE - 1 			and sim.checkpoints < Night.DAWN_STAGE - 1:
		target = 1.0   # night for stages 5-9; dawn returns at stage 10 (D-143)
	_night = move_toward(_night, target, delta / Night.FADE)
	# Tunnels (D-127): lights on and daylight dimmed while inside, any stage;
	# the effects bus gets a reverb.
	var in_t := sim != null and sim.in_tunnel
	_tunnel_k = move_toward(_tunnel_k, 1.0 if in_t else 0.0, delta / 0.4)
	_lamps = maxf(_night, _tunnel_k)
	if _reverb != null:
		_reverb.wet = 0.45 * _tunnel_k
	if is_equal_approx(_night, _night_shown) and is_equal_approx(_tunnel_k, _tunnel_shown):
		return
	_tunnel_shown = _tunnel_k
	Night.set_level(_lamps)
	get_tree().call_group(NIGHT_GROUP, "set_visible", _lamps > 0.0)
	var dim := 1.0 - 0.85 * _tunnel_k
	if is_equal_approx(_night, _night_shown):
		_sun.light_energy = lerpf(1.1, 0.22, _night) * dim
		_env.ambient_light_energy = lerpf(0.7, 0.4, _night) * (1.0 - 0.5 * _tunnel_k)
		return
	_night_shown = _night
	var k := _night
	Sprites.set_night(k)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("night", k)
		# Same night grade as the backdrop shader, for the sky above it.
		var lin := _day_top.srgb_to_linear()   # the shader works in linear colour
		var l := lin.r * 0.3 + lin.g * 0.59 + lin.b * 0.11
		var top := lin.lerp(Color(0.06, 0.07, 0.2) + Color(0.1, 0.12, 0.3) * l, k).linear_to_srgb()
		_sky_proc.sky_top_color = top
		_sky_proc.sky_horizon_color = top
	_env.ambient_light_color = Color(0.85, 0.65, 0.8).lerp(Color(0.3, 0.36, 0.62), k)
	_env.ambient_light_energy = lerpf(0.7, 0.4, k) * (1.0 - 0.5 * _tunnel_k)
	_sun.light_energy = lerpf(1.1, 0.22, k) * dim
	_sun.light_color = Color(1.0, 0.85, 0.7).lerp(Color(0.55, 0.65, 1.0), k)
	_env.fog_light_color = _day_fog.lerp(Color(0.05, 0.06, 0.16), k)


func _exit_tree() -> void:
	# Take the tunnel reverb off the shared effects bus (D-127).
	var bus := AudioServer.get_bus_index("SFX")
	if _reverb != null and bus >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, i) == _reverb:
				AudioServer.remove_bus_effect(bus, i)
	super._exit_tree()


## Debug builds only (DebugTools, D-057): F freezes / unfreezes the race clock
## (D-118). Shown on the HUD so it isn't left on by accident.
func _on_debug_action(action: StringName) -> void:
	if action == &"spawn_police":
		# Debug O (D-138): a police car comes from behind right away.
		if sim != null and _phase == "race" and sim.state == Sim.State.RACE and sim.police.is_empty():
			sim.police = {"s": sim.s - Sim.POLICE_BEHIND, "x": sim.x, "v": sim.v, "state": "chase", "t": 0.0}
			_center_message(tr("RC_POLICE"), 1.4)
			_cops_flash = true   # red/blue flashing text (D-158)
			Dmd.flash(tr("RC_POLICE"), 1.4, Dmd.RED)
		return
	if action == &"skip_stage":
		_debug_skip_to_night()
		return
	if action != &"fire_line":
		return
	_freeze_time = not _freeze_time
	if sim != null:
		sim.freeze_time = _freeze_time
	if is_instance_valid(_frozen_label):
		_frozen_label.modulate.a = 1.0 if _freeze_time else 0.0


## Debug S (D-121): jump to stage 5 (night falls) without driving there.
func _debug_skip_to_night() -> void:
	if sim == null or _phase != "race" or sim.checkpoints >= Night.NIGHT_STAGE - 1:
		return
	sim.checkpoints = Night.NIGHT_STAGE - 1
	sim.next_checkpoint = sim.s + Sim.CHECKPOINT_EVERY
	sim.time_left = maxf(sim.time_left, 60.0)
	Dmd.flash(tr("RC_STAGE") % (sim.checkpoints + 1), 1.0, Dmd.CYAN)


## Plays one of the DMD event animations (D-115) with its translated texts.
func _dmd_anim(name: String, args: Array) -> void:
	Dmd.play(Callable(_anims, name).bindv(args), DmdAnims.DURATIONS[name])


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
	# Engine (D-116): three layers mixed by rpm and speed, 16/32-bit style rather
	# than realistic. Each loop holds a whole number of cycles (0.4 s).
	# Body: a firing-pulse train (80 Hz) with uneven cylinders and a sub tone.
	_engine = AudioStreamPlayer.new()
	_engine.bus = "SFX"
	_engine.stream = _loop_wav(func(t: float) -> float:
		var fire := t * 80.0
		var ph := fmod(fire, 1.0)
		var amp: float = [1.0, 0.82, 0.94, 0.78][int(fire) % 4]
		var pulse := exp(-ph * 5.0) * (sin(TAU * ph * 2.0) * 0.7 + sin(TAU * ph * 5.0) * 0.25)
		return pulse * amp * 0.75 + sin(TAU * 40.0 * t) * 0.22, 0.4, 0.04)
	_engine.volume_db = -8.0
	add_child(_engine)
	# Whine: soft harmonics of 160 Hz, rising with the revs.
	_engine_hi = AudioStreamPlayer.new()
	_engine_hi.bus = "SFX"
	_engine_hi.stream = _loop_wav(func(t: float) -> float:
		var v := 0.0
		for n in range(1, 7):
			v += sin(TAU * 160.0 * n * t) / n * (1.0 if n % 2 == 1 else -0.6)
		return v * 0.32, 0.4, 0.0)
	_engine_hi.volume_db = -60.0
	add_child(_engine_hi)
	# Wind: filtered noise that grows with speed.
	_wind = AudioStreamPlayer.new()
	_wind.bus = "SFX"
	_wind.stream = _loop_wav(func(_t: float) -> float: return 0.0, 1.0, 0.7)
	_wind.volume_db = -60.0
	add_child(_wind)
	_engine_hi.play()
	_wind.play()
	# Passing traffic (D-134): a buzzy engine loop per nearby vehicle.
	var buzz := _loop_wav(func(t: float) -> float:
		var ph := fmod(t * 110.0, 1.0)
		return (ph * 2.0 - 1.0) * 0.35 + sin(TAU * 220.0 * t) * 0.2 + sin(TAU * 55.0 * t) * 0.25, 0.4, 0.06)
	for i in PASSERS:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		pl.stream = buzz
		pl.volume_db = -80.0
		add_child(pl)
		pl.play()
		_passers.append(pl)
	_skid = AudioStreamPlayer.new()
	_skid.bus = "SFX"
	_skid.stream = _loop_wav(func(t: float) -> float:
		return sin(TAU * 950.0 * t + sin(TAU * 25.0 * t) * 2.0) * 0.25, 0.4, 0.5)
	_skid.volume_db = -80.0
	add_child(_skid)
	_engine.play()
	_skid.play()


## Doppler engine noise from the nearest traffic (D-134). Pitch follows the
## closing speed (an exaggerated "speed of sound" so it's clearly arcade), the
## volume falls off with distance; trucks rumble lower.
func _update_passers() -> void:
	var near: Array = []
	if sim != null and sim.state != Sim.State.COUNTDOWN:
		for t in sim.traffic:
			var ds: float = t.s - sim.s
			var d := Vector2(ds, t.x - sim.x).length()
			if d < PASS_RANGE:
				near.append([d, t])
		near.sort_custom(func(a, b): return a[0] < b[0])
	for i in _passers.size():
		var pl: AudioStreamPlayer = _passers[i]
		if i >= near.size():
			pl.volume_db = lerpf(pl.volume_db, -80.0, 0.2)
			continue
		var d: float = near[i][0]
		var t: Dictionary = near[i][1]
		var ds: float = t.s - sim.s
		# Closing speed: positive while it approaches us, negative once past.
		var closing: float = (sim.v - t.v) * signf(ds if absf(ds) > 0.5 else 1.0)
		var doppler := clampf(SOUND_SPEED / maxf(SOUND_SPEED - closing, 20.0), 0.5, 2.2)
		var base := 0.55 if t.get("kind", "car") == "truck" else 0.85
		pl.pitch_scale = lerpf(pl.pitch_scale, base * doppler, 0.35)
		var target := -6.0 - 30.0 * clampf(d / PASS_RANGE, 0.0, 1.0)
		pl.volume_db = lerpf(pl.volume_db, target, 0.3)


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
	var pitch := 0.55 + rpm * 1.5 + (0.2 if sim.boosting else 0.0)
	if rpm > 0.97 and fmod(_phase_t * 18.0, 1.0) < 0.5:
		pitch -= 0.15   # rev limiter bouncing (D-112)
	var revving := sim.state == Sim.State.COUNTDOWN and sim.throttle > 0.0
	_engine.pitch_scale = pitch
	_engine_hi.pitch_scale = pitch
	_engine.volume_db = -11.0 + sim.throttle * 3.0 - rpm * 3.0 + (3.0 if revving else 0.0)
	_engine_hi.volume_db = -34.0 + rpm * 22.0 + sim.throttle * 2.0 + (2.0 if revving else 0.0)
	_update_passers()
	_wind.volume_db = -46.0 + clampf(sim.v / Sim.MAX_SPEED, 0.0, 1.3) * 28.0
	var squeal := sim.drifting or (sim.state == Sim.State.OVER and sim.v > 3.0) 		or (sim.spin_t > 0.0 and not sim.stalled()) or sim.auto_braking
	_skid.volume_db = lerpf(_skid.volume_db, -10.0 if squeal else -60.0, 0.2)
