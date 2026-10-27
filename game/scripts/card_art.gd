extends Control

var card_id := ""
var card_kind := "attack"
var owner_id := ""
var accent := Color("69d7e7")
var illustration_texture: Texture2D = null

const CARD_TEXTURE_PATHS := {
	"A": "res://assets/cards/illustrations/A_standard_directive_v3.png",
	"D": "res://assets/cards/illustrations/D_guarding_directive_v3.png",
	"H": "res://assets/cards/illustrations/H_heavy_directive_v3.png",
	"R": "res://assets/cards/illustrations/R_emergency_supply_v3.png",
	"T": "res://assets/cards/illustrations/T_quota_transfer_v3.png",
	"V": "res://assets/cards/illustrations/V_check_strike_v3.png",
	"G1": "res://assets/cards/illustrations/G1_step_advance_v4.png",
	"G2": "res://assets/cards/illustrations/G2_all_in_push_v4.png",
	"C1": "res://assets/cards/illustrations/C1_minimal_edit_v2.png",
	"C2": "res://assets/cards/illustrations/C2_item_reply_v2.png",
	"S1": "res://assets/cards/illustrations/S1_hold_flame_v4.png",
	"S2": "res://assets/cards/illustrations/S2_early_feast_v4.png",
	"basic_attack": "res://assets/cards/illustrations/basic_strike_v3.png",
	"basic_guard": "res://assets/cards/illustrations/basic_defend_v3.png"
}

func configure(kind: String, owner: String, color: Color, p_card_id: String = "") -> void:
	card_kind = kind
	owner_id = owner
	accent = color
	card_id = p_card_id
	_load_texture()
	queue_redraw()

func _load_texture() -> void:
	illustration_texture = null
	if card_id.is_empty():
		return
	if CARD_TEXTURE_PATHS.has(card_id):
		var path: String = CARD_TEXTURE_PATHS[card_id]
		if ResourceLoader.exists(path):
			illustration_texture = load(path)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("10182a"), true)
	draw_rect(Rect2(2, 2, maxf(0.0, size.x - 4), maxf(0.0, size.y - 4)), Color(accent, 0.22), true)

	if illustration_texture != null:
		var inner_rect := Rect2(2, 2, maxf(0.0, size.x - 4), maxf(0.0, size.y - 4))
		var tex_size := illustration_texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var aspect_w := inner_rect.size.x
			var aspect_h := inner_rect.size.y
			var src_w: float = tex_size.x
			var src_h: float = tex_size.y
			if (src_w / src_h) > (aspect_w / aspect_h):
				var target_src_w: float = src_h * (aspect_w / aspect_h)
				var src_x: float = (src_w - target_src_w) * 0.5
				draw_texture_rect_region(illustration_texture, inner_rect, Rect2(src_x, 0, target_src_w, src_h))
			else:
				var target_src_h: float = src_w * (aspect_h / aspect_w)
				var src_y: float = (src_h - target_src_h) * 0.5
				draw_texture_rect_region(illustration_texture, inner_rect, Rect2(0, src_y, src_w, target_src_h))
		draw_rect(inner_rect, Color(accent, 0.35), false, 1.0)
	else:
		# High-density technical graph paper grid filling the background
		var step := 10.0
		var x_lines := int(size.x / step)
		for ix in range(1, x_lines):
			var gx := float(ix) * step
			draw_line(Vector2(gx, 4), Vector2(gx, size.y - 4), Color("f2efe7", 0.05), 1.0)
		var y_lines := int(size.y / step)
		for iy in range(1, y_lines):
			var gy := float(iy) * step
			draw_line(Vector2(4, gy), Vector2(size.x - 4, gy), Color("f2efe7", 0.05), 1.0)

		# Role-specific high-density fallback or kind fallback
		if card_id == "S1" or card_id == "S2":
			_draw_deepseek_fallback()
		elif card_id == "G1" or card_id == "G2":
			_draw_gpt_fallback()
		elif card_id == "C1" or card_id == "C2":
			_draw_claude_fallback()
		else:
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
	var start := Vector2(size.x * 0.12, size.y * 0.86)
	var finish := Vector2(size.x * 0.86, size.y * 0.14)
	# Thick energy beam with multiple layers
	draw_line(start, finish, Color("f2efe7", 0.22), 16.0, true)
	draw_line(start, finish, Color(accent, 0.4), 10.0, true)
	draw_line(start, finish, accent, 4.0, true)
	draw_line(start, finish, Color("ffffff"), 1.5, true)
	# Arrow head
	var arrow := PackedVector2Array([
		finish + Vector2(-22, 4),
		finish + Vector2(10, -10),
		finish + Vector2(-4, 22)
	])
	draw_colored_polygon(arrow, accent)
	# Checkpoint prisms along the line
	for index in 3:
		var point := start.lerp(finish, 0.22 + float(index) * 0.24)
		draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), Color("0a101b"), true)
		draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), accent, false, 1.5)
		draw_circle(point, 2.5, Color("ffffff"))
	# Target impact box in upper right
	var target_box := Rect2(finish - Vector2(16, 16), Vector2(28, 28))
	draw_rect(target_box, Color("ef6a62", 0.35), false, 2.0)
	draw_line(target_box.position, target_box.position + target_box.size, Color("ef6a62", 0.6), 1.5)

func _draw_guard() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	var w := size.x * 0.38
	var h := size.y * 0.42
	# Outer shield
	var outer_shield := PackedVector2Array([
		center + Vector2(-w, -h * 0.7),
		center + Vector2(w, -h * 0.7),
		center + Vector2(w * 0.85, h * 0.35),
		center + Vector2(0, h),
		center + Vector2(-w * 0.85, h * 0.35)
	])
	draw_colored_polygon(outer_shield, Color(accent, 0.28))
	draw_polyline(outer_shield, accent, 4.0, true)
	# Inner reinforced plate
	var inner_shield := PackedVector2Array([
		center + Vector2(-w * 0.65, -h * 0.5),
		center + Vector2(w * 0.65, -h * 0.5),
		center + Vector2(w * 0.55, h * 0.25),
		center + Vector2(0, h * 0.75),
		center + Vector2(-w * 0.55, h * 0.25)
	])
	draw_polyline(inner_shield, Color("f2efe7", 0.7), 2.0, true)
	# Central rib & deflection sparks
	draw_line(center + Vector2(0, -h * 0.6), center + Vector2(0, h * 0.65), Color("ffffff", 0.9), 2.5)
	for angle in [-0.6, 0.0, 0.6]:
		var spark_dir := Vector2(sin(angle), -cos(angle)) * 18.0
		draw_line(center + Vector2(0, -h * 0.7), center + Vector2(0, -h * 0.7) + spark_dir, Color("ef6a62", 0.7), 2.0)

func _draw_heal() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	# High-density concentric pulse rings
	for radius in [46.0, 36.0, 26.0, 16.0]:
		draw_arc(center, radius, 0.1, TAU - 0.2, 32, Color(accent, 0.25 + (46.0 - radius) / 70.0), 2.5, true)
	# Glowing medical cross
	var arm_w := 14.0
	var arm_l := 48.0
	draw_rect(Rect2(center - Vector2(arm_w * 0.5, arm_l * 0.5), Vector2(arm_w, arm_l)), Color("f2efe7", 0.9), true)
	draw_rect(Rect2(center - Vector2(arm_l * 0.5, arm_w * 0.5), Vector2(arm_l, arm_w)), Color("f2efe7", 0.9), true)
	draw_circle(center, 5.0, Color("f2b85b"))

func _draw_transfer() -> void:
	var left := Vector2(size.x * 0.22, size.y * 0.5)
	var right := Vector2(size.x * 0.78, size.y * 0.5)
	var center := (left + right) * 0.5
	# Hands/brackets
	draw_arc(left, 18.0, -PI * 0.4, PI * 0.4, 16, accent, 4.0)
	draw_arc(right, 18.0, PI * 0.6, PI * 1.4, 16, Color("f2b85b"), 4.0)
	# Dense dual energy stream
	draw_line(left + Vector2(8, -6), right - Vector2(8, -6), Color(accent, 0.7), 3.0, true)
	draw_line(left + Vector2(8, 6), right - Vector2(8, 6), Color("f2b85b", 0.7), 3.0, true)
	# Center large glowing Token coin
	draw_circle(center, 18.0, Color("0a101b"))
	draw_circle(center, 16.0, Color("f2b85b", 0.85))
	draw_arc(center, 16.0, 0.0, TAU, 24, Color("ffffff"), 2.0)
	draw_circle(center, 7.0, Color("ffffff", 0.9))

func _draw_deepseek_fallback() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	# Deep-sea concentric water waves filling bottom
	for r in [52.0, 40.0, 28.0]:
		draw_arc(center + Vector2(0, 12), r, PI * 0.8, PI * 2.2, 32, Color("52d6c9", 0.35 + (52.0 - r) / 80.0), 2.5)
	# Simmer flame
	var flame := PackedVector2Array([
		center + Vector2(-12, 28),
		center + Vector2(0, 14),
		center + Vector2(12, 28),
		center + Vector2(0, 32)
	])
	draw_colored_polygon(flame, Color("52d6c9", 0.8))
	draw_circle(center + Vector2(0, 24), 4.0, Color("f2b85b"))
	# White porcelain bowl
	var bowl := PackedVector2Array([
		center + Vector2(-34, -4),
		center + Vector2(34, -4),
		center + Vector2(26, 22),
		center + Vector2(-26, 22)
	])
	draw_colored_polygon(bowl, Color("f2efe7", 0.95))
	draw_polyline(bowl, Color("52d6c9"), 2.5, true)
	# Glowing rice grain/dewdrop of light
	var grain_pos := center + Vector2(0, -20)
	draw_circle(grain_pos, 7.0, Color("ffffff"))
	draw_circle(grain_pos, 11.0, Color("52d6c9", 0.45))

func _draw_gpt_fallback() -> void:
	var start := Vector2(size.x * 0.15, size.y * 0.78)
	# Cloudlet in lower left
	draw_circle(start, 12.0, Color("6ea8fe", 0.85))
	draw_circle(start + Vector2(8, -6), 10.0, Color("c8d7ff", 0.85))
	draw_circle(start + Vector2(-8, -4), 9.0, Color("6ea8fe", 0.75))
	# Three large ascending stepping crystal pads
	for idx in 3:
		var pad_pos := start + Vector2(24.0 + float(idx) * 28.0, -16.0 - float(idx) * 24.0)
		var pad := PackedVector2Array([
			pad_pos + Vector2(-16, 0),
			pad_pos + Vector2(0, -10),
			pad_pos + Vector2(16, 0),
			pad_pos + Vector2(0, 10)
		])
		draw_colored_polygon(pad, Color("c8d7ff", 0.45))
		draw_polyline(pad, Color("6ea8fe"), 2.5, true)
		draw_circle(pad_pos, 3.0, Color("ffffff"))
	# Target checkbox
	var target_pt := start + Vector2(108.0, -88.0)
	draw_rect(Rect2(target_pt - Vector2(10, 10), Vector2(20, 20)), Color("6ea8fe"), false, 2.0)
	draw_line(target_pt + Vector2(-5, 0), target_pt + Vector2(-1, 5), Color("ffffff"), 2.0)
	draw_line(target_pt + Vector2(-1, 5), target_pt + Vector2(6, -5), Color("ffffff"), 2.0)

func _draw_claude_fallback() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	# Leather tome background
	draw_rect(Rect2(Vector2(size.x * 0.12, size.y * 0.15), Vector2(size.x * 0.76, size.y * 0.7)), Color("16151d", 0.7), true)
	draw_rect(Rect2(Vector2(size.x * 0.12, size.y * 0.15), Vector2(size.x * 0.76, size.y * 0.7)), Color("f2b85b", 0.5), false, 1.5)
	# Dual orange bracket blades [ ]
	var left_b := center + Vector2(-22, 0)
	draw_line(left_b + Vector2(8, -26), left_b + Vector2(-8, -26), Color("fd9a5f"), 3.5)
	draw_line(left_b + Vector2(-8, -26), left_b + Vector2(-8, 26), Color("fd9a5f"), 3.5)
	draw_line(left_b + Vector2(-8, 26), left_b + Vector2(8, 26), Color("fd9a5f"), 3.5)
	var right_b := center + Vector2(22, 0)
	draw_line(right_b + Vector2(-8, -26), right_b + Vector2(8, -26), Color("fd9a5f"), 3.5)
	draw_line(right_b + Vector2(8, -26), right_b + Vector2(8, 26), Color("fd9a5f"), 3.5)
	draw_line(right_b + Vector2(8, 26), right_b + Vector2(-8, 26), Color("fd9a5f"), 3.5)
	# Center glowing needle & stitch line
	draw_line(center + Vector2(0, -32), center + Vector2(0, 32), Color("f2b85b", 0.8), 2.5)
	draw_circle(center, 4.0, Color("ffffff"))

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
