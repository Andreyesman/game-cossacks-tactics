extends Node

const IsoMath = preload("res://src/core/IsoMath.gd")

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("\n=== TestIsoMath ===")
	_test_get_dist_4()
	_test_cell_roundtrip()
	_test_line_of_sight()
	print("=== Результат: %d ✓  %d ✗ ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ✓ %s" % label)
		_passed += 1
	else:
		push_error("  ✗ ПРОВАЛ: %s" % label)
		_failed += 1

func _test_get_dist_4() -> void:
	print("--- get_dist_4 ---")
	_assert(IsoMath.get_dist_4(Vector2i(0, 0), Vector2i(3, 4)) == 7,  "(0,0)→(3,4) = 7")
	_assert(IsoMath.get_dist_4(Vector2i(2, 2), Vector2i(2, 2)) == 0,  "однакові точки = 0")
	_assert(IsoMath.get_dist_4(Vector2i(-1, 0), Vector2i(1, 0)) == 2, "від'ємні координати = 2")

func _test_cell_roundtrip() -> void:
	print("--- get_cell_center / local_to_map ---")
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(5, 3), Vector2i(10, 7)]:
		var center: Vector2 = IsoMath.get_cell_center(pos)
		var back: Vector2i = IsoMath.local_to_map(center)
		_assert(back == pos, "round-trip %s" % str(pos))

func _test_line_of_sight() -> void:
	print("--- get_line_of_sight_path ---")
	var path: Array[Vector2i] = IsoMath.get_line_of_sight_path(Vector2i(0, 0), Vector2i(3, 0))
	_assert(path.size() == 4,               "горизонтальна лінія: 4 клітинки")
	_assert(path.front() == Vector2i(0, 0), "починається з (0,0)")
	_assert(path.back()  == Vector2i(3, 0), "закінчується на (3,0)")
	var diag: Array[Vector2i] = IsoMath.get_line_of_sight_path(Vector2i(0, 0), Vector2i(2, 2))
	_assert(diag.front() == Vector2i(0, 0), "діагональ: початок (0,0)")
	_assert(diag.back()  == Vector2i(2, 2), "діагональ: кінець (2,2)")
