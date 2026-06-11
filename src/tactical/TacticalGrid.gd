extends Node2D

const IsoMath = preload("res://src/core/IsoMath.gd")
const GRID_SIZE = 16

var hovered_map_pos: Vector2i = Vector2i(-1, -1)
var hovered_unit: Node2D = null
var current_path: Array[Vector2i] = []
var moving_target: Vector2i = Vector2i(-1, -1) # Кінцева точка під час активного руху

enum TerrainType { CLEAR, BUSHES, SWAMP, WATER, ROCKS, TREE }
var terrain_map: Dictionary[Vector2i, int] = {}

var astar: AStar2D = null
var _tile_layer: TileMapLayer = null
var _path_cost_label: RichTextLabel
var location_name: String = "Степ"
var location_color: Color = Color(0.88, 0.78, 0.38)

func _ready() -> void:
	var cm = get_node_or_null("/root/CampaignManager")
	var is_tutorial: bool = cm != null and cm.active_battle_config.get("is_tutorial", false)

	if is_tutorial:
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				terrain_map[Vector2i(x, y)] = TerrainType.CLEAR
		location_name = tr("MAP_OPEN_FIELD")
		location_color = Color(0.88, 0.78, 0.38)
	else:
		var wfc = WFCGenerator.new()
		var loc_type = randi() % WFCGenerator.LocationType.size()
		var generated = wfc.generate(-1, loc_type)
		if not generated.is_empty():
			terrain_map.clear()
			terrain_map.merge(generated)
			location_name = tr(WFCGenerator.LOCATION_NAMES[loc_type])
			location_color = WFCGenerator.LOCATION_COLORS[loc_type]
		else:
			push_warning("WFCGenerator: всі спроби провалились, fallback на hardcoded terrain")
			_generate_test_terrain()
	_init_astar()
	_setup_tile_layer()
	# Юніти не можуть стояти на непрохідних тайлах (після ініціалізації _tile_layer)
	for node in get_parent().get_children():
		if node is CombatUnit:
			var map_pos: Vector2i = _local_to_cell(node.position)
			if terrain_map.get(map_pos) == TerrainType.TREE:
				terrain_map[map_pos] = TerrainType.CLEAR
				_tile_layer.erase_cell(map_pos)
	queue_redraw()
	_setup_path_cost_label()

# --- Координатні хелпери (TileMapLayer як джерело істини) ---

func _cell_center(pos: Vector2i) -> Vector2:
	return _tile_layer.map_to_local(pos) + _tile_layer.position

func _cell_vertex(pos: Vector2i) -> Vector2:
	return _cell_center(pos) - Vector2(0.0, float(_tile_layer.tile_set.tile_size.y) * 0.5)

func _local_to_cell(local_pos: Vector2) -> Vector2i:
	return _tile_layer.local_to_map(local_pos - _tile_layer.position)

# --- UI ---

func _setup_path_cost_label() -> void:
	_path_cost_label = RichTextLabel.new()
	_path_cost_label.bbcode_enabled = true
	_path_cost_label.fit_content = true
	_path_cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_path_cost_label.scroll_active = false
	_path_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path_cost_label.add_theme_font_size_override("normal_font_size", 20)
	_path_cost_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_path_cost_label.add_theme_constant_override("shadow_offset_x", 0)
	_path_cost_label.add_theme_constant_override("shadow_offset_y", 0)
	_path_cost_label.add_theme_constant_override("shadow_outline_size", 4)
	_path_cost_label.visible = false
	var ui = get_parent().find_child("UI")
	if ui:
		ui.add_child(_path_cost_label)
	else:
		add_child(_path_cost_label)

func _update_path_cost_label() -> void:
	if not _path_cost_label:
		return
	if current_path.size() < 2:
		_path_cost_label.visible = false
		return

	var total_ap = get_real_ap_cost(current_path)
	var total_stam = 0
	for i in range(1, current_path.size()):
		match get_terrain_at(current_path[i]):
			TerrainType.BUSHES: total_stam += 6
			TerrainType.SWAMP:  total_stam += 15
			TerrainType.WATER:  total_stam += 15
			TerrainType.ROCKS:  total_stam += 8
			_: total_stam += 2

	_path_cost_label.text = "[color=#1A9933]%d %s[/color]  [color=#1A4DCC]%d 💧[/color]" % [total_ap, tr("UI_AP_SHORT"), total_stam]
	_path_cost_label.reset_size()

	var target_center = _cell_center(current_path.back())
	var screen_pos = get_viewport().get_canvas_transform() * to_global(target_center)
	var label_size = _path_cost_label.get_combined_minimum_size()
	_path_cost_label.position = screen_pos + Vector2(-label_size.x * 0.5, -label_size.y - 22)
	_path_cost_label.visible = true

func _init_astar() -> void:
	astar = AStar2D.new()
	var weights = get_terrain_weights()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var id = x + y * GRID_SIZE
			astar.add_point(id, Vector2(x, y))
			var pos = Vector2i(x, y)
			if weights.has(pos):
				astar.set_point_weight_scale(id, weights[pos])
	
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var id = x + y * GRID_SIZE
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var neighbour = Vector2i(x, y) + dir
				if neighbour.x >= 0 and neighbour.x < GRID_SIZE and neighbour.y >= 0 and neighbour.y < GRID_SIZE:
					var nid = neighbour.x + neighbour.y * GRID_SIZE
					astar.connect_points(id, nid)

func _refresh_astar_obstacles(start: Vector2i) -> void:
	if not astar: return
	var obstacles = get_all_obstacles()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var id = x + y * GRID_SIZE
			var pos = Vector2i(x, y)
			# Юніти та дерева тепер ЗАВЖДИ заблоковані для пошуку шляху (крім старту)
			var is_disabled = pos in obstacles and pos != start
			astar.set_point_disabled(id, is_disabled)

func _generate_test_terrain() -> void:
	# Базова земля
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			terrain_map[Vector2i(x, y)] = TerrainType.CLEAR
			
	# Болото в центрі
	for px in range(6, 9):
		for py in range(6, 9):
			terrain_map[Vector2i(px, py)] = TerrainType.SWAMP
			
	# Кущі (Зарості)
	terrain_map[Vector2i(3, 4)] = TerrainType.BUSHES
	terrain_map[Vector2i(3, 5)] = TerrainType.BUSHES
	terrain_map[Vector2i(8, 7)] = TerrainType.BUSHES
	terrain_map[Vector2i(8, 8)] = TerrainType.BUSHES
	terrain_map[Vector2i(13, 11)] = TerrainType.BUSHES
	
	# Каміння
	terrain_map[Vector2i(4, 2)] = TerrainType.ROCKS
	terrain_map[Vector2i(7, 10)] = TerrainType.ROCKS
	terrain_map[Vector2i(12, 3)] = TerrainType.ROCKS
	
	# Вода (Брід)
	for py in range(GRID_SIZE):
		if py < 5 or py > 10:
			terrain_map[Vector2i(10, py)] = TerrainType.WATER
			
	# Дерева (Окремі непрохідні перешкоди)
	terrain_map[Vector2i(4, 4)] = TerrainType.TREE
	terrain_map[Vector2i(7, 5)] = TerrainType.TREE
	terrain_map[Vector2i(11, 14)] = TerrainType.TREE

func get_terrain_at(m_pos: Vector2i) -> TerrainType:
	if terrain_map.has(m_pos):
		return terrain_map[m_pos] as TerrainType
	return TerrainType.CLEAR

func is_on_border(m_pos: Vector2i) -> bool:
	return m_pos.x == 0 or m_pos.y == 0 or m_pos.x == GRID_SIZE - 1 or m_pos.y == GRID_SIZE - 1

func _draw_retreat_zones() -> void:
	var dot_color = Color(0.2, 0.1, 0.0, 0.5)
	var radius = 3.0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var pos = Vector2i(x, y)
			if is_on_border(pos):
				var center = _cell_center(pos)
				draw_circle(center, radius, dot_color)

const TERRAIN_TEXTURES: Dictionary = {
	0: "res://assets/sprites/tiles/tile_grass.png",
	1: "res://assets/sprites/tiles/tile_bushes.png",
	2: "res://assets/sprites/tiles/tile_swamp.png",
	3: "res://assets/sprites/tiles/tile_water.png",
	4: "res://assets/sprites/tiles/tile_rocks.png",
	5: "res://assets/sprites/tiles/tile_trees.png",
}

func _setup_tile_layer() -> void:
	var terrain_colors: Dictionary = {
		TerrainType.CLEAR:  Color(0.55, 0.50, 0.25, 0.30),
		TerrainType.BUSHES: Color(0.10, 0.40, 0.10, 0.45),
		TerrainType.SWAMP:  Color(0.30, 0.25, 0.10, 0.55),
		TerrainType.WATER:  Color(0.10, 0.30, 0.60, 0.45),
		TerrainType.ROCKS:  Color(0.35, 0.28, 0.20, 0.75),
		TerrainType.TREE:   Color(0.20, 0.10, 0.05, 0.75),
	}

	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(160, 80)

	var terrain_source_ids: Dictionary = {}
	for terrain_type: int in terrain_colors:
		var tex_path: String = TERRAIN_TEXTURES.get(terrain_type, "")
		var atlas_texture: Texture2D
		if tex_path != "" and ResourceLoader.exists(tex_path):
			atlas_texture = load(tex_path)
		else:
			atlas_texture = _make_diamond_texture(terrain_colors[terrain_type])
		var src := TileSetAtlasSource.new()
		src.texture = atlas_texture
		src.texture_region_size = Vector2i(160, 80)
		src.create_tile(Vector2i(0, 0))
		terrain_source_ids[terrain_type] = ts.add_source(src)

	_tile_layer = TileMapLayer.new()
	_tile_layer.name = "TerrainTileLayer"
	_tile_layer.tile_set = ts
	_tile_layer.z_index = -1  # рендериться до решти гексів TacticalGrid
	# Зсув на half-tile-height: Godot CENTER клітинки (x,y) = map_to_local(pos),
	# а юніти стоять на center + (0,40). Зсув вирівнює візуальні тайли з юнітами.
	_tile_layer.position = Vector2(0, 40)
	add_child(_tile_layer)

	var has_grass := terrain_source_ids.has(TerrainType.CLEAR)
	for map_pos: Vector2i in terrain_map:
		var t: int = terrain_map[map_pos]
		if t == TerrainType.CLEAR:
			if has_grass:
				_tile_layer.set_cell(map_pos, terrain_source_ids[TerrainType.CLEAR], Vector2i(0, 0))
		elif terrain_source_ids.has(t):
			_tile_layer.set_cell(map_pos, terrain_source_ids[t], Vector2i(0, 0))

func _make_diamond_texture(color: Color) -> ImageTexture:
	const W := 160
	const H := 80
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for py: int in range(H):
		for px: int in range(W):
			var nx := (float(px) - W * 0.5) / (W * 0.5)
			var ny := (float(py) - H * 0.5) / (H * 0.5)
			if abs(nx) + abs(ny) <= 1.0:
				img.set_pixel(px, py, color)
	return ImageTexture.create_from_image(img)

func _draw() -> void:
	var grid_color = Color(0.25, 0.18, 0.10, 0.45)
	for x in range(GRID_SIZE + 1):
		draw_line(_cell_vertex(Vector2i(x, 0)), _cell_vertex(Vector2i(x, GRID_SIZE)), grid_color, 1.0)
	for y in range(GRID_SIZE + 1):
		draw_line(_cell_vertex(Vector2i(0, y)), _cell_vertex(Vector2i(GRID_SIZE, y)), grid_color, 1.0)
	
	_draw_retreat_zones()
	
	var bm = get_parent().find_child("BattleManager")
	var is_skill_mode = bm and bm.current_skill_id != ""
	var is_hover_skill = bm and bm.hover_skill_id != ""
	
	if is_hover_skill and bm.hover_skill_id == "rally":
		draw_rally_preview(bm)
	elif is_skill_mode:
		draw_attack_zone()
		if bm.current_skill_id == "shoot" and hovered_map_pos != Vector2i(-1, -1):
			_draw_shoot_line(bm)
	else:
		draw_movement_zone()
		draw_preview_path()
	
	# Малюємо точку призначення, якщо юніт зараз у дорозі
	if moving_target != Vector2i(-1, -1):
		_draw_destination_circle(moving_target)


func get_terrain_weights() -> Dictionary:
	var weights: Dictionary = {}
	for pos in terrain_map.keys():
		match terrain_map[pos]:
			TerrainType.BUSHES: weights[pos] = 1.5  # 3 AP / 2
			TerrainType.SWAMP:  weights[pos] = 2.0  # 4 AP / 2
			TerrainType.WATER:  weights[pos] = 2.0
			TerrainType.ROCKS:  weights[pos] = 1.5
	return weights

func get_real_ap_cost(path: Array[Vector2i]) -> int:
	var total = 0
	for i in range(1, path.size()):
		var t = get_terrain_at(path[i])
		match t:
			TerrainType.BUSHES: total += 3
			TerrainType.SWAMP:  total += 4
			TerrainType.WATER:  total += 4
			TerrainType.ROCKS:  total += 3
			_: total += 2
	return total

var _reachable_cells: Array[Vector2i] = []
var _last_state_key: String = ""

func update_reachable_cells() -> void:
	var bm = get_parent().find_child("BattleManager")
	if not bm or not bm.active_unit or bm.active_unit.is_moving:
		_reachable_cells = []
		_last_state_key = ""
		return
	
	var unit = bm.active_unit
	var u_map = _local_to_cell(unit.position)
	var state_key = "%s_%d_%d_%d" % [unit.name, u_map.x, u_map.y, unit.ap]
	
	if _last_state_key == state_key: return
	_last_state_key = state_key
	
	_refresh_astar_obstacles(u_map) # Оновлюємо перешкоди (юнітів)
	
	_reachable_cells = []
	var available_ap = unit.ap
	if available_ap < 2: return
	
	var max_dist = int(available_ap / 2.0) + 2
	
	for x in range(u_map.x - max_dist, u_map.x + max_dist + 1):
		for y in range(u_map.y - max_dist, u_map.y + max_dist + 1):
			if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
				var target = Vector2i(x, y)
				if target == u_map: continue
				var path = IsoMath.get_astar_path_from_instance(astar, u_map, target, GRID_SIZE)
				if path.size() > 1:
					var real_cost = get_real_ap_cost(path)
					if real_cost <= available_ap:
						_reachable_cells.append(target)

func draw_movement_zone() -> void:
	if _reachable_cells.is_empty(): return
	var highlight_color = Color(1, 1, 0, 0.12)

	# 1. Заливка досяжних клітинок
	for cell in _reachable_cells:
		draw_cell_highlight(cell.x, cell.y, highlight_color)

	# 2. Зона атаки ворогів (ZoC)
	var bm = get_parent().find_child("BattleManager")
	if not bm or not bm.active_unit: return
	var zoc_tiles: Array[Vector2i] = get_enemy_zoc_tiles(bm.active_unit.team)
	var obstacles: Array[Vector2i] = get_all_obstacles()
	for z in zoc_tiles:
		if z.x >= 0 and z.x < GRID_SIZE and z.y >= 0 and z.y < GRID_SIZE and not z in obstacles:
			var is_near_hovered_enemy = false
			if hovered_unit is CombatUnit and hovered_unit.team != bm.active_unit.team:
				var e_map = _local_to_cell(hovered_unit.position)
				if IsoMath.get_dist_4(z, e_map) == 1:
					is_near_hovered_enemy = true

			var is_on_path = z in current_path
			var is_hovered_destination = (z == hovered_map_pos)
			var is_reachable = z in _reachable_cells

			if is_near_hovered_enemy:
				draw_cell_highlight(z.x, z.y, Color(1, 0, 0, 0.15))
			elif is_reachable and (is_on_path or is_hovered_destination):
				draw_cell_highlight(z.x, z.y, Color(1, 0, 0, 0.15))

	# 3. Контур зони руху
	var unit_cell := _local_to_cell(bm.active_unit.position)
	_draw_movement_zone_outline(unit_cell)

func _draw_movement_zone_outline(unit_cell: Vector2i) -> void:
	if _reachable_cells.is_empty(): return
	var outline_color := Color(1.0, 0.75, 0.0, 0.85)
	const W := 80.0
	const H := 40.0
	# Для кожного з 4 напрямків: зміщення двох вершин спільного ребра
	var edges: Array = [
		[Vector2i( 1,  0), Vector2( W, 0.0), Vector2(0.0,  H)],  # bottom-right
		[Vector2i(-1,  0), Vector2(-W, 0.0), Vector2(0.0, -H)],  # top-left
		[Vector2i( 0,  1), Vector2(0.0,  H), Vector2(-W, 0.0)],  # bottom-left
		[Vector2i( 0, -1), Vector2(0.0, -H), Vector2( W, 0.0)],  # top-right
	]
	for cell: Vector2i in _reachable_cells:
		var center := _cell_center(cell)
		for edge: Array in edges:
			var neighbor: Vector2i = cell + edge[0]
			if neighbor not in _reachable_cells and neighbor != unit_cell:
				draw_line(center + edge[1], center + edge[2], outline_color, 1.5)

func draw_attack_zone() -> void:
	var bm = get_parent().find_child("BattleManager")
	if not bm or not bm.active_unit or bm.active_unit.is_moving: return
	
	# Отримуємо вибрану навичку
	if bm.current_skill_id == "": return
	
	var skill = get_current_skill(bm)
	if not skill or bm.active_unit.ap < skill.ap or bm.active_unit.stamina < skill.stamina: return
	
	if skill.range == 0: return # Спеціальна навичка на себе (Riposte)

	var u_map = _local_to_cell(bm.active_unit.position)

	# Малюємо радіус навички (Battle Brothers Style)
	for x in range(u_map.x - skill.range, u_map.x + skill.range + 1):
		for y in range(u_map.y - skill.range, u_map.y + skill.range + 1):
			var target = Vector2i(x, y)
			if target.x >= 0 and target.x < GRID_SIZE and target.y >= 0 and target.y < GRID_SIZE:
				var dist = IsoMath.get_dist_4(u_map, target)
				if dist > 0 and dist <= skill.range:
					# Додаткове обмеження для списа: тільки прямі лінії (dx=0 або dy=0)
					if skill.id == "thrust" and (target.x != u_map.x and target.y != u_map.y):
						continue
						
					var enemy = get_unit_at(target)
					if enemy and enemy.team != bm.active_unit.team:
						draw_cell_highlight(target.x, target.y, Color(1, 0, 0, 0.4)) # Ворог
					else:
						# Вся зона тепер червона (напівпрозора)
						draw_cell_highlight(target.x, target.y, Color(1, 0, 0, 0.15))

func check_line_of_sight(start_map: Vector2i, end_map: Vector2i) -> Dictionary:
	var path = IsoMath.get_line_of_sight_path(start_map, end_map)
	var is_blocked = false
	var has_friendly_fire_risk = false
	var bush_count = 0
	var units_in_way = []
	
	for i in range(1, path.size() - 1): # Skip start and end
		var p = path[i]
		var t = get_terrain_at(p)
		if t == TerrainType.TREE or t == TerrainType.ROCKS:
			is_blocked = true
			break
		if t == TerrainType.BUSHES:
			bush_count += 1
			
		var unit = get_unit_at(p)
		if unit and not unit.get("is_dead"):
			# Check if adjacent to start (shooting over shoulder is allowed)
			if IsoMath.get_dist_4(start_map, p) == 1:
				continue
			has_friendly_fire_risk = true
			units_in_way.append(unit)
			
	return {
		"path": path,
		"is_blocked": is_blocked,
		"has_friendly_fire_risk": has_friendly_fire_risk,
		"bush_count": bush_count,
		"units_in_way": units_in_way
	}

func _draw_shoot_line(bm: Node2D) -> void:
	if hovered_map_pos.x < 0 or hovered_map_pos.x >= GRID_SIZE or hovered_map_pos.y < 0 or hovered_map_pos.y >= GRID_SIZE:
		return
	var u_map = _local_to_cell(bm.active_unit.position)
	var skill = get_current_skill(bm)
	if not skill or IsoMath.get_dist_4(u_map, hovered_map_pos) > skill.range: return

	var los = check_line_of_sight(u_map, hovered_map_pos)
	var color = Color(0, 1, 0, 0.8) # Green
	if los["is_blocked"]:
		color = Color(1, 0, 0, 0.8) # Red
	elif los["has_friendly_fire_risk"]:
		color = Color(1, 0.5, 0, 0.8) # Orange

	var start_pos = _cell_center(u_map)
	var end_pos = _cell_center(hovered_map_pos)

	if los["is_blocked"]:
		var first_blocked_map = hovered_map_pos
		for p in los["path"]:
			var t = get_terrain_at(p)
			if t == TerrainType.TREE or t == TerrainType.ROCKS:
				first_blocked_map = p
				break
		end_pos = _cell_center(first_blocked_map)
		
	draw_line(start_pos, end_pos, color, 3.0)
		
	# Draw X if blocked
	if los["is_blocked"]:
		draw_line(end_pos - Vector2(10, 10), end_pos + Vector2(10, 10), Color.RED, 3.0)
		draw_line(end_pos - Vector2(-10, 10), end_pos + Vector2(-10, 10), Color.RED, 3.0)

func get_current_skill(bm: Node2D) -> Dictionary:
	for s in bm.active_unit.available_skills:
		if s.id == bm.current_skill_id:
			return s
	return {}

func get_unit_at(m_pos: Vector2i) -> Node2D:
	var corpse = null
	for child in get_parent().get_children():
		if child is CombatUnit:
			if _local_to_cell(child.position) == m_pos:
				if not child.get("is_dead"):
					return child # Пріоритет живому
				else:
					corpse = child
	return corpse # Якщо живих немає, повертаємо тіло (для інфо)

func _draw_destination_circle(m_pos: Vector2i) -> void:
	var target_center = _cell_center(m_pos)
	var path_color = Color(0.15, 0.40, 0.85)

	# Малюємо маленьке коло в ізометрії (еліпс 2:1)
	var points_iso = PackedVector2Array()
	var radius = 12.0
	for i in range(16):
		var angle = (float(i) / 16.0) * TAU
		points_iso.append(target_center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.5))
	draw_colored_polygon(points_iso, path_color)

func draw_preview_path() -> void:
	if current_path.size() < 2: return
	
	var target_cell = current_path.back()
	_draw_destination_circle(target_cell)
	
	var points: PackedVector2Array = []
	for p in current_path: points.append(_cell_center(p))
	if points.size() > 1: draw_polyline(points, Color(0.15, 0.40, 0.85), 2.0)


func draw_rally_preview(bm: Node2D) -> void:
	var unit = bm.active_unit
	if not unit: return
	
	# Перевірка чи вистачає ресурсів
	var rally_cost = {"ap": 5, "stamina": 25}
	if unit.ap < rally_cost.ap or unit.stamina < rally_cost.stamina:
		return
		
	var u_map = _local_to_cell(unit.position)
	var radius = 4
	
	for x in range(u_map.x - radius, u_map.x + radius + 1):
		for y in range(u_map.y - radius, u_map.y + radius + 1):
			if IsoMath.get_dist_4(u_map, Vector2i(x,y)) <= radius:
				var target = Vector2i(x, y)
				if target.x >= 0 and target.x < GRID_SIZE and target.y >= 0 and target.y < GRID_SIZE:
					draw_cell_highlight(target.x, target.y, Color(0, 0.8, 1, 0.15)) # Блакитна зона згуртування

func draw_cell_highlight(mx: int, my: int, color: Color) -> void:
	var center = _cell_center(Vector2i(mx, my))
	var w = 79.0
	var h = 39.5
	var points = PackedVector2Array([
		center + Vector2(0, -h), center + Vector2(w, 0),
		center + Vector2(0, h), center + Vector2(-w, 0)
	])
	draw_colored_polygon(points, color)

func _process(_delta: float) -> void:
	# Блокування взаємодії з полем, якщо відкрито вікно персонажа АБО миша над UI
	var ui = get_parent().get_node_or_null("UI")
	var is_sheet_open = ui and ui.has_node("CharacterSheet") and ui.get_node("CharacterSheet").visible
	var is_over_ui = get_viewport().gui_get_hovered_control() != null

	if is_sheet_open or is_over_ui:
		var bm = get_parent().find_child("BattleManager")
		if hovered_unit != null:
			if bm: bm.update_hover_info(null)
			hovered_unit = null

		# ПРИХОВУЄМО підказки тайлів при наведенні на UI
		if bm: bm.update_hover_terrain(-1)

		current_path = []
		queue_redraw()
		if _path_cost_label: _path_cost_label.visible = false
		return

	_update_path_cost_label()
	update_reachable_cells()
	
	var m_pos := _tile_layer.local_to_map(_tile_layer.to_local(get_global_mouse_position()))
	if m_pos != hovered_map_pos:
		hovered_map_pos = m_pos
		update_path_preview()
		
		# Hover logic (Battle Brothers Intel)
		var target = get_unit_at(m_pos)
		var bm = get_parent().find_child("BattleManager")
		if target != hovered_unit:
			hovered_unit = target
			if bm:
				bm.update_hover_info(hovered_unit)
				if target:
					bm.update_hover_terrain(-1)

		# Підказка тайлу місцевості (якщо немає юніта)
		if not target and bm:
			var t = get_terrain_at(m_pos)
			if t != TerrainType.CLEAR:
				bm.update_hover_terrain(t)
			else:
				bm.update_hover_terrain(-1)
		
		queue_redraw()

func get_all_obstacles() -> Array[Vector2i]:
	var obs: Array[Vector2i] = []
	for child in get_parent().get_children():
		if child is CombatUnit and not child.is_dead:
			var pos = _local_to_cell(child.position)
			obs.append(pos)
			
			# Якщо юніт у дорозі - він також блокує свою ТІЛЬКИ ЦІЛЬОВУ клітинку
			if child.get("is_moving") and child.has_method("_get_move_target"):
				var target = child.call("_get_move_target")
				if target != Vector2i(-1, -1) and not target in obs:
					obs.append(target)
	
	if terrain_map:
		for pos in terrain_map.keys():
			if terrain_map[pos] == TerrainType.TREE:
				if not pos in obs:
					obs.append(pos)
					
	return obs

func get_enemy_zoc_tiles(unit_team: int) -> Array[Vector2i]:
	var zoc: Array[Vector2i] = []
	for child in get_parent().get_children():
		if child is CombatUnit and child.team != unit_team and not child.is_dead:
			var pos := _local_to_cell(child.position)
			for dir: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var adj: Vector2i = pos + dir
				if adj.x >= 0 and adj.x < GRID_SIZE and adj.y >= 0 and adj.y < GRID_SIZE:
					if not adj in zoc:
						zoc.append(adj)
	return zoc

func update_path_preview() -> void:
	var bm = get_parent().find_child("BattleManager")
	if not bm or not bm.active_unit or bm.active_unit.is_moving:
		current_path = []
		return

	if hovered_map_pos.x >= 0 and hovered_map_pos.x < GRID_SIZE and hovered_map_pos.y >= 0 and hovered_map_pos.y < GRID_SIZE:
		if bm.active_unit.team == 0 and bm.current_skill_id == "":
			var unit_map := _local_to_cell(bm.active_unit.position)
			_refresh_astar_obstacles(unit_map)
			var full_path := IsoMath.get_astar_path_from_instance(astar, unit_map, hovered_map_pos, GRID_SIZE)
			# Відсікаємо шлях на першій клітинці поза зоною руху
			current_path = []
			for i in range(full_path.size()):
				if i == 0 or full_path[i] in _reachable_cells:
					current_path.append(full_path[i])
				else:
					break
		else:
			current_path = []
	else:
		current_path = []

func _unhandled_input(event: InputEvent) -> void:
	# --- ОБРОБКА ПРАВОЇ КНОПКИ (Скасування навички) ---
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var bm_rmb = get_parent().find_child("BattleManager")
		if bm_rmb and bm_rmb.active_unit and bm_rmb.current_skill_id != "":
			bm_rmb._on_skill_selected(bm_rmb.current_skill_id)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var bm = get_parent().find_child("BattleManager")
		if not bm or not bm.active_unit: return

		# Ігноруємо ввід, якщо зараз хід ШІ (команда 1)
		if bm.active_unit.team != 0: return

		var skill = get_current_skill(bm)
		var m_pos := _tile_layer.local_to_map(_tile_layer.to_local(get_global_mouse_position()))
		var enemy = get_unit_at(m_pos)

		# Взаємодія з навичками (Скілами)
		if skill:
			var u_map := _local_to_cell(bm.active_unit.position)

			if skill.id == "rally":
				if m_pos == u_map:
					if bm.active_unit.ap >= skill.ap:
						bm.active_unit.use_rally(skill)
						bm.current_skill_id = ""
						if bm.unit_panel: bm.unit_panel.update_unit_info(bm.active_unit)
						return
				else:
					bm._on_skill_selected(bm.current_skill_id)
					return

			elif enemy and enemy.team != bm.active_unit.team:
				var dist := IsoMath.get_dist_4(u_map, m_pos)
				if dist <= skill.range and bm.active_unit.ap >= skill.ap:
					# Спеціальна перевірка для списа (thrust) — заборона діагоналей
					if skill.id == "thrust" and (m_pos.x != u_map.x and m_pos.y != u_map.y):
						return

					if skill.id == "shoot":
						if "is_loaded" in bm.active_unit and not bm.active_unit.is_loaded:
							return
						var los = check_line_of_sight(u_map, m_pos)
						if los["is_blocked"]:
							return
						bm.active_unit.execute_shoot(enemy, skill)
					else:
						bm.active_unit.attack(enemy, skill)
					bm.current_skill_id = ""
					if bm.unit_panel: bm.unit_panel.update_unit_info(bm.active_unit)
					return
			else:
				# Клік повз ворога при активній навичці — не скасовуємо,
				# щоб випадковий промах по юніту не скидав режим атаки.
				return

		if current_path.size() > 1:
			var target_pos: Vector2i = current_path.back()

			# ФІНАЛЬНА ВАЛІДАЦІЯ: Перевіряємо чи ціль все ще вільна в момент кліку
			var obstacles := get_all_obstacles()
			if target_pos in obstacles:
				current_path = []
				return
			if is_on_border(target_pos) and bm.active_unit.team == 0:
				bm.request_retreat_confirmation(current_path)
				return

			var zoc_tiles: Array[Vector2i] = get_enemy_zoc_tiles(bm.active_unit.team)
			var truncated_path: Array[Vector2i] = [current_path[0]]
			for i in range(1, current_path.size()):
				truncated_path.append(current_path[i])
				if current_path[i] in zoc_tiles:
					break

			var cost := get_real_ap_cost(truncated_path)

			# Запам'ятовуємо ціль для постійного відображення під час руху
			moving_target = truncated_path.back()

			var active_unit: CombatUnit = bm.active_unit as CombatUnit
			active_unit.move_finished.connect(func():
				moving_target = Vector2i(-1, -1)
				update_path_preview()
				queue_redraw()
			, CONNECT_ONE_SHOT)

			active_unit.move_along_path(truncated_path, cost)
			current_path = []
			queue_redraw()
