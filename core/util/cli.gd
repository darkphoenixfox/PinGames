## Pure helpers for command-line parsing. No autoload references (testable headless).
extends RefCounted

## Parses "--key=value" and "--flag" style arguments into a Dictionary.
## Flags without a value become true. Unknown positional args are ignored.
static func parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for raw in args:
		if not raw.begins_with("--"):
			continue
		var body := raw.substr(2)
		if body.is_empty():
			continue
		var eq := body.find("=")
		if eq == -1:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
