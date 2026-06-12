class_name WFCGenerator
extends RefCounted

@warning_ignore("shadowed_global_identifier")
const ChunkLibrary = preload("res://src/tactical/ChunkLibrary.gd")

const GRID_SIZE = 16
const TERRAIN_COUNT = 6

# Дзеркалює TerrainType enum з TacticalGrid: CLEAR=0 BUSHES=1 SWAMP=2 WATER=3 ROCKS=4 TREE=5
const T_CLEAR  = 0
const T_BUSHES = 1
const T_SWAMP  = 2
const T_WATER  = 3
const T_ROCKS  = 4
const T_TREE   = 5

enum LocationType { STEPPE, FOREST, WETLANDS, RIVER }

# Ваги за типом локації: [CLEAR, BUSHES, SWAMP, WATER, ROCKS, TREE]
const LOCATION_NAMES: Dictionary = {
	LocationType.STEPPE:   "Степ",
	LocationType.FOREST:   "Ліс",
	LocationType.WETLANDS: "Болото",
	LocationType.RIVER:    "Річка",
}

const LOCATION_COLORS: Dictionary = {
	LocationType.STEPPE:   Color(0.88, 0.78, 0.38),  # золотисто-жовтий, суха трава
	LocationType.FOREST:   Color(0.35, 0.72, 0.35),  # зелений, хвоя
	LocationType.WETLANDS: Color(0.58, 0.72, 0.42),  # оливковий, мох
	LocationType.RIVER:    Color(0.38, 0.65, 0.88),  # блакитний, вода
}

# Правила суміжності: ADJACENCY_RULES[тип] = дозволені типи сусідів
const ADJACENCY_RULES: Array = [
	[0, 1, 2, 3, 4, 5],  # CLEAR — суміжний з усім
	[0, 1, 2, 4, 5],     # BUSHES — не WATER
	[0, 1, 2, 3],        # SWAMP — не ROCKS, не TREE
	[0, 2, 3],           # WATER — тільки CLEAR/SWAMP/WATER
	[0, 1, 4],           # ROCKS — тільки CLEAR/BUSHES/ROCKS
	[0, 1, 5],           # TREE  — тільки CLEAR/BUSHES/TREE
]

const MAX_ATTEMPTS = 10

var _wave: Array          # [cell_idx] -> Array[bool] довжиною TERRAIN_COUNT
var _entropy_cache: Array # [cell_idx] -> float (-1.0 = collapsed)
var _rng: RandomNumberGenerator
var _cell_weights: Array  # [cell_idx] -> Array[int] ваги зони для цієї клітини
var _current_location_type: int = LocationType.STEPPE


func generate(rng_seed: int = -1, location_type: int = LocationType.STEPPE, layout: Array = []) -> Dictionary:
	_current_location_type = location_type
	_rng = RandomNumberGenerator.new()
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	# Визначаємо ваги кожної клітини з лейауту зон
	var use_layout: Array = layout if not layout.is_empty() else ChunkLibrary.pick_layout(location_type)
	_cell_weights = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var zone_idx := (0 if x < 8 else 1) + (0 if y < 8 else 1) * 2
			_cell_weights.append(ChunkLibrary.ZONE_WEIGHTS[use_layout[zone_idx]])

	for _attempt in range(MAX_ATTEMPTS):
		var result = _attempt_generation()
		if not result.is_empty():
			return result
		_rng.seed = _rng.randi()

	return {}


func _attempt_generation() -> Dictionary:
	_initialize_wave()
	_seed_spawn_zones()

	if not _propagate_spawn_zones():
		return {}

	while true:
		var cell_idx = _find_lowest_entropy_cell()
		if cell_idx == -2:
			break  # всі клітини collapsed
		if cell_idx == -1:
			return {}  # протиріччя

		if _collapse_cell(cell_idx) == -1:
			return {}

		if not _propagate_from(cell_idx):
			return {}

	var terrain_map = _build_terrain_map()

	if _current_location_type == LocationType.RIVER:
		_carve_river(terrain_map)
	elif _current_location_type == LocationType.WETLANDS:
		_fix_wetlands(terrain_map)
	elif _current_location_type == LocationType.FOREST:
		_fix_forest(terrain_map)
	elif _current_location_type == LocationType.STEPPE:
		_fix_steppe(terrain_map)

	_compact_rock_clusters(terrain_map)

	if _check_connectivity(terrain_map):
		return terrain_map
	return {}


func _initialize_wave() -> void:
	_wave = []
	_entropy_cache = []
	for i in range(GRID_SIZE * GRID_SIZE):
		var cell: Array[bool] = []
		cell.resize(TERRAIN_COUNT)
		cell.fill(true)
		_wave.append(cell)
		_entropy_cache.append(_compute_cell_entropy_full(i))


func _seed_spawn_zones() -> void:
	for x in range(3):
		for y in range(3):
			_force_cell(x + y * GRID_SIZE, T_CLEAR)
	for x in range(GRID_SIZE - 3, GRID_SIZE):
		for y in range(GRID_SIZE - 3, GRID_SIZE):
			_force_cell(x + y * GRID_SIZE, T_CLEAR)


func _force_cell(idx: int, terrain: int) -> void:
	var cell: Array = _wave[idx]
	for t in range(TERRAIN_COUNT):
		cell[t] = (t == terrain)
	_entropy_cache[idx] = -1.0


func _propagate_spawn_zones() -> bool:
	for x in range(3):
		for y in range(3):
			if not _propagate_from(x + y * GRID_SIZE):
				return false
	for x in range(GRID_SIZE - 3, GRID_SIZE):
		for y in range(GRID_SIZE - 3, GRID_SIZE):
			if not _propagate_from(x + y * GRID_SIZE):
				return false
	return true


func _compute_cell_entropy_full(idx: int) -> float:
	var w: Array = _cell_weights[idx]
	var total: float = 0.0
	for weight in w:
		total += weight
	var entropy: float = 0.0
	for weight in w:
		if weight > 0:
			var p := float(weight) / total
			entropy -= p * log(p)
	return entropy


func _compute_entropy(cell: Array, idx: int) -> float:
	var w: Array = _cell_weights[idx]
	var total_weight: float = 0.0
	for t in range(TERRAIN_COUNT):
		if cell[t]:
			total_weight += w[t]
	if total_weight == 0.0:
		return 0.0  # протиріччя
	var entropy: float = 0.0
	for t in range(TERRAIN_COUNT):
		if cell[t]:
			var p = float(w[t]) / total_weight
			entropy -= p * log(p)
	return entropy


func _find_lowest_entropy_cell() -> int:
	var min_entropy: float = INF
	var min_idx: int = -2  # -2 = всі collapsed

	for i in range(GRID_SIZE * GRID_SIZE):
		var e: float = _entropy_cache[i]
		if e < 0.0:
			continue  # вже collapsed
		if e == 0.0:
			return -1  # протиріччя
		# Додаємо мікро-шум щоб уникнути top-left bias
		var noisy = e + _rng.randf_range(0.0, 0.0001)
		if noisy < min_entropy:
			min_entropy = noisy
			min_idx = i

	return min_idx


func _collapse_cell(idx: int) -> int:
	var cell: Array = _wave[idx]
	var w: Array = _cell_weights[idx]
	var total_weight: int = 0
	for t in range(TERRAIN_COUNT):
		if cell[t]:
			total_weight += w[t]

	if total_weight == 0:
		return -1

	var roll: int = _rng.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	var chosen: int = -1
	for t in range(TERRAIN_COUNT):
		if cell[t]:
			cumulative += w[t]
			if roll < cumulative:
				chosen = t
				break

	if chosen == -1:
		return -1

	_force_cell(idx, chosen)
	return chosen


func _propagate_from(start_idx: int) -> bool:
	var queue: Array[int] = [start_idx]
	var in_queue: Dictionary = {start_idx: true}

	const DIRS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var idx: int = queue.pop_front()
		in_queue.erase(idx)

		var x: int = idx % GRID_SIZE
		@warning_ignore("integer_division")
		var y: int = idx / GRID_SIZE
		var current_cell: Array = _wave[idx]

		# Які типи сусідів дозволяє ця клітина
		var allowed_for_neighbor: Array[bool] = []
		allowed_for_neighbor.resize(TERRAIN_COUNT)
		allowed_for_neighbor.fill(false)
		for t in range(TERRAIN_COUNT):
			if current_cell[t]:
				for allowed in ADJACENCY_RULES[t]:
					allowed_for_neighbor[allowed] = true

		for dir in DIRS:
			var nx: int = x + dir.x
			var ny: int = y + dir.y
			if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
				continue

			var nidx: int = nx + ny * GRID_SIZE
			if _entropy_cache[nidx] < 0.0:
				continue  # collapsed — пропустити

			var neighbor_cell: Array = _wave[nidx]
			var changed = false
			for t in range(TERRAIN_COUNT):
				if neighbor_cell[t] and not allowed_for_neighbor[t]:
					neighbor_cell[t] = false
					changed = true

			if not changed:
				continue

			var new_entropy = _compute_entropy(neighbor_cell, nidx)
			if new_entropy == 0.0:
				return false  # протиріччя

			_entropy_cache[nidx] = new_entropy

			# Якщо залишився рівно один варіант — вважати collapsed
			var count = 0
			for t in range(TERRAIN_COUNT):
				if neighbor_cell[t]:
					count += 1
			if count == 1:
				_entropy_cache[nidx] = -1.0

			if not nidx in in_queue:
				queue.append(nidx)
				in_queue[nidx] = true

	return true


func _build_terrain_map() -> Dictionary:
	var result: Dictionary = {}
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var idx = x + y * GRID_SIZE
			var cell: Array = _wave[idx]
			var terrain = T_CLEAR
			for t in range(TERRAIN_COUNT):
				if cell[t]:
					terrain = t
					break
			result[Vector2i(x, y)] = terrain
	return result


func _check_connectivity(terrain_map: Dictionary) -> bool:
	# BFS від центру spawn гравців до центру spawn ворогів через не-TREE клітини
	var start := Vector2i(1, 1)
	var goal  := Vector2i(GRID_SIZE - 2, GRID_SIZE - 2)

	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]

	const DIRS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			return true
		for dir in DIRS:
			var next: Vector2i = current + dir
			if next.x < 0 or next.x >= GRID_SIZE or next.y < 0 or next.y >= GRID_SIZE:
				continue
			if next in visited:
				continue
			if terrain_map.get(next, T_CLEAR) == T_TREE:
				continue
			visited[next] = true
			queue.append(next)

	return false


func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE


func _is_spawn_zone(pos: Vector2i) -> bool:
	return (pos.x <= 2 and pos.y <= 2) or (pos.x >= GRID_SIZE - 3 and pos.y >= GRID_SIZE - 3)


func _carve_river(terrain_map: Dictionary) -> void:
	# Очищаємо ізольовані краплі WATER від WFC
	for pos in terrain_map:
		if terrain_map[pos] == T_WATER:
			terrain_map[pos] = T_CLEAR

	const DIRS4 = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	# Випадкова орієнтація: горизонтальна або вертикальна
	var horizontal: bool = _rng.randi() % 2 == 0

	var river_cells: Array[Vector2i] = []
	var current: Vector2i
	var end_pos: Vector2i

	if horizontal:
		current  = Vector2i(0, _rng.randi_range(3, GRID_SIZE - 4))
		end_pos  = Vector2i(GRID_SIZE - 1, _rng.randi_range(3, GRID_SIZE - 4))
	else:
		current  = Vector2i(_rng.randi_range(3, GRID_SIZE - 4), 0)
		end_pos  = Vector2i(_rng.randi_range(3, GRID_SIZE - 4), GRID_SIZE - 1)

	# Крокова генерація: рухаємось по головній осі, зрідка коригуємо другорядну.
	# Запобіжник guard: раніше clamp обох осей робив end_pos (на краю карти)
	# недосяжним — вічний цикл і зависання на завантаженні бою.
	var guard: int = 0
	while current != end_pos and guard < GRID_SIZE * GRID_SIZE:
		guard += 1
		river_cells.append(current)

		var diff_main: int
		var diff_sec: int
		var step_main: Vector2i
		var step_sec: Vector2i

		if horizontal:
			diff_main = end_pos.x - current.x
			diff_sec  = end_pos.y - current.y
			step_main = Vector2i(sign(diff_main), 0)
			step_sec  = Vector2i(0, sign(diff_sec))
		else:
			diff_main = end_pos.y - current.y
			diff_sec  = end_pos.x - current.x
			step_main = Vector2i(0, sign(diff_main))
			step_sec  = Vector2i(sign(diff_sec), 0)

		# Примусова корекція якщо не встигнемо виправити secondary вісь
		var must_correct: bool = diff_sec != 0 and abs(diff_sec) >= abs(diff_main)
		var want_correct: bool = diff_sec != 0 and _rng.randf() < 0.45

		if must_correct or want_correct:
			current = current + step_sec
		else:
			current = current + step_main

		# Клемп лише ПОПЕРЕЧНОЇ осі: вздовж течії річка мусить дійти до краю (end_pos)
		if horizontal:
			current.y = clamp(current.y, 1, GRID_SIZE - 2)
		else:
			current.x = clamp(current.x, 1, GRID_SIZE - 2)

	river_cells.append(end_pos)

	# Ставимо WATER вздовж шляху
	for pos in river_cells:
		terrain_map[pos] = T_WATER

	# Болотяні береги: сусіди WATER, що не є WATER і не є spawn-зоною
	for pos in river_cells:
		for dir in DIRS4:
			var nb: Vector2i = pos + dir
			if _in_bounds(nb) and not _is_spawn_zone(nb) and terrain_map.get(nb, T_CLEAR) != T_WATER:
				terrain_map[nb] = T_SWAMP


func _fix_wetlands(terrain_map: Dictionary) -> void:
	# Збираємо всі WATER-клітини; якщо порожньо — інʼєктуємо 2×2 водойм у центр
	var water_cells: Array[Vector2i] = []
	for pos in terrain_map:
		if terrain_map[pos] == T_WATER:
			water_cells.append(pos)

	if water_cells.is_empty():
		var cx: int = _rng.randi_range(5, GRID_SIZE - 6)
		var cy: int = _rng.randi_range(5, GRID_SIZE - 6)
		for dx in range(2):
			for dy in range(2):
				var p := Vector2i(cx + dx, cy + dy)
				terrain_map[p] = T_WATER
				water_cells.append(p)

	# SWAMP, що далі ніж 5 тайлів від будь-якого WATER → замінити на BUSHES
	for pos in terrain_map:
		if terrain_map[pos] == T_SWAMP:
			if _bfs_dist_to_terrain(terrain_map, pos, T_WATER) > 5:
				terrain_map[pos] = T_BUSHES


func _bfs_dist_to_terrain(terrain_map: Dictionary, start: Vector2i, target: int) -> int:
	const DIRS4 = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	const MAX_SEARCH = 6
	var visited: Dictionary = {start: true}
	var queue: Array = [[start, 0]]

	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var pos: Vector2i = item[0]
		var dist: int = item[1]
		if terrain_map.get(pos, T_CLEAR) == target:
			return dist
		if dist >= MAX_SEARCH:
			continue
		for dir in DIRS4:
			var nb: Vector2i = pos + dir
			if _in_bounds(nb) and not visited.has(nb):
				visited[nb] = true
				queue.append([nb, dist + 1])

	return 999


func _fix_forest(terrain_map: Dictionary) -> void:
	_break_tree_walls(terrain_map)
	_space_trees(terrain_map)
	_break_tree_rings(terrain_map)


func _break_tree_walls(terrain_map: Dictionary) -> void:
	# По рядках: розбиваємо серії 4+ дерев підряд
	for y in range(GRID_SIZE):
		var run := 0
		for x in range(GRID_SIZE):
			if terrain_map.get(Vector2i(x, y), T_CLEAR) == T_TREE:
				run += 1
				if run >= 4:
					terrain_map[Vector2i(x, y)] = T_BUSHES
					run = 0
			else:
				run = 0
	# По стовпцях: те саме
	for x in range(GRID_SIZE):
		var run := 0
		for y in range(GRID_SIZE):
			if terrain_map.get(Vector2i(x, y), T_CLEAR) == T_TREE:
				run += 1
				if run >= 4:
					terrain_map[Vector2i(x, y)] = T_BUSHES
					run = 0
			else:
				run = 0


func _space_trees(terrain_map: Dictionary) -> void:
	const DIRS4 = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for _pass in range(2):
		var to_remove: Array[Vector2i] = []
		for pos in terrain_map.keys():
			if terrain_map[pos] != T_TREE:
				continue
			var adj := 0
			for dir in DIRS4:
				var nb: Vector2i = pos + dir
				if _in_bounds(nb) and terrain_map.get(nb, T_CLEAR) == T_TREE:
					adj += 1
			if adj >= 2:
				to_remove.append(pos)
			elif adj == 1 and _rng.randf() < 0.55:
				to_remove.append(pos)
		for pos in to_remove:
			terrain_map[pos] = T_BUSHES


func _break_tree_rings(terrain_map: Dictionary) -> void:
	const DIRS4 = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	# Flood-fill від усіх граничних не-TREE клітин → множина "зовні"
	var outside: Dictionary = {}
	var queue: Array[Vector2i] = []

	for x in range(GRID_SIZE):
		for y in [0, GRID_SIZE - 1]:
			var p := Vector2i(x, y)
			if terrain_map.get(p, T_CLEAR) != T_TREE and not outside.has(p):
				outside[p] = true
				queue.append(p)
	for y in range(1, GRID_SIZE - 1):
		for x in [0, GRID_SIZE - 1]:
			var p := Vector2i(x, y)
			if terrain_map.get(p, T_CLEAR) != T_TREE and not outside.has(p):
				outside[p] = true
				queue.append(p)

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir in DIRS4:
			var nb: Vector2i = cur + dir
			if not _in_bounds(nb) or outside.has(nb):
				continue
			if terrain_map.get(nb, T_CLEAR) == T_TREE:
				continue
			outside[nb] = true
			queue.append(nb)

	# Замкнені (не-TREE, не досягнуті) → проламуємо сусідні TREE → BUSHES
	for pos in terrain_map:
		if terrain_map[pos] == T_TREE or outside.has(pos):
			continue
		for dir in DIRS4:
			var nb: Vector2i = pos + dir
			if _in_bounds(nb) and terrain_map.get(nb, T_CLEAR) == T_TREE:
				terrain_map[nb] = T_BUSHES


func _compact_rock_clusters(terrain_map: Dictionary) -> void:
	const DIRS4 = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited: Dictionary = {}

	for start_pos in terrain_map.keys():
		if terrain_map[start_pos] != T_ROCKS or visited.has(start_pos):
			continue

		# BFS → зібрати кластер
		var cluster: Array[Vector2i] = []
		var q: Array[Vector2i] = [start_pos]
		visited[start_pos] = true
		while not q.is_empty():
			var cur: Vector2i = q.pop_front()
			cluster.append(cur)
			for dir in DIRS4:
				var nb: Vector2i = cur + dir
				if _in_bounds(nb) and not visited.has(nb) and terrain_map.get(nb, T_CLEAR) == T_ROCKS:
					visited[nb] = true
					q.append(nb)

		if cluster.size() < 4:
			continue

		# Centroid
		var sx := 0
		var sy := 0
		for c in cluster:
			sx += c.x
			sy += c.y
		var center := Vector2i(roundi(float(sx) / cluster.size()),
							   roundi(float(sy) / cluster.size()))

		# Очистити кластер
		for c in cluster:
			terrain_map[c] = T_CLEAR

		# Кандидати в радіусі від центру, відсортовані за відстанню²
		var r_int: int = ceili(sqrt(float(cluster.size()) / PI) * 1.1) + 1
		var candidates: Array = []
		for dx in range(-r_int, r_int + 1):
			for dy in range(-r_int, r_int + 1):
				var p := center + Vector2i(dx, dy)
				if _in_bounds(p) and not _is_spawn_zone(p):
					candidates.append([dx * dx + dy * dy, p])
		candidates.sort_custom(func(a, b): return a[0] < b[0])

		# Заповнити N найближчих клітин
		var placed := 0
		for cand in candidates:
			if placed >= cluster.size():
				break
			terrain_map[cand[1]] = T_ROCKS
			placed += 1


func _fix_steppe(terrain_map: Dictionary) -> void:
	_consolidate_water(terrain_map)
	_remove_isolated_swamp(terrain_map)


func _consolidate_water(terrain_map: Dictionary) -> void:
	const DIRS4 = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited: Dictionary = {}
	var components: Array = []

	for pos in terrain_map.keys():
		if terrain_map[pos] != T_WATER or visited.has(pos):
			continue
		var comp: Array[Vector2i] = []
		var q: Array[Vector2i] = [pos]
		visited[pos] = true
		while not q.is_empty():
			var cur: Vector2i = q.pop_front()
			comp.append(cur)
			for dir in DIRS4:
				var nb: Vector2i = cur + dir
				if _in_bounds(nb) and not visited.has(nb) and terrain_map.get(nb, T_CLEAR) == T_WATER:
					visited[nb] = true
					q.append(nb)
		components.append(comp)

	if components.size() <= 1:
		return

	# Залишаємо лише найбільший компонент
	var largest: Array = components[0]
	for comp in components:
		if comp.size() > largest.size():
			largest = comp

	for comp in components:
		if comp == largest:
			continue
		for p in comp:
			terrain_map[p] = T_CLEAR


func _remove_isolated_swamp(terrain_map: Dictionary) -> void:
	for pos in terrain_map.keys():
		if terrain_map[pos] == T_SWAMP:
			if _bfs_dist_to_terrain(terrain_map, pos, T_WATER) > 5:
				terrain_map[pos] = T_BUSHES
