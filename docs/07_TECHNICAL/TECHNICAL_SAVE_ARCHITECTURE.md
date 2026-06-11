# TECHNICAL_SAVE_ARCHITECTURE.md
# Технічна структура збережень (Save System)

## 1. Загальний світовий стан (WorldState)

```json
{
  "save_version": 1,
  "seed": 123456,
  "current_day": 124,
  "current_time": 0.55,
  "renown": 2450,
  "gold": 3420,
  "fog_of_war_data": "base64_compressed_grid",
  "factions_reputation": {
    "crown": 15,
    "sich": 65,
    "orda": -45
  }
}
```

## 2. Стан юніта (UnitState)

```json
{
  "unit_id": "u001",
  "name": "Микола",
  "background": "peasant",
  "level": 7,
  "xp": 6800,
  "hp_current": 62,
  "stamina_current": 45,
  "mood": 3,
  "traits": ["iron_lungs", "brave"],
  "injuries": ["broken_arm_temporary"],
  "equipment": {
    "head": "kuchma_02",
    "body": "gусарська_кіраса",
    "main_hand": "sabre_famed_01",
    "off_hand": "shield_pavise",
    "belt": ["musket_loaded", "bandage", "gunpowder"]
  }
}
```

## 3. Стан загону (SquadState)

```json
{
  "unit_id": "u001",
  "name": "Микола",
  "background": "peasant",
  "level": 7,
  "xp": 6800,
  "hp_current": 62,
  "stamina_current": 45,
  "mood": 3,
  "traits": ["iron_lungs", "brave"],
  "injuries": ["broken_arm_temporary"],
  "equipment": {
    "head": "kuchma_02",
    "body": "gусарська_кіраса",
    "main_hand": "sabre_famed_01",
    "off_hand": "shield_pavise",
    "belt": ["musket_loaded", "bandage", "gunpowder"]
  }
}
```

## 4. Глобальні дані

Активні та завершені контракти
Стан возів і вантажу
Прогрес амбіцій і криз

## 5. Реалізація в Godot

Використовувати `FileAccess` або `Resource` + `save_custom`.
Ironman-режим: після завантаження файл видаляється або стає недоступним до наступного виходу.

---

## 6. Поточна реалізація v2 (18.05.2026)

Файл: `user://cossacks_save.json`

```json
{
  "version": 2,
  "world_state": {
    "day": 5,
    "thalers": 350,
    "provisions": 8,
    "faction_rep": { "crown": 0, "sich": 0, "orda": -10 },
    "biomes": [...],
    "rivers": [[{"x":..., "y":...}, ...]],
    "lakes":  [[{"x":..., "y":...}, ...]],
    "roads":  [[{"x":..., "y":...}, ...]],
    "locations": [
      {
        "id": "loc_0",
        "type": "bandit_camp",
        "faction": "none",
        "pos": { "x": 310.0, "y": 240.0 },
        "garrison_paths": ["res://src/resources/units/Bandit.tres", ...],
        "cleared": false,
        "reward_thalers": 150,
        "name": "Розбійничий табір"
      }
    ],
    "enemy_parties": [
      {
        "id": "party_0",
        "faction": "none",
        "unit_paths": ["res://src/resources/units/Bandit.tres", ...],
        "patrol_waypoints": [{"x":..., "y":...}, ...],
        "base_pos": { "x": 200.0, "y": 300.0 },
        "pos": { "x": 220.0, "y": 285.0 },
        "alive": true
      }
    ],
    "player_pos": { "x": 600.0, "y": 500.0 },
    "squad": [
      {
        "name": "Ничипір",
        "hp": 72, "max_hp": 80,
        "xp": 150, "level": 1, "xp_to_next": 150,
        "weapon_resource_path": "res://src/resources/combat/weapons/saber.tres"
      }
    ]
  }
}
```

**Класи:**
- `SaveManager` (`src/core/SaveManager.gd`): `has_save()`, `save_campaign(world_state)`, `load_campaign() → Dictionary`
- `CampaignManager` (`src/core/CampaignManager.gd`): тримає `world_state` в пам'яті, делегує збереження SaveManager

---

## 7. Поточна реалізація v3 (02.06.2026)

Формат збережено зворотньо сумісним: `load_campaign()` викликає `_migrate(ws, version)`, що дописує нові поля з дефолтами якщо вони відсутні.

**Нові поля в `world_state`:**

```json
{
  "version": 3,
  "squad": [
    {
      "name": "Ничипір",
      "hp": 72, "max_hp": 80,
      "morale": 100,
      "xp": 150, "level": 1, "xp_to_next": 150,
      "data_path": "res://src/resources/units/Nychypir.tres",
      "weapon_resource_path": "res://src/resources/combat/weapons/saber.tres",
      "armor_path": "",
      "helm_path": ""
    }
  ],
  "squad_inventory": [
    {
      "id": "saber",
      "name": "Козацька шабля",
      "type": "weapon",
      "buy_price": 80,
      "sell_price": 50,
      "res_path": "res://src/resources/combat/weapons/saber.tres"
    }
  ],
  "shop_inventory": [
    {"id": "saber",            "name": "Козацька шабля",   "type": "weapon", "buy_price": 80,  "sell_price": 50, "res_path": "..."},
    {"id": "spear",            "name": "Спис",              "type": "weapon", "buy_price": 120, "sell_price": 70, "res_path": "..."},
    {"id": "padded_zhupan",    "name": "Стьобаний жупан",  "type": "armor",  "buy_price": 60,  "sell_price": 35, "res_path": "..."},
    {"id": "leather_lamellar", "name": "Шкіряний панцир",  "type": "armor",  "buy_price": 100, "sell_price": 55, "res_path": "..."},
    {"id": "shlyk",            "name": "Звичайна шапка",   "type": "helm",   "buy_price": 40,  "sell_price": 20, "res_path": "..."},
    {"id": "kuchma",           "name": "Хутряна кучма",    "type": "helm",   "buy_price": 70,  "sell_price": 40, "res_path": "..."}
  ]
}
```

**Нові класи:**
- `InventoryManager` (`src/core/InventoryManager.gd`) — статичний `class_name`, не autoload. API: `add_item`, `remove_item`, `sell_item`, `equip_item(ws, item_id, unit_name)`, `get_by_type`, `make_item_from_resource`. Пошук юніта по `name`.

**Версія:** 1.2 (оновлено) — 02.06.2026