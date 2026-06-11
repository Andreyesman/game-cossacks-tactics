extends Node2D

# ── Константи ─────────────────────────────────────────────────────────────────

const MAP_W := 3000.0
const MAP_H := 2000.0

const C_BG := Color(0.08, 0.07, 0.05)
const C_ROAD := Color(0.45, 0.38, 0.22, 0.7)
const C_RIVER := Color(0.18, 0.35, 0.55, 0.85)
const C_LAKE := Color(0.15, 0.30, 0.50, 0.75)
const C_PLAYER := Color(0.9, 0.85, 0.2)
const C_GOLD := Color(0.894, 0.804, 0.42)
const C_DARK_BG := Color(0.04, 0.035, 0.03)

# Пікселів карти на один ігровий день
const PIXELS_PER_DAY := 1500.0

# Торгівля
const TRADE_PROV_PACK := 5 # провізій у пакеті
const TRADE_PROV_COST := 25 # талерів за пакет
const TRADE_HEAL_COST := 30 # талерів за лікування одного юніта

# День/ніч
const FOG_REVEAL_DAY := 280.0 # радіус видимості вдень (px карти)
const FOG_REVEAL_NIGHT := 160.0 # радіус видимості вночі
const C_DAY := Color(1.00, 1.00, 1.00)
const C_DUSK := Color(0.72, 0.52, 0.32)
const C_NIGHT := Color(0.32, 0.34, 0.50)

# ── Посилання на вузли ────────────────────────────────────────────────────────

var _camera: Camera2D
var _map_root: Node2D
var _biome_layer: Node2D
var _water_layer: Node2D
var _roads_layer: Node2D
var _locations_layer: Node2D
var _parties_layer: Node2D
var _player_party: Node2D # Node2D з PlayerParty.gd
var _hud: CanvasLayer

# HUD елементи
var _day_label: Label
var _time_phase_label: Label
var _thalers_label: Label
var _provisions_label: Label
var _bandages_label: Label
var _rep_labels: Dictionary[String, Label] = {}
var _squad_panel: Control
var _encounter_dialog: Control # EncounterDialog.tscn (бій з загоном/локацією)
var _location_dialog: Control # процедурний діалог очищеної локації (торгівля/найм)
var _inventory_panel: Control = null
var _inventory_btn: Button = null
var _selected_unit_name: String = ""
var _inv_squad_row: VBoxContainer = null
var _inv_equipment_vbox: VBoxContainer = null
var _inv_items_vbox: VBoxContainer = null
var _encounter_bg: ColorRect
var _top_bar_root: Control = null
var _speed_panel: Control
var _day_circle: Control = null
var _day_circle_style: StyleBoxFlat = null
var _pause_btn: TextureButton
var _speed1_btn: TextureButton
var _speed2_btn: TextureButton
var _tex_pause_default: Texture2D
var _tex_pause_hover: Texture2D
var _tex_pause_active: Texture2D
var _tex_play_default: Texture2D
var _tex_play_hover: Texture2D
var _tex_play_active: Texture2D
var _tex_fwd_default: Texture2D
var _tex_fwd_hover: Texture2D
var _tex_fwd_active: Texture2D
var _pause_label: Label
var _discovery_panel: PanelContainer = null
var _discovery_label: RichTextLabel = null
var _discovery_tween: Tween = null

# Стан
var world_ticking: bool = false
var _speed_multiplier: int = 1
var _prev_speed: int = 1
var _is_paused: bool = false
var _active_encounter: Node2D = null # загін або локація з активним діалогом
var _encounter_cooldowns: Dictionary[Node2D, float] = {}
var _nav_target_marker: Node2D = null # локація, до якої гравець іде після кліку
var _recruits_cache: Dictionary[String, Array] = {} # loc_id → Array[Dict]
var _camera_follows_player: bool = true
var _is_dragging_cam: bool = false

# Туман війни та день/ніч
const FOG_GRID_W := 100
const FOG_GRID_H := 67
const FOG_CELL_SIZE := 30.0 # px на одну комірку сітки

var _fog_rect: ColorRect = null
var _canvas_modulate: CanvasModulate = null
var _day_time: float = 0.285 * PIXELS_PER_DAY # починаємо о 12:00 (полудень = phase 0.285)
var _torch_light: PointLight2D = null
var _fog_cloud_rect: ColorRect = null

var _fog_image: Image = null
var _fog_texture: ImageTexture = null
var _fog_bytes: PackedByteArray = PackedByteArray()
var _current_target_reveal_radius: float = FOG_REVEAL_DAY
var _current_actual_reveal_radius: float = FOG_REVEAL_DAY

# Onboarding підказки — скидаються з кожною грою, не зберігаються в world_state
var _onboarding_panel: PanelContainer = null
var _onboarding_label: RichTextLabel = null
var _onboarding_tween: Tween = null
var _onboarding_shown: Dictionary = {}
var _current_hint_key: String = ""

# ── _ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm or cm.world_state.is_empty():
		push_error("WorldMap: CampaignManager не має world_state")
		return

	_build_scene_tree()
	_render_world(cm.world_state)
	_build_hud(cm.world_state)
	AudioManager.play_music("map")
	_update_hud(cm.world_state)

	if cm.world_state.get("day", 1) == 1:
		get_tree().create_timer(1.0).timeout.connect(func():
			_show_onboarding_hint("move", "[color=gold]" + tr("HINT_MOVE") + "[/color]")
		, CONNECT_ONE_SHOT)

	var squad: Array = cm.world_state.get("squad", [])
	for unit in squad:
		var hp: int = unit.get("hp", 100)
		var max_hp: int = unit.get("max_hp", 100)
		if max_hp > 0 and hp * 2 < max_hp:
			_show_onboarding_hint("wounded", "[color=red]" + tr("HINT_WOUNDED") + "[/color]")
			break

# ── Побудова дерева вузлів ────────────────────────────────────────────────────

func _build_scene_tree() -> void:
	# Камера
	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(MAP_W)
	_camera.limit_bottom = int(MAP_H)
	add_child(_camera)
	_camera.make_current()

	# Оновлюємо зум при старті та зміні розміру вікна
	get_tree().root.size_changed.connect(_update_camera_zoom)
	_update_camera_zoom()

	# Корінь карти
	_map_root = Node2D.new()
	_map_root.name = "MapRoot"
	add_child(_map_root)

	_biome_layer = Node2D.new(); _biome_layer.name = "BiomeLayer"; _map_root.add_child(_biome_layer)
	_water_layer = Node2D.new(); _water_layer.name = "WaterLayer"; _map_root.add_child(_water_layer)
	_roads_layer = Node2D.new(); _roads_layer.name = "RoadsLayer"; _map_root.add_child(_roads_layer)
	_locations_layer = Node2D.new(); _locations_layer.name = "LocationsLayer"; _map_root.add_child(_locations_layer)
	_parties_layer = Node2D.new(); _parties_layer.name = "PartiesLayer"; _map_root.add_child(_parties_layer)

	# Гравець — z_index > туману, щоб завжди бути видимим
	var pp := Node2D.new()
	pp.name = "PlayerParty"
	pp.set_script(load("res://src/world/PlayerParty.gd"))
	pp.z_index = 10
	_map_root.add_child(pp)
	_player_party = pp

	# CanvasModulate — для дня/ночі. Не впливає на HUD (CanvasLayer)
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.color = C_DAY
	add_child(_canvas_modulate)

	# HUD
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	add_child(_hud)

func _update_camera_zoom() -> void:
	if not _camera: return
	var v_size = get_viewport_rect().size
	# Встановлюємо зум так, щоб карта красивим чином заповнювала весь екран
	var z = max(v_size.x / MAP_W, v_size.y / MAP_H)
	# Забезпечуємо приємний мінімальний зум, щоб карта не виглядала занадто дрібною
	z = max(z, 0.95)
	_camera.zoom = Vector2(z, z)

# ── Рендер карти ─────────────────────────────────────────────────────────────

func _render_world(state: Dictionary) -> void:
	_render_biomes(state.get("biomes", [])) # biomes arg kept for API compat (ignored internally)
	_render_water(state.get("rivers", []), state.get("lakes", []))
	_render_roads(state.get("roads", []))
	_render_locations(state.get("locations", []))
	_render_parties(state.get("enemy_parties", []))

	# Позиція гравця
	var pp = state.get("player_pos", {"x": MAP_W / 2, "y": MAP_H / 2})
	_player_party.position = Vector2(pp["x"] if pp is Dictionary else pp.x,
									  pp["y"] if pp is Dictionary else pp.y)
	_camera.position = _player_party.position

	# Підключення сигналів PlayerParty
	_player_party.movement_started.connect(_on_player_movement_started)
	_player_party.movement_stopped.connect(_on_player_movement_stopped)

	_setup_fog()
	_setup_cloud_layer()
	_setup_torch_light()

func _setup_cloud_layer() -> void:
	var cloud_shader := Shader.new()
	cloud_shader.code = """
shader_type canvas_item;
uniform sampler2D fog_texture : filter_linear;
uniform vec2 player_pos = vec2(1500.0, 1000.0);
uniform float reveal_radius = 280.0;
uniform vec2 map_size = vec2(3000.0, 2000.0);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float worley(vec2 uv, float scale) {
	uv *= scale;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float md = 4.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = n + hash2(cell + n);
			md = min(md, length(f - pt));
		}
	}
	return md;
}

float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i).x;
	float b = hash2(i + vec2(1.0, 0.0)).x;
	float c = hash2(i + vec2(0.0, 1.0)).x;
	float d = hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float explored = texture(fog_texture, UV).r;
	float unexplored = smoothstep(0.15, 0.0, explored);

	vec2 world_pos = UV * map_size;
	float dist = distance(world_pos, player_pos);
	float reveal = smoothstep(reveal_radius, reveal_radius * 0.2, dist);

	// Повільний дрейф
	float t = TIME * 0.006;
	vec2 warp = vec2(vnoise(UV * 9.0 + vec2(t, t * 0.7)),
	                 vnoise(UV * 9.0 + vec2(t * 1.3, 0.4))) * 0.12;
	vec2 wuv = UV + warp;

	// Три розміри хмар
	float c1 = smoothstep(0.72, 0.30, worley(wuv, 3.2));
	float c2 = smoothstep(0.62, 0.22, worley(wuv, 6.5)) * 0.85;
	float c3 = smoothstep(0.50, 0.18, worley(wuv, 11.0)) * 0.65;
	float cloud = max(c1, max(c2, c3));

	float alpha = cloud * unexplored * (1.0 - reveal);
	COLOR = vec4(0.97, 0.97, 0.95, clamp(alpha, 0.0, 0.88));
}
"""
	var cloud_mat := ShaderMaterial.new()
	cloud_mat.shader = cloud_shader
	cloud_mat.set_shader_parameter("fog_texture", _fog_texture)
	cloud_mat.set_shader_parameter("map_size", Vector2(MAP_W, MAP_H))
	cloud_mat.set_shader_parameter("player_pos", Vector2(MAP_W / 2.0, MAP_H / 2.0))
	cloud_mat.set_shader_parameter("reveal_radius", FOG_REVEAL_DAY)

	_fog_cloud_rect = ColorRect.new()
	_fog_cloud_rect.name = "CloudLayer"
	_fog_cloud_rect.size = Vector2(MAP_W, MAP_H)
	_fog_cloud_rect.color = Color(0, 0, 0, 0)
	_fog_cloud_rect.z_index = 9
	_fog_cloud_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_cloud_rect.material = cloud_mat
	_map_root.add_child(_fog_cloud_rect)

func _setup_torch_light() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.72, 0.25, 1.0))
	grad.set_color(1, Color(1.0, 0.72, 0.25, 0.0))
	var tex := GradientTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = grad
	_torch_light = PointLight2D.new()
	_torch_light.texture = tex
	_torch_light.texture_scale = 0.75 # ~96px radius
	_torch_light.energy = 0.0
	_torch_light.color = Color(1.0, 0.72, 0.25)
	_player_party.add_child(_torch_light)

func _setup_fog() -> void:
	# 1. Завантаження та розкодування стану сітки з world_state
	var cm := get_node_or_null("/root/CampaignManager")
	var fow_base64: String = ""
	if cm and cm.world_state.has("fog_of_war_data"):
		fow_base64 = cm.world_state["fog_of_war_data"]
	
	if not fow_base64.is_empty():
		_fog_bytes = Marshalls.base64_to_raw(fow_base64)
	
	if _fog_bytes.size() != FOG_GRID_W * FOG_GRID_H:
		_fog_bytes = PackedByteArray()
		_fog_bytes.resize(FOG_GRID_W * FOG_GRID_H)
		_fog_bytes.fill(0)
	
	# 2. Створення Image та ImageTexture
	_fog_image = Image.create(FOG_GRID_W, FOG_GRID_H, false, Image.FORMAT_RGBA8)
	for y in range(FOG_GRID_H):
		for x in range(FOG_GRID_W):
			var idx := y * FOG_GRID_W + x
			var explored := _fog_bytes[idx]
			# R = explored (0-255), G = active_visibility (0), B = 0, A = 255
			_fog_image.set_pixel(x, y, Color(float(explored) / 255.0, 0.0, 0.0, 1.0))
	
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	
	# 3. Шейдер туману війни з лінійною фільтрацією та текстурним шумом пергаменту
	var fog_shader := Shader.new()
	fog_shader.code = """
shader_type canvas_item;
uniform sampler2D fog_texture : filter_linear;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 color_shroud = vec4(0.80, 0.82, 0.88, 1.0);
uniform vec2 player_pos = vec2(1500.0, 1000.0);
uniform float reveal_radius = 280.0;
uniform vec2 map_size = vec2(3000.0, 2000.0);

void fragment() {
	float explored = texture(fog_texture, UV).r;

	float noise = fract(sin(dot(UV * 150.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 fog_rgb = color_shroud.rgb + vec3(noise * 0.024 - 0.012);

	float shroud_factor = smoothstep(0.25, 0.0, explored);

	vec2 world_pos = UV * map_size;
	float dist = distance(world_pos, player_pos);
	float soft_edge = reveal_radius * 0.08;
	float soft_active = smoothstep(reveal_radius + soft_edge, reveal_radius - soft_edge, dist);

	// Пам'ять — відтінки сірого
	vec4 scene = texture(screen_texture, SCREEN_UV);
	float gray = dot(scene.rgb, vec3(0.299, 0.587, 0.114));
	vec3 memory_rgb = vec3(gray * 0.65);

	// Активна зона: прозоро; Пам'ять: сіра; Shroud: туман
	float mem_factor = (1.0 - soft_active) * (1.0 - shroud_factor);
	float out_alpha = mix(mem_factor, 1.0, shroud_factor);
	vec3 out_rgb = mix(memory_rgb, fog_rgb, shroud_factor);

	COLOR = vec4(out_rgb, out_alpha);
}
"""
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = fog_shader
	fog_mat.set_shader_parameter("fog_texture", _fog_texture)
	fog_mat.set_shader_parameter("map_size", Vector2(MAP_W, MAP_H))
	fog_mat.set_shader_parameter("player_pos", Vector2(MAP_W / 2.0, MAP_H / 2.0))
	fog_mat.set_shader_parameter("reveal_radius", FOG_REVEAL_DAY)

	_fog_rect = ColorRect.new()
	_fog_rect.name = "FogLayer"
	_fog_rect.size = Vector2(MAP_W, MAP_H)
	_fog_rect.color = Color(0, 0, 0, 0)
	_fog_rect.z_index = 8 # вище локацій (4) та загонів (5), нижче гравця (10)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_rect.material = fog_mat
	_map_root.add_child(_fog_rect)

var _last_fog_update_pos: Vector2 = Vector2.ZERO
var _last_fog_update_radius: float = 0.0

func _get_biome_at(pos: Vector2) -> String:
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return "steppe"
	var state: Dictionary = cm.world_state

	# 1. Ліси — перевіряємо outer полігон
	for patch in state.get("forest_patches", []):
		if patch.has("outer"):
			var poly := PackedVector2Array()
			for pt in patch["outer"]:
				poly.append(Vector2(pt["x"], pt["y"]))
			if Geometry2D.is_point_in_polygon(pos, poly):
				return "forest"

	# 2. Болота — перевіряємо verts полігон
	for patch in state.get("swamp_patches", []):
		if patch.has("verts"):
			var poly := PackedVector2Array()
			for pt in patch["verts"]:
				poly.append(Vector2(pt["x"], pt["y"]))
			if Geometry2D.is_point_in_polygon(pos, poly):
				return "swamp"

	# 3. Пагорби — перевіряємо verts полігон
	for patch in state.get("hill_patches", []):
		if patch.has("verts"):
			var poly := PackedVector2Array()
			for pt in patch["verts"]:
				poly.append(Vector2(pt["x"], pt["y"]))
			if Geometry2D.is_point_in_polygon(pos, poly):
				return "hill"

	# 4. Кургани — відстань менша за 30px
	for kurgan in state.get("kurgans", []):
		if Vector2(kurgan["x"], kurgan["y"]).distance_to(pos) < 30.0:
			return "kurgan"

	# 5. Яри — відстань менша за 30px до сегментів
	for ravine in state.get("ravines", []):
		for i in range(ravine.size() - 1):
			var a := Vector2(ravine[i]["x"], ravine[i]["y"])
			var b := Vector2(ravine[i + 1]["x"], ravine[i + 1]["y"])
			if _dist_to_segment(pos, a, b) < 30.0:
				return "ravine"

	return "steppe"

func _get_biome_modifier(biome_id: String) -> float:
	match biome_id:
		"forest":
			return 0.7 # -30% дальність огляду в лісі
		"hill":
			if is_instance_valid(_player_party) and not _player_party.is_moving:
				return 1.2 # +20% дальність огляду при зупинці на пагорбі
			return 1.0
		"kurgan":
			return 1.5 # +50% дальність огляду на кургані
		_:
			return 1.0 # звичайний огляд в степу / болоті / яру

func _update_fog_grid(player_pos: Vector2, reveal_radius: float) -> void:
	if not is_instance_valid(_fog_image):
		return
	
	# Конвертуємо позицію гравця до сітки
	var p_grid := player_pos / FOG_CELL_SIZE
	
	# Радіус у комірках сітки
	var r_cells := reveal_radius / FOG_CELL_SIZE
	var r_cells_sq := r_cells * r_cells
	
	var grid_changed := false
	
	for y in range(FOG_GRID_H):
		for x in range(FOG_GRID_W):
			var idx := y * FOG_GRID_W + x
			
			# Обчислюємо відстань у клітинках сітки від гравця
			var dx := float(x) + 0.5 - p_grid.x
			var dy := float(y) + 0.5 - p_grid.y
			var dist_sq := dx * dx + dy * dy
			
			var cell_visible := dist_sq <= r_cells_sq
			
			var old_explored := _fog_bytes[idx]
			var new_explored := old_explored
			if cell_visible and old_explored != 255:
				new_explored = 255
				_fog_bytes[idx] = 255
				grid_changed = true
			
			var r_val := float(new_explored) / 255.0
			_fog_image.set_pixel(x, y, Color(r_val, 0.0, 0.0, 1.0))
	
	if is_instance_valid(_fog_texture):
		_fog_texture.update(_fog_image)
	
	# Зберігаємо оновлений Shroud назад у world_state, якщо він змінився
	if grid_changed:
		var cm := get_node_or_null("/root/CampaignManager")
		if cm:
			cm.world_state["fog_of_war_data"] = Marshalls.raw_to_base64(_fog_bytes)

func _update_entity_visibility_and_discovery() -> void:
	if not is_instance_valid(_player_party):
		return
	
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return
	
	var reveal_r := _current_actual_reveal_radius
	var p_pos := _player_party.position
	
	# 1. Оновлюємо видимість ворожих загонів (EnemyParty)
	if is_instance_valid(_parties_layer):
		for party in _parties_layer.get_children():
			if party is Node2D:
				var dist := p_pos.distance_to(party.position)
				var party_visible := dist <= reveal_r
				party.visible = party_visible
				
				# Якщо загін невидимий, припиняємо його переслідування гравця
				if not party_visible and "state" in party and party.get("state") == 1: # State.PURSUE
					party.set("state", 0) # State.PATROL
	
	# 2. Оновлюємо видимість локацій та перевіряємо відкриття
	if is_instance_valid(_locations_layer):
		for marker in _locations_layer.get_children():
			if marker is Node2D:
				var dist := p_pos.distance_to(marker.position)
				var is_discovered := marker.get("discovered") as bool if "discovered" in marker else false
				
				if not is_discovered:
					if dist <= reveal_r:
						marker.set("discovered", true)
						marker.visible = true
						
						# Оновлюємо стан у CampaignManager
						var loc_id_val = marker.get("loc_id")
						if loc_id_val != null:
							var loc_id_str := str(loc_id_val)
							var locations: Array = cm.world_state.get("locations", [])
							for loc in locations:
								if loc.get("id") == loc_id_str:
									loc["discovered"] = true
									break
						
						# Сповіщення через кастомний банер
						var loc_name_val = marker.get("loc_name")
						var loc_name_str := str(loc_name_val) if loc_name_val != null else "Нова локація"
						_show_discovery_notification("[color=gold]" + tr("MAP_DISCOVERED") % loc_name_str + "[/color]")
						
						if Globals.DEBUG_LOG: print("Гравець виявив нову локацію: ", loc_name_str)
					else:
						marker.visible = false
				else:
					marker.visible = true


func _render_biomes(_biomes: Array) -> void:
	# ── Широкий фон (за межами карти) ─────────────────────────────────────────
	var huge_bg := ColorRect.new()
	huge_bg.position = Vector2(-5000, -5000)
	huge_bg.size = Vector2(10000, 10000)
	huge_bg.color = Color(0.12, 0.09, 0.06)
	_biome_layer.add_child(huge_bg)

	# ── Пергаментний фон (шейдер) ─────────────────────────────────────────────
	var parch_shader := Shader.new()
	parch_shader.code = """
shader_type canvas_item;
uniform vec2 map_size = vec2(3000.0, 2000.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1; a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 wp = uv * map_size;

	// Базовий пергаментний колір
	vec3 base = vec3(0.86, 0.76, 0.52);

	// Зернистість паперу (дрібний шум)
	float grain = fbm(wp * 0.08) * 0.18 + fbm(wp * 0.22) * 0.09;
	base += vec3(grain * 0.6, grain * 0.45, grain * 0.18) - 0.07;

	// Плями старіння (великі, рідкі)
	float stain = fbm(wp * 0.012 + vec2(3.7, 1.2)) * fbm(wp * 0.018 + vec2(0.5, 4.1));
	stain = smoothstep(0.28, 0.50, stain) * 0.22;
	base -= vec3(stain * 0.3, stain * 0.12, stain * 0.05);

	// Ефект вигорання на краях (vignette)
	vec2 vig = uv * 2.0 - 1.0;
	float vignette = 1.0 - dot(vig, vig) * 0.28;
	base *= vignette;

	// Легкий мікро-шум (фактура волокна)
	float fiber = hash(wp * 1.8) * 0.04 - 0.02;
	base += fiber;

	COLOR = vec4(clamp(base, 0.0, 1.0), 1.0);
}
"""
	var parch_mat := ShaderMaterial.new()
	parch_mat.shader = parch_shader
	parch_mat.set_shader_parameter("map_size", Vector2(MAP_W, MAP_H))

	var bg := ColorRect.new()
	bg.name = "ParchmentBG"
	bg.position = Vector2.ZERO
	bg.size = Vector2(MAP_W, MAP_H)
	bg.color = Color(0.86, 0.76, 0.52) # fallback якщо шейдер не завантажиться
	bg.material = parch_mat
	_biome_layer.add_child(bg)

	# ── Отримуємо географічні патчі зі стану світу ─────────────────────────────
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return
	var state: Dictionary = cm.world_state

	_render_geography_patches(state)
	_render_cartographic_symbols(state)

	# ── Декоративна подвійна рамка карти ──────────────────────────────────────
	# Зовнішня (товста, темна)
	var border_out := Line2D.new()
	border_out.width = 7.0
	border_out.default_color = Color(0.30, 0.20, 0.08)
	border_out.closed = true
	border_out.add_point(Vector2(2, 2))
	border_out.add_point(Vector2(MAP_W - 2, 2))
	border_out.add_point(Vector2(MAP_W - 2, MAP_H - 2))
	border_out.add_point(Vector2(2, MAP_H - 2))
	_biome_layer.add_child(border_out)
	# Внутрішня (тонка, золота)
	var border_in := Line2D.new()
	border_in.width = 2.0
	border_in.default_color = Color(0.62, 0.46, 0.14, 0.85)
	border_in.closed = true
	border_in.add_point(Vector2(10, 10))
	border_in.add_point(Vector2(MAP_W - 10, 10))
	border_in.add_point(Vector2(MAP_W - 10, MAP_H - 10))
	border_in.add_point(Vector2(10, MAP_H - 10))
	_biome_layer.add_child(border_in)
	# Кутові марки (маленькі хрестики по кутах)
	for corner in [Vector2(10, 10), Vector2(MAP_W - 10, 10),
			Vector2(MAP_W - 10, MAP_H - 10), Vector2(10, MAP_H - 10)]:
		for is_horiz in [true, false]:
			var tick := Line2D.new()
			tick.width = 2.0
			tick.default_color = Color(0.45, 0.32, 0.10)
			if is_horiz:
				tick.add_point(corner + Vector2(-8, 0))
				tick.add_point(corner + Vector2(8, 0))
			else:
				tick.add_point(corner + Vector2(0, -8))
				tick.add_point(corner + Vector2(0, 8))
			_biome_layer.add_child(tick)


# ── Картографічні символи (дерева, пагорби, болото) ─────────────────────────────────

# Символи малюються на окремому шарі (symbol_layer) поверх біомних полігонів.
var _symbol_layer: Node2D = null

func _render_cartographic_symbols(state: Dictionary) -> void:
	# Окремий шар для символів
	_symbol_layer = Node2D.new()
	_symbol_layer.name = "SymbolLayer"
	_symbol_layer.z_index = 1
	_map_root.add_child(_symbol_layer)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777 # Фіксований seed — символи розташовані однаково

	# 1. Дерева у лісових патчах
	for patch in state.get("forest_patches", []):
		var cx: float = patch["x"]
		var cy: float = patch["y"]
		var r: float = patch["r"]
		# Кількість дерев пропорційна до площі патчу
		var num_trees := clampi(int(r * r * 0.00028), 5, 22)
		for _t in range(num_trees):
			for _attempt in range(12):
				var angle := rng.randf() * TAU
				var dist := sqrt(rng.randf()) * r * 0.82 # рівномірно по площі
				var tp := Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist)
				_draw_tree_symbol(tp)
				break

	# 2. Штрихування пагорбів
	for patch in state.get("hill_patches", []):
		var cx: float = patch["x"]
		var cy: float = patch["y"]
		var r: float = patch["r"]
		var verts: Array = patch.get("verts", [])
		if verts.is_empty():
			continue
		_draw_hill_hatching(cx, cy, r, verts, rng)

	# 3. Хвилясті лінії для боліт
	for patch in state.get("swamp_patches", []):
		var cx: float = patch["x"]
		var cy: float = patch["y"]
		var r: float = patch["r"]
		_draw_swamp_symbols(cx, cy, r, rng)

# Намалює одне дерево у стилі рукописних карт XVII ст.
func _draw_tree_symbol(pos: Vector2) -> void:
	const C_TRUNK := Color(0.26, 0.17, 0.07, 0.80)
	const C_CROWN := Color(0.14, 0.26, 0.09, 0.82)
	# Стовбур
	var trunk := Line2D.new()
	trunk.width = 1.5
	trunk.default_color = C_TRUNK
	trunk.add_point(pos + Vector2(0.0, 5.0))
	trunk.add_point(pos + Vector2(0.0, -1.0))
	_symbol_layer.add_child(trunk)
	# Ліва гілка
	var bl := Line2D.new()
	bl.width = 1.2; bl.default_color = C_CROWN
	bl.add_point(pos + Vector2(0.0, -1.0))
	bl.add_point(pos + Vector2(-6.0, -7.0))
	_symbol_layer.add_child(bl)
	# Права гілка
	var br := Line2D.new()
	br.width = 1.2; br.default_color = C_CROWN
	br.add_point(pos + Vector2(0.0, -1.0))
	br.add_point(pos + Vector2(6.0, -7.0))
	_symbol_layer.add_child(br)
	# Центральна гілка (верхівка)
	var bc := Line2D.new()
	bc.width = 1.2; bc.default_color = C_CROWN
	bc.add_point(pos + Vector2(0.0, -1.0))
	bc.add_point(pos + Vector2(0.0, -10.0))
	_symbol_layer.add_child(bc)
	# Нижня пара гілок (для класичного вигляду)
	var bl2 := Line2D.new()
	bl2.width = 1.0; bl2.default_color = C_CROWN
	bl2.add_point(pos + Vector2(0.0, 2.0))
	bl2.add_point(pos + Vector2(-4.5, -2.5))
	_symbol_layer.add_child(bl2)
	var br2 := Line2D.new()
	br2.width = 1.0; br2.default_color = C_CROWN
	br2.add_point(pos + Vector2(0.0, 2.0))
	br2.add_point(pos + Vector2(4.5, -2.5))
	_symbol_layer.add_child(br2)

# Штрихування пагорба паралельними похилими рисками всередині форми.
func _draw_hill_hatching(cx: float, cy: float, r: float,
		_verts: Array, rng: RandomNumberGenerator) -> void:
	const C_HATCH := Color(0.28, 0.20, 0.10, 0.60)
	# Кількість рядів штрихів — більше для великих пагорбів
	var num_rows := clampi(int(r * 0.28), 4, 14)
	for row in range(num_rows):
		# Відстань від центру (0 = центр, 1 = край)
		var t := (float(row) + 0.5) / float(num_rows)
		# Ширина рядку зменшується до краю
		var half_w := sqrt(1.0 - t * t) * r * 1.2
		var row_y := cy - r * 0.6 + t * r * 1.2
		# Невеликий jitter по Y
		row_y += rng.randf_range(-3.0, 3.0)
		# Риска: злегка по ходу від лівого краю до правого
		var stroke := Line2D.new()
		stroke.width = lerpf(2.0, 0.8, t) # Товщіше внизу, тонше вгорі
		stroke.default_color = C_HATCH
		stroke.add_point(Vector2(cx - half_w, row_y + 3.0)) # лівий край — нижче
		stroke.add_point(Vector2(cx, row_y)) # центр
		stroke.add_point(Vector2(cx + half_w, row_y + 3.0)) # правий край — нижче
		_symbol_layer.add_child(stroke)

# Хвилясті горизонтальні лінії — класичний символ болота на старих картах.
func _draw_swamp_symbols(cx: float, cy: float, r: float,
		rng: RandomNumberGenerator) -> void:
	const C_WAVE := Color(0.12, 0.28, 0.20, 0.70)
	var num_waves := clampi(int(r * 0.18), 3, 10)
	for _w in range(num_waves):
		# Випадкова позиція всередині патчу
		var wx := cx + rng.randf_range(-r * 0.60, r * 0.60)
		var wy := cy + rng.randf_range(-r * 0.55, r * 0.55)
		var wave_w := rng.randf_range(10.0, 22.0)
		# Хвиляста лінія: 4 точки зі змінним Y (sin-подібна)
		var wave := Line2D.new()
		wave.width = 1.2
		wave.default_color = C_WAVE
		for seg in range(5):
			var sx := wx - wave_w * 0.5 + (wave_w / 4.0) * float(seg)
			var sy := wy + sin(float(seg) * PI * 0.5) * 3.0
			wave.add_point(Vector2(sx, sy))
		_symbol_layer.add_child(wave)

# ── Процедурний рендер географічних патчів ────────────────────────────────────

func _render_geography_patches(state: Dictionary) -> void:
	# Кольори
	const C_FOREST := Color(0.11, 0.22, 0.09, 0.88) # Темно-зелений ліс
	const C_FOREST2 := Color(0.16, 0.32, 0.12, 0.55) # Прозорі краї лісу
	const C_HILL := Color(0.40, 0.31, 0.16, 0.75) # Хребет пагорбів
	const C_HILL_HI := Color(0.55, 0.44, 0.22, 0.50) # Освітлена грань
	const C_SWAMP := Color(0.13, 0.21, 0.15, 0.82) # Болото
	const C_KURGAN := Color(0.50, 0.40, 0.22) # Курган
	const C_RAVINE := Color(0.20, 0.14, 0.08, 0.92) # Яр

	# 1. Ліси — органічні blob з pre-computed вершинами
	for patch in state.get("forest_patches", []):
		# Зовнішній прозорий ареол
		if patch.has("outer"):
			var outer := _verts_to_poly(patch["outer"], C_FOREST2)
			_biome_layer.add_child(outer)
		# Щільне ядро
		if patch.has("inner"):
			var inner := _verts_to_poly(patch["inner"], C_FOREST)
			_biome_layer.add_child(inner)

	# 2. Пагорби — витягнуті хребти з pre-computed вершинами
	for patch in state.get("hill_patches", []):
		if patch.has("verts"):
			var body := _verts_to_poly(patch["verts"], C_HILL)
			_biome_layer.add_child(body)
			# Підсвітка гребеня: зменшені вершини (60% розміру відносно центру)
			var cx: float = patch["x"]
			var cy: float = patch["y"]
			var shrunken := []
			for pt in patch["verts"]:
				shrunken.append({
					"x": cx + (pt["x"] - cx) * 0.55,
					"y": cy + (pt["y"] - cy) * 0.40
				})
			var hi := _verts_to_poly(shrunken, C_HILL_HI)
			_biome_layer.add_child(hi)

	# 3. Болота — аморфні плями
	for patch in state.get("swamp_patches", []):
		if patch.has("verts"):
			var body := _verts_to_poly(patch["verts"], C_SWAMP)
			_biome_layer.add_child(body)

	# 4. Кургани — маленький горбик + хрестик/риска
	for k in state.get("kurgans", []):
		var kp := Vector2(k["x"], k["y"])
		var kpoly := _make_circle_poly(kp, 9.0, 8, C_KURGAN)
		_biome_layer.add_child(kpoly)
		# Горизонтальна риска (символ кургану)
		var tick := Line2D.new()
		tick.width = 2.0
		tick.default_color = Color(0.20, 0.13, 0.05)
		tick.add_point(kp + Vector2(-7, 0))
		tick.add_point(kp + Vector2(7, 0))
		_biome_layer.add_child(tick)

	# 5. Яри — меандруючі лінії з двома шарами
	for ravine in state.get("ravines", []):
		if ravine.size() < 2:
			continue
		# Основна лінія (товста, темна)
		var rl := Line2D.new()
		rl.width = 5.0
		rl.default_color = C_RAVINE
		for pt in ravine:
			rl.add_point(Vector2(pt["x"], pt["y"]))
		_biome_layer.add_child(rl)
		# Паралельна тінь (трохи зміщена)
		var rl2 := Line2D.new()
		rl2.width = 2.0
		rl2.default_color = Color(0.35, 0.26, 0.16, 0.60)
		for pt in ravine:
			rl2.add_point(Vector2(pt["x"] + 4, pt["y"] + 4))
		_biome_layer.add_child(rl2)

# ── Конвертер масиву вершин → Polygon2D ───────────────────────────────────────

func _verts_to_poly(verts_arr: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var v := PackedVector2Array()
	for pt in verts_arr:
		v.append(Vector2(pt["x"], pt["y"]))
	poly.polygon = v
	return poly


# ── Допоміжні геометричні методи ─────────────────────────────────────────────

func _make_circle_poly(center: Vector2, radius: float, points: int, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var verts := PackedVector2Array()
	for i in range(points):
		var angle := float(i) / float(points) * TAU
		verts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = verts
	return poly

func _make_ellipse_poly(center: Vector2, rx: float, ry: float, points: int, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var verts := PackedVector2Array()
	for i in range(points):
		var angle := float(i) / float(points) * TAU
		verts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	poly.polygon = verts
	return poly

# ── Запит поточного терейна гравця / зони впливу ─────────────────────────────

## Повертає множник швидкості руху для позиції pos.
## 1.0 = нормальна; < 1.0 = сповільнення; > 1.0 = прискорення.
func get_terrain_speed_modifier(pos: Vector2) -> float:
	var biome := _get_biome_at(pos)
	match biome:
		"forest":
			return 0.70 # -30% швидкість у лісі
		"swamp":
			return 0.50 # -50% швидкість у болоті
		"hill":
			return 0.60 # -40% швидкість на пагорбах
		"ravine":
			return 0.40 # -60% швидкість в ярах (багнах) або обхід
		_:
			return 1.0 # Степ/Курган — звичайна швидкість

## Повертає назву фракції, яка контролює точку pos (Voronoi за найближчим містом).
func get_faction_at(pos: Vector2) -> String:
	var cm = get_node_or_null("/root/CampaignManager")
	if not cm:
		return "none"
	var state = cm.get("world_state")
	if not state is Dictionary:
		return "none"
	var anchors: Array = state.get("influence_anchors", [])
	if anchors.is_empty():
		return "none"
	var best_faction := "none"
	var best_dist := INF
	for anchor: Dictionary in anchors:
		var pos_dict: Dictionary = anchor.get("pos", {})
		var ap := Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
		var d := pos.distance_to(ap)
		if d < best_dist:
			best_dist = d
			best_faction = str(anchor.get("faction", "none"))
	return best_faction
	
func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.dot(ab)
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _render_water(rivers: Array, lakes: Array) -> void:
	for river_pts in rivers:
		if river_pts.size() < 2:
			continue
		var line := Line2D.new()
		line.width = 6.0
		line.default_color = C_RIVER
		for pt in river_pts:
			line.add_point(Vector2(pt["x"], pt["y"]))
		_water_layer.add_child(line)

	for lake_pts in lakes:
		if lake_pts.size() < 3:
			continue
		var poly := Polygon2D.new()
		poly.color = C_LAKE
		var verts: PackedVector2Array = PackedVector2Array()
		for pt in lake_pts:
			verts.append(Vector2(pt["x"], pt["y"]))
		poly.polygon = verts
		_water_layer.add_child(poly)

func _render_roads(roads: Array) -> void:
	for road_pts in roads:
		if road_pts.size() < 2:
			continue
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = C_ROAD
		for pt in road_pts:
			line.add_point(Vector2(pt["x"], pt["y"]))
		_roads_layer.add_child(line)

func _render_locations(locations: Array) -> void:
	for loc_data in locations:
		var marker := Node2D.new()
		marker.set_script(load("res://src/world/LocationMarker.gd"))
		_locations_layer.add_child(marker)
		marker.setup(loc_data)
		marker.interaction_requested.connect(_on_location_clicked)
		# Спочатку приховуємо локацію, якщо вона не відкрита
		marker.visible = loc_data.get("discovered", false)

func _render_parties(parties: Array) -> void:
	for party_data in parties:
		if not party_data.get("alive", true):
			continue
		var ep := Node2D.new()
		ep.set_script(load("res://src/world/EnemyParty.gd"))
		_parties_layer.add_child(ep)
		ep.setup(party_data, _player_party)
		ep.encounter_reached.connect(_on_party_encounter)
		# Спочатку приховуємо загони ворогів (будуть показані при наближенні)
		ep.visible = false

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud(_state: Dictionary) -> void:
	_build_top_bar()
	_build_squad_panel()
	_build_encounter_dialog()
	_build_inventory_panel()
	_build_pause_label()
	_build_discovery_notification_ui()
	_build_onboarding_panel()

func _build_top_bar() -> void:
	const C_PANEL_BG := Color(0.996, 0.957, 0.792) # #FEF4CA
	const C_STROKE := Color(0.0, 0.0, 0.0, 0.6) # rgba(0,0,0,0.60)
	const C_TEXT_PRI := Color(0.0, 0.0, 0.0) # text/primary  → black
	const C_TEXT_SEC := Color(0.392, 0.388, 0.388) # text/secondary → #646363
	const C_CIRCLE := Color(0.6, 0.776, 1.0) # #99C6FF placeholder

	# TOP MENU — [spacer_l][left_panel][speed_days][right_panel][spacer_r]
	# flex-1 spacers тримають три панелі разом по центру
	var hbox_root := HBoxContainer.new()
	hbox_root.add_theme_constant_override("separation", 0)
	hbox_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hbox_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_bar_root = hbox_root
	_hud.add_child(_top_bar_root)

	# ── Spacer лівий ─────────────────────────────────────────────────────────────
	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar_root.add_child(spacer_l)

	# ── Ліва панель: py=5 px=25 gap=15 rounded-BL=20 border=1 ──────────────────
	var lp_st := StyleBoxFlat.new()
	lp_st.bg_color = C_PANEL_BG
	lp_st.border_color = C_STROKE
	lp_st.set_border_width_all(1)
	lp_st.corner_radius_bottom_left = 20
	lp_st.content_margin_top = 5.0; lp_st.content_margin_bottom = 5.0
	lp_st.content_margin_left = 25.0; lp_st.content_margin_right = 25.0

	var left_panel := PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", lp_st)
	left_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_bar_root.add_child(left_panel)

	var left_hbox := HBoxContainer.new()
	left_hbox.add_theme_constant_override("separation", 15)
	left_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_child(left_hbox)

	# ⛺️ Inventory 30×30
	# Button без тексту → min-size = 0, заповнює inv_box точно 30×30.
	# Emoji рендеримо окремою Label (MOUSE_FILTER_IGNORE) поверх кнопки.
	var inv_box := Control.new()
	inv_box.custom_minimum_size = Vector2(30, 30)
	inv_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inv_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inv_box.clip_contents = true
	left_hbox.add_child(inv_box)

	_inventory_btn = Button.new()
	_inventory_btn.focus_mode = Control.FOCUS_NONE
	_inventory_btn.text = ""
	_inventory_btn.pressed.connect(_toggle_inventory)
	_inventory_btn.mouse_entered.connect(func(): FloatingLabel.show_label(tr("UI_INVENTORY") + " [color=gray][I][/color]"))
	_inventory_btn.mouse_exited.connect(func(): FloatingLabel.hide_label())
	var inv_st_n := StyleBoxFlat.new(); inv_st_n.bg_color = Color(0, 0, 0, 0); inv_st_n.set_corner_radius_all(4)
	var inv_st_h := StyleBoxFlat.new(); inv_st_h.bg_color = Color(0, 0, 0, 0.1); inv_st_h.set_corner_radius_all(4)
	_inventory_btn.add_theme_stylebox_override("normal", inv_st_n)
	_inventory_btn.add_theme_stylebox_override("hover", inv_st_h)
	_inventory_btn.add_theme_stylebox_override("focus", inv_st_h)
	_inventory_btn.add_theme_stylebox_override("pressed", inv_st_h)
	_inventory_btn.add_theme_stylebox_override("disabled", inv_st_n)
	inv_box.add_child(_inventory_btn)
	_inventory_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var inv_label := Label.new()
	inv_label.text = "⛺️"
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inv_label.add_theme_font_size_override("font_size", 24)
	inv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inv_box.add_child(inv_label)

	# 🪙 Money — gap=5, icon 20×20, value w=35
	var money_hbox := HBoxContainer.new(); money_hbox.add_theme_constant_override("separation", 5)
	left_hbox.add_child(money_hbox)
	var coin_icon := Label.new(); coin_icon.text = "🪙"
	coin_icon.add_theme_font_size_override("font_size", 16)
	coin_icon.custom_minimum_size = Vector2(20, 20); coin_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_hbox.add_child(coin_icon)
	_thalers_label = Label.new(); _thalers_label.text = "0"
	_thalers_label.add_theme_font_size_override("font_size", 16)
	_thalers_label.add_theme_color_override("font_color", C_TEXT_PRI)
	_thalers_label.custom_minimum_size = Vector2(35, 0)
	money_hbox.add_child(_thalers_label)

	# 🍞 Food
	var food_hbox := HBoxContainer.new(); food_hbox.add_theme_constant_override("separation", 5)
	left_hbox.add_child(food_hbox)
	var bread_icon := Label.new(); bread_icon.text = "🍞"
	bread_icon.add_theme_font_size_override("font_size", 16)
	bread_icon.custom_minimum_size = Vector2(20, 20); bread_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	food_hbox.add_child(bread_icon)
	_provisions_label = Label.new(); _provisions_label.text = "0"
	_provisions_label.add_theme_font_size_override("font_size", 16)
	_provisions_label.add_theme_color_override("font_color", C_TEXT_PRI)
	_provisions_label.custom_minimum_size = Vector2(35, 0)
	food_hbox.add_child(_provisions_label)

	# 🩹 Bandage
	var bandage_hbox := HBoxContainer.new(); bandage_hbox.add_theme_constant_override("separation", 5)
	left_hbox.add_child(bandage_hbox)
	var bandage_icon := Label.new(); bandage_icon.text = "🩹"
	bandage_icon.add_theme_font_size_override("font_size", 16)
	bandage_icon.custom_minimum_size = Vector2(20, 20); bandage_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandage_hbox.add_child(bandage_icon)
	_bandages_label = Label.new(); _bandages_label.text = "0"
	_bandages_label.add_theme_font_size_override("font_size", 16)
	_bandages_label.add_theme_color_override("font_color", C_TEXT_PRI)
	_bandages_label.custom_minimum_size = Vector2(35, 0)
	bandage_hbox.add_child(_bandages_label)

	# ── Центральна колонка Speed → Days pill → frame_day (circle) ──────────────
	var speed_days := VBoxContainer.new()
	speed_days.add_theme_constant_override("separation", 0)
	speed_days.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_top_bar_root.add_child(speed_days)

	var sp := _build_speed_panel()
	speed_days.add_child(sp)
	_refresh_speed_btns()

	# Days pill: w=140 py=5 px=40 rounded-BL/BR=10 border=1 z=2
	var days_st := StyleBoxFlat.new()
	days_st.bg_color = C_PANEL_BG
	days_st.border_color = C_STROKE
	days_st.set_border_width_all(1)
	days_st.corner_radius_bottom_left = 10
	days_st.corner_radius_bottom_right = 10
	days_st.content_margin_top = 5.0; days_st.content_margin_bottom = 5.0
	days_st.content_margin_left = 40.0; days_st.content_margin_right = 40.0
	var days_pill := PanelContainer.new()
	days_pill.add_theme_stylebox_override("panel", days_st)
	days_pill.custom_minimum_size = Vector2(140, 0)
	days_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	days_pill.z_index = 2
	speed_days.add_child(days_pill)

	var days_hbox := HBoxContainer.new()
	days_hbox.add_theme_constant_override("separation", 5)
	days_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	days_pill.add_child(days_hbox)
	_time_phase_label = Label.new(); _time_phase_label.text = tr("TIME_DAY")
	_time_phase_label.add_theme_font_size_override("font_size", 16)
	_time_phase_label.add_theme_color_override("font_color", C_TEXT_PRI)
	days_hbox.add_child(_time_phase_label)
	_day_label = Label.new(); _day_label.text = "1"
	_day_label.add_theme_font_size_override("font_size", 16)
	_day_label.add_theme_color_override("font_color", C_TEXT_PRI)
	days_hbox.add_child(_day_label)

	# Frame day: 50px висота, overflow без кліпу — коло виходить за межі
	var frame_day := Control.new()
	frame_day.custom_minimum_size = Vector2(0, 50)
	frame_day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_day.z_index = 1
	speed_days.add_child(frame_day)

	var circle_st := StyleBoxFlat.new()
	circle_st.bg_color = C_CIRCLE
	circle_st.border_color = C_STROKE
	circle_st.set_border_width_all(1)
	circle_st.set_corner_radius_all(70)
	circle_st.content_margin_top = 5.0; circle_st.content_margin_bottom = 5.0
	circle_st.content_margin_left = 0.0; circle_st.content_margin_right = 0.0
	_day_circle_style = circle_st
	var day_circle := PanelContainer.new()
	day_circle.name = "DayCircle"
	day_circle.add_theme_stylebox_override("panel", circle_st)
	day_circle.anchor_left = 0.5; day_circle.anchor_right = 0.5
	day_circle.anchor_top = 1.0; day_circle.anchor_bottom = 1.0
	day_circle.offset_left = -70.0; day_circle.offset_right = 70.0
	day_circle.offset_top = -140.0; day_circle.offset_bottom = 0.0
	day_circle.pivot_offset = Vector2(70.0, 70.0)
	day_circle.rotation_degrees = 180.0
	_day_circle = day_circle
	frame_day.add_child(day_circle)

	var circle_vbox := VBoxContainer.new()
	circle_vbox.add_theme_constant_override("separation", 0)
	day_circle.add_child(circle_vbox)
	var sun_lbl := Label.new(); sun_lbl.text = "☀️"
	sun_lbl.add_theme_font_size_override("font_size", 28)
	sun_lbl.custom_minimum_size = Vector2(40, 40)
	sun_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sun_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle_vbox.add_child(sun_lbl)
	var circle_spacer := Control.new(); circle_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	circle_vbox.add_child(circle_spacer)
	var moon_lbl := Label.new(); moon_lbl.text = "🌙"
	moon_lbl.add_theme_font_size_override("font_size", 28)
	moon_lbl.custom_minimum_size = Vector2(40, 40)
	moon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle_vbox.add_child(moon_lbl)

	# ── Права панель: py=10 px=25 gap=15 rounded-BR=20 border=1 ────────────────
	var rp_st := StyleBoxFlat.new()
	rp_st.bg_color = C_PANEL_BG
	rp_st.border_color = C_STROKE
	rp_st.set_border_width_all(1)
	rp_st.corner_radius_bottom_right = 20
	rp_st.content_margin_top = 10.0; rp_st.content_margin_bottom = 10.0
	rp_st.content_margin_left = 25.0; rp_st.content_margin_right = 25.0
	var right_panel := PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", rp_st)
	right_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_bar_root.add_child(right_panel)

	var right_hbox := HBoxContainer.new()
	right_hbox.add_theme_constant_override("separation", 15)
	right_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_panel.add_child(right_hbox)
	var faction_labels: Array[Array] = [
		["crown", tr("FACTION_CROWN") + ":"],
		["sich", tr("FACTION_SICH") + ":"],
		["orda", tr("FACTION_ORDA")],
	]
	for pair in faction_labels:
		var key: String = pair[0]
		var name_text: String = pair[1]
		var f_hbox := HBoxContainer.new(); f_hbox.add_theme_constant_override("separation", 4)
		right_hbox.add_child(f_hbox)
		var name_lbl := Label.new(); name_lbl.text = name_text
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", C_TEXT_PRI)
		f_hbox.add_child(name_lbl)
		var val_lbl := Label.new(); val_lbl.text = "0"
		val_lbl.add_theme_font_size_override("font_size", 16)
		val_lbl.add_theme_color_override("font_color", C_TEXT_SEC)
		val_lbl.custom_minimum_size = Vector2(36, 0)
		f_hbox.add_child(val_lbl)
		_rep_labels[key] = val_lbl

	# ── Spacer правий ─────────────────────────────────────────────────────────────
	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar_root.add_child(spacer_r)

	call_deferred("_debug_topbar_heights")


func _debug_topbar_heights() -> void:
	await get_tree().process_frame
	var panels: Array[Array] = [
		["Ліва", _top_bar_root.get_child(1)],
		["Центр (speed)", _speed_panel],
		["Права", _top_bar_root.get_child(3)],
	]
	for row in panels:
		var label: String = row[0]
		var p: Control = row[1]
		var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
		var mt := sb.content_margin_top if sb else 0.0
		var mb := sb.content_margin_bottom if sb else 0.0
		var cmin := p.get_combined_minimum_size().y
		if Globals.DEBUG_LOG: print("[TopBar] %s: margin_top=%.0f  margin_bottom=%.0f  (sum=%.0f)  content_min=%.1f  size.y=%.1f" % [
			label, mt, mb, mt + mb, cmin, p.size.y])


func _make_hud_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.345, 0.333, 0.318))
	return lbl

func _make_separator() -> VSeparator:
	var sep := VSeparator.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.3, 0.25, 0.1, 0.5)
	sep.add_theme_stylebox_override("separator", st)
	return sep

func _build_squad_panel() -> void:
	_squad_panel = PanelContainer.new()
	_squad_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_squad_panel.offset_bottom = -10
	_squad_panel.offset_left = 10
	_squad_panel.custom_minimum_size = Vector2(200, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(C_DARK_BG.r, C_DARK_BG.g, C_DARK_BG.b, 0.88)
	st.border_color = Color(0.35, 0.28, 0.1)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 12; st.content_margin_right = 12
	st.content_margin_top = 10; st.content_margin_bottom = 10
	_squad_panel.add_theme_stylebox_override("panel", st)
	_squad_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud.add_child(_squad_panel)

func _build_pause_label() -> void:
	_pause_label = Label.new()
	_pause_label.text = "⏸  " + tr("UI_PAUSE").to_upper()
	_pause_label.add_theme_font_size_override("font_size", 36)
	_pause_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45, 0.9))
	_pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pause_label.offset_top = 72
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.visible = false
	_hud.add_child(_pause_label)

func _build_discovery_notification_ui() -> void:
	_discovery_panel = PanelContainer.new()
	_discovery_panel.anchor_left = 0.5
	_discovery_panel.anchor_right = 0.5
	_discovery_panel.anchor_top = 0.0
	_discovery_panel.anchor_bottom = 0.0
	_discovery_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_discovery_panel.grow_vertical = Control.GROW_DIRECTION_END
	_discovery_panel.offset_top = 160
	_discovery_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discovery_panel.modulate = Color(1, 1, 1, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.08, 0.04, 0.92)
	st.border_color = Color(0.75, 0.62, 0.22)
	st.set_border_width_all(2)
	st.set_corner_radius_all(5)
	st.content_margin_left = 20; st.content_margin_right = 20
	st.content_margin_top = 8; st.content_margin_bottom = 8
	_discovery_panel.add_theme_stylebox_override("panel", st)
	_discovery_label = RichTextLabel.new()
	_discovery_label.bbcode_enabled = true
	_discovery_label.fit_content = true
	_discovery_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_discovery_label.scroll_active = false
	_discovery_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discovery_label.custom_minimum_size = Vector2(200, 0)
	_discovery_panel.add_child(_discovery_label)
	_hud.add_child(_discovery_panel)

func _build_onboarding_panel() -> void:
	_onboarding_panel = PanelContainer.new()
	_onboarding_panel.anchor_left = 0.5
	_onboarding_panel.anchor_right = 0.5
	_onboarding_panel.anchor_top = 1.0
	_onboarding_panel.anchor_bottom = 1.0
	_onboarding_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_onboarding_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_onboarding_panel.offset_bottom = -80
	_onboarding_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.065, 0.055, 0.92)
	st.border_color = Color(0.48, 0.38, 0.13)
	st.set_border_width_all(2)
	st.set_corner_radius_all(5)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	_onboarding_panel.add_theme_stylebox_override("panel", st)
	_onboarding_label = RichTextLabel.new()
	_onboarding_label.bbcode_enabled = true
	_onboarding_label.fit_content = true
	_onboarding_label.scroll_active = false
	_onboarding_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_onboarding_panel.add_child(_onboarding_label)
	_onboarding_panel.modulate.a = 0.0
	_onboarding_panel.hide()
	_hud.add_child(_onboarding_panel)

func _show_onboarding_hint(key: String, bbcode_text: String) -> void:
	if _onboarding_shown.get(key, false):
		return
	_onboarding_shown[key] = true
	_current_hint_key = key
	if not is_instance_valid(_onboarding_panel):
		return
	_onboarding_label.text = bbcode_text
	if is_instance_valid(_onboarding_tween):
		_onboarding_tween.kill()
	_onboarding_panel.show()
	_onboarding_tween = create_tween()
	_onboarding_tween.tween_property(_onboarding_panel, "modulate:a", 1.0, 0.3)

func _dismiss_onboarding_hint(key: String) -> void:
	if _current_hint_key != key:
		return
	_current_hint_key = ""
	if not is_instance_valid(_onboarding_panel):
		return
	if is_instance_valid(_onboarding_tween):
		_onboarding_tween.kill()
	_onboarding_tween = create_tween()
	_onboarding_tween.tween_property(_onboarding_panel, "modulate:a", 0.0, 0.5)
	_onboarding_tween.tween_callback(_onboarding_panel.hide)

func _show_discovery_notification(bbcode_text: String) -> void:
	if not is_instance_valid(_discovery_panel):
		return
	if is_instance_valid(_discovery_tween):
		_discovery_tween.kill()
	_discovery_label.text = bbcode_text
	AudioManager.play_sfx("notification")
	_discovery_panel.modulate.a = 0.0
	_discovery_tween = create_tween()
	_discovery_tween.tween_property(_discovery_panel, "modulate:a", 1.0, 0.3)
	_discovery_tween.tween_interval(2.5)
	_discovery_tween.tween_property(_discovery_panel, "modulate:a", 0.0, 0.5)

func _build_encounter_dialog() -> void:
	_encounter_bg = ColorRect.new()
	_encounter_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_encounter_bg.color = Color(0, 0, 0, 0.6)
	_encounter_bg.visible = false
	_hud.add_child(_encounter_bg)

	var scene: PackedScene = load("res://src/ui/EncounterDialog.tscn")
	_encounter_dialog = scene.instantiate()
	_encounter_dialog.name = "EncounterDialog"
	(_encounter_dialog as EncounterDialog).attack_pressed.connect(_on_encounter_attack)
	(_encounter_dialog as EncounterDialog).avoid_pressed.connect(_on_encounter_avoid)
	(_encounter_dialog as EncounterDialog).talk_pressed.connect(_on_encounter_talk)
	_hud.add_child(_encounter_dialog)

	_location_dialog = Control.new()
	_location_dialog.name = "LocationDialog"
	_location_dialog.visible = false
	_hud.add_child(_location_dialog)

# ── Оновлення HUD ─────────────────────────────────────────────────────────────

func _update_hud(state: Dictionary) -> void:
	if _day_label:
		_day_label.text = "%d" % state.get("day", 1)
	if _thalers_label:
		_thalers_label.text = "%d" % state.get("thalers", 0)
	if _provisions_label:
		_provisions_label.text = "%d" % state.get("provisions", 0)
	if _bandages_label:
		_bandages_label.text = "%d" % state.get("bandages", 0)
	var rep: Dictionary = state.get("faction_rep", {})
	for f in _rep_labels:
		_rep_labels[f].text = "%d" % rep.get(f, 0)
	_refresh_squad_panel(state)

func _refresh_squad_panel(_state: Dictionary) -> void:
	for child in _squad_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_squad_panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("UI_SQUAD")
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(title)

	# Читаємо козаків зі сцени Battle якщо є squad у world_state
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return
	var squad: Array = cm.world_state.get("squad", [])
	if squad.is_empty():
		# Перша гра — покажемо дефолтні імена
		for n in ["Ничипір", "Гаврило", "Тимофій", "Панько"]:
			var lbl := Label.new()
			lbl.text = "• " + n
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
			vbox.add_child(lbl)
		return

	for u in squad:
		var hp_cur: int = u.get("hp", 0)
		var hp_max: int = u.get("max_hp", 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = "• " + str(u.get("name", "?"))
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.55))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var hp_lbl := Label.new()
		hp_lbl.text = "%d/%d" % [hp_cur, hp_max]
		hp_lbl.add_theme_font_size_override("font_size", 11)
		var hp_ratio := float(hp_cur) / float(hp_max)
		var hp_color := Color(0.3, 0.9, 0.3) if hp_ratio > 0.6 else (Color(0.9, 0.7, 0.1) if hp_ratio > 0.3 else Color(0.9, 0.2, 0.2))
		hp_lbl.add_theme_color_override("font_color", hp_color)
		row.add_child(hp_lbl)

# ── Показ діалогу зустрічі ────────────────────────────────────────────────────

func _show_encounter_dialog(entity: Node2D) -> void:
	_player_party.stop()
	_active_encounter = entity
	_encounter_bg.visible = true

	var cm := get_node_or_null("/root/CampaignManager")
	var faction: String = entity.get("faction") if "faction" in entity else "none"
	var options: Array = cm.get_encounter_options(faction) if cm else ["attack", "avoid"]

	var enc_name: String
	if "loc_name" in entity:
		enc_name = str(entity.get("loc_name"))
	elif "unit_paths" in entity:
		var unit_paths: Array = entity.get("unit_paths")
		enc_name = _faction_label(faction) + " (%d)" % unit_paths.size()
	else:
		enc_name = tr("UI_ENCOUNTER")

	var config: Dictionary = entity.get_battle_config() if entity.has_method("get_battle_config") else {}
	var reward: int = config.get("reward_thalers", 0)

	(_encounter_dialog as EncounterDialog).show_for(enc_name, reward, options)

func _show_location_dialog(marker: Node2D) -> void:
	_player_party.stop()
	_show_onboarding_hint("settlement", "[color=gold]" + tr("HINT_SETTLEMENT") + "[/color]")
	_active_encounter = marker
	_encounter_bg.visible = true

	for child in _location_dialog.get_children():
		child.queue_free()
	_location_dialog.visible = true

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_location_dialog.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.06, 0.055, 0.045)
	pst.border_color = Color(0.35, 0.35, 0.35)
	pst.set_border_width_all(2)
	pst.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 24)
	mc.add_theme_constant_override("margin_right", 24)
	mc.add_theme_constant_override("margin_top", 20)
	mc.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(mc)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	mc.add_child(vbox)

	# Заголовок
	var title_lbl := Label.new()
	title_lbl.text = str(marker.get("loc_name"))
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.55))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var status_lbl := Label.new()
	var _is_cleared: bool = bool(marker.get("cleared"))
	status_lbl.text = _cleared_desc(str(marker.get("loc_type"))) if _is_cleared else tr("MAP_SETTLEMENT_OPEN")
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_lbl)

	# ── Торгівля ─────────────────────────────────────────────────────────────
	var cm := get_node_or_null("/root/CampaignManager")
	if cm:
		var sep := HSeparator.new()
		var sep_st := StyleBoxFlat.new()
		sep_st.bg_color = Color(0.35, 0.28, 0.1, 0.5)
		sep.add_theme_stylebox_override("separator", sep_st)
		vbox.add_child(sep)

		var trade_title := Label.new()
		trade_title.text = tr("MAP_TRADE")
		trade_title.add_theme_font_size_override("font_size", 15)
		trade_title.add_theme_color_override("font_color", C_GOLD)
		trade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(trade_title)

		var thalers: int = cm.world_state.get("thalers", 0)
		var squad: Array = cm.world_state.get("squad", [])

		# Купити провізію
		var prov_row := HBoxContainer.new()
		prov_row.add_theme_constant_override("separation", 8)
		vbox.add_child(prov_row)
		var prov_lbl := Label.new()
		prov_lbl.text = tr("MAP_PROVISIONS") + " ×%d" % TRADE_PROV_PACK
		prov_lbl.add_theme_font_size_override("font_size", 13)
		prov_lbl.add_theme_color_override("font_color", Color(0.82, 0.76, 0.55))
		prov_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prov_row.add_child(prov_lbl)
		var prov_btn := _make_trade_btn("%d 💰" % TRADE_PROV_COST, thalers >= TRADE_PROV_COST)
		prov_btn.pressed.connect(_on_trade_buy_provisions)
		prov_row.add_child(prov_btn)

		# Лікування загону
		var injured_count: int = squad.filter(
			func(u: Dictionary) -> bool: return u.get("hp", 0) < u.get("max_hp", 1)
		).size()
		var heal_cost := injured_count * TRADE_HEAL_COST
		var heal_row := HBoxContainer.new()
		heal_row.add_theme_constant_override("separation", 8)
		vbox.add_child(heal_row)
		var heal_lbl := Label.new()
		heal_lbl.text = tr("MAP_HEALING") + " (" + (tr("MAP_INJURED") % injured_count) + ")" if injured_count > 0 else tr("MAP_HEALING") + " (" + tr("MAP_ALL_HEALTHY") + ")"
		heal_lbl.add_theme_font_size_override("font_size", 13)
		heal_lbl.add_theme_color_override("font_color", Color(0.82, 0.76, 0.55))
		heal_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heal_row.add_child(heal_lbl)
		var heal_btn := _make_trade_btn("%d 💰" % heal_cost, injured_count > 0 and thalers >= heal_cost)
		heal_btn.pressed.connect(_on_trade_heal_squad)
		heal_row.add_child(heal_btn)

		# ── Крамниця ──────────────────────────────────────────────────────────
		var shop_inventory: Array = cm.world_state.get("shop_inventory", [])
		if not shop_inventory.is_empty():
			var sep_shop := HSeparator.new()
			var sep_shop_st := StyleBoxFlat.new()
			sep_shop_st.bg_color = Color(0.35, 0.28, 0.1, 0.5)
			sep_shop.add_theme_stylebox_override("separator", sep_shop_st)
			vbox.add_child(sep_shop)

			var shop_title := Label.new()
			shop_title.text = tr("MAP_SHOP")
			shop_title.add_theme_font_size_override("font_size", 15)
			shop_title.add_theme_color_override("font_color", C_GOLD)
			shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(shop_title)

			var type_names_shop := {"weapon": tr("SLOT_WEAPON").to_lower(), "armor": tr("STAT_ARMOR").to_lower(), "helm": tr("STAT_HELMET").to_lower()}
			for shop_item: Dictionary in shop_inventory:
				var item_name: String = tr(shop_item.get("name", "?"))
				var item_type: String = shop_item.get("type", "")
				var buy_price: int = shop_item.get("buy_price", 0)
				var type_str: String = type_names_shop.get(item_type, item_type)

				var shop_row := HBoxContainer.new()
				shop_row.add_theme_constant_override("separation", 8)
				vbox.add_child(shop_row)

				var shop_icon_tex: Texture2D = InventoryManager.get_item_icon(shop_item.get("id", ""))
				if shop_icon_tex:
					var shop_icon_rect := TextureRect.new()
					shop_icon_rect.texture = shop_icon_tex
					shop_icon_rect.custom_minimum_size = Vector2(32, 32)
					shop_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					shop_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					shop_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					shop_row.add_child(shop_icon_rect)

				var item_lbl := Label.new()
				item_lbl.text = "%s (%s)" % [item_name, type_str]
				item_lbl.add_theme_font_size_override("font_size", 13)
				item_lbl.add_theme_color_override("font_color", Color(0.82, 0.76, 0.55))
				item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				shop_row.add_child(item_lbl)

				var item_ref := shop_item
				var buy_btn := _make_trade_btn("%d 💰" % buy_price, thalers >= buy_price)
				buy_btn.pressed.connect(func() -> void: _on_buy_shop_item(item_ref))
				shop_row.add_child(buy_btn)

		# ── Рекрутування ─────────────────────────────────────────────────────
		const MAX_SQUAD := 4
		if squad.size() < MAX_SQUAD:
			var loc_id_v: Variant = marker.get("loc_id")
			var loc_id: String = loc_id_v if loc_id_v is String else ""
			if not _recruits_cache.has(loc_id):
				_recruits_cache[loc_id] = _generate_recruit_candidates()
			var recruits: Array = _recruits_cache[loc_id]

			var sep2 := HSeparator.new()
			var sep2_st := StyleBoxFlat.new()
			sep2_st.bg_color = Color(0.35, 0.28, 0.1, 0.5)
			sep2.add_theme_stylebox_override("separator", sep2_st)
			vbox.add_child(sep2)

			var rec_title := Label.new()
			rec_title.text = tr("MAP_HIRING") + " (%d/%d)" % [squad.size(), MAX_SQUAD]
			rec_title.add_theme_font_size_override("font_size", 15)
			rec_title.add_theme_color_override("font_color", C_GOLD)
			rec_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(rec_title)

			for i: int in range(recruits.size()):
				var r: Dictionary = recruits[i]
				var rec_row := HBoxContainer.new()
				rec_row.add_theme_constant_override("separation", 8)
				vbox.add_child(rec_row)

				var rec_lbl := Label.new()
				rec_lbl.text = "%s  ❤%d  %s%d%%" % [tr(r.get("name", "?")), r.get("max_hp", 40), tr("STAT_MORALE_SHORT"), r.get("morale", 80)]
				rec_lbl.add_theme_font_size_override("font_size", 12)
				rec_lbl.add_theme_color_override("font_color", Color(0.78, 0.74, 0.55))
				rec_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rec_row.add_child(rec_lbl)

				var cost: int = r.get("cost", 60)
				var hire_btn := _make_trade_btn("%d 💰" % cost, thalers >= cost)
				hire_btn.pressed.connect(func(): _on_hire_recruit(loc_id, i))
				rec_row.add_child(hire_btn)

	# Кнопки дій
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)

	if not marker.get("cleared"):
		var btn_attack := _make_dialog_btn(tr("UI_ATTACK"), Color(0.35, 0.08, 0.08))
		btn_attack.pressed.connect(func() -> void:
			if marker.has_method("get_battle_config"):
				var config: Dictionary = marker.get_battle_config()
				_hide_encounter_dialog()
				var cm_atk := get_node_or_null("/root/CampaignManager")
				if cm_atk and not config.is_empty():
					cm_atk.start_battle(config)
		)
		btn_box.add_child(btn_attack)

	var btn_leave := _make_dialog_btn(tr("UI_LEAVE"), Color(0.15, 0.15, 0.15))
	btn_leave.pressed.connect(_hide_encounter_dialog)
	btn_box.add_child(btn_leave)

func _make_trade_btn(text: String, enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 34)
	btn.disabled = not enabled
	var active_col := Color(0.18, 0.28, 0.12)
	var dim_col := Color(0.12, 0.12, 0.12, 0.7)
	var normal := StyleBoxFlat.new()
	normal.bg_color = active_col if enabled else dim_col
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = active_col.lightened(0.25)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.5))
	return btn

func _on_trade_buy_provisions() -> void:
	_dismiss_onboarding_hint("low_food")
	_dismiss_onboarding_hint("settlement")
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm or not is_instance_valid(_active_encounter):
		return
	if cm.world_state.get("thalers", 0) < TRADE_PROV_COST:
		return
	cm.world_state["thalers"] -= TRADE_PROV_COST
	AudioManager.play_sfx("buy")
	cm.world_state["provisions"] = cm.world_state.get("provisions", 0) + TRADE_PROV_PACK
	_update_hud(cm.world_state)
	_show_location_dialog(_active_encounter)

func _on_trade_heal_squad() -> void:
	_dismiss_onboarding_hint("wounded")
	_dismiss_onboarding_hint("settlement")
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm or not is_instance_valid(_active_encounter):
		return
	var squad: Array = cm.world_state.get("squad", [])
	var injured_count: int = squad.filter(
		func(u: Dictionary) -> bool: return u.get("hp", 0) < u.get("max_hp", 1)
	).size()
	var cost := injured_count * TRADE_HEAL_COST
	if injured_count == 0 or cm.world_state.get("thalers", 0) < cost:
		return
	cm.world_state["thalers"] -= cost
	AudioManager.play_sfx("heal")
	for u: Dictionary in squad:
		u["hp"] = u.get("max_hp", u.get("hp", 1))
	_update_hud(cm.world_state)
	if is_instance_valid(_inventory_panel) and _inventory_panel.visible:
		_refresh_inventory_panel()
	_show_location_dialog(_active_encounter)

const _RECRUIT_NAMES: Array[String] = [
	"Іван", "Петро", "Михайло", "Семен", "Данило", "Грицько", "Хома", "Тарас",
	"Остап", "Назар", "Кирило", "Панас", "Юхим", "Андрій", "Яків", "Степан",
	"Кость", "Денис", "Лесько", "Охрім", "Роман", "Клим", "Пилип", "Улас", "Сава"
]

func _generate_recruit_candidates() -> Array:
	var pool := _RECRUIT_NAMES.duplicate()
	pool.shuffle()
	var result: Array = []
	for i: int in range(mini(3, pool.size())):
		var max_hp: int = randi_range(36, 52)
		result.append({
			"name": tr(pool[i]),
			"hp": max_hp,
			"max_hp": max_hp,
			"morale": randi_range(70, 100),
			"level": 1,
			"xp": 0,
			"cost": randi_range(80, 120)
		})
	return result

func _on_buy_shop_item(item: Dictionary) -> void:
	_dismiss_onboarding_hint("settlement")
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm or not is_instance_valid(_active_encounter):
		return
	var buy_price: int = item.get("buy_price", 0)
	if cm.world_state.get("thalers", 0) < buy_price:
		return
	cm.world_state["thalers"] -= buy_price
	AudioManager.play_sfx("buy")
	InventoryManager.add_item(cm.world_state, item.duplicate())
	_update_hud(cm.world_state)
	if is_instance_valid(_inventory_panel) and _inventory_panel.visible:
		_refresh_inventory_panel()
	_show_location_dialog(_active_encounter)

func _on_hire_recruit(loc_id: String, recruit_idx: int) -> void:
	_dismiss_onboarding_hint("settlement")
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm or not is_instance_valid(_active_encounter):
		return
	if not _recruits_cache.has(loc_id):
		return
	var recruits: Array = _recruits_cache[loc_id]
	if recruit_idx >= recruits.size():
		return
	var r: Dictionary = recruits[recruit_idx]
	var cost: int = r.get("cost", 60)
	if cm.world_state.get("thalers", 0) < cost:
		return
	cm.world_state["thalers"] -= cost
	AudioManager.play_sfx("hire")
	var squad: Array = cm.world_state.get("squad", [])
	squad.append({
		"name": r.get("name", "Козак"),
		"hp": r.get("hp", 40),
		"max_hp": r.get("max_hp", 40),
		"morale": r.get("morale", 80),
		"level": 1,
		"xp": 0,
		"data_path": "",
		"weapon_resource_path": "res://src/resources/combat/weapons/saber.tres",
		"armor_path": "",
		"helm_path": ""
	})
	cm.world_state["squad"] = squad
	recruits.remove_at(recruit_idx)
	_update_hud(cm.world_state)
	if is_instance_valid(_inventory_panel) and _inventory_panel.visible:
		_refresh_inventory_panel()
	_show_location_dialog(_active_encounter)

func _cleared_desc(loc_type: String) -> String:
	match loc_type:
		"bandit_camp": return tr("CLEARED_BANDIT_CAMP")
		"tatar_camp": return tr("CLEARED_TATAR_CAMP")
		"ruins": return tr("CLEARED_RUINS")
		"crown_outpost": return tr("CLEARED_CROWN_OUTPOST")
		"fortress": return tr("CLEARED_FORTRESS")
		_: return tr("MAP_LOCATION_CLEARED")

func _faction_label(faction: String) -> String:
	match faction:
		"orda": return tr("FACTION_ORDA_PLURAL")
		"crown": return tr("FACTION_CROWN_PLURAL")
		"sich": return tr("FACTION_SICH_PLURAL")
		_: return tr("FACTION_BANDITS")

func _make_dialog_btn(text: String, base_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 42)
	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate(); hover.bg_color = base_color.lightened(0.2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_font_size_override("font_size", 15)
	return btn

func _hide_encounter_dialog() -> void:
	_dismiss_onboarding_hint("enemy")
	_encounter_bg.visible = false
	(_encounter_dialog as EncounterDialog).hide_dialog()
	# Додаємо cooldown для cleared-локацій щоб _check_all_encounters не тригерив одразу
	if _location_dialog.visible and is_instance_valid(_active_encounter):
		_encounter_cooldowns[_active_encounter] = 6.0
	_location_dialog.visible = false
	_active_encounter = null

# ── Обробники подій ───────────────────────────────────────────────────────────

func _on_encounter_attack() -> void:
	if not _active_encounter:
		return
	var faction: String = str(_active_encounter.get("faction")) if "faction" in _active_encounter else "none"
	var cm := get_node_or_null("/root/CampaignManager")
	
	# Напад на нейтральну або союзну фракцію робить їх ворогами
	if cm and faction != "none":
		var rep = cm.get_rep(faction)
		if rep > -20:
			cm.change_rep(faction, -35) # Знижуємо до ворожого стану (-20 і нижче)
			
	var config: Dictionary = _active_encounter.call("get_battle_config") if _active_encounter.has_method("get_battle_config") else {}
	_hide_encounter_dialog()
	if cm and not config.is_empty():
		cm.start_battle(config)

func _on_encounter_avoid() -> void:
	if is_instance_valid(_active_encounter):
		_encounter_cooldowns[_active_encounter] = 5.0
		if _active_encounter.has_method("set_process"):
			_active_encounter.set_process(world_ticking)
	_hide_encounter_dialog()

func _on_encounter_talk() -> void:
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm or not _active_encounter:
		return
	var faction: String = str(_active_encounter.get("faction")) if "faction" in _active_encounter else "none"
	cm.change_rep(faction, 5)
	if is_instance_valid(_active_encounter):
		_encounter_cooldowns[_active_encounter] = 10.0
		if _active_encounter.has_method("set_process"):
			_active_encounter.set_process(world_ticking)
	_hide_encounter_dialog()
	_update_hud(cm.world_state)

func _on_party_encounter(party: Node2D) -> void:
	if party in _encounter_cooldowns:
		return
	_show_onboarding_hint("enemy", "[color=gold]" + tr("HINT_ENEMY") + "[/color]")
	_show_encounter_dialog(party)

func _on_location_clicked(marker: Node2D) -> void:
	if _player_party.position.distance_to(marker.position) > _player_party.get_interaction_radius() * 1.5:
		_player_party.set_target(marker.position)
		_nav_target_marker = marker
		return
	_nav_target_marker = null
	if marker.get("cleared") or not _is_location_hostile(marker):
		_show_location_dialog(marker)
		return
	_show_encounter_dialog(marker)

func _on_player_movement_started() -> void:
	_dismiss_onboarding_hint("move")
	if not _is_paused:
		world_ticking = true
	_camera_follows_player = true
	_set_parties_ticking(world_ticking)

func _on_player_movement_stopped() -> void:
	world_ticking = false
	_set_parties_ticking(false)
	_save_player_pos()
	_check_all_encounters()
	if _active_encounter == null and is_instance_valid(_nav_target_marker):
		var dist := _player_party.position.distance_to(_nav_target_marker.position)
		var target := _nav_target_marker
		_nav_target_marker = null
		if dist <= _player_party.get_interaction_radius():
			if target.get("cleared") or not _is_location_hostile(target):
				_show_location_dialog(target)
			else:
				_show_encounter_dialog(target)
	else:
		_nav_target_marker = null

func _set_parties_ticking(ticking: bool) -> void:
	for child in _parties_layer.get_children():
		if is_instance_valid(child) and child.has_method("set_process"):
			child.set_process(ticking)

func _save_player_pos() -> void:
	var cm := get_node_or_null("/root/CampaignManager")
	if cm:
		cm.world_state["player_pos"] = {"x": _player_party.position.x, "y": _player_party.position.y}

func _apply_hunger_effects(cm: Node) -> void:
	var squad: Array = cm.world_state.get("squad", [])
	var deserters: Array[String] = []
	for unit in squad:
		var morale: int = unit.get("morale", 100)
		if morale == 0:
			if randf() < 0.5:
				deserters.append(str(unit.get("name", "Козак")))
		else:
			unit["morale"] = max(0, morale - 20)

	for unit_name in deserters:
		cm.world_state["squad"] = cm.world_state["squad"].filter(
			func(u: Dictionary) -> bool: return u.get("name") != unit_name
		)
		_show_hud_notification(tr("MAP_DESERTED") % unit_name)

	if not deserters.is_empty():
		_refresh_squad_panel(cm.world_state)
		if cm.world_state.get("squad", []).is_empty():
			_show_game_over()
			return

func _show_game_over() -> void:
	world_ticking = false
	_set_parties_ticking(false)
	if is_instance_valid(_player_party):
		_player_party.stop()

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	_hud.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.06, 0.055, 0.045)
	pst.border_color = Color(0.75, 0.62, 0.22)
	pst.set_border_width_all(2)
	pst.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 24)
	mc.add_theme_constant_override("margin_right", 24)
	mc.add_theme_constant_override("margin_top", 24)
	mc.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(mc)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	mc.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = tr("GAME_OVER_TITLE")
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.1))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = tr("GAME_OVER_DESERT")
	msg_lbl.add_theme_font_size_override("font_size", 15)
	msg_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.55))
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn := _make_dialog_btn(tr("UI_MAIN_MENU"), Color(0.15, 0.12, 0.08))
	btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")
	)
	btn_row.add_child(btn)

func _show_hud_notification(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.95, 0.3, 0.1))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 90
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)

# ── Рух гравця по кліку та камера ─────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging_cam = event.pressed
			if _is_dragging_cam:
				_camera_follows_player = false
			get_viewport().set_input_as_handled()
			return
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(0.05)
			get_viewport().set_input_as_handled()
			return
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-0.05)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
				get_viewport().set_input_as_handled()
				return
			KEY_1:
				_set_speed(1)
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				_set_speed(2)
				get_viewport().set_input_as_handled()
				return
			KEY_I:
				_toggle_inventory()
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and _is_dragging_cam:
		if _camera:
			_camera.position -= event.relative / _camera.zoom.x
			_clamp_camera_position()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if Globals.DEBUG_LOG: print("[WorldMap] LMB click detected")
	if _encounter_dialog.visible or _location_dialog.visible:
		if Globals.DEBUG_LOG: print("[WorldMap] blocked by encounter dialog")
		return
	var mouse_vp := get_viewport().get_mouse_position()
	if _is_click_on_hud(mouse_vp):
		if Globals.DEBUG_LOG: print("[WorldMap] blocked by HUD at ", mouse_vp)
		return
	if not is_instance_valid(_player_party):
		print("[WorldMap] ERROR: _player_party is null!")
		return
	var world_pos := get_global_mouse_position()
	world_pos.x = clamp(world_pos.x, 0.0, MAP_W)
	world_pos.y = clamp(world_pos.y, 0.0, MAP_H)

	# Перевіряємо чи клікнули на якогось ворога
	var clicked_enemy: Node2D = null
	var min_dist: float = 32.0 # Радіус кліку на іконку ворога
	for child in _parties_layer.get_children():
		if is_instance_valid(child) and child.get("alive") != false:
			var d := world_pos.distance_to(child.position)
			if d < min_dist:
				clicked_enemy = child
				min_dist = d

	if clicked_enemy:
		if Globals.DEBUG_LOG: print("[WorldMap] Enemy clicked! Pursuing: ", clicked_enemy)
		_player_party.set_pursuit_target(clicked_enemy)
	else:
		if Globals.DEBUG_LOG: print("[WorldMap] set_target -> ", world_pos, " (player at ", _player_party.position, ")")
		_player_party.set_target(world_pos)

	get_viewport().set_input_as_handled()

func _is_click_on_hud(vp_pos: Vector2) -> bool:
	if is_instance_valid(_top_bar_root) and _top_bar_root.get_global_rect().has_point(vp_pos):
		return true
	for ctrl in [_squad_panel, _inventory_panel] as Array[Control]:
		if is_instance_valid(ctrl) and ctrl.visible:
			if ctrl.get_global_rect().has_point(vp_pos):
				return true
	return false

func _process(delta: float) -> void:
	# Скролінг клавіатурою (WASD або стрілочки)
	var cam_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		cam_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		cam_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		cam_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		cam_dir.x += 1.0

	if cam_dir != Vector2.ZERO:
		_camera_follows_player = false
		if _camera:
			_camera.position += cam_dir.normalized() * 700.0 * delta / _camera.zoom.x

	# Камера слідує за гравцем, якщо увімкнено
	elif _camera_follows_player and _camera and _player_party:
		_camera.position = _camera.position.lerp(_player_party.position, 0.08)

	_clamp_camera_position()

	# Просте виявлення зустрічей (замість сигналів з PlayerParty._check_encounters)
	if world_ticking:
		_check_all_encounters()

	# Просування доби та дня — лише під час руху
	if world_ticking and _player_party and _player_party.is_moving:
		var cm := get_node_or_null("/root/CampaignManager")
		if cm:
			_day_time += 150.0 * _speed_multiplier * delta # PlayerParty.SPEED
			while _day_time >= PIXELS_PER_DAY:
				_day_time -= PIXELS_PER_DAY
				cm.world_state["day"] = cm.world_state.get("day", 1) + 1
				var prov: int = cm.world_state.get("provisions", 0)
				cm.world_state["provisions"] = max(0, prov - 1)
				if cm.world_state["provisions"] == 0:
					_apply_hunger_effects(cm)
				elif cm.world_state["provisions"] <= 2:
					if not _encounter_dialog.visible and not _location_dialog.visible:
						_show_onboarding_hint("low_food", "[color=orange]" + tr("HINT_LOW_FOOD") + "[/color]")
				_update_hud(cm.world_state)

	# Cooldown зустрічей
	for entity in _encounter_cooldowns.keys():
		_encounter_cooldowns[entity] -= delta
		if _encounter_cooldowns[entity] <= 0.0:
			_encounter_cooldowns.erase(entity)

	_update_day_night(delta)

func _update_day_night(delta: float) -> void:
	var phase: float = _day_time / PIXELS_PER_DAY # 0.0 → 1.0

	# Фази: 0–0.57 день, 0.57–0.64 захід, 0.64–0.93 ніч, 0.93–1.0 схід
	var mod_color: Color
	var base_reveal: float
	if phase < 0.57:
		mod_color = C_DAY
		base_reveal = FOG_REVEAL_DAY
	elif phase < 0.64:
		var t := (phase - 0.57) / 0.07
		mod_color = C_DAY.lerp(C_NIGHT, t)
		base_reveal = lerpf(FOG_REVEAL_DAY, FOG_REVEAL_NIGHT, t)
	elif phase < 0.93:
		mod_color = C_NIGHT
		base_reveal = FOG_REVEAL_NIGHT
	else:
		var t := (phase - 0.93) / 0.07
		mod_color = C_NIGHT.lerp(C_DAY, t)
		base_reveal = lerpf(FOG_REVEAL_NIGHT, FOG_REVEAL_DAY, t)

	if is_instance_valid(_canvas_modulate):
		_canvas_modulate.color = mod_color

	# Обертання: полудень (phase=0.285) → 180° (☀️ внизу), північ (phase=0.785) → 360° (🌙 внизу)
	if is_instance_valid(_day_circle):
		_day_circle.rotation_degrees = 180.0 + (phase - 0.285) * 360.0

	# Колір кола: Blue-300 (#99C6FF) вдень → Blue-950 (#002C5B) вночі
	if is_instance_valid(_day_circle_style):
		const C_BLUE_300 := Color(0.6, 0.776, 1.0) # #99C6FF
		const C_BLUE_950 := Color(0.0, 0.173, 0.357) # #002C5B
		var circle_color: Color
		if phase < 0.57:
			circle_color = C_BLUE_300
		elif phase < 0.64:
			circle_color = C_BLUE_300.lerp(C_BLUE_950, (phase - 0.57) / 0.07)
		elif phase < 0.93:
			circle_color = C_BLUE_950
		else:
			circle_color = C_BLUE_950.lerp(C_BLUE_300, (phase - 0.93) / 0.07)
		_day_circle_style.bg_color = circle_color


	if is_instance_valid(_torch_light):
		var torch_energy: float
		if phase < 0.57:
			torch_energy = 0.0
		elif phase < 0.64:
			torch_energy = lerpf(0.0, 1.2, (phase - 0.57) / 0.07)
		elif phase < 0.93:
			torch_energy = 1.2
		else:
			torch_energy = lerpf(1.2, 0.0, (phase - 0.93) / 0.07)
		_torch_light.energy = torch_energy

	# Розраховуємо цільовий радіус відповідно до поточного біому під гравцем
	if is_instance_valid(_player_party):
		var biome := _get_biome_at(_player_party.position)
		var modifier := _get_biome_modifier(biome)
		_current_target_reveal_radius = base_reveal * modifier
		
		# Плавна інтерполяція (lerp) радіуса видимості (приблизно 1.0 сек до 98% цілі)
		_current_actual_reveal_radius = lerpf(_current_actual_reveal_radius, _current_target_reveal_radius, 4.0 * delta)
		
		# Оновлюємо видимість ворогів та прихованих локацій на кожному кадрі
		_update_entity_visibility_and_discovery()
		
		# Перевірка необхідності оновлення сітки туману війни (оптимізація продуктивності)
		var dist_moved := _last_fog_update_pos.distance_to(_player_party.position)
		var radius_diff := absf(_last_fog_update_radius - _current_actual_reveal_radius)
		
		if dist_moved > 2.0 or radius_diff > 1.0 or _last_fog_update_radius == 0.0:
			_last_fog_update_pos = _player_party.position
			_last_fog_update_radius = _current_actual_reveal_radius
			_update_fog_grid(_player_party.position, _current_actual_reveal_radius)

		var pp := _player_party.position
		var rr := _current_actual_reveal_radius
		if is_instance_valid(_fog_rect) and _fog_rect.material is ShaderMaterial:
			var m := _fog_rect.material as ShaderMaterial
			m.set_shader_parameter("player_pos", pp)
			m.set_shader_parameter("reveal_radius", rr)
		if is_instance_valid(_fog_cloud_rect) and _fog_cloud_rect.material is ShaderMaterial:
			var m := _fog_cloud_rect.material as ShaderMaterial
			m.set_shader_parameter("player_pos", pp)
			m.set_shader_parameter("reveal_radius", rr)

func _clamp_camera_position() -> void:
	if not _camera: return
	var v_size = get_viewport_rect().size / _camera.zoom.x
	var half_w = v_size.x / 2.0
	var half_h = v_size.y / 2.0
	
	if MAP_W > v_size.x:
		_camera.position.x = clamp(_camera.position.x, half_w, MAP_W - half_w)
	else:
		_camera.position.x = MAP_W / 2.0
		
	if MAP_H > v_size.y:
		_camera.position.y = clamp(_camera.position.y, half_h, MAP_H - half_h)
	else:
		_camera.position.y = MAP_H / 2.0

func _zoom_camera(change: float) -> void:
	if not _camera: return
	var v_size = get_viewport_rect().size
	var min_z = max(v_size.x / MAP_W, v_size.y / MAP_H)
	var target_z = clamp(_camera.zoom.x + change, min_z, 2.2)
	
	_camera_follows_player = false
	var tw = create_tween()
	tw.tween_property(_camera, "zoom", Vector2(target_z, target_z), 0.15).set_trans(Tween.TRANS_SINE)

func _set_speed(n: int) -> void:
	_is_paused = false
	_speed_multiplier = n
	if is_instance_valid(_player_party):
		_player_party.speed_multiplier = n
	_refresh_speed_btns()

func _toggle_pause() -> void:
	if not _is_paused:
		_prev_speed = _speed_multiplier
		_is_paused = true
		if is_instance_valid(_player_party):
			_player_party.stop()
		world_ticking = false
		_set_parties_ticking(false)
		_refresh_speed_btns()
	else:
		_set_speed(_prev_speed)

func _build_speed_panel() -> Control:
	var panel := PanelContainer.new()
	_speed_panel = panel
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.996, 0.957, 0.792) # #FEF4CA
	st.border_color = Color(0.0, 0.0, 0.0, 0.6)
	st.set_border_width_all(1)
	st.corner_radius_bottom_left = 15
	st.corner_radius_bottom_right = 15
	st.content_margin_left = 25.0
	st.content_margin_right = 25.0
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", st)
	panel.z_index = 3 # вище за days_pill(2) і frame_day(1) — поверх кола

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	if ResourceLoader.exists("res://assets/sprites/ui/speed_pause_default.svg"):
		_tex_pause_default = load("res://assets/sprites/ui/speed_pause_default.svg")
	if ResourceLoader.exists("res://assets/sprites/ui/speed_pause_hover.svg"):
		_tex_pause_hover = load("res://assets/sprites/ui/speed_pause_hover.svg")
	if ResourceLoader.exists("res://assets/sprites/ui/speed_pause_active.svg"):
		_tex_pause_active = load("res://assets/sprites/ui/speed_pause_active.svg")

	if ResourceLoader.exists("res://assets/sprites/ui/speed_play_default.svg"):
		_tex_play_default = load("res://assets/sprites/ui/speed_play_default.svg")
	if ResourceLoader.exists("res://assets/sprites/ui/speed_play_hover.svg"):
		_tex_play_hover = load("res://assets/sprites/ui/speed_play_hover.svg")
	if ResourceLoader.exists("res://assets/sprites/ui/speed_play_active.svg"):
		_tex_play_active = load("res://assets/sprites/ui/speed_play_active.svg")

	if ResourceLoader.exists("res://assets/sprites/ui/speed_fwd_default.svg"):
		_tex_fwd_default = load("res://assets/sprites/ui/speed_fwd_default.svg")
	if ResourceLoader.exists("res://assets/sprites/ui/speed_fwd_hover.svg"):
		_tex_fwd_hover = load("res://assets/sprites/ui/speed_fwd_hover.svg")
	if ResourceLoader.exists("res://assets/sprites/ui/speed_fwd_active.svg"):
		_tex_fwd_active = load("res://assets/sprites/ui/speed_fwd_active.svg")

	# ── Пауза ──────────────────────────────────────────────
	_pause_btn = _make_speed_tex_btn(
		_tex_pause_default, _tex_pause_hover, _tex_pause_active,
		tr("UI_PAUSE") + " [color=gray][Space][/color]", Vector2(35, 30))
	_pause_btn.pressed.connect(_toggle_pause)
	hbox.add_child(_pause_btn)

	# ── Play 1× ────────────────────────────────────────────
	_speed1_btn = _make_speed_tex_btn(
		_tex_play_default, _tex_play_hover, _tex_play_active,
		tr("UI_SPEED_NORMAL") + " [color=gray][1][/color]", Vector2(35, 30))
	_speed1_btn.pressed.connect(func(): _set_speed(1))
	hbox.add_child(_speed1_btn)

	# ── Forward 2× ─────────────────────────────────────────
	_speed2_btn = _make_speed_tex_btn(
		_tex_fwd_default, _tex_fwd_hover, _tex_fwd_active,
		tr("UI_SPEED_FAST") + " [color=gray][2][/color]", Vector2(35, 30))
	_speed2_btn.pressed.connect(func(): _set_speed(2))
	hbox.add_child(_speed2_btn)

	return panel


func _make_speed_icon_btn(tip: String = "") -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	if tip != "":
		btn.mouse_entered.connect(func(): FloatingLabel.show_label(tip))
		btn.mouse_exited.connect(func(): FloatingLabel.hide_label())
	return btn


func _make_speed_tex_btn(tex_n: Texture2D, tex_h: Texture2D, tex_p: Texture2D, tip: String, sz: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = tex_n
	btn.texture_hover = tex_h
	btn.texture_pressed = tex_p
	btn.custom_minimum_size = sz
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.focus_mode = Control.FOCUS_NONE
	if tip != "":
		btn.mouse_entered.connect(func(): FloatingLabel.show_label(tip))
		btn.mouse_exited.connect(func(): FloatingLabel.hide_label())
	return btn


func _refresh_speed_btns() -> void:
	var pause_active := _is_paused
	var play_active := not _is_paused and _speed_multiplier == 1
	var fwd_active := not _is_paused and _speed_multiplier == 2
	_apply_speed_btn_state(_pause_btn, pause_active, _tex_pause_default, _tex_pause_hover, _tex_pause_active)
	_apply_speed_btn_state(_speed1_btn, play_active, _tex_play_default, _tex_play_hover, _tex_play_active)
	_apply_speed_btn_state(_speed2_btn, fwd_active, _tex_fwd_default, _tex_fwd_hover, _tex_fwd_active)
	if is_instance_valid(_pause_label):
		_pause_label.visible = _is_paused


func _apply_speed_btn_state(btn: TextureButton, is_active: bool,
		tex_def: Texture2D, tex_hov: Texture2D, tex_act: Texture2D) -> void:
	if not is_instance_valid(btn):
		return
	if is_active:
		btn.texture_normal = tex_act
		btn.texture_hover = tex_act
		btn.texture_pressed = tex_act
		btn.texture_disabled = tex_act
		btn.disabled = true
	else:
		btn.disabled = false
		btn.texture_normal = tex_def
		btn.texture_hover = tex_hov
		btn.texture_pressed = tex_act
		btn.texture_disabled = null

func _make_speed_btn(label_text: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.tooltip_text = tip
	btn.custom_minimum_size = Vector2(36, 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_DARK_BG.r, C_DARK_BG.g, C_DARK_BG.b, 0.9)
	sb.border_color = Color(0.45, 0.35, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = Color(0.18, 0.15, 0.08, 0.95)
	sb_h.border_color = Color(0.89, 0.8, 0.42)
	sb_h.set_border_width_all(2)
	sb_h.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_font_size_override("font_size", 13)
	return btn

# ── Інвентар загону ───────────────────────────────────────────────────────────

func _build_inventory_panel() -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.anchor_left = 1.0
	_inventory_panel.anchor_right = 1.0
	_inventory_panel.anchor_top = 0.0
	_inventory_panel.anchor_bottom = 1.0
	_inventory_panel.offset_left = -320
	_inventory_panel.offset_right = -10
	_inventory_panel.offset_top = 72
	_inventory_panel.offset_bottom = -10
	_inventory_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.06, 0.055, 0.045, 0.95)
	pst.border_color = Color(0.35, 0.28, 0.1)
	pst.set_border_width_all(2)
	pst.set_corner_radius_all(5)
	_inventory_panel.add_theme_stylebox_override("panel", pst)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 12)
	mc.add_theme_constant_override("margin_bottom", 12)
	_inventory_panel.add_child(mc)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	mc.add_child(main_vbox)

	# ── ЗАГІН ─────────────────────────────────────────────────────────
	main_vbox.add_child(_make_inv_section_label(tr("UI_SQUAD").to_upper()))
	main_vbox.add_child(_make_inv_separator())
	_inv_squad_row = VBoxContainer.new()
	_inv_squad_row.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_inv_squad_row)

	# ── СПОРЯДЖЕННЯ ───────────────────────────────────────────────────
	main_vbox.add_child(_make_inv_separator())
	main_vbox.add_child(_make_inv_section_label(tr("UI_EQUIPMENT").to_upper()))
	_inv_equipment_vbox = VBoxContainer.new()
	_inv_equipment_vbox.add_theme_constant_override("separation", 5)
	main_vbox.add_child(_inv_equipment_vbox)

	# ── ІНВЕНТАР ЗАГОНУ ───────────────────────────────────────────────
	main_vbox.add_child(_make_inv_separator())
	main_vbox.add_child(_make_inv_section_label((tr("UI_INVENTORY") + " " + tr("UI_SQUAD")).to_upper()))
	var scroll_inv := ScrollContainer.new()
	scroll_inv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_inv.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_inv)
	_inv_items_vbox = VBoxContainer.new()
	_inv_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_items_vbox.add_theme_constant_override("separation", 4)
	scroll_inv.add_child(_inv_items_vbox)

	_inventory_panel.visible = false
	_hud.add_child(_inventory_panel)

func _toggle_inventory() -> void:
	if not is_instance_valid(_inventory_panel):
		return
	_inventory_panel.visible = not _inventory_panel.visible
	if _inventory_panel.visible:
		_refresh_inventory_panel()

func _refresh_inventory_panel() -> void:
	if not is_instance_valid(_inventory_panel):
		return
	_refresh_squad_row()
	_refresh_equipment_section()
	_refresh_inventory_section()

func _refresh_squad_row() -> void:
	if not is_instance_valid(_inv_squad_row):
		return
	for child in _inv_squad_row.get_children():
		child.queue_free()

	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return
	var squad: Array = cm.world_state.get("squad", [])
	if squad.is_empty():
		return

	var names: Array = squad.map(func(u: Dictionary) -> String: return u.get("name", ""))
	if _selected_unit_name.is_empty() or _selected_unit_name not in names:
		_selected_unit_name = names[0] if not names.is_empty() else ""

	const NAME_TO_SPRITE: Dictionary = {
		"Ничипір": "nychypir", "Havrylo": "havrylo",
		"Гаврило": "havrylo", "Тимофій": "tymofiy",
		"Панько": "panko",
	}
	var fallback_sprites: Array[String] = ["nychypir", "havrylo", "tymofiy", "panko"]
	for unit in squad:
		var unit_name: String = unit.get("name", "?")
		var is_sel := (unit_name == _selected_unit_name)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 48)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.1, 0.09, 0.07)
		st.border_color = Color(0.89, 0.8, 0.42) if is_sel else Color(0.45, 0.35, 0.12)
		st.set_border_width_all(2 if is_sel else 1)
		st.set_corner_radius_all(3)
		st.content_margin_left = 4; st.content_margin_right = 4
		st.content_margin_top = 4; st.content_margin_bottom = 4
		var hover_st := st.duplicate() as StyleBoxFlat
		hover_st.bg_color = Color(0.18, 0.14, 0.09)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", hover_st)
		btn.add_theme_stylebox_override("pressed", hover_st)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hb)
		var sprite_key: String = NAME_TO_SPRITE.get(unit_name, "")
		if sprite_key.is_empty():
			sprite_key = fallback_sprites[squad.find(unit) % fallback_sprites.size()]
		var sprite_path := "res://assets/sprites/units/%s_front.png" % sprite_key
		var tex_rect := TextureRect.new()
		if ResourceLoader.exists(sprite_path):
			tex_rect.texture = load(sprite_path)
		tex_rect.custom_minimum_size = Vector2(40, 40)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tex_rect)
		var name_lbl := Label.new()
		name_lbl.text = unit_name
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color",
			Color(0.89, 0.8, 0.42) if is_sel else Color(0.72, 0.68, 0.52))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(name_lbl)
		btn.pressed.connect(func() -> void:
			_selected_unit_name = unit_name
			_refresh_squad_row()
			_refresh_equipment_section()
		)
		_inv_squad_row.add_child(btn)

func _refresh_equipment_section() -> void:
	if not is_instance_valid(_inv_equipment_vbox):
		return
	for child in _inv_equipment_vbox.get_children():
		child.queue_free()

	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return
	var unit: Dictionary = {}
	for u in cm.world_state.get("squad", []):
		if u.get("name", "") == _selected_unit_name:
			unit = u
			break

	if unit.is_empty():
		var lbl := Label.new()
		lbl.text = tr("UI_NO_UNIT_SELECTED")
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))
		_inv_equipment_vbox.add_child(lbl)
		return

	# ── Заголовок (стиль CharacterSheet) ─────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.text = unit.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_inv_equipment_vbox.add_child(name_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP: %d/%d   %s: %d" % [
		unit.get("hp", 0), unit.get("max_hp", 1), tr("STAT_LEVEL"), unit.get("level", 1)]
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	_inv_equipment_vbox.add_child(hp_lbl)

	_inv_equipment_vbox.add_child(_make_inv_separator())

	# ── Сітка слотів 3×3 (точний стиль CharacterSheet._equipment_slot) ────────
	var ws: Dictionary = cm.world_state
	var slot_types: Dictionary = {
		"weapon_resource_path": "weapon",
		"armor_path": "armor",
		"helm_path": "helm",
	}
	# [slot_key or null, slot_label, icon_if_empty]
	var grid_def: Array = [
		[null, tr("SLOT_TRINKET"), "○"],
		["helm_path", tr("STAT_HELMET"), "○"],
		[null, tr("SLOT_AMMO"), "○"],
		["weapon_resource_path", tr("SLOT_WEAPON"), "○"],
		["armor_path", tr("STAT_ARMOR"), "○"],
		[null, tr("SLOT_SHIELD"), "○"],
		[null, tr("SLOT_BELT"), "○"],
		[null, tr("SLOT_BELT"), "○"],
		[null, tr("SLOT_BELT"), "○"],
	]

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_inv_equipment_vbox.add_child(grid)

	var _cell_idx: int = 0
	for cell in grid_def:
		var slot_key: Variant = cell[0]
		var slot_label: String = cell[1]
		var is_active: bool = (slot_key != null)
		var res_path: String = unit.get(slot_key as String, "") if is_active else ""
		var is_filled: bool = is_active and not res_path.is_empty()
		@warning_ignore("integer_division")
		var _cell_row: int = _cell_idx / 3
		var _slot_size: Vector2 = Vector2(100, 180) if _cell_row == 1 else Vector2(100, 100)

		# ── Іконка ────────────────────────────────────────────────────────────
		var icon: String = "○"
		if is_filled:
			match (slot_key as String):
				"helm_path": icon = "🪖"
				"armor_path": icon = "🛡️"
				"weapon_resource_path":
					icon = "⚔️"
					if ResourceLoader.exists(res_path):
						var wr := load(res_path)
						if wr:
							match int(wr.get("type")):
								0: icon = "⚔️"
								1: icon = "🔱"
								2: icon = "🪓"
								3: icon = "🔨"
								4: icon = "🔫"
								5: icon = "🪓"
								7: icon = "🏹"

		# ── Назва предмета ────────────────────────────────────────────────────
		var item_display: String
		if is_filled:
			item_display = res_path.get_file().get_basename()
			if ResourceLoader.exists(res_path):
				var r := load(res_path)
				if r and "name" in r and (r["name"] as String) != "":
					item_display = r["name"]
		else:
			item_display = slot_label

		# ── Стиль (точний з CharacterSheet._equipment_slot рядки 350-353) ─────
		var base_st := StyleBoxFlat.new()
		base_st.bg_color = Color(0.13, 0.11, 0.07) if is_filled else Color(0.055, 0.055, 0.065)
		base_st.border_color = Color(0.48, 0.38, 0.13) if is_filled else Color(0.18, 0.18, 0.2)
		base_st.set_border_width_all(2)
		base_st.set_corner_radius_all(4)

		var slot := PanelContainer.new()
		slot.custom_minimum_size = _slot_size
		slot.add_theme_stylebox_override("panel", base_st)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if is_active \
			else Control.MOUSE_FILTER_IGNORE

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(vb)

		# Іконка — точний стиль CharacterSheet._equipment_slot()
		var slot_item_id: String = res_path.get_file().get_basename() if is_filled else ""
		var slot_icon_tex: Texture2D = InventoryManager.get_item_icon(slot_item_id) if slot_item_id != "" else null
		var slot_p_size := _slot_size
		if slot_icon_tex:
			var tex_rect := TextureRect.new()
			tex_rect.texture = slot_icon_tex
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_size: float = minf(slot_p_size.x - 10, slot_p_size.y - 50)
			tex_rect.custom_minimum_size = Vector2(slot_p_size.x - 10, icon_size)
			tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(tex_rect)
		else:
			var icon_lbl := Label.new()
			icon_lbl.text = icon
			icon_lbl.add_theme_font_size_override("font_size", 24)
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.add_theme_color_override("font_color",
				Color.WHITE if is_filled else Color(0.2, 0.2, 0.22))
			icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(icon_lbl)

		var text_margin := MarginContainer.new()
		text_margin.add_theme_constant_override("margin_left", 5)
		text_margin.add_theme_constant_override("margin_right", 5)
		text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(text_margin)

		var text_lbl := Label.new()
		text_lbl.text = item_display
		text_lbl.add_theme_font_size_override("font_size", 12)
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.add_theme_constant_override("line_spacing", -2)
		text_lbl.add_theme_color_override("font_color",
			Color(0.85, 0.72, 0.38) if is_filled else Color(0.3, 0.3, 0.32))
		text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_margin.add_child(text_lbl)

		# Hover + клік для активних слотів
		if is_active:
			var hover_st := base_st.duplicate() as StyleBoxFlat
			if is_filled:
				hover_st.border_color = Color(0.65, 0.5, 0.18)
			else:
				hover_st.border_color = Color(0.32, 0.28, 0.18)
			slot.mouse_entered.connect(func() -> void:
				slot.add_theme_stylebox_override("panel", hover_st))
			slot.mouse_exited.connect(func() -> void:
				slot.add_theme_stylebox_override("panel", base_st))

			if is_filled:
				var cap_key: String = slot_key as String
				var cap_type: String = slot_types.get(cap_key, "weapon")
				var cap_path: String = res_path
				slot.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton and ev.pressed \
							and ev.button_index == MOUSE_BUTTON_LEFT:
						var it := InventoryManager.make_item_from_resource(cap_path, cap_type)
						if not it.is_empty():
							InventoryManager.add_item(ws, it)
						unit[cap_key] = ""
						_refresh_inventory_panel()
						_update_hud(cm.world_state)
				)

		_cell_idx += 1
		grid.add_child(slot)

	# ── Стати ─────────────────────────────────────────────────────────────────
	_inv_equipment_vbox.add_child(_make_inv_separator())

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 2)
	_inv_equipment_vbox.add_child(stats_vbox)

	var data_path: String = unit.get("data_path", "")
	if data_path.is_empty() or not ResourceLoader.exists(data_path):
		var u_lbl := Label.new()
		u_lbl.text = tr("UI_STATS_UNKNOWN")
		u_lbl.add_theme_font_size_override("font_size", 11)
		u_lbl.add_theme_color_override("font_color", Color(0.45, 0.44, 0.4))
		stats_vbox.add_child(u_lbl)
	else:
		var d := load(data_path)
		var melee_skill: int = unit.get("stat_melee_skill",
			int(d.get("base_melee_skill")) if d else 0)
		var melee_def: int = unit.get("stat_melee_defense",
			int(d.get("base_melee_defense")) if d else 0)

		var body_hp := 0
		var a_path: String = unit.get("armor_path", "")
		if not a_path.is_empty() and ResourceLoader.exists(a_path):
			var ar := load(a_path)
			if ar and "armor_hp" in ar:
				body_hp = ar.armor_hp

		var head_hp := 0
		var h_path: String = unit.get("helm_path", "")
		if not h_path.is_empty() and ResourceLoader.exists(h_path):
			var hl := load(h_path)
			if hl and "armor_hp" in hl:
				head_hp = hl.armor_hp

		for stat_line: String in [
			tr("STAT_MELEE_SHORT") % melee_skill,
			tr("STAT_DEFENSE_MELEE_SHORT") % melee_def,
			tr("STAT_ARMOR_HELMET_FORMAT") % [body_hp, head_hp],
		]:
			var sl := Label.new()
			sl.text = stat_line
			sl.add_theme_font_size_override("font_size", 11)
			sl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.5))
			stats_vbox.add_child(sl)

func _refresh_inventory_section() -> void:
	if not is_instance_valid(_inv_items_vbox):
		return
	for child in _inv_items_vbox.get_children():
		child.queue_free()

	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return
	var ws: Dictionary = cm.world_state
	var inventory: Array = ws.get("squad_inventory", [])

	if inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = tr("UI_INVENTORY_EMPTY")
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inv_items_vbox.add_child(empty_lbl)
		return

	var at_settlement := _is_at_settlement()
	var type_names := {"weapon": tr("SLOT_WEAPON").to_lower(), "armor": tr("STAT_ARMOR").to_lower(), "helm": tr("STAT_HELMET").to_lower()}

	for item in inventory:
		var item_id: String = item.get("id", "")
		var item_name: String = tr(item.get("name", "?"))
		var item_type: String = item.get("type", "")
		var sell_price: int = item.get("sell_price", 0)
		var type_str: String = type_names.get(item_type, item_type)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_inv_items_vbox.add_child(row)

		var inv_icon_tex: Texture2D = InventoryManager.get_item_icon(item_id)
		if inv_icon_tex:
			var inv_icon_rect := TextureRect.new()
			inv_icon_rect.texture = inv_icon_tex
			inv_icon_rect.custom_minimum_size = Vector2(24, 24)
			inv_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			inv_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			inv_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(inv_icon_rect)

		var name_lbl := Label.new()
		name_lbl.text = "%s (%s)" % [item_name, type_str]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.55))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_lbl)

		var equip_btn := _make_trade_btn("⬆", not _selected_unit_name.is_empty())
		equip_btn.custom_minimum_size = Vector2(32, 26)
		equip_btn.tooltip_text = tr("UI_EQUIP") + " " + _selected_unit_name
		equip_btn.pressed.connect(func() -> void:
			if _selected_unit_name.is_empty():
				return
			InventoryManager.equip_item(ws, item_id, _selected_unit_name)
			_refresh_squad_row()
			_refresh_equipment_section()
			_refresh_inventory_section()
			_update_hud(cm.world_state)
		)
		row.add_child(equip_btn)

		var sell_btn := _make_trade_btn("%d" % sell_price, at_settlement)
		sell_btn.custom_minimum_size = Vector2(46, 26)
		if not at_settlement:
			sell_btn.tooltip_text = tr("UI_SELL_SETTLEMENT")
		sell_btn.pressed.connect(func() -> void: _on_sell_item(item_id))
		row.add_child(sell_btn)

func _make_inv_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", C_GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _make_inv_separator() -> HSeparator:
	var sep := HSeparator.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.35, 0.28, 0.1, 0.5)
	sep.add_theme_stylebox_override("separator", st)
	return sep

func _on_sell_item(item_id: String) -> void:
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return
	InventoryManager.sell_item(cm.world_state, item_id)
	_refresh_inventory_panel()
	_update_hud(cm.world_state)
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		sm.save_campaign(cm.world_state)

func _is_location_hostile(marker: Node2D) -> bool:
	var loc_type: String = str(marker.get("loc_type"))
	if loc_type in ["bandit_camp", "tatar_camp", "crown_outpost", "ruins", "poi"]:
		return true
	var faction: String = str(marker.get("faction"))
	if faction == "none":
		return true
	var cm := get_node_or_null("/root/CampaignManager")
	if not cm:
		return true
	return (cm.get_rep(faction) as int) <= -20

func _is_at_settlement() -> bool:
	if not is_instance_valid(_player_party) or not is_instance_valid(_locations_layer):
		return false
	for marker in _locations_layer.get_children():
		if not is_instance_valid(marker):
			continue
		var loc_type: String = str(marker.get("loc_type"))
		if loc_type != "town" and loc_type != "village":
			continue
		if not marker.get("cleared") and _is_location_hostile(marker):
			continue
		if _player_party.position.distance_to(marker.position) <= 90.0 * 1.5:
			return true
	return false

func _check_all_encounters() -> void:
	if _encounter_dialog.visible or _location_dialog.visible:
		return
	for child in _parties_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child in _encounter_cooldowns:
			continue
		if child.get("alive") != false and child.has_method("get_battle_config"):
			var dist := _player_party.position.distance_to(child.position)
			var threshold: float = child.get("ENCOUNTER_RADIUS") if child.get("ENCOUNTER_RADIUS") != null else 28.0
			if dist < threshold:
				_show_encounter_dialog(child)
				return
	for child in _locations_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child in _encounter_cooldowns:
			continue
		var dist := _player_party.position.distance_to(child.position)
		if dist <= _player_party.get_interaction_radius() * 1.5:
			if child.get("cleared") or not _is_location_hostile(child):
				_show_location_dialog(child)
			else:
				_show_encounter_dialog(child)
			return
