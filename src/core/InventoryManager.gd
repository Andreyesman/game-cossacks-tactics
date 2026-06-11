class_name InventoryManager
# Статична утиліта для роботи з інвентарем загону.
# Не є Autoload — викликається як InventoryManager.метод(ws, ...).
# Вся логіка мутує world_state, переданий аргументом.
#
# Структура предмета в squad_inventory / shop_inventory:
# {
#   "id":         String  — ім'я файлу ресурсу без розширення (напр. "saber")
#   "name":       String  — відображуване ім'я
#   "type":       String  — "weapon" | "armor" | "helm"
#   "buy_price":  int     — ціна в магазині (0 якщо не продається в магазині)
#   "sell_price": int     — ціна при продажу гравцем
#   "res_path":   String  — "res://..." шлях до .tres ресурсу
# }

# ── Іконки предметів ──────────────────────────────────────────────────────────

const ITEM_ICONS: Dictionary = {
	"saber":            "res://assets/sprites/icons/icon_saber.png",
	"musket":           "res://assets/sprites/icons/icon_musket.png",
	"janissary_musket": "res://assets/sprites/icons/icon_musket.png",
	"spear":            "res://assets/sprites/icons/icon_spear.png",
	"warhammer":        "res://assets/sprites/icons/icon_warhammer.png",
	"battle_axe":       "res://assets/sprites/icons/icon_axe.png",
	"dagger":           "res://assets/sprites/icons/icon_dagger.png",
	"bow":              "res://assets/sprites/icons/icon_bow.png",
	"mail":             "res://assets/sprites/icons/icon_mail.png",
	"jupan":            "res://assets/sprites/icons/icon_jupan.png",
	"padded_zhupan":   "res://assets/sprites/icons/icon_jupan.png",
	"cuirass":          "res://assets/sprites/icons/icon_cuirass.png",
	"leather_lamellar": "res://assets/sprites/icons/icon_mail.png",
	"helm":             "res://assets/sprites/icons/icon_helm.png",
	"misyurka":         "res://assets/sprites/icons/icon_helm.png",
	"kuchma":           "res://assets/sprites/icons/icon_kuchma.png",
	"cap":              "res://assets/sprites/icons/icon_cap.png",
	"shlyk":            "res://assets/sprites/icons/icon_cap.png",
}

static func get_item_icon(item_id: String) -> Texture2D:
	var path: String = ITEM_ICONS.get(item_id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

# ── Базові операції ───────────────────────────────────────────────────────────

static func add_item(ws: Dictionary, item: Dictionary) -> void:
	if not ws.has("squad_inventory"):
		ws["squad_inventory"] = []
	ws["squad_inventory"].append(item)

## Видаляє перший предмет з item["id"] == item_id. Повертає true при успіху.
static func remove_item(ws: Dictionary, item_id: String) -> bool:
	var inv: Array = ws.get("squad_inventory", [])
	for i in inv.size():
		if inv[i].get("id") == item_id:
			inv.remove_at(i)
			return true
	return false

## Продає предмет: збільшує thalers на sell_price і видаляє з інвентаря.
static func sell_item(ws: Dictionary, item_id: String) -> bool:
	var inv: Array = ws.get("squad_inventory", [])
	for item in inv:
		if item.get("id") == item_id:
			ws["thalers"] = ws.get("thalers", 0) + item.get("sell_price", 0)
			return remove_item(ws, item_id)
	return false

# ── Екіпірування ──────────────────────────────────────────────────────────────

## Надіває предмет item_id на козака unit_name.
## Стара зброя/броня автоматично повертається в squad_inventory.
## Повертає true при успіху.
static func equip_item(ws: Dictionary, item_id: String, unit_name: String) -> bool:
	var target := _find_item(ws, item_id)
	if target.is_empty():
		return false
	var slot := _slot_key(target.get("type", ""))
	if slot.is_empty():
		return false
	for unit in ws.get("squad", []):
		if unit.get("name") != unit_name:
			continue
		# Стара зброя → назад в інвентар
		var old_path: String = unit.get(slot, "")
		if not old_path.is_empty():
			var old_item := make_item_from_resource(old_path, target["type"])
			if not old_item.is_empty():
				add_item(ws, old_item)
		unit[slot] = target.get("res_path", "")
		remove_item(ws, item_id)
		return true
	return false

# ── Запит ─────────────────────────────────────────────────────────────────────

static func get_by_type(ws: Dictionary, item_type: String) -> Array:
	return ws.get("squad_inventory", []).filter(
		func(item: Dictionary) -> bool: return item.get("type") == item_type
	)

# ── Хелпери ───────────────────────────────────────────────────────────────────

static func _find_item(ws: Dictionary, item_id: String) -> Dictionary:
	for item in ws.get("squad_inventory", []):
		if item.get("id") == item_id:
			return item
	return {}

static func _slot_key(item_type: String) -> String:
	match item_type:
		"weapon": return "weapon_resource_path"
		"armor":  return "armor_path"
		"helm":   return "helm_path"
	return ""

## Будує item-словник із шляху до ресурсу.
## Використовується при зніманні старого спорядження та генерації луту.
static func make_item_from_resource(res_path: String, item_type: String) -> Dictionary:
	if res_path.is_empty() or not ResourceLoader.exists(res_path):
		return {}
	var res := load(res_path)
	if not res:
		return {}
	var display_name: String = res_path.get_file().get_basename()
	if "name" in res and (res["name"] as String) != "":
		display_name = res["name"]
	var sell_price := 40
	match item_type:
		"armor": sell_price = 30
		"helm":  sell_price = 20
	return {
		"id":         res_path.get_file().get_basename(),
		"name":       display_name,
		"type":       item_type,
		"buy_price":  0,
		"sell_price": sell_price,
		"res_path":   res_path
	}
