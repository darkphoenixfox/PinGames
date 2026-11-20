## Pure helpers that convert binding strings <-> InputEvents.
## Binding format (stored in pingames.cfg, edited by the operator menu):
##   key:<KeyName>[@left|@right]   e.g. key:Shift@left, key:Enter, key:1
##   joy:<button_index>            e.g. joy:9   (any joypad device)
##   axis:<axis_index><+|->        e.g. axis:4+ (trigger / analog past threshold)
extends RefCounted

static func to_event(binding: String) -> InputEvent:
	var parts := binding.split(":", true, 1)
	if parts.size() != 2:
		return null
	var kind := parts[0]
	var value := parts[1]
	match kind:
		"key":
			var location := KEY_LOCATION_UNSPECIFIED
			var at := value.find("@")
			if at != -1:
				var loc := value.substr(at + 1)
				value = value.substr(0, at)
				location = KEY_LOCATION_LEFT if loc == "left" else KEY_LOCATION_RIGHT
			var code := OS.find_keycode_from_string(value)
			if code == KEY_NONE:
				return null
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			ev.location = location
			return ev
		"joy":
			if not value.is_valid_int():
				return null
			var jb := InputEventJoypadButton.new()
			jb.device = -1
			jb.button_index = int(value)
			return jb
		"axis":
			if value.length() < 2:
				return null
			var sign_char := value.right(1)
			var idx := value.left(value.length() - 1)
			if not idx.is_valid_int() or not (sign_char == "+" or sign_char == "-"):
				return null
			var jm := InputEventJoypadMotion.new()
			jm.device = -1
			jm.axis = int(idx)
			jm.axis_value = 1.0 if sign_char == "+" else -1.0
			return jm
	return null
