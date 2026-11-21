## Startup system checks (D-070). Windows accessibility shortcuts — Sticky Keys
## (Shift pressed 5 times) and Filter Keys (Right Shift held 8 s) — pop up a
## prompt that steals keyboard focus mid-game, and Shift is the default flipper
## key. Reads the per-user registry flags once per run (Windows only).
##   HKCU\Control Panel\Accessibility\StickyKeys        Flags: 0x1 on, 0x4 shortcut
##   HKCU\Control Panel\Accessibility\Keyboard Response Flags: 0x1 on, 0x4 shortcut
extends RefCounted

const ON := 0x1
const HOTKEY := 0x4

static var _warnings: Variant = null


## Translation keys of the problems found (empty = all good). Cached per run.
static func warnings() -> Array:
	if _warnings != null:
		return _warnings
	var out: Array = []
	if Config.cli.has("fake-keys-warning"):  # dev: preview the warnings
		_warnings = ["SYS_WARN_STICKY", "SYS_WARN_FILTER"]
		return _warnings
	if OS.get_name() == "Windows":
		var sticky := _read_flags("HKCU\\Control Panel\\Accessibility\\StickyKeys")
		if sticky >= 0 and sticky & (ON | HOTKEY):
			out.append("SYS_WARN_STICKY")
		var filter := _read_flags("HKCU\\Control Panel\\Accessibility\\Keyboard Response")
		if filter >= 0 and filter & (ON | HOTKEY):
			out.append("SYS_WARN_FILTER")
	_warnings = out
	return out


## Parses `reg query <key> /v Flags` -> int, or -1 if unavailable.
static func _read_flags(key: String) -> int:
	var output: Array = []
	if OS.execute("reg", ["query", key, "/v", "Flags"], output, true) != 0 or output.is_empty():
		return -1
	for line in str(output[0]).split("\n"):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() >= 3 and parts[0] == "Flags":
			return int(parts[parts.size() - 1])
	return -1


## Pure helper for tests: would these flag values trigger a warning?
static func flags_warn(flags: int) -> bool:
	return flags >= 0 and (flags & (ON | HOTKEY)) != 0
