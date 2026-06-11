# Імплементаційний план «Козацька Варта»

**Поточний фокус:** Фаза 3.5 — Візуальне наповнення  
**✅ TopBar висоти 56px (v4.6 — 09.06.2026) — ліва панель margin 15px, inventory wrapped у Control 32×32**  
**✅ Speed buttons TextureButton + 9 SVG Figma (v4.5 — 09.06.2026) — radio-group логіка, _apply_speed_btn_state()**  
**✅ Pause button SVG іконки з Figma (v4.4 — 09.06.2026) — три стани: default/hover/active, assets/sprites/ui/**  
**✅ Native Godot Theme game_theme.tres (v4.3 — 09.06.2026) — Kelly Slab + Label color каскадно, прибрано ~25 зайвих font_size_override**  
**✅ TopBar WorldMap — Figma-дизайн (v4.2 — 08.06.2026) — три пергаментні панелі, Kelly Slab, розміри по макету**  
**✅ Bugfix v3.9.1 (06.06.2026) — другий бій більше не зависає, data_path збережений, спрайти захисно завантажуються**  
**✅ Фаза 3 — Локалізація + Аудіо — ЗАВЕРШЕНО**  
**✅ Фаза 2 — Onboarding + Polish — ЗАВЕРШЕНО**  
**✅ Локалізація тексту (4.1–4.7+) — ЗАВЕРШЕНО** — ~361 ключів, grep повертає 0 UI-рядків без tr()  
**✅ AudioManager + Settings panel — ЗАВЕРШЕНО (v3.3)** — код аудіо готовий, меню налаштувань готове  
**✅ Фаза 3 — Локалізація + Аудіо — ЗАВЕРШЕНО (v3.6)**

**✅ Фаза 1 — Progression Loop — ЗАВЕРШЕНО** (гра playable на 5+ боїв)

---

## 1. Завершені виправлення та рефакторинг ✅

Технічна основа, на якій будується Фаза 1:

| # | Задача | Файли |
|---|--------|-------|
| 1.1 | ПКМ-скасування навички — `MOUSE_BUTTON_RIGHT` винесено в окремий `if` | `TacticalGrid.gd:596` |
| 1.2 | Resource duplication при level up — `res.duplicate()` скрізь; `_serialize_units()` тепер зберігає `stat_melee_skill/ranged_skill/melee_defense` | `BattleManager.gd`, `CampaignManager.gd` |
| 1.3 | Авто-діалог при прибутті — `_nav_target_marker` + `_on_player_movement_stopped` | `WorldMap.gd` |
| 1.4 | TileMapLayer замість ручного `draw_polygon` — DIAMOND_DOWN 160×80, `_tile_layer.position=(0,40)` | `TacticalGrid.gd` |
| 1.5 | `has_method("start_turn")` → `is CombatUnit` — 9 місць | `CombatUnit.gd`, `UnitPanel.gd` |
| 1.6 | `EncounterDialog.tscn` — повне дерево вузлів, запечені `StyleBoxFlat` | `WorldMap.gd` |
| 1.7 | `UnitPanel.tscn` — статична оболонка (LeftCol/MidCol/RightCol, MoraleBar); `UnitPanel.gd` + `Battle.tscn` не оновлені | `UnitPanel.tscn` |
| 1.8 | `terrain_map: Dictionary[Vector2i, int]` типізовано | `TacticalGrid.gd` |
| 1.9 | Поле `morale: 100` додано до стартового загону; `_serialize_units()` зберігає мораль між боями | `CampaignManager.gd` |
| 1.10 | `AudioManager.play_music()` → `get_node_or_null` guard — бій більше не краша якщо Autoload не ініціалізований | `BattleManager.gd:43` |
| 1.11 | **Bugfix: beige screen у другому бою** — `await tw.finished` → `await create_timer(0.25).timeout` в `start_battle()` і `finish_battle()`: tween міг мовчки зависати під час переходу сцени | `CampaignManager.gd` |
| 1.12 | **Bugfix: `data_path` порожній після бою** — `resource_path` стає `""` після `.duplicate()`; `_serialize_units()` тепер читає шлях з `pre_battle_squad` через `pre.get("data_path", ...)` | `CampaignManager.gd` |
| 1.13 | **Bugfix: невидимі юніти** — `update_sprite()` додано в `CombatUnit._ready()` як захисний виклик; раніше виклик залежав виключно від `BattleManager` | `CombatUnit.gd` |

---

## 2. Фаза 1 — Progression Loop 🎯 [ПОТОЧНИЙ ФОКУС]

### 2.1 InventoryManager.gd — центральний API інвентаря ✅ ЗАВЕРШЕНО

**Чому першим:** усі панелі (магазин, лут, екіпіровка) мають іти через нього. Без нього кожна панель мутуватиме `world_state` напряму — архітектурний антипатерн.

- [x] Створити `src/core/InventoryManager.gd` як статичний клас (не autoload)
- [x] `CampaignManager` делегує всі зміни інвентаря через нього

> **Реалізовано (v1.8):** `InventoryManager.gd` створено як `class_name` без autoload. API: `add_item`, `remove_item`, `sell_item`, `equip_item`, `get_by_type`, `make_item_from_resource`. Використовує `buy_price`/`sell_price` замість єдиного `price`. Пошук юніта по `name` (не uuid — спрощення для MVP).

---

### 2.2 SaveManager v2 → v3 ✅ ГОТОВО

- [x] Додати в `world_state` поля: `squad_inventory: []`, `shop_inventory: [...]`, `day_count: 0`
- [x] Версія: `"version": 3`
- [x] Міграція: якщо завантажений save v2 — дописати відсутні поля зі значеннями за замовчуванням (не ламати стару гру)
- ~~**UUID-міграція:**~~ Скасовано — використовуємо `name` замість uuid для пошуку козаків

> **Реалізовано:** `_migrate()` у [SaveManager.gd:111-125](src/core/SaveManager.gd#L111) заповнює `squad_inventory`, `shop_inventory`, `day_count`, `armor_path`, `helm_path` для v2 save-файлів. Міграція повна.

---

### 2.3 Лікування в поселеннях ✅ ЗАВЕРШЕНО

**Тригер:** EncounterDialog для локацій типу `town` або `village`  
**Ціна:** 5 талерів/юніт → HP = max_hp

- [x] Додати кнопку "Лікувати" в `EncounterDialog.tscn` (видима тільки для town/village)
- [x] Створити `src/ui/HealingPanel.gd` / `.tscn`
- [x] Після підтвердження — викликати `CampaignManager.save_world_state()`

> **Реалізовано (v1.7+):** Вбудовано в `WorldMap._show_location_dialog()` замість окремого `HealingPanel.gd`. Ціна: 30 тал/юніт (не 5 як планувалось). Лікує весь загін одразу за один клік.

---

### 2.4 Базовий магазин ✅ ЗАВЕРШЕНО

**Тригер:** EncounterDialog для town/village — кнопка "Торгівля"  
**Асортимент:** фіксований `world_state["shop_inventory"]` (без динамічних цін)

- [x] Створити `src/ui/ShopPanel.gd` / `.tscn`
- [x] Список товарів: назва, ціна, кнопка "Купити"
- [x] "Купити" → `ws["thalers"] -= price`, `InventoryManager.add_item(ws, item)`
- [x] `ShopPanel` не знає про `world_state` напряму — тільки через `CampaignManager.world_state`

> **Реалізовано (v1.8):** Секція "Крамниця" вбудована в `_show_location_dialog()` замість окремого `ShopPanel.gd`. Товари з `world_state["shop_inventory"]`. Без ліміту стоку. Купівля через `InventoryManager.add_item()`.

**UI-структура:**
```
[Магазин]
─────────────────────────────────
Козацька шабля     80 тал.  [Купити]
Мушкет            200 тал.  [Купити]
Кольчужна байдана 150 тал.  [Купити]
Мисюрка           100 тал.  [Купити]
─────────────────────────────────
Ваші талери: 350
```

---

### 2.5 Лут після бою ✅ ЗАВЕРШЕНО

**Де генерується:** `BattleManager` збирає `loot_pool: Array[Dictionary]` при смерті ворога (30% шанс), передає в `finish_battle()`  
**Де показується:** `BattleResultScreen` — нова секція "Трофеї"

- [x] В `BattleManager._show_battle_result()`: якщо `unit.team == 1` і `randf() < 0.3` — додати зброю ворога в `loot_pool`
- [x] `CampaignManager.finish_battle(is_victory, player_units, loot_pool)` — нова сигнатура
- [x] `BattleResultScreen` отримує `loot_pool`, показує список
- [x] "Продовжити кампанію" → `finish_battle()` → `InventoryManager.add_item()` для кожного

> **Реалізовано (v1.7+/v1.8):** `BattleManager._show_battle_result()` збирає лут при перемозі (30% з мертвих ворогів). Передає через `BattleResultScreen.init()`. Використовує `InventoryManager.make_item_from_resource()`.

---

### 2.6 UI інвентаря загону ✅ ЗАВЕРШЕНО

**Де:** панель на екрані WorldMap, розгортається кнопкою або автоматично

- [x] Створити `src/ui/SquadInventoryPanel.gd` / `.tscn`
- [x] Список предметів: назва, `[⬆ Озброїти]`, `[Продати N тал.]`
- [x] "Озброїти" → екіпірує на обраного козака → `InventoryManager.equip_item()`
- [x] "Продати" → `InventoryManager.sell_item()` → оновити HUD талерів
- [x] Без drag-and-drop

> **Реалізовано (v1.8):** Вбудовано в `WorldMap.gd` замість окремого файлу. Панель праворуч (клавіша `I`): ряд козаків зверху, сітка слотів 3×3 (точний стиль `CharacterSheet.gd`), інвентар загону знизу. Клік на зайнятий слот — зняти предмет. Кнопка "Озброїти" одразу на обраного козака. "Продати" активна лише в поселенні.

---

### 2.7 Найм бійців ✅ ЗАВЕРШЕНО

**Тригер:** EncounterDialog для `town` — кнопка "Таверна"  
**Механіка:** генерується 3-5 кандидатів, показується список, ціна 100-400 тал.

- [x] Створити `src/ui/HiringPanel.gd` / `.tscn`
- [x] Генерація кандидатів — випадкові імена + стати
- [x] "Найняти" → додати в `ws["squad"]`, `ws["thalers"] -= price`
- [x] Якщо загін ≥ 8 — не показувати секцію найму

> **Реалізовано (v1.7+/v1.8):** Вбудовано в `WorldMap._show_location_dialog()`. 3 кандидати з випадковими іменами, HP, мораллю. Ціна 50-80 тал. (не 100-400 як планувалось). Трейти не реалізовані (відкладено). Дефолтна зброя — шабля. `armor_path`/`helm_path` ініціалізуються порожніми.

> **Трейти для MVP (відкладено):** `tough` (+10 hp), `brave` (+15 resolve), `quick` (+10 ini), `iron_lungs` (+15 stam), `asthmatic` (−10 stam), `craven` (−15 resolve).

---

### 2.8 Додаткові покращення (не в початковому плані) ✅

- **Мирний доступ до поселень** — `town`/`village` з нейтральною/дружньою репутацією (-19..+100) відкриваються без бою. `_is_location_hostile()` перевіряє тип локації і `cm.get_rep(faction)`. Кнопка "Атакувати" доступна з мирного діалогу
- **Підключення броні/шоломів до бою** — `BattleManager` завантажує `armor_path`/`helm_path` в `data.default_armor`/`data.default_helmet` перед `setup_from_data()`. `CampaignManager._serialize_units()` зберігає шляхи після бою
- **Дефолтна зброя при наймі** — `weapon_resource_path = saber.tres` при додаванні найманця в загін

---

## 3. Фаза 2 — Onboarding + Polish 🎯 [ПОТОЧНИЙ ФОКУС]

**Тривалість:** 4-6 тижнів (30-40 годин)  
**Мета:** Новий гравець розуміє, що робити, за 10 хвилин  
**Критерій:** Людина без досвіду проходить перший бій і першу торгівлю без питань

---

### 3.1 Tooltips ✅ ЗАВЕРШЕНО

**Реалізовано (v1.9):** Мінімалістичний підхід — тільки там, де без підказки неможливо прийняти рішення.

**Що зроблено:**
- **Навички в UnitPanel** — вже працювали через `FloatingLabel`. Оновлено `desc` для `rally`: "Перевірка моралі союзників у радіусі 4 клітинок." Решта (`recover`, `riposte`, `reload`) вже мали коректні описи
- **Кнопка "Чекати"** — додано `mouse_entered/exited` з FloatingLabel: "Пропустити хід, походити пізніше."
- **Terrain hover** — `_get_terrain_tooltip_text()` розширено числовими модифікаторами (захист %, влучність %, вартість AP та витривалості на крок). Значення взяті прямо з `_get_terrain_step_costs()` та `_get_terrain_defense_mod()` в `CombatUnit.gd`

**Що НЕ чіпалось (навмисно):**
- HP/AP/Stamina/Morale бари — очевидно з візуалу
- Талери/провізії/репутація в HUD
- Кнопки купівлі/продажу/найму — ціна і так видна
- Hover на ворога — `show_hover_intel()` вже показує всю потрібну інформацію

**Файли:** `src/ui/UnitPanel.gd`, `src/units/CombatUnit.gd`

---

### 3.2 Tutorial-бій ✅ ЗАВЕРШЕНО

**Тригер:** `world_state["tutorial_done"] == false` при першому запуску нової гри  
**Умова:** 4 козаки проти 2 бандитів, пласка карта без перешкод (всі клітинки CLEAR)

**Реалізовано (v2.2):**

- [x] `world_state["tutorial_done"] = false` у `CampaignManager.new_campaign()` — нові гри починають з tutorial
- [x] Старі збереження: `SaveManager._migrate()` додає `tutorial_done = true` (пропускають tutorial)
- [x] `CampaignManager.new_campaign()` запускає tutorial-бій замість переходу на WorldMap (`source_type: "tutorial"`, `is_tutorial: true`, 2 бандити, 50 тал. нагорода)
- [x] `TacticalGrid._ready()` — якщо `is_tutorial` → заповнює `terrain_map` тільки `CLEAR` (без WFCGenerator)
- [x] `CampaignManager.finish_battle()` — для `source_type == "tutorial"` встановлює `tutorial_done = true`, не позначає локації/загони cleared/dead
- [x] 5 покрокових підказок у `BattleManager` — панель по центру над UnitPanel, fade-in/out 0.3с

**5 кроків підказок:**

| Крок | Тригер | Текст |
|------|--------|-------|
| 1 | Перший хід козака | "Це ваш загін. Оберіть навичку атаки на панелі знизу." |
| 2 | Навичку обрано | "Тепер клікніть на ворога в зоні дії, щоб атакувати." |
| 3 | HP ворогів зменшились після дії | "Влучили! Залишились очки дій — можна рухатись або атакувати знову." |
| 4 | Хід ворога після End Turn | "Тепер ходить ворог. Спостерігайте." |
| 5 | Другий хід козака | "Ваш хід! Рухайтесь клікнувши на жовту клітинку, атакуйте ворогів." |

**Кнопка "Пропустити":** вбудована в tutorial-панель справа; викликає `cm.finish_battle(true, player_units)` → `tutorial_done = true` → WorldMap.

**Підказки в CombatLog вимкнені під час tutorial** (`_maybe_combat_hint` повертає `false` при `_is_tutorial`).

**Файли:** `src/core/CampaignManager.gd`, `src/core/SaveManager.gd`, `src/tactical/BattleManager.gd`, `src/tactical/TacticalGrid.gd`

---

### 3.3 Плаваючі підказки на глобальній карті ✅ ЗАВЕРШЕНО

**Реалізовано (v2.0):** Окрема persistent-панель `_onboarding_panel` — залишається на екрані поки гравець не виконає умову, потім зникає з fade-out.

**5 підказок і де вони зникають:**

| Ключ | Тригер появи | Умова зникнення |
|------|-------------|-----------------|
| `move` | `_ready()` якщо `day == 1`, затримка 1 сек | `_on_player_movement_started()` |
| `enemy` | `_on_party_encounter()` | `_hide_encounter_dialog()` (охоплює attack/avoid/talk) |
| `settlement` | `_show_location_dialog()` | будь-яка дія в поселенні (купівля, лікування, найм) |
| `wounded` | `_ready()` якщо козак має `hp * 2 < max_hp` | `_on_trade_heal_squad()` |
| `low_food` | `_process()` якщо `provisions <= 2 and > 0` | `_on_trade_buy_provisions()` |

**Відмінність від плану:** замість `_show_discovery_notification()` (fade через 3 сек) — окремий `_onboarding_panel` знизу по центру. Підказка тримається до виконання умови.

**Файли:** `src/ui/WorldMap.gd`

---

### 3.4 Геймплейні підказки в CombatLog ✅ ЗАВЕРШЕНО

**Де:** `CombatLog` у Battle.tscn — додаткові рядки поряд з повідомленнями про атаки  
**Коли показувати:** один раз за бій, по тригеру

| Тригер | Текст |
|--------|-------|
| Перший хід гравця | `[Підказка] Натисніть на ворога в межах зони атаки, щоб вдарити` |
| Stamina < 30% | `[Підказка] При низькій витривалості шкода і влучність падають` |
| Козак у стані "Вагається" | `[Підказка] «Вагається»: –10% влучності. Використайте Rally щоб відновити мораль` |
| Перший дальній постріл | `[Підказка] LoS: перевірте, чи не стоїть союзник на лінії вогню` |
| Перший ZoC | `[Підказка] Зона контролю: вихід із сусідньої клітинки ворога дає йому безкоштовну атаку` |

```gdscript
# BattleManager.gd
var _combat_hints_shown: Dictionary = {}

func _maybe_combat_hint(key: String, text: String) -> void:
    if _combat_hints_shown.has(key):
        return
    _combat_hints_shown[key] = true
    _add_to_log("[color=yellow][Підказка][/color] " + text)
```

> **Реалізовано (v2.1):** `_combat_hints_shown: Dictionary` + `_maybe_combat_hint(key, text) -> bool` у `BattleManager.gd`. Повертає `true` якщо підказка показана вперше — дозволяє обмежити одну підказку за хід (послідовні `if not _hint` в `start_next_unit_turn`).
>
> **5 підказок (відхилення від плану):**
> - `first_turn` — у `start_next_unit_turn()` при першому ході козака (team 0). Текст: "Клікніть на ворога в зоні атаки, щоб вдарити. ПКМ скасовує навичку."
> - `low_stamina` — у `start_next_unit_turn()` якщо `stamina < max_stamina * 0.3`. Текст: "Витривалість низька — використайте Відпочинок для відновлення."
> - `low_morale` — у `start_next_unit_turn()` якщо `current_morale >= WAVERING`. Текст: "Мораль падає! Згуртування (Rally) може допомогти."
> - `zoc` — у `CombatUnit.move_along_path()` перед opportunity attack, лише для team 0. Текст: "Вихід із зони контролю ворога дає йому безкоштовну атаку."
> - `reload` — у `CombatUnit.execute_shoot()` одразу після `is_loaded = false`, лише для team 0. Текст: "Після пострілу мушкет треба перезарядити." (замінює LoS-підказку з плану — більш пріоритетна для новачка)
>
> **Файли:** `src/tactical/BattleManager.gd`, `src/units/CombatUnit.gd`

---

### 3.5 Баланс ✅ ЗАВЕРШЕНО

**Мета:** 1 бій = 15-25 хв; гравець завжди відчуває, що грошей мало

**Параметри для калібрування:**

| Параметр | Поточне | Ціль |
|----------|---------|------|
| Нагорода за бій | ~100-200 тал. | 80-150 тал. |
| Ціна лікування | 30 тал./козак | лишити |
| Ціна провізії | 25 тал. за 5 шт. | лишити |
| Ціна найму | 50-80 тал. | підняти до 80-120 тал. |
| Ціна шаблі | 80 тал. | лишити |
| Ціна кольчуги | 100 тал. | 150 тал. |
| Дроп луту | 30% | 20-25% (менше лута = більша цінність) |

**Тест-сесія:** зіграти 3+ бої самому, записати: чи вистачає грошей? чи вмирають козаки? чи є сенс купувати?

**Чек-лист балансу:**
- [x] 1 бій триває 15-25 хв (якщо менше — AI занадто слабкий; якщо більше — занадто міцний)
- [x] Після 3 боїв гравець має мати рівно стільки грошей, щоб найняти 1 козака АБО купити 1 броню, але не обоє
- [x] Хоча б 1 козак гине в перших 5 боях (якщо ні — складність занизька)

> **Реалізовано (v1.9):** Стартові талери 150 (було 200). Нагороди за локації −20/25/30% залежно від тиру (усі 25 точок WorldGenerator). Найм 80–120 тал. (було 50–80). Броня 90–150 тал., шоломи 50–80 тал. Механіка луту: броня/шолом дропають тільки якщо стан > 50% (`body_armor * 2 > max_body_armor`). Виправлено синхронізацію кнопок навичок з `current_skill_id` (`toggle_mode = false`, кеш `_last_active_data` включає `current_skill`). Виправлено зникнення кнопки "Чекати" на деяких юнітах.

---

### 3.6 Порядок реалізації Фази 2

```
Tooltips на кнопки/стати    (2 год)   ✅
        ↓
Плаваючі підказки WorldMap  (2 год)   ✅
        ↓
Підказки в CombatLog        (1 год)   ✅
        ↓
Tutorial-бій                (5 год)   ✅
        ↓
Тест-сесія балансу          (2 год)   ✅
        ↓
Fix по результатах тесту    (2 год)   ✅
```

**Загальна оцінка:** ~14 годин = ~3 сесії по 5 годин.

---

## 4. Фаза 3 — Локалізація + Аудіо 🎯 [ПОТОЧНИЙ ФОКУС]

**Тривалість:** 4-6 тижнів (30-45 годин)  
**Мета:** Грати можуть англомовні гравці, гра звучить живою  
**Критерій завершення:** Гра запускається англійською без хардкоджених українських текстів, є фоновий трек на карті та в бою, основні SFX працюють

---

### 4.1 Система локалізації (інфраструктура) ✅ ЗАВЕРШЕНО

**Що:** CSV-файл з ключами перекладу (uk/en), Autoload для перемикання мови, збереження вибору мови.

- [x] Створити `res://localization/translations.csv` — 110 ключів (uk/en): UI, BATTLE, MAP, STAT, FACTION, MORALE, HINT, TUTORIAL, COMBAT_HINT, TERRAIN, LOC_TYPE, ENEMY
- [x] Створити `src/core/LocaleManager.gd` як Autoload — `set_language()`, `get_language()`, збереження в `user://settings.cfg`, дефолт `uk`
- [x] Зареєструвати `.translation` бінарники в `project.godot` → `[internationalization]`
- [x] Зареєструвати `LocaleManager` як Autoload в `project.godot`
- [x] Дефолтна мова: uk

> **Реалізовано (v2.6):** `localization/translations.csv` (110 ключів), `src/core/LocaleManager.gd`. У `project.godot` — `LocaleManager` в `[autoload]`, `translations.uk.translation` + `translations.en.translation` в `[internationalization]` (не сам CSV — Godot 4 завантажує скомпільовані бінарники). CSV вже проімпортований редактором.

**Оцінка:** 1 година

---

### 4.2 Витягнути тексти — бойова система ✅ ЗАВЕРШЕНО

**Що:** Замінити хардкоджені українські рядки в бойовій системі на `tr("KEY")`.

**Файли змінено:**
- [x] `BattleManager.gd` — `BATTLE_STARTED`, `BATTLE_VICTORY`, `BATTLE_DEFEAT`, `BATTLE_ROUND`, `BATTLE_UNIT_TURN` (з `TEAM_COSSACK`/`TEAM_ENEMY`), `COMBAT_HINT_FIRST/STAMINA/MORALE`, `TUTORIAL_STEP1–5`, `UI_SKIP_TUTORIAL`
- [x] `CombatUnit.gd` — `get_morale_string()` → `MORALE_*`; всі `spawn_text_fx` → `BATTLE_RECOVER/RIPOSTE/LOADED/SHOT/RALLY/INTERCEPT/FLEE/RETREAT/RETREAT_TACTICAL`; логи атак/промахів → `BATTLE_HIT/MISS` (форматування масивом); смерть → `BATTLE_DEATH`; `BATTLE_MISS_SHORT` в `show_miss_fx`; підказки → `COMBAT_HINT_ZOC/RELOAD`
- [x] `UnitPanel.gd` — `STAT_HP/AP/STAMINA/ARMOR/HELMET` у барах; `UI_SKILLS` у заголовку; `UI_WAIT` + `UI_WAIT_TOOLTIP` у кнопці "Чекати"; `_style_morale_label()` виправлено на перевірку `tr("MORALE_*")` замість hardcoded рядків
- [x] `CharacterSheet.gd` — `STAT_LEVEL`; слоти (`SLOT_TRINKET/AMMO/SHIELD/BELT`, `STAT_HELMET/ARMOR`); `STAT_MORALE`; всі 6 барів статів; всі 6 рядків combat grid
- `BattleResultScreen.gd` — перевірено, немає хардкоджених рядків що потребують локалізації
- `TurnQueueUI.gd` — перевірено, немає хардкоджених рядків

**Нові ключі додано до CSV (11 шт.):** `UI_SKILLS`, `UI_WAIT_TOOLTIP`, `BATTLE_MISS_SHORT`, `BATTLE_HEADSHOT`, `BATTLE_RETREAT_TACTICAL`, `SLOT_TRINKET`, `SLOT_AMMO`, `SLOT_SHIELD`, `SLOT_BELT`, `STAT_MORALE`

**Не чіпалось (навмисно):**
- Назви козаків та ворогів — власні імена
- Hover intel panel (`_update_intel_text`) — поза scope задачі
- Debug `print()` виклики

**Оцінка:** 4 години

---

### 4.3 Витягнути тексти — глобальна карта ✅ ЗАВЕРШЕНО

**Що:** Замінити хардкоджені рядки на карті на `tr("KEY")`.

**Файли змінено:**
- [x] `WorldMap.gd` — TopBar: `UI_DAY`, `FACTION_CROWN/SICH/ORDA`, `UI_PAUSE`; speed tooltips: `UI_PAUSE/SPEED_NORMAL/SPEED_FAST`; діалог поселення: `MAP_TRADE/SHOP/HIRING/HEALING/ALL_HEALTHY/INJURED/PROVISIONS/SETTLEMENT_OPEN/LOCATION_CLEARED`; кнопки: `UI_ATTACK/LEAVE`; дезертирство: `MAP_DESERTED`; інвентар: `UI_SQUAD/EQUIPMENT/INVENTORY` (з `.to_upper()`), `UI_INVENTORY_EMPTY`, `UI_EQUIP`, слоти обладнання через `SLOT_*/STAT_*`; item type: `SLOT_WEAPON.to_lower()/STAT_ARMOR.to_lower()/STAT_HELMET.to_lower()`; onboarding: `HINT_MOVE/ENEMY/SETTLEMENT/WOUNDED/LOW_FOOD`
- [x] `EncounterDialog.gd` — `ENCOUNTER_REWARD` (новий ключ)
- [x] `MainMenu.gd` — `UI_NEW_GAME`, `UI_CONTINUE`, `UI_EXIT`
- `LocationMarker.gd` — перевірено, немає хардкоджених рядків що потребують локалізації

**Нові ключі додано до CSV (2 шт.):** `SLOT_WEAPON`, `ENCOUNTER_REWARD` (всього в CSV: 123 ключі)

**Не чіпалось (навмисно):**
- Кнопки `EncounterDialog.tscn` (Атакувати/Уникнути/Говорити) — текст вузлів у `.tscn`, потребує Godot Translation Remap або встановити в `_ready()`
- `"Козака не обрано"`, `"Стати невідомі"` — технічні fallback рядки, поза scope
- `"Продаж лише в поселеннях"` — tooltip, поза scope
- Debug `print()`, назви козаків та міст — власні назви

**Оцінка:** 3 години

---

### 4.4 Назви локацій та юнітів ✅ ЗАВЕРШЕНО

**Що:** Назви міст, сіл, ворогів — чи перекладати?

**Рішення для MVP:**
- Назви локацій (Суботів, Чигирин, Бахчисарай) — НЕ перекладати, це власні назви
- Типи локацій (Розбійничий табір, Татарський кіш) — перекладати через `tr()`
- Назви козаків (Ничипір, Гаврило) — НЕ перекладати
- Типи ворогів (Бандит, Татарин) — перекладаються через наявні `ENEMY_*` ключі (UnitData.tres не чіпали)

- [x] Додати ключі для типів локацій в CSV (10 нових + 5 CLEARED_* + 4 FACTION_*_PLURAL)
- [x] В `WorldGenerator.gd` — всі 13 типових назв замінено на `tr()`
- [x] В `WorldMap.gd` — `_cleared_desc()` і `_faction_label()` повністю через `tr()`

> **Реалізовано (v2.9):** У `WorldGenerator.gd` 13 хардкоджених типових назв локацій (Розбійничий табір, Занедбані руїни, Покинута пасіка, Печера розбійників, Татарський кіш, Ставка мурзи, Скіфська могила, Козацький цвинтар, Татарський дозор, Прикордонний форпост, Фортеця, Зруйнований костел, Яр язичників) замінено на `tr()`. Власні назви (Чигирин, Київ, Бахчисарай тощо) — без змін. У `WorldMap.gd` функції `_cleared_desc()` і `_faction_label()` переведено на `tr()`. До `translations.csv` додано 20 нових ключів (всього ~143).

**Файли:** `localization/translations.csv`, `src/core/WorldGenerator.gd`, `src/ui/WorldMap.gd`

**Оцінка:** 1 година

---

### 4.5 Перемикач мови в UI ✅ ЗАВЕРШЕНО

**Що:** Dropdown або кнопка для зміни мови в MainMenu або в окремому екрані налаштувань.

- [x] Додати dropdown мови в MainMenu: Українська / English (OptionButton після кнопки "Вийти")
- [x] При зміні — `LocaleManager.set_language()`, оновити тексти кнопок через `_update_button_texts()`
- [x] Мова зберігається між сесіями (`user://settings.cfg`) — через наявний `LocaleManager`
- [x] Поточне значення встановлюється в `_ready()` з `LocaleManager.get_language()`

> **Реалізовано (v3.0):** `_make_lang_option()` — OptionButton зі стилем під гру (bg `Color(0.12, 0.11, 0.08)`, border `Color(0.48, 0.38, 0.13)`, текст `Color(0.85, 0.8, 0.6)`, font_size 15). `_update_button_texts()` — оновлює `tr()` для Нова гра / Продовжити / Вийти. Додано ключ `UI_LANGUAGE` в CSV. Instance vars `_btn_new/_btn_continue/_btn_quit` зберігають посилання на кнопки.

**Файли:** `localization/translations.csv`, `src/ui/MainMenu.gd`

**Оцінка:** 1 година

---

### 4.6 Шрифти ✅ ЗАВЕРШЕНО

**Що:** Встановити Kelly Slab як глобальний шрифт за замовчуванням для всього проекту.

- [x] Знайдено `assets/fonts/KellySlab-Regular.ttf` (вже був у проекті)
- [x] Встановлено як дефолтний шрифт через `project.godot` → секція `[gui]`
- [x] Встановлено дефолтний розмір 16px
- [x] Видалено зайві `add_theme_font_override("font", load(KellySlab))` в BattleManager.gd, LoadingScreen.gd, TacticalGrid.gd — тепер використовується глобальний
- [x] RuslanDisplay залишено тільки для заголовку MainMenu (навмисно)
- [x] **Native Theme Resource** `assets/theme/game_theme.tres` — Kelly Slab + `Label/colors/font_color=#585551`; встановлено через `project.godot [gui] theme/custom=`. Видалено ~25 зайвих `add_theme_font_size_override(prop, 16)` та всі `add_theme_font_override("font", KellySlab)` з 9 файлів

> **Реалізовано (v3.0):** `project.godot` → `[gui]`: `theme/default_font`, `theme/default_font_size=16`. Kelly Slab підтримує кирилицю і латиницю.
>
> **Доопрацьовано (v4.3 — 09.06.2026):** Створено `assets/theme/game_theme.tres` — нативний Godot Theme ресурс. `project.godot` → `theme/custom=`. `Label/colors/font_color = Color(0.345098, 0.333333, 0.317647, 1)` (#585551) каскадується на всі Label без override в коді. Прибрано `_font_button`/`FONT_BUTTON` з `MainMenu.gd`, `_top_bar_root` font override з `WorldMap.gd`. Видалено ~25 зайвих `add_theme_font_size_override(prop, 16)` з CombatLog, TurnQueueUI, BattleResultScreen, UnitPanel, MainMenu, WorldMap, CharacterSheet, BattleManager, CombatUnit.

**Файли:** `project.godot`, `assets/theme/game_theme.tres`, `src/ui/MainMenu.gd`, `src/ui/WorldMap.gd`, `src/ui/CombatLog.gd`, `src/ui/TurnQueueUI.gd`, `src/ui/BattleResultScreen.gd`, `src/ui/UnitPanel.gd`, `src/ui/CharacterSheet.gd`, `src/tactical/BattleManager.gd`, `src/units/CombatUnit.gd`

**Оцінка:** 0.5 год + 1 год (v4.3)

---

### 4.7 Залишкові непереведені тексти ✅ ЗАВЕРШЕНО

**Що:** Після 4.1–4.6 залишились непереведені тексти в навичках, CharacterSheet, TurnQueueUI, MainMenu, WorldMap, WorldGenerator та CampaignManager.

- [x] **MainMenu.gd** — назва гри `tr("GAME_TITLE").replace(" ", "\n")` (ключ: `GAME_TITLE`)
- [x] **UnitPanel.gd** — `tr(weapon.name)`, `tr(skill.name)`, `tr(raw_desc)`, типи шкоди через `DAMAGE_*`, tooltip-формати через `SKILL_TOOLTIP_*`
- [x] **CharacterSheet.gd** — `tr(origin_name)`, `tr(origin_bonus)`, `tr("ORIGIN_UNKNOWN")`
- [x] **WorldMap.gd** — discovery: `tr("MAP_DISCOVERED") % loc_name_str`; рекрути: `tr(pool[i])`
- [x] **TurnQueueUI.gd** — `tr("BATTLE_ROUND") % round_num` (замість хардкодженого "РАУНД %d")
- [x] **TacticalGrid.gd** — `tr("MAP_OPEN_FIELD")` для туторіалу; `tr(WFCGenerator.LOCATION_NAMES[...])` для WFC
- [x] **BattleManager.gd** — `btn.text = "🏁 " + tr("UI_END_TURN")` у `_style_end_turn_button()`
- [x] **WorldGenerator.gd** — `tr()` для 12 власних назв міст/сіл + 3 назви біомів (`Ліси/Дике Поле/Кордон`)
- [x] **CampaignManager.gd** — `tr(data.unit_name)` для стартових козаків

> **Реалізовано (v3.1):** До `translations.csv` додано ~130 нових ключів (~275 рядків загалом). Нові групи ключів: назви та описи навичок (22+22), назви зброї (13), типи шкоди (5), tooltip-формати (4), origin-назви/бонуси (10+10), WFC-локації та біоми (7), власні назви міст з транскрипцією (12), імена козаків (4), імена рекрутів (25). Ключ = українська назва (з .tres або hardcode) — без змін .tres файлів.

**Файли (v3.1):** `localization/translations.csv`, `src/ui/MainMenu.gd`, `src/ui/UnitPanel.gd`, `src/ui/CharacterSheet.gd`, `src/ui/WorldMap.gd`, `src/ui/TurnQueueUI.gd`, `src/tactical/TacticalGrid.gd`, `src/tactical/BattleManager.gd`, `src/core/WorldGenerator.gd`, `src/core/CampaignManager.gd`

**Оцінка:** 2 години

---

### 4.7+ Grep-аудит непереведених рядків ✅ ЗАВЕРШЕНО (v3.2)

**Що:** Повний `grep -P '"[^"]*[а-яА-ЯіІїЇєЄґҐ][^"]*"'` по всіх `.gd` файлах. Знайдено і виправлено рядки, пропущені при ручному перегляді v3.1.

- [x] **TacticalGrid.gd** — `"ОД"` у підказці шляху → `tr("UI_AP_SHORT")`
- [x] **WorldMap.gd** — час доби, `"Рівень"`, `"Стати невідомі"`, 3 стат-рядки, `"Козака не обрано"`, назви товарів у крамниці/інвентарі, `"Продаж лише в поселеннях"`, `"Зустріч"`, `"М:%d%%"`
- [x] **UnitPanel.gd** — назви зброї legacy (Шабля/Мушкет/Бердиш), `"Мертвий"`, `"Зброя: %s"`, стійка/шанс/вогонь; terrain tooltips (повний опис); bugfix `"Чекати" in btn.text` → `tr("UI_WAIT")`
- [x] **BattleResultScreen.gd** — **повністю переведено** (до v3.2 некоректно відмічено "без hardcode"): ПЕРЕМОГА/ПОРАЗКА, кнопки, лут, талери, травми, рівень, стати
- [x] **CharacterSheet.gd** — weapon/slot tooltips, `_get_weapon_resource_tooltip`, `_get_weapon_tooltip`
- [x] **BattleManager.gd** — `[Підказка]`, кінець раунду, `"Ворог"` fallback
- [x] **CombatUnit.gd** — level up fx, паніка від втечі/смерті, дружній вогонь у лог
- [x] **CameraController.gd** — `"Зум: x%s"` → `tr("UI_ZOOM_FORMAT")`
- [x] **LoadingScreen.gd** — `"Завантаження битви..."` → `tr("LOADING_BATTLE")`

> **Реалізовано (v3.2):** +78 нових ключів у CSV (357 рядків загалом). Grep по кирилиці повертає 0 UI-рядків. Детальніше: [LOCALIZATION_PLAN.md §11](docs/07_TECHNICAL/LOCALIZATION_PLAN.md)

**Файли (v3.2):** `localization/translations.csv` (+78), `src/tactical/TacticalGrid.gd`, `src/ui/WorldMap.gd`, `src/ui/UnitPanel.gd`, `src/ui/BattleResultScreen.gd`, `src/ui/CharacterSheet.gd`, `src/tactical/BattleManager.gd`, `src/units/CombatUnit.gd`, `src/tactical/CameraController.gd`, `src/ui/LoadingScreen.gd`

---

### 4.8 Аудіо — фонові треки ✅ ЗАВЕРШЕНО (v3.4)

**Що:** 2 зациклених треки: глобальна карта (спокійний) та бій (напружений).

- [x] `AudioManager.gd` (Autoload) — crossfade 1.5s, зберігає гучність у settings.cfg
- [x] Audio Buses "Music"/"SFX" → "Master" — створюються динамічно
- [x] `MainMenu._ready()` → `AudioManager.play_music("map")`
- [x] `WorldMap._ready()` → `AudioManager.play_music("map")`
- [x] `BattleManager._ready()` → `AudioManager.play_music("battle")`
- [x] Crossfade 1.5s між треками (Tween на volume_db)
- [x] **Створити `assets/audio/music/map_theme.wav`** — ✅ додано, ім�

### 4.5.5 Глобальна карта — процедурна географія та зони впливу ⬜

**Що:** Повна відмова від візуальних триколірних смуг («біомів»). Замість них — генерація природного ландшафту з окремими елементами (лісові масиви, пагорби, болота біля річок, яри, кургани) та створення невидимих (логічних) сфер впливу фракцій.

#### 1. Типи ландшафту на глобальній карті:
* **Степ (Steppe / Grassland):** Базове тло карти (теплий трав'янисто-піщаний або пергаментний колір, напр. `#F6F0DA` або текстура степу). Найвища швидкість руху, нормальний огляд.
* **Лісові масиви (Forest patches):** Процедурно згенеровані плями дерев (групи іконок або текстуровані зони). Сповільнюють рух на 30%, обмежують дальність огляду (коефіцієнт `0.7`).
* **Пагорби (Hills):** Ланцюги пагорбів (спрайти або ізометричні холмики). Рух сповільнюється на 40%, але при зупинці на пагорбі радіус огляду (Fog of War) збільшується на `1.2x`.
* **Плавні / Болота (Swamps):** Вологі зони навколо річок та озер. Сильне уповільнення руху (на 50%), підвищений ризик засідок бандитів.
* **Яри / Балки (Ravines):** Природні глибокі тріщини в степу. Повністю непрохідні (потребують обходу) або сильно уповільнюють рух; ідеальні точки засідок для бандитів.
* **Кургани (Kurgans):** Поодинокі стародавні могили в степу. Дають значний бонус до огляду (`1.5x` радіус відкриття туману війни) при знаходженні на них.

#### 2. Невидимі зони впливу (Geopolitical Spheres of Influence):
* На карті більше немає яскравих кольорових підкладок під фракціями. Візуально карта виглядає як природна географічна мапа.
* **Логіка зон:** Світ ділиться на три логічні сектори (Захід — Корона, Центр — Січ, Схід/Південь — Кримське Ханство) або на основі близькості до найближчого міста фракції.
* **Поведінка ШІ та патрулів:** Спавн і логіка ворожих партій (Орда патрулює степ, застави Корони охороняють захід) прив'язані до цих невидимих зон.
* **Зворотний зв'язок гравцеві:** Не робимо штучних текстових банерів чи нотифікацій. Належність території гравець розуміє природним шляхом за кольорами, назвами та зовнішнім виглядом (в майбутньому прапорами) найближчих міст та сіл.

#### 3. Інтеграція:
* **`WorldGenerator.gd`:**
  * Переписати `_gen_biomes()` та логіку ландшафту: генерувати масиви лісу (`forest_patches`), пагорбів (`hill_patches`), боліт (`swamp_patches`), курганів та ярів через шум (Perlin Noise / Value Noise) або випадкові скупчення точок.
  * Зберегти логічні зони впливу у `world_state` (наприклад, `state["influence_map"]` або зберегти X-кордон як константу).
* **`WorldMap.gd`:**
  * Оновити `_render_biomes()`: рендерити базовий степ + накладати текстурні маски або спрайти для лісів, пагорбів, боліт, ярів та курганів. Прибрати фонові кольорові прямокутники біомів.
  * Оновити `_get_biome_at(pos)`: визначати тип місцевості під гравцем (степ/ліс/пагорб/болото/яр/курган) за координатами generated patches для розрахунку швидкості та огляду.

**Оцінка:** 12 годин (код 6 + дизайн/арт 6)�ї польоту)
  - `CombatUnit.die()` → `"death"` (після `is_dead = true`)
  - `CombatUnit.gain_xp` → `"level_up"` (після `level += 1`)
  - `WorldMap._on_trade_buy_provisions` → `"buy"`
  - `WorldMap._on_buy_shop_item` → `"buy"`
  - `WorldMap._on_trade_heal_squad` → `"heal"`
  - `WorldMap._on_hire_recruit` → `"hire"`
  - `WorldMap._show_discovery_notification` → `"notification"`
  - `MainMenu` btn_new / btn_continue / `_open_settings` → `"ui_click"`
- [x] **Створити SFX файли** (`.wav`) у `assets/audio/sfx/` — ✅ всі 9 файлів додано і імпортовано Godot

> **Реалізовано (v3.3):** AudioManager.play_sfx() готовий.
> **Реалізовано (v3.5):** 10 викликів play_sfx() підключені в коді.
> **Реалізовано (v3.6):** `"heal"`, `"hire"`, `"notification"` додані в `SFX` dict. Всі 9 `.wav` файлів наявні і імпортовані. SFX система повністю готова.

**Оцінка:** ✅ ЗАВЕРШЕНО — Код + Файли + Підключення.

---

### 4.10 Меню налаштувань ✅ ЗАВЕРШЕНО (v3.3)

**Що:** Базове меню з регуляторами гучності та вибором мови.

- [x] Кнопка "Налаштування" в MainMenu (між "Продовжити" та "Вийти")
- [x] Модальна панель: димер + CenterContainer + PanelContainer зі стилем гри
- [x] HSlider Music Volume (0–100%), золотий стиль, live-preview "%d%%" у label
- [x] HSlider SFX Volume (0–100%), той самий стиль
- [x] Dropdown мови (перенесено з основних кнопок у Settings)
- [x] Кнопка "Закрити" + клік поза панеллю закриває
- [x] Збереження гучності в `user://settings.cfg` (секція `[audio]`) через `AudioManager`
- [x] Всі тексти через `tr()` — оновлюються при зміні мови (`_update_settings_texts()`)

> **Реалізовано (v3.3):** `_build_settings_overlay()`, `_open_settings()`, `_update_settings_texts()`, `_style_slider()`, `_make_circle_texture()` у `MainMenu.gd`. Мовний dropdown переміщено зі старої позиції після кнопки "Вийти" в Settings.

**Файли:** `src/ui/MainMenu.gd`

---

### 4.11 Порядок реалізації Фази 3

```
Система локалізації (CSV + LocaleManager)   (1 год)   ✅
        ↓
Витягнути тексти — бій                      (4 год)   ✅
        ↓
Витягнути тексти — карта                    (3 год)   ✅
        ↓
Назви локацій/ворогів                       (1 год)   ✅
        ↓
Шрифти (Kelly Slab глобально)               (0.5 год) ✅
        ↓
Перемикач мови → переміщено в Settings     (1 год)   ✅
        ↓
Залишкові тексти (grep-аудит)              (2 год)   ✅
        ↓
AudioManager + Settings menu               (2 год)   ✅ (v3.3)
        ↓
Аудіо файли (map_theme + battle_theme)     (?)       ✅ (v3.4)
        ↓
SFX підключення у коді                     (1 год)   ✅ (v3.5)
```

**Загальна оцінка:** ~21.5 годин коду ✅ + створення аудіо контенту (на Андрії).

---

## 4.5. Фаза 3.5 — Візуальне наповнення 🎯 [ПОТОЧНИЙ ФОКУС]

**Тривалість:** 4-6 тижнів (30-50 годин)
**Мета:** Гра виглядає як готовий продукт, а не прототип. Скріншоти придатні для Steam-сторінки.
**Критерій завершення:** Юніти мають спрайти, карта має текстури, інвентар має іконки. Жодних кольорових ромбів і емодзі.

---

### 4.5.1 Спрайти юнітів у бою ✅ ЗАВЕРШЕНО

**Що:** Замінити кольорові ромби (Polygon2D) на ізометричні спрайти юнітів.

**Мінімальний набір:**
- [x] Козак з шаблею (дефолтний)
- [x] Козак з мушкетом
- [x] Козак зі списом
- [x] Бандит (2 варіанти)
- [x] Татарин (2 варіанти: легкий, важкий)
- [x] Яничар
- [x] Реєстровий козак

**Джерела:** itch.io (isometric RPG sprite packs), Fiverr (кастомні), AI генерація + ручна доробка

**Інтеграція:**
- [x] Замінити Polygon2D в CombatUnit.create_visual_placeholder() на Sprite2D
- [x] Спрайти залежать від імені юніта (козаки) та resource_path/unit_name (вороги)
- [x] Анімації: idle, attack, walk, death (мінімум idle + death) — відкладено після фінального арту
- [x] Розмір спрайту: ~120×120px — scale=0.7, offset=(0,−30)

**Оцінка:** 10 годин (код 3 + арт 7) — **✅ повністю завершено (v3.9)**

> **Зроблено (v3.8):** Папку `assets/sprites/units/` створено. 14 placeholder PNG файлів (валідні 1×1 px, Godot може імпортувати):
> - Козаки: `nychypir_front/back`, `havrylo_front/back`, `tymofiy_front/back`, `panko_front/back`
> - Вороги: `bandit_front/back`, `tatar_front/back`, `janissary_front/back`

> **Зроблено (v3.9):** Код інтеграції `CombatUnit.gd` + `BattleManager.gd` повністю реалізовано. Всі 14 фінальних PNG (7 юнітів × 2 ракурси) додані в `assets/sprites/units/` та працюють у грі.

---

### 4.5.2 Портрети юнітів ✅ ЗАВЕРШЕНО

**Рішення:** Окремі портрети не створюємо — використовуємо спрайти юнітів (`*_front.png`).

`CombatUnit.get_portrait()` вже має правильний fallback-ланцюг:
1. `portrait_override` (якщо виставлений в сцені)
2. `data.portrait` (якщо є в .tres)
3. `_sprite_front` — текстура фронтального спрайта ← використовується автоматично
4. placeholder SVG

Окремий арт для портретів не потрібен. Задача закрита.

---

### 4.5.3 Іконки предметів ✅ ЗАВЕРШЕНО

**Що:** Замінити емодзі (⚔️🛡️🪖) на іконки в інвентарі, CharacterSheet, магазині.

**Мінімальний набір:**
- [x] Шабля, мушкет, спис, бойовий молот, бойова сокира, кинджал, лук
- [x] Кольчуга, жупан, кіраса
- [x] Шолом, мисюрка, кучма, шапка
- [x] Fallback на емодзі при відсутньому файлі іконки

**Інтеграція:**
- [x] `InventoryManager.ITEM_ICONS` — маппінг `item_id → res://assets/sprites/icons/*.png`
- [x] `InventoryManager.get_item_icon(item_id) -> Texture2D` — повертає `null` якщо файл не існує
- [x] `CharacterSheet._equipment_slot()` — квадратний `TextureRect` розміром `min(p_size.x−20, p_size.y−50)`, центрований; назва з `AUTOWRAP_WORD_SMART` і `custom_minimum_size.x = p_size.x−10`; інакше Label з емодзі
- [x] `WorldMap` сітка слотів — `TextureRect` динамічний `SIZE_EXPAND_FILL` (стиль CharacterSheet: `minf(p_x−10, p_y−50)`), назва в `MarginContainer 5px`
- [x] `WorldMap` список інвентарю — іконка `24×24` перед назвою предмета
- [x] `WorldMap` крамниця — іконка `32×32` перед назвою товару
- [x] `BattleResultScreen` лут — `TextureRect 56×56` якщо є іконка (назва через `FloatingLabel` при hover); емодзі + текст якщо іконки немає
- [x] Папка `assets/sprites/icons/` створена — очікує PNG-файли 48×48

> **Реалізовано (v4.0):** Без зміни структури item-словників і без нових полів у .tres. Маппінг виключно через `ITEM_ICONS` по `item["id"]`. `get_item_icon()` перевіряє `ResourceLoader.exists()` перед `load()` — гра не падає при відсутніх файлах. CharacterSheet отримує item_id через `weapon_resource.resource_path`, `armor_path`, `helm_path`.

> **UI polish (v4.0.1 — 08.06.2026):** Іконки у слотах CharacterSheet збільшені до квадратного розміру слоту. WorldMap сітка слотів: 32×32 → 48×48. Назва предмета в слоті CharacterSheet тепер переноситься по словах. BattleResultScreen лут-слот: 32×32 → 56×56, назва у FloatingLabel hover.

> **UI polish (v4.0.2 — 08.06.2026):** `InventoryManager.ITEM_ICONS` доповнено 3 маппінгами для товарів крамниці (`padded_zhupan`, `leather_lamellar`, `shlyk`). WorldMap крамниця: іконка 24×24 → 32×32. WorldMap сітка слотів: динамічний `SIZE_EXPAND_FILL` замість фіксованих 48×48, MarginContainer 5px для тексту — стиль ідентичний CharacterSheet. WorldMap секція ЗАГІН: `HBoxContainer` → `GridContainer (3 кол.)`, кнопки з портретом-спрайтом 40×40 + ім'ям.

> **UI polish (v4.0.3–4.0.5 — 08.06.2026):** Фінальна доробка кнопок козаків і слотів:
> - Видалено `btn.flat = true`; `bg_color = Color(0.1, 0.09, 0.07)`; неактивний border `Color(0.45, 0.35, 0.12)`
> - Кнопки козаків: `GridContainer (3 кол.)` → `VBoxContainer`. Кожна кнопка горизонтальна (`SIZE_EXPAND_FILL`, висота 48): `HBoxContainer` → `TextureRect 40×40` + `Label font_size 14 vertical_center`
> - Слоти спорядження в WorldMap тепер мають розміри відповідно до рядка сітки: Ряд 1/3 → `100×100`, Ряд 2 → `100×180` — ідентично `CharacterSheet._equipment_slot()`

**Оцінка:** 5 годин (код 2 + арт 3) — **✅ код завершено (v4.0.5)**

---

### 4.5.4 Тайли місцевості в бою ✅ КОД ЗАВЕРШЕНО

**Що:** Замінити кольорові ромби на текстуровані тайли для бойової карти.

**Мінімальний набір:**
- [x] Трава/степ (дефолт) — `tile_grass.png`
- [x] Чагарники — `tile_bushes.png`
- [x] Болото — `tile_swamp.png`
- [x] Каміння — `tile_rocks.png`
- [x] Дерева (перешкода) — `tile_trees.png`
- [x] Вода/брід — `tile_water.png`

**Джерела:** itch.io (isometric tileset), OpenGameArt.org

**Інтеграція:**
- [x] `TERRAIN_TEXTURES` константа в `TacticalGrid.gd` — маппінг `terrain_type int → res://assets/sprites/tiles/*.png`
- [x] `_setup_tile_layer()` — `ResourceLoader.exists()` перевірка → `load(tex_path)` або `_make_diamond_texture()` як fallback
- [x] CLEAR/трава тепер теж рендериться якщо `tile_grass.png` існує (раніше не рендерувалась взагалі)
- [x] Папка `assets/sprites/tiles/` створена — очікує PNG 160×80px
- [x] Fallback на кольоровий ромб якщо PNG відсутній — гра не падає

**Оцінка:** 6 годин (код 2 + арт 4) — **✅ код завершено (v4.1), потрібен арт**

> **Реалізовано (v4.1 — 08.06.2026):** `TacticalGrid.gd` — додана константа `TERRAIN_TEXTURES` перед `_setup_tile_layer()`. Метод перебирає всі 6 terrain-типів (включно з CLEAR), для кожного перевіряє `ResourceLoader.exists(tex_path)` і або завантажує PNG, або генерує `_make_diamond_texture(color)`. Цикл заповнення клітинок тепер рендерить CLEAR-тайли якщо `tile_grass.png` наявний. Без змін у `_draw()`, `terrain_map`, логіці A\*.

---

### 4.5.5 Глобальна карта — процедурна географія та зони впливу ⬜

**Що:** Повна відмова від візуальних триколірних смуг («біомів»). Замість них — генерація природного ландшафту з окремими елементами (лісові масиви, пагорби, болота біля річок) та створення невидимих (логічних) сфер впливу фракцій.

#### 1. Нові типи ландшафту на глобальній карті:
* **Степ (Steppe / Grassland):** Базове тло карти (теплий трав'янисто-піщаний або пергаментний колір, напр. `#F6F0DA` або текстура степу). Найвища швидкість руху, нормальний огляд.
* **Лісові масиви (Forest patches):** Процедурно згенеровані плями дерев (групи іконок або текстуровані зони). Сповільнюють рух на 30%, обмежують дальність огляду (коефіцієнт `0.7`).
* **Пагорби / Холми (Hills):** Ланцюги пагорбів (спрайти або ізометричні холмики). Рух сповільнюється на 40%, але при зупинці на пагорбі радіус огляду ( Fog of War) збільшується на `1.2x`.
* **Плавні / Болота (Swamps):** Вологі зони навколо річок та озер. Сильне уповільнення руху (на 50%), підвищений ризик засідок бандитів.

**Додаткові пропозиції (для обговорення):**
* **Яри / Балки (Ravines):** Природні глибокі тріщини в степу. Повністю непрохідні (потребують обходу) або сильно уповільнюють рух; ідеальні точки засідок для бандитів.
* **Кургани (Kurgans):** Поодинокі стародавні могили в степу. Дають значний бонус до огляду (`1.5x` радіус відкриття туману війни) при знаходженні на них.

#### 2. Невидимі зони впливу (Geopolitical Spheres of Influence):
* На карті більше немає яскравих кольорових підкладок під фракціями. Візуально карта виглядає як природна географічна мапа.
* **Логіка зон:** Світ ділиться на три логічні сектори (наприклад, за координатою X: Захід — Корона, Центр — Січ, Схід/Південь — Кримське Ханство) або на основі близькості до найближчого міста фракції.
* **Поведінка ШІ та патрулів:** Спавн і логіка ворожих партій (Орда патрулює степ, застави Корони охороняють захід) прив'язані до цих невидимих зон.
* **Зворотний зв'язок гравцеві:** При вході в зону на екрані на короткий час з'являється плавна текстова підказка/нотифікація (наприклад, *"Територія Війська Запорозького"* або *"Володіння Корони"*), або це відображається дрібним шрифтом біля годинника.

#### 3. Інтеграція:
* **`WorldGenerator.gd`:**
  * Переписати `_gen_biomes()`: замінити фіксовані прямокутники на генерацію масивів лісу (`forest_patches`) та пагорбів (`hill_patches`) через шум (Perlin Noise / Value Noise) або випадкові скупчення точок.
  * Зберегти логічні зони впливу у `world_state` (наприклад, `state["influence_map"]` або зберегти X-кордон як константу).
* **`WorldMap.gd`:**
  * Оновити `_render_biomes()`: рендерити базовий степ + накладати текстурні маски або спрайти для лісів та пагорбів. Прибрати фонові кольорові прямокутники біомів.
  * Оновити `_get_biome_at(pos)`: визначати тип місцевості під гравцем (степ/ліс/пагорб/болото) за координатами generated patches для розрахунку швидкості та огляду.
  * Додати визначення поточної невидимої фракційної зони та відображати її назву в HUD.

**Оцінка:** 12 годин (код 6 + дизайн/арт 6)

---

### 4.5.6 UI polish 🔄 В ПРОЦЕСІ

**Що:** Загальна стилізація UI під козацьку тематику.

- [x] **TopBar глобальної карти — Figma-дизайн** (3 пергаментні панелі) — ✅ v4.2
- [ ] Фон головного меню (вже є ілюстрація з козаками — перевірити)
- [ ] Стилізовані кнопки (дерев'яна/шкіряна текстура замість плоских)
- [ ] Рамки панелей (орнамент замість простих ліній)
- [ ] Курсор (козацький стиль — шабля або перо)

**Оцінка:** 5 годин

### TODO: Синхронізація розмірів UI між Figma і Godot

Проблема: Godot рахує висоту шрифту інакше ніж Figma (font_size 18 в Figma = 18px, в Godot = 26px через ascent/descent/line_spacing). Це ламає padding і висоти панелей в усьому UI.

- [ ] Визначити реальні висоти Kelly Slab в Godot для кожного font_size (12, 13, 14, 15, 16, 18, 20, 26)
- [ ] Скласти таблицю відповідності: Figma font_size → Godot font_size → реальна висота в px
- [ ] Оновити ВСІ макети в Figma з реальними висотами (або підібрати font_size в Godot під Figma)
- [ ] Застосувати до ВСЬОГО UI: TopBar, інвентар, діалоги поселень, BattleResultScreen, UnitPanel, CharacterSheet, TurnQueueUI, MainMenu, tutorial панель, onboarding підказки
- [ ] Перевірити що padding і висоти панелей збігаються з Figma після виправлення

---

### 4.5.8 TopBar глобальної карти — Figma-дизайн ✅ ЗАВЕРШЕНО (v4.2–v4.6)

**Що:** Переробити суцільний темний TopBar на три окремі пергаментні панелі відповідно до Figma-макету.

**Що зроблено:**
- [x] Три `PanelContainer` на `Control (PRESET_TOP_WIDE, h=68px)`: ліва (фаза + ресурси), центральна (швидкість), права (репутація + інвентар)
- [x] Кольори з Figma: фон `#F6F0DA`, рамка/текст `#585551`; corner BR=16 (ліва), BL/BR=32 (центр), BL=16 (права)
- [x] **Виправлено дублювання іконки доби**: `tr("TIME_DAY")` = `"☀️ День"` — видалено окремий `_time_phase_icon`, залишено `_time_phase_label` як один Label
- [x] Колір тексту фази доби — статичний `#585551` (без кольорових overrides по фазах) — відповідно до Figma
- [x] Центральна і права панелі: `content_margin_top/bottom = 12px`; ліва — `15px` (скориговано для компенсації font metrics)
- [x] Кнопки швидкості: PauseButton 32×32, PlayButton 32×32, ForwardButton 40×32
- [x] **SVG іконки паузи з Figma** (v4.4): три файли `assets/sprites/ui/speed_pause_*.svg`
- [x] **TextureButton + 9 SVG Figma** (v4.5): `Button+TextureRect → TextureButton`; `speed_play/fwd_*.svg`; radio-group через `_apply_speed_btn_state()`
- [x] **Висота 56px для всіх трьох панелей** (v4.6): ліва `margin 15px`, inventory wrapped у `Control(32×32)` → 15+26+15=56, 12+32+12=56

**Файл:** `src/ui/WorldMap.gd` — `_build_top_bar()`, `_build_speed_panel()`, `_refresh_speed_btns()`, `_apply_speed_btn_state()`, `_make_speed_tex_btn()`, `_debug_topbar_heights()`

---

### 4.5.9 Порядок реалізації Фази 3.5

```
Спрайти юнітів у бою       (10 год)  ✅  ← завершено (v3.9)

↓

Іконки предметів           (5 год)   ✅  ← код завершено (v4.0), потрібен арт

↓

Портрети юнітів            (6 год)   ✅  ← використовуємо _sprite_front

↓

Тайли місцевості           (6 год)   ✅  ← код завершено (v4.1), потрібен арт

↓

TopBar — Figma-дизайн      (3 год)   ✅  ← завершено (v4.2)

↓

Native Theme + cleanup     (1 год)   ✅  ← завершено (v4.3)

↓

Pause button SVG (Figma)   (0.5 год) ✅  ← завершено (v4.4)

↓

Speed buttons TextureButton (1 год)  ✅  ← завершено (v4.5)

↓

TopBar висоти 56px         (0.5 год) ✅  ← завершено (v4.6)

↓

Глобальна карта            (8 год)   ⬜

↓

UI polish (решта)          (4 год)   ⬜
```

**Загальна оцінка:** ~40 годин (код ~14 + арт ~26)

**Примітка:** Арт-контент можна робити паралельно з кодом. Спочатку код з placeholder текстурами, потім заміна на фінальний арт.

---

## 5. Відкладені задачі (не блокують Фазу 2)

### 5.1 Голод та дезертирство ✅ ЗАВЕРШЕНО (Game Over — v3.7)

**Стан:** Повністю реалізовано. Щоденна логіка вбудована в `WorldMap._process()` через акумуляцію `_day_time`. Бойовий штраф застосовується в `BattleManager._ready()`. Game Over при порожньому загоні — реалізовано.

- [x] `WorldMap._apply_hunger_effects()` → при `provisions == 0`: кожен козак `morale -= 20`
- [x] При `morale == 0`: 50% шанс дезертирства — видалити козака з `ws["squad"]`, повідомлення в HUD через `_show_hud_notification()`
- [x] На початку бою при `provisions == 0`: стан `WAVERING`, `stamina *= 0.7` (`BattleManager.gd`)
- [x] **Game Over:** після видалення дезертирів перевіряється `squad.is_empty()` → `_show_game_over()` ([WorldMap.gd](src/ui/WorldMap.gd))
  - Зупиняє `world_ticking`, `_player_party.stop()`, `_set_parties_ticking(false)`
  - Overlay (ColorRect 75% opacity) + центрована панель з темним фоном і золотою рамкою
  - Заголовок `tr("GAME_OVER_TITLE")`, текст `tr("GAME_OVER_DESERT")`, кнопка `tr("UI_MAIN_MENU")`
  - Кнопка → `get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")`
- [x] **4 нових ключі в CSV:** `GAME_OVER_TITLE`, `GAME_OVER_DESERT`, `GAME_OVER_DEFEAT`, `UI_MAIN_MENU`

### 5.2 UnitPanel.gd + Battle.tscn → UnitPanel.tscn ✅ ГОТОВО

`Battle.tscn` тепер інстансить `UnitPanel.tscn`. Виправлено шлях `MoraleLabel` у `_ensure_nodes_ready()` (`HBoxMain/LeftCol/MoraleBar/MoraleLabel`). Inline-дублікат вузлів видалено.

### 5.3 Globals.new() → пряме звернення до autoload ✅ ЗАВЕРШЕНО

`CombatUnit.gd` та `UnitPanel.gd` вже використовували autoload `Globals` напряму. Виправлено `CharacterSheet.gd` — прибрано `const Globals_Script = preload(...)` і `var Globals = Globals_Script.new()` ([CharacterSheet.gd:5-6](src/ui/CharacterSheet.gd#L5)).

---

## 6. Поза MVP — не торкати до релізу

> Записати ідеї в `docs/00_FUTURE_PLANS.md`, а не реалізовувати зараз.

| # | Задача | Чому відкладено |
|---|--------|-----------------|
| 6.1 | Бандити атакують загони інших фракцій | Scope creep; MVP має 1 фракцію ворогів |
| 6.2 | Fog of war / день-ніч на глобальній карті | Візуальний ефект є; логічний FoW — Фаза 5+ |
| 6.3 | Повна статична типізація всіх функцій | Технічний борг, не впливає на гру |
| 6.4 | Динамічні ціни в магазині | 50+ годин на баланс; фіксовані ціни достатньо |
| 6.5 | Drag-and-drop інвентар | 30+ годин; кнопки [Озброїти]/[Продати] достатньо |
| 6.6 | Save/load кілька слотів | 1 автозбереження достатньо для MVP |

---

## 7. Верифікація Фази 1

| Тест | Умова успіху |
|------|-------------|
| Лікування | Козак з неповним HP → "Лікувати" → HP = max_hp, талери зменшились на 30/козак |
| Магазин | Купити шаблю → вона з'являється в `squad_inventory`, талери зменшились |
| Лут | Після бою з 3+ ворогами — хоча б 1 предмет у `BattleResultScreen` |
| Екіпіровка | [Озброїти] для козака → старий предмет повертається в інвентар |
| Продаж | [Продати] → предмет зникає, талери зростають |
| Найм | В town → "Таверна" → 3-5 кандидатів → "Найняти" → козак у загоні |
| Save/load v3 | Зберегти → закрити → завантажити → інвентар і загін збережені |
| Стара гра (v2) | Завантажити v2-save → гра запускається, `squad_inventory = []` |
| 5 боїв поспіль | Зіграти 5 боїв: 1+ смерть, 1+ найм, 1+ купівля, HP відновлено |

---

## 8. Порядок реалізації (Фаза 1 — архів)

```
InventoryManager.gd API  (0.5 год)  ✅
        ↓
SaveManager v2→v3        (1 год)    ✅ завершено
        ↓
Лут із BattleManager     (2 год)    ✅
        ↓
BattleResultScreen лут   (1 год)    ✅
        ↓
HealingPanel             (2 год)    ✅ (inline в WorldMap.gd)
        ↓
ShopPanel                (2 год)    ✅ (inline в WorldMap.gd)
        ↓
SquadInventoryPanel      (3 год)    ✅ (inline в WorldMap.gd)
        ↓
HiringPanel              (3 год)    ✅ (inline в WorldMap.gd)
        ↓
Тест "5 боїв" ← критерій Фази 1    ⬜ потрібно провести
```

**Загальна оцінка:** ~15 годин чистого коду = ~3 сесії по 5 годин або 6 сесій по 2.5 год.
