## Pure helpers that convert binding strings <-> InputEvents.
## Binding format (stored in pingames.cfg, edited by the operator menu):
##   key:<KeyName>[@left|@right]   e.g. key:Shift@left, key:Enter, key:1
##   joy:<button_index>            e.g. joy:9   (any joypad device)
##   axis:<axis_index><+|->        e.g. axis:4+ (trigger / analog past threshold)
extends RefCounted

const AXIS_CAPTURE_THRESHOLD := 0.6


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


## Converts a raw input event (a press) into a binding string, or "" if it is not
## a usable press (releases, key echo, small analog movement, mouse...).
static func from_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return ""
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if code == KEY_NONE:
			return ""
		var name := OS.get_keycode_string(code)
		match k.location:
			KEY_LOCATION_LEFT:
				name += "@left"
			KEY_LOCATION_RIGHT:
				name += "@right"
		return "key:" + name
	if event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		return "joy:%d" % b.button_index if b.pressed else ""
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) < AXIS_CAPTURE_THRESHOLD:
			return ""
		return "axis:%d%s" % [m.axis, "+" if m.axis_value > 0.0 else "-"]
	return ""


## "key" for keyboard bindings, "joy" for joypad buttons and axes.
static func kind(binding: String) -> String:
	return "key" if binding.begins_with("key:") else "joy"


## Short human-readable form for menus, e.g. "L SHIFT", "PAD 9", "AXIS 4+".
static func describe(binding: String) -> String:
	var parts := binding.split(":", true, 1)
	if parts.size() != 2:
		return binding
	match parts[0]:
		"key":
			var v := parts[1]
			var prefix := ""
			if v.ends_with("@left"):
				prefix = "L "
				v = v.trim_suffix("@left")
			elif v.ends_with("@right"):
				prefix = "R "
				v = v.trim_suffix("@right")
			return (prefix + v).to_upper()
		"joy":
			return "PAD " + parts[1]
		"axis":
			return "AXIS " + parts[1]
	return binding
