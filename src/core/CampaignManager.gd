extends Node

# ── Стан кампанії ─────────────────────────────────────────────────────────────

var world_state: Dictionary = {}
# Формат world_state:
# {
#   "day": int,
#   "thalers": int,
#   "provisions": int,
#   "faction_rep": {"crown": int, "sich": int, "orda": int},
#   "forest_patches": Array[Dictionary], # географія: [{x, y, r, outer, inner}]
#   "hill_patches": Array[Dictionary],   # [{x, y, r, verts}]
#   "swamp_patches": Array[Dictionary],  # [{x, y, r, verts}]
#   "kurgans": Array[Dictionary],        # [{x, y}]
#   "ravines": Array[Array],             # [[{x,y},...], ...]
#   "influence_anchors": Array[Dictionary], # зони впливу: [{faction, pos}] (Voronoi по містах)
#   "rivers": Array[Array],            # [[Vector2,...], ...]
#   "lakes": Array[Array],             # [[Vector2,...], ...]
#   "roads": Array[Array],             # [[Vector2, Vector2], ...]
#   "locations": Array[Dictionary],    # [{id, type, faction, pos, garrison_paths, cleared, reward_thalers, name}]
#   "enemy_parties": Array[Dictionary],# [{id, faction, unit_paths, patrol_waypoints, base_pos, pos, alive}]
#   "player_pos": Vector2,
#   "squad": Array[Dictionary]         # збережені дані козаків (як у SaveManager)
# }

# Конфіг активного бою — встановлюється перед переходом в Battle
var active_battle_config: Dictionary = {}
# {
#   "enemy_data_paths": Array[String],
#   "reward_thalers": int,
#   "source_id": String,   # id загону або локації
#   "source_type": String  # "party" або "location"
# }

# ── Запуск нової кампанії ─────────────────────────────────────────────────────

func new_campaign() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.clear_save()

	var sm_node := get_node_or_null("/root/SaveManager")
	world_state = {
		"day": 1,
		"thalers": 150,
		"provisions": 10,
		"tutorial_done": false,
		"faction_rep": {"crown": 0, "sich": 0, "orda": 0},
		"rivers": [],
		"lakes": [],
		"roads": [],
		"locations": [],
		"enemy_parties": [],
		"player_pos": Vector2(600, 500),
		"squad": _create_starting_squad(),
		"squad_inventory": [],
		"shop_inventory": sm_node._default_shop() if sm_node else [],
		"fog_of_war_data": ""
	}

	var gen = load("res://src/core/WorldGenerator.gd").new()
	gen.generate(world_state)

	# Створюємо початковий пустий масив туману (100 * 67 байтів) та кодуємо в Base64
	var empty_bytes := PackedByteArray()
	empty_bytes.resize(100 * 67)
	empty_bytes.fill(0)
	world_state["fog_of_war_data"] = Marshalls.raw_to_base64(empty_bytes)

	if not world_state.get("tutorial_done", true):
		start_battle({
			"enemy_data_paths": ["res://src/resources/units/Bandit.tres", "res://src/resources/units/Bandit.tres"],
			"reward_thalers": 50,
			"source_id": "tutorial",
			"source_type": "tutorial",
			"is_tutorial": true
		})
	else:
		var tw = get_tree().create_tween()
		tw.tween_property(get_tree().current_scene, "modulate:a", 0.0, 0.25)
		await tw.finished
		get_tree().change_scene_to_file("res://src/scenes/WorldMap.tscn")

func _create_starting_squad() -> Array:
	var starting_units = [
		"res://src/resources/units/Nychypir.tres",
		"res://src/resources/units/Gavrulo.tres",
		"res://src/resources/units/Tymofiy.tres",
		"res://src/resources/units/Panko.tres"
	]
	var squad = []
	for path in starting_units:
		if ResourceLoader.exists(path):
			var data = load(path)
			if data:
				squad.append({
					"name": tr(data.unit_name),
					"hp": data.base_hp if data.base_hp > 0 else 60,
					"max_hp": data.base_hp if data.base_hp > 0 else 60,
					"morale": 100,
					"xp": 0,
					"level": 1,
					"xp_to_next": 150,
					"data_path": path,
					"weapon_resource_path": data.default_weapon.resource_path if data.get("default_weapon") else "",
					"armor_path": "",
					"helm_path": ""
				})
	return squad

# ── Перехід у бій ─────────────────────────────────────────────────────────────

func start_battle(config: Dictionary) -> void:
	print("CM: start_battle() викликано, config=", config)
	active_battle_config = config
	var tw = get_tree().create_tween()
	tw.tween_property(get_tree().current_scene, "modulate:a", 0.0, 0.2)
	# Timer замість await tw.finished: tween може зависнути в деяких edge cases
	await get_tree().create_timer(0.25).timeout
	print("CM: timer finished, changing scene to LoadingScreen...")
	get_tree().change_scene_to_file("res://src/scenes/LoadingScreen.tscn")

# ── Повернення після бою ──────────────────────────────────────────────────────

func finish_battle(is_victory: bool, player_units: Array, loot_pool: Array = []) -> void:
	if is_victory:
		var reward = active_battle_config.get("reward_thalers", 0)
		world_state["thalers"] = world_state.get("thalers", 0) + reward

		var src_id = active_battle_config.get("source_id", "")
		var src_type = active_battle_config.get("source_type", "")

		if src_type == "location":
			for loc in world_state.get("locations", []):
				if loc["id"] == src_id:
					loc["cleared"] = true
					break

		elif src_type == "party":
			var parties: Array = world_state.get("enemy_parties", [])
			for i in range(parties.size()):
				if parties[i]["id"] == src_id:
					parties[i]["alive"] = false
					break

		elif src_type == "tutorial":
			world_state["tutorial_done"] = true

		# Оновлюємо стан козаків
		world_state["squad"] = _serialize_units(player_units)
		# Додаємо трофеї з бою до інвентаря загону
		for item in loot_pool:
			InventoryManager.add_item(world_state, item)

	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.save_campaign(world_state)

	active_battle_config = {}

	var tw = get_tree().create_tween()
	tw.tween_property(get_tree().current_scene, "modulate:a", 0.0, 0.2)
	await get_tree().create_timer(0.25).timeout
	get_tree().change_scene_to_file("res://src/scenes/WorldMap.tscn")

# ── Завантаження збереженої кампанії ─────────────────────────────────────────

func load_campaign(saved_state: Dictionary) -> void:
	world_state = saved_state

# ── Репутація ─────────────────────────────────────────────────────────────────

func change_rep(faction: String, delta: int) -> void:
	if faction in world_state.get("faction_rep", {}):
		world_state["faction_rep"][faction] = clamp(
			world_state["faction_rep"][faction] + delta, -100, 100
		)

func get_rep(faction: String) -> int:
	return world_state.get("faction_rep", {}).get(faction, 0)

# Дії з загоном/локацією залежно від репутації
func get_encounter_options(faction: String) -> Array[String]:
	var rep = get_rep(faction)
	if faction == "none":
		return ["attack", "avoid"]
	if rep >= 20:
		return ["avoid", "talk"]
	if rep <= -20:
		return ["attack", "avoid"]
	return ["attack", "avoid", "talk"]

# ── Серіалізація юнітів ───────────────────────────────────────────────────────

func _serialize_units(units: Array) -> Array:
	var result = []
	var pre_battle_squad: Array = world_state.get("squad", [])
	for unit in units:
		if unit.get("is_dead"):
			continue
		var pre: Dictionary = {}
		for s: Dictionary in pre_battle_squad:
			if s.get("name") == unit.name:
				pre = s
				break
		var u_data = {
			"name": unit.name,
			"hp": unit.get("hp"),
			"max_hp": unit.get("max_hp"),
			"morale": pre.get("morale", 100),
			"xp": unit.get("xp"),
			"level": unit.get("level"),
			"xp_to_next": unit.get("xp_to_next"),
			"weapon_resource_path": unit.weapon_resource.resource_path if unit.get("weapon_resource") else "",
			"armor_path": pre.get("armor_path", ""),
			"helm_path":  pre.get("helm_path", "")
		}
		if "data" in unit and unit.data != null:
			# resource_path порожній після .duplicate() — зберігаємо шлях з попереднього запису загону
			u_data["data_path"] = pre.get("data_path", unit.data.resource_path)
			u_data["stat_melee_skill"] = unit.data.base_melee_skill
			u_data["stat_ranged_skill"] = unit.data.base_ranged_skill
			u_data["stat_melee_defense"] = unit.data.base_melee_defense
		result.append(u_data)
	return result
