extends HBoxContainer

# TurnQueueUI: Відображає черговість ходів, раунди та історію раунду.

@onready var battle_manager: BattleManager = get_node_or_null("../../BattleManager")
var round_plaque: PanelContainer
var round_label: Label
var location_label: Label
var prev_active: Node2D = null

# Розмір іконки (квадрат). Слот = icon_size + 2px gap + 4px hp_bar
const ICON_ACTIVE   := 80
const ICON_UPCOMING := 60
const ICON_DONE     := 52
const HP_BAR_H      := 4
const GAP           := 2

func _slot_size(icon: int) -> Vector2:
	return Vector2(icon, icon + GAP + HP_BAR_H)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 8)

	_create_round_plaque()

	var grid = get_node_or_null("../../TacticalGrid")
	if grid and location_label:
		location_label.text = grid.location_name
		location_label.add_theme_color_override("font_color", grid.location_color)

	if battle_manager:
		if not battle_manager.queue_changed.is_connected(_on_queue_changed):
			battle_manager.queue_changed.connect(_on_queue_changed)
		if not battle_manager.unit_hovered.is_connected(_on_unit_hovered_on_map):
			battle_manager.unit_hovered.connect(_on_unit_hovered_on_map)
		if not battle_manager.unit_unhovered.is_connected(_on_unit_unhovered_on_map):
			battle_manager.unit_unhovered.connect(_on_unit_unhovered_on_map)
		_on_queue_changed(battle_manager.current_round, battle_manager.active_unit, battle_manager.turn_queue, battle_manager.completed_units)

func _process(_delta: float) -> void:
	for slot in get_children():
		if not slot.has_meta("unit"): continue
		var unit = slot.get_meta("unit")
		if not is_instance_valid(unit): continue
		var hp_bar = slot.get_node_or_null("HPBar")
		if hp_bar and "hp" in unit and "max_hp" in unit and unit.max_hp > 0:
			hp_bar.value = float(unit.hp) / float(unit.max_hp)

func _on_unit_hovered_on_map(unit: Node2D) -> void:
	_set_slot_highlight(unit, true)

func _on_unit_unhovered_on_map(unit: Node2D) -> void:
	_set_slot_highlight(unit, false)

func _set_slot_highlight(unit: Node2D, active: bool) -> void:
	for slot in get_children():
		if not (slot.has_meta("unit") and slot.get_meta("unit") == unit): continue

		if slot.has_meta("hover_tween"):
			var old = slot.get_meta("hover_tween")
			if old and old.is_valid(): old.kill()

		var tween = create_tween()
		slot.set_meta("hover_tween", tween)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		slot.pivot_offset = Vector2(slot.custom_minimum_size.x / 2.0, 0)
		var target_scale = Vector2(1.12, 1.12) if active else Vector2(1.0, 1.0)
		tween.tween_property(slot, "scale", target_scale, 0.25)

		if active:
			slot.z_index = max(slot.z_index, 10)
		else:
			if slot.z_index == 10:
				tween.finished.connect(func(): if is_instance_valid(slot): slot.z_index = 0)

func _create_round_plaque() -> void:
	round_plaque = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.85)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.set_corner_radius_all(2)
	round_plaque.add_theme_stylebox_override("panel", style)
	round_plaque.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)

	round_label = Label.new()
	round_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(round_label)

	location_label = Label.new()
	location_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.55))
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(location_label)

	round_plaque.add_child(vbox)
	add_child(round_plaque)

func _on_queue_changed(round_num: int, active: Node2D, upcoming: Array, completed: Array) -> void:
	if round_label:
		round_label.text = tr("BATTLE_ROUND") % round_num

	var target_units = []
	var unit_to_state = {}
	for unit in completed:
		if is_instance_valid(unit):
			target_units.append(unit)
			unit_to_state[unit] = "completed"
	if is_instance_valid(active):
		target_units.append(active)
		unit_to_state[active] = "active"
	for unit in upcoming:
		if is_instance_valid(unit) and unit != active:
			target_units.append(unit)
			unit_to_state[unit] = "upcoming"

	var existing_slots = {}
	for child in get_children():
		if child.has_meta("unit"):
			existing_slots[child.get_meta("unit")] = child

	for unit in existing_slots.keys():
		if not unit_to_state.has(unit):
			existing_slots[unit].queue_free()
			existing_slots.erase(unit)

	var current_pos = 1
	for unit in target_units:
		var slot
		var is_new = false
		if existing_slots.has(unit):
			slot = existing_slots[unit]
		else:
			slot = _create_unit_slot(unit)
			add_child(slot)
			is_new = true
		move_child(slot, current_pos)
		_update_slot_visuals(slot, unit_to_state[unit], is_new)
		current_pos += 1

	prev_active = active

func _update_slot_visuals(slot: Control, state: String, is_new: bool) -> void:
	var icon_rect = slot.get_node_or_null("IconRect")
	var hp_bar    = slot.get_node_or_null("HPBar")
	if not icon_rect: return

	var unit    = slot.get_meta("unit")
	var is_dead = unit.is_dead if is_instance_valid(unit) and "is_dead" in unit else false
	var border_visible := false
	var icon_size: int

	match state:
		"active":
			icon_size     = ICON_ACTIVE
			border_visible = not is_dead
			slot.z_index  = 20
		"upcoming":
			icon_size    = ICON_UPCOMING
			slot.z_index = 0
		_:
			icon_size    = ICON_DONE
			slot.z_index = 0

	var target_slot := _slot_size(icon_size)
	var tween := create_tween().set_parallel(true)

	# Слот
	tween.tween_property(slot, "custom_minimum_size", target_slot, 0.2)

	# Іконка (явний розмір — без анкерів)
	tween.tween_property(icon_rect, "custom_minimum_size", Vector2(icon_size, icon_size), 0.2)
	tween.tween_property(icon_rect, "size",                Vector2(icon_size, icon_size), 0.2)

	# HP бар (позиція під іконкою)
	if hp_bar:
		tween.tween_property(hp_bar, "position",           Vector2(0, icon_size + GAP), 0.2)
		tween.tween_property(hp_bar, "size",               Vector2(icon_size, HP_BAR_H), 0.2)
		tween.tween_property(hp_bar, "custom_minimum_size",Vector2(icon_size, HP_BAR_H), 0.2)

	# Затемнення
	var overlay = icon_rect.get_node_or_null("InactiveOverlay")
	if overlay:
		var oa = 0.85 if is_dead else (0.55 if state == "completed" else 0.0)
		tween.tween_property(overlay, "modulate:a", oa, 0.2)

	# Тінт
	var target_mod: Color
	if is_dead:
		target_mod = Color(0.3, 0.3, 0.3, 0.4)
	elif state == "completed":
		target_mod = Color(0.9, 0.9, 0.9, 0.6)
	else:
		target_mod = Color(1.0, 1.0, 1.0, 1.0)
	tween.tween_property(icon_rect, "modulate", target_mod, 0.2)

	# Рамка
	var border = icon_rect.get_node_or_null("ActiveBorder")
	if border:
		border.visible = border_visible

	# Фейд для нових
	if is_new:
		slot.modulate.a = 0.0
		tween.tween_property(slot, "modulate:a", 1.0, 0.3)

func _create_unit_slot(unit: Node2D) -> Control:
	var icon_size := ICON_UPCOMING

	var slot_container = Control.new()
	slot_container.custom_minimum_size = _slot_size(icon_size)
	slot_container.set_meta("unit", unit)
	slot_container.pivot_offset = Vector2(icon_size / 2.0, 0)

	# Іконка — явний розмір і позиція (без анкерів, щоб hp_bar не перекривав)
	var icon_rect = TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.position = Vector2(0, 0)
	icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_rect.size = Vector2(icon_size, icon_size)

	if unit.has_method("get_portrait"):
		icon_rect.texture = unit.get_portrait()

	# Фон (дитина icon_rect → FULL_RECT відносно icon_rect)
	var bg = Panel.new()
	bg.name = "Background"
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.14, 0.8)
	bg_style.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.add_child(bg)

	# Затемнення
	var overlay = ColorRect.new()
	overlay.name = "InactiveOverlay"
	overlay.color = Color(0.25, 0.25, 0.25, 1.0)
	overlay.modulate.a = 0.0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.add_child(overlay)

	# Кольорова рамка + фон (лише для активного, команда визначає колір)
	var team = unit.get("team") if "team" in unit else 0
	var team_color = Color(0.3, 0.7, 1.0) if team == 0 else Color(1.0, 0.35, 0.35)
	var border = Panel.new()
	border.name = "ActiveBorder"
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(team_color.r, team_color.g, team_color.b, 0.12)
	border_style.set_border_width_all(3)
	border_style.border_color = team_color
	border.add_theme_stylebox_override("panel", border_style)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.visible = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.add_child(border)

	slot_container.add_child(icon_rect)

	# HP бар — явна позиція під іконкою
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.max_value = 1.0
	hp_bar.value = 1.0
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.position = Vector2(0, icon_size + GAP)
	hp_bar.size = Vector2(icon_size, HP_BAR_H)
	hp_bar.custom_minimum_size = Vector2(0, HP_BAR_H)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.75, 0.1, 0.1)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	var hp_bg_style = StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0.1, 0.08, 0.08, 0.9)
	hp_bar.add_theme_stylebox_override("background", hp_bg_style)

	if "hp" in unit and "max_hp" in unit and unit.max_hp > 0:
		hp_bar.value = float(unit.hp) / float(unit.max_hp)

	slot_container.add_child(hp_bar)

	slot_container.mouse_entered.connect(func(): _on_slot_hovered(unit, true))
	slot_container.mouse_exited.connect(func(): _on_slot_hovered(unit, false))

	return slot_container

func _on_slot_hovered(unit: Node2D, is_hover: bool) -> void:
	if not battle_manager: return
	battle_manager.update_hover_info(unit if is_hover else null)
	_set_slot_highlight(unit, is_hover)
