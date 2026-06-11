class_name UnitData
extends Resource

@export var unit_name: String = "Новобранець"
@export var background: String = "Peasant"

# Базові характеристики (Design Doc v24)
@export var base_hp: int = 60
@export var base_stamina: int = 90
@export var base_body_armor: int = 0
@export var base_head_armor: int = 0
@export var base_melee_skill: int = 50
@export var base_ranged_skill: int = 35
@export var base_melee_defense: int = 5
@export var base_ranged_defense: int = 5
@export var base_initiative: int = 60
@export var base_resolve: int = 40

# Зірочки талантів (0 - немає, 1, 2, 3)
@export var star_hp: int = 0
@export var star_melee: int = 0
@export var star_defense: int = 0

# Походження (для Character Sheet)
@export var origin_name: String = ""
@export var origin_trait: String = ""
@export var origin_bonus: String = ""

# Портрет для UI (черга ходів, панель, вікно юніта)
@export var portrait: Texture2D

# Нагорода за перемогу (XP, яку отримує той хто вбив)
@export var xp_reward: int = 30

# Екіпірування
@export var default_weapon: WeaponResource
@export var default_armor: ArmorResource
@export var default_helmet: HelmetResource
