extends Node2D

const INTERACTION_RADIUS := 90.0

var loc_id: String = ""
var loc_type: String = ""
var faction: String = "none"
var garrison_paths: Array[String] = []
var reward_thalers: int = 150
var loc_name: String = ""
var cleared: bool = false
var discovered: bool = false

var _label: Label

signal interaction_requested(marker: Node2D)

func _ready() -> void:
	z_index = 4
	_build_visual()

func setup(data: Dictionary) -> void:
	loc_id = data.get("id", "")
	loc_type = data.get("type", "bandit_camp")
	faction = data.get("faction", "none")
	garrison_paths.assign(data.get("garrison_paths", []))
	reward_thalers = data.get("reward_thalers", 100)
	loc_name = data.get("name", "Локація")
	cleared = data.get("cleared", false)
	discovered = data.get("discovered", false)
	position = Vector2(data["pos"]["x"], data["pos"]["y"])
	_refresh_visual()

func _build_visual() -> void:
	# Мітка назви
	_label = Label.new()
	_label.position = Vector2(-50, 20)
	_label.custom_minimum_size = Vector2(100, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	add_child(_label)

func _refresh_visual() -> void:
	if _label:
		_label.text = loc_name
		if cleared:
			_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	queue_redraw()

func _get_faction_color() -> Color:
	match faction:
		"crown": return Color(0.2, 0.4, 0.9)
		"sich":  return Color(0.15, 0.65, 0.3)
		"orda":  return Color(0.9, 0.5, 0.1)
		_:       return Color(0.65, 0.2, 0.2)  # бандити

func _get_color() -> Color:
	if cleared:
		return Color(0.35, 0.35, 0.35, 0.6)
	return _get_faction_color()

func _draw() -> void:
	var color := _get_color()
	var gold_outline := Color(0.89, 0.8, 0.42, 0.5 if cleared else 1.0)
	
	match loc_type:
		"town":
			# Зовнішній круг фортеці
			draw_circle(Vector2.ZERO, 16.0, color)
			draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, gold_outline, 2.0, true)
			# Внутрішнє кільце
			draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, gold_outline, 1.2, true)
			# Зубці фортеці (бастіони)
			for angle in [0.0, PI/2.0, PI, 3.0*PI/2.0]:
				var dir = Vector2.from_angle(angle)
				draw_line(dir * 16.0, dir * 21.0, gold_outline, 2.5, true)
				
		"village":
			# Трикутник даху
			var pts_roof : Array[Vector2] = [
				Vector2(0, -16),
				Vector2(-15, 0),
				Vector2(15, 0)
			]
			draw_polygon(pts_roof, [color])
			# Стіни будинку (квадрат)
			var pts_house : Array[Vector2] = [
				Vector2(-10, 0),
				Vector2(10, 0),
				Vector2(10, 12),
				Vector2(-10, 12)
			]
			draw_polygon(pts_house, [color])
			# Золотий контур даху
			draw_line(Vector2(0, -16), Vector2(-15, 0), gold_outline, 2.0, true)
			draw_line(Vector2(0, -16), Vector2(15, 0), gold_outline, 2.0, true)
			draw_line(Vector2(-15, 0), Vector2(15, 0), gold_outline, 2.0, true)
			
		"ruins", "poi":
			# Ромб
			var pts_diamond : Array[Vector2] = [
				Vector2(0, -18),
				Vector2(12, 0),
				Vector2(0, 18),
				Vector2(-12, 0)
			]
			draw_polygon(pts_diamond, [color])
			draw_polyline(pts_diamond + [pts_diamond[0]], gold_outline, 2.0, true)
			# Центральний містичний кружечок
			draw_circle(Vector2.ZERO, 4.0, gold_outline)
			
		_: # Табори або застави (default)
			# П'ятикутний щит/банер
			var pts_shield : Array[Vector2] = [
				Vector2(0, -15),
				Vector2(12, -7),
				Vector2(9, 13),
				Vector2(-9, 13),
				Vector2(-12, -7)
			]
			draw_polygon(pts_shield, [color])
			draw_polyline(pts_shield + [pts_shield[0]], gold_outline, 1.8, true)
			draw_line(Vector2(-8, 0), Vector2(8, 0), gold_outline, 1.5, true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos := to_local(get_global_mouse_position())
		if local_pos.length() < 30.0:
			interaction_requested.emit(self)
			get_viewport().set_input_as_handled()

func get_battle_config() -> Dictionary:
	return {
		"enemy_data_paths": garrison_paths,
		"reward_thalers": reward_thalers,
		"source_id": loc_id,
		"source_type": "location"
	}

func mark_cleared() -> void:
	cleared = true
	_refresh_visual()
