# AUDIO_DESIGN.md
# Звуковий дизайн та музика

**Статус:** ✅ ПОВНІСТЮ ЗАВЕРШЕНО  
**Реалізовано (v3.3):** `AudioManager.gd` (Autoload) + Settings panel у MainMenu  
**Реалізовано (v3.4):** `map_theme.wav` + `battle_theme.wav` додані, імпортовані Godot  
**Реалізовано (v3.5):** 10 викликів `play_sfx()` підключені в коді  
**Реалізовано (v3.6):** `heal/hire/notification` в `SFX` dict; всі 9 SFX файлів наявні і імпортовані  
**Bugfix #1 (05.06.2026):** Музика тепер зациклена через сигнал `finished` (деталі в розділі 3)  
**Bugfix #2 (05.06.2026):** BattleManager guard — бій не крашиться якщо AudioManager недоступний (деталі в розділі 4)

---

## 0. AudioManager API (`src/core/AudioManager.gd`) — Autoload ✅

```gdscript
# Autoload зареєстровано в project.godot
AudioManager.play_music("map")      # crossfade до map_theme.wav
AudioManager.play_music("battle")   # crossfade до battle_theme.wav
AudioManager.stop_music()           # fade out 1.0s
AudioManager.play_sfx("hit_melee")  # з пулу 5 плеєрів
AudioManager.set_music_volume(0.7)  # 0.0–1.0, зберігається
AudioManager.set_sfx_volume(0.8)
```

**Де викликається:**
- `MainMenu._ready()` → `play_music("map")`
- `WorldMap._ready()` → `play_music("map")`
- `BattleManager._ready()` → `play_music("battle")`

**Crossfade:** 1.5s між треками (2 AudioStreamPlayer, Tween на volume_db).  
**Persistence:** гучність у `user://settings.cfg` секція `[audio]`.  
**Graceful fallback:** відсутній файл → `push_warning`, не краш.

---

## 1. Музичний напрямок

| Контекст | Стиль | Файл |
|----------|-------|------|
| Глобальна карта | Медитативний, кобза/сопілка або ambient | `map_theme.wav` ✅ |
| Тактичний бій | Напружений, тулумбаси/перкусія | `battle_theme.wav` ✅ |
| Перемога | Короткий фанфар | `victory_sting.wav` (відкладено) |
| Поразка/паніка | Драматичний хор, дисонанс | `defeat_sting.wav` (відкладено) |

**Джерела для MVP:** freesound.org (CC0), OpenGameArt.org, incompetech.com (Kevin MacLeod)

---

## 2. Структура Audio Bus

**Реалізовано (v3.3):** 2 buses створюються програмно в `AudioManager._ensure_audio_buses()`.

```
Master
├── Music  — фонові треки (loop), гучність регулюється слайдером у Settings
└── SFX    — ігрові ефекти (5-плеєрний пул), гучність регулюється слайдером у Settings
```

> Sub-buses (MeleeHit, RangedShot, Ambient) — відкладено після MVP.

---

## 3. Реалізація loop музики (bugfix 05.06.2026)

**Проблема:** WAV-треки грали один раз і зупинялись.

**Спроба #1 (зламана):** Встановити `AudioStreamWAV.loop_mode = LOOP_FORWARD` + `loop_end = 0` в коді під час завантаження. `loop_end = 0` означає "кінець петлі на семпл 0" — відтворення не починалось взагалі.

**Рішення (фінальне):** Сигнал `finished` на кожному музичному плеєрі.

```gdscript
# AudioManager._create_players()
func _create_players() -> void:
    for i in 2:
        var player := AudioStreamPlayer.new()
        player.bus = "Music"
        add_child(player)
        player.finished.connect(_on_music_player_finished.bind(player))
        _music_players.append(player)
    ...

func _on_music_player_finished(player: AudioStreamPlayer) -> void:
    if player == _music_players[_active_music_idx]:
        player.play()
```

**Чому це безпечно з crossfade:**
- `stop()` після кросфейду **не** емітує `finished` в Godot 4 — попередній плеєр не перезапускається.
- Активний плеєр перевіряється через `_active_music_idx` — якщо плеєр вже не активний, рестарту немає.
- Сигнал підключається один раз у `_create_players()` — без накопичення з'єднань.

---

## 4. Список SFX ✅ ПОВНІСТЮ ЗАВЕРШЕНО (v3.6)

| Ключ | Подія | Файл | Місце виклику |
|------|-------|------|---------------|
| `hit_melee` | Удар холодною зброєю | `hit_melee.wav` ✅ | `CombatUnit._perform_attack_logic` — при `is_hit` |
| `hit_ranged` | Постріл / влучання | `hit_ranged.wav` ✅ | `CombatUnit.execute_shoot` — перед await |
| `death` | Смерть юніта | `death.wav` ✅ | `CombatUnit.die()` — після `is_dead = true` |
| `ui_click` | Клік кнопки UI | `ui_click.wav` ✅ | `MainMenu.gd` — btn_new, btn_continue, `_open_settings` |
| `buy` | Купівля предмета | `buy.wav` ✅ | `WorldMap._on_trade_buy_provisions`, `_on_buy_shop_item` |
| `level_up` | Підвищення рівня | `level_up.wav` ✅ | `CombatUnit.gain_xp` — після `level += 1` |
| `heal` | Лікування загону | `heal.wav` ✅ | `WorldMap._on_trade_heal_squad` |
| `hire` | Найм бійця | `hire.wav` ✅ | `WorldMap._on_hire_recruit` |
| `notification` | Відкриття локації | `notification.wav` ✅ | `WorldMap._show_discovery_notification` |

---

## 4. BattleManager AudioManager guard (bugfix #2 — 05.06.2026)

**Проблема:** Пряме звернення `AudioManager.play_music("battle")` у `BattleManager._ready()` (рядок 43) могло призводити до краша якщо AudioManager Autoload не ініціалізувався. Симптом: бежевий фон без юнітів — `_ready()` зупинявся на рядку 43, вся ініціалізація черги/юнітів/камери не виконувалась.

**Причина конкретного інциденту (05.06.2026):** Під час правки AudioManager.gd метод `_on_music_player_finished` був referenced в `_create_players()` але ще не оголошений (між двома commit-кроками). GDScript викинув parsing error → Autoload не завантажився → перший запуск після правки давав beige screen.

**Рішення (BattleManager.gd:43):**
```gdscript
# Було (крашило якщо AudioManager broken):
AudioManager.play_music("battle")

# Стало (стійко до відсутності Autoload):
var audio_mgr := get_node_or_null("/root/AudioManager")
if audio_mgr:
    audio_mgr.play_music("battle")
else:
    push_warning("BattleManager: AudioManager недоступний — перезапусти Godot Editor")
```

**Діагностика:** Додано `print("BattleManager: _ready() ЗАВЕРШЕНО")` в кінці `_ready()`. Якщо цей рядок відсутній у консолі при запуску бою — ініціалізація зупинилась десь вище.

---

## 5. Crossfade деталі

`_active_music_idx` (0 або 1) вказує на активний плеєр. При виклику `play_music()`:
1. Перевірка: якщо ключ той самий — return
2. `ResourceLoader.exists(path)` — якщо немає файлу → `push_warning`, return
3. Попередній плеєр: fade out до `–80 dB` за 1.5s
4. Новий плеєр: старт з `–80 dB`, fade in до `0 dB` за 1.5s
5. Після завершення tween: `prev_player.stop()` (CONNECT_ONE_SHOT)

---

## 6. Меню налаштувань ✅ ЗАВЕРШЕНО (v3.3)

Реалізовано в `MainMenu.gd` як lazy-created overlay.

**Структура:**
```
Control (overlay, full rect)
├── ColorRect (dimmer 0.65α, клік → закрити)
└── CenterContainer (full rect)
    └── PanelContainer (min_w=400, border gold 2px, bg Color(0.07,0.065,0.055))
        └── MarginContainer (20px) → VBoxContainer (sep=12)
            ├── Label "Налаштування" (22px, gold)
            ├── HSeparator (gold)
            ├── HBoxContainer: Label "Мова:" + OptionButton (uk/en)
            ├── Label "Музика N%" (оновлюється під час drag)
            ├── HSlider 0–100 (gold grabber, dark track)
            ├── Label "Звуки N%"
            ├── HSlider 0–100
            └── HBoxContainer (center): Button "Закрити"
```

**Зберігання:** `AudioManager.set_music_volume()` → `settings.cfg [audio]` автоматично.  
**Локалізація:** всі тексти через `tr()`, `_update_settings_texts()` викликається при зміні мови.

---

## 7. Структура папок аудіо

```
assets/audio/
├── music/               ✅ обидва треки додані, імпортовані, зациклені
│   ├── map_theme.wav    ✅
│   └── battle_theme.wav ✅
└── sfx/                 ✅ всі 9 файлів додані і імпортовані
    ├── hit_melee.wav    ✅
    ├── hit_ranged.wav   ✅
    ├── death.wav        ✅
    ├── ui_click.wav     ✅
    ├── buy.wav          ✅
    ├── level_up.wav     ✅
    ├── heal.wav         ✅
    ├── hire.wav         ✅
    └── notification.wav ✅
```

---

## 8. На майбутнє — Dynamic Audio Layers (після MVP)

Замість одного суцільного треку — розбити бойову музику на стеми: барабани, бас, атмосфера, лід-мелодія. Кожен стем — окремий `AudioStreamPlayer`. Гучність кожного шару змінюється залежно від ігрової ситуації:

| Ситуація | Ефект |
|----------|-------|
| Початок бою, всі живі | Всі шари на повній гучності |
| HP активного юніта < 25% | Low-pass filter на лід-мелодії, підсилити барабани |
| Мораль «Зламаний» / «Тікає» | Різко знизити бас, залишити лише атмосферу й хор |
| Перемога | Поступовий fade out + fanfare |

`BattleManager` емітує сигнал `tension_changed(level: int)` → `AudioManager` (autoload) реагує tweens.

---

**Версія:** 3.6 — оновлено 05.06.2026 (bugfix #1: loop через сигнал finished; bugfix #2: BattleManager AudioManager guard)
