## TILT BREAKER (D-037): block breaker for pinball cabinets. This module renders the
## pure simulation (sim.gd) in 3D on the TABLE, shows status on DMD + BACKGLASS, and
## maps cabinet actions (D-007):
##   flippers (hold) = move ship   Launch/Start = fire plasma   magna saves = dash
## Fiction (D-041): the bricks are a sentient, self-replicating nanomachine swarm.
## The player's ship fires a plasma shot; its energy shield deflects the plasma
## back at the swarm. Lives are the ship's energy charges.
extends "res://core/game_module.gd"

const InstParam = preload("res://core/util/inst_param.gd")

const Sim = preload("res://games/breakout/sim.gd")
const Fx = preload("res://games/breakout/fx.gd")
const UI = preload("res://core/ui/ui.gd")
const Synth = preload("res://core/util/synth.gd")
const ScoreTable = preload("res://core/util/score_table.gd")
const BRICK_SHADER = preload("res://games/breakout/shaders/brick_circuit.gdshader")
const SHIELD_SHADER = preload("res://games/breakout/shaders/shield.gdshader")
const EXPLOSION_SHADER = preload("res://games/breakout/shaders/explosion.gdshader")
const BLAST_SHADER = preload("res://games/breakout/shaders/blast.gdshader")
const DmdAnims = preload("res://games/breakout/dmd_anims.gd")
const BackglassLights = preload("res://games/breakout/backglass_lights.gd")
const BACKGLASS_SHADER = preload("res://games/breakout/shaders/backglass_lights.gdshader")
const STARFIELD_SHADER = preload("res://games/breakout/shaders/starfield.gdshader")

const ACCENT := Color("3ec7ff")
const TITLE_FONT := "nano"  # D-062
const PADDLE_MODEL := "res://assets/models/breakout/paddle.glb"
const MODEL_PADDLE_WIDTH := 1.9  # paddle.glb's native length along X
const ENGINE_X := 0.74           # engine nozzles, after scaling to PADDLE_W
## Brick textures (D-045): the director's circuit_<colour>.png, downsampled to
## 512 px (scripts/tools/prepare_circuit_textures.py). Each brick shows its own
## random rectangle. Rows top->bottom (until stage layouts, M2 step 3):
## red, red, yellow, green, blue, blue.
## Brick colour letters in level files (D-068) -> circuit texture colour.
const LETTER_COLOUR := {"R": "red", "Y": "yellow", "G": "green", "B": "blue"}
const CIRCUIT_GLOW := {"red": Color("ff5a32"), "yellow": Color("ffd23e"), "green": Color("4dff6a"), "blue": Color("3ec7ff")}
const CIRCUIT_TEXELS := 512.0
const BRICK_TEXELS_W := 64.0  # texels across one brick (chunky pixel size)
## Attract + intro (D-061): bricks drop in one after another, then the ship
## blasts up from below on its belly afterburner.
const INTRO_BRICK_STAGGER := 0.022  # s between bricks
const INTRO_BRICK_FALL := 0.4       # s each brick takes to drop into place
const INTRO_DROP_HEIGHT := 9.0      # units above the playfield (towards the camera)
const INTRO_SHIP_TIME := 0.8
const INTRO_SHIP_FROM_Z := 10.5     # below the bottom of the screen
const INTRO_SETTLE := 0.35          # pause after the ship arrives
## Game-over finale (D-044): explosion fills the screen, fade to black, then
## GAME OVER + score; Launch/Start may skip once the score is shown.
const FINALE_FADE_AT := 0.9
const FINALE_FADE_TIME := 0.8
const FINALE_TEXT_AT := 1.9
const FINALE_SKIP_AT := 2.6
const FINALE_END_AT := 6.0
## Camera lean towards the player (0 = straight down) (D-040).
const CAMERA_TILT_DEG := 20.0
## Blast charge levels (D-054): particle/sphere/bolt colour and sphere size.
const LEVEL_COLORS := [Color(0.35, 0.65, 1.0), Color(1.0, 0.85, 0.25), Color(1.0, 0.3, 0.2)]
## Power-up colours (D-072); also the DMD power bar colour while active.
const POWERUP_COLORS := {"T": Color(0.3, 0.55, 1.0), "P": Color(1.0, 0.25, 0.2), "B": Color(1.0, 0.85, 0.2),
	"I": Color(0.72, 0.3, 1.0), "L": Color(1.0, 1.0, 1.0), "S": Color(0.3, 1.0, 0.4)}
const MUSIC := "res://assets/audio/music/breakout/n_dimensions.ogg"
const MUSIC_ATTRACT := "res://assets/audio/music/breakout/dead_ship_attract.ogg"  # D-082
const ION_SHADER = preload("res://games/breakout/shaders/ion_beam.gdshader")
const LEVEL_SPHERE_SCALE := [0.5, 0.75, 1.0]
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
## Starfield rotation (D-049): radians/s of spin per unit/s of ship speed, how
## quickly the spin follows the ship, and an idle drift.
const STAR_SPIN_PER_SPEED := 0.006
const STAR_SPIN_RESPONSE := 3.0
const STAR_DRIFT := 0.004

## 16-bit style sound effects (D-050), synthesized by core/util/synth.gd.
const ECHO := [0.085, 0.3, 0.55]
const SOUNDS := {
	"tb_fire": {"voices": [  # serve: laser cannon (D-074) - whine, sweep, thump
		[{"f": [600.0, 1800.0], "t": 0.06, "w": "pulse25", "v": 0.12, "env": "hold"},
		 {"f": [3200.0, 180.0], "t": 0.32, "w": "saw", "v": 0.26, "lp": 0.15}],
		[{"f": [0.0, 0.0], "t": 0.05, "w": "sine", "v": 0.0, "gap": 0.0},
		 {"f": [140.0, 38.0], "t": 0.35, "w": "sine", "v": 0.55}],
		[{"f": [0.0, 0.0], "t": 0.05, "w": "sine", "v": 0.0},
		 {"f": [5000.0, 800.0], "t": 0.15, "w": "lfsr", "v": 0.14, "lp": 0.35}]], "echo": [0.1, 0.35, 0.55]},
	"tb_shield": {"voices": [  # laser hitting an energy shield (D-074)
		[{"f": [4200.0, 1400.0], "t": 0.07, "w": "pulse12", "v": 0.2}],
		[{"f": [6000.0, 2500.0], "t": 0.09, "w": "lfsr", "v": 0.1, "lp": 0.2}],
		[{"f": [2350.0, 2200.0], "t": 0.22, "w": "sine", "v": 0.16, "vib": [55.0, 0.4]}]],
		"echo": [0.05, 0.28, 0.5], "reverb": [0.6, 0.3]},
	"tb_brick": {"voices": [  # crunchy chip break
		[{"f": [5000.0, 700.0], "t": 0.13, "w": "lfsr", "v": 0.2}],
		[{"f": [880.0, 1760.0], "t": 0.05, "w": "square", "v": 0.14}]], "crush": 8},
	"tb_explode": {"voices": [
		[{"f": [1600.0, 70.0], "t": 0.9, "w": "lfsr", "v": 0.4, "lp": 0.55}],
		[{"f": [90.0, 30.0], "t": 0.6, "w": "sine", "v": 0.5}]], "echo": [0.11, 0.3, 0.5], "reverb": [1.0, 0.35]},
	"tb_explode_big": {"voices": [
		[{"f": [2200.0, 40.0], "t": 2.0, "w": "lfsr", "v": 0.45, "lp": 0.6, "env": "lin"}],
		[{"f": [110.0, 25.0], "t": 1.6, "w": "sine", "v": 0.6}],
		[{"f": [600.0, 50.0], "t": 1.2, "w": "noise", "v": 0.2, "lp": 0.8}]], "echo": [0.14, 0.4, 0.6], "reverb": [1.4, 0.35]},
	"tb_dash": {"voices": [[{"f": [400.0, 3000.0], "t": 0.14, "w": "noise", "v": 0.18, "lp": 0.5, "env": "lin"}]]},
	"tb_rack": {"voices": [  # victory jingle
		[{"f": [523.0, 523.0], "t": 0.08, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [659.0, 659.0], "t": 0.08, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [784.0, 784.0], "t": 0.08, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1047.0, 1047.0], "t": 0.08, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1568.0, 1568.0], "t": 0.5, "w": "pulse25", "v": 0.22, "vib": [7.0, 0.3]}],
		[{"f": [131.0, 131.0], "t": 0.32, "w": "triangle", "v": 0.35, "env": "hold"},
		 {"f": [196.0, 196.0], "t": 0.5, "w": "triangle", "v": 0.35}]], "echo": ECHO},
	# Charge-up per level (D-054): a rising sweep while charging towards level n...
	"tb_charge1": {"voices": [
		[{"f": [140.0, 330.0], "t": 0.8, "w": "pulse25", "v": 0.12, "vib": [12.0, 0.4], "env": "hold", "a": 0.05}],
		[{"f": [70.0, 165.0], "t": 0.8, "w": "triangle", "v": 0.25, "env": "hold", "a": 0.05}]]},
	"tb_charge2": {"voices": [
		[{"f": [220.0, 520.0], "t": 0.8, "w": "pulse25", "v": 0.12, "vib": [15.0, 0.5], "env": "hold", "a": 0.05}],
		[{"f": [110.0, 260.0], "t": 0.8, "w": "triangle", "v": 0.25, "env": "hold", "a": 0.05}]]},
	"tb_charge3": {"voices": [
		[{"f": [330.0, 780.0], "t": 0.8, "w": "pulse25", "v": 0.13, "vib": [18.0, 0.6], "env": "hold", "a": 0.05}],
		[{"f": [165.0, 390.0], "t": 0.8, "w": "triangle", "v": 0.26, "env": "hold", "a": 0.05}]]},
	# ...and a warm hum (not a beep) when level n is reached, deeper-to-higher.
	"tb_level1": {"voices": [
		[{"f": [110.0, 110.0], "t": 0.6, "w": "sine", "v": 0.45, "vib": [5.0, 0.15], "a": 0.08}],
		[{"f": [220.0, 220.0], "t": 0.6, "w": "triangle", "v": 0.18, "vib": [5.0, 0.15], "a": 0.12, "lp": 0.5}]],
		"echo": [0.1, 0.3, 0.5]},
	"tb_level2": {"voices": [
		[{"f": [147.0, 147.0], "t": 0.6, "w": "sine", "v": 0.45, "vib": [6.0, 0.18], "a": 0.08}],
		[{"f": [294.0, 294.0], "t": 0.6, "w": "triangle", "v": 0.18, "vib": [6.0, 0.18], "a": 0.12, "lp": 0.5}]],
		"echo": [0.1, 0.3, 0.5]},
	"tb_level3": {"voices": [
		[{"f": [196.0, 196.0], "t": 0.7, "w": "sine", "v": 0.48, "vib": [7.0, 0.22], "a": 0.08}],
		[{"f": [392.0, 392.0], "t": 0.7, "w": "triangle", "v": 0.2, "vib": [7.0, 0.22], "a": 0.12, "lp": 0.5}],
		[{"f": [98.0, 98.0], "t": 0.7, "w": "pulse25", "v": 0.06, "a": 0.15, "lp": 0.7}]],
		"echo": [0.1, 0.35, 0.55]},
	"tb_blast1": {"voices": [  # energy blast, level 1..3 (bigger each level)
		[{"f": [1600.0, 220.0], "t": 0.3, "w": "saw", "v": 0.22, "lp": 0.25}],
		[{"f": [120.0, 70.0], "t": 0.25, "w": "sine", "v": 0.35}]], "echo": ECHO},
	"tb_blast2": {"voices": [
		[{"f": [1800.0, 160.0], "t": 0.4, "w": "saw", "v": 0.25, "lp": 0.2}],
		[{"f": [3200.0, 400.0], "t": 0.25, "w": "lfsr", "v": 0.15, "lp": 0.3}],
		[{"f": [110.0, 55.0], "t": 0.35, "w": "sine", "v": 0.42}]], "echo": ECHO},
	"tb_blast3": {"voices": [
		[{"f": [2000.0, 90.0], "t": 0.6, "w": "saw", "v": 0.28, "lp": 0.15}],
		[{"f": [4000.0, 300.0], "t": 0.4, "w": "lfsr", "v": 0.2, "lp": 0.25}],
		[{"f": [100.0, 35.0], "t": 0.55, "w": "sine", "v": 0.5}]], "echo": [0.12, 0.4, 0.6]},
	"tb_wormhole": {"voices": [  # warping teleport whoosh
		[{"f": [180.0, 1300.0], "t": 1.1, "w": "sine", "v": 0.3, "vib": [9.0, 2.0], "env": "hold", "a": 0.25}],
		[{"f": [90.0, 650.0], "t": 1.1, "w": "pulse25", "v": 0.07, "vib": [13.0, 1.0], "env": "hold", "a": 0.35}]],
		"echo": ECHO},
	"tb_enemy_die": {"voices": [
		[{"f": [3500.0, 150.0], "t": 0.45, "w": "lfsr", "v": 0.3, "lp": 0.2}],
		[{"f": [1200.0, 1200.0], "t": 0.3, "w": "square", "v": 0.12, "arp": [0, -5, -12, -17], "arp_rate": 24.0}]],
		"echo": ECHO, "reverb": [0.9, 0.35], "crush": 9},
	"tb_ship_die": {"voices": [
		[{"f": [1800.0, 50.0], "t": 1.2, "w": "lfsr", "v": 0.45, "lp": 0.5}],
		[{"f": [140.0, 30.0], "t": 1.0, "w": "sine", "v": 0.55}],
		[{"f": [880.0, 110.0], "t": 0.6, "w": "saw", "v": 0.15, "vib": [20.0, 1.0]}]], "echo": [0.12, 0.35, 0.6], "reverb": [1.4, 0.35]},
	"tb_brick_land": {"voices": [[{"f": [1500.0, 700.0], "t": 0.035, "w": "pulse12", "v": 0.1}]]},
	"tb_ship_arrive": {"voices": [  # belly afterburner roar
		[{"f": [180.0, 1800.0], "t": 0.7, "w": "noise", "v": 0.22, "lp": 0.45, "env": "lin"}],
		[{"f": [55.0, 110.0], "t": 0.7, "w": "saw", "v": 0.18, "lp": 0.4, "env": "lin"}]],
		"echo": ECHO},
	"tb_pu_drop": {"voices": [[{"f": [1600.0, 2400.0], "t": 0.18, "w": "triangle", "v": 0.25, "arp": [0, 7, 12], "arp_rate": 30.0}]],
		"echo": ECHO},
	"tb_pu_get": {"voices": [
		[{"f": [523.0, 523.0], "t": 0.06, "w": "pulse25", "v": 0.22, "env": "hold"},
		 {"f": [784.0, 784.0], "t": 0.06, "w": "pulse25", "v": 0.22, "env": "hold"},
		 {"f": [1047.0, 1047.0], "t": 0.06, "w": "pulse25", "v": 0.22, "env": "hold"},
		 {"f": [1568.0, 1568.0], "t": 0.35, "w": "pulse25", "v": 0.24, "vib": [8.0, 0.3]}],
		[{"f": [262.0, 262.0], "t": 0.53, "w": "triangle", "v": 0.3}]], "echo": ECHO},
	"tb_ion": {"voices": [
		[{"f": [90.0, 60.0], "t": 0.7, "w": "saw", "v": 0.3, "lp": 0.3, "vib": [30.0, 0.8]}],
		[{"f": [2400.0, 600.0], "t": 0.5, "w": "lfsr", "v": 0.18, "lp": 0.2}],
		[{"f": [1200.0, 1200.0], "t": 0.5, "w": "sine", "v": 0.15, "vib": [45.0, 2.0]}]], "echo": [0.1, 0.35, 0.55]},
	"tb_shield_break": {"voices": [
		[{"f": [700.0, 200.0], "t": 0.35, "w": "triangle", "v": 0.35, "vib": [25.0, 1.0]}],
		[{"f": [4000.0, 900.0], "t": 0.25, "w": "noise", "v": 0.15, "lp": 0.3}]], "echo": ECHO},
	"tb_armour": {"voices": [[{"f": [2200.0, 1400.0], "t": 0.06, "w": "square", "v": 0.16},
		{"f": [900.0, 900.0], "t": 0.05, "w": "lfsr", "v": 0.1}]], "crush": 8},
	"tb_low_power": {"voices": [[{"f": [220.0, 220.0], "t": 0.08, "w": "pulse25", "v": 0.2, "env": "hold", "gap": 0.04},
		{"f": [165.0, 165.0], "t": 0.16, "w": "pulse25", "v": 0.2}]]},
}

var _portrait_req := false   # D-255
var sim: Sim
var _root: Node3D
var _cam: Camera3D
var _planet: Fx.Planet
var _paddle: Node3D       # follows the sim position
var _ship: Node3D         # child of _paddle; banks visually
var _engines: Array = []  # [left, right] Fx.ShipEngine
var _shield_mat: ShaderMaterial
var _shield_age := 99.0
var _edge_shields := {}  # "l"/"r"/"t" -> {mat: ShaderMaterial, age: float}
var _star_mat: ShaderMaterial
var _star_angle := 0.0
var _star_spin := 0.0
var _ball: Node3D
var _halo: MeshInstance3D
var _trail: Fx.Trail
var _brick_nodes: Array[MeshInstance3D] = []
var _brick_mats := {}  # colour -> ShaderMaterial
var _hint: Label
var _blast_nodes: Array[Node3D] = []
var _enemy_nodes := {}  # enemy id -> {root, body, spin: Vector3, hole, colour: Color}
var _circuit_textures: Array = []
var _dmd_anims := DmdAnims.new()
var _lights := BackglassLights.new()
var _backglass_mat: ShaderMaterial
var _charge_glow: Node3D
var _charge_particles: CPUParticles3D
var _charge_level_shown := 0
var _charge_sound: AudioStreamPlayer  # the rising charge sfx (cut on release)
var _charge_sound_name := ""
var _launch := false
var _dash := 0
var _dash_glow := 0.0
var _fire_flash := 0.0
var _recoil := 0.0
var _finale_t := -1.0
var _finale_black: ColorRect
var _finale_text: Control
var _shown_score := -1
## "attract" -> (Start) -> "intro" -> "play" (D-061)
var _phase := "attract"
var _phase_t := 0.0
var _belly_engines: Array = []  # two belly afterburners at the nozzles (D-072)
var _powerup_nodes := {}  # capsule id -> Fx.PowerupCapsule
var _extra_ball_nodes: Array = []  # [ball Node3D, Fx.Trail]
var _ghost_nodes: Array[Node3D] = []
var _shield_node: MeshInstance3D
var _shield_bar_mat: ShaderMaterial
var _shield_flash := 99.0
var _low_power_t := 0.0
var _debug_pu := 0
var _recharge_mat: StandardMaterial3D
var _recharge_flash := 0.0
var _outro_x0 := 0.0  # ship x when the level ended (it glides to the centre)
var _last_power_step := -1  # bar levels reached, to detect recharges (D-084)
var _attract_ui: Control
var _attract_blink: Label
var _ready_label: Label
var _attract_steps: Array = []  # [Callable, seconds]
var _attract_step := -1
var _attract_left := 0.0
var _landed := 0


func get_info() -> Dictionary:
	return {"id": "breakout", "title_key": "GAME_BREAKOUT_TITLE", "color": ACCENT, "font": TITLE_FONT,
		"logo": "res://assets/textures/breakout/logo.png",
		"dmd_logo": "res://assets/textures/breakout/dmd_logo.png", "buttons_min": 3,
		"backglass": "res://assets/textures/breakout/backglass_on_2screen.png"}  # shell screens (D-088, D-108)


func start(_players: int) -> void:
	# D-262: on a single screen the game area takes the space under the DMD;
	# the orthographic camera keeps the playfield's height, so a wide screen
	# shows more space at the sides.
	_portrait_req = true
	Screens.want_dmd_above(true)
	for s in SOUNDS:
		Audio.register_sfx(s, Synth.make(SOUNDS[s]))
	sim = Sim.new()
	sim.setup(int(Config.get_value("operator", "balls_per_game")), _start_difficulty())
	if Config.cli.has("tb-level"):  # dev: start at level N
		sim.level = maxi(1, int(str(Config.cli["tb-level"])))
		sim.build_rack()
	if Config.cli.has("tb-enemy-now"):  # dev: first enemy right after firing
		sim._enemy_timer = 0.3
	_build_world()
	_build_bricks()
	_build_hud()
	_build_backglass()
	DebugTools.debug_action.connect(_on_debug_action)
	if Config.cli.has("tb-skip-intro"):  # dev: straight into play
		Audio.play_music(MUSIC)
		_enter_play()
	else:
		_enter_attract()


func on_action(action: StringName, pressed: bool) -> void:
	if not pressed:
		return
	if _phase == "attract":
		if action == &"start" or action == &"launch":
			_enter_select()
		return
	if _phase == "select":
		match action:
			&"flip_l", &"magna_l":
				_move_select(-1)
			&"flip_r", &"magna_r":
				_move_select(1)
			&"launch", &"start":
				_confirm_select()
		return
	if _phase == "intro":
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
	_phase_t += delta
	if _phase == "attract":
		_attract(delta)
		_animate(delta)
		return
	if _phase == "select":
		_animate(delta)
		if _phase_t > SELECT_IDLE_SECONDS:   # walked away: back to attract
			_select_ui.queue_free()
			_enter_attract()
		return
	if _phase == "intro":
		_animate(delta)
		_intro()
		return
	if _phase == "outro":
		_animate(delta)
		_outro()
		return
	if _finale_t >= 0.0:
		_finale(delta)
		_animate(delta)
		return
	if Config.cli.has("tb-dmd-anim") and not Dmd.is_animating():  # dev: loop one DMD animation
		_dmd_anim(str(Config.cli["tb-dmd-anim"]))
	sim.paddle_axis = CabinetInput.steer_axis()   # D-252
	sim.step(minf(delta, 0.05), CabinetInput.is_down(&"flip_l"), CabinetInput.is_down(&"flip_r"), _launch, _dash)
	_launch = false
	_dash = 0
	_handle_events()
	_animate(delta)


# --- events ------------------------------------------------------------------------
func _handle_events() -> void:
	for e in sim.events:
		if e[0] != "paddle" and e[0] != "wall":
			DebugTools.mark(str(e[0]))
		match e[0]:
			"paddle":
				Audio.sfx("tb_shield")
				_lights.pulse(BackglassLights.SHOTS, 0.3, 16.0, 0.7)
				_shield_age = 0.0
				_shield_mat.set_shader_parameter("hit_x",
					clampf((sim.ball_pos.x - sim.paddle_x) / (Sim.PADDLE_W * 0.5), -1.0, 1.0))
			"wall":
				Audio.sfx("tb_shield")
				_flash_edge_shield(e[1][0], e[1][1])
			"brick":
				var n := _brick_nodes[e[1]]
				n.visible = false
				_explode_brick(n.position, _brick_glow(sim.bricks[e[1]]))
				_lights.pulse(BackglassLights.IMPACTS, 0.35, 14.0)
				Audio.sfx("tb_brick")
			"serve":
				Audio.sfx("tb_fire")
				_lights.pulse(BackglassLights.SHOTS, 0.7, 12.0)
				_fire_flash = 1.0
				_recoil = 1.0
				_trail.clear()
				_hint.visible = false
			"dash":
				Audio.sfx("tb_dash")
				_dash_glow = 1.0
			"charge_start":
				_stop_charge_sound()
				_charge_sound_name = "tb_charge%d" % int(e[1])
				_charge_sound = Audio.sfx(_charge_sound_name)
			"charged":
				Audio.sfx("tb_level%d" % int(e[1]))
			"blast":
				_stop_charge_sound()
				var blevel: int = e[1][1]
				var bdir: Vector2 = e[1][2] if e[1].size() > 2 else Vector2.UP
				if bdir == Vector2.UP:  # one sound/recoil per volley (Triple = 3 events)
					Audio.sfx("tb_blast%d" % blevel)
					_recoil = 0.5 + 0.25 * blevel
				_spawn_blast_node(blevel, bdir)
				_lights.pulse(BackglassLights.SHOTS + BackglassLights.IMPACTS, 0.5 + 0.2 * blevel, 10.0)
			"blast_fail":
				Audio.sfx("tb_low_power")
				_low_power_t = 1.2  # LOW shows only in the DMD power bar area (D-072)
			"brick_hit":
				var hb: Dictionary = sim.bricks[e[1]]
				InstParam.set_param(_brick_nodes[e[1]], "mode", 2.0)
				Audio.sfx("tb_armour")
				_explode_brick(_brick_nodes[e[1]].position, _brick_glow(hb), 0.5)
			"powerup_spawn":
				_spawn_powerup_node(e[1][0], e[1][1], e[1][2])
				Audio.sfx("tb_pu_drop")
			"powerup_collect":
				_remove_powerup_node(e[1][0])
				var kind: String = e[1][1]
				Audio.sfx("tb_pu_get")
				Dmd.flash(tr("TB_PU_%s" % kind), 1.4, POWERUP_COLORS[kind])
				_lights.pulse(BackglassLights.ALL, 0.8, 10.0)
				_recoil = 0.4
			"powerup_lost":
				_remove_powerup_node(e[1])
			"ion_beam":
				_fire_ion_beam(e[1])
			"bounce_ball":
				Audio.sfx("tb_fire")
				_recoil = 0.7
			"ghost":
				Audio.sfx("tb_shield")
			"shield_used":
				Audio.sfx("tb_shield_break")
				_shield_flash = 0.0
				_shield_bar_mat.set_shader_parameter("hit_x", clampf(e[1] / (Sim.FIELD.size.x * 0.5), -1.0, 1.0))
				_lights.pulse(BackglassLights.ENGINES + BackglassLights.SHOTS, 0.6, 12.0)
			"extra_lost":
				Audio.sfx("tb_explode")
				_planet.impact(Vector3(e[1], 0.0, Sim.DRAIN_Y), -_cam.global_transform.basis.z)
			"blast_end":
				var end_pos: Vector2 = e[1][0]
				var end_level: int = e[1][2]
				_explode_brick(Vector3(end_pos.x, 0.0, end_pos.y), LEVEL_COLORS[end_level - 1], 0.8 + 0.3 * end_level)
			"enemy_spawn":
				_spawn_enemy_node(e[1][0], e[1][1])
				Audio.sfx("tb_wormhole")
				_dmd_anim("incoming")
			"enemy_ready":
				_close_wormhole(e[1])
			"enemy_destroyed":
				var ecol: Color = _enemy_nodes[e[1][0]].colour if _enemy_nodes.has(e[1][0]) else Color(0.75, 0.4, 1.0)
				_remove_enemy_node(e[1][0])
				var ep: Vector2 = e[1][1]
				_explode_brick(Vector3(ep.x, 0.2, ep.y), ecol, 1.2)
				Audio.sfx("tb_enemy_die")
				_lights.pulse(BackglassLights.IMPACTS + BackglassLights.SHOTS, 0.8, 10.0)
				if e[1][2]:  # shot down (not a ship collision)
					_dmd_anims.enemy_color = ecol
					_dmd_anim("tetra_hit")
			"ship_destroyed":
				var sp: Vector2 = e[1]
				Audio.sfx("tb_ship_die")
				_lights.pulse(BackglassLights.ALL, 1.3, 8.0)
				_explode_brick(Vector3(sp.x, 0.2, sp.y), Color(0.4, 0.8, 1.0), 2.6)
				_trail.clear()
				if sim.state == Sim.State.OVER:
					_planet._spawn_fireball(Vector3(sp.x, 0.5, sp.y), 18.0, 1.1, 99.0)
				else:
					_dmd_anim("ship_destroyed")
					_hint.visible = true
			"rack_clear":
				Audio.sfx("tb_rack")
				_lights.chase(1.8)
				_dmd_anim("rack_clear")
				_trail.clear()
				_begin_outro()
			"lost":
				var last := sim.state == Sim.State.OVER
				Audio.sfx("tb_explode_big" if last else "tb_explode")
				_lights.pulse(BackglassLights.ALL, 1.2, 8.0)
				_planet.impact(Vector3(e[1], 0.0, Sim.DRAIN_Y), -_cam.global_transform.basis.z, last)
				_trail.clear()
				if sim.state != Sim.State.OVER:
					_dmd_anim("charge_lost")
					_hint.visible = true
				_refresh_status()
			"over":
				_finale_t = 0.0
				_hint.visible = false
	if sim.score != _shown_score:
		_refresh_status()


## Score, lives (plasma dots) and blast power are shown only on the DMD (D-051).
func _refresh_status() -> void:
	if _shown_score != sim.score:
		_shown_score = sim.score
		score_changed.emit(0, sim.score)
	if _finale_t >= 0.0 or _phase != "play":
		return  # the finale / attract / intro own the DMD
	var pu: String = sim.powerup
	var pcol: Color = POWERUP_COLORS.get(pu, Dmd.YELLOW)
	Dmd.show_status(sim.score, sim.balls_left, sim.balls_total,
		sim.power, 3, ACCENT, pcol, sim.level, pu, pcol, sim.blasts_enabled(), _low_power_t > 0.0)


# --- game-over finale (D-044) -----------------------------------------------------------
func _finale(delta: float) -> void:
	var before := _finale_t
	_finale_t += delta
	if before < FINALE_FADE_AT and _finale_t >= FINALE_FADE_AT:
		_finale_black = UI.fill(Color(0, 0, 0, 0))
		add_to_table(_finale_black)
		var tw := _finale_black.create_tween()
		tw.tween_property(_finale_black, "color:a", 1.0, FINALE_FADE_TIME)
	if before < FINALE_FADE_AT and _finale_t >= FINALE_FADE_AT:
		_lights.pulse(BackglassLights.ALL, FINALE_TEXT_AT - FINALE_FADE_AT, 6.0)
	if before < FINALE_TEXT_AT and _finale_t >= FINALE_TEXT_AT:
		_lights.set_dark(true)
		var col := UI.vstack(40)
		col.add_child(UI.styled_label(tr("DMD_GAME_OVER"), TITLE_FONT, 3))
		col.add_child(UI.spacer(40))
		col.add_child(UI.styled_label(tr("TB_FINAL_SCORE"), TITLE_FONT, 2))
		col.add_child(UI.styled_label(ScoreTable.format_score(sim.score), TITLE_FONT, 2))
		col.modulate.a = 0.0
		add_to_table(col)
		col.create_tween().tween_property(col, "modulate:a", 1.0, 0.5)
		_finale_text = col
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
	_refresh_status()  # DMD power bar changes continuously
	_update_backglass_lights(delta)
	# "PLASMA CANNON READY" blinks while waiting to fire (D-059).
	if _hint != null and _phase != "play":
		_hint.visible = false
	if _hint != null and _hint.visible:
		_hint.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5 else 0.0
	_animate_blasts(delta)
	_animate_enemies(delta)
	_animate_powerups(delta)
	_animate_recharge_flash(delta)
	# Ship respawn: hidden briefly after being destroyed, then blinks while invulnerable.
	if _phase == "attract" or _phase == "select":
		_paddle.visible = false
	elif _phase == "intro":
		pass  # positioned and shown by _intro()
	elif sim.ship_invulnerable > 0.0:
		var since := Sim.SHIP_INVULNERABLE - sim.ship_invulnerable
		_paddle.visible = since > 0.6 and fmod(Time.get_ticks_msec() / 1000.0, 0.2) < 0.13
	else:
		_paddle.visible = true
	# Edge shields (dev: --tb-show-shields keeps them lit mid-ripple for checks)
	for side in _edge_shields:
		var sh: Dictionary = _edge_shields[side]
		if Config.cli.has("tb-show-shields"):
			sh.age = 0.12
		if sh.age < 5.0:
			sh.age += delta
			sh.mat.set_shader_parameter("age", sh.age)
			sh.mat.set_shader_parameter("strength", clampf(1.0 - sh.age / SHIELD_FADE, 0.0, 1.0))
	# Starfield swings with the ship's movement (D-049)
	var target_spin := -sim.paddle_vx * STAR_SPIN_PER_SPEED
	_star_spin = lerpf(_star_spin, target_spin, 1.0 - exp(-STAR_SPIN_RESPONSE * delta))
	_star_angle += (_star_spin + STAR_DRIFT) * delta
	_star_mat.set_shader_parameter("angle", _star_angle)
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
	# Space background = a pixel starfield drawn on canvas layer -1 (D-049).
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.background_canvas_max_layer = -1
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
	# No camera DOF: it also blurred the starfield background. The planet's
	# out-of-focus look is done in its own shader instead (D-049).
	_root.add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true
	_cam = cam

	# No floor: the ship flies in orbit above an earth-like planet (D-043).
	_planet = Fx.Planet.new(PLANET_RADIUS)
	_root.add_child(_planet)
	_planet.place(cam.global_transform.basis, target, -cam.size * 0.5 + PLANET_RIM_ABOVE_BOTTOM, PLANET_DEPTH_BEHIND)

	# No visible barriers (D-049): invisible boundaries flash an energy shield
	# where the plasma rebounds.
	_build_edge_shields()
	_build_starfield()

	var fallback_mat := StandardMaterial3D.new()
	fallback_mat.albedo_color = Color(0.6, 0.7, 0.8)
	_build_ship(fallback_mat)

	# Plasma shot + trail
	_ball = Fx.make_plasma_ball(Sim.BALL_R)
	_halo = _ball.get_child(1) as MeshInstance3D
	_root.add_child(_ball)
	_trail = Fx.Trail.new()
	_trail.width = Sim.BALL_R * 1.1
	_root.add_child(_trail)
	_animate(0.0)


func _build_starfield() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1  # <= background_canvas_max_layer: drawn as the 3D background
	add_to_table(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_star_mat = ShaderMaterial.new()
	_star_mat.shader = STARFIELD_SHADER
	rect.material = _star_mat
	layer.add_child(rect)


## Shield strips along the invisible boundaries, same effect as the ship's shield.
func _build_edge_shields() -> void:
	var f := Sim.FIELD
	var side_len := Sim.DRAIN_Y - f.position.y
	var side_cz := f.position.y + side_len * 0.5
	# side: [length, position, rotation_y_degrees]
	var specs := {
		"l": [side_len, Vector3(f.position.x, 0.08, side_cz), 90.0],
		"r": [side_len, Vector3(f.end.x, 0.08, side_cz), -90.0],
		"t": [f.size.x, Vector3(f.get_center().x, 0.08, f.position.y), 0.0],
	}
	for side in specs:
		var spec: Array = specs[side]
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(spec[0], 0.6)
		m.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = SHIELD_SHADER
		mat.set_shader_parameter("strength", 0.0)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = spec[1]
		m.rotation_degrees = Vector3(0.0, spec[2], 0.0)
		_root.add_child(m)
		_edge_shields[side] = {"mat": mat, "age": 99.0, "center": spec[1], "half": spec[0] * 0.5}


func _flash_edge_shield(side: String, hit: Vector2) -> void:
	var sh: Dictionary = _edge_shields[side]
	var c: Vector3 = sh.center
	var t := 0.0
	match side:
		"l":
			t = -(hit.y - c.z) / sh.half   # rotated +90: local +X runs towards -Z
		"r":
			t = (hit.y - c.z) / sh.half    # rotated -90: local +X runs towards +Z
		"t":
			t = (hit.x - c.x) / sh.half
	sh.mat.set_shader_parameter("hit_x", clampf(t, -1.0, 1.0))
	sh.age = 0.0


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
		# Show the front face (cockpit window at the top) to the camera, cockpit
		# towards the top of the screen, as in the director's reference (D-071).
		model.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_ship.add_child(model)
		# Recharge flash (D-084): a yellow additive overlay on every ship mesh.
		_recharge_mat = StandardMaterial3D.new()
		_recharge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_recharge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_recharge_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_recharge_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.0)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _recharge_mat
	else:
		_ship.add_child(_box(Vector3(Sim.PADDLE_W, 0.3, Sim.PADDLE_H), Vector3.ZERO, fallback_mat))
	# Side engines (left fires outward to -X, right to +X).
	for side in [-1.0, 1.0]:
		var eng := Fx.ShipEngine.new(Vector3(side, 0.0, 0.0))
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
	# Belly afterburner (D-061): fires downwards for the ship's entrance.
	# Two belly nozzles (left/right of centre on the ship's lower edge, D-072).
	for bx in [-0.3, 0.27]:
		var be := Fx.ShipEngine.new(Vector3(0.0, 0.0, 1.0))
		be.position = Vector3(bx, -0.05, Sim.PADDLE_H * 0.5)
		_ship.add_child(be)
		_belly_engines.append(be)
	# Blast charge (D-053): particles gather at a point in front of the nose while
	# charging; once charged, the plasma ball appears there until release.
	var charge_point := Vector3(0.0, 0.1, -Sim.PADDLE_H * 0.5 - 0.3)
	_charge_particles = Fx.make_charge_particles(0.9, Color(0.45, 0.8, 1.0))
	_charge_particles.position = charge_point
	_ship.add_child(_charge_particles)
	_charge_glow = Fx.make_plasma_ball(Sim.BALL_R * 1.4)
	_charge_glow.position = charge_point
	_charge_glow.visible = false
	_ship.add_child(_charge_glow)
	# A soft blue key light so the white hull reads under the darker scene.
	var key := OmniLight3D.new()
	key.light_color = Color(0.7, 0.85, 1.0)
	key.omni_range = 2.5
	key.light_energy = 1.2
	key.position = Vector3(0.0, 1.2, 0.4)
	_paddle.add_child(key)


func _brick_glow(b: Dictionary) -> Color:
	if b.get("metal", false):
		return Color(0.6, 0.65, 0.7)
	return CIRCUIT_GLOW[LETTER_COLOUR.get(b.get("colour", "B"), "blue")]


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
	for n in _brick_nodes:
		n.queue_free()
	_brick_nodes.clear()
	for i in sim.bricks.size():
		var b: Dictionary = sim.bricks[i]
		var r: Rect2 = b.rect
		var col: int = b.get("col", i % Sim.BRICK_COLS)
		var size := Vector3(r.size.x, 0.3, r.size.y)
		var colour: String = LETTER_COLOUR.get(b.get("colour", "B"), "blue")  # X uses blue art, shown as metal
		var n := _box(size, Vector3(r.get_center().x, 0, r.get_center().y), _brick_material(colour, size))
		_randomize_crop(n)
		# Pulse ripples diagonally across the swarm, with a little jitter.
		InstParam.set_param(n, "phase", -(col * 0.55 + b.row * 0.8) + float((i * 37) % 11) * 0.08)
		InstParam.set_param(n, "mode", 3.0 if b.get("metal", false) else (1.0 if b.get("armoured", false) else 0.0))
		_root.add_child(n)
		_brick_nodes.append(n)


## Each brick shows a rectangle cut from a random, texel-snapped spot (D-045).
func _randomize_crop(n: MeshInstance3D) -> void:
	InstParam.set_param(n, "crop_offset",
		Vector2(randi() % int(CIRCUIT_TEXELS), randi() % int(CIRCUIT_TEXELS)) / CIRCUIT_TEXELS)


## Explosion (D-083, D-087): a smooth fireball billboard in the brick's colour plus
## tumbling brick-coloured debris shards.
## Shader warm-up (D-178): one of each effect that is otherwise built only
## when it happens, so its shaders compile behind the loading bar. The shell
## frees the returned nodes when the warm-up ends.
func warmup_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var c := Vector3(0.0, 0.3, (Sim.FIELD.position.y + Sim.PADDLE_Y) * 0.5)
	_explode_brick(c, Color(1.0, 0.5, 0.2))   # blast + debris; frees itself
	var cap := Fx.PowerupCapsule.new("T", POWERUP_COLORS["T"], Sim.POWERUP_R)
	cap.position = c + Vector3(-2.0, 0.0, 0.0)
	out.append(cap)
	var tet := Fx.make_tetrahedron(Sim.ENEMY_R * 1.5,
		load("res://assets/textures/breakout/circuit_red.png"), CIRCUIT_GLOW["red"])
	tet.position = c + Vector3(2.0, 0.0, 0.0)
	out.append(tet)
	var hole := Fx.make_wormhole(1.7)
	hole.position = c + Vector3(2.0, -0.05, 0.0)
	out.append(hole)
	var ball := Fx.make_plasma_ball(Sim.BALL_R)
	Fx.tint_plasma(ball, POWERUP_COLORS["B"])
	ball.position = c + Vector3(0.0, 0.0, 1.0)
	out.append(ball)
	var beam := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Sim.ION_BEAM_W * 1.8, 2.0)
	beam.mesh = plane
	var bmat := ShaderMaterial.new()
	bmat.shader = ION_SHADER
	beam.material_override = bmat
	beam.position = c + Vector3(0.0, 0.0, -1.0)
	out.append(beam)
	var ghost := _make_ghost_ship()
	ghost.visible = true
	ghost.position = c + Vector3(0.0, 0.0, 2.0)
	out.append(ghost)
	for n in out:
		_root.add_child(n)
	InstParam.set_param(hole, "open", 1.0)
	# The ball's trail is built while it flies (an empty mesh draws nothing):
	# a few points so its material is drawn now.
	var trail := Fx.Trail.new()
	for k in 4:
		trail.update(c + Vector3(float(k) * 0.3, 0.0, 0.5))
	_root.add_child(trail)
	out.append(trail)
	# The fireball a lost charge makes on the planet (additive billboard + a
	# gradient texture); it frees itself.
	_planet._spawn_fireball(c + Vector3(0.0, 0.0, -2.0), 1.0, 0.1, 0.2)
	return out


func _explode_brick(pos: Vector3, color: Color, size_scale: float = 1.0) -> void:
	var blast := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3) * size_scale
	blast.mesh = quad
	var bm := ShaderMaterial.new()
	bm.shader = EXPLOSION_SHADER
	bm.set_shader_parameter("tint", color)
	blast.material_override = bm
	blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blast.position = pos + Vector3(0, 0.25, 0)
	InstParam.set_param(blast, "seed", randf() * 100.0)
	_root.add_child(blast)
	var tw := blast.create_tween()
	tw.tween_method(func(a: float): InstParam.set_param(blast, "age", a), 0.0, 1.0, 0.55)
	tw.tween_callback(blast.queue_free)

	# Debris (D-087): tumbling brick-coloured shards that shrink away.
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(16 * size_scale)
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.8
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, 0.05, 0.12) * size_scale
	p.particle_flag_rotate_y = true
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.6, 0.85))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	var shard := BoxMesh.new()
	shard.size = Vector3(0.13, 0.05, 0.09)
	p.mesh = shard
	p.material_override = _debris_material(color)
	p.position = pos
	_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


var _debris_mats := {}


## Debris material per brick colour (D-087): the brick's hue, lit, with a glow.
func _debris_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _debris_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.35)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.9
		m.metallic = 0.4
		m.roughness = 0.45
		_debris_mats[key] = m
	return _debris_mats[key]


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m


# --- 2D overlays ---------------------------------------------------------------------
## The TABLE stays clean: status lives on the DMD (D-051); only the fire hint here.
func _build_hud() -> void:
	_hint = UI.styled_label(tr("TB_PRESS_LAUNCH"), TITLE_FONT, 2)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -560
	_hint.offset_left = -400
	_hint.offset_right = 400
	add_to_table(_hint)


## Debug keys (D-057): F = piercing plasma along the ship's vertical line.
func _on_debug_action(action: StringName) -> void:
	if action == &"powerup" and sim != null and _phase == "play":
		var kind: String = Sim.POWERUP_KINDS[_debug_pu % Sim.POWERUP_KINDS.size()]
		_debug_pu += 1
		sim.events.clear()
		sim.spawn_powerup(kind, Vector2(sim.paddle_x, Sim.PADDLE_Y - 1.3))
		_handle_events()
		return
	if action == &"clear_level" and sim != null and _phase == "play":
		sim.debug_clear_level()
		_handle_events()  # events raised between steps must be handled now
		return
	if action == &"fire_line" and sim != null and sim.state != Sim.State.OVER:
		# Called between frames, so react here (sim events are cleared on the next step).
		sim.debug_fire_line()
		Audio.sfx("tb_blast3")
		_spawn_blast_node(3)


# --- attract + intro (D-061) ---------------------------------------------------------
func _enter_attract() -> void:
	# Attract music (D-082): "My Very Own Dead Ship" by yd, CC0.
	Audio.play_music(MUSIC_ATTRACT)
	_phase = "attract"
	_phase_t = 0.0
	for n in _brick_nodes:
		n.visible = false
	_paddle.visible = false
	_attract_ui = UI.vstack(60)
	_attract_ui.add_child(UI.styled_label(tr("GAME_BREAKOUT_TITLE"), TITLE_FONT, 3))
	_attract_blink = UI.styled_label(tr("TB_PRESS_START"), TITLE_FONT, 2)
	_attract_ui.add_child(_attract_blink)
	add_to_table(_attract_ui)
	_build_attract_steps()


## DMD attract loop: title / PRESS START, high scores, pixel animations.
func _build_attract_steps() -> void:
	var title: String = tr("GAME_BREAKOUT_TITLE")
	_attract_steps = [
		[func(): _dmd_anim("logo"), DmdAnims.DURATIONS["logo"]],
		[func(): Dmd.show_text(title, tr("TB_PRESS_START"), Dmd.CYAN, Dmd.WHITE), 2.0],
		[func(): Dmd.show_text(tr("ATTRACT_HIGH_SCORES"), "", Dmd.YELLOW), 1.4],
	]
	var table: Array = HighScores.get_table("breakout")
	for i in mini(5, table.size()):
		var row: Array = table[i]
		var line := "%d. %s %s" % [i + 1, row[0], ScoreTable.format_score(int(row[1]))]
		var col: Color = Dmd.YELLOW if i == 0 else Dmd.WHITE
		_attract_steps.append([func(): Dmd.show_text(line, "", col), 1.3])
	_attract_steps.append([func(): _dmd_anim("tetra_hit"), DmdAnims.DURATIONS["tetra_hit"] + 0.2])
	_attract_steps.append([func(): Dmd.show_text(title, Credits.status_text(), Dmd.CYAN, Dmd.GREEN), 2.0])
	_attract_steps.append([func(): _dmd_anim("incoming"), DmdAnims.DURATIONS["incoming"] + 0.2])
	_attract_steps.append([func(): _dmd_anim("rack_clear"), DmdAnims.DURATIONS["rack_clear"] + 0.2])
	_attract_step = -1
	_attract_left = 0.0


func _attract(delta: float) -> void:
	# Blink by alpha, not visibility: a hidden label collapses in its VBox and
	# makes the text below it jump (D-096).
	_attract_blink.modulate.a = 1.0 if fmod(_phase_t, 1.0) < 0.6 else 0.0
	_attract_left -= delta
	if _attract_left <= 0.0 and not _attract_steps.is_empty():
		_attract_step = (_attract_step + 1) % _attract_steps.size()
		var step: Array = _attract_steps[_attract_step]
		(step[0] as Callable).call()
		_attract_left = step[1]


# --- difficulty select (D-182) -----------------------------------------------------
## After PRESS START: EASY / NORMAL / HARD, chosen with the flippers, LAUNCH to
## go. The choice sets the plasma's speed and the lives, and is remembered.
const SELECT_IDLE_SECONDS := 30.0
const DIFF_NAME := {"easy": "TB_DIFF_EASY", "normal": "TB_DIFF_NORMAL", "hard": "TB_DIFF_HARD"}
const DIFF_SPEED := {"easy": "TB_SPEED_SLOW", "normal": "TB_SPEED_NORMAL", "hard": "TB_SPEED_FAST"}
var _select_ui: Control
var _select_rows: Array = []   # [name label, info label] per difficulty
var _select_index := 1


## --tb-difficulty=easy|normal|hard (dev), else the last choice, else normal.
func _start_difficulty() -> String:
	var d := str(Config.cli.get("tb-difficulty", Config.get_value("breakout", "difficulty", "normal")))
	return d if Sim.DIFFICULTIES.has(d) else "normal"


func _lives_for(d: String) -> int:
	return maxi(1, int(Config.get_value("operator", "balls_per_game")) + int(Sim.DIFFICULTIES[d].balls))


func _enter_select() -> void:
	_phase = "select"
	_phase_t = 0.0
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	Audio.sfx("select")
	Dmd.play(Callable(), 0.0)   # stop the attract animation so the choice shows
	_select_index = maxi(0, Sim.DIFFICULTY_ORDER.find(_start_difficulty()))
	_select_ui = UI.vstack(70)
	_select_ui.add_child(UI.styled_label(tr("TB_DIFFICULTY"), TITLE_FONT, 2))
	_select_rows.clear()
	for d in Sim.DIFFICULTY_ORDER:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l := UI.label("", 96, UI.WHITE)
		var info_l := UI.label(tr("TB_DIFF_INFO") % [tr(DIFF_SPEED[d]), _lives_for(d)], 36, UI.WHITE)
		row.add_child(name_l)
		row.add_child(info_l)
		_select_ui.add_child(row)
		_select_rows.append([name_l, info_l, row])
	_select_ui.add_child(UI.label(tr("TB_SELECT_HINT"), 36, UI.CYAN))
	add_to_table(_select_ui)
	_refresh_select()


func _move_select(step: int) -> void:
	var i := clampi(_select_index + step, 0, Sim.DIFFICULTY_ORDER.size() - 1)
	_phase_t = 0.0
	if i == _select_index:
		Audio.sfx("error")
		return
	_select_index = i
	Audio.sfx("move")
	_refresh_select()


func _refresh_select() -> void:
	for i in _select_rows.size():
		var d: String = Sim.DIFFICULTY_ORDER[i]
		var on := i == _select_index
		var name_l: Label = _select_rows[i][0]
		name_l.text = ("> %s <" % tr(DIFF_NAME[d])) if on else tr(DIFF_NAME[d])
		name_l.add_theme_color_override("font_color", UI.YELLOW if on else UI.WHITE)
		(_select_rows[i][2] as Control).modulate.a = 1.0 if on else 0.4
	var cur: String = Sim.DIFFICULTY_ORDER[_select_index]
	# The DMD line is short: the lives only (the speed is on the TABLE).
	Dmd.show_text(tr(DIFF_NAME[cur]), tr("TB_DIFF_DMD") % _lives_for(cur), Dmd.YELLOW, Dmd.WHITE)


func _confirm_select() -> void:
	var d: String = Sim.DIFFICULTY_ORDER[_select_index]
	sim.set_difficulty(d, int(Config.get_value("operator", "balls_per_game")))
	# Remembered for next time (not from scripted test runs, which mustn't save).
	if not Config.cli.has("press") and str(Config.get_value("breakout", "difficulty", "normal")) != d:
		Config.set_value("breakout", "difficulty", d)
		Config.save()
	if is_instance_valid(_select_ui):
		_select_ui.queue_free()
	_refresh_status()
	_begin_intro()


func _begin_intro() -> void:
	# Game music (D-081): "n-Dimensions (Retro)" by Matthew Pablo, CC BY 3.0.
	Audio.play_music(MUSIC)
	_phase = "intro"
	_phase_t = 0.0
	_landed = 0
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	Audio.sfx("start")
	Dmd.play(Callable(), 0.0)
	# Level 1 says GET READY; later levels announce their number (D-068).
	var title: String = tr("TB_GET_READY") if sim.level == 1 else tr("TB_LEVEL") % sim.level
	Dmd.show_text(title, tr("TB_GET_READY") if sim.level > 1 else tr("DMD_PLAYER_1"), Dmd.YELLOW, Dmd.WHITE)
	_ready_label = UI.styled_label(title, TITLE_FONT, 3)
	_ready_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ready_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_to_table(_ready_label)
	_lights.chase(1.5)


## Bricks drop in one after another (3D fall with a little bounce), then the
## ship rises from below the screen on its belly afterburner.
func _intro() -> void:
	var t := _phase_t
	var landed := 0
	for i in _brick_nodes.size():
		var n := _brick_nodes[i]
		var r: Rect2 = sim.bricks[i].rect
		var k := (t - i * INTRO_BRICK_STAGGER) / INTRO_BRICK_FALL
		n.visible = k > 0.0
		if k <= 0.0:
			continue
		k = minf(k, 1.0)
		var drop := INTRO_DROP_HEIGHT * pow(1.0 - _ease_out_bounce(k), 1.0)
		n.position = Vector3(r.get_center().x, drop, r.get_center().y)
		n.rotation = Vector3((1.0 - k) * 0.6, 0.0, (1.0 - k) * 0.4 * (1.0 if i % 2 == 0 else -1.0))
		if k >= 1.0:
			landed += 1
	while _landed < landed:
		_landed += 1
		if _landed % 3 == 1:  # don't spam: a clack every few bricks
			Audio.sfx("tb_brick_land")
	var bricks_done := (_brick_nodes.size() - 1) * INTRO_BRICK_STAGGER + INTRO_BRICK_FALL
	var st := (t - bricks_done) / INTRO_SHIP_TIME
	if st < 0.0:
		_paddle.visible = false
		_set_belly_thrust(0.0)
		return
	if not _paddle.visible:
		_paddle.visible = true
		Audio.sfx("tb_ship_arrive")
	var e := 1.0 - pow(1.0 - clampf(st, 0.0, 1.0), 3.0)  # ease out
	_paddle.position = Vector3(sim.paddle_x, 0.0, lerpf(INTRO_SHIP_FROM_Z, Sim.PADDLE_Y, e))
	_set_belly_thrust(1.5 * (1.0 - e) + 0.1 if st < 1.0 else 0.0)
	if st >= 1.0 + INTRO_SETTLE / INTRO_SHIP_TIME:
		_enter_play()


func _enter_play() -> void:
	_phase = "play"
	_phase_t = 0.0
	for i in _brick_nodes.size():
		var r: Rect2 = sim.bricks[i].rect
		_brick_nodes[i].visible = sim.bricks[i].alive
		_brick_nodes[i].position = Vector3(r.get_center().x, 0.0, r.get_center().y)
		_brick_nodes[i].rotation = Vector3.ZERO
	_set_belly_thrust(0.0)
	_paddle.scale = Vector3.ONE
	_paddle.rotation = Vector3.ZERO
	if is_instance_valid(_ready_label):
		_ready_label.queue_free()
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_hint.visible = true
	_shown_score = -1
	_refresh_status()


# --- level complete (D-068) -------------------------------------------------------------
const OUTRO_LIFT_AT := 0.9     # ship starts flying away (LEVEL CLEAR reads first)
const OUTRO_LIFT_TIME := 1.4
const OUTRO_FADE_AT := 1.9     # fade to black
const OUTRO_FADE_TIME := 0.6
const OUTRO_NEXT_AT := 2.7     # next level loads (behind the black)
var _outro_black: ColorRect
var _outro_lifted := false


## Level complete: remaining enemies already exploded (sim); the ship flies off
## towards the top and towards the screen, fade to black, then the next level
## plays the same intro (bricks drop in, ship blasts in).
func _begin_outro() -> void:
	_phase = "outro"
	_phase_t = 0.0
	_outro_lifted = false
	_outro_x0 = sim.paddle_x
	_hint.visible = false
	# Settle the ship before lift-off (D-085): the sim is paused now, so clear its
	# last speed (the per-frame banking/thrusters read it) and cut the thrusters.
	sim.paddle_vx = 0.0
	for eng in _engines:
		eng.set_thrust(0.0)


func _outro() -> void:
	var t := _phase_t
	# Ship flies away: up the screen (-z) and up towards the camera (+y). The
	# camera is orthographic, so growing scale sells "towards the screen".
	var k := clampf((t - OUTRO_LIFT_AT) / OUTRO_LIFT_TIME, 0.0, 1.0)
	if k > 0.0 and not _outro_lifted:
		_outro_lifted = true
		DebugTools.mark("outro_lift")
		Audio.sfx("tb_ship_arrive")
		Dmd.play(Callable(_dmd_anims, "ship_boost"), DmdAnims.DURATIONS["ship_boost"])  # D-076
	var e := k * k
	# Before lift-off the ship glides to the centre and levels out (D-085).
	var settle := smoothstep(0.0, OUTRO_LIFT_AT * 0.9, t)
	var x := lerpf(_outro_x0, Sim.FIELD.get_center().x, settle)
	_paddle.visible = true
	_paddle.position = Vector3(x, 7.0 * e, Sim.PADDLE_Y - 13.0 * e)
	_paddle.scale = Vector3.ONE * (1.0 + 2.2 * e)
	_paddle.rotation = Vector3(-0.5 * k, 0.0, 0.0)
	_set_belly_thrust(1.5 if k > 0.0 and k < 1.0 else 0.0)
	if t >= OUTRO_FADE_AT and _outro_black == null:
		DebugTools.mark("outro_fade")
		_outro_black = UI.fill(Color(0, 0, 0, 0))
		add_to_table(_outro_black)
		_outro_black.create_tween().tween_property(_outro_black, "color:a", 1.0, OUTRO_FADE_TIME)
	if t >= OUTRO_NEXT_AT:
		_load_next_level()


func _load_next_level() -> void:
	DebugTools.mark("next_level")
	sim.next_level()
	_build_bricks()
	for n in _brick_nodes:
		n.visible = false
	_paddle.visible = false
	_paddle.scale = Vector3.ONE
	_paddle.rotation = Vector3.ZERO
	_set_belly_thrust(0.0)
	for id in _enemy_nodes.keys():
		_remove_enemy_node(id)
	_begin_intro()
	# Fade back in over the new level's intro.
	var black := _outro_black
	_outro_black = null
	if is_instance_valid(black):
		black.move_to_front()
		var tw := black.create_tween()
		tw.tween_property(black, "color:a", 0.0, 0.5)
		tw.tween_callback(black.queue_free)


static func _ease_out_bounce(x: float) -> float:
	const N := 7.5625
	const D := 2.75
	if x < 1.0 / D:
		return N * x * x
	if x < 2.0 / D:
		x -= 1.5 / D
		return N * x * x + 0.75
	if x < 2.5 / D:
		x -= 2.25 / D
		return N * x * x + 0.9375
	x -= 2.625 / D
	return N * x * x + 0.984375


## Plays one of the Tilt Breaker DMD pixel animations (D-056), unless the
## game-over finale owns the DMD.
func _dmd_anim(name: String) -> void:
	if _finale_t >= 0.0 or sim.state == Sim.State.OVER:
		return
	_dmd_anims.texts = {
		# Attract shows just the art: no point texts (D-066).
		"plus_enemy": "" if _phase == "attract" else "+%d" % Sim.ENEMY_POINTS,
		"incoming": tr("TB_DMD_INCOMING"),
		"charge_lost": tr("TB_CHARGE_LOST"),
		"ship_destroyed": tr("TB_SHIP_DESTROYED"),
		"rack_clear": tr("TB_LEVEL_CLEAR"),
		"plus_rack": "" if _phase == "attract" else "+%d" % Sim.RACK_BONUS,
	}
	Dmd.play(Callable(_dmd_anims, name), DmdAnims.DURATIONS[name])


func _stop_charge_sound() -> void:
	Audio.stop_sfx(_charge_sound, _charge_sound_name)
	_charge_sound = null


func _set_belly_thrust(t: float) -> void:
	for be in _belly_engines:
		be.set_thrust(t)


# --- power-up visuals (D-072) -----------------------------------------------------------
func _spawn_powerup_node(id: int, pos: Vector2, kind: String) -> void:
	var cap := Fx.PowerupCapsule.new(kind, POWERUP_COLORS[kind], Sim.POWERUP_R)
	cap.position = Vector3(pos.x, 0.3, pos.y)
	_root.add_child(cap)
	_powerup_nodes[id] = cap


func _remove_powerup_node(id: int) -> void:
	if _powerup_nodes.has(id):
		_powerup_nodes[id].queue_free()
		_powerup_nodes.erase(id)


func _fire_ion_beam(x: float) -> void:
	Audio.sfx("tb_ion")
	_recoil = 1.0
	_lights.pulse(BackglassLights.SHOTS + BackglassLights.IMPACTS, 1.0, 14.0)
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var length := Sim.PADDLE_Y - Sim.FIELD.position.y
	plane.size = Vector2(Sim.ION_BEAM_W * 1.8, length)
	m.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = ION_SHADER
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(x, 0.15, Sim.FIELD.position.y + length * 0.5)
	_root.add_child(m)
	var tw := m.create_tween()
	tw.tween_method(func(f: float): InstParam.set_param(m, "fade", f), 1.0, 0.0, 0.55)
	tw.tween_callback(m.queue_free)


## Capsules, extra plasma balls, Lightspeed afterimages, Shield barrier.
func _animate_powerups(delta: float) -> void:
	_low_power_t = maxf(0.0, _low_power_t - delta)
	for p in sim.powerups:
		if _powerup_nodes.has(p.id):
			var cap: Fx.PowerupCapsule = _powerup_nodes[p.id]
			cap.position = Vector3(p.pos.x, 0.3, p.pos.y)
			cap.spin(delta)
	# Extra balls (Bounce): one plasma ball + trail each.
	while _extra_ball_nodes.size() < sim.extra_balls.size():
		var b := Fx.make_plasma_ball(Sim.BALL_R)
		Fx.tint_plasma(b, POWERUP_COLORS["B"])
		_root.add_child(b)
		var tr_node := Fx.Trail.new()
		tr_node.width = Sim.BALL_R * 1.1
		tr_node.head_color = Color(1.0, 0.85, 0.3, 0.9)
		tr_node.tail_color = Color(1.0, 0.4, 0.1, 0.0)
		_root.add_child(tr_node)
		_extra_ball_nodes.append([b, tr_node])
	while _extra_ball_nodes.size() > sim.extra_balls.size():
		var pair: Array = _extra_ball_nodes.pop_back()
		pair[0].queue_free()
		pair[1].queue_free()
	for i in sim.extra_balls.size():
		var ep: Vector2 = sim.extra_balls[i].pos
		var pos := Vector3(ep.x, 0.05, ep.y)
		_extra_ball_nodes[i][0].position = pos
		_extra_ball_nodes[i][1].update(pos)
	# Lightspeed afterimages
	var gx: Array = sim.ghost_xs() if _phase == "play" else []
	while _ghost_nodes.size() < 2:
		var g := _make_ghost_ship()
		_root.add_child(g)
		_ghost_nodes.append(g)
	for i in _ghost_nodes.size():
		var on := i < gx.size()
		_ghost_nodes[i].visible = on
		if on:
			_ghost_nodes[i].position = Vector3(gx[i], 0.0, Sim.PADDLE_Y)
	# Shield barrier: steady while active, flashes and fades when it saves a ball.
	if _shield_node == null:
		_shield_node = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(Sim.FIELD.size.x, 0.5)
		_shield_node.mesh = plane
		_shield_bar_mat = ShaderMaterial.new()
		_shield_bar_mat.shader = SHIELD_SHADER
		_shield_bar_mat.set_shader_parameter("shield_color", POWERUP_COLORS["S"])
		_shield_node.material_override = _shield_bar_mat
		_shield_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield_node.position = Vector3(Sim.FIELD.get_center().x, 0.06, Sim.SHIELD_Y + 0.12)
		_root.add_child(_shield_node)
	_shield_flash += delta
	var flashing := _shield_flash < SHIELD_FADE
	_shield_node.visible = (sim.shield_active and _phase == "play") or flashing
	if flashing:
		_shield_bar_mat.set_shader_parameter("age", _shield_flash)
		_shield_bar_mat.set_shader_parameter("strength", 1.0 - _shield_flash / SHIELD_FADE)
	elif sim.shield_active:
		_shield_bar_mat.set_shader_parameter("hit_x", 5.0)  # no hot spot
		_shield_bar_mat.set_shader_parameter("age", 99.0)
		_shield_bar_mat.set_shader_parameter("strength", 0.55 + 0.1 * sin(Time.get_ticks_msec() * 0.006))


## The ship flashes yellow each time the bar recharges a level (D-084): every
## third for 3-level guns, only when full for 1-level guns (Bounce, Ion), never
## without a bar (Lightspeed, Shield). Pickups and level refills count too.
func _animate_recharge_flash(delta: float) -> void:
	var levels := 3 if sim.max_level() >= 3 and sim.powerup != "I" else 1
	var step := int(floor(sim.power * levels + 0.0001))
	if _phase == "play" and sim.blasts_enabled() and _last_power_step >= 0 and step > _last_power_step:
		_recharge_flash = 1.0
	_last_power_step = step
	_recharge_flash = maxf(0.0, _recharge_flash - delta / 0.3)
	if _recharge_mat:
		_recharge_mat.albedo_color.a = 0.75 * _recharge_flash * _recharge_flash


func _make_ghost_ship() -> Node3D:
	var root := Node3D.new()
	var scene := load(PADDLE_MODEL) as PackedScene
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.7, 0.85, 1.0, 0.35)
	if scene:
		var model := scene.instantiate() as Node3D
		var s := Sim.PADDLE_W / MODEL_PADDLE_WIDTH
		model.scale = Vector3(s, s, s)
		model.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		root.add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
	root.visible = false
	return root


# --- tetrahedron enemies (D-052) ------------------------------------------------------
func _spawn_enemy_node(id: int, pos: Vector2) -> void:
	if _circuit_textures.is_empty():
		for c in ["red", "yellow", "green", "blue"]:
			_circuit_textures.append(load("res://assets/textures/breakout/circuit_%s.png" % c))
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.3, pos.y)
	# One circuit colour per enemy (D-053).
	var pick := randi() % _circuit_textures.size()
	var colour: Color = CIRCUIT_GLOW[["red", "yellow", "green", "blue"][pick]]
	var body := Fx.make_tetrahedron(Sim.ENEMY_R * 1.5, _circuit_textures[pick], colour)
	body.scale = Vector3.ONE * 0.01
	root.add_child(body)
	_root.add_child(root)
	var hole := Fx.make_wormhole(1.7)
	hole.position = Vector3(pos.x, 0.25, pos.y)
	_root.add_child(hole)
	var tw := hole.create_tween()
	tw.tween_method(func(o: float): InstParam.set_param(hole, "open", o), 0.0, 1.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(1.2, 2.2)
	_enemy_nodes[id] = {"root": root, "body": body, "spin": spin, "hole": hole, "colour": colour}


func _close_wormhole(id: int) -> void:
	if not _enemy_nodes.has(id) or _enemy_nodes[id].hole == null:
		return
	var hole: MeshInstance3D = _enemy_nodes[id].hole
	_enemy_nodes[id].hole = null
	var tw := hole.create_tween()
	tw.tween_method(func(o: float): InstParam.set_param(hole, "open", o), 1.0, 0.0, 0.4)
	tw.tween_callback(hole.queue_free)


func _remove_enemy_node(id: int) -> void:
	if not _enemy_nodes.has(id):
		return
	_close_wormhole(id)
	_enemy_nodes[id].root.queue_free()
	_enemy_nodes.erase(id)


func _animate_enemies(delta: float) -> void:
	for en in sim.enemies:
		if not _enemy_nodes.has(en.id):
			continue
		var n: Dictionary = _enemy_nodes[en.id]
		var p: Vector2 = en.pos
		n.root.position = Vector3(p.x, 0.3, p.y)
		var body: Node3D = n.body
		var spin: Vector3 = n.spin
		body.rotate(spin.normalized(), spin.length() * delta)
		# Emerges from the wormhole over the last part of WORMHOLE_TIME.
		var emerge := clampf((en.t - 0.3) / (Sim.WORMHOLE_TIME - 0.3), 0.0, 1.0) if en.state == "wormhole" else 1.0
		body.scale = Vector3.ONE * maxf(0.01, emerge)


# --- energy blast visuals (D-051) -------------------------------------------------------
func _spawn_blast_node(level: int, dir: Vector2 = Vector2.UP) -> void:
	var m := MeshInstance3D.new()
	m.rotation.y = -atan2(dir.x, -dir.y)  # the bolt's nose points along `dir`
	var plane := PlaneMesh.new()
	var grow := 0.85 + 0.25 * level
	plane.size = Vector2(Sim.blast_width(level) * 2.4, Sim.BLAST_H * 2.2 * grow)
	m.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = BLAST_SHADER
	var col: Color = LEVEL_COLORS[level - 1]
	mat.set_shader_parameter("body_color", col)
	mat.set_shader_parameter("edge_color", col.lerp(Color(0.7, 0.4, 1.0), 0.4))
	mat.set_shader_parameter("intensity", 2.2 + 0.5 * level)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(m)
	_blast_nodes.append(m)


func _animate_blasts(_delta: float) -> void:
	# One node per live sim blast; finished blasts are removed from the front.
	while _blast_nodes.size() > sim.blasts.size():
		_blast_nodes.pop_front().queue_free()
	while _blast_nodes.size() < sim.blasts.size():  # safety net: never index past the nodes
		var nb: Dictionary = sim.blasts[_blast_nodes.size()]
		_spawn_blast_node(int(nb.level), nb.get("dir", Vector2.UP))
	for i in sim.blasts.size():
		var p: Vector2 = sim.blasts[i].pos
		var d: Vector2 = sim.blasts[i].get("dir", Vector2.UP)
		# Nose leads: shift the drawn bolt so its tail trails behind the hitbox.
		var off := -d * Sim.BLAST_H * 0.55
		_blast_nodes[i].position = Vector3(p.x + off.x, 0.12, p.y + off.y)
	# Charging (D-053, D-054): particles in the colour of the level being charged
	# converge in front of the nose; the sphere shows the level already reached
	# (small blue, medium yellow, full-size red).
	var reached := int(floor(sim.blast_charge + 0.0001))
	var charging := sim.blast_charge > 0.0 or (sim.state == Sim.State.PLAY and CabinetInput.is_down(&"flip_l") \
		and CabinetInput.is_down(&"flip_r"))
	charging = charging and reached < mini(sim.affordable_level(), Sim.BLAST_MAX_LEVEL)
	if _charge_particles.emitting != charging:
		if charging:
			_charge_particles.restart()  # no leftovers from a previous charge
			_charge_particles.visible = true
		else:
			_charge_particles.visible = false  # vanish at once on release (D-067)
		_charge_particles.emitting = charging
	if sim.blast_charge <= 0.0 and not charging:
		_stop_charge_sound()
	if charging:
		# Power laser goes straight to level 3: red particles only (D-076).
		_charge_particles.color = LEVEL_COLORS[2] if sim.powerup == "P" else LEVEL_COLORS[reached]
	_charge_glow.visible = reached >= 1 and sim.powerup != "P"
	if reached >= 1:
		if _charge_level_shown != reached:
			_charge_level_shown = reached
			Fx.tint_plasma(_charge_glow, LEVEL_COLORS[reached - 1])
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.03)
		_charge_glow.scale = Vector3.ONE * LEVEL_SPHERE_SCALE[reached - 1] * pulse
	else:
		_charge_level_shown = 0


## Backglass (D-058): the director's art; three light groups (engines, shots,
## impacts) blink with game events. Status stays on the DMD (D-051).
func _build_backglass() -> void:
	add_to_backglass(UI.fill(Color.BLACK))
	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The 2-screen art (room for the DMD at the bottom, D-080) is used on every
	# cabinet, 3-screen too (director, D-108).
	var sfx_2 := "_2screen"
	art.texture = load("res://assets/textures/breakout/backglass_off%s.png" % sfx_2)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backglass_mat = ShaderMaterial.new()
	_backglass_mat.shader = BACKGLASS_SHADER
	_backglass_mat.set_shader_parameter("on_tex", load("res://assets/textures/breakout/backglass_on%s.png" % sfx_2))
	_backglass_mat.set_shader_parameter("mask_tex", load("res://assets/textures/breakout/backglass_mask%s.png" % sfx_2))
	_backglass_mat.set_shader_parameter("logo_mask_tex", load("res://assets/textures/breakout/backglass_mask_logo%s.png" % sfx_2))
	art.material = _backglass_mat
	add_to_backglass(art)


func _update_backglass_lights(delta: float) -> void:
	if _backglass_mat == null:
		return
	_lights.engine_drive = clampf(absf(sim.paddle_vx) / Sim.PADDLE_MAX_SPEED, 0.0, 1.0)
	_lights.charge = clampf(sim.blast_charge / Sim.BLAST_MAX_LEVEL, 0.0, 1.0)
	_lights.logo_mode = "blink" if _phase == "attract" else "on"
	var lv := _lights.levels(delta)
	if Config.cli.has("tb-lights-on"):  # dev: hold every light group fully lit
		lv = Vector4.ONE
	_backglass_mat.set_shader_parameter("levels", lv)


func _exit_tree() -> void:
	if _portrait_req:
		Screens.want_dmd_above(false)   # D-262
	super._exit_tree()
