extends Node
class_name EquipmentManager

## Менеджер екіпірування, який відповідає за зміну зброї та оновлення списку атак юніта.

var unit: CombatUnit

func _ready() -> void:
	unit = get_parent() as CombatUnit

## Екіпірує зброю та автоматично формує список доступних навичок.
func equip_weapon(weapon: WeaponResource) -> void:
	if not unit:
		printerr("EquipmentManager: Не вдалося знайти CombatUnit у батьківському вузлі!")
		return
	
	unit.weapon_resource = weapon
	unit.available_skills = []
	
	if not weapon:
		# Якщо зброю знято, додаємо тільки кулаки або базовий відпочинок
		_add_default_actions()
		return
	
	# Конвертуємо AttackAction ресурси у словники навичок, які розуміє CombatUnit
	for action in weapon.actions:
		var skill_data = {
			"id": action.id,
			"name": action.name,
			"description": action.description,
			"ap": action.ap_cost,
			"stamina": action.stamina_cost,
			"range": action.attack_range,
			"damage_mod": action.damage_multiplier,
			"damage_type": action.damage_type,
			"armor_pen": weapon.armor_penetration + action.armor_penetration_bonus,
			"hit_mod": action.hit_chance_modifier,
			"head_bonus": action.head_hit_chance_bonus,
			"animation": action.animation_type,
			"icon": action.icon
		}
		unit.available_skills.append(skill_data)
	
	# Завжди додаємо Відпочинок
	_add_default_actions()
	
	# Оновлюємо UI панель юніта, якщо вона існує
	var bm = unit.get_parent().find_child("BattleManager")
	if bm and bm.unit_panel:
		bm.unit_panel.update_unit_info(unit)

func _add_default_actions() -> void:
	# Базовий відпочинок, який є у всіх
	unit.available_skills.append({
		"id": "recover",
		"name": "Відпочинок",
		"ap": 9,
		"stamina": 0,
		"range": 0,
		"desc": "Відновлює 50% витривалості (завершує хід)."
	})
