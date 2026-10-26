extends Control

var card_kind := "attack"
var owner_id := ""
var accent := Color("69d7e7")

func configure(kind: String, owner: String, color: Color) -> void:
	card_kind = kind
	owner_id = owner
	accent = color
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("10182a"), true)
	draw_rect(Rect2(2, 2, maxf(0.0, size.x - 4), maxf(0.0, size.y - 4)), Color(accent, 0.22), true)
	for index in 5:
		var y := 12.0 + float(index) * maxf(8.0, (size.y - 24.0) / 5.0)
		draw_line(Vector2(8, y), Vector2(size.x - 8, y - 6), Color("f2efe7", 0.08), 1.0)
	match card_kind:
		"guard":
			_draw_guard()
		"heal":
			_draw_heal()
		"transfer":
			_draw_transfer()
		_:
			_draw_attack()
	_draw_owner_mark()

func _draw_attack() -> void:
	var start := Vector2(size.x * 0.18, size.y * 0.78)
	var finish := Vector2(size.x * 0.78, size.y * 0.22)
	draw_line(start, finish, Color("f2efe7", 0.35), 12.0, true)
	draw_line(start, finish, accent, 5.0, true)
	var arrow := PackedVector2Array([
		finish + Vector2(-16, 2),
		finish + Vector2(8, -8),
		finish + Vector2(-2, 17)
	])
	draw_colored_polygon(arrow, accent)
	for index in 3:
		var point := start.lerp(finish, 0.2 + float(index) * 0.22)
		draw_circle(point, 5.0, Color("f2efe7"))

func _draw_guard() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	var shield := PackedVector2Array([
		center + Vector2(-29, -28),
		center + Vector2(29, -28),
		center + Vector2(25, 12),
		center + Vector2(0, 39),
		center + Vector2(-25, 12)
	])
	draw_colored_polygon(shield, Color(accent, 0.26))
	draw_polyline(shield, accent, 6.0, true)
	draw_line(center + Vector2(0, -21), center + Vector2(0, 22), Color("f2efe7", 0.78), 3.0)

func _draw_heal() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	for radius in [38.0, 29.0, 20.0]:
		draw_arc(center, radius, 0.2, TAU - 0.35, 32, Color(accent, 0.36 + (38.0 - radius) / 80.0), 3.0, true)
	draw_rect(Rect2(center - Vector2(6, 24), Vector2(12, 48)), Color("f2efe7"), true)
	draw_rect(Rect2(center - Vector2(24, 6), Vector2(48, 12)), Color("f2efe7"), true)

func _draw_transfer() -> void:
	var left := Vector2(size.x * 0.27, size.y * 0.52)
	var right := Vector2(size.x * 0.73, size.y * 0.52)
	draw_circle(left, 15.0, Color(accent, 0.7))
	draw_circle(right, 15.0, Color("f2b85b", 0.85))
	draw_line(left + Vector2(17, 0), right - Vector2(19, 0), Color("f2efe7", 0.8), 5.0, true)
	var arrow := PackedVector2Array([
		right + Vector2(-25, -10),
		right + Vector2(-8, 0),
		right + Vector2(-25, 10)
	])
	draw_colored_polygon(arrow, Color("f2efe7"))

func _draw_owner_mark() -> void:
	if owner_id.is_empty():
		return
	var center := Vector2(size.x - 18, 18)
	draw_circle(center, 11.0, Color("0a101b", 0.88))
	draw_arc(center, 11.0, 0.0, TAU, 20, accent, 2.0, true)
	if owner_id == "GPT":
		draw_circle(center, 4.0, accent)
	elif owner_id == "Claude":
		draw_line(center + Vector2(-4, -6), center + Vector2(-4, 6), accent, 3.0)
		draw_line(center + Vector2(4, -6), center + Vector2(4, 6), accent, 3.0)
	else:
		draw_arc(center, 6.0, 0.0, PI, 12, accent, 3.0, true)
