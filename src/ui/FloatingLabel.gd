## FloatingLabel.gd
## Глобальний тултіп, слідує за курсором.
## Виклик: FloatingLabel.show_label("Текст")  або  show_label("Текст", Color.GOLD)
## Скрити:  FloatingLabel.hide_label()
extends CanvasLayer

@onready var _label: RichTextLabel = $RichLabel
var _source: String = ""
var _target_pos: Vector2 = Vector2.ZERO
var _fade_tween: Tween

func show_label(text: String, color: Color = Color.WHITE, source: String = "") -> void:
	_source = source
	# Обгортаємо текст у колір, якщо він не білий і не містить власних тегів [color]
	var bbcode = text
	if color != Color.WHITE and not "[color" in text:
		bbcode = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	_label.text = bbcode
	_label.reset_size()

	if not _label.visible:
		# Перша поява — ставимо позицію одразу (без ковзання з кута екрану)
		var mouse = _label.get_global_mouse_position()
		_target_pos = _calc_clamped_pos(mouse)
		_label.global_position = _target_pos
		_label.visible = true
		# Fade-in анімація
		_label.modulate.a = 0.0
		if _fade_tween: _fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_label, "modulate:a", 1.0, 0.1)
	else:
		_reposition()

func hide_label(source: String = "") -> void:
	if source != "" and source != _source:
		return
	if _label:
		_label.visible = false
		_label.modulate.a = 1.0
	_source = ""

func _process(_delta: float) -> void:
	if _label and _label.visible:
		_reposition()

func _reposition() -> void:
	var mouse = _label.get_global_mouse_position()
	_target_pos = _calc_clamped_pos(mouse)
	# Плавне ковзання за курсором (lerp)
	_label.global_position = _label.global_position.lerp(_target_pos, 0.35)

func _calc_clamped_pos(mouse: Vector2) -> Vector2:
	var pos = mouse + Vector2(20, 16)

	var label_size = _label.get_combined_minimum_size()
	var viewport_size = get_viewport().get_visible_rect().size

	if pos.x + label_size.x > viewport_size.x:
		pos.x = mouse.x - label_size.x - 8
	if pos.y + label_size.y > viewport_size.y:
		pos.y = mouse.y - label_size.y - 8

	pos.x = max(4, pos.x)
	pos.y = max(4, pos.y)

	return pos
