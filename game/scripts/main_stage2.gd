extends Control

const DEFAULT_SEED := 20261025
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const ROLE_IDS := ["GPT", "Claude", "DeepSeek"]
const ROLE_COPY := {
	"GPT": {"tag": "连击", "color": Color("6ea8fe"), "portrait": "res://assets/portraits/gpt_placeholder.svg", "copy": "连续使用攻击牌，伤害逐步提高。"},
	"Claude": {"tag": "保护反击", "color": Color("fd9a5f"), "portrait": "res://assets/portraits/claude_placeholder.svg", "copy": "防护实际挡伤后，下一次攻击强化。"},
	"DeepSeek": {"tag": "白饭", "color": Color("52d6c9"), "portrait": "res://assets/portraits/deepseek_placeholder.svg", "copy": "回合末蓄积白饭，可提前兑现或满层爆发。"}
}

var content: Dictionary
var rules: GameRules
var save_manager
var run_state: Dictionary = {}
var battle_state: Dictionary = {}
var lineup: Array = []
var selected_role := ""
var selected_actor := ""
var selected_target := ""
var selected_action := ""
var current_battle_kind := ""
var current_mode := "standard"
var flow := "title"
var run_seed := DEFAULT_SEED
var screen_root: VBoxContainer
var preview_label: Label
var confirm_button: Button
var rest_button: Button
var rest_buttons: Array[Button] = []
var rest_action_pending := false
var legal_target_cache: Dictionary = {}
var battle_log: Array[String] = []
var last_load_result: Dictionary = {"ok": false, "error": "not_found"}
var save_notice := ""

func _ready() -> void:
	content = ContentDB.load_content()
	if content.is_empty():
		_show_fatal("内容数据缺失。请先在仓库根目录运行 _build\\sync_game_data.ps1。")
		return
	rules = GameRules.new(content)
	run_seed = _read_seed()
	save_manager = SaveManagerScript.new(_read_save_path(), str(content.get("version", "0.5")))
	last_load_result = save_manager.load_snapshot()
	if last_load_result.get("recovered", false):
		save_notice = "主存档无效，已从上一有效备份恢复。"
	elif not last_load_result.get("ok", false) and last_load_result.get("error") != "not_found":
		save_notice = "存档不可用：%s。永久数据未被清空。" % _save_error_text(str(last_load_result.get("error", "invalid_save")))
	print("[未尽之托] fixed seed=%d" % run_seed)
	_show_title()
	var autoplay := _read_argument("--autoplay=")
	var save_and_exit := _read_argument("--save-and-exit=")
	var capture_team := _read_argument("--capture-team=")
	if not capture_team.is_empty():
		call_deferred("_run_capture_verification", capture_team, _read_argument("--capture="))
	elif not save_and_exit.is_empty():
		call_deferred("_run_save_and_exit_verification", save_and_exit)
	elif _has_argument("--continue-autoplay"):
		call_deferred("_run_continue_verification")
	elif not autoplay.is_empty():
		call_deferred("_run_export_verification", autoplay)

func _read_seed() -> int:
	var candidate := _read_argument("--seed=")
	return int(candidate) if candidate.is_valid_int() else DEFAULT_SEED

func _read_save_path() -> String:
	var candidate := _read_argument("--save-path=")
	return candidate if not candidate.is_empty() else "user://left_in_trust.save.json"

func _read_argument(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _has_argument(value: String) -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == value:
			return true
	return false

func _new_screen() -> VBoxContainer:
	for child in get_children():
		remove_child(child)
		# Screen transitions are often triggered by a Button.pressed callback.
		# Defer destruction until the current signal dispatch has completed.
		child.queue_free()
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("080b17")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	screen_root = VBoxContainer.new()
	screen_root.add_theme_constant_override("separation", 14)
	screen_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(screen_root)
	return screen_root

func _show_title() -> void:
	flow = "title"
	_new_screen()
	_add_spacer(65)
	var eyebrow := _label("离线卡牌战术 · Windows 阶段二", 18, Color("9ca3af"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(eyebrow)
	var title := _label("未尽之托", 68, Color("f7f4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(title)
	var english_title := _label(str(content.get("titleEn", "Left in Trust")), 20, Color("7f8aa8"))
	english_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(english_title)
	var subtitle := _label("把有限的 token，花在真正值得完成的事上。", 24, Color("b9c1d9"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(subtitle)
	_add_spacer(22)
	if last_load_result.get("ok", false):
		var continue_button := _button("继续上次委托", Callable(self, "_continue_saved_run"), Color("22a06b"))
		continue_button.custom_minimum_size = Vector2(360, 58)
		continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen_root.add_child(continue_button)
	var start := _button("开始新的委托", Callable(self, "_show_role_select"), Color("6366f1"))
	start.custom_minimum_size = Vector2(360, 58)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen_root.add_child(start)
	if not save_notice.is_empty():
		var notice := _label(save_notice, 16, Color("ffcc66"))
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		screen_root.add_child(notice)
	var seed_note := _label("固定随机种子：%d（可用 --seed=数字 覆盖）" % run_seed, 15, Color("7f8aa8"))
	seed_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(seed_note)
	var scope := _label("常规：1–2 人两战与休息 · 独立测试场：三人战斗", 16, Color("7f8aa8"))
	scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(scope)

func _show_role_select(reset_selection: bool = true) -> void:
	if reset_selection:
		lineup = []
	_new_screen()
	var title := _label("编成同行小队", 36, Color("f7f4ff"))
	screen_root.add_child(title)
	screen_root.add_child(_label("常规委托选择 1–2 人；三人只进入独立测试场。点击角色决定入队。", 17, Color("9ca3af")))
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 14)
	screen_root.add_child(cards)
	for role_id in ROLE_IDS:
		var captured_role := str(role_id)
		var info: Dictionary = ROLE_COPY[captured_role]
		var selected := lineup.has(captured_role)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel_style(Color(info["color"], 0.24 if selected else 0.10), Color(info["color"], 0.9 if selected else 0.42), 18))
		cards.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		var portrait := TextureRect.new()
		portrait.texture = load(info["portrait"])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(180, 210)
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(portrait)
		var name_label := _label(captured_role, 28, info["color"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var tag := _label("被动：%s" % info["tag"], 17, Color("f7f4ff"))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tag)
		var choose := _button("移出小队" if selected else "加入小队", func(): _toggle_role(captured_role), info["color"] if not selected else Color("39415a"))
		box.add_child(choose)
	var summary := _label("当前编队：%s" % ("尚未选择" if lineup.is_empty() else " + ".join(lineup)), 19, Color("f7f4ff"))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(summary)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 14)
	screen_root.add_child(choices)
	var normal := _button("开始常规委托", func(): _begin_run_with_lineup(lineup, "standard"), Color("6366f1"))
	normal.disabled = lineup.is_empty() or lineup.size() > 2
	choices.add_child(normal)
	var test_arena := _button("进入三人独立测试场", func(): _begin_run_with_lineup(lineup, "test_arena"), Color("a33c5f"))
	test_arena.disabled = lineup.size() != 3
	choices.add_child(test_arena)
	screen_root.add_child(_button("返回标题", Callable(self, "_show_title"), Color("30384f")))

func _toggle_role(role_id: String) -> void:
	if lineup.has(role_id):
		lineup.erase(role_id)
	else:
		lineup.append(role_id)
	_show_role_select(false)

func _begin_run(role_id: String) -> void:
	_begin_run_with_lineup([role_id], "standard")

func _begin_run_with_lineup(role_ids_value: Array, mode: String) -> void:
	var role_ids := role_ids_value.duplicate()
	if role_ids.is_empty() or (mode == "standard" and role_ids.size() > 2) or (mode == "test_arena" and role_ids.size() != 3):
		_show_fatal("编队不符合当前模式。")
		return
	lineup = role_ids
	selected_role = str(lineup[0])
	selected_actor = selected_role
	selected_target = selected_role
	current_mode = mode
	run_state = rules.make_run_for_roles(lineup, run_seed)
	if run_state.is_empty():
		_show_fatal("无法建立编队。")
		return
	battle_log = ["RUN seed=%d" % run_seed, "编队：%s" % " + ".join(lineup)]
	if mode == "test_arena":
		_start_battle("submit", "test_arena", run_seed ^ 0x35791)
	else:
		_start_battle("missing_attachment", "ordinary", run_seed ^ 0x13579)

func _available_lineup() -> Array:
	var result: Array = []
	for role_id_value in lineup:
		var role_id := str(role_id_value)
		if run_state.get("accounts", {}).has(role_id) and int(run_state["accounts"][role_id]["token"]) > 0:
			result.append(role_id)
	return result

func _start_battle(enemy_id: String, kind: String, battle_seed: int) -> void:
	current_battle_kind = kind
	selected_action = ""
	legal_target_cache.clear()
	var active_lineup := _available_lineup()
	battle_state = rules.start_battle(run_state, kind, active_lineup, enemy_id, battle_seed)
	if battle_state.has("error"):
		_show_fatal("无法开始战斗：%s" % _error_text(str(battle_state["error"])))
		return
	selected_actor = str(active_lineup[0])
	selected_target = selected_actor
	print("[未尽之托] battle=%s seed=%d lineup=%s" % [kind, battle_seed, ",".join(active_lineup)])
	battle_log.append("%s seed=%d" % [_battle_label(), battle_seed])
	var begin_result := rules.begin_turn(battle_state)
	if not begin_result["ok"]:
		_show_fatal("无法开始回合：%s" % _error_text(str(begin_result["error"])))
		return
	_save_progress("battle")
	_render_battle()

func _ensure_selected_actor() -> void:
	var current := rules.actor_status(battle_state, selected_actor)
	if not current.is_empty() and bool(current.get("online", false)) and not bool(current.get("acted", false)):
		return
	for actor_value in battle_state.get("actors", []):
		if bool(actor_value.get("online", false)) and not bool(actor_value.get("acted", false)):
			selected_actor = str(actor_value["id"])
			selected_target = selected_actor
			return
	if selected_actor.is_empty() and not battle_state.get("actors", []).is_empty():
		selected_actor = str(battle_state["actors"][0]["id"])
		selected_target = selected_actor

func _render_battle() -> void:
	_ensure_selected_actor()
	_new_screen()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	screen_root.add_child(header)
	header.add_child(_pill(_battle_label(), Color("6366f1") if current_battle_kind == "ordinary" else Color("ef476f")))
	header.add_child(_label("回合 %d" % battle_state["turn"], 20, Color("e8eaf2")))
	var seed_label := _label("seed %d" % battle_state["initial_seed"], 15, Color("7f8aa8"))
	seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(seed_label)
	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 10)
	screen_root.add_child(arena)
	for actor_value in battle_state["actors"]:
		var actor: Dictionary = actor_value
		var role_id := str(actor["id"])
		var account: Dictionary = battle_state["accounts"][role_id]
		var hero_panel := _status_panel()
		hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arena.add_child(hero_panel)
		var hero_box: VBoxContainer = hero_panel.get_child(0)
		hero_box.add_child(_label(role_id, 24, ROLE_COPY[role_id]["color"] if bool(actor["online"]) else Color("667085")))
		hero_box.add_child(_label("TOKEN %d / %d" % [account["token"], account["max"]], 19, Color("f7f4ff")))
		var action_state := "已下线" if not bool(actor["online"]) else ("已行动" if bool(actor["acted"]) else "可行动")
		hero_box.add_child(_label("防护 %d · %s" % [actor["shield"], action_state], 15, Color("aab2c8")))
		hero_box.add_child(_label(_passive_status(role_id, actor), 15, ROLE_COPY[role_id]["color"]))
	var enemy_panel := _status_panel()
	screen_root.add_child(enemy_panel)
	var enemy_box: VBoxContainer = enemy_panel.get_child(0)
	enemy_box.add_child(_label(str(battle_state["enemy"]["name"]), 29, Color("ff6b8a")))
	enemy_box.add_child(_label("完整度（HP） %d / %d · 锁定意图：%s" % [battle_state["hp"], battle_state["enemy"]["hp"], _intent_text()], 19, Color("ffcc66")))
	enemy_box.add_child(_label("意图在回合开始锁定；目标中途下线后，剩余段不会转火。", 14, Color("7f8aa8")))
	var actor_row := HBoxContainer.new()
	actor_row.add_theme_constant_override("separation", 8)
	screen_root.add_child(actor_row)
	actor_row.add_child(_label("行动角色", 17, Color("f7f4ff")))
	for actor_value in battle_state["actors"]:
		var actor: Dictionary = actor_value
		var actor_id := str(actor["id"])
		var captured_actor := actor_id
		var actor_button := _button(actor_id, func(): _select_actor(captured_actor), ROLE_COPY[actor_id]["color"] if actor_id == selected_actor else Color("30384f"))
		actor_button.disabled = not bool(actor["online"]) or bool(actor["acted"])
		actor_row.add_child(actor_button)
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 8)
	screen_root.add_child(target_row)
	target_row.add_child(_label("角色目标", 17, Color("f7f4ff")))
	for actor_value in battle_state["actors"]:
		var target_id := str(actor_value["id"])
		var captured_target := target_id
		var target_button := _button(target_id, func(): _select_target(captured_target), Color("47516b") if target_id == selected_target else Color("293451"))
		target_button.disabled = not bool(actor_value["online"])
		target_row.add_child(target_button)
	target_row.add_child(_label("攻击牌自动指向敌人；防护、补给与转交使用这里的角色目标。", 14, Color("7f8aa8")))
	screen_root.add_child(_label("本回合行动（每名在线角色至多一次，顺序由你决定）", 18, Color("f7f4ff")))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	screen_root.add_child(actions)
	_add_action_button(actions, GameRules.BASIC_ATTACK, "基础攻击\n费用 0 · 伤害 %d" % content["parameters"]["basicAttack"], _cached_legal_targets(GameRules.BASIC_ATTACK))
	_add_action_button(actions, GameRules.BASIC_GUARD, "基础防御\n费用 0 · 防护 %d" % content["parameters"]["basicGuard"], _cached_legal_targets(GameRules.BASIC_GUARD))
	for card_value in battle_state["hand"]:
		var card: Dictionary = card_value
		var action_id := str(card["uid"])
		_add_action_button(actions, action_id, _card_button_text(card), _cached_legal_targets(action_id))
	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color("11172a"), Color("303a58"), 12))
	screen_root.add_child(preview_panel)
	var preview_box := HBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 18)
	preview_panel.add_child(preview_box)
	preview_label = _label("选择行动角色、角色目标和行动；预览不会改变状态。", 16, Color("b9c1d9"))
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_box.add_child(preview_label)
	confirm_button = _button("确认执行", Callable(self, "_confirm_action"), Color("22a06b"))
	confirm_button.disabled = true
	preview_box.add_child(confirm_button)
	var end_turn := _button("结束回合 / 敌方执行意图", Callable(self, "_finish_turn"), Color("a33c5f"))
	screen_root.add_child(end_turn)

func _battle_label() -> String:
	if current_battle_kind == "ordinary":
		return "普通战"
	if current_battle_kind == "test_arena":
		return "三人测试场"
	return "BOSS"

func _cached_legal_targets(action_id: String) -> Array:
	var key := "%s|%s|%s|%s" % [battle_state.get("instance_id", ""), battle_state.get("turn", 0), selected_actor, action_id]
	if not legal_target_cache.has(key):
		legal_target_cache[key] = rules.legal_targets(battle_state, selected_actor, action_id)
	return legal_target_cache[key]

func _add_action_button(parent: Control, action_id: String, text: String, legal_targets: Array) -> void:
	var captured_action := action_id
	var action_button := _button(text, func(): _select_action(captured_action), Color("293451"))
	action_button.custom_minimum_size = Vector2(168, 56)
	var actor := rules.actor_status(battle_state, selected_actor)
	action_button.disabled = actor.is_empty() or bool(actor.get("acted", true)) or not bool(actor.get("online", false)) or legal_targets.is_empty()
	parent.add_child(action_button)

func _select_actor(actor_id: String) -> void:
	var actor := rules.actor_status(battle_state, actor_id)
	if actor.is_empty() or not bool(actor.get("online", false)) or bool(actor.get("acted", false)):
		return
	selected_actor = actor_id
	selected_role = actor_id
	selected_target = actor_id
	selected_action = ""
	legal_target_cache.clear()
	_render_battle()

func _select_target(target_id: String) -> void:
	var target := rules.actor_status(battle_state, target_id)
	if target.is_empty() or not bool(target.get("online", false)):
		return
	selected_target = target_id
	if selected_action.is_empty():
		_render_battle()
	else:
		_select_action(selected_action)

func _select_action(action_id: String) -> void:
	selected_action = action_id
	var preview := rules.preview_action(battle_state, selected_actor, action_id, selected_target)
	if not preview["ok"]:
		preview_label.text = "不可执行：%s。状态未改变。" % _error_text(str(preview["error"]))
		preview_label.modulate = Color("ff8fa3")
		confirm_button.disabled = true
		return
	var effects: Array[String] = []
	if int(preview["damage"]) > 0:
		effects.append("预计造成 %d 伤害" % preview["damage"])
	if int(preview["shield"]) > 0:
		effects.append("获得 %d 防护" % preview["shield"])
	if int(preview["heal"]) > 0:
		effects.append("恢复 %d token（不超过上限）" % preview["heal"])
	if int(preview["rice_gain"]) > 0:
		effects.append("白饭 +%d" % preview["rice_gain"])
	preview_label.modulate = Color.WHITE
	preview_label.text = "%s 使用 %s → 目标：%s ｜ 费用：%d ｜ 扣费后：%d token ｜ %s" % [selected_actor, preview["name"], preview["target"], preview["cost"], preview["balance_after"], "，".join(effects)]
	confirm_button.disabled = false

func _confirm_action() -> void:
	if not is_instance_valid(confirm_button) or confirm_button.disabled:
		return
	confirm_button.disabled = true
	if selected_action.is_empty():
		return
	var result := rules.try_action(battle_state, selected_actor, selected_action, selected_target)
	if not result["ok"]:
		preview_label.text = "不可执行：%s。状态未改变。" % _error_text(str(result["error"]))
		return
	var note := "回合 %d：%s 使用 %s" % [battle_state["turn"], selected_actor, result["name"]]
	if int(result["damage"]) > 0:
		note += "，造成 %d 伤害" % result["damage"]
	battle_log.append(note)
	if battle_state["result"] == "win":
		_complete_battle()
	else:
		selected_action = ""
		_save_progress("battle")
		_render_battle()

func _finish_turn() -> void:
	if battle_state.get("result") != "ongoing":
		return
	var result := rules.finish_turn(battle_state)
	if not result["ok"]:
		return
	for event_value in result["events"]:
		var event: Dictionary = event_value
		if event["skipped"]:
			battle_log.append("%s 已下线，锁定的本段攻击空过。" % event["target"])
		else:
			battle_log.append("敌方攻击 %s：防护吸收 %d，token 损失 %d。" % [event["target"], event["absorbed"], event["lost"]])
	if battle_state["result"] == "loss":
		rules.settle_battle(run_state, battle_state)
		_save_progress("result")
		_show_result(false)
		return
	var begin_result := rules.begin_turn(battle_state)
	if not begin_result["ok"]:
		_show_fatal("无法开始下一回合：%s" % _error_text(str(begin_result["error"])))
		return
	selected_action = ""
	_save_progress("battle")
	_render_battle()

func _complete_battle() -> void:
	var before_accounts: Dictionary = battle_state["accounts"].duplicate(true)
	if battle_state.get("phase") == "player":
		rules.finish_turn(battle_state)
	for role_id in before_accounts.keys():
		assert(int(battle_state["accounts"][role_id]["token"]) == int(before_accounts[role_id]["token"]))
	var settlement := rules.settle_battle(run_state, battle_state)
	if not settlement["ok"]:
		_show_fatal("战斗结算失败：%s" % _error_text(str(settlement["error"])))
		return
	battle_log.append("敌人被击败；所有正余额已入队成员（含替补）战后恢复 +%d，0 token 不复起。" % content["parameters"]["winRecovery"])
	if current_battle_kind == "ordinary":
		_save_progress("rest")
		_show_rest()
	else:
		_save_progress("result")
		_show_result(true)

func _show_rest() -> void:
	flow = "rest"
	rest_action_pending = false
	rest_button = null
	rest_buttons.clear()
	_new_screen()
	_add_spacer(25)
	var title := _label("休息节点", 42, Color("f7f4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(title)
	if run_state.get("services", {}).has("rest"):
		screen_root.add_child(_label("本休息节点已经结算，不会再次提供恢复。", 18, Color("ffcc66")))
		var continue_button := _button("继续迎战 Boss", Callable(self, "_start_boss"), Color("22a06b"))
		continue_button.custom_minimum_size = Vector2(430, 58)
		continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen_root.add_child(continue_button)
		return
	var any_recoverable := false
	for role_id_value in lineup:
		var role_id := str(role_id_value)
		var account: Dictionary = run_state["accounts"][role_id]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		screen_root.add_child(row)
		row.add_child(_label("%s  %d / %d token" % [role_id, account["token"], account["max"]], 21, ROLE_COPY[role_id]["color"]))
		if int(account["token"]) < int(account["max"]):
			any_recoverable = true
			var captured_role := role_id
			var recover := _button("选择此人恢复 +%d" % content["parameters"]["restRecovery"], func(): _take_rest(captured_role), Color("22a06b"))
			if rest_button == null:
				rest_button = recover
			rest_buttons.append(recover)
			row.add_child(recover)
	screen_root.add_child(_label("本节点只能选择一人；战外恢复允许 0 token 成员重新上线。", 16, Color("aab2c8")))
	if not any_recoverable:
		var onward := _button("全员满额，迎战 Boss", Callable(self, "_start_boss"), Color("22a06b"))
		onward.custom_minimum_size = Vector2(430, 58)
		onward.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen_root.add_child(onward)

func _take_rest(target_id: String = "") -> void:
	if rest_action_pending:
		return
	if target_id.is_empty():
		target_id = selected_actor if run_state.get("accounts", {}).has(selected_actor) else str(lineup[0])
	rest_action_pending = true
	for button in rest_buttons:
		if is_instance_valid(button):
			button.disabled = true
	var result := rules.rest_recover(run_state, "rest", target_id)
	if not result["ok"]:
		_show_fatal("休息失败：%s" % _error_text(str(result["error"])))
		return
	battle_log.append("%s 休息恢复后：%d token。" % [target_id, result["token"]])
	_start_boss()

func _start_boss() -> void:
	_start_battle("submit", "boss", run_seed ^ 0x24680)

func _show_result(victory: bool) -> void:
	flow = "result"
	_new_screen()
	_add_spacer(18)
	var title := _label("委托完成" if victory else "本次交付未完成", 48, Color("63e6be") if victory else Color("ff6b8a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(title)
	var team_summary: Array[String] = []
	for role_id_value in lineup:
		var role_id := str(role_id_value)
		var account: Dictionary = run_state["accounts"][role_id]
		team_summary.append("%s %d/%d" % [role_id, account["token"], account["max"]])
	var summary := _label("%s · 算力 %d · seed %d" % [" ｜ ".join(team_summary), run_state["wallet"], run_seed], 18, Color("aab2c8"))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(summary)
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_stylebox_override("panel", _panel_style(Color("101529"), Color("293451"), 14))
	screen_root.add_child(log_panel)
	var log_text := _label("\n".join(battle_log), 15, Color("b9c1d9"))
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_panel.add_child(log_text)
	var again := _button("返回标题", Callable(self, "_show_title"), Color("6366f1"))
	again.custom_minimum_size = Vector2(260, 58)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen_root.add_child(again)

func _snapshot() -> Dictionary:
	return {
		"contentVersion": str(content.get("version", "")),
		"runState": run_state.duplicate(true),
		"battleState": battle_state.duplicate(true),
		"lineup": lineup.duplicate(),
		"selectedActor": selected_actor,
		"selectedTarget": selected_target,
		"currentBattleKind": current_battle_kind,
		"mode": current_mode,
		"flow": flow,
		"runSeed": run_seed,
		"battleLog": battle_log.duplicate()
	}

func _save_progress(next_flow: String) -> bool:
	flow = next_flow
	var result: Dictionary = save_manager.save_snapshot(_snapshot())
	if not result["ok"]:
		save_notice = "保存失败：%s" % _save_error_text(str(result.get("error", "save_failed")))
		push_error(save_notice)
		return false
	last_load_result = {"ok": true, "snapshot": _snapshot(), "source": "primary", "recovered": false}
	save_notice = "进度已保存。"
	return true

func _continue_saved_run() -> void:
	var loaded: Dictionary = save_manager.load_snapshot()
	last_load_result = loaded
	if not loaded["ok"]:
		save_notice = "无法继续：%s。永久数据未被清空。" % _save_error_text(str(loaded.get("error", "invalid_save")))
		_show_title()
		return
	var snapshot: Dictionary = loaded["snapshot"]
	run_state = snapshot["runState"].duplicate(true)
	battle_state = snapshot["battleState"].duplicate(true)
	lineup = snapshot["lineup"].duplicate()
	selected_role = str(lineup[0])
	selected_actor = str(snapshot.get("selectedActor", selected_role))
	selected_target = str(snapshot.get("selectedTarget", selected_actor))
	selected_action = ""
	current_battle_kind = str(snapshot["currentBattleKind"])
	current_mode = str(snapshot["mode"])
	flow = str(snapshot["flow"])
	run_seed = int(snapshot["runSeed"])
	battle_log = []
	for entry in snapshot["battleLog"]:
		battle_log.append(str(entry))
	if flow == "battle":
		if battle_state.get("result") != "ongoing":
			var settlement := rules.settle_battle(run_state, battle_state)
			if not settlement["ok"]:
				_show_fatal("恢复结算失败：%s" % _error_text(str(settlement["error"])))
				return
			if battle_state["result"] == "loss":
				_save_progress("result")
				_show_result(false)
			elif current_battle_kind == "ordinary":
				_save_progress("rest")
				_show_rest()
			else:
				_save_progress("result")
				_show_result(true)
		else:
			_render_battle()
	elif flow == "rest":
		_show_rest()
	else:
		_show_result(battle_state.get("result") == "win")

func _passive_status(role_id: String, actor: Dictionary) -> String:
	if role_id == "GPT":
		return "连击 %d / 2" % actor["streak"]
	if role_id == "Claude":
		return "反击：%s" % ("就绪（+4）" if actor["counter"] else "未就绪")
	return "白饭 %d / 3" % actor["rice"]

func _intent_text() -> String:
	if battle_state["intents"].is_empty():
		return "休整（无伤害）"
	var segments: Array[String] = []
	for intent_value in battle_state["intents"]:
		segments.append("%s 受到 %d" % [intent_value["target"], intent_value["raw"]])
	return " + ".join(segments)

func _card_button_text(card: Dictionary) -> String:
	var definition: Dictionary = rules.resolved_card(card)
	return "%s\n费用 %d · %s" % [definition["name"], definition["cost"], _compact_effect(definition)]

func _compact_effect(definition: Dictionary) -> String:
	var parts: Array[String] = []
	if int(definition.get("damage", 0)) > 0:
		parts.append("伤害%d" % definition["damage"])
	if int(definition.get("shield", 0)) > 0:
		parts.append("防护%d" % definition["shield"])
	if int(definition.get("heal", 0)) > 0:
		parts.append("恢复%d" % definition["heal"])
	if int(definition.get("riceGain", 0)) > 0:
		parts.append("白饭+%d" % definition["riceGain"])
	return " / ".join(parts)

func _error_text(code: String) -> String:
	var messages := {
		"action_unavailable": "本回合行动已用完或角色已下线",
		"not_in_hand": "卡牌不在手中",
		"wrong_owner": "专属牌只能由所属角色使用",
		"offline_target": "目标已下线",
		"self_only": "目标不合法",
		"bad_transfer": "转交目标不合法或缺口不足 2",
		"no_heal": "目标已满额",
		"personal_payment": "支付后不足 1 token",
		"run_ended": "本次委托已结束",
		"service_used": "该休息服务已使用",
		"battle_already_started": "该战斗已开始，不能重复进入",
		"invalid_lineup": "当前没有可入场的健康成员"
	}
	return str(messages.get(code, code))

func _save_error_text(code: String) -> String:
	var messages := {
		"invalid_json": "JSON 已损坏",
		"checksum_mismatch": "校验值不匹配",
		"unsupported_schema": "不支持的存档 schemaVersion",
		"unsupported_content_version": "存档内容版本不兼容",
		"not_found": "没有存档",
		"temp_validation_failed": "临时文件校验失败",
		"backup_restore_failed": "上一有效备份恢复失败"
	}
	return str(messages.get(code, code))

func _show_fatal(message: String) -> void:
	_new_screen()
	_add_spacer(120)
	var label := _label(message, 24, Color("ff6b8a"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_root.add_child(label)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _panel_style(color, color.lightened(0.18), 10))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.12), color.lightened(0.35), 10))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.12), color.lightened(0.25), 10))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("202535"), Color("303548"), 10))
	button.pressed.connect(callback)
	return button

func _pill(text: String, color: Color) -> Label:
	var panel := Label.new()
	panel.text = "  %s  " % text
	panel.add_theme_font_size_override("font_size", 17)
	panel.add_theme_color_override("font_color", Color.WHITE)
	panel.add_theme_stylebox_override("normal", _panel_style(color, color.lightened(0.2), 14))
	return panel

func _status_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("101529"), Color("293451"), 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return panel

func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	screen_root.add_child(spacer)

func _run_export_verification(value: String) -> void:
	var requested: Array = []
	for role_id in value.split(",", false):
		requested.append(str(role_id))
	var mode := "test_arena" if requested.size() == 3 else "standard"
	_begin_run_with_lineup(requested, mode)
	if battle_state.has("error"):
		get_tree().quit(1)
		return
	var records: Array = []
	var first := _auto_play_current_battle()
	records.append(first)
	if first.get("result") != "win":
		print("[EXE FLOW] %s" % JSON.stringify({"completed": false, "lineup": requested, "records": records}))
		get_tree().quit(1)
		return
	if battle_state.get("phase") == "player":
		rules.finish_turn(battle_state)
	rules.settle_battle(run_state, battle_state)
	if mode == "standard":
		var rest_target := _lowest_recoverable_role()
		if not rest_target.is_empty():
			rules.rest_recover(run_state, "rest", rest_target)
		_start_battle("submit", "boss", run_seed ^ 0x24680)
		var second := _auto_play_current_battle()
		records.append(second)
		if battle_state.get("phase") == "player":
			rules.finish_turn(battle_state)
		if second.get("result") == "win":
			rules.settle_battle(run_state, battle_state)
	flow = "result"
	_save_progress("result")
	var completed := true
	for record_value in records:
		if record_value.get("result") != "win":
			completed = false
	var output := {"completed": completed, "lineup": requested, "mode": mode, "records": records, "accounts": run_state.get("accounts", {}), "wallet": run_state.get("wallet", 0), "save": save_manager.paths()["primary"]}
	print("[EXE FLOW] %s" % JSON.stringify(output))
	get_tree().quit(0 if completed else 1)

func _run_capture_verification(value: String, path: String) -> void:
	var requested: Array = []
	for role_id in value.split(",", false):
		requested.append(str(role_id))
	var mode := "test_arena" if requested.size() == 3 else "standard"
	_begin_run_with_lineup(requested, mode)
	await RenderingServer.frame_post_draw
	if path.is_empty():
		print("[EXE CAPTURE] missing capture path")
		get_tree().quit(1)
		return
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[EXE CAPTURE] %s" % JSON.stringify({"ok": error == OK, "path": path, "lineup": requested, "mode": mode, "error": error}))
	get_tree().quit(0 if error == OK else 1)

func _run_save_and_exit_verification(value: String) -> void:
	var requested: Array = []
	for role_id in value.split(",", false):
		requested.append(str(role_id))
	_begin_run_with_lineup(requested, "standard")
	if battle_state.has("error"):
		get_tree().quit(1)
		return
	var actor_id := str(requested[0])
	var choice := _auto_choice(actor_id)
	var action: Dictionary = rules.try_action(battle_state, actor_id, str(choice["action"]), str(choice["target"]))
	if not action["ok"] or not _save_progress("battle"):
		print("[EXE SAVE EXIT] %s" % JSON.stringify({"saved": false, "error": action.get("error", save_notice)}))
		get_tree().quit(1)
		return
	print("[EXE SAVE EXIT] %s" % JSON.stringify({"saved": true, "lineup": requested, "battle": battle_state["id"], "turn": battle_state["turn"], "actor": actor_id, "wallet": run_state["wallet"], "path": save_manager.paths()["primary"]}))
	get_tree().quit(0)

func _run_continue_verification() -> void:
	if not last_load_result.get("ok", false):
		print("[EXE CONTINUE] %s" % JSON.stringify({"completed": false, "error": last_load_result.get("error", "not_found")}))
		get_tree().quit(1)
		return
	_continue_saved_run()
	if flow != "battle" or battle_state.get("result") != "ongoing":
		print("[EXE CONTINUE] %s" % JSON.stringify({"completed": false, "error": "save_not_in_battle", "flow": flow}))
		get_tree().quit(1)
		return
	var records: Array = []
	var first := _auto_play_current_battle()
	records.append(first)
	if battle_state.get("phase") == "player":
		rules.finish_turn(battle_state)
	if first.get("result") == "win":
		rules.settle_battle(run_state, battle_state)
	if current_mode == "standard" and first.get("result") == "win":
		var rest_target := _lowest_recoverable_role()
		if not rest_target.is_empty():
			rules.rest_recover(run_state, "rest", rest_target)
		_start_battle("submit", "boss", run_seed ^ 0x24680)
		var second := _auto_play_current_battle()
		records.append(second)
		if battle_state.get("phase") == "player":
			rules.finish_turn(battle_state)
		if second.get("result") == "win":
			rules.settle_battle(run_state, battle_state)
	var completed := true
	for record_value in records:
		if record_value.get("result") != "win":
			completed = false
	_save_progress("result")
	print("[EXE CONTINUE] %s" % JSON.stringify({"completed": completed, "resumed": true, "lineup": lineup, "records": records, "accounts": run_state["accounts"], "wallet": run_state["wallet"], "path": save_manager.paths()["primary"]}))
	get_tree().quit(0 if completed else 1)

func _lowest_recoverable_role() -> String:
	var chosen := ""
	var lowest := 1000000
	for role_id_value in lineup:
		var role_id := str(role_id_value)
		var account: Dictionary = run_state["accounts"][role_id]
		if int(account["token"]) < int(account["max"]) and int(account["token"]) < lowest:
			chosen = role_id
			lowest = int(account["token"])
	return chosen

func _auto_play_current_battle() -> Dictionary:
	var turn_counts := {}
	while battle_state["result"] == "ongoing" and int(battle_state["turn"]) < 40:
		var counts := {}
		for actor_value in battle_state["actors"]:
			var actor_id := str(actor_value["id"])
			if not bool(actor_value["online"]) or bool(actor_value["acted"]):
				continue
			var choice := _auto_choice(actor_id)
			var action := rules.try_action(battle_state, actor_id, str(choice["action"]), str(choice["target"]))
			if not action["ok"]:
				return {"result": "error", "error": action.get("error"), "turn": battle_state["turn"]}
			counts[actor_id] = int(counts.get(actor_id, 0)) + 1
			if battle_state["result"] != "ongoing":
				break
		turn_counts[str(battle_state["turn"])] = counts
		if battle_state["result"] == "ongoing":
			rules.finish_turn(battle_state)
			if battle_state["result"] == "ongoing":
				rules.begin_turn(battle_state)
	return {"battle": current_battle_kind, "result": battle_state["result"], "turns": battle_state["turn"], "actions": turn_counts}

func _auto_choice(actor_id: String) -> Dictionary:
	var options: Array = [GameRules.BASIC_ATTACK, GameRules.BASIC_GUARD]
	for card_value in battle_state["hand"]:
		options.append(str(card_value["uid"]))
	var best := {"action": GameRules.BASIC_ATTACK, "target": actor_id, "score": -1}
	for action_id_value in options:
		var action_id := str(action_id_value)
		for target_id_value in rules.legal_targets(battle_state, actor_id, action_id):
			var target_id := str(target_id_value)
			var preview := rules.preview_action(battle_state, actor_id, action_id, target_id)
			var score := int(preview.get("damage", 0)) * 100 + int(preview.get("shield", 0)) * 2 + int(preview.get("heal", 0))
			if score > int(best["score"]):
				best = {"action": action_id, "target": target_id, "score": score}
	return best
