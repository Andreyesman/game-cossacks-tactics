class_name EncounterDialog
extends Control

signal attack_pressed
signal avoid_pressed
signal talk_pressed

@onready var _title_lbl: Label    = $CenterContainer/PanelContainer/VBox/TitleLabel
@onready var _reward_lbl: Label   = $CenterContainer/PanelContainer/VBox/RewardLabel
@onready var _attack_btn: Button  = $CenterContainer/PanelContainer/VBox/ButtonBox/AttackBtn
@onready var _avoid_btn: Button   = $CenterContainer/PanelContainer/VBox/ButtonBox/AvoidBtn
@onready var _talk_btn: Button    = $CenterContainer/PanelContainer/VBox/ButtonBox/TalkBtn

func _ready() -> void:
	_attack_btn.pressed.connect(func(): attack_pressed.emit())
	_avoid_btn.pressed.connect(func(): avoid_pressed.emit())
	_talk_btn.pressed.connect(func(): talk_pressed.emit())

	# Дерев'яні кнопки з семантичними відтінками; стилі з .tscn — фолбек
	UIStyle.apply_button(_attack_btn, UIStyle.tint_from(Color(0.45, 0.10, 0.10)), Vector4(14, 6, 14, 6))
	UIStyle.apply_button(_avoid_btn, Color.WHITE, Vector4(14, 6, 14, 6))
	UIStyle.apply_button(_talk_btn, UIStyle.tint_from(Color(0.15, 0.40, 0.15)), Vector4(14, 6, 14, 6))
	var dlg_panel := get_node_or_null("CenterContainer/PanelContainer")
	if dlg_panel is PanelContainer:
		UIStyle.apply_panel(dlg_panel)

func show_for(title: String, reward: int, options: Array) -> void:
	_title_lbl.text = title
	_reward_lbl.text = tr("ENCOUNTER_REWARD") % reward
	_reward_lbl.visible = reward > 0
	_attack_btn.visible = "attack" in options
	_avoid_btn.visible  = "avoid"  in options
	_talk_btn.visible   = "talk"   in options
	visible = true

func hide_dialog() -> void:
	visible = false
