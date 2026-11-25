## Headless smoke tests. Run: scripts/test.ps1  (or scripts/test.sh)
## Loads pure helpers from core/util (autoloads are also present but not relied on).
extends SceneTree

const CliUtil = preload("res://core/util/cli.gd")
const Bindings = preload("res://core/util/bindings.gd")
const CsvI18n = preload("res://core/util/csv_i18n.gd")
const ScoreTable = preload("res://core/util/score_table.gd")
const Synth = preload("res://core/util/synth.gd")
const DotFont = preload("res://core/dmd/dot_font.gd")
const ConfigScript = preload("res://core/config.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_cli()
	test_config_coerce()
	test_bindings()
	test_score_table()
	test_synth()
	test_dot_font()
	test_translation_keys()
	test_all_scripts_compile()
	test_system_checks()
	test_ball_physics()
	test_breakout_sim()
	test_racer_sim()
	test_racer_time_of_day()
	test_racer_hd_assets()
	test_racer_first_nitro()
	test_racer_police_rams()
	test_exported_translation()
	test_export_includes_data()
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + what)


func test_cli() -> void:
	var c := CliUtil.parse(PackedStringArray(["--layout=3screen", "--game=breakout", "--smoke", "junk", "--display.render_scale=1.5"]))
	check(c.get("layout") == "3screen", "cli layout")
	check(c.get("game") == "breakout", "cli game")
	check(c.get("smoke") == true, "cli flag")
	check(c.get("display.render_scale") == "1.5", "cli dotted override")
	check(not c.has("junk"), "cli ignores positional")


func test_config_coerce() -> void:
	check(ConfigScript.coerce("false", true) == false, "coerce bool false")
	check(ConfigScript.coerce("on", false) == true, "coerce bool on")
	check(ConfigScript.coerce("42", 1) == 42, "coerce int")
	check(ConfigScript.coerce("auto", "x") == "auto", "coerce string passthrough")


func test_bindings() -> void:
	var k := Bindings.to_event("key:Shift@left") as InputEventKey
	check(k != null and k.physical_keycode == KEY_SHIFT and k.location == KEY_LOCATION_LEFT, "binding left shift")
	var e := Bindings.to_event("key:Space") as InputEventKey
	check(e != null and e.physical_keycode == KEY_SPACE, "binding space")
	var j := Bindings.to_event("joy:9") as InputEventJoypadButton
	check(j != null and j.button_index == 9, "binding joy button")
	var a := Bindings.to_event("axis:5+") as InputEventJoypadMotion
	check(a != null and a.axis == 5 and a.axis_value > 0.0, "binding axis")
	check(Bindings.to_event("key:NotAKey") == null, "binding rejects bad key")
	check(Bindings.to_event("nonsense") == null, "binding rejects bad format")
	var defaults: Dictionary = load("res://core/cabinet_input.gd").DEFAULT_BINDINGS
	for action in defaults:
		for b in defaults[action]:
			var ev := Bindings.to_event(b)
			check(ev != null, "default binding parses: %s %s" % [action, b])
			# Round trip: captured event -> same binding string.
			if ev is InputEventKey:
				(ev as InputEventKey).pressed = true
			elif ev is InputEventJoypadButton:
				(ev as InputEventJoypadButton).pressed = true
			check(Bindings.from_event(ev) == b, "binding round trip %s -> %s" % [b, Bindings.from_event(ev)])
	check(Bindings.kind("axis:4+") == "joy" and Bindings.kind("key:A") == "key", "binding kind")
	check(Bindings.describe("key:Shift@left") == "L SHIFT", "binding describe")
	var weak := InputEventJoypadMotion.new()
	weak.axis = 4
	weak.axis_value = 0.2
	check(Bindings.from_event(weak) == "", "small axis movement ignored")


func test_score_table() -> void:
	var t := ScoreTable.defaults(10)
	check(t.size() == 10 and int(t[0][1]) > int(t[9][1]), "defaults sorted")
	check(not ScoreTable.qualifies(t, 1, 10), "low score does not qualify")
	check(ScoreTable.insert(t, "ZZZ", 999999, 10) == 0 and t[0][0] == "ZZZ" and t.size() == 10, "insert top")
	check(ScoreTable.insert(t, "MID", 27500, 10) >= 1, "insert middle")
	check(ScoreTable.insert(t, "LOW", 1, 10) == -1, "reject low")
	check(ScoreTable.format_score(1234567) == "1,234,567" and ScoreTable.format_score(999) == "999", "format score")


func test_synth() -> void:
	var s := Synth.make([[440.0, 440.0, 0.1], [880.0, 220.0, 0.05, "noise"]])
	check(s.data.size() == (int(0.1 * Synth.RATE) + int(0.05 * Synth.RATE)) * 2, "synth length")
	# D-278: sounds made on worker threads are the ones make() then returns.
	var spec := [[330.0, 660.0, 0.08, "square"]]
	var job: Variant = Synth.begin_many([spec, spec])
	if job != null:
		check((job["todo"] as Array).size() == 1, "synth batch skips duplicates")
		Synth.finish_many(job)
		check(Synth.many_done(job), "synth batch done")
	var made := Synth.make(spec)
	check(made.data.size() == int(0.08 * Synth.RATE) * 2, "synth batch length")
	check(Synth.make(spec) == made, "synth cached")
	check(Synth.begin_many([spec]) == null, "synth batch: nothing left to make")


func test_dot_font() -> void:
	check(DotFont.measure("AB", 1) == 11 and DotFont.measure("AB", 2) == 22, "dot font measure")
	for ch in DotFont.GLYPHS:
		var rows: PackedStringArray = DotFont.GLYPHS[ch].split(" ")
		var ok := rows.size() == DotFont.H
		for r in rows:
			ok = ok and r.length() == DotFont.W
		check(ok, "glyph shape '%s'" % ch)


## Every translation key used in code must exist in the English column:
## tr("KEY") calls and any ALL_CAPS_WITH_UNDERSCORE string literal (menu keys etc.).
func test_translation_keys() -> void:
	var data := CsvI18n.parse_file("res://core/locale/strings.csv")
	check(data.has("en"), "strings.csv has en column")
	var en: Dictionary = data.get("en", {})
	var key_re := RegEx.create_from_string("\"([A-Z][A-Z0-9]*_[A-Z0-9_]+)\"")
	var used := {}
	for path in _gd_files("res://"):
		if path.begins_with("res://tests/"):
			continue
		var src := FileAccess.get_file_as_string(path)
		for m in key_re.search_all(src):
			used[m.get_string(1)] = path
	for a in load("res://core/cabinet_input.gd").ACTIONS:
		used["ACTION_" + String(a).to_upper()] = "CabinetInput.ACTIONS"
	for key in used:
		check(en.has(key), "missing translation key %s (%s)" % [key, used[key]])


## Power-ups (D-072) and brick types (D-073).
func test_breakout_powerups(Sim) -> void:
	var dt := 1.0 / 60.0
	var mk := func():
		var x = Sim.new()
		x.setup(3)
		x.step(dt, false, false, true, 0)  # plasma in play
		x.freeze_ball = true
		return x
	# Upward ball passes through the ship (no bounce back down).
	var up = Sim.new()
	up.setup(3)
	up.step(dt, false, false, true, 0)
	up.ball_pos = Vector2(up.paddle_x, Sim.PADDLE_Y + 0.4)
	up.ball_vel = Vector2(0, -8)
	up.step(dt, false, false, false, 0)
	up.step(dt, false, false, false, 0)
	check(up.ball_vel.y < 0.0, "ball rising from below passes through the ship")
	# Capsule falls onto the ship and is collected.
	var c = mk.call()
	c.spawn_powerup("T", Vector2(c.paddle_x, Sim.PADDLE_Y - 2.0))
	var got := ""
	for k in 120:
		c.step(dt, false, false, false, 0)
		for e in c.events:
			if e[0] == "powerup_collect":
				got = e[1][1]
	check(got == "T" and c.powerup == "T", "power-up capsule collected")
	var rc = mk.call()
	rc.power = 0.1
	rc.spawn_powerup("S", Vector2(rc.paddle_x, Sim.PADDLE_Y - 1.0))
	var ctl = mk.call()
	ctl.power = 0.1
	for k in 90:
		rc.step(dt, false, false, false, 0)
		ctl.step(dt, false, false, false, 0)
	check(absf(rc.power - ctl.power - 1.0 / 3.0) < 0.02, "capsule restores one bar level (+%.2f)" % (rc.power - ctl.power))
	# T: triple laser fires 3 bolts.
	c.power = 1.0
	for k in 50:
		c.step(dt, true, true, false, 0)
	c.step(dt, false, false, false, 0)
	check(c.blasts.size() == 3, "triple laser: 3 bolts (%d)" % c.blasts.size())
	# P: charges 3x faster.
	var pw = mk.call()
	pw.apply_powerup("P")
	for k in int(Sim.BLAST_CHARGE_TIME * 60.0) + 2:
		pw.step(dt, true, true, false, 0)
	check(pw.blasts.size() == 1 and pw.blasts[0].level == 3, "power laser reaches level 3 in one phase and auto-fires")
	var pe = mk.call()
	pe.apply_powerup("P")
	var starts: Array = []
	for k in 60:
		pe.step(dt, true, true, false, 0)
		for e in pe.events:
			if e[0] == "charge_start" or e[0] == "charged":
				starts.append([e[0], e[1]])
	check(starts == [["charge_start", 1], ["charged", 1]], "power laser: one level of charge (D-327) (%s)" % [starts])
	# I: only level 3, full bar, clears the column.
	var ion = mk.call()
	ion.apply_powerup("I")
	for k in 20:
		ion.step(dt, true, true, false, 0)
	ion.step(dt, false, false, false, 0)
	check(ion.power > 0.9, "ion: releasing before level 3 does nothing")
	var before: int = ion.bricks_alive()
	for k in int(Sim.BLAST_CHARGE_TIME * 60.0) + 3:   # D-327: one level of charge
		ion.step(dt, true, true, false, 0)
	ion.step(dt, false, false, false, 0)
	check(ion.power < 0.1 and ion.bricks_alive() <= before - 4, "ion beam fries the column (%d -> %d)" % [before, ion.bricks_alive()])
	# Beam centred on a column gap still burns only one column.
	var ig = mk.call()
	ig.freeze_ball = true
	var xs := {}
	var b0: Dictionary = ig.bricks[0]
	ig._ion_beam(b0.rect.end.x + Sim.BRICK_GAP * 0.5)
	for b in ig.bricks:
		if not b.alive:
			xs[snappedf(b.rect.get_center().x, 0.01)] = true
	check(xs.size() == 1, "ion beam never burns two columns (%d)" % xs.size())
	# B: extra ball; losing the main ball while it lives costs no charge.
	var bb = mk.call()
	bb.apply_powerup("B")
	for k in 50:
		bb.step(dt, true, true, false, 0)
	bb.step(dt, false, false, false, 0)
	check(bb.extra_balls.size() == 1 and bb.power < 0.01, "bounce plasma launches an extra ball for the full bar")
	bb.freeze_ball = false
	bb.ball_pos = Vector2(0, Sim.DRAIN_Y + 1.0)
	bb.ball_vel = Vector2(0, 5)
	bb.extra_balls[0].pos = Vector2(0, -2)
	bb.extra_balls[0].vel = Vector2(0, -5)
	bb.step(dt, false, false, false, 0)
	check(bb.balls_left == 3 and bb.extra_balls.is_empty() and bb.state == Sim.State.PLAY, "extra ball takes over: no charge lost")
	# S: barrier saves one sinking ball, no charged shot.
	var sh = mk.call()
	sh.apply_powerup("S")
	sh.freeze_ball = false
	check(sh.affordable_level() > 0 and sh.padup == "S" and sh.powerup == "", "shield: a paddle upgrade; the blaster still fires (D-327)")
	sh.ball_pos = Vector2(-3.0, Sim.SHIELD_Y - 0.5)
	sh.ball_vel = Vector2(0, 9)
	for k in 10:
		sh.step(dt, false, false, false, 0)
	check(sh.ball_vel.y < 0.0 and not sh.shield_active and sh.balls_left == 3, "shield bounces one ball, then breaks")
	check(sh.padup == "" and sh.affordable_level() > 0, "lost shield empties the paddle slot (D-084, D-327)")
	# L: afterimages trail the moving ship and are cleared with the power-up on death.
	var ls = mk.call()
	ls.apply_powerup("L")
	for k in 12:  # still accelerating, not yet at the wall
		ls.step(dt, false, true, false, 0)
	check(ls.ghost_xs().size() == 2, "lightspeed: two afterimages while moving")
	ls.power = 0.2
	ls._lose_ball()
	check(ls.powerup == "" and ls.padup == "", "power-ups end on death")
	check(ls.power == 1.0, "losing a life refills the power bar (D-102)")
	ls.power = 0.1
	ls._destroy_ship()
	check(ls.power == 1.0, "losing the ship refills the power bar (D-102)")
	# Bricks: lowercase = 2 hits, X = indestructible and doesn't block clearing.
	var lv = Sim.new()
	lv.setup(3)
	lv.bricks.clear()
	lv.bricks.append({"rect": Rect2(0, 0, 1, 0.4), "hp": 2, "alive": true, "row": 0, "col": 0, "colour": "R",
		"points": 180, "metal": false, "armoured": true})
	lv.bricks.append({"rect": Rect2(2, 0, 1, 0.4), "hp": -1, "alive": true, "row": 0, "col": 2, "colour": "X",
		"points": 0, "metal": true, "armoured": false})
	check(not lv._damage_brick(1) and lv.bricks[1].alive, "metal brick is indestructible")
	check(not lv._damage_brick(0) and lv.bricks[0].alive, "armoured brick survives the first hit")
	check(lv._damage_brick(0) and lv.state == Sim.State.LEVEL_CLEAR, "second hit breaks it; metal doesn't block clearing")
	# Levels 1-10 exist and enemies speed up every 5 levels.
	for n in range(1, 11):
		var layout: Array = Sim.level_layout(n)
		check(layout.size() >= 3, "level %d has a layout" % n)
	var t = Sim.new()
	t.setup(3)
	t.level = 6
	check(t.enemy_tier() == 1 and t.enemy_speed_mult() > 1.3, "levels 6-10: faster enemies")


## Tetrahedron enemy (D-052): blocked by a full rack, descends through a gap,
## orbits at the bottom, dies to the plasma, destroys the ship on contact.
## Level complete (D-068): enemies explode, play pauses, next_level loads level 2.
## Difficulty (D-182): plasma start speed and cap, lives from the operator's balls.
func test_breakout_difficulty(Sim) -> void:
	var e = Sim.new()
	e.setup(3, "easy")
	var n = Sim.new()
	n.setup(3)
	var h = Sim.new()
	h.setup(3, "hard")
	check(e.balls_left == 5 and n.balls_left == 3 and h.balls_left == 2, "lives: easy 5, normal 3, hard 2")
	check(e.ball_speed < n.ball_speed and n.ball_speed < h.ball_speed, "serve speed rises with difficulty")
	check(e.ball_max_speed < n.ball_max_speed and n.ball_max_speed < h.ball_max_speed, "speed cap rises with difficulty")
	check(n.ball_speed == Sim.BALL_START_SPEED and n.ball_max_speed == Sim.BALL_MAX_SPEED, "normal keeps the original tuning")
	var one = Sim.new()
	one.setup(1, "hard")
	check(one.balls_left == 1, "hard never goes below one life")
	# D-264: a held charge button charges the shot like both flippers.
	var cb = Sim.new()
	cb.setup(3)
	cb.step(1.0 / 60.0, false, false, true, 0)   # serve
	cb.power = 1.0
	cb.charge_held = true
	for i in 20:
		cb.step(1.0 / 60.0, false, false, false, 0)
	check(cb.state == Sim.State.PLAY and cb.blast_charge > 0.0, "the charge button charges the shot (%.2f)" % cb.blast_charge)
	# D-275: never the power-up you have; the ship enters the next level centred.
	var pw = Sim.new()
	pw.setup(3)
	pw.powerup = "L"
	var same := false
	for i in 300:
		same = same or pw.random_powerup_kind() == "L"
	pw.paddle_x = 3.0
	pw.next_level()
	check(not same and is_equal_approx(pw.paddle_x, Sim.FIELD.get_center().x),
		"no drop of the power-up you have; the ship starts a level in the centre")
	# D-321: extra lives at 20,000 and 50,000, once each.
	var xl = Sim.new()
	xl.setup(3)
	var l0: int = xl.balls_left
	xl.score = 19990
	xl.step(1.0 / 60.0, false, false, false, 0)
	var none: bool = xl.balls_left == l0
	xl.score = 20000
	xl.step(1.0 / 60.0, false, false, false, 0)
	var got1: bool = xl.balls_left == l0 + 1 and xl.events.any(func(e): return e[0] == "extra_life")
	xl.step(1.0 / 60.0, false, false, false, 0)
	var once: bool = xl.balls_left == l0 + 1
	xl.score = 80000
	xl.step(1.0 / 60.0, false, false, false, 0)
	xl.score = 200000
	xl.step(1.0 / 60.0, false, false, false, 0)
	check(none and got1 and once and xl.balls_left == l0 + 2 and xl.balls_total == l0 + 2,
		"extra life at 20,000 and 50,000, once each (lives %d -> %d)" % [l0, xl.balls_left])
	# D-322: the proximity alert: an enemy in the bottom 20% of the field.
	var dz = Sim.new()
	dz.setup(3)
	dz.spawn_enemy(0.0)
	var line: float = dz.field.end.y - dz.field.size.y * 0.2
	dz.enemies[0].pos = Vector2(0.0, line + 0.3)
	var hole: bool = dz.enemy_in_danger()   # still in its wormhole: no alert
	dz.enemies[0].state = "orbit"
	var near: bool = dz.enemy_in_danger()
	dz.enemies[0].pos.y = line - 0.2
	var held: bool = dz.enemy_in_danger(0.45) and not dz.enemy_in_danger()
	check(not hole and near and held, "proximity alert: an enemy out of its wormhole in the bottom 20%, with hysteresis")
	# D-323: the cube enemy heads for the ship more than the tetra.
	var ag = Sim.new()
	ag.setup(3)
	ag.bricks.clear()
	ag.paddle_x = 3.0
	ag.spawn_enemy(-3.0, "tetra")
	ag.spawn_enemy(-3.0, "cube")
	var kinds_ok: bool = ag.enemies[0].kind == "tetra" and ag.enemies[1].kind == "cube"
	for en in ag.enemies:
		en.state = "sweep"
		en.phase = 0.0
		en.dir = 1.0
	var dist := [0.0, 0.0]
	var cube_low := false
	for i in 600:
		ag._update_enemies(1.0 / 60.0)
		for k in 2:
			dist[k] += absf(float(ag.enemies[k].pos.x) - ag.paddle_x)
	cube_low = ag.enemies[1].pos.y > ag.enemies[0].pos.y
	check(kinds_ok and dist[1] < dist[0] * 0.85 and cube_low,
		"cube enemy: nearer the ship (%.0f vs %.0f) and lower than a tetra" % [dist[1], dist[0]])
	# D-335: the level-10 boss.
	var bs = Sim.new()
	bs.setup(3)
	var none_on_1: bool = bs.boss_hp == 0
	bs.level = 10
	bs.build_rack()
	var b_low := -INF
	for i in 600:
		bs.boss_t += 0.1
		b_low = maxf(b_low, bs._boss_path(bs.boss_t).y)
	var stays_up: bool = b_low <= Sim.BOSS_Y.y + 0.001
	bs.step(1.0 / 60.0, false, false, true, 0)   # serve
	bs.freeze_ball = true
	bs.ball_pos = Vector2(-3.5, 3.0)   # out of the ray's way
	bs.boss_fire_in = 0.05
	var b_fired := false
	for i in 10:
		bs.step(1.0 / 60.0, false, false, false, 0)
		for ev in bs.events:
			b_fired = b_fired or ev[0] == "boss_fire"
	var b_through: bool = bs.rays.size() == 1
	var lives_b: int = bs.balls_left
	for i in 400:   # it flies through the bricks onto the ship
		bs.step(1.0 / 60.0, false, false, false, 0)
		if bs.rays.is_empty():
			break
	var ship_hit: bool = bs.balls_left == lives_b - 1
	# The ball stops a ray.
	var bl = Sim.new()
	bl.setup(3)
	bl.level = 10
	bl.build_rack()
	bl.step(1.0 / 60.0, false, false, true, 0)
	bl.freeze_ball = true
	bl.ball_pos = Vector2(0.0, 2.0)
	bl.rays.append({"id": 999, "pos": Vector2(0.0, 1.0), "vel": Vector2(0.0, Sim.RAY_SPEED)})
	for i in 30:
		bl.step(1.0 / 60.0, false, false, false, 0)
	var b_blocked: bool = bl.rays.is_empty() and bl.balls_left == 3
	# No level clear while the boss lives; its death clears an empty level.
	for j in bl.bricks.size():
		if bl.bricks[j].alive and not bl.bricks[j].metal:
			bl.bricks[j].hp = 1
			bl._damage_brick(j)
	var b_waits: bool = bl.state != Sim.State.LEVEL_CLEAR
	bl._hurt_boss(Sim.BOSS_HP)
	check(none_on_1 and stays_up and b_fired and b_through and ship_hit and b_blocked and b_waits and bl.state == Sim.State.LEVEL_CLEAR,
		"boss: level 10 only, stays up, fires through bricks, hits the ship, the ball stops rays, level ends with it")
	# D-342: new bricks, enemies and the level-20 boss.
	var nb = Sim.new()
	nb.setup(3)
	nb.level = 11
	nb.build_rack()
	var ci := -1
	for j in nb.bricks.size():
		if nb.bricks[j].get("charged", false):
			ci = j
			break
	var torp0: int = nb.rays.size()
	nb._damage_brick(ci)
	var torp_ok: bool = ci != -1 and nb.rays.size() == torp0 + 1 and nb.bricks[ci].alive and Vector2(nb.rays[-1].vel).y > 0.0
	nb._damage_brick(ci)
	var torp_once: bool = nb.rays.size() == torp0 + 1 and not nb.bricks[ci].alive
	nb.level = 12
	nb.build_rack()
	var pi := -1
	for j in nb.bricks.size():
		if nb.bricks[j].get("plasma", false):
			pi = j
			break
	nb.extra_balls.clear()
	nb._damage_brick(pi)
	var freed: bool = pi != -1 and nb.extra_balls.size() == 1
	check(torp_ok and torp_once and freed, "charged brick fires one torpedo down on its first hit; a plasma brick frees a ball")
	var mi = Sim.new()
	mi.setup(3)
	mi.level = 11
	mi.build_rack()
	mi.step(1.0 / 60.0, false, false, true, 0)
	mi.freeze_ball = true
	mi.spawn_enemy(0.0, "ico")
	mi.enemies[0].state = "sweep"
	mi.enemies[0].fire_in = 0.5
	var mf := false
	for i in 60:
		mi.step(1.0 / 60.0, false, false, false, 0)
		for ev in mi.events:
			mf = mf or ev[0] == "mini_fire"
	var kinds11 := {}
	for i in 300:
		mi.spawn_enemy()
		kinds11[mi.enemies[-1].kind] = true
	mi.level = 10
	var ico_early := false
	for i in 300:
		mi.spawn_enemy()
		ico_early = ico_early or mi.enemies[-1].kind == "ico"
	check(mf and kinds11.has("ico") and not ico_early and float(mi.rays[0].get("r", 1.0)) < Sim.RAY_R,
		"mini-icosahedron from level 11 fires a smaller torpedo")
	# Corrupted paddle: only where its band is clear; 10 ball hits or 5 weapon hits.
	var bands_ok := true
	for ln in range(15, 20):
		for wide2 in [false, true]:
			var lvd = Sim.new()
			if wide2:
				lvd.setup_two(3)
			else:
				lvd.setup(3)
			lvd.level = ln
			lvd.build_rack()
			bands_ok = bands_ok and lvd.dark_band_clear()
	var dk = Sim.new()
	dk.setup(3)
	dk.level = 15
	dk.build_rack()
	dk.spawn_dark(0.0)
	dk.darks[0].state = "live"
	for i in 9:
		dk._hurt_dark(0, 1)
	var alive9: bool = dk.darks.size() == 1
	dk._hurt_dark(0, 1)
	var dead10: bool = dk.darks.is_empty()
	dk.spawn_dark(0.0)
	for i in 5:
		dk._hurt_dark(0, 2)
	var dead5: bool = dk.darks.is_empty()
	var bounce = Sim.new()
	bounce.setup(3)
	bounce.level = 15
	bounce.build_rack()
	bounce.step(1.0 / 60.0, false, false, true, 0)
	bounce.spawn_dark(0.0)
	bounce.darks[0].state = "live"
	bounce.darks[0].vx = 0.0
	bounce.ball_pos = Vector2(0.0, bounce._dark_y() + 0.6)
	bounce.ball_vel = Vector2(0.0, -8.0)
	for i in 12:
		bounce.step(1.0 / 60.0, false, false, false, 0)
	check(bands_ok and alive9 and dead10 and dead5 and bounce.ball_vel.y > 0.0 and int(bounce.darks[0].hp) == Sim.DARK_HP - 1,
		"corrupted paddle: levels 15-19 leave its band clear; blocks the ball; 10 ball hits or 5 weapon hits")
	# D-346: it chases the ball, slower than the ship can move.
	var ch = Sim.new()
	ch.setup(3)
	ch.level = 15
	ch.build_rack()
	ch.step(1.0 / 60.0, false, false, true, 0)
	ch.freeze_ball = true
	ch.ball_pos = Vector2(2.5, 3.0)
	ch.spawn_dark(-2.5)
	ch.darks[0].state = "live"
	var fastest := 0.0
	for i in 120:
		ch.step(1.0 / 60.0, false, false, false, 0)
		fastest = maxf(fastest, absf(float(ch.darks[0].vx)))
	check(absf(float(ch.darks[0].pos.x) - 2.5) < 0.3 and fastest <= Sim.DARK_SPEED * ch.enemy_speed_mult() + 0.01 and fastest < Sim.PADDLE_MAX_SPEED,
		"corrupted paddle chases the ball (x %.2f), slower than the ship" % float(ch.darks[0].pos.x))
	# D-347: mini-icosahedrons stay in the top 20% (no bricks in the way, a long time).
	var top = Sim.new()
	top.setup(3)
	top.level = 12
	top.build_rack()
	top.bricks.clear()
	top.spawn_enemy(0.0, "ico")
	var lowest := -INF
	for i in 60 * 40:
		top._update_enemies(1.0 / 60.0)
		lowest = maxf(lowest, float(top.enemies[0].pos.y))
	check(lowest <= top.field.position.y + top.field.size.y * 0.2 and top.enemies[0].state != "orbit",
		"mini-icosahedron stays in the top 20%% (lowest %.2f)" % lowest)
	var dd = Sim.new()
	dd.setup(3)
	dd.level = 20
	dd.build_rack()
	dd.step(1.0 / 60.0, false, false, true, 0)
	dd.freeze_ball = true
	dd.ball_pos = Vector2(-3.5, 3.0)
	dd.boss_fire_in = 0.05
	for i in 6:
		dd.step(1.0 / 60.0, false, false, false, 0)
	check(dd.boss_kind == "dodeca" and dd.boss_hp == Sim.DODECA_HP and dd.rays.size() == 3,
		"level 20: the dodecahedron fires three torpedoes (%d)" % dd.rays.size())
	# D-344: no relaunch for 2 s after a lost charge.
	var sl2 = Sim.new()
	sl2.setup(3)
	sl2.step(1.0 / 60.0, false, false, true, 0)
	sl2._lose_ball()
	for i in 60:   # 1 s of launch held
		sl2.step(1.0 / 60.0, false, false, true, 0)
	var still: bool = sl2.state == Sim.State.SERVE
	for i in 70:
		sl2.step(1.0 / 60.0, false, false, true, 0)
	check(still and sl2.state == Sim.State.PLAY, "after a lost charge the plasma can't be launched for 2 s")
	# D-355: torpedoes pass the Sidekicks; only the ship itself is hit.
	var sk2 = Sim.new()
	sk2.setup(3)
	sk2.step(1.0 / 60.0, false, false, true, 0)
	sk2.freeze_ball = true
	sk2.ball_pos = Vector2(-3.5, -2.0)
	sk2.apply_powerup("K")
	var side_x: float = sk2.paddle_x + Sim.PADDLE_W * 0.5 + Sim.SIDEKICK_W * 0.5
	sk2._spawn_torpedo(Vector2(side_x, sk2.paddle_y - 1.0), Vector2.DOWN, Sim.TORP_BRICK)
	var lives_k: int = sk2.balls_left
	for i in 90:
		sk2.step(1.0 / 60.0, false, false, false, 0)
	check(sk2.balls_left == lives_k, "a torpedo through a Sidekick doesn't cost a charge")
	# D-339: every 4 damage to the boss drops a capsule.
	var bd = Sim.new()
	bd.setup(3)
	bd.level = 10
	bd.build_rack()
	var caps0: int = bd.powerups.size()
	for i in 8:
		bd._hurt_boss(1)
	check(bd.powerups.size() == caps0 + 2 and float(bd.powerups[-1].pos.y) > bd.boss_pos.y,
		"boss: every 4 hits shake a capsule loose (%d)" % (bd.powerups.size() - caps0))
	# D-333: never more than 15 bricks in a row without a drop.
	var pt = Sim.new()
	pt.setup(3)
	var gap := 0
	var worst := 0
	var drops := 0
	for j in pt.bricks.size():
		if not pt.bricks[j].alive or pt.bricks[j].get("metal", false) or pt.bricks_alive() <= 1:
			continue
		var before_n: int = pt.powerups.size()
		pt.bricks[j].hp = 1
		pt._damage_brick(j)
		if pt.powerups.size() > before_n:
			drops += 1
			gap = 0
		else:
			gap += 1
			worst = maxi(worst, gap)
	check(worst <= Sim.DROP_PITY and drops >= 2, "a capsule drops at least every 16 bricks (longest gap %d, %d drops)" % [worst, drops])
	# D-330: brick hits +2%, ship hits +5% of the bar.
	var eg = Sim.new()
	eg.setup(3)
	eg.step(1.0 / 60.0, false, false, true, 0)   # serve
	eg.power = 0.3
	eg._since_blast = 0.0   # no recharge over time in this step
	var bj: Dictionary = eg.bricks[eg.bricks.size() - 1]
	eg.ball_pos = Vector2(bj.rect.get_center().x, bj.rect.end.y + Sim.BALL_R + 0.02)
	eg.ball_vel = Vector2(0.0, -8.0)
	eg.ball_speed = 8.0
	eg.step(1.0 / 60.0, false, false, false, 0)
	var after_brick: float = eg.power
	eg._since_blast = 0.0
	eg.ball_pos = Vector2(eg.paddle_x, Sim.PADDLE_Y - Sim.PADDLE_H * 0.5 - Sim.BALL_R - 0.02)
	eg.ball_vel = Vector2(0.0, 8.0)
	eg.step(1.0 / 60.0, false, false, false, 0)
	check(absf(after_brick - 0.32) < 0.001 and absf(eg.power - 0.37) < 0.001,
		"energy: brick hit +2%% (%.3f), ship hit +5%% (%.3f)" % [after_brick, eg.power])
	# D-329: blaster and paddle drops take turns; capsules caught just under the ship.
	var al = Sim.new()
	al.setup(3)
	var groups := []
	for i in 400:
		var kk: String = al.random_powerup_kind()
		if kk in Sim.INSTANT_KINDS:
			continue
		groups.append("p" if kk in Sim.PADDLE_KINDS else "b")
	var alternates := true
	for i in range(1, groups.size()):
		alternates = alternates and groups[i] != groups[i - 1]
	var cu = Sim.new()
	cu.setup(3)
	cu.spawn_powerup("T", Vector2(cu.paddle_x, Sim.PADDLE_Y + Sim.PADDLE_H * 0.5 + Sim.POWERUP_R + 0.3))
	var caught_under := false
	cu.step(1.0 / 60.0, false, false, false, 0)
	for ev in cu.events:
		caught_under = caught_under or ev[0] == "powerup_collect"
	check(alternates and groups.size() > 300 and caught_under,
		"drops alternate blaster/paddle (%d in a row checked); a capsule just under the ship is caught" % groups.size())
	# D-327: two slots; upgrades charge one level and use their cost per shot.
	var sl = Sim.new()
	sl.setup(3)
	sl.apply_powerup("T")
	sl.apply_powerup("S")
	var both: bool = sl.powerup == "T" and sl.padup == "S"
	sl.apply_powerup("W")
	sl.apply_powerup("L")
	both = both and sl.powerup == "W" and sl.padup == "L" and sl.max_level() == 1
	var tc = Sim.new()
	tc.setup(3)
	tc.step(1.0 / 60.0, false, false, true, 0)   # serve
	tc.freeze_ball = true
	tc.apply_powerup("T")
	for k in int(Sim.BLAST_CHARGE_TIME * 60.0) + 3:
		tc.step(1.0 / 60.0, true, true, false, 0)
	var t_ok: bool = tc.blasts.size() == 3 and absf(tc.power - 2.0 / 3.0) < 0.02 and tc.blasts[0].level == 1
	check(both and t_ok, "two slots; T: level 1 after one charge time, 3 bolts for one cell (power %.2f)" % tc.power)
	# W: snakes up through the bricks, hitting each once.
	var wv = Sim.new()
	wv.setup(3)
	wv.step(1.0 / 60.0, false, false, true, 0)
	wv.freeze_ball = true
	var hp_before := {}
	for j in wv.bricks.size():
		hp_before[j] = wv.bricks[j].hp
	wv.apply_powerup("W")
	for k in int(Sim.BLAST_CHARGE_TIME * 60.0) + 3:
		wv.step(1.0 / 60.0, true, true, false, 0)
	var fired: bool = wv.waves.size() == 1 and wv.power < 0.01
	var lost := 0
	for k in 120:
		wv.step(1.0 / 60.0, false, false, false, 0)
	for j in wv.bricks.size():
		if not wv.bricks[j].alive or wv.bricks[j].hp < hp_before[j]:
			lost += 1
	check(fired and wv.waves.is_empty() and lost >= 4, "wave beam: the full bar, passes through, hits %d bricks once each" % lost)
	# H: homes on the nearest target; 3 hits on everything in a 3x3-brick area.
	var hm = Sim.new()
	hm.setup(3)
	hm.step(1.0 / 60.0, false, false, true, 0)
	hm.freeze_ball = true
	var alive0: int = hm.bricks_alive()
	hm.apply_powerup("H")
	for k in int(Sim.BLAST_CHARGE_TIME * 60.0) + 3:
		hm.step(1.0 / 60.0, true, true, false, 0)
	var launched: bool = hm.missiles.size() == 1
	var blasted := false
	for k in 180:
		hm.step(1.0 / 60.0, false, false, false, 0)
		for ev in hm.events:
			blasted = blasted or ev[0] == "missile_blast"
	check(launched and blasted and hm.missiles.is_empty() and alive0 - hm.bricks_alive() >= 5,
		"homing missile: one blast takes out a 3x3 area (%d bricks)" % (alive0 - hm.bricks_alive()))
	# K: sidekicks widen what catches the plasma and the capsules.
	var sk = Sim.new()
	sk.setup(3)
	var w0: float = sk.catch_rect().size.x
	sk.apply_powerup("K")
	check(is_equal_approx(sk.catch_rect().size.x, w0 + Sim.SIDEKICK_W * 2.0) and sk.affordable_level() > 0,
		"sidekicks: the ship catches %.2f m wider, no energy used" % (Sim.SIDEKICK_W * 2.0))
	# D-326: 1UP and Nuclear, rarer than the others, used on the catch.
	var rp = Sim.new()
	rp.setup(3)
	var counts := {}
	for i in 6000:
		var kk: String = rp.random_powerup_kind()
		counts[kk] = int(counts.get(kk, 0)) + 1
	var rare_ok: bool = counts.get("U", 0) > 70 and counts.get("N", 0) > 70 		and counts.get("U", 0) < counts.get("T", 0) * 0.4 and counts.get("N", 0) < counts.get("T", 0) * 0.4
	var up = Sim.new()
	up.setup(3)
	var lives0: int = up.balls_left
	up.spawn_powerup("U", Vector2(up.paddle_x, Sim.PADDLE_Y - 0.3))
	for i in 20:
		up.step(1.0 / 60.0, false, false, false, 0)
	var nk = Sim.new()
	nk.setup(3)
	nk.spawn_powerup("N", Vector2(nk.paddle_x, Sim.PADDLE_Y - 0.3))
	var score0: int = nk.score
	for i in 20:
		nk.step(1.0 / 60.0, false, false, false, 0)
	check(rare_ok and up.balls_left == lives0 + 1 and up.powerup == "" 		and nk.bricks_alive() == 0 and nk.state == Sim.State.LEVEL_CLEAR and nk.score > score0 and nk.powerups.is_empty(),
		"1UP adds a charge, Nuclear clears the level; both rarer (U %d, N %d, T %d per 6000)" % [counts.get("U", 0), counts.get("N", 0), counts.get("T", 0)])
	# D-324: no cubes before level 3.
	var cl = Sim.new()
	cl.setup(3)
	var early_cube := false
	for lv in [1, 2]:
		cl.level = lv
		for i in 200:
			cl.spawn_enemy()
			early_cube = early_cube or cl.enemies[-1].kind == "cube"
	cl.level = 3
	var late_cube := false
	for i in 200:
		cl.spawn_enemy()
		late_cube = late_cube or cl.enemies[-1].kind == "cube"
	check(not early_cube and late_cube, "cube enemies spawn from level 3 only")
	# D-323: unstuck. An enemy in a brick cup circles up and out after 10 s.
	var us = Sim.new()
	us.setup(3)
	us.bricks.clear()
	var cy := -2.0
	for r in [Rect2(-1.3, cy + 0.4, 2.6, 0.4), Rect2(-1.7, cy - 0.8, 0.4, 1.6), Rect2(1.3, cy - 0.8, 0.4, 1.6)]:
		us.bricks.append({"rect": r, "hp": 1, "alive": true, "row": 0, "points": 0})
	us.spawn_enemy(0.0, "tetra")
	var ue: Dictionary = us.enemies[0]
	ue.state = "sweep"
	ue.pos = Vector2(0.0, cy)
	ue.best_y = cy
	var circled := -1.0
	var out := -1.0
	for i in 60 * 40:
		us._update_enemies(1.0 / 60.0)
		if circled < 0.0 and ue.state == "circle":
			circled = i / 60.0
		if out < 0.0 and float(ue.pos.y) > cy + 1.0:
			out = i / 60.0
		var hit := false
		for b in us.bricks:
			hit = hit or not Sim.BP.collide_circle_rect(ue.pos, Sim.ENEMY_R * 0.9, b.rect).is_empty()
		if hit:
			out = -2.0
			break
	check(circled >= 9.5 and circled < 10.5 and out > circled,
		"stuck enemy: circles at 10 s (%.1f), gets below the cup (%.1f s), never through a brick" % [circled, out])
	# D-285: 2-player Tilt Breaker.
	var tp = Sim.new()
	tp.setup_two(3)
	var bricks2: int = tp.bricks.size()
	var solo = Sim.new()
	solo.setup(3)
	check(tp.two_player and tp.field.size.x > Sim.FIELD.size.x * 1.6 and bricks2 > solo.bricks.size(),
		"2P: a wider field with wider levels (%d bricks vs %d)" % [bricks2, solo.bricks.size()])
	var y0: float = tp.player_get(0, "paddle_y")
	var y1: float = tp.player_get(1, "paddle_y")
	check(y1 < y0 - 0.4, "2P: player 2's ship flies higher, so the ships pass")
	var x1_before: float = tp.player_get(1, "paddle_x")
	for i in 30:
		tp.step_two(1.0 / 60.0, [false, false, false, 0], [true, false, false, 0])
	check(float(tp.player_get(1, "paddle_x")) < x1_before - 0.5 and is_equal_approx(float(tp.player_get(0, "paddle_x")), tp._start_x(0)),
		"2P: each player moves only their own ship")
	tp._use(1)
	tp.apply_powerup("L")
	tp._use(0)
	check(tp.player_get(1, "padup") == "L" and tp.player_get(0, "padup") == "", "2P: power-ups are per ship")
	var lives: int = tp.balls_left
	tp.step_two(1.0 / 60.0, [false, false, true, 0], [false, false, false, 0])   # serve
	tp.ball_pos = Vector2(0.0, Sim.DRAIN_Y + 1.0)
	tp.ball_vel = Vector2(0.0, 5.0)
	tp.step_two(1.0 / 60.0, [false, false, false, 0], [false, false, false, 0])
	check(tp.balls_left == lives - 1 and tp.server == 1 and tp.player_get(1, "padup") == "",
		"2P: a drain costs a shared life, ends both power-ups and passes the serve")
	n.set_difficulty("hard", 3)
	check(n.balls_left == 2 and n.balls_total == 2 and n.ball_speed == 10.0 and n.level == 1, "picking later keeps the level")


## D-334: every destructible brick of every level can be reached by the ball:
## from the open space below (and, once a way through opens, above), the ball
## passes through empty cells (an empty cell is wider and taller than it), and
## breaking a reachable brick opens its cell. Metal never breaks. Returns the
## unreachable bricks as "row,col".
func _trapped_bricks(rows: Array, cols: int) -> Array:
	var h := rows.size()
	var grid := []   # "" empty, "X" metal, "b" destructible
	for r in h:
		var line: String = rows[r]
		var row := []
		for c in cols:
			var ch := line[c] if c < line.length() else "."
			row.append("" if ch == "." else ("X" if ch.to_upper() == "X" else "b"))
		grid.append(row)
	var changed := true
	while changed:
		changed = false
		# Flood from the space below (row h) and, if reached, the space above (row -1);
		# rows -1 and h are open space.
		var stack := []
		for c in cols:
			stack.append(Vector2i(h, c))
		var seen := {}
		var top_reached := false
		while not stack.is_empty():
			var v: Vector2i = stack.pop_back()
			var k := "%d,%d" % [v.x, v.y]
			if seen.has(k):
				continue
			seen[k] = true
			if v.x == -1 and not top_reached:
				top_reached = true
				for c in cols:
					stack.append(Vector2i(-1, c))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = v + d
				if n.y < 0 or n.y >= cols or n.x < -1 or n.x > h:
					continue
				if n.x == -1 or n.x == h or grid[n.x][n.y] == "":
					stack.append(n)
				elif grid[n.x][n.y] == "b":   # touching it: the ball breaks it
					grid[n.x][n.y] = ""
					changed = true
	var out := []
	for r in h:
		for c in cols:
			if grid[r][c] == "b":
				out.append("%d,%d" % [r, c])
	return out


func test_breakout_levels(Sim) -> void:
	# D-334: no level hides a brick the ball can never reach.
	for wide in [false, true]:
		var files: Array = Sim.LEVEL_FILES_2P if wide else Sim.LEVEL_FILES
		for n in files.size():
			var trapped := _trapped_bricks(Sim.level_layout(n + 1, wide), Sim.BRICK_COLS_2P if wide else Sim.BRICK_COLS)
			check(trapped.is_empty(), "%s: every brick reachable %s" % [String(files[n]).get_file(), trapped])
	var lv = Sim.new()
	lv.setup(3)
	lv.spawn_enemy(0.0)
	lv.step(1.0 / 60.0, false, false, true, 0)
	for b in lv.bricks:
		b.alive = false
	lv.bricks[0].alive = true
	var cleared: bool = lv._damage_brick(0)
	check(cleared and lv.state == Sim.State.LEVEL_CLEAR and lv.enemies.is_empty(), "level clear: enemies explode, play pauses")
	check(lv.events.filter(func(e): return e[0] == "enemy_destroyed").size() == 1, "remaining enemy exploded")
	lv.step(1.0 / 60.0, true, false, true, 0)
	check(lv.state == Sim.State.LEVEL_CLEAR, "sim waits during the level-complete sequence")
	lv.power = 0.2
	lv.next_level()
	check(is_equal_approx(lv.power, 1.0), "full power bar at the start of the level (D-076)")
	check(lv.level == 2 and lv.state == Sim.State.SERVE and lv.bricks.size() == lv.bricks_alive() and lv.bricks.size() > 20,
		"next_level loads level 2 (%d bricks)" % lv.bricks.size())


func test_breakout_enemies(Sim) -> void:
	seed(42)
	var blocked = Sim.new()
	blocked.setup(3)
	blocked.spawn_enemy(0.0)
	var max_y := -99.0
	for k in 60 * 20:
		blocked._held_time = 0.0  # no auto-serve
		blocked.step(1.0 / 60.0, false, false, false, 0)
		if not blocked.enemies.is_empty():
			max_y = maxf(max_y, blocked.enemies[0].pos.y)
	check(not blocked.enemies.is_empty() and max_y < Sim.BRICK_TOP, "enemy stays above a full rack (max y %.2f)" % max_y)
	# Open a 3-brick-wide corridor through every row: the enemy gets down and orbits.
	var gap = Sim.new()
	gap.setup(3)
	for bi in gap.bricks.size():
		var col: int = bi % Sim.BRICK_COLS
		if col >= 4 and col <= 6:
			gap.bricks[bi].alive = false
	gap.spawn_enemy(0.0)
	var orbited := false
	for k in 60 * 60:
		gap.paddle_x = -3.0  # keep the ship out of the way
		gap._held_time = 0.0  # no auto-serve: the plasma would kill the enemy
		gap.step(1.0 / 60.0, false, false, false, 0)
		if not gap.enemies.is_empty() and gap.enemies[0].state == "orbit":
			orbited = true
			break
	check(orbited, "enemy descends through a gap and starts orbiting")
	# The plasma destroys an enemy.
	var shot = Sim.new()
	shot.setup(3)
	shot.spawn_enemy(0.0)
	for k in 80:
		shot.step(1.0 / 60.0, false, false, false, 0)
	shot.state = Sim.State.PLAY
	shot.enemies[0].pos = Vector2(0.0, 2.0)
	shot.enemies[0].state = "orbit"
	shot.enemies[0].center = Vector2(0.0, 2.0)
	shot.ball_pos = Vector2(0.0, 3.0)
	shot.ball_vel = Vector2(0.0, -8.0)
	var s0: int = shot.score
	var killed := false
	var rebounded := false
	for k in 30:
		shot.step(1.0 / 60.0, false, false, false, 0)
		for e in shot.events:
			if e[0] == "enemy_destroyed" and not killed:
				killed = true
				rebounded = shot.ball_vel.y > 0.0
	check(killed and rebounded and shot.score >= s0 + Sim.ENEMY_POINTS, "plasma destroys enemy and rebounds")
	# Contact with the ship destroys the ship (one charge) and the enemy.
	var crash = Sim.new()
	crash.setup(3)
	crash.spawn_enemy(0.0)
	for k in 80:
		crash.step(1.0 / 60.0, false, false, false, 0)
	crash.enemies[0].state = "orbit"
	crash.enemies[0].center = Vector2(crash.paddle_x, Sim.PADDLE_Y)
	crash.enemies[0].pos = Vector2(crash.paddle_x, Sim.PADDLE_Y)
	var ship_hit := false
	for k in 5:
		crash.step(1.0 / 60.0, false, false, false, 0)
		for e in crash.events:
			if e[0] == "ship_destroyed":
				ship_hit = true
	check(ship_hit and crash.balls_left == 2 and crash.enemies.is_empty(), "enemy destroys the ship and itself")


## Windows accessibility flag parsing (D-070): 26 = shortcuts off (the director's
## current setting), 510 / 126 = Windows defaults with the shortcut on.
func test_system_checks() -> void:
	var SC = load("res://core/system_checks.gd")
	check(not SC.flags_warn(26), "flags 26 (shortcut off) -> no warning")
	check(SC.flags_warn(510) and SC.flags_warn(126), "default flags (shortcut on) -> warning")
	check(not SC.flags_warn(-1), "unreadable -> no warning")


## Every script in the project must parse/compile (catches errors in scenes the
## other tests never load, e.g. game modules).
func test_all_scripts_compile() -> void:
	for path in _gd_files("res://"):
		if path.begins_with("res://tests/"):
			continue
		var s: Script = load(path)
		check(s != null and s.can_instantiate(), "script compiles: %s" % path)


func test_ball_physics() -> void:
	var BP = load("res://games/breakout/ball_physics.gd")
	var rect := Rect2(0, 0, 2, 1)
	var c: Dictionary = BP.collide_circle_rect(Vector2(1, -0.1), 0.2, rect)
	check(not c.is_empty() and c.normal.is_equal_approx(Vector2.UP) and is_equal_approx(c.depth, 0.1), "circle hits rect top")
	check(BP.collide_circle_rect(Vector2(1, -0.5), 0.2, rect).is_empty(), "circle misses rect")
	var inside: Dictionary = BP.collide_circle_rect(Vector2(0.05, 0.5), 0.1, rect)
	check(not inside.is_empty() and inside.normal == Vector2.LEFT, "centre inside pushes out shallow side")
	check(BP.reflect(Vector2(1, 1), Vector2.UP).is_equal_approx(Vector2(1, -1)), "reflect")
	check(BP.reflect(Vector2(1, -1), Vector2.UP).is_equal_approx(Vector2(1, -1)), "no reflect when leaving")
	var mid: Vector2 = BP.paddle_bounce(0.0, 0.0, 1.0, 10.0, 0.0)
	check(mid.is_equal_approx(Vector2(0, -10)), "centre hit goes straight up")
	var edge: Vector2 = BP.paddle_bounce(1.0, 0.0, 1.0, 10.0, 0.0)
	check(edge.x > 8.0 and edge.y < 0.0 and is_equal_approx(edge.length(), 10.0), "edge hit goes steep right")
	var flat: Vector2 = BP.enforce_min_vertical(Vector2(10, 0.1), 10.0, 0.28)
	check(absf(flat.normalized().y) >= 0.279 and is_equal_approx(flat.length(), 10.0), "min vertical enforced")


## Autopilot plays Tilt Breaker headless: the ball must never leave the walls,
## bricks must break, and the game must end or keep going without errors.
func test_breakout_sim() -> void:
	var Sim = load("res://games/breakout/sim.gd")
	seed(1234)
	var sim = Sim.new()
	sim.setup(3)
	check(sim.bricks.size() == 44, "level 1 built from its file (%d bricks)" % sim.bricks.size())
	var l2: Array = Sim.level_layout(2)
	check(l2.size() >= 5 and l2[0] != l2[l2.size() - 1], "level 2 is not a rectangle")
	var dt := 1.0 / 120.0
	var escaped := false
	var bricks_broken := 0
	var paddle_hits := 0
	for i in int(180.0 / dt):  # 3 simulated minutes
		var target: float = sim.ball_pos.x + 0.35 * sin(i * 0.01)  # imperfect autopilot
		var left: bool = target < sim.paddle_x - 0.15
		var right: bool = target > sim.paddle_x + 0.15
		sim.step(dt, left, right, i % 240 == 0, 0)
		for e in sim.events:
			if e[0] == "brick":
				bricks_broken += 1
			elif e[0] == "paddle":
				paddle_hits += 1
		var f: Rect2 = Sim.FIELD
		if sim.ball_pos.x < f.position.x - 0.01 or sim.ball_pos.x > f.end.x + 0.01 \
				or sim.ball_pos.y < f.position.y - 0.01 or is_nan(sim.ball_pos.x):
			escaped = true
		if sim.state == Sim.State.LEVEL_CLEAR:
			sim.next_level()
		if sim.state == Sim.State.OVER:
			break
	check(not escaped, "ball never escapes the walls")
	check(bricks_broken > 20, "autopilot broke bricks (%d)" % bricks_broken)
	check(paddle_hits > 10, "paddle returned the ball (%d)" % paddle_hits)
	check(sim.score > 0, "score increased (%d)" % sim.score)
	# Dash moves faster than walking and respects the cooldown.
	var d = Sim.new()
	d.setup(3)
	d.step(0.05, false, false, false, 1)
	var after_dash: float = d.paddle_x
	d.step(0.05, false, false, false, 1)
	check(after_dash > 0.5 and d.events.filter(func(e): return e[0] == "dash").is_empty(), "dash + cooldown")
	# Energy blast (D-051, D-054): 0.8 s per level, up to 3 levels, 1/3 power per
	# level, only while the plasma is in play.
	var bl = Sim.new()
	bl.setup(3)
	var tally := {"blast": 0, "blast_fail": 0, "levels": []}
	var stepper := func(both: bool) -> void:
		if bl.state == Sim.State.SERVE and not both:
			bl.step(1.0 / 60.0, false, false, true, 0)  # keep the plasma in play
		else:
			bl.step(1.0 / 60.0, both, both, false, 0)
		for e in bl.events:
			if e[0] == "blast":
				tally.blast += 1
				tally.levels.append(e[1][1])
			elif e[0] == "blast_fail":
				tally.blast_fail += 1
	var serve_test = Sim.new()
	serve_test.setup(3)
	for k in 120:
		serve_test.step(1.0 / 60.0, true, true, false, 0)
	serve_test.step(1.0 / 60.0, false, false, false, 0)
	check(serve_test.blasts.is_empty() and is_equal_approx(serve_test.power, 1.0), "no blast while waiting to fire the plasma")
	stepper.call(false)  # fire the plasma
	bl.freeze_ball = true
	for shot in 3:  # three level-1 blasts (hold 0.9 s)
		for k in 54:
			stepper.call(true)
		stepper.call(false)
	check(tally.blast == 3 and tally.levels == [1, 1, 1], "three level-1 blasts (%s)" % [tally.levels])
	for k in 54:
		stepper.call(true)
	stepper.call(false)
	check(tally.blast == 3 and tally.blast_fail >= 1, "empty bar: no 4th blast, LOW POWER after a long hold")
	var quick = Sim.new()
	quick.setup(3)
	quick.step(1.0 / 60.0, false, false, true, 0)
	quick.freeze_ball = true
	quick.power = 0.0
	var fails := 0
	for k in 20:  # 0.33 s: shorter than LOW_POWER_HOLD
		quick.step(1.0 / 60.0, true, true, false, 0)
		fails += quick.events.filter(func(e): return e[0] == "blast_fail").size()
	check(fails == 0, "quick double-press on an empty bar stays silent (D-075)")
	check(Sim.BLAST_CHARGE_TIME < 0.7, "charge time cut (0.8 -> 0.68)")
	var lv = Sim.new()
	lv.setup(3)
	lv.step(1.0 / 60.0, false, false, true, 0)  # plasma in play
	lv.freeze_ball = true  # the ship can't move while charging; keep the plasma safe
	var reached: Array = []
	var fired: Array = []
	var pierced := 0
	var power_after_fire := -1.0
	for k in 60 * 3:
		lv.step(1.0 / 60.0, true, true, false, 0)
		for e in lv.events:
			if e[0] == "charged":
				reached.append(e[1])
			elif e[0] == "blast":
				fired.append(e[1][1])
				power_after_fire = lv.power
			elif e[0] == "brick":
				pierced += 1
	check(reached == [1, 2, 3], "charges through 3 levels (%s)" % [reached])
	check(fired == [3] and power_after_fire < 0.01, "level 3 fires automatically and spends the full bar (D-074)")
	lv.step(1.0 / 60.0, false, false, false, 0)
	check(lv.events.filter(func(e): return e[0] == "blast").is_empty(), "no second shot on release after auto-fire")
	for k in 120:
		lv.step(1.0 / 60.0, false, false, false, 0)
		pierced += lv.events.filter(func(e): return e[0] == "brick").size()
	check(pierced >= 3, "level-3 blast pierces 3 bricks (%d)" % pierced)
	var cap = Sim.new()
	cap.setup(3)
	cap.step(1.0 / 60.0, false, false, true, 0)
	cap.freeze_ball = true
	cap.power = 0.4  # only 1 level affordable (stays < 2/3 while recharging 3 s)
	for k in 60 * 3:
		cap.step(1.0 / 60.0, true, true, false, 0)
	check(is_equal_approx(cap.blast_charge, 1.0), "charge capped by available power")
	var p0: float = cap.power
	cap.step(1.0 / 60.0, false, false, false, 0)
	for k in 60 * 5:
		cap.step(1.0 / 60.0, false, false, false, 0)
	check(cap.power > p0 - Sim.BLAST_COST + 0.2, "slow recharge after delay")
	# Debug piercing line (D-057): destroys a whole column of bricks.
	var dbg = Sim.new()
	dbg.setup(3)
	dbg.debug_fire_line()
	var broken := 0
	for k in 90:
		dbg.step(1.0 / 60.0, false, false, false, 0)
		broken += dbg.events.filter(func(e): return e[0] == "brick").size()
	check(broken >= 4, "debug line destroys a full column (%d)" % broken)
	test_breakout_levels(Sim)
	test_breakout_difficulty(Sim)
	test_breakout_powerups(Sim)
	test_breakout_enemies(Sim)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		var sub := dir.path_join(d)
		if sub == "res://android" or sub == "res://addons" or sub == "res://exports":
			continue   # Android build template and third-party plugins (D-170)
		out.append_array(_gd_files(sub))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


## Turbo Run (D-089): track, auto throttle, drift, nitro, checkpoints, traffic.
## Every export must carry the plain data files read with FileAccess
## (D-172): levels (.txt). JSON is a resource and ships anyway. Only the Quest
## build turns OpenXR on (the "quest" feature tag, D-180).
func test_export_includes_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		return
	for sec in cfg.get_sections():
		if sec.ends_with(".options"):
			continue
		var preset_name := str(cfg.get_value(sec, "name", sec))
		var inc := str(cfg.get_value(sec, "include_filter", ""))
		check("*.txt" in inc, "the %s export includes the .txt level files" % preset_name)
		var feats := str(cfg.get_value(sec, "custom_features", ""))
		var xr := int(cfg.get_value(sec + ".options", "xr_features/xr_mode", 0))
		check((xr == 1) == ("quest" in feats), "%s: OpenXR mode only with the quest feature" % preset_name)


## Exported builds don't carry the CSV, only the imported translation (D-171):
## it must load and contain the game's keys.
func test_exported_translation() -> void:
	var t := load("res://core/locale/strings.en.translation") as Translation
	check(t != null and t.get_message("RC_TIME") != "" and t.get_message("GAME_RACER_TITLE") != "",
		"the imported translation (used by exported builds) loads with the game texts")


## Turbo Run time of day (D-193): stages 1-3 day, 4-5 sunset, 6-9 night, dawn at 10.
## HD graphics (D-195): every sprite kind has its HD cut-out and every car model
## its high-res texture in the shipped assets.
## D-197: the race's first nitro canister sits in the player's path.
func test_racer_first_nitro() -> void:
	var Sim = load("res://games/racer/sim.gd")
	var sm = Sim.new()
	sm.setup(7)
	sm.state = Sim.State.RACE
	sm.step(1.0 / 60.0, false, false)
	var first: Dictionary = sm.pickups[0]
	check(absf(float(first.x) - sm.x) < Sim.PICKUP_DX and first.s > sm.s, "the first nitro sits in front of the car")


## D-198: rams only count close together; running into the police slows it.
func test_racer_police_rams() -> void:
	var Sim = load("res://games/racer/sim.gd")
	var dt := 1.0 / 60.0
	# Two rams, then a long pause: the count starts again.
	var a = Sim.new()
	a.setup(7)
	a.state = Sim.State.RACE
	a.freeze_time = true
	a.grace_t = 0.0
	a.police = {"s": a.s - 2.0, "x": a.x, "v": a.v, "state": "chase", "t": 0.0, "hits": 2, "last_hit_t": 0.0, "side": 1.0}
	a.police.t = Sim.HIT_STREAK + 1.0
	a.police.hit_cd = 9.0   # no new ram this step
	a.step(dt, false, false)
	check(int(a.police.get("hits", 0)) == 0, "rams far apart in time don't add up to a bust")
	# Getting well ahead of it clears the count too.
	var b = Sim.new()
	b.setup(7)
	b.state = Sim.State.RACE
	b.freeze_time = true
	b.police = {"s": b.s - Sim.HIT_RESET_GAP - 10.0, "x": b.x, "v": b.v, "state": "chase", "t": 1.0, "hits": 2, "last_hit_t": 0.5, "side": 1.0}
	b.step(dt, false, false)
	check(int(b.police.get("hits", 0)) == 0, "pulling away from the police clears its rams")
	# Running into it from behind: it slows hard, we lose a little.
	var c = Sim.new()
	c.setup(7)
	c.state = Sim.State.RACE
	c.freeze_time = true
	c.grace_t = 0.0
	c.v = 50.0
	c.police = {"s": c.s + Sim.CAR_LEN * 0.6, "x": c.x, "v": 48.0, "state": "chase", "t": 1.0, "side": 1.0}
	c.step(dt, false, false)
	check(float(c.police.v) < 30.0 and c.v > 40.0 and int(c.police.get("hits", 0)) == 0,
		"running into the police car slows it, not a ram (%.0f / %.0f m/s)" % [float(c.police.v), c.v])


func test_racer_hd_assets() -> void:
	var Sprites = load("res://games/racer/sprites.gd")
	var missing: Array = []
	for kind in Sprites.KINDS:
		var f: String = Sprites.KINDS[kind][0]
		if not ResourceLoader.exists("res://assets/sprites/racer/hd/%s.png" % f):
			missing.append(f)
	check(missing.is_empty(), "HD sprite cut-outs exist (%s missing)" % ", ".join(missing))
	var Game = load("res://games/racer/game.gd")
	var miss_tex: Array = []
	for lo in Game.HD_TEXTURES:
		if not ResourceLoader.exists(Game.HD_TEXTURES[lo]):
			miss_tex.append(Game.HD_TEXTURES[lo])
	check(miss_tex.is_empty() and Game.HD_TEXTURES.size() == 7, "HD car textures exist for all seven models")
	# D-213: the oncoming horn is synthesised quickly, audible and not clipped flat.
	var hg = Game.new()
	var h_t0 := Time.get_ticks_msec()
	var horns: Array = []
	for pat in Game.HORN_PATTERNS:
		horns.append(hg._horn_wav(pat))
	var h_ms := Time.get_ticks_msec() - h_t0
	var h_ok := true
	for i in horns.size():
		var hw: AudioStreamWAV = horns[i]
		var peak := 0
		for j in range(0, hw.data.size(), 64):
			peak = maxi(peak, absi(hw.data.decode_s16(j)))
		h_ok = h_ok and peak > 16000 and hw.get_length() > 0.5
		if OS.has_environment("PG_HORN_OUT"):
			hw.save_to_wav(OS.get_environment("PG_HORN_OUT") + "/horn_%d.wav" % i)
	hg.free()
	check(h_ok and h_ms < 1500, "oncoming horns synthesise (%d ms) and are audible" % h_ms)
	# D-216: areas per stage, and the city's sidewalk barrier.
	var TrackA = load("res://games/racer/track.gd")
	var seq: Array = []
	for k in range(1, 12):
		seq.append(TrackA.stage_area(k))
	check(seq == ["beach", "beach", "forest", "forest", "desert", "city", "city", "fields", "snow", "snow", "snow"],
		"areas by stage (D-225: %s)" % ", ".join(seq))
	var SimA = load("res://games/racer/sim.gd")
	var cs = SimA.new()
	cs.setup(5)
	cs.state = SimA.State.RACE
	cs.s = 5.0 * SimA.CHECKPOINT_EVERY + 500.0
	cs.track.ensure(cs.s + 600.0)
	cs.x = 20.0
	cs.v = 30.0
	cs.step(1.0 / 60.0, false, false)
	check(cs.track.area_at(cs.s) == "city" and cs.x <= TrackA.CITY_WALL, "in town the car is held off the sidewalk (x %.1f)" % cs.x)
	var nb := 0
	for o in cs.track.objects_between(cs.s - 200.0, cs.s + 400.0):
		if o.kind == "building":
			nb += 1
	check(nb > 10 and not cs.track.junctions.is_empty(), "the city has buildings (%d) and junctions (%d)" % [nb, cs.track.junctions.size()])
	# D-221: the end of stage 10 is the finish line.
	var fs = SimA.new()
	fs.setup(4)
	fs.state = SimA.State.RACE
	fs.checkpoints = SimA.FINISH_STAGE - 1
	fs.next_checkpoint = SimA.FINISH_STAGE * SimA.CHECKPOINT_EVERY
	fs.s = fs.next_checkpoint - 5.0
	fs.track.ensure(fs.s + 800.0)
	fs.traffic.clear()
	fs.v = 40.0
	fs.time_left = 12.0
	var score0: int = fs.score
	var fin_ev := false
	for i in 900:
		fs.traffic.clear()
		fs.step(1.0 / 60.0, false, false)
		for e in fs.events:
			if e[0] == "finish":
				fin_ev = true
		if fs.done:
			break
	check(fs.finished and fin_ev and fs.done and fs.time_bonus == 12 * SimA.TIME_BONUS_PER_S
		and fs.score - score0 >= SimA.FINISH_BONUS + fs.time_bonus,
		"crossing the end of stage %d finishes the race with the bonuses" % SimA.FINISH_STAGE)
	# D-223: slow crashes only slow you; traffic behind waits; none past the finish.
	var sb = SimA.new()
	sb.setup(4)
	sb.state = SimA.State.RACE
	sb.s = 1000.0
	sb.track.ensure(2000.0)
	sb.traffic.clear()
	sb.x = TrackA.LANES[3]
	sb.v = 20.0   # about 38 mph
	sb.traffic.append({"id": 900, "s": sb.s + 3.0, "x": TrackA.LANES[3], "lane": 3, "v": 5.0, "hue": 0.0,
		"weave": 0.0, "last_ds": 6.0, "kind": "truck", "len": SimA.TRUCK_LEN, "w": SimA.TRUCK_W})
	sb.step(1.0 / 60.0, false, false)
	check(sb.spin_t <= 0.0 and not sb.flipping and sb.v < 20.0, "a slow knock into a truck only slows the car (%.1f m/s)" % sb.v)
	var sw = SimA.new()
	sw.setup(4)
	sw.state = SimA.State.RACE
	sw.s = 1000.0
	sw.track.ensure(2000.0)
	sw.traffic.clear()
	sw.x = TrackA.LANES[3]
	sw.v = 0.0
	sw.spin_t = 2.5
	sw.traffic.append({"id": 901, "s": sw.s - 60.0, "x": TrackA.LANES[3], "lane": 3, "v": 35.0, "v0": 35.0, "hue": 0.0,
		"weave": 0.0, "last_ds": -60.0, "kind": "car", "len": SimA.CAR_LEN, "w": SimA.CAR_W})
	for i in 150:
		sw.spin_t = maxf(sw.spin_t, 1.0)
		sw.v = 0.0
		sw._update_traffic(1.0 / 60.0)
	var waiter: Dictionary = sw.traffic[0] if not sw.traffic.is_empty() else {}
	check(not waiter.is_empty() and float(waiter.v) < 1.0 and sw.s - float(waiter.s) > SimA.CAR_LEN,
		"traffic behind a crash stops and waits")
	var sf = SimA.new()
	sf.setup(4)
	sf.state = SimA.State.RACE
	sf.s = SimA.FINISH_STAGE * SimA.CHECKPOINT_EVERY - 150.0
	sf.track.ensure(sf.s + 1500.0)
	sf.traffic.clear()
	for i in 200:
		sf._spawn_traffic()
	var past := 0
	for t in sf.traffic:
		if float(t.s) > SimA.FINISH_STAGE * SimA.CHECKPOINT_EVERY:
			past += 1
	check(past == 0 and sf.traffic_target() <= 11, "no traffic spawns past the finish line; at most 11 cars")
	# D-239: a side swipe turns both cars away from each other.
	var sws = SimA.new()
	sws.setup(4)
	sws.state = SimA.State.RACE
	sws.s = 1000.0
	sws.track.ensure(2000.0)
	sws.traffic.clear()
	sws.x = 3.6
	sws.v = 30.0
	sws.traffic.append({"id": 950, "s": sws.s + 0.5, "x": 1.875, "lane": 2, "v": 30.0, "hue": 0.0,
		"weave": 0.0, "last_ds": 0.5, "kind": "car", "len": SimA.CAR_LEN, "w": SimA.CAR_W})
	sws.step(1.0 / 60.0, false, false)
	var tsw: float = float(sws.traffic[0].get("sway", 0.0)) if not sws.traffic.is_empty() else 0.0
	# We're on its right (+x): our nose swings right (negative), its nose left (positive).
	check(sws.sway < -0.1 and tsw > 0.1, "a side swipe turns both cars away from each other (%.2f, %.2f)" % [sws.sway, tsw])
	# D-252: the analog stick steers proportionally.
	var xs: Array = []
	for amt in [0.5, 1.0]:
		var an = SimA.new()
		an.setup(4)
		an.state = SimA.State.RACE
		an.s = 600.0
		an.track.ensure(1500.0)
		an.v = 30.0
		an.gear = SimA.Gear.HIGH
		for i in 30:
			an.traffic.clear()
			an.steer_axis = amt
			an.step(1.0 / 60.0, false, false)
		xs.append(an.x)
	check(xs[0] > 0.05 and xs[1] > xs[0] * 1.3, "half stick steers less than full stick (%.2f vs %.2f m)" % [xs[0], xs[1]])
	# D-258: the accelerator revs on the grid.
	var rg = SimA.new()
	rg.setup(4)
	rg.gas_axis = 0.6
	for i in 60:
		rg.step(1.0 / 60.0, false, false)
	check(rg.state == SimA.State.COUNTDOWN and rg.rpm > 0.5 and rg.rpm < 0.65, "R2 revs on the grid in proportion (rpm %.2f)" % rg.rpm)
	# D-271: oncoming traffic never drives through a crashed car.
	var od = SimA.new()
	od.setup(4)
	od.state = SimA.State.RACE
	od.s = 1000.0
	od.track.ensure(2000.0)
	od.traffic.clear()
	od.x = TrackA.LANES[1]
	od.v = 0.0
	od.traffic.append({"id": 960, "s": od.s + 150.0, "x": TrackA.LANES[1], "lane": 1, "v": -30.0, "v0": -30.0, "hue": 0.0,
		"weave": 0.0, "last_ds": 150.0, "kind": "car", "len": SimA.CAR_LEN, "w": SimA.CAR_W})
	var hit := false
	for i in 600:
		od.spin_t = 1.0
		od.v = 0.0
		od._update_traffic(1.0 / 60.0)
		for t in od.traffic:
			if absf(float(t.s) - od.s) < SimA.CAR_LEN and absf(float(t.x) - od.x) < SimA.CAR_W:
				hit = true
	check(not hit, "oncoming traffic avoids a crashed car instead of driving through it")
	# D-284: 2P input: player 2's actions and keys.
	var CI = load("res://core/cabinet_input.gd")
	check(CI.for_player(&"launch", 1) == &"p2_launch" and CI.for_player(&"launch", 0) == &"launch"
		and CI.P2_ACTIONS.size() == 5 and CI.P2_KEYS.has("p2_flip_l"), "2P input: player 2's actions and keys")
	# D-219: random weather spells: at least WEATHER_MIN long, suited to the
	# area, different per seed, the same for the same seed.
	var spell_ok := true
	var firsts := {}
	for sd in range(1, 9):
		var wt = TrackA.new()
		wt.avoid_every = SimA.CHECKPOINT_EVERY
		wt.setup(3)
		wt.weather_seed = sd
		wt.ensure(10.0 * SimA.CHECKPOINT_EVERY)
		wt.weather(10.0 * SimA.CHECKPOINT_EVERY)
		firsts[int(float(wt.spells[0].a))] = true
		for sp in wt.spells:
			spell_ok = spell_ok and float(sp.b) - float(sp.a) >= TrackA.WEATHER_MIN
			var mid := (float(sp.a) + float(sp.b)) * 0.5
			spell_ok = spell_ok and sp.kind in TrackA.AREA_WEATHER[wt.area_at(mid)]
		var w_mid: Dictionary = wt.weather((float(wt.spells[0].a) + float(wt.spells[0].b)) * 0.5)
		spell_ok = spell_ok and not w_mid.is_empty() and wt.weather(float(wt.spells[0].a) - 10.0).is_empty()
	check(spell_ok and firsts.size() >= 6, "weather comes in random spells of at least %d m, suited to the area (D-219)" % int(TrackA.WEATHER_MIN))


func test_racer_time_of_day() -> void:
	var T = load("res://games/racer/sky.gd")
	var el := func(p: float) -> float: return T.sun_elevation(T.hour_at(p))
	var day_ok := true
	for p in [0.0, 1.0, 2.0, 2.9]:
		day_ok = day_ok and el.call(p) > 15.0
	check(day_ok, "stages 1-3: the sun is well up")
	check(el.call(3.0) > 0.0 and el.call(3.0) < 25.0 and el.call(4.5) > 0.0 and el.call(4.5) < 8.0, "stages 4-5: the sun is low (sunset)")
	check(el.call(4.99) < 0.0, "the sun has set by the end of stage 5")
	var night_ok := true
	for p in [5.2, 6.0, 7.0, 7.7]:
		night_ok = night_ok and T.night_level(el.call(p)) > 0.5
	check(night_ok, "stages 6-8: night (lights on, D-225)")
	check(el.call(8.0) < 0.0 and el.call(9.2) > 0.0, "dawn in stages 9-10: first light, then the sun comes up (D-225)")
	# One sun: its direction is a single unit vector, ahead of the road at sunset.
	var sd: Vector3 = T.sun_dir(18.0)
	check(is_equal_approx(sd.length(), 1.0) and sd.z < -0.9, "the sun sets ahead of the road's start")
	var md: Vector3 = T.moon_dir(24.0)
	check(md.y > 0.3 and md.z < 0.0, "the moon is up ahead at midnight")
	var a: Dictionary = T.palette(10.0)
	var b: Dictionary = T.palette(10.5)
	check((a.zenith as Color).is_equal_approx(b.zenith) == false and absf((a.zenith as Color).b - (b.zenith as Color).b) < 0.05,
		"the palette changes smoothly with the sun's elevation")


func test_racer_sim() -> void:
	var Sim = load("res://games/racer/sim.gd")
	var dt := 1.0 / 60.0
	# D-317: rear-ending a truck: it's shoved on, the car rolls off beside it, never through it.
	var rt = Sim.new()
	rt.setup(7)
	rt.state = Sim.State.RACE
	rt.time_left = 99.0
	rt.v = 60.0
	rt.x = float(Sim.Track.LANES[3])
	rt.traffic = [{"id": 900, "s": rt.s + 9.0, "x": rt.x, "lane": 3, "v": 22.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 9.0, "kind": "truck", "len": Sim.TRUCK_LEN, "w": Sim.TRUCK_W}]
	var inside := false
	var truck_v0 := 22.0
	var max_tv := 0.0
	for k in 240:
		rt.step(dt, false, false)
		for t in rt.traffic:
			if int(t.id) == 900:
				max_tv = maxf(max_tv, float(t.v))
				if absf(rt.s - float(t.s)) < (Sim.CAR_LEN + Sim.TRUCK_LEN) * 0.5 - 0.3 						and absf(rt.x - float(t.x)) < (Sim.CAR_W + Sim.TRUCK_W) * 0.5 - 0.3:
					inside = true
	check(rt.flipping or rt.spin_t > 0.0 or rt.grace_t > 0.0, "D-317: rear-ending a truck at speed rolls the car")
	check(not inside, "D-317: the rolling car never passes through the truck")
	check(max_tv > truck_v0 + 3.0, "D-317: the truck is shoved forward")
	# D-288: 2-player Turbo Run.
	var r2 = Sim.new()
	r2.setup_two(7, [0, 2])
	check(r2.player_get(0, "car") == 0 and r2.player_get(1, "car") == 2 		and float(r2.player_get(0, "x")) < 0.0 and float(r2.player_get(1, "x")) > 0.0,
		"2P racer: each player's own car, side by side on the grid")
	var idle := [false, false, false]
	for k in 400:   # countdown, then player 2 steers right (after the launch lock)
		r2.step_two(dt, [idle, [false, k > 300, false]])
	check(float(r2.player_get(1, "x")) > float(r2.player_get(0, "x")) + 3.0 and float(r2.player_get(0, "s")) > 60.0,
		"2P racer: each player steers only their own car; both drive")
	check(float(r2.player_get(0, "time_left")) >= 98.9, "2P racer: no clock")
	# Side by side and touching: both bounce apart.
	r2._use(0)
	r2.player_set(0, "x", 0.0)
	r2.player_set(1, "x", 1.2)
	r2.player_set(1, "s", float(r2.player_get(0, "s")))
	r2.player_set(0, "spin_t", 0.0)
	r2.player_set(1, "spin_t", 0.0)
	r2._rival_contact()
	check(float(r2.player_get(0, "lat_v")) < 0.0 and float(r2.player_get(1, "lat_v")) > 0.0, "2P racer: a side-swipe pushes both apart")
	# The first across the last line wins.
	r2.player_set(1, "checkpoints", Sim.FINISH_STAGE - 1)
	r2.player_set(1, "next_checkpoint", float(r2.player_get(1, "s")) + 5.0)
	for k in 60:
		r2.step_two(dt, [idle, idle])
	check(r2.winner == 1 and r2.player_get(1, "finished") and not r2.player_get(0, "finished"), "2P racer: the first to finish wins")
	for k in int(Sim.WIN_WAIT * 60.0) + 10:
		r2.step_two(dt, [idle, idle])
	check(r2.race_over, "2P racer: the race ends a while after the winner crosses")
	# D-183: the cars set the clock: the easy car gets the most time, the hard car the least.
	var times: Array = []
	var bonuses: Array = []
	var floors: Array = []
	for i in Sim.CARS.size():
		var c = Sim.new()
		c.setup(7)
		c.car = i
		times.append(c.start_time())
		bonuses.append(c.checkpoint_bonus())
		c.checkpoints = 50
		floors.append(c.checkpoint_bonus())
	check(times[0] > times[1] and times[1] > times[2], "start clock: easy > normal > hard")
	check(bonuses[0] > bonuses[1] and bonuses[1] > bonuses[2], "checkpoint time: easy > normal > hard")
	check(floors[0] > floors[1] and floors[1] > floors[2] and floors[2] > 0.0, "checkpoint floor: easy > normal > hard")
	check(times[1] == Sim.START_TIME and bonuses[1] == Sim.CHECKPOINT_BONUS, "normal car keeps the original clock")
	var a = Sim.new()
	a.setup(7)
	var b = Sim.new()
	b.setup(7)
	a.track.ensure(5000.0)
	b.track.ensure(5000.0)
	check(a.track.center(4000.0).is_equal_approx(b.track.center(4000.0)), "racer track is deterministic per seed")
	var hills := 0.0
	var curves := 0
	for i in 2000:
		hills = maxf(hills, absf(a.track.center(i * 2.5).y))
		if absf(a.track.curvature(i * 2.5)) > 1.0 / 120.0:
			curves += 1
	check(hills > 5.0 and curves > 0, "racer track has hills (%.1f m) and sharp curves" % hills)
	var steep := 0.0
	a.track.ensure(20000.0)
	for i in 8000:
		steep = maxf(steep, absf(a.track.slope(i * 2.5)))
	check(steep > 0.18, "the road has some steep climbs and drops (max grade %.0f %%)" % (steep * 100.0))
	var steep_tunnel := false
	for tv in a.track.tunnels:
		var ss: float = tv.x
		while ss < tv.y:
			steep_tunnel = steep_tunnel or absf(a.track.slope(ss)) > 0.12
			ss += 5.0
	check(not steep_tunnel, "tunnels don't go through steep hills")
	# The road never doubles back: heading stays within the limit and no stretch
	# passes near an earlier one (hillsides would cross the track, D-094).
	for seed_i in [1, 7, 42]:
		var t = load("res://games/racer/track.gd").new()
		t.setup(seed_i)
		t.ensure(30000.0)
		var max_h := 0.0
		var near := false
		for i in 6000:
			max_h = maxf(max_h, absf(t.heading(i * 5.0)))
		for i in range(0, 6000, 4):
			var p: Vector3 = t.center(i * 5.0)
			for j in range(i + 80, 6000, 4):   # 400 m or more further along
				var q: Vector3 = t.center(j * 5.0)
				if Vector2(p.x - q.x, p.z - q.z).length() < 160.0:
					near = true
					break
			if near:
				break
		check(max_h < deg_to_rad(85.0) and not near,
			"racer road (seed %d) never doubles back (max heading %.0f deg)" % [seed_i, rad_to_deg(max_h)])
	# Tunnels (D-127): some exist, clear of checkpoints, with nothing inside;
	# their walls hold the car on the road.
	var tt_ = load("res://games/racer/track.gd").new()
	tt_.avoid_every = 2300.0
	tt_.setup(7)
	tt_.ensure(30000.0)
	var clear := true
	for tv in tt_.tunnels:
		var k := ceilf((tv.x - 60.0) / 2300.0) * 2300.0
		clear = clear and k > tv.y + 60.0
		for o in tt_.objects_between(tv.x, tv.y):
			clear = false
	check(tt_.tunnels.size() >= 3 and clear, "tunnels appear, clear of checkpoints and empty (%d)" % tt_.tunnels.size())
	for sd in [1, 7, 42, 99]:
		var gt = load("res://games/racer/track.gd").new()
		gt.avoid_every = 2300.0
		gt.setup(sd)
		gt.ensure(6900.0)
		check(not gt.tunnels.is_empty() and (gt.tunnels[0] as Vector2).y < 6900.0 - 60.0,
			"seed %d: a tunnel comes in the forest, before stage 4 (D-132, D-225)" % sd)
	var tn = Sim.new()
	tn.setup(7)
	tn.track.ensure(30000.0)
	var tun: Vector2 = tn.track.tunnels[0]
	tn.state = Sim.State.RACE
	tn.gear = Sim.Gear.HIGH
	tn.s = tun.x + 10.0
	tn.v = 50.0
	var scraped := false
	for i in 90:
		tn.traffic.clear()
		tn.step(dt, false, true)
		for e in tn.events:
			scraped = scraped or e[0] == "scrape"
	check(tn.in_tunnel and tn.x <= tn.track.TUNNEL_HALF - Sim.CAR_W * 0.5 + 0.01 and scraped,
		"tunnel walls hold the car on the road (x %.1f)" % tn.x)
	# Speed traps + police (D-135).
	var pt = Sim.new()
	pt.setup(7)
	pt.track.ensure(20000.0)
	var first_trap: Dictionary = pt.track.next_trap(0.0)
	check(not first_trap.is_empty() and first_trap.s > Sim.CHECKPOINT_EVERY * 3.0,
		"speed cameras start after stage 3 (first at %.0f m)" % first_trap.get("s", 0.0))
	pt.state = Sim.State.RACE
	pt.gear = Sim.Gear.HIGH
	pt.s = first_trap.s - 300.0
	pt.v = 30.0
	pt.step(dt, false, false)
	check(pt.radar > 0.2 and pt.radar < 0.5, "the radar detector picks up a camera ahead (%.2f)" % pt.radar)
	# 99 mph past it: nothing happens.
	pt.v = 99.0 / Sim.MPH
	pt.s = first_trap.s - 0.3
	pt.traffic.clear()
	pt.step(dt, false, false)
	check(pt.police.is_empty(), "passing a camera slowly doesn't call the police")
	var cop = Sim.new()
	cop.setup(7)
	cop.track.ensure(20000.0)
	cop.state = Sim.State.RACE
	cop.gear = Sim.Gear.HIGH
	cop.s = first_trap.s - 0.3
	cop.next_checkpoint = cop.s + 99999.0   # no checkpoint points in the way
	cop.v = 101.0 / Sim.MPH   # just over 100 mph
	cop.score = 100000
	cop._score_f = 100000.0
	cop.step(dt, false, false)
	check(not cop.police.is_empty() and cop.police.s < cop.s - 100.0, "speeding past a camera calls a police car from behind")
	# Slow right down with the police close: busted, fined, held.
	# 20 m back is not close enough to bust (D-157)...
	cop.police.s = cop.s - 20.0
	cop.police.v = 0.0
	cop.v = 15.0
	cop.traffic.clear()
	cop.step(dt, false, false)
	check(cop.police.state == "chase", "slowing down with the police 20 m back is no bust yet")
	# ...right on you, it is.
	cop.police.s = cop.s - 8.0
	cop.v = 15.0
	var fined := 0
	var before: int = cop.score
	var lit_till_fine := true
	for i in 900:
		cop.traffic.clear()
		var lit_before: bool = cop.police_lights()
		cop.step(dt, false, false)
		for e in cop.events:
			if e[0] == "busted":
				fined = int(e[1])
				lit_till_fine = lit_till_fine and lit_before and not cop.police_lights()
		if fined > 0:
			break
		lit_till_fine = lit_till_fine and (i < 3 or cop.police_lights())
	check(fined == Sim.FINE and cop.score < before - Sim.FINE + 2000 and cop.busted_t > 0.0, "slowing down with the police close is a bust and a fine")
	check(lit_till_fine and cop.police.state == "bust", "the police lights stay on until the fine, then go off before it leaves (D-230)")
	for i in int((Sim.BUST_TIME + 1.0) * 60.0):
		cop.traffic.clear()
		cop.step(dt, false, false)
	check(cop.busted_t <= 0.0 and (cop.police.is_empty() or cop.police.state == "leave"), "after the fine the police drive off")
	# The police stays with the player instead of driving past (D-137).
	var pc = Sim.new()
	pc.setup(7)
	pc.state = Sim.State.RACE
	pc.manual = true
	pc.gear = Sim.Gear.HIGH
	pc.grace_t = 99.0          # no ramming: just watch it hold station
	pc.police = {"s": pc.s - 100.0, "x": 0.0, "v": 40.0, "state": "chase", "t": 0.0}
	var max_ahead := -999.0
	for i in 60 * 8:
		pc.s = clampf(pc.s, 0.0, 1e9)
		pc.v = 40.0 if i < 240 else 25.0
		pc.x = 0.0
		pc.traffic.clear()
		pc.step(dt, false, false, true)
		if i > 120:
			max_ahead = maxf(max_ahead, pc.police.s - pc.s)
	check(max_ahead < 4.0 and pc.police.s - pc.s > -15.0,
		"the police keeps alongside the player, not past (max %.1f m ahead)" % max_ahead)
	var pb = Sim.new()
	pb.setup(7)
	pb.state = Sim.State.RACE
	pb.police = {"s": pb.s - 3.0, "x": 0.0, "v": 80.0, "state": "chase", "t": 0.0}   # rams at full speed
	pb.v = 10.0
	for i in 60 * 3:
		pb.traffic.clear()
		pb.step(dt, false, false)
	check(not pb.police_lights(), "after the fine the police lights and siren go off (D-147)")
	check(pb.police.state == "bust" and absf(pb.police.s - pb.s - Sim.BLOCK_AHEAD) < 2.5
		and absf(float(pb.police.x) - pb.x) < 1.5,
		"on a bust the police stops across the lane in front of the player (%.1f m ahead)" % (pb.police.s - pb.s))
	# ... stays parked for a while, then drives off ahead instead of vanishing (D-139).
	var parked_for := 0.0
	var gone_ahead := false
	for i in 60 * 8:
		pb.traffic.clear()
		pb.step(dt, false, false)
		if not pb.police.is_empty():
			if pb.police.state == "bust":
				parked_for = float(pb.police.get("park_t", 0.0))
			if pb.police.state == "leave" and pb.police.s > pb.s + 30.0:
				gone_ahead = true
	check(parked_for >= Sim.PARK_HOLD - 0.05 and gone_ahead,
		"the police stays parked %.1f s, then drives off ahead" % parked_for)
	# Police hits (D-142): each slows the player and bounces the cars apart;
	# the third spins the player out. Nitro outruns it.
	var ph = Sim.new()
	ph.setup(7)
	ph.state = Sim.State.RACE
	ph.gear = Sim.Gear.HIGH
	ph.v = 70.0
	ph.police = {"s": ph.s, "x": 0.5, "v": 70.0, "state": "chase", "t": 0.0, "side": 1.0}
	ph._police_hit()
	check(ph.spin_t <= 0.0 and ph.v < 70.0 and ph.v > 45.0 and ph.lat_v != 0.0,
		"a police hit slows and shoves the player without stopping it")
	ph.police.hit_cd = 0.0
	ph._police_hit()
	ph.police.hit_cd = 0.0
	ph._police_hit()
	check(ph.spin_t > 0.0, "the third police hit spins the player out")
	var nz = Sim.new()
	nz.setup(7)
	nz.police = {"s": 0.0, "x": 0.0, "v": 0.0, "state": "chase", "t": 0.0}
	nz.v = nz.nitro_speed()
	nz._police_follow(10.0, 0.0, 100.0, 1000.0)
	check(float(nz.police.v) < nz.nitro_speed() - 5.0, "the police can't keep up with nitro")
	# Traffic yields to the police (D-163): pulls to its right-hand edge, slows, indicates.
	var yt = Sim.new()
	yt.setup(7)
	yt.state = Sim.State.RACE
	yt.grace_t = 99.0
	yt.police = {"s": yt.s - 50.0, "x": 0.0, "v": 0.0, "state": "chase", "t": 0.0}
	yt.traffic = [{"id": 1, "s": yt.s + 100.0, "x": 1.875, "lane": 2, "v": 40.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 100.0, "kind": "car", "len": Sim.CAR_LEN, "w": Sim.CAR_W},
		{"id": 2, "s": yt.s + 150.0, "x": -1.875, "lane": 1, "v": -30.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 150.0, "kind": "car", "len": Sim.CAR_LEN, "w": Sim.CAR_W}]
	for i in 60 * 3:
		yt.police.s = yt.s - 50.0
		yt.police.t = 0.0
		yt.step(dt, false, false)
	var ours: Dictionary = yt.traffic[0]
	var theirs: Dictionary = yt.traffic.filter(func(t): return t.id == 2)[0] if yt.traffic.any(func(t): return t.id == 2) else {}
	check(ours.blink and ours.x > 5.5 and ours.v < 30.0 and (theirs.is_empty() or theirs.x < -5.5),
		"traffic pulls over to its own right-hand edge for the police, indicating")
	# D-200: it only gives up once you've stayed far enough ahead long enough;
	# close behind you, it never does, however long the chase.
	var close_cop = Sim.new()
	close_cop.setup(7)
	close_cop.state = Sim.State.RACE
	close_cop.freeze_time = true
	close_cop.grace_t = 999.0
	close_cop.v = 50.0
	close_cop.police = {"s": close_cop.s - 30.0, "x": 5.0, "v": 50.0, "state": "chase", "t": 500.0, "side": 1.0}
	for i in 60 * 10:
		close_cop.traffic.clear()
		close_cop.v = 50.0
		close_cop.step(dt, false, false)
	check(not close_cop.police.is_empty() and close_cop.police.state == "chase",
		"a police car close behind never gives up, however long the chase")
	# D-203: a fresh chase (it appears POLICE_BEHIND back) can't be lost, and
	# the police closes in even on a car flat out.
	var fresh = Sim.new()
	fresh.setup(7)
	fresh.state = Sim.State.RACE
	fresh.freeze_time = true
	fresh.grace_t = 999.0
	fresh.gear = Sim.Gear.HIGH
	fresh.v = fresh.top_speed()
	fresh.police = {"s": fresh.s - Sim.POLICE_BEHIND, "x": 0.0, "v": fresh.v, "state": "chase", "t": 0.0, "side": 1.0}
	var gap0: float = fresh.s - float(fresh.police.s)
	for i in 60 * 8:
		fresh.traffic.clear()
		fresh.v = fresh.top_speed()
		fresh.step(dt, false, false)
	check(not fresh.police.is_empty() and fresh.police.state == "chase" and fresh.s - float(fresh.police.s) < gap0 - 10.0,
		"a fresh chase can't be lost: the police closes in on a car flat out")
	# D-201: flat out in H, every car slowly pulls away from the police.
	for ci in Sim.CARS.size():
		var flat = Sim.new()
		flat.setup(7)
		flat.car = ci
		flat.state = Sim.State.RACE
		flat.freeze_time = true
		flat.grace_t = 999.0
		flat.gear = Sim.Gear.HIGH
		flat.v = flat.top_speed()
		flat.police = {"s": flat.s - 20.0, "x": 5.0, "v": flat.v, "state": "chase", "t": 1.0, "side": 1.0}
		for i in 60 * 10:
			flat.traffic.clear()
			flat.v = flat.top_speed()
			flat.step(dt, false, false)
		check(flat.police.is_empty() or float(flat.police.s) < flat.s - 40.0,
			"car %d at its top speed pulls away from the police" % ci)
	var run = Sim.new()
	run.setup(7)
	run.state = Sim.State.RACE
	run.freeze_time = true
	run.police = {"s": run.s - Sim.ESCAPE_GAP - 30.0, "x": 0.0, "v": 0.0, "state": "chase", "t": 1.0, "caught": true}
	run.v = 60.0
	run.gear = Sim.Gear.HIGH
	var esc := false
	var check_ok := true
	var esc_steps := 0
	while not esc and esc_steps < int(60 * (Sim.ESCAPE_TIME + 1.0)):
		run.traffic.clear()
		run.step(dt, false, false)
		esc_steps += 1
		for e in run.events:
			esc = esc or e[0] == "police_escape"
	check(esc and esc_steps >= int(60 * Sim.ESCAPE_TIME) - 1 and run.police.state == "giveup" and not run.police_lights(),
		"staying %d m ahead for %d s loses the police, lights off" % [int(Sim.ESCAPE_GAP), int(Sim.ESCAPE_TIME)])
	for i in 60 * 6:
		run.traffic.clear()
		run.step(dt, false, false)
		check_ok = check_ok and (run.police.is_empty() or run.police.s < run.s)
	check(check_ok, "an escaped police car drops behind instead of passing")
	# Countdown, then automatic throttle.
	var c = Sim.new()
	c.setup(7)
	for i in 60 * 3 + 5:
		c.step(dt, false, false)
	check(c.state == Sim.State.RACE, "racer countdown ends in RACE")
	# Flippers rev the engine on the grid (D-112).
	var rv = Sim.new()
	rv.setup(7)
	for i in 45:
		rv.step(dt, true, false)
	var revved: float = rv.rpm
	for i in 60:
		rv.step(dt, false, false)
	check(revved > 0.8 and rv.rpm < 0.2 and rv.v == 0.0, "flippers rev the engine during the countdown (%.2f)" % revved)
	# Steering scales with speed (D-119): a slow car barely moves sideways.
	var slow = Sim.new()
	slow.setup(7)
	slow.state = Sim.State.RACE
	slow.manual = true
	slow.v = 5.0
	var fast = Sim.new()
	fast.setup(7)
	fast.state = Sim.State.RACE
	fast.gear = Sim.Gear.HIGH
	fast.v = 50.0
	for i in 60:
		slow.v = 5.0
		slow.s = Sim.START_S + 50.0
		fast.s = Sim.START_S + 50.0
		slow.step(dt, false, true)
		fast.step(dt, false, true)
	check(slow.x < 2.0 and fast.x > 6.0, "sideways movement scales with speed (%.1f m slow, %.1f m fast)" % [slow.x, fast.x])
	# Handling by gear (D-120): in the same bend at the same speed, H drifts
	# further to the outside than L.
	var hg = Sim.new()
	hg.setup(7)
	hg.track.ensure(8000.0)
	var bend := -1.0
	for i in 4000:
		if absf(hg.track.curvature(i * 2.0)) > 1.0 / 160.0:
			bend = i * 2.0
			break
	var lg = Sim.new()
	lg.setup(7)
	lg.track.ensure(8000.0)
	for sim_g in [hg, lg]:
		sim_g.state = Sim.State.RACE
		sim_g.manual = true
		sim_g.s = bend
	hg.gear = Sim.Gear.HIGH
	for i in 45:
		hg.v = 44.0
		lg.v = 44.0
		hg.step(dt, false, false, true)
		lg.step(dt, false, false, true)
	var cb: float = hg.track.curvature(bend)
	check(bend > 0.0 and hg.x * signf(cb) > lg.x * signf(cb) + 0.5,
		"high gear slides wider in a bend than low (%.1f vs %.1f m)" % [hg.x * signf(cb), lg.x * signf(cb)])
	# Car choice (D-122): the hard car is faster but slides wider than the easy one.
	var cars := []
	for ci in 3:
		var cs = Sim.new()
		cs.setup(7)
		cs.track.ensure(8000.0)
		cs.car = ci
		cs.state = Sim.State.RACE
		cs.manual = true
		cs.gear = Sim.Gear.HIGH
		cs.s = bend
		for i in 45:
			cs.v = 44.0
			cs.step(dt, false, false, true)
		cars.append(cs)
	check(cars[0].top_speed() < cars[1].top_speed() and cars[1].top_speed() < cars[2].top_speed()
		and cars[0].x * signf(cb) < cars[2].x * signf(cb) - 0.5,
		"easy car is slower but grips; hard car is fastest but slides wide")
	# Perfect start (D-118): revs in the perfect band at GO launch the car.
	var good = Sim.new()
	good.setup(7)
	var plain = Sim.new()
	plain.setup(7)
	var launched := false
	for i in 60 * 3 + 10:
		var hold: bool = good.rpm < (Sim.START_FROM + Sim.START_TO) * 0.5
		good.step(dt, hold, false)
		plain.step(dt, false, false)
		for e in good.events:
			launched = launched or e[0] == "perfect_start"
	var hr = Sim.new()
	hr.setup(7)
	for i in 60 * 3 + 40:
		hr.step(dt, true, false)
	var held_x: float = hr.x
	for i in 30:
		hr.step(dt, false, false)
		hr.step(dt, true, false)
	check(absf(held_x) < 0.01 and hr.x < -0.1,
		"a flipper held to rev at GO doesn't steer until it is released and pressed again (D-131)")
	check(launched and good.v > plain.v + 8.0, "a perfect rev at GO launches faster (%.0f vs %.0f m/s)" % [good.v, plain.v])
	good.freeze_time = true
	var t_before: float = good.time_left
	for i in 60:
		good.step(dt, false, false)
	check(good.time_left == t_before, "the debug cheat freezes the clock")
	# Gears (D-103): L tops out at its rev limit; both flippers held 0.5 s shift
	# to H, which then reaches top speed. H is slow off the line. (The first
	# canister sits in the car's path since D-197: keep nitro out of this.)
	for i in 60 * 8:
		c.pickups.clear()
		c.boost_t = 0.0
		c.boosting = false
		c.step(dt, false, false)
	check(c.gear == Sim.Gear.LOW and absf(c.v - c.l_top()) < 2.0 and c.rpm > Sim.REDLINE,
		"low gear tops out at its rev limit (%.0f m/s, rpm %.2f)" % [c.v, c.rpm])
	var shifted := false
	for i in 40:
		c.s = Sim.START_S + 100.0   # stay on the straight: no steering while shifting
		c.step(dt, true, true)
		for e in c.events:
			shifted = shifted or e[0] == "shift"
	check(shifted and c.gear == Sim.Gear.HIGH, "holding both flippers 0.5 s shifts to high gear")
	for i in 20:
		c.s = Sim.START_S + 100.0
		c.step(dt, true, true)
	check(c.gear == Sim.Gear.HIGH, "keeping them held does not shift again")
	c.traffic.clear()
	for i in 60 * 8:
		c.s = Sim.START_S + 100.0   # on the straight
		c.x = 0.0
		c.step(dt, false, false)
		c.traffic.clear()
	check(c.v > c.top_speed() - 3.0, "high gear reaches top speed (%.0f m/s)" % c.v)
	check(roundi(Sim.CARS[2].top * Sim.MPH) == 168,
		"the fastest car's top speed reads 168 mph / 270 km/h (D-147)")
	var lo = Sim.new()
	lo.setup(7)
	lo.state = Sim.State.RACE
	var hi = Sim.new()
	hi.setup(7)
	hi.state = Sim.State.RACE
	hi.gear = Sim.Gear.HIGH
	for i in 60 * 2:
		lo.step(dt, false, false)
		hi.step(dt, false, false)
	check(lo.v > hi.v * 1.5, "low gear pulls away much faster than high (%.0f vs %.0f m/s)" % [lo.v, hi.v])
	# Perfect shift (D-116): upshifting inside the window gives a boost; at the
	# redline it doesn't.
	var ps = Sim.new()
	ps.setup(7)
	ps.state = Sim.State.RACE
	ps.v = Sim.GEAR_L_TOP * 0.82
	ps.rpm = 0.82
	var v0: float = ps.v
	ps.shift(Sim.Gear.HIGH)
	var perfect_ev: bool = ps.events.any(func(e): return e[0] == "perfect_shift")
	check(perfect_ev and ps.v > v0 + 2.0 and ps.perfect_t > 0.0, "a perfect upshift gives a boost")
	var late = Sim.new()
	late.setup(7)
	late.state = Sim.State.RACE
	late.rpm = 0.95
	late.shift(Sim.Gear.HIGH)
	check(not late.events.any(func(e): return e[0] == "perfect_shift"), "an upshift at the redline is not perfect")
	var q = Sim.new()
	q.setup(7)
	q.state = Sim.State.RACE
	for i in 10:
		q.step(dt, true, true)
	q.step(dt, false, false)
	check(q.gear == Sim.Gear.LOW, "a short both-flipper tap does not shift")
	# Nitro canisters on the road (D-103): drive through one for 5 s of boost.
	var n = Sim.new()
	n.setup(7)
	n.state = Sim.State.RACE
	n.gear = Sim.Gear.HIGH
	n.step(dt, false, false)
	check(n.pickups.size() > 0, "nitro canisters are placed on the road ahead")
	var pk: Dictionary = n.pickups[0]
	n.s = pk.s - 1.0
	n.x = pk.x
	n.v = 50.0
	n.traffic.clear()
	var got := false
	n.step(dt, false, false)
	for e in n.events:
		got = got or e[0] == "nitro"
	check(got and n.boosting and absf(n.boost_t - Sim.NITRO_TIME) < 0.05, "driving through a canister starts 5 s of nitro")
	var ended := false
	for i in 60 * 5 + 10:
		n.traffic.clear()
		n.step(dt, false, false)
		for e in n.events:
			ended = ended or e[0] == "nitro_end"
	check(ended and not n.boosting, "nitro ends by itself after 5 s")
	# Drift: steering into a sharp curve at speed breaks loose and scores.
	var d = Sim.new()
	d.setup(7)
	d.state = Sim.State.RACE
	var s_curve := -1.0
	d.track.ensure(8000.0)
	for i in 4000:
		if absf(d.track.curvature(i * 2.0)) > 1.0 / 110.0:
			s_curve = i * 2.0
			break
	d.s = s_curve
	d.gear = Sim.Gear.HIGH
	d.v = 70.0
	var cv: float = d.track.curvature(d.s)
	var drifted := false
	for i in 30:
		d.step(dt, cv > 0.0, cv < 0.0)
		drifted = drifted or d.drifting
	check(s_curve > 0.0 and drifted and d.v > 60.0, "steering into a sharp curve at speed drifts and keeps speed")
	d.traffic.clear()
	for i in 30:
		d.step(dt, false, false)
	check(not d.drifting and d.score > 0, "releasing the steering ends the drift and banks points")
	# Same curve without drifting: auto-brake slows the car instead.
	var ab = Sim.new()
	ab.setup(7)
	ab.track.ensure(8000.0)
	ab.state = Sim.State.RACE
	ab.s = s_curve
	ab.gear = Sim.Gear.HIGH
	ab.v = 75.0
	ab.x = 4.0 if cv > 0.0 else -4.0  # already on the outside
	var braked := false
	for i in 40:
		ab.step(dt, false, false)
		braked = braked or ab.auto_braking
	check(braked and not ab.drifting, "auto mode brakes when a corner would throw the car off")
	# Checkpoint extends the time; running out ends the race.
	var cp = Sim.new()
	cp.setup(7)
	cp.state = Sim.State.RACE
	cp.s = Sim.CHECKPOINT_EVERY - 0.5
	cp.v = 60.0
	var t0: float = cp.time_left
	cp.step(dt, false, false)
	check(cp.checkpoints == 1 and cp.time_left > t0 + 20.0, "checkpoint extends the clock")
	cp.time_left = 0.01
	cp.step(dt, false, false)
	check(cp.state == Sim.State.OVER, "time up ends the race")
	# Reaching a checkpoint on momentum after TIME UP puts the time back (D-103).
	cp.s = cp.next_checkpoint - 30.0
	cp.v = 40.0
	cp.traffic.clear()
	var saved := false
	for i in 120:
		cp.traffic.clear()
		cp.step(dt, false, false)
		for e in cp.events:
			saved = saved or (e[0] == "checkpoint" and e[3])
	check(saved and cp.state == Sim.State.RACE and cp.time_left > 15.0 and not cp.done,
		"a checkpoint reached by coasting after TIME UP extends the time and the race goes on")
	cp.time_left = 0.01
	cp.step(dt, false, false)
	cp.v = 10.0
	for i in 60 * 4:
		cp.traffic.clear()
		cp.step(dt, false, false)
	check(cp.state == Sim.State.OVER and cp.done, "coasting to a stop short of a checkpoint ends the game")
	# Rear-ending a slower car at speed crashes; passing close is a near miss.
	var tr = Sim.new()
	tr.setup(7)
	tr.state = Sim.State.RACE
	tr.s = 100.0
	tr.gear = Sim.Gear.HIGH
	tr.v = 75.0
	tr.x = 1.875
	tr.traffic = [{"id": 1, "s": 104.2, "x": 1.875, "lane": 2, "v": 30.0, "hue": 0.3, "weave": 0.0, "last_ds": 4.6}]
	tr.step(dt, false, false)
	check(tr.spin_t > 0.0 and tr.v <= 14.0 and not tr.flipping, "rear-ending traffic at speed spins out")
	# Side-swipe (D-152): touching a car alongside bumps both apart, no crash.
	var sw = Sim.new()
	sw.setup(7)
	sw.state = Sim.State.RACE
	sw.gear = Sim.Gear.HIGH
	sw.s = 100.0
	sw.v = 50.0
	sw.x = 0.1
	sw.traffic = [{"id": 1, "s": 100.5, "x": 1.875, "lane": 2, "v": 40.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 0.5, "kind": "car", "len": Sim.CAR_LEN, "w": Sim.CAR_W}]
	sw.step(dt, false, false)
	check(sw.spin_t <= 0.0 and sw.v < 50.0 and sw.v > 44.0 and sw.lat_v < 0.0 and float(sw.traffic[0].shove) > 0.0,
		"a side-swipe bumps both cars apart without a crash")
	# Every crash ends stopped dead for CRASH_STOP s, then the car drives on (D-101).
	tr.traffic.clear()
	var stopped_for := 0.0
	var steps := 0
	while tr.spin_t > 0.0 and steps < 600:
		tr.step(dt, false, false)
		tr.traffic.clear()
		steps += 1
		if tr.stalled() and tr.v == 0.0:
			stopped_for += dt
	for i in 30:
		tr.step(dt, false, false)
	check(absf(stopped_for - Sim.CRASH_STOP) < 0.05 and tr.v > 0.0,
		"a crash ends with the car stopped for %.2f s, then it drives on" % stopped_for)
	# Then 3 s of immunity to traffic (D-125).
	check(tr.grace_t > 2.0, "after a crash the car is immune to traffic for a while")
	tr.traffic = [{"id": 9, "s": tr.s + 1.0, "x": tr.x, "lane": 2, "v": -25.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 1.0, "kind": "car", "len": Sim.CAR_LEN, "w": Sim.CAR_W}]
	tr.step(dt, false, false)
	check(tr.spin_t <= 0.0, "an immune car drives through traffic")
	# Traffic keeps to its side (D-099): right lanes go our way, left lanes come
	# at us; some of it is trucks.
	var tf = Sim.new()
	tf.setup(7)
	tf.state = Sim.State.RACE
	var lanes_ok := true
	var seen := {"ahead": 0, "oncoming": 0, "truck": 0}
	for i in 400:
		tf.traffic.clear()
		tf._spawn_traffic()
		for t in tf.traffic:
			lanes_ok = lanes_ok and ((t.v < 0.0 and t.x < 0.0) or (t.v > 0.0 and t.x > 0.0))
			seen["oncoming" if t.v < 0.0 else "ahead"] += 1
			if t.kind == "truck":
				seen.truck += 1
	check(lanes_ok and seen.ahead > 100 and seen.oncoming > 100 and seen.truck > 40,
		"traffic drives on its own side, both directions, with trucks (%s)" % str(seen))
	var ho = Sim.new()
	ho.setup(7)
	ho.state = Sim.State.RACE
	ho.s = 100.0
	ho.v = 40.0
	ho.x = -1.875
	ho.traffic = [{"id": 1, "s": 104.6, "x": -1.875, "lane": 1, "v": -25.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 5.2, "kind": "car", "len": Sim.CAR_LEN, "w": Sim.CAR_W}]
	ho.step(dt, false, false)
	check(ho.spin_t > 0.0 and not ho.flipping, "a head-on with an oncoming car crashes")
	# Oncoming drivers flash their high beams at a car in their lane (D-105).
	var hb = Sim.new()
	hb.setup(7)
	hb.state = Sim.State.RACE
	hb.s = 100.0
	hb.v = 30.0
	hb.x = -5.625
	hb.traffic = [{"id": 1, "s": 200.0, "x": -5.625, "lane": 0, "v": -25.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 100.0, "kind": "car", "len": Sim.CAR_LEN, "w": Sim.CAR_W},
		{"id": 2, "s": 200.0, "x": -1.875, "lane": 1, "v": -25.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 100.0, "kind": "car", "len": Sim.CAR_LEN, "w": Sim.CAR_W}]
	hb.step(dt, false, false)
	var honks := 0
	for e in hb.events:
		if e[0] == "high_beams":
			honks += 1
	check(hb.traffic[0].flash and not hb.traffic[1].flash and honks == 1,
		"an oncoming car flashes its high beams only at a car in its lane")
	hb.step(dt, false, false)
	check(hb.events.filter(func(e): return e[0] == "high_beams").is_empty(), "it honks only once")
	var tk = Sim.new()
	tk.setup(7)
	tk.state = Sim.State.RACE
	tk.s = 100.0
	tk.gear = Sim.Gear.HIGH
	tk.v = 70.0
	tk.x = 5.0
	tk.traffic = [{"id": 1, "s": 107.5, "x": 5.625, "lane": 3, "v": 22.0, "hue": 0.0, "weave": 0.0,
		"last_ds": 7.6, "kind": "truck", "len": Sim.TRUCK_LEN, "w": Sim.TRUCK_W}]
	tk.step(dt, false, false)
	check(tk.flipping, "rear-ending a truck at speed rolls the car over")
	# A big roadside object rolls the car over, away from the obstacle (D-098).
	var fl = Sim.new()
	fl.setup(7)
	fl.track.ensure(12000.0)   # past the beach stages, which have no rocks (D-225)
	var rock: Dictionary = {}
	for o in fl.track.objects:
		if o.kind == "rock":
			rock = o
			break
	fl.state = Sim.State.RACE
	fl.s = rock.s
	fl.x = rock.x - signf(rock.x) * 0.5
	fl.gear = Sim.Gear.HIGH
	fl.v = 60.0
	fl.step(dt, false, false)
	check(fl.flipping and fl.spin_t > Sim.SPIN_TIME and fl.flip_dir == -signf(rock.x),
		"hitting a rock flips the car over, away from it")
	check(fl.gear == Sim.Gear.LOW, "a crash shifts down to low gear by itself (D-112)")
	# The roll-over tumbles on down the road, then stops (D-105).
	check(fl.flip_turns == (2 if 60.0 * Sim.MPH >= Sim.DOUBLE_FLIP_MPH else 1),
		"a roll-over at 100+ mph rolls twice (D-206)")
	var s_hit: float = fl.s
	for i in int(fl.crash_anim * 60.0) + 2:
		fl.traffic.clear()
		fl.step(dt, false, false)
	check(fl.s - s_hit > 25.0 and fl.v > 10.0, "the car keeps advancing as it rolls over (%.0f m)" % (fl.s - s_hit))
	# ... then slides on its side, slowing down, before the stop (D-106).
	var slid := false
	var n_steps := 0
	while not fl.stalled() and n_steps < 600:
		fl.traffic.clear()
		fl.step(dt, false, false)
		slid = slid or fl.crash_slide
		n_steps += 1
	# Off-road crash: the car is put back on the road by the end of the stop (D-114).
	var off_x: float = fl.x
	while fl.spin_t > 0.0:
		fl.traffic.clear()
		fl.step(dt, false, false)
	check(absf(off_x) > Sim.RECOVER_X and absf(fl.x) <= Sim.RECOVER_X + 0.01,
		"a crash that ends off the road is put back on it (x %.1f -> %.1f)" % [off_x, fl.x])
	check(slid and fl.s - s_hit > 40.0,
		"after the roll the car slides to a stop (%.0f m in all), then stays stopped" % (fl.s - s_hit))
	fl.spin_t = 0.0
	fl.flipping = false
	fl._crash("chevron", 1.0)
	check(not fl.flipping, "a small sign only spins the car")
	var nm = Sim.new()
	nm.setup(7)
	nm.state = Sim.State.RACE
	nm.s = 100.0
	nm.gear = Sim.Gear.HIGH
	nm.v = 75.0
	nm.x = -1.0
	nm.traffic = [{"id": 1, "s": 100.5, "x": 1.875, "lane": 2, "v": 30.0, "hue": 0.3, "weave": 0.0, "last_ds": 0.5}]
	var near := false
	for i in 3:
		nm.step(dt, false, false)
		for e in nm.events:
			near = near or e[0] == "near_miss"
	check(near, "passing traffic closely scores a near miss")
	# Manual mode: no gas = no acceleration.
	var m = Sim.new()
	m.setup(7)
	m.state = Sim.State.RACE
	m.manual = true
	for i in 60:
		m.step(dt, false, false, false, false)
	check(m.v > 8.0, "4-button mode: the throttle is automatic (D-189)")
	var mv0: float = m.v
	for i in 30:
		m.step(dt, false, false, false, true)
	check(m.v < mv0 - 5.0 and m.braking, "4-button mode: the left magna brakes")
	# The shifter button flips the gear once per press; both flippers don't shift.
	var g0: int = m.gear
	m.shift_request = true
	m.step(dt, false, false)
	check(m.gear != g0 and not m.shift_request, "4-button shifter flips the gear")
	var g1: int = m.gear
	for i in 60:
		m.step(dt, true, true)
	check(m.gear == g1, "4-button mode: holding both flippers doesn't shift")
	m.state = Sim.State.COUNTDOWN
	m.shift_request = true
	m.step(dt, false, false)
	check(not m.shift_request, "a shifter press on the grid is dropped")

