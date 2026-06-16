class_name UIStyle
## Централізовані стилі UI: текстурні StyleBox-и з фолбеком на StyleBoxFlat.
## SVG-асети тимчасові (процедурні) — фінальний арт із Figma замінює файли
## за тими ж шляхами без змін у коді. Якщо файлів немає — гра не падає,
## повертаються плоскі стилі в палітрі гри (патерн TERRAIN_TEXTURES / ITEM_ICONS).

const BTN_TEX: Dictionary = {
	"normal":  "res://assets/sprites/ui/btn_wood_normal.svg",
	"hover":   "res://assets/sprites/ui/btn_wood_hover.svg",
	"pressed": "res://assets/sprites/ui/btn_wood_pressed.svg",
}
const PANEL_FRAME_TEX := "res://assets/sprites/ui/panel_frame_ornate.svg"
const CURSOR_TEX := "res://assets/sprites/ui/cursor_quill.svg"

# Палітра гри
const COL_PARCHMENT := Color(0.965, 0.941, 0.855)  # #F6F0DA
const COL_GOLD := Color(0.62, 0.46, 0.14)
const COL_PANEL_BG := Color(0.07, 0.065, 0.055)
const COL_WOOD := Color(0.30, 0.20, 0.08)

# 9-patch межі текстур (мають відповідати SVG)
const _BTN_TEX_MARGIN := 16.0
const _PANEL_TEX_MARGIN := 56.0  # орнамент у кутах SVG сягає ~53px

## Відтінок для семантичних кнопок (атака червона, торгівля зелена тощо):
## множиться на текстуру дерева, тому базовий колір розбавляємо білим.
static func tint_from(base: Color) -> Color:
	return Color.WHITE.lerp(base, 0.45)

## StyleBox кнопки: state = "normal" | "hover" | "pressed".
## margins — content margin (left, top, right, bottom).
static func button_box(state: String, tint: Color = Color.WHITE,
		margins: Vector4 = Vector4(12, 4, 12, 4)) -> StyleBox:
	var path: String = BTN_TEX.get(state, BTN_TEX["normal"])
	if ResourceLoader.exists(path):
		var sb := StyleBoxTexture.new()
		sb.texture = load(path)
		sb.set_texture_margin(SIDE_LEFT, _BTN_TEX_MARGIN)
		sb.set_texture_margin(SIDE_TOP, _BTN_TEX_MARGIN)
		sb.set_texture_margin(SIDE_RIGHT, _BTN_TEX_MARGIN)
		sb.set_texture_margin(SIDE_BOTTOM, _BTN_TEX_MARGIN)
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.modulate_color = tint
		_set_content_margins(sb, margins)
		return sb
	# Фолбек: плоска кнопка в палітрі гри
	var fb := StyleBoxFlat.new()
	match state:
		"hover":
			fb.bg_color = COL_WOOD.lightened(0.18)
			fb.border_color = Color(0.79, 0.64, 0.15)
		"pressed":
			fb.bg_color = COL_WOOD.darkened(0.25)
			fb.border_color = COL_GOLD
		_:
			fb.bg_color = COL_WOOD
			fb.border_color = COL_GOLD
	fb.bg_color = fb.bg_color * tint if tint != Color.WHITE else fb.bg_color
	fb.set_border_width_all(1)
	fb.set_corner_radius_all(4)
	_set_content_margins(fb, margins)
	return fb

## Повна стилізація кнопки: 4 стани + focus + кольори шрифту.
static func apply_button(btn: Button, tint: Color = Color.WHITE,
		margins: Vector4 = Vector4(12, 4, 12, 4)) -> void:
	btn.add_theme_stylebox_override("normal", button_box("normal", tint, margins))
	btn.add_theme_stylebox_override("hover", button_box("hover", tint, margins))
	btn.add_theme_stylebox_override("pressed", button_box("pressed", tint, margins))
	# Disabled — без окремої текстури: normal із сірим відтінком
	btn.add_theme_stylebox_override("disabled",
		button_box("normal", tint * Color(0.5, 0.5, 0.5, 0.85), margins))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", COL_PARCHMENT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.92))
	btn.add_theme_color_override("font_pressed_color", COL_PARCHMENT.darkened(0.2))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.48))

## StyleBox панелі з орнаментною рамкою (9-patch).
## content_margins за замовчуванням ~ старій товщині рамки StyleBoxFlat,
## щоб лейаут не «стрибнув» (внутрішні MarginContainer-и дають решту відступів).
static func panel_box(tint: Color = Color.WHITE,
		margins: Vector4 = Vector4(4, 4, 4, 4),
		fallback_border: Color = COL_GOLD) -> StyleBox:
	if ResourceLoader.exists(PANEL_FRAME_TEX):
		var sb := StyleBoxTexture.new()
		sb.texture = load(PANEL_FRAME_TEX)
		sb.set_texture_margin(SIDE_LEFT, _PANEL_TEX_MARGIN)
		sb.set_texture_margin(SIDE_TOP, _PANEL_TEX_MARGIN)
		sb.set_texture_margin(SIDE_RIGHT, _PANEL_TEX_MARGIN)
		sb.set_texture_margin(SIDE_BOTTOM, _PANEL_TEX_MARGIN)
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.modulate_color = tint
		_set_content_margins(sb, margins)
		return sb
	# Фолбек: поточний плоский стиль модальних панелей
	var fb := StyleBoxFlat.new()
	fb.bg_color = COL_PANEL_BG
	fb.border_color = fallback_border
	fb.set_border_width_all(2)
	fb.set_corner_radius_all(4)
	_set_content_margins(fb, margins)
	return fb

static func apply_panel(panel: PanelContainer, tint: Color = Color.WHITE,
		margins: Vector4 = Vector4(4, 4, 4, 4),
		fallback_border: Color = COL_GOLD) -> void:
	panel.add_theme_stylebox_override("panel", panel_box(tint, margins, fallback_border))

static func _set_content_margins(sb: StyleBox, m: Vector4) -> void:
	sb.content_margin_left = m.x
	sb.content_margin_top = m.y
	sb.content_margin_right = m.z
	sb.content_margin_bottom = m.w
