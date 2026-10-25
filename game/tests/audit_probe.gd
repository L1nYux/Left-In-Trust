extends SceneTree

# 边界探针（审计用，不改动既有实现）。
# 直接调用 res://scripts/game_rules.gd 的真实实现，按 A–L 十二组跑状态机/数值边界断言。
# 输出格式：[AUDIT] <ID>|<PASS/FAIL>|<前置状态>|<操作>|<预期>|<实际>
# 失败不中断，全部跑完再汇总；预期与实际逐字符对比，不同即 FAIL。

const ContentDBScript = preload("res://scripts/content_db.gd")
const RulesScript = preload("res://scripts/game_rules.gd")
const BASIC_ATTACK := "basic_attack"
const BASIC_GUARD := "basic_guard"
const ZONES := ["draw", "hand", "discard", "consumed", "sealed"]

var rules
var pass_count := 0
var fail_count := 0
var inject_counter := 0
var key_values := {}

func _init() -> void:
	var content: Dictionary = ContentDBScript.load_content()
	if content.is_empty():
		push_error("[AUDIT] content missing")
		quit(1)
		return
	rules = RulesScript.new(content)
	_group_a()
	_group_b()
	_group_c()
	_group_d()
	_group_e()
	_group_f()
	_group_g()
	_group_h()
	_group_i()
	_group_j()
	_group_k()
	_group_l()
	var total := pass_count + fail_count
	print("[AUDIT] KEYVALS|%s" % JSON.stringify(key_values))
	if fail_count == 0:
		print("[AUDIT] PASS %d/%d" % [pass_count, total])
	else:
		print("[AUDIT] FAIL %d/%d" % [fail_count, total])
	quit(0 if fail_count == 0 else 1)

# ---------------------------------------------------------------- 基础工具

func _r(id: String, pre: String, op: String, expected: String, actual: String) -> void:
	var ok := expected == actual
	if ok:
		pass_count += 1
	else:
		fail_count += 1
	print("[AUDIT] %s|%s|%s|%s|%s|%s" % [id, "PASS" if ok else "FAIL", pre, op, expected, actual])

func _kv(pairs: Array) -> String:
	var parts: Array = []
	var index := 0
	while index + 1 < pairs.size():
		parts.append("%s=%s" % [str(pairs[index]), str(pairs[index + 1])])
		index += 2
	return " ".join(parts)

func _snapshot(state: Dictionary) -> String:
	return JSON.stringify(state)

func _err(result: Dictionary) -> String:
	return "" if bool(result.get("ok", false)) else str(result.get("error", "?"))

func _battle(roles: Array, lineup: Array, enemy_id: String = "missing_attachment", seed: int = 7, extras: Array = [], upgrades: Array = []) -> Dictionary:
	var run_state: Dictionary
	if roles.size() == 1:
		run_state = rules.make_run(str(roles[0]), seed)
	else:
		run_state = rules.make_run_for_roles(roles, seed)
	for code in upgrades:
		for instance in run_state["deck"]:
			if str(instance["code"]) == str(code):
				instance["upgraded"] = true
	for extra in extras:
		run_state["deck"].append(extra)
	var state: Dictionary = rules.start_battle(run_state, "probe", lineup, enemy_id, seed)
	return {"run": run_state, "state": state}

func _extra(code: String, upgraded: bool = false) -> Dictionary:
	inject_counter += 1
	return {"uid": "x%03d-%s" % [inject_counter, code], "code": code, "upgraded": upgraded}

func _inject(state: Dictionary, code: String, upgraded: bool = false) -> String:
	inject_counter += 1
	var uid := "inj%03d-%s" % [inject_counter, code]
	state["hand"].append({"uid": uid, "code": code, "upgraded": upgraded})
	state["total_cards"] = int(state["total_cards"]) + 1
	return uid

func _force_card(state: Dictionary, code: String, upgraded: bool = false) -> String:
	for zone_name in ["hand", "draw", "discard"]:
		for index in state[zone_name].size():
			var instance: Dictionary = state[zone_name][index]
			if str(instance["code"]) == code and bool(instance.get("upgraded", false)) == upgraded:
				if zone_name != "hand":
					state[zone_name].remove_at(index)
					state["hand"].append(instance)
				return str(instance["uid"])
	return _inject(state, code, upgraded)

func _move_to_zone(state: Dictionary, uid: String, target: String) -> void:
	for zone_name in ZONES:
		for index in state[zone_name].size():
			if str(state[zone_name][index]["uid"]) == uid:
				var instance: Dictionary = state[zone_name][index]
				state[zone_name].remove_at(index)
				state[target].append(instance)
				return

func _uid_list(state: Dictionary) -> Array:
	var uids: Array = []
	for zone_name in ZONES:
		for instance in state[zone_name]:
			uids.append(str(instance["uid"]))
	return uids

func _conservation(state: Dictionary) -> Dictionary:
	var uids := _uid_list(state)
	var seen := {}
	for uid in uids:
		seen[uid] = true
	return {"sum": uids.size(), "total": int(state["total_cards"]), "unique": seen.size()}

func _conservation_ok(state: Dictionary) -> bool:
	var ctt := _conservation(state)
	return int(ctt["sum"]) == int(ctt["total"]) and int(ctt["unique"]) == int(ctt["sum"])

func _conservation_text(state: Dictionary) -> String:
	var ctt := _conservation(state)
	return _kv(["sum", ctt["sum"], "total", ctt["total"], "unique", ctt["unique"]])

func _codes_in_zones(state: Dictionary, wanted: Array) -> int:
	var count := 0
	for zone_name in ["draw", "hand", "discard"]:
		for instance in state[zone_name]:
			if wanted.has(str(instance["code"])):
				count += 1
	return count

func _hand_owned_count(state: Dictionary, wanted: Array) -> int:
	var count := 0
	for instance in state["hand"]:
		if wanted.has(str(instance["code"])):
			count += 1
	return count

func _pick_attack(state: Dictionary, role_id: String) -> String:
	var best := BASIC_ATTACK
	var best_damage := 0
	for instance in state["hand"]:
		var preview: Dictionary = rules.preview_action(state, role_id, str(instance["uid"]), role_id)
		if not bool(preview.get("ok", false)):
			continue
		var definition: Dictionary = preview.get("definition", {})
		if str(definition.get("kind", "")) != "attack":
			continue
		if int(preview.get("damage", 0)) > best_damage:
			best_damage = int(preview["damage"])
			best = str(instance["uid"])
	return best

func _pick_passive(state: Dictionary, role_id: String) -> String:
	for instance in state["hand"]:
		var preview: Dictionary = rules.preview_action(state, role_id, str(instance["uid"]), role_id)
		if bool(preview.get("ok", false)) and int(preview.get("damage", 0)) == 0:
			return str(instance["uid"])
	return BASIC_GUARD

func _has_attack_card(state: Dictionary, role_id: String) -> bool:
	for instance in state["hand"]:
		var preview: Dictionary = rules.preview_action(state, role_id, str(instance["uid"]), role_id)
		if not bool(preview.get("ok", false)):
			continue
		var definition: Dictionary = preview.get("definition", {})
		if str(definition.get("kind", "")) == "attack":
			return true
	return false

# ---------------------------------------------------------------- A 非法操作原子性

func _group_a() -> void:
	# A01 已行动后再次行动
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", 11)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	rules.try_action(st, "GPT", BASIC_ATTACK, "GPT")
	var snap := _snapshot(st)
	var res: Dictionary = rules.try_action(st, "GPT", BASIC_GUARD, "GPT")
	_r("A01", "单人 GPT，本回合已行动", "再次执行基础防御", "err=action_unavailable state_same=true",
		_kv(["err", _err(res), "state_same", _snapshot(st) == snap]))

	# A02 非本人专属牌
	var b2 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 12)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	st2["intents"] = []
	var g1_uid := _force_card(st2, "G1")
	var snap2 := _snapshot(st2)
	var res2: Dictionary = rules.try_action(st2, "Claude", g1_uid, "Claude")
	_r("A02", "双人战，GPT 专属牌 G1 在 Claude 手牌", "Claude 打出 G1", "err=wrong_owner state_same=true",
		_kv(["err", _err(res2), "state_same", _snapshot(st2) == snap2]))

	# A03 牌不在手
	var b3 := _battle(["GPT"], ["GPT"], "missing_attachment", 13)
	var st3: Dictionary = b3["state"]
	rules.begin_turn(st3)
	st3["intents"] = []
	var draw_uid := ""
	if not st3["draw"].is_empty():
		draw_uid = str(st3["draw"][0]["uid"])
	var snap3 := _snapshot(st3)
	var res3: Dictionary = rules.try_action(st3, "GPT", draw_uid, "GPT")
	_r("A03", "抽牌堆中的牌 uid 不在手牌", "用抽牌堆 uid 出牌", "err=not_in_hand state_same=true",
		_kv(["err", _err(res3), "state_same", _snapshot(st3) == snap3]))

	# A04 目标下线
	var b4 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 14)
	var st4: Dictionary = b4["state"]
	rules.begin_turn(st4)
	st4["intents"] = []
	var d_uid := _force_card(st4, "D")
	st4["accounts"]["Claude"]["token"] = 1
	rules.resolve_hit(st4, "Claude", 1)
	var snap4 := _snapshot(st4)
	var res4: Dictionary = rules.try_action(st4, "GPT", d_uid, "Claude")
	_r("A04", "Claude 已下线（token=0）", "GPT 用 D 指定 Claude 为目标", "err=offline_target state_same=true",
		_kv(["err", _err(res4), "state_same", _snapshot(st4) == snap4]))

	# A05 攻击卡改目标
	var b5 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 15)
	var st5: Dictionary = b5["state"]
	rules.begin_turn(st5)
	st5["intents"] = []
	var a_uid := _force_card(st5, "A")
	var snap5 := _snapshot(st5)
	var res5: Dictionary = rules.try_action(st5, "GPT", a_uid, "Claude")
	_r("A05", "双人在线", "GPT 用攻击卡 A 指定 Claude 为目标", "err=self_only state_same=true",
		_kv(["err", _err(res5), "state_same", _snapshot(st5) == snap5]))

	# A06 满血用 R
	var b6 := _battle(["GPT"], ["GPT"], "missing_attachment", 16)
	var st6: Dictionary = b6["state"]
	rules.begin_turn(st6)
	st6["intents"] = []
	var r_uid := _force_card(st6, "R")
	var snap6 := _snapshot(st6)
	var res6: Dictionary = rules.try_action(st6, "GPT", r_uid, "GPT")
	_r("A06", "GPT token 满 12 上限", "对自己使用 R（回复 2）", "err=no_heal state_same=true",
		_kv(["err", _err(res6), "state_same", _snapshot(st6) == snap6]))

	# A07 T 缺口 < 2
	var b7 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 17)
	var st7: Dictionary = b7["state"]
	rules.begin_turn(st7)
	st7["intents"] = []
	var t_uid := _force_card(st7, "T")
	st7["accounts"]["Claude"]["token"] = 11
	var snap7 := _snapshot(st7)
	var res7: Dictionary = rules.try_action(st7, "GPT", t_uid, "Claude")
	_r("A07", "Claude token=11（缺口 1）", "GPT 用 T 转交给 Claude", "err=bad_transfer state_same=true",
		_kv(["err", _err(res7), "state_same", _snapshot(st7) == snap7]))

	# A08 token 不足
	var b8 := _battle(["GPT"], ["GPT"], "missing_attachment", 18)
	var st8: Dictionary = b8["state"]
	rules.begin_turn(st8)
	st8["intents"] = []
	var a8_uid := _force_card(st8, "A")
	st8["accounts"]["GPT"]["token"] = 1
	var snap8 := _snapshot(st8)
	var res8: Dictionary = rules.try_action(st8, "GPT", a8_uid, "GPT")
	_r("A08", "GPT token=1", "打出 A（费用 1，支付后不足 1）", "err=personal_payment state_same=true",
		_kv(["err", _err(res8), "state_same", _snapshot(st8) == snap8]))

	# A09 phase=between（begin 之前）
	var b9 := _battle(["GPT"], ["GPT"], "missing_attachment", 19)
	var st9: Dictionary = b9["state"]
	var snap9 := _snapshot(st9)
	var res9: Dictionary = rules.try_action(st9, "GPT", BASIC_ATTACK, "GPT")
	_r("A09", "start_battle 之后、begin_turn 之前（phase=between）", "执行基础攻击", "err=action_unavailable state_same=true",
		_kv(["err", _err(res9), "state_same", _snapshot(st9) == snap9]))

	# A10 phase=enemy
	var b10 := _battle(["GPT"], ["GPT"], "missing_attachment", 20)
	var st10: Dictionary = b10["state"]
	rules.begin_turn(st10)
	st10["phase"] = "enemy"
	var snap10 := _snapshot(st10)
	var res10: Dictionary = rules.try_action(st10, "GPT", BASIC_ATTACK, "GPT")
	_r("A10", "phase 手工置为 enemy", "执行基础攻击", "err=action_unavailable state_same=true",
		_kv(["err", _err(res10), "state_same", _snapshot(st10) == snap10]))

	# A11 result=win
	var b11 := _battle(["GPT"], ["GPT"], "missing_attachment", 21)
	var st11: Dictionary = b11["state"]
	rules.begin_turn(st11)
	st11["result"] = "win"
	var snap11 := _snapshot(st11)
	var res11: Dictionary = rules.try_action(st11, "GPT", BASIC_ATTACK, "GPT")
	_r("A11", "result 手工置为 win", "执行基础攻击", "err=action_unavailable state_same=true",
		_kv(["err", _err(res11), "state_same", _snapshot(st11) == snap11]))

	# A12 result=loss
	var b12 := _battle(["GPT"], ["GPT"], "missing_attachment", 22)
	var st12: Dictionary = b12["state"]
	rules.begin_turn(st12)
	st12["result"] = "loss"
	var snap12 := _snapshot(st12)
	var res12: Dictionary = rules.try_action(st12, "GPT", BASIC_ATTACK, "GPT")
	_r("A12", "result 手工置为 loss", "执行基础攻击", "err=action_unavailable state_same=true",
		_kv(["err", _err(res12), "state_same", _snapshot(st12) == snap12]))

	# A13 重复 finish_turn
	var b13 := _battle(["GPT"], ["GPT"], "missing_attachment", 23)
	var st13: Dictionary = b13["state"]
	rules.begin_turn(st13)
	st13["intents"] = []
	rules.finish_turn(st13)
	var snap13 := _snapshot(st13)
	var res13: Dictionary = rules.finish_turn(st13)
	_r("A13", "已 finish_turn，phase=between", "再次 finish_turn", "err=invalid_finish state_same=true",
		_kv(["err", _err(res13), "state_same", _snapshot(st13) == snap13]))

	key_values["A"] = {"rows": 13, "atomicity_violations": fail_count}

# ---------------------------------------------------------------- B 支付保留 1

func _group_b() -> void:
	# B01 cost1@token1
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", 31)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	var a_uid := _force_card(st, "A")
	st["accounts"]["GPT"]["token"] = 1
	var snap := _snapshot(st)
	var res: Dictionary = rules.try_action(st, "GPT", a_uid, "GPT")
	_r("B01", "GPT token=1，A 在手", "打出 A（费用 1）", "err=personal_payment state_same=true",
		_kv(["err", _err(res), "state_same", _snapshot(st) == snap]))

	# B02 cost1@token2 接受
	var b2 := _battle(["GPT"], ["GPT"], "missing_attachment", 32)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	st2["intents"] = []
	var a2_uid := _force_card(st2, "A")
	st2["accounts"]["GPT"]["token"] = 2
	var res2: Dictionary = rules.try_action(st2, "GPT", a2_uid, "GPT")
	_r("B02", "GPT token=2，A 在手", "打出 A（费用 1）", "ok=true token=1 damage=6 discard=1",
		_kv(["ok", bool(res2.get("ok", false)), "token", st2["accounts"]["GPT"]["token"], "damage", res2.get("damage", -1), "discard", st2["discard"].size()]))

	# B03 cost2@token2 拒绝
	var b3 := _battle(["GPT"], ["GPT"], "missing_attachment", 33)
	var st3: Dictionary = b3["state"]
	rules.begin_turn(st3)
	st3["intents"] = []
	var h3_uid := _force_card(st3, "H")
	st3["accounts"]["GPT"]["token"] = 2
	var snap3 := _snapshot(st3)
	var res3: Dictionary = rules.try_action(st3, "GPT", h3_uid, "GPT")
	_r("B03", "GPT token=2，H 在手", "打出 H（费用 2）", "err=personal_payment state_same=true",
		_kv(["err", _err(res3), "state_same", _snapshot(st3) == snap3]))

	# B04 cost2@token3 接受
	var b4 := _battle(["GPT"], ["GPT"], "missing_attachment", 34)
	var st4: Dictionary = b4["state"]
	rules.begin_turn(st4)
	st4["intents"] = []
	var h4_uid := _force_card(st4, "H")
	st4["accounts"]["GPT"]["token"] = 3
	var res4: Dictionary = rules.try_action(st4, "GPT", h4_uid, "GPT")
	_r("B04", "GPT token=3，H 在手", "打出 H（费用 2）", "ok=true token=1 damage=10 discard=1",
		_kv(["ok", bool(res4.get("ok", false)), "token", st4["accounts"]["GPT"]["token"], "damage", res4.get("damage", -1), "discard", st4["discard"].size()]))

	# B05 cost0@token1 接受
	var b5 := _battle(["GPT"], ["GPT"], "missing_attachment", 35)
	var st5: Dictionary = b5["state"]
	rules.begin_turn(st5)
	st5["intents"] = []
	var d5_uid := _force_card(st5, "D")
	st5["accounts"]["GPT"]["token"] = 1
	var res5: Dictionary = rules.try_action(st5, "GPT", d5_uid, "GPT")
	_r("B05", "GPT token=1，D 在手", "打出 D（费用 0）", "ok=true token=1 shield=4 discard=1",
		_kv(["ok", bool(res5.get("ok", false)), "token", st5["accounts"]["GPT"]["token"], "shield", int(rules.actor_status(st5, "GPT")["shield"]), "discard", st5["discard"].size()]))

	# B06 被拒无副作用（GPT 连击/行动/手牌/弃牌不变）
	var b6 := _battle(["GPT"], ["GPT"], "missing_attachment", 36)
	var st6: Dictionary = b6["state"]
	rules.begin_turn(st6)
	st6["intents"] = []
	var g1_uid := _force_card(st6, "G1")
	rules.try_action(st6, "GPT", g1_uid, "GPT")
	rules.finish_turn(st6)
	rules.begin_turn(st6)
	st6["intents"] = []
	var a6_uid := _force_card(st6, "A")
	st6["accounts"]["GPT"]["token"] = 1
	var snap6 := _snapshot(st6)
	var res6: Dictionary = rules.try_action(st6, "GPT", a6_uid, "GPT")
	var actor6: Dictionary = rules.actor_status(st6, "GPT")
	_r("B06", "GPT 上回合打出 G1 已积 1 层连击，本回合 token=1", "打出 A（被拒）", "err=personal_payment state_same=true streak=1 acted=false",
		_kv(["err", _err(res6), "state_same", _snapshot(st6) == snap6, "streak", int(actor6["streak"]), "acted", bool(actor6["acted"])]))

	# B07 T 因支付被拒（缺口合法）
	var b7 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 37)
	var st7: Dictionary = b7["state"]
	rules.begin_turn(st7)
	st7["intents"] = []
	var t7_uid := _force_card(st7, "T")
	st7["accounts"]["GPT"]["token"] = 2
	st7["accounts"]["Claude"]["token"] = 9
	var snap7 := _snapshot(st7)
	var res7: Dictionary = rules.try_action(st7, "GPT", t7_uid, "Claude")
	_r("B07", "GPT token=2，Claude 缺口 3（目标合法）", "打出 T（费用 2）", "err=personal_payment state_same=true",
		_kv(["err", _err(res7), "state_same", _snapshot(st7) == snap7]))

	key_values["B"] = {"token_1_cost_1": "rejected", "token_2_cost_1": "1", "token_2_cost_2": "rejected", "token_3_cost_2": "1"}

# ---------------------------------------------------------------- C 多段攻击与目标下线

func _group_c() -> void:
	# C01 防护 5 对 3+3
	var b := _battle(["Claude", "GPT"], ["Claude", "GPT"], "missing_attachment", 41)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	var c1_uid := _force_card(st, "C1")
	rules.try_action(st, "Claude", c1_uid, "GPT")
	var hit1: Dictionary = rules.resolve_hit(st, "GPT", 3)
	var hit2: Dictionary = rules.resolve_hit(st, "GPT", 3)
	var gpt: Dictionary = rules.actor_status(st, "GPT")
	_r("C01", "Claude 用 C1 给 GPT 防护 5", "依次对 GPT 结算 3、3 两段", "absorbed1=3 absorbed2=2 lost2=1 token=11 shield=0",
		_kv(["absorbed1", hit1["absorbed"], "absorbed2", hit2["absorbed"], "lost2", hit2["lost"], "token", st["accounts"]["GPT"]["token"], "shield", int(gpt["shield"])]))

	# C02 锁定目标下线后剩余段跳过、不转火
	var b2 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 42)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	st2["intents"] = []
	st2["accounts"]["GPT"]["token"] = 1
	rules.resolve_hit(st2, "GPT", 1)
	var skipped: Dictionary = rules.resolve_hit(st2, "GPT", 99)
	_r("C02", "GPT 被第一段打到 0 下线，Claude 仍在线", "对已下线的 GPT 再结算 99", "skipped=true absorbed=0 lost=0 claude=12",
		_kv(["skipped", bool(skipped["skipped"]), "absorbed", skipped["absorbed"], "lost", skipped["lost"], "claude", st2["accounts"]["Claude"]["token"]]))

	# C03 敌方多段意图：GPT 第一段下线，第二段空过
	var b3 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "duplicate", 43)
	var st3: Dictionary = b3["state"]
	rules.begin_turn(st3)
	st3["accounts"]["GPT"]["token"] = 1
	var fin3: Dictionary = rules.finish_turn(st3)
	var events3: Array = fin3["events"]
	var seg2_skipped := false
	if events3.size() > 1:
		seg2_skipped = bool(events3[1]["skipped"])
	_r("C03", "重复条目首回合意图 1+1 指向 GPT，GPT token=1", "finish_turn 结算敌方两段", "events=2 seg2_skipped=true claude=12 result=ongoing",
		_kv(["events", events3.size(), "seg2_skipped", seg2_skipped, "claude", st3["accounts"]["Claude"]["token"], "result", str(st3["result"])]))

	# C04 第一段被防护吸收并触发反击，第三段因目标下线跳过
	var b4 := _battle(["Claude", "GPT"], ["Claude", "GPT"], "missing_attachment", 44)
	var st4: Dictionary = b4["state"]
	rules.begin_turn(st4)
	st4["intents"] = []
	var c4_uid := _force_card(st4, "C1")
	rules.try_action(st4, "Claude", c4_uid, "GPT")
	st4["accounts"]["GPT"]["token"] = 1
	st4["intents"] = [{"target": "GPT", "raw": 3}, {"target": "GPT", "raw": 3}, {"target": "GPT", "raw": 3}]
	var fin4: Dictionary = rules.finish_turn(st4)
	var events4: Array = fin4["events"]
	var seg3_skipped := false
	if events4.size() > 2:
		seg3_skipped = bool(events4[2]["skipped"])
	_r("C04", "Claude 给 GPT 防护 5，GPT token=1，三段 3", "finish_turn 结算三段", "events=3 seg3_skipped=true counter=true",
		_kv(["events", events4.size(), "seg3_skipped", seg3_skipped, "counter", bool(rules.actor_status(st4, "Claude")["counter"])]))

	key_values["C"] = {"shield5_vs_3_3": "absorbed 3+2, lost 1", "offline_redirect": false}

# ---------------------------------------------------------------- D 击杀停手

func _group_d() -> void:
	# D01 击杀立即 win
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", 51)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	st["hp"] = 3
	var a_uid := _force_card(st, "A")
	rules.try_action(st, "GPT", a_uid, "GPT")
	_r("D01", "敌方 HP=3，A 在手", "打出 A（伤害 6）", "hp=0 result=win",
		_kv(["hp", st["hp"], "result", str(st["result"])]))

	# D02 击杀动作仍扣费/弃牌/标行动
	var b2 := _battle(["GPT"], ["GPT"], "missing_attachment", 52)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	st2["intents"] = []
	st2["hp"] = 3
	var a2_uid := _force_card(st2, "A")
	rules.try_action(st2, "GPT", a2_uid, "GPT")
	var discard_has := false
	for instance in st2["discard"]:
		if str(instance["uid"]) == a2_uid:
			discard_has = true
	_r("D02", "同上，击杀动作自身结算", "检查 token/弃牌/行动标记", "token=11 discard_has=true acted=true hand=4",
		_kv(["token", st2["accounts"]["GPT"]["token"], "discard_has", discard_has, "acted", bool(rules.actor_status(st2, "GPT")["acted"]), "hand", st2["hand"].size()]))

	# D03 击杀后敌方意图不结算
	var b3 := _battle(["GPT"], ["GPT"], "missing_attachment", 53)
	var st3: Dictionary = b3["state"]
	rules.begin_turn(st3)
	st3["hp"] = 3
	st3["intents"] = [{"target": "GPT", "raw": 99}]
	var a3_uid := _force_card(st3, "A")
	rules.try_action(st3, "GPT", a3_uid, "GPT")
	var token_before: int = st3["accounts"]["GPT"]["token"]
	rules.finish_turn(st3)
	_r("D03", "击杀当回合敌方意图 99 已预告", "finish_turn", "token=11 result=win",
		_kv(["token", st3["accounts"]["GPT"]["token"], "result", str(st3["result"])]))

	# D04 击杀回合不产白饭
	var b4 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 54)
	var st4: Dictionary = b4["state"]
	rules.begin_turn(st4)
	st4["intents"] = []
	var ds: Dictionary = rules.actor_status(st4, "DeepSeek")
	ds["rice"] = 1
	st4["hp"] = 3
	var s2_uid := _force_card(st4, "S2")
	var res4: Dictionary = rules.try_action(st4, "DeepSeek", s2_uid, "DeepSeek")
	rules.finish_turn(st4)
	_r("D04", "DeepSeek 白饭 1 层、敌方 HP=3", "S2 击杀后 finish_turn", "damage=10 result=win rice=0 token=10",
		_kv(["damage", res4.get("damage", -1), "result", str(st4["result"]), "rice", int(ds["rice"]), "token", st4["accounts"]["DeepSeek"]["token"]]))

	# D05 击杀回合不产反击
	var b5 := _battle(["Claude"], ["Claude"], "missing_attachment", 55)
	var st5: Dictionary = b5["state"]
	rules.begin_turn(st5)
	st5["intents"] = [{"target": "Claude", "raw": 2}]
	st5["hp"] = 3
	var c2_uid := _force_card(st5, "C2")
	rules.try_action(st5, "Claude", c2_uid, "Claude")
	rules.finish_turn(st5)
	_r("D05", "Claude 用 C2（自带防护 2）击杀，敌方意图 2 已预告", "finish_turn", "result=win counter=false token=11",
		_kv(["result", str(st5["result"]), "counter", bool(rules.actor_status(st5, "Claude")["counter"]), "token", st5["accounts"]["Claude"]["token"]]))

	# D06 击杀后行动/回合被拒
	var b6 := _battle(["GPT"], ["GPT"], "missing_attachment", 56)
	var st6: Dictionary = b6["state"]
	rules.begin_turn(st6)
	st6["intents"] = []
	st6["hp"] = 3
	var a6_uid := _force_card(st6, "A")
	rules.try_action(st6, "GPT", a6_uid, "GPT")
	var act_res: Dictionary = rules.try_action(st6, "GPT", BASIC_GUARD, "GPT")
	var begin_res: Dictionary = rules.begin_turn(st6)
	_r("D06", "已击杀（result=win）", "再尝试行动与 begin_turn", "err=action_unavailable begin=invalid_begin",
		_kv(["err", _err(act_res), "begin", _err(begin_res)]))

	# D07 基础攻击击杀
	var b7 := _battle(["GPT"], ["GPT"], "missing_attachment", 57)
	var st7: Dictionary = b7["state"]
	rules.begin_turn(st7)
	st7["intents"] = []
	st7["hp"] = 3
	var res7: Dictionary = rules.try_action(st7, "GPT", BASIC_ATTACK, "GPT")
	_r("D07", "敌方 HP=3", "基础攻击（伤害 3）", "result=win hp=0 token=12 discard=0 acted=true",
		_kv(["result", str(st7["result"]), "hp", st7["hp"], "token", st7["accounts"]["GPT"]["token"], "discard", st7["discard"].size(), "acted", bool(rules.actor_status(st7, "GPT")["acted"])]))

	key_values["D"] = {"kill_immediate_win": true, "intents_skipped": true, "rice_on_kill_turn": 0, "counter_on_kill_turn": false}

# ---------------------------------------------------------------- E 牌实体守恒

func _group_e() -> void:
	# E01 整场逐步守恒
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", 61)
	var st: Dictionary = b["state"]
	var all_ok := true
	var steps := 0
	for turn_index in range(1, 13):
		if str(st["result"]) != "ongoing":
			break
		rules.begin_turn(st)
		all_ok = all_ok and _conservation_ok(st)
		steps += 1
		var action_id := _pick_attack(st, "GPT")
		if not _has_attack_card(st, "GPT"):
			action_id = _pick_passive(st, "GPT")
		rules.try_action(st, "GPT", action_id, "GPT")
		all_ok = all_ok and _conservation_ok(st)
		steps += 1
		rules.finish_turn(st)
		all_ok = all_ok and _conservation_ok(st)
		steps += 1
	_r("E01", "单人 GPT，逐回合「有攻击牌则打最高伤害，否则防守」", "每步检查五区总数与 uid 唯一性", "ok=true result=win " + _conservation_text(st),
		_kv(["ok", all_ok, "result", str(st["result"])]) + " " + _conservation_text(st))

	# E02 R 进 consumed
	var b2 := _battle(["GPT"], ["GPT"], "missing_attachment", 62)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	st2["intents"] = []
	var r_uid := _force_card(st2, "R")
	st2["accounts"]["GPT"]["token"] = 11
	var res2: Dictionary = rules.try_action(st2, "GPT", r_uid, "GPT")
	var consumed_has := false
	for instance in st2["consumed"]:
		if str(instance["uid"]) == r_uid:
			consumed_has = true
	var discard_has := false
	for instance in st2["discard"]:
		if str(instance["uid"]) == r_uid:
			discard_has = true
	_r("E02", "GPT token=11，R 在手", "使用 R（回复后 token 截断到 12）", "ok=true token=12 consumed=1 consumed_has=true discard_has=false " + _conservation_text(st2),
		_kv(["ok", bool(res2.get("ok", false)), "token", st2["accounts"]["GPT"]["token"], "consumed", st2["consumed"].size(), "consumed_has", consumed_has, "discard_has", discard_has]) + " " + _conservation_text(st2))

	# E03 洗回
	var b3 := _battle(["GPT"], ["GPT"], "missing_attachment", 63)
	var st3: Dictionary = b3["state"]
	var refill := false
	var discard_at_refill := -1
	var hand_at_refill := -1
	for turn_index in range(1, 4):
		var pre_discard: int = st3["discard"].size()
		rules.begin_turn(st3)
		if pre_discard > 0 and st3["discard"].size() == 0:
			refill = true
			discard_at_refill = st3["discard"].size()
			hand_at_refill = st3["hand"].size()
		var action_id := _pick_passive(st3, "GPT")
		rules.try_action(st3, "GPT", action_id, "GPT")
		rules.finish_turn(st3)
	_r("E03", "单人 GPT，前三回合只防守（不打伤害）", "第三回合验证抽牌堆空后洗回弃牌堆", "refill=true discard=0 hand=5 " + _conservation_text(st3),
		_kv(["refill", refill, "discard", discard_at_refill, "hand", hand_at_refill]) + " " + _conservation_text(st3))

	# E04 已消耗牌不再被抽到
	var b4 := _battle(["GPT"], ["GPT"], "missing_attachment", 64)
	var st4: Dictionary = b4["state"]
	rules.begin_turn(st4)
	st4["intents"] = []
	var r4_uid := _force_card(st4, "R")
	st4["accounts"]["GPT"]["token"] = 11
	rules.try_action(st4, "GPT", r4_uid, "GPT")
	rules.finish_turn(st4)
	for turn_index in range(1, 3):
		rules.begin_turn(st4)
		var action_id := _pick_passive(st4, "GPT")
		rules.try_action(st4, "GPT", action_id, "GPT")
		rules.finish_turn(st4)
	var r_absent := true
	for zone_name in ["draw", "hand", "discard"]:
		for instance in st4[zone_name]:
			if str(instance["uid"]) == r4_uid:
				r_absent = false
	_r("E04", "R 已在上一回合被消耗（consumed）", "再走两回合检查 R 不再出现", "r_absent=true turns=2 " + _conservation_text(st4),
		_kv(["r_absent", r_absent, "turns", 2]) + " " + _conservation_text(st4))

	# E05 开局五区分布
	var b5 := _battle(["GPT"], ["GPT"], "missing_attachment", 65)
	var st5: Dictionary = b5["state"]
	rules.begin_turn(st5)
	_r("E05", "开局完成后", "检查 draw/hand/discard 与总牌数", "draw=7 hand=5 " + _conservation_text(st5),
		_kv(["draw", st5["draw"].size(), "hand", st5["hand"].size()]) + " " + _conservation_text(st5))

	key_values["E"] = {"E01_steps": steps, "conservation": "12/12/12", "refill_turn": 3, "consumed_R": 1}

# ---------------------------------------------------------------- F 下线封存

func _group_f() -> void:
	var b := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 71)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	var g1_uid := _force_card(st, "G1")
	var g2_uid := _force_card(st, "G2")
	_move_to_zone(st, g2_uid, "discard")
	for instance in st["hand"]:
		if str(instance["code"]) == "G1" and str(instance["uid"]) != g1_uid:
			_move_to_zone(st, str(instance["uid"]), "draw")
			break
	st["accounts"]["GPT"]["token"] = 1
	rules.resolve_hit(st, "GPT", 1)

	var sealed_codes: Array = []
	for instance in st["sealed"]:
		sealed_codes.append(str(instance["code"]))
	sealed_codes.sort()
	var sealed_csv := ""
	for code in sealed_codes:
		sealed_csv += ("-" if sealed_csv != "" else "") + str(code)
	var owned_in_zones := _codes_in_zones(st, ["G1", "G2"])
	_r("F01", "双人战，GPT 的 G1 在手牌、G2 在弃牌堆、另一张 G1 在抽牌堆；GPT token=1", "结算 1 点伤害使 GPT 下线", "sealed=3 sealed_codes=G1-G1-G2 zones_has_owned=false",
		_kv(["sealed", st["sealed"].size(), "sealed_codes", sealed_csv, "zones_has_owned", owned_in_zones > 0]))

	var generic_count := 0
	for zone_name in ["draw", "hand", "discard"]:
		for instance in st[zone_name]:
			if ["A", "D", "H", "R"].has(str(instance["code"])):
				generic_count += 1
	var claude_cards := _codes_in_zones(st, ["C1", "C2"])
	var sealed_generic := _codes_in_zones({"draw": st["sealed"], "hand": [], "discard": []}, ["A", "D", "H", "R"])
	_r("F02", "同上封存完成", "统计通用牌与 Claude 专属牌的所在区域", "generic=18 claude_cards=3 sealed_generic=0",
		_kv(["generic", generic_count, "claude_cards", claude_cards, "sealed_generic", sealed_generic]))

	rules.finish_turn(st)
	var owned_in_hand := 0
	for turn_index in range(1, 3):
		if turn_index > 1:
			rules.finish_turn(st)
		var begin_res: Dictionary = rules.begin_turn(st)
		owned_in_hand += _hand_owned_count(st, ["G1", "G2"])
		_r("F0%d" % (2 + turn_index), "GPT 已下线且专属牌全部封存", "开始第 %d 个新回合检查手牌" % turn_index,
			"begin_ok=true hand_owned=0 " + _conservation_text(st),
			_kv(["begin_ok", bool(begin_res.get("ok", false)), "hand_owned", _hand_owned_count(st, ["G1", "G2"])]) + " " + _conservation_text(st))

	# F05 另一角色可继续行动并正常结算
	var claude1 := _force_card(st, "C1")
	var act: Dictionary = rules.try_action(st, "Claude", claude1, "Claude")
	var fin: Dictionary = rules.finish_turn(st)
	var begin2: Dictionary = rules.begin_turn(st)
	_r("F05", "GPT 下线后仍处 player 阶段", "Claude 打出 C1，随后 finish/begin", "claude_ok=true finish_ok=true begin_ok=true result=ongoing",
		_kv(["claude_ok", bool(act.get("ok", false)), "finish_ok", bool(fin.get("ok", false)), "begin_ok", bool(begin2.get("ok", false)), "result", str(st["result"])]))

	key_values["F"] = {"sealed_gpt_cards": 3, "generic_remaining": 18, "sealed_never_drawn": true}

# ---------------------------------------------------------------- G 战后恢复

func _settle_token_case(token_before: int, seed: int) -> Dictionary:
	var run_state: Dictionary = rules.make_run("GPT", seed)
	var state: Dictionary = rules.start_battle(run_state, "probe", ["GPT"], "missing_attachment", seed)
	state["accounts"]["GPT"]["token"] = token_before
	state["result"] = "win"
	var settle: Dictionary = rules.settle_battle(run_state, state)
	return {"run": run_state, "state": state, "settle": settle}

func _group_g() -> void:
	var cases := [[0, 0], [1, 4], [10, 12], [11, 12], [12, 12]]
	var case_index := 0
	for case_value in cases:
		var before: int = case_value[0]
		var after: int = case_value[1]
		var result := _settle_token_case(before, 81 + case_index)
		var run_state: Dictionary = result["run"]
		_r("G0%d" % (case_index + 1), "战斗胜利时 GPT token=%d（上限 12）" % before, "settle_battle", "token=%d" % after,
			_kv(["token", int(run_state["accounts"]["GPT"]["token"])]))
		case_index += 1

	# G06 替补也 +3
	var run6: Dictionary = rules.make_run_for_roles(["GPT", "Claude"], 86)
	run6["accounts"]["GPT"]["token"] = 5
	run6["accounts"]["Claude"]["token"] = 5
	var st6: Dictionary = rules.start_battle(run6, "probe", ["GPT"], "missing_attachment", 86)
	st6["result"] = "win"
	rules.settle_battle(run6, st6)
	_r("G06", "双人 run，仅 GPT 上场；GPT 与替补 Claude token 均为 5", "settle_battle 胜利", "gpt=8 claude=8",
		_kv(["gpt", int(run6["accounts"]["GPT"]["token"]), "claude", int(run6["accounts"]["Claude"]["token"])]))

	# G07 二次结算不重复发奖
	var c7 := _settle_token_case(5, 87)
	var run7: Dictionary = c7["run"]
	var st7: Dictionary = c7["state"]
	var token7: int = int(run7["accounts"]["GPT"]["token"])
	var wallet7: int = int(run7["wallet"])
	var again: Dictionary = rules.settle_battle(run7, st7)
	_r("G07", "同一战斗已结算胜利", "再次 settle_battle", "duplicate=true token=8 wallet=4",
		_kv(["duplicate", bool(again.get("duplicate", false)), "token", int(run7["accounts"]["GPT"]["token"]), "wallet", int(run7["wallet"])]))

	# G08 冲突结果被拒
	var c8 := _settle_token_case(5, 88)
	var run8: Dictionary = c8["run"]
	var st8: Dictionary = c8["state"]
	var cloned: Dictionary = st8.duplicate(true)
	cloned["result"] = "loss"
	var res8: Dictionary = rules.settle_battle(run8, cloned)
	_r("G08", "同一 node 已结算 win", "再对同一 node 结算 loss", "err=conflicting_result node=win token=8",
		_kv(["err", _err(res8), "node", str(run8["nodes"].get("probe", "?")), "token", int(run8["accounts"]["GPT"]["token"])]))

	# G09 失败结束 run 且不能开战
	var run9: Dictionary = rules.make_run("GPT", 89)
	var st9: Dictionary = rules.start_battle(run9, "probe", ["GPT"], "missing_attachment", 89)
	st9["result"] = "loss"
	rules.settle_battle(run9, st9)
	var restart9: Dictionary = rules.start_battle(run9, "probe2", ["GPT"], "missing_attachment", 89)
	_r("G09", "战斗结果 loss 并已结算", "尝试开启新战斗", "ended=true restart_err=run_or_node_finished",
		_kv(["ended", bool(run9["ended"]), "restart_err", _err(restart9)]))

	# G10 算力奖励
	var run10: Dictionary = rules.make_run("GPT", 90)
	var st10: Dictionary = rules.start_battle(run10, "probe", ["GPT"], "missing_attachment", 90)
	st10["result"] = "win"
	rules.settle_battle(run10, st10)
	var ordinary_wallet: int = int(run10["wallet"])
	var run10b: Dictionary = rules.make_run("GPT", 91)
	var st10b: Dictionary = rules.start_battle(run10b, "probe", ["GPT"], "submit", 91)
	st10b["result"] = "win"
	rules.settle_battle(run10b, st10b)
	_r("G10", "普通战「缺失附件」与 Boss 战「本次提交版」各胜利结算一次", "比较 wallet", "ordinary=4 boss=8",
		_kv(["ordinary", ordinary_wallet, "boss", int(run10b["wallet"])]))

	# G11 未完成战斗拒绝结算
	var run11: Dictionary = rules.make_run("GPT", 92)
	var st11: Dictionary = rules.start_battle(run11, "probe", ["GPT"], "missing_attachment", 92)
	var res11: Dictionary = rules.settle_battle(run11, st11)
	_r("G11", "战斗 result 仍为 ongoing", "settle_battle", "err=unfinished nodes=0",
		_kv(["err", _err(res11), "nodes", run11["nodes"].size()]))

	key_values["G"] = {"settle_tokens": "0->0,1->4,10->12,11->12,12->12", "bench_plus3": true, "wallet_ordinary": 4, "wallet_boss": 8}

# ---------------------------------------------------------------- H GPT 连击

func _group_h() -> void:
	# H01-H05 自然两回合叠连击
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", 101)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	var g1_uid := _force_card(st, "G1")
	var act1: Dictionary = rules.try_action(st, "GPT", g1_uid, "GPT")
	var actor: Dictionary = rules.actor_status(st, "GPT")
	_r("H01", "GPT 首回合，streak=0", "打出 G1", "damage=5 streak=1",
		_kv(["damage", act1.get("damage", -1), "streak", int(actor["streak"])]))
	rules.finish_turn(st)
	_r("H02", "GPT 本回合已行动（攻击）", "finish_turn 后检查连击", "streak_after_finish=1",
		_kv(["streak_after_finish", int(actor["streak"])]))
	rules.begin_turn(st)
	st["intents"] = []
	var g1b := _force_card(st, "G1")
	var act2: Dictionary = rules.try_action(st, "GPT", g1b, "GPT")
	_r("H03", "第二回合开始，streak 跨回合仍为 1", "打出 G1", "damage=7 streak=2",
		_kv(["damage", act2.get("damage", -1), "streak", int(actor["streak"])]))
	rules.finish_turn(st)
	rules.begin_turn(st)
	st["intents"] = []
	var g2_uid := _force_card(st, "G2")
	var act3: Dictionary = rules.try_action(st, "GPT", g2_uid, "GPT")
	_r("H04", "第三回合开始，streak=2", "打出 G2（满层）", "damage=16 streak=2",
		_kv(["damage", act3.get("damage", -1), "streak", int(actor["streak"])]))

	# H05 升级 G2 满层
	var b5 := _battle(["GPT"], ["GPT"], "missing_attachment", 102, [], ["G2"])
	var st5: Dictionary = b5["state"]
	rules.begin_turn(st5)
	st5["intents"] = []
	var g5a := _force_card(st5, "G1")
	rules.try_action(st5, "GPT", g5a, "GPT")
	rules.finish_turn(st5)
	rules.begin_turn(st5)
	st5["intents"] = []
	var g5b := _force_card(st5, "G1")
	rules.try_action(st5, "GPT", g5b, "GPT")
	rules.finish_turn(st5)
	rules.begin_turn(st5)
	st5["intents"] = []
	var g5c := _force_card(st5, "G2", true)
	var act5: Dictionary = rules.try_action(st5, "GPT", g5c, "GPT")
	_r("H05", "G2 已升级，streak=2", "打出升级 G2", "damage=18 streak=2",
		_kv(["damage", act5.get("damage", -1), "streak", int(rules.actor_status(st5, "GPT")["streak"])]))

	# H06 G2 在 streak=0 时读加层前状态
	var b6 := _battle(["GPT"], ["GPT"], "missing_attachment", 103)
	var st6: Dictionary = b6["state"]
	rules.begin_turn(st6)
	st6["intents"] = []
	var g6 := _force_card(st6, "G2")
	var act6: Dictionary = rules.try_action(st6, "GPT", g6, "GPT")
	_r("H06", "GPT streak=0", "打出 G2（验证读取加层前状态）", "damage=10 streak=1",
		_kv(["damage", act6.get("damage", -1), "streak", int(rules.actor_status(st6, "GPT")["streak"])]))

	# H07 G2 在 streak=1 时读加层前状态
	var b7 := _battle(["GPT"], ["GPT"], "missing_attachment", 104)
	var st7: Dictionary = b7["state"]
	rules.begin_turn(st7)
	st7["intents"] = []
	var g7a := _force_card(st7, "G1")
	rules.try_action(st7, "GPT", g7a, "GPT")
	rules.finish_turn(st7)
	rules.begin_turn(st7)
	st7["intents"] = []
	var g7b := _force_card(st7, "G2")
	var act7: Dictionary = rules.try_action(st7, "GPT", g7b, "GPT")
	_r("H07", "GPT streak=1", "打出 G2（满层加成本段不应生效）", "damage=12 streak=2",
		_kv(["damage", act7.get("damage", -1), "streak", int(rules.actor_status(st7, "GPT")["streak"])]))

	# H08 基础攻击断连击
	var b8 := _battle(["GPT"], ["GPT"], "missing_attachment", 105)
	var st8: Dictionary = b8["state"]
	rules.begin_turn(st8)
	st8["intents"] = []
	rules.try_action(st8, "GPT", _force_card(st8, "G1"), "GPT")
	rules.finish_turn(st8)
	rules.begin_turn(st8)
	st8["intents"] = []
	var act8: Dictionary = rules.try_action(st8, "GPT", BASIC_ATTACK, "GPT")
	_r("H08", "GPT streak=1", "基础攻击", "damage=3 streak=0",
		_kv(["damage", act8.get("damage", -1), "streak", int(rules.actor_status(st8, "GPT")["streak"])]))

	# H09 基础防御断连击
	var b9 := _battle(["GPT"], ["GPT"], "missing_attachment", 106)
	var st9: Dictionary = b9["state"]
	rules.begin_turn(st9)
	st9["intents"] = []
	rules.try_action(st9, "GPT", _force_card(st9, "G1"), "GPT")
	rules.finish_turn(st9)
	rules.begin_turn(st9)
	st9["intents"] = []
	rules.try_action(st9, "GPT", BASIC_GUARD, "GPT")
	_r("H09", "GPT streak=1", "基础防御", "shield=3 streak=0",
		_kv(["shield", int(rules.actor_status(st9, "GPT")["shield"]), "streak", int(rules.actor_status(st9, "GPT")["streak"])]))

	# H10 非攻击牌断连击
	var b10 := _battle(["GPT"], ["GPT"], "missing_attachment", 107)
	var st10: Dictionary = b10["state"]
	rules.begin_turn(st10)
	st10["intents"] = []
	rules.try_action(st10, "GPT", _force_card(st10, "G1"), "GPT")
	rules.finish_turn(st10)
	rules.begin_turn(st10)
	st10["intents"] = []
	rules.try_action(st10, "GPT", _force_card(st10, "D"), "GPT")
	_r("H10", "GPT streak=1", "打出非攻击牌 D", "shield=4 streak=0",
		_kv(["shield", int(rules.actor_status(st10, "GPT")["shield"]), "streak", int(rules.actor_status(st10, "GPT")["streak"])]))

	# H11 跳过断连击
	var b11 := _battle(["GPT"], ["GPT"], "missing_attachment", 108)
	var st11: Dictionary = b11["state"]
	rules.begin_turn(st11)
	st11["intents"] = []
	rules.try_action(st11, "GPT", _force_card(st11, "G1"), "GPT")
	rules.finish_turn(st11)
	rules.begin_turn(st11)
	st11["intents"] = []
	rules.finish_turn(st11)
	_r("H11", "GPT streak=1", "本回合跳过（不行动）直接 finish_turn", "streak=0",
		_kv(["streak", int(rules.actor_status(st11, "GPT")["streak"])]))

	# H12 streak 上限 2，第三张攻击仍是 5+4
	var b12 := _battle(["GPT"], ["GPT"], "missing_attachment", 109)
	var st12: Dictionary = b12["state"]
	rules.begin_turn(st12)
	st12["intents"] = []
	rules.try_action(st12, "GPT", _force_card(st12, "G1"), "GPT")
	rules.finish_turn(st12)
	rules.begin_turn(st12)
	st12["intents"] = []
	rules.try_action(st12, "GPT", _force_card(st12, "G1"), "GPT")
	rules.finish_turn(st12)
	rules.begin_turn(st12)
	st12["intents"] = []
	var act12: Dictionary = rules.try_action(st12, "GPT", _force_card(st12, "G1"), "GPT")
	_r("H12", "GPT streak 已到上限 2", "再打 G1（从上回合弃牌堆取回）", "damage=9 streak=2",
		_kv(["damage", act12.get("damage", -1), "streak", int(rules.actor_status(st12, "GPT")["streak"])]))

	# H13 streak 2 时通用攻击 A 也吃满层
	var b13 := _battle(["GPT"], ["GPT"], "missing_attachment", 110)
	var st13: Dictionary = b13["state"]
	rules.begin_turn(st13)
	st13["intents"] = []
	rules.try_action(st13, "GPT", _force_card(st13, "G1"), "GPT")
	rules.finish_turn(st13)
	rules.begin_turn(st13)
	st13["intents"] = []
	rules.try_action(st13, "GPT", _force_card(st13, "G1"), "GPT")
	rules.finish_turn(st13)
	rules.begin_turn(st13)
	st13["intents"] = []
	var act13: Dictionary = rules.try_action(st13, "GPT", _force_card(st13, "A"), "GPT")
	_r("H13", "GPT streak=2", "打出通用攻击 A", "damage=10 streak=2",
		_kv(["damage", act13.get("damage", -1), "streak", int(rules.actor_status(st13, "GPT")["streak"])]))

	key_values["H"] = {"g1_5_7": true, "g2_full": 16, "g2_full_upgraded": 18, "g2_at_streak1": 12, "basic_break": true, "cap": 2}

# ---------------------------------------------------------------- I Claude 反击

func _arm_counter(seed: int) -> Dictionary:
	var b := _battle(["Claude"], ["Claude"], "missing_attachment", seed)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	var c1_uid := _force_card(st, "C1")
	rules.try_action(st, "Claude", c1_uid, "Claude")
	st["intents"] = [{"target": "Claude", "raw": 2}]
	var fin: Dictionary = rules.finish_turn(st)
	return {"battle": b, "state": st, "finish": fin}

func _group_i() -> void:
	# I01 保护对象实际挡伤且自己在线 -> 就绪
	var armed := _arm_counter(121)
	var st: Dictionary = armed["state"]
	var events: Array = armed["finish"]["events"]
	var absorbed := 0
	if not events.is_empty():
		absorbed = int(events[0]["absorbed"])
	_r("I01", "Claude 用 C1 给自己防护 5，敌方 2 点攻击实际挡伤", "finish_turn", "counter=true absorbed=2",
		_kv(["counter", bool(rules.actor_status(st, "Claude")["counter"]), "absorbed", absorbed]))

	# I02 只保护未挡伤
	var b2 := _battle(["Claude", "GPT"], ["Claude", "GPT"], "missing_attachment", 122)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	var c12 := _force_card(st2, "C1")
	rules.try_action(st2, "Claude", c12, "GPT")
	st2["intents"] = [{"target": "Claude", "raw": 2}]
	rules.finish_turn(st2)
	_r("I02", "Claude 给 GPT 防护 5，但敌方打的是 Claude（未挡伤）", "finish_turn", "counter=false",
		_kv(["counter", bool(rules.actor_status(st2, "Claude")["counter"])]))

	# I03 完全未防护
	var b3 := _battle(["Claude"], ["Claude"], "missing_attachment", 123)
	var st3: Dictionary = b3["state"]
	rules.begin_turn(st3)
	st3["intents"] = [{"target": "Claude", "raw": 2}]
	rules.finish_turn(st3)
	_r("I03", "Claude 本回合未提供任何防护", "finish_turn", "counter=false",
		_kv(["counter", bool(rules.actor_status(st3, "Claude")["counter"])]))

	# I04 反击 +4 用于基础攻击
	var a4 := _arm_counter(124)
	var st4: Dictionary = a4["state"]
	rules.begin_turn(st4)
	st4["intents"] = []
	var act4: Dictionary = rules.try_action(st4, "Claude", BASIC_ATTACK, "Claude")
	_r("I04", "Claude 反击就绪", "基础攻击（基础 3 + 4）", "damage=7 counter_after=false",
		_kv(["damage", act4.get("damage", -1), "counter_after", bool(rules.actor_status(st4, "Claude")["counter"])]))

	# I05 反击 +4 用于 C2
	var a5 := _arm_counter(125)
	var st5: Dictionary = a5["state"]
	rules.begin_turn(st5)
	st5["intents"] = []
	var c2_uid := _force_card(st5, "C2")
	var act5: Dictionary = rules.try_action(st5, "Claude", c2_uid, "Claude")
	_r("I05", "Claude 反击就绪", "打出 C2（5 + 4）", "damage=9 counter_after=false",
		_kv(["damage", act5.get("damage", -1), "counter_after", bool(rules.actor_status(st5, "Claude")["counter"])]))

	# I06 反击 +4 用于 V
	var a6 := _arm_counter(126)
	var st6: Dictionary = a6["state"]
	rules.begin_turn(st6)
	st6["intents"] = []
	var v_uid := _force_card(st6, "V")
	var act6: Dictionary = rules.try_action(st6, "Claude", v_uid, "Claude")
	_r("I06", "Claude 反击就绪", "打出 V（4 + 4）", "damage=8 counter_after=false",
		_kv(["damage", act6.get("damage", -1), "counter_after", bool(rules.actor_status(st6, "Claude")["counter"])]))

	# I07 只兑现一次
	var a7 := _arm_counter(127)
	var st7: Dictionary = a7["state"]
	rules.begin_turn(st7)
	st7["intents"] = []
	var first7: Dictionary = rules.try_action(st7, "Claude", BASIC_ATTACK, "Claude")
	rules.finish_turn(st7)
	rules.begin_turn(st7)
	st7["intents"] = []
	var second7: Dictionary = rules.try_action(st7, "Claude", BASIC_ATTACK, "Claude")
	_r("I07", "反击已获得，已用于第一次攻击", "连续两回合基础攻击", "first=7 second=3",
		_kv(["first", first7.get("damage", -1), "second", second7.get("damage", -1)]))

	# I08 未兑现跨回合保留
	var a8 := _arm_counter(128)
	var st8: Dictionary = a8["state"]
	rules.begin_turn(st8)
	st8["intents"] = []
	var c18 := _force_card(st8, "C1")
	rules.try_action(st8, "Claude", c18, "Claude")
	var after_guard := bool(rules.actor_status(st8, "Claude")["counter"])
	rules.finish_turn(st8)
	var after_finish := bool(rules.actor_status(st8, "Claude")["counter"])
	rules.begin_turn(st8)
	st8["intents"] = []
	var act8: Dictionary = rules.try_action(st8, "Claude", BASIC_ATTACK, "Claude")
	_r("I08", "反击就绪后当回合只用非攻击牌 C1", "检查反击是否保留并在下回合兑现", "after_guard=true after_finish=true damage=7",
		_kv(["after_guard", after_guard, "after_finish", after_finish, "damage", act8.get("damage", -1)]))

	# I09 再次获得不叠加
	var a9 := _arm_counter(129)
	var st9: Dictionary = a9["state"]
	rules.begin_turn(st9)
	st9["intents"] = []
	var c19 := _force_card(st9, "C1")
	rules.try_action(st9, "Claude", c19, "Claude")
	st9["intents"] = [{"target": "Claude", "raw": 2}]
	rules.finish_turn(st9)
	var rearmed := bool(rules.actor_status(st9, "Claude")["counter"])
	rules.begin_turn(st9)
	st9["intents"] = []
	var act9: Dictionary = rules.try_action(st9, "Claude", BASIC_ATTACK, "Claude")
	_r("I09", "反击已就绪时再次满足就绪条件", "下一次基础攻击只应 +4 一次", "counter=true damage=7 counter_after=false",
		_kv(["counter", rearmed, "damage", act9.get("damage", -1), "counter_after", bool(rules.actor_status(st9, "Claude")["counter"])]))

	# I10 下线清空
	var a10 := _arm_counter(130)
	var st10: Dictionary = a10["state"]
	st10["accounts"]["Claude"]["token"] = 1
	rules.resolve_hit(st10, "Claude", 1)
	_r("I10", "Claude 反击就绪后 token=1", "结算 1 点伤害使其下线", "counter=false online=false",
		_kv(["counter", bool(rules.actor_status(st10, "Claude")["counter"]), "online", bool(rules.actor_status(st10, "Claude")["online"])]))

	key_values["I"] = {"counter_basic": 7, "counter_C2": 9, "counter_V": 8, "once_only": true, "persist": true, "offline_clear": true}

# ---------------------------------------------------------------- J DeepSeek 白饭

func _s2_case(seed: int, layer: int, upgraded: bool) -> Dictionary:
	var upgrades: Array = []
	if upgraded:
		upgrades.append("S2")
	var b := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", seed, [], upgrades)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	var ds: Dictionary = rules.actor_status(st, "DeepSeek")
	ds["rice"] = layer
	var uid := _force_card(st, "S2", upgraded)
	var res: Dictionary = rules.try_action(st, "DeepSeek", uid, "DeepSeek")
	return {"damage": int(res.get("damage", -1)), "rice": int(ds["rice"]), "ok": bool(res.get("ok", false))}

func _group_j() -> void:
	# J01 回合末 +1
	var b := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 141)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	rules.finish_turn(st)
	_r("J01", "DeepSeek 在线、白饭 0 层", "finish_turn", "rice=1",
		_kv(["rice", int(rules.actor_status(st, "DeepSeek")["rice"])]))

	# J02 上限 3
	var b2 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 142)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	st2["intents"] = []
	rules.actor_status(st2, "DeepSeek")["rice"] = 3
	rules.finish_turn(st2)
	_r("J02", "白饭已 3 层", "finish_turn", "rice=3",
		_kv(["rice", int(rules.actor_status(st2, "DeepSeek")["rice"])]))

	# J03 S1 行动时 +1 当回合生效
	var b3 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 143)
	var st3: Dictionary = b3["state"]
	rules.begin_turn(st3)
	st3["intents"] = []
	var s1_uid := _force_card(st3, "S1")
	rules.try_action(st3, "DeepSeek", s1_uid, "DeepSeek")
	_r("J03", "白饭 0 层", "打出 S1（riceGain=1）", "rice=1 shield=4",
		_kv(["rice", int(rules.actor_status(st3, "DeepSeek")["rice"]), "shield", int(rules.actor_status(st3, "DeepSeek")["shield"])]))

	# J04-J07 S2 层数 0/1/2/3
	var layers := [0, 1, 2, 3]
	var layer_index := 0
	for layer in layers:
		var case_result := _s2_case(150 + layer_index, layer, false)
		var expected_damage: int = 8 + 2 * int(layer)
		_r("J0%d" % (4 + layer_index), "DeepSeek 白饭 %d 层，S2 在手" % layer, "打出 S2", "damage=%d rice=0" % expected_damage,
			_kv(["damage", case_result["damage"], "rice", case_result["rice"]]))
		layer_index += 1

	# J08 升级 S2
	var upgraded_layers := [0, 1, 2, 3]
	var upgraded_index := 0
	for layer in upgraded_layers:
		var case_result := _s2_case(160 + upgraded_index, layer, true)
		var expected_damage: int = 10 + 2 * int(layer)
		_r("J08%s" % ["a", "b", "c", "d"][upgraded_index], "升级 S2，白饭 %d 层" % layer, "打出升级 S2", "damage=%d rice=0" % expected_damage,
			_kv(["damage", case_result["damage"], "rice", case_result["rice"]]))
		upgraded_index += 1

	# J09 H 满层 +6 并清空
	var b9 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 171)
	var st9: Dictionary = b9["state"]
	rules.begin_turn(st9)
	st9["intents"] = []
	rules.actor_status(st9, "DeepSeek")["rice"] = 3
	var h_uid := _force_card(st9, "H")
	var act9: Dictionary = rules.try_action(st9, "DeepSeek", h_uid, "DeepSeek")
	_r("J09", "白饭 3 层，H 在手", "打出 H（费用 2，满层 +6）", "damage=16 rice=0",
		_kv(["damage", act9.get("damage", -1), "rice", int(rules.actor_status(st9, "DeepSeek")["rice"])]))

	# J10 A(cost1) 满层无加成不清空
	var b10 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 172)
	var st10: Dictionary = b10["state"]
	rules.begin_turn(st10)
	st10["intents"] = []
	rules.actor_status(st10, "DeepSeek")["rice"] = 3
	var a_uid := _force_card(st10, "A")
	var act10: Dictionary = rules.try_action(st10, "DeepSeek", a_uid, "DeepSeek")
	_r("J10", "白饭 3 层，A（费用 1）在手", "打出 A", "damage=6 rice=3",
		_kv(["damage", act10.get("damage", -1), "rice", int(rules.actor_status(st10, "DeepSeek")["rice"])]))

	# J11 击杀回合不再产白饭
	var b11 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 173)
	var st11: Dictionary = b11["state"]
	rules.begin_turn(st11)
	st11["intents"] = []
	rules.actor_status(st11, "DeepSeek")["rice"] = 1
	st11["hp"] = 3
	var s2_uid := _force_card(st11, "S2")
	var act11: Dictionary = rules.try_action(st11, "DeepSeek", s2_uid, "DeepSeek")
	rules.finish_turn(st11)
	_r("J11", "白饭 1 层，S2 击杀（result=win）", "finish_turn 检查回合末白饭", "damage=10 result=win rice=0",
		_kv(["damage", act11.get("damage", -1), "result", str(st11["result"]), "rice", int(rules.actor_status(st11, "DeepSeek")["rice"])]))

	# J12 下线回合不产白饭
	var b12 := _battle(["DeepSeek", "GPT"], ["DeepSeek", "GPT"], "missing_attachment", 174)
	var st12: Dictionary = b12["state"]
	rules.begin_turn(st12)
	st12["intents"] = []
	st12["accounts"]["DeepSeek"]["token"] = 1
	rules.resolve_hit(st12, "DeepSeek", 1)
	rules.finish_turn(st12)
	_r("J12", "DeepSeek 本回合被打到 0 下线（GPT 在线）", "finish_turn", "rice=0 result=ongoing",
		_kv(["rice", int(rules.actor_status(st12, "DeepSeek")["rice"]), "result", str(st12["result"])]))

	# J13 S1 满层不溢出
	var b13 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 175)
	var st13: Dictionary = b13["state"]
	rules.begin_turn(st13)
	st13["intents"] = []
	rules.actor_status(st13, "DeepSeek")["rice"] = 3
	var s1b_uid := _force_card(st13, "S1")
	rules.try_action(st13, "DeepSeek", s1b_uid, "DeepSeek")
	_r("J13", "白饭 3 层", "打出 S1（riceGain=1，应截断）", "rice=3 shield=4",
		_kv(["rice", int(rules.actor_status(st13, "DeepSeek")["rice"]), "shield", int(rules.actor_status(st13, "DeepSeek")["shield"])]))

	# J14 失败回合不产白饭
	var b14 := _battle(["DeepSeek"], ["DeepSeek"], "missing_attachment", 176)
	var st14: Dictionary = b14["state"]
	rules.begin_turn(st14)
	st14["intents"] = [{"target": "DeepSeek", "raw": 5}]
	st14["accounts"]["DeepSeek"]["token"] = 1
	rules.finish_turn(st14)
	_r("J14", "DeepSeek token=1，敌方 5 点攻击导致全队下线", "finish_turn", "rice=0 result=loss",
		_kv(["rice", int(rules.actor_status(st14, "DeepSeek")["rice"]), "result", str(st14["result"])]))

	key_values["J"] = {"s2_layers": "8/10/12/14", "s2_upgraded": "10/12/14/16", "H_full": 16, "A_full": 6, "cap": 3}

# ---------------------------------------------------------------- K 数值边界

func _intent_sequence(enemy_id: String, turns: int, seed: int) -> Array:
	var b := _battle(["GPT"], ["GPT"], enemy_id, seed)
	var st: Dictionary = b["state"]
	var out: Array = []
	for turn_index in range(1, turns + 1):
		rules.begin_turn(st)
		var raws: Array = []
		for intent in st["intents"]:
			raws.append(int(intent["raw"]))
		out.append(raws)
		st["intents"] = []
		rules.finish_turn(st)
	return out

func _group_k() -> void:
	# K01 HP 溢出裁剪
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", 181)
	var st: Dictionary = b["state"]
	rules.begin_turn(st)
	st["intents"] = []
	st["hp"] = 3
	var h_uid := _force_card(st, "H")
	var act: Dictionary = rules.try_action(st, "GPT", h_uid, "GPT")
	_r("K01", "敌方 HP=3，H 伤害 10", "打出 H", "hp=0 result=win damage=10",
		_kv(["hp", st["hp"], "result", str(st["result"]), "damage", act.get("damage", -1)]))

	# K02 HP 归零立即 win（A 6 对 HP 2）
	var b2 := _battle(["GPT"], ["GPT"], "missing_attachment", 182)
	var st2: Dictionary = b2["state"]
	rules.begin_turn(st2)
	st2["intents"] = []
	st2["hp"] = 2
	var a_uid := _force_card(st2, "A")
	rules.try_action(st2, "GPT", a_uid, "GPT")
	_r("K02", "敌方 HP=2，A 伤害 6", "打出 A", "hp=0 result=win",
		_kv(["hp", st2["hp"], "result", str(st2["result"])]))

	# K03-K06 拖延加压
	var missing_seq := _intent_sequence("missing_attachment", 9, 183)
	var submit_seq := _intent_sequence("submit", 8, 184)
	_r("K03", "缺失附件（pattern 2/2/3），连续 9 回合只结算意图不打伤害", "第 5 回合意图", "turn5_raw=3",
		_kv(["turn5_raw", int(missing_seq[4][0])]))
	_r("K04", "同上", "第 9 回合意图", "turn9_raw=5",
		_kv(["turn9_raw", int(missing_seq[8][0])]))
	var submit6: Array = submit_seq[5]
	var submit6_text := ""
	for raw in submit6:
		submit6_text += ("-" if submit6_text != "" else "") + str(raw)
	_r("K05", "本次提交版（pattern 2/1+1/4/0）", "第 6 回合意图段（1+1 只加第一段）", "segments=2-1",
		_kv(["segments", submit6_text]))
	var submit8: Array = submit_seq[7]
	_r("K06", "同上", "第 8 回合意图（全零休整）", "intents=0",
		_kv(["intents", submit8.size()]))

	# K07 0 伤害段不产生 intent（第 4 回合休整）
	var submit4: Array = submit_seq[3]
	_r("K07", "同上", "第 4 回合意图（休整）", "intents=0",
		_kv(["intents", submit4.size()]))

	# K08 目标轮换
	var b8 := _battle(["GPT", "Claude"], ["GPT", "Claude"], "missing_attachment", 185)
	var st8: Dictionary = b8["state"]
	rules.begin_turn(st8)
	var target1 := ""
	if not st8["intents"].is_empty():
		target1 = str(st8["intents"][0]["target"])
	st8["intents"] = []
	rules.finish_turn(st8)
	rules.begin_turn(st8)
	var target2 := ""
	if not st8["intents"].is_empty():
		target2 = str(st8["intents"][0]["target"])
	_r("K08", "双人上场 GPT/Claude", "连续两回合检查敌方意图目标", "turn1=GPT turn2=Claude",
		_kv(["turn1", target1, "turn2", target2]))

	key_values["K"] = {"missing_ramp": [2, 2, 3, 2, 3, 4, 3, 3, 5], "submit_ramp": "2 / 2-1 / 5 / 0", "overflow_clamped": true}

# ---------------------------------------------------------------- L 状态机

func _replay_state(seed: int) -> Dictionary:
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", seed)
	var st: Dictionary = b["state"]
	for turn_index in range(1, 9):
		if str(st["result"]) != "ongoing":
			break
		rules.begin_turn(st)
		var action_id := _pick_attack(st, "GPT")
		rules.try_action(st, "GPT", action_id, "GPT")
		rules.finish_turn(st)
	return st

func _group_l() -> void:
	# L01 begin 前 try_action
	var b := _battle(["GPT"], ["GPT"], "missing_attachment", 191)
	var st: Dictionary = b["state"]
	var snap := _snapshot(st)
	var res: Dictionary = rules.try_action(st, "GPT", BASIC_ATTACK, "GPT")
	_r("L01", "start_battle 后未 begin_turn", "try_action", "err=action_unavailable state_same=true",
		_kv(["err", _err(res), "state_same", _snapshot(st) == snap]))

	# L02 重复 begin_turn
	rules.begin_turn(st)
	var snap2 := _snapshot(st)
	var res2: Dictionary = rules.begin_turn(st)
	_r("L02", "已在 player 阶段", "再次 begin_turn", "err=invalid_begin state_same=true",
		_kv(["err", _err(res2), "state_same", _snapshot(st) == snap2]))

	# L03 重复 try_action
	rules.try_action(st, "GPT", BASIC_ATTACK, "GPT")
	var snap3 := _snapshot(st)
	var res3: Dictionary = rules.try_action(st, "GPT", BASIC_GUARD, "GPT")
	_r("L03", "本回合已行动", "再次 try_action", "err=action_unavailable state_same=true",
		_kv(["err", _err(res3), "state_same", _snapshot(st) == snap3]))

	# L04 重复 finish_turn
	st["intents"] = []
	rules.finish_turn(st)
	var snap4 := _snapshot(st)
	var res4: Dictionary = rules.finish_turn(st)
	_r("L04", "已在 between 阶段", "再次 finish_turn", "err=invalid_finish state_same=true",
		_kv(["err", _err(res4), "state_same", _snapshot(st) == snap4]))

	# L05 同 seed 同操作集可重放
	var s1 := _replay_state(192)
	var s2 := _replay_state(192)
	var full_equal := JSON.stringify(s1) == JSON.stringify(s2)
	var hp_equal := int(s1["hp"]) == int(s2["hp"])
	var turn_equal := int(s1["turn"]) == int(s2["turn"])
	var accounts_equal := JSON.stringify(s1["accounts"]) == JSON.stringify(s2["accounts"])
	var log_equal := JSON.stringify(s1["log"]) == JSON.stringify(s2["log"])
	_r("L05", "同一 seed=192，同一确定性操作集各跑一遍", "比较整份战斗状态", "equal=true hp_equal=true turn_equal=true accounts_equal=true log_equal=true",
		_kv(["equal", full_equal, "hp_equal", hp_equal, "turn_equal", turn_equal, "accounts_equal", accounts_equal, "log_equal", log_equal]))
	key_values["L"] = {"replay_hp": s1["hp"], "replay_turn": s1["turn"], "replay_result": str(s1["result"]), "replay_equal": full_equal}

	# L06 begin 之前 finish_turn
	var b6 := _battle(["GPT"], ["GPT"], "missing_attachment", 193)
	var st6: Dictionary = b6["state"]
	var snap6 := _snapshot(st6)
	var res6: Dictionary = rules.finish_turn(st6)
	_r("L06", "start_battle 后未 begin_turn（phase=between）", "finish_turn", "err=invalid_finish state_same=true",
		_kv(["err", _err(res6), "state_same", _snapshot(st6) == snap6]))
