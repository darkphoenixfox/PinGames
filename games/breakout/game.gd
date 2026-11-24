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
const SIDE_THRUST_BRIGHTNESS := 0.22   # D-344: the side thrusters, dimmed so the ship's ends read
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
	"I": Color(0.72, 0.3, 1.0), "L": Color(1.0, 1.0, 1.0), "S": Color(0.3, 1.0, 0.4),
	"U": Color(1.0, 0.35, 0.7), "N": Color(1.0, 0.5, 0.05),   # D-326: 1UP pink, Nuclear orange
	"W": Color(0.2, 1.0, 0.9), "H": Color(0.65, 1.0, 0.2), "K": Color(0.55, 0.75, 1.0)}   # D-327
const ATOM_ICON := preload("res://assets/textures/breakout/pu_atom.png")   # D-326
const MUSIC := "res://assets/audio/music/breakout/tilt_breaker_original.ogg"   # D-318: the director's own (was n-Dimensions)
const MUSIC_ATTRACT := "res://assets/audio/music/breakout/dead_ship_attract.ogg"  # D-082
const MUSIC_GAME_OVER := "res://assets/audio/music/breakout/earths_end.ogg"   # D-320: the director's, after the last life
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
	"tb_extra_life": {"voices": [  # D-321: an extra life: a bright rising arpeggio, twice
		[{"f": [784.0, 784.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [988.0, 988.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1175.0, 1175.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1568.0, 1568.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1175.0, 1175.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1568.0, 1568.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [1976.0, 1976.0], "t": 0.06, "w": "pulse25", "v": 0.2, "env": "hold"},
		 {"f": [2349.0, 2349.0], "t": 0.45, "w": "pulse25", "v": 0.22, "vib": [8.0, 0.35]}],
		[{"f": [196.0, 196.0], "t": 0.24, "w": "triangle", "v": 0.35, "env": "hold"},
		 {"f": [294.0, 294.0], "t": 0.24, "w": "triangle", "v": 0.35, "env": "hold"},
		 {"f": [392.0, 392.0], "t": 0.45, "w": "triangle", "v": 0.35}]], "echo": ECHO},
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
var _launch2 := false   # D-286: player 2
var _dash2 := 0
var _charge_btn2 := false
var _players_sel := 0   # 0 = 1 player, 1 = 2 players
var _players_ui: Control
var _players_rows: Array = []
var _p2_bars: Array = []   # [[root, fill, label], ...] per player (TABLE energy bars)
var _charge_btn := false   # D-264
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
	# D-265: landscape: DMD left, backglass right; D-266: framed in circuit brick.
	Screens.want_side_panels(true, load("res://assets/textures/breakout/circuit_blue.png"), self)
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
	if Config.cli.has("tb-2p"):   # dev: a 2-player game (D-286)
		_go_two()
	if Config.cli.has("tb-skip-intro"):  # dev: straight into play
		Audio.play_music(MUSIC)
		_enter_play()
	else:
		_enter_attract()


func on_action(action: StringName, pressed: bool) -> void:
	# D-264: on a single screen, LAUNCH (a pad's Cross) held is the charge shot,
	# like both flippers; only a press made while the ball is in play counts.
	if action == &"launch":
		_charge_btn = pressed and Screens.current_layout == "single" and sim != null and sim.state == Sim.State.PLAY
	if action == &"p2_launch":   # D-286
		_charge_btn2 = pressed and sim != null and sim.state == Sim.State.PLAY
	if not pressed:
		return
	if _phase == "attract":
		if action == &"start" or action == &"launch":
			if CabinetInput.two_player_possible():
				_enter_players()   # D-286: 1 PLAYER / 2 PLAYERS first
			else:
				_enter_level()   # D-336
		return
	if _phase == "level":   # D-336: the starting level
		match action:
			&"flip_l", &"magna_l":
				_move_level(-1)
			&"flip_r", &"magna_r":
				_move_level(1)
			&"launch", &"start":
				_confirm_level()
		return
	if _phase == "players":
		match action:
			&"flip_l", &"flip_r", &"magna_l", &"magna_r":
				_players_sel = 1 - _players_sel
				_sfx("move")
				_refresh_players()
			&"launch", &"start":
				_confirm_players()
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
		&"p2_launch":   # D-286
			_launch2 = true
			return
		&"p2_magna_l":
			_dash2 = -1
			return
		&"p2_magna_r":
			_dash2 = 1
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
	if _phase == "level":   # D-336
		_animate(delta)
		if _phase_t > SELECT_IDLE_SECONDS:
			_level_ui.queue_free()
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
		var an := str(Config.cli["tb-dmd-anim"])
		if an.begins_with("pu_"):
			_dmd_pu_anim(an.trim_prefix("pu_"))
		else:
			_dmd_anim(an)
	if Config.cli.has("tb-enemy-low") and _phase == "play" and not has_meta("dev_enemy"):   # dev: an enemy at the bottom (D-322)
		set_meta("dev_enemy", true)
		var ek := "cube" if Config.cli.has("tb-cube") else str(Config.cli.get("tb-enemy-kind", "tetra"))
		var eid: int = sim.spawn_enemy(-3.0, ek)
		sim.enemies[-1].state = "sweep"
		sim.enemies[-1].pos = Vector2(-3.0, Sim.ENEMY_ORBIT_START_Y + 0.5)
		sim.events.append(["enemy_ready", eid])
		sim.ship_invulnerable = 999.0   # so it stays for the screenshot
		_handle_events()
	if Config.cli.has("tb-pu-clear-at") and _phase == "play" and _phase_t >= float(str(Config.cli["tb-pu-clear-at"])) 			and not has_meta("dev_pu_clear"):   # dev: a capsule drops as the level ends (D-325)
		set_meta("dev_pu_clear", true)
		_on_debug_action(&"powerup")
		_on_debug_action(&"clear_level")
	if Config.cli.has("tb-dark") and _phase == "play" and not has_meta("dev_dark"):   # dev: a corrupted paddle now (D-342)
		set_meta("dev_dark", true)
		sim.events.clear()
		sim.spawn_dark(1.0)
		_handle_events()
	if Config.cli.has("tb-boss-hp") and sim.boss_hp > 0 and not has_meta("dev_boss_hp"):   # dev: boss health (D-338)
		set_meta("dev_boss_hp", true)
		sim.boss_hp = int(str(Config.cli["tb-boss-hp"]))
	if Config.cli.has("tb-boss-fire") and _phase == "play" and not has_meta("dev_boss_fire"):   # dev: the boss fires N s in (D-335)
		set_meta("dev_boss_fire", true)
		sim.boss_fire_in = float(str(Config.cli["tb-boss-fire"]))
		_launch = true   # it only fires in play
	if Config.cli.has("tb-give") and _phase == "play" and not has_meta("dev_give"):   # dev: start with power-ups, e.g. H,K (D-327)
		set_meta("dev_give", true)
		for k in str(Config.cli["tb-give"]).split(","):
			sim.apply_powerup(k)
	if Config.cli.has("tb-drop") and _phase == "play" and not has_meta("dev_drop"):   # dev: drop capsules, e.g. U,N (D-326)
		set_meta("dev_drop", true)
		sim.events.clear()
		var kinds: PackedStringArray = str(Config.cli["tb-drop"]).split(",")
		for i in kinds.size():
			sim.spawn_powerup(kinds[i], Vector2((i - (kinds.size() - 1) * 0.5) * 1.2, -1.0))
		_handle_events()
	if Config.cli.has("tb-score") and not has_meta("dev_score"):   # dev: start at N points (D-321)
		set_meta("dev_score", true)
		sim.score = int(str(Config.cli["tb-score"]))
	if Config.cli.has("tb-over-at") and _phase_t >= float(str(Config.cli["tb-over-at"])) 			and sim.state != Sim.State.OVER and not has_meta("dev_over"):   # dev: game over at N s (D-319)
		set_meta("dev_over", true)
		sim.balls_left = 1
		sim._lose_ball()
		_handle_events()
	if _two:   # D-286: each player's controls and stick
		sim.player_set(0, "paddle_axis", CabinetInput.steer_axis(0))
		sim.player_set(1, "paddle_axis", CabinetInput.steer_axis(1))
		sim.player_set(0, "charge_held", _charge_btn and CabinetInput.is_down(&"launch"))
		sim.player_set(1, "charge_held", _charge_btn2 and CabinetInput.is_down(&"p2_launch"))
		sim.step_two(minf(delta, 0.05),
			[CabinetInput.is_down(&"flip_l"), CabinetInput.is_down(&"flip_r"), _launch, _dash],
			[CabinetInput.is_down(&"p2_flip_l"), CabinetInput.is_down(&"p2_flip_r"), _launch2, _dash2])
	else:
		sim.paddle_axis = CabinetInput.steer_axis()   # D-252
		sim.charge_held = _charge_btn and CabinetInput.is_down(&"launch")   # D-264
		if Config.cli.has("tb-autofire"):   # dev: serve, then keep charging and firing (D-327)
			if sim.state == Sim.State.SERVE:
				_launch = true
			sim.freeze_ball = sim.state == Sim.State.PLAY   # the plasma waits, so no charge is lost
			sim.charge_held = fmod(_phase_t, 1.2) < 1.0
		sim.step(minf(delta, 0.05), CabinetInput.is_down(&"flip_l"), CabinetInput.is_down(&"flip_r"), _launch, _dash)
	_launch = false
	_launch2 = false
	_dash = 0
	_dash2 = 0
	_handle_events()
	_animate(delta)


## D-302, D-304 (director): on the attract and selection screens only the
## menu sounds play (choosing, confirming, a blocked move), never the gameplay
## behind them. Every effect in this game goes through here.
const MENU_SFX := ["start", "select", "move", "error", "rc_shift"]
const QUIET_PHASES := ["attract", "players", "select", "level"]


func _sfx(sound_name: String) -> AudioStreamPlayer:
	if _phase in QUIET_PHASES and not (sound_name in MENU_SFX):
		return null
	return Audio.sfx(sound_name)


# --- events ------------------------------------------------------------------------
func _handle_events() -> void:
	# D-326: a nuke's bricks share one big blast sound, not one each.
	var nuked := sim.events.any(func(ev): return ev[0] == "nuke")
	var from_1up := sim.events.any(func(ev): return ev[0] == "powerup_collect" and ev[1][1] == "U")
	for k in sim.events.size():
		var e: Array = sim.events[k]
		if e[0] != "paddle" and e[0] != "wall":
			DebugTools.mark(str(e[0]))
		if _two:   # D-286: this event's ship visuals
			var who := 0
			if e[0] == "paddle" and e[1] != null:
				who = int(e[1])
			elif e[0] == "powerup_collect" and (e[1] as Array).size() > 2:
				who = int(e[1][2])
			elif e[0] == "serve":
				who = sim.server
			elif k < sim.event_ship.size():
				who = int(sim.event_ship[k])
			_view_use(who)
		match e[0]:
			"paddle":
				_sfx("tb_shield")
				_lights.pulse(BackglassLights.SHOTS, 0.3, 16.0, 0.7)
				_shield_age = 0.0
				_shield_mat.set_shader_parameter("hit_x",
					clampf((sim.ball_pos.x - sim.paddle_x) / sim.catch_half_w(), -1.0, 1.0))   # D-332: sidekicks too
			"wall":
				_sfx("tb_shield")
				_flash_edge_shield(e[1][0], e[1][1])
			"brick":
				var n := _brick_nodes[e[1]]
				n.visible = false
				_explode_brick(n.position, _brick_glow(sim.bricks[e[1]]), 1.5 if nuked else 1.0)
				_lights.pulse(BackglassLights.IMPACTS, 0.35, 14.0)
				if not nuked:
					_sfx("tb_brick")
			"nuke":   # D-326: a white flash over the TABLE, one big blast
				_sfx("tb_explode_big")
				_lights.pulse(BackglassLights.ALL, 1.4, 8.0)
				_nuke_flash()
			"serve":
				_sfx("tb_fire")
				_lights.pulse(BackglassLights.SHOTS, 0.7, 12.0)
				_fire_flash = 1.0
				_recoil = 1.0
				_trail.clear()
				_hint.visible = false
			"dash":
				_sfx("tb_dash")
				_dash_glow = 1.0
			"charge_start":
				_stop_charge_sound()
				_charge_sound_name = "tb_charge%d" % int(e[1])
				_charge_sound = _sfx(_charge_sound_name)
			"charged":
				_sfx("tb_level%d" % int(e[1]))
			"blast":
				_stop_charge_sound()
				var blevel: int = e[1][1]
				var bdir: Vector2 = e[1][2] if e[1].size() > 2 else Vector2.UP
				if bdir == Vector2.UP:  # one sound/recoil per volley (Triple = 3 events)
					_sfx("tb_blast%d" % blevel)
					_recoil = 0.5 + 0.25 * blevel
				_spawn_blast_node(blevel, bdir)
				_lights.pulse(BackglassLights.SHOTS + BackglassLights.IMPACTS, 0.5 + 0.2 * blevel, 10.0)
			"wave_fire":   # D-327
				_stop_charge_sound()
				_sfx("tb_blast2")
				_recoil = 0.8
				_lights.pulse(BackglassLights.SHOTS, 0.6, 10.0)
			"missile_fire":   # D-327
				_stop_charge_sound()
				_sfx("tb_fire")
				_recoil = 0.6
				_lights.pulse(BackglassLights.SHOTS, 0.5, 10.0)
			"boss_charge":   # D-335: red sparks pour into the eye
				_sfx("tb_charge3")
				_boss_charge_t = Sim.BOSS_CHARGE
				if _boss_nodes.has("charge"):
					(_boss_nodes.charge as CPUParticles3D).restart()
					(_boss_nodes.charge as CPUParticles3D).emitting = true
			"boss_fire":
				_sfx("tb_ion")
				_boss_charge_t = 0.0
				_lights.pulse(BackglassLights.SHOTS, 0.8, 12.0)
				if _boss_nodes.has("charge"):
					(_boss_nodes.charge as CPUParticles3D).emitting = false
			"boss_hit":
				_sfx("tb_armour")
				_boss_flash = 1.0
				_boss_shield_hit(e[1][1] if e[1] is Array else sim.boss_pos)   # D-342
				_lights.pulse(BackglassLights.IMPACTS, 0.4, 14.0)
			"boss_dead":
				var bp: Vector2 = e[1]
				_sfx("tb_explode_big")
				_lights.pulse(BackglassLights.ALL, 2.0, 8.0)
				for q in 7:
					var off := Vector2.from_angle(q * 0.9) * (0.4 + 0.15 * q)
					_explode_brick(Vector3(bp.x + off.x, 0.4, bp.y + off.y),
						[Color(1.0, 0.2, 0.1), Color(1.0, 0.7, 0.2), Color(0.9, 0.3, 1.0)][q % 3], 2.0 + 0.3 * q)
				Dmd.flash(tr("TB_BOSS_DOWN"), 2.2, Dmd.RED)
				_free_boss_nodes()
			"brick_torpedo":   # D-342: a charged brick fires back
				_sfx("tb_fire")
				InstParam.set_param(_brick_nodes[e[1][0]], "hit_flash", 0.0)
			"plasma_free":   # D-342: a captured ball goes free
				_sfx("tb_pu_get")
				_lights.pulse(BackglassLights.SHOTS, 0.5, 12.0)
			"mini_charge":
				if _enemy_nodes.has(e[1]) and _enemy_nodes[e[1]].has("charge"):
					var mc: CPUParticles3D = _enemy_nodes[e[1]].charge
					mc.restart()
					mc.emitting = true
					_enemy_nodes[e[1]].charge_t = Sim.MINI_CHARGE
			"mini_fire":
				_sfx("tb_blast1")
				if _enemy_nodes.has(e[1][0]) and _enemy_nodes[e[1][0]].has("charge"):
					(_enemy_nodes[e[1][0]].charge as CPUParticles3D).emitting = false
			"dark_spawn":
				_spawn_dark_node(e[1][0], e[1][1])
				_sfx("tb_wormhole")
			"dark_hit":
				_sfx("tb_armour")
				if _dark_nodes.has(e[1][0]):
					_dark_nodes[e[1][0]].flash = 1.0
			"dark_dead":
				var dp: Vector2 = e[1][1]
				_sfx("tb_explode")
				_explode_brick(Vector3(dp.x, 0.3, dp.y), Color(1.0, 0.2, 0.2), 1.8)
				_lights.pulse(BackglassLights.IMPACTS + BackglassLights.SHOTS, 0.8, 10.0)
				if _dark_nodes.has(e[1][0]):
					(_dark_nodes[e[1][0]].root as Node).queue_free()
					_dark_nodes.erase(e[1][0])
			"ray_blocked":
				var rb: Vector2 = e[1]
				_sfx("tb_shield_break")
				_explode_brick(Vector3(rb.x, 0.3, rb.y), Color(1.0, 0.25, 0.2), 1.1)
			"ray_hit":
				_sfx("tb_ion")
			"missile_blast":   # D-327: the 3x3-brick blast
				var mp: Vector2 = e[1][0]
				_sfx("tb_explode")
				_explode_brick(Vector3(mp.x, 0.2, mp.y), POWERUP_COLORS["H"], 2.4)
				_lights.pulse(BackglassLights.IMPACTS + BackglassLights.SHOTS, 0.9, 10.0)
			"blast_fail":
				_sfx("tb_low_power")
				_low_power_t = 1.2  # LOW shows only in the DMD power bar area (D-072)
			"brick_hit":
				var hb: Dictionary = sim.bricks[e[1]]
				InstParam.set_param(_brick_nodes[e[1]], "mode", 2.0)
				_sfx("tb_armour")
				_explode_brick(_brick_nodes[e[1]].position, _brick_glow(hb), 0.5)
			"powerup_spawn":
				_spawn_powerup_node(e[1][0], e[1][1], e[1][2])
				_sfx("tb_pu_drop")
			"powerup_collect":
				_remove_powerup_node(e[1][0])
				var kind: String = e[1][1]
				if (e[1] as Array).size() > 3:
					_pickup_popup(tr("TB_PU_%s" % kind), e[1][3], POWERUP_COLORS[kind])
				_sfx("tb_pu_get")
				_dmd_pu_anim(kind)   # D-328 (was a text flash)
				_lights.pulse(BackglassLights.ALL, 0.8, 10.0)
				_recoil = 0.4
			"powerup_lost":
				_remove_powerup_node(e[1])
			"ion_beam":
				_fire_ion_beam(e[1])
			"bounce_ball":
				_sfx("tb_fire")
				_recoil = 0.7
			"ghost":
				_sfx("tb_shield")
			"shield_used":
				_sfx("tb_shield_break")
				_shield_flash = 0.0
				_shield_bar_mat.set_shader_parameter("hit_x", clampf(e[1] / (sim.field.size.x * 0.5), -1.0, 1.0))
				_lights.pulse(BackglassLights.ENGINES + BackglassLights.SHOTS, 0.6, 12.0)
			"extra_life":   # D-321
				_sfx("tb_extra_life")
				if not from_1up:   # a 1UP's own DMD clip says it (D-328)
					Dmd.flash(tr("TB_EXTRA_CHARGE"), 1.8, Dmd.CYAN)
				_lights.chase(1.2)
				_refresh_status()
			"extra_lost":
				_sfx("tb_explode")
				_planet.impact(Vector3(e[1], 0.0, Sim.DRAIN_Y), -_cam.global_transform.basis.z)
			"blast_end":
				var end_pos: Vector2 = e[1][0]
				var end_level: int = e[1][2]
				_explode_brick(Vector3(end_pos.x, 0.0, end_pos.y), LEVEL_COLORS[end_level - 1], 0.8 + 0.3 * end_level)
			"enemy_spawn":
				_spawn_enemy_node(e[1][0], e[1][1], e[1][2] if e[1].size() > 2 else "tetra")
				_sfx("tb_wormhole")
				_dmd_anim("incoming")
			"enemy_ready":
				_close_wormhole(e[1])
			"enemy_destroyed":
				var ecol: Color = _enemy_nodes[e[1][0]].colour if _enemy_nodes.has(e[1][0]) else Color(0.75, 0.4, 1.0)
				_remove_enemy_node(e[1][0])
				var ep: Vector2 = e[1][1]
				_explode_brick(Vector3(ep.x, 0.2, ep.y), ecol, 1.2)
				_sfx("tb_enemy_die")
				_lights.pulse(BackglassLights.IMPACTS + BackglassLights.SHOTS, 0.8, 10.0)
				if e[1][2]:  # shot down (not a ship collision)
					_dmd_anims.enemy_color = ecol
					_dmd_anim("tetra_hit")
			"ship_destroyed":
				var sp: Vector2 = e[1]
				_sfx("tb_ship_die")
				_lights.pulse(BackglassLights.ALL, 1.3, 8.0)
				_explode_brick(Vector3(sp.x, 0.2, sp.y), Color(0.4, 0.8, 1.0), 2.6)
				_trail.clear()
				if sim.state == Sim.State.OVER:
					_planet._spawn_fireball(Vector3(sp.x, 0.5, sp.y), 18.0, 1.1, 99.0)
				else:
					_dmd_anim("ship_destroyed")
					_hint.visible = true
			"rack_clear":
				_sfx("tb_rack")
				_lights.chase(1.8)
				if not nuked:   # a nuke's own DMD clip plays instead (D-328)
					_dmd_anim("rack_clear")
				_trail.clear()
				_begin_outro()
			"lost":
				var last := sim.state == Sim.State.OVER
				_sfx("tb_explode_big" if last else "tb_explode")
				_lights.pulse(BackglassLights.ALL, 1.2, 8.0)
				_planet.impact(Vector3(e[1], 0.0, Sim.DRAIN_Y), -_cam.global_transform.basis.z, last)
				_trail.clear()
				if sim.state != Sim.State.OVER:
					_dmd_anim("charge_lost")
					_hint.visible = true
				_refresh_status()
			"over":
				_finale_t = 0.0
				Audio.play_music(MUSIC_GAME_OVER, 0.5, true, false)   # D-320: once, over the finale
				_hint.visible = false
	if sim.score != _shown_score:
		_refresh_status()


## D-327: the power-up's name pops out where it was caught: growing and fading.
func _pickup_popup(text: String, at: Vector2, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/pinpixel.ttf")
	l.font_size = 48
	l.pixel_size = 0.0075
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.modulate = col.lerp(Color.WHITE, 0.25)
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.render_priority = 3
	l.position = Vector3(at.x, 1.0, at.y)
	l.scale = Vector3.ONE * 0.35
	_root.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * 1.0, 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:z", at.y - 0.9, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.4)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.7).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## D-335: the boss (icosahedron, HAL eye, charge sparks) and its rays
## (D-338: no health bar; the eye's colour shows it).
const HAL_SHADER := preload("res://games/breakout/shaders/hal_eye.gdshader")
const BOSS_SHIELD_SHADER := preload("res://games/breakout/shaders/boss_shield.gdshader")
var _boss_shield_age := 9.0


## D-342: lights the boss's shield where a hit landed (`at`, field coords).
func _boss_shield_hit(at: Vector2) -> void:
	if _boss_nodes.is_empty():
		return
	var d := at - sim.boss_pos
	(_boss_nodes.shield as ShaderMaterial).set_shader_parameter("hit_dir", Vector3(d.x, 0.45, d.y).normalized())
	_boss_shield_age = 0.0
const BOSS_VIS_R := 1.35   # the icosahedron's circumradius (hitbox: Sim.BOSS_R)
var _boss_nodes := {}
var _boss_flash := 0.0
var _boss_charge_t := 0.0
var _ray_nodes := {}


func _build_boss_nodes() -> void:
	var root := Node3D.new()
	var body: Node3D
	if sim.boss_kind == "dodeca":   # D-342: level 20
		body = Fx.make_dodecahedron(BOSS_VIS_R * 1.05, load("res://assets/textures/breakout/circuit_blue.png"),
			Color(0.75, 0.3, 1.0), 0.45)
	else:
		body = Fx.make_icosahedron(BOSS_VIS_R, load("res://assets/textures/breakout/circuit_red.png"),
			Color(1.0, 0.25, 0.3), 0.45)
	root.add_child(body)
	# D-342: the shield: a red glow where hits land.
	var shell := MeshInstance3D.new()
	var shm := SphereMesh.new()
	shm.radius = Sim.BOSS_R + 0.25
	shm.height = (Sim.BOSS_R + 0.25) * 2.0
	shell.mesh = shm
	var shmat := ShaderMaterial.new()
	shmat.shader = BOSS_SHIELD_SHADER
	shell.material_override = shmat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shell)
	var eye := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	eye.mesh = sm
	var em := ShaderMaterial.new()
	em.shader = HAL_SHADER
	eye.material_override = em
	root.add_child(eye)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.15, 0.1)
	glow.omni_range = 3.0
	glow.light_energy = 1.5
	root.add_child(glow)
	var charge := Fx.make_charge_particles(1.9, Color(1.0, 0.15, 0.1))
	charge.amount = 90
	charge.position = Vector3(0.0, 0.6, 0.0)
	root.add_child(charge)
	_root.add_child(root)
	_boss_nodes = {"root": root, "body": body, "eye": em, "light": glow, "charge": charge, "shield": shmat}


## D-338: the eye's colour by health left (1 = full): blue, green, yellow,
## orange, red, blended between the steps.
const BOSS_EYE_COLS := [Color(1.0, 0.08, 0.04), Color(1.0, 0.45, 0.05), Color(1.0, 0.9, 0.1),
	Color(0.15, 1.0, 0.2), Color(0.15, 0.4, 1.0)]


func _boss_eye_colour(health: float) -> Color:
	var f := clampf(health, 0.0, 1.0) * (BOSS_EYE_COLS.size() - 1)
	var i := mini(int(f), BOSS_EYE_COLS.size() - 2)
	return (BOSS_EYE_COLS[i] as Color).lerp(BOSS_EYE_COLS[i + 1], f - i)


func _free_boss_nodes() -> void:
	if _boss_nodes.is_empty():
		return
	(_boss_nodes.root as Node).queue_free()
	_boss_nodes = {}


func _animate_boss(delta: float) -> void:
	var live := sim.boss_hp > 0 and _phase in ["play", "intro", "outro"]
	if live and _boss_nodes.is_empty():
		_build_boss_nodes()
	elif not live and not _boss_nodes.is_empty():
		_free_boss_nodes()
	if not _boss_nodes.is_empty():
		var p: Vector2 = sim.boss_pos
		(_boss_nodes.root as Node3D).position = Vector3(p.x, 0.4, p.y)
		(_boss_nodes.body as Node3D).rotate(Vector3(0.3, 1.0, 0.45).normalized(), delta * 0.8)
		_boss_flash = maxf(0.0, _boss_flash - delta * 4.0)
		_boss_shield_age += delta
		var shm2: ShaderMaterial = _boss_nodes.shield
		shm2.set_shader_parameter("age", _boss_shield_age)
		shm2.set_shader_parameter("strength", clampf(1.0 - _boss_shield_age / 0.6, 0.0, 1.0))
		_boss_charge_t = maxf(0.0, _boss_charge_t - delta)
		var charge := 1.0 - _boss_charge_t / Sim.BOSS_CHARGE if _boss_charge_t > 0.0 else 0.0
		(_boss_nodes.eye as ShaderMaterial).set_shader_parameter("glow", charge * 1.5 + _boss_flash)
		(_boss_nodes.light as OmniLight3D).light_energy = 1.5 + charge * 4.0 + _boss_flash * 3.0
		if _boss_charge_t <= 0.0 and (_boss_nodes.charge as CPUParticles3D).emitting:
			(_boss_nodes.charge as CPUParticles3D).emitting = false
		# D-338: no health bar: the eye's colour tells it, blue to red.
		var iris := _boss_eye_colour(float(sim.boss_hp) / sim.boss_max_hp)
		(_boss_nodes.eye as ShaderMaterial).set_shader_parameter("iris", iris)
		(_boss_nodes.light as OmniLight3D).light_color = iris
	# Rays: a red bolt each, along its flight.
	var seen := {}
	for r in sim.rays:
		seen[r.id] = true
		if not _ray_nodes.has(r.id):
			var m := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(float(r.get("r", Sim.RAY_R)) * 4.0, float(r.get("len", Sim.RAY_LEN)) * 1.5)
			m.mesh = plane
			var mat := ShaderMaterial.new()
			mat.shader = BLAST_SHADER
			mat.set_shader_parameter("body_color", Color(1.0, 0.12, 0.08))
			mat.set_shader_parameter("edge_color", Color(1.0, 0.5, 0.2))
			mat.set_shader_parameter("intensity", 3.5)
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(m)
			_ray_nodes[r.id] = m
		var rp: Vector2 = r.pos
		var rv: Vector2 = r.vel
		var mid := rp - rv.normalized() * float(r.get("len", Sim.RAY_LEN)) * 0.5
		var node: MeshInstance3D = _ray_nodes[r.id]
		node.position = Vector3(mid.x, 0.35, mid.y)
		node.rotation.y = -atan2(rv.x, -rv.y)
	for id in _ray_nodes.keys():
		if not seen.has(id):
			(_ray_nodes[id] as Node).queue_free()
			_ray_nodes.erase(id)


## D-327: the wave shots and missiles, one node each, kept in step with the sim.
var _shot_nodes := {}   # id -> {node, trail}


func _animate_shots(_delta: float) -> void:
	var live := {}
	for w in sim.waves:
		live[w.id] = true
		if not _shot_nodes.has(w.id):
			var m := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(Sim.WAVE_SIZE.x * 1.9, Sim.WAVE_SIZE.y * 2.4)
			m.mesh = plane
			var mat := ShaderMaterial.new()
			mat.shader = BLAST_SHADER
			mat.set_shader_parameter("body_color", POWERUP_COLORS["W"])
			mat.set_shader_parameter("edge_color", Color(0.4, 0.6, 1.0))
			mat.set_shader_parameter("intensity", 3.2)
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(m)
			var tr_node := Fx.Trail.new()
			tr_node.width = 0.32
			tr_node.head_color = Color(POWERUP_COLORS["W"], 0.8)
			tr_node.tail_color = Color(0.2, 0.4, 1.0, 0.0)
			_root.add_child(tr_node)
			_shot_nodes[w.id] = {"node": m, "trail": tr_node}
		var n: Dictionary = _shot_nodes[w.id]
		var wp: Vector2 = w.pos
		n.node.position = Vector3(wp.x, 0.25, wp.y)
		n.node.rotation.y = -cos(float(w.t) * Sim.WAVE_RATE) * 0.6   # leans along its swing
		n.trail.update(Vector3(wp.x, 0.2, wp.y))
	for mi in sim.missiles:
		live[mi.id] = true
		if not _shot_nodes.has(mi.id):
			var rocket := Fx.make_missile(POWERUP_COLORS["H"])   # D-331: a rocket, not a plasma ball
			_root.add_child(rocket)
			(rocket.get_node("Thruster") as CPUParticles3D).restart()
			_shot_nodes[mi.id] = {"node": rocket, "trail": null}
		var n2: Dictionary = _shot_nodes[mi.id]
		var mp: Vector2 = mi.pos
		var mv: Vector2 = mi.vel
		n2.node.position = Vector3(mp.x, 0.25, mp.y)
		n2.node.rotation.y = -atan2(mv.x, -mv.y)   # nose along its flight
	for id in _shot_nodes.keys():
		if not live.has(id):
			_shot_nodes[id].node.queue_free()
			if _shot_nodes[id].trail != null:
				_shot_nodes[id].trail.queue_free()
			_shot_nodes.erase(id)


## D-327, D-332: the Sidekicks: the ship's own outer thirds, cut from the ship
## model by a shader (full height), fly up from below and dock at its ends;
## the catch width grows by Sim.SIDEKICK_W (a third of the ship) each side.
const SIDEKICK_FLY := 0.7   # s to fly in
const CLIP_SHADER := preload("res://games/breakout/shaders/clip_x.gdshader")


func _animate_sidekicks(delta: float) -> void:
	if not _paddle.has_meta("sidekicks"):
		var pair := []
		var scene := load(PADDLE_MODEL) as PackedScene
		var s := Sim.PADDLE_W / MODEL_PADDLE_WIDTH
		var half := MODEL_PADDLE_WIDTH * 0.5
		for side in [-1.0, 1.0]:
			var holder := Node3D.new()
			if scene:
				var model := scene.instantiate() as Node3D
				model.scale = Vector3(s, s, s)
				model.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				# Keep only this side's outer third of the ship (model X).
				for mi in model.find_children("*", "MeshInstance3D", true, false):
					var m := mi as MeshInstance3D
					var src := m.get_active_material(0) as StandardMaterial3D
					var cm := ShaderMaterial.new()
					cm.shader = CLIP_SHADER
					if src:
						cm.set_shader_parameter("albedo_tex", src.albedo_texture)
						cm.set_shader_parameter("roughness_v", src.roughness)
						cm.set_shader_parameter("metallic_v", src.metallic)
					cm.set_shader_parameter("keep_min", half / 3.0 if side > 0.0 else -100.0)
					cm.set_shader_parameter("keep_max", 100.0 if side > 0.0 else -half / 3.0)
					m.material_override = cm
				holder.add_child(model)
			else:
				holder.add_child(_box(Vector3(Sim.SIDEKICK_W, 0.2, Sim.PADDLE_H * 0.7), Vector3(side * Sim.PADDLE_W / 3.0, 0, 0), StandardMaterial3D.new()))
			var eng := Fx.ShipEngine.new(Vector3(0.0, 0.0, 1.0))   # belly burner while flying in
			eng.position = Vector3(side * Sim.PADDLE_W / 3.0, 0.0, 0.15)   # under the piece
			holder.add_child(eng)
			holder.visible = false
			_ship.add_child(holder)
			pair.append(holder)
		_paddle.set_meta("sidekicks", pair)
		_paddle.set_meta("sidekick_t", 0.0)
	var on: bool = sim.padup == "K" and _phase == "play"
	var t: float = _paddle.get_meta("sidekick_t")
	# D-337: losing them (another paddle upgrade, a lost charge) sends them off
	# down the screen, burners on, instead of vanishing.
	var leave: float = _paddle.get_meta("sidekick_leave", -1.0)
	if on:
		leave = -1.0
	elif t > 0.0 and _phase == "play":
		leave = 0.0
	elif leave >= 0.0:
		leave += delta / SIDEKICK_FLY
		if leave >= 1.0:
			leave = -1.0
	_paddle.set_meta("sidekick_leave", leave)
	t = minf(1.0, t + delta / SIDEKICK_FLY) if on else 0.0
	_paddle.set_meta("sidekick_t", t)
	var e := 1.0 - pow(1.0 - t, 3.0)   # ease out: they brake as they dock
	var pair: Array = _paddle.get_meta("sidekicks")
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var h: Node3D = pair[i]
		h.visible = on or leave >= 0.0
		# The piece is the ship's outer third; moved out by a third it sits
		# just beyond the ship's end.
		var dock := Vector3(side * Sim.PADDLE_W / 3.0, 0.0, 0.0)
		var burn := 1.0 - e
		if leave >= 0.0:   # accelerating away, peeling outwards
			var k := leave * leave
			h.position = dock + Vector3(side * 0.8, 0.0, 6.0) * k
			burn = 1.0
		else:
			h.position = dock + Vector3(side * 0.6, 0.0, 5.0) * (1.0 - e)
		(h.get_child(h.get_child_count() - 1) as Fx.ShipEngine).set_thrust(burn)
	# The ball-hit shield spreads over the docked sidekicks too.
	if _paddle.has_meta("shield_node"):
		var reach := 1.0 + (Sim.SIDEKICK_W * 2.0 / Sim.PADDLE_W) * (e if on else 0.0)
		(_paddle.get_meta("shield_node") as Node3D).scale.x = reach


## D-326: the Nuclear power-up's flash: the TABLE goes white and fades out.
func _nuke_flash() -> void:
	var f := ColorRect.new()
	f.color = Color(1.0, 0.95, 0.85, 0.9)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_table(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_callback(f.queue_free)


## Score, lives (plasma dots) and blast power are shown only on the DMD (D-051).
	if _two:
		_view_use(0)


func _refresh_status() -> void:
	if _shown_score != sim.score:
		_shown_score = sim.score
		score_changed.emit(0, sim.score)
	if _finale_t >= 0.0 or _phase != "play":
		return  # the finale / attract / intro own the DMD
	if _two:   # D-287: a power bar for each player
		var bars := []
		for i in 2:
			var pu2: String = sim.player_get(i, "powerup")
			var c2: Color = POWERUP_COLORS.get(pu2, Dmd.YELLOW)
			var low: float = _low_power_t if i == _vship else float(_vs[i]._low_power_t)
			var enabled := true   # D-327: paddle upgrades never stop the blaster
			# No power-up: the badge slot shows the player's number instead.
			bars.append({"value": sim.player_get(i, "power"), "color": c2,
				"badge": pu2 if not pu2.is_empty() else str(i + 1),
				"badge_color": c2 if not pu2.is_empty() else Dmd.DIM, "bar": enabled, "warn": low > 0.0})
		Dmd.show_status_two(sim.score, sim.balls_left, sim.balls_total, sim.level, bars, ACCENT)
		return
	var pu: String = sim.powerup
	var pcol: Color = POWERUP_COLORS.get(pu, Dmd.YELLOW)
	Dmd.show_status(sim.score, sim.balls_left, sim.balls_total,
		sim.power, 3, ACCENT, pcol, sim.level, pu, pcol, sim.blasts_enabled(), _low_power_t > 0.0,
		sim.padup, POWERUP_COLORS.get(sim.padup, Dmd.WHITE))   # D-327: the paddle slot's badge


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
	# D-267: tell the single-screen layout how wide the play area is (its field
	# plus the edge shields and a margin), so the side panels stay clear of it.
	# The camera is orthographic, 16 units high: half width / TABLE width.
	if Screens.side_panels:
		var b := Vector2(Screens.table_base())
		Screens.set_play_half_width((sim.field.size.x * 0.5 + PLAY_MARGIN) / (16.0 * b.x / b.y))
	_refresh_status()  # DMD power bar changes continuously
	_update_backglass_lights(delta)
	# "PLASMA CANNON READY" blinks while waiting to fire (D-059).
	if _hint != null and _phase != "play":
		_hint.visible = false
	if _hint != null and _hint.visible:
		_hint.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5 else 0.0
		if sim.serve_lock > 0.0:   # D-344: not ready until the relaunch lock ends
			_hint.modulate.a = 0.0
	_update_danger()   # D-322
	_animate_blasts(delta)
	_animate_enemies(delta)
	_animate_powerups(delta)
	_animate_shots(delta)   # D-327
	_animate_backdrop(delta)   # D-343
	_animate_boss(delta)   # D-335
	_animate_ships(delta)   # D-286: each ship's own visuals
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


## D-286: one ship's visuals, for the ship whose state and nodes are live
## (sim._use / _view_use): position, banking, engines, blinking, its shield
## flash and recoil, the charge glow, Lightspeed ghosts, the recharge flash.
func _animate_ship(delta: float) -> void:
	_low_power_t = maxf(0.0, _low_power_t - delta)
	_paddle.position = Vector3(sim.paddle_x, 0.0, sim.paddle_y)
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
	# Ship respawn: hidden briefly after being destroyed, then blinks while invulnerable.
	if _phase == "attract" or _phase == "select" or _phase == "players" or _phase == "level":
		_paddle.visible = false
	elif _phase == "intro":
		pass  # positioned and shown by _intro()
	elif sim.ship_invulnerable > 0.0:
		var since := Sim.SHIP_INVULNERABLE - sim.ship_invulnerable
		_paddle.visible = since > 0.6 and fmod(Time.get_ticks_msec() / 1000.0, 0.2) < 0.13
	else:
		_paddle.visible = true
	_animate_sidekicks(delta)   # D-327
	# Shield flash
	_shield_age += delta
	_shield_mat.set_shader_parameter("age", _shield_age)
	_shield_mat.set_shader_parameter("strength", clampf(1.0 - _shield_age / SHIELD_FADE, 0.0, 1.0))
	# Firing recoil: kick back towards the player + decaying shake.
	_recoil = maxf(0.0, _recoil - delta / RECOIL_SECONDS)
	var r := _recoil * _recoil
	_ship.position = Vector3(randf_range(-1.0, 1.0) * RECOIL_SHAKE * r, 0.0,
		RECOIL_KICK * r + randf_range(-1.0, 1.0) * RECOIL_SHAKE * r)
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
			_ghost_nodes[i].position = Vector3(gx[i], 0.0, sim.paddle_y)
	# Charging (D-053, D-054): particles in the colour of the level being charged
	# converge in front of the nose; the sphere shows the level already reached
	# (small blue, medium yellow, full-size red).
	var reached := int(floor(sim.blast_charge + 0.0001))
	var charging := sim.blast_charge > 0.0 or (sim.state == Sim.State.PLAY and CabinetInput.is_down(CabinetInput.for_player(&"flip_l", _vship)) \
		and CabinetInput.is_down(CabinetInput.for_player(&"flip_r", _vship))) or (sim.state == Sim.State.PLAY and sim.charge_held)
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
		# D-327: an upgrade charges in its own colour (one level only).
		_charge_particles.color = POWERUP_COLORS[sim.powerup] if POWERUP_COLORS.has(sim.powerup) else LEVEL_COLORS[reached]
	_charge_glow.visible = reached >= 1 and sim.powerup.is_empty()
	if reached >= 1:
		if _charge_level_shown != reached:
			_charge_level_shown = reached
			Fx.tint_plasma(_charge_glow, LEVEL_COLORS[reached - 1])
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.03)
		_charge_glow.scale = Vector3.ONE * LEVEL_SPHERE_SCALE[reached - 1] * pulse
	else:
		_charge_level_shown = 0

	_animate_recharge_flash(delta)


# --- level select (D-336) ---------------------------------------------------------------
## After 1 PLAYER / 2 PLAYERS: the level to start on, 1..10 (wrapping), with
## the flippers; LAUNCH goes on to the difficulty.
var _level_ui: Control
var _level_sel := 1
var _level_num: Label
var _level_info: Label


func _enter_level() -> void:
	_phase = "level"
	_phase_t = 0.0
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_sfx("select")
	Dmd.play(Callable(), 0.0)
	_level_sel = 1
	_level_ui = UI.vstack(50)
	_level_ui.add_child(UI.styled_label(tr("TB_START_LEVEL"), TITLE_FONT, 2))
	_level_num = UI.label("", 192, UI.YELLOW)
	_level_ui.add_child(_level_num)
	_level_info = UI.label("", 48, UI.WHITE)
	_level_ui.add_child(_level_info)
	_level_ui.add_child(UI.label(tr("TB_SELECT_HINT"), 36, UI.CYAN))
	add_to_table(_level_ui)
	_refresh_level()


func _move_level(step: int) -> void:
	_phase_t = 0.0
	_level_sel = wrapi(_level_sel + step, 1, Sim.LEVEL_FILES.size() + 1)
	_sfx("move")
	_refresh_level()


func _refresh_level() -> void:
	_level_num.text = "< %d >" % _level_sel
	var boss := _level_sel % Sim.BOSS_EVERY == 0
	_level_info.text = tr("TB_BOSS_LEVEL") if boss else ""
	_level_info.add_theme_color_override("font_color", UI.RED)
	Dmd.show_text(tr("TB_LEVEL") % _level_sel, tr("TB_BOSS_LEVEL") if boss else tr("TB_SELECT_HINT_DMD"),
		Dmd.YELLOW, Dmd.RED if boss else Dmd.WHITE)


func _confirm_level() -> void:
	if is_instance_valid(_level_ui):
		_level_ui.queue_free()
	if _level_sel != sim.level:
		sim.level = _level_sel
		sim.build_rack()
		sim._enemy_timer = Sim.ENEMY_FIRST_SPAWN / (1.0 + Sim.ENEMY_TIER_RATE * sim.enemy_tier())
		_build_bricks()
		for n in _brick_nodes:   # the intro drops them in
			n.visible = false
		_apply_backdrop()   # D-343
	_enter_select()


# --- 2 players (D-286) ------------------------------------------------------------------
func _enter_players() -> void:
	_phase = "players"
	_phase_t = 0.0
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_sfx("select")
	Dmd.play(Callable(), 0.0)
	_players_ui = UI.vstack(70)
	_players_rows.clear()
	for k in ["TB_ONE_PLAYER", "TB_TWO_PLAYERS"]:
		var l := UI.label(tr(k), 96, UI.WHITE)
		_players_ui.add_child(l)
		_players_rows.append(l)
	_players_ui.add_child(UI.label(tr("TB_SELECT_HINT"), 36, UI.CYAN))
	add_to_table(_players_ui)
	_refresh_players()


func _refresh_players() -> void:
	for i in _players_rows.size():
		var l: Label = _players_rows[i]
		var on := i == _players_sel
		var t := tr(["TB_ONE_PLAYER", "TB_TWO_PLAYERS"][i])
		l.text = ("> %s <" % t) if on else t
		l.add_theme_color_override("font_color", UI.YELLOW if on else UI.WHITE)
		l.modulate.a = 1.0 if on else 0.45
	Dmd.show_text(tr(["TB_ONE_PLAYER", "TB_TWO_PLAYERS"][_players_sel]), "", Dmd.YELLOW, Dmd.WHITE)


func _confirm_players() -> void:
	if is_instance_valid(_players_ui):
		_players_ui.queue_free()
	if _players_sel == 1:
		_go_two()
	_enter_level()   # D-336


## Switches to a 2-player game: player 2's controls, the 2P simulation on the
## wide field, its bricks and edge shields, a second ship and the energy bars.
func _go_two() -> void:
	if _two:
		return
	CabinetInput.set_two_player(true)
	sim = Sim.new()
	sim.setup_two(int(Config.get_value("operator", "balls_per_game")), _start_difficulty())
	_build_bricks()
	for n in _root.get_children():
		if n.has_meta("edge_shield"):
			n.queue_free()
	_edge_shields.clear()
	_build_edge_shields()
	if is_instance_valid(_shield_node):
		_shield_node.queue_free()
	_shield_node = null
	# Player 2's ship: the same build, into its own set of view fields.
	_two = true
	for f in VIEW_FIELDS:
		_vs[0][f] = get(f)
	_vs[1] = _vs[0].duplicate()
	_vship = 1
	_engines = []
	_belly_engines = []
	_ghost_nodes = []
	_recharge_flash = 0.0
	_last_power_step = -1
	_charge_level_shown = 0
	_dash_glow = 0.0
	_recoil = 0.0
	_shield_age = 99.0
	_build_ship(StandardMaterial3D.new())
	for l in _paddle.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).light_color = Color(1.0, 0.6, 0.3)   # player 2's warm key light
	for f in VIEW_FIELDS:
		_vs[1][f] = get(f)
	_vship = 0
	for f in VIEW_FIELDS:
		set(f, _vs[0][f])
	_build_p2_bars()


## Each player's energy bar on the TABLE, at the bottom corners (2P).
func _build_p2_bars() -> void:
	_p2_bars.clear()
	for i in 2:
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UI.label(tr("TB_P%d" % (i + 1)), 36, [Color(0.5, 0.8, 1.0), Color(1.0, 0.65, 0.35)][i])
		box.add_child(l)
		var bg := ColorRect.new()
		bg.custom_minimum_size = Vector2(240, 22)
		bg.color = Color(0.1, 0.1, 0.15, 0.8)
		var fill := ColorRect.new()
		fill.size = Vector2(0, 22)
		bg.add_child(fill)
		box.add_child(bg)
		box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if i == 0 else Control.PRESET_BOTTOM_RIGHT)
		box.offset_left = 30.0 if i == 0 else -270.0
		box.offset_right = 270.0 if i == 0 else -30.0
		box.offset_top = -100.0
		box.offset_bottom = -30.0
		add_to_table(box)
		_p2_bars.append([box, fill, l])


func _update_p2_bars() -> void:
	for i in _p2_bars.size():
		var fill: ColorRect = _p2_bars[i][1]
		var pw: float = sim.player_get(i, "power")
		var pu: String = sim.player_get(i, "powerup")
		fill.size.x = 240.0 * pw
		fill.color = POWERUP_COLORS.get(pu, Color(0.4, 0.75, 1.0) if i == 0 else Color(1.0, 0.6, 0.3))
		var pad: String = sim.player_get(i, "padup")
		(_p2_bars[i][2] as Label).text = tr("TB_P%d" % (i + 1)) + ("  " + pu if not pu.is_empty() else "") \
			+ ("  " + pad if not pad.is_empty() else "")
		(_p2_bars[i][0] as Control).visible = _phase == "play"


## Runs _animate_ship for each ship (2P: both, D-286).
func _animate_ships(delta: float) -> void:
	for i in (2 if _two else 1):
		_view_use(i)
		_animate_ship(delta)
	_view_use(0)
	if _two:
		_update_p2_bars()


## D-286: makes ship i's nodes and view state live (and its sim state).
const VIEW_FIELDS := ["_paddle", "_ship", "_recharge_mat", "_engines", "_shield_mat", "_belly_engines",
	"_charge_particles", "_charge_glow", "_dash_glow", "_recoil", "_shield_age", "_ghost_nodes",
	"_recharge_flash", "_last_power_step", "_charge_level_shown", "_low_power_t"]
var _two := false
var _vship := 0
var _vs := [{}, {}]


func _view_use(i: int) -> void:
	sim._use(i)
	if not _two or i == _vship:
		return
	for f in VIEW_FIELDS:
		_vs[_vship][f] = get(f)
	for f in VIEW_FIELDS:
		set(f, _vs[i][f])
	_vship = i


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
	_planet_horizon = _planet
	_build_space_backdrop(cam.global_transform.basis, target)

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
## D-263: the field's edge shields always glow faintly, so the play area reads
## on a wide screen (D-262).
const EDGE_IDLE := 0.10   # D-269: 10 % (was 5 %, D-263)
const PLAY_MARGIN := 0.9   # units beyond the field the panels keep clear of (D-267)


func _build_edge_shields() -> void:
	var f := sim.field
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
		mat.set_shader_parameter("idle", EDGE_IDLE)   # D-263: always faintly there
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = spec[1]
		m.rotation_degrees = Vector3(0.0, spec[2], 0.0)
		m.set_meta("edge_shield", true)
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
		var eng := Fx.ShipEngine.new(Vector3(side, 0.0, 0.0), SIDE_THRUST_BRIGHTNESS)   # D-344: darker
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
	_paddle.set_meta("shield_node", shield)   # D-332: widened over the sidekicks
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
		var col: int = b.get("col", i % sim.cols)
		var size := Vector3(r.size.x, 0.3, r.size.y)
		var colour: String = LETTER_COLOUR.get(b.get("colour", "B"), "blue")  # X uses blue art, shown as metal
		var n := _box(size, Vector3(r.get_center().x, 0, r.get_center().y), _brick_material(colour, size))
		_randomize_crop(n)
		# Pulse ripples diagonally across the swarm, with a little jitter.
		InstParam.set_param(n, "phase", -(col * 0.55 + b.row * 0.8) + float((i * 37) % 11) * 0.08)
		InstParam.set_param(n, "mode", 3.0 if b.get("metal", false) else (4.0 if b.get("charged", false)
			else (1.0 if b.get("armoured", false) else 0.0)))   # D-342: 4 = charged
		if b.get("plasma", false):   # D-342: its captured plasma ball, on show
			var pb := Fx.make_plasma_ball(Sim.BALL_R * 0.8)
			pb.position = Vector3(0.0, 0.2, 0.0)
			n.add_child(pb)
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
	var c := Vector3(0.0, 0.3, (sim.field.position.y + Sim.PADDLE_Y) * 0.5)
	_explode_brick(c, Color(1.0, 0.5, 0.2))   # blast + debris; frees itself
	var cap := Fx.PowerupCapsule.new("T", POWERUP_COLORS["T"], Sim.POWERUP_R)
	cap.position = c + Vector3(-2.0, 0.0, 0.0)
	out.append(cap)
	var tet := Fx.make_tetrahedron(Sim.ENEMY_R * 1.5,
		load("res://assets/textures/breakout/circuit_red.png"), CIRCUIT_GLOW["red"])
	tet.position = c + Vector3(2.0, 0.0, 0.0)
	out.append(tet)
	var cube := Fx.make_cube(Sim.ENEMY_R * 1.5,
		load("res://assets/textures/breakout/circuit_blue.png"), CIRCUIT_GLOW["blue"])
	cube.position = c + Vector3(2.0, 0.0, 0.8)
	out.append(cube)
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
	_build_danger()


## D-322: "DANGER / PROXIMITY ALERT" in see-through red, blinking in the middle
## of the play area while an enemy is in the bottom 20% of the field. Warning
## triangles are drawn (PinPixel has no warning sign).
const DANGER_COL := Color(1.0, 0.16, 0.2, 0.62)
const DANGER_MARGIN := 0.45      # m the enemy must climb back above the line
var _danger: Control
var _danger_on := false


class WarnSign extends Control:
	var col := Color.RED
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(w * 0.5, 0.0), Vector2(w, h), Vector2(0.0, h)])
		draw_colored_polygon(pts, col)
		var k := Color(0.0, 0.0, 0.0, 0.55)
		draw_rect(Rect2(w * 0.44, h * 0.3, w * 0.12, h * 0.38), k)
		draw_rect(Rect2(w * 0.44, h * 0.76, w * 0.12, h * 0.12), k)


func _build_danger() -> void:
	_danger = Control.new()
	_danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sized to the TABLE's height (the camera shows 16 units over it): the single
	# screen's landscape TABLE has a narrower play area in base pixels.
	var k := float(Screens.table_base().y) / 1920.0
	var v := UI.vstack(roundi(18 * k))
	_danger.add_child(v)
	# Centred a little above the middle, clear of PLASMA CANNON READY (which
	# sits mid-screen on the single screen's short TABLE).
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_bottom = -float(Screens.table_base().y) * 0.2
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", roundi(28 * k))
	v.add_child(row)
	for part in ["sign", "text", "sign"]:
		if part == "text":
			row.add_child(UI.label(tr("TB_DANGER"), roundi(120 * k), DANGER_COL))
		else:
			var s := WarnSign.new()
			s.col = DANGER_COL
			s.custom_minimum_size = Vector2(96, 84) * k
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(s)
	v.add_child(UI.label(tr("TB_PROXIMITY_ALERT"), roundi(72 * k), DANGER_COL))
	_danger.visible = false
	add_to_table(_danger)


func _update_danger() -> void:
	if _danger == null:
		return
	var playing := _phase == "play" and _finale_t < 0.0 and sim.state != Sim.State.OVER
	_danger_on = playing and sim.enemy_in_danger(DANGER_MARGIN if _danger_on else 0.0)
	_danger.visible = _danger_on
	if _danger_on:
		_danger.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.38 else 0.0


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
		_sfx("tb_blast3")
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
	# D-267: the game's logo above PRESS START (was the title in its font).
	var logo := TextureRect.new()
	logo.texture = load("res://assets/textures/breakout/logo.png")
	logo.custom_minimum_size = Vector2(760, 520)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_attract_ui.add_child(logo)
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
		# D-321: the extra-charge scores
		[func(): Dmd.show_text(tr("TB_EXTRA_CHARGE_AT"), "  ".join(Sim.EXTRA_LIFE_AT.map(
			func(v): return ScoreTable.format_score(int(v)))), Dmd.CYAN, Dmd.YELLOW), 2.0],
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
	_sfx("select")
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
		_sfx("error")
		return
	_select_index = i
	_sfx("move")
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


# --- levels 11-20 backdrop (D-343) -------------------------------------------------------
## Earth seen from further out: its curve fills the bottom-left corner and runs
## under the ship; a grey moon orbits slowly at the top right; now and then a
## dimmed alien ship crosses far behind, thrusters trailing particles.
const SPACE_EARTH_R := 10.0
const SPACE_EARTH_AT := Vector2(-5.0, -14.2)   # view units from the view centre: its rim just under the ship
const SPACE_MOON_R := 1.4
const SPACE_FLYBY := Vector2(8.0, 16.0)        # s between ships (D-345: they linger longer now)
## D-345: fly-bys are far off: tiny, slow, dim, behind the Earth and the moon.
const FLYBY_SCALE := 0.35
const FLYBY_DEPTH := Vector2(40.0, 60.0)
const FLYBY_SPEED := Vector2(0.5, 1.0)
var _planet_horizon: Fx.Planet
var _planet_space: Fx.Planet
var _moon: Fx.Planet
var _space_on := false
var _space_t := 0.0
var _flyby_in := 3.0
var _flybys: Array = []   # {node, vel}
var _view_basis: Basis
var _view_target: Vector3
const MOON_PARALLAX := 0.08     # D-345: of the near stars' swing
const MOON_RETURN := 0.6        # 1/s it eases back to its spot
const STAR_PIVOT_DIST := 48.0   # view units from the top of the view to the stars' pivot (3 TABLE heights)
var _moon_sway := 0.0


func _build_space_backdrop(basis: Basis, target: Vector3) -> void:
	_view_basis = basis
	_view_target = target
	_planet_space = Fx.Planet.new(SPACE_EARTH_R)
	_planet_space.restyle({"detail_scale": 0.7}, Color(0.3, 0.6, 1.0), 1.6)
	_planet_space.place_at(basis, target, SPACE_EARTH_AT, 24.0)
	_planet_space.visible = false
	_root.add_child(_planet_space)
	_moon = Fx.Planet.new(SPACE_MOON_R)
	_moon.restyle({"detail_scale": 2.6, "sea_level": 0.48, "softness": 0.25,
		"deep_sea": Color(0.32, 0.32, 0.34), "shallow_sea": Color(0.42, 0.42, 0.44),
		"lowland": Color(0.55, 0.55, 0.56), "highland": Color(0.7, 0.69, 0.66),
		"atmosphere": Color(0.5, 0.5, 0.55), "atmosphere_glow": 0.6, "cloud_amount": 0.0},
		Color(0.6, 0.6, 0.65), 0.35)
	_moon.visible = false
	_root.add_child(_moon)
	_apply_backdrop()


## Levels 11-20 (of each 20) use the space backdrop; the others the horizon.
func _apply_backdrop() -> void:
	if _planet_space == null:
		return
	var on := (sim.level - 1) % 20 >= 10
	_space_on = on
	_planet_horizon.visible = not on
	_planet_space.visible = on
	_moon.visible = on
	_planet = _planet_space if on else _planet_horizon   # drains hit the visible one
	if not on:
		for f in _flybys:
			(f.node as Node).queue_free()
		_flybys.clear()


func _view_half_width() -> float:
	var b := Vector2(Screens.table_base())
	return 8.0 * b.x / b.y


func _animate_backdrop(delta: float) -> void:
	if not _space_on:
		return
	_space_t += delta
	# The moon: a slow orbit (an ellipse about its spot, 2 minutes round) and spin.
	var hw := _view_half_width()
	var base := Vector2(minf(6.4, hw - 1.6), 4.6)
	var a := _space_t * TAU / 120.0
	# D-345: it swings a little with the starfield (the ship's movement), much
	# less than the stars, and eases back: a far, slow parallax.
	_moon_sway += _star_spin * MOON_PARALLAX * delta
	_moon_sway *= exp(-MOON_RETURN * delta)
	var sway := Vector2(-_moon_sway * STAR_PIVOT_DIST, 0.0)
	_moon.place_at(_view_basis, _view_target, base + Vector2(cos(a) * 1.1, sin(a) * 0.45) + sway, 18.0 - sin(a) * 2.0)
	_moon.rotate_y(delta * 0.05)
	_planet_space.rotate_y(delta * 0.01)
	# Fly-bys, far behind and dimmed.
	_flyby_in -= delta
	if _flyby_in <= 0.0:
		_flyby_in = randf_range(SPACE_FLYBY.x, SPACE_FLYBY.y)
		_spawn_flyby(hw)
	for i in range(_flybys.size() - 1, -1, -1):
		var f: Dictionary = _flybys[i]
		var node: Node3D = f.node
		node.position += f.vel * delta
		(node.get_child(0) as Node3D).rotate(Vector3(0.3, 1.0, 0.2).normalized(), delta * 1.2)
		if f.t_left <= 0.0:
			node.queue_free()
			_flybys.remove_at(i)
		f.t_left = float(f.t_left) - delta


func _spawn_flyby(hw: float) -> void:
	var from_left := randf() < 0.5
	var y0 := randf_range(-1.0, 6.5)
	var y1 := y0 + randf_range(-2.0, 2.0)
	var x0 := -(hw + 2.0) if from_left else hw + 2.0
	var p0 := Vector2(x0, y0)
	var p1 := Vector2(-x0, y1)
	var speed := randf_range(FLYBY_SPEED.x, FLYBY_SPEED.y)
	var dur := p0.distance_to(p1) / speed
	var depth := randf_range(FLYBY_DEPTH.x, FLYBY_DEPTH.y)
	var start := _view_target + _view_basis.x * p0.x + _view_basis.y * p0.y - _view_basis.z * depth
	var vel := (_view_basis.x * (p1.x - p0.x) + _view_basis.y * (p1.y - p0.y)) / dur
	var root := Node3D.new()
	root.position = start
	var tex: Texture2D = load("res://assets/textures/breakout/circuit_%s.png" % ["red", "yellow", "green", "blue"][randi() % 4])
	var r := Sim.ENEMY_R * 1.5 * FLYBY_SCALE * randf_range(0.8, 1.2)
	var body: Node3D
	match randi() % 3:
		0: body = Fx.make_tetrahedron(r, tex, Color(0.6, 0.4, 0.9))
		1: body = Fx.make_cube(r, tex, Color(0.4, 0.7, 0.9))
		_: body = Fx.make_icosahedron(r, tex, Color(1.0, 0.3, 0.3), 0.6)
	root.add_child(body)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).transparency = 0.72   # dimmed: background, not a threat
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.7
	p.local_coords = false
	p.direction = -vel.normalized()
	p.spread = 10.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.5
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.5, 0.4, 0.6))
	grad.set_color(1, Color(0.2, 0.15, 0.12, 0.0))
	grad.add_point(0.3, Color(0.5, 0.28, 0.1, 0.45))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = pm
	p.mesh = q
	p.position = -vel.normalized() * r
	root.add_child(p)
	_root.add_child(root)
	p.restart()
	_flybys.append({"node": root, "vel": vel, "t_left": dur + 1.0})


func _begin_intro() -> void:
	# Game music (D-081): "n-Dimensions (Retro)" by Matthew Pablo, CC BY 3.0.
	Audio.play_music(MUSIC)
	_phase = "intro"
	_phase_t = 0.0
	_landed = 0
	if is_instance_valid(_attract_ui):
		_attract_ui.queue_free()
	_sfx("start")
	Dmd.play(Callable(), 0.0)
	# Level 1 says GET READY; later levels announce their number (D-068).
	var title: String = tr("TB_GET_READY") if sim.level == 1 else tr("TB_LEVEL") % sim.level
	Dmd.show_text(title, tr("TB_GET_READY") if sim.level > 1 else tr("TB_TWO_PLAYERS" if _two else "DMD_PLAYER_1"), Dmd.YELLOW, Dmd.WHITE)
	if sim.is_boss_level():   # D-335
		Dmd.show_text(title, tr("TB_BOSS_WARNING"), Dmd.YELLOW, Dmd.RED)
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
			_sfx("tb_brick_land")
	var bricks_done := (_brick_nodes.size() - 1) * INTRO_BRICK_STAGGER + INTRO_BRICK_FALL
	var st := (t - bricks_done) / INTRO_SHIP_TIME
	for ship in (2 if _two else 1):   # D-286: both ships fly in together
		_view_use(ship)
		if st < 0.0:
			_paddle.visible = false
			_set_belly_thrust(0.0)
			continue
		if not _paddle.visible:
			_paddle.visible = true
			if ship == 0:
				_sfx("tb_ship_arrive")
		var e := 1.0 - pow(1.0 - clampf(st, 0.0, 1.0), 3.0)  # ease out
		_paddle.position = Vector3(sim.paddle_x, 0.0, lerpf(INTRO_SHIP_FROM_Z, sim.paddle_y, e))
		_set_belly_thrust(1.5 * (1.0 - e) + 0.1 if st < 1.0 else 0.0)
	_view_use(0)
	if st < 0.0:
		return
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
	for ship in (2 if _two else 1):
		_view_use(ship)
		_set_belly_thrust(0.0)
		_paddle.scale = Vector3.ONE
		_paddle.rotation = Vector3.ZERO
	_view_use(0)
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
var _outro_x0s: Array = []   # D-286: each ship's x at the level's end


## Level complete: remaining enemies already exploded (sim); the ship flies off
## towards the top and towards the screen, fade to black, then the next level
## plays the same intro (bricks drop in, ship blasts in).
func _begin_outro() -> void:
	_phase = "outro"
	_phase_t = 0.0
	_outro_lifted = false
	_hint.visible = false
	# Settle the ship before lift-off (D-085): the sim is paused now, so clear its
	# last speed (the per-frame banking/thrusters read it) and cut the thrusters.
	_outro_x0s.clear()
	for ship in (2 if _two else 1):
		_view_use(ship)
		_outro_x0s.append(sim.paddle_x)
		sim.paddle_vx = 0.0
		for eng in _engines:
			eng.set_thrust(0.0)
	_view_use(0)
	_outro_x0 = _outro_x0s[0]


func _outro() -> void:
	var t := _phase_t
	# Ship flies away: up the screen (-z) and up towards the camera (+y). The
	# camera is orthographic, so growing scale sells "towards the screen".
	var k := clampf((t - OUTRO_LIFT_AT) / OUTRO_LIFT_TIME, 0.0, 1.0)
	if k > 0.0 and not _outro_lifted:
		_outro_lifted = true
		DebugTools.mark("outro_lift")
		_sfx("tb_ship_arrive")
		Dmd.play(Callable(_dmd_anims, "ship_boost"), DmdAnims.DURATIONS["ship_boost"])  # D-076
	var e := k * k
	# Before lift-off the ship glides to the centre and levels out (D-085).
	var settle := smoothstep(0.0, OUTRO_LIFT_AT * 0.9, t)
	for ship in (2 if _two else 1):   # D-286: 2P: each ship to the middle of its half
		_view_use(ship)
		var to_x: float = sim._start_x(ship) if _two else sim.field.get_center().x
		var x := lerpf(_outro_x0s[ship], to_x, settle)
		_paddle.visible = true
		_paddle.position = Vector3(x, 7.0 * e, sim.paddle_y - 13.0 * e)
		_paddle.scale = Vector3.ONE * (1.0 + 2.2 * e)
		_paddle.rotation = Vector3(-0.5 * k, 0.0, 0.0)
		_set_belly_thrust(1.5 if k > 0.0 and k < 1.0 else 0.0)
	_view_use(0)
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
	_apply_backdrop()   # D-343
	_build_bricks()
	for n in _brick_nodes:
		n.visible = false
	for ship in (2 if _two else 1):
		_view_use(ship)
		_paddle.visible = false
		_paddle.scale = Vector3.ONE
		_paddle.rotation = Vector3.ZERO
	_view_use(0)
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
		"pu_name": _dmd_anims.texts.get("pu_name", ""),   # D-328: set by _dmd_pu_anim
		"extra_charge": tr("TB_EXTRA_CHARGE"),
	}
	Dmd.play(Callable(_dmd_anims, name), DmdAnims.DURATIONS[name])


## D-328: a power-up's pickup clip on the DMD, in its colour, with its name.
func _dmd_pu_anim(kind: String) -> void:
	_dmd_anims.pu_color = POWERUP_COLORS.get(kind, Dmd.YELLOW)
	_dmd_anims.texts["pu_name"] = tr("TB_PU_%s" % kind)
	_dmd_anim("pu_" + kind)


func _stop_charge_sound() -> void:
	Audio.stop_sfx(_charge_sound, _charge_sound_name)
	_charge_sound = null


func _set_belly_thrust(t: float) -> void:
	for be in _belly_engines:
		be.set_thrust(t)


# --- power-up visuals (D-072) -----------------------------------------------------------
func _spawn_powerup_node(id: int, pos: Vector2, kind: String) -> void:
	var cap := Fx.PowerupCapsule.new("1UP" if kind == "U" else kind, POWERUP_COLORS[kind], Sim.POWERUP_R,
		ATOM_ICON if kind == "N" else null, kind in Sim.PADDLE_KINDS)   # D-326, D-327: paddle upgrades are pills
	cap.position = Vector3(pos.x, 0.3, pos.y)
	_root.add_child(cap)
	_powerup_nodes[id] = cap


func _remove_powerup_node(id: int) -> void:
	if _powerup_nodes.has(id):
		_powerup_nodes[id].queue_free()
		_powerup_nodes.erase(id)


func _fire_ion_beam(x: float) -> void:
	_sfx("tb_ion")
	_recoil = 1.0
	_lights.pulse(BackglassLights.SHOTS + BackglassLights.IMPACTS, 1.0, 14.0)
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var length := Sim.PADDLE_Y - sim.field.position.y
	plane.size = Vector2(Sim.ION_BEAM_W * 1.8, length)
	m.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = ION_SHADER
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(x, 0.15, sim.field.position.y + length * 0.5)
	_root.add_child(m)
	var tw := m.create_tween()
	tw.tween_method(func(f: float): InstParam.set_param(m, "fade", f), 1.0, 0.0, 0.55)
	tw.tween_callback(m.queue_free)


## Capsules, extra plasma balls, Lightspeed afterimages, Shield barrier.
func _animate_powerups(delta: float) -> void:
	# D-325: a capsule the sim dropped without an event (cleared at a level's
	# end, or a new level / serve reset) goes too; it used to stay on screen.
	if not _powerup_nodes.is_empty():
		var live := {}
		for p in sim.powerups:
			live[p.id] = true
		for id in _powerup_nodes.keys():
			if not live.has(id):
				_remove_powerup_node(id)
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
	# Shield barrier: steady while active, flashes and fades when it saves a ball.
	if _shield_node == null:
		_shield_node = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(sim.field.size.x, 0.5)
		_shield_node.mesh = plane
		_shield_bar_mat = ShaderMaterial.new()
		_shield_bar_mat.shader = SHIELD_SHADER
		_shield_bar_mat.set_shader_parameter("shield_color", POWERUP_COLORS["S"])
		_shield_node.material_override = _shield_bar_mat
		_shield_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield_node.position = Vector3(sim.field.get_center().x, 0.06, Sim.SHIELD_Y + 0.12)
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
	var levels := roundi(1.0 / sim.shot_cost())   # D-327: a flash per shot's worth
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


# --- corrupted paddles (D-342) ---------------------------------------------------------
## A dark copy of the ship (the ship model, darkened, by the clip shader with
## nothing cut) with a red HAL eye in the middle; it warps in (grows out of a
## red flash) and flashes when hit.
var _dark_nodes := {}


func _spawn_dark_node(id: int, pos: Vector2) -> void:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.y)
	var scene := load(PADDLE_MODEL) as PackedScene
	var s := Sim.PADDLE_W / MODEL_PADDLE_WIDTH
	var mats := []
	if scene:
		var model := scene.instantiate() as Node3D
		model.scale = Vector3(s, s, s)
		model.rotation_degrees = Vector3(-90.0, 180.0, 0.0)   # facing the player
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var src := m.get_active_material(0) as StandardMaterial3D
			var cm := ShaderMaterial.new()
			cm.shader = CLIP_SHADER
			if src:
				cm.set_shader_parameter("albedo_tex", src.albedo_texture)
			cm.set_shader_parameter("tint", Color(0.22, 0.17, 0.22))
			m.material_override = cm
			mats.append(cm)
		root.add_child(model)
	var eye := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	eye.mesh = sm
	var em := ShaderMaterial.new()
	em.shader = HAL_SHADER
	eye.material_override = em
	eye.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(eye)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.1, 0.1)
	glow.omni_range = 1.6
	glow.light_energy = 1.2
	glow.position = Vector3(0.0, 0.4, 0.0)
	root.add_child(glow)
	root.scale = Vector3(0.01, 1.0, 0.01)
	_root.add_child(root)
	_explode_brick(Vector3(pos.x, 0.3, pos.y), Color(1.0, 0.15, 0.2), 1.2)   # the warp flash
	_dark_nodes[id] = {"root": root, "mats": mats, "eye": em, "flash": 0.0}


func _animate_darks(delta: float) -> void:
	for d in sim.darks:
		if not _dark_nodes.has(d.id):
			_spawn_dark_node(d.id, d.pos)
		var n: Dictionary = _dark_nodes[d.id]
		var p: Vector2 = d.pos
		var root: Node3D = n.root
		root.position = Vector3(p.x, 0.0, p.y)
		var w: float = clampf(float(d.t) / Sim.DARK_WARP, 0.0, 1.0) if d.state == "warp" else 1.0
		root.scale = Vector3(maxf(0.01, w * w), 1.0, maxf(0.01, w))
		n.flash = maxf(0.0, float(n.flash) - delta * 5.0)
		for m in n.mats:
			(m as ShaderMaterial).set_shader_parameter("tint", Color(0.22, 0.17, 0.22).lerp(Color(1.0, 0.5, 0.5), n.flash))
		(n.eye as ShaderMaterial).set_shader_parameter("glow", 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006) + n.flash)
	for id in _dark_nodes.keys():
		var alive := false
		for d in sim.darks:
			alive = alive or d.id == id
		if not alive:
			(_dark_nodes[id].root as Node).queue_free()
			_dark_nodes.erase(id)


# --- tetrahedron enemies (D-052) ------------------------------------------------------
func _spawn_enemy_node(id: int, pos: Vector2, kind: String = "tetra") -> void:
	if _circuit_textures.is_empty():
		for c in ["red", "yellow", "green", "blue"]:
			_circuit_textures.append(load("res://assets/textures/breakout/circuit_%s.png" % c))
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.3, pos.y)
	# One circuit colour per enemy (D-053).
	var pick := randi() % _circuit_textures.size()
	var colour: Color = CIRCUIT_GLOW[["red", "yellow", "green", "blue"][pick]]
	var body: Node3D
	if kind == "ico":   # D-342: a little boss: red panels, a HAL eye, its own charge sparks
		body = Fx.make_icosahedron(Sim.ENEMY_R * 1.5, _circuit_textures[0], Color(1.0, 0.25, 0.3), 0.5)
	elif kind == "cube":
		body = Fx.make_cube(Sim.ENEMY_R * 1.5, _circuit_textures[pick], colour)   # D-323
	else:
		body = Fx.make_tetrahedron(Sim.ENEMY_R * 1.5, _circuit_textures[pick], colour)
	body.scale = Vector3.ONE * 0.01
	root.add_child(body)
	var extra := {}
	if kind == "ico":
		colour = Color(1.0, 0.25, 0.3)
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		eye.mesh = sm
		var em := ShaderMaterial.new()
		em.shader = HAL_SHADER
		eye.material_override = em
		eye.scale = Vector3.ONE * 0.01
		root.add_child(eye)
		var ch := Fx.make_charge_particles(0.7, Color(1.0, 0.15, 0.1))
		ch.position = Vector3(0.0, 0.3, 0.0)
		root.add_child(ch)
		extra = {"eye": eye, "eye_mat": em, "charge": ch, "charge_t": 0.0}
	_root.add_child(root)
	var hole := Fx.make_wormhole(1.7)
	hole.position = Vector3(pos.x, 0.25, pos.y)
	_root.add_child(hole)
	var tw := hole.create_tween()
	tw.tween_method(func(o: float): InstParam.set_param(hole, "open", o), 0.0, 1.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(1.2, 2.2)
	_enemy_nodes[id] = {"root": root, "body": body, "spin": spin, "hole": hole, "colour": colour}
	_enemy_nodes[id].merge(extra)


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
		if n.has("eye"):   # D-342: the mini-icosahedron's eye glows up as it charges
			(n.eye as Node3D).scale = body.scale
			n.charge_t = maxf(0.0, float(n.charge_t) - delta)
			(n.eye_mat as ShaderMaterial).set_shader_parameter("glow", (1.0 - n.charge_t / Sim.MINI_CHARGE) * 1.5 if n.charge_t > 0.0 else 0.0)
			if n.charge_t <= 0.0 and (n.charge as CPUParticles3D).emitting:
				(n.charge as CPUParticles3D).emitting = false
	_animate_darks(delta)   # D-342


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
	if _two:
		CabinetInput.set_two_player(false)   # D-286: player 2's keys go back to 1P
	if _portrait_req:
		Screens.want_side_panels(false, null, self)   # D-265; D-319: only if still ours
	super._exit_tree()
