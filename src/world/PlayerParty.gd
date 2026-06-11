extends Node2D

const SPEED := 100.0
const DETECTION_RADIUS := 18.0  # відстань до тригеру зустрічі
const INTERACTION_RADIUS := 18.0  # відстань для взаємодії з локацією

var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var pursuit_target: Node2D = null
var speed_multiplier: int = 1

signal movement_started
signal movement_stopped

func _ready() -> void:
	z_index = 10
	queue_redraw()

func _draw() -> void:
	# Зовнішнє кільце
	draw_circle(Vector2.ZERO, 14.0, Color(0.0, 0.0, 0.0, 0.5))
	# Основний жовтий кружок
	draw_circle(Vector2.ZERO, 11.0, Color(0.95, 0.85, 0.15))
	# Внутрішнє ядро
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.55, 0.0))
	# Хрестик всередині
	draw_line(Vector2(-5, 0), Vector2(5, 0), Color(0.2, 0.1, 0.0), 1.5)
	draw_line(Vector2(0, -5), Vector2(0, 5), Color(0.2, 0.1, 0.0), 1.5)

func _process(delta: float) -> void:
	if is_instance_valid(pursuit_target):
		target_position = pursuit_target.position

	if not is_moving:
		return

	var dist := position.distance_to(target_position)
	if dist < 4.0:
		position = target_position
		_stop()
		return

	var dir := (target_position - position).normalized()
	position += dir * SPEED * speed_multiplier * get_terrain_speed_mod() * delta

	# Перевірка зустрічей з ворожими загонами
	_check_encounters()

func get_terrain_speed_mod() -> float:
	var world_map = get_parent().get_parent()
	if world_map and world_map.has_method("get_terrain_speed_modifier"):
		return world_map.get_terrain_speed_modifier(position)
	return 1.0

func set_target(world_pos: Vector2) -> void:
	pursuit_target = null
	target_position = world_pos
	if not is_moving:
		is_moving = true
		movement_started.emit()

func set_pursuit_target(enemy: Node2D) -> void:
	pursuit_target = enemy
	if is_instance_valid(pursuit_target):
		target_position = pursuit_target.position
		if not is_moving:
			is_moving = true
			movement_started.emit()

func stop() -> void:
	_stop()

func _stop() -> void:
	if is_moving:
		is_moving = false
		pursuit_target = null
		movement_stopped.emit()

func _check_encounters() -> void:
	# WorldMap.gd підписується на цей сигнал і перевіряє конкретні вузли
	# Тут просто сповіщаємо — WorldMap вирішує, що робити
	pass

func get_interaction_radius() -> float:
	return INTERACTION_RADIUS

func get_detection_radius() -> float:
	return DETECTION_RADIUS
