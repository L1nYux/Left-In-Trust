extends SceneTree

const ContentDBScript = preload("res://scripts/content_db.gd")
const RulesScript = preload("res://scripts/game_rules.gd")
const TestPolicy = preload("res://tests/test_policy.gd")

var rules

func _init() -> void:
	var content: Dictionary = ContentDBScript.load_content()
	if content.is_empty():
		push_error("Missing generated content")
		quit(1)
		return
	rules = RulesScript.new(content)
	var records: Array = []
	for index in 3:
		var role_id: String = ["GPT", "Claude", "DeepSeek"][index]
		var seed := 20261025 + index
		var record := _complete_slice(role_id, seed)
		records.append(record)
		if not record.get("completed", false):
			push_error("Smoke run failed: %s" % JSON.stringify(record))
			quit(1)
			return
	print("[SMOKE RUNS] %s" % JSON.stringify(records))
	quit(0)

func _complete_slice(role_id: String, seed: int) -> Dictionary:
	var run_state: Dictionary = rules.make_run(role_id, seed)
	var ordinary := _play(run_state, "ordinary", role_id, "missing_attachment", seed ^ 0x13579)
	if ordinary["result"] != "win":
		return {"role": role_id, "seed": seed, "completed": false, "failed_at": "ordinary", "turn": ordinary["turn"]}
	rules.settle_battle(run_state, ordinary)
	var before_rest: int = run_state["accounts"][role_id]["token"]
	if before_rest < run_state["accounts"][role_id]["max"]:
		rules.rest_recover(run_state, "rest", role_id)
	var after_rest: int = run_state["accounts"][role_id]["token"]
	var boss := _play(run_state, "boss", role_id, "submit", seed ^ 0x24680)
	if boss["result"] != "win":
		return {"role": role_id, "seed": seed, "completed": false, "failed_at": "boss", "turn": boss["turn"], "rest": [before_rest, after_rest]}
	rules.settle_battle(run_state, boss)
	return {
		"role": role_id, "seed": seed, "completed": true,
		"ordinary_turns": ordinary["turn"], "rest": [before_rest, after_rest],
		"boss_turns": boss["turn"], "final_token": run_state["accounts"][role_id]["token"],
		"wallet": run_state["wallet"]
	}

func _play(run_state: Dictionary, battle_id: String, role_id: String, enemy_id: String, seed: int) -> Dictionary:
	var state: Dictionary = rules.start_battle(run_state, battle_id, [role_id], enemy_id, seed)
	while state["result"] == "ongoing" and int(state["turn"]) < 40:
		rules.begin_turn(state)
		var chosen := TestPolicy.choose_action(rules, state, role_id)
		rules.try_action(state, role_id, chosen, role_id)
		rules.finish_turn(state)
	return state
