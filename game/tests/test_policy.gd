extends RefCounted

const RulesScript = preload("res://scripts/game_rules.gd")

static func choose_action(rules, state: Dictionary, role_id: String) -> String:
	var options: Array[String] = [RulesScript.BASIC_ATTACK, RulesScript.BASIC_GUARD]
	for card_value in state["hand"]:
		options.append(str(card_value["uid"]))
	var best := RulesScript.BASIC_ATTACK
	var best_score := -1000000.0
	for action_id in options:
		var trial: Dictionary = state.duplicate(true)
		var action: Dictionary = rules.try_action(trial, role_id, action_id, role_id)
		if not action["ok"]:
			continue
		rules.finish_turn(trial)
		var damage_done := int(state["hp"]) - int(trial["hp"])
		var actor: Dictionary = rules.actor_status(trial, role_id)
		var passive_score := float(actor.get("streak", 0)) * 1.2 + float(actor.get("rice", 0)) * 1.5
		if bool(actor.get("counter", false)):
			passive_score += 3.0
		var score := 0.0
		if str(trial["result"]) == "loss":
			score = -10000.0
		elif str(trial["result"]) == "win":
			score = 10000.0 + float(trial["accounts"][role_id]["token"])
		else:
			score = float(damage_done) * 1.25 + float(trial["accounts"][role_id]["token"]) * 2.0 + passive_score
		if score > best_score:
			best_score = score
			best = action_id
	return best
