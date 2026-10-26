extends Control
class_name BattleUIDecor

## Non-interactive battle-stage chrome. The playable controls stay in
## main_stage2.gd; this layer only establishes the duel composition.

var turn_index := 1


func configure(turn_value: int) -> void:
	turn_index = maxi(1, turn_value)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width <= 0.0 or height <= 0.0:
		return

	# Stage split: cool team space on the left, hostile fracture space on the right.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 54), Vector2(width * 0.59, 54),
		Vector2(width * 0.53, height * 0.68), Vector2(0, height * 0.78)
	]), Color("bdebf0", 0.06))
	draw_colored_polygon(PackedVector2Array([
		Vector2(width * 0.62, 54), Vector2(width, 54), Vector2(width, height * 0.76),
		Vector2(width * 0.55, height * 0.67)
	]), Color("ff365c", 0.075))

	# Enemy-side fracture lines echo the red threat language without obscuring art.
	var fracture := Color("ff4568", 0.34)
	for segment in [
		[Vector2(width * 0.78, 82), Vector2(width * 0.89, 148)],
		[Vector2(width * 0.89, 148), Vector2(width * 0.96, 104)],
		[Vector2(width * 0.89, 148), Vector2(width * 0.97, 224)],
		[Vector2(width * 0.76, 306), Vector2(width * 0.88, 254)],
		[Vector2(width * 0.88, 254), Vector2(width * 0.98, 322)]
	]:
		draw_line(segment[0], segment[1], fracture, 2.0, true)

	# Header glass and bottom vignette keep information readable over the arena.
	draw_rect(Rect2(0, 0, width, 54), Color("07101f", 0.9), true)
	draw_line(Vector2(0, 54), Vector2(width, 54), Color("91a7cc", 0.45), 1.0)
	for band in 4:
		var band_height := 34.0
		var y := height - band_height * float(band + 1)
		draw_rect(Rect2(0, y, width, band_height + 1), Color("050916", 0.08 + float(band) * 0.055), true)

	# Round medallion.
	var round_center := Vector2(47, 27)
	draw_circle(round_center, 17.0, Color("dce9ff", 0.13))
	draw_circle(round_center, 11.5, Color("dce9ff", 0.88))
	draw_colored_polygon(PackedVector2Array([
		round_center + Vector2(0, -11.5), round_center + Vector2(11.5, 0),
		round_center + Vector2(0, 0)
	]), Color("6989c8", 0.82))

	# Compact progress track, deliberately decorative for now.
	var track_start := Vector2(width * 0.36, 27)
	var track_end := Vector2(width * 0.67, 27)
	draw_line(track_start, track_end, Color("b7c7e7", 0.46), 2.0, true)
	var current_step := mini(6, (turn_index - 1) % 7)
	for step in 7:
		var ratio := float(step) / 6.0
		var center := track_start.lerp(track_end, ratio)
		var radius := 8.5 if step == current_step else 4.0
		if step == current_step:
			draw_circle(center, 13.0, Color("07101f", 0.9))
			draw_arc(center, 13.0, 0.0, TAU, 24, Color("69a8ff", 0.78), 2.0, true)
		draw_circle(center, radius, Color("7fb3ff") if step == current_step else Color("d7e1f5", 0.75))

	# Utility glyphs are visual anchors only; no fake clickable buttons.
	for index in 4:
		var icon_center := Vector2(width - 164.0 + float(index) * 42.0, 27)
		draw_rect(Rect2(icon_center - Vector2(7, 8), Vector2(14, 16)), Color("b9c7df", 0.12), true)
		draw_rect(Rect2(icon_center - Vector2(7, 8), Vector2(14, 16)), Color("b9c7df", 0.72), false, 1.5)
		if index == 3:
			draw_circle(icon_center, 3.5, Color("b9c7df", 0.8))

	# The cyan/red contact line keeps the two sides visually opposed.
	draw_line(Vector2(width * 0.46, height * 0.43), Vector2(width * 0.61, height * 0.38), Color("70e4ff", 0.42), 2.0, true)
	draw_line(Vector2(width * 0.61, height * 0.38), Vector2(width * 0.72, height * 0.34), Color("ff5572", 0.32), 2.0, true)
