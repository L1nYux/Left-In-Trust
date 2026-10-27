extends Control
class_name BattleUIDecor

## Non-interactive battle-stage chrome. The playable controls stay in
## main_stage2.gd; this layer only establishes the duel composition.
## Turn banners and fake reticles were removed so the stage reads like a
## clean Slay-the-Spire style encounter; turn info lives in the UI layer.

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
		Vector2(0, 0), Vector2(width * 0.59, 0),
		Vector2(width * 0.53, height * 0.68), Vector2(0, height * 0.78)
	]), Color("bdebf0", 0.06))
	draw_colored_polygon(PackedVector2Array([
		Vector2(width * 0.62, 0), Vector2(width, 0), Vector2(width, height * 0.76),
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

	# Soft top and bottom vignettes keep the HUD labels readable over the arena
	# without drawing a solid header band.
	for band in 3:
		var top_height := 30.0
		var top_y := top_height * float(band)
		draw_rect(Rect2(0, top_y, width, top_height + 1), Color("050916", 0.13 - float(band) * 0.04), true)
	for band in 4:
		var band_height := 34.0
		var y := height - band_height * float(band + 1)
		draw_rect(Rect2(0, y, width, band_height + 1), Color("050916", 0.08 + float(band) * 0.055), true)

	# The cyan/red contact line keeps the two sides visually opposed.
	draw_line(Vector2(width * 0.46, height * 0.43), Vector2(width * 0.61, height * 0.38), Color("70e4ff", 0.42), 2.0, true)
	draw_line(Vector2(width * 0.61, height * 0.38), Vector2(width * 0.72, height * 0.34), Color("ff5572", 0.32), 2.0, true)
