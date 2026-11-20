## Config autoload: persistent settings in user://pingames.cfg plus CLI overrides.
## All values have defaults here, so a missing/partial file is always valid.
## CLI: any "--section.key=value" overrides that setting for this run; shortcuts
## --layout, --game, --lang are also accepted. Pass game args after "--".
extends Node

const CliUtil = preload("res://core/util/cli.gd")
const PATH := "user://pingames.cfg"

const DEFAULTS := {
	"display": {
		# windowed | 2screen | 3screen   (see docs/DECISIONS.md D-006, D-013)
		"layout": "windowed",
		"windowed_monitor": 0,
		"table_monitor": 0,
		"backglass_monitor": 1,
		"dmd_monitor": 2,
		# Clockwise rotation applied in-engine: 0, 90, 180, 270. -1 = auto
		# (270 if the monitor is landscape, else 0) for the table in cabinet layouts.
		"table_rotation": -1,
		"backglass_rotation": 0,
		"dmd_rotation": 0,
		# window | backglass | hardware   (2screen forces backglass unless hardware)
		"dmd_sink": "window",
		# DMD region inside the backglass, as fractions x,y,w,h
		"dmd_region": "0.0,0.78,1.0,0.22",
		# "auto" or a number (1.0 = base resolution 1080x1920 for the table)
		"render_scale": "auto",
	},
	"dmd": {
		"width": 128,
		"height": 32,
		"color": "ff7319",
		"hardware_host": "127.0.0.1",
		"hardware_port": 6789,
	},
	"operator": {
		"language": "en",
		"free_play": true,
		"balls_per_game": 3,
		"attract_sounds": false,
	},
	"input": {},  # filled from CabinetInput.DEFAULT_BINDINGS when missing
}

var cli: Dictionary = {}
var _file := ConfigFile.new()


func _init() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	cli = CliUtil.parse(args)
	var err := _file.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Config: could not read %s (error %d), using defaults" % [PATH, err])


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var cli_key := "%s.%s" % [section, key]
	if cli.has(cli_key):
		return cli[cli_key]
	var def: Variant = fallback
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		def = DEFAULTS[section][key]
	return _file.get_value(section, key, def)


func set_value(section: String, key: String, value: Variant) -> void:
	_file.set_value(section, key, value)


func save() -> void:
	var err := _file.save(PATH)
	if err != OK:
		push_error("Config: failed to save %s (error %d)" % [PATH, err])


func layout() -> String:
	return str(cli.get("layout", get_value("display", "layout")))


func requested_game() -> String:
	return str(cli.get("game", ""))
