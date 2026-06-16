extends Node

# Глобальні константи (з Дизайн-Документації)
const TILE_W = 64
const TILE_H = 32

const AP_MAX = 10
const AP_MOVE_COST = 2
const AP_ATTACK_COST = 4

const STAMINA_RECOVERY = 15
const STAMINA_MOVE_COST = 5
const STAMINA_ATTACK_COST = 15

const CHANCE_MIN = 5
const CHANCE_MAX = 95

# Глобальний прапорець debug-логів: увімкни true під час налагодження
const DEBUG_LOG := false

func _ready() -> void:
	_setup_custom_cursor()

# Кастомний курсор-перо: Globals — перший autoload, тож курсор активний
# ще до MainMenu. Без файлу — лишається системний курсор.
func _setup_custom_cursor() -> void:
	if not ResourceLoader.exists(UIStyle.CURSOR_TEX):
		return
	var tex: Texture2D = load(UIStyle.CURSOR_TEX)
	var hotspot := Vector2(3, 3)  # кінчик пера у SVG
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, hotspot)
