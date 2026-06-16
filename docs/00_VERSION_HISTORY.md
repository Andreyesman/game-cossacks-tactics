# Історія змін GDD

## Версія 4.9 — 12.06.2026

### UI polish (Фаза 3.5, пункт 4.5.6) — дерев'яні кнопки, орнаментні рамки, курсор-перо

#### `src/ui/UIStyle.gd` (новий)

- Статичний хелпер (`class_name`, не autoload — патерн `InventoryManager`). `apply_button(btn, tint, margins)`, `apply_panel(panel, tint, margins, fallback_border)`, `tint_from(base)`.
- `StyleBoxTexture` з 9-patch межами. Фолбек на `StyleBoxFlat` у палітрі гри, якщо SVG відсутній — гра не падає без файлів (конвенція `TERRAIN_TEXTURES`/`ITEM_ICONS`).

#### `assets/sprites/ui/` — 5 нових SVG (тимчасові, процедурні)

- `btn_wood_normal/hover/pressed.svg` (192×64, 9-patch margin 16) — дерев'яна дошка з волокнами, сучками, цвяшками; hover дає золотий обідок, pressed — втиснута фаска.
- `panel_frame_ornate.svg` (192×192, margin 56) — рослинні завитки в кутах, подвійна золота лінія по краях, центр #0f0e0c.
- `cursor_quill.svg` (48×48) — гусяче перо, hotspot у кінчику (3,3).
- Figma-арт пізніше замінить файли за тими ж шляхами без змін у коді.

#### `src/core/Globals.gd`

- Додано `_ready()` → `_setup_custom_cursor()`: `Input.set_custom_mouse_cursor()` для `CURSOR_ARROW` і `CURSOR_POINTING_HAND`. Globals — перший autoload, курсор активний ще до MainMenu.

#### `src/ui/MainMenu.gd`

- Увімкнено мертву `_add_gradient_overlay()` (градієнтне затемнення зліва для читабельності заголовка/кнопок поверх ілюстрації). Кнопка «Закрити» Settings і панель Settings — через `UIStyle`.

#### Точки застосування

- Кнопки: `BattleResultScreen._create_button()`, `WorldMap._make_dialog_btn()/_make_trade_btn()`, `BattleManager._style_end_turn_button()` (зелений tint), `EncounterDialog` (червоний/нейтральний/зелений tint — code-override, `.tscn` не чіпали).
- Рамки панелей: Settings, CharacterSheet, BattleResultScreen (червонуватий tint при поразці), Game Over, діалог поселення, EncounterDialog.

#### Свідомо не чіпали

- Великі кнопки MainMenu (Tween анімує `StyleBoxFlat.bg_color` — несумісно зі StyleBoxTexture, навмисний дизайн), TopBar (Figma), нутрощі UnitPanel/CombatLog/TurnQueueUI, `game_theme.tres`.

#### Верифікація

- Headless-компіляція 7 змінених скриптів — без помилок. Візуально в грі: градієнт меню, Settings (орнаментна рамка + дерев'яна «Закрити»), EncounterDialog, End Turn; бій запускається чисто.

---

## Версія 4.8 — 12.06.2026

### Закрито 4.5.5 — Процедурна географія глобальної карти та зони впливу

Більшість механік уже була реалізована в коміті «Map generator» (генерація патчів, пергаментний рендер, швидкість/огляд по місцевості, Voronoi-зони впливу), але пункт не був закритий у плані. Доробка цієї версії — останній геймплейний пробіл специфікації (засідки) та чистка мертвого коду.

#### `src/ui/WorldMap.gd`

- Додано `get_ambush_detection_multiplier(pos)` — ×1.6 до радіуса виявлення гравця, коли він у болоті або яру (місця засідок).
- `_render_biomes()` — прибрано мертвий параметр `_biomes: Array` (масив прямокутних біомів давно ігнорувався).

#### `src/world/EnemyParty.gd`

- `_process_patrol()`: радіус виявлення гравця множиться на `_ambush_multiplier()` — лише для бандитських загонів (`none`/`bandits`); фракційні патрулі orda/crown у засідках не сидять.
- Посилання на WorldMap кешується (`_world_map_ref`, `_get_world_map()`) — без пошуку по дереву щокадру (урок перф-фіксу 0.1.13 з v4.7).

#### `src/core/WorldGenerator.gd`

- Видалено `_gen_biomes()` та її виклик — прямокутні триколірні біоми більше не генеруються; ключ `biomes` зник із `world_state`. Географія повністю на патчах (`forest_patches`, `hill_patches`, `swamp_patches`, `kurgans`, `ravines`) + `influence_anchors`.

#### `src/core/CampaignManager.gd`

- Прибрано `"biomes": []` зі стартового `world_state`; коментар-формат стану доповнено ключами географії.

#### `implementation_plan.md`

- **Відновлено пошкоджені секції 4.8/4.9 «Аудіо»** — у коміті «Map generator» новий текст 4.5.5 був вставлений посеред секції 4.8 і затер кінець 4.8 та початок 4.9; оригінальний текст відновлено з гіту (`f606ef5`), стару дублюючу версію 4.5.5 замінено новою специфікацією.
- 4.5.5 позначено ✅ з нотатками реалізації.

#### Верифікація

- Headless smoke-тест `WorldGenerator.generate()`: 25 локацій, 6 партій, 21 ліс, 9 пагорбів, 8 боліт, 5 курганів, 3 яри, 5 якорів впливу; ключа `biomes` немає.
- Headless-компіляція `WorldMap.gd` (з ручною реєстрацією автолоадів), `EnemyParty.gd`, `CampaignManager.gd` — без помилок.

---

## Версія 4.7 — 11.06.2026

### Завершення Фази 3.5 — Спрайти та анімація юнітів

#### `implementation_plan.md`

- Позначено як виконане завдання з інтеграції анімацій (idle, attack, walk, death) для юнітів у бою.

#### `src/units/CombatUnit.gd`

- Проведено налаштування анімації смерті: протестовано більш м'яке приземлення тіла за допомогою `Tween.TRANS_SINE` замість `Tween.TRANS_BOUNCE`, після чого повернуто оригінальний перехід `TRANS_BOUNCE` для кращого візуального сприйняття.

---

## Версія 4.6 — 09.06.2026

### TopBar — вирівнювання висоти всіх трьох панелей до 56px (Figma-точно)

**Проблема:** Godot Label з `font_size=18` дає `content_min=26px` (не 24px як CSS `leading-[24px]`). Кнопка інвентарю `Button` з emoji `⛺️` при `font_size=28` вимагає `content_min=41px`. Результат: ліва панель 58px, права 65px, центральна 56px.

#### `src/ui/WorldMap.gd` — `_build_top_bar()`

| Місце | Зміна | Обґрунтування |
|-------|-------|---------------|
| Ліва панель `lp_st` | `content_margin_top/bottom: 16.0 → 15.0` | 15+26+15=56px (компенсація Godot font metrics ≠ CSS line-height) |
| `_inventory_btn` | Загорнуто в `Control inv_box (custom_minimum_size=32×32)`; кнопка `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` | plain `Control` не транслює мінімальний розмір дітей у `HBoxContainer`; HBoxContainer бачить 32px замість 41px |

**Додано:** `_debug_topbar_heights()` — тимчасова діагностична функція (виводить `margin_top/bottom`, `content_min`, `size.y` для кожної панелі після першого frame). Викликається через `call_deferred("_debug_topbar_heights")` в `_build_top_bar()`.

**Результат:** всі три панелі — 56px.

---

## Версія 4.5 — 09.06.2026

### Кнопки швидкості — повний перехід на `TextureButton` + 9 SVG іконок з Figma

Замінено схему `Button + TextureRect (дочірній)` на нативний `TextureButton` з трьома текстурними слотами. Додано radio-group поведінку: активна кнопка завжди показує `*_active.svg` і не реагує на кліки.

#### `assets/sprites/ui/` — нові файли (з Figma)

**Видалено (9 файлів):** `pause_default.svg`, `pause_hover.svg`, `pause_active.svg`, `speed_play_gray.svg`, `speed_play_hover.svg`, `speed_play_yellow.svg`, `speed_fwd_gray.svg`, `speed_fwd_hover.svg`, `speed_fwd_yellow.svg`

**Створено (9 файлів):**

| Файл | Розмір | Опис |
|------|--------|------|
| `speed_pause_default.svg` | 32×32 | Дві смуги, fill `#BEBBAC`, stroke `#585551`, noise filter (Figma) |
| `speed_pause_hover.svg` | 32×32 | Дві смуги, fill `#E4CD80` |
| `speed_pause_active.svg` | 32×32 | Дві смуги, fill `#FCCC28` |
| `speed_play_default.svg` | 32×32 | Трикутник-стрілка, fill `#BEBBAC`, stroke `#080707` (автентичні Figma шляхи) |
| `speed_play_hover.svg` | 32×32 | fill `#E4CD80` |
| `speed_play_active.svg` | 32×32 | fill `#FCCC28` |
| `speed_fwd_default.svg` | 40×32 | Composite: tri1 (fill `#BEBBAC`, stroke `#585551`) + tri2 (fill `#E4CD80`, stroke `#080707`) |
| `speed_fwd_hover.svg` | 40×32 | Обидва трикутники fill `#E4CD80` |
| `speed_fwd_active.svg` | 40×32 | Обидва трикутники fill `#FCCC28` |

Кольори по станах: **Default** = `#BEBBAC` (сіро-бежевий), **Hover** = `#E4CD80` (світло-золотий), **Active** = `#FCCC28` (яскраво-жовтий).

`speed_fwd_*.svg` — composite SVG 40×32: два nested `<svg>` елементи (`tri2` x=12 під `tri1` x=0), масштаб через `viewBox`.

#### `src/ui/WorldMap.gd`

| Місце | Зміна |
|-------|-------|
| Змінні `_pause_btn/_speed1_btn/_speed2_btn` | `Button → TextureButton` |
| Видалено змінні | `_pause_icon: TextureRect`, `_play_icon: TextureRect`, `_fwd_icon: TextureRect` |
| Перейменовано текстури | `_tex_play_gray → _tex_play_default`, `_tex_play_yellow → _tex_play_active`, `_tex_fwd_gray → _tex_fwd_default`, `_tex_fwd_yellow → _tex_fwd_active` |
| Шляхи завантаження | `pause_*.svg → speed_pause_*.svg`, `speed_play_gray → speed_play_default`, тощо |
| `_build_speed_panel()` — кнопки | Замість `_make_speed_icon_btn() + TextureRect-дитина` → `_make_speed_tex_btn(tex_n, tex_h, tex_p, tip, size) → TextureButton` |
| Новий хелпер `_make_speed_tex_btn()` | Створює `TextureButton (ignore_texture_size=true, STRETCH_KEEP_ASPECT_CENTERED, focus_mode=NONE)` + FloatingLabel tooltip |
| `_make_speed_icon_btn()` | Залишено (використовується для `_inventory_btn`) |
| `_refresh_speed_btns()` | Делегує до `_apply_speed_btn_state()` для кожної з трьох кнопок |
| Новий метод `_apply_speed_btn_state()` | **Активна:** `disabled=true`, `texture_normal/hover/pressed/disabled = *_active`; **Неактивна:** `disabled=false`, `texture_normal=*_default`, `texture_hover=*_hover`, `texture_pressed=*_active`, `texture_disabled=null` |

**Radio-group логіка:** активна кнопка заблокована (`disabled=true`) і завжди золота — не реагує на hover і не перемикається повторним кліком. Hover і pressed обробляються нативно TextureButton.

---

## Версія 4.4 — 09.06.2026

### Кнопка паузи — SVG іконки з Figma (три стани)

#### `assets/sprites/ui/` (нова папка)

| Файл | Стан | Fill | Stroke |
|------|------|------|--------|
| `pause_default.svg` | Default | прозорий | `#585551` |
| `pause_hover.svg` | Hover | `#E4CD80` | `#585551` |
| `pause_active.svg` | Active (пауза) | `#FCCC28` | `#585551` |

Геометрія (з Figma фрейм `2037:70`): дві смуги 7×25px, `rx=2`, x=4.5/20.5, y=3.5, viewBox 0 0 32 32. Три окремі символи: `state=Default` (2037:69), `state=Hover` (2037:71), `state=Active` (2037:74).

#### `src/ui/WorldMap.gd`

| Місце | Зміна |
|-------|-------|
| Нові змінні | `_pause_icon: TextureRect`; `_tex_pause_default/hover/active: Texture2D` (замінюють `_pause_bar_styles: Array[StyleBoxFlat]`) |
| `_build_speed_panel()` | Завантаження трьох текстур з `res://assets/sprites/ui/`; замість 2× `Panel` зі `StyleBoxFlat` → `TextureRect 32×32, STRETCH_KEEP_ASPECT_CENTERED` |
| `mouse_entered` на `_pause_btn` | `_pause_icon.texture = _tex_pause_hover` якщо не пауза |
| `_refresh_speed_btns()` | `_pause_icon.texture = _tex_pause_active if _is_paused else _tex_pause_default` (замість циклу по `_pause_bar_styles`) |

**Видалено:** `_pause_bar_styles: Array[StyleBoxFlat]`, hover-колір `c_bar_hover`, `c_active`, `c_dim` локальні змінні у `_refresh_speed_btns()`.

---

## Версія 4.3 — 09.06.2026

### Native Godot Theme — game_theme.tres

Замість розрізнених `add_theme_font_override` по всьому коду — один Theme ресурс, який автоматично каскадується на всі нащадки.

#### `assets/theme/game_theme.tres` (новий файл)

```gdresource
[gd_resource type="Theme" load_steps=2 format=3]
[ext_resource type="FontFile" uid="uid://puda8fxf8f7q"
    path="res://assets/fonts/KellySlab-Regular.ttf" id="1_kelly"]
[resource]
default_font = ExtResource("1_kelly")
default_font_size = 16
Label/colors/font_color = Color(0.345098, 0.333333, 0.317647, 1)  # #585551
```

#### `project.godot`

```ini
[gui]
theme/custom="res://assets/theme/game_theme.tres"   ← НОВЕ
theme/default_font="res://assets/fonts/KellySlab-Regular.ttf"
theme/default_font_size=16
```

#### Видалено `add_theme_font_override("font", Kelly Slab)` з:

| Файл | Місця |
|------|-------|
| `src/ui/MainMenu.gd` | `_make_btn()`, settings lang OptionButton, settings close Button; `_font_button: FontFile` і `FONT_BUTTON` const прибрані; лямбда підкреслення → `btn.get_theme_font("font")` |
| `src/ui/WorldMap.gd` | `_build_top_bar()` — блок `if ResourceLoader.exists(KellySlab): _top_bar_root.add_theme_font_override(...)` |

#### Видалено зайві `add_theme_font_size_override(prop, 16)` (default = 16, override не потрібен):

| Файл | Видалені рядки |
|------|----------------|
| `src/ui/CombatLog.gd` | `normal_font_size=16`, `bold_font_size=16` для RichTextLabel |
| `src/ui/TurnQueueUI.gd` | `font_size=16` для `round_label`, `location_label` |
| `src/ui/BattleResultScreen.gd` | `font_size=16` для `name_lbl` |
| `src/ui/UnitPanel.gd` | `font_size=16` для `weapon_header`, `skill_header`, skill btn; `normal_font_size=16`+`bold_font_size=16` для RichTextLabel |
| `src/ui/MainMenu.gd` | `font_size=16` для `lang_lbl`, `_settings_music_label`, `_settings_sfx_label` |
| `src/ui/WorldMap.gd` | `font_size=16` для `lbl` нотифікації; `normal_font_size=16` для `_discovery_label`, `_onboarding_label` |
| `src/ui/CharacterSheet.gd` | `font_size=16` для `nl` (origin), `kl`/`vl` (stat row) |
| `src/tactical/BattleManager.gd` | `font_size=16` для TurnQueue label |
| `src/units/CombatUnit.gd` | `font_size=16` для floating damage label |

**Залишено без змін:** всі `add_theme_font_size_override` з розмірами ≠ 16 (10, 12, 13, 14, 15, 18, 20, 22, 26, 28, 36, 60, 120).  
**RuslanDisplay** залишено тільки для заголовку в MainMenu (`_font_title`, `FONT_TITLE`) — навмисно.

#### Виправлено INTEGER_DIVISION попередження

`WorldMap.gd:2241` — `var _cell_row: int = _cell_idx / 3` → додано `@warning_ignore("integer_division")` (GDScript не підтримує `//` як оператор).

---

## Версія 4.2 — 08.06.2026

### TopBar глобальної карти — Figma-дизайн (три пергаментні панелі)

#### `src/ui/WorldMap.gd`

| Місце | Зміна |
|-------|-------|
| `_build_top_bar()` — структура | Суцільний темний бар замінено на три `PanelContainer` на `Control (PRESET_TOP_WIDE, h=68px)`: ліва, центральна (anchor=0.5), права (anchor=1.0) |
| `_build_top_bar()` — кольори | Фон `Color(0.965, 0.941, 0.855)` (`#F6F0DA`), рамка `Color(0.345, 0.333, 0.318)` (`#585551`), border 2px |
| `_build_top_bar()` — corner radii | Ліва: `corner_radius_bottom_right=16`; Центральна: `BL=BR=32`; Права: `corner_radius_bottom_left=16` |
| `_build_top_bar()` — padding | Ліва: `py=16 px=24`; Центральна: `py=12 px=24`; Права: `py=12 px=24` |
| `_build_top_bar()` — Kelly Slab | `_top_bar_root.add_theme_font_override("font", load("res://assets/fonts/KellySlab-Regular.ttf"))` — каскадно на всі нащадки |
| `_build_top_bar()` — Day group | Видалено зайвий `tod_hbox` та `_time_phase_icon`; `_time_phase_label` один (текст `"☀️ День"` вже містить emoji з перекладу) |
| `_build_top_bar()` — інвентар | `custom_minimum_size = Vector2(32, 32)` (було 36×36), `font_size = 28` (було 32) |
| `_build_speed_panel()` — padding | `content_margin_top/bottom = 12.0` (було 16.0) |
| `_build_speed_panel()` — PauseButton | `custom_minimum_size = Vector2(32, 32)` (було 40×40); bars `8×32px` з gap=8px — без змін |
| `_build_speed_panel()` — PlayButton | `custom_minimum_size = Vector2(32, 32)` (було 41×40); icon `28×32` (було 33×38) |
| `_build_speed_panel()` — ForwardButton | `custom_minimum_size = Vector2(40, 32)` (було 54×40); fwd_box `40×32`; tris `28×32 at i*12` (було 33×38 at i*21) |
| `_refresh_speed_btns()` — c_dim | `Color(0, 0, 0, 0)` прозорий (було `Color(0.345, 0.333, 0.318)`) — пауза-смужки без заливки в default-стані |
| `_update_day_night()` | Видалено `add_theme_color_override("font_color", ...)` для `_time_phase_label` — колір статичний `#585551`; видалено оновлення `_time_phase_icon` |
| Видалено | `var _time_phase_icon: Label = null` — змінна більше не потрібна |

**Причина дублювання іконки (bug root cause):** `tr("TIME_DAY")` повертає `"☀️ День"` (emoji вбудований у переклад `localization/translations.csv`). Окремий `_time_phase_icon` Label створював другу копію сонця.

---

## Версія 4.1 — 08.06.2026

### Спрайтові текстури тайлів місцевості в бою

#### `src/tactical/TacticalGrid.gd`

| Місце | Зміна |
|-------|-------|
| Нова константа `TERRAIN_TEXTURES` | Маппінг `terrain_type int → res://assets/sprites/tiles/*.png` для всіх 6 типів (0=CLEAR/grass, 1=bushes, 2=swamp, 3=water, 4=rocks, 5=trees) |
| `_setup_tile_layer()` — цикл по terrain_colors | Для кожного типу: `ResourceLoader.exists(tex_path)` → `load(tex_path)` або `_make_diamond_texture(color)` як fallback |
| `_setup_tile_layer()` — terrain_colors | Додано `TerrainType.CLEAR: Color(0.55, 0.50, 0.25, 0.30)` (fallback колір для трави якщо PNG відсутній) |
| `_setup_tile_layer()` — цикл заповнення | CLEAR-тайли тепер рендеряться якщо `terrain_source_ids.has(TerrainType.CLEAR)` (тобто якщо `tile_grass.png` завантажено) |

#### `assets/sprites/tiles/` (нова папка)

Очікувані файли: `tile_grass.png`, `tile_bushes.png`, `tile_swamp.png`, `tile_water.png`, `tile_rocks.png`, `tile_trees.png` — ізометричні ромби 160×80px з прозорим фоном.

**Поведінка fallback:** якщо PNG файл відсутній — `_make_diamond_texture(color)` генерує кольоровий ромб як раніше. Гра не падає.

---

## Версія 4.0.5 — 08.06.2026

### UI polish: горизонтальні кнопки вибору козака, розміри слотів інвентарю

#### `src/ui/WorldMap.gd`

| Місце | Зміна |
|-------|-------|
| `_inv_squad_row` (декларація + init) | `GridContainer (columns=3)` → `VBoxContainer (separation=4)` |
| `_refresh_squad_row()` — кожна кнопка | `Button (SIZE_EXPAND_FILL, min_height=48)` + `HBoxContainer (sep=10)` всередині: `TextureRect 40×40` ліворуч + `Label font_size 14` праворуч. Обраний: `border Color(0.89, 0.8, 0.42) 2px`; неактивний: `Color(0.45, 0.35, 0.12) 1px`; фон: `Color(0.1, 0.09, 0.07)` |
| `_refresh_equipment_section()` — розміри слотів | Розмір слоту тепер залежить від рядка сітки: `_cell_idx / 3 == 1` → `Vector2(100, 180)`, інші → `Vector2(100, 100)`. Відповідає точно `CharacterSheet._equipment_slot()` |

---

## Версія 4.0.4 — 08.06.2026

### UI polish: портрет в кнопці козака — SIZE_EXPAND_FILL

#### `src/ui/WorldMap.gd` — `_refresh_squad_row()`

- `btn.custom_minimum_size` — висота `80 → 0` (автоматична)
- `TextureRect.custom_minimum_size` — `40×40 → 80×80` (квадрат на повну ширину)
- `TextureRect.size_flags_horizontal` — `SIZE_SHRINK_CENTER → SIZE_EXPAND_FILL`
- `VBoxContainer.size_flags_horizontal = SIZE_EXPAND_FILL`
- `Label.size_flags_horizontal = SIZE_EXPAND_FILL`

---

## Версія 4.0.3 — 08.06.2026

### Bugfix: кнопки козаків — стиль і розміри

#### `src/ui/WorldMap.gd` — `_refresh_squad_row()`

- Видалено `btn.flat = true` — StyleBoxFlat фон тепер відображається коректно
- `btn.custom_minimum_size` — `Vector2(90, 0) → Vector2(90, 80)`
- `st.bg_color` — уніфіковано: `Color(0.1, 0.09, 0.07)` для обраного і неактивного
- `st.border_color` неактивний — `Color(0.3, 0.24, 0.09) → Color(0.45, 0.35, 0.12)` (яскравіший)
- `GridContainer.v_separation` — `8 → 4`

---

## Версія 4.0.2 — 08.06.2026

### UI polish: іконки крамниці, сітка інвентарю, портрети у виборі загону

#### `src/core/InventoryManager.gd`

Додано 3 маппінги в `ITEM_ICONS` для товарів крамниці (`_default_shop`):
- `"padded_zhupan"` → `icon_jupan.png`
- `"leather_lamellar"` → `icon_mail.png`
- `"shlyk"` → `icon_cap.png`

#### `src/ui/WorldMap.gd`

| Місце | Зміна |
|-------|-------|
| Крамниця (`_show_location_dialog`) | Іконка товару `24×24` → `32×32` |
| Сітка слотів (`_refresh_equipment_section`) | `TextureRect 48×48 SIZE_SHRINK_CENTER` → динамічний `minf(p_x−10, p_y−50)` з `SIZE_EXPAND_FILL`, назва в `MarginContainer 5px`, `line_spacing −2` — стиль ідентичний `CharacterSheet._equipment_slot()` |
| Секція ЗАГІН (`_refresh_squad_row`) | `HBoxContainer` → `GridContainer (columns=3, h/v_sep=8)`, кнопки тепер містять `VBoxContainer`: спрайт `40×40` (`{name}_front.png`) + `Label font_size 10`. `NAME_TO_SPRITE` dict для Ничипір/Гаврило/Тимофій/Панько; fallback для рекрутів по індексу |

---

## Версія 4.0.1 — 08.06.2026

### UI polish: розмір іконок у слотах CharacterSheet та WorldMap

**`src/ui/CharacterSheet.gd` — `_equipment_slot()`:**
- `TextureRect.custom_minimum_size` — замінено фіксовані `32×32` на квадрат `min(p_size.x−20, p_size.y−50)`. Іконка займає більшу частину слоту (80×70 для слоту 100×100, 80×130 для 100×180) і залишає місце для назви знизу.
- `size_flags_horizontal/vertical = SIZE_SHRINK_CENTER` — іконка центрується, не розтягується.
- Label назви предмета: `autowrap_mode = AUTOWRAP_WORD_SMART`, `custom_minimum_size.x = p_size.x − 10`, `line_spacing = −2`. Довгі назви (напр. "Козацька Шабля") переносяться на два рядки і не обрізаються.

**`src/ui/WorldMap.gd` — `_refresh_equipment_section()` сітка слотів:**
- `TextureRect.custom_minimum_size` — `32×32` → `48×48`.

---

## Версія 4.0 — 08.06.2026

### Фаза 3.5 — 4.5.3: Іконки предметів (код) ✅

Замінено емодзі (⚔️🛡️🪖) на `TextureRect` з PNG-іконками у всіх UI-панелях. При відсутньому файлі — автоматичний fallback на емодзі. Без змін структури item-словників і `.tres` файлів.

---

#### Нові файли та папки

| Шлях | Опис |
|------|------|
| `assets/sprites/icons/` | Нова папка для іконок предметів 48×48px, прозорий фон. Очікує фінальний PNG-арт. |

---

#### `src/core/InventoryManager.gd`

**`ITEM_ICONS: Dictionary`** — новий константний маппінг `item_id → res://assets/sprites/icons/*.png` (15 записів: saber, musket, janissary_musket, spear, warhammer, battle_axe, dagger, bow, mail, jupan, cuirass, helm, misyurka, kuchma, cap).

**`get_item_icon(item_id: String) -> Texture2D`** — новий статичний метод:
- Шукає `item_id` у `ITEM_ICONS`
- Перевіряє `ResourceLoader.exists()` перед `load()`
- Повертає `null` якщо файл відсутній → всі споживачі показують емодзі-fallback

---

#### `src/ui/CharacterSheet.gd`

**`_equipment_slot()`** — доданий останній параметр `item_id: String = ""`. Якщо `filled and item_id != ""` і текстура знайдена → `TextureRect` квадратний (розмір залежить від слоту, детальніше в v4.0.1). Інакше → `Label` з емодзі.

**`_build_equipment()`** — визначає `item_id` для трьох слотів перед побудовою рядів:

| Слот | Джерело |
|------|---------|
| Зброя | `_unit.weapon_resource.resource_path.get_file().get_basename()` |
| Броня | `(_unit.get("armor_path") as String).get_file().get_basename()` |
| Шолом | `(_unit.get("helm_path") as String).get_file().get_basename()` |

---

#### `src/ui/WorldMap.gd`

| Місце | Зміна |
|-------|-------|
| `_refresh_equipment_section()` — сітка слотів 3×3 | `TextureRect 32×32` або Label-емодзі (fallback) |
| `_refresh_inventory_section()` — список інвентарю | `TextureRect 24×24` перед назвою кожного предмета |
| `_show_location_dialog()` — секція крамниці | `TextureRect 24×24` перед назвою кожного товару |

---

#### `src/ui/BattleResultScreen.gd`

**`_loot_slot()`** — доданий параметр `icon_tex: Texture2D = null`. Якщо `icon_tex != null` → `TextureRect 56×56` (збільшено в v4.0.1, було 32×32), назва через `FloatingLabel` при hover; інакше → `Label` з емодзі + текст.

**`_build_loot_column()`** — передає `InventoryManager.get_item_icon(item.get("id", ""))` у `_loot_slot()`.

---

**Файли:** `src/core/InventoryManager.gd`, `src/ui/CharacterSheet.gd`, `src/ui/WorldMap.gd`, `src/ui/BattleResultScreen.gd`, `assets/sprites/icons/` (нова папка)

---

## Версія 3.9.1 — 06.06.2026

### Bugfix: другий бій не завантажувався (beige screen) + data_path + невидимі юніти

Три пов'язані баги виявлені та усунені. Жодних нових функцій — тільки надійність.

---

#### Баг 1 — Beige screen у другому бою (root cause)

**Симптом:** Після першого бою повернення на WorldMap проходило нормально, але при старті наступного бою CarpaignManager.start_battle() викликався (музика плавно затихала), проте сцена Battle ніколи не завантажувалась — залишався порожній бежевий екран. Лог зупинявся на `[WorldMap] blocked by encounter dialog`, `BattleManager: _ready() починається...` так і не з'являвся.

**Причина:** `get_tree().create_tween()` у `start_battle()` і `finish_battle()` — SceneTree tween може мовчки зависати під час переходу сцени і ніколи не емітувати сигнал `finished`. `await tw.finished` підвішував корутину назавжди; `change_scene_to_file` так і не викликався.

**Фікс у `src/core/CampaignManager.gd`** (обидві функції):
```gdscript
# Було:
var tw = get_tree().create_tween()
tw.tween_property(get_tree().current_scene, "modulate:a", 0.0, 0.2)
await tw.finished
get_tree().change_scene_to_file(...)

# Стало:
var tw = get_tree().create_tween()
tw.tween_property(get_tree().current_scene, "modulate:a", 0.0, 0.2)
await get_tree().create_timer(0.25).timeout   # create_timer() надійніший за tween.finished
get_tree().change_scene_to_file(...)
```

`create_timer().timeout` гарантовано спрацьовує через SceneTree — не залежить від стану вузлів і не підвішується при переходах між сценами.

---

#### Баг 2 — `data_path` порожній після першого бою

**Симптом:** Козаки між боями втрачали прив'язку до своїх `.tres` файлів — замість `Nychypir.tres` поле `data_path` ставало порожнім або вказувало на `CossackData.tres` (шаблонний ресурс).

**Причина:** `Resource.duplicate()` в BattleManager видаляє `resource_path` у продублікованого ресурсу (очікувана поведінка Godot). Після бою `_serialize_units()` читав `unit.data.resource_path` — і отримував `""`.

**Фікс у `src/core/CampaignManager.gd`, `_serialize_units()`:**
```gdscript
# Було:
u_data["data_path"] = unit.data.resource_path   # "" після .duplicate()

# Стало:
# resource_path порожній після .duplicate() — зберігаємо шлях з попереднього запису загону
u_data["data_path"] = pre.get("data_path", unit.data.resource_path)
```

`pre` — запис цього ж козака у `world_state["squad"]` до бою, знайдений за `name`. Якщо запис є — беремо `data_path` звідти.

---

#### Баг 3 — Невидимі юніти при нестандартному потоці ініціалізації

**Симптом:** У деяких крайніх випадках юніти рендерились як порожні Sprite2D (без текстури).

**Причина:** `setup_from_data()` завжди завершувався `create_visual_placeholder()` — порожній Sprite2D без текстури. Заповнення текстури (`update_sprite()`) відбувалось лише в `BattleManager._apply_enemy_config()` та в блоці ініціалізації козаків. Якщо якийсь юніт оминав ці шляхи — залишався невидимим.

**Фікс у `src/units/CombatUnit.gd`, `_ready()`:**
```gdscript
func _ready() -> void:
    setup_from_data()
    update_sprite()   # захисний виклик: спрайт завжди заповнений після _ready()
```

BattleManager продовжує викликати `update_sprite()` після встановлення `name` вузла (ключ спрайту залежить від імені) — це залишається основним шляхом. Виклик в `_ready()` — страхова сітка.

---

#### Діагностичні prints (тимчасові, очистити після підтвердження)

Додано для діагностики під час лагодження. Присутні у файлах:

| Файл | Print |
|------|-------|
| `CampaignManager.gd` | `"CM: start_battle() викликано, config=..."` і `"CM: timer finished, changing scene..."` |
| `LoadingScreen.gd` | `"LoadingScreen: _ready() — починаємо перехід до Battle..."` і `"LoadingScreen: fade завершено..."` |
| `BattleManager.gd` | `"BattleManager: _ready() починається..."`, `"Старт системи..."`, squad_data.size(), `_apply_enemy_config` stats, `update_sprite() ДО/ПІСЛЯ` |
| `CombatUnit.gd` | `"  update_sprite: '%s' key='%s' front_exists=..."` |

**Файли:** `src/core/CampaignManager.gd`, `src/units/CombatUnit.gd`, `src/tactical/BattleManager.gd`, `src/ui/LoadingScreen.gd`

---

## Версія 3.9 — 05.06.2026

### Фаза 3.5 — 4.5.1: Код інтеграції спрайтів юнітів ✅

Повна заміна `Polygon2D`-ромбів на `Sprite2D` у бою. Код готовий — достатньо замінити placeholder PNG на фінальний арт.

**Що зроблено:**

#### `src/units/CombatUnit.gd`

**Нові змінні:**
```gdscript
var _sprite: Sprite2D
var _sprite_front: Texture2D
var _sprite_back: Texture2D
```

**Нові константи:**
```gdscript
const NAME_TO_SPRITE = {"Ничипір":"nychypir","Гаврило":"havrylo","Тимофій":"tymofiy","Панько":"panko"}
const PATH_TO_SPRITE = {"BanditLeader":"bandit","Bandit":"bandit","Отаман":"bandit","Розбійник":"bandit",
    "TatarHeavy":"tatar","Tatar":"tatar","Татарський":"tatar","Татарин":"tatar",
    "Janissary":"janissary","Яничар":"janissary","Reiestr":"nychypir","Реєстровий":"nychypir"}
```

**Нові методи:**

| Метод | Опис |
|-------|------|
| `_get_sprite_key() -> String` | Ключ спрайту по імені вузла (козаки) або `name`/`resource_path` (вороги). Для ворогів: `resource_path` порожній після `.duplicate()` — fallback на `name` вузла |
| `_update_sprite_direction(dir: Vector2)` | Перемикає `texture`/`flip_h` за screen-space напрямком: `dir.y ≥ 0` → front, `dir.y < 0` → back; `flip_h` за знаком `dir.x` |
| `update_sprite()` | Завантажує `_sprite_front`/`_sprite_back`, встановлює початковий напрямок (козаки: back+flip_h=true; вороги: front+flip_h=true). Якщо файли не існують — fallback на Polygon2D+ActiveOutline |

**Змінені методи:**

| Метод | Зміна |
|-------|-------|
| `create_visual_placeholder()` | Очищає старі дочірні візуальні вузли; створює порожній `Sprite2D` (scale=0.7, offset=(0,−30)); текстур не завантажує — це робить `update_sprite()` |
| `get_portrait()` | Повертає `_sprite_front` замість пошуку `Sprite2D` по дереву |
| `start_turn()` | `_sprite.modulate = Color(1.3,1.3,1.3)` замість `ActiveOutline.visible = true` |
| `end_turn()` | `_sprite.modulate = Color.WHITE` замість `ActiveOutline.visible = false` |
| `die()` | Скидає `_sprite.modulate = Color.WHITE` перед death tween (щоб active-highlight не впливав на колір тіла) |
| `move_along_path()` | `tween.tween_callback(_update_sprite_direction.bind(dir))` перед кожним кроком шляху |
| `execute_shoot()` | `_update_sprite_direction(target.position - position)` перед анімацією |
| `_perform_attack_logic()` | `_update_sprite_direction(target.position - position)` перед анімацією |
| `set_highlight()` | Tweens `_sprite.modulate` (Color(1.15,1.15,1.15)/WHITE); fallback на `self.modulate:v` без спрайту |

**Початкові напрямки:**
- Козаки: `_sprite_back`, `flip_h = true` — спиною до камери (вправо-вгору)
- Вороги: `_sprite_front`, `flip_h = true` — обличчям до камери (вліво-вниз)

#### `src/tactical/BattleManager.gd`

- Козаки (~рядок 99): після `node.name = data.get("name", node.name)` → `node.update_sprite()` — щоб ім'я вузла вже було встановлено при визначенні ключа спрайту
- Вороги (~рядок 693): після `enemy.setup_from_data()` → `enemy.update_sprite()` — аналогічно після призначення `enemy.name`

**Логіка виклику `update_sprite()`:**

```
_ready() → setup_from_data() → create_visual_placeholder()  [порожній Sprite2D]
BattleManager:
  node.name = "Ничипір"        ← ключ sprite_key тепер відомий
  node.update_sprite()         ← завантажує nychypir_front/back.png
```

**Fallback:** якщо `ResourceLoader.exists(front_path) == false` — `Sprite2D` видаляється, створюється `Polygon2D` + `ActiveOutline` (стара поведінка). Гра не падає при відсутніх спрайтах.

**Файли:** `src/units/CombatUnit.gd`, `src/tactical/BattleManager.gd`

---

## Версія 3.8 — 05.06.2026

### Фаза 3.5 — Візуальне наповнення: план та структура спрайтів

**Що зроблено:**

#### Планування Фази 3.5

- **`implementation_plan.md`** — додано секцію `## 4.5. Фаза 3.5 — Візуальне наповнення 🎯 [ПОТОЧНИЙ ФОКУС]` з підзадачами 4.5.1–4.5.7:
  - 4.5.1 Спрайти юнітів у бою (10 год)
  - 4.5.2 Портрети юнітів (6 год)
  - 4.5.3 Іконки предметів (5 год)
  - 4.5.4 Тайли місцевості в бою (6 год)
  - 4.5.5 Глобальна карта — текстури (8 год)
  - 4.5.6 UI polish (5 год)
  - 4.5.7 Порядок реалізації
  - Загальна оцінка: ~40 годин (код ~14 + арт ~26)
- Заголовок плану оновлено: `Поточний фокус: Фаза 3.5 — Візуальне наповнення`

- **`docs/00_MVP_PLAN.md`** — таблиця "ВХОДИТЬ у MVP" розширена рядками 14–18 (спрайти, портрети, іконки, тайли, текстури глобальної карти зі статусом "Немає — Фаза 3.5"). У зведеній таблиці додано рядок `3.5 | Візуальне наповнення | 30-50 | Тиж 39 | Тиж 46`. Фаза 4 (Steam Release) зсунута на Тиж 47+.

#### Структура спрайтів

- **`assets/sprites/units/`** — нова папка, 14 placeholder PNG файлів (валідні 1×1 px, Godot імпортує без помилок):

| Файл | Опис |
|------|------|
| `nychypir_front.png` / `nychypir_back.png` | Козак Ничипір |
| `havrylo_front.png` / `havrylo_back.png` | Козак Гаврило |
| `tymofiy_front.png` / `tymofiy_back.png` | Козак Тимофій |
| `panko_front.png` / `panko_back.png` | Козак Панько |
| `bandit_front.png` / `bandit_back.png` | Бандит |
| `tatar_front.png` / `tatar_back.png` | Татарин |
| `janissary_front.png` / `janissary_back.png` | Яничар |

Конвенція імен: `{unit_id}_{direction}.png`, де `direction` = `front` (юніт дивиться вниз-ліво, типова ізометрична перспектива) або `back` (вгору-право).

**Статус:** завершено — код інтеграції (v3.9) + фінальний арт додано.

**Файли:** `implementation_plan.md`, `docs/00_MVP_PLAN.md`, `assets/sprites/units/` (14 файлів)

---

## Версія 3.7 — 05.06.2026

### Game Over при порожньому загоні ✅

Коли всі козаки дезертирують з голоду, гра тепер показує екран кінця гри замість того, щоб продовжувати рух порожнього загону по карті.

**Що зроблено:**

**`src/ui/WorldMap.gd`:**
- `_apply_hunger_effects()` — після видалення дезертирів і `_refresh_squad_panel()` додано перевірку: якщо `cm.world_state.get("squad", []).is_empty()` → `_show_game_over()` + `return`
- Новий метод `_show_game_over()`:
  - Зупиняє гру: `world_ticking = false`, `_set_parties_ticking(false)`, `_player_party.stop()`
  - Рендерить overlay `ColorRect(0,0,0,0.75)` поверх HUD
  - Будує центровану панель зі стилем діалогу поселення (фон `#0F0E0B`, золота рамка `Color(0.75,0.62,0.22)`)
  - Заголовок (32px, червоний): `tr("GAME_OVER_TITLE")`
  - Текст (15px, золотисто-сірий): `tr("GAME_OVER_DESERT")`
  - Кнопка "Головне меню" (`_make_dialog_btn`) → `change_scene_to_file("res://src/scenes/MainMenu.tscn")`

**`localization/translations.csv`** — додано 4 нові ключі:

| Ключ | uk | en |
|------|----|----|
| `GAME_OVER_TITLE` | Кінець | Game Over |
| `GAME_OVER_DESERT` | Усі козаки дезертирували. Ваш загін розпався. | All cossacks deserted. Your squad has disbanded. |
| `GAME_OVER_DEFEAT` | Усі козаки загинули в бою. | All cossacks fell in battle. |
| `UI_MAIN_MENU` | Головне меню | Main Menu |

**Файли:** `src/ui/WorldMap.gd`, `localization/translations.csv`

---

## Версія 3.6 — 05.06.2026

### Фаза 3 — 4.9: SFX система повністю завершена ✅

Два кроки в одній сесії:

1. **Розширено `AudioManager.SFX` dict** — додано 3 ключі: `"heal"`, `"hire"`, `"notification"` з відповідними шляхами `assets/audio/sfx/*.wav`.

2. **Всі SFX файли наявні** — 9 файлів у `assets/audio/sfx/`, всі імпортовані Godot (`.wav.import`):

| Файл | Ключ |
|------|------|
| `hit_melee.wav` | `"hit_melee"` |
| `hit_ranged.wav` | `"hit_ranged"` |
| `death.wav` | `"death"` |
| `ui_click.wav` | `"ui_click"` |
| `buy.wav` | `"buy"` |
| `level_up.wav` | `"level_up"` |
| `heal.wav` | `"heal"` |
| `hire.wav` | `"hire"` |
| `notification.wav` | `"notification"` |

**Фаза 3 (Локалізація + Аудіо) повністю завершена.**

**Файли:** `src/core/AudioManager.gd`

---

## Версія 3.5 — 05.06.2026

### Фаза 3 — 4.9: SFX виклики підключені до ігрових подій

Додано 10 викликів `AudioManager.play_sfx()` у трьох файлах. Файли `.wav` ще відсутні — AudioManager тихо пропускає (`push_warning`).

| Файл | Метод | Ключ |
|------|-------|------|
| `CombatUnit.gd` | `_perform_attack_logic` (is_hit) | `"hit_melee"` |
| `CombatUnit.gd` | `execute_shoot` (перед await) | `"hit_ranged"` |
| `CombatUnit.gd` | `die()` | `"death"` |
| `CombatUnit.gd` | `gain_xp` (level up) | `"level_up"` |
| `WorldMap.gd` | `_on_trade_buy_provisions` | `"buy"` |
| `WorldMap.gd` | `_on_buy_shop_item` | `"buy"` |
| `WorldMap.gd` | `_on_trade_heal_squad` | `"heal"` |
| `WorldMap.gd` | `_on_hire_recruit` | `"hire"` |
| `WorldMap.gd` | `_show_discovery_notification` | `"notification"` |
| `MainMenu.gd` | btn_new, btn_continue, `_open_settings` | `"ui_click"` |

> Ключі `"heal"`, `"hire"`, `"notification"` не в `AudioManager.SFX` dict — при додаванні файлів потрібно також розширити dict в `AudioManager.gd`.

**Залишилось:** завантажити SFX файли з freesound.org (CC0) та розширити `SFX` dict.

**Файли:** `src/units/CombatUnit.gd`, `src/ui/WorldMap.gd`, `src/ui/MainMenu.gd`

---

## Версія 3.4 — 04.06.2026

### Фаза 3 — 4.8: Музичні треки додані ✅

Андрій записав і додав обидва музичних треки у `assets/audio/music/`. Godot автоматично імпортував файли (`.wav.import`).

| Файл | Статус |
|------|--------|
| `assets/audio/music/map_theme.wav` | ✅ додано, імпортовано |
| `assets/audio/music/battle_theme.wav` | ✅ додано, імпортовано |

Музика тепер грає в грі: карта → `map_theme.wav`, бій → `battle_theme.wav` (crossfade 1.5s через `AudioManager`).

**Залишилось у Фазі 3:** SFX файли + підключення `AudioManager.play_sfx()` у коді.

**Файли:** `assets/audio/music/map_theme.wav`, `assets/audio/music/battle_theme.wav`

---

## Версія 3.3.1 — 04.06.2026

### Формат аудіо: .ogg → .wav

Всі шляхи до аудіо файлів у `AudioManager.gd` змінено з `.ogg` на `.wav` (константи `TRACKS` і `SFX`).

**Файли:** `src/core/AudioManager.gd`

---

## Версія 3.3 — 04.06.2026

### Фаза 3 — 4.8 (AudioManager) + 4.10 (Settings) + bugfix title label

---

#### AudioManager (`src/core/AudioManager.gd`) — новий Autoload ✅

Повна реалізація аудіо-менеджера. Зареєстровано в `project.godot` → `[autoload]`.

**Архітектура:**
- 2× `AudioStreamPlayer` для музики (crossfade між ними)
- 5× `AudioStreamPlayer` SFX-пул (round-robin)
- Audio buses: `"Music"` та `"SFX"` → `"Master"` — створюються динамічно якщо відсутні

**API:**
```gdscript
AudioManager.play_music("map")     # "map" → map_theme.wav, "battle" → battle_theme.wav
AudioManager.stop_music()          # fade out 1.0s
AudioManager.play_sfx("hit_melee") # з SFX-пулу
AudioManager.set_music_volume(0.7) # 0.0–1.0
AudioManager.set_sfx_volume(0.8)
AudioManager.get_music_volume()    # → float
AudioManager.get_sfx_volume()      # → float
```

**Crossfade:** 1.5s між треками (Tween на `volume_db`). При `play_music()` з тим самим ключем — ігнорується.

**Гучність:** зберігається в `user://settings.cfg` (секція `[audio]`), завантажується в `_ready()`.

**TRACKS / SFX dictionaries:**
```gdscript
TRACKS = { "map": "res://assets/audio/music/map_theme.wav",
           "battle": "res://assets/audio/music/battle_theme.wav" }
SFX    = { "hit_melee", "hit_ranged", "death", "ui_click", "buy", "level_up" }
```
Файли `.wav` ще не існують — Андрій записує в Ableton. Відсутній файл → `push_warning`, гра не падає.

**Інтеграція (play_music):**

| Файл | Де | Трек |
|------|----|------|
| `MainMenu.gd:33` | `_ready()` | `"map"` |
| `WorldMap.gd:121` | `_ready()` | `"map"` |
| `BattleManager.gd:43` | `_ready()` | `"battle"` |

---

#### Settings overlay (`MainMenu.gd`) — задача 4.10 ✅

Модальна панель налаштувань, відкривається кнопкою "Налаштування" у головному меню.

**UI-структура:**
```
[Налаштування]
───────────────────────────────
Мова:     [Українська ▼]
───────────────────────────────
Музика 70%
[━━━━━━━━━━●──────────────────]
Звуки 80%
[━━━━━━━━━━━━━━━●──────────────]
───────────────────────────────
           [Закрити]
```

**Технічні деталі:**
- Димер (ColorRect `Color(0,0,0,0.65)`) + клік поза панеллю закриває
- HSlider 0–100% зі стилем у кольорах гри (золотий трек/grabber через `_style_slider()`)
- `_style_slider()` + `_make_circle_texture()` — кастомний grabber (коло через `Image.create`)
- `_update_settings_texts()` — всі тексти оновлюються при зміні мови
- Мовний dropdown перенесено з основного меню в Settings
- При відкритті: зчитує поточні значення з `AudioManager.get_*_volume()`

**Нові instance vars MainMenu:**  
`_btn_settings`, `_settings_overlay`, `_settings_music_slider`, `_settings_sfx_slider`, `_settings_music_label`, `_settings_sfx_label`, `_settings_title_label`, `_settings_close_btn`, `_settings_lang_opt`

---

#### Bugfix: назва гри не оновлювалась при зміні мови (`MainMenu.gd`)

`_update_button_texts()` оновлював кнопки, але не заголовок "КОЗАЦЬКА ВАРТА".

```gdscript
var _title_label: Label          # новий instance var
# в _add_left_content():
_title_label = title             # зберігаємо посилання
# в _update_button_texts():
if _title_label: _title_label.text = tr("GAME_TITLE").replace(" ", "\n")
```

---

#### CSV: +4 ключі (тепер ~361 рядків)

| Ключ | uk | en |
|------|----|----|
| `UI_SETTINGS` | Налаштування | Settings |
| `UI_CLOSE` | Закрити | Close |
| `UI_MUSIC_VOLUME` | Музика | Music |
| `UI_SFX_VOLUME` | Звуки | Sounds |

**Файли:** `src/core/AudioManager.gd` (новий), `src/ui/MainMenu.gd`, `src/tactical/BattleManager.gd`, `src/ui/WorldMap.gd`, `localization/translations.csv`, `project.godot`

---

## Версія 3.2 — 04.06.2026

### Фаза 3 — 4.7 (повторний прохід): Повний grep-аудит непереведених рядків ✅

**Grep-аудит по всіх `.gd` файлах виявив і виправив рядки, пропущені в 4.7 (v3.1).**  
**+78 нових ключів у CSV (357 рядків загалом). Grep по кирилиці без `tr()` повертає 0 UI-рядків.**

**Що виправлено:**

| Файл | Що знайдено і виправлено |
|------|--------------------------|
| `src/tactical/TacticalGrid.gd` | `"ОД"` → `tr("UI_AP_SHORT")` у підказці вартості шляху |
| `src/ui/WorldMap.gd` | `"☀️ День/🌅 Захід/🌙 Ніч/🌅 Схід"` → `tr("TIME_*")`; `"Рівень"` → `tr("STAT_LEVEL")`; `"Стати невідомі"` → `tr("UI_STATS_UNKNOWN")`; 3 стат-рядки панелі → `tr("STAT_*_SHORT/FORMAT")`; `"Козака не обрано"` → `tr("UI_NO_UNIT_SELECTED")`; назви в крамниці/інвентарі → `tr(item_name)`; `"Продаж лише в поселеннях"` → `tr("UI_SELL_SETTLEMENT")`; `"Зустріч"` → `tr("UI_ENCOUNTER")`; `"М:%d%%"` → `tr("STAT_MORALE_SHORT")` |
| `src/ui/UnitPanel.gd` | Назви зброї legacy (Шабля/Мушкет/Спис/Бердиш) → `tr("WEAPON_TYPE_*")`; `"Мертвий"` → `tr("UI_DEAD")`; `"Зброя: %s"` → `tr("SLOT_WEAPON") + ": %s"`; `"⚔️ Стійка: КОНТРУДАР"` → `tr("UI_RIPOSTE_STANCE")`; `"🎯 Шанс влучити:"` → `tr("UI_HIT_CHANCE")`; `"⚠️ РИЗИК ДРУЖНЬОГО ВОГНЮ!"` → `tr("UI_FRIENDLY_FIRE")`; terrain info рядки → `tr("TERRAIN_*_INFO")`; `"Чекати"` in check → `tr("UI_WAIT")` (bugfix: English mode) |
| `src/ui/BattleResultScreen.gd` | `"ПЕРЕМОГА/ПОРАЗКА"` → `tr("RESULT_VICTORY/DEFEAT")`; кнопки → `tr("RESULT_BTN_*")`; секція луту → `tr("RESULT_LOOT/NOTHING")`; підписи статів, травми, рівень, талери — всі через `tr()` |
| `src/ui/CharacterSheet.gd` | Назви legacy-зброї → `tr()`; slot tooltips (Шолом/Набої/Броня тіла/Пояс/Амулет) → `tr("CS_SLOT_*_TOOLTIP")`; `_get_weapon_resource_tooltip()` (Шкода/Пробиття/Тип) → `tr("WEAPON_STAT_*")`; `_get_weapon_tooltip()` нотатки (кровотеча/перезарядка/радіус/площа) → `tr("WEAPON_NOTE_*")` |
| `src/tactical/BattleManager.gd` | `"[Підказка]"` → `tr("BATTLE_HINT_LABEL")`; кінець раунду → `tr("BATTLE_ROUND_END")`; `"Ворог"` fallback → `tr("BATTLE_ENEMY_FALLBACK")` |
| `src/units/CombatUnit.gd` | `"🌟 РІВЕНЬ %d!"` → `tr("BATTLE_LEVEL_UP_FX")`; паніка від втечі/смерті → `tr("BATTLE_PANIC_*")`; дружній вогонь у лог → `tr("BATTLE_FRIENDLY_FIRE_HIT")` |
| `src/tactical/CameraController.gd` | `"Зум: x%s"` → `tr("UI_ZOOM_FORMAT")` |
| `src/ui/LoadingScreen.gd` | `"Завантаження битви..."` → `tr("LOADING_BATTLE")` |

**Нові групи ключів CSV (+78):**

| Група | Ключі |
|-------|-------|
| UI панелі | `UI_AP_SHORT`, `UI_DEAD`, `UI_NO_UNIT_SELECTED`, `UI_STATS_UNKNOWN`, `UI_SELL_SETTLEMENT`, `UI_ENCOUNTER`, `UI_ZOOM_FORMAT`, `UI_THALERS_FORMAT`, `UI_ITEM_FALLBACK` |
| Фази доби | `TIME_DAY/DUSK/NIGHT/DAWN` |
| Стати (скорочені) | `STAT_MELEE_SHORT`, `STAT_DEFENSE_MELEE_SHORT`, `STAT_ARMOR_HELMET_FORMAT`, `STAT_MORALE_SHORT` |
| Бойовий UI | `UI_RIPOSTE_STANCE`, `UI_HIT_CHANCE`, `UI_FRIENDLY_FIRE` |
| Terrain tooltips | `TERRAIN_BUSHES/SWAMP/WATER/ROCKS/TREES_INFO` (повний опис з витратами) |
| Зброя | `WEAPON_TYPE_SWORD/MUSKET/HEAVY`, `WEAPON_TYPE_ONE/TWO_HAND`, `WEAPON_GENERIC_DESC`, `WEAPON_STAT_DAMAGE/PEN/TYPE`, `WEAPON_NOTE_BLEED/RELOAD_NEEDED/RANGE2/ARC` |
| CharacterSheet слоти | `CS_SLOT_TRINKET/HELMET/AMMO/ARMOR/BELT_TOOLTIP` |
| Екран результатів | `RESULT_VICTORY/DEFEAT`, `RESULT_LOOT/NOTHING`, `RESULT_DEFEAT_NO_LOOT`, `RESULT_NO_TROPHIES`, `RESULT_KILLED`, `RESULT_DMG_DEALT/TAKEN`, `RESULT_LEVEL_UP`, `RESULT_INJURY_PERMANENT/TEMPORARY`, `RESULT_BTN_MAIN_MENU/RETRY/CONTINUE` |
| Бойові повідомлення | `BATTLE_HINT_LABEL`, `BATTLE_ROUND_END`, `BATTLE_ENEMY_FALLBACK`, `BATTLE_FRIENDLY_FIRE_HIT`, `BATTLE_LEVEL_UP_FX`, `BATTLE_PANIC_FLEE/DEATH` |
| Завантаження | `LOADING_BATTLE` |
| Травми (uk-ключ) | Порізана рука, Забиті ребра, Струс мозку, Перелом ребра, Рана в ногу, Глибокий поріз |
| Предмети (uk-ключ) | Козацька шабля, Піка (2H), Стьобаний жупан, Шкіряний панцир, Звичайна шапка, Хутряна кучма |

**Що не чіпалось (навмисно):**
- Debug `print()` / `push_error()` / `push_warning()` — не UI
- Список імен рекрутів — дані, вже в CSV, `tr()` при відображенні
- WFCGenerator.LOCATION_NAMES — рядки вже використовуються як `tr()`-ключі в TacticalGrid
- `UnitData.gd` `unit_name = "Новобранець"` — дефолт поля ресурсу, одразу перекривається .tres

**Файли:** `localization/translations.csv` (+78 ключів), 9 `.gd` файлів

---

## Версія 3.1 — 04.06.2026

### Фаза 3 — 4.7: Фіналізація локалізації — залишкові непереведені тексти ✅

**~130 нових ключів у CSV (~275 рядків загалом). Всі видимі тексти гри тепер перекладаються.**

**Що зроблено:**

- **`src/ui/MainMenu.gd`** — `tr("GAME_TITLE").replace(" ", "\n")` замінює хардкоджений заголовок "КОЗАЦЬКА\nВАРТА"
- **`src/ui/UnitPanel.gd`** — `tr(weapon.name)`, `tr(skill.name)`, `tr(raw_desc)` для навичок; `DAMAGE_SLASH/PIERCE/BLUNT/FIRE/RANGED` для типів шкоди; `SKILL_TOOLTIP_TYPE/HIT/HEAD_BONUS/GUARANTEED_HEAD` для tooltip-форматів
- **`src/ui/CharacterSheet.gd`** — `tr(origin_name)`, `tr(origin_bonus)`, `tr("ORIGIN_UNKNOWN")` у `_build_origin()`
- **`src/ui/WorldMap.gd`** — discovery: `tr("MAP_DISCOVERED") % loc_name_str`; імена рекрутів: `tr(pool[i])`
- **`src/ui/TurnQueueUI.gd`** — `tr("BATTLE_ROUND") % round_num` замінює "РАУНД %d"
- **`src/tactical/TacticalGrid.gd`** — `tr("MAP_OPEN_FIELD")` для туторіалу; `tr(WFCGenerator.LOCATION_NAMES[loc_type])` для WFC-локацій
- **`src/tactical/BattleManager.gd`** — `btn.text = "🏁 " + tr("UI_END_TURN")` у `_style_end_turn_button()`
- **`src/core/WorldGenerator.gd`** — `tr()` для 12 власних назв міст (Чигирин→Chyhyryn тощо) + 3 назви біомів (Ліси/Дике Поле/Кордон)
- **`src/core/CampaignManager.gd`** — `tr(data.unit_name)` для стартових козаків

**Нові групи ключів CSV:**

| Група | К-сть | Приклади |
|-------|-------|---------|
| Назва гри | 1 | `GAME_TITLE` |
| Карта | 3 | `MAP_OPEN_FIELD`, `MAP_DISCOVERED`, `ORIGIN_UNKNOWN` |
| Типи шкоди | 5 | `DAMAGE_SLASH/PIERCE/BLUNT/FIRE/RANGED` |
| Tooltip-формати | 4 | `SKILL_TOOLTIP_TYPE/HIT/HEAD_BONUS/GUARANTEED_HEAD` |
| Назви зброї | 13 | Козацька Шабля, Мушкет «Яничарка»… |
| Назви навичок | 22 | Удар шаблею, Відповідь, Відпочинок… |
| Описи навичок | 22 | "Швидкий рубаючий удар." тощо |
| Origin-назви | 9 | Бурсак-утікач, Козак-піхотинець… |
| Origin-бонуси | 10 | "+10 Мораль, +5 Ініціатива" тощо |
| WFC-локації | 4 | Степ, Ліс, Болото, Річка |
| Біоми | 3 | Ліси, Дике Поле, Кордон |
| Власні назви міст | 12 | Чигирин→Chyhyryn, Київ→Kyiv… |
| Імена козаків | 4 | Ничипір→Nychypir тощо |
| Імена рекрутів | 25 | Іван→Ivan, Тарас→Taras… |

**Файли:** `localization/translations.csv` (+130 ключів), 9 `.gd` файлів

---

## Версія 3.0 — 04.06.2026

### Фаза 3 — 4.5 + 4.6: Перемикач мови + Kelly Slab як глобальний шрифт ✅

**Що зроблено:**

- **`project.godot`** — додано секцію `[gui]`:
  - `theme/default_font = "res://assets/fonts/KellySlab-Regular.ttf"`
  - `theme/default_font_size = 16`
  - Kelly Slab тепер підхоплюється всіма Label, Button, RichTextLabel без явного override
- **`src/ui/MainMenu.gd`** — OptionButton для вибору мови:
  - Розміщено між кнопкою "Вийти" і нижнім flex-spacer'ом
  - Стиль: bg `Color(0.12,0.11,0.08)`, border `Color(0.48,0.38,0.13)`, текст `Color(0.85,0.8,0.6)`, 15px
  - При зміні → `LocaleManager.set_language()` + `_update_button_texts()` оновлює тексти кнопок
  - При `_ready()` → зчитує поточну мову з `LocaleManager.get_language()`
  - Instance vars `_btn_new/_btn_continue/_btn_quit` для live-оновлення текстів
- **`localization/translations.csv`** — додано ключ `UI_LANGUAGE` (uk: Мова / en: Language)
- **Видалено зайві font overrides** (Kelly Slab тепер глобальний):
  - `src/tactical/BattleManager.gd` — tutorial label (3 рядки видалено)
  - `src/tactical/TacticalGrid.gd` — path cost label (3 рядки + `font_path` видалено)
  - `src/ui/LoadingScreen.gd` — loading label + константа `FONT_PATH` видалено

**Файли:** `project.godot`, `localization/translations.csv`, `src/ui/MainMenu.gd`, `src/tactical/BattleManager.gd`, `src/tactical/TacticalGrid.gd`, `src/ui/LoadingScreen.gd`

---

## Версія 2.9 — 04.06.2026

### Фаза 3 — 4.4: Локалізація назв локацій ✅

**Типові назви локацій і мітки фракцій/очищених місць замінено на `tr()`.**

**Що зроблено:**

- **`WorldGenerator.gd`** — 13 хардкоджених типових назв у масиві `templates` замінено на `tr()`:
  - Ліс: `LOC_TYPE_BANDIT_CAMP`, `LOC_ABANDONED_RUINS`, `LOC_ABANDONED_APIARY`, `LOC_BANDIT_CAVE`
  - Степ: `LOC_TYPE_TATAR_CAMP`, `LOC_MURZA_CAMP`, `LOC_SCYTHIAN_TOMB`, `LOC_COSSACK_CEMETERY`, `LOC_TATAR_PATROL`
  - Кордон: `LOC_TYPE_CROWN_OUTPOST`, `LOC_FORTRESS`, `LOC_RUINED_CHURCH`, `LOC_PAGAN_RAVINE`
  - Власні назви (Чигирин, Київ, Бахчисарай тощо) — без змін
- **`WorldMap.gd`** — `_cleared_desc()` і `_faction_label()` повністю через `tr()`:
  - 5 типів `CLEARED_*` + fallback `MAP_LOCATION_CLEARED`
  - 4 мітки фракцій: `FACTION_ORDA_PLURAL`, `FACTION_CROWN_PLURAL`, `FACTION_SICH_PLURAL`, `FACTION_BANDITS`

**Нові ключі в `localization/translations.csv`** (20 шт., всього ~143 ключі):

| Ключ | uk | en |
|------|----|----|
| `LOC_ABANDONED_RUINS` | Занедбані руїни | Abandoned Ruins |
| `LOC_ABANDONED_APIARY` | Покинута пасіка | Abandoned Apiary |
| `LOC_BANDIT_CAVE` | Печера розбійників | Bandit Cave |
| `LOC_MURZA_CAMP` | Ставка мурзи | Murza's Camp |
| `LOC_SCYTHIAN_TOMB` | Скіфська могила | Scythian Tomb |
| `LOC_COSSACK_CEMETERY` | Козацький цвинтар | Cossack Cemetery |
| `LOC_TATAR_PATROL` | Татарський дозор | Tatar Patrol |
| `LOC_FORTRESS` | Фортеця | Fortress |
| `LOC_RUINED_CHURCH` | Зруйнований костел | Ruined Church |
| `LOC_PAGAN_RAVINE` | Яр язичників | Pagan Ravine |
| `CLEARED_BANDIT_CAMP` | Табір розбійників розгромлено… | Bandit camp destroyed… |
| `CLEARED_TATAR_CAMP` | Татарський кіш знищено… | Tatar camp destroyed… |
| `CLEARED_RUINS` | Руїни обшукано… | Ruins searched… |
| `CLEARED_CROWN_OUTPOST` | Застава була взята штурмом… | Outpost stormed… |
| `CLEARED_FORTRESS` | Фортецю підкорено… | Fortress conquered… |
| `FACTION_ORDA_PLURAL` | Татари | Tatars |
| `FACTION_CROWN_PLURAL` | Реєстрові | Registered |
| `FACTION_SICH_PLURAL` | Запорожці | Zaporozhians |
| `FACTION_BANDITS` | Бандити | Bandits |

**Файли:** `localization/translations.csv`, `src/core/WorldGenerator.gd`, `src/ui/WorldMap.gd`

---

## Версія 2.8 — 04.06.2026

### Фаза 3 — 4.3: Витягнути тексти — глобальна карта + меню ✅

**Замінено всі хардкоджені українські рядки у WorldMap.gd, EncounterDialog.gd, MainMenu.gd на `tr("KEY")`.**

**Що зроблено:**

- **`WorldMap.gd`** (30+ замін):
  - TopBar: `UI_DAY`, `FACTION_CROWN/SICH/ORDA`, `UI_PAUSE`.to_upper(), `UI_INVENTORY` tooltip
  - Speed panel tooltips: `UI_PAUSE/SPEED_NORMAL/SPEED_FAST` + збереження `[color=gray][Key][/color]`
  - Refresh squad panel: `UI_SQUAD`
  - Діалог поселення: `MAP_SETTLEMENT_OPEN`, `MAP_TRADE`, `MAP_PROVISIONS`, `MAP_HEALING` + `MAP_INJURED`/`MAP_ALL_HEALTHY`, `MAP_SHOP`, `MAP_HIRING`, `UI_ATTACK`, `UI_LEAVE`
  - `_cleared_desc()`: `MAP_LOCATION_CLEARED` (fallback)
  - Hunger: `MAP_DESERTED`
  - Inventory panel sections: `UI_SQUAD/EQUIPMENT/INVENTORY` + `.to_upper()` для збереження стилю
  - Grid slots: `SLOT_TRINKET/AMMO/WEAPON/SHIELD/BELT`, `STAT_HELMET/ARMOR`
  - Item type dictionaries: `SLOT_WEAPON/STAT_ARMOR/STAT_HELMET` + `.to_lower()` для lowercase відображення
  - `UI_INVENTORY_EMPTY`, `UI_EQUIP` tooltip
  - Onboarding hints: `HINT_MOVE/ENEMY/SETTLEMENT/WOUNDED/LOW_FOOD` (BBCode `[color=...]` залишено навколо)
- **`EncounterDialog.gd`** (1 зміна): `ENCOUNTER_REWARD` — "Здобич: ~%d талерів"
- **`MainMenu.gd`** (3 зміни): `UI_NEW_GAME`, `UI_CONTINUE`, `UI_EXIT`

**Нові ключі в `localization/translations.csv`** (2 шт., всього 123 ключі):
| Ключ | uk | en |
|------|----|----|
| `SLOT_WEAPON` | Зброя | Weapon |
| `ENCOUNTER_REWARD` | Здобич: ~%d талерів | Loot: ~%d thalers |

**Файли:** `localization/translations.csv`, `src/ui/WorldMap.gd`, `src/ui/EncounterDialog.gd`, `src/ui/MainMenu.gd`

---

## Версія 2.7 — 04.06.2026

### Фаза 3 — 4.2: Витягнути тексти — бойова система ✅

**Замінено всі хардкоджені українські рядки в бойовій системі на `tr("KEY")`.**

**Що зроблено:**

- **`BattleManager.gd`** (11 замін): `BATTLE_STARTED`, `BATTLE_VICTORY`, `BATTLE_DEFEAT`, `BATTLE_ROUND`, `BATTLE_UNIT_TURN` з підстановкою `TEAM_COSSACK`/`TEAM_ENEMY`; combat hints → `COMBAT_HINT_FIRST/STAMINA/MORALE`; tutorial steps → `TUTORIAL_STEP1–5`; кнопка "Пропустити" → `UI_SKIP_TUTORIAL`
- **`CombatUnit.gd`** (16 замін): `get_morale_string()` → `MORALE_CONFIDENT/STEADY/WAVERING/BREAKING/FLEEING`; всі `spawn_text_fx` → `BATTLE_RECOVER/RIPOSTE/LOADED/SHOT/RALLY/INTERCEPT/FLEE/RETREAT/RETREAT_TACTICAL`; логи атак/промахів через `BATTLE_HIT`/`BATTLE_MISS` (масив-форматування `% [a, b, c]`); смерть → `BATTLE_DEATH`; `show_miss_fx` → `BATTLE_MISS_SHORT`; підказки ZoC/reload → `COMBAT_HINT_ZOC/RELOAD`
- **`UnitPanel.gd`** (9 замін): бари `STAT_HP/AP/STAMINA/ARMOR/HELMET`; заголовок секції → `UI_SKILLS`; кнопка "Чекати" → `UI_WAIT`; tooltip → `UI_WAIT_TOOLTIP`; **`_style_morale_label()`** виправлено: тепер перевіряє `tr("MORALE_*") in m_str` замість hardcoded Ukrainian рядків — інакше English mode ламав кольори мінімального індикатора
- **`CharacterSheet.gd`** (10 замін): `STAT_LEVEL`; слоти → `SLOT_TRINKET/AMMO/SHIELD/BELT` та `STAT_HELMET/ARMOR`; `STAT_MORALE`; 6 барів статів → `STAT_AP/HELMET/ARMOR/HP/STAMINA`; 6 бойових рядків → `STAT_MELEE/RANGED/DEFENSE_MELEE/DEFENSE_RANGED/INITIATIVE/RESOLVE`

**Нові ключі в `localization/translations.csv`** (11 шт., тепер 121 ключ):
| Ключ | uk | en |
|------|----|----|
| `UI_SKILLS` | Навички | Skills |
| `UI_WAIT_TOOLTIP` | Пропустити хід походити пізніше. | Skip turn act later. |
| `BATTLE_MISS_SHORT` | ПРОМАХ | MISS |
| `BATTLE_HEADSHOT` | ГОЛОВА! | HEADSHOT! |
| `BATTLE_RETREAT_TACTICAL` | ВІДХІД | RETREAT |
| `SLOT_TRINKET` | Прикраса | Trinket |
| `SLOT_AMMO` | Набої | Ammo |
| `SLOT_SHIELD` | Щит | Shield |
| `SLOT_BELT` | Пояс | Belt |
| `STAT_MORALE` | Мораль | Morale |

**Не торкалось:** `WorldMap.gd` (наступний промпт 4.3), hover intel panel (`_update_intel_text`), debug `print()`, внутрішні назви вузлів (fallback `"Ворог"` в `_apply_enemy_config`).

**Файли:** `localization/translations.csv`, `src/tactical/BattleManager.gd`, `src/units/CombatUnit.gd`, `src/ui/UnitPanel.gd`, `src/ui/CharacterSheet.gd`

---

## Версія 2.6 — 03.06.2026

### Фаза 3 — 4.1: Система локалізації (інфраструктура) ✅

**Реалізовано інфраструктуру локалізації** — CSV з ключами перекладу, Autoload `LocaleManager`, реєстрація в `project.godot`.

**Що зроблено:**

- **`res://localization/translations.csv`** — 110 ключів для uk/en: UI (`UI_*`), бій (`BATTLE_*`), карта (`MAP_*`), стати (`STAT_*`), фракції (`FACTION_*`), підказки (`HINT_*`), tutorial (`TUTORIAL_*`), бойові підказки (`COMBAT_HINT_*`), terrain (`TERRAIN_*`), типи локацій (`LOC_TYPE_*`), вороги (`ENEMY_*`), мораль (`MORALE_*`)
- **`src/core/LocaleManager.gd`** — Autoload: `set_language(locale)`, `get_language()`, збереження/відновлення через `user://settings.cfg`, дефолт `uk`
- **`project.godot`** — `LocaleManager` додано в `[autoload]`; секція `[internationalization]` з посиланнями на скомпільовані `.translation` файли (`translations.uk.translation`, `translations.en.translation`)
- **Godot-імпорт** — CSV вже проімпортований редактором; `.translation` бінарники лежать поруч з CSV в `localization/`

**Технічна деталь:** `project.godot` реєструє `.translation` файли (не сам CSV) — це правильний спосіб для Godot 4, оскільки `TranslationServer` завантажує скомпільовані бінарники.

**Файли:** `localization/translations.csv`, `src/core/LocaleManager.gd`, `project.godot`

---

## Версія 2.5 — 03.06.2026

### Фаза 3 — Локалізація + Аудіо: деталізація плану

**Фаза 2 (Onboarding + Polish) повністю завершена.** Усі 6 підзадач (3.1–3.6) реалізовані та задокументовані у версіях 1.9–2.4.

**Фаза 3 стає поточним фокусом.** Деталізований план додано до `implementation_plan.md` (секція 4.1–4.10). Оновлено `LOCALIZATION_PLAN.md` та `AUDIO_DESIGN.md`.

**Що заплановано:**

| Підзадача | Опис | Оцінка |
|-----------|------|--------|
| 4.1 | Система локалізації: `translations.csv` + `LocaleManager` autoload | 1 год |
| 4.2 | Витягнути тексти — бойова система | 4 год |
| 4.3 | Витягнути тексти — глобальна карта | 3 год |
| 4.4 | Назви локацій та типів ворогів | 1 год |
| 4.5 | Перемикач мови в UI | 1 год |
| 4.6 | Шрифти (кирилиця + латиниця) | 0.5 год |
| 4.7 | Фонові треки (map + battle) | 2 год коду |
| 4.8 | SFX (10–15 ефектів) | 5 год |
| 4.9 | Меню налаштувань (гучність + мова) | 2 год |

**Загальна оцінка:** ~19.5 годин коду + окремо — створення аудіо контенту (Андрій планує треки в Ableton).

**Файли:** `implementation_plan.md`, `docs/07_TECHNICAL/LOCALIZATION_PLAN.md`, `docs/06_UI_AND_AUDIO/AUDIO_DESIGN.md`, `docs/00_MVP_PLAN.md`

---

## Версія 2.4 — 03.06.2026

### Виправлення зникнення кнопки "Чекати" — UnitPanel

**Баг:** у деяких козаків кнопка "Чекати" не з'являлася. Кнопка береться з `_button_pool` (пул перевикористовуваних Button-вузлів) і могла прийти зі станом від попереднього використання як скілова кнопка.

**Три причини:**

1. **`toggle_mode` не скидався.** Скілові кнопки до v2.3 мали `toggle_mode = true`. Після потрапляння в пул і перевикористання як кнопка "Чекати" `toggle_mode` залишався `true`, що спотворювало логіку кліку.
2. **`disabled` не скидався.** Якщо попередній юніт мав замало AP/stamina для скіла, кнопка залишалась з `disabled = true` — "Чекати" рендерилась затемненою або повністю не реагувала.
3. **Дочірні вузли очищались через `queue_free()` без `remove_child()`.** Старий VBox (NameLabel/APLabel) залишався дочірнім вузлом кнопки до кінця кадру і міг перекривати текст "🕒 Чекати".

**Фіксація в `src/ui/UnitPanel.gd`, `_rebuild_skill_bar()`:**

```gdscript
var wait_btn = _get_button_from_pool()
wait_btn.toggle_mode = false      # скидаємо toggle-режим з попереднього використання
wait_btn.button_pressed = false   # скидаємо pressed-стан
wait_btn.disabled = false         # скидаємо disabled-стан
for child in wait_btn.get_children():
    wait_btn.remove_child(child)  # remove_child — негайно (не defer)
    child.queue_free()
```

Попередньо дочірні вузли видалялись тільки через `child.queue_free()` без `remove_child()`.

---

## Версія 2.3 — 03.06.2026

### Виправлення розсинхронізації кнопок навичок — UnitPanel

**Баг:** кнопки навичок мали `toggle_mode = true`, тобто Godot зберігав власний внутрішній стан `button_pressed`. При скасуванні навички через ПКМ `BattleManager.current_skill_id` скидався у `""`, але `button_pressed` залишався `true` — кнопка виглядала активною при неактивній навичці. Повторний клік перемикав `button_pressed` у `false` — навичка ставала активною, але кнопка виглядала вимкненою.

**Фіксація в `src/ui/UnitPanel.gd`:**

- `_create_skill_button()`: `toggle_mode = false`, видалено `btn.button_pressed = is_active`. Візуальний стан відтепер контролюється виключно через `style_button(btn, is_active)` на основі `BattleManager.current_skill_id`.
- `_refresh_active_panel()` — кеш: додано поле `"current_skill": bm_node.current_skill_id if bm_node else ""`. Завдяки цьому хеш `_last_active_data` змінюється при кожній зміні `current_skill_id`, в тому числі при скасуванні через ПКМ.
- `_refresh_active_panel()` — цикл оновлення кнопок: видалено `btn.button_pressed = is_active`, `bm_node` береться з вже отриманого вище рефа замість повторного `get_node_or_null`.

**Незачеплені файли:** `BattleManager.gd`, `TacticalGrid.gd`, `CombatUnit.gd`.

---

## Версія 2.2 — 03.06.2026

### Tutorial-бій — Фаза 2, задача 3.2

Перший запуск нової гри відкриває tutorial-бій (4 козаки проти 2 бандитів) замість переходу на WorldMap. Старі збереження пропускають tutorial автоматично.

**Нові поля:**
- `world_state["tutorial_done"]: bool` — `false` для нових ігор, `true` після tutorial або для старих збережень (міграція)
- `active_battle_config["is_tutorial"]: bool`, `active_battle_config["source_type"]: "tutorial"`

**Зміни у `CampaignManager.gd`:**
- `new_campaign()` — якщо `tutorial_done == false` → `start_battle()` з tutorial-конфігом (2 бандити, 50 тал.), інакше → WorldMap
- `finish_battle()` — гілка `source_type == "tutorial"`: `tutorial_done = true`, не позначає локації/загони cleared/dead

**Зміни у `SaveManager.gd`:**
- `_migrate()` — додає `tutorial_done = true` для збережень без цього поля (v3 сейви до 2.2)

**Зміни у `TacticalGrid.gd`:**
- `_ready()` — якщо `is_tutorial`: `terrain_map` заповнюється тільки `CLEAR` (без WFCGenerator). Локація: "Відкрите поле"

**Зміни у `BattleManager.gd`:**
- Нові змінні: `_is_tutorial: bool`, `_tutorial_step: int`, `_tutorial_panel: Control`, `_tutorial_label: Label`, `_skip_btn: Button`, `_tutorial_enemy_hp_snapshot: int`
- `_build_tutorial_panel()` — `Control` + `ColorRect` + `Label` + `Button "Пропустити"`. Ручне позиціювання через `_reposition_tutorial_panel()`, підключено до `size_changed`
- `_reposition_tutorial_panel()` — панель 45% ширини viewport, `y = vp.y - unit_panel.size.y - panel_h - 30`
- `_show_tutorial_step(text)` / `_hide_tutorial_panel()` — fade-in/out 0.3 сек через `create_tween()`
- `_get_total_enemy_hp()` — порівняння HP ворогів до/після дії для детекції атаки
- `_maybe_combat_hint()` — повертає `false` під час tutorial (без дублювання підказок у CombatLog)

**5 кроків tutorial (тригери → текст):**

| Крок | Де спрацьовує | Текст |
|------|--------------|-------|
| 1 | `start_next_unit_turn`, team 0, step 0 | "Це ваш загін. Оберіть навичку атаки на панелі знизу." |
| 2 | `_on_skill_selected`, skill вибрано, step 1 | "Тепер клікніть на ворога в зоні дії, щоб атакувати." |
| 3 | `_on_unit_move_finished`, enemy HP знизився, step 2 | "Влучили! Залишились очки дій — можна рухатись або атакувати знову." |
| 4 | `start_next_unit_turn`, team 1, step 3 | "Тепер ходить ворог. Спостерігайте." |
| 5 | `start_next_unit_turn`, team 0, step 4 | "Ваш хід! Рухайтесь клікнувши на жовту клітинку, атакуйте ворогів." |

Крок 3 ховається при `end_unit_turn` (team 0). Крок 5 ховається при наступній `_on_unit_move_finished` або `end_unit_turn`.

**Файли:** `src/core/CampaignManager.gd`, `src/core/SaveManager.gd`, `src/tactical/BattleManager.gd`, `src/tactical/TacticalGrid.gd`

---

## Версія 2.1 — 03.06.2026

### Геймплейні підказки в CombatLog — Фаза 2, задача 3.4

Підказки з'являються в бойовому лозі один раз за бій, жовтим кольором з тегом `[Підказка]`. Дедублікація через `_combat_hints_shown: Dictionary` (скидається автоматично при новому бою — свіжий екземпляр `BattleManager`). В `start_next_unit_turn()` не більше однієї підказки за хід: послідовний ланцюг `if not _hint`.

**Нові змінні і методи** в `BattleManager.gd`:
- `_combat_hints_shown: Dictionary` — ключі показаних підказок
- `_maybe_combat_hint(key, text) -> bool` — логує `[color=yellow][Підказка][/color] text`, повертає `true` якщо показано вперше

**5 підказок:**

| Ключ | Де викликається | Умова | Текст |
|------|----------------|-------|-------|
| `first_turn` | `BattleManager.start_next_unit_turn()` | перший хід будь-якого козака за бій | "Клікніть на ворога в зоні атаки, щоб вдарити. ПКМ скасовує навичку." |
| `low_stamina` | `BattleManager.start_next_unit_turn()` | `stamina < max_stamina * 0.3`, team 0 | "Витривалість низька — використайте Відпочинок для відновлення." |
| `low_morale` | `BattleManager.start_next_unit_turn()` | `current_morale >= WAVERING`, team 0 | "Мораль падає! Згуртування (Rally) може допомогти." |
| `zoc` | `CombatUnit.move_along_path()` | team 0 виходить із ZoC (перед opportunity attack) | "Вихід із зони контролю ворога дає йому безкоштовну атаку." |
| `reload` | `CombatUnit.execute_shoot()` | team 0, одразу після `is_loaded = false` | "Після пострілу мушкет треба перезарядити." |

**Файли:** `src/tactical/BattleManager.gd`, `src/units/CombatUnit.gd`

---

## Версія 2.0 — 03.06.2026

### Onboarding-підказки на глобальній карті — Фаза 2, задача 3.3

Persistent onboarding-панель: підказка залишається на екрані поки гравець не виконає умову.

**Нові змінні** в `WorldMap.gd`:
- `_onboarding_panel: PanelContainer` — панель знизу по центру (`anchor_bottom`, `offset_bottom = -80`)
- `_onboarding_label: RichTextLabel` — bbcode-текст всередині
- `_onboarding_shown: Dictionary` — флаги показаних підказок (не зберігаються в `world_state`)
- `_current_hint_key: String` — ключ поточної видимої підказки

**Нові методи**:
- `_build_onboarding_panel()` — будує панель, викликається з `_build_hud()`
- `_show_onboarding_hint(key, bbcode_text)` — показує підказку з fade-in 0.3 сек; якщо вже показана — return; замінює попередню
- `_dismiss_onboarding_hint(key)` — ховає підказку з fade-out 0.5 сек; ігнорує якщо key не збігається з поточним

**5 підказок і точки dismiss**:

| Ключ | Показується | Зникає при |
|------|------------|------------|
| `move` | `_ready()` день 1, затримка 1 сек | `_on_player_movement_started()` |
| `enemy` | `_on_party_encounter()` | `_hide_encounter_dialog()` |
| `settlement` | `_show_location_dialog()` | `_on_trade_buy_provisions()`, `_on_trade_heal_squad()`, `_on_buy_shop_item()`, `_on_hire_recruit()` |
| `wounded` | `_ready()` якщо `hp * 2 < max_hp` | `_on_trade_heal_squad()` |
| `low_food` | `_process()` якщо `provisions <= 2 > 0`, діалог закритий | `_on_trade_buy_provisions()` |

**Стиль панелі:** фон `Color(0.07, 0.065, 0.055, 0.92)`, рамка `Color(0.48, 0.38, 0.13)` 2px, кути 5, margins 20/10.

**Файли:** `src/ui/WorldMap.gd`

---

## Версія 1.9 — 03.06.2026

### Фаза 2 — Onboarding + Polish завершена (v1.9 – v2.4)

Повний цикл змін Фази 2 охоплює версії 1.9–2.4. Короткий підсумок:

- **Tooltips (3.1)** — terrain-модифікатори числами, desc навичок через FloatingLabel, hover "Чекати"
- **Tutorial-бій (3.2)** — `tutorial_done` flag, пласка карта, 5 покрокових підказок, кнопка "Пропустити"
- **Плаваючі підказки (3.3)** — `_onboarding_panel` знизу по центру, 5 тригерів, тримаються до дії
- **Підказки в CombatLog (3.4)** — 5 бойових підказок жовтим, один раз за бій, вимкнені в tutorial
- **Баланс економіки (3.5)** — стартові 150 тал., нагороди −20/25/30%, найм 80–120 тал., броня 90–150 тал.
- **Механіка луту броні** — `body_armor * 2 > max_body_armor` → 40% шанс дропу; аналогічно шолом
- **Bugfix: кнопки навичок** — `toggle_mode = false`, кеш `_last_active_data` включає `current_skill_id`
- **Bugfix: кнопка "Чекати"** — `toggle_mode/button_pressed/disabled = false` + `remove_child` перед `queue_free`

**Файли:** `BattleManager.gd`, `UnitPanel.gd`, `WorldMap.gd`, `WorldGenerator.gd`, `CampaignManager.gd`, `SaveManager.gd`, `TacticalGrid.gd`

---

### Tooltips — Фаза 2, задача 3.1

Мінімалістичні підказки тільки там, де без них неможливо прийняти рішення:

- **`rally` desc** (`CombatUnit.gd:220`) — оновлено: "Перевірка моралі союзників у радіусі 4 клітинок." (було: "Активна навичка Осавула.")
- **Кнопка "Чекати"** (`UnitPanel.gd` `_rebuild_skill_bar()`) — додано `mouse_entered/exited` з FloatingLabel: "Пропустити хід, походити пізніше."
- **Terrain tooltips** (`UnitPanel._get_terrain_tooltip_text()`) — числові модифікатори на hover: AP / витривалість на крок + захист % / влучність %. Значення з `_get_terrain_step_costs()` та `_get_terrain_defense_mod()` в `CombatUnit.gd`

**Виправлення doc:** `TACTICAL_TERRAIN_MECHANICS.md` — WATER (Брід) не має бойового штрафу (було помилково вказано -25% захист).

**Файли:** `src/ui/UnitPanel.gd`, `src/units/CombatUnit.gd`

---

## Версія 1.8 — 02.06.2026

### Progression Loop (Фаза 1 MVP — завершено)

- **InventoryManager** (`src/core/InventoryManager.gd`) — новий статичний `class_name` (не autoload). API: `add_item`, `remove_item`, `sell_item`, `equip_item(ws, item_id, unit_name)`, `get_by_type`, `make_item_from_resource`. Використовує `buy_price`/`sell_price`. Пошук козака за `name`
- **SaveManager v3** — `world_state` розширено: `squad_inventory`, `shop_inventory`, `day_count`. Міграція v2→v3: `_migrate()` дописує відсутні поля зі значеннями за замовчуванням без ломання старих збережень
- **Squad Inventory UI** — панель інвентарю на глобальній карті (клавіша `I`). Ряд козаків, сітка спорядження 3×3 (стиль `CharacterSheet.gd`), інвентар загону. Клік на слот — зняти предмет; кнопка "Озброїти" екіпірує на обраного козака; "Продати" активна лише в поселенні
- **Лут після бою** — `BattleManager._show_battle_result()` збирає лут при перемозі (30% шанс від мертвих ворогів). `BattleResultScreen` показує секцію "Трофеї". `InventoryManager.make_item_from_resource()` перетворює `WeaponResource` на item-словник
- **Лікування в поселеннях** — кнопка "Лікувати" в діалозі `town`/`village`. Ціна 30 тал./поранений козак, HP = max_hp. `CampaignManager.save_world_state()` після підтвердження
- **Крамниця** — секція магазину зброї в діалозі поселення. Товари з `world_state["shop_inventory"]`, безлімітний сток для MVP
- **Найм бійців** — секція "Таверна" в діалозі `town`. 3 кандидати з випадковими іменами, HP, мораллю. Ціна 50–80 тал. Дефолтна зброя — `saber.tres`. Якщо загін ≥ 8 — секція прихована
- **Голод та дезертирство** — `WorldMap._apply_hunger_effects()`: при `provisions == 0` кожен козак отримує `morale -= 20` за день; при `morale == 0` → 50% шанс дезертирства (козак видаляється, нотифікація в HUD). На початку бою при голоді: стан `WAVERING`, `stamina *= 0.7`
- **Мирний доступ до поселень** — `town`/`village` з репутацією ≥ −19 відкриваються без бою. `_is_location_hostile()` перевіряє тип локації і репутацію фракції. Кнопка "Атакувати" залишається для агресивного входу
- **Броня/шоломи в бою** — `BattleManager` завантажує `armor_path` і `helm_path` в `data.default_armor` / `data.default_helmet` перед `setup_from_data()`. `CampaignManager._serialize_units()` зберігає шляхи після бою
- **Дефолтна зброя найманців** — `weapon_resource_path = saber.tres` додається при наймі
- **Виправлення `_is_at_settlement()`** — радіус 135 px (`90.0 × 1.5`), рахує не-ворожі поселення
- **Оновлення панелі після дій** — найм, лікування, купівля в крамниці оновлюють панель інвентарю якщо вона відкрита

**Файли:** `WorldMap.gd`, `BattleManager.gd`, `CampaignManager.gd`, `SaveManager.gd`, `InventoryManager.gd` (новий)

---

## Версія 1.7 — 29.05.2026

### WorldMap — туман війни, цикл доби, факел

**Синхронізація дня і доби:**
- `_day_time` (0..`PIXELS_PER_DAY=1500`) — єдина змінна прогресу; росте лише при русі загону. Видалено `_pixels_traveled` та `DAY_CYCLE_DURATION`.
- Один повний цикл `_day_time` = один ігровий день = +1 до лічильника = –1 провізія.
- При 2× швидкості доба і дні пришвидшуються синхронно.

**Фази доби (пропорції українського літа):**
- ☀️ День 57% / 🌅 Захід 7% / 🌙 Ніч 29% / 🌅 Схід 7%
- `CanvasModulate` плавно переходить між `C_DAY(1,1,1)` → `C_DUSK(0.72,0.52,0.32)` → `C_NIGHT(0.32,0.34,0.50)` → назад
- Індикатор фази у TopBar: `☀️ День` / `🌅 Захід` / `🌙 Ніч`

**Радіус огляду залежно від доби:**
- День: `FOG_REVEAL_DAY = 280 px`; Ніч: `FOG_REVEAL_NIGHT = 160 px`
- Біомний модифікатор: ліс ×0.7, степ ×1.15

**Факел загону:**
- `PointLight2D` з теплим кольором `(1.0, 0.65, 0.25)`, фіксований розмір
- Energy: 0 вдень → 1.2 вночі; процедурна `GradientTexture2D` як текстура

**Туман війни — повна реалізація:**
- Сітка `100×67` комірок по 30 px; `ImageTexture` (RGBA8) оновлюється щокадру
- `FogLayer` (z=8): плавне шейдерне коло видимості, grayscale-пам'ять через `hint_screen_texture`, світлий туман у terra incognita (`color_shroud = (0.80, 0.82, 0.88)`)
- `CloudLayer` (z=9): Worley noise (3 масштаби) + domain warping; хмари `(0.97,0.97,0.95)` зникають при наближенні; без `return` у fragment (Godot 4 обмеження)
- Обидва `ColorRect` мають `color = Color(0,0,0,0)` — прозорий fallback при помилці шейдера

**Нотифікація відкриття локації:**
- `PanelContainer` + `RichTextLabel` + `Tween`: fade in 0.3с → 2.5с → fade out 0.5с
- При накладанні нова нотифікація витісняє попередню

---

## Версія 1.6 — 26.05.2026

### TacticalGrid — координати, зона руху, TurnQueueUI

**Архітектурний рефакторинг координат (`TacticalGrid.gd`):**
- `IsoMath.map_to_local/get_cell_center/local_to_map` в `TacticalGrid.gd` **повністю замінено** на 3 методи-хелпери через `TileMapLayer` як єдине джерело істини:
  - `_cell_center(pos)` → `_tile_layer.map_to_local(pos) + _tile_layer.position` — піксельний центр клітинки (де стоять юніти)
  - `_cell_vertex(pos)` → `_cell_center(pos) - Vector2(0, tile_height/2)` — верхня вершина ромба (для ліній сітки)
  - `_local_to_cell(local_pos)` → `_tile_layer.local_to_map(local_pos - _tile_layer.position)` — позиція юніта → клітинка
- `IsoMath` тепер містить **виключно чисту логіку сітки**: `get_dist_4`, `get_line_of_sight_path`, `get_astar_path_from_instance` — жодної пікселевої математики.
- `CombatUnit.gd` / `BattleManager.gd` / `UnitPanel.gd` тимчасово залишаються на `IsoMath.local_to_map/get_cell_center` (формула коректна для позицій на центрах клітинок; рефакторинг цих файлів — окреме завдання).

**Зона руху — обводка та обрізка шляху:**
- Додано **золоту обводку** (`Color(1.0, 0.75, 0.0, 0.85)`, 1.5px) навколо зони досяжності: малюється ребро ромба між досяжною та недосяжною клітинкою.
- **Шлях та кінцева точка** тепер відображаються **постійно**, але обрізаються на межі зони руху: `update_path_preview()` будує повний A\*-шлях до курсора, але залишає тільки клітинки в `_reachable_cells` (зупиняється на першій недосяжній).
- Раніше шлях і маркер призначення малювались поза зоною — баг усунено.

**Hover юніта — terrain tooltip:**
- При наведенні курсора на юніта `update_hover_terrain(-1)` тепер явно очищає підказку місцевості, щоб не залишалась стара інформація.

**TurnQueueUI — перший юніт у черзі (`BattleManager.gd`):**
- Видалено надлишковий блок у `_ready()`, який двічі витягував юніта з черги (`pop_front()`) — один раз вручну перед `start_next_unit_turn`, ще раз у самому `start_next_unit_turn` (deferred). Перший юніт (найвища ініціатива, нерідко козак) пропадав із панелі «Раунд».
- Тепер `initialize_queue()` заповнює повну чергу і емітує `queue_changed` з усіма юнітами; `start_next_unit_turn` (deferred) коректно витягує першого і починає хід.

---

## Версія 1.5 — 19.05.2026

### WorldMap fixes + UI polish

**Ігровий цикл:**
- **День / провізії** — підключено: кожні 250px руху `day += 1`, `provisions -= 1`. При 2× швидкості витрачається вдвічі швидше.
- **weapon_resource_path** у `_create_starting_squad()` — козаки тепер завантажують свою зброю при першому вході в бій з нової гри.
- **Меню cleared-локації** — клік на очищену локацію показує тематичний текст і кнопку "Покинути" (замість "Атакувати/Уникнути").

**Процедурна генерація:**
- **Озера ≥ 150px від ріки** — retry-loop 20 спроб при генерації центру озера; `MIN_LAKE_RIVER_DIST = 150.0`.

**Панель швидкості (переработка):**
- Видалено стару кнопку bottom-right і 🎯 центрування.
- Три нових кнопки `[⏸] [1×] [2×]` у TopBar перед "День". Активна підсвічується золотою рамкою.
- Клавіші: `Space` = пауза, `1` = 1×, `2` = 2×.
- Пауза зупиняє все: `_player_party.stop()` + freeze ворогів + `world_ticking=false`.
- Надпис `⏸  ПАУЗА` (36px, золотий) по центру зверху при активній паузі.

**Encounter Dialog:**
- Cooldown після "Уникнути" → 5 сек, після "Говорити" → 10 сек для конкретного загону.
- EnemyParty відновлює рух одразу після закриття діалогу.
- `_check_all_encounters()` та `_on_party_encounter()` ігнорують загони на cooldown.

**UX: авто-діалог при прибутті до локації (fix 1.3):**
- Раніше гравець, що клікав на далеку локацію, після прибуття мав клікати вручну ще раз — діалог не відкривався.
- `_on_player_movement_stopped` тепер перевіряє `_nav_target_marker`: якщо загін зупинився в радіусі взаємодії — діалог зустрічі відкривається автоматично.
- Виправлено відсутній cooldown-check для локацій в `_check_all_encounters()` (запобігає повторному тригеру після "Уникнути").

**EncounterDialog → .tscn (3.2 часткове):**
- `EncounterDialog.tscn` перенесено з процедурного коду у повноцінну сцену з деревом вузлів та запеченими стилями.
- `WorldMap.gd` оновлено для завантаження сцени та отримання сигналів замість inline-побудови.

---

## Версія 1.4 — 18.05.2026

### WorldMap + Campaign System (повний шар кампанії)

**Виправлення бугів бойової системи:**
- **Скасування навички ПКМ (fix 1.1)**: Блок `MOUSE_BUTTON_RIGHT` в `TacticalGrid._unhandled_input()` був вкладений всередину `MOUSE_BUTTON_LEFT` — скасування ніколи не спрацьовувало. Розведено на два незалежних `if`.
- **Resource.duplicate при level up (fix 1.2)**: Характеристики юніта при підвищенні рівня змінювались безпосередньо в `UnitData.tres` (shared resource). Тепер `BattleManager` при призначенні юнітів завжди викликає `res.duplicate()`. Виправлено суміжний баг: `_serialize_units()` у `CampaignManager` тепер зберігає `stat_melee_skill`, `stat_ranged_skill`, `stat_melee_defense` щоб бонуси рівня не губились після перезавантаження.
- **Безпечна перевірка типів (fix 4.2)**: Замінено 9 входжень `has_method("start_turn")` та `has_method("gain_xp")` у `CombatUnit.gd` і `UnitPanel.gd` на `is CombatUnit` (Godot 4 `class_name`).

**Поле моралі кампанії (1.4 часткове):**
- Додано поле `morale: 100` до стартового загону в `CampaignManager._create_starting_squad()`.
- `_serialize_units()` зберігає мораль між боями. Механіка щоденного зниження та дезертирства — не реалізована (TODO).

**Нові autoload / сервіси:**
- `CampaignManager` (`src/core/CampaignManager.gd`) — координує world_state, запуск/завершення бою, репутацію фракцій
- `SaveManager` розширено: `has_save()`, `save_campaign(world_state)`, `load_campaign()` — формат v2 (JSON)

**Процедурна генерація світу (`src/core/WorldGenerator.gd`):**
- 3 біоми: Ліси (бандити, північ), Дике Поле (Орда, степ), Кордон (Crown, захід)
- Ріки та озера — Line2D/Polygon2D, hвилясті кривові
- Дороги між локаціями — жадібний spanning tree із зигзагом
- 6 локацій із гарнізонами (bandit_camp, ruins, tatar_camp, crown_outpost, fortress)
- 5 ворожих загонів (бандити патрулюють дороги, Орда і Crown — свої зони)

**Глобальна карта (`src/scenes/WorldMap.tscn` + `src/ui/WorldMap.gd`):**
- Real-time рух гравця (клік → переміщення зі швидкістю 150 px/s)
- **Пауза**: `world_ticking = false` коли гравець стоїть — вороги теж стоять (як у Battle Brothers)
- HUD: день, тал., провізії, репутації 3 фракцій, панель загону зліва
- EncounterDialog: Атакувати / Уникнути / Говорити (кнопки залежать від репутації з фракцією)

**World-entities:**
- `PlayerParty.gd` — рух, detection radius, зупинка
- `EnemyParty.gd` — state machine: PATROL → PURSUE → RETURN_TO_BASE; бандити патрулюють дороги
- `LocationMarker.gd` — іконки локацій, interaction_radius, get_battle_config()

**Інтеграція з бойовою системою:**
- `BattleManager._apply_enemy_config()` — одноразово при старті бою призначає UnitData ворожим вузлам зі сцени
- `BattleResultScreen` — кнопка "Продовжити кампанію" → `CampaignManager.finish_battle()`; лут із `active_battle_config`
- `MainMenu` — "Нова гра" → `cm.new_campaign()`, "Продовжити" → load + WorldMap

**10 нових UnitData ресурсів (`src/resources/units/`):**
- Козаки: Ничипір (saber), Гаврило (janissary_musket), Тимофій (spear), Панько (warhammer)
- Вороги: Bandit, BanditLeader (battle_axe), Tatar (bow), TatarHeavy, Janissary, Reiestr

**Flow сцен після змін:**
```
MainMenu → new_campaign() → WorldMap ← → (start_battle) → Battle → BattleResultScreen → finish_battle() → WorldMap
```

---

## Версія 1.3 — 16.05.2026
- **Генерація мап (WFC + ChunkLibrary):** Процедурна генерація карт 16×16 з 4 типами локацій (Степ, Ліс, Болото, Річка). Система зон ділить карту на 4 чверті з власним характером рельєфу. Пост-обробка виправляє стіни з дерев, замкнені кільця, розкидану воду і форму каменів. Детальніше: [MAP_GENERATION.md](07_TECHNICAL/MAP_GENERATION.md)
- **Гібридна генерація (Chunk + WFC):** Кожна зона карти отримує власні ваги рельєфу з бібліотеки чанків, замість єдиних ваг на всю карту. Це дає структуровану різноманітність: один кут лісу, інший — скелі.
- **Поведінка ворожого ШІ:** Задокументовано пріоритети дій ШІ (відпочинок → відступ → Rally → перезарядка → атака → рух → Riposte). Детальніше: [ENEMY_AI_BEHAVIOR.md](03_COMBAT/ENEMY_AI_BEHAVIOR.md)
- **Візуальний зворотній зв'язок:** Задокументовано анімації атак, числа шкоди, спалах при ударі, тремтіння екрану, смерть юніта, підсвічування зон. Детальніше: [VISUAL_FEEDBACK.md](06_UI_AND_AUDIO/VISUAL_FEEDBACK.md)

## Версія 1.2 — 13.05.2026
- **Екран результатів бою (BattleResultScreen):** Процедурно генерований UI, який показує завдану/отриману шкоду, досвід, підвищення рівнів, зібраний лут та відстежує смерть козаків у кінці бою.
- **Система збережень (SaveManager):** Автоматичне збереження та завантаження прогресу (`user://cossacks_save.json`). Зберігаються HP, XP, рівні. Реалізовано перманентну смерть (мертві козаки видаляються зі сцени після завантаження).

## Версія 1.1 — 30.04.2026
- Встановлено базову роздільну здатність екрану 1920x1080 (Stretch Mode: canvas_items + expand).
- Імплементовано вільну тактичну камеру (Panning: WASD + MMB).
- Налаштовано механіку масштабування (Zoom: 0.5x - 1.25x) з динамічним UI-індикатором.
- Стандартизовано розміри шрифтів у всьому тактичному інтерфейсі (UI_UX_LAYOUTS.md).

## Версія 1.0 — 02.04.2026
- Повна реструктуризація всіх документів
- Створено єдину логічну ієрархію папок
- Додано службові файли 00_*
- Створено повний індекс (00_INDEX.md)
- Перенесено всі існуючі документи в нові розділи
- Додано `PERKS_FULL_LIST.md` з tier-list та вартістю AP/Stamina

## Попередні версії
- 0.9 — 02.04.2026 — Створення повного списку перків
- 0.8 — Березень 2026 — Початкове збирання всіх документів

**Примітка:** При кожній значній зміні механіки оновлювати версію та додавати запис сюди.