extends Node

const SAVE_PATH = "user://cossacks_save.json"

var squad_data: Array = []
var global_inventory: Dictionary = {
	"thalers": 0,
	"provisions": 0
}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Зберігає поточний стан загону (лише живих бійців) та лут
func save_game(player_units: Array, earned_thalers: int = 0, earned_provisions: int = 0) -> void:
	squad_data.clear()
	for unit in player_units:
		if unit.get("is_dead"):
			continue
			
		var u_data = {
			"name": unit.name,
			"hp": unit.get("hp"),
			"max_hp": unit.get("max_hp"),
			"xp": unit.get("xp"),
			"level": unit.get("level"),
			"xp_to_next": unit.get("xp_to_next"),
			"weapon_type": unit.get("weapon_type")
		}
		
		if "data" in unit and unit.data != null:
			u_data["data_path"] = unit.data.resource_path
		
		# Якщо юніт має конкретний WeaponResource, ми б мали зберігати його шлях
		if "weapon_resource" in unit and unit.weapon_resource != null:
			u_data["weapon_resource_path"] = unit.weapon_resource.resource_path
			
		squad_data.append(u_data)
		
	global_inventory["thalers"] += earned_thalers
	global_inventory["provisions"] += earned_provisions
	
	var save_dict = {
		"squad": squad_data,
		"inventory": global_inventory
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()
		print("Гру збережено: ", SAVE_PATH)
	else:
		push_error("Помилка створення файлу збереження")

## Завантажує стан з файлу. Повертає true, якщо збереження знайдене та коректне.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Збережень не знайдено.")
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file: 
		push_error("Не вдалося відкрити файл збереження")
		return false
	
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(json) == TYPE_DICTIONARY:
		squad_data = json.get("squad", [])
		global_inventory = json.get("inventory", {"thalers": 0, "provisions": 0})
		print("Гру завантажено. В загоні бійців: ", squad_data.size())
		return true
		
	push_error("Файл збереження пошкоджений.")
	return false

## Зберігає повний стан кампанії (викликається CampaignManager)
func save_campaign(world_state: Dictionary) -> void:
	var save_dict := {
		"version": 3,
		"world_state": _serialize_world_state(world_state)
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()
		print("Кампанію збережено: ", SAVE_PATH)
	else:
		push_error("SaveManager: помилка запису файлу")

## Завантажує стан кампанії. Повертає Dictionary або порожній dict якщо не знайдено.
func load_campaign() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(json) != TYPE_DICTIONARY:
		return {}
	var json_dict := json as Dictionary
	if json_dict.get("version", 1) >= 2:
		var ws := _deserialize_world_state(json_dict.get("world_state", {}))
		return _migrate(ws, json_dict.get("version", 2) as int)
	return {}

## Міграція старих збережень до поточної версії.
func _migrate(ws: Dictionary, from_version: int) -> Dictionary:
	if from_version < 3:
		if not ws.has("squad_inventory"):
			ws["squad_inventory"] = []
		if not ws.has("shop_inventory"):
			ws["shop_inventory"] = _default_shop()
		if not ws.has("day_count"):
			ws["day_count"] = ws.get("day", 0)
		# Додаємо armor_path / helm_path до збережених козаків
		for unit in ws.get("squad", []):
			if not unit.has("armor_path"):
				unit["armor_path"] = ""
			if not unit.has("helm_path"):
				unit["helm_path"] = ""
		# Старі збереження пропускають tutorial (вже пройдено)
		if not ws.has("tutorial_done"):
			ws["tutorial_done"] = true
	return ws

func _default_shop() -> Array:
	return [
		{"id": "saber",           "name": "Козацька шабля",     "type": "weapon",
		 "buy_price": 80,  "sell_price": 50,
		 "res_path": "res://src/resources/combat/weapons/saber.tres"},
		{"id": "spear",           "name": "Спис",                "type": "weapon",
		 "buy_price": 120, "sell_price": 70,
		 "res_path": "res://src/resources/combat/weapons/spear.tres"},
		{"id": "padded_zhupan",   "name": "Стьобаний жупан",    "type": "armor",
		 "buy_price": 90,  "sell_price": 45,
		 "res_path": "res://src/resources/equipment/armor/padded_zhupan.tres"},
		{"id": "leather_lamellar","name": "Шкіряний панцир",    "type": "armor",
		 "buy_price": 150, "sell_price": 75,
		 "res_path": "res://src/resources/equipment/armor/leather_lamellar.tres"},
		{"id": "shlyk",           "name": "Звичайна шапка",     "type": "helm",
		 "buy_price": 50,  "sell_price": 25,
		 "res_path": "res://src/resources/equipment/helmets/shlyk.tres"},
		{"id": "kuchma",          "name": "Хутряна кучма",      "type": "helm",
		 "buy_price": 80,  "sell_price": 45,
		 "res_path": "res://src/resources/equipment/helmets/kuchma.tres"},
	]

## Серіалізація Vector2 і Dictionary для JSON
func _serialize_world_state(ws: Dictionary) -> Dictionary:
	var result := ws.duplicate(true)
	# player_pos
	if ws.get("player_pos") is Vector2:
		result["player_pos"] = {"x": ws["player_pos"].x, "y": ws["player_pos"].y}
	return result

func _deserialize_world_state(ws: Dictionary) -> Dictionary:
	# player_pos вже Dictionary {"x":..,"y":..} — CampaignManager читає обидва формати
	return ws

## Допоміжний метод для очищення збережень (наприклад, для нової гри)
func clear_save() -> void:
	squad_data.clear()
	global_inventory = {"thalers": 0, "provisions": 0}
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("cossacks_save.json")
