class_name BattleManager
extends Node2D

const IsoMath = preload("res://src/core/IsoMath.gd")
@onready var tile_map: Node2D = $"../TacticalGrid"
@onready var unit_panel: Control = $"../UI/UnitPanel"

var turn_queue: Array = []
var active_unit: Node2D = null
var current_skill_id: String = "" # Порожньо на старті
var hover_skill_id: String = "" # Для підсвітки зони при наведенні на кнопку
@onready var combat_log = get_node_or_null("../UI/CombatLog")

var current_round: int = 1
var battle_ended: bool = false

var full_round_order: Array = [] # Всі успішно ініціалізовані юніти в раунді
var completed_units: Array = [] # Ті, хто вже походив
var _pending_retreat_path: Array = [] # Для підтвердження відступу
var _combat_hints_shown: Dictionary = {}

var _is_tutorial: bool = false
var _tutorial_step: int = 0
var _tutorial_panel: Control = null
var _tutorial_label: Label = null
var _skip_btn: Button = null
var _tutorial_enemy_hp_snapshot: int = 0

signal queue_changed(round_num: int, active: Node2D, upcoming: Array, completed: Array)
signal unit_hovered(unit: Node2D)
signal unit_unhovered(unit: Node2D)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.902, 0.835, 0.722, 1)) # степ #E6D5B8

	# Чекаємо один кадр, щоб всі _ready в сцені завершились і вузли стали стабільними
	if Globals.DEBUG_LOG: print("BattleManager: _ready() починається...")
	await get_tree().process_frame

	if Globals.DEBUG_LOG: print("BattleManager: Старт системи...")

	# Налаштовуємо ворогів з конфігу кампанії (до ініціалізації черги)
	var cm = get_node_or_null("/root/CampaignManager")
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_music("battle")
	else:
		push_warning("BattleManager: AudioManager недоступний — перезапусти Godot Editor")
	if cm and not cm.active_battle_config.is_empty():
		_apply_enemy_config(cm.active_battle_config)
		await get_tree().process_frame

	# Відновлюємо стан козаків з CampaignManager або SaveManager
	var squad_data: Array = []
	if cm and not cm.world_state.get("squad", []).is_empty():
		squad_data = cm.world_state["squad"]
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.load_game():
			squad_data = save_mgr.squad_data
	if Globals.DEBUG_LOG: print("BattleManager: squad_data.size() = ", squad_data.size())

	if not squad_data.is_empty():
		var player_nodes = []
		for child in get_parent().get_children():
			if child is CombatUnit and child.team == 0:
				player_nodes.append(child)

		for i in range(player_nodes.size()):
			var node = player_nodes[i]
			if i < squad_data.size():
				var data = squad_data[i]
				if data.has("data_path") and data["data_path"] != "":
					var res = load(data["data_path"])
					if res:
						var dup: Resource = res.duplicate()
						if data.has("stat_melee_skill"):
							dup.set("base_melee_skill", data["stat_melee_skill"])
						if data.has("stat_ranged_skill"):
							dup.set("base_ranged_skill", data["stat_ranged_skill"])
						if data.has("stat_melee_defense"):
							dup.set("base_melee_defense", data["stat_melee_defense"])
						node.set("data", dup)

				if data.has("weapon_resource_path") and data["weapon_resource_path"] != "":
					var res = load(data["weapon_resource_path"])
					if res:
						node.set("weapon_resource", res)

				if data.has("armor_path") and data["armor_path"] != "":
					var armor_res = load(data["armor_path"])
					if armor_res and node.get("data") != null:
						node.data.default_armor = armor_res

				if data.has("helm_path") and data["helm_path"] != "":
					var helm_res = load(data["helm_path"])
					if helm_res and node.get("data") != null:
						node.data.default_helmet = helm_res

				if node is CombatUnit:
					node.setup_from_data()
				
				# Встановлюємо стан ПІСЛЯ setup_from_data, інакше він скине hp до max_hp
				node.name = data.get("name", node.name)
				if node.has_method("update_sprite"):
					node.update_sprite()
				node.set("hp", data.get("hp", node.get("hp")))
				node.set("max_hp", data.get("max_hp", node.get("max_hp")))
				node.set("xp", data.get("xp", 0))
				node.set("level", data.get("level", 1))
				node.set("xp_to_next", data.get("xp_to_next", 150))
				if data.has("weapon_type"):
					node.set("weapon_type", data.get("weapon_type"))
			else:
				node.get_parent().remove_child(node)
				node.queue_free()
	
	# Штраф за голод: знижуємо мораль та витривалість при нульових провізіях
	var cm_hunger := get_node_or_null("/root/CampaignManager")
	if cm_hunger and (cm_hunger.get("world_state") as Dictionary).get("provisions", 1) == 0:
		for child in get_parent().get_children():
			if child is CombatUnit and child.team == 0:
				child.current_morale = CombatUnit.MoralState.WAVERING
				child.stamina = int(child.stamina * 0.7)

	if unit_panel:
		unit_panel.skill_selected.connect(_on_skill_selected)

	var retreat_dialog = get_node_or_null("../UI/RetreatConfirmation")
	if retreat_dialog:
		retreat_dialog.confirmed.connect(_on_retreat_confirmed)

	log_message("--- ⚔️ " + tr("BATTLE_STARTED") % 1 + " ---", Color.GOLD)
	
	# Ініціалізація юнітів (позиція та мораль)
	if Globals.DEBUG_LOG: print("--- BattleManager: Unit Starting Positions ---")
	for child in get_parent().get_children():
		if child is CombatUnit:
			var m_pos = IsoMath.local_to_map(child.position)
			if Globals.DEBUG_LOG: print("Unit: ", child.name, " team: ", child.team, " pos: ", child.position, " map_pos: ", m_pos, " dead: ", child.is_dead)
			child.position = IsoMath.get_cell_center(m_pos)
			child.roll_starting_morale()
			
	initialize_queue()
	_setup_turn_queue_ui()
	_style_end_turn_button()
	_center_camera()

	if cm and cm.active_battle_config.get("is_tutorial", false):
		_is_tutorial = true
		_build_tutorial_panel()

	start_next_unit_turn.call_deferred()
	if Globals.DEBUG_LOG: print("BattleManager: _ready() ЗАВЕРШЕНО")

func _on_skill_selected(id: String) -> void:
	# Toggle logic: якщо клікнути на вже обрану — вона скидається
	if current_skill_id == id:
		current_skill_id = ""
	else:
		current_skill_id = id

	if Globals.DEBUG_LOG: print("Навичок: %s" % (current_skill_id if current_skill_id != "" else "Move Mode"))
	if tile_map: tile_map.queue_redraw()
	if unit_panel: unit_panel.update_unit_info(active_unit)

	if _is_tutorial and _tutorial_step == 1 and current_skill_id != "":
		_tutorial_step = 2
		_show_tutorial_step(tr("TUTORIAL_STEP2"))

func activate_rally_immediately() -> void:
	if not active_unit or active_unit.is_dead: return
	
	var rally_skill = null
	for s in active_unit.available_skills:
		if s.id == "rally":
			rally_skill = s
			break
	
	if rally_skill:
		if active_unit.ap >= rally_skill.ap and active_unit.stamina >= rally_skill.stamina:
			active_unit.use_rally(rally_skill)
			current_skill_id = ""
			if tile_map: tile_map.queue_redraw()
			if unit_panel: unit_panel.update_unit_info(active_unit)
			end_unit_turn()

func activate_riposte_immediately() -> void:
	if not active_unit or active_unit.is_dead: return
	
	var riposte_skill = null
	for s in active_unit.available_skills:
		if s.id == "riposte":
			riposte_skill = s
			break
			
	if riposte_skill:
		if active_unit.ap >= riposte_skill.ap and active_unit.stamina >= riposte_skill.stamina:
			active_unit.activate_riposte(riposte_skill)
			current_skill_id = ""
			if tile_map: tile_map.queue_redraw()
			if unit_panel: unit_panel.update_unit_info(active_unit)
			end_unit_turn()

func log_message(text: String, color: Color = Color.WHITE) -> void:
	if combat_log:
		combat_log.add_log_message(text, color)
	else:
		print("LOG [%s]: %s" % [color.to_html(false), text])

func _maybe_combat_hint(key: String, text: String) -> bool:
	if _is_tutorial:
		return false
	if _combat_hints_shown.has(key):
		return false
	_combat_hints_shown[key] = true
	log_message("[color=yellow][" + tr("BATTLE_HINT_LABEL") + "][/color] " + text)
	return true

func request_retreat_confirmation(path: Array) -> void:
	_pending_retreat_path = path
	var dialog = get_node_or_null("../UI/RetreatConfirmation")
	if dialog:
		dialog.popup_centered()

func _on_retreat_confirmed() -> void:
	if not active_unit or _pending_retreat_path.is_empty(): return
	active_unit.request_move(_pending_retreat_path)
	_pending_retreat_path = []

func initialize_queue() -> void:
	turn_queue.clear()
	completed_units.clear()
	
	if check_battle_end():
		return
		
	for child in get_parent().get_children():
		if child is CombatUnit and not child.is_dead:
			child.set("has_waited", false)
			turn_queue.append(child)
	
	turn_queue.sort_custom(func(a, b):
		var init_a: int = a.get_effective_initiative() if a is CombatUnit else 0
		var init_b: int = b.get_effective_initiative() if b is CombatUnit else 0
		return init_a > init_b
	)
	
	full_round_order = turn_queue.duplicate()
	queue_changed.emit(current_round, null, turn_queue, completed_units)

func _show_battle_result(is_victory: bool) -> void:
	var player_units: Array = []
	var loot_pool: Array = []

	for child in get_parent().get_children():
		if not (child is CombatUnit):
			continue
		if child.team == 0:
			player_units.append(child)
		elif child.team == 1 and child.is_dead and is_victory:
			# 30% шанс отримати зброю (без умов на стан)
			if randf() < 0.3:
				var weapon: WeaponResource = child.get("weapon_resource")
				if weapon != null and weapon.resource_path != "":
					var item := InventoryManager.make_item_from_resource(weapon.resource_path, "weapon")
					if not item.is_empty():
						loot_pool.append(item)

			# 40% шанс отримати броню — тільки якщо ціла (>50% max)
			var body_armor: int = child.get("body_armor") if "body_armor" in child else 0
			var max_body: int = child.get("max_body_armor") if "max_body_armor" in child else 0
			if max_body > 0 and body_armor * 2 > max_body:
				if randf() < 0.4:
					var unit_data = child.get("data")
					var armor_res = unit_data.default_armor if unit_data and unit_data.default_armor else null
					if armor_res and armor_res.resource_path != "":
						var item := InventoryManager.make_item_from_resource(armor_res.resource_path, "armor")
						if not item.is_empty():
							loot_pool.append(item)

			# 40% шанс отримати шолом — тільки якщо цілий (>50% max)
			var head_armor: int = child.get("head_armor") if "head_armor" in child else 0
			var max_head: int = child.get("max_head_armor") if "max_head_armor" in child else 0
			if max_head > 0 and head_armor * 2 > max_head:
				if randf() < 0.4:
					var unit_data2 = child.get("data")
					var helm_res = unit_data2.default_helmet if unit_data2 and unit_data2.default_helmet else null
					if helm_res and helm_res.resource_path != "":
						var item := InventoryManager.make_item_from_resource(helm_res.resource_path, "helm")
						if not item.is_empty():
							loot_pool.append(item)

	var ui_layer = get_node_or_null("../UI")
	if ui_layer:
		for hide_name in ["TurnQueueUI", "UnitPanel", "EndTurnButton", "CombatLog"]:
			var node = ui_layer.get_node_or_null(hide_name)
			if node:
				node.visible = false

		var result_screen = load("res://src/ui/BattleResultScreen.gd").new()
		ui_layer.add_child(result_screen)
		result_screen.init(is_victory, player_units, loot_pool)

func check_battle_end() -> bool:
	if battle_ended: return true
	var cossacks_count = 0
	var enemy_count = 0
	for child in get_parent().get_children():
		if child is CombatUnit and not child.is_dead:
			if child.get("team") == 0: cossacks_count += 1
			else: enemy_count += 1
			
	if cossacks_count == 0:
		battle_ended = true
		log_message("--- 💀 " + tr("BATTLE_DEFEAT") + " ---", Color.DARK_RED)
		turn_queue.clear()
		_show_battle_result(false)
		return true
	if enemy_count == 0:
		battle_ended = true
		log_message("--- 🏆 " + tr("BATTLE_VICTORY") + " ---", Color.SKY_BLUE)
		turn_queue.clear()
		_show_battle_result(true)
		return true
	return false

func start_next_unit_turn() -> void:
	if check_battle_end():
		return
		
	if turn_queue.is_empty():
		log_message(tr("BATTLE_ROUND_END") % current_round, Color.DIM_GRAY)
		end_round()
		return
		
	var next = turn_queue.pop_front()
	if not is_instance_valid(next):
		start_next_unit_turn()
		return
	active_unit = next

	# Стрибаємо через мертвих юнітів, якщо вони все ще в черзі
	if active_unit.is_dead:
		start_next_unit_turn()
		return

	log_message(">> 🦶 " + tr("BATTLE_UNIT_TURN") % [active_unit.name, tr("TEAM_COSSACK") if active_unit.team == 0 else tr("TEAM_ENEMY")], Color(0.3, 0.7, 1.0) if active_unit.team == 0 else Color.INDIAN_RED)
	current_skill_id = "" # Скидання (нічого не обрано)
	queue_changed.emit(current_round, active_unit, turn_queue, completed_units)
	
	if is_instance_valid(active_unit):
		# Якщо юніт чекав, це НЕ новий раунд для нього
		var is_waited_turn = active_unit.get("has_waited")
		active_unit.start_turn(not is_waited_turn)
		
		if not active_unit.move_finished.is_connected(_on_unit_move_finished):
			active_unit.move_finished.connect(_on_unit_move_finished)
			
		if unit_panel:
			unit_panel.update_unit_info(active_unit)

		# Підказки в бойовому лозі (лише для козаків, по одній за хід)
		if active_unit.team == 0:
			var _hint := _maybe_combat_hint("first_turn", tr("COMBAT_HINT_FIRST"))
			if not _hint and active_unit.stamina < active_unit.max_stamina * 0.3:
				_hint = _maybe_combat_hint("low_stamina", tr("COMBAT_HINT_STAMINA"))
			if not _hint and active_unit.current_morale >= CombatUnit.MoralState.WAVERING:
				_maybe_combat_hint("low_morale", tr("COMBAT_HINT_MORALE"))

		# Tutorial кроки
		if _is_tutorial:
			if active_unit.team == 0 and _tutorial_step == 0:
				_tutorial_step = 1
				_tutorial_enemy_hp_snapshot = _get_total_enemy_hp()
				_show_tutorial_step(tr("TUTORIAL_STEP1"))
			elif active_unit.team == 1 and _tutorial_step == 3:
				_tutorial_step = 4
				_show_tutorial_step(tr("TUTORIAL_STEP4"))
			elif active_unit.team == 0 and _tutorial_step == 4:
				_tutorial_step = 5
				_show_tutorial_step(tr("TUTORIAL_STEP5"))

		# Блокування/розблокування кнопки завершення ходу
		var end_turn_btn = get_node_or_null("../UI/EndTurnButton")
		if end_turn_btn:
			end_turn_btn.disabled = (active_unit.get("team") != 0)
			
		# Впровадження ШІ для ворогів (Team 1)
		if active_unit.team == 1:
			if active_unit is CombatUnit:
				active_unit.execute_ai()

func end_unit_turn() -> void:
	if active_unit:
		if _is_tutorial and active_unit.team == 0:
			if _tutorial_step == 3:
				_hide_tutorial_panel()
			elif _tutorial_step == 5:
				_tutorial_step = 6
				_hide_tutorial_panel()
		completed_units.append(active_unit)
		active_unit.end_turn()
	start_next_unit_turn()

# Окремий обробник для кнопки UI: гравець НЕ може завершити хід за ворога.
# Працює в усіх збірках, на відміну від get_stack(), який в release повертає [].
func _on_end_turn_pressed() -> void:
	if active_unit and active_unit.get("team") != 0:
		return
	end_unit_turn()

func wait_current_unit() -> void:
	if active_unit and not active_unit.get("has_waited"):
		active_unit.set("has_waited", true)
		active_unit.end_turn()
		
		# Поміщаємо в кінець черги
		turn_queue.append(active_unit)
		
		# Важливо: спочатку емітимо сигнал для анімації UI, а потім переходимо до наступного
		# Для цього в UI додамо обробку "Wait" станів. 
		# Поки що просто перемикаємо.
		start_next_unit_turn()

func end_round() -> void:
	current_round += 1
	log_message("\n=== 📜 " + tr("BATTLE_ROUND") % current_round + " ===", Color.YELLOW)
	initialize_queue()
	start_next_unit_turn()

func _on_unit_move_finished() -> void:
	if not active_unit: return
	
	# Якщо юніт помер під час свого ходу (наприклад від контрудару) - завершуємо хід
	if active_unit.is_dead:
		start_next_unit_turn.call_deferred()
		return
	
	# Перевірка на вихід за межі карти
	var u_map = IsoMath.local_to_map(active_unit.position)
	if tile_map and tile_map.has_method("is_on_border") and tile_map.is_on_border(u_map):
		print("Юніт %s відступає!" % active_unit.name)
		
		# Видаляємо з усіх черг
		turn_queue.erase(active_unit)
		full_round_order.erase(active_unit)
		
		active_unit.retreat()
		start_next_unit_turn.call_deferred()
		return
		
	if tile_map:
		tile_map.update_path_preview()
		tile_map.queue_redraw()
	if unit_panel and active_unit:
		unit_panel.update_unit_info(active_unit)

	if _is_tutorial and active_unit and active_unit.team == 0:
		if _tutorial_step == 2:
			if _get_total_enemy_hp() < _tutorial_enemy_hp_snapshot:
				_tutorial_step = 3
				_show_tutorial_step(tr("TUTORIAL_STEP3"))
		elif _tutorial_step == 5:
			_tutorial_step = 6
			_hide_tutorial_panel()

var _prev_hovered: Node2D = null
func update_hover_info(unit: Node2D) -> void:
	if unit == _prev_hovered: return
	
	if is_instance_valid(_prev_hovered):
		unit_unhovered.emit(_prev_hovered)
		if _prev_hovered.has_method("set_highlight"):
			_prev_hovered.set_highlight(false)
			
	if is_instance_valid(unit) and unit != active_unit:
		unit_hovered.emit(unit)
		if unit.has_method("set_highlight"):
			unit.set_highlight(true)
		if unit_panel and unit_panel.has_method("show_hover_intel"):
			unit_panel.show_hover_intel(unit)
		if unit_panel and unit_panel.has_method("show_hover_terrain"):
			unit_panel.show_hover_terrain(-1)
	elif unit_panel and unit_panel.has_method("show_hover_intel"):
		unit_panel.show_hover_intel(null)
		
	_prev_hovered = unit

func update_hover_terrain(terrain_type: int) -> void:
	if unit_panel and unit_panel.has_method("show_hover_terrain"):
		unit_panel.show_hover_terrain(terrain_type)

func _process(_delta: float) -> void:
	pass # HUD оновлюється через сигнали

func _setup_turn_queue_ui() -> void:
	var ui_layer = get_node_or_null("../UI")
	if not ui_layer: return
	
	if ui_layer.has_node("TurnQueueUI"): return
	
	var queue_ui = HBoxContainer.new()
	queue_ui.name = "TurnQueueUI"
	queue_ui.set_script(load("res://src/ui/TurnQueueUI.gd"))
	ui_layer.add_child(queue_ui)
	ui_layer.move_child(queue_ui, 0) # Кладемо на самий низ (під оверлей)
	if Globals.DEBUG_LOG: print("BattleManager: TurnQueueUI автоматично додано до UI.")

func _style_end_turn_button() -> void:
	var btn = get_node_or_null("../UI/EndTurnButton")
	if not btn: return

	btn.text = "🏁 " + tr("UI_END_TURN")

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.18, 0.12)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.2, 0.5, 0.2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	
	var hover = normal.duplicate()
	hover.bg_color = Color(0.2, 0.3, 0.2)
	hover.border_color = Color(0.3, 0.8, 0.3)
	
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.08, 0.6)
	disabled.border_color = Color(0.15, 0.15, 0.15)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	btn.add_theme_color_override("font_color_disabled", Color(0.4, 0.4, 0.4))

func _on_tutorial_skip_pressed() -> void:
	_hide_tutorial_panel()
	if battle_ended: return
	battle_ended = true
	turn_queue.clear()
	var cm = get_node_or_null("/root/CampaignManager")
	if not cm: return
	var player_units: Array = []
	for child in get_parent().get_children():
		if child is CombatUnit and child.team == 0:
			player_units.append(child)
	cm.finish_battle(true, player_units)

func _build_tutorial_panel() -> void:
	var ui_layer = get_node_or_null("../UI")
	if not ui_layer: return

	var panel := Control.new()
	panel.name = "TutorialHintPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.065, 0.055, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	panel.add_child(label)

	var skip_btn := Button.new()
	skip_btn.name = "TutorialSkipButton"
	skip_btn.text = tr("UI_SKIP_TUTORIAL")
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15)
	btn_normal.set_border_width_all(0)
	btn_normal.set_corner_radius_all(3)
	var btn_hover: StyleBoxFlat = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.25, 0.2, 0.1)
	skip_btn.add_theme_stylebox_override("normal", btn_normal)
	skip_btn.add_theme_stylebox_override("hover", btn_hover)
	skip_btn.add_theme_stylebox_override("pressed", btn_hover)
	skip_btn.add_theme_font_size_override("font_size", 13)
	skip_btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	skip_btn.pressed.connect(_on_tutorial_skip_pressed)
	panel.add_child(skip_btn)

	ui_layer.add_child(panel)
	panel.visible = false

	_tutorial_panel = panel
	_tutorial_label = label
	_skip_btn = skip_btn

	get_tree().root.size_changed.connect(_reposition_tutorial_panel)
	_reposition_tutorial_panel()

func _reposition_tutorial_panel() -> void:
	if not is_instance_valid(_tutorial_panel): return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel_w: float = maxf(350.0, vp.x * 0.45)
	var panel_h: float = 50.0
	var x: float = (vp.x - panel_w) / 2.0
	var unit_panel_node: Control = get_node_or_null("../UI/UnitPanel")
	var unit_panel_h: float = 0.0
	if unit_panel_node and unit_panel_node.visible:
		unit_panel_h = unit_panel_node.size.y
	var y: float = vp.y - unit_panel_h - panel_h - 30.0
	_tutorial_panel.position = Vector2(x, y)
	_tutorial_panel.size = Vector2(panel_w, panel_h)
	if is_instance_valid(_tutorial_label):
		_tutorial_label.position = Vector2(20.0, 0.0)
		_tutorial_label.size = Vector2(panel_w - 150.0, panel_h)
	if is_instance_valid(_skip_btn):
		_skip_btn.position = Vector2(panel_w - 130.0, 9.0)
		_skip_btn.size = Vector2(110.0, 32.0)

func _show_tutorial_step(text: String) -> void:
	if not is_instance_valid(_tutorial_panel) or not is_instance_valid(_tutorial_label):
		return
	_tutorial_label.text = text
	_tutorial_panel.modulate.a = 0.0
	_tutorial_panel.visible = true
	var tw := create_tween()
	tw.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.3)

func _hide_tutorial_panel() -> void:
	if not is_instance_valid(_tutorial_panel) or not _tutorial_panel.visible:
		return
	var tw := create_tween()
	tw.tween_property(_tutorial_panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_tutorial_panel.hide)

func _get_total_enemy_hp() -> int:
	var total := 0
	for child in get_parent().get_children():
		if child is CombatUnit and child.team == 1 and not child.is_dead:
			total += (child as CombatUnit).hp
	return total

func _center_camera() -> void:
	var camera = get_node_or_null("../Camera2D")
	var grid = get_node_or_null("../TacticalGrid")
	if not camera or not grid: return
	
	# Розраховуємо центр мапи на основі GRID_SIZE з TacticalGrid
	if not "GRID_SIZE" in grid: return
	var size = grid.GRID_SIZE
	
	# Точки країв ромба мапи: (0,0), (size-1, 0), (0, size-1), (size-1, size-1)
	# Середня точка по Y: (size-1) * 40.0
	# Середня точка по X: завжди 0 (оскільки мапа симетрична відносно осі Y в нашій ізометрії)
	var center_y = (size - 1) * 40.0
	camera.position = Vector2(0, center_y)
	
	if Globals.DEBUG_LOG: print("BattleManager: Камеру центровано на (0, ", center_y, ") для GRID_SIZE ", size)

## Призначає UnitData ворожим вузлам зі сцені на основі конфігу CampaignManager.
## Викликається один раз при старті бою.
func _apply_enemy_config(config: Dictionary) -> void:
	var enemy_nodes: Array = []
	for child in get_parent().get_children():
		if child is CombatUnit and child.team == 1:
			enemy_nodes.append(child)

	# Окремі дефолтні позиції для спавну до 4 ворогів для запобігання стаканню
	var spawn_positions = [
		Vector2(320, 320),  # Ворог 1
		Vector2(400, 440),  # Ворог 2
		Vector2(480, 480),  # Ворог 3
		Vector2(560, 520)   # Ворог 4
	]

	var paths: Array = config.get("enemy_data_paths", [])
	if Globals.DEBUG_LOG: print("BattleManager: _apply_enemy_config — вузлів ворогів: %d, шляхів: %d" % [enemy_nodes.size(), paths.size()])
	for i in range(enemy_nodes.size()):
		if i < paths.size():
			var enemy = enemy_nodes[i]
			enemy.position = spawn_positions[i]
			enemy.set("is_dead", false)
			enemy.visible = true
			
			var unit_data = load(paths[i])
			if unit_data:
				enemy.set("data", unit_data.duplicate())
				var base_name = unit_data.get("unit_name") if "unit_name" in unit_data else tr("BATTLE_ENEMY_FALLBACK")
				enemy.name = base_name + " " + str(i + 1)
				if enemy is CombatUnit:
					enemy.setup_from_data()
					var _d = enemy.get("data")
					if Globals.DEBUG_LOG: print("BattleManager: update_sprite() ДО  — enemy[%d] name='%s' data_path='%s'" % [
						i, enemy.name, _d.resource_path if _d else "null"])
					enemy.update_sprite()
					if Globals.DEBUG_LOG: print("BattleManager: update_sprite() ПІСЛЯ — enemy[%d] OK" % i)
		else:
			# Повністю видаляємо зайві вузли ворогів
			var enemy = enemy_nodes[i]
			enemy.get_parent().remove_child(enemy)
			enemy.queue_free()
