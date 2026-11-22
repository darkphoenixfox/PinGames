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
	check(starts == [["charge_start", 3], ["charged", 3]], "power laser: only level-3 charge effects (%s)" % [starts])
	# I: only level 3, full bar, clears the column.
	var ion = mk.call()
	ion.apply_powerup("I")
	for k in 20:
		ion.step(dt, true, true, false, 0)
	ion.step(dt, false, false, false, 0)
	check(ion.power > 0.9, "ion: releasing before level 3 does nothing")
	var before: int = ion.bricks_alive()
	for k in 200:
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
	check(sh.affordable_level() == 0, "shield: no charged shot")
	sh.ball_pos = Vector2(-3.0, Sim.SHIELD_Y - 0.5)
	sh.ball_vel = Vector2(0, 9)
	for k in 10:
		sh.step(dt, false, false, false, 0)
	check(sh.ball_vel.y < 0.0 and not sh.shield_active and sh.balls_left == 3, "shield bounces one ball, then breaks")
	check(sh.powerup == "" and sh.affordable_level() > 0, "lost shield returns to the normal plasma cannon (D-084)")
	# L: afterimages trail the moving ship and are cleared with the power-up on death.
	var ls = mk.call()
	ls.apply_powerup("L")
	for k in 12:  # still accelerating, not yet at the wall
		ls.step(dt, false, true, false, 0)
	check(ls.ghost_xs().size() == 2, "lightspeed: two afterimages while moving")
	ls.power = 0.2
	ls._lose_ball()
	check(ls.powerup == "", "power-up ends on death")
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
func test_breakout_levels(Sim) -> void:
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
	test_breakout_powerups(Sim)
	test_breakout_enemies(Sim)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		out.append_array(_gd_files(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


## Turbo Run (D-089): track, auto throttle, drift, nitro, checkpoints, traffic.
func test_racer_sim() -> void:
	var Sim = load("res://games/racer/sim.gd")
	var dt := 1.0 / 60.0
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
		gt.ensure(4600.0)
		check(not gt.tunnels.is_empty() and (gt.tunnels[0] as Vector2).y < 4600.0 - 60.0,
			"seed %d: a tunnel comes before stage 3 (D-132)" % sd)
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
	for i in 5:
		cop.traffic.clear()
		cop.step(dt, false, false)
		for e in cop.events:
			if e[0] == "busted":
				fined = int(e[1])
	check(fined == Sim.FINE and cop.score < before - Sim.FINE + 2000 and cop.busted_t > 0.0, "slowing down with the police close is a bust and a fine")
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
	# Outrunning it long enough: it gives up with a bonus.
	var run = Sim.new()
	run.setup(7)
	run.state = Sim.State.RACE
	run.police = {"s": run.s - 100.0, "x": 0.0, "v": 0.0, "state": "chase", "t": Sim.POLICE_GIVE_UP}
	run.v = 60.0
	run.gear = Sim.Gear.HIGH
	var esc := false
	var check_ok := true
	run.step(dt, false, false)
	for e in run.events:
		esc = esc or e[0] == "police_escape"
	check(esc and run.police.state == "giveup" and not run.police_lights(),
		"outrunning the police long enough makes them give up, lights off")
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
	# to H, which then reaches top speed. H is slow off the line.
	for i in 60 * 8:
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
	fl.track.ensure(2000.0)
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
	var s_hit: float = fl.s
	for i in int(Sim.FLIP_TIME * 60.0) + 2:
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
	check(m.v < 1.0, "manual mode needs the gas button")
	for i in 60:
		m.step(dt, false, false, true, false)
	check(m.v > 8.0, "manual gas accelerates")

