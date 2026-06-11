extends Camera2D

@export var move_speed: float = 600.0
@export var drag_speed: float = 1.0

# Межі камери, щоб гравець не загубився у порожнечі
@export var limit_left_bound: float = -500.0
@export var limit_right_bound: float = 500.0
@export var limit_top_bound: float = 200.0
@export var limit_bottom_bound: float = 1000.0

# Налаштування зуму
const ZOOM_LEVELS: Array[float] = [0.5, 0.75, 1.0, 1.25]

var is_dragging: bool = false
var target_zoom: float = 1.0

var zoom_label: Label
var zoom_timer: Timer

func _ready() -> void:
	target_zoom = zoom.x
	
	# Створення UI для зуму
	var ui_layer = get_node_or_null("../UI")
	if ui_layer:
		zoom_label = Label.new()
		zoom_label.name = "ZoomLabel"
		zoom_label.add_theme_font_size_override("font_size", 20)
		zoom_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
		zoom_label.anchor_left = 1.0
		zoom_label.anchor_right = 1.0
		zoom_label.offset_left = -200
		zoom_label.offset_right = -20
		zoom_label.offset_top = 110
		zoom_label.offset_bottom = 150
		zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		zoom_label.text = "Зум: x%s" % str(target_zoom)
		zoom_label.modulate.a = 0.0 # Приховано за замовчуванням
		ui_layer.add_child(zoom_label)
		
		zoom_timer = Timer.new()
		zoom_timer.one_shot = true
		zoom_timer.wait_time = 1.5
		zoom_timer.timeout.connect(_on_zoom_timer_timeout)
		add_child(zoom_timer)

func _on_zoom_timer_timeout() -> void:
	if zoom_label and is_instance_valid(zoom_label):
		var fade_out = create_tween()
		fade_out.tween_property(zoom_label, "modulate:a", 0.0, 0.3)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-1)
			
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			_zoom_camera(1)
		elif event.keycode == KEY_MINUS:
			_zoom_camera(-1)
	
	if event is InputEventMouseMotion and is_dragging:
		# Зміщуємо камеру з урахуванням зуму (чим ближче, тим повільніше треба тягнути)
		position -= event.relative * drag_speed / zoom.x
		_clamp_position()

func _zoom_camera(direction: int) -> void:
	var closest_idx = 0
	var min_diff = 999.0
	for i in range(ZOOM_LEVELS.size()):
		var diff = abs(ZOOM_LEVELS[i] - target_zoom)
		if diff < min_diff:
			min_diff = diff
			closest_idx = i
			
	var new_idx = clamp(closest_idx + direction, 0, ZOOM_LEVELS.size() - 1)
	target_zoom = ZOOM_LEVELS[new_idx]
	
	var tween = create_tween()
	tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.15).set_trans(Tween.TRANS_SINE)
	
	if zoom_label and is_instance_valid(zoom_label):
		var display_text = str(target_zoom)
		if not "." in display_text:
			display_text += ".0"
		zoom_label.text = tr("UI_ZOOM_FORMAT") % display_text
		zoom_label.modulate.a = 1.0 # Миттєво показуємо
		if zoom_timer:
			zoom_timer.start()

func _process(delta: float) -> void:
	var dir = Vector2.ZERO
	
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
		
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		position += dir * move_speed * delta * zoom.x
		_clamp_position()

func play_crit_effect() -> void:
	var shake = create_tween()
	for i in range(4):
		shake.tween_property(self, "offset", Vector2(randf_range(-8, 8), randf_range(-3, 3)), 0.04)
	shake.tween_property(self, "offset", Vector2.ZERO, 0.04)

	if target_zoom < 1.25:
		var zoom_tween = create_tween()
		zoom_tween.tween_property(self, "zoom", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_SINE)
		zoom_tween.tween_interval(0.25)
		zoom_tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.2).set_trans(Tween.TRANS_SINE)

func _clamp_position() -> void:
	position.x = clamp(position.x, limit_left_bound, limit_right_bound)
	position.y = clamp(position.y, limit_top_bound, limit_bottom_bound)
