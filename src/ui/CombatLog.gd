extends PanelContainer

@onready var message_list = $MarginContainer/ScrollContainer/VBoxContainer
@onready var scroll = $MarginContainer/ScrollContainer
@onready var resize_handle = $ResizeHandle

var is_resizing = false

func _ready() -> void:
	if resize_handle:
		resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	
	# Налаштовуємо стилі (прозорий темний фон)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	add_theme_stylebox_override("panel", style)

const MAX_MESSAGES = 50

func add_log_message(text: String, color: Color = Color.WHITE) -> void:
	if message_list == null:
		message_list = $MarginContainer/ScrollContainer/VBoxContainer
	if scroll == null:
		scroll = $MarginContainer/ScrollContainer

	# Оптимізація: Видаляємо старі повідомлення, якщо ліміт перевищено
	if message_list.get_child_count() >= MAX_MESSAGES:
		var oldest = message_list.get_child(0)
		message_list.remove_child(oldest)
		oldest.queue_free()

	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	
	# Форматування тексту без часу, з використанням BBCode
	label.text = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	
	message_list.add_child(label)
	
	# Автоматична прокрутка до низу
	await get_tree().process_frame
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_resizing = event.pressed
			get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion and is_resizing:
		var new_height = clamp(custom_minimum_size.y + event.relative.y, 100, 600)
		custom_minimum_size.y = new_height
		get_viewport().set_input_as_handled()
