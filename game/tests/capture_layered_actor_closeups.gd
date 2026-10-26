extends SceneTree

const ROLE_SCENES := {
	"GPT": preload("res://scenes/actors/GPTActor.tscn"),
	"Claude": preload("res://scenes/actors/ClaudeActor.tscn"),
	"DeepSeek": preload("res://scenes/actors/DeepSeekActor.tscn")
}


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var canvas := Control.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("172033")
	background.size = canvas.size
	canvas.add_child(background)
	var positions := {"GPT": Vector2(32, 112), "Claude": Vector2(430, 112), "DeepSeek": Vector2(828, 112)}
	for role_id_value in ROLE_SCENES.keys():
		var role_id := str(role_id_value)
		var actor: Control = ROLE_SCENES[role_id].instantiate()
		actor.position = positions[role_id]
		actor.size = Vector2(170, 250)
		actor.scale = Vector2(2, 2)
		canvas.add_child(actor)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../_build/evidence/layered_actor_closeups.png")
	var error := root.get_texture().get_image().save_png(output)
	print("[LAYERED ACTOR CLOSEUPS] %s" % JSON.stringify({"ok": error == OK, "path": output, "error": error}))
	quit(0 if error == OK else 1)
