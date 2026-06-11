# INVENTORY_SYSTEM.md
# Система інвентарю (MVP)

**Версія:** 1.9 — 08.06.2026

---

## 1. InventoryManager

`src/core/InventoryManager.gd` — статичний `class_name InventoryManager`, **не autoload**. Усі зміни інвентарю проходять через нього, щоб панелі не мутували `world_state` напряму.

### API

```gdscript
# Додати предмет у squad_inventory
InventoryManager.add_item(ws: Dictionary, item: Dictionary) -> void

# Видалити предмет за id (перший збіг)
InventoryManager.remove_item(ws: Dictionary, item_id: String) -> bool

# Продати предмет: видалити з інвентарю + ws["thalers"] += sell_price
InventoryManager.sell_item(ws: Dictionary, item_id: String) -> bool

# Екіпірувати предмет на козака (пошук за name)
# Старе спорядження того слота повертається в squad_inventory
InventoryManager.equip_item(ws: Dictionary, item_id: String, unit_name: String) -> bool

# Отримати всі предмети певного типу ("weapon" | "armor" | "helm")
InventoryManager.get_by_type(ws: Dictionary, type: String) -> Array[Dictionary]

# Перетворити WeaponResource/ArmorResource на item-словник
InventoryManager.make_item_from_resource(res: Resource) -> Dictionary

# Повернути Texture2D іконки для item_id, або null (fallback на емодзі)
InventoryManager.get_item_icon(item_id: String) -> Texture2D
```

### Іконки предметів (`ITEM_ICONS`)

`InventoryManager` містить константний маппінг `item_id → PNG-шлях`:

```gdscript
const ITEM_ICONS: Dictionary = {
    "saber":            "res://assets/sprites/icons/icon_saber.png",
    "musket":           "res://assets/sprites/icons/icon_musket.png",
    "janissary_musket": "res://assets/sprites/icons/icon_musket.png",
    "spear":            "res://assets/sprites/icons/icon_spear.png",
    "warhammer":        "res://assets/sprites/icons/icon_warhammer.png",
    "battle_axe":       "res://assets/sprites/icons/icon_axe.png",
    "dagger":           "res://assets/sprites/icons/icon_dagger.png",
    "bow":              "res://assets/sprites/icons/icon_bow.png",
    "mail":             "res://assets/sprites/icons/icon_mail.png",
    "jupan":            "res://assets/sprites/icons/icon_jupan.png",
    "cuirass":          "res://assets/sprites/icons/icon_cuirass.png",
    "helm":             "res://assets/sprites/icons/icon_helm.png",
    "misyurka":         "res://assets/sprites/icons/icon_helm.png",
    "kuchma":           "res://assets/sprites/icons/icon_kuchma.png",
    "cap":              "res://assets/sprites/icons/icon_cap.png",
}
```

`get_item_icon()` повертає `null` якщо файл відсутній — усі споживачі автоматично відображають емодзі-fallback. Файли зберігаються в `assets/sprites/icons/` (48×48 px, прозорий фон).

**Де використовується:**

| UI-компонент | Розмір | Fallback |
|--------------|--------|---------|
| `CharacterSheet._equipment_slot()` | 32×32 | Label з емодзі |
| `WorldMap._refresh_equipment_section()` | 32×32 | Label з емодзі |
| `WorldMap._refresh_inventory_section()` | 24×24 | відсутній (лише іконка) |
| `WorldMap._show_location_dialog()` (крамниця) | 24×24 | відсутній (лише іконка) |
| `BattleResultScreen._loot_slot()` | 32×32 | Label з емодзі |

### Формат item-словника

```json
{
  "id": "saber",
  "name": "Козацька шабля",
  "type": "weapon",
  "buy_price": 80,
  "sell_price": 50,
  "res_path": "res://src/resources/combat/weapons/saber.tres"
}
```

Поля `type`: `"weapon"` / `"armor"` / `"helm"`.  
Пошук козака — за полем `name` (не uuid, спрощення для MVP).

---

## 2. world_state — інвентарні поля (v3)

```json
{
  "squad_inventory": [ /* масив item-словників */ ],
  "shop_inventory": [
    {"id": "saber",            "name": "Козацька шабля",   "type": "weapon", "buy_price": 80,  "sell_price": 50,  "res_path": "..."},
    {"id": "spear",            "name": "Спис",              "type": "weapon", "buy_price": 120, "sell_price": 70,  "res_path": "..."},
    {"id": "padded_zhupan",    "name": "Стьобаний жупан",  "type": "armor",  "buy_price": 60,  "sell_price": 35,  "res_path": "..."},
    {"id": "leather_lamellar", "name": "Шкіряний панцир",  "type": "armor",  "buy_price": 100, "sell_price": 55,  "res_path": "..."},
    {"id": "shlyk",            "name": "Звичайна шапка",   "type": "helm",   "buy_price": 40,  "sell_price": 20,  "res_path": "..."},
    {"id": "kuchma",           "name": "Хутряна кучма",    "type": "helm",   "buy_price": 70,  "sell_price": 40,  "res_path": "..."}
  ]
}
```

Кожен козак у `ws["squad"]` також має поля:
```json
{
  "weapon_resource_path": "res://src/resources/combat/weapons/saber.tres",
  "armor_path": "",
  "helm_path": ""
}
```

---

## 3. SaveManager — міграція v2→v3

`SaveManager._migrate(ws, version)` (`src/core/SaveManager.gd:111–125`):
- якщо `version < 3`: дописує `squad_inventory: []`, `shop_inventory: [...]` (дефолтний асортимент), `day_count: 0`
- для кожного козака без `armor_path`/`helm_path` — ініціалізує порожніми рядками
- старі збереження залишаються робочими без ломання

---

## 4. Squad Inventory Panel (UI)

Вбудовано в `WorldMap.gd`. Відкривається клавішею `I` або кнопкою `🎒` в HUD.

**Структура:**
- Ряд козаків (горизонтальний, кнопки вибору)
- Сітка спорядження 3×3 для обраного козака (стиль `CharacterSheet.gd`): зброя, броня, шолом + порожні слоти
- Список предметів `squad_inventory` з кнопками:
  - `[Озброїти]` — `equip_item()` на обраного козака
  - `[Продати N тал.]` — активна лише при знаходженні в поселенні (`_is_at_settlement()`)

Клік на зайнятий слот → зняти предмет назад в `squad_inventory`.  
Панель автоматично оновлюється після найму, лікування, купівлі.

---

## 5. Потоки даних

```
BattleManager (смерть ворога)
  → make_item_from_resource(weapon_res)
  → loot_pool[]
  → BattleResultScreen ("Трофеї")
  → finish_battle(loot_pool)
  → add_item(ws, item) для кожного

WorldMap (крамниця)
  → купити: ws["thalers"] -= buy_price, add_item(ws, item)
  → продати: sell_item(ws, item_id) → ws["thalers"] += sell_price

WorldMap (екіпіровка)
  → equip_item(ws, item_id, unit_name)
  → unit["weapon_resource_path"] / unit["armor_path"] / unit["helm_path"] = res_path
  → старий предмет → add_item(ws, old_item)

BattleManager._apply_enemy_config()
  → unit["armor_path"] → data.default_armor = load(path)
  → unit["helm_path"]  → data.default_helmet = load(path)
```
