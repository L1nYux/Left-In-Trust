extends SceneTree

const SaveManagerScript = preload("res://scripts/save_manager.gd")
const LifeStagesScript = preload("res://scripts/life_stages.gd")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for stage_id in LifeStagesScript.IDS:
		for via_rest in [false, true]:
			var role_id := "GPT"
			var game = load("res://scenes/Main.tscn").instantiate()
			root.add_child(game)
			await process_frame
			var save_path := ProjectSettings.globalize_path("res://../_build/test_saves/map_identity_%s_%s.json" % [stage_id, via_rest])
			game.save_manager = SaveManagerScript.new(save_path, str(game.content["version"]))
			# Exercise the real identity selector, independently of AI team selection.
			game.call("_show_role_select")
			var selector := game.find_child("LifeStageSelector", true, false) as OptionButton
			selector.select(LifeStagesScript.IDS.find(stage_id))
			selector.item_selected.emit(LifeStagesScript.IDS.find(stage_id))
			await process_frame
			game.call("_toggle_role", "Claude")
			if game.selected_stage != stage_id:
				_fail("changing AI selection reset the player identity")
				return
			game.call("_begin_run", role_id)
			if not _expect_map(game, false, false):
				return
			var before := JSON.stringify([game.run_state, game.battle_state])
			var paper: Color = game.map_path_layer.paper
			if game.map_path_layer.life_stage != stage_id:
				_fail("map did not use the selected player identity")
				return
			game.call("_show_map")
			if JSON.stringify([game.run_state, game.battle_state]) != before:
				_fail("drawing the map changed gameplay state")
				return
			await _press_node(game, "MapRoot/MapOrdinary")
			if failed:
				return
			var ordinary: Dictionary = game.call("_auto_play_current_battle")
			if ordinary.get("result") != "win":
				_fail("ordinary battle did not complete")
				return
			game.call("_complete_battle")
			if not _expect_map(game, true, false):
				return
			# Return through the real settings signal and reload the saved map.
			await _press_node(game, "MapRoot/SettingsButton")
			await _press_text(game, "返回标题界面")
			if failed:
				return
			game.call("_continue_saved_run")
			if not _expect_map(game, true, false) or game.map_path_layer.paper != paper or game.selected_stage != stage_id:
				_fail("map progress or player identity was lost after reload")
				return
			if via_rest:
				# A recoverable account fixture exercises the actual recovery button.
				game.run_state["accounts"][role_id]["token"] = 5
				await _press_node(game, "MapRoot/MapRest")
				await _press_text(game, "选择此人恢复")
				if failed or not _expect_map(game, true, true):
					return
				if int(game.run_state["accounts"][role_id]["token"]) != 11:
					_fail("rest branch did not apply the existing +6 recovery once")
					return
			await _press_node(game, "MapRoot/MapBoss")
			if failed or game.flow != "battle" or game.current_battle_kind != "boss":
				_fail("the direct or rest branch did not enter the boss battle")
				return
			var boss: Dictionary = game.call("_auto_play_current_battle")
			if boss.get("result") != "win":
				_fail("boss battle did not complete")
				return
			game.call("_complete_battle")
			if game.flow != "result" or game.run_state.get("services", {}).has("rest") != via_rest:
				_fail("branch choice changed on completion")
				return
			root.remove_child(game)
			game.queue_free()
			await process_frame
	# Changing companions must not recolor a given player's map.
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_manager = SaveManagerScript.new(ProjectSettings.globalize_path("res://../_build/test_saves/map_identity_invariance.json"), str(game.content["version"]))
	for stage_id in LifeStagesScript.IDS:
		for team in [["GPT"], ["Claude"], ["DeepSeek"], ["GPT", "Claude"]]:
			game.selected_stage = stage_id
			game.call("_begin_run_with_lineup", team, "standard")
			if game.map_path_layer.paper != LifeStagesScript.THEMES[stage_id]["paper"] or game.map_path_layer.life_stage != stage_id:
				_fail("AI lineup affected map appearance")
				return
	# Missing stage in a legacy save defaults to student, regardless of UI selection.
	game.run_state.erase("stage")
	game.call("_save_progress", "map")
	game.selected_stage = "researcher"
	game.call("_continue_saved_run")
	if game.selected_stage != "student" or game.map_path_layer.life_stage != "student":
		_fail("legacy saves did not use the independent student default")
		return
	root.remove_child(game)
	game.queue_free()
	await process_frame
	print("[MAP ROUTES] PASS 12 identity/branch flows, 24 AI-invariance checks, identity save reload and legacy fallback")
	quit(0)


func _expect_map(game: Node, ordinary_done: bool, rest_done: bool) -> bool:
	if game.flow != "map":
		_fail("expected map, got %s" % game.flow)
		return false
	var battle := game.get_node("MapRoot/MapOrdinary") as Button
	var rest := game.get_node("MapRoot/MapRest") as Button
	var boss := game.get_node("MapRoot/MapBoss") as Button
	if battle.disabled != ordinary_done or rest.disabled != (not ordinary_done or rest_done) or boss.disabled != (not ordinary_done):
		_fail("route availability does not match completed nodes")
		return false
	if game.map_path_layer.ordinary_done != ordinary_done or game.map_path_layer.rest_done != rest_done:
		_fail("drawn route progress disagrees with actual buttons")
		return false
	if rest.get_meta("completed") != rest_done:
		_fail("rest completion indicator disagrees with actual recovery")
		return false
	return true


func _press_node(game: Node, path: String) -> void:
	var button := game.get_node_or_null(path) as Button
	if button == null or button.disabled:
		_fail("missing or disabled button: %s" % path)
		return
	button.pressed.emit()
	await process_frame
	await process_frame


func _press_text(game: Node, prefix: String) -> void:
	var button := _find_button(game, prefix)
	if button == null or button.disabled:
		_fail("missing or disabled text button: %s" % prefix)
		return
	button.pressed.emit()
	await process_frame
	await process_frame


func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for child in node.get_children():
		var button := _find_button(child, prefix)
		if button != null:
			return button
	return null


func _fail(message: String) -> void:
	failed = true
	push_error("[MAP ROUTES FAIL] %s" % message)
	quit(1)
