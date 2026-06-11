extends Node2D
class_name CombatUnit

const IsoMath = preload("res://src/core/IsoMath.gd")

@export var data: Resource # UnitData
@export var portrait_override: Texture2D
@export var team: int = 0
@export var weapon_type: String = "sword" # sword | musket | spear | heavy
@export var weapon_resource: WeaponResource

# Основні характеристики
var hp: int
var max_hp: int = 100
var body_armor: int
var max_body_armor: int = 0
var head_armor: int
var max_head_armor: int = 0
var stamina: int
var max_stamina: int = 100
var ap: int
var is_active: bool = false
var is_moving: bool = false
var _move_target: Vector2i = Vector2i(-1, -1)
var is_riposting: bool = false
var is_dead: bool = false
var has_waited: bool = false
var is_loaded: bool = true # Для стрільців

# Досвід та рівень
var xp: int = 0
var level: int = 1
var xp_to_next: int = 150

# Статистика за бій
var damage_taken_in_battle: int = 0
var damage_dealt_in_battle: int = 0
var xp_earned_in_battle: int = 0
var levels_gained_in_battle: int = 0

# Травми отримані в бою
var injuries: Array = []  # [{id, name, icon, days, permanent, penalties}]

const INJURY_TABLE = [
	{"id": "cut_arm",      "name": "Порізана рука",  "icon": "🤕", "days": 7,  "permanent": false, "penalties": {"melee_skill": -5}},
	{"id": "bruised_ribs", "name": "Забиті ребра",   "icon": "🫁", "days": 14, "permanent": false, "penalties": {"stamina": -10}},
	{"id": "concussion",   "name": "Струс мозку",    "icon": "💫", "days": 10, "permanent": false, "penalties": {"initiative": -10, "melee_defense": -5}},
	{"id": "broken_rib",   "name": "Перелом ребра",  "icon": "🦴", "days": 21, "permanent": false, "penalties": {"stamina": -15, "melee_skill": -5}},
	{"id": "leg_wound",    "name": "Рана в ногу",    "icon": "🦵", "days": 10, "permanent": false, "penalties": {"initiative": -5}},
	{"id": "deep_cut",     "name": "Глибокий поріз", "icon": "🩹", "days": 7,  "permanent": false, "penalties": {"melee_skill": -5, "initiative": -5}},
]

enum MoralState { CONFIDENT = 0, STEADY = 1, WAVERING = 2, BREAKING = 3, FLEEING = 4 }
var current_morale: MoralState = MoralState.STEADY

func get_morale_modifier() -> int:
	match current_morale:
		MoralState.CONFIDENT: return 10
		MoralState.STEADY: return 0
		MoralState.WAVERING: return -10
		MoralState.BREAKING: return -20
		MoralState.FLEEING: return -30
	return 0

func trigger_resolve_check(penalty: int) -> void:
	if is_dead or current_morale == MoralState.FLEEING: return
	
	var resolve_skill = data.base_resolve if data else 40
	var success_chance = clamp(resolve_skill - penalty, 5, 95)
	var roll = randi() % 100
	
	var is_success = (roll < success_chance) # Успіх - це кидок НИЖЧЕ навички
	
	if penalty > 0:
		# Перевірка ПІД ТИСКОМ (поранення, смерть союзника)
		if not is_success:
			set_morale_state(current_morale + 1) # Провал -> мораль падає
		# При успіху нічого не змінюється (юніт встояв)
	else:
		# Перевірка на ВІДНОВЛЕННЯ (початок ходу, Rally)
		if is_success:
			if current_morale > MoralState.STEADY or (penalty < 0 and current_morale > MoralState.CONFIDENT):
				set_morale_state(current_morale - 1) # Успіх -> мораль покращується
		# При провалі нічого не змінюється (юніт не лякається сам по собі)

func set_morale_state(new_state: int) -> void:
	new_state = clampi(new_state, 0, MoralState.FLEEING)
	if new_state == current_morale: return
	
	var old_state = current_morale
	current_morale = new_state as MoralState
	
	# ТРІГЕР: Якщо юніт почав тікати, це лякає сусідів (Ланцюгова паніка)
	if current_morale == MoralState.FLEEING and old_state != MoralState.FLEEING:
		_spread_panic_to_allies(3, 10, "😱 " + tr("BATTLE_PANIC_FLEE") % name)
	
	var color = Color.WHITE
	match current_morale:
		MoralState.CONFIDENT: color = Color.GREEN
		MoralState.STEADY: color = Color.WHITE
		MoralState.WAVERING: color = Color.ORANGE
		MoralState.BREAKING: color = Color.ORANGE_RED
		MoralState.FLEEING: color = Color.PURPLE
			
	spawn_text_fx(get_morale_string(), color)

func get_morale_string() -> String:
	match current_morale:
		MoralState.CONFIDENT: return "🔥 " + tr("MORALE_CONFIDENT")
		MoralState.STEADY: return tr("MORALE_STEADY")
		MoralState.WAVERING: return "😰 " + tr("MORALE_WAVERING")
		MoralState.BREAKING: return "😱 " + tr("MORALE_BREAKING")
		MoralState.FLEEING: return "🏳️ " + tr("MORALE_FLEEING") + "!"
	return ""

func roll_starting_morale() -> void:
	if is_dead: return
	var resolve_skill = data.base_resolve if data else 40
	var roll = randi() % 100
	
	# Тільки позитивний ефект: шанс почати бій впевненим (зменшено до ~5% для звичайних юнітів)
	if roll < (resolve_skill - 35):
		set_morale_state(MoralState.CONFIDENT)

# Система навичок (Weapon Skills)
var available_skills = []

signal move_finished

var _sprite: Sprite2D
var _sprite_front: Texture2D
var _sprite_back: Texture2D

func _ready() -> void:
	setup_from_data()
	update_sprite()

var _idle_time: float = randf() * 10.0

func _process(delta: float) -> void:
	if is_dead or is_moving: return
	if _sprite:
		_idle_time += delta * 2.0
		var scale_y = 0.7 + sin(_idle_time) * 0.015
		var scale_x = 0.7 - sin(_idle_time) * 0.007
		_sprite.scale = Vector2(scale_x, scale_y)

func setup_from_data() -> void:
	if data:
		max_hp = data.base_hp if data.base_hp > 0 else 60
		hp = max_hp
		
		if data.default_armor:
			max_body_armor = data.default_armor.armor_hp
			body_armor = max_body_armor
			# Штрафи враховуються при розрахунку поточної ініціативи та стаміни
		else:
			max_body_armor = data.base_body_armor
			body_armor = max_body_armor
		
		if data.default_helmet:
			max_head_armor = data.default_helmet.armor_hp
			head_armor = max_head_armor
		else:
			max_head_armor = data.base_head_armor
			head_armor = max_head_armor
		
		max_stamina = data.base_stamina if data.base_stamina > 0 else 90
		# Штраф до стаміни від броні (зменшує МАКСИМАЛЬНУ стаміну)
		var stamina_pen = (data.default_armor.stamina_penalty if data.default_armor else 0) + (data.default_helmet.stamina_penalty if data.default_helmet else 0)
		max_stamina += stamina_pen # stamina_penalty зазвичай від'ємний (-5, -15 тощо)
		
		stamina = max_stamina
		ap = Globals.AP_MAX
		
		if not weapon_resource and data.default_weapon:
			weapon_resource = data.default_weapon
		
	# Ініціалізація навичок з ресурсу зброї
	if weapon_resource:
		available_skills = []
		for action in weapon_resource.actions:
			var skill_dict = {
				"id": action.id,
				"name": action.name,
				"ap": action.ap_cost,
				"stamina": action.stamina_cost,
				"range": action.attack_range,
				"armor_pen": weapon_resource.armor_penetration + action.armor_penetration_bonus,
				"armor_dmg": weapon_resource.armor_damage_modifier,
				"shield_dmg": weapon_resource.shield_damage_modifier,
				"desc": action.description,
				"damage_mod": action.damage_multiplier,
				"head_bonus": action.head_hit_chance_bonus,
				"guaranteed_head": action.guaranteed_headshot,
				"animation": action.animation_type
			}
			available_skills.append(skill_dict)
		
		# Завжди додаємо Відпочинок
		available_skills.append({"id": "recover", "name": "Відпочинок", "ap": 9, "stamina": 0, "range": 0, "desc": "Відновлює 50% витривалості (завершує хід)."})

		# Якщо це мушкет, обов'язково додаємо навичку перезарядки
		if weapon_resource.type == 4: # WeaponType.MUSKET
			available_skills.append({
				"id": "reload",
				"name": "Перезарядити",
				"ap": 5,
				"stamina": 10,
				"range": 0,
				"desc": "Заряджає зброю для наступного пострілу."
			})
	else:
		# Навички за типом зброї (залишаємо для зворотної сумісності)
		if weapon_type == "musket":
			available_skills = [
				{"id": "shoot", "name": "Постріл", "ap": 5, "stamina": 15, "range": 12, "armor_pen": 0.2, "desc": "Постріл з мушкета. Ігнорує 20% броні."},
				{"id": "reload", "name": "Перезарядити", "ap": 5, "stamina": 10, "range": 0, "desc": "Заряджає зброю для наступного пострілу."},
				{"id": "recover", "name": "Відпочинок", "ap": 9, "stamina": 0, "range": 0, "desc": "Відновлює 50% витривалості (завершує хід)."}
			]
		elif weapon_type == "spear":
			available_skills = [
				{"id": "thrust", "name": "Укол списом", "ap": 5, "stamina": 12, "range": 2, "armor_pen": 0.0, "desc": "Атака на дистаніцію 2 гекси."},
				{"id": "recover", "name": "Відпочинок", "ap": 9, "stamina": 0, "range": 0, "desc": "Відновлює 50% витривалості (завершує хід)."}
			]
		elif weapon_type == "heavy":
			available_skills = [
				{"id": "cleave", "name": "Важкий удар", "ap": 6, "stamina": 15, "range": 1, "armor_pen": 0.3, "desc": "Ігнорує 30% броні цілі."},
				{"id": "recover", "name": "Відпочинок", "ap": 9, "stamina": 0, "range": 0, "desc": "Відновлює 50% витривалості (завершує хід)."}
			]
		else: # sword (за замовчуванням)
			available_skills = [
				{"id": "strike", "name": "Удар", "ap": 4, "stamina": 10, "range": 1, "armor_pen": 0.0, "desc": "Звичайна рубаюча атака."},
				{"id": "riposte", "name": "Контрудар", "ap": 4, "stamina": 20, "range": 0, "desc": "Бойова стійка: автоматична відповідь при промаху ворога."},
				{"id": "rally", "name": "Згуртування", "ap": 5, "stamina": 25, "range": 0, "desc": "Перевірка моралі союзників у радіусі 4 клітинок."},
				{"id": "recover", "name": "Відпочинок", "ap": 9, "stamina": 0, "range": 0, "desc": "Відновлює 50% витривалості (завершує хід)."}
			]
		
	create_visual_placeholder()

func get_portrait() -> Texture2D:
	if portrait_override:
		return portrait_override
	if data and data.get("portrait") and data.portrait:
		return data.portrait
	if _sprite_front:
		return _sprite_front
	var path = "res://assets/ui/placeholder_cossack.svg" if team == 0 else "res://assets/ui/placeholder_enemy.svg"
	return load(path)

func get_effective_initiative() -> int:
	if not data: return 0
	# Battle Brothers style: Initiative = Base - Accumulated Fatigue - Weapon/Armor Penalty
	var fatigue = max_stamina - stamina
	var weapon_pen = weapon_resource.initiative_penalty if weapon_resource else 0
	var armor_pen = (data.default_armor.initiative_penalty if data and data.default_armor else 0) + (data.default_helmet.initiative_penalty if data and data.default_helmet else 0)
	return data.base_initiative - fatigue + weapon_pen + armor_pen

func get_adjacent_enemies_count() -> int:
	var count = 0
	var parent = get_parent()
	if not parent: return 0
	
	var my_map_pos = IsoMath.local_to_map(position)
	for child in parent.get_children():
		if child is CombatUnit and child != self and not child.get("is_dead"):
			if child.get("team") != team:
				var child_map_pos = IsoMath.local_to_map(child.position)
				if IsoMath.get_dist_4(my_map_pos, child_map_pos) == 1:
					count += 1
	return count

const NAME_TO_SPRITE: Dictionary = {
	"Ничипір": "nychypir",
	"Гаврило": "havrylo",
	"Тимофій": "tymofiy",
	"Панько": "panko",
}

const PATH_TO_SPRITE: Dictionary = {
	"BanditLeader": "bandit",
	"Bandit": "bandit",
	"Отаман": "bandit",
	"Розбійник": "bandit",
	"TatarHeavy": "tatar",
	"Tatar": "tatar",
	"Татарський": "tatar",
	"Татарин": "tatar",
	"Janissary": "janissary",
	"Яничар": "janissary",
	"Reiestr": "nychypir",
	"Реєстровий": "nychypir",
}

func _get_sprite_key() -> String:
	if team == 0:
		for cyr_name in NAME_TO_SPRITE:
			if name.contains(cyr_name):
				return NAME_TO_SPRITE[cyr_name]
		var cossack_keys = ["nychypir", "havrylo", "tymofiy", "panko"]
		return cossack_keys[randi() % cossack_keys.size()]
	else:
		# resource_path порожній після .duplicate() — беремо ім'я вузла як запасний варіант
		var ref = data.resource_path if data else ""
		if not ref:
			ref = name
		for key in PATH_TO_SPRITE:
			if key in ref:
				return PATH_TO_SPRITE[key]
		return "bandit"

func _update_sprite_direction(dir: Vector2) -> void:
	if not _sprite: return
	if dir.y >= 0:
		_sprite.texture = _sprite_front
		_sprite.flip_h = dir.x < 0
	else:
		_sprite.texture = _sprite_back
		_sprite.flip_h = dir.x > 0

func create_visual_placeholder() -> void:
	for child in get_children():
		if child is Polygon2D or child is Line2D or child is Sprite2D:
			child.queue_free()
	_sprite = null
	_sprite_front = null
	_sprite_back = null

	# Створюємо порожній Sprite2D — update_sprite() заповнить текстуру після призначення імені
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(0.7, 0.7)
	_sprite.offset = Vector2(0, -30)
	add_child(_sprite)

func update_sprite() -> void:
	var key: String = _get_sprite_key()
	var front_path: String = "res://assets/sprites/units/%s_front.png" % key
	var back_path: String = "res://assets/sprites/units/%s_back.png" % key
	if Globals.DEBUG_LOG: print("  update_sprite: '%s' key='%s' front_exists=%s" % [name, key, ResourceLoader.exists(front_path)])

	if ResourceLoader.exists(front_path) and ResourceLoader.exists(back_path):
		_sprite_front = load(front_path)
		_sprite_back = load(back_path)

		if not _sprite:
			_sprite = Sprite2D.new()
			_sprite.scale = Vector2(0.7, 0.7)
			_sprite.offset = Vector2(0, -30)
			add_child(_sprite)

		if team == 0:
			_sprite.texture = _sprite_back
			_sprite.flip_h = true
		else:
			_sprite.texture = _sprite_front
			_sprite.flip_h = true

		_apply_visual_identity()
	else:
		# Fallback: видаляємо порожній Sprite2D, повертаємось до Polygon2D
		if _sprite:
			_sprite.queue_free()
			_sprite = null

		var poly = Polygon2D.new()
		var w = 60
		var h = 30
		poly.polygon = PackedVector2Array([
			Vector2(0, -h), Vector2(w, 0), Vector2(0, h), Vector2(-w, 0)
		])
		poly.color = Color(0.3, 0.7, 1.0) if team == 0 else Color.CRIMSON
		add_child(poly)

		var active_line = Line2D.new()
		active_line.name = "ActiveOutline"
		active_line.points = poly.polygon
		active_line.add_point(poly.polygon[0])
		active_line.width = 3.0
		active_line.default_color = Color.WHITE
		active_line.visible = false
		add_child(active_line)

# Тимчасові відтінки для рекрутів, що ділять один спрайт (поки немає унікальних)
const RECRUIT_TINTS: Array[Color] = [
	Color(1.00, 0.86, 0.86), # рожевуватий
	Color(0.86, 1.00, 0.86), # зеленуватий
	Color(0.85, 0.92, 1.00), # блакитнуватий
	Color(1.00, 1.00, 0.82), # жовтуватий
	Color(0.98, 0.88, 1.00), # бузковий
	Color(0.85, 1.00, 1.00), # бірюзовий
]

# Візуальна ідентичність через self_modulate — НЕ конфліктує з modulate,
# який використовується для підсвітки активного юніта та флешу від ударів.
func _apply_visual_identity() -> void:
	if not _sprite: return
	_sprite.self_modulate = Color.WHITE
	_sprite.scale = Vector2(0.7, 0.7)

	if team == 0:
		# Оригінальні персонажі зі своїми спрайтами — без відтінку
		for cyr_name in NAME_TO_SPRITE:
			if name.contains(cyr_name):
				return
		# Рекрут: детермінований відтінок за ім'ям — стабільний між боями
		_sprite.self_modulate = RECRUIT_TINTS[abs(hash(str(name))) % RECRUIT_TINTS.size()]
	else:
		var ref: String = (data.resource_path if data else "")
		if ref.is_empty():
			ref = str(name)
		if "BanditLeader" in ref or "Отаман" in ref:
			_sprite.self_modulate = Color(1.00, 0.84, 0.55) # золотавий — ватажок
			_sprite.scale = Vector2(0.78, 0.78)
		elif "TatarHeavy" in ref or "Татарський" in ref:
			_sprite.self_modulate = Color(0.74, 0.78, 0.86) # сталевий — важкий
			_sprite.scale = Vector2(0.78, 0.78)

func start_turn(is_new_round: bool = true) -> void:
	if is_dead: return
	is_riposting = false # Скидаємо стійку на початку ходу
	
	if current_morale == MoralState.FLEEING:
		spawn_text_fx("😱 " + tr("BATTLE_FLEE"), Color.PURPLE)
		execute_flee_ai()
		return
		
	is_active = true
	
	if is_new_round:
		has_waited = false
		ap = Globals.AP_MAX
		stamina = clampi(stamina + 15, 0, max_stamina) # Регенерація тільки на новий раунд
		# Спроба відновити мораль на 1 сходинку, якщо вона впала 
		if current_morale > MoralState.STEADY:
			trigger_resolve_check(0)
		
	if _sprite:
		_sprite.modulate = Color(1.3, 1.3, 1.3)
	elif has_node("ActiveOutline"):
		get_node("ActiveOutline").visible = true

func end_turn() -> void:
	is_active = false
	if _sprite:
		_sprite.modulate = Color.WHITE
	elif has_node("ActiveOutline"):
		get_node("ActiveOutline").visible = false

func execute_flee_ai() -> void:
	var bm = get_parent().find_child("BattleManager")
	var grid = get_parent().find_child("TacticalGrid")
	if not bm or not grid:
		if bm: bm.end_unit_turn.call_deferred()
		return
		
	var my_map_pos = IsoMath.local_to_map(position)
	var grid_size = grid.GRID_SIZE if "GRID_SIZE" in grid else 16
	var max_coord = grid_size - 1
	var edge_tiles = []
	for x in range(grid_size):
		edge_tiles.append(Vector2i(x, 0))
		edge_tiles.append(Vector2i(x, max_coord))
	for y in range(1, max_coord):
		edge_tiles.append(Vector2i(0, y))
		edge_tiles.append(Vector2i(max_coord, y))

	var best_tile = my_map_pos
	var min_dist = 9999
	for tile in edge_tiles:
		if tile == my_map_pos:
			die()
			if bm: bm.end_unit_turn.call_deferred()
			return
		if grid.get_unit_at(tile) == null:
			var d = IsoMath.get_dist_4(my_map_pos, tile)
			if d < min_dist:
				min_dist = d
				best_tile = tile

	var obstacles = grid.get_all_obstacles()
	var zoc_tiles = grid.get_enemy_zoc_tiles(team)
	var a_path = IsoMath.get_astar_path(my_map_pos, best_tile, obstacles, grid_size)

	if a_path.size() > 1:
		var steps_to_take = min(a_path.size() - 1, int(ap / 2.0))
		if steps_to_take > 0:
			var move_path: Array[Vector2i] = [a_path[0]]
			for i in range(1, steps_to_take + 1):
				move_path.append(a_path[i])
				if a_path[i] in zoc_tiles: break

			var cost = (move_path.size() - 1) * 2

			await move_along_path(move_path, cost)

			var new_pos = IsoMath.local_to_map(position)
			if grid.has_method("is_on_border") and grid.is_on_border(new_pos):
				die()
			if bm: bm.end_unit_turn()
			return
			
	if bm: bm.end_unit_turn.call_deferred()

func _get_terrain_step_costs(m_pos: Vector2i) -> Dictionary:
	var grid = get_parent().find_child("TacticalGrid")
	if not grid: return {"ap": 2, "stamina": 2}
	var t = grid.get_terrain_at(m_pos)
	match t:
		grid.TerrainType.BUSHES: return {"ap": 3, "stamina": 6}
		grid.TerrainType.SWAMP:  return {"ap": 4, "stamina": 15}
		grid.TerrainType.WATER:  return {"ap": 4, "stamina": 15}
		grid.TerrainType.ROCKS:  return {"ap": 3, "stamina": 8}
		_: return {"ap": 2, "stamina": 2}

func _get_terrain_defense_mod(m_pos: Vector2i) -> int:
	var grid = get_parent().find_child("TacticalGrid")
	if not grid: return 0
	var t = grid.get_terrain_at(m_pos)
	match t:
		grid.TerrainType.BUSHES: return 15
		grid.TerrainType.ROCKS:  return 5
		grid.TerrainType.SWAMP:  return -25
		grid.TerrainType.WATER:  return 0
		_: return 0

func _get_terrain_skill_mod(m_pos: Vector2i) -> int:
	var grid = get_parent().find_child("TacticalGrid")
	if not grid: return 0
	var t = grid.get_terrain_at(m_pos)
	match t:
		grid.TerrainType.SWAMP: return -25
		_: return 0

func _get_terrain_height(m_pos: Vector2i) -> int:
	var grid = get_parent().find_child("TacticalGrid")
	if not grid: return 0
	var t = grid.get_terrain_at(m_pos)
	match t:
		grid.TerrainType.ROCKS: return 1
		_: return 0

func _get_move_target() -> Vector2i:
	return _move_target

func move_along_path(map_path: Array[Vector2i], ap_cost: int) -> void:
	if is_moving or ap < ap_cost: return

	is_moving = true
	_move_target = map_path.back()
	ap -= ap_cost
	# Витрати стаміни залежать від типу місцевості кожного кроку
	var total_stamina_cost = 0
	for i in range(1, map_path.size()):
		var costs = _get_terrain_step_costs(map_path[i])
		total_stamina_cost += costs["stamina"]
	stamina = clampi(stamina - total_stamina_cost, 0, max_stamina)
	
	var is_escaping_zoc = false
	var adjacent_enemies_at_start = []
	
	var my_map_pos = IsoMath.local_to_map(position)
	for child in get_parent().get_children():
		if child is CombatUnit and child != self and not child.get("is_dead") and child.get("team") != team:
			var e_map = IsoMath.local_to_map(child.position)
			if IsoMath.get_dist_4(my_map_pos, e_map) == 1:
				adjacent_enemies_at_start.append(child)
				is_escaping_zoc = true
				
	# If escaping ZoC, they get an opportunity attack!
	if is_escaping_zoc:
		print("%s намагається вийти з ZoC!" % name)
		if team == 0:
			var bm_zoc = get_parent().find_child("BattleManager")
			if bm_zoc:
				bm_zoc._maybe_combat_hint("zoc", tr("COMBAT_HINT_ZOC"))
		for enemy in adjacent_enemies_at_start:
			if enemy.is_dead: continue
			var hit_success = await enemy.perform_opportunity_attack(self)
			if hit_success:
				print("Опортуністична атака від %s зупинила рух %s!" % [enemy.name, name])
				# Рух скасовується (але AP/Stamina вже витрачені за спробу)
				is_moving = false
				_move_target = Vector2i(-1, -1)
				move_finished.emit()
				return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	var sprite_tween = create_tween()
	sprite_tween.set_trans(Tween.TRANS_LINEAR)
	
	for i in range(1, map_path.size()):
		var target_world = IsoMath.get_cell_center(map_path[i])
		var dir = target_world - IsoMath.get_cell_center(map_path[i - 1])
		tween.tween_callback(_update_sprite_direction.bind(dir))
		tween.tween_property(self, "position", target_world, 0.25)
		
		if _sprite:
			sprite_tween.tween_property(_sprite, "position:y", -12.0, 0.125).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			sprite_tween.parallel().tween_property(_sprite, "rotation", deg_to_rad(5.0 if dir.x > 0 else -5.0), 0.125)
			sprite_tween.tween_property(_sprite, "position:y", 0.0, 0.125).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			sprite_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.125)

	await tween.finished
	if _sprite:
		_sprite.position = Vector2.ZERO
		_sprite.rotation = 0.0
		_sprite.scale = Vector2(0.7, 0.7)
	position = IsoMath.get_cell_center(map_path.back())
	is_moving = false
	_move_target = Vector2i(-1, -1)
	
	# Тригер моралі: вороги, біля яких ми зупинились, перевіряють дух, якщо тепер вони оточені
	var final_map_pos = IsoMath.local_to_map(position)
	for child in get_parent().get_children():
		if child is CombatUnit and child != self and not child.get("is_dead") and child.get("team") != team:
			var e_map = IsoMath.local_to_map(child.position)
			if IsoMath.get_dist_4(final_map_pos, e_map) == 1:
				var flankers = child.get_adjacent_enemies_count()
				if flankers > 1:
					child.trigger_resolve_check((flankers - 1) * 5)
	
	move_finished.emit()

func take_damage(amount: int, is_headshot: bool = false, armor_pen: float = 0.0, armor_dmg_mult: float = 1.0, killer: Node2D = null) -> int:
	if is_dead: return 0
	
	var hp_before = hp
	var remaining_damage = amount
	
	if is_headshot:
		var ignored_armor = int(head_armor * armor_pen)
		var effective_armor = head_armor - ignored_armor
		if effective_armor > 0:
			var armor_damage = min(effective_armor, int(remaining_damage * armor_dmg_mult))
			head_armor -= armor_damage
			# armor_dmg_mult > 1 (напр. молот 1.5): броня зношується швидше,
			# але й захищає пропорційно менше — більше шкоди проходить до HP.
			remaining_damage -= int(armor_damage / armor_dmg_mult) if armor_dmg_mult > 0 else armor_damage
		
		if remaining_damage > 0:
			hp -= int(remaining_damage * 1.5)
	else:
		var ignored_armor = int(body_armor * armor_pen)
		var effective_armor = body_armor - ignored_armor
		if effective_armor > 0:
			var armor_damage = min(effective_armor, int(remaining_damage * armor_dmg_mult))
			body_armor -= armor_damage
			remaining_damage -= int(armor_damage / armor_dmg_mult) if armor_dmg_mult > 0 else armor_damage
		
		if remaining_damage > 0:
			hp -= remaining_damage
	
	hp = max(0, hp)
	var hp_lost = hp_before - hp
	damage_taken_in_battle += hp_lost
	
	spawn_damage_text(hp_lost, is_headshot) # Використовуємо РЕАЛЬНУ втрату HP
	play_shake_effect()
	if is_headshot and hp_lost > 0:
		var cam = get_parent().find_child("Camera2D")
		if cam and cam.has_method("play_crit_effect"):
			cam.play_crit_effect()
	
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(1.5, 0.3, 0.3), 0.05)
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	await get_tree().create_timer(0.6).timeout # Чекаємо завершення анімації -HP
	
	if hp <= 0:
		die(killer)
	else:
		# Перевірка на паніку від сильного поранення (>25% HP)
		if float(hp_lost) > float(max_hp) * 0.25:
			trigger_resolve_check(10)
			_try_roll_injury(is_headshot)
		
	return hp_lost # Повертаємо результат для логів

func _try_roll_injury(is_headshot: bool) -> void:
	if injuries.size() >= 3: return  # Не більше 3 травм одночасно
	var roll = randi() % 100
	# 30% шанс при сильному пораненні; голова збільшує шанс до 50%
	var threshold = 50 if is_headshot else 30
	if roll >= threshold: return
	# Голова → тільки струс; тіло → все крім струсу
	var pool: Array
	if is_headshot:
		pool = INJURY_TABLE.filter(func(e): return e.id == "concussion")
	else:
		pool = INJURY_TABLE.filter(func(e): return e.id != "concussion")
	# Не додавати дублікати
	var existing_ids = injuries.map(func(e): return e.id)
	pool = pool.filter(func(e): return not existing_ids.has(e.id))
	if pool.is_empty(): return
	var injury = pool[randi() % pool.size()]
	injuries.append(injury)

func spawn_damage_text(amount: int, is_crit: bool = false) -> void:
	var label = Label.new()
	label.text = "-%d" % amount + ("!!" if is_crit else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.YELLOW if is_crit else Color.CRIMSON)
	label.add_theme_font_size_override("font_size", 20 if is_crit else 16)
	label.global_position = global_position + Vector2(randf_range(-15, 15), -40)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0, 0.8)
	tween.chain().tween_callback(label.queue_free)

func spawn_text_fx(text_str: String, color: Color) -> void:
	var label = Label.new()
	label.text = text_str
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.global_position = global_position + Vector2(randf_range(-10, 10), -60)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0, 1.2)
	tween.chain().tween_callback(label.queue_free)

func play_shake_effect() -> void:
	var tween = create_tween()
	var start_pos = position
	for i in range(5):
		var offset = Vector2(randf_range(-5, 5), randf_range(-2, 2))
		tween.tween_property(self, "position", start_pos + offset, 0.02)
	tween.tween_property(self, "position", start_pos, 0.02)

func play_recoil_effect(target: Node2D) -> void:
	var dir = (target.position - position).normalized()
	var start_pos = position
	var tw = create_tween()
	tw.tween_property(self, "position", start_pos - dir * 10.0, 0.05).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", start_pos, 0.2).set_trans(Tween.TRANS_SPRING)

func attack(target: Node2D, skill: Dictionary) -> void:
	if is_dead or ap < skill.ap or stamina < skill.stamina: return
	
	ap -= skill.ap
	stamina -= skill.stamina
	
	_perform_attack_logic(target, skill, false)

func execute_recover(skill: Dictionary) -> void:
	if is_dead: return
	if ap < skill.ap: return
	
	spawn_text_fx("💤 " + tr("BATTLE_RECOVER"), Color.SKY_BLUE)
	stamina = clampi(stamina + int(max_stamina * 0.5), 0, max_stamina)
	ap = 0 # Забирає всі AP
	
	var bm = get_parent().find_child("BattleManager")
	if bm:
		bm.current_skill_id = ""
		if bm.unit_panel: bm.unit_panel.update_unit_info(self)
		bm.end_unit_turn()

func execute_riposte_counter(attacker: Node2D) -> void:
	if is_dead: return
	spawn_text_fx("⚡ " + tr("BATTLE_RIPOSTE"), Color.GOLD)
	# Знаходимо чи у нас є звичайний удар для контр-атаки
	var strike_skill = null
	for s in available_skills:
		if s.id == "strike":
			strike_skill = s
			break
	
	# Контрудар у стійці Відповідь зазвичай не витрачає AP
	if strike_skill:
		_perform_attack_logic(attacker, strike_skill, true)

func execute_reload(skill: Dictionary) -> void:
	if is_dead or is_loaded: return
	if ap < skill.ap or stamina < skill.stamina: return
	
	ap -= skill.ap
	stamina -= skill.stamina
	is_loaded = true
	
	spawn_text_fx("🔄 " + tr("BATTLE_LOADED"), Color.LIGHT_GREEN)

func execute_shoot(target: Node2D, skill: Dictionary) -> void:
	if is_dead or ap < skill.ap or stamina < skill.stamina or not is_loaded: return
	
	ap -= skill.ap
	stamina -= skill.stamina
	is_loaded = false

	if _sprite:
		_update_sprite_direction(target.position - position)

	spawn_text_fx("💥 " + tr("BATTLE_SHOT"), Color.ORANGE)
	play_recoil_effect(target)
	
	var grid = get_parent().find_child("TacticalGrid")
	var bm = get_parent().find_child("BattleManager")
	if team == 0 and bm:
		bm._maybe_combat_hint("reload", tr("COMBAT_HINT_RELOAD"))
	var u_map = IsoMath.local_to_map(position)
	var target_map = IsoMath.local_to_map(target.position)
	
	var final_target = target
	var hit_chance = get_potential_hit_chance(target)
	
	if grid:
		var los = grid.check_line_of_sight(u_map, target_map)
		# Перевірка дружнього вогню / побічних цілей (friendly fire)
		for unit_in_way in los["units_in_way"]:
			var base_skill = data.base_ranged_skill if data and "base_ranged_skill" in data else 50
			var collateral_chance = max(5, 50 - int(base_skill / 2.0))
			
			var c_roll = randi() % 100
			if c_roll < collateral_chance:
				final_target = unit_in_way
				hit_chance = 100 # Гарантоване побічне влучання (куля знайшла ціль достроково)
				if bm: bm.log_message(tr("BATTLE_FRIENDLY_FIRE_HIT") % unit_in_way.name, Color.ORANGE)
				break
				
	AudioManager.play_sfx("hit_ranged")
	# Затримка для анімації польоту
	await get_tree().create_timer(0.3).timeout

	if not is_instance_valid(final_target) or final_target.get("is_dead"):
		move_finished.emit()
		return

	var roll = randi() % 100
	var is_hit = roll < hit_chance

	if is_hit:
		var amount = randi_range(25, 45) # Мушкет б'є сильніше
		var is_head = (randi() % 100) < 15

		var armor_pen = skill.get("armor_pen", 0.0)
		var actual_damage = await final_target.take_damage(amount, is_head, armor_pen, 1.0, self)
		damage_dealt_in_battle += actual_damage
		
		if bm:
			var team_name = tr("TEAM_ENEMY") if final_target.team == 1 else tr("TEAM_COSSACK")
			var head_text = " (" + tr("BATTLE_HEADSHOT") + ")" if is_head else ""
			var msg = "🎯 " + tr("BATTLE_HIT") % [name, final_target.name, actual_damage] + " (%s)%s" % [team_name, head_text]
			bm.log_message(msg, Color.INDIAN_RED if final_target.team == 1 else Color(0.3, 0.7, 1.0))
	else:
		if bm: bm.log_message("💨 " + tr("BATTLE_MISS") % [name, final_target.name], Color.GRAY)
		final_target.show_miss_fx()

	move_finished.emit()

func get_potential_hit_chance(target: Node2D) -> int:
	var my_map_pos = IsoMath.local_to_map(position)
	var target_map_pos = IsoMath.local_to_map(target.position)
	
	var bm = get_parent().find_child("BattleManager")
	var is_ranged = (bm and bm.current_skill_id == "shoot")
	
	var attacker_skill = 50
	var skill_hit_mod = 0
	
	if bm and bm.current_skill_id:
		for s in available_skills:
			if s.id == bm.current_skill_id:
				skill_hit_mod = s.get("hit_mod", 0)
				break

	var target_defense = (target.data.base_melee_defense if target.data else 5) + target.get_morale_modifier()
	
	if is_ranged:
		attacker_skill = (data.base_ranged_skill if data and "base_ranged_skill" in data else 45) + get_morale_modifier() + skill_hit_mod
	else:
		attacker_skill = (data.base_melee_skill if data else 50) + get_morale_modifier() + _get_terrain_skill_mod(my_map_pos) + skill_hit_mod
		# Бонус від висоти тільки для ближнього бою згідно старого коду
		var height_diff = _get_terrain_height(my_map_pos) - _get_terrain_height(target_map_pos)
		if height_diff > 0: attacker_skill += 10
		elif height_diff < 0: attacker_skill -= 10
	
	# Штраф від місцевості цілі
	target_defense += target._get_terrain_defense_mod(target_map_pos)
	
	# Оточення (Flanking)
	var adjacent_enemies_for_target = target.get_adjacent_enemies_count()
	var flanking_bonus = 0
	if adjacent_enemies_for_target > 1:
		flanking_bonus = (adjacent_enemies_for_target - 1) * 5
	attacker_skill += flanking_bonus
	
	if is_ranged:
		var grid = get_parent().find_child("TacticalGrid")
		if grid:
			var los = grid.check_line_of_sight(my_map_pos, target_map_pos)
			attacker_skill -= los["bush_count"] * 20 # -20% за кожен кущ
		
		# Знаходимо максимальну дистанцію зброї
		var skill_range = 12 # дефолт мушкета
		if bm and bm.current_skill_id:
			for s in available_skills:
				if s.id == bm.current_skill_id:
					skill_range = s.range
					break
					
		# Бонус за ближчу дистанцію: максимум дальності дає базу 45. Кожен крок ближче дає +5%.
		# АЛЕ впритул (дистанція 1) бонус скидається, оскільки прицілитись неможливо
		var dist = IsoMath.get_dist_4(my_map_pos, target_map_pos)
		var distance_bonus = 0
		if dist > 1:
			distance_bonus = max(0, skill_range - dist) * 5
		
		var base_ranged = (data.base_ranged_skill if data and "base_ranged_skill" in data else 45)
		attacker_skill = base_ranged + get_morale_modifier() + distance_bonus
		
		# Штраф за стрільбу з-під тиску ворогів (ZoC)
		if get_adjacent_enemies_count() > 0:
			attacker_skill -= 40
			
	return clamp(attacker_skill - target_defense, Globals.CHANCE_MIN, Globals.CHANCE_MAX)

func _perform_attack_logic(target: Node2D, _skill: Dictionary, is_counter: bool = false) -> void:
	if _sprite:
		_update_sprite_direction(target.position - position)

	var hit_chance = get_potential_hit_chance(target)

	var roll = randi() % 100
	var is_hit = roll < hit_chance

	# Анімація залежить від типу навички
	var original_pos = position
	var tween = create_tween()
	var dir = (target.position - position).normalized()
	
	if _sprite:
		var rotate_tween = create_tween()
		rotate_tween.tween_property(_sprite, "rotation", deg_to_rad(12.0 if dir.x > 0 else -12.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rotate_tween.tween_property(_sprite, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if _skill.get("id", "") == "thrust":
		# Lunge: короткий випад вперед на ~1 гекс і різке повернення
		var lunge_pos = position + dir * 80.0 # ~1 гекс вперед
		tween.tween_property(self, "position", lunge_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", original_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(self, "position", lerp(original_pos, target.position, 0.45), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", original_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	if is_hit:
		AudioManager.play_sfx("hit_melee")
		var d_min = weapon_resource.damage_min if weapon_resource else 20
		var d_max = weapon_resource.damage_max if weapon_resource else 35
		var damage_mod = _skill.get("damage_mod", 1.0)
		
		var amount = int(randi_range(d_min, d_max) * damage_mod)
		
		var base_head_chance = 15
		var head_bonus = _skill.get("head_bonus", 0.0)
		var is_head = _skill.get("guaranteed_head", false) or (randi() % 100) < (base_head_chance + int(head_bonus * 100))
		
		var armor_pen = _skill.get("armor_pen", 0.0)
		var armor_dmg = _skill.get("armor_dmg", 1.0)
		# Наносимо шкоду і отримуємо реальний результат
		var actual_damage = await target.take_damage(amount, is_head, armor_pen, armor_dmg, self)
		damage_dealt_in_battle += actual_damage
		
		var bm = get_parent().find_child("BattleManager")
		if bm:
			var team_name = tr("TEAM_ENEMY") if team == 1 else tr("TEAM_COSSACK")
			var head_text = " (" + tr("BATTLE_HEADSHOT") + ")" if is_head else ""
			var msg = "🎯 " + tr("BATTLE_HIT") % [name, target.name, actual_damage] + " (%s)%s" % [team_name, head_text]
			bm.log_message(msg, Color.INDIAN_RED if team == 1 else Color(0.3, 0.7, 1.0))
	else:
		var bm = get_parent().find_child("BattleManager")
		if bm:
			bm.log_message("🛡️ " + tr("BATTLE_MISS") % [name, target.name], Color.GRAY)
		
		target.show_miss_fx()
		# Механіка «Відповіді» не спрацьовує ланцюжком (тільки на пряму атаку)
		if not is_counter and target.get("is_riposting"):
			target.execute_riposte_counter(self)
			
	move_finished.emit()

func is_melee_unit() -> bool:
	# Тільки зброя ближнього бою дає ZoC атаки
	if weapon_resource:
		return weapon_resource.type != WeaponResource.WeaponType.MUSKET
	return weapon_type in ["sword", "spear", "heavy", "mace", "axe"]

func perform_opportunity_attack(target: Node2D) -> bool:
	if not is_melee_unit(): return false
	if current_morale == MoralState.FLEEING: return false
	
	spawn_text_fx("⚔️ " + tr("BATTLE_INTERCEPT"), Color.CRIMSON)
	
	var attacker_skill = (data.base_melee_skill if data else 50) + get_morale_modifier()
	var target_defense = (target.data.base_melee_defense if target.data else 5) + target.get_morale_modifier()
	
	# --- Розрахунок складності відступу з ZoC ---
	# Базовий штраф: повертаючись спиною, втікач є легкою мішенню
	var base_escape_penalty = 25
	
	# Стан юніта: втомлений юніт (низька stamina) отримує до +20 до штрафу
	var fatigue_penalty = 0
	if target.max_stamina > 0:
		fatigue_penalty = int(20.0 * (1.0 - float(target.stamina) / float(target.max_stamina)))
		
	# Навички: різниця у бойовому вмінні між втікачем та нападником
	var skill_diff = 0
	if target.data and data:
		skill_diff = int((target.data.base_melee_skill - data.base_melee_skill) / 2.0)
	
	# Фінальний штраф до захисту при втечі (що збільшує шанс влучання ворога)
	var effective_penalty = base_escape_penalty + fatigue_penalty - skill_diff
	# Штраф не може стати бонусом
	effective_penalty = max(0, effective_penalty)
	
	target_defense -= effective_penalty
	# ---------------------------------------------
	
	var hit_chance = clamp(attacker_skill - target_defense, Globals.CHANCE_MIN, Globals.CHANCE_MAX)
	
	var roll = randi() % 100
	var is_hit = roll < hit_chance
	
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", lerp(original_pos, target.position, 0.4), 0.1).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", original_pos, 0.1).set_trans(Tween.TRANS_QUAD)
	
	if is_hit:
		# Шкода залежить від зброї нападника (фолбек 20–35, як було)
		var d_min = weapon_resource.damage_min if weapon_resource else 20
		var d_max = weapon_resource.damage_max if weapon_resource else 35
		var opp_armor_pen = weapon_resource.armor_penetration if weapon_resource else 0.0
		var opp_armor_dmg = weapon_resource.armor_damage_modifier if weapon_resource else 1.0
		var damage = randi_range(d_min, d_max)
		var is_head = (randi() % 100) < 25
		var actual_damage = await target.take_damage(damage, is_head, opp_armor_pen, opp_armor_dmg, self)
		damage_dealt_in_battle += actual_damage
		
		var bm = get_parent().find_child("BattleManager")
		if bm:
			bm.log_message("⚔️ " + tr("BATTLE_INTERCEPT") + ": " + tr("BATTLE_HIT") % [name, target.name, actual_damage], Color.ORANGE_RED)
		return true
	else:
		target.show_miss_fx()
		var bm = get_parent().find_child("BattleManager")
		if bm:
			bm.log_message("💨 " + tr("BATTLE_MISS") % [name, target.name], Color.GRAY)
		return false

func show_miss_fx() -> void:
	var label = Label.new()
	label.text = tr("BATTLE_MISS_SHORT")
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.top_level = true
	label.global_position = global_position + Vector2(-30, -50)
	get_parent().add_child.call_deferred(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.6)
	tween.tween_property(label, "modulate:a", 0, 0.6)
	tween.chain().tween_callback(label.queue_free)

func use_rally(skill: Dictionary) -> void:
	ap -= skill.ap
	stamina = clampi(stamina - skill.stamina, 0, max_stamina)
	is_riposting = false
	
	spawn_text_fx("🔊 " + tr("BATTLE_RALLY"), Color.GOLD)
	
	var my_map_pos = IsoMath.local_to_map(position)
	for child in get_parent().get_children():
		if child is CombatUnit and not child.get("is_dead") and child.get("team") == team:
			var c_pos = IsoMath.local_to_map(child.position)
			if IsoMath.get_dist_4(my_map_pos, c_pos) <= 4:
				if child != self:
					# Додатковий бонус Осавула
					child.trigger_resolve_check(-20)

func activate_riposte(skill: Dictionary) -> void:
	ap -= skill.ap
	stamina = clampi(stamina - skill.stamina, 0, max_stamina)
	is_riposting = true
	spawn_text_fx("⚔️ " + tr("BATTLE_RIPOSTE"), Color.GOLD)

func execute_ai() -> void:
	var bm = get_parent().find_child("BattleManager")
	var grid = get_parent().find_child("TacticalGrid")
	if not bm or not grid or is_dead: return
	var grid_size: int = grid.GRID_SIZE if "GRID_SIZE" in grid else 16
	
	# 1. Перевірка моралі (Втеча вже оброблена в start_turn через execute_flee_ai)
	if current_morale == MoralState.FLEEING: return
	
	# 2. Перевірка Stamina (Recover)
	if stamina < 20 and ap >= 9:
		spawn_text_fx("💤 " + tr("BATTLE_RECOVER"), Color.SKY_BLUE)
		stamina = clampi(stamina + int(max_stamina * 0.5), 0, max_stamina)
		await get_tree().create_timer(0.8).timeout
		bm.end_unit_turn()
		return
		
	# 3. Перевірка на відступ (тактивний відступ при низькому HP)
	# Якщо HP < 25%, ШІ намагається відійти, замість атаки
	if float(hp) < float(max_hp) * 0.25 and ap >= 4:
		spawn_text_fx("🏃 " + tr("BATTLE_RETREAT_TACTICAL"), Color.WHITE)
		execute_flee_ai()
		return

	# Основний цикл дій ШІ
	while ap > 0 and not is_dead:
		await get_tree().create_timer(0.5).timeout # Пауза для читабельності
		
		# Оцінка обстановки
		var targets = []
		for child in get_parent().get_children():
			if child is CombatUnit and not child.get("is_dead") and child.get("team") != team:
				targets.append(child)
		
		if targets.is_empty(): break
		
		# Знаходимо найкращу ціль (враховуємо дистанцію та HP)
		var my_map_pos = IsoMath.local_to_map(position)
		targets.sort_custom(func(a,b):
			var dist_a = IsoMath.get_dist_4(my_map_pos, IsoMath.local_to_map(a.position))
			var dist_b = IsoMath.get_dist_4(my_map_pos, IsoMath.local_to_map(b.position))
			
			# Пріоритет 1: Дуже низьке HP (можна добити)
			var hp_priority_a = 1.0 if a.hp < 15 else 0.0
			var hp_priority_b = 1.0 if b.hp < 15 else 0.0
			
			if hp_priority_a != hp_priority_b:
				return hp_priority_a > hp_priority_b
			
			# Пріоритет 2: Дистанція
			return dist_a < dist_b
		)
		var target = targets[0]
		var dist = IsoMath.get_dist_4(my_map_pos, IsoMath.local_to_map(target.position))
		
		# --- Пріоритет дій ---
		
		# 1. Рятування (Rally) - якщо ми офіцер і союзники панікують
		var rally_skill = null
		for s in available_skills: if s.id == "rally": rally_skill = s
		if rally_skill and ap >= rally_skill.ap and stamina >= rally_skill.stamina:
			var needs_rally = false
			for child in get_parent().get_children():
				if child is CombatUnit and not child.get("is_dead") and child.get("team") == team and child != self:
					var c_pos = IsoMath.local_to_map(child.position)
					if IsoMath.get_dist_4(my_map_pos, c_pos) <= 4 and child.get("current_morale") >= MoralState.WAVERING:
						needs_rally = true
						break
			if needs_rally:
				use_rally(rally_skill)
				await get_tree().create_timer(0.6).timeout
				break # Згуртування зазвичай завершує хід

		# 2. Вибір та застосування бойової навички
		var active_skill = null
		
		# Пріоритет 1: Перезарядка (для мушкетів)
		var reload_skills = available_skills.filter(func(s): return s.id == "reload")
		if not reload_skills.is_empty():
			var reload_skill = reload_skills.front()
			if not is_loaded and ap >= reload_skill.ap and stamina >= reload_skill.stamina:
				execute_reload(reload_skill)
				await get_tree().create_timer(0.6).timeout
				continue
			
		# Пріоритет 2: Атака (якщо є в радіусі)
		# Шукаємо будь-яку атакуючу навичку (крім reload/recover/rally/riposte)
		var attack_skills = available_skills.filter(func(s): 
			return s.id in ["shoot", "thrust", "cleave", "strike"]
		)
		
		for s in attack_skills:
			if dist <= s.range and ap >= s.ap and stamina >= s.stamina:
				# Для пострілу перевіряємо чи заряджено
				if s.id == "shoot" and not is_loaded: continue
				# Для списа перевіряємо пряму лінію
				if s.id == "thrust":
					var t_map = IsoMath.local_to_map(target.position)
					if t_map.x != my_map_pos.x and t_map.y != my_map_pos.y:
						continue
				
				active_skill = s
				break
		
		if active_skill:
			if active_skill.id == "shoot":
				execute_shoot(target, active_skill)
			else:
				attack(target, active_skill)
			await move_finished # Чекаємо завершення анімації атаки
			continue
			
		# 3. Рух до цілі
		if ap >= 2:
			# Отримуємо дальність поточної найкращої атаки
			var preferred_range = 1
			for s in attack_skills:
				preferred_range = max(preferred_range, s.range)
			
			if dist > preferred_range:
				var obstacles = grid.get_all_obstacles()
				var weights = grid.get_terrain_weights()
				var a_path = IsoMath.get_astar_path(my_map_pos, IsoMath.local_to_map(target.position), obstacles, grid_size, weights)
				
				# Якщо шлях довший ніж наша дальність
				if a_path.size() > (preferred_range + 1):
					var zoc_tiles = grid.get_enemy_zoc_tiles(team)
					var move_path: Array[Vector2i] = [a_path[0]]
					var cost = 0
					
					# Йдемо по шляху, але не ближче ніж preferred_range
					# (a_path.size() - preferred_range) - це індекс точки, яка знаходиться на потрібній дистанції
					var limit = clampi(a_path.size() - preferred_range, 0, a_path.size())
					
					for i in range(1, limit):
						var step_cost = _get_terrain_step_costs(a_path[i])["ap"]
						if cost + step_cost <= ap:
							move_path.append(a_path[i])
							cost += step_cost
							if a_path[i] in zoc_tiles: break
						else:
							break
					
					if move_path.size() > 1:
						await move_along_path(move_path, cost)
						continue
		
		# 4. Захисна стійка (Riposte) в кінці ходу
		var riposte_skill = null
		for s in available_skills: if s.id == "riposte": riposte_skill = s
		if riposte_skill and dist == 1 and ap >= riposte_skill.ap and stamina >= riposte_skill.stamina and not is_riposting:
			activate_riposte(riposte_skill)
			await get_tree().create_timer(0.4).timeout
			break # Рипост зазвичай завершує хід за логікою Battle Brothers
			
		break # Якщо нічого не зробили — завершуємо цикл
		
	bm.end_unit_turn()

func gain_xp(amount: int) -> void:
	if team != 0: return # Тільки для козаків
	xp += amount
	xp_earned_in_battle += amount
	spawn_text_fx("+%d XP" % amount, Color(0.4, 0.9, 1.0))
	if xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		AudioManager.play_sfx("level_up")
		levels_gained_in_battle += 1
		xp_to_next = int(xp_to_next * 1.4) # Кожен наступний рівень коштує більше
		spawn_text_fx(tr("BATTLE_LEVEL_UP_FX") % level, Color.GOLD)
		# Невелике підвищення характеристик за рівень
		if data:
			data.base_melee_skill += 1
			data.base_ranged_skill += 1
			data.base_melee_defense += 1
			max_hp += 2
			hp = min(hp + 2, max_hp)


func die(killer: Node2D = null) -> void:
	if is_dead: return
	is_dead = true
	AudioManager.play_sfx("death")
	is_active = false
	var bm = get_parent().find_child("BattleManager")
	if bm:
		bm.log_message("💀 [b]!!! " + tr("BATTLE_DEATH") % name + " !!![/b]", Color.CRIMSON)
	
	print("%s загинув та впав на землю." % name)
	
	var my_map_pos = IsoMath.local_to_map(position)
	_spread_panic_to_allies(4, 15, "💀 " + tr("BATTLE_PANIC_DEATH") % name)
	
	# XP за вбивство — насамперед вбивці, навіть якщо він стріляв здалеку
	var xp_reward = data.xp_reward if data and "xp_reward" in data else 30
	if killer and killer is CombatUnit and not killer.get("is_dead") and killer.get("team") != team:
		killer.gain_xp(xp_reward)

	# Бонус ворогам поруч: перевірка духу + половина XP свідкам убивства
	for child in get_parent().get_children():
		if child is CombatUnit and not child.get("is_dead") and child != self:
			if child.get("team") != team:
				var other_map_pos = IsoMath.local_to_map(child.position)
				if IsoMath.get_dist_4(my_map_pos, other_map_pos) <= 3:
					child.trigger_resolve_check(-5) # Смерть ворога (бонус)
					if child != killer:
						child.gain_xp(int(xp_reward / 2.0))
	
	# Прибираємо обводку активності
	if _sprite:
		_sprite.modulate = Color.WHITE
	elif has_node("ActiveOutline"):
		get_node("ActiveOutline").visible = false

	# Анімація смерті (Темнішає, падає набік та стає неактивним)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate", Color(0.2, 0.2, 0.2, 0.6), 1.0)
	if _sprite:
		var fall_angle = deg_to_rad(90.0 if randf() > 0.5 else -90.0)
		tw.tween_property(_sprite, "rotation", fall_angle, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "position:y", 15.0, 0.6)
	z_index = -1 # Тіло лежить під ногами живих

func _spread_panic_to_allies(radius: int, penalty: int, log_msg: String) -> void:
	var my_map_pos = IsoMath.local_to_map(position)
	var bm = get_parent().find_child("BattleManager")
	var spread_count = 0
	
	for child in get_parent().get_children():
		if child is CombatUnit and not child.get("is_dead") and child != self:
			if child.get("team") == team:
				var other_map_pos = IsoMath.local_to_map(child.position)
				if IsoMath.get_dist_4(my_map_pos, other_map_pos) <= radius:
					child.trigger_resolve_check(penalty)
					spread_count += 1
	
	if spread_count > 0 and bm:
		bm.log_message("⚠️ " + log_msg, Color.ORANGE_RED)

func retreat() -> void:
	if is_dead: return
	is_active = false
	spawn_text_fx("🏃 " + tr("BATTLE_RETREAT"), Color.WHITE)

	# Видаляємо себе з черги ходів до звільнення
	var bm = get_parent().find_child("BattleManager")
	if bm:
		bm.turn_queue.erase(self)

	# Анімація зникнення
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

var _highlight_tween: Tween

func set_highlight(active: bool) -> void:
	if is_dead: return

	if _highlight_tween:
		_highlight_tween.kill()
	_highlight_tween = create_tween()

	var target_scale = Vector2(1.15, 1.15) if active else Vector2(1.0, 1.0)
	var duration = 0.25

	_highlight_tween.set_parallel(true)
	_highlight_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(self, "scale", target_scale, duration)

	if _sprite:
		var target_mod = Color(1.15, 1.15, 1.15) if active else Color.WHITE
		_highlight_tween.tween_property(_sprite, "modulate", target_mod, duration)
	elif active:
		_highlight_tween.tween_property(self, "modulate:v", 1.5, duration)
	else:
		_highlight_tween.tween_property(self, "modulate", Color.WHITE, duration)
