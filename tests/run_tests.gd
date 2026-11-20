## Headless smoke tests. Run: scripts/test.ps1  (or scripts/test.sh)
## Only loads pure helpers from core/util, so it works without autoloads.
extends SceneTree

const CliUtil = preload("res://core/util/cli.gd")
const Bindings = preload("res://core/util/bindings.gd")
const CsvI18n = preload("res://core/util/csv_i18n.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_cli()
	test_bindings()
	test_translation_keys()
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


func test_bindings() -> void:
	var k := Bindings.to_event("key:Shift@left") as InputEventKey
	check(k != null and k.physical_keycode == KEY_SHIFT and k.location == KEY_LOCATION_LEFT, "binding left shift")
	var e := Bindings.to_event("key:Enter") as InputEventKey
	check(e != null and e.physical_keycode == KEY_ENTER, "binding enter")
	var j := Bindings.to_event("joy:9") as InputEventJoypadButton
	check(j != null and j.button_index == 9, "binding joy button")
	var a := Bindings.to_event("axis:5+") as InputEventJoypadMotion
	check(a != null and a.axis == 5 and a.axis_value > 0.0, "binding axis")
	check(Bindings.to_event("key:NotAKey") == null, "binding rejects bad key")
	check(Bindings.to_event("nonsense") == null, "binding rejects bad format")
	# Every default binding must parse.
	var defaults: Dictionary = load("res://core/cabinet_input.gd").DEFAULT_BINDINGS
	for action in defaults:
		for b in defaults[action]:
			check(Bindings.to_event(b) != null, "default binding parses: %s %s" % [action, b])


## Every tr() key used in code must exist in the English column.
func test_translation_keys() -> void:
	var data := CsvI18n.parse_file("res://core/locale/strings.csv")
	check(data.has("en"), "strings.csv has en column")
	var en: Dictionary = data.get("en", {})
	var re := RegEx.create_from_string("tr\\(\"([A-Z0-9_]+)\"\\)")
	var key_re := RegEx.create_from_string("\"([A-Z][A-Z0-9_]+_(?:TITLE|PLAY|COIN))\"")
	for path in _gd_files("res://"):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			check(en.has(m.get_string(1)), "missing translation key %s (%s)" % [m.get_string(1), path])
		for m in key_re.search_all(src):
			check(en.has(m.get_string(1)), "missing translation key %s (%s)" % [m.get_string(1), path])


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
