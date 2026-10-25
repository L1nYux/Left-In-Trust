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
		["starting decks and draw cycle", _test_deck_and_draw],
		["multi-role run composes every starting deck", _test_multi_role_deck],
		["fixed seed is reproducible", _test_seed_reproducible],
		["payment rejection is atomic", _test_payment_atomicity],
		["one action per actor per turn", _test_action_count],
		["personal protection absorbs multiple segments", _test_protection],
		["offline target does not redirect and seals owner cards", _test_offline],
		["lethal damage stops enemy immediately", _test_kill_stop],
		["GPT combo passive", _test_gpt_combo],
		["Claude protection counter passive", _test_claude_counter],
		["DeepSeek rice and early cash-out passive", _test_deepseek_rice],
		["unsettled battle cannot be restarted", _test_battle_registration],
		["ended run reports run_ended for rest", _test_ended_rest_error]
	]
	for test_case in cases:
		if not _run(test_case[0], test_case[1]):
			return
	print("[RULE TESTS] PASS %d/%d" % [passed, cases.size()])
	quit(0)

func _run(test_name: String, callable: Callable) -> bool:
	var result = callable.call()
	if result != true:
		_fail("%s: %s" % [test_name, result])
		return false
	passed += 1
	print("[PASS] %s" % test_name)
	return true

func _fail(message: String) -> void:
	push_error("[FAIL] %s" % message)
	quit(1)

func _battle(role_id: String, enemy_id: String = "submit", seed: int = 7) -> Array:
	var run_state: Dictionary = rules.make_run(role_id, seed)
	var state: Dictionary = rules.start_battle(run_state, "test", [role_id], enemy_id, seed)
	rules.begin_turn(state)
	return [run_state, state]

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

func _test_deck_and_draw():
	for role_id in ["GPT", "Claude", "DeepSeek"]:
		var run_state: Dictionary = rules.make_run(role_id, 11)
		if run_state["deck"].size() != 12:
			return "%s deck size" % role_id
		var state: Dictionary = rules.start_battle(run_state, "deck", [role_id], "missing_attachment", 11)
		rules.begin_turn(state)
		if state["hand"].size() != 5:
			return "%s opening hand" % role_id
		state["intents"] = []
		rules.try_action(state, role_id, RulesScript.BASIC_GUARD, role_id)
		rules.finish_turn(state)
		rules.begin_turn(state)
		if state["hand"].size() != 5:
			return "%s redraw" % role_id
	return true

func _test_multi_role_deck():
	var run_state: Dictionary = rules.make_run_for_roles(["GPT", "Claude"], 12)
	if run_state["deck"].size() != 24:
		return "two roles should contribute 24 cards"
	var uids := {}
	var counts := {"G1": 0, "G2": 0, "C1": 0, "C2": 0}
	for card_value in run_state["deck"]:
		var card: Dictionary = card_value
		if uids.has(card["uid"]):
			return "card uid collision"
		uids[card["uid"]] = true
		if counts.has(card["code"]):
			counts[card["code"]] += 1
	if counts != {"G1": 2, "G2": 1, "C1": 2, "C2": 1}:
		return "role-specific recipe mismatch: %s" % counts
	var state: Dictionary = rules.start_battle(run_state, "claude-only", ["Claude"], "missing_attachment", 12)
	if state["total_cards"] != 21:
		return "bench-specific cards should be filtered"
	return true

func _test_seed_reproducible():
	var first: Dictionary = _battle("GPT", "missing_attachment", 123)[1]
	var second: Dictionary = _battle("GPT", "missing_attachment", 123)[1]
	return JSON.stringify(first["hand"]) == JSON.stringify(second["hand"])

func _test_payment_atomicity():
	var state: Dictionary = _battle("GPT")[1]
	var card_id := _force_card(state, "A")
	state["accounts"]["GPT"]["token"] = 1
	var before := JSON.stringify(state)
	var result: Dictionary = rules.try_action(state, "GPT", card_id, "GPT")
	if result["ok"] or result["error"] != "personal_payment":
		return "payment should reject"
	return JSON.stringify(state) == before

func _test_action_count():
	var state: Dictionary = _battle("GPT")[1]
	if not rules.try_action(state, "GPT", RulesScript.BASIC_ATTACK, "GPT")["ok"]:
		return "first action failed"
	var before := JSON.stringify(state)
	var second: Dictionary = rules.try_action(state, "GPT", RulesScript.BASIC_GUARD, "GPT")
	if second["ok"] or second["error"] != "action_unavailable":
		return "second action should reject"
	return JSON.stringify(state) == before

func _test_protection():
	var run_state: Dictionary = rules.make_run_for_roles(["Claude", "GPT"], 9)
	var state: Dictionary = rules.start_battle(run_state, "protect", ["Claude", "GPT"], "submit", 9)
	rules.begin_turn(state)
	var card_id := _force_card(state, "D")
	if not rules.try_action(state, "Claude", card_id, "GPT")["ok"]:
		return "guard failed"
	var one: Dictionary = rules.resolve_hit(state, "GPT", 3)
	var two: Dictionary = rules.resolve_hit(state, "GPT", 3)
	if one["absorbed"] != 3 or two["absorbed"] != 1:
		return "segment absorption mismatch"
	return state["accounts"]["GPT"]["token"] == 10 and rules.actor_status(state, "Claude")["shield"] == 0

func _test_offline():
	var run_state: Dictionary = rules.make_run_for_roles(["GPT", "Claude"], 13)
	var state: Dictionary = rules.start_battle(run_state, "offline", ["GPT", "Claude"], "submit", 13)
	rules.begin_turn(state)
	state["accounts"]["GPT"]["token"] = 1
	var claude_before: int = state["accounts"]["Claude"]["token"]
	rules.resolve_hit(state, "GPT", 1)
	var skipped: Dictionary = rules.resolve_hit(state, "GPT", 99)
	if not skipped["skipped"] or state["accounts"]["Claude"]["token"] != claude_before:
		return "locked target redirected"
	return state["sealed"].size() == 3 and state["result"] == "ongoing"

func _test_kill_stop():
	var state: Dictionary = _battle("GPT")[1]
	state["hp"] = 3
	state["intents"] = [{"target": "GPT", "raw": 99}]
	if not rules.try_action(state, "GPT", RulesScript.BASIC_ATTACK, "GPT")["ok"]:
		return "lethal action failed"
	var token_before: int = state["accounts"]["GPT"]["token"]
	var rejected: Dictionary = rules.try_action(state, "GPT", RulesScript.BASIC_GUARD, "GPT")
	if rejected["ok"]:
		return "post-lethal action accepted"
	rules.finish_turn(state)
	return state["accounts"]["GPT"]["token"] == token_before and state["result"] == "win"

func _test_gpt_combo():
	var state: Dictionary = _battle("GPT")[1]
	state["intents"] = []
	var first := _force_card(state, "G1")
	if rules.try_action(state, "GPT", first, "GPT")["damage"] != 5:
		return "first combo damage"
	rules.finish_turn(state)
	rules.begin_turn(state)
	state["intents"] = []
	var second := _force_card(state, "G1")
	if rules.try_action(state, "GPT", second, "GPT")["damage"] != 7:
		return "second combo damage"
	rules.finish_turn(state)
	rules.begin_turn(state)
	var finisher := _force_card(state, "G2")
	return rules.preview_action(state, "GPT", finisher, "GPT")["damage"] == 16

func _test_claude_counter():
	var state: Dictionary = _battle("Claude")[1]
	var guard := _force_card(state, "C1")
	state["intents"] = [{"target": "Claude", "raw": 2}]
	if not rules.try_action(state, "Claude", guard, "Claude")["ok"]:
		return "C1 failed"
	rules.finish_turn(state)
	if not rules.actor_status(state, "Claude")["counter"]:
		return "counter not armed"
	rules.begin_turn(state)
	return rules.preview_action(state, "Claude", RulesScript.BASIC_ATTACK, "Claude")["damage"] == 7

func _test_deepseek_rice():
	var state: Dictionary = _battle("DeepSeek")[1]
	state["intents"] = []
	var simmer := _force_card(state, "S1")
	rules.try_action(state, "DeepSeek", simmer, "DeepSeek")
	rules.finish_turn(state)
	if rules.actor_status(state, "DeepSeek")["rice"] != 2:
		return "S1 plus end-turn rice"
	rules.begin_turn(state)
	state["intents"] = []
	rules.try_action(state, "DeepSeek", RulesScript.BASIC_GUARD, "DeepSeek")
	rules.finish_turn(state)
	if rules.actor_status(state, "DeepSeek")["rice"] != 3:
		return "rice cap"
	rules.begin_turn(state)
	var cash := _force_card(state, "S2")
	var action: Dictionary = rules.try_action(state, "DeepSeek", cash, "DeepSeek")
	return action["damage"] == 14 and rules.actor_status(state, "DeepSeek")["rice"] == 0

func _test_battle_registration():
	var run_state: Dictionary = rules.make_run("GPT", 201)
	var state: Dictionary = rules.start_battle(run_state, "ordinary", ["GPT"], "missing_attachment", 202)
	state["result"] = "loss"
	var before := JSON.stringify(run_state)
	var restarted: Dictionary = rules.start_battle(run_state, "ordinary", ["GPT"], "missing_attachment", 999)
	if restarted.get("error") != "battle_already_started":
		return "unsettled battle restart should reject"
	if JSON.stringify(run_state) != before:
		return "rejected restart mutated run"
	return true

func _test_ended_rest_error():
	var run_state: Dictionary = rules.make_run("GPT", 301)
	run_state["ended"] = true
	var before := JSON.stringify(run_state)
	var result: Dictionary = rules.rest_recover(run_state, "rest", "GPT")
	if result.get("error") != "run_ended":
		return "ended run should not report service_used"
	if JSON.stringify(run_state) != before:
		return "rejected rest mutated run"
	return true
