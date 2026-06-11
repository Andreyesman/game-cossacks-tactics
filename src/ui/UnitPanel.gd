extends PanelContainer

const IsoMath = preload("res://src/core/IsoMath.gd")

signal skill_selected(skill_id: String)

# Node references (Lazy initialized)
var name_label: Label
var ap_label: Label
var hp_label: Label
var stamina_label: Label
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var ap_bar: ProgressBar
var body_armor_bar: ProgressBar
var head_armor_bar: ProgressBar
var body_armor_label: Label
var head_armor_label: Label
var icon_rect: ColorRect
var skill_container: HBoxContainer
var morale_label: Label

# Character Sheet
var character_sheet: Control = null

# Intel Panel (Hover tooltip)
var hover_intel_panel: PanelContainer
var current_hovered_unit: Node2D = null

# State
var current_active_unit: Node2D = null

func _ready() -> void:
	_ensure_nodes_ready()
	_init_character_sheet()
	
	# Налаштовуємо динамічне розширення один раз при старті
	position.x = 20
	custom_minimum_size.x = 544 
	_style_panel()

func _style_panel() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.055, 0.05)
	style.border_color = Color(0.48, 0.38, 0.13) # Золотистий бордюр
	style.set_border_width_all(2)
	style.shadow_size = 10
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	
	if name_label:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Золотистий як у CharacterSheet
		name_label.add_theme_font_size_override("font_size", 20)

func _init_character_sheet() -> void:
	var sheet_script = load("res://src/ui/CharacterSheet.gd")
	if not sheet_script: return
	character_sheet = Control.new()
	character_sheet.set_script(sheet_script)
	character_sheet.name = "CharacterSheet"
	# Додаємо до UI-шару (батьківський батько UnitPanel)
	var ui_layer = get_parent()
	if ui_layer:
		ui_layer.add_child.call_deferred(character_sheet)

func _ensure_nodes_ready() -> void:
	if not name_label: name_label = get_node_or_null("HBoxMain/LeftCol/NameLabel")
	if not ap_label: ap_label = get_node_or_null("HBoxMain/LeftCol/APBar/APLabel")
	if not hp_label: hp_label = get_node_or_null("HBoxMain/MidCol/HPBar/HPLabel")
	if not stamina_label: stamina_label = get_node_or_null("HBoxMain/MidCol/StaminaBar/StaminaLabel")
	
	if not hp_bar: hp_bar = get_node_or_null("HBoxMain/MidCol/HPBar")
	if not stamina_bar: stamina_bar = get_node_or_null("HBoxMain/MidCol/StaminaBar")
	if not ap_bar: ap_bar = get_node_or_null("HBoxMain/LeftCol/APBar")
	if not body_armor_bar: body_armor_bar = get_node_or_null("HBoxMain/MidCol/ArmorBodyBar")
	if not head_armor_bar: head_armor_bar = get_node_or_null("HBoxMain/MidCol/ArmorHeadBar")
	
	if not body_armor_label: body_armor_label = get_node_or_null("HBoxMain/MidCol/ArmorBodyBar/ArmorLabel")
	
	if not body_armor_label: body_armor_label = get_node_or_null("HBoxMain/MidCol/ArmorBodyBar/ArmorLabel")
	if not head_armor_label: head_armor_label = get_node_or_null("HBoxMain/MidCol/ArmorHeadBar/HeadLabel")
	
	if not icon_rect: icon_rect = get_node_or_null("HBoxMain/LeftCol/IconRect")
	if icon_rect:
		icon_rect.custom_minimum_size = Vector2(80, 80)
	if not skill_container: skill_container = get_node_or_null("HBoxMain/RightCol/SkillBar")

	if not morale_label:
		morale_label = get_node_or_null("HBoxMain/LeftCol/MoraleBar/MoraleLabel")

# --- PUBLIC API ---

func update_unit_info(unit: Node2D) -> void:
	if not unit: return
	
	self.visible = (unit.get("team") == 0)
	if not self.visible:
		current_active_unit = null
		return
	
	var is_new_unit = (current_active_unit != unit)
	current_active_unit = unit
	
	_ensure_nodes_ready()
	
	if hp_bar and not hp_bar.has_theme_stylebox_override("fill"):
		style_bars()
	
	if is_new_unit:
		_rebuild_skill_bar()
	
	_refresh_active_panel()

# --- PRIVATE LOGIC ---

func _process(delta: float) -> void:
	_refresh_active_panel()
	_update_intel_panel_realtime(delta)

func _refresh_active_panel() -> void:
	if not current_active_unit or not is_instance_valid(current_active_unit): 
		return
		
	var unit = current_active_unit
	var bm_node := get_node_or_null("../../BattleManager")

	# Збираємо поточний стан для порівняння з кешем
	var current_data = {
		"hp": unit.hp,
		"ap": unit.ap,
		"stamina": unit.stamina,
		"morale": unit.get_morale_string() if unit.has_method("get_morale_string") else "",
		"body_armor": unit.body_armor,
		"head_armor": unit.head_armor,
		"is_riposting": unit.get("is_riposting") if "is_riposting" in unit else false,
		"is_loaded": unit.get("is_loaded") if "is_loaded" in unit else true,
		"current_skill": bm_node.current_skill_id if bm_node else ""
	}
	
	# Якщо дані не змінились - виходимо (ОПТИМІЗАЦІЯ)
	if _last_active_data.hash() == current_data.hash():
		return
	_last_active_data = current_data

	if name_label: name_label.text = unit.name
	
	if morale_label:
		var m_str = current_data.morale
		morale_label.text = m_str
		_style_morale_label(morale_label, m_str)
	
	if hp_bar:
		hp_bar.max_value = unit.max_hp
		hp_bar.value = unit.hp
		hp_label.text = "❤️ " + tr("STAT_HP") + ": %d / %d" % [unit.hp, unit.max_hp]
	
	if ap_bar:
		ap_bar.max_value = Globals.AP_MAX
		ap_bar.value = unit.ap
		ap_label.text = "⚡ " + tr("STAT_AP") + ": %d / %d" % [unit.ap, Globals.AP_MAX]
		
	if stamina_bar:
		stamina_bar.max_value = unit.max_stamina
		stamina_bar.value = unit.stamina
		stamina_label.text = "💧 " + tr("STAT_STAMINA") + ": %d / %d" % [unit.stamina, unit.max_stamina]

	# Оновлення Моралі як бару
	_update_morale_bar(unit)
		
	if body_armor_bar:
		body_armor_bar.show()
		var max_ba = max(1, unit.max_body_armor)
		body_armor_bar.max_value = max_ba
		body_armor_bar.value = unit.body_armor
		body_armor_label.text = "🛡️ " + tr("STAT_ARMOR") + ": %d / %d" % [unit.body_armor, unit.max_body_armor]
			
	if head_armor_bar:
		head_armor_bar.show()
		var max_ha = max(1, unit.max_head_armor)
		head_armor_bar.max_value = max_ha
		head_armor_bar.value = unit.head_armor
		head_armor_label.text = "🪖 " + tr("STAT_HELMET") + ": %d / %d" % [unit.head_armor, unit.max_head_armor]
			
	# Оновлення стану кнопок навичок
	if skill_container:
		for btn in _get_all_skill_buttons():
			var skill_id = btn.get_meta("skill_id") if btn.has_meta("skill_id") else ""
			if skill_id != "":
				var is_active = _is_skill_active(unit, skill_id, bm_node)
				style_button(btn, is_active)

func _update_morale_bar(unit: Node2D) -> void:
	if not morale_label: return
	
	# Створюємо бар, якщо його ще немає (замість простого лейбла)
	var bar = morale_label.get_parent() as ProgressBar
	if not bar or bar.name != "MoraleBar":
		var old_label = morale_label
		bar = ProgressBar.new()
		bar.name = "MoraleBar"
		bar.custom_minimum_size = Vector2(200, 32)
		bar.show_percentage = false
		
		# Замінюємо в ієрархії (LeftCol)
		var parent = old_label.get_parent()
		var idx = old_label.get_index()
		parent.add_child(bar)
		parent.move_child(bar, idx)
		parent.remove_child(old_label)
		
		# Додаємо лейбл всередину бару
		bar.add_child(old_label)
		old_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		old_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		old_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		morale_label = old_label

	var m_state = unit.get("current_morale")
	var m_val = 100
	var m_color = Color.GREEN
	match m_state:
		0: m_val = 100; m_color = Color(0.2, 0.9, 0.2) # Confident
		1: m_val = 75; m_color = Color(0.1, 0.6, 0.9)  # Steady
		2: m_val = 50; m_color = Color(0.9, 0.7, 0.1)  # Wavering
		3: m_val = 25; m_color = Color(0.9, 0.4, 0.1)  # Breaking
		4: m_val = 10; m_color = Color(0.8, 0.1, 0.1)  # Fleeing
	
	bar.max_value = 100
	bar.value = m_val
	morale_label.text = unit.get_morale_string()
	
	# Синхронізація стилю тексту
	morale_label.add_theme_color_override("font_color", Color.WHITE)
	morale_label.add_theme_color_override("font_outline_color", Color.BLACK)
	morale_label.add_theme_constant_override("outline_size", 4)
	
	var bg = StyleBoxFlat.new(); bg.bg_color = Color(0.1, 0.1, 0.1)
	var fg = StyleBoxFlat.new(); fg.bg_color = m_color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

	_update_portrait(unit)
	_update_all_action_buttons_state()

func _get_all_skill_buttons() -> Array[Button]:
	var all_buttons: Array[Button] = []
	if not skill_container: return all_buttons
	_find_buttons_recursive(skill_container, all_buttons)
	return all_buttons

func _find_buttons_recursive(node: Node, list: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button:
			list.append(child)
		elif child.get_child_count() > 0:
			_find_buttons_recursive(child, list)

var _button_pool: Array[Button] = []

func _rebuild_skill_bar() -> void:
	if not skill_container or not current_active_unit: return
	var unit = current_active_unit
	
	# Повертаємо всі існуючі кнопки в пул перед очищенням контейнера
	_collect_buttons_to_pool()
	
	# Забезпечуємо розширення контейнера
	skill_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	for child in skill_container.get_children():
		child.queue_free() # Самі контейнери (VBox/HBox) видаляємо
		
	var bm = get_node_or_null("../../BattleManager")
	var skills = unit.available_skills if "available_skills" in unit else []
	
	var TACTICAL_SKILLS = ["recover", "rally"]
	var weapon_skills = skills.filter(func(s): return s.id not in TACTICAL_SKILLS)
	var tactical_skills = skills.filter(func(s): return s.id in TACTICAL_SKILLS)
	
	var weapon_label_text := tr("Без зброї")
	if unit.get("weapon_resource"):
		weapon_label_text = tr(unit.weapon_resource.name)
	else:
		var wt = unit.get("weapon_type") if "weapon_type" in unit else "sword"
		if wt == "musket": weapon_label_text = tr("Яничарка")
		elif wt == "spear": weapon_label_text = tr("Піка")
		elif wt == "heavy": weapon_label_text = tr("Бердиш (2H)")
		else: weapon_label_text = tr("Козацька Шабля")
	
	# --- БЛОК 1: ЗБРОЯ ---
	var weapon_section = VBoxContainer.new()
	skill_container.add_child(weapon_section)
	
	var weapon_header = Label.new()
	weapon_header.text = weapon_label_text
	weapon_header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	weapon_section.add_child(weapon_header)
	
	var weapon_row = HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 6)
	weapon_section.add_child(weapon_row)
	
	for skill in weapon_skills:
		var btn = _create_skill_button(skill, unit, bm)
		weapon_row.add_child(btn)
	
	# --- БЛОК 2: НАВИЧКИ ---
	var skill_section = VBoxContainer.new()
	skill_container.add_child(skill_section)
	skill_section.add_theme_constant_override("separation", 4)
	
	var skill_header = Label.new()
	skill_header.text = tr("UI_SKILLS")
	skill_header.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
	skill_section.add_child(skill_header)
	
	var tactic_row = HBoxContainer.new()
	tactic_row.add_theme_constant_override("separation", 6)
	skill_section.add_child(tactic_row)
	
	for skill in tactical_skills:
		var btn = _create_skill_button(skill, unit, bm)
		tactic_row.add_child(btn)
	
	if not unit.get("has_waited") and unit.get("team") == 0:
		var wait_btn = _get_button_from_pool()
		wait_btn.toggle_mode = false
		wait_btn.button_pressed = false
		wait_btn.disabled = false
		# Очищуємо кастомну розмітку з попереднього використання (remove_child щоб одразу, не defer)
		for child in wait_btn.get_children():
			wait_btn.remove_child(child)
			child.queue_free()

		style_button(wait_btn, false)
		wait_btn.text = "🕒 " + tr("UI_WAIT")
		wait_btn.custom_minimum_size = Vector2(96, 52)
		_disconnect_all(wait_btn.pressed)
		_disconnect_all(wait_btn.mouse_entered)
		_disconnect_all(wait_btn.mouse_exited)
		wait_btn.pressed.connect(func(): if bm: bm.wait_current_unit())
		wait_btn.mouse_entered.connect(func(): FloatingLabel.show_label(tr("UI_WAIT_TOOLTIP")))
		wait_btn.mouse_exited.connect(func(): FloatingLabel.hide_label())
		tactic_row.add_child(wait_btn)

func _collect_buttons_to_pool() -> void:
	var buttons = _get_all_skill_buttons()
	for btn in buttons:
		if btn.get_parent():
			btn.get_parent().remove_child(btn)
		_button_pool.append(btn)

func _get_button_from_pool() -> Button:
	if _button_pool.is_empty():
		return Button.new()
	return _button_pool.pop_back()

func _disconnect_all(sig: Signal) -> void:
	for conn in sig.get_connections():
		sig.disconnect(conn.callable)

func _create_skill_button(skill: Dictionary, unit: Node2D, bm: Node) -> Button:
	var btn = _get_button_from_pool()
	
	_disconnect_all(btn.pressed)
	_disconnect_all(btn.mouse_entered)
	_disconnect_all(btn.mouse_exited)
	
	var is_active = _is_skill_active(unit, skill.id, bm)
	btn.toggle_mode = false
	style_button(btn, is_active)
	
	btn.text = "" # Використовуємо кастомну розмітку
	btn.custom_minimum_size = Vector2(96, 52)
	
	# Очищуємо старі елементи негайно (щоб уникнути конфліктів імен у find_child)
	for child in btn.get_children():
		btn.remove_child(child)
		child.queue_free()
		
	var vb = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	btn.add_child(vb)
	
	var nl = Label.new()
	nl.name = "NameLabel"
	nl.text = tr(skill.name)
	nl.add_theme_font_size_override("font_size", 12)
	nl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6) if not btn.disabled else Color(0.5, 0.5, 0.5))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	
	var hb_cost = HBoxContainer.new()
	hb_cost.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_cost.add_theme_constant_override("separation", 4)
	hb_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb_cost)
	
	var ap_c = Color(0.1, 0.6, 0.2)
	var st_c = Color(0.1, 0.3, 0.8)
	
	var ap_lbl = Label.new()
	ap_lbl.name = "APLabel"
	ap_lbl.text = "⚡ %d" % skill.ap
	ap_lbl.add_theme_font_size_override("font_size", 10)
	ap_lbl.add_theme_color_override("font_color", ap_c)
	hb_cost.add_child(ap_lbl)
	
	var sep = Label.new(); sep.text = "|"; sep.add_theme_font_size_override("font_size", 10)
	hb_cost.add_child(sep)
	
	var stam_lbl = Label.new()
	stam_lbl.name = "StaminaLabel"
	stam_lbl.text = "💧 %d" % skill.stamina
	stam_lbl.add_theme_font_size_override("font_size", 10)
	stam_lbl.add_theme_color_override("font_color", st_c)
	hb_cost.add_child(stam_lbl)

	# Додаємо інформацію про тип шкоди та бонуси в тултіп
	var raw_desc: String = skill.get("desc", "")
	var tooltip := tr(raw_desc) if raw_desc != "" else ""
	if skill.has("damage_type"):
		var dt_name := tr("DAMAGE_SLASH")
		match skill.damage_type:
			1: dt_name = tr("DAMAGE_PIERCE")
			2: dt_name = tr("DAMAGE_BLUNT")
			3: dt_name = tr("DAMAGE_FIRE")
			4: dt_name = tr("DAMAGE_RANGED")
		tooltip += "\n[color=gray]" + tr("SKILL_TOOLTIP_TYPE") % dt_name + "[/color]"

	if skill.get("hit_mod", 0) != 0:
		tooltip += "\n[color=green]" + tr("SKILL_TOOLTIP_HIT") % skill.hit_mod + "[/color]"
	if skill.get("head_bonus", 0) != 0:
		tooltip += "\n[color=orange]" + tr("SKILL_TOOLTIP_HEAD_BONUS") % int(skill.head_bonus * 100) + "[/color]"
	if skill.get("guaranteed_head", false):
		tooltip += "\n[color=red]" + tr("SKILL_TOOLTIP_GUARANTEED_HEAD") + "[/color]"
		
	btn.set_meta("skill_id", skill.id)
	btn.set_meta("skill_ap", skill.ap)
	btn.set_meta("skill_stamina", skill.stamina)
	
	if skill.id == "rally":
		btn.pressed.connect(func(): if bm: bm.activate_rally_immediately())
	elif skill.id == "riposte":
		btn.pressed.connect(func(): if bm: bm.activate_riposte_immediately())
	elif skill.id == "reload":
		var s_ref = skill
		btn.pressed.connect(func(): 
			if unit.has_method("execute_reload") and not unit.is_loaded: 
				unit.execute_reload(s_ref)
				if bm:
					bm.current_skill_id = ""
					if bm.unit_panel: bm.unit_panel.update_unit_info(unit)
					if unit.ap == 0: bm.end_unit_turn()
		)
	elif skill.id == "recover":
		var s_ref = skill
		btn.pressed.connect(func():
			if unit.has_method("execute_recover"):
				unit.execute_recover(s_ref)
		)
	else:
		btn.pressed.connect(func(): skill_selected.emit(skill.id))
		
	btn.mouse_entered.connect(func():
		if bm: bm.hover_skill_id = skill.id; if bm.tile_map: bm.tile_map.queue_redraw()
		if tooltip != "": FloatingLabel.show_label(tooltip)
	)
	btn.mouse_exited.connect(func():
		if bm: bm.hover_skill_id = ""; if bm.tile_map: bm.tile_map.queue_redraw()
		FloatingLabel.hide_label()
	)
	
	return btn

func _update_all_action_buttons_state() -> void:
	if not current_active_unit or not skill_container: return
	
	var is_player = (current_active_unit.team == 0)
	skill_container.visible = is_player
	if not is_player: return
	
	var unit = current_active_unit
	
	var all_buttons = _get_all_skill_buttons()
	
	for btn in all_buttons:
		if btn.has_meta("skill_ap"):
			var s_ap = btn.get_meta("skill_ap")
			var s_stam = btn.get_meta("skill_stamina")
			var s_id = btn.get_meta("skill_id")
			
			btn.disabled = (unit.ap < s_ap or unit.stamina < s_stam)
			
			if s_id == "shoot" and "is_loaded" in unit and not unit.is_loaded:
				btn.disabled = true
			if s_id == "reload" and "is_loaded" in unit and unit.is_loaded:
				btn.disabled = true
				
			# Оновлюємо кольори підписів відповідно до стану
			# Ми використовуємо find_child з owner=false, щоб знайти нові вузли
			var nl = btn.find_child("NameLabel", true, false)
			var ap_l = btn.find_child("APLabel", true, false)
			var st_l = btn.find_child("StaminaLabel", true, false)
			
			var is_btn_disabled = btn.disabled
			
			if nl: nl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6) if not is_btn_disabled else Color(0.5, 0.5, 0.5))
			if ap_l: ap_l.add_theme_color_override("font_color", Color(0.1, 0.6, 0.2) if not is_btn_disabled else Color(0.4, 0.4, 0.4))
			if st_l: st_l.add_theme_color_override("font_color", Color(0.1, 0.3, 0.8) if not is_btn_disabled else Color(0.4, 0.4, 0.4))

		if tr("UI_WAIT") in btn.text:
			btn.disabled = (unit.ap < 1)

func _style_morale_label(label: Label, m_str: String) -> void:
	if tr("MORALE_CONFIDENT") in m_str: label.add_theme_color_override("font_color", Color.GREEN)
	elif tr("MORALE_STEADY") in m_str: label.add_theme_color_override("font_color", Color.WHITE)
	elif tr("MORALE_WAVERING") in m_str: label.add_theme_color_override("font_color", Color.ORANGE)
	elif tr("MORALE_BREAKING") in m_str: label.add_theme_color_override("font_color", Color.ORANGE_RED)
	elif tr("MORALE_FLEEING") in m_str: label.add_theme_color_override("font_color", Color.PURPLE)
	else: label.add_theme_color_override("font_color", Color.GRAY)

# --- STYLING ---

func style_button(btn: Button, is_active: bool) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.18)
	normal.border_width_bottom = 3
	normal.border_color = Color(0.08, 0.08, 0.1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	
	var hover = normal.duplicate()
	hover.bg_color = Color(0.25, 0.25, 0.3)
	hover.border_color = Color(0.4, 0.4, 0.6)
	hover.set_border_width_all(1)
	
	var active = StyleBoxFlat.new()
	active.bg_color = Color(0.7, 0.5, 0.1) # Яскравіший золотистий
	active.set_border_width_all(3) 
	active.border_color = Color(1.0, 1.0, 0.6) # Світле золото (майже білий блиск)
	active.set_corner_radius_all(4)
	active.shadow_size = 4
	active.shadow_color = Color(1, 0.8, 0, 0.3)
	active.content_margin_left = 12
	active.content_margin_right = 12
	active.content_margin_top = 8
	active.content_margin_bottom = 8
	
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.05, 0.05, 0.05, 0.7)
	disabled.border_width_bottom = 0
	
	btn.add_theme_stylebox_override("normal", active if is_active else normal)
	btn.add_theme_stylebox_override("hover", active if is_active else hover)
	btn.add_theme_stylebox_override("focus", active if is_active else normal)
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("disabled", disabled)
	
	# Колір тексту для активної кнопки - ТЕПЕР ЖОВТИЙ для максимального контрасту
	var text_color = Color.YELLOW if is_active else Color(0.9, 0.9, 0.9)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", text_color)

func _is_skill_active(unit: Node2D, skill_id: String, bm: Node) -> bool:
	if not bm: return false
	# Стан 1: Навичка обрана гравцем для застосування зараз
	if bm.current_skill_id == skill_id: return true
	# Стан 2: Навичка є активною стійкою (Persistent stance)
	if skill_id == "riposte" and unit.get("is_riposting"): return true
	return false

func style_bars() -> void:
	if not hp_bar: return
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.2, 0.2, 0.2)
	
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.8, 0.1, 0.1) # Червоний
	
	var stam_fill = StyleBoxFlat.new()
	stam_fill.bg_color = Color(0.1, 0.3, 0.8) # Синій
	
	var ap_fill = StyleBoxFlat.new()
	ap_fill.bg_color = Color(0.1, 0.6, 0.2) # Темно-зелений
	
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	
	if stamina_bar:
		stamina_bar.add_theme_stylebox_override("background", bg)
		stamina_bar.add_theme_stylebox_override("fill", stam_fill)
	
	if ap_bar:
		ap_bar.add_theme_stylebox_override("background", bg)
		ap_bar.add_theme_stylebox_override("fill", ap_fill)

	if body_armor_bar:
		body_armor_bar.add_theme_stylebox_override("background", bg)
		var f = StyleBoxFlat.new(); f.bg_color = Color(0.6, 0.5, 0.4)
		body_armor_bar.add_theme_stylebox_override("fill", f)

	if head_armor_bar:
		head_armor_bar.add_theme_stylebox_override("background", bg)
		var f = StyleBoxFlat.new(); f.bg_color = Color(0.5, 0.5, 0.6)
		head_armor_bar.add_theme_stylebox_override("fill", f)

	# Чорна обводка для всіх лейблів барів (читабельність)
	for lbl in [ap_label, hp_label, stamina_label, body_armor_label, head_armor_label]:
		if lbl:
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 4)

func has_enemy_in_range(unit: Node2D, radius: int) -> bool:
	if not unit: return false
	var parent = unit.get_parent()
	if not parent: return false
	
	var my_map_pos = IsoMath.local_to_map(unit.position)
	for child in parent.get_children():
		if child is CombatUnit and not child.get("is_dead") and child.get("team") != unit.team:
			var e_map = IsoMath.local_to_map(child.position)
			if IsoMath.get_dist_4(my_map_pos, e_map) <= radius:
				return true
	return false

var _intel_tween: Tween
var _hover_timer: float = 0.0
var _pending_intel_unit: Node2D = null

# Кешування для оптимізації
var _last_active_data: Dictionary = {}
var _last_intel_data: Dictionary = {}

func show_hover_intel(unit: Node2D) -> void:
	if not hover_intel_panel: create_intel_panel()
	
	# Якщо ціль не змінилась - нічого не робимо
	if unit == current_hovered_unit and unit != null: return
	
	# Якщо ми перемикаємось між двома РЕАЛЬНИМИ юнітами і панель вже видима - оновлюємо МИТТЄВО
	if unit != null and current_hovered_unit != null and hover_intel_panel.visible:
		_pending_intel_unit = unit
		_activate_hover_intel(unit, true) # Спеціальний режим "Швидке перемикання"
		return
	
	# Скидаємо таймер при кожній зміні цілі (для першого наведення)
	if unit != _pending_intel_unit:
		_pending_intel_unit = unit
		_hover_timer = 0.08 if unit != null else 0.0
	
	if not unit:
		_pending_intel_unit = null
		if _intel_tween: _intel_tween.kill()
		_intel_tween = create_tween()
		_intel_tween.tween_property(hover_intel_panel, "modulate:a", 0.0, 0.1)
		_intel_tween.tween_callback(hover_intel_panel.hide)
		current_hovered_unit = null
		_last_intel_data.clear()
		return

func _update_intel_panel_realtime(delta: float) -> void:
	# Обробка затримки появи (Debounce)
	if _pending_intel_unit != null and current_hovered_unit != _pending_intel_unit:
		if _hover_timer > 0:
			_hover_timer -= delta
			return
		else:
			# Таймер вийшов - показуємо
			_activate_hover_intel(_pending_intel_unit)

	if hover_intel_panel and hover_intel_panel.visible:
		var target_pos = _clamp_intel_pos(hover_intel_panel.get_global_mouse_position())
		# Швидкий слідуючий рух
		hover_intel_panel.global_position = hover_intel_panel.global_position.lerp(target_pos, 0.3)
		
		if current_hovered_unit: _update_intel_text(current_hovered_unit)

func _activate_hover_intel(unit: Node2D, fast_switch: bool = false) -> void:
	if not is_instance_valid(unit): return
	if has_node("/root/FloatingLabel"): get_node("/root/FloatingLabel").hide_label()
	
	if _intel_tween: _intel_tween.kill()
	
	if fast_switch:
		current_hovered_unit = unit
		_last_intel_data.clear()
		_update_intel_text(unit)
		hover_intel_panel.show()
		hover_intel_panel.modulate.a = 1.0
		return

	_intel_tween = create_tween()
	if hover_intel_panel.visible and current_hovered_unit != null:
		# Це старий шлях для перемикання з великою паузою - ми його майже не використовуємо тепер
		current_hovered_unit = unit
		_last_intel_data.clear()
		_update_intel_text(unit)
	else:
		current_hovered_unit = unit
		_last_intel_data.clear()
		_update_intel_text(unit)
		hover_intel_panel.global_position = _clamp_intel_pos(hover_intel_panel.get_global_mouse_position())
		hover_intel_panel.show()
		_intel_tween.tween_property(hover_intel_panel, "modulate:a", 1.0, 0.15).from(0.0)

func _update_intel_text(unit: Node2D) -> void:
	if not hover_intel_panel: return
	var l_name = hover_intel_panel.get_node("VBox/Name")
	var l_stats = hover_intel_panel.get_node("VBox/Stats")
	
	# Отримуємо додаткові дані (Шанс влучання, режим)
	var bm = get_node_or_null("../../BattleManager")
	var hit_chance = -1
	var current_skill = ""
	if bm and bm.active_unit and bm.active_unit != unit:
		current_skill = bm.current_skill_id
		if current_skill != "":
			hit_chance = bm.active_unit.get_potential_hit_chance(unit)
	
	# Збираємо стан для порівняння
	var current_data = {
		"hp": unit.hp,
		"ap": unit.ap,
		"stamina": unit.stamina,
		"morale": unit.get_morale_string() if unit.has_method("get_morale_string") else "",
		"body_armor": unit.body_armor,
		"head_armor": unit.head_armor,
		"is_riposting": unit.get("is_riposting") if "is_riposting" in unit else false,
		"hit_chance": hit_chance,
		"skill": current_skill
	}
	
	# Виходимо, якщо нічого не змінилось (ОПТИМІЗАЦІЯ)
	if _last_intel_data.hash() == current_data.hash():
		return
	_last_intel_data = current_data
	
	# Визначаємо назву зброї для підказки
	var wt = unit.get("weapon_type") if "weapon_type" in unit else "sword"
	var wt_name = tr("WEAPON_TYPE_SWORD")
	if wt == "musket": wt_name = tr("WEAPON_TYPE_MUSKET")
	elif wt == "spear": wt_name = tr("Спис")
	elif wt == "heavy": wt_name = tr("WEAPON_TYPE_HEAVY")
	
	l_name.text = unit.name + (" - " + current_data.morale if current_data.morale != "" else "")
	
	if unit.get("is_dead"):
		l_stats.text = tr("UI_DEAD")
	else:
		var weapon_line = "[color=orange]" + tr("SLOT_WEAPON") + ": %s[/color]\n" % wt_name
		var stance_str = ""
		if current_data.is_riposting: stance_str = "\n" + tr("UI_RIPOSTE_STANCE")
		
		# Передперегляд шансу влучання
		var hit_preview = ""
		if hit_chance >= 0:
			# Перевірка чи ціль в радіусі для відображення шансу
			var active = bm.active_unit
			var dist = IsoMath.get_dist_4(IsoMath.local_to_map(active.position), IsoMath.local_to_map(unit.position))
			var skill_data = null
			for s in active.available_skills:
				if s.id == current_skill:
					skill_data = s
					break
			if skill_data and skill_data.get("range", 0) >= dist:
				hit_preview = "\n[color=cyan]" + tr("UI_HIT_CHANCE") + "[/color] [b]%d%%[/b]" % hit_chance
				
				# Перевірка дружнього вогню
				if current_skill == "shoot":
					var grid = get_node_or_null("../../TacticalGrid")
					if grid:
						var los = grid.check_line_of_sight(IsoMath.local_to_map(active.position), IsoMath.local_to_map(unit.position))
						if los["has_friendly_fire_risk"]:
							hit_preview += "\n[color=orange][b]" + tr("UI_FRIENDLY_FIRE") + "[/b][/color]"
			
		l_stats.text = "%s❤️: %d/%d | ⚡: %d/%d | 💧: %d/%d\n🛡️: %d/%d | 🪖: %d/%d%s%s" % [
			weapon_line,
			unit.hp, unit.max_hp, unit.ap, Globals.AP_MAX, unit.stamina, unit.max_stamina, 
			unit.body_armor, unit.max_body_armor, unit.head_armor, unit.max_head_armor, stance_str, hit_preview
		]

func show_hover_terrain(terrain_type: int) -> void:
	var fl = get_node_or_null("/root/FloatingLabel")
	if terrain_type < 0:
		if fl: fl.hide_label("terrain")
		return
	var info = _get_terrain_tooltip_text(terrain_type)
	if fl: fl.show_label(info["name"], info["color"], "terrain")

func _get_terrain_tooltip_text(terrain_type: int) -> Dictionary:
	match terrain_type:
		1: return {"name": tr("TERRAIN_BUSHES_INFO"), "color": Color(0.3, 0.8, 0.3)}
		2: return {"name": tr("TERRAIN_SWAMP_INFO"), "color": Color(0.7, 0.6, 0.2)}
		3: return {"name": tr("TERRAIN_WATER_INFO"), "color": Color(0.3, 0.6, 0.9)}
		4: return {"name": tr("TERRAIN_ROCKS_INFO"), "color": Color(0.7, 0.7, 0.7)}
		5: return {"name": tr("TERRAIN_TREES_INFO"), "color": Color(0.5, 0.3, 0.1)}
		_: return {"name": "", "color": Color.WHITE}

func create_intel_panel() -> void:
	hover_intel_panel = PanelContainer.new()
	hover_intel_panel.top_level = true
	hover_intel_panel.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.96)
	style.border_color = Color(0.48, 0.38, 0.13, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hover_intel_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	var l_name = Label.new()
	l_name.name = "Name"
	l_name.add_theme_font_size_override("font_size", 20)
	l_name.add_theme_color_override("font_color", Color.GOLD)
	var l_stats = RichTextLabel.new()
	l_stats.name = "Stats"
	l_stats.bbcode_enabled = true
	l_stats.fit_content = true
	l_stats.scroll_active = false
	l_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	vbox.add_child(l_name)
	vbox.add_child(l_stats)
	hover_intel_panel.add_child(vbox)
	get_parent().add_child(hover_intel_panel)
	hover_intel_panel.hide()
	hover_intel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _clamp_intel_pos(mouse_pos: Vector2) -> Vector2:
	var pos = mouse_pos + Vector2(20, 16)
	var v_size = get_viewport().get_visible_rect().size
	var p_size = hover_intel_panel.size
	if pos.x + p_size.x > v_size.x: pos.x = mouse_pos.x - p_size.x - 8
	if pos.y + p_size.y > v_size.y: pos.y = mouse_pos.y - p_size.y - 8
	return pos

func _update_portrait(unit: Node2D) -> void:
	if not icon_rect: return

	# Базовий колір фону
	var base_color = Color(0.3, 0.7, 1.0, 0.45) if unit.get("team") == 0 else Color(0.4, 0.0, 0.1, 0.6)
	icon_rect.color = base_color

	var portrait = icon_rect.get_node_or_null("Portrait")
	if not portrait:
		portrait = TextureRect.new()
		portrait.name = "Portrait"
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.add_child(portrait)
	if unit.has_method("get_portrait"):
		portrait.texture = unit.get_portrait()

	# Обводка підсвічування (додається один раз)
	if not icon_rect.has_node("BorderOverlay"):
		var border = ReferenceRect.new() # Використовуємо ReferenceRect або Panel для рамки
		border.name = "BorderOverlay"
		border.editor_only = false
		border.border_color = Color(0.3, 0.3, 0.3, 0.5)
		border.border_width = 2.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.add_child(border)

	# Обробник кліку з ефектами hover (додається один раз)
	if not icon_rect.has_meta("click_connected"):
		icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var border_node = icon_rect.get_node("BorderOverlay")

		icon_rect.mouse_entered.connect(func():
			icon_rect.color = base_color.lightened(0.2)
			border_node.border_color = Color(0.8, 0.7, 0.3, 1.0)
		)
		icon_rect.mouse_exited.connect(func():
			icon_rect.color = base_color
			border_node.border_color = Color(0.3, 0.3, 0.3, 0.5)
		)
		icon_rect.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if character_sheet and current_active_unit:
					# Flash підсвітки при кліку
					border_node.border_color = Color(1.0, 1.0, 1.0, 1.0)
					icon_rect.color = base_color.lightened(0.35)
					character_sheet.open(current_active_unit)
		)
		icon_rect.set_meta("click_connected", true)
