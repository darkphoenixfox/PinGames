## Config autoload: persistent settings in user://pingames.cfg plus CLI overrides.
## All values have defaults here, so a missing/partial file is always valid.
## CLI: any "--section.key=value" overrides that setting for this run; shortcuts
## --layout, --game, --lang are also accepted. Pass game args after "--".
extends Node

const CliUtil = preload("res://core/util/cli.gd")
const PATH := "user://pingames.cfg"

const DEFAULTS := {
	"display": {
		# windowed | 2screen | 3screen | vr   (D-006, D-013, D-164)
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
		# Box for the DMD inside the backglass, as fractions x,y,w,h. The DMD keeps
		# its dot aspect, centred in the box, with a frame around it (D-080).
		"dmd_region": "0.2,0.755,0.6,0.216",
		# "auto" or a number (1.0 = base resolution 1080x1920 for the table)
		"render_scale": "auto",
	},
	"dmd": {
		"width": 128,
		"height": 32,
		"color": "ff7319",
		# false = full colour RGB DMD (D-026); true = classic single-colour look
		"mono": false,
		"hardware_host": "127.0.0.1",
		"hardware_port": 6789,
	},
	"operator": {
		"language": "en",
		"free_play": true,
		"balls_per_game": 3,
		# auto | 2 | 4 — number of side buttons (D-022)
		"cabinet_buttons": "auto",
		"attract_delay": 60,
		"attract_sounds": false,
		"volume_master": 8,
		"volume_music": 7,
		"volume_sfx": 8,
	},
	"input": {},  # filled from CabinetInput.DEFAULT_BINDINGS when missing
}

## CLI shortcut -> setting it overrides.
const CLI_SHORTCUTS := {"layout": "display.layout", "lang": "operator.language"}

var cli: Dictionary = {}
var _file := ConfigFile.new()


func _init() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	cli = CliUtil.parse(args)
	for shortcut in CLI_SHORTCUTS:
		if cli.has(shortcut):
			cli[CLI_SHORTCUTS[shortcut]] = cli[shortcut]
	var err := _file.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Config: could not read %s (error %d), using defaults" % [PATH, err])


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var def: Variant = fallback
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		def = DEFAULTS[section][key]
	var cli_key := "%s.%s" % [section, key]
	if cli.has(cli_key):
		return coerce(cli[cli_key], def)
	return _file.get_value(section, key, def)


## Setting a value also drops any CLI override for it, so operator-menu changes
## take effect even when the app was launched with overrides.
func set_value(section: String, key: String, value: Variant) -> void:
	_file.set_value(section, key, value)
	cli.erase("%s.%s" % [section, key])


func save() -> void:
	var err := _file.save(PATH)
	if err != OK:
		push_error("Config: failed to save %s (error %d)" % [PATH, err])


func layout() -> String:
	if OS.has_feature("android"):
		return "vr"   # the Quest build is the VR cabinet (D-170)
	return str(get_value("display", "layout"))


func requested_game() -> String:
	return str(cli.get("game", ""))


## CLI values are strings; convert them to the type of the default.
static func coerce(v: Variant, like: Variant) -> Variant:
	if typeof(v) != TYPE_STRING:
		return v
	match typeof(like):
		TYPE_BOOL:
			return (v as String).to_lower() in ["1", "true", "yes", "on"]
		TYPE_INT:
			return (v as String).to_int()
		TYPE_FLOAT:
			return (v as String).to_float()
	return v
