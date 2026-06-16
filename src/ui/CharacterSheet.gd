extends Control

# Вікно персонажа (Character Sheet) — відкривається по кліку на портрет у UnitPanel




var _unit: Node2D = null
var _panel: PanelContainer
var _content: VBoxContainer

func _ready() -> void:
	_build_overlay()
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP

func _build_overlay() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Темний напівпрозорий фон (клік закриває вікно)
	var overlay_bg = ColorRect.new()
	overlay_bg.name = "OverlayBG"
	overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_bg.color = Color(0, 0, 0, 0.65)
	overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_bg.gui_input.connect(_on_overlay_clicked)
	add_child(overlay_bg)

	# Центрований контейнер
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Головна панель (статична ширина 520px)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	UIStyle.apply_panel(_panel, Color.WHITE, Vector4(2, 2, 2, 2))
	center.add_child(_panel)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 100) # Мінімальна початкова висота
	_panel.add_child(scroll)

	var mc = MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 16)
	mc.add_theme_constant_override("margin_right", 16)
	mc.add_theme_constant_override("margin_top", 16)
	mc.add_theme_constant_override("margin_bottom", 16)
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(mc)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	mc.add_child(_content)

	# Автоприховування скролбару
	var v_scroll = scroll.get_v_scroll_bar()
	v_scroll.modulate.a = 0.0
	scroll.gui_input.connect(func(event):
		if event is InputEventMouseButton:
			_show_scrollbar(v_scroll)
	)
	v_scroll.value_changed.connect(func(_val): _show_scrollbar(v_scroll))

	# Оновлюємо висоту при зміні розміру вікна
	get_tree().root.size_changed.connect(_update_panel_size)
	_update_panel_size()

var _scroll_tween: Tween
func _show_scrollbar(sb: ScrollBar) -> void:
	if _scroll_tween: _scroll_tween.kill()
	sb.modulate.a = 1.0
	_scroll_tween = create_tween()
	_scroll_tween.tween_interval(1.5)
	_scroll_tween.tween_property(sb, "modulate:a", 0.0, 0.5)

func _update_panel_size() -> void:
	if not _panel or not _content: return
	var v_size = get_viewport_rect().size
	var scroll = _panel.get_child(0)
	if scroll:
		# Примусово оновлюємо розрахунок розмірів контенту
		_content.update_minimum_size()
		var content_height = _content.get_combined_minimum_size().y
		
		# Обмежуємо висоту: не більше ніж (екран - 200px відступів)
		var max_allowed = v_size.y - 200
		
		# Встановлюємо висоту скролу рівною контенту (з лімітом)
		scroll.custom_minimum_size.y = min(content_height, max_allowed)
		# Також скидаємо вертикальну розтяжку панелі
		_panel.size.y = 0

# --- PUBLIC API ---

func open(unit: Node2D) -> void:
	_unit = unit
	# Якщо вузол ще не готовий (add_child.call_deferred) - чекаємо
	if not _content:
		await get_tree().process_frame
		await get_tree().process_frame
	if not _content:
		push_error("CharacterSheet: failed to initialize _content")
		return
	_refresh()
	_update_panel_size()
	show()
	modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self , "modulate:a", 1.0, 0.15)
	tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK)

func close() -> void:
	if _scroll_tween:
		_scroll_tween.kill()
		_scroll_tween = null
	var tween = create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.1)
	tween.tween_callback(hide)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

# --- ЗБІРКА UI ---

func _refresh() -> void:
	if not _unit or not _content: return
	# Миттєво видаляємо старих нащадків
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_build_header()
	_add_separator()
	_build_origin()
	_add_separator()
	_build_equipment()
	_add_separator()
	_build_attacks()
	_add_separator()
	_build_stats()

func _build_header() -> void:
	# Портрет + Ім'я/Рівень/XP
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_content.add_child(header)

	# Портрет
	var portrait_bg = PanelContainer.new()
	portrait_bg.custom_minimum_size = Vector2(80, 80) # 1:1 (Стандарт)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.12, 0.18)
	ps.border_color = Color(0.5, 0.4, 0.15)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(4)
	portrait_bg.add_theme_stylebox_override("panel", ps)
	header.add_child(portrait_bg)

	# Портрет: кольорова плитка + текстура
	var color_rect = ColorRect.new()
	color_rect.color = Color(0.0, 0.35, 0.35, 0.8) if (_unit.get("team") == 0) else Color(0.35, 0.0, 0.05, 0.8)
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_bg.add_child(color_rect)

	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_bg.add_child(portrait)
	
	if _unit.has_method("get_portrait"):
		portrait.texture = _unit.get_portrait()

	# Колонка: Ім'я, Рівень, XP
	var info_col = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 6)
	header.add_child(info_col)

	var name_lbl = Label.new()
	name_lbl.text = _unit.name
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	info_col.add_child(name_lbl)

	var lvl = _unit.get("level") if "level" in _unit else 1
	var xp_cur = _unit.get("xp") if "xp" in _unit else 0
	var xp_next = _unit.get("xp_to_next") if "xp_to_next" in _unit else 150

	var xp_hbox = HBoxContainer.new()
	xp_hbox.add_theme_constant_override("separation", 10)
	info_col.add_child(xp_hbox)

	var level_lbl = Label.new()
	level_lbl.text = tr("STAT_LEVEL") + " %d" % lvl
	level_lbl.add_theme_font_size_override("font_size", 18)
	level_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	xp_hbox.add_child(level_lbl)

	var xp_bar = ProgressBar.new()
	xp_bar.max_value = xp_next
	xp_bar.value = xp_cur
	xp_bar.show_percentage = false
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.custom_minimum_size = Vector2(0, 24)
	var xp_bg = StyleBoxFlat.new(); xp_bg.bg_color = Color(0.08, 0.08, 0.12)
	var xp_fill = StyleBoxFlat.new(); xp_fill.bg_color = Color(0.25, 0.55, 0.95)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_hbox.add_child(xp_bar)

	var xp_lbl = Label.new()
	xp_lbl.text = "%d / %d XP" % [xp_cur, xp_next]
	xp_lbl.add_theme_font_size_override("font_size", 14)
	xp_lbl.add_theme_color_override("font_color", Color.WHITE)
	xp_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_bar.add_child(xp_lbl)

func _build_equipment() -> void:
	var eq_vbox = VBoxContainer.new()
	eq_vbox.add_theme_constant_override("separation", 10)
	_content.add_child(eq_vbox)

	var wt = _unit.get("weapon_type") if "weapon_type" in _unit else "sword"
	var is_2h = _is_two_handed(wt)
	var has_helm = false
	var has_armor = false
	if "data" in _unit and _unit.data:
		has_helm = _unit.data.base_head_armor > 0
		has_armor = _unit.data.base_body_armor > 0

	var weapon_icon = "⚔️"
	var weapon_text = tr("WEAPON_TYPE_SWORD")
	var w_tooltip = ""

	if _unit.get("weapon_resource"):
		var wr = _unit.weapon_resource
		weapon_text = wr.name
		is_2h = wr.is_two_handed
		w_tooltip = _get_weapon_resource_tooltip(wr)
		
		# Вибираємо іконку на основі типу зброї
		match wr.type:
			0: weapon_icon = "⚔️" # SWORD
			1: weapon_icon = "🔱" # SPEAR
			2: weapon_icon = "🪓" # AXE
			3: weapon_icon = "🔨" # MACE
			4: weapon_icon = "🔫" # MUSKET
			5: weapon_icon = "🪓" # POLEARM
			7: weapon_icon = "🏹" # BOW
			_: weapon_icon = "⚔️"
	else:
		if wt == "musket": weapon_icon = "🔫"; weapon_text = tr("Яничарка")
		elif wt == "spear": weapon_icon = "🔱"; weapon_text = tr("Піка (2H)")
		elif wt == "heavy": weapon_icon = "🪓"; weapon_text = tr("Бердиш (2H)")
		w_tooltip = _get_weapon_tooltip(wt)

	# item_id для іконок
	var weapon_item_id := ""
	if _unit.get("weapon_resource"):
		var _wr_path: String = _unit.weapon_resource.resource_path
		weapon_item_id = _wr_path.get_file().get_basename()
	var _a_raw: Variant = _unit.get("armor_path")
	var armor_item_id: String = (_a_raw as String).get_file().get_basename() if _a_raw is String else ""
	var _h_raw: Variant = _unit.get("helm_path")
	var helm_item_id: String = (_h_raw as String).get_file().get_basename() if _h_raw is String else ""

	# Ряд 1: Прикраса (1:1), Шолом (1:1), Стріли (1:1)
	var row1 = HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 10)
	eq_vbox.add_child(row1)
	row1.add_child(_equipment_slot("○", tr("SLOT_TRINKET"), false, Vector2(100, 100), "[color=gray]" + tr("CS_SLOT_TRINKET_TOOLTIP") + "[/color]"))
	var h_tooltip = "[b][color=#c8a050]" + tr("STAT_HELMET") + "[/color][/b]\n[color=gray]" + tr("CS_SLOT_HELMET_TOOLTIP") + "[/color]" if has_helm else ""
	row1.add_child(_equipment_slot(("🪖" if has_helm else "○"), tr("STAT_HELMET"), has_helm, Vector2(100, 100), h_tooltip, helm_item_id))
	var ammo_tooltip = "[b][color=#c8a050]" + tr("SLOT_AMMO") + "[/color][/b]\n[color=gray]" + tr("CS_SLOT_AMMO_TOOLTIP") + "[/color]" if (wt == "musket" or (_unit.get("weapon_resource") and _unit.weapon_resource.type == 4)) else ""
	row1.add_child(_equipment_slot(("🏹" if (wt == "musket" or (_unit.get("weapon_resource") and _unit.weapon_resource.type == 4)) else "○"), tr("SLOT_AMMO"), (wt == "musket" or (_unit.get("weapon_resource") and _unit.weapon_resource.type == 4)), Vector2(100, 100), ammo_tooltip))

	# Ряд 2: Зброя (1:2), Броня (1:2), Щит (1:2)
	var row2 = HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 10)
	eq_vbox.add_child(row2)
	
	row2.add_child(_equipment_slot(weapon_icon, weapon_text, true, Vector2(100, 180), w_tooltip, weapon_item_id))

	var a_tooltip = "[b][color=#c8a050]" + tr("STAT_ARMOR") + "[/color][/b]\n[color=gray]" + tr("CS_SLOT_ARMOR_TOOLTIP") + "[/color]" if has_armor else ""
	row2.add_child(_equipment_slot(("🛡️" if has_armor else "○"), tr("STAT_ARMOR"), has_armor, Vector2(100, 180), a_tooltip, armor_item_id))

	if is_2h:
		row2.add_child(_equipment_slot(weapon_icon, weapon_text, true, Vector2(100, 180), w_tooltip, weapon_item_id))
	else:
		row2.add_child(_equipment_slot("○", tr("SLOT_SHIELD"), false, Vector2(100, 180)))

	# Ряд 3: Пояс (3 слоти 1:1)
	var row3 = HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	row3.add_theme_constant_override("separation", 10)
	eq_vbox.add_child(row3)
	var belt_tip := "[color=gray]" + tr("CS_SLOT_BELT_TOOLTIP") + "[/color]"
	row3.add_child(_equipment_slot("○", tr("SLOT_BELT"), false, Vector2(100, 100), belt_tip))
	row3.add_child(_equipment_slot("○", tr("SLOT_BELT"), false, Vector2(100, 100), belt_tip))
	row3.add_child(_equipment_slot("○", tr("SLOT_BELT"), false, Vector2(100, 100), belt_tip))

func _is_two_handed(type: String) -> bool:
	return type in ["musket", "spear", "heavy", "bow"]

func _get_weapon_resource_tooltip(wr: WeaponResource) -> String:
	var name_colored = "[b][color=#c8a050]%s[/color][/b]" % wr.name
	var damage = "[color=gray]" + tr("WEAPON_STAT_DAMAGE") + "[/color] [color=#e8c870]%d-%d[/color]" % [wr.damage_min, wr.damage_max]
	var pen = "[color=gray]" + tr("WEAPON_STAT_PEN") + "[/color] [color=#6cb4ee]%d%%[/color]" % int(wr.armor_penetration * 100)
	var type_str = tr("WEAPON_TYPE_ONE_HAND") if not wr.is_two_handed else tr("WEAPON_TYPE_TWO_HAND")
	var type_info = "[color=gray]" + tr("WEAPON_STAT_TYPE") + "[/color] [color=white]%s[/color]" % type_str
	return "%s\n%s\n%s\n%s" % [name_colored, damage, pen, type_info]

func _get_weapon_tooltip(type: String) -> String:
	var dmg = "[color=gray]" + tr("WEAPON_STAT_DAMAGE") + "[/color]"
	var pen = "[color=gray]" + tr("WEAPON_STAT_PEN") + "[/color]"
	match type:
		"sword": return "[b][color=#c8a050]%s[/color][/b]\n%s [color=#e8c870]35-45[/color]\n%s [color=#6cb4ee]20%%[/color]\n[color=gray][i]%s[/i][/color]" % [tr("Козацька Шабля"), dmg, pen, tr("WEAPON_NOTE_BLEED")]
		"musket": return "[b][color=#c8a050]%s[/color][/b]\n%s [color=#e8c870]50-70[/color]\n%s [color=#6cb4ee]20%%[/color]\n[color=gray][i]%s[/i][/color]" % [tr("Яничарка"), dmg, pen, tr("WEAPON_NOTE_RELOAD_NEEDED")]
		"spear": return "[b][color=#c8a050]%s[/color][/b]\n%s [color=#e8c870]40-55[/color]\n%s [color=#6cb4ee]40%%[/color]\n[color=gray][i]%s[/i][/color]" % [tr("Піка (2H)"), dmg, pen, tr("WEAPON_NOTE_RANGE2")]
		"heavy": return "[b][color=#c8a050]%s[/color][/b]\n%s [color=#e8c870]60-90[/color]\n%s [color=#6cb4ee]40%%[/color]\n[color=gray][i]%s[/i][/color]" % [tr("Бердиш (2H)"), dmg, pen, tr("WEAPON_NOTE_ARC")]
	return "[color=gray]" + tr("WEAPON_GENERIC_DESC") + "[/color]"


func _equipment_slot(icon: String, label_text: String, filled: bool, p_size: Vector2, tooltip: String = "", item_id: String = "") -> PanelContainer:
	var p = PanelContainer.new()
	p.custom_minimum_size = p_size
	if tooltip != "":
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_entered.connect(func(): FloatingLabel.show_label(tooltip))
		p.mouse_exited.connect(func(): FloatingLabel.hide_label())
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.11, 0.07) if filled else Color(0.055, 0.055, 0.065)
	st.border_color = Color(0.48, 0.38, 0.13) if filled else Color(0.18, 0.18, 0.2)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", st)
	
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	
	var icon_tex: Texture2D = InventoryManager.get_item_icon(item_id) if filled and item_id != "" else null
	if icon_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_size: float = minf(p_size.x - 10, p_size.y - 50)
		tex_rect.custom_minimum_size = Vector2(p_size.x - 10, icon_size)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tex_rect)
	else:
		var il = Label.new(); il.text = icon
		il.add_theme_font_size_override("font_size", 32 if p_size.y > 120 else 24)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.add_theme_color_override("font_color", Color.WHITE if filled else Color(0.2, 0.2, 0.22))
		vb.add_child(il)

	var text_margin := MarginContainer.new()
	text_margin.add_theme_constant_override("margin_left", 5)
	text_margin.add_theme_constant_override("margin_right", 5)
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(text_margin)

	var tl = Label.new(); tl.text = label_text
	tl.add_theme_font_size_override("font_size", 12)
	tl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.38) if filled else Color(0.3, 0.3, 0.32))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_theme_constant_override("line_spacing", -2)
	text_margin.add_child(tl)
	
	return p

func _build_attacks() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	var skills = _unit.available_skills if "available_skills" in _unit else []
	for skill in skills:
		if skill.id in ["rally", "wait", "rest", "recover"]: continue # Це не атаки
		row.add_child(_skill_card(skill))

func _skill_card(skill: Dictionary) -> PanelContainer:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(110, 64)
	var skill_desc = skill.get("desc", "")
	if skill_desc != "":
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_entered.connect(func(): FloatingLabel.show_label(skill_desc))
		p.mouse_exited.connect(func(): FloatingLabel.hide_label())
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.11, 0.13)
	st.border_color = Color(0.28, 0.26, 0.16)
	st.set_border_width_all(1); st.set_corner_radius_all(3)
	st.content_margin_left = 8; st.content_margin_right = 8
	st.content_margin_top = 6; st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	var nl = Label.new(); nl.text = skill.name
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.6))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	var hb_cost = HBoxContainer.new()
	hb_cost.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_cost.add_theme_constant_override("separation", 6)
	hb_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb_cost)
	
	var ap_lbl = Label.new()
	ap_lbl.text = "⚡ %d" % skill.ap
	ap_lbl.add_theme_font_size_override("font_size", 12)
	ap_lbl.add_theme_color_override("font_color", Color(0.1, 0.6, 0.2))
	hb_cost.add_child(ap_lbl)
	
	var sep = Label.new(); sep.text = "|"; sep.add_theme_font_size_override("font_size", 12)
	hb_cost.add_child(sep)
	
	var stam_lbl = Label.new()
	stam_lbl.text = "💧 %d" % skill.stamina
	stam_lbl.add_theme_font_size_override("font_size", 12)
	stam_lbl.add_theme_color_override("font_color", Color(0.1, 0.3, 0.8))
	hb_cost.add_child(stam_lbl)
	return p

func _build_origin() -> void:
	var origin_name = ""
	var origin_bonus = ""
	if "data" in _unit and _unit.data:
		if "origin_name" in _unit.data: origin_name = _unit.data.origin_name
		if "origin_bonus" in _unit.data: origin_bonus = _unit.data.origin_bonus

	var trait_panel = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.075, 0.04)
	st.border_color = Color(0.38, 0.28, 0.08)
	st.set_border_width_all(1); st.set_corner_radius_all(3)
	st.content_margin_left = 12; st.content_margin_right = 12
	st.content_margin_top = 8; st.content_margin_bottom = 8
	trait_panel.add_theme_stylebox_override("panel", st)
	_content.add_child(trait_panel)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 4)
	trait_panel.add_child(vb)

	if origin_name != "":
		var nl = Label.new(); nl.text = "🏷️  " + tr(origin_name)
		nl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.22))
		vb.add_child(nl)
	if origin_bonus != "":
		var bl = Label.new(); bl.text = tr(origin_bonus)
		bl.add_theme_font_size_override("font_size", 14)
		bl.add_theme_color_override("font_color", Color(0.68, 0.9, 0.68))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(bl)
	if origin_name == "" and origin_bonus == "":
		var el = Label.new(); el.text = tr("ORIGIN_UNKNOWN")
		el.add_theme_font_size_override("font_size", 14)
		el.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		vb.add_child(el)

func _build_stats() -> void:
	var ap = _unit.get("ap") if "ap" in _unit else 0
	var hp = _unit.get("hp") if "hp" in _unit else 0
	var max_hp = _unit.get("max_hp") if "max_hp" in _unit else 0
	var head_a = _unit.get("head_armor") if "head_armor" in _unit else 0
	var max_head_a = _unit.get("max_head_armor") if "max_head_armor" in _unit else 0
	var body_a = _unit.get("body_armor") if "body_armor" in _unit else 0
	var max_body_a = _unit.get("max_body_armor") if "max_body_armor" in _unit else 0
	var stam = _unit.get("stamina") if "stamina" in _unit else 0
	var max_stam = _unit.get("max_stamina") if "max_stamina" in _unit else 0

	var d = _unit.data if "data" in _unit and _unit.data else null
	var melee_sk = d.base_melee_skill if d and "base_melee_skill" in d else 50
	var ranged_sk = d.base_ranged_skill if d and "base_ranged_skill" in d else 35
	var melee_def = d.base_melee_defense if d and "base_melee_defense" in d else 5
	var ranged_def = d.base_ranged_defense if d and "base_ranged_defense" in d else 5
	var initiative = d.base_initiative if d and "base_initiative" in d else 60
	var resolve = d.base_resolve if d and "base_resolve" in d else 40

	# Створюємо головну сітку 2x6
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)

	# Підготовка даних для правої колонки
	var combat_rows = [
		["⚔️ " + tr("STAT_MELEE"), "%d%%" % melee_sk],
		["🏹 " + tr("STAT_RANGED"), "%d%%" % ranged_sk],
		["🛡 " + tr("STAT_DEFENSE_MELEE"), "%d%%" % melee_def],
		["🏹 " + tr("STAT_DEFENSE_RANGED"), "%d%%" % ranged_def],
		["🎯 " + tr("STAT_INITIATIVE"), str(initiative)],
		["💪 " + tr("STAT_RESOLVE"), str(resolve)],
	]

	# Мораль (підготовка)
	var morale_val = 100
	var morale_color = Color.GREEN
	match _unit.get("current_morale"):
		0: morale_val = 100; morale_color = Color(0.2, 0.9, 0.2)
		1: morale_val = 75; morale_color = Color(0.1, 0.6, 0.9)
		2: morale_val = 50; morale_color = Color(0.9, 0.7, 0.1)
		3: morale_val = 25; morale_color = Color(0.9, 0.4, 0.1)
		4: morale_val = 10; morale_color = Color(0.8, 0.1, 0.1)
	
	var morale_bar = _build_stat_bar(tr("STAT_MORALE"), morale_val, 100, morale_color)
	var m_label = morale_bar.get_child(0)
	m_label.text = _unit.get_morale_string()

	# Список барів для лівої колонки
	var bars = [
		_build_stat_bar("⚡ " + tr("STAT_AP"), ap, Globals.AP_MAX, Color(0.1, 0.6, 0.2)),
		morale_bar,
		_build_stat_bar("🪖 " + tr("STAT_HELMET"), head_a, max_head_a, Color(0.5, 0.5, 0.6)),
		_build_stat_bar("🛡️ " + tr("STAT_ARMOR"), body_a, max_body_a, Color(0.6, 0.5, 0.4)),
		_build_stat_bar("❤️ " + tr("STAT_HP"), hp, max_hp, Color(0.8, 0.1, 0.1)),
		_build_stat_bar("💧 " + tr("STAT_STAMINA"), stam, max_stam, Color(0.1, 0.3, 0.8))
	]

	# Заповнюємо сітку ряд за рядом
	for i in range(6):
		# Ліва ячейка (Бар)
		var left_item = bars[i]
		left_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(left_item)
		
		# Права ячейка (Бойовий параметр)
		var right_item = _build_stat_cell(combat_rows[i][0], combat_rows[i][1])
		right_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(right_item)

# --- HELPERS ---

func _build_stat_cell(key: String, val: String) -> PanelContainer:
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.09)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.18, 0.15)
	style.content_margin_left = 12
	style.content_margin_right = 12
	pc.add_theme_stylebox_override("panel", style)
	pc.custom_minimum_size = Vector2(0, 36)
	
	var hb = HBoxContainer.new()
	pc.add_child(hb)
	
	var kl = Label.new(); kl.text = key
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hb.add_child(kl)

	var vl = Label.new(); vl.text = val
	vl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	hb.add_child(vl)
	
	return pc

# --- HELPERS ---

func _section_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.65, 0.5, 0.18))
	return l

func _build_stat_bar(label_text: String, val: float, m_val: float, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.max_value = m_val
	bar.value = val
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 36)
	
	var bg = StyleBoxFlat.new(); bg.bg_color = Color(0.1, 0.1, 0.12)
	var fg = StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_border_width_all(1)
	fg.border_color = color.lightened(0.2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	
	var l = Label.new()
	l.text = "%s: %d / %d" % [label_text, val, m_val]
	
	# ProgressBar потребує мінімум 1 для коректного відображення порожнього стану
	bar.max_value = max(1, m_val)
	bar.value = val
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	
	return bar

func _add_separator() -> void:
	var sep = HSeparator.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.28, 0.22, 0.08)
	st.content_margin_top = 1; st.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", st)
	_content.add_child(sep)
