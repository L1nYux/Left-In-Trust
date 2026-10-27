extends SceneTree

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
		if not str(game.call("_error_text", "basic_used")).contains("基础动作"):
			_fail("basic_used was not mapped to readable UI text")
			return
		game.run_seed = seed
		game.call("_show_role_select")
		game.call("_begin_run", role_id)
		if game.flow != "map" or game.get_node_or_null("MapRoot/MapOrdinary") == null:
			_fail("%s did not enter the chapter map" % role_id)
			return
		var ordinary_icon := game.get_node_or_null("MapRoot/MapOrdinary") as Button
		if ordinary_icon == null or ordinary_icon.icon == null or not ordinary_icon.text.is_empty():
			_fail("map nodes are not icon-only buttons")
			return
		if game.get_node_or_null("MapRoot/MapRest") == null or game.get_node_or_null("MapRoot/MapBoss") == null:
			_fail("map is missing rest/boss icon nodes")
			return
		if game.get_node_or_null("MapRoot/SettingsButton") == null:
			_fail("map is missing the settings button")
			return
		game.call("_start_ordinary")
		if game.get_node_or_null("BattleRoot/SharedHand") == null:
			_fail("battle is missing the SharedHand layer")
			return
		if game.get_node_or_null("BattleRoot/SettingsButton") == null:
			_fail("battle is missing the settings button")
			return
		if not _battle_layout_ok(game):
			return
		var attack_uid := _first_attack_uid(game)
		if attack_uid.is_empty():
			_fail("starting hand has no attack card to drag")
			return
		game.call("_show_card_detail", attack_uid)
		var detail: Control = game.get_node_or_null("BattleRoot/CardDetailPanel")
		if detail == null or not (detail as Control).visible:
			_fail("card hover detail panel did not open")
			return
		var detail_text := _collect_texts(detail)
		if not detail_text.contains("伤害"):
			_fail("card hover detail did not show the effect text")
			return
		for retired_detail in ["费用", "归属", "目标", "token", "拖到"]:
			if detail_text.contains(retired_detail):
				_fail("card hover detail is not concise: %s" % detail_text)
				return
		var detail_definition: Dictionary = game.card_definitions.get(attack_uid, {})
		var expected_owner := str(detail_definition.get("owner", ""))
		expected_owner = "通用" if expected_owner.is_empty() else expected_owner
		if not detail_text.contains(expected_owner):
			_fail("card hover detail is missing concise owner %s: %s" % [expected_owner, detail_text])
			return
		game.call("_hide_card_detail")
		var hp_before := int(game.battle_state["hp"])
		if not game.call("_begin_drag", attack_uid):
			_fail("dragging an attack card could not start")
			return
		var enemy_center: Vector2 = game.call("_enemy_drop_center")
		game.call("_update_drag", enemy_center)
		if not game.call("_drop_drag_at", enemy_center):
			_fail("dropping an attack card on the enemy was rejected")
			return
		if int(game.battle_state["hp"]) >= hp_before:
			_fail("dragged attack card did not damage the enemy")
			return
		if index == 0:
			if not game.call("_play_action", role_id, "basic_attack", role_id):
				_fail("basic attack was rejected on its first use")
				return
			if game.call("_play_action", role_id, "basic_attack", role_id):
				_fail("basic attack was allowed twice in one turn")
				return
			if not bool(game.rules.basic_used(game.battle_state, role_id, "basic_attack")):
				_fail("rules.basic_used did not report the spent basic attack")
				return
			if not game.call("_play_action", role_id, "basic_guard", role_id):
				_fail("basic guard was rejected on its first use")
				return
			if game.call("_play_action", role_id, "basic_guard", role_id):
				_fail("basic guard was allowed twice in one turn")
				return
		var ordinary_turns := _finish_visible_battle(game, [role_id])
		if game.run_state["nodes"].get("ordinary") != "win":
			_fail("%s ordinary UI flow failed" % role_id)
			return
		if game.flow != "map":
			_fail("%s did not return to the map after ordinary battle" % role_id)
			return
		var before_rest: int = game.run_state["accounts"][role_id]["token"]
		if before_rest < int(game.run_state["accounts"][role_id]["max"]):
			game.call("_show_rest")
			game.call("_take_rest")
			var after_first_rest := JSON.stringify([game.run_state, game.battle_state])
			game.call("_take_rest")
			if JSON.stringify([game.run_state, game.battle_state]) != after_first_rest:
				_fail("double rest mutated state for %s" % role_id)
				return
		game.call("_start_boss")
		var after_rest: int = game.run_state["accounts"][role_id]["token"]
		var boss_turns := _finish_visible_battle(game, [role_id])
		if game.run_state["nodes"].get("boss") != "win":
			_fail("%s boss UI flow failed" % role_id)
			return
		if index == 0:
			if not _result_screen_ok(game, [role_id]):
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
		game.call("_start_ordinary")
		var ordinary_turns := _finish_visible_battle(game, pair)
		if game.run_state["nodes"].get("ordinary") != "win":
			_fail("%s ordinary pair UI flow failed" % pair)
			return
		var rest_target := _recoverable(game, pair)
		if not rest_target.is_empty():
			game.call("_show_rest")
			game.call("_take_rest", rest_target)
		game.call("_start_boss")
		if game.enemy_visual == null or str(game.enemy_visual.enemy_id) != "submit":
			_fail("%s boss battle did not use the formal submit artwork" % pair)
			return
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
		if _find_node_named(trio.get_node("BattleRoot"), "Card_%s" % str(exclusive_probe["uid"])) == null:
			_fail("exclusive card button was not built on the hand layer")
			return
	var trio_turns := _finish_visible_battle(trio, ["DeepSeek", "GPT", "Claude"])
	if trio.run_state["nodes"].get("test_arena") != "win":
		_fail("three-person UI test arena failed")
		return
	records.append({"lineup": ["GPT", "Claude", "DeepSeek"], "mode": "test_arena", "turns": trio_turns, "completed": true})
	root.remove_child(trio)
	trio.free()
	var settings_game = await _new_game("settings")
	settings_game.call("_begin_run", "GPT")
	if settings_game.flow != "map":
		_fail("settings probe did not reach the map")
		return
	var settings_button := settings_game.get_node_or_null("MapRoot/SettingsButton") as Button
	if settings_button == null:
		_fail("map settings button missing")
		return
	settings_button.emit_signal("pressed")
	await process_frame
	await process_frame
	if settings_game.get_node_or_null("SettingsOverlay/SettingsPanel") == null:
		_fail("settings overlay did not open from the map")
		return
	if not _collect_texts(settings_game.get_node_or_null("SettingsOverlay")).contains("返回标题界面"):
		_fail("settings overlay is missing the return-to-title button")
		return
	var back_button = _find_button(settings_game.get_node_or_null("SettingsOverlay"), "返回标题界面")
	if back_button == null:
		_fail("settings return button was not clickable")
		return
	back_button.emit_signal("pressed")
	await process_frame
	await process_frame
	if settings_game.flow != "title":
		_fail("settings return to title did not land on the title screen")
		return
	if not _collect_texts(settings_game).contains("未尽之托"):
		_fail("title screen did not render after leaving settings")
		return
	records.append({"settings": "map->title", "completed": true})
	root.remove_child(settings_game)
	settings_game.free()
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
			if actor.is_empty() or not bool(actor["online"]):
				continue
			var actions_taken := 0
			while game.battle_state["result"] == "ongoing" and actions_taken < 12 and bool(game.call("_has_legal_action", role_id)):
				var choice := _pick_play(game, role_id)
				if choice.is_empty():
					break
				if not bool(game.call("_play_action", role_id, str(choice["action"]), str(choice["target"]))):
					_fail("_play_action rejected %s for %s" % [choice["action"], role_id])
					return -1
				actions_taken += 1
		if game.battle_state["result"] == "ongoing":
			game.call("_finish_turn")
	return int(game.battle_state["turn"])

func _pick_play(game, role_id: String) -> Dictionary:
	var options: Array = ["basic_attack", "basic_guard"]
	for card_value in game.battle_state["hand"]:
		options.append(str(card_value["uid"]))
	var best := {}
	for action_id_value in options:
		var action_id := str(action_id_value)
		if bool(game.call("_basic_used", role_id, action_id)):
			continue
		for target_value in game.rules.legal_targets(game.battle_state, role_id, action_id):
			var target_id := str(target_value)
			var preview: Dictionary = game.rules.preview_action(game.battle_state, role_id, action_id, target_id)
			var score := int(preview.get("damage", 0)) * 100 + int(preview.get("shield", 0)) * 2 + int(preview.get("heal", 0)) * 5 + int(preview.get("rice_gain", 0)) * 2
			if best.is_empty() or score > int(best["score"]):
				best = {"action": action_id, "target": target_id, "score": score}
	return best

func _first_attack_uid(game) -> String:
	for card_value in game.battle_state["hand"]:
		var definition: Dictionary = game.rules.resolved_card(card_value)
		if str(definition.get("kind", "attack")) == "attack":
			return str(card_value["uid"])
	return ""

func _battle_layout_ok(game) -> bool:
	var battle_root: Node = game.get_node_or_null("BattleRoot")
	if battle_root == null:
		_fail("battle root missing")
		return false
	var texts := _collect_texts(battle_root)
	for forbidden in ["共享手牌", "当前行动", "每名在线角色", "选择场中角色", "确认执行"]:
		if texts.contains(forbidden):
			_fail("battle UI still shows retired text: %s" % forbidden)
			return false
	var round_label := battle_root.get_node_or_null("RoundLabel") as Label
	if round_label == null or not str(round_label.text).begins_with("第 "):
		_fail("battle header is missing the standalone turn label")
		return false
	for child in battle_root.get_children():
		if child is Label and child != round_label and (child as Control).position.y < 64.0 and str(child.text).contains(str(game.selected_actor)):
			_fail("battle header still repeats the active actor beside the turn")
			return false
	var end_turn := battle_root.get_node_or_null("EndTurnButton") as Button
	if end_turn == null or end_turn.text != "↑" or not end_turn.tooltip_text.contains("结束回合"):
		_fail("end turn is not represented by the send control")
		return false
	var pause := battle_root.get_node_or_null("SettingsButton") as Button
	if pause == null or pause.text != "Ⅱ" or not pause.tooltip_text.contains("暂停"):
		_fail("settings is not represented by the pause control")
		return false
	for uid in game.hand_card_buttons.keys():
		var card: Button = game.hand_card_buttons[uid]
		if not is_instance_valid(card):
			continue
		var card_texts := _collect_texts(card)
		if card_texts.contains("费用") or card_texts.contains("伤害") or card_texts.contains("归属") or card_texts.contains("白饭") or card_texts.contains("防护 ") or card_texts.contains("恢复 "):
			_fail("card face leaks effect text: %s" % card_texts)
			return false
		if card.size.x > 132.0 or card.size.y > 184.0:
			_fail("card footprint is larger than the compact layout: %s" % card.size)
			return false
		if card.get_node_or_null("TokenCostBadge") != null:
			_fail("card face still uses the old token badge")
			return false
		var title := card.find_child("CardTitle", true, false) as Label
		var cost := card.find_child("TokenCost", true, false) as Label
		if title == null or cost == null:
			_fail("card face is missing the title or token cost line")
			return false
		var cost_parts := cost.text.split("  ", false)
		if cost_parts.size() != 2 or cost_parts[0] != "token" or not str(cost_parts[1]).is_valid_int():
			_fail("card token cost does not use the requested format: %s" % cost.text)
			return false
		if cost.get_parent() != title.get_parent() or cost.get_index() <= title.get_index():
			_fail("card token cost is not placed below the title")
			return false
		var minimum_title_size := 13 if card.size.x <= 100.0 else 16
		if title.get_theme_font_size("font_size") < minimum_title_size:
			_fail("card title font is smaller than the revised layout")
			return false
	return true

func _result_screen_ok(game, lineup: Array) -> bool:
	if game.flow != "result":
		_fail("boss victory did not reach the result screen")
		return false
	var texts := _collect_texts(game)
	if not texts.contains("委托完成"):
		_fail("result screen is missing the 委托完成 title")
		return false
	for forbidden in ["seed", "算力", "战斗日志", "TOKEN"]:
		if texts.contains(forbidden):
			_fail("result screen still shows battle summary text: %s" % forbidden)
			return false
	for role_id_value in lineup:
		if not texts.contains(str(role_id_value)):
			_fail("result screen is missing lineup member %s" % role_id_value)
			return false
	return true

func _collect_texts(node: Node) -> String:
	var parts: Array[String] = []
	_collect_texts_into(node, parts)
	return "\n".join(parts)

func _collect_texts_into(node: Node, parts: Array) -> void:
	if node == null:
		return
	if node is Label or node is Button:
		parts.append(str(node.text))
	for child in node.get_children():
		_collect_texts_into(child, parts)

func _find_node_named(node: Node, node_name: String) -> Node:
	if node == null:
		return null
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_named(child, node_name)
		if found != null:
			return found
	return null

func _find_button(node: Node, text_prefix: String) -> Button:
	if node == null:
		return null
	if node is Button and str(node.text).begins_with(text_prefix):
		return node
	for child in node.get_children():
		var found := _find_button(child, text_prefix)
		if found != null:
			return found
	return null

func _recoverable(game, actors: Array) -> String:
	for role_id_value in actors:
		var role_id := str(role_id_value)
		if int(game.run_state["accounts"][role_id]["token"]) < int(game.run_state["accounts"][role_id]["max"]):
			return role_id
	return ""

func _fail(message: String) -> void:
	push_error("[UI FLOW FAIL] %s" % message)
	quit(1)
