extends Object

# Чиста логіка тактичної сітки (Vector2i ↔ Vector2i, без пікселів).
# Конвертація клітинка ↔ піксель — виключно через TileMapLayer:
#   пікселі → клітинка : _tile_layer.local_to_map(pos - _tile_layer.position)
#   клітинка → пікселі : _tile_layer.map_to_local(pos) + _tile_layer.position

# get_cell_center / local_to_map залишаються для CombatUnit та BattleManager,
# де немає прямого доступу до TileMapLayer.
# УВАГА: Godot 4.6 map_to_local((x,y)) = ((x-y+1)*80, (x+y+1)*40) — зсунуто на (80,40)
# відносно очікуваного (x-y)*80, (x+y)*40. Обидві формули нижче враховують цей зсув.
static func get_cell_center(map_pos: Vector2i) -> Vector2:
	var center_x = (float(map_pos.x) - float(map_pos.y) + 1.0) * 80.0
	var center_y = (float(map_pos.x) + float(map_pos.y) + 2.0) * 40.0
	return Vector2(center_x, center_y)

static func local_to_map(local_pos: Vector2) -> Vector2i:
	var x = (local_pos.x / 80.0 + local_pos.y / 40.0 - 3.0) / 2.0
	var y = (local_pos.y / 40.0 - local_pos.x / 80.0 - 1.0) / 2.0
	return Vector2i(floor(x), floor(y))

# Реалізація A* (ТІЛЬКИ 4 напрямки) - Базова версія (для зворотної сумісності)
static func get_astar_path(start: Vector2i, end: Vector2i, obstacles: Array[Vector2i], grid_size: int, terrain_weights: Dictionary = {}) -> Array[Vector2i]:
	if start == end: return [start]
	
	var astar = AStar2D.new()
	# ... (Попередній тяжкий код для сумісності залишаємо, але додаємо легку альтернативу нижче)
	for x in range(grid_size):
		for y in range(grid_size):
			var id = x + y * grid_size
			astar.add_point(id, Vector2(x, y))
			var pos = Vector2i(x, y)
			if terrain_weights.has(pos):
				astar.set_point_weight_scale(id, terrain_weights[pos])
			if pos in obstacles and pos != start and pos != end:
				astar.set_point_disabled(id, true)
	
	for x in range(grid_size):
		for y in range(grid_size):
			var id = x + y * grid_size
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var neighbour = Vector2i(x, y) + dir
				if neighbour.x >= 0 and neighbour.x < grid_size and neighbour.y >= 0 and neighbour.y < grid_size:
					var nid = neighbour.x + neighbour.y * grid_size
					astar.connect_points(id, nid)

	return get_astar_path_from_instance(astar, start, end, grid_size)

# Оптимізована версія: Використовує вже ініціалізований та налаштований AStar2D
static func get_astar_path_from_instance(astar: AStar2D, start: Vector2i, end: Vector2i, grid_size: int) -> Array[Vector2i]:
	if not astar: return []
	var start_id = start.x + start.y * grid_size
	var end_id = end.x + end.y * grid_size
	
	if not astar.has_point(start_id) or not astar.has_point(end_id): return []
	
	var path_v2 = astar.get_point_path(start_id, end_id)
	var result: Array[Vector2i] = []
	for p in path_v2:
		result.append(Vector2i(round(p.x), round(p.y)))
	
	return result

# Мангеттенська відстань (для 4-напрямкового руху)
static func get_dist_4(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

# Алгоритм Брезенгема для Лінії Зору
static func get_line_of_sight_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var dx = abs(end.x - start.x)
	var dy = -abs(end.y - start.y)
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var err = dx + dy
	
	var current = start
	while true:
		path.append(current)
		if current == end:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			current.x += sx
		if e2 <= dx:
			err += dx
			current.y += sy
			
	return path
