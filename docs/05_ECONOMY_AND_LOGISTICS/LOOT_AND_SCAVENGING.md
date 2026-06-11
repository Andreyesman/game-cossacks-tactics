# LOOT_AND_SCAVENGING.md
# Система луту та мародерства

## Поточна реалізація MVP (v1.8)

### Лут після бою

При перемозі `BattleManager._show_battle_result()` збирає `loot_pool`:
- Для кожного мертвого ворога (`team == 1`): `randf() < 0.3` → зброя ворога додається в `loot_pool`
- Сигнатура: `finish_battle(is_victory, player_units, loot_pool)`
- `BattleResultScreen` отримує `loot_pool` через `init()`, показує секцію "Трофеї"
- "Продовжити кампанію" → `InventoryManager.make_item_from_resource(weapon_res)` для кожного предмета → `add_item(ws, item)`

**Конвертація ресурсу в item:** `InventoryManager.make_item_from_resource(res: WeaponResource) -> Dictionary` повертає `{ id, name, type: "weapon", buy_price, sell_price, res_path }`.

---

## Правило цілісності броні
- Якщо броня ворога доведена до 0 Armor HP — вона **не випадає**.
- Щоб отримати цілу елітну кірасу, треба вбити ворога **кинджалом** (Puncture — 100% Armor Pen).

> **На майбутнє — Curve-based Loot Quality (Godot `Curve` resource):**
> Таблиця дропу через `Curve`: вісь X = прогрес гравця (день / party power / рівень контракту), вісь Y = ймовірність рідкісного предмета. Дизайнер малює криву в редакторі — наприклад, плавне зростання шансу на рідкісний лут від 5% на старті до 35% в ендгеймі з «горбом» навколо 60-го дня для золотої середини.
>
> Реалізація: окремий `LootTable.tres` з масивом `Curve`-ресурсів по категоріях (зброя, броня, витратні). При генерації дропу — `curve.sample(progress)` визначає шанс кожної категорії.
>
> **Коли доречно:** після появи `FAMED_ITEMS_AND_LOOT.md` в грі і мінімум 3 рівнів якості предметів (common / rare / famed).

**Версія:** 1.0 (структурована) — 02.04.2026