extends Control

## One independently transformable drawing layer used by LayeredActor2D.
## All three Demo roles use formal transparent art. The procedural fallback is
## retained so future roles can enter the shared motion controller before their
## final six-piece art kit is ready.

const FORMAL_MASTERS := {
	"GPT": preload("res://assets/actors/gpt/gpt_master_v1.png"),
	"Claude": preload("res://assets/actors/claude/claude_master_v1.png"),
	"DeepSeek": preload("res://assets/actors/deepseek/deepseek_master_v1.png")
}
const FORMAL_SCALES := {"GPT": 0.9, "Claude": 0.88, "DeepSeek": 0.88}
const FORMAL_MASTER_RECTS := {
	"GPT": Rect2(-19, -40, 208, 325),
	"Claude": Rect2(-26, -42, 222, 332),
	"DeepSeek": Rect2(-26, -42, 222, 332)
}

var layer_id := "body"
var role_id := "GPT"
var profile: Dictionary = {}
var effect_tag := "idle"
var selected := false


func configure(next_layer_id: String, next_role_id: String, next_profile: Dictionary) -> void:
	layer_id = next_layer_id
	role_id = next_role_id
	profile = next_profile
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_effect(next_effect_tag: String) -> void:
	effect_tag = next_effect_tag
	queue_redraw()


func set_selected(next_selected: bool) -> void:
	selected = next_selected
	queue_redraw()


func _draw() -> void:
	if profile.is_empty():
		return
	if FORMAL_MASTERS.has(role_id) and bool(profile.get("formal_art", false)) and layer_id in ["back", "body", "head", "prop", "front"]:
		_draw_formal_actor_layer()
		return
	match layer_id:
		"shadow":
			_draw_shadow()
		"aura":
			_draw_aura()
		"back":
			_draw_back()
		"body":
			_draw_body()
		"head":
			_draw_head()
		"prop":
			_draw_prop()
		"front":
			_draw_front()
		"effect":
			_draw_effect()


func _draw_formal_actor_layer() -> void:
	# The generated part cells are retained for later rigging, but their neck and
	# collar contours were painted independently and cannot form a reliable seam.
	# Runtime therefore keeps the character silhouette on one coherent master
	# layer. The surrounding logical layers still carry aura, state and card-type
	# effects, so motion stays reusable without ever separating head from torso.
	if layer_id != "body":
		return
	var master: Texture2D = FORMAL_MASTERS[role_id]
	var master_rect: Rect2 = FORMAL_MASTER_RECTS.get(role_id, Rect2(-26, -42, 222, 332))
	draw_texture_rect(master, _formal_actor_rect(master_rect), false)


func _formal_actor_rect(source: Rect2) -> Rect2:
	var pivot := Vector2(size.x * 0.5, 160)
	var art_scale := float(FORMAL_SCALES.get(role_id, 0.88))
	return Rect2(pivot + (source.position - pivot) * art_scale, source.size * art_scale)


func _color(key: String, fallback: String = "ffffff") -> Color:
	return Color(str(profile.get(key, fallback)))


func _p(x_ratio: float, y_ratio: float) -> Vector2:
	return Vector2(size.x * x_ratio, size.y * y_ratio)


func _ellipse(center: Vector2, radius: Vector2, color: Color, points := 32) -> void:
	var vertices := PackedVector2Array()
	for index in points:
		var angle := TAU * float(index) / float(points)
		vertices.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(vertices, color)


func _draw_shadow() -> void:
	_ellipse(_p(0.5, 0.92), Vector2(size.x * 0.31, size.y * 0.035), Color(0.01, 0.02, 0.06, 0.48))


func _draw_aura() -> void:
	var accent := _color("accent")
	accent.a = 0.72 if selected else 0.25
	draw_arc(_p(0.5, 0.57), size.x * (0.38 if selected else 0.34), -2.72, 0.42, 34, accent, 2.2, true)
	var soft := accent
	soft.a *= 0.34
	draw_circle(_p(0.5, 0.57), size.x * 0.29, soft)


func _draw_back() -> void:
	var dark := _color("dark")
	var secondary := _color("secondary")
	match str(profile.get("motif", "segments")):
		"book":
			var page_left := PackedVector2Array([_p(0.18, 0.36), _p(0.48, 0.31), _p(0.48, 0.82), _p(0.16, 0.77)])
			var page_right := PackedVector2Array([_p(0.52, 0.31), _p(0.82, 0.36), _p(0.84, 0.77), _p(0.52, 0.82)])
			draw_colored_polygon(page_left, Color(dark, 0.92))
			draw_colored_polygon(page_right, Color(dark, 0.92))
			draw_polyline(page_left + PackedVector2Array([page_left[0]]), secondary, 2.0, true)
			draw_polyline(page_right + PackedVector2Array([page_right[0]]), secondary, 2.0, true)
		"ripple":
			for radius_ratio in [0.23, 0.29, 0.35]:
				var ring := secondary
				ring.a = 0.34
				draw_arc(_p(0.5, 0.7), size.x * radius_ratio, PI, TAU, 28, ring, 2.0, true)
		_:
			for index in 3:
				var x := 0.25 + float(index) * 0.25
				var segment := Rect2(_p(x - 0.065, 0.49 - float(index) * 0.035), Vector2(size.x * 0.13, size.y * 0.26))
				draw_style_box(_rounded_box(Color(dark, 0.8), secondary, 8), segment)


func _draw_body() -> void:
	var body := _color("body")
	var dark := _color("dark")
	var outline := _color("outline")
	var torso := PackedVector2Array([_p(0.29, 0.51), _p(0.42, 0.43), _p(0.58, 0.43), _p(0.71, 0.51), _p(0.78, 0.89), _p(0.22, 0.89)])
	draw_colored_polygon(torso, body)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 2.0, true)
	draw_colored_polygon(PackedVector2Array([_p(0.42, 0.45), _p(0.5, 0.58), _p(0.58, 0.45)]), dark)
	draw_line(_p(0.5, 0.58), _p(0.5, 0.87), Color(outline, 0.5), 1.4, true)


func _draw_head() -> void:
	var skin := _color("skin")
	var hair := _color("hair")
	var dark := _color("dark")
	var center := _p(0.5, 0.3)
	draw_circle(center, size.x * 0.205, skin)
	draw_arc(center, size.x * 0.205, 0.0, TAU, 36, _color("outline"), 2.0, true)
	var cap := PackedVector2Array([_p(0.3, 0.29), _p(0.34, 0.16), _p(0.49, 0.09), _p(0.68, 0.16), _p(0.71, 0.29), _p(0.62, 0.23), _p(0.54, 0.27), _p(0.45, 0.21), _p(0.37, 0.26)])
	draw_colored_polygon(cap, hair)
	draw_circle(_p(0.43, 0.31), size.x * 0.015, dark)
	draw_circle(_p(0.57, 0.31), size.x * 0.015, dark)
	draw_arc(_p(0.5, 0.34), size.x * 0.045, 0.22, PI - 0.22, 12, Color(dark, 0.72), 1.2, true)


func _draw_prop() -> void:
	var accent := _color("accent")
	var secondary := _color("secondary")
	var outline := _color("outline")
	match str(profile.get("motif", "segments")):
		"book":
			var book := Rect2(_p(0.5, 0.5), Vector2(size.x * 0.37, size.y * 0.22))
			draw_style_box(_rounded_box(_color("dark"), accent, 5), book)
			draw_line(_p(0.685, 0.51), _p(0.685, 0.71), accent, 2.0, true)
			draw_line(_p(0.74, 0.55), _p(0.82, 0.55), Color("fff1df"), 1.5, true)
			draw_line(_p(0.74, 0.59), _p(0.84, 0.59), Color("fff1df"), 1.5, true)
			var bookmark := PackedVector2Array([_p(0.79, 0.5), _p(0.83, 0.5), _p(0.83, 0.66), _p(0.81, 0.63), _p(0.79, 0.66)])
			draw_colored_polygon(bookmark, secondary)
		"ripple":
			draw_style_box(_rounded_box(_color("dark"), accent, 6), Rect2(_p(0.52, 0.56), Vector2(size.x * 0.34, size.y * 0.17)))
			for ring_index in 3:
				draw_arc(_p(0.69, 0.56), size.x * (0.06 + ring_index * 0.035), PI, TAU, 18, Color(secondary, 0.88 - ring_index * 0.2), 1.8, true)
			draw_colored_polygon(PackedVector2Array([_p(0.79, 0.5), _p(0.88, 0.46), _p(0.84, 0.55)]), accent)
		_:
			draw_line(_p(0.55, 0.58), _p(0.82, 0.47), outline, 7.0, true)
			for index in 3:
				var center := _p(0.73 + index * 0.07, 0.43 - index * 0.035)
				draw_circle(center, size.x * 0.055, Color(accent, 0.92 - index * 0.15))
			draw_line(_p(0.68, 0.47), _p(0.88, 0.36), secondary, 2.6, true)


func _draw_front() -> void:
	var accent := _color("accent")
	var motif := str(profile.get("motif", "segments"))
	if motif == "book":
		draw_line(_p(0.31, 0.57), _p(0.2, 0.72), accent, 8.0, true)
		draw_arc(_p(0.31, 0.69), size.x * 0.11, 1.7, 4.45, 18, accent, 2.0, true)
	elif motif == "ripple":
		draw_line(_p(0.31, 0.57), _p(0.22, 0.76), accent, 8.0, true)
		for radius_ratio in [0.045, 0.08, 0.115]:
			draw_arc(_p(0.26, 0.74), size.x * radius_ratio, 0.0, PI, 14, Color(accent, 0.75), 1.6, true)
	else:
		draw_line(_p(0.31, 0.57), _p(0.2, 0.73), accent, 8.0, true)
		for index in 3:
			draw_circle(_p(0.32 + index * 0.09, 0.76), size.x * 0.024, Color(accent, 0.55 + index * 0.18))


func _draw_effect() -> void:
	var accent := _color("accent")
	var secondary := _color("secondary")
	var motif := str(profile.get("motif", "segments"))
	if effect_tag in ["light_attack", "heavy_attack", "basic"]:
		var width := 5.0 if effect_tag == "heavy_attack" else 3.0
		if motif == "book":
			draw_arc(_p(0.72, 0.48), size.x * 0.31, -1.15, 0.62, 24, accent, width, true)
			draw_line(_p(0.84, 0.26), _p(0.94, 0.19), secondary, width, true)
		elif motif == "ripple":
			for index in 3:
				draw_arc(_p(0.82, 0.5), size.x * (0.14 + index * 0.08), -0.78, 0.78, 18, Color(accent, 0.9 - index * 0.2), width, true)
		else:
			for index in 3:
				draw_line(_p(0.58, 0.5 - index * 0.055), _p(0.98, 0.39 - index * 0.025), Color(accent, 1.0 - index * 0.18), width, true)
	elif effect_tag == "guard":
		if motif == "book":
			draw_arc(_p(0.5, 0.58), size.x * 0.42, -1.35, 1.35, 30, accent, 4.0, true)
			draw_line(_p(0.8, 0.28), _p(0.8, 0.84), secondary, 3.0, true)
		elif motif == "ripple":
			for index in 3:
				draw_arc(_p(0.5, 0.72), size.x * (0.22 + index * 0.085), PI, TAU, 26, Color(accent, 0.95 - index * 0.2), 3.0, true)
		else:
			draw_arc(_p(0.53, 0.57), size.x * 0.4, -1.42, 1.42, 30, accent, 3.0, true)
			for index in 3:
				draw_circle(_p(0.79, 0.4 + index * 0.1), size.x * 0.025, secondary)
	elif effect_tag in ["support", "transfer"]:
		for index in 5:
			var point := _p(0.42 + index * 0.11, 0.55 - sin(float(index)) * 0.09)
			draw_circle(point, size.x * (0.018 + index * 0.003), Color(accent, 0.55 + index * 0.09))
		if effect_tag == "transfer":
			draw_line(_p(0.45, 0.56), _p(0.92, 0.51), secondary, 2.0, true)


func _rounded_box(fill: Color, border: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(radius))
	return box
