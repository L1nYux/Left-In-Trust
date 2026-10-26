extends Control

const TEXTURES := {
	"back": preload("res://assets/enemies/missing_attachment/layers/missing_attachment_back_v1.png"),
	"body": preload("res://assets/enemies/missing_attachment/layers/missing_attachment_body_v1.png"),
	"legs": preload("res://assets/enemies/missing_attachment/layers/missing_attachment_legs_v1.png"),
	"core": preload("res://assets/enemies/missing_attachment/layers/missing_attachment_core_v1.png")
}

var layer_id := "body"
var effect_tag := "idle"


func configure(next_layer_id: String) -> void:
	layer_id = next_layer_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_effect(next_tag: String) -> void:
	effect_tag = next_tag
	queue_redraw()


func _draw() -> void:
	if TEXTURES.has(layer_id):
		draw_texture_rect(TEXTURES[layer_id], _art_rect(), false)
		return
	if layer_id == "shadow":
		_draw_shadow()
	elif layer_id == "effect":
		_draw_effect()


func _art_rect() -> Rect2:
	var target_width := minf(400.0, size.x)
	var target_height := target_width * 2.0 / 3.0
	return Rect2((size.x - target_width) * 0.5, 38.0, target_width, target_height)


func _draw_shadow() -> void:
	var vertices := PackedVector2Array()
	var center := Vector2(size.x * 0.5, size.y * 0.89)
	for index in 36:
		var angle := TAU * float(index) / 36.0
		vertices.append(center + Vector2(cos(angle) * size.x * 0.31, sin(angle) * size.y * 0.035))
	draw_colored_polygon(vertices, Color("050610", 0.58))


func _draw_effect() -> void:
	if effect_tag == "idle":
		return
	var center := Vector2(size.x * 0.49, size.y * 0.49)
	if effect_tag == "attack":
		for index in 3:
			draw_line(center + Vector2(-35, -38 + index * 35), Vector2(-12, 92 + index * 12), Color("ff4568", 0.9 - index * 0.18), 5.0 - index, true)
	elif effect_tag == "hit":
		for index in 8:
			var angle := TAU * float(index) / 8.0
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(center + direction * 52.0, center + direction * 86.0, Color("ffcf70", 0.85), 3.0, true)
		draw_arc(center, 66.0, 0.0, TAU, 30, Color("ff5572", 0.82), 3.0, true)
