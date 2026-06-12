# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Козацька Варта** — покрокова тактична RPG у стилі Battle Brothers. Godot 4.6, GDScript. Козацька тематика, XVII ст.

Flow сцен: `MainMenu → WorldMap → Battle → BattleResultScreen → WorldMap`

## Running the project

Відкрити папку проекту в **Godot 4.6 Editor** → F5 або кнопка Play. Немає CLI-білду, тестів або лінтера — перевірка виключно через запуск у редакторі. Godot друкує помилки у вбудовану консоль.

## Architecture

### Autoloads (глобальні синглтони)
- `Globals` (`src/core/Globals.gd`) — константи: `AP_MAX=10`, `TILE_W/H`, `CHANCE_MIN/MAX=5/95`
- `FloatingLabel` (`src/ui/FloatingLabel.tscn`) — `FloatingLabel.show_label(bbcode)` / `hide_label()`
- `CampaignManager` (`src/core/CampaignManager.gd`) — координує стан кампанії, переходи між сценами

### CampaignManager API

```gdscript
var world_state: Dictionary = {}
# { day, thalers, provisions, faction_rep:{crown,sich,orda},
#   locations:[{id,type,faction,pos,garrison_paths,cleared,reward_thalers,name}],
#   enemy_parties:[{id,faction,unit_paths,patrol_waypoints,base_pos,pos,alive}],
#   player_pos, rivers, lakes, roads,
#   forest_patches, hill_patches, swamp_patches, kurgans, ravines, influence_anchors,
#   squad:[{name,hp,max_hp,morale,...}] }

var active_battle_config: Dictionary = {}
# { enemy_data_paths:[String], reward_thalers:int, source_id:String }
```

- `new_campaign()` → генерує `world_state` через `WorldGenerator`, переходить на WorldMap
- `start_battle(config)` → зберігає `active_battle_config`, завантажує Battle
- `finish_battle(is_victory, player_units)` → оновлює стан, зберігає, повертає на WorldMap
- `change_rep(faction, delta)` / `get_encounter_options(faction) -> Array[String]`

Детальніше про WorldMap і EncounterDialog: [docs/02_WORLD_AND_FACTIONS/GLOBAL_MAP_MECHANICS.md](docs/02_WORLD_AND_FACTIONS/GLOBAL_MAP_MECHANICS.md)

### Сцена бою (`src/scenes/Battle.tscn`)

```
Battle (Node2D)
├── TacticalGrid       — ізометрична сітка 16×16, TileMapLayer terrain, A* pathfinding, input
│   └── TileMapLayer   — DIAMOND_DOWN 160×80, _tile_layer.position=(0,40)
├── Camera2D           — CameraController.gd: WASD/MMB pan, scroll zoom 0.5×–1.25×
├── BattleManager      — черга ходів, round management, ШІ, combat log
├── Player1-4 / Enemy1-4  — CombatUnit вузли з UnitData.tres
└── UI (CanvasLayer)
    ├── CombatLog, EndTurnButton, RetreatConfirmation
    ├── UnitPanel      — панель активного юніта (HP/Stamina/AP/skills)
    ├── CharacterSheet — модальне вікно (будується процедурно)
    └── TurnQueueUI    — створюється BattleManager._setup_turn_queue_ui()
```

**Ініціалізація ворогів:** `BattleManager._ready()` → `_apply_enemy_config()` — призначає UnitData існуючим Enemy-вузлам (`res.duplicate()`). Зайві → `is_dead=true` + `visible=false`.

**Ініціалізація козаків:** якщо `cm.world_state["squad"]` не порожній — завантажує HP/XP/зброю звідти.

### Потік ходу
1. `BattleManager.start_next_unit_turn()` → `unit.start_turn(is_new_round)`
2. `team == 1`: `unit.execute_ai()` (async while-loop з `await create_timer`)
3. `team == 0`: гравець → `TacticalGrid._unhandled_input()` → move або attack
4. `BattleManager.end_unit_turn()` → наступний юніт
5. Черга порожня → `end_round()` → `initialize_queue()` (сортування за ініціативою)

`CombatUnit` емітує `signal move_finished` після будь-якої дії. ШІ: `await move_finished`.

Детальніше про механіки бою: [docs/03_COMBAT/COMBAT_CORE_MECHANICS.md](docs/03_COMBAT/COMBAT_CORE_MECHANICS.md)

### Координатна система

**`IsoMath.gd`** (`const`, не autoload — preload де потрібно) — **чиста логіка сітки, без пікселів**:
- `get_dist_4(a, b)`, `get_astar_path_from_instance(astar, from, to, grid_size)`, `get_line_of_sight_path(start, end)`
- `get_cell_center(map_pos)` / `local_to_map(pos)` — залишаються для `CombatUnit` та `BattleManager`

**Пікселі в `TacticalGrid`** — виключно через три хелпери (TileMapLayer як джерело істини):
```gdscript
func _cell_center(pos: Vector2i) -> Vector2:      # де стоїть юніт
    return _tile_layer.map_to_local(pos) + _tile_layer.position

func _cell_vertex(pos: Vector2i) -> Vector2:      # верхня вершина ромба (лінії сітки)
    return _cell_center(pos) - Vector2(0.0, float(_tile_layer.tile_set.tile_size.y) * 0.5)

func _local_to_cell(local_pos: Vector2) -> Vector2i:  # позиція юніта → клітинка
    return _tile_layer.local_to_map(local_pos - _tile_layer.position)
```
`_tile_layer.position = Vector2(0, 40)` — вирівнює тайли TileMapLayer з позиціями юнітів.

### Ресурси зброї та пошкодження

Два шляхи ініціалізації скілів (в `CombatUnit._ready`):
1. **Пріоритетний**: `data.default_weapon` → `WeaponResource.actions[]` → `AttackAction.gd` → `available_skills`
2. **Fallback**: legacy `weapon_type: String` → hardcoded скіли

`CombatUnit.take_damage(amount, is_headshot, armor_pen, armor_dmg_mult)`:
- `effective_armor = armor * (1 - armor_pen)` → надлишок іде в HP
- Голова: ×1.5 до HP, окрема шкала `head_armor`

### SaveManager
- Файл: `user://cossacks_save.json`, формат v2
- `has_save() -> bool`, `save_campaign(world_state)`, `load_campaign() -> Dictionary`
- `CampaignManager` делегує збереження `SaveManager`

## Key files

| Файл | Призначення |
|------|-------------|
| `src/core/CampaignManager.gd` | Autoload: world_state, переходи, репутація, active_battle_config |
| `src/core/WorldGenerator.gd` | Proc-gen світу → [MAP_GENERATION.md](docs/07_TECHNICAL/MAP_GENERATION.md) |
| `src/ui/WorldMap.gd` | Логіка глобальної карти |
| `src/world/PlayerParty.gd` | Рух гравця: `set_target(pos)`, `stop()`, SPEED=150, DETECTION_RADIUS=65 |
| `src/world/EnemyParty.gd` | State machine: PATROL → PURSUE → RETURN_TO_BASE |
| `src/world/LocationMarker.gd` | `setup(data)`, `get_battle_config()`, `mark_cleared()` |
| `src/units/CombatUnit.gd` | Юніт (~1100 рядків): стани, мораль, бій, ШІ |
| `src/tactical/BattleManager.gd` | Черга ходів, раунди, ворожа конфігурація |
| `src/tactical/TacticalGrid.gd` | Сітка, terrain (TileMapLayer), pathfinding, input |
| `src/ui/UnitPanel.gd` | Панель активного юніта |
| `src/ui/BattleResultScreen.gd` | Екран результатів → `cm.finish_battle()` |
| `src/ui/MainMenu.gd` | "Нова гра" / "Продовжити" |
| `src/core/SaveManager.gd` | Збереження/завантаження v2 JSON |
| `src/resources/UnitData.gd` | Resource-клас шаблону юніта |
| `src/resources/combat/WeaponResource.gd` | Зброя зі списком AttackAction |

## Resource paths

- **Козаки:** `src/resources/units/Nychypir.tres`, `Gavrulo.tres`, `Tymofiy.tres`, `Panko.tres`
- **Вороги:** `src/resources/units/Bandit.tres`, `BanditLeader.tres`, `Tatar.tres`, `TatarHeavy.tres`, `Janissary.tres`, `Reiestr.tres`
- **Зброя:** `src/resources/combat/weapons/*.tres`
- **Навички:** `src/resources/combat/actions/*.tres`
- **Броня:** `src/resources/equipment/armor/*.tres`, `helmets/*.tres`
- **Портрети:** `assets/portraits/`, placeholder-SVG: `assets/ui/`

## Current state (v4.8 — 12.06.2026)

**Що реалізовано:**
- Бойовий цикл: рух, атаки, ШІ, мораль, ZoC, LoS, riposte/rally, відступ, TurnQueueUI, tutorial-бій
- WorldMap: `TextureButton [⏸ ▶ ⏩]` (radio-group, Figma SVG іконки, 56px висота), день/провізії, EncounterDialog, авто-діалог
- Progression loop: магазин, лікування, лут, найм, інвентар загону (InventoryManager), SaveManager v3
- Локалізація uk/en (~361 ключів), AudioManager (музика + 9 SFX), Settings menu
- Спрайти юнітів (14 PNG), іконки предметів (InventoryManager.ITEM_ICONS), тайли місцевості
- Native Theme (`assets/theme/game_theme.tres`), TopBar (три пергаментні панелі, Figma-дизайн)
- CampaignManager + WorldGenerator: proc-gen світ, фракції, репутація; голод/дезертирство, Game Over
- Глобальна карта (v4.8): процедурна географія (пергаментний шейдер, ліси/пагорби/болота/кургани/яри як патчі-полігони), швидкість руху й радіус огляду залежать від місцевості, засідки бандитів у болотах/ярах (`get_ambush_detection_multiplier`), невидимі зони впливу (`influence_anchors`, `get_faction_at`); прямокутних біомів більше немає

**TODO / Фаза 3.5 (залишок):**
- Текстури глобальної карти (іконки локацій, іконка гравця; заміна процедурних символів на арт)
- UI polish (фон MainMenu, стилізовані кнопки, курсор)

Повна документація: [docs/00_VERSION_HISTORY.md](docs/00_VERSION_HISTORY.md)

## GDScript conventions

- Коментарі та назви змінних — **українською**
- Перевірка типів: `if node is CombatUnit` — **не** `has_method(...)`
- `resource.duplicate()` при кожному призначенні `UnitData` вузлам
- Складні UI-панелі у `.tscn` (вже: `EncounterDialog.tscn`, `UnitPanel.tscn`-оболонка); прості — процедурно
- `get_node_or_null` замість `$` де вузол може бути відсутній
- Async через `await signal` або `await get_tree().create_timer(sec).timeout`
- `find_child("Name")` для пошуку між сестринськими гілками
- Явні типи для Variant: `var json: Variant = JSON.parse_string(...)` (warnings-as-errors)
- Типізовані словники де має сенс: `Dictionary[Vector2i, int]`; `Dictionary[String, Variant]` — ні

## Wiki Knowledge Base
Path: ~/Documents/Obsidian/claude-obsidian

Після кожної завершеної задачі автоматично оновлюй wiki:
1. Оновлюй відповідну wiki-сторінку в ~/Documents/Obsidian/claude-obsidian/wiki/
2. Якщо такої сторінки немає — створи нову за шаблоном (frontmatter з tags, created, updated)
3. Оновлюй wiki/log.md — додавай запис про зміну
4. Оновлюй wiki/hot.md — оновлюй кеш останнього контексту
Не питай, чи потрібно записувати — просто записуй.

Коли потрібен контекст:
1. Read wiki/hot.md first
2. If not enough, read wiki/index.md
3. Drill into specific wiki pages

Не читай wiki для загальних питань програмування.
