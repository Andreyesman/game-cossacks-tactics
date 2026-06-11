class_name ChunkLibrary
extends RefCounted

# Типи зон — задають "характер" кожної чверті карти 8×8
enum ZoneType { OPEN, FOREST, ROCKY, WETLAND, RIVER_EDGE }

# Ваги для WFC по кожному типу зони: [CLEAR, BUSHES, SWAMP, WATER, ROCKS, TREE]
const ZONE_WEIGHTS: Dictionary = {
	ZoneType.OPEN:       [75, 15,  2,  2,  4,  2],
	ZoneType.FOREST:     [20, 20,  3,  2, 10, 45],
	ZoneType.ROCKY:      [35, 20,  5,  2, 30,  8],
	ZoneType.WETLAND:    [20, 15, 40, 15,  2,  8],
	ZoneType.RIVER_EDGE: [30, 10, 20, 35,  5,  0],
}

# Лейаут = [TL, TR, BL, BR] — типи зон для 4 квадрантів карти
# Індекси відповідають WFCGenerator.LocationType: 0=STEPPE 1=FOREST 2=WETLANDS 3=RIVER
const LAYOUTS: Dictionary = {
	0: [  # STEPPE — степ
		[ZoneType.OPEN, ZoneType.OPEN,   ZoneType.OPEN,    ZoneType.OPEN],
		[ZoneType.OPEN, ZoneType.ROCKY,  ZoneType.OPEN,    ZoneType.OPEN],
		[ZoneType.OPEN, ZoneType.OPEN,   ZoneType.WETLAND, ZoneType.OPEN],
		[ZoneType.OPEN, ZoneType.ROCKY,  ZoneType.WETLAND, ZoneType.OPEN],
	],
	1: [  # FOREST — ліс
		[ZoneType.FOREST, ZoneType.OPEN,   ZoneType.ROCKY,  ZoneType.FOREST],
		[ZoneType.FOREST, ZoneType.FOREST, ZoneType.OPEN,   ZoneType.FOREST],
		[ZoneType.FOREST, ZoneType.ROCKY,  ZoneType.FOREST, ZoneType.FOREST],
		[ZoneType.FOREST, ZoneType.OPEN,   ZoneType.FOREST, ZoneType.ROCKY],
	],
	2: [  # WETLANDS — болото
		[ZoneType.WETLAND, ZoneType.WETLAND, ZoneType.OPEN,    ZoneType.WETLAND],
		[ZoneType.OPEN,    ZoneType.WETLAND, ZoneType.WETLAND, ZoneType.WETLAND],
		[ZoneType.WETLAND, ZoneType.OPEN,    ZoneType.WETLAND, ZoneType.WETLAND],
	],
	3: [  # RIVER — річка
		[ZoneType.RIVER_EDGE, ZoneType.RIVER_EDGE, ZoneType.OPEN,        ZoneType.OPEN],
		[ZoneType.OPEN,       ZoneType.RIVER_EDGE, ZoneType.OPEN,        ZoneType.RIVER_EDGE],
		[ZoneType.RIVER_EDGE, ZoneType.OPEN,       ZoneType.RIVER_EDGE,  ZoneType.OPEN],
	],
}

# Повертає випадковий лейаут для вказаного типу локації
static func pick_layout(location_type: int) -> Array:
	var options: Array = LAYOUTS[location_type]
	return options[randi() % options.size()]
