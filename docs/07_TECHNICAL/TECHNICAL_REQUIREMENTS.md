
# TECHNICAL_REQUIREMENTS.md
# Технічні вимоги для реалізації

## Ключові класи (Godot 4.x, поточна реалізація)

### 1. CombatUnit (Node2D) — `src/units/CombatUnit.gd`
- Властивості: `hp`, `max_hp`, `stamina`, `max_stamina`, `ap` (max 10), `body_armor`, `head_armor`, `team`, `weapon_type`
- Стани моралі: `CONFIDENT / STEADY / WAVERING / BREAKING / FLEEING`
- Методи: `take_damage()`, `attack()`, `move_along_path()`, `execute_ai()`, `execute_flee_ai()`, `trigger_resolve_check()`, `use_rally()`, `activate_riposte()`, `execute_shoot()`, `perform_opportunity_attack()`
- Типи зброї: `sword`, `musket`, `spear`, `heavy` — визначають `available_skills`

### 2. BattleManager (Node2D) — `src/tactical/BattleManager.gd`
- Черга ходів (`turn_queue`), сортована за `get_effective_initiative()` (Initiative – Fatigue)
- Керує раундами, черговістю, UI-панеллями, CombatLog
- Блокує ввід гравця під час ходу ШІ (`team != 0`)
- `wait_current_unit()` — механіка "Зачекати" (юніт іде в кінець черги)
- `_center_camera()` — автоматично центрує камеру на старті

### 3. TacticalGrid (Node2D) — `src/tactical/TacticalGrid.gd`
- Сітка **16×16** клітинок; ізометрична пряма (не діагональна)
- Типи місцевості: `CLEAR, BUSHES, SWAMP, WATER, ROCKS, TREE`
- `TREE` — непрохідна перешкода, блокує LoS і рух
- Використовує `AStar2D` для пошуку шляху з урахуванням вагових коефіцієнтів місцевості
- `check_line_of_sight()` — перевірка прямої видимості з підрахунком кущів і дружнього вогню
- ZoC (4 напрямки) лише для юнітів з `is_melee_unit() == true`

### 4. CameraController (Camera2D) — `src/tactical/CameraController.gd`
- WASD + стрілки: переміщення камери (600 px/с)
- MMB drag: перетягування
- Зум: фіксовані рівні `[0.5, 0.75, 1.0, 1.25]`, коліщатко миші та клавіші `+/-`
- Ліміти: `X: -500..500`, `Y: 200..1000`
- Динамічний UI-індикатор зуму (зникає через 1.5с після бездіяльності)

### 5. UnitData (Resource) — `src/resources/UnitData.gd`
- Ресурс з усіма базовими характеристиками юніта
- Поля: `base_hp`, `base_stamina`, `base_body_armor`, `base_head_armor`, `base_melee_skill`, `base_ranged_skill`, `base_melee_defense`, `base_ranged_defense`, `base_initiative`, `base_resolve`
- Зірочки талантів: `star_hp`, `star_melee`, `star_defense`

### 6. IsoMath (GDScript) — `src/core/IsoMath.gd`
- **Чиста логіка сітки** (без пікселів): `get_dist_4()`, `get_astar_path()`, `get_astar_path_from_instance()`, `get_line_of_sight_path()`
- `get_cell_center()` / `local_to_map()` — залишаються для `CombatUnit`, `BattleManager`, `UnitPanel` (не мають прямого доступу до `TileMapLayer`)
- **Пікселі в `TacticalGrid`** — виключно через хелпери: `_cell_center()`, `_cell_vertex()`, `_local_to_cell()` (використовують `TileMapLayer` як джерело істини; `_tile_layer.position = Vector2(0, 40)` вирівнює тайли з юнітами)

### 7. Globals (Node) — `src/core/Globals.gd`
- Глобальні константи: `AP_MAX=10`, `CHANCE_MIN=5`, `CHANCE_MAX=95`, `STAMINA_RECOVERY=15`

## UI-компоненти
- `UnitPanel.gd` + `UnitPanel.tscn` — панель активного юніта (HP, Stamina, AP, навички); .tscn-оболонка зі статичним деревом вузлів (LeftCol/MidCol/RightCol) — логіка ще в GDScript
- `TurnQueueUI.gd` — черга ходів у верхній частині екрана (процедурний код, слоти з тween-анімацією)
- `EncounterDialog.tscn` — модальний діалог зустрічі (перенесено з inline-коду у .tscn + сигнали)
- `CombatLog.gd` — журнал бою (RichTextLabel зі скролом)
- `FloatingLabel.gd` — плаваючий текст пошкоджень/-FX

## Додаткові системи
- MoraleSystem (вбудований у CombatUnit через `trigger_resolve_check`)
- LoS + Friendly Fire (вбудований у TacticalGrid + CombatUnit)
- ZoneOfControl system (вбудований у TacticalGrid)
- WeatherSystem + TimeOfDay (заплановано)
- LootSystem (заплановано)
- SpriteSystem (Фаза 3.5) — `assets/sprites/units/` → `Sprite2D` замість `Polygon2D` в `CombatUnit.create_visual_placeholder()`

## Арт-ресурси (Фаза 3.5)

| Тип | Папка | Стан |
|-----|-------|------|
| Спрайти юнітів у бою | `assets/sprites/units/` | ⬜ 14 placeholder PNG, очікує арт |
| Портрети юнітів | `assets/portraits/` | ⬜ існує, очікує арт |
| Іконки предметів | `assets/ui/icons/` | ⬜ не створено |
| Тайлсет бою | через `TileMapLayer` в `Battle.tscn` | ⬜ не створено |
| Текстури глобальної карти | через `WorldMap.gd` | ⬜ не створено |

## Стандарти коду (GDScript 2.0)

- **Перевірка типів**: `if node is CombatUnit` замість `has_method("start_turn")` — покрито всі 10 входжень у `CombatUnit.gd` та `UnitPanel.gd`.
- **Resource isolation**: `BattleManager` завжди викликає `res.duplicate()` при призначенні `UnitData` вузлам; `.tres`-файли на диску не змінюються при level up.
- **Типізовані словники**: `terrain_map: Dictionary[Vector2i, int]` у `TacticalGrid.gd`; `world_state` та `active_battle_config` (вкладені `Dictionary[String, Variant]`) не типізуються — практичної користі нема.
- **Autoload правильно**: звернення до `Globals.AP_MAX` безпосередньо; `Globals_Script.new()` в `CombatUnit.gd` — TODO для виправлення (4.3).

**Версія:** 1.3 (оновлено) — 26.05.2026