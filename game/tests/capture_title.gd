extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://../_build/evidence/title.png")
	var error := image.save_png(output)
	if error != OK:
		push_error("Screenshot failed: %s" % error_string(error))
		quit(1)
		return
	print("[SCREENSHOT] %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	instance.call("_begin_run", "GPT")
	await process_frame
	await process_frame
	image = root.get_texture().get_image()
	output = ProjectSettings.globalize_path("res://../_build/evidence/battle_gpt.png")
	error = image.save_png(output)
	if error != OK:
		push_error("Battle screenshot failed: %s" % error_string(error))
		quit(1)
		return
	print("[SCREENSHOT] %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	quit(0)
