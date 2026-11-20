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
const BLAST_SHADER = preload("res://games/breakout/shaders/blast.gdshader")
const DmdAnims = preload("res://games/breakout/dmd_anims.gd")
const STARFIELD_SHADER = preload("res://games/breakout/shaders/starfield.gdshader")

const ACCENT := Color("3ec7ff")
const PADDLE_MODEL := "res://assets/models/breakout/paddle.glb"
const MODEL_PADDLE_WIDTH := 1.9  # paddle.glb's native length along X
const ENGINE_X := 0.74           # engine nozzles, after scaling to PADDLE_W
## Brick textures (D-045): the director's circuit_<colour>.png, downsampled to
## 512 px (scripts/tools/prepare_circuit_textures.py). Each brick shows its own
## random rectangle. Rows top->bottom (until stage layouts, M2 step 3):
## red, red, yellow, green, blue, blue.
const CIRCUIT_COLOURS := ["red", "red", "yellow", "green", "blue", "blue"]
const CIRCUIT_GLOW := {"red": Color("ff5a32"), "yellow": Color("ffd23e"), "green": Color("4dff6a"), "blue": Color("3ec7ff")}
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
## Blast charge levels (D-054): particle/sphere/bolt colour and sphere size.
const LEVEL_COLORS := [Color(0.35, 0.65, 1.0), Color(1.0, 0.85, 0.25), Color(1.0, 0.3, 0.2)]
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
	"tb_fire": {"voices": [  # plasma shot: laser zap + breathy burst
		[{"f": [2400.0, 260.0], "t": 0.22, "w": "pulse12", "v": 0.22}],
		[{"f": [3000.0, 600.0], "t": 0.1, "w": "noise", "v": 0.12, "lp": 0.4}]], "echo": ECHO},
	"tb_shield": {"voices": [  # energy shield "bwong"
		[{"f": [330.0, 880.0], "t": 0.14, "w": "triangle", "v": 0.4, "vib": [30.0, 0.5]}],
		[{"f": [1760.0, 1760.0], "t": 0.1, "w": "pulse25", "v": 0.08, "arp": [0, 12, 7], "arp_rate": 40.0}]],
		"echo": [0.06, 0.25, 0.5]},
	"tb_brick": {"voices": [  # crunchy chip break
		[{"f": [5000.0, 700.0], "t": 0.13, "w": "lfsr", "v": 0.2}],
		[{"f": [880.0, 1760.0], "t": 0.05, "w": "square", "v": 0.14}]], "crush": 8},
	"tb_explode": {"voices": [
		[{"f": [1600.0, 70.0], "t": 0.9, "w": "lfsr", "v": 0.4, "lp": 0.55}],
		[{"f": [90.0, 30.0], "t": 0.6, "w": "sine", "v": 0.5}]], "echo": [0.11, 0.3, 0.5]},
	"tb_explode_big": {"voices": [
		[{"f": [2200.0, 40.0], "t": 2.0, "w": "lfsr", "v": 0.45, "lp": 0.6, "env": "lin"}],
		[{"f": [110.0, 25.0], "t": 1.6, "w": "sine", "v": 0.6}],
		[{"f": [600.0, 50.0], "t": 1.2, "w": "noise", "v": 0.2, "lp": 0.8}]], "echo": [0.14, 0.4, 0.6]},
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
		"echo": ECHO, "crush": 9},
	"tb_ship_die": {"voices": [
		[{"f": [1800.0, 50.0], "t": 1.2, "w": "lfsr", "v": 0.45, "lp": 0.5}],
		[{"f": [140.0, 30.0], "t": 1.0, "w": "sine", "v": 0.55}],
		[{"f": [880.0, 110.0], "t": 0.6, "w": "saw", "v": 0.15, "vib": [20.0, 1.0]}]], "echo": [0.12, 0.35, 0.6]},
	"tb_low_power": {"voices": [[{"f": [220.0, 220.0], "t": 0.08, "w": "pulse25", "v": 0.2, "env": "hold", "gap": 0.04},
		{"f": [165.0, 165.0], "t": 0.16, "w": "pulse25", "v": 0.2}]]},
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
var _charge_glow: Node3D
var _charge_particles: CPUParticles3D
var _charge_level_shown := 0
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
	if Config.cli.has("tb-enemy-now"):  # dev: first enemy right after firing
		sim._enemy_timer = 0.3
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
	if Config.cli.has("tb-dmd-anim") and not Dmd.is_animating():  # dev: loop one DMD animation
		_dmd_anim(str(Config.cli["tb-dmd-anim"]))
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
				Audio.sfx("tb_shield")
				_flash_edge_shield(e[1][0], e[1][1])
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
			"charge_start":
				Audio.sfx("tb_charge%d" % int(e[1]))
			"charged":
				Audio.sfx("tb_level%d" % int(e[1]))
			"blast":
				var blevel: int = e[1][1]
				Audio.sfx("tb_blast%d" % blevel)
				_recoil = 0.5 + 0.25 * blevel
				_spawn_blast_node(blevel)
			"blast_fail":
				Audio.sfx("tb_low_power")
				Dmd.flash(tr("TB_LOW_POWER"), 1.0, Dmd.RED)
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
				if e[1][2]:  # shot down (not a ship collision)
					_dmd_anims.enemy_color = ecol
					_dmd_anim("tetra_hit")
			"ship_destroyed":
				var sp: Vector2 = e[1]
				Audio.sfx("tb_ship_die")
				_explode_brick(Vector3(sp.x, 0.2, sp.y), Color(0.4, 0.8, 1.0), 2.6)
				_trail.clear()
				if sim.state == Sim.State.OVER:
					_planet._spawn_fireball(Vector3(sp.x, 0.5, sp.y), 18.0, 1.1, 99.0)
				else:
					_dmd_anim("ship_destroyed")
					_hint.visible = true
			"rack_clear":
				Audio.sfx("tb_rack")
				_dmd_anim("rack_clear")
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
	if _finale_t >= 0.0:
		return  # the finale owns the DMD
	Dmd.show_status(sim.score, sim.balls_left, int(Config.get_value("operator", "balls_per_game")),
		sim.power, 3, ACCENT)


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
	_animate_blasts(delta)
	_animate_enemies(delta)
	# Ship respawn: hidden briefly after being destroyed, then blinks while invulnerable.
	if sim.ship_invulnerable > 0.0:
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
	blast.set_instance_shader_parameter("seed", randf() * 100.0)
	_root.add_child(blast)
	var tw := blast.create_tween()
	tw.tween_method(func(a: float): blast.set_instance_shader_parameter("age", a), 0.0, 1.0, 0.45)
	tw.tween_callback(blast.queue_free)

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(28 * size_scale)
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
	p.emission_box_extents = Vector3(0.3, 0.05, 0.12) * size_scale
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
## The TABLE stays clean: status lives on the DMD (D-051); only the fire hint here.
func _build_hud() -> void:
	_hint = UI.label(tr("TB_PRESS_LAUNCH"), 52, UI.WHITE)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -560
	_hint.offset_left = -400
	_hint.offset_right = 400
	add_to_table(_hint)


## Plays one of the Tilt Breaker DMD pixel animations (D-056), unless the
## game-over finale owns the DMD.
func _dmd_anim(name: String) -> void:
	if _finale_t >= 0.0 or sim.state == Sim.State.OVER:
		return
	_dmd_anims.texts = {
		"plus_enemy": "+%d" % Sim.ENEMY_POINTS,
		"incoming": tr("TB_DMD_INCOMING"),
		"charge_lost": tr("TB_CHARGE_LOST"),
		"ship_destroyed": tr("TB_SHIP_DESTROYED"),
		"rack_clear": tr("DMD_RACK_CLEAR"),
		"plus_rack": "+%d" % Sim.RACK_BONUS,
	}
	Dmd.play(Callable(_dmd_anims, name), DmdAnims.DURATIONS[name])


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
	tw.tween_method(func(o: float): hole.set_instance_shader_parameter("open", o), 0.0, 1.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(1.2, 2.2)
	_enemy_nodes[id] = {"root": root, "body": body, "spin": spin, "hole": hole, "colour": colour}


func _close_wormhole(id: int) -> void:
	if not _enemy_nodes.has(id) or _enemy_nodes[id].hole == null:
		return
	var hole: MeshInstance3D = _enemy_nodes[id].hole
	_enemy_nodes[id].hole = null
	var tw := hole.create_tween()
	tw.tween_method(func(o: float): hole.set_instance_shader_parameter("open", o), 1.0, 0.0, 0.4)
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
func _spawn_blast_node(level: int) -> void:
	var m := MeshInstance3D.new()
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
	for i in sim.blasts.size():
		var p: Vector2 = sim.blasts[i].pos
		# Nose leads: shift the drawn bolt so its tail trails behind the hitbox.
		_blast_nodes[i].position = Vector3(p.x, 0.12, p.y + Sim.BLAST_H * 0.55)
	# Charging (D-053, D-054): particles in the colour of the level being charged
	# converge in front of the nose; the sphere shows the level already reached
	# (small blue, medium yellow, full-size red).
	var reached := int(floor(sim.blast_charge + 0.0001))
	var charging := sim.blast_charge > 0.0 or (sim.state == Sim.State.PLAY and CabinetInput.is_down(&"flip_l") \
		and CabinetInput.is_down(&"flip_r"))
	charging = charging and reached < mini(sim.affordable_level(), Sim.BLAST_MAX_LEVEL)
	if _charge_particles.emitting != charging:
		_charge_particles.emitting = charging
	if charging:
		_charge_particles.color = LEVEL_COLORS[reached]
	_charge_glow.visible = reached >= 1
	if reached >= 1:
		if _charge_level_shown != reached:
			_charge_level_shown = reached
			Fx.tint_plasma(_charge_glow, LEVEL_COLORS[reached - 1])
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.03)
		_charge_glow.scale = Vector3.ONE * LEVEL_SPHERE_SCALE[reached - 1] * pulse
	else:
		_charge_level_shown = 0


## Backglass: title art only (status is on the DMD, D-051).
func _build_backglass() -> void:
	add_to_backglass(UI.fill(ACCENT.darkened(0.85)))
	var col := UI.vstack(30)
	add_to_backglass(col)
	col.add_child(UI.label(tr("GAME_BREAKOUT_TITLE"), 170, ACCENT))
