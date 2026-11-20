## Pure helper: parses a translation CSV (first column "keys", one column per locale)
## into { locale: { key: message } }. Kept independent of Godot's CSV importer so
## translations can be dropped in as plain files without the editor (D-009).
extends RefCounted

static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("i18n: cannot open %s" % path)
		return {}
	var header := f.get_csv_line()
	var out := {}
	for c in range(1, header.size()):
		var loc := header[c].strip_edges()
		if not loc.is_empty():
			out[loc] = {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2:
			continue
		var key := row[0].strip_edges()
		if key.is_empty() or key.begins_with("#"):
			continue
		for c in range(1, mini(row.size(), header.size())):
			var loc := header[c].strip_edges()
			if out.has(loc) and not row[c].is_empty():
				out[loc][key] = row[c]
	return out
