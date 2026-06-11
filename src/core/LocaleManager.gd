extends Node


func _ready() -> void:
	var saved_locale: String = _load_locale()
	TranslationServer.set_locale(saved_locale)


func set_language(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_save_locale(locale)


func get_language() -> String:
	return TranslationServer.get_locale()


func _save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "locale", locale)
	config.save("user://settings.cfg")


func _load_locale() -> String:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("settings", "locale", "uk")
	return "uk"
