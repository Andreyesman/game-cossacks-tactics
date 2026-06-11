# LOCALIZATION_PLAN.md
# План локалізації

**Статус:** v3.3 — локалізація повністю завершена; аудіо код готовий  
**Реалізовано:** 4.1 інфраструктура ✅ — CSV (~361 ключів) + LocaleManager + project.godot  
**Реалізовано:** 4.2 бойова система ✅ — BattleManager, CombatUnit, UnitPanel, CharacterSheet  
**Реалізовано:** 4.3 глобальна карта + меню ✅ — WorldMap, EncounterDialog, MainMenu  
**Реалізовано:** 4.4 назви локацій ✅ — WorldGenerator (13 типових назв), WorldMap._cleared_desc/_faction_label  
**Реалізовано:** 4.5 перемикач мови ✅ — OptionButton у Settings overlay (v3.3: переміщено з основних кнопок)  
**Реалізовано:** 4.6 шрифт ✅ — Kelly Slab глобально через project.godot [gui], зайві overrides прибрано  
**Реалізовано:** 4.7 залишкові тексти ✅ — навички/зброя/origin/міста/рекрути/біоми (9 файлів, +130 ключів)  
**Реалізовано:** 4.7+ grep-аудит ✅ — BattleResultScreen, terrain tooltips, зброя legacy, травми, крамниця, час доби (+78 ключів, v3.2)  
**Залишилось:** 4.8 аудіо треки ⬜ / 4.9 SFX ⬜ / 4.10 меню налаштувань ⬜  
**Grep-статус:** `grep -rn '"[^"]*[а-яА-ЯіІїЇєЄґҐ][^"]*"' src/ | grep -v 'tr(' | grep -v 'print\|push_'` → **0 UI-рядків**  
**Мови MVP:** Українська (базова) + Англійська (для релізу)

---

## 1. Формат файлу перекладів

Використовується **Godot CSV Translation** (вбудована підтримка, не JSON).

`res://localization/translations.csv` (✅ створено, 110 ключів):
```
keys,uk,en
UI_BUTTON_END_TURN,Завершити хід,End Turn
UI_BUTTON_RETREAT,Відступити,Retreat
UI_BUTTON_HEAL,"Лікувати (30 тал.)","Heal (30 thal.)"
UI_BUTTON_HIRE,Найняти,Hire
UI_BUTTON_BUY,Купити,Buy
UI_BUTTON_SELL,Продати,Sell
MSG_NOT_ENOUGH_GOLD,Недостатньо талерів!,Not enough thalers!
MSG_UNIT_DIED,%s загинув у бою,%s died in battle
MSG_LEVEL_UP,%s досяг рівня %d!,%s reached level %d!
TOOLTIP_AP,Очки дій — витрачаються на рух та атаки,Action Points — spent on movement and attacks
TOOLTIP_STAMINA,Витривалість — витрачається на дії відновлюється на початку раунду,Stamina — spent on actions restored at round start
TOOLTIP_MORALE,Мораль — впливає на бойові стати,Morale — affects combat stats
SKILL_RECOVER,Відпочинок,Recover
SKILL_RIPOSTE,Контрудар,Riposte
SKILL_RALLY,Згуртування,Rally
SKILL_RELOAD,Перезарядка,Reload
SKILL_RETREAT,Відступ,Retreat
SKILL_FLEE,Втеча,Flee
MORALE_CONFIDENT,Впевнений,Confident
MORALE_STEADY,Спокійний,Steady
MORALE_WAVERING,Вагається,Wavering
MORALE_BREAKING,Зламаний,Breaking
MORALE_FLEEING,Тікає,Fleeing
LOCATION_TYPE_BANDIT_CAMP,Розбійничий табір,Bandit Camp
LOCATION_TYPE_RUINS,Руїни,Ruins
LOCATION_TYPE_TATAR_CAMP,Татарський кіш,Tatar Camp
LOCATION_TYPE_CROWN_OUTPOST,Форпост Корони,Crown Outpost
LOCATION_TYPE_FORTRESS,Фортеця,Fortress
LOCATION_TYPE_TOWN,Місто,Town
LOCATION_TYPE_VILLAGE,Село,Village
ENEMY_BANDIT,Бандит,Bandit
ENEMY_BANDIT_LEADER,Ватажок,Bandit Leader
ENEMY_TATAR,Татарин,Tatar
ENEMY_TATAR_HEAVY,Важкий татарин,Heavy Tatar
ENEMY_JANISSARY,Яничар,Janissary
ENEMY_REIESTR,Реєстровий,Registered Cossack
```

---

## 2. LocaleManager (Autoload) ✅ РЕАЛІЗОВАНО

**Файл:** `src/core/LocaleManager.gd` ✅  
**Реєстрація:** `project.godot` → `[autoload]` → `LocaleManager` ✅

```gdscript
extends Node

func _ready() -> void:
    TranslationServer.set_locale(_load_locale())

func set_language(locale: String) -> void:
    TranslationServer.set_locale(locale)
    _save_locale(locale)

func get_language() -> String:
    return TranslationServer.get_locale()

func _save_locale(locale: String) -> void:
    var config := ConfigFile.new()
    config.set_value("settings", "locale", locale)
    config.save("user://settings.cfg")

func _load_locale() -> String:
    var config := ConfigFile.new()
    if config.load("user://settings.cfg") == OK:
        return config.get_value("settings", "locale", "uk")
    return "uk"
```

**Примітка:** `project.godot` реєструє `.translation` бінарники (не CSV):
```
locale/translations=PackedStringArray("res://localization/translations.uk.translation", "res://localization/translations.en.translation")
```

---

## 3. Що перекладається, що ні

### Перекладається через `tr("KEY")`
- Всі кнопки UI (Атакувати, Купити, Лікувати тощо)
- Назви барів і статів (Здоров'я, Витривалість, Мораль)
- Стани моралі (Впевнений → Тікає)
- Назви навичок і їх описи
- Системні повідомлення (смерть козака, рівень, помилки)
- Типи локацій (Розбійничий табір, Місто)
- Типи ворогів (Бандит, Татарин)
- Лог бою та підказки

### НЕ перекладається (власні назви)
- Імена козаків: Ничипір, Гаврило, Тимофій, Панько
- Географічні назви: Суботів, Чигирин, Бахчисарай
- Назви фракцій: Корона, Січ, Орда (або лишити)
- Валюта: "тал." (скорочення, однакове в обох мовах)

---

## 4. Пріоритет файлів для перекладу

| Пріоритет | Файл | Статус |
|-----------|------|--------|
| 1 | `UnitPanel.gd` | ✅ Готово (v2.7 + v3.2 weapon/terrain/stance/hitchance) |
| 2 | `BattleManager.gd` | ✅ Готово (v2.7 + v3.0 + v3.2 hint/round/fallback) |
| 3 | `CombatUnit.gd` | ✅ Готово (v2.7 + v3.2 levelup/panic/friendlyfire) |
| 4 | `CharacterSheet.gd` | ✅ Готово (v2.7 + v3.2 weapon tooltips/slot descs) |
| 5 | `WorldMap.gd` | ✅ Готово (v2.8 + v2.9 + v3.2 time/level/stats/items) |
| 6 | `EncounterDialog.gd` | ✅ Готово (v2.8) |
| 7 | `MainMenu.gd` | ✅ Готово (v2.8 + v3.0 lang switcher) |
| 8 | `BattleResultScreen.gd` | ✅ Готово (v3.2 — повністю переведено) |
| 9 | `WorldGenerator.gd` | ✅ Готово (v2.9) — 13 типових назв |
| 10 | `TacticalGrid.gd` | ✅ v3.0 font; v3.1 WFC names; v3.2 UI_AP_SHORT |
| 11 | `LoadingScreen.gd` | ✅ v3.2 LOADING_BATTLE |
| 12 | `TurnQueueUI.gd` | ✅ v3.1 BATTLE_ROUND |
| 13 | `CampaignManager.gd` | ✅ v3.1 cossack names tr() |
| 14 | `WFCGenerator.gd` | ✅ v3.1 LOCATION_NAMES used as tr() keys |
| 15 | `CameraController.gd` | ✅ v3.2 UI_ZOOM_FORMAT |

---

## 5. Технічні вимоги

- Реєстрація CSV у Project Settings → Localization → Translations
- Шрифт повинен підтримувати кирилицю і латиницю (перевірити поточний, замінити на Inter/Noto Sans якщо ні)
- `ConfigFile` для збереження вибору мови між сесіями
- Зміна мови — без рестарту гри (`TranslationServer.set_locale()` оновлює `tr()` миттєво)

---

## 6. Польська та інші мови

- **Польська** — після релізу (через історичний контекст, але не для MVP)
- **Російська** — не планується

---

## 7. Реалізовано в 4.2 — технічні деталі

### Паттерн заміни рядків

```gdscript
# Простий рядок
label.text = tr("STAT_HP")

# З форматуванням (одне значення)
log_message("--- 🏆 " + tr("BATTLE_VICTORY") + " ---", Color.SKY_BLUE)

# З форматуванням (масив)
tr("BATTLE_HIT") % [attacker_name, target_name, damage]  # "%s вдарив %s на %d HP"
tr("BATTLE_UNIT_TURN") % [unit.name, tr("TEAM_COSSACK")]  # "Хід юніта: %s (%s)"

# Конкатенація з emoji (emoji не перекладаються)
spawn_text_fx("💥 " + tr("BATTLE_SHOT"), Color.ORANGE)
```

### Виправлення _style_morale_label

До v2.7: `if "Впевнений" in m_str` — ламало English mode.  
Після: `if tr("MORALE_CONFIDENT") in m_str` — працює в обох мовах.

### Ключі НЕ додані в 4.2 (залишено на потім)

- Hover intel panel (`_update_intel_text` в `UnitPanel.gd`) — назви зброї, стійка КОНТРУДАР
- Panic spread log message (`"😱 ВТЕЧА %s лякає союзників!"`) — немає відповідного ключа
- Debug `print()` — не UI-текст

---

## 8. Реалізовано в 4.4 — типові назви локацій

### WorldGenerator.gd — масив `templates`

13 хардкоджених типових назв замінено на `tr()`. Власні назви (Чигирин, Київ, Диканька, Суботів, Полтавка, Бахчисарай, Опішня, Кам'яний Брід, Кам'янець, Кодак, Ямпіль, Жванець) — **без змін**.

| Стара назва | Ключ |
|-------------|------|
| Розбійничий табір | `LOC_TYPE_BANDIT_CAMP` (вже існував) |
| Занедбані руїни | `LOC_ABANDONED_RUINS` |
| Покинута пасіка | `LOC_ABANDONED_APIARY` |
| Печера розбійників | `LOC_BANDIT_CAVE` |
| Татарський кіш | `LOC_TYPE_TATAR_CAMP` (вже існував) |
| Ставка мурзи | `LOC_MURZA_CAMP` |
| Скіфська могила | `LOC_SCYTHIAN_TOMB` |
| Козацький цвинтар | `LOC_COSSACK_CEMETERY` |
| Татарський дозор | `LOC_TATAR_PATROL` |
| Прикордонний форпост | `LOC_TYPE_CROWN_OUTPOST` (вже існував) |
| Фортеця | `LOC_FORTRESS` |
| Зруйнований костел | `LOC_RUINED_CHURCH` |
| Яр язичників | `LOC_PAGAN_RAVINE` |

### WorldMap.gd — `_cleared_desc()` і `_faction_label()`

```gdscript
func _cleared_desc(loc_type: String) -> String:
    match loc_type:
        "bandit_camp":   return tr("CLEARED_BANDIT_CAMP")
        "tatar_camp":    return tr("CLEARED_TATAR_CAMP")
        "ruins":         return tr("CLEARED_RUINS")
        "crown_outpost": return tr("CLEARED_CROWN_OUTPOST")
        "fortress":      return tr("CLEARED_FORTRESS")
        _:               return tr("MAP_LOCATION_CLEARED")

func _faction_label(faction: String) -> String:
    match faction:
        "orda":  return tr("FACTION_ORDA_PLURAL")
        "crown": return tr("FACTION_CROWN_PLURAL")
        "sich":  return tr("FACTION_SICH_PLURAL")
        _:       return tr("FACTION_BANDITS")
```

### Нові ключі CSV (20 шт., всього ~143)

`LOC_ABANDONED_RUINS`, `LOC_ABANDONED_APIARY`, `LOC_BANDIT_CAVE`, `LOC_MURZA_CAMP`, `LOC_SCYTHIAN_TOMB`, `LOC_COSSACK_CEMETERY`, `LOC_TATAR_PATROL`, `LOC_FORTRESS`, `LOC_RUINED_CHURCH`, `LOC_PAGAN_RAVINE`, `CLEARED_BANDIT_CAMP`, `CLEARED_TATAR_CAMP`, `CLEARED_RUINS`, `CLEARED_CROWN_OUTPOST`, `CLEARED_FORTRESS`, `FACTION_ORDA_PLURAL`, `FACTION_CROWN_PLURAL`, `FACTION_SICH_PLURAL`, `FACTION_BANDITS` + `MAP_LOCATION_CLEARED` (вже існував).

---

## 9. Реалізовано в 4.5 + 4.6 — перемикач мови та глобальний шрифт

### 4.6 Kelly Slab як глобальний шрифт (project.godot + game_theme.tres)

```ini
[gui]
theme/custom="res://assets/theme/game_theme.tres"   ← (v4.3)
theme/default_font="res://assets/fonts/KellySlab-Regular.ttf"
theme/default_font_size=16
```

`assets/theme/game_theme.tres` — нативний Godot Theme ресурс (v4.3): `default_font=KellySlab`, `default_font_size=16`, `Label/colors/font_color=#585551`. Автоматично каскадується на всі `Label`, `Button`, `RichTextLabel`, `OptionButton`. Видалено явні `add_theme_font_override("font", KellySlab)` з усього коду (MainMenu.gd, WorldMap.gd та ін.). Видалено ~25 зайвих `add_theme_font_size_override(prop, 16)` — дефолт 16 більше не потребує override. `font_size_override` з розмірами ≠ 16 — залишені.

### 4.5 OptionButton мови (MainMenu.gd)

```gdscript
# _make_lang_option() — OptionButton зі стилем під гру
opt.add_item("Українська", 0)
opt.add_item("English",    1)
opt.selected = 0 if LocaleManager.get_language() == "uk" else 1

opt.item_selected.connect(func(idx):
    LocaleManager.set_language("uk" if idx == 0 else "en")
    _update_button_texts()   # tr("UI_NEW_GAME"), tr("UI_CONTINUE"), tr("UI_EXIT")
)
```

Розміщення: після кнопки "Вийти", перед нижнім flex-spacer. Мова зберігається між сесіями через `LocaleManager._save_locale()` → `user://settings.cfg`.

### Новий ключ CSV (1 шт., всього ~144)

`UI_LANGUAGE` | uk: Мова | en: Language

---

## 10. Реалізовано в 4.7 — залишкові непереведені тексти

### Підхід: ключ = українська назва з .tres / hardcode

Оскільки `.tres` файли не змінюються, ключем у CSV є **точний українській рядок** зі `.tres` або з коду. При `tr("Відпочинок")` повертається "Rest" в англійській локалі.

### Критичні тонкощі

| Файл | Що зроблено |
|------|-------------|
| `UnitPanel.gd` | `var raw_desc := skill.get("desc", ""); var tooltip := tr(raw_desc) if raw_desc != "" else ""` |
| `WorldGenerator.gd` | `"name": tr("Чигирин")` — генерується при `new_campaign()`, зберігається у `world_state` вже перекладеним |
| `TacticalGrid.gd` | `tr(WFCGenerator.LOCATION_NAMES[loc_type])` — перекладає при старті бою, не при генерації WFCGenerator.LOCATION_NAMES |
| `CampaignManager.gd` | `tr(data.unit_name)` — козаки іменуються при старті кампанії; в save зберігається перекладене ім'я |

### CSV ключі зі складними символами

Деякі origin_bonus містять коми — вони в CSV ОБОВ'ЯЗКОВО в кавичках:
```csv
"+10 Мораль, +5 Ініціатива","+10 Мораль, +5 Ініціатива","+10 Morale, +5 Initiative"
```

Godot 4 CSV-парсер (RFC 4180) коректно обробляє quoted fields у всіх трьох колонках.

### Відомі обмеження

- **Save-файли:** збережені `world_state["squad"][].name` і `locations[].name` вже є перекладеними рядками. При зміні мови після завантаження старого save — імена залишаться мовою генерації. Рішення для post-MVP: зберігати tr()-ключі замість translated strings.
- **BanditLeader/enemy origins:** переведені (є в CSV), але видно лише у CharacterSheet в бою.

**Версія:** 3.2 — оновлено 04.06.2026 (4.1 + 4.2 + 4.3 + 4.4 + 4.5 + 4.6 + 4.7 + 4.7-audit реалізовано)

---

## 11. Реалізовано в v3.2 — grep-аудит (повторний прохід)

### Метод

```bash
grep -rn --include="*.gd" -P '"[^"]*[а-яА-ЯіІїЇєЄґҐ][^"]*"' src/ \
  | grep -v 'tr(' | grep -v 'print\|push_error\|push_warning'
```

Виявлено рядки, пропущені в 4.7 через обмеження ручного перегляду.

### Нові паттерни, відкриті аудитом

| Паттерн | Де зустрічається | Рішення |
|---------|-----------------|---------|
| Назви зброї legacy (без WeaponResource) | UnitPanel, CharacterSheet | `tr("WEAPON_TYPE_SWORD/MUSKET/HEAVY")` |
| Terrain tooltips (повний опис) | UnitPanel._get_terrain_tooltip_text() | `tr("TERRAIN_*_INFO")` — ціла рядка з витратами |
| Injury names у BattleResultScreen | `injury.get("name")` | `tr(str(injury.get("name")))` — uk-ключ в CSV |
| Shop item names у WorldMap | `shop_item.get("name")` | `tr(shop_item.get("name"))` — uk-ключ в CSV |
| Фази доби | WorldMap._update_time_phase() | `tr("TIME_DAY/DUSK/NIGHT/DAWN")` |
| Slot tooltips у CharacterSheet | Шолом/Набої/Броня тіла/Пояс | `tr("CS_SLOT_*_TOOLTIP")` |
| Weapon resource tooltip | _get_weapon_resource_tooltip() | `tr("WEAPON_STAT_*")` |
| Бойові повідомлення | BattleManager log, CombatUnit spread | `tr("BATTLE_*")` |

### Bugfix: `"Чекати" in btn.text` → `tr("UI_WAIT") in btn.text`

Перевірка в `UnitPanel._refresh_active_panel()` використовувала hardcoded `"Чекати"`. В English locale кнопка має текст `"Wait"` — перевірка завжди давала `false`, кнопка ніколи не блокувалась при AP < 1.

### Схема перекладу injury/item names

```
CombatUnit.INJURY_TABLE → "name": "Порізана рука"
    ↓ зберігається у unit.injuries[].name
    ↓ BattleResultScreen: tr(str(injury.get("name")))
    ↓ translations.csv: "Порізана рука,Порізана рука,Cut Arm"
```

Аналогічно для `shop_inventory[].name` і `squad_inventory[].name`.
