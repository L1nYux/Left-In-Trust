extends Control

## One quiet task sheet; the player's life stage sets paper and margin marks.
## Positions are shared with the real buttons so decorative paths never invent nodes.
const LifeStagesScript = preload("res://scripts/life_stages.gd")
const ORDINARY := Vector2(576, 544)
const REST := Vector2(453, 365)
const BOSS := Vector2(576, 184)
const START := Vector2(576, 616)
const INK := Color("303b38")
var life_stage := LifeStagesScript.DEFAULT
var paper := Color("c9cabe")
var accent := Color("7b8c85")
var ordinary_done := false
var rest_done := false
var boss_done := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(stage_id: String) -> void:
	life_stage = LifeStagesScript.normalize(stage_id)
	paper = LifeStagesScript.THEMES[life_stage]["paper"]
	accent = LifeStagesScript.THEMES[life_stage]["accent"]
	queue_redraw()


func set_progress(ordinary: bool, rest: bool, boss: bool) -> void:
	ordinary_done = ordinary
	rest_done = rest
	boss_done = boss
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("89918a"))
	# The narrow edge is a document sleeve, not a scenic landscape.
	draw_rect(Rect2(261, 94, 650, 570), Color("36453e", 0.10))
	var page := PackedVector2Array([
		Vector2(254, 88), Vector2(894, 88), Vector2(902, 107),
		Vector2(898, 235), Vector2(902, 392), Vector2(897, 561),
		Vector2(901, 656), Vector2(748, 653), Vector2(603, 657),
		Vector2(449, 654), Vector2(252, 657), Vector2(256, 529),
		Vector2(252, 366), Vector2(256, 210)
	])
	draw_colored_polygon(page, paper)
	_draw_scifi_ambient()
	draw_line(Vector2(278, 108), Vector2(278, 633), Color(INK, 0.10), 1.0, true)
	# Sparse technical registration ticks live in the margins, outside the route.
	for index in 23:
		var y := 126.0 + float(index) * 22.0
		draw_line(Vector2(282, y), Vector2(290 if index % 5 == 0 else 286, y), Color(INK, 0.15), 1.0)
	for index in 10:
		var y := 117.0 + float(index) * 53.0
		draw_line(Vector2(841, y), Vector2(875, y), Color(INK, 0.035), 1.0)
	for row in 5:
		for column in 5:
			draw_circle(Vector2(823 + column * 9, 588 + row * 9), 0.7, Color(INK, 0.10))
	_draw_trace(Vector2(300, 135), false)
	_draw_trace(Vector2(813, 610), true)
	_draw_stage_marks()
	_draw_stage_margin()
	# Very shallow paper fibres, deterministic and never coupled to gameplay RNG.
	for index in 52:
		var x := 300.0 + fmod(float(index * 83), 560.0)
		var y := 120.0 + fmod(float(index * 139), 498.0)
		draw_line(Vector2(x, y), Vector2(x + 12 + index % 19, y + 0.4), Color(INK, 0.022), 1.0)

	_draw_route(START, Vector2(574, 586), ORDINARY, true, false, 9.0, 34.0)
	_draw_route(ORDINARY, Vector2(447, 484), REST, ordinary_done, rest_done)
	_draw_route(REST, Vector2(442, 246), BOSS, ordinary_done, boss_done and rest_done)
	_draw_route(ORDINARY, Vector2(825, 369), BOSS, ordinary_done, boss_done and not rest_done)
	draw_circle(START, 4.0, Color(INK, 0.50), false, 1.5, true)
	_draw_state(ORDINARY, not ordinary_done, ordinary_done, 30.0)
	_draw_state(REST, ordinary_done and not rest_done and not boss_done, rest_done, 30.0)
	_draw_state(BOSS, ordinary_done and not boss_done, boss_done, 37.0)
	# Quiet header and footer anchor the sheet without extra panels.
	draw_line(Vector2(0, 78), Vector2(size.x, 78), Color(INK, 0.16), 1.0)
	draw_line(Vector2(32, 660), Vector2(218, 660), Color(INK, 0.20), 1.0)
	draw_line(Vector2(973, 288), Vector2(1175, 288), Color(INK, 0.22), 1.0)


func _draw_scifi_ambient() -> void:
	# Low-contrast circuitry stays in the dead margins. It should suggest a
	# machine-readable route sheet without competing with playable nodes.
	var cool := Color("b7d8d2", 0.11)
	var cool_soft := Color("b7d8d2", 0.055)
	var page_ink := Color(accent, 0.16)
	# Left sleeve: a partial navigation dial and two quiet signal traces.
	draw_arc(Vector2(126, 352), 76.0, -1.18, 1.18, 38, cool, 1.2, true)
	draw_arc(Vector2(126, 352), 54.0, -0.94, 0.94, 30, cool_soft, 1.0, true)
	for index in 5:
		var angle := -0.82 + float(index) * 0.41
		var inner := Vector2(126, 352) + Vector2(cos(angle), sin(angle)) * 61.0
		var outer := Vector2(126, 352) + Vector2(cos(angle), sin(angle)) * 70.0
		draw_line(inner, outer, cool, 1.0, true)
	var left_trace := PackedVector2Array([
		Vector2(38, 522), Vector2(96, 522), Vector2(112, 506),
		Vector2(168, 506), Vector2(184, 490), Vector2(224, 490)
	])
	draw_polyline(left_trace, cool, 1.0, true)
	for point in [left_trace[0], left_trace[3], left_trace[5]]:
		draw_circle(point, 2.5, cool, false, 1.0, true)
	# Right sleeve: sparse terminal brackets and a subdued data ladder.
	var right_trace := PackedVector2Array([
		Vector2(970, 126), Vector2(1010, 126), Vector2(1026, 142),
		Vector2(1104, 142), Vector2(1120, 126), Vector2(1182, 126)
	])
	draw_polyline(right_trace, cool, 1.0, true)
	for index in 8:
		var y := 358.0 + float(index) * 24.0
		var width := 54.0 + float((index * 17) % 46)
		draw_line(Vector2(1018, y), Vector2(1018 + width, y), cool_soft, 1.0)
		draw_rect(Rect2(1006, y - 2, 4, 4), cool, false, 1.0)
	# Paper corners receive only short circuit fragments, kept away from routes.
	var top_fragment := PackedVector2Array([
		Vector2(318, 136), Vector2(352, 136), Vector2(364, 148),
		Vector2(398, 148), Vector2(410, 136), Vector2(438, 136)
	])
	draw_polyline(top_fragment, page_ink, 1.0, true)
	draw_circle(top_fragment[3], 2.0, page_ink, false, 1.0, true)
	for index in 6:
		var x := 774.0 + float(index) * 16.0
		draw_line(Vector2(x, 620), Vector2(x + 7, 620), Color(accent, 0.11), 1.0)
		draw_line(Vector2(x + 7, 620), Vector2(x + 7, 614 - float(index % 2) * 5.0), Color(accent, 0.08), 1.0)


func _draw_trace(origin: Vector2, mirrored: bool) -> void:
	var direction := -1.0 if mirrored else 1.0
	var points := PackedVector2Array([
		origin, origin + Vector2(26 * direction, 0),
		origin + Vector2(38 * direction, -12), origin + Vector2(59 * direction, -12)
	])
	draw_polyline(points, Color(accent, 0.35), 1.0, true)
	draw_circle(points[points.size() - 1], 2.5, Color(accent, 0.50), false, 1.0, true)


func _draw_stage_marks() -> void:
	var color := Color(accent, 0.35)
	var at := Vector2(321, 592)
	match life_stage:
		"student":
			# A timetable corner and one folded sticky note.
			for index in 4:
				draw_line(at + Vector2(index * 12, 0), at + Vector2(index * 12, 36), color, 1.0)
				draw_line(at + Vector2(0, index * 12), at + Vector2(36, index * 12), color, 1.0)
			draw_polyline(PackedVector2Array([at + Vector2(63, 9), at + Vector2(85, 9), at + Vector2(85, 27), at + Vector2(78, 34), at + Vector2(63, 34), at + Vector2(63, 9)]), color, 1.0, true)
		"graduate":
			for index in 3:
				var y := float(index * 12)
				draw_line(at + Vector2(0, y), at + Vector2(36 - index * 6, y), color, 1.0)
			draw_polyline(PackedVector2Array([at + Vector2(44, 0), at + Vector2(50, 0), at + Vector2(50, 30), at + Vector2(44, 30)]), color, 1.0)
		"employee":
			for index in 3:
				var y := float(index * 13)
				draw_rect(Rect2(at + Vector2(0, y), Vector2(5, 5)), color, false, 1.0)
				draw_line(at + Vector2(12, y + 3), at + Vector2(42, y + 3), color, 1.0)
		"researcher":
			# Measurement axes and an unembellished observation trace.
			draw_polyline(PackedVector2Array([at + Vector2(0, -4), at + Vector2(0, 32), at + Vector2(57, 32)]), color, 1.0)
			draw_polyline(PackedVector2Array([at + Vector2(4, 26), at + Vector2(14, 18), at + Vector2(25, 23), at + Vector2(37, 7), at + Vector2(49, 13)]), color, 1.0, true)
			for index in 4:
				draw_line(at + Vector2(index * 14, 32), at + Vector2(index * 14, 36), color, 1.0)
		"expert":
			# A reviewed brief with a margin note, echoing accumulated judgement.
			draw_polyline(PackedVector2Array([at + Vector2(0, 33), at + Vector2(0, 0), at + Vector2(45, 0), at + Vector2(45, 33)]), color, 1.0)
			for index in 3:
				draw_line(at + Vector2(8, 11 + index * 9), at + Vector2(45 - index * 7, 11 + index * 9), color, 1.0)
			draw_polyline(PackedVector2Array([at + Vector2(54, 8), at + Vector2(61, 8), at + Vector2(61, 23), at + Vector2(54, 23)]), color, 1.0)
			draw_line(at + Vector2(62, 15), at + Vector2(79, 15), color, 1.0)
		"wealthy":
			# An embossed invitation and a reserved seat tie this life to being present.
			draw_rect(Rect2(at, Vector2(53, 33)), color, false, 1.0)
			draw_rect(Rect2(at + Vector2(3, 3), Vector2(47, 27)), Color(accent, 0.20), false, 1.0)
			draw_line(at + Vector2(11, 12), at + Vector2(42, 12), color, 1.0)
			draw_line(at + Vector2(17, 21), at + Vector2(36, 21), color, 1.0)
			draw_polyline(PackedVector2Array([at + Vector2(65, 20), at + Vector2(65, 5), at + Vector2(79, 5), at + Vector2(79, 20)]), color, 1.0)
			draw_line(at + Vector2(62, 23), at + Vector2(82, 23), color, 1.0)
			draw_line(at + Vector2(65, 23), at + Vector2(65, 32), color, 1.0)
			draw_line(at + Vector2(79, 23), at + Vector2(79, 32), color, 1.0)


func _draw_stage_margin() -> void:
	# These are unconnected page annotations, away from the playable route.
	var at := Vector2(798, 170)
	var color := Color(accent, 0.27)
	match life_stage:
		"expert":
			# Tiny review options stay in the margin; square ends separate them from routes.
			draw_rect(Rect2(at, Vector2(16, 8)), color, false, 1.0)
			draw_line(at + Vector2(8, 8), at + Vector2(8, 20), color, 1.0)
			draw_line(at + Vector2(-10, 20), at + Vector2(26, 20), color, 1.0)
			for x in [-10.0, 26.0]:
				draw_line(at + Vector2(x, 20), at + Vector2(x, 28), color, 1.0)
				draw_rect(Rect2(at + Vector2(x - 6, 28), Vector2(12, 7)), color, false, 1.0)
		"wealthy":
			draw_arc(at + Vector2(8, 12), 13.0, 0, TAU, 40, color, 1.0, true)
			draw_arc(at + Vector2(8, 12), 10.0, 0, TAU, 36, Color(accent, 0.16), 1.0, true)
			draw_line(at + Vector2(1, 12), at + Vector2(15, 12), color, 1.0)
			draw_line(at + Vector2(8, 5), at + Vector2(8, 19), color, 1.0)


func _draw_route(from: Vector2, control: Vector2, to: Vector2, available: bool, visited: bool, start_clear: float = 35.0, end_clear: float = 40.0) -> void:
	var color := Color(INK, 0.62 if available else 0.26)
	if visited:
		color = Color(INK, 0.90)
	var last := from
	var travelled := 0.0
	var samples := PackedVector2Array()
	for step in 101:
		var t := float(step) / 100.0
		samples.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	var total := 0.0
	for index in samples.size() - 1:
		total += samples[index].distance_to(samples[index + 1])
	for index in range(1, samples.size()):
		var point: Vector2 = samples[index]
		var length := last.distance_to(point)
		# Subdivide so dash rhythm follows the curve rather than restarting per segment.
		var pieces := maxi(1, ceili(length))
		for piece in pieces:
			var along := travelled + length * float(piece) / float(pieces)
			if along > start_clear and along < total - end_clear and fmod(along, 9.0) < 3.5:
				var a := last.lerp(point, float(piece) / float(pieces))
				var b := last.lerp(point, float(piece + 1) / float(pieces))
				draw_line(a, b, color, 2.0 if visited else 1.5, true)
		travelled += length
		last = point


func _draw_state(center: Vector2, available: bool, completed: bool, radius: float) -> void:
	if available:
		draw_arc(center, radius + 3, -0.25, 5.55, 64, Color(INK, 0.75), 1.8, true)
		draw_arc(center + Vector2(1.2, -0.7), radius + 6, 0.25, 4.5, 54, Color(accent, 0.72), 1.5, true)
	elif completed:
		draw_arc(center, radius, 0.25, 5.9, 64, Color(INK, 0.42), 1.2, true)
		var check_at := center + Vector2(22, 22)
		draw_polyline(PackedVector2Array([check_at + Vector2(-5, 0), check_at + Vector2(-1, 4), check_at + Vector2(7, -6)]), INK, 2.0, true)
