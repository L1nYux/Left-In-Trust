extends SceneTree

# 数值复核辅助脚本（只读规则实现，不改 game/scripts、game/data 与既有测试）。
# 用途：
#   1. 用 game_rules.gd 的实际 preview_action/try_action 复算派生值
#   2. 用实际回合时序测白饭/连击/反击的最早兑现回合
#   3. 复制 game/tests/smoke_runs.gd 的确定性选牌策略，跑 3 角色 x 种子 1..50 的完整切片
#   4. 输出 docs/审计/数值复核数据.json
# 规则口径：现行规则为「每角色每回合不限行动次数，仅基础攻击/基础防御各限 1 次」。
#   本脚本的自动策略仍保持每回合只执行 1 次行动（保守下界），故回合数与“理论最少回合”口径偏保守；
#   真人/最优策略在同回合多次行动后会比这里的估计更快结束战斗。
# 运行：
#   & 'D:\MyPros\AI游戏\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless ^
#     --path 'D:\MyPros\AI游戏\game' --script res://tests/audit_numeric.gd

const ContentDBScript = preload("res://scripts/content_db.gd")
const RulesScript = preload("res://scripts/game_rules.gd")
const TestPolicy = preload("res://tests/test_policy.gd")

const ROLES := ["GPT", "Claude", "DeepSeek"]
const SEED_FROM := 1
const SEED_TO := 50
const DOCUMENTED_SEEDS := {"GPT": 20261025, "Claude": 20261026, "DeepSeek": 20261027}
# docs/垂直切片验证报告.md「三条走通记录」原值，用于交叉核对
const DOC_EXPECTED := {
	"GPT": {"ordinaryTurns": 2, "rest": [10, 12], "bossTurns": 3, "finalToken": 6, "wallet": 12},
	"Claude": {"ordinaryTurns": 2, "rest": [10, 12], "bossTurns": 4, "finalToken": 7, "wallet": 12},
	"DeepSeek": {"ordinaryTurns": 2, "rest": [9, 12], "bossTurns": 3, "finalToken": 5, "wallet": 12},
}

var rules
var content: Dictionary
var report: Dictionary = {}


func _init() -> void:
	content = ContentDBScript.load_content()
	if content.is_empty():
		push_error("[AUDIT_NUMERIC] missing content")
		quit(1)
		return
	rules = RulesScript.new(content)
	report["generatedBy"] = "game/tests/audit_numeric.gd"
	report["engine"] = str(Engine.get_version_info()["string"])
	report["dataVersion"] = str(content.get("version", ""))
	report["method"] = {
		"dataSource": "docs/首批内容.json（经 game/data/content.json 载入，两者 SHA-256 一致性见 sourceSHA256）",
		"derivedValues": "所有伤害/防护/回复/白饭数字由 game_rules.gd 的 resolved_card + preview_action 实际算出",
		"simulation": "完整切片=普通战 missing_attachment(HP16)->settle->休息(若未满)->Boss submit(HP30)->settle；自动出牌统一调用 game/tests/test_policy.gd；种子 1..50，战斗种子沿用 run_seed ^ 0x13579 / ^ 0x24680",
		"bootstrapping": "白饭/连击/反击最早回合用真实 begin_turn/try_action/finish_turn 时序脚本化实测",
		"hpBounds": "最少回合=ceil(HP/单次行动最大伤害)；最多回合估计=ceil(HP/3)（保守假设每回合只打一次基础攻击；现行规则允许同回合多次行动，故该上限只作最慢情形下界）",
	}
	report["sourceSHA256"] = _sha_check()
	report["parameters"] = content["parameters"]
	report["derived"] = _derived()
	report["reachability"] = _reachability()
	report["simulation"] = _simulate()
	report["hpBounds"] = _hp_bounds()
	report["basicOnly"] = _basic_only_runs()
	report["reproduction"] = {
		"command": "& 'D:\\MyPros\\AI游戏\\.tools\\godot-4.7.2\\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\\MyPros\\AI游戏\\game' --script res://tests/audit_numeric.gd",
		"writes": "docs/审计/数值复核数据.json",
		"expectedStdoutPrefix": "[AUDIT_NUMERIC]",
	}
	_write_json(report)
	_print_summary()
	quit(0)


# ---------------------------------------------------------------- 基础工具

func _sha_check() -> Dictionary:
	var game_dir := ProjectSettings.globalize_path("res://")
	var repo_dir := game_dir.trim_suffix("/").get_base_dir()
	var docs_json := repo_dir.path_join("docs").path_join("首批内容.json")
	var game_json := game_dir.path_join("data").path_join("content.json")
	var recorded_path := game_dir.path_join("data").path_join("content.sha256")
	var recorded := ""
	if FileAccess.file_exists(recorded_path):
		recorded = FileAccess.get_file_as_string(recorded_path).strip_edges()
	var docs_sha := FileAccess.get_sha256(docs_json)
	var game_sha := FileAccess.get_sha256(game_json)
	return {
		"docsJson": docs_json,
		"docsJsonSha256": docs_sha,
		"gameJson": game_json,
		"gameJsonSha256": game_sha,
		"recordedSha256": recorded,
		"docsEqualsGameData": docs_sha == game_sha,
		"recordedMatches": recorded == docs_sha,
	}


func _effect(definition: Dictionary) -> Dictionary:
	return {
		"cost": int(definition.get("cost", 0)),
		"damage": int(definition.get("damage", 0)),
		"shield": int(definition.get("shield", 0)),
		"heal": int(definition.get("heal", 0)),
		"riceGain": int(definition.get("riceGain", 0)),
		"cashRice": bool(definition.get("cashRice", false)),
		"fullStreakBonus": int(definition.get("fullStreakBonus", 0)),
		"consume": bool(definition.get("consume", false)),
	}


func _histogram(values: Array) -> Dictionary:
	var histogram := {}
	for value in values:
		var key := str(value)
		histogram[key] = int(histogram.get(key, 0)) + 1
	return histogram


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	var total := 0
	var minimum := int(values[0])
	var maximum := int(values[0])
	for value in values:
		total += int(value)
		minimum = mini(minimum, int(value))
		maximum = maxi(maximum, int(value))
	return {
		"n": values.size(),
		"min": minimum,
		"max": maximum,
		"mean": snapped(float(total) / float(values.size()), 0.01),
		"histogram": _histogram(values),
	}


func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total


func _count_at_least(values: Array, threshold: int) -> int:
	var count := 0
	for value in values:
		if int(value) >= threshold:
			count += 1
	return count


# ---------------------------------------------------------------- 派生值

func _derived() -> Dictionary:
	var cards: Array = []
	for definition_value in content["cards"]:
		var definition: Dictionary = definition_value
		var card_id := str(definition["id"])
		var base: Dictionary = rules.resolved_card({"code": card_id, "upgraded": false})
		var upgraded: Dictionary = rules.resolved_card({"code": card_id, "upgraded": true})
		var base_effect := _effect(base)
		var upgraded_effect := _effect(upgraded)
		cards.append({
			"id": card_id,
			"name": str(definition["name"]),
			"owner": str(definition.get("owner", "通用")),
			"kind": str(definition["kind"]),
			"target": str(definition.get("target", "")),
			"cost": int(definition.get("cost", 0)),
			"base": base_effect,
			"upgraded": upgraded_effect,
			"upgradeDelta": definition.get("upgrade", {}),
			"formula": _card_formula(definition, base_effect, upgraded_effect),
		})
	var derived := {
		"cards": cards,
		"gptStreak": _gpt_table(),
		"claudeCounter": _claude_table(),
		"deepseekRice": _deepseek_table(),
		"tokenThresholds": _token_thresholds(),
	}
	derived["maxSingleActionDamage"] = _max_single_action(derived)
	derived["maxHeal"] = _max_heal()
	derived["observedMaxDamage"] = _observed_max_damage()
	derived["passiveValueSummary"] = {
		"gptStreak": "攻击卡按出牌前 streak 每层 +2；streak=2 时 G2 另 +fullStreakBonus(2)；streak 上限 2",
		"claudeCounter": "本回合正数防护对象实际挡伤且本人在线 -> 下一次攻击的一段 +4，最多存一次",
		"deepseekRice": "S2 每次行动按当前 rice x2 换伤害并清零(cashRice)；cost>=2 的普通攻击在 rice=3 时 +6 并清零；S1 行动时 rice+1",
	}
	return derived


func _card_formula(definition: Dictionary, base: Dictionary, upgraded: Dictionary) -> String:
	var parts: Array = []
	for field in ["damage", "shield", "heal", "riceGain"]:
		var base_value := int(base[field])
		var upgraded_value := int(upgraded[field])
		if base_value != 0 or upgraded_value != 0:
			var delta := upgraded_value - base_value
			parts.append("%s 基础 %d%s" % [field, base_value, ("" if delta == 0 else "，升级 %+d -> %d" % [delta, upgraded_value])])
	if bool(base["cashRice"]):
		parts.append("cashRice: 伤害 += 当前白饭 x2 后清零")
	if int(base["fullStreakBonus"]) > 0:
		parts.append("满连击额外 +%d" % int(base["fullStreakBonus"]))
	if bool(base["consume"]):
		parts.append("本战消耗")
	return "；".join(parts)


func _probe(role_id: String, actor_setup: Dictionary, action_id: String, upgraded: bool, token: int = -1) -> Dictionary:
	var run_state: Dictionary = rules.make_run(role_id, 1)
	var state: Dictionary = rules.start_battle(run_state, "probe", [role_id], "hidden", 424242)
	state["phase"] = "player"
	state["turn"] = 1
	var actor: Dictionary = rules.actor_status(state, role_id)
	if token >= 0:
		state["accounts"][role_id]["token"] = token
	for key in actor_setup.keys():
		actor[str(key)] = actor_setup[key]
	if action_id != RulesScript.BASIC_ATTACK and action_id != RulesScript.BASIC_GUARD:
		state["hand"].append({"uid": action_id, "code": action_id, "upgraded": upgraded})
	return rules.preview_action(state, role_id, action_id, role_id)


func _observe(role_id: String, action_id: String, upgraded: bool, actor_setup: Dictionary) -> Dictionary:
	var run_state: Dictionary = rules.make_run(role_id, 3)
	var state: Dictionary = rules.start_battle(run_state, "observe", [role_id], "hidden", 424242)
	state["phase"] = "player"
	state["turn"] = 1
	var actor: Dictionary = rules.actor_status(state, role_id)
	for key in actor_setup.keys():
		actor[str(key)] = actor_setup[key]
	if action_id != RulesScript.BASIC_ATTACK and action_id != RulesScript.BASIC_GUARD:
		state["hand"].append({"uid": action_id, "code": action_id, "upgraded": upgraded})
	var hp_before := int(state["hp"])
	var action: Dictionary = rules.try_action(state, role_id, action_id, role_id)
	return {
		"ok": bool(action["ok"]),
		"enemyHpBefore": hp_before,
		"enemyHpAfter": int(state["hp"]),
		"damageObserved": hp_before - int(state["hp"]),
		"tokenAfter": int(state["accounts"][role_id]["token"]),
	}


func _gpt_table() -> Dictionary:
	var table := {}
	for card_id in ["basic_attack", "A", "H", "V", "G1", "G2"]:
		var variants := {}
		for upgraded in [false, true]:
			if card_id == "basic_attack" and upgraded:
				continue
			var rows := {}
			for streak in [0, 1, 2]:
				var preview: Dictionary = _probe("GPT", {"streak": streak}, card_id, upgraded)
				rows[str(streak)] = {
					"ok": bool(preview.get("ok", false)),
					"damage": int(preview.get("damage", 0)),
					"shield": int(preview.get("shield", 0)),
				}
			variants["upgraded" if upgraded else "base"] = rows
		table[card_id] = variants
	return table


func _claude_table() -> Dictionary:
	var table := {}
	for card_id in ["basic_attack", "A", "H", "V", "C2"]:
		var variants := {}
		for upgraded in [false, true]:
			if card_id == "basic_attack" and upgraded:
				continue
			var rows := {}
			for counter in [false, true]:
				var preview: Dictionary = _probe("Claude", {"counter": counter}, card_id, upgraded)
				rows["counter" if counter else "no_counter"] = {
					"ok": bool(preview.get("ok", false)),
					"damage": int(preview.get("damage", 0)),
					"shield": int(preview.get("shield", 0)),
				}
			variants["upgraded" if upgraded else "base"] = rows
		table[card_id] = variants
	return table


func _deepseek_table() -> Dictionary:
	var table := {}
	for card_id in ["basic_attack", "A", "H", "V", "S2"]:
		var variants := {}
		for upgraded in [false, true]:
			if card_id == "basic_attack" and upgraded:
				continue
			var rows := {}
			for rice in [0, 1, 2, 3]:
				var preview: Dictionary = _probe("DeepSeek", {"rice": rice}, card_id, upgraded)
				rows[str(rice)] = {
					"ok": bool(preview.get("ok", false)),
					"damage": int(preview.get("damage", 0)),
					"shield": int(preview.get("shield", 0)),
				}
			variants["upgraded" if upgraded else "base"] = rows
		table[card_id] = variants
	return table


func _token_thresholds() -> Dictionary:
	var rows := {}
	for spec in [["D", 0], ["A", 1], ["H", 2]]:
		var card_id := str(spec[0])
		var cost := int(spec[1])
		var at_cost: Dictionary = _probe("GPT", {}, card_id, false, cost)
		var at_cost_plus_one: Dictionary = _probe("GPT", {}, card_id, false, cost + 1)
		rows[card_id] = {
			"cost": cost,
			"tokenEqualsCost": {
				"ok": bool(at_cost.get("ok", false)),
				"error": str(at_cost.get("error", "")),
			},
			"tokenEqualsCostPlusOne": {
				"ok": bool(at_cost_plus_one.get("ok", false)),
				"balanceAfter": int(at_cost_plus_one.get("balance_after", -1)),
			},
			"minTokenToPlay": cost + 1,
			"formula": "R02：支付后至少剩 1 -> token >= cost + 1",
		}
	return rows


func _max_single_action(derived: Dictionary) -> Dictionary:
	var result := {}
	for role_id in ROLES:
		var base_best := 0
		var upgraded_best := 0
		var source := ""
		if role_id == "GPT":
			var gpt_rows: Dictionary = derived["gptStreak"]
			for card_id in gpt_rows.keys():
				var variants: Dictionary = gpt_rows[card_id]
				if variants.has("base"):
					var base_rows: Dictionary = variants["base"]
					base_best = maxi(base_best, int(base_rows["2"]["damage"]))
				if variants.has("upgraded"):
					var upgraded_rows: Dictionary = variants["upgraded"]
					upgraded_best = maxi(upgraded_best, int(upgraded_rows["2"]["damage"]))
			source = "G2 streak=2：base 16，升级 18"
		elif role_id == "Claude":
			var claude_rows: Dictionary = derived["claudeCounter"]
			for card_id in claude_rows.keys():
				var variants: Dictionary = claude_rows[card_id]
				if variants.has("base"):
					var base_rows: Dictionary = variants["base"]
					base_best = maxi(base_best, int(base_rows["counter"]["damage"]))
				if variants.has("upgraded"):
					var upgraded_rows: Dictionary = variants["upgraded"]
					upgraded_best = maxi(upgraded_best, int(upgraded_rows["counter"]["damage"]))
			source = "H counter=true：base 14，升级 16"
		else:
			var rice_rows: Dictionary = derived["deepseekRice"]
			for card_id in rice_rows.keys():
				var variants: Dictionary = rice_rows[card_id]
				if variants.has("base"):
					var base_rows: Dictionary = variants["base"]
					base_best = maxi(base_best, int(base_rows["3"]["damage"]))
				if variants.has("upgraded"):
					var upgraded_rows: Dictionary = variants["upgraded"]
					upgraded_best = maxi(upgraded_best, int(upgraded_rows["3"]["damage"]))
			source = "H rice=3：base 16，升级 18"
		result[role_id] = {
			"baseDeckMax": base_best,
			"upgradedMax": upgraded_best,
			"maxStateSource": source,
			"note": "单次行动=一回合内一名角色的一次出牌；切片内每回合只执行一次行动（现行规则允许同回合多次行动，此处取保守下界）",
		}
	return result


func _max_heal() -> Dictionary:
	var card_heals := {}
	for definition_value in content["cards"]:
		var definition: Dictionary = definition_value
		var base: Dictionary = rules.resolved_card({"code": str(definition["id"]), "upgraded": false})
		var upgraded: Dictionary = rules.resolved_card({"code": str(definition["id"]), "upgraded": true})
		if int(base.get("heal", 0)) > 0 or int(upgraded.get("heal", 0)) > 0:
			card_heals[str(definition["id"])] = {
				"base": int(base.get("heal", 0)),
				"upgraded": int(upgraded.get("heal", 0)),
				"target": str(definition.get("target", "")),
			}
	return {
		"perActionMaxHeal": 3,
		"source": "R 应急补给升级后 heal=2+1=3（本战消耗、每套牌最多 1 份）；T 额度转交 heal=2",
		"cards": card_heals,
	}


func _observed_max_damage() -> Dictionary:
	return {
		"GPT_G2_upgraded_streak2": _observe("GPT", "G2", true, {"streak": 2}),
		"DeepSeek_H_upgraded_rice3": _observe("DeepSeek", "H", true, {"rice": 3}),
		"DeepSeek_S2_upgraded_rice3": _observe("DeepSeek", "S2", true, {"rice": 3}),
		"Claude_H_upgraded_counter": _observe("Claude", "H", true, {"counter": true}),
		"Claude_basic_counter": _observe("Claude", RulesScript.BASIC_ATTACK, false, {"counter": true}),
		"note": "对 hidden(HP56) 假人执行真实 try_action，用 HP 差实测伤害，排除预览层误差",
	}


# ---------------------------------------------------------------- 可达性 / 时序

func _reachability() -> Dictionary:
	return {
		"deepseekRice": {
			"withS1OnTurn1": _rice_window(true),
			"withoutS1": _rice_window(false),
			"ruleNote": "begin_turn 不加白饭；S1 行动 rice+1；finish_turn 末尾在线且 ongoing 再 +1（上限 3）。故 S1 路线第 3 回合行动时 rice=3，非 S1 路线第 4 回合；与规则基准「不再采用最快第四回合的旧绝对时点」一致。",
		},
		"gptStreak": _gpt_window(),
		"claudeCounter": _claude_window(),
		"deepseekFullRiceS2vsH": _s2_vs_h(),
	}


func _rice_window(with_s1: bool) -> Dictionary:
	var run_state: Dictionary = rules.make_run("DeepSeek", int(DOCUMENTED_SEEDS["DeepSeek"]))
	var state: Dictionary = rules.start_battle(run_state, "rice", ["DeepSeek"], "missing_attachment", 777)
	state["accounts"]["DeepSeek"]["token"] = 60
	var rows: Array = []
	for turn_index in 5:
		if str(state["result"]) != "ongoing":
			break
		rules.begin_turn(state)
		var actor: Dictionary = rules.actor_status(state, "DeepSeek")
		var turn := int(state["turn"])
		state["hand"].append({"uid": "probe-S2-%d" % turn, "code": "S2", "upgraded": false})
		state["hand"].append({"uid": "probe-H-%d" % turn, "code": "H", "upgraded": false})
		var s2: Dictionary = rules.preview_action(state, "DeepSeek", "probe-S2-%d" % turn, "DeepSeek")
		var h: Dictionary = rules.preview_action(state, "DeepSeek", "probe-H-%d" % turn, "DeepSeek")
		var row := {
			"turn": turn,
			"riceAtAction": int(actor["rice"]),
			"s2Damage": int(s2.get("damage", 0)),
			"hDamage": int(h.get("damage", 0)),
			"played": "",
		}
		if with_s1 and turn == 1:
			state["hand"].append({"uid": "probe-S1", "code": "S1", "upgraded": false})
			var s1: Dictionary = rules.try_action(state, "DeepSeek", "probe-S1", "DeepSeek")
			row["played"] = "S1"
			row["actionOk"] = bool(s1.get("ok", false))
		elif int(row["s2Damage"]) >= 14 and str(row["played"]) == "":
			var hp_before := int(state["hp"])
			var cash: Dictionary = rules.try_action(state, "DeepSeek", "probe-S2-%d" % turn, "DeepSeek")
			row["played"] = "S2"
			row["actionOk"] = bool(cash.get("ok", false))
			row["enemyHpDrop"] = hp_before - int(state["hp"])
		rules.finish_turn(state)
		rows.append(row)
	var first_s2_full := -1
	var first_h_full := -1
	for row_value in rows:
		var row: Dictionary = row_value
		if first_s2_full < 0 and int(row["s2Damage"]) >= 14:
			first_s2_full = int(row["turn"])
		if first_h_full < 0 and int(row["hDamage"]) >= 16:
			first_h_full = int(row["turn"])
	return {
		"withS1": with_s1,
		"turns": rows,
		"firstS2FullRiceTurn": first_s2_full,
		"firstHFullRiceTurn": first_h_full,
	}


func _gpt_window() -> Dictionary:
	var run_state: Dictionary = rules.make_run("GPT", int(DOCUMENTED_SEEDS["GPT"]))
	var state: Dictionary = rules.start_battle(run_state, "streak", ["GPT"], "hidden", 888)
	state["accounts"]["GPT"]["token"] = 60
	var rows: Array = []
	for turn_index in 4:
		if str(state["result"]) != "ongoing":
			break
		rules.begin_turn(state)
		var actor: Dictionary = rules.actor_status(state, "GPT")
		var turn := int(state["turn"])
		state["hand"].append({"uid": "probe-G1-%d" % turn, "code": "G1", "upgraded": false})
		state["hand"].append({"uid": "probe-G2-%d" % turn, "code": "G2", "upgraded": false})
		var g1: Dictionary = rules.preview_action(state, "GPT", "probe-G1-%d" % turn, "GPT")
		var g2: Dictionary = rules.preview_action(state, "GPT", "probe-G2-%d" % turn, "GPT")
		rows.append({
			"turn": turn,
			"streakAtAction": int(actor["streak"]),
			"g1Damage": int(g1.get("damage", 0)),
			"g2Damage": int(g2.get("damage", 0)),
		})
		var acted: Dictionary = rules.try_action(state, "GPT", "probe-G1-%d" % turn, "GPT")
		rows[rows.size() - 1]["playedG1Ok"] = bool(acted.get("ok", false))
		rules.finish_turn(state)
	var first_full := -1
	for row_value in rows:
		var row: Dictionary = row_value
		if first_full < 0 and int(row["streakAtAction"]) == 2:
			first_full = int(row["turn"])
	return {
		"turns": rows,
		"firstFullStreakTurn": first_full,
		"note": "自动策略每回合只执行一次行动（现行规则允许同回合多次行动，此处取保守下界）；每打出一张攻击卡 streak+1（上限 2），非攻击/基础动作/跳过断连击。连续两回合攻击后，第 3 回合行动前 streak=2。",
	}


func _claude_window() -> Dictionary:
	var run_state: Dictionary = rules.make_run("Claude", int(DOCUMENTED_SEEDS["Claude"]))
	var state: Dictionary = rules.start_battle(run_state, "counter", ["Claude"], "missing_attachment", 555)
	state["accounts"]["Claude"]["token"] = 60
	var rows: Array = []
	for turn_index in 3:
		if str(state["result"]) != "ongoing":
			break
		rules.begin_turn(state)
		var actor: Dictionary = rules.actor_status(state, "Claude")
		var turn := int(state["turn"])
		for code in ["C1", "C2", "V", "A", "H"]:
			state["hand"].append({"uid": "probe-%s-%d" % [code, turn], "code": code, "upgraded": false})
		var basic: Dictionary = rules.preview_action(state, "Claude", RulesScript.BASIC_ATTACK, "Claude")
		var c2: Dictionary = rules.preview_action(state, "Claude", "probe-C2-%d" % turn, "Claude")
		var v: Dictionary = rules.preview_action(state, "Claude", "probe-V-%d" % turn, "Claude")
		var a: Dictionary = rules.preview_action(state, "Claude", "probe-A-%d" % turn, "Claude")
		var h: Dictionary = rules.preview_action(state, "Claude", "probe-H-%d" % turn, "Claude")
		var row := {
			"turn": turn,
			"counterBeforeAction": bool(actor["counter"]),
			"protectedBeforeAction": actor["protected"].duplicate(),
			"basicDamage": int(basic.get("damage", 0)),
			"C2Damage": int(c2.get("damage", 0)),
			"VDamage": int(v.get("damage", 0)),
			"ADamage": int(a.get("damage", 0)),
			"HDamage": int(h.get("damage", 0)),
			"played": "",
		}
		if turn == 1:
			var guard: Dictionary = rules.try_action(state, "Claude", "probe-C1-%d" % turn, "Claude")
			row["played"] = "C1(shield5 self)"
			row["actionOk"] = bool(guard.get("ok", false))
		elif turn == 2:
			var attack: Dictionary = rules.try_action(state, "Claude", "probe-C2-%d" % turn, "Claude")
			row["played"] = "C2(consume counter)"
			row["actionOk"] = bool(attack.get("ok", false))
		rules.finish_turn(state)
		rows.append(row)
	return {
		"turns": rows,
		"firstCounterReadyEndOfTurn": 1,
		"firstCounterUsableTurn": 2,
		"note": "第 1 回合 C1 给自身防护 5；敌方第 1 段 2 被实际吸收且 Claude 在线 -> 回合末 counter=true；第 2 回合攻击即 +4。单人阵容目标恒为本人，故每次防住即可续反击。",
	}


func _s2_vs_h() -> Dictionary:
	var s2_base: Dictionary = rules.resolved_card({"code": "S2", "upgraded": false})
	var s2_up: Dictionary = rules.resolved_card({"code": "S2", "upgraded": true})
	var h_base: Dictionary = rules.resolved_card({"code": "H", "upgraded": false})
	var h_up: Dictionary = rules.resolved_card({"code": "H", "upgraded": true})
	var rows: Array = []
	for rice in [0, 1, 2, 3]:
		rows.append({
			"rice": rice,
			"S2_base": int(s2_base.get("damage", 0)) + rice * 2,
			"S2_upgraded": int(s2_up.get("damage", 0)) + rice * 2,
			"H_base": int(h_base.get("damage", 0)) + (6 if rice == 3 else 0),
			"H_upgraded": int(h_up.get("damage", 0)) + (6 if rice == 3 else 0),
			"note": "同 cost=2；H 在 rice<3 时不清空白饭，S2 每次兑现都清零",
		})
	return {
		"rows": rows,
		"fullRiceComparison": {"S2_base": 14, "H_base": 16, "S2_upgraded": 16, "H_upgraded": 18},
		"note": "满层时 H 比 S2 高 2；S2 的收益在 rice=2 时（12 > H 的 10）体现为提前兑现，符合规则基准「S2 覆盖该牌满层 +6、不叠通用满层加成」。",
	}


# ---------------------------------------------------------------- 完整切片模拟

func _simulate() -> Dictionary:
	var result := {
		"policy": "统一调用 game/tests/test_policy.gd：对每个合法动作 duplicate 状态 -> try_action -> finish_turn -> 评分 damage*1.25 + 自身token*2 + streak*1.2 + rice*1.5 + counter?3；胜 10000+token，负 -10000；严格大于才替换（同分取先出现者）。",
		"seedRange": [SEED_FROM, SEED_TO],
		"roles": {},
		"documentedSeeds": {},
		"determinism": {},
	}
	for role_id in ROLES:
		var records: Array = []
		for run_seed in range(SEED_FROM, SEED_TO + 1):
			records.append(_complete_slice(role_id, run_seed))
		result["roles"][role_id] = _aggregate(records)
	for role_id in ROLES:
		var documented: Dictionary = _complete_slice(role_id, int(DOCUMENTED_SEEDS[role_id]))
		documented["docExpected"] = DOC_EXPECTED[role_id]
		documented["matchesDocTable"] = _matches_doc(documented)
		result["documentedSeeds"][role_id] = documented
	var first := JSON.stringify(_complete_slice("GPT", 1))
	var second := JSON.stringify(_complete_slice("GPT", 1))
	result["determinism"] = {
		"test": "同一 seed=1 GPT 完整切片跑两次，JSON 完全一致",
		"identical": first == second,
	}
	return result


func _matches_doc(record: Dictionary) -> Dictionary:
	var expected: Dictionary = DOC_EXPECTED[str(record["role"])]
	var ordinary: Dictionary = record["ordinary"]
	var boss: Dictionary = record.get("boss", {})
	var rest: Dictionary = record.get("rest", {})
	var rest_pair := [int(rest.get("before", -1)), int(rest.get("after", -2))]
	return {
		"ordinaryTurns": int(ordinary["turns"]) == int(expected["ordinaryTurns"]),
		"rest": rest_pair == expected["rest"],
		"bossTurns": int(boss.get("turns", -1)) == int(expected["bossTurns"]),
		"finalToken": int(record.get("finalToken", -1)) == int(expected["finalToken"]),
		"wallet": int(record.get("wallet", -1)) == int(expected["wallet"]),
		"all": (
			int(ordinary["turns"]) == int(expected["ordinaryTurns"])
			and rest_pair == expected["rest"]
			and int(boss.get("turns", -1)) == int(expected["bossTurns"])
			and int(record.get("finalToken", -1)) == int(expected["finalToken"])
			and int(record.get("wallet", -1)) == int(expected["wallet"])
		),
	}


func _complete_slice(role_id: String, run_seed: int) -> Dictionary:
	var run_state: Dictionary = rules.make_run(role_id, run_seed)
	var ordinary: Dictionary = _play(run_state, "ordinary", role_id, "missing_attachment", run_seed ^ 0x13579)
	var record := {
		"role": role_id,
		"seed": run_seed,
		"completed": false,
		"ordinary": _battle_record(ordinary, role_id),
	}
	if str(ordinary["result"]) != "win":
		record["failedAt"] = "ordinary"
		record["finalToken"] = int(run_state["accounts"][role_id]["token"])
		record["wallet"] = int(run_state["wallet"])
		return record
	# 结算前 token 必须取战斗 state 的余额：run_state 尚未被 settle_battle 同步，
	# 仍是进入战斗前的旧值，会系统性夸大 +3 恢复的截断浪费。
	var ordinary_before_settle := int(ordinary["accounts"][role_id]["token"])
	rules.settle_battle(run_state, ordinary)
	var ordinary_after_settle := int(run_state["accounts"][role_id]["token"])
	record["ordinary"]["tokenBeforeSettle"] = ordinary_before_settle
	record["ordinary"]["tokenAfterSettle"] = ordinary_after_settle
	record["ordinary"]["winRecoveryWaste"] = (ordinary_before_settle + 3 - ordinary_after_settle) if ordinary_before_settle > 0 else 0
	record["walletAfterOrdinary"] = int(run_state["wallet"])
	var before_rest := int(run_state["accounts"][role_id]["token"])
	var rest_performed := false
	if before_rest < int(run_state["accounts"][role_id]["max"]):
		rules.rest_recover(run_state, "rest", role_id)
		rest_performed = true
	var after_rest := int(run_state["accounts"][role_id]["token"])
	record["rest"] = {
		"performed": rest_performed,
		"before": before_rest,
		"after": after_rest,
		"waste": (before_rest + 6 - after_rest) if rest_performed else 0,
	}
	var boss: Dictionary = _play(run_state, "boss", role_id, "submit", run_seed ^ 0x24680)
	record["boss"] = _battle_record(boss, role_id)
	record["boss"]["tokenAtEntry"] = after_rest
	if str(boss["result"]) != "win":
		record["failedAt"] = "boss"
		record["finalToken"] = int(run_state["accounts"][role_id]["token"])
		record["wallet"] = int(run_state["wallet"])
		return record
	var boss_before_settle := int(boss["accounts"][role_id]["token"])
	rules.settle_battle(run_state, boss)
	var boss_after_settle := int(run_state["accounts"][role_id]["token"])
	record["boss"]["tokenBeforeSettle"] = boss_before_settle
	record["boss"]["tokenAfterSettle"] = boss_after_settle
	record["boss"]["winRecoveryWaste"] = (boss_before_settle + 3 - boss_after_settle) if boss_before_settle > 0 else 0
	record["completed"] = true
	record["finalToken"] = boss_after_settle
	record["wallet"] = int(run_state["wallet"])
	return record


func _play(run_state: Dictionary, battle_id: String, role_id: String, enemy_id: String, battle_seed: int) -> Dictionary:
	var state: Dictionary = rules.start_battle(run_state, battle_id, [role_id], enemy_id, battle_seed)
	state["audit_ramp_turns"] = []
	state["audit_rest_row_turns"] = []
	state["audit_reached_turn5"] = false
	while str(state["result"]) == "ongoing" and int(state["turn"]) < 40:
		rules.begin_turn(state)
		if str(state["phase"]) != "player":
			break
		var turn := int(state["turn"])
		if turn >= 5:
			state["audit_reached_turn5"] = true
		var pattern: Array = state["enemy"]["pattern"]
		var row: Array = pattern[(turn - 1) % pattern.size()]
		var has_positive := false
		for raw_value in row:
			if int(raw_value) > 0:
				has_positive = true
				break
		if not has_positive:
			state["audit_rest_row_turns"].append(turn)
		elif turn >= 5:
			state["audit_ramp_turns"].append(turn)
		var chosen := TestPolicy.choose_action(rules, state, role_id)
		rules.try_action(state, role_id, chosen, role_id)
		rules.finish_turn(state)
	return state


func _battle_record(state: Dictionary, role_id: String) -> Dictionary:
	return {
		"result": str(state["result"]),
		"turns": int(state["turn"]),
		"enemy": str(state["enemy"]["id"]),
		"enemyHp": int(state["hp"]),
		"tokenAtEnd": int(state["accounts"][role_id]["token"]),
		"rampTurns": state["audit_ramp_turns"].duplicate(),
		"rampTriggerCount": state["audit_ramp_turns"].size(),
		"restRowTurns": state["audit_rest_row_turns"].duplicate(),
		"restRowTriggerCount": state["audit_rest_row_turns"].size(),
		"reachedTurn5": bool(state["audit_reached_turn5"]),
	}


func _aggregate(records: Array) -> Dictionary:
	var aggregate := {
		"n": records.size(),
		"completed": 0,
		"ordinaryWins": 0,
		"bossWins": 0,
		"failedAt": {"ordinary": [], "boss": []},
	}
	var ordinary_turns: Array = []
	var boss_turns: Array = []
	var final_tokens: Array = []
	var rest_befores: Array = []
	var rest_wastes: Array = []
	var ordinary_recovery_wastes: Array = []
	var boss_recovery_wastes: Array = []
	var ordinary_end_tokens: Array = []
	var boss_end_tokens: Array = []
	var rest_performed_count := 0
	var ramp_turn_totals := 0
	var rest_row_totals := 0
	var battles_reached_turn5 := 0
	var battles_reached_rest_row := 0
	var boss_entry_tokens: Array = []
	for record_value in records:
		var record: Dictionary = record_value
		var ordinary: Dictionary = record["ordinary"]
		if str(ordinary["result"]) == "win":
			aggregate["ordinaryWins"] = int(aggregate["ordinaryWins"]) + 1
			ordinary_turns.append(int(ordinary["turns"]))
			ordinary_recovery_wastes.append(int(ordinary["winRecoveryWaste"]))
			ordinary_end_tokens.append(int(ordinary["tokenAtEnd"]))
		else:
			aggregate["failedAt"]["ordinary"].append(int(record["seed"]))
		ramp_turn_totals += int(ordinary["rampTriggerCount"])
		rest_row_totals += int(ordinary["restRowTriggerCount"])
		if bool(ordinary["reachedTurn5"]):
			battles_reached_turn5 += 1
		if int(ordinary["restRowTriggerCount"]) > 0:
			battles_reached_rest_row += 1
		if not record.has("boss"):
			continue
		var boss: Dictionary = record["boss"]
		boss_entry_tokens.append(int(boss.get("tokenAtEntry", 0)))
		ramp_turn_totals += int(boss["rampTriggerCount"])
		rest_row_totals += int(boss["restRowTriggerCount"])
		if bool(boss["reachedTurn5"]):
			battles_reached_turn5 += 1
		if int(boss["restRowTriggerCount"]) > 0:
			battles_reached_rest_row += 1
		if str(boss["result"]) == "win":
			aggregate["bossWins"] = int(aggregate["bossWins"]) + 1
			boss_turns.append(int(boss["turns"]))
			boss_recovery_wastes.append(int(boss["winRecoveryWaste"]))
			boss_end_tokens.append(int(boss["tokenAtEnd"]))
		else:
			aggregate["failedAt"]["boss"].append(int(record["seed"]))
		var rest: Dictionary = record["rest"]
		rest_befores.append(int(rest["before"]))
		rest_wastes.append(int(rest["waste"]))
		if bool(rest["performed"]):
			rest_performed_count += 1
		if bool(record["completed"]):
			aggregate["completed"] = int(aggregate["completed"]) + 1
			final_tokens.append(int(record["finalToken"]))
	aggregate["completionRate"] = snapped(float(aggregate["completed"]) / float(aggregate["n"]), 0.01)
	aggregate["ordinaryWinRate"] = snapped(float(aggregate["ordinaryWins"]) / float(aggregate["n"]), 0.01)
	aggregate["bossWinRate"] = snapped(float(aggregate["bossWins"]) / float(aggregate["n"]), 0.01)
	aggregate["ordinaryTurns"] = _stats(ordinary_turns)
	aggregate["bossTurns"] = _stats(boss_turns)
	aggregate["finalToken"] = _stats(final_tokens)
	aggregate["bossEntryToken"] = _stats(boss_entry_tokens)
	aggregate["rest"] = {
		"performedCount": rest_performed_count,
		"before": _stats(rest_befores),
		"waste": _stats(rest_wastes),
		"wasteSum": _sum(rest_wastes),
	}
	aggregate["winRecoveryWaste"] = {
		"ordinary": _stats(ordinary_recovery_wastes),
		"boss": _stats(boss_recovery_wastes),
		"totalSum": _sum(ordinary_recovery_wastes) + _sum(boss_recovery_wastes),
		"ordinaryEndToken": _stats(ordinary_end_tokens),
		"bossEndToken": _stats(boss_end_tokens),
		"ordinaryTruncationPotentialBattles": _count_at_least(ordinary_end_tokens, 10),
		"bossTruncationPotentialBattles": _count_at_least(boss_end_tokens, 10),
		"note": "浪费 = 应发 +3 与实际到手之差；0 token 成员本就 +0（不复起），不计入浪费；EndToken>=10 时 +3 必然被 12 上限截断",
	}
	aggregate["ramp"] = {
		"battlesReachedTurn5": battles_reached_turn5,
		"triggerTurnCount": ramp_turn_totals,
		"perBattleMean": snapped(float(ramp_turn_totals) / float(records.size() * 2), 0.01),
		"note": "turn>=5 且该回合 pattern 第一段为正时才算触发（floor((turn-1)/4) 加到第一段正伤害）",
	}
	aggregate["restRow"] = {
		"battlesReachedRestRow": battles_reached_rest_row,
		"triggerTurnCount": rest_row_totals,
		"note": "missing_attachment(HP16) 无第 4 行；submit 第 4 行 pattern=[0] 即休整行，只有战斗活到 turn 4 才会触发",
	}
	return aggregate


# ---------------------------------------------------------------- HP 边界

func _hp_bounds() -> Dictionary:
	var max_single: Dictionary = report["derived"]["maxSingleActionDamage"]
	var rows: Array = []
	for enemy_value in content["enemies"]:
		var enemy: Dictionary = enemy_value
		var hp := int(enemy["hp"])
		var row := {
			"id": str(enemy["id"]),
			"name": str(enemy["name"]),
			"hp": hp,
			"boss": bool(enemy.get("boss", false)),
			"chapter": int(enemy.get("chapter", 0)),
			"minTurnsByRoleBaseDeck": {},
			"minTurnsByRoleUpgraded": {},
			"maxTurnsBasicAttackOnly": int(ceil(float(hp) / 3.0)),
		}
		for role_id in ROLES:
			row["minTurnsByRoleBaseDeck"][role_id] = int(ceil(float(hp) / float(max_single[role_id]["baseDeckMax"])))
			row["minTurnsByRoleUpgraded"][role_id] = int(ceil(float(hp) / float(max_single[role_id]["upgradedMax"])))
		rows.append(row)
	return {
		"formula": {
			"min": "ceil(HP / 单次行动最大伤害)，保守假设每回合满状态只打一次该上限动作",
			"maxEstimate": "ceil(HP / 3)，保守假设每回合只打一次基础攻击（理论最低持续输出；现行规则允许同回合多次行动）",
		},
		"rows": rows,
	}


func _basic_only_runs() -> Dictionary:
	# 只用基础攻击（3 伤害）打每个敌人：给出实际回合与是否会被先打死
	var rows: Array = []
	for enemy_value in content["enemies"]:
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("hidden", false)) or enemy.has("stageOnly"):
			continue
		var run_state: Dictionary = rules.make_run("GPT", 11)
		var battle_seed := 4242 + int(enemy["hp"])
		var state: Dictionary = rules.start_battle(run_state, "basic-only", ["GPT"], str(enemy["id"]), battle_seed)
		while str(state["result"]) == "ongoing" and int(state["turn"]) < 40:
			rules.begin_turn(state)
			if str(state["phase"]) != "player":
				break
			rules.try_action(state, "GPT", RulesScript.BASIC_ATTACK, "GPT")
			rules.finish_turn(state)
		rows.append({
			"enemy": str(enemy["id"]),
			"hp": int(enemy["hp"]),
			"result": str(state["result"]),
			"turns": int(state["turn"]),
			"enemyHpLeft": int(state["hp"]),
			"tokenAtEnd": int(state["accounts"]["GPT"]["token"]),
			"battleSeed": battle_seed,
		})
	return {
		"scenario": "GPT 每回合只打基础攻击(3)，无卡牌、无防护/回复；用于给出理论最低输出下的生存/耗时边界（现行规则允许同回合多次行动，此处取最慢情形）",
		"rows": rows,
	}


# ---------------------------------------------------------------- 输出

func _print_summary() -> void:
	print("[AUDIT_NUMERIC] engine=", report["engine"], " dataVersion=", report["dataVersion"])
	print("[AUDIT_NUMERIC] sha docs=", report["sourceSHA256"]["docsJsonSha256"], " game=", report["sourceSHA256"]["gameJsonSha256"], " match=", report["sourceSHA256"]["docsEqualsGameData"])
	for card_value in report["derived"]["cards"]:
		var card: Dictionary = card_value
		print("[AUDIT_NUMERIC][CARD] ", card["id"], " cost=", card["cost"], " kind=", card["kind"], " base=", JSON.stringify(card["base"]), " upgraded=", JSON.stringify(card["upgraded"]))
	for role_id in ROLES:
		var max_row: Dictionary = report["derived"]["maxSingleActionDamage"][role_id]
		print("[AUDIT_NUMERIC][MAXDMG] ", role_id, " base=", max_row["baseDeckMax"], " upgraded=", max_row["upgradedMax"])
	print("[AUDIT_NUMERIC][RICE] withS1=", JSON.stringify(report["reachability"]["deepseekRice"]["withS1OnTurn1"]["turns"]), " firstS2Full=", report["reachability"]["deepseekRice"]["withS1OnTurn1"]["firstS2FullRiceTurn"])
	print("[AUDIT_NUMERIC][RICE] noS1 firstS2Full=", report["reachability"]["deepseekRice"]["withoutS1"]["firstS2FullRiceTurn"])
	print("[AUDIT_NUMERIC][STREAK] firstFullStreakTurn=", report["reachability"]["gptStreak"]["firstFullStreakTurn"], " rows=", JSON.stringify(report["reachability"]["gptStreak"]["turns"]))
	print("[AUDIT_NUMERIC][COUNTER] rows=", JSON.stringify(report["reachability"]["claudeCounter"]["turns"]))
	for role_id in ROLES:
		var aggregate: Dictionary = report["simulation"]["roles"][role_id]
		print("[AUDIT_NUMERIC][SIM] ", role_id, " completed=", aggregate["completed"], "/", aggregate["n"], " ordinaryTurns=", JSON.stringify(aggregate["ordinaryTurns"]), " bossTurns=", JSON.stringify(aggregate["bossTurns"]), " finalToken=", JSON.stringify(aggregate["finalToken"]))
		print("[AUDIT_NUMERIC][SIM-WASTE] ", role_id, " rest=", JSON.stringify(aggregate["rest"]["waste"]), " winRecovery=", JSON.stringify(aggregate["winRecoveryWaste"]), " ramp=", JSON.stringify(aggregate["ramp"]), " restRow=", JSON.stringify(aggregate["restRow"]))
	for role_id in ROLES:
		print("[AUDIT_NUMERIC][DOC] ", role_id, " record=", JSON.stringify(report["simulation"]["documentedSeeds"][role_id]))
	print("[AUDIT_NUMERIC][DETERMINISM] identical=", report["simulation"]["determinism"]["identical"])
	for row_value in report["basicOnly"]["rows"]:
		print("[AUDIT_NUMERIC][BASIC-ONLY] ", JSON.stringify(row_value))
	for row_value in report["hpBounds"]["rows"]:
		print("[AUDIT_NUMERIC][HP-BOUND] ", JSON.stringify(row_value))
	print("[AUDIT_NUMERIC] done")


func _write_json(data: Dictionary) -> void:
	var game_dir := ProjectSettings.globalize_path("res://")
	var repo_dir := game_dir.trim_suffix("/").get_base_dir()
	var out_dir := repo_dir.path_join("docs").path_join("审计")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out_path := out_dir.path_join("数值复核数据.json")
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("[AUDIT_NUMERIC] cannot write " + out_path)
		return
	file.store_string(JSON.stringify(data, "  ", true, true))
	file.close()
	print("[AUDIT_NUMERIC] wrote ", out_path, " bytes=", FileAccess.get_size(out_path))
