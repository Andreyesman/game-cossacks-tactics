extends Resource
class_name AttackAction
## Ресурс для опису конкретної атаки (наприклад, "Замах", "Випад").

enum DamageType { SLASH, PIERCE, BLUNT, FIRE, RANGED }

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var damage_type: DamageType = DamageType.SLASH

@export_group("Costs")
@export var ap_cost: int = 4
@export var stamina_cost: int = 10
@export var hit_chance_modifier: int = 0 # Прямий бонус до шансу влучання (%)

@export_group("Stats")
@export var attack_range: int = 1
@export var damage_multiplier: float = 1.0
@export var armor_penetration_bonus: float = 0.0 # Додаткове пробиття до базового у зброї
@export var head_hit_chance_bonus: float = 0.0 # Базовий шанс 15%
@export var ignores_shield: bool = false
@export var guaranteed_headshot: bool = false
@export var animation_type: String = "strike" # "strike", "thrust", "shoot", etc.
@export var icon: Texture2D
