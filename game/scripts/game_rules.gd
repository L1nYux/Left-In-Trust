class_name GameRules
extends RefCounted

const BASIC_ATTACK := "basic_attack"
const BASIC_GUARD := "basic_guard"

var data: Dictionary
var card_defs: Dictionary = {}
var role_defs: Dictionary = {}
var enemy_defs: Dictionary = {}

func _init(content: Dictionary) -> void:
	data = content
	for definition in data.get("cards", []):
		card_defs[definition["id"]] = definition
	for role in data.get("roles", []):
		role_defs[role["id"]] = role
	for enemy in data.get("enemies", []):
		enemy_defs[enemy["id"]] = enemy

func make_starting_deck(role_id: String) -> Array:
	if not role_defs.has(role_id):
		return []
	var role: Dictionary = role_defs[role_id]
	var recipe: Array = ["A", "A", "A", "D", "D", "D", "H", "H", "R", role["cards"][0], role["cards"][0], role["cards"][1]]
	var deck: Array = []
	for index in recipe.size():
		deck.append({"uid": "%s-%02d" % [role_id, index], "code": recipe[index], "upgraded": false})
	return deck

func make_run(role_id: String, seed: int) -> Dictionary:
	return make_run_for_roles([role_id], seed)

func make_run_for_roles(role_ids: Array, seed: int) -> Dictionary:
	if role_ids.is_empty() or not role_defs.has(str(role_ids[0])):
		return {}
	var accounts := {}
	var deck: Array = []
	for role_id_value in role_ids:
		var role_id := str(role_id_value)
		if not role_defs.has(role_id) or accounts.has(role_id):
			return {}
		accounts[role_id] = {"token": int(data["parameters"]["maxToken"]), "max": int(data["parameters"]["maxToken"])}
		deck.append_array(make_starting_deck(role_id))
	return {
		"id": "run-%d" % seed,
		"seed": seed,
		"accounts": accounts,
		"deck": deck,
		"wallet": 0,
		"nodes": {},
		"battles": {},
		"next_battle_instance": 1,
		"services": {},
		"started": false,
		"ended": false
	}

func start_battle(run_state: Dictionary, battle_id: String, lineup: Array, enemy_id: String, battle_seed: int) -> Dictionary:
	if run_state.is_empty() or run_state.get("ended", false) or run_state["nodes"].has(battle_id):
		return {"error": "run_or_node_finished"}
	if run_state.get("battles", {}).has(battle_id):
		return {"error": "battle_already_started"}
	if lineup.is_empty() or lineup.size() > 3:
		return {"error": "invalid_lineup"}
	var seen := {}
	for role_id_value in lineup:
		var role_id := str(role_id_value)
		if seen.has(role_id) or not run_state["accounts"].has(role_id) or int(run_state["accounts"][role_id]["token"]) <= 0:
			return {"error": "invalid_lineup"}
		seen[role_id] = true
	if not enemy_defs.has(enemy_id):
		return {"error": "unknown_enemy"}
	var actors: Array = []
	for role_id_value in lineup:
		actors.append({
			"id": str(role_id_value), "online": true, "acted": false,
			"basic_attack_used": false, "basic_guard_used": false,
			"shield": 0, "streak": 0, "counter": false, "rice": 0,
			"protected": []
		})
	var draw: Array = []
	for instance in run_state["deck"]:
		var definition: Dictionary = card_defs[instance["code"]]
		if not definition.has("owner") or lineup.has(definition["owner"]):
			draw.append(instance.duplicate(true))
	var enemy: Dictionary = enemy_defs[enemy_id].duplicate(true)
	var instance_number := int(run_state.get("next_battle_instance", 1))
	var instance_id := "%s:%s:%d" % [str(run_state["id"]), battle_id, instance_number]
	var state := {
		"id": battle_id,
		"instance_id": instance_id,
		"seed": battle_seed,
		"initial_seed": battle_seed,
		"turn": 0,
		"phase": "between",
		"result": "ongoing",
		"accounts": run_state["accounts"].duplicate(true),
		"enemy": enemy,
		"hp": int(enemy["hp"]),
		"actors": actors,
		"draw": draw,
		"hand": [],
		"discard": [],
		"consumed": [],
		"sealed": [],
		"intents": [],
		"total_cards": draw.size(),
		"log": []
	}
	_shuffle(state, state["draw"])
	run_state["battles"][battle_id] = {
		"instance_id": instance_id,
		"seed": battle_seed,
		"settled": false,
		"result": "ongoing"
	}
	run_state["next_battle_instance"] = instance_number + 1
	run_state["started"] = true
	return state

func begin_turn(state: Dictionary) -> Dictionary:
	if state.get("phase") != "between" or state.get("result") != "ongoing":
		return _failure("invalid_begin")
	state["turn"] = int(state["turn"]) + 1
	state["phase"] = "player"
	for actor_value in state["actors"]:
		var actor: Dictionary = actor_value
		actor["acted"] = false
		actor["basic_attack_used"] = false
		actor["basic_guard_used"] = false
		actor["shield"] = 0
		actor["protected"] = []
	var pattern: Array = state["enemy"]["pattern"]
	var pattern_row: Array = pattern[(int(state["turn"]) - 1) % pattern.size()]
	var amounts: Array = pattern_row.duplicate()
	var first_positive := -1
	for index in amounts.size():
		if int(amounts[index]) > 0:
			first_positive = index
			break
	if first_positive >= 0:
		amounts[first_positive] = int(amounts[first_positive]) + int(floor(float(int(state["turn"]) - 1) / 4.0))
	var target_id := _rotating_online_target(state)
	state["intents"] = []
	if target_id != "":
		for raw_value in amounts:
			var raw := int(raw_value)
			if raw > 0:
				state["intents"].append({"target": target_id, "raw": raw})
	_draw_to_five(state)
	return {"ok": true, "intents": state["intents"].duplicate(true)}

func preview_action(state: Dictionary, actor_id: String, action_id: String, target_id: String = "") -> Dictionary:
	var validation := _validate_action(state, actor_id, action_id, target_id)
	if not validation["ok"]:
		return validation
	var actor: Dictionary = validation["actor"]
	var definition: Dictionary = validation["definition"]
	var damage := int(definition.get("damage", 0))
	if actor_id == "GPT" and not validation["basic"] and definition.get("kind") == "attack":
		damage += int(actor["streak"]) * 2
		if int(actor["streak"]) == 2:
			damage += int(definition.get("fullStreakBonus", 0))
	if actor_id == "Claude" and definition.get("kind") == "attack" and bool(actor["counter"]):
		damage += 4
	if actor_id == "DeepSeek" and not validation["basic"] and definition.get("kind") == "attack":
		if definition.get("cashRice", false):
			damage += int(actor["rice"]) * 2
		elif int(definition.get("cost", 0)) >= 2 and int(actor["rice"]) == 3:
			damage += 6
	var resolved_target := str(validation["target_id"])
	var target_label := str(state["enemy"]["name"]) if definition.get("kind") == "attack" else resolved_target
	return {
		"ok": true,
		"actor": actor_id,
		"action_id": action_id,
		"name": str(validation["name"]),
		"target_id": resolved_target,
		"target": target_label,
		"cost": int(definition.get("cost", 0)),
		"balance_after": int(state["accounts"][actor_id]["token"]) - int(definition.get("cost", 0)),
		"damage": damage,
		"shield": int(definition.get("shield", 0)),
		"heal": int(definition.get("heal", 0)),
		"rice_gain": int(definition.get("riceGain", 0)),
		"consume": bool(definition.get("consume", false)),
		"basic": bool(validation["basic"]),
		"definition": definition,
		"card": validation.get("card", {})
	}

func try_action(state: Dictionary, actor_id: String, action_id: String, target_id: String = "") -> Dictionary:
	var preview := preview_action(state, actor_id, action_id, target_id)
	if not preview["ok"]:
		return preview
	var actor: Dictionary = _find_actor(state, actor_id)
	var definition: Dictionary = preview["definition"]
	var resolved_target := str(preview["target_id"])
	var target: Dictionary = _find_actor(state, resolved_target)

	# Every rejection happens before this point. Mutation begins here.
	if actor_id == "GPT":
		if not preview["basic"] and definition.get("kind") == "attack":
			actor["streak"] = mini(2, int(actor["streak"]) + 1)
		else:
			actor["streak"] = 0
	if actor_id == "Claude" and definition.get("kind") == "attack" and bool(actor["counter"]):
		actor["counter"] = false
	if actor_id == "DeepSeek" and not preview["basic"] and definition.get("kind") == "attack":
		if definition.get("cashRice", false) or (int(definition.get("cost", 0)) >= 2 and int(actor["rice"]) == 3):
			actor["rice"] = 0

	state["accounts"][actor_id]["token"] = int(state["accounts"][actor_id]["token"]) - int(preview["cost"])
	if int(preview["heal"]) > 0:
		state["accounts"][resolved_target]["token"] = mini(
			int(state["accounts"][resolved_target]["max"]),
			int(state["accounts"][resolved_target]["token"]) + int(preview["heal"])
		)
	if int(preview["shield"]) > 0:
		target["shield"] = int(target["shield"]) + int(preview["shield"])
		actor["protected"].append(resolved_target)
	if int(preview["rice_gain"]) > 0:
		actor["rice"] = mini(3, int(actor["rice"]) + int(preview["rice_gain"]))
	if int(preview["damage"]) > 0:
		state["hp"] = maxi(0, int(state["hp"]) - int(preview["damage"]))
	if not preview["basic"]:
		_move_hand_card(state, action_id, "consumed" if preview["consume"] else "discard")
	if preview["basic"]:
		if action_id == BASIC_ATTACK:
			actor["basic_attack_used"] = true
		else:
			actor["basic_guard_used"] = true
	actor["acted"] = true
	if int(state["hp"]) == 0:
		state["result"] = "win"
	return preview

func finish_turn(state: Dictionary) -> Dictionary:
	if state.get("phase") != "player":
		return _failure("invalid_finish")
	state["phase"] = "enemy"
	var events: Array = []
	if state["result"] == "ongoing":
		for intent_value in state["intents"]:
			var intent: Dictionary = intent_value
			events.append(resolve_hit(state, str(intent["target"]), int(intent["raw"])))
			if state["result"] != "ongoing":
				break
	for actor_value in state["actors"]:
		var actor: Dictionary = actor_value
		if actor["id"] == "GPT" and not bool(actor["acted"]):
			actor["streak"] = 0
		if state["result"] == "ongoing" and bool(actor["online"]):
			if actor["id"] == "Claude":
				for event_value in events:
					var event: Dictionary = event_value
					if actor["protected"].has(event["target"]) and int(event["absorbed"]) > 0:
						actor["counter"] = true
						break
			if actor["id"] == "DeepSeek":
				actor["rice"] = mini(3, int(actor["rice"]) + 1)
		actor["shield"] = 0
	while not state["hand"].is_empty():
		state["discard"].append(state["hand"].pop_front())
	state["phase"] = "between"
	state["log"].append({
		"turn": state["turn"], "enemy_hp": state["hp"],
		"balances": state["accounts"].duplicate(true),
		"events": events.duplicate(true), "result": state["result"]
	})
	return {"ok": true, "events": events, "result": state["result"]}

func resolve_hit(state: Dictionary, target_id: String, raw: int) -> Dictionary:
	var actor := _find_actor(state, target_id)
	if actor.is_empty() or not bool(actor["online"]):
		return {"target": target_id, "absorbed": 0, "lost": 0, "skipped": true}
	var absorbed := mini(raw, int(actor["shield"]))
	actor["shield"] = int(actor["shield"]) - absorbed
	var lost := mini(int(state["accounts"][target_id]["token"]), raw - absorbed)
	state["accounts"][target_id]["token"] = int(state["accounts"][target_id]["token"]) - lost
	if int(state["accounts"][target_id]["token"]) == 0:
		actor["online"] = false
		actor["shield"] = 0
		actor["streak"] = 0
		actor["counter"] = false
		actor["rice"] = 0
		actor["protected"] = []
		_seal_owned_cards(state, target_id)
		var any_online := false
		for candidate_value in state["actors"]:
			if bool(candidate_value["online"]):
				any_online = true
				break
		if not any_online:
			state["result"] = "loss"
	return {"target": target_id, "absorbed": absorbed, "lost": lost, "skipped": false}

func settle_battle(run_state: Dictionary, state: Dictionary) -> Dictionary:
	if state.get("result") == "ongoing":
		return _failure("unfinished")
	if run_state["nodes"].has(state["id"]):
		if run_state["nodes"][state["id"]] != state["result"]:
			return _failure("conflicting_result")
		return {"ok": true, "duplicate": true}
	if run_state.get("ended", false):
		return _failure("run_ended")
	var battle_id := str(state.get("id", ""))
	var registered_battles: Dictionary = run_state.get("battles", {})
	if not registered_battles.has(battle_id):
		return _failure("battle_not_registered")
	var registration: Dictionary = registered_battles[battle_id]
	if str(registration.get("instance_id", "")) != str(state.get("instance_id", "")):
		return _failure("battle_instance_mismatch")
	run_state["accounts"] = state["accounts"].duplicate(true)
	run_state["nodes"][battle_id] = state["result"]
	registration["settled"] = true
	registration["result"] = state["result"]
	if state["result"] == "win":
		var recovery := int(data["parameters"]["winRecovery"])
		for account_value in run_state["accounts"].values():
			if int(account_value["token"]) > 0:
				account_value["token"] = mini(int(account_value["max"]), int(account_value["token"]) + recovery)
		run_state["wallet"] = int(run_state["wallet"]) + int(data["parameters"]["bossReward"] if state["enemy"].get("boss", false) else data["parameters"]["ordinaryReward"])
	else:
		run_state["ended"] = true
	return {"ok": true, "duplicate": false}

func rest_recover(run_state: Dictionary, node_id: String, target_id: String) -> Dictionary:
	if run_state.get("ended", false):
		return _failure("run_ended")
	if run_state["services"].has(node_id):
		return _failure("service_used")
	if not run_state["accounts"].has(target_id):
		return _failure("bad_target")
	var account: Dictionary = run_state["accounts"][target_id]
	if int(account["token"]) == int(account["max"]):
		return _failure("no_heal")
	account["token"] = mini(int(account["max"]), int(account["token"]) + int(data["parameters"]["restRecovery"]))
	run_state["services"][node_id] = "rest"
	return {"ok": true, "token": account["token"]}

func card_name(code: String) -> String:
	return str(card_defs.get(code, {}).get("name", code))

func actor_status(state: Dictionary, role_id: String) -> Dictionary:
	return _find_actor(state, role_id)

func resolved_card(instance: Dictionary) -> Dictionary:
	return _resolved_card(instance)

func legal_targets(state: Dictionary, actor_id: String, action_id: String) -> Array:
	var targets: Array = []
	for actor_value in state.get("actors", []):
		var target_id := str(actor_value.get("id", ""))
		if preview_action(state, actor_id, action_id, target_id).get("ok", false):
			targets.append(target_id)
	return targets

func basic_used(state: Dictionary, actor_id: String, action_id: String) -> bool:
	var actor := _find_actor(state, actor_id)
	if actor.is_empty():
		return false
	if action_id == BASIC_ATTACK:
		return bool(actor.get("basic_attack_used", false))
	if action_id == BASIC_GUARD:
		return bool(actor.get("basic_guard_used", false))
	return false

func has_legal_action(state: Dictionary, actor_id: String) -> bool:
	var actor := _find_actor(state, actor_id)
	if actor.is_empty() or not bool(actor.get("online", false)):
		return false
	if state.get("phase") != "player" or state.get("result") != "ongoing":
		return false
	if not basic_used(state, actor_id, BASIC_ATTACK) and not legal_targets(state, actor_id, BASIC_ATTACK).is_empty():
		return true
	if not basic_used(state, actor_id, BASIC_GUARD) and not legal_targets(state, actor_id, BASIC_GUARD).is_empty():
		return true
	for instance_value in state.get("hand", []):
		if not legal_targets(state, actor_id, str(instance_value["uid"])).is_empty():
			return true
	return false

func _validate_action(state: Dictionary, actor_id: String, action_id: String, target_id: String) -> Dictionary:
	var actor := _find_actor(state, actor_id)
	if state.get("phase") != "player" or state.get("result") != "ongoing" or actor.is_empty() or not bool(actor.get("online", false)):
		return _failure("action_unavailable")
	var basic := action_id == BASIC_ATTACK or action_id == BASIC_GUARD
	var card: Dictionary = {}
	var definition: Dictionary
	var action_name: String
	if basic:
		if action_id == BASIC_ATTACK:
			if bool(actor.get("basic_attack_used", false)):
				return _failure("basic_used")
			definition = {"kind": "attack", "cost": 0, "damage": int(data["parameters"]["basicAttack"])}
			action_name = "基础攻击"
		else:
			if bool(actor.get("basic_guard_used", false)):
				return _failure("basic_used")
			definition = {"kind": "guard", "cost": 0, "shield": int(data["parameters"]["basicGuard"]), "target": "self"}
			action_name = "基础防御"
	else:
		card = _find_hand_card(state, action_id)
		if card.is_empty():
			return _failure("not_in_hand")
		definition = _resolved_card(card)
		action_name = str(definition["name"])
	if definition.has("owner") and definition["owner"] != actor_id:
		return _failure("wrong_owner")
	var resolved_target := actor_id if target_id == "" else target_id
	var target := _find_actor(state, resolved_target)
	if target.is_empty() or not bool(target["online"]):
		return _failure("offline_target")
	if (definition.get("target") == "self" or definition.get("kind") == "attack") and resolved_target != actor_id:
		return _failure("self_only")
	if definition.get("kind") == "transfer":
		if resolved_target == actor_id or int(state["accounts"][resolved_target]["max"]) - int(state["accounts"][resolved_target]["token"]) < 2:
			return _failure("bad_transfer")
	if definition.get("kind") == "heal" and int(state["accounts"][resolved_target]["token"]) == int(state["accounts"][resolved_target]["max"]):
		return _failure("no_heal")
	var cost := int(definition.get("cost", 0))
	if int(state["accounts"][actor_id]["token"]) - cost < 1:
		return _failure("personal_payment")
	return {"ok": true, "actor": actor, "definition": definition, "name": action_name, "target_id": resolved_target, "basic": basic, "card": card}

func _resolved_card(instance: Dictionary) -> Dictionary:
	var definition: Dictionary = card_defs[instance["code"]].duplicate(true)
	if instance.get("upgraded", false):
		for key in definition.get("upgrade", {}).keys():
			definition[key] = int(definition.get(key, 0)) + int(definition["upgrade"][key])
	return definition

func _find_actor(state: Dictionary, actor_id: String) -> Dictionary:
	for actor_value in state.get("actors", []):
		if actor_value["id"] == actor_id:
			return actor_value
	return {}

func _find_hand_card(state: Dictionary, uid: String) -> Dictionary:
	for instance_value in state.get("hand", []):
		if instance_value["uid"] == uid:
			return instance_value
	return {}

func _move_hand_card(state: Dictionary, uid: String, destination: String) -> void:
	for index in state["hand"].size():
		if state["hand"][index]["uid"] == uid:
			state[destination].append(state["hand"].pop_at(index))
			return

func _seal_owned_cards(state: Dictionary, owner_id: String) -> void:
	for zone_name in ["draw", "hand", "discard"]:
		var keep: Array = []
		for instance_value in state[zone_name]:
			var definition: Dictionary = card_defs[instance_value["code"]]
			if definition.get("owner", "") == owner_id:
				state["sealed"].append(instance_value)
			else:
				keep.append(instance_value)
		state[zone_name] = keep

func _draw_to_five(state: Dictionary) -> void:
	while state["hand"].size() < int(data["parameters"]["draw"]):
		if state["draw"].is_empty():
			while not state["discard"].is_empty():
				state["draw"].append(state["discard"].pop_front())
			_shuffle(state, state["draw"])
		if state["draw"].is_empty():
			break
		state["hand"].append(state["draw"].pop_front())

func _rotating_online_target(state: Dictionary) -> String:
	if state["actors"].is_empty():
		return ""
	var offset: int = (int(state["turn"]) - 1) % state["actors"].size()
	for step in state["actors"].size():
		var actor: Dictionary = state["actors"][(offset + step) % state["actors"].size()]
		if bool(actor["online"]):
			return str(actor["id"])
	return ""

func _next_random(state: Dictionary) -> float:
	var x := int(state["seed"]) & 0xffffffff
	if x == 0:
		x = 1
	x = (x ^ ((x << 13) & 0xffffffff)) & 0xffffffff
	x = (x ^ (x >> 17)) & 0xffffffff
	x = (x ^ ((x << 5) & 0xffffffff)) & 0xffffffff
	state["seed"] = x
	return float(x) / 4294967296.0

func _shuffle(state: Dictionary, cards: Array) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := int(floor(_next_random(state) * float(index + 1)))
		var temporary = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = temporary

func _failure(code: String) -> Dictionary:
	return {"ok": false, "error": code}
