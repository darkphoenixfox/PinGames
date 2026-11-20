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
	test_ball_physics()
	test_breakout_sim()
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
	check(sim.bricks.size() == Sim.BRICK_ROWS * Sim.BRICK_COLS, "rack built")
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
