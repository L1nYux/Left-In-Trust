extends SceneTree

const ContentDBScript = preload("res://scripts/content_db.gd")
const RulesScript = preload("res://scripts/game_rules.gd")

var rules
var passed := 0

func _init() -> void:
	var content: Dictionary = ContentDBScript.load_content()
	if content.is_empty():
		_fail("generated content is missing")
		return
	rules = RulesScript.new(content)
	var cases := [
		["all three pair combinations complete", _test_pair_combinations],
		["three actors act exactly once in chosen order", _test_three_actor_order],
		["bench exclusive cards stay out of battle deck", _test_bench_cards_filtered],
		["offline owner cards are sealed and never redrawn", _test_offline_cards_sealed],
		["locked target going offline does not redirect", _test_locked_target_no_redirect],
		["directed protection and transfer use personal balances", _test_targets_and_transfer],
		["bench recovers after victory and zero token stays offline", _test_bench_recovery]
	]
	for test_case in cases:
		if not _run(test_case[0], test_case[1]):
			return
	print("[MULTIPLAYER TESTS] PASS %d/%d" % [passed, cases.size()])
	quit(0)

func _run(test_name: String, callable: Callable) -> bool:
	var result = callable.call()
	if typeof(result) != TYPE_BOOL or not bool(result):
		_fail("%s: %s" % [test_name, result])
		return false
	passed += 1
	print("[PASS] %s" % test_name)
	return true

func _fail(message: String) -> void:
	push_error("[MULTIPLAYER FAIL] %s" % message)
	quit(1)

func _start(roster: Array, fielded: Array, battle_id: String = "test", enemy_id: String = "submit", seed: int = 71) -> Array:
	var run_state: Dictionary = rules.make_run_for_roles(roster, seed)
	var state: Dictionary = rules.start_battle(run_state, battle_id, fielded, enemy_id, seed ^ 0x31415)
	if state.has("error"):
		return [run_state, state]
	rules.begin_turn(state)
	return [run_state, state]

func _test_pair_combinations():
	for pair in [["GPT", "Claude"], ["GPT", "DeepSeek"], ["Claude", "DeepSeek"]]:
		var pair_state := _start(pair, pair, "pair-%s-%s" % [pair[0], pair[1]], "submit", 80 + passed)
		var state: Dictionary = pair_state[1]
		var played := _play_to_end(state, pair)
		if state["result"] != "win":
			return "%s did not win: %s" % [pair, played]
		for turn_value in played["actions"].values():
			for count_value in turn_value.values():
				if int(count_value) != 1:
					return "%s actor acted more than once" % pair
	return true

func _test_three_actor_order():
	var started := _start(["GPT", "Claude", "DeepSeek"], ["GPT", "Claude", "DeepSeek"], "three", "recipient", 91)
	var state: Dictionary = started[1]
	state["hp"] = 999
	state["intents"] = []
	var order := ["DeepSeek", "GPT", "Claude"]
	for actor_id in order:
		var before := JSON.stringify(state)
		var first: Dictionary = rules.try_action(state, actor_id, RulesScript.BASIC_GUARD, actor_id)
		if not first["ok"]:
			return "%s first action rejected" % actor_id
		var after := JSON.stringify(state)
		var second: Dictionary = rules.try_action(state, actor_id, RulesScript.BASIC_ATTACK, actor_id)
		if second["ok"] or second.get("error") != "action_unavailable":
			return "%s second action accepted" % actor_id
		if JSON.stringify(state) != after or before == after:
			return "%s rejection was not atomic" % actor_id
	for actor_id in order:
		if not bool(rules.actor_status(state, actor_id)["acted"]):
			return "%s did not act" % actor_id
	return true

func _test_bench_cards_filtered():
	var started := _start(["GPT", "Claude", "DeepSeek"], ["GPT", "Claude"], "bench", "submit", 101)
	var state: Dictionary = started[1]
	if state["actors"].size() != 2 or not rules.actor_status(state, "DeepSeek").is_empty():
		return "healthy bench entered automatically"
	if int(state["total_cards"]) != 33:
		return "expected 36 minus three bench-exclusive cards, got %s" % state["total_cards"]
	for zone_name in ["draw", "hand", "discard"]:
		for card_value in state[zone_name]:
			var definition: Dictionary = rules.resolved_card(card_value)
			if definition.get("owner", "") == "DeepSeek":
				return "bench exclusive %s entered %s" % [card_value["code"], zone_name]
	return true

func _test_offline_cards_sealed():
	var started := _start(["GPT", "Claude"], ["GPT", "Claude"], "seal", "submit", 111)
	var state: Dictionary = started[1]
	state["accounts"]["GPT"]["token"] = 1
	rules.resolve_hit(state, "GPT", 1)
	if state["sealed"].size() != 3:
		return "expected three GPT cards sealed"
	for zone_name in ["draw", "hand", "discard"]:
		for card_value in state[zone_name]:
			if rules.resolved_card(card_value).get("owner", "") == "GPT":
				return "GPT card remained in %s" % zone_name
	for unused in 3:
		if state["result"] != "ongoing":
			break
		rules.try_action(state, "Claude", RulesScript.BASIC_GUARD, "Claude")
		rules.finish_turn(state)
		if state["result"] == "ongoing":
			rules.begin_turn(state)
			for card_value in state["hand"]:
				if rules.resolved_card(card_value).get("owner", "") == "GPT":
					return "sealed GPT card was redrawn"
	return true

func _test_locked_target_no_redirect():
	var started := _start(["GPT", "Claude"], ["GPT", "Claude"], "locked", "duplicate", 121)
	var state: Dictionary = started[1]
	state["accounts"]["GPT"]["token"] = 1
	state["intents"] = [{"target": "GPT", "raw": 1}, {"target": "GPT", "raw": 9}]
	var claude_before: int = state["accounts"]["Claude"]["token"]
	var result: Dictionary = rules.finish_turn(state)
	if result["events"].size() != 2 or not bool(result["events"][1]["skipped"]):
		return "remaining segment was not skipped"
	if int(state["accounts"]["Claude"]["token"]) != claude_before:
		return "remaining segment redirected to Claude"
	return state["result"] == "ongoing"

func _test_targets_and_transfer():
	var started := _start(["GPT", "Claude"], ["GPT", "Claude"], "targets", "submit", 131)
	var state: Dictionary = started[1]
	var guard_uid := _force_card(state, "D")
	var guard_result: Dictionary = rules.try_action(state, "Claude", guard_uid, "GPT")
	if not guard_result["ok"] or int(rules.actor_status(state, "GPT")["shield"]) != 4:
		return "directed protection did not land on GPT"
	rules.finish_turn(state)
	rules.begin_turn(state)
	state["accounts"]["GPT"]["token"] = 3
	state["accounts"]["Claude"]["token"] = 7
	var transfer := {"uid": "probe-T", "code": "T", "upgraded": true}
	state["hand"].append(transfer)
	state["total_cards"] = int(state["total_cards"]) + 1
	var before_invalid := JSON.stringify(state)
	var invalid: Dictionary = rules.try_action(state, "GPT", "probe-T", "GPT")
	if invalid["ok"] or invalid.get("error") != "bad_transfer" or JSON.stringify(state) != before_invalid:
		return "invalid self-transfer was not atomic"
	var moved: Dictionary = rules.try_action(state, "GPT", "probe-T", "Claude")
	if not moved["ok"]:
		return "valid transfer rejected"
	if int(state["accounts"]["GPT"]["token"]) != 1 or int(state["accounts"]["Claude"]["token"]) != 9:
		return "personal transfer balances mismatch"
	return int(rules.actor_status(state, "Claude")["shield"]) == 2

func _test_bench_recovery():
	var started := _start(["GPT", "Claude", "DeepSeek"], ["GPT", "Claude"], "recover", "submit", 141)
	var run_state: Dictionary = started[0]
	var state: Dictionary = started[1]
	state["accounts"]["GPT"]["token"] = 4
	state["accounts"]["Claude"]["token"] = 8
	state["accounts"]["DeepSeek"]["token"] = 0
	state["result"] = "win"
	var settled: Dictionary = rules.settle_battle(run_state, state)
	if not settled["ok"]:
		return "settlement failed"
	if [run_state["accounts"]["GPT"]["token"], run_state["accounts"]["Claude"]["token"], run_state["accounts"]["DeepSeek"]["token"]] != [7, 11, 0]:
		return "victory recovery mismatch"
	return rules.actor_status(state, "DeepSeek").is_empty()

func _force_card(state: Dictionary, code: String) -> String:
	for zone_name in ["hand", "draw", "discard"]:
		for index in state[zone_name].size():
			if state[zone_name][index]["code"] == code:
				var instance: Dictionary = state[zone_name][index]
				if zone_name != "hand":
					state[zone_name].remove_at(index)
					state["hand"].append(instance)
				return str(instance["uid"])
	return ""

func _play_to_end(state: Dictionary, actor_order: Array) -> Dictionary:
	var action_counts := {}
	while state["result"] == "ongoing" and int(state["turn"]) < 40:
		var counts := {}
		for actor_id_value in actor_order:
			var actor_id := str(actor_id_value)
			var actor: Dictionary = rules.actor_status(state, actor_id)
			if actor.is_empty() or not bool(actor["online"]):
				continue
			var choice := _best_action(state, actor_id)
			var result: Dictionary = rules.try_action(state, actor_id, str(choice["action"]), str(choice["target"]))
			if not result["ok"]:
				return {"error": result.get("error"), "turn": state["turn"], "actions": action_counts}
			counts[actor_id] = int(counts.get(actor_id, 0)) + 1
			if state["result"] != "ongoing":
				break
		action_counts[str(state["turn"])] = counts
		if state["result"] == "ongoing":
			rules.finish_turn(state)
			if state["result"] == "ongoing":
				rules.begin_turn(state)
	return {"result": state["result"], "actions": action_counts}

func _best_action(state: Dictionary, actor_id: String) -> Dictionary:
	var options: Array = [RulesScript.BASIC_ATTACK, RulesScript.BASIC_GUARD]
	for card_value in state["hand"]:
		options.append(str(card_value["uid"]))
	var best := {"action": RulesScript.BASIC_ATTACK, "target": actor_id, "score": -1}
	for action_id_value in options:
		var action_id := str(action_id_value)
		for target_id_value in rules.legal_targets(state, actor_id, action_id):
			var target_id := str(target_id_value)
			var preview: Dictionary = rules.preview_action(state, actor_id, action_id, target_id)
			var score := int(preview.get("damage", 0)) * 100 + int(preview.get("shield", 0))
			if score > int(best["score"]):
				best = {"action": action_id, "target": target_id, "score": score}
	return best
