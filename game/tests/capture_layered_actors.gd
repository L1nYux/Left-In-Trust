extends SceneTree

const SaveManagerScript = preload("res://scripts/save_manager.gd")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var save_path := ProjectSettings.globalize_path("res://../_build/test_saves/layered_capture.json")
	game.save_manager = SaveManagerScript.new(save_path, "0.5")
	game.call("_begin_run_with_lineup", ["GPT", "Claude", "DeepSeek"], "test_arena")
	for _frame in 4:
		await process_frame
	var idle_output := ProjectSettings.globalize_path("res://../_build/evidence/layered_actors_trio.png")
	var error := root.get_texture().get_image().save_png(idle_output)
	if error != OK:
		push_error("Layered actor idle screenshot failed: %s" % error_string(error))
		quit(1)
		return
	game.actor_visuals["GPT"].play_motion("light_attack")
	game.actor_visuals["Claude"].play_motion("guard")
	game.actor_visuals["DeepSeek"].play_motion("support")
	if is_instance_valid(game.enemy_visual):
		game.enemy_visual.play_motion("attack")
	await create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	var motion_output := ProjectSettings.globalize_path("res://../_build/evidence/layered_actors_motion_sample.png")
	error = root.get_texture().get_image().save_png(motion_output)
	if error != OK:
		push_error("Layered actor motion screenshot failed: %s" % error_string(error))
		quit(1)
		return
	print("[LAYERED ACTOR SCREENSHOT] idle=%s motion=%s" % [idle_output, motion_output])
	quit(0)
