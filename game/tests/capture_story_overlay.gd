extends SceneTree

const SaveManagerScript = preload("res://scripts/save_manager.gd")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_manager = SaveManagerScript.new(ProjectSettings.globalize_path("res://../_build/test_saves/story_capture.json"), str(game.content["version"]))
	game.selected_stage = "student"
	game.call("_begin_run_with_lineup", ["GPT", "Claude"], "standard")
	await process_frame
	await process_frame
	game.call("_skip_story_sequence")
	game.call("_show_story_event", "ch1.report.student.open", false)
	for index in game.story_pages.size():
		if str(game.story_pages[index].get("speaker", "")) in ["GPT", "Claude"]:
			game.story_page_index = index
			game.call("_render_story_page")
			break
	for unused in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../_build/evidence/story_opening_overlay.png")
	var image := root.get_texture().get_image()
	var error := image.save_png(output)
	if error != OK:
		push_error("Story screenshot failed: %s" % error_string(error))
		quit(1)
		return
	print("[STORY SCREENSHOT] %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	quit(0)
