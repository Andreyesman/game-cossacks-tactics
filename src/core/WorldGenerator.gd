extends RefCounted

# Карта 3000×2000px, гравець стартує близько до центру
const MAP_W := 3000.0
const MAP_H := 2000.0
const MIN_LOC_DIST := 180.0
const MIN_PARTY_DIST := 100.0
const MIN_LAKE_RIVER_DIST := 150.0

# Шляхи до UnitData ресурсів
const U := "res://src/resources/units/"
const BANDIT      := U + "Bandit.tres"
const BANDIT_LEAD := U + "BanditLeader.tres"
const TATAR       := U + "Tatar.tres"
const TATAR_HEAVY := U + "TatarHeavy.tres"
const JANISSARY   := U + "Janissary.tres"
const REIESTR     := U + "Reiestr.tres"

# ── Головний метод ────────────────────────────────────────────────────────────

func generate(state: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	_gen_biomes(state)
	_gen_water(state, rng)
	_gen_geography(state, rng)
	_gen_locations(state, rng)
	_gen_roads(state)
	_gen_parties(state, rng)
	_gen_influence_zones(state)

# ── Процедурна Географія ──────────────────────────────────────────────────────

func _gen_geography(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var forest_patches: Array = []
	var hill_patches: Array = []
	var swamp_patches: Array = []
	var kurgans: Array = []
	var ravines: Array = []

	# 1. Ліси — органічні нерівні blob-полігони
	# Густіші на заході, рідшають на сході
	var num_forests := rng.randi_range(16, 24)
	for _i in range(num_forests):
		var cx := 0.0
		var cy := rng.randf_range(100.0, MAP_H - 100.0)
		var r := rng.randf_range(120.0, 260.0)
		var roll := rng.randf()
		if roll < 0.60:
			cx = rng.randf_range(100.0, MAP_W * 0.38)
		elif roll < 0.90:
			cx = rng.randf_range(MAP_W * 0.38, MAP_W * 0.76)
		else:
			cx = rng.randf_range(MAP_W * 0.76, MAP_W - 100.0)
		# Зовнішній контур: 22 вершини, roughness 0.38 → зазубрені краї
		var outer_verts := _blob_poly(rng, cx, cy, r, 22, 0.38, 1.0, 1.0)
		# Внутрішнє ядро: трохи менший blob
		var inner_verts := _blob_poly(rng, cx, cy, r * 0.62, 18, 0.30, 1.0, 1.0)
		forest_patches.append({
			"x": cx, "y": cy, "r": r,
			"outer": outer_verts, "inner": inner_verts
		})

	# 2. Пагорби — витягнуті хребти під кутом
	var num_hills := rng.randi_range(8, 14)
	for _i in range(num_hills):
		var cx := rng.randf_range(100.0, MAP_W - 100.0)
		var cy := rng.randf_range(100.0, MAP_H - 100.0)
		var r := rng.randf_range(100.0, 200.0)
		# Хребет: витягнутий у 2-3x по осі X відносно Y, повернутий на довільний кут
		var ridge_angle := rng.randf_range(0.0, TAU)
		var rx := r * rng.randf_range(1.8, 2.8)  # довжина хребта
		var ry := r * rng.randf_range(0.4, 0.7)  # ширина хребта
		var verts := _ridge_poly(rng, cx, cy, rx, ry, ridge_angle, 16, 0.22)
		hill_patches.append({
			"x": cx, "y": cy, "r": r,
			"verts": verts
		})

	# 3. Болота — аморфні, нерівні, biased до води
	var num_swamps := rng.randi_range(6, 10)
	for _i in range(num_swamps):
		var cx := 0.0
		var cy := 0.0
		var r := rng.randf_range(80.0, 160.0)
		var ok := false
		if state.has("rivers") and not state["rivers"].is_empty():
			var river = state["rivers"][rng.randi() % state["rivers"].size()]
			var pt = river[rng.randi() % river.size()]
			cx = pt["x"] + rng.randf_range(-120.0, 120.0)
			cy = pt["y"] + rng.randf_range(-120.0, 120.0)
			ok = true
		elif state.has("lakes") and not state["lakes"].is_empty():
			var lake = state["lakes"][rng.randi() % state["lakes"].size()]
			var pt = lake[rng.randi() % lake.size()]
			cx = pt["x"] + rng.randf_range(-100.0, 100.0)
			cy = pt["y"] + rng.randf_range(-100.0, 100.0)
			ok = true
		if not ok:
			cx = rng.randf_range(150.0, MAP_W - 150.0)
			cy = rng.randf_range(150.0, MAP_H - 150.0)
		# Болото: висока нерівність (roughness 0.48), асиметричне масштабування
		var sx := rng.randf_range(0.8, 1.4)
		var sy := rng.randf_range(0.6, 1.2)
		var verts := _blob_poly(rng, cx, cy, r, 16, 0.48, sx, sy)
		swamp_patches.append({
			"x": cx, "y": cy, "r": r,
			"verts": verts
		})

	# 4. Кургани — точки (насправді невеликі горбики, залишаємо як маркери)
	var num_kurgans := rng.randi_range(4, 7)
	for _i in range(num_kurgans):
		var cx := rng.randf_range(150.0, MAP_W - 150.0)
		var cy := rng.randf_range(150.0, MAP_H - 150.0)
		kurgans.append({"x": cx, "y": cy})

	# 5. Яри — природній меандр: 10+ точок з перпендикулярним відхиленням
	var num_ravines := rng.randi_range(3, 5)
	for _i in range(num_ravines):
		var rsx := rng.randf_range(200.0, MAP_W - 200.0)
		var rsy := rng.randf_range(200.0, MAP_H - 200.0)
		var rangle := rng.randf_range(0.0, PI)
		var rlength := rng.randf_range(200.0, 380.0)
		var num_seg := 10
		var rpts := []
		var perp_x := cos(rangle + PI * 0.5)
		var perp_y := sin(rangle + PI * 0.5)
		for j in range(num_seg + 1):
			var t := float(j) / float(num_seg)
			var bx := rsx + cos(rangle) * rlength * t
			var by := rsy + sin(rangle) * rlength * t
			var jitter := rng.randf_range(-35.0, 35.0) * sin(t * PI)
			rpts.append({
				"x": bx + perp_x * jitter,
				"y": by + perp_y * jitter
			})
		ravines.append(rpts)

	state["forest_patches"] = forest_patches
	state["hill_patches"] = hill_patches
	state["swamp_patches"] = swamp_patches
	state["kurgans"] = kurgans
	state["ravines"] = ravines

# ── Зони впливу фракцій (невидимі, логічні) ──────────────────────────────────

# Будує список anchor-точок {pos, faction} — по одній на кожне місто.
# WorldMap / CampaignManager можуть викликати get_faction_at(pos) через Voronoi-lookup.
func _gen_influence_zones(state: Dictionary) -> void:
	var anchors: Array = []
	var locations: Array = state.get("locations", [])
	for loc in locations:
		if loc.get("type", "") == "town":
			anchors.append({
				"faction": loc.get("faction", "none"),
				"pos": loc["pos"]
			})
	state["influence_anchors"] = anchors

# ── Біоми (3 фіксованих зони) ─────────────────────────────────────────────────

func _gen_biomes(state: Dictionary) -> void:
	state["biomes"] = [
		{
			"id": "forest",
			"name": tr("Ліси"),
			"rect": {"x": 0.0, "y": 0.0, "w": MAP_W * 0.38, "h": MAP_H},
			"color": {"r": 0.13, "g": 0.22, "b": 0.10, "a": 1.0},
			"faction": "none"
		},
		{
			"id": "steppe",
			"name": tr("Дике Поле"),
			"rect": {"x": MAP_W * 0.38, "y": 0.0, "w": MAP_W * 0.38, "h": MAP_H},
			"color": {"r": 0.32, "g": 0.26, "b": 0.10, "a": 1.0},
			"faction": "orda"
		},
		{
			"id": "border",
			"name": tr("Кордон"),
			"rect": {"x": MAP_W * 0.76, "y": 0.0, "w": MAP_W * 0.24, "h": MAP_H},
			"color": {"r": 0.15, "g": 0.18, "b": 0.22, "a": 1.0},
			"faction": "crown"
		}
	]

# ── Ріки та озера ─────────────────────────────────────────────────────────────

func _gen_water(state: Dictionary, rng: RandomNumberGenerator) -> void:
	# Одна ріка — вертикально через ліс/степ з хвилястим відхиленням
	var river_pts: Array = []
	var rx := MAP_W * 0.35 + rng.randf_range(-40.0, 40.0)
	for i in range(8):
		var t := float(i) / 7.0
		var pt = {
			"x": rx + rng.randf_range(-35.0, 35.0),
			"y": t * MAP_H
		}
		river_pts.append(pt)
	state["rivers"] = [river_pts]

	# Два озера (мінімум MIN_LAKE_RIVER_DIST від будь-якої точки ріки)
	var lakes: Array = []
	for _i in range(2):
		var cx := 0.0
		var cy := 0.0
		for _attempt in range(20):
			cx = rng.randf_range(200.0, MAP_W - 200.0)
			cy = rng.randf_range(150.0, MAP_H - 150.0)
			var ok := true
			for river in state["rivers"]:
				for pt in river:
					if Vector2(cx, cy).distance_to(Vector2(pt["x"], pt["y"])) < MIN_LAKE_RIVER_DIST:
						ok = false
						break
				if not ok:
					break
			if ok:
				break
		var lake_pts: Array = []
		var radius := rng.randf_range(40.0, 80.0)
		for j in range(8):
			var angle := j * TAU / 8.0
			lake_pts.append({
				"x": cx + cos(angle) * radius * rng.randf_range(0.7, 1.3),
				"y": cy + sin(angle) * radius * rng.randf_range(0.7, 1.3)
			})
		lakes.append(lake_pts)
	state["lakes"] = lakes

# ── Локації ───────────────────────────────────────────────────────────────────

func _gen_locations(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var templates := [
		# === ЛІС (Біом Cossacks / Sich) ===
		# Міста
		{"type": "town",          "faction": "sich",  "biome": "forest",
		 "garrison": [REIESTR, REIESTR, REIESTR],
		 "reward": 245, "name": tr("Чигирин"), "connected_by_road": true},
		{"type": "town",          "faction": "sich",  "biome": "forest",
		 "garrison": [REIESTR, REIESTR, BANDIT_LEAD],
		 "reward": 225, "name": tr("Київ"), "connected_by_road": true},
		# Села
		{"type": "village",       "faction": "sich",  "biome": "forest",
		 "garrison": [REIESTR, REIESTR],
		 "reward": 120, "name": tr("Диканька"), "connected_by_road": true},
		{"type": "village",       "faction": "sich",  "biome": "forest",
		 "garrison": [REIESTR, BANDIT],
		 "reward": 105, "name": tr("Суботів"), "connected_by_road": true},
		{"type": "village",       "faction": "sich",  "biome": "forest",
		 "garrison": [BANDIT, BANDIT],
		 "reward": 100, "name": tr("Полтавка"), "connected_by_road": true},
		# Бандити
		{"type": "bandit_camp",   "faction": "none",  "biome": "forest",
		 "garrison": [BANDIT, BANDIT, BANDIT, BANDIT_LEAD],
		 "reward": 135, "name": tr("LOC_TYPE_BANDIT_CAMP"), "connected_by_road": true},
		# Приховані точки інтересу (без доріг)
		{"type": "ruins",         "faction": "none",  "biome": "forest",
		 "garrison": [BANDIT, BANDIT, BANDIT],
		 "reward": 120, "name": tr("LOC_ABANDONED_RUINS"), "connected_by_road": false},
		{"type": "poi",           "faction": "none",  "biome": "forest",
		 "garrison": [BANDIT, BANDIT_LEAD],
		 "reward": 115, "name": tr("LOC_ABANDONED_APIARY"), "connected_by_road": false},
		{"type": "poi",           "faction": "none",  "biome": "forest",
		 "garrison": [BANDIT, BANDIT, BANDIT_LEAD],
		 "reward": 130, "name": tr("LOC_BANDIT_CAVE"), "connected_by_road": false},

		# === СТЕП (Дике Поле, Orda) ===
		# Міста
		{"type": "town",          "faction": "orda",  "biome": "steppe",
		 "garrison": [TATAR, TATAR, TATAR_HEAVY, TATAR_HEAVY],
		 "reward": 280, "name": tr("Бахчисарай"), "connected_by_road": true},
		# Села
		{"type": "village",       "faction": "sich",  "biome": "steppe",
		 "garrison": [REIESTR, TATAR],
		 "reward": 130, "name": tr("Опішня"), "connected_by_road": true},
		{"type": "village",       "faction": "orda",  "biome": "steppe",
		 "garrison": [TATAR, TATAR],
		 "reward": 115, "name": tr("Кам'яний Брід"), "connected_by_road": true},
		# Татарські табори
		{"type": "tatar_camp",    "faction": "orda",  "biome": "steppe",
		 "garrison": [TATAR, TATAR, TATAR_HEAVY],
		 "reward": 150, "name": tr("LOC_TYPE_TATAR_CAMP"), "connected_by_road": true},
		{"type": "tatar_camp",    "faction": "orda",  "biome": "steppe",
		 "garrison": [TATAR, TATAR, TATAR, TATAR_HEAVY],
		 "reward": 190, "name": tr("LOC_MURZA_CAMP"), "connected_by_road": true},
		# Приховані точки інтересу (без доріг)
		{"type": "poi",           "faction": "none",  "biome": "steppe",
		 "garrison": [TATAR, TATAR],
		 "reward": 120, "name": tr("LOC_SCYTHIAN_TOMB"), "connected_by_road": false},
		{"type": "poi",           "faction": "none",  "biome": "steppe",
		 "garrison": [REIESTR, REIESTR],
		 "reward": 135, "name": tr("LOC_COSSACK_CEMETERY"), "connected_by_road": false},
		{"type": "poi",           "faction": "orda",  "biome": "steppe",
		 "garrison": [TATAR, TATAR_HEAVY],
		 "reward": 135, "name": tr("LOC_TATAR_PATROL"), "connected_by_road": false},

		# === КОРДОН (Crown / Річ Посполита) ===
		# Міста
		{"type": "town",          "faction": "crown", "biome": "border",
		 "garrison": [REIESTR, REIESTR, JANISSARY, JANISSARY],
		 "reward": 315, "name": tr("Кам'янець"), "connected_by_road": true},
		{"type": "town",          "faction": "sich",  "biome": "border",
		 "garrison": [REIESTR, REIESTR, REIESTR, REIESTR],
		 "reward": 265, "name": tr("Кодак"), "connected_by_road": true},
		# Села
		{"type": "village",       "faction": "crown", "biome": "border",
		 "garrison": [REIESTR, REIESTR],
		 "reward": 120, "name": tr("Ямпіль"), "connected_by_road": true},
		{"type": "village",       "faction": "crown", "biome": "border",
		 "garrison": [JANISSARY, REIESTR],
		 "reward": 135, "name": tr("Жванець"), "connected_by_road": true},
		# Застави
		{"type": "crown_outpost", "faction": "crown", "biome": "border",
		 "garrison": [REIESTR, REIESTR, JANISSARY],
		 "reward": 165, "name": tr("LOC_TYPE_CROWN_OUTPOST"), "connected_by_road": true},
		{"type": "crown_outpost", "faction": "crown", "biome": "border",
		 "garrison": [JANISSARY, JANISSARY, REIESTR, REIESTR],
		 "reward": 225, "name": tr("LOC_FORTRESS"), "connected_by_road": true},
		# Приховані точки інтересу (без доріг)
		{"type": "poi",           "faction": "none",  "biome": "border",
		 "garrison": [BANDIT, BANDIT, JANISSARY],
		 "reward": 150, "name": tr("LOC_RUINED_CHURCH"), "connected_by_road": false},
		{"type": "poi",           "faction": "none",  "biome": "border",
		 "garrison": [TATAR, REIESTR],
		 "reward": 135, "name": tr("LOC_PAGAN_RAVINE"), "connected_by_road": false}
	]

	var placed_positions: Array[Vector2] = []
	var biome_bounds := {
		"forest": Rect2(0, 0, MAP_W * 0.38, MAP_H),
		"steppe": Rect2(MAP_W * 0.38, 0, MAP_W * 0.38, MAP_H),
		"border": Rect2(MAP_W * 0.76, 0, MAP_W * 0.24, MAP_H)
	}

	var locations: Array = []
	var loc_id := 0

	for tmpl in templates:
		var bounds: Rect2 = biome_bounds[tmpl["biome"]]
		var pos := _find_free_pos(rng, bounds, placed_positions, MIN_LOC_DIST, 60.0)
		if pos == Vector2.ZERO:
			continue
		placed_positions.append(pos)
		locations.append({
			"id": "loc_%d" % loc_id,
			"type": tmpl["type"],
			"faction": tmpl["faction"],
			"pos": {"x": pos.x, "y": pos.y},
			"garrison_paths": tmpl["garrison"],
			"cleared": false,
			"reward_thalers": tmpl["reward"],
			"name": tmpl["name"],
			"connected_by_road": tmpl.get("connected_by_road", true),
			"discovered": tmpl["type"] == "town"
		})
		loc_id += 1

	state["locations"] = locations

# ── Дороги (spanning tree між локаціями) ──────────────────────────────────────

func _gen_roads(state: Dictionary) -> void:
	var locs: Array = state.get("locations", [])
	if locs.size() < 2:
		return

	# Додаємо позицію гравця як вузол
	var player_v2 := Vector2(
		state["player_pos"].x if state["player_pos"] is Vector2 else state["player_pos"]["x"],
		state["player_pos"].y if state["player_pos"] is Vector2 else state["player_pos"]["y"]
	)

	# Фільтруємо лише локації, які мають бути з'єднані дорогами
	var road_locs := []
	for loc in locs:
		if loc.get("connected_by_road", true) == true:
			road_locs.append(loc)

	var points: Array[Vector2] = [player_v2]
	for loc in road_locs:
		points.append(Vector2(loc["pos"]["x"], loc["pos"]["y"]))

	# Жадібний spanning tree (мінімальне дерево)
	var connected: Array[int] = [0]
	var roads: Array = []

	while connected.size() < points.size():
		var best_dist := INF
		var best_from := -1
		var best_to := -1

		for i in connected:
			for j in range(points.size()):
				if j in connected:
					continue
				var d := points[i].distance_to(points[j])
				if d < best_dist:
					best_dist = d
					best_from = i
					best_to = j

		if best_to == -1:
			break

		connected.append(best_to)
		# Дорога з легким зигзагом посередині
		var a := points[best_from]
		var b := points[best_to]
		var mid := (a + b) / 2.0
		var offset := (b - a).orthogonal().normalized() * randf_range(-25.0, 25.0)
		roads.append([
			{"x": a.x, "y": a.y},
			{"x": mid.x + offset.x, "y": mid.y + offset.y},
			{"x": b.x, "y": b.y}
		])

	state["roads"] = roads

# ── Ворожі загони ─────────────────────────────────────────────────────────────

func _gen_parties(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var _locs: Array = state.get("locations", [])
	var roads: Array = state.get("roads", [])

	var FACTION_POOLS = {
		"none": [BANDIT, BANDIT, BANDIT_LEAD],
		"orda": [TATAR, TATAR, TATAR_HEAVY],
		"crown": [REIESTR, REIESTR, JANISSARY],
		"sich": [BANDIT] # Поки що немає юнітів для Січі, використаємо заглушку
	}

	var party_templates := [
		{"faction": "none",  "biome": "forest", "road_patrol": true,  "min": 2, "max": 3},
		{"faction": "none",  "biome": "forest", "road_patrol": true,  "min": 3, "max": 4},
		{"faction": "orda",  "biome": "steppe", "road_patrol": false, "min": 2, "max": 4},
		{"faction": "orda",  "biome": "steppe", "road_patrol": false, "min": 3, "max": 5},
		{"faction": "crown", "biome": "border", "road_patrol": false, "min": 2, "max": 3},
		{"faction": "crown", "biome": "border", "road_patrol": true,  "min": 3, "max": 4},
	]

	var biome_bounds := {
		"forest": Rect2(0, 0, MAP_W * 0.38, MAP_H),
		"steppe": Rect2(MAP_W * 0.38, 0, MAP_W * 0.38, MAP_H),
		"border": Rect2(MAP_W * 0.76, 0, MAP_W * 0.24, MAP_H)
	}

	var parties: Array = []
	var placed: Array[Vector2] = []
	var party_id := 0

	for tmpl in party_templates:
		var bounds: Rect2 = biome_bounds[tmpl["biome"]]
		var base_pos := _find_free_pos(rng, bounds, placed, MIN_PARTY_DIST, 50.0)
		if base_pos == Vector2.ZERO:
			continue
		placed.append(base_pos)

		var waypoints: Array = _get_patrol_waypoints(tmpl, base_pos, roads, rng)
		
		# Динамічна генерація юнітів (Battle Brothers style)
		var pool: Array = FACTION_POOLS.get(tmpl["faction"], FACTION_POOLS["none"])
		var size = rng.randi_range(tmpl["min"], tmpl["max"])
		
		# Логіка масштабування від дня гри (на майбутнє)
		var day = state.get("day", 1)
		if day > 10:
			size += 1
			
		var generated_units: Array = []
		for i in range(size):
			generated_units.append(pool[rng.randi() % pool.size()])

		parties.append({
			"id": "party_%d" % party_id,
			"faction": tmpl["faction"],
			"unit_paths": generated_units,
			"patrol_waypoints": waypoints,
			"base_pos": {"x": base_pos.x, "y": base_pos.y},
			"pos": {"x": base_pos.x, "y": base_pos.y},
			"alive": true
		})
		party_id += 1

	state["enemy_parties"] = parties

# ── Waypoints для патруля ─────────────────────────────────────────────────────

func _get_patrol_waypoints(tmpl: Dictionary, base: Vector2, roads: Array,
		rng: RandomNumberGenerator) -> Array:
	var pts: Array = []

	if tmpl.get("road_patrol", false) and not roads.is_empty():
		# Знаходимо найближчий відрізок дороги
		var best_road: Array = roads[0]
		var best_d := INF
		for road in roads:
			for pt_dict in road:
				var d := base.distance_to(Vector2(pt_dict["x"], pt_dict["y"]))
				if d < best_d:
					best_d = d
					best_road = road

		# Беремо 3-4 точки вздовж дороги з невеликим відхиленням
		for pt_dict in best_road:
			pts.append({
				"x": pt_dict["x"] + rng.randf_range(-20.0, 20.0),
				"y": pt_dict["y"] + rng.randf_range(-20.0, 20.0)
			})
	else:
		# Патруль навколо base_pos (3 точки в радіусі ~100px)
		for i in range(3):
			var angle := float(i) * TAU / 3.0 + rng.randf_range(-0.3, 0.3)
			var r := rng.randf_range(60.0, 120.0)
			pts.append({
				"x": base.x + cos(angle) * r,
				"y": base.y + sin(angle) * r
			})

	return pts

# ── Допоміжні методи ─────────────────────────────────────────────────────────

func _find_free_pos(rng: RandomNumberGenerator, bounds: Rect2,
		existing: Array, min_dist: float, margin: float) -> Vector2:
	for _attempt in range(50):
		var x := rng.randf_range(bounds.position.x + margin, bounds.position.x + bounds.size.x - margin)
		var y := rng.randf_range(bounds.position.y + margin, bounds.position.y + bounds.size.y - margin)
		var candidate := Vector2(x, y)
		var ok := true
		for pos in existing:
			if candidate.distance_to(pos) < min_dist:
				ok = false
				break
		if ok:
			return candidate
	return Vector2.ZERO

# ── Генератори органічних форм ────────────────────────────────────────────────

# Нерівний blob-полігон навколо (cx, cy).
# roughness: 0.0 = правильне коло, 0.5 = дуже нерівний
# rx_scale/ry_scale: масштаб по осях (для асиметрії болота)
func _blob_poly(rng: RandomNumberGenerator, cx: float, cy: float,
		base_r: float, n: int, roughness: float,
		rx_scale: float, ry_scale: float) -> Array:
	# Генеруємо радіуси з шумом
	var radii: Array[float] = []
	for _j in range(n):
		radii.append(base_r * rng.randf_range(1.0 - roughness, 1.0 + roughness * 0.6))
	# Один прохід згладжування (moving average) → органічний силует
	var smoothed: Array[float] = []
	for k in range(n):
		var prev: float = radii[(k - 1 + n) % n]
		var curr: float = radii[k]
		var nxt: float  = radii[(k + 1) % n]
		smoothed.append((prev + curr * 2.0 + nxt) / 4.0)
	# Будуємо вершини з невеликим кутовим jitter
	var pts := []
	for m in range(n):
		var base_angle := float(m) / float(n) * TAU
		var angle_jitter := (TAU / float(n)) * rng.randf_range(-0.25, 0.25)
		var a := base_angle + angle_jitter
		var sr: float = smoothed[m]
		pts.append({
			"x": cx + cos(a) * sr * rx_scale,
			"y": cy + sin(a) * sr * ry_scale
		})
	return pts

# Витягнутий хребет (для пагорбів): еліпс під кутом ridge_angle з roughness
func _ridge_poly(rng: RandomNumberGenerator, cx: float, cy: float,
		rx: float, ry: float, ridge_angle: float,
		n: int, roughness: float) -> Array:
	var pts := []
	var jitter_scale := sqrt(rx * ry) * roughness
	for i in range(n):
		var base_angle := float(i) / float(n) * TAU
		var lx := cos(base_angle) * rx
		var ly := sin(base_angle) * ry
		# Поворот на ridge_angle
		var world_x := lx * cos(ridge_angle) - ly * sin(ridge_angle)
		var world_y := lx * sin(ridge_angle) + ly * cos(ridge_angle)
		# Перпендикулярний jitter
		var perp_angle := base_angle + PI * 0.5
		var jitter := rng.randf_range(-0.5, 0.5) * jitter_scale
		pts.append({
			"x": cx + world_x + cos(perp_angle) * jitter,
			"y": cy + world_y + sin(perp_angle) * jitter
		})
	return pts
