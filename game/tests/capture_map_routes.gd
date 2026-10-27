extends SceneTree

const SaveManagerScript = preload("res://scripts/save_manager.gd")
const MainScript = preload("res://scripts/main_stage2.gd")
const LifeStagesScript = preload("res://scripts/life_stages.gd")
var failed := false


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for stage_id in LifeStagesScript.IDS:
		var save_path := ProjectSettings.globalize_path("res://../_build/test_saves/map_identity_capture_%s.json" % stage_id)
		game.save_manager = SaveManagerScript.new(save_path, str(game.content["version"]))
		game.selected_stage = stage_id
		game.call("_begin_run", "GPT")
		await _save_shot("map_identity_v2_%s" % stage_id)
	for role_id in ["GPT", "Claude", "DeepSeek"]:
		game.selected_stage = "researcher"
		game.call("_begin_run", role_id)
		await _save_shot("map_identity_v2_researcher_%s" % str(role_id).to_lower())
	game.call("_show_role_select")
	game.call("_select_life_stage", "researcher")
	await _save_shot("map_identity_v2_selection")
	game.selected_stage = "student"
	game.call("_begin_run_with_lineup", ["GPT", "Claude"], "standard")
	await _save_shot("map_identity_v2_pair")
	game.call("_start_ordinary")
	var battle: Dictionary = game.call("_auto_play_current_battle")
	if battle.get("result") != "win":
		push_error("ordinary battle failed during map capture")
		quit(1)
		return
	game.call("_complete_battle")
	await _save_shot("map_identity_v2_progress")
	game.call("_open_settings")
	await _save_shot("map_identity_v2_settings")
	game.call("_close_settings")
	game.run_state["accounts"]["GPT"]["token"] = 5
	game.call("_enter_rest")
	game.call("_take_rest", "GPT")
	await _save_shot("map_identity_v2_rest_done")
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await _capture_symbol_sheet()
	quit(1 if failed else 0)


func _save_shot(stem: String) -> void:
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../_build/evidence/%s.png" % stem)
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		failed = true
		push_error("map screenshot failed: %s" % path)
	else:
		print("[MAP SCREENSHOT] %s" % path)


func _capture_symbol_sheet() -> void:
	var gallery := Control.new()
	root.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("c9cabe")
	background.size = Vector2(1280, 720)
	gallery.add_child(background)
	_add_caption(gallery, "未尽之托 · 地图事件符号", Vector2(68, 45), 28)
	_add_caption(gallery, "64 px / 32 px · 单色轮廓", Vector2(70, 92), 16)
	var names := ["普通战斗", "精英战斗", "事件", "休息", "商店", "同行招募", "记忆线索", "终点验收"]
	var keys := ["battle_ordinary", "battle_elite", "event_clue", "rest", "shop_supply", "recruit", "memory_clue", "boss_acceptance"]
	for index in keys.size():
		var at := Vector2(84 + (index % 4) * 300, 210 + (index / 4) * 238)
		for icon_size in [64, 32]:
			var symbol := TextureRect.new()
			symbol.texture = MainScript.MAP_ICONS[keys[index]]
			symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			symbol.size = Vector2(icon_size, icon_size)
			symbol.position = at + (Vector2(101, 16) if icon_size == 32 else Vector2.ZERO)
			gallery.add_child(symbol)
		_add_caption(gallery, names[index], at + Vector2(0, 89), 18)
	await _save_shot("map_route_v2_symbols")
	root.remove_child(gallery)
	gallery.queue_free()


func _add_caption(parent: Node, text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("303b38"))
	parent.add_child(label)
