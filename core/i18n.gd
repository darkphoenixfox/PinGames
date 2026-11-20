## I18n autoload: loads every CSV in res://core/locale/ and user://locale/ into
## TranslationServer at runtime. All visible text must use tr() with a key (D-009).
extends Node

const CsvI18n = preload("res://core/util/csv_i18n.gd")
const DIRS := ["res://core/locale", "user://locale"]


func _ready() -> void:
	for dir_path in DIRS:
		if not DirAccess.dir_exists_absolute(dir_path):
			continue
		for file_name in DirAccess.get_files_at(dir_path):
			if file_name.ends_with(".csv"):
				_load_csv(dir_path.path_join(file_name))
	var lang := str(Config.cli.get("lang", Config.get_value("operator", "language")))
	TranslationServer.set_locale(lang)


func _load_csv(path: String) -> void:
	var data := CsvI18n.parse_file(path)
	for loc in data:
		var t := Translation.new()
		t.locale = loc
		for key in data[loc]:
			t.add_message(key, data[loc][key])
		TranslationServer.add_translation(t)


func available_locales() -> PackedStringArray:
	return TranslationServer.get_loaded_locales()
