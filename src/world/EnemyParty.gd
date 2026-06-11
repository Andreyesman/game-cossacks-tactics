extends Node2D

enum State { PATROL, PURSUE, RETURN_TO_BASE, FLEE }

const SPEED := 80.0
const DETECTION_RADIUS := 40.0
const ENCOUNTER_RADIUS := 25.0

var faction: String = "none"
var unit_paths: Array[String] = []
var base_pos: Vector2 = Vector2.ZERO
var patrol_waypoints: Array[Vector2] = []
var current_wp_idx: int = 0
var state: State = State.PATROL
var source_id: String = ""
var reward_thalers: int = 100

var _wait_timer: float = 0.0
var _player_ref: Node2D = null
var _enemy_target: Node2D = null  # ціль для міжфракційного бою (тільки бандити)

signal encounter_reached(party: Node2D)

func _ready() -> void:
	z_index = 5
	set_process(false)  # Стоїмо доки WorldMap не вмикає через _set_parties_ticking()

func _draw() -> void:
	var col := get_faction_color()
	# Тінь
	draw_circle(Vector2.ZERO, 12.0, Color(0.0, 0.0, 0.0, 0.45))
	# Основний кружок фракції
	draw_circle(Vector2.ZERO, 9.0, col)
	# Темний центр (виглядає як ікона загону)
	draw_circle(Vector2.ZERO, 4.0, col.darkened(0.5))
	# Мечі (два діагональних штрихи)
	draw_line(Vector2(-4, -4), Vector2(4, 4), Color(1, 1, 1, 0.7), 1.5)
	draw_line(Vector2(4, -4), Vector2(-4, 4), Color(1, 1, 1, 0.7), 1.5)

func setup(data: Dictionary, player: Node2D) -> void:
	source_id = data.get("id", "")
	faction = data.get("faction", "none")
	unit_paths.assign(data.get("unit_paths", []))
	base_pos = Vector2(data["base_pos"]["x"], data["base_pos"]["y"])
	position = Vector2(data["pos"]["x"], data["pos"]["y"])
	reward_thalers = _calc_reward()
	_player_ref = player

	var raw_wps: Array = data.get("patrol_waypoints", [])
	patrol_waypoints.clear()
	for wp in raw_wps:
		patrol_waypoints.append(Vector2(wp["x"], wp["y"]))

	if patrol_waypoints.is_empty():
		patrol_waypoints = [base_pos]

	queue_redraw()

func _process(delta: float) -> void:
	# WorldMap керує set_process(false) коли гравець не рухається (пауза)
	if _player_ref:
		var d := position.distance_to(_player_ref.position)
		if d < ENCOUNTER_RADIUS:
			encounter_reached.emit(self)
			set_process(false)
			return

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.PURSUE:
			_process_pursue(delta)
		State.FLEE:
			_process_flee(delta)
		State.RETURN_TO_BASE:
			_process_return(delta)

func _process_patrol(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		return

	if patrol_waypoints.is_empty():
		return

	var target := patrol_waypoints[current_wp_idx]
	var dist := position.distance_to(target)

	if dist < 5.0:
		current_wp_idx = (current_wp_idx + 1) % patrol_waypoints.size()
		_wait_timer = randf_range(0.5, 1.5)
		return

	position += (target - position).normalized() * SPEED * delta

	# Перевіряємо чи гравець поруч
	if _player_ref and position.distance_to(_player_ref.position) < DETECTION_RADIUS:
		_evaluate_hostility_and_strength()

	# Бандити сканують слабші фракційні загони
	if faction == "bandits" and _enemy_target == null:
		_scan_for_faction_target()
	if _enemy_target != null:
		state = State.PURSUE

func _evaluate_hostility_and_strength() -> void:
	var cm = get_node_or_null("/root/CampaignManager")
	var is_hostile = true
	var player_strength = 20
	
	if cm:
		if faction != "none" and cm.get_rep(faction) > -20:
			is_hostile = false
			
		var squad = cm.world_state.get("squad", [])
		player_strength = 0
		for u in squad:
			player_strength += 10 + u.get("level", 1) * 2
			
	if not is_hostile:
		return
		
	var my_strength = unit_paths.size() * 10
	if my_strength >= player_strength * 0.7:
		state = State.PURSUE
	else:
		state = State.FLEE

func _scan_for_faction_target() -> void:
	var my_strength := unit_paths.size()
	for party: Node2D in get_parent().get_children():
		if party == self:
			continue
		var their_faction: Variant = party.get("faction")
		if their_faction == null or their_faction == "bandits":
			continue
		var their_paths: Variant = party.get("unit_paths")
		if their_paths == null:
			continue
		var d := position.distance_to(party.position)
		if d < DETECTION_RADIUS and (their_paths as Array).size() <= my_strength:
			_enemy_target = party
			return

func _simulate_party_battle(target: Node2D) -> void:
	var my_str := unit_paths.size()
	var their_paths: Variant = target.get("unit_paths")
	var their_str := (their_paths as Array).size() if their_paths is Array else 3
	var win_chance := float(my_str) / float(my_str + their_str)

	if randf() < win_chance:
		var src_id_v: Variant = target.get("source_id")
		var src_id: String = src_id_v if src_id_v is String else ""
		var cm := get_node_or_null("/root/CampaignManager")
		if cm:
			var parties: Array = cm.world_state.get("enemy_parties", [])
			for i: int in range(parties.size()):
				if parties[i].get("id", "") == src_id:
					parties.remove_at(i)
					break
		target.queue_free()
		if unit_paths.size() > 1:
			unit_paths.pop_back()
		_enemy_target = null
		state = State.RETURN_TO_BASE
	else:
		var cm := get_node_or_null("/root/CampaignManager")
		if cm:
			var parties: Array = cm.world_state.get("enemy_parties", [])
			for i: int in range(parties.size()):
				if parties[i].get("id", "") == source_id:
					parties.remove_at(i)
					break
		queue_free()

func _process_pursue(delta: float) -> void:
	# Переслідування ворожого фракційного загону
	if _enemy_target != null:
		if not is_instance_valid(_enemy_target):
			_enemy_target = null
			state = State.PATROL
			return
		var d := position.distance_to(_enemy_target.position)
		if d < ENCOUNTER_RADIUS:
			_simulate_party_battle(_enemy_target)
			return
		if d > DETECTION_RADIUS * 2.0:
			_enemy_target = null
			state = State.PATROL
			return
		position += (_enemy_target.position - position).normalized() * (SPEED * 1.1) * delta
		return

	# Переслідування гравця
	if not _player_ref:
		state = State.PATROL
		return

	var player_dist := position.distance_to(_player_ref.position)

	if player_dist > DETECTION_RADIUS * 1.5:
		state = State.PATROL
		return

	position += (_player_ref.position - position).normalized() * (SPEED * 1.1) * delta

func _process_flee(delta: float) -> void:
	if not _player_ref:
		state = State.PATROL
		return

	var d := position.distance_to(_player_ref.position)
	if d > DETECTION_RADIUS * 1.8:
		state = State.PATROL
		return

	position += (position - _player_ref.position).normalized() * (SPEED * 1.2) * delta

func _process_return(delta: float) -> void:
	var dist := position.distance_to(base_pos)
	if dist < 5.0:
		_wait_timer = randf_range(2.0, 4.0)
		state = State.PATROL
		return
	position += (base_pos - position).normalized() * SPEED * delta

func on_battle_finished(player_won: bool) -> void:
	if player_won:
		queue_free()
	else:
		state = State.RETURN_TO_BASE
		set_process(true)

func get_battle_config() -> Dictionary:
	return {
		"enemy_data_paths": unit_paths,
		"reward_thalers": reward_thalers,
		"source_id": source_id,
		"source_type": "party"
	}

func _calc_reward() -> int:
	return unit_paths.size() * 40

func get_faction_color() -> Color:
	match faction:
		"orda":  return Color(0.9, 0.5, 0.1)
		"crown": return Color(0.2, 0.4, 0.9)
		_:       return Color(0.7, 0.2, 0.2)
