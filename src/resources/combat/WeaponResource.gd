extends Resource
class_name WeaponResource
## Ресурс для зброї, що зберігає базові статти та масив об'єктів AttackAction.

enum WeaponType { SWORD, SPEAR, AXE, MACE, MUSKET, POLEARM, DAGGER, BOW, THROWING }

@export var name: String = "Common Weapon"
@export var type: WeaponType = WeaponType.SWORD
@export var icon: Texture2D

@export_group("Base Stats")
@export var damage_min: int = 20
@export var damage_max: int = 35
@export var armor_penetration: float = 0.0 # 0.0 to 1.0
@export var armor_damage_modifier: float = 1.0 # 1.0 = 100% (Warhammer is 1.5)
@export var shield_damage_modifier: float = 1.0 # (Axe is 1.5)
@export var weapon_range: int = 1
@export var weight: int = 10 # Впливає на втому (Fatigue)
@export var initiative_penalty: int = 0

@export_group("Actions")
@export var actions: Array[AttackAction] = []

@export_group("Requirement")
@export var is_two_handed: bool = false
