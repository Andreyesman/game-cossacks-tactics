@tool
extends EditorScript

## Запустити через Godot Editor: Script → Run
## Друкує реальні висоти Kelly Slab для таблиці Figma↔Godot

func _run() -> void:
	var font: FontFile = load("res://assets/fonts/KellySlab-Regular.ttf")
	if not font:
		print("ПОМИЛКА: шрифт не знайдено")
		return

	var sizes := [12, 13, 14, 15, 16, 18, 20, 26]

	print("\n=== Kelly Slab — реальні висоти в Godot ===")
	print("%-12s %-10s %-10s %-12s %-14s" % ["font_size", "ascent", "descent", "line_height", "label_min_h"])
	print("-" * 60)

	for sz in sizes:
		var ascent  := roundi(font.get_ascent(sz))
		var descent := roundi(font.get_descent(sz))
		var height  := roundi(font.get_height(sz))  # ascent + descent + spacing

		# Реальна мінімальна висота Label (одна строка, без margin)
		var label := Label.new()
		label.text = "Аб"
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", sz)
		label.size = Vector2.ZERO
		# get_minimum_size() без дерева — але font.get_height() дає те саме
		var label_h := height  # Label single-line = font.get_height()

		print("%-12d %-10d %-10d %-12d %-14d" % [sz, ascent, descent, height, label_h])
		label.queue_free()

	print("")
	print("Примітка: label_min_h = висота Label без padding/margin (одна строка)")
	print("Для PanelContainer додай content_margin_top + content_margin_bottom")
	print("Приклад: panel h=56px, font_size=16 → margin = (56 - %d) / 2 = %dpx кожен бік" % [
		roundi(font.get_height(16)),
		(56 - roundi(font.get_height(16))) / 2
	])
