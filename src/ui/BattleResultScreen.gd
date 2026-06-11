extends Control
class_name BattleResultScreen

var _panel: PanelContainer
var _loot_pool: Array = []

func init(is_victory: bool, player_units: Array, loot_pool: Array = []) -> void:
	_loot_pool = loot_pool
	_build_ui(is_victory, player_units)
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

func _build_ui(is_victory: bool, player_units: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var overlay_bg = ColorRect.new()
	overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_bg.color = Color(0, 0, 0, 0.85)
	add_child(overlay_bg)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.065, 0.055)
	panel_style.border_color = Color(0.65, 0.5, 0.18) if is_victory else Color(0.6, 0.15, 0.15)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var outer_mc = MarginContainer.new()
	outer_mc.add_theme_constant_override("margin_left", 20)
	outer_mc.add_theme_constant_override("margin_right", 20)
	outer_mc.add_theme_constant_override("margin_top", 16)
	outer_mc.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(outer_mc)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	outer_mc.add_child(main_vbox)

	# Заголовок
	var title = Label.new()
	title.text = tr("RESULT_VICTORY") if is_victory else tr("RESULT_DEFEAT")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.SKY_BLUE if is_victory else Color.CRIMSON)
	main_vbox.add_child(title)

	main_vbox.add_child(_make_hseparator())

	# Два стовпці: юніти зліва, лут справа
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content_hbox)

	# ── ЛІВИЙ стовпець: список козаків ──
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(left_vbox)

	for unit in player_units:
		left_vbox.add_child(_build_unit_row(unit))

	# Вертикальний роздільник
	var vdiv = VSeparator.new()
	var vdiv_st = StyleBoxFlat.new()
	vdiv_st.bg_color = Color(0.28, 0.22, 0.08)
	vdiv_st.content_margin_left = 1
	vdiv_st.content_margin_right = 1
	vdiv.add_theme_stylebox_override("separator", vdiv_st)
	content_hbox.add_child(vdiv)

	# ── ПРАВИЙ стовпець: лут ──
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(210, 0)
	right_vbox.add_theme_constant_override("separation", 10)
	content_hbox.add_child(right_vbox)

	_build_loot_column(right_vbox, is_victory, _loot_pool)

	main_vbox.add_child(_make_hseparator())
	main_vbox.add_child(_build_buttons(is_victory, player_units))

# ── Рядок юніта ──────────────────────────────────────────────────────────────

func _build_unit_row(unit: Node2D) -> PanelContainer:
	var is_dead: bool = unit.get("is_dead")

	# Кольори з Figma: темно-коричневий фон, відповідна рамка
	var C_BG_NORMAL   := Color(0.098, 0.086, 0.075)
	var C_BG_DEAD     := Color(0.15,  0.05,  0.05)
	var C_BORDER      := Color(0.196, 0.176, 0.145)
	var C_BORDER_DEAD := Color(0.3,   0.1,   0.1)
	var C_GOLD        := Color(0.894, 0.804, 0.502)
	var C_RED         := Color(0.902, 0.349, 0.349)
	var C_CYAN        := Color(0.396, 0.855, 1.0)

	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = C_BG_DEAD if is_dead else C_BG_NORMAL
	st.border_color = C_BORDER_DEAD if is_dead else C_BORDER
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 12; st.content_margin_right = 12
	st.content_margin_top = 12;  st.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", st)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	p.add_child(hbox)

	# Портрет 104×104 (Figma)
	var portrait_bg = PanelContainer.new()
	portrait_bg.custom_minimum_size = Vector2(104, 104)
	portrait_bg.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pst = StyleBoxFlat.new()
	pst.bg_color = Color(0.06, 0.06, 0.06)
	pst.set_border_width_all(0)
	pst.set_corner_radius_all(3)
	portrait_bg.add_theme_stylebox_override("panel", pst)
	hbox.add_child(portrait_bg)

	if unit.has_method("get_portrait"):
		var tex = TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.texture = unit.get_portrait()
		if is_dead:
			tex.modulate = Color(0.35, 0.35, 0.35)
		portrait_bg.add_child(tex)

	# Права частина: ім'я + стати (gap=12 як у Figma)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	info_vbox.add_theme_constant_override("separation", 12)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = unit.name + (" (" + tr("RESULT_KILLED") + ")" if is_dead else "")
	name_lbl.add_theme_color_override("font_color",
		C_RED if is_dead else C_GOLD)
	info_vbox.add_child(name_lbl)

	var dmg_dealt: int = unit.get("damage_dealt_in_battle") if "damage_dealt_in_battle" in unit else 0
	var dmg_taken: int = unit.get("damage_taken_in_battle") if "damage_taken_in_battle" in unit else 0
	var xp_earned: int = unit.get("xp_earned_in_battle")   if "xp_earned_in_battle" in unit   else 0
	var lvls: int      = unit.get("levels_gained_in_battle") if "levels_gained_in_battle" in unit else 0

	info_vbox.add_child(_stat_line("⚔️", tr("RESULT_DMG_DEALT"), str(dmg_dealt), C_GOLD))
	if dmg_taken > 0:
		info_vbox.add_child(_stat_line("🩸", tr("RESULT_DMG_TAKEN"), "-%d HP" % [dmg_taken], C_RED))

	var unit_injuries = unit.get("injuries") if "injuries" in unit else []
	if unit_injuries.size() > 0:
		info_vbox.add_child(_build_injury_chips(unit_injuries))

	if not is_dead:
		var xp_text: String = "+%d XP" % [xp_earned] + ("  " + tr("RESULT_LEVEL_UP") if lvls > 0 else "")
		info_vbox.add_child(_stat_line("⭐", "", xp_text, C_CYAN))

	return p

func _build_injury_chips(unit_injuries: Array) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	for injury: Dictionary in unit_injuries:
		var chip = PanelContainer.new()
		var chip_st = StyleBoxFlat.new()
		chip_st.bg_color = Color(0.18, 0.05, 0.05)
		chip_st.border_color = Color(0.45, 0.15, 0.15)
		chip_st.set_border_width_all(1)
		chip_st.set_corner_radius_all(3)
		chip_st.content_margin_left = 4; chip_st.content_margin_right = 4
		chip_st.content_margin_top = 1;  chip_st.content_margin_bottom = 1
		chip.add_theme_stylebox_override("panel", chip_st)

		var lbl = Label.new()
		lbl.text = str(injury.get("icon", "🤕")) + " " + tr(str(injury.get("name", "")))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		chip.add_child(lbl)

		var is_permanent: bool = injury.get("permanent", false)
		var status_line: String = "[color=red]" + tr("RESULT_INJURY_PERMANENT") + "[/color]" if is_permanent else "[color=orange]" + tr("RESULT_INJURY_TEMPORARY") % [int(injury.get("days", 0))] + "[/color]"
		var custom_tooltip: String = "[b]" + tr(str(injury.get("name", ""))) + "[/b]\n" + status_line
		var hover_func = func(text: String):
			var fl = get_node_or_null("/root/FloatingLabel")
			if fl: fl.show_label(text)
		chip.mouse_entered.connect(hover_func.bind(custom_tooltip))
		chip.mouse_exited.connect(func():
			var fl = get_node_or_null("/root/FloatingLabel")
			if fl: fl.hide_label()
		)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP

		row.add_child(chip)

	return row

func _stat_line(icon: String, label: String, value: String, value_color: Color) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var icon_lbl = Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(icon_lbl)

	if label != "":
		var key_lbl = Label.new()
		key_lbl.text = label
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hbox.add_child(key_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", value_color)
	hbox.add_child(val_lbl)

	return hbox

# ── Правий стовпець: лут ─────────────────────────────────────────────────────

func _build_loot_column(parent: VBoxContainer, is_victory: bool, loot_pool: Array) -> void:
	var title = Label.new()
	title.text = tr("RESULT_LOOT") if is_victory else tr("RESULT_NOTHING")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)

	parent.add_child(_make_hseparator())

	if not is_victory:
		var none_lbl = Label.new()
		none_lbl.text = tr("RESULT_DEFEAT_NO_LOOT")
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(none_lbl)
		return

	var reward_thalers := 50
	var cm := get_node_or_null("/root/CampaignManager")
	if cm and not cm.active_battle_config.is_empty():
		reward_thalers = cm.active_battle_config.get("reward_thalers", 50)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	grid.add_child(_loot_slot("💰", tr("UI_THALERS_FORMAT") % reward_thalers, Color(0.95, 0.82, 0.25)))

	for item in loot_pool:
		var item_name: String = tr(item.get("name", "Предмет"))
		var loot_icon_tex: Texture2D = InventoryManager.get_item_icon(item.get("id", ""))
		grid.add_child(_loot_slot("⚔️", item_name, Color(0.8, 0.75, 0.55), loot_icon_tex))

	if loot_pool.is_empty():
		var none_lbl = Label.new()
		none_lbl.text = tr("RESULT_NO_TROPHIES")
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(none_lbl)

func _loot_slot(icon: String, text: String, color: Color, icon_tex: Texture2D = null) -> PanelContainer:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(90, 90)
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.11, 0.07)
	st.border_color = Color(0.48, 0.38, 0.13)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", st)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)

	if icon_tex:
		var tex_rect = TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(56, 56)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tex_rect)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_entered.connect(func(): FloatingLabel.show_label(text))
		p.mouse_exited.connect(func(): FloatingLabel.hide_label())
	else:
		var icon_lbl = Label.new()
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", 32)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(icon_lbl)

		var text_lbl = Label.new()
		text_lbl.text = text
		text_lbl.add_theme_font_size_override("font_size", 12)
		text_lbl.add_theme_color_override("font_color", color)
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(text_lbl)

	return p

# ── Кнопки ───────────────────────────────────────────────────────────────────

func _build_buttons(is_victory: bool, player_units: Array) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)

	var btn_restart = _create_button(tr("RESULT_BTN_MAIN_MENU"), Color(0.35, 0.18, 0.08))
	btn_restart.pressed.connect(func():
		get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")
	)
	hbox.add_child(btn_restart)

	var btn_retry = _create_button(tr("RESULT_BTN_RETRY"), Color(0.28, 0.28, 0.28))
	btn_retry.pressed.connect(func(): get_tree().reload_current_scene())
	hbox.add_child(btn_retry)

	if is_victory:
		var btn_finish = _create_button(tr("RESULT_BTN_CONTINUE"), Color(0.18, 0.48, 0.18))
		btn_finish.pressed.connect(func():
			var cm = get_node_or_null("/root/CampaignManager")
			if cm:
				cm.finish_battle(true, player_units, _loot_pool)
			else:
				get_tree().change_scene_to_file("res://src/scenes/WorldMap.tscn")
		)
		hbox.add_child(btn_finish)

	return hbox

func _create_button(text: String, base_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 45)
	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.set_corner_radius_all(4)
	var hover = normal.duplicate(); hover.bg_color = base_color.lightened(0.2)
	var press = normal.duplicate(); press.bg_color = base_color.darkened(0.2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", press)
	btn.add_theme_font_size_override("font_size", 18)
	return btn

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_hseparator() -> HSeparator:
	var sep = HSeparator.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.28, 0.22, 0.08)
	st.content_margin_top = 1; st.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", st)
	return sep
