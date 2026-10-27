extends SceneTree

const MapCanvasScript = preload("res://scripts/map_route_canvas.gd")
const LifeStagesScript = preload("res://scripts/life_stages.gd")
const MainScript = preload("res://scripts/main_stage2.gd")
const NOTES := {
	"student": "课表 · 折角便签", "graduate": "文献摘录 · 引注",
	"employee": "办公清单 · 复选格", "researcher": "测量坐标 · 观察记录",
	"expert": "审阅批注 · 决策分支", "wealthy": "压印邀请函 · 预约座位"
}

class DetailPreview extends MapCanvasScript:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), paper)
		draw_set_transform(Vector2(12, 12) - Vector2(321, 592) * 1.35, 0, Vector2(1.35, 1.35))
		_draw_stage_marks()


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var gallery := Control.new()
	root.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("e1e0d6")
	background.size = Vector2(1280, 720)
	gallery.add_child(background)
	_caption(gallery, "未尽之托 · 六种人生身份的地图差分", Vector2(32, 22), 26)
	_caption(gallery, "统一路线与事件符号；仅纸色、页边纹样与弱强调线变化", Vector2(34, 67), 15)
	for index in LifeStagesScript.IDS.size():
		var stage_id: String = LifeStagesScript.IDS[index]
		var at := Vector2(32 + (index % 3) * 416, 112 + (index / 3) * 296)
		_caption(gallery, LifeStagesScript.display_name(stage_id), at, 20)
		_caption(gallery, NOTES[stage_id], at + Vector2(0, 32), 14)
		var clip := Control.new()
		clip.position = at + Vector2(0, 62)
		clip.size = Vector2(228, 200)
		clip.clip_contents = true
		gallery.add_child(clip)
		var canvas := MapCanvasScript.new()
		canvas.configure(stage_id)
		canvas.position = Vector2(-254, -88) * 0.35
		canvas.scale = Vector2(0.35, 0.35)
		canvas.size = Vector2(1280, 720)
		clip.add_child(canvas)
		for entry in [[MapCanvasScript.ORDINARY, "battle_ordinary"], [MapCanvasScript.REST, "rest"], [MapCanvasScript.BOSS, "boss_acceptance"]]:
			var icon := TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.texture = MainScript.MAP_ICONS[entry[1]]
			canvas.add_child(icon)
			icon.size = Vector2(50, 50)
			icon.position = entry[0] - Vector2(25, 25)
		_caption(gallery, "页脚细节", at + Vector2(244, 83), 13)
		var detail := DetailPreview.new()
		detail.configure(stage_id)
		detail.position = at + Vector2(240, 114)
		detail.size = Vector2(142, 80)
		gallery.add_child(detail)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../_build/evidence/map_identity_v2_all_comparison.png")
	var error := root.get_texture().get_image().save_png(path)
	print("[LIFE STAGE COMPARISON] %s error=%d" % [path, error])
	quit(0 if error == OK else 1)


func _caption(parent: Node, text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MapCanvasScript.INK)
	parent.add_child(label)
