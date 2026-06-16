extends Control
class_name MainMenu

const C_GOLD       := Color(0.965, 0.941, 0.855)
const C_GOLD_DIM   := Color(0.55,  0.48,  0.24)
const C_GOLD_LIGHT := Color(1.0,   0.94,  0.68)
const C_DARK_BG    := Color(0.04,  0.03,  0.025)

const FONT_TITLE   := "res://assets/fonts/RuslanDisplay-Regular.ttf"
const FONT_BUTTONS := "res://assets/fonts/KellySlab-Regular.ttf"

var _font_title:   FontFile
var _font_buttons: FontFile
var _anim_nodes:  Array[Control] = []
var _btn_new:      Button
var _btn_continue: Button
var _btn_settings: Button
var _btn_quit:     Button
var _title_label:  Label
var _settings_overlay: Control = null
var _settings_music_slider: HSlider = null
var _settings_sfx_slider: HSlider = null
var _settings_music_label: Label = null
var _settings_sfx_label: Label = null
var _settings_title_label: Label = null
var _settings_close_btn: Button = null
var _settings_lang_opt: OptionButton = null

func _ready() -> void:
	_load_fonts()
	_build_ui()
	_setup_focus_navigation()
	_btn_new.grab_focus()
	_start_intro_animation()
	AudioManager.play_music("map")

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_TITLE):
		_font_title = load(FONT_TITLE)
	if ResourceLoader.exists(FONT_BUTTONS):
		_font_buttons = load(FONT_BUTTONS)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_add_background()
	_add_left_content()
	_add_version_label()

# ── Фон ──────────────────────────────────────────────────────────────────────

func _add_background() -> void:
	var bg = ColorRect.new()
	bg.color = C_DARK_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var hero_path := "res://assets/ui/menu_background.png"
	if ResourceLoader.exists(hero_path):
		var hero := TextureRect.new()
		hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hero.texture = load(hero_path)
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		hero.modulate.a = 0.0
		add_child(hero)

		var tween := create_tween()
		tween.tween_property(hero, "modulate:a", 1.0, 0.7).set_ease(Tween.EASE_OUT)

	# Градієнтне затемнення зліва — читабельність заголовка і кнопок поверх ілюстрації
	_add_gradient_overlay()

func _add_gradient_overlay() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.50, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		C_DARK_BG,
		C_DARK_BG,
		Color(C_DARK_BG.r, C_DARK_BG.g, C_DARK_BG.b, 0.15),
		Color(C_DARK_BG.r, C_DARK_BG.g, C_DARK_BG.b, 0.0),
	])

	var gtex := GradientTexture2D.new()
	gtex.gradient = gradient
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.0, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 4

	var overlay := TextureRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.texture = gtex
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(overlay)

# ── Лівий блок з заголовком та кнопками ──────────────────────────────────────

func _add_left_content() -> void:
	var left := Control.new()
	left.anchor_right = 0.52
	left.anchor_bottom = 1.0
	add_child(left)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 200
	vbox.offset_right = -20
	vbox.add_theme_constant_override("separation", 0)
	left.add_child(vbox)

	# Верхній відступ (~30% висоти)
	vbox.add_child(_flex_spacer(1.0))

	# Заголовок
	var title := Label.new()
	title.text = tr("GAME_TITLE").replace(" ", "\n")
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_constant_override("line_spacing", 30)
	title.add_theme_color_override("font_color", C_GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	if _font_title:
		title.add_theme_font_override("font", _font_title)
	title.modulate.a = 0.0
	vbox.add_child(title)
	_anim_nodes.append(title)
	_title_label = title

	# Відступ між заголовком і кнопками
	vbox.add_child(_fixed_gap(100))

	# Кнопки
	var btn_new := _make_btn(tr("UI_NEW_GAME"))
	btn_new.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		var cm := get_node_or_null("/root/CampaignManager")
		if cm:
			cm.new_campaign()
		else:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.2)
			await tw.finished
			get_tree().change_scene_to_file("res://src/scenes/WorldMap.tscn")
	)
	btn_new.modulate.a = 0.0
	_btn_new = btn_new
	vbox.add_child(btn_new)
	_anim_nodes.append(btn_new)
	vbox.add_child(_fixed_gap(20))

	var btn_continue := _make_btn(tr("UI_CONTINUE"))
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	var has_save: bool = save_mgr != null and save_mgr.has_method("has_save") and save_mgr.has_save()
	if not has_save:
		btn_continue.disabled = true
		btn_continue.focus_mode = Control.FOCUS_NONE
	btn_continue.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		var cm := get_node_or_null("/root/CampaignManager")
		var sm := get_node_or_null("/root/SaveManager")
		if cm and sm:
			var saved_state: Dictionary = sm.load_campaign()
			if not saved_state.is_empty():
				cm.load_campaign(saved_state)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		await tw.finished
		get_tree().change_scene_to_file("res://src/scenes/WorldMap.tscn")
	)
	btn_continue.modulate.a = 0.0
	_btn_continue = btn_continue
	vbox.add_child(btn_continue)
	_anim_nodes.append(btn_continue)
	vbox.add_child(_fixed_gap(20))

	var btn_settings := _make_btn(tr("UI_SETTINGS"))
	btn_settings.pressed.connect(_open_settings)
	btn_settings.modulate.a = 0.0
	_btn_settings = btn_settings
	vbox.add_child(btn_settings)
	_anim_nodes.append(btn_settings)
	vbox.add_child(_fixed_gap(20))

	var btn_quit := _make_btn(tr("UI_EXIT"))
	btn_quit.pressed.connect(func(): get_tree().quit())
	btn_quit.modulate.a = 0.0
	_btn_quit = btn_quit
	vbox.add_child(btn_quit)
	_anim_nodes.append(btn_quit)

	# Нижній відступ (решта)
	vbox.add_child(_flex_spacer(1.0))

func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 60)
	if _font_buttons:
		btn.add_theme_font_override("font", _font_buttons)

	# Цільові кольори станів
	var bg_targets := {
		"normal":   Color(0, 0, 0, 0),
		"hover":    Color(0.965, 0.941, 0.855),
		"pressed":  Color(0.988, 0.800, 0.157),
		"disabled": Color(0, 0, 0, 0),
	}
	var text_targets := {
		"normal":   Color(0.965, 0.941, 0.855),
		"hover":    Color(0.031, 0.027, 0.027),
		"pressed":  Color(0.031, 0.027, 0.027),
		"disabled": Color(0.573, 0.573, 0.573, 0.4),
	}

	# Єдиний stylebox для всіх станів — анімуємо bg_color
	var tween_box := _btn_style(Color(0, 0, 0, 0))
	btn.add_theme_stylebox_override("normal",   tween_box)
	btn.add_theme_stylebox_override("hover",    tween_box)
	btn.add_theme_stylebox_override("focus",    tween_box)
	btn.add_theme_stylebox_override("pressed",  tween_box)
	btn.add_theme_stylebox_override("disabled", tween_box)
	btn.add_theme_color_override("font_color", text_targets["normal"])

	# Ініціалізація: якщо кнопка disabled — одразу правильні кольори
	btn.ready.connect(func():
		if btn.disabled:
			tween_box.bg_color = bg_targets["disabled"]
			var dc: Color = text_targets["disabled"]
			btn.add_theme_color_override("font_color",          dc)
			btn.add_theme_color_override("font_hover_color",    dc)
			btn.add_theme_color_override("font_focus_color",    dc)
			btn.add_theme_color_override("font_pressed_color",  dc)
			btn.add_theme_color_override("font_disabled_color", dc)
	)

	# Стан у Dictionary — лямбди мутують контейнер, а не перепризначають змінну
	var s := {"hovered": false, "pressed": false, "tween": null}

	var get_state := func() -> String:
		if btn.disabled:                    return "disabled"
		if s["pressed"]:                    return "pressed"
		if s["hovered"] or btn.has_focus(): return "hover"
		return "normal"

	var animate := func(state: String) -> void:
		var bg_to   : Color = bg_targets[state]
		var text_to : Color = text_targets[state]
		var text_from := btn.get_theme_color("font_color", "Button")
		if s["tween"] != null:
			var t: Tween = s["tween"]
			if t.is_running():
				t.kill()
		var tw := btn.create_tween().set_parallel(true) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		s["tween"] = tw
		tw.tween_property(tween_box, "bg_color", bg_to, 0.15)
		tw.tween_method(
			func(c: Color):
				btn.add_theme_color_override("font_color",         c)
				btn.add_theme_color_override("font_hover_color",   c)
				btn.add_theme_color_override("font_focus_color",   c)
				btn.add_theme_color_override("font_pressed_color", c),
			text_from, text_to, 0.15
		)

	btn.mouse_entered.connect(func():
		s["hovered"] = true
		if btn.focus_mode != Control.FOCUS_NONE:
			btn.grab_focus()
		animate.call(get_state.call())
	)
	btn.mouse_exited.connect(func():
		s["hovered"] = false
		animate.call(get_state.call())
	)
	btn.focus_entered.connect(func(): animate.call("hover"))
	btn.focus_exited.connect(func():
		s["hovered"] = false
		animate.call("normal")
	)
	btn.button_down.connect(func():
		s["pressed"] = true
		animate.call("pressed")
	)
	btn.button_up.connect(func():
		s["pressed"] = false
		animate.call(get_state.call())
	)

	return btn


func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	s.shadow_size = 0
	s.content_margin_left   = 25.0
	s.content_margin_right  = 25.0
	s.content_margin_top    = 15.0
	s.content_margin_bottom = 15.0
	return s


func _update_button_texts() -> void:
	if _title_label:   _title_label.text   = tr("GAME_TITLE").replace(" ", "\n")
	if _btn_new:       _btn_new.text       = tr("UI_NEW_GAME")
	if _btn_continue:  _btn_continue.text  = tr("UI_CONTINUE")
	if _btn_settings:  _btn_settings.text  = tr("UI_SETTINGS")
	if _btn_quit:      _btn_quit.text      = tr("UI_EXIT")
	_update_settings_texts()


# ── Вступна анімація ──────────────────────────────────────────────────────────

func _start_intro_animation() -> void:
	await get_tree().process_frame  # чекаємо поки VBox порахує лейаут

	var delay := 0.15
	var last_tw: Tween = null
	for node in _anim_nodes:
		var orig_x := node.position.x
		node.position.x = orig_x - 20.0

		var tw := create_tween().set_parallel(true)
		tw.tween_property(node, "position:x", orig_x, 0.45)\
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(node, "modulate:a", 1.0, 0.40)\
			.set_delay(delay).set_ease(Tween.EASE_OUT)
		last_tw = tw
		delay += 0.15

	if last_tw:
		await last_tw.finished

# ── Версія ────────────────────────────────────────────────────────────────────

func _setup_focus_navigation() -> void:
	if _btn_continue.disabled:
		# "Продовжити" недоступна — пропускаємо її в навігації
		_btn_new.focus_neighbor_bottom   = _btn_new.get_path_to(_btn_settings)
		_btn_settings.focus_neighbor_top = _btn_settings.get_path_to(_btn_new)
	else:
		_btn_new.focus_neighbor_bottom      = _btn_new.get_path_to(_btn_continue)
		_btn_continue.focus_neighbor_top    = _btn_continue.get_path_to(_btn_new)
		_btn_continue.focus_neighbor_bottom = _btn_continue.get_path_to(_btn_settings)
		_btn_settings.focus_neighbor_top    = _btn_settings.get_path_to(_btn_continue)
	_btn_settings.focus_neighbor_bottom = _btn_settings.get_path_to(_btn_quit)
	_btn_quit.focus_neighbor_top        = _btn_quit.get_path_to(_btn_settings)


func _add_version_label() -> void:
	var ver := Label.new()
	ver.text = "v0.1 — демо"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.32, 0.27, 0.20))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 200
	ver.offset_top = -28
	ver.offset_bottom = -8
	add_child(ver)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _flex_spacer(ratio: float) -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_stretch_ratio = ratio
	return s

func _fixed_gap(px: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, px)
	return s

# ── Налаштування ──────────────────────────────────────────────────────────────

func _open_settings() -> void:
	AudioManager.play_sfx("ui_click")
	if _settings_overlay == null:
		_settings_overlay = _build_settings_overlay()
		add_child(_settings_overlay)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		if _settings_music_slider:
			_settings_music_slider.value = am.get_music_volume() * 100.0
		if _settings_sfx_slider:
			_settings_sfx_slider.value = am.get_sfx_volume() * 100.0
	var lm := get_node_or_null("/root/LocaleManager")
	if lm and _settings_lang_opt:
		_settings_lang_opt.selected = 0 if lm.get_language() == "uk" else 1
	_update_settings_texts()
	_settings_overlay.visible = true


func _update_settings_texts() -> void:
	if _settings_title_label:
		_settings_title_label.text = tr("UI_SETTINGS")
	if _settings_music_label and _settings_music_slider:
		_settings_music_label.text = tr("UI_MUSIC_VOLUME") + " %d%%" % int(_settings_music_slider.value)
	if _settings_sfx_label and _settings_sfx_slider:
		_settings_sfx_label.text = tr("UI_SFX_VOLUME") + " %d%%" % int(_settings_sfx_slider.value)
	if _settings_close_btn:
		_settings_close_btn.text = tr("UI_CLOSE")


func _build_settings_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.65)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dimmer)
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			overlay.visible = false
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	UIStyle.apply_panel(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_settings_title_label = Label.new()
	_settings_title_label.text = tr("UI_SETTINGS")
	_settings_title_label.add_theme_font_size_override("font_size", 22)
	_settings_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_settings_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_settings_title_label)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.65, 0.5, 0.18, 0.5)
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	vbox.add_child(lang_row)

	var lang_lbl := Label.new()
	lang_lbl.text = tr("UI_LANGUAGE")
	lang_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lang_row.add_child(lang_lbl)

	_settings_lang_opt = OptionButton.new()
	_settings_lang_opt.add_item("Українська", 0)
	_settings_lang_opt.add_item("English", 1)
	_settings_lang_opt.focus_mode = Control.FOCUS_NONE
	_settings_lang_opt.add_theme_font_size_override("font_size", 15)
	_settings_lang_opt.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	_settings_lang_opt.add_theme_color_override("font_hover_color", Color(0.85, 0.8, 0.6))
	var opt_sn := StyleBoxFlat.new()
	opt_sn.bg_color = Color(0.12, 0.11, 0.08)
	opt_sn.border_color = Color(0.48, 0.38, 0.13)
	opt_sn.set_border_width_all(1)
	opt_sn.content_margin_left = 10.0
	opt_sn.content_margin_right = 10.0
	opt_sn.content_margin_top = 5.0
	opt_sn.content_margin_bottom = 5.0
	_settings_lang_opt.add_theme_stylebox_override("normal",  opt_sn)
	_settings_lang_opt.add_theme_stylebox_override("hover",   opt_sn.duplicate())
	_settings_lang_opt.add_theme_stylebox_override("pressed", opt_sn.duplicate())
	_settings_lang_opt.add_theme_stylebox_override("focus",   opt_sn.duplicate())
	lang_row.add_child(_settings_lang_opt)

	var lm := get_node_or_null("/root/LocaleManager")
	_settings_lang_opt.item_selected.connect(func(idx: int):
		var locale := "uk" if idx == 0 else "en"
		if lm:
			lm.set_language(locale)
		_update_button_texts()
	)

	_settings_music_label = Label.new()
	_settings_music_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	vbox.add_child(_settings_music_label)

	_settings_music_slider = HSlider.new()
	_settings_music_slider.min_value = 0.0
	_settings_music_slider.max_value = 100.0
	_settings_music_slider.step = 1.0
	_settings_music_slider.focus_mode = Control.FOCUS_NONE
	_style_slider(_settings_music_slider)
	vbox.add_child(_settings_music_slider)
	_settings_music_slider.value_changed.connect(func(val: float):
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.set_music_volume(val / 100.0)
		_settings_music_label.text = tr("UI_MUSIC_VOLUME") + " %d%%" % int(val)
	)

	_settings_sfx_label = Label.new()
	_settings_sfx_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	vbox.add_child(_settings_sfx_label)

	_settings_sfx_slider = HSlider.new()
	_settings_sfx_slider.min_value = 0.0
	_settings_sfx_slider.max_value = 100.0
	_settings_sfx_slider.step = 1.0
	_settings_sfx_slider.focus_mode = Control.FOCUS_NONE
	_style_slider(_settings_sfx_slider)
	vbox.add_child(_settings_sfx_slider)
	_settings_sfx_slider.value_changed.connect(func(val: float):
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.set_sfx_volume(val / 100.0)
		_settings_sfx_label.text = tr("UI_SFX_VOLUME") + " %d%%" % int(val)
	)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_settings_close_btn = Button.new()
	_settings_close_btn.text = tr("UI_CLOSE")
	_settings_close_btn.add_theme_font_size_override("font_size", 18)
	_settings_close_btn.add_theme_color_override("font_color", C_GOLD)
	_settings_close_btn.add_theme_color_override("font_hover_color", C_GOLD_LIGHT)
	_settings_close_btn.add_theme_color_override("font_pressed_color", C_GOLD_DIM)
	_settings_close_btn.add_theme_color_override("font_focus_color", C_GOLD)
	_settings_close_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.apply_button(_settings_close_btn, Color.WHITE, Vector4(24, 10, 24, 10))
	_settings_close_btn.pressed.connect(func(): overlay.visible = false)
	btn_row.add_child(_settings_close_btn)

	return overlay


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.18, 0.12)
	track.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("slider", track)

	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(0.89, 0.8, 0.42)
	filled.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)

	slider.add_theme_icon_override("grabber",           _make_circle_texture(Color(0.89, 0.8, 0.42), 10))
	slider.add_theme_icon_override("grabber_highlight", _make_circle_texture(C_GOLD_LIGHT, 11))


func _make_circle_texture(color: Color, radius: int) -> ImageTexture:
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in d:
		for x in d:
			if Vector2(x + 0.5 - radius, y + 0.5 - radius).length() < radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
