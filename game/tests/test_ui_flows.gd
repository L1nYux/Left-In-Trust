extends SceneTree

const TestPolicy = preload("res://tests/test_policy.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

func _init() -> void:
	call_deferred("_run_flows")

func _run_flows() -> void:
	var records: Array = []
	for index in 3:
		var role_id: String = ["GPT", "Claude", "DeepSeek"][index]
		var seed := 20261025 + index
		var game = await _new_game("solo_%s" % role_id)
		var upgraded_button_text: String = game.call("_card_button_text", {"uid": "probe-A", "code": "A", "upgraded": true})
		if not upgraded_button_text.contains("伤害8"):
			_fail("upgraded card button did not use resolved values: %s" % upgraded_button_text)
			return
		if game.call("_error_text", "run_ended") != "本次委托已结束":
			_fail("run_ended was not mapped to readable UI text")
			return
		game.run_seed = seed
		game.call("_show_role_select")
		game.call("_begin_run", role_id)
		var ordinary_turns := _finish_visible_battle(game, [role_id])
		if game.run_state["nodes"].get("ordinary") != "win":
			_fail("%s ordinary UI flow failed" % role_id)
			return
		var before_rest: int = game.run_state["accounts"][role_id]["token"]
		if before_rest < int(game.run_state["accounts"][role_id]["max"]):
			game.call("_take_rest")
			var after_first_rest := JSON.stringify([game.run_state, game.battle_state])
			game.call("_take_rest")
			if JSON.stringify([game.run_state, game.battle_state]) != after_first_rest:
				_fail("double rest mutated state for %s" % role_id)
				return
		else:
			game.call("_start_boss")
		var after_rest: int = game.run_state["accounts"][role_id]["token"]
		var boss_turns := _finish_visible_battle(game, [role_id])
		if game.run_state["nodes"].get("boss") != "win":
			_fail("%s boss UI flow failed" % role_id)
			return
		var after_boss := JSON.stringify([game.run_state, game.battle_state])
		game.call("_finish_turn")
		if JSON.stringify([game.run_state, game.battle_state]) != after_boss:
			_fail("finish_turn advanced a completed battle for %s" % role_id)
			return
		records.append({
			"role": role_id, "seed": seed, "ordinary_turns": ordinary_turns,
			"rest": [before_rest, after_rest], "boss_turns": boss_turns,
			"final_token": game.run_state["accounts"][role_id]["token"],
			"wallet": game.run_state["wallet"], "completed": true
		})
		root.remove_child(game)
		game.free()
	for index in 3:
		var pair: Array = [["GPT", "Claude"], ["GPT", "DeepSeek"], ["Claude", "DeepSeek"]][index]
		var game = await _new_game("pair_%d" % index)
		game.run_seed = 20261100 + index
		game.call("_begin_run_with_lineup", pair, "standard")
		var ordinary_turns := _finish_visible_battle(game, pair)
		if game.run_state["nodes"].get("ordinary") != "win":
			_fail("%s ordinary pair UI flow failed" % pair)
			return
		var rest_target := _recoverable(game, pair)
		if rest_target.is_empty():
			game.call("_start_boss")
		else:
			game.call("_take_rest", rest_target)
		var boss_turns := _finish_visible_battle(game, pair)
		if game.run_state["nodes"].get("boss") != "win":
			_fail("%s boss pair UI flow failed" % pair)
			return
		records.append({"pair": pair, "ordinary_turns": ordinary_turns, "boss_turns": boss_turns, "wallet": game.run_state["wallet"], "completed": true})
		root.remove_child(game)
		game.free()
	var trio = await _new_game("trio")
	trio.run_seed = 20261200
	trio.call("_begin_run_with_lineup", ["GPT", "Claude", "DeepSeek"], "test_arena")
	if trio.get_node_or_null("BattleRoot/SharedHand") == null:
		_fail("three-person battle did not expose one shared hand")
		return
	if trio.actor_visuals.size() != 3:
		_fail("three-person battle did not render three actor units")
		return
	var exclusive_probe: Dictionary = {}
	for card_value in trio.battle_state["hand"]:
		var definition: Dictionary = trio.rules.resolved_card(card_value)
		var owner := str(definition.get("owner", ""))
		if not owner.is_empty() and owner != trio.selected_actor:
			exclusive_probe = card_value
			break
	if not exclusive_probe.is_empty():
		var exclusive_definition: Dictionary = trio.rules.resolved_card(exclusive_probe)
		trio.call("_select_action", str(exclusive_probe["uid"]))
		if trio.selected_actor != str(exclusive_definition["owner"]):
			_fail("exclusive shared-hand card did not select its owner")
			return
		if trio.confirm_button.disabled:
			_fail("owner-selected exclusive card did not produce a legal preview")
			return
	var trio_turns := _finish_visible_battle(trio, ["DeepSeek", "GPT", "Claude"])
	if trio.run_state["nodes"].get("test_arena") != "win":
		_fail("three-person UI test arena failed")
		return
	records.append({"lineup": ["GPT", "Claude", "DeepSeek"], "mode": "test_arena", "turns": trio_turns, "completed": true})
	root.remove_child(trio)
	trio.free()
	print("[UI FLOWS] %s" % JSON.stringify(records))
	quit(0)

func _new_game(save_name: String):
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var path := ProjectSettings.globalize_path("res://../_build/test_saves/ui_%s.json" % save_name)
	var manager = SaveManagerScript.new(path, "0.5")
	for candidate in manager.paths().values():
		if FileAccess.file_exists(str(candidate)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(candidate)))
	game.save_manager = manager
	game.last_load_result = {"ok": false, "error": "not_found"}
	return game

func _finish_visible_battle(game, actor_order: Array) -> int:
	while game.battle_state["result"] == "ongoing" and int(game.battle_state["turn"]) < 40:
		for role_id_value in actor_order:
			var role_id := str(role_id_value)
			var actor: Dictionary = game.rules.actor_status(game.battle_state, role_id)
			if actor.is_empty() or not bool(actor["online"]) or bool(actor["acted"]):
				continue
			game.call("_select_actor", role_id)
			var action_id := TestPolicy.choose_action(game.rules, game.battle_state, role_id)
			game.call("_select_action", action_id)
			if game.confirm_button.disabled:
				_fail("Preview unexpectedly rejected %s for %s" % [action_id, role_id])
				return -1
			game.call("_confirm_action")
			var after_first_confirm := JSON.stringify([game.run_state, game.battle_state])
			game.call("_confirm_action")
			if JSON.stringify([game.run_state, game.battle_state]) != after_first_confirm:
				_fail("double confirm mutated state for %s" % role_id)
				return -1
			if game.battle_state["result"] != "ongoing":
				break
		if game.battle_state["result"] == "ongoing":
			game.call("_finish_turn")
	return int(game.battle_state["turn"])

func _recoverable(game, actors: Array) -> String:
	for role_id_value in actors:
		var role_id := str(role_id_value)
		if int(game.run_state["accounts"][role_id]["token"]) < int(game.run_state["accounts"][role_id]["max"]):
			return role_id
	return ""

func _fail(message: String) -> void:
	push_error("[UI FLOW FAIL] %s" % message)
	quit(1)
