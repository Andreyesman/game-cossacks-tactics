extends Control
class_name LoadingScreen

const C_DARK_BG := Color(0.04, 0.03, 0.025)
const C_GOLD    := Color(0.894, 0.804, 0.42)
const TARGET := "res://src/scenes/Battle.tscn"

var _label: Label

func _ready() -> void:
	print("LoadingScreen: _ready() — починаємо перехід до Battle...")
	_build_ui()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.1)
	tw.finished.connect(_on_fade_in_finished)

func _on_fade_in_finished() -> void:
	print("LoadingScreen: fade завершено — завантажуємо Battle...")
	_change_scene_staged.call_deferred()

# Діагностична версія переходу: розбито на етапи, щоб бачити, де саме висне
func _change_scene_staged() -> void:
	print("LoadingScreen: [1/3] load(Battle.tscn) почався...")
	var packed: PackedScene = load(TARGET)
	print("LoadingScreen: [2/3] load() завершено, packed valid=", is_instance_valid(packed) if packed else false)
	var err := get_tree().change_scene_to_packed(packed)
	print("LoadingScreen: [3/3] change_scene_to_packed -> ", error_string(err))

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = C_DARK_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_label = Label.new()
	_label.text = tr("LOADING_BATTLE")
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", C_GOLD)
	_label.anchor_left   = 0.5
	_label.anchor_top    = 0.5
	_label.anchor_right  = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left   = -220.0
	_label.offset_right  =  220.0
	_label.offset_top    =  -18.0
	_label.offset_bottom =   18.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

