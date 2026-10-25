extends Control

const DEFAULT_SEED := 20261025
const ROLE_COPY := {
	"GPT": {"tag": "连击", "color": Color("6ea8fe"), "portrait": "res://assets/portraits/gpt_placeholder.svg", "copy": "连续使用攻击牌，伤害逐步提高。"},
	"Claude": {"tag": "保护反击", "color": Color("fd9a5f"), "portrait": "res://assets/portraits/claude_placeholder.svg", "copy": "防护实际挡伤后，下一次攻击强化。"},
	"DeepSeek": {"tag": "白饭", "color": Color("52d6c9"), "portrait": "res://assets/portraits/deepseek_placeholder.svg", "copy": "回合末蓄积白饭，可提前兑现或满层爆发。"}
}

var content: Dictionary
var rules: GameRules
var run_state: Dictionary = {}
var battle_state: Dictionary = {}
var selected_role := ""
var selected_action := ""
var current_battle_kind := ""
var run_seed := DEFAULT_SEED
var screen_root: VBoxContainer
var preview_label: Label
var confirm_button: Button
var rest_button: Button
var rest_action_pending := false
var battle_log: Array[String] = []

func _ready() -> void:
	content = ContentDB.load_content()
	if content.is_empty():
		_show_fatal("内容数据缺失。请先在仓库根目录运行 _build\\sync_game_data.ps1。")
		return
	rules = GameRules.new(content)
	run_seed = _read_seed()
	print("[未尽之托] fixed seed=%d" % run_seed)
	_show_title()

func _read_seed() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			var candidate := argument.trim_prefix("--seed=")
			if candidate.is_valid_int():
				return int(candidate)
	return DEFAULT_SEED

func _new_screen() -> VBoxContainer:
	for child in get_children():
		remove_child(child)
		child.free()
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("080b17")
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	screen_root = VBoxContainer.new()
	screen_root.add_theme_constant_override("separation", 18)
	margin.add_child(screen_root)
	return screen_root

func _show_title() -> void:
	_new_screen()
	_add_spacer(90)
	var eyebrow := _label("离线卡牌战术 · Windows 垂直切片", 18, Color("9ca3af"))
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
	_add_spacer(36)
	var start := _button("开始新的委托", Callable(self, "_show_role_select"), Color("6366f1"))
	start.custom_minimum_size = Vector2(360, 64)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen_root.add_child(start)
	var seed_note := _label("固定随机种子：%d（可用 --seed=数字 覆盖）" % run_seed, 16, Color("7f8aa8"))
	seed_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(seed_note)
	_add_spacer(40)
	var scope := _label("本切片：角色选择 → 普通战 → 休息 → Boss 战 → 结果", 17, Color("7f8aa8"))
	scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(scope)

func _show_role_select() -> void:
	_new_screen()
	var title := _label("选择本次同行者", 36, Color("f7f4ff"))
	screen_root.add_child(title)
	screen_root.add_child(_label("三人均使用同一份首批内容数据；每人拥有十二张初始牌。", 17, Color("9ca3af")))
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 18)
	screen_root.add_child(cards)
	for role_id in ["GPT", "Claude", "DeepSeek"]:
		var info: Dictionary = ROLE_COPY[role_id]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel_style(Color(info["color"], 0.16), Color(info["color"], 0.55), 18))
		cards.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		var portrait := TextureRect.new()
		portrait.texture = load(info["portrait"])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(240, 300)
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(portrait)
		var name_label := _label(role_id, 30, info["color"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var tag := _label("被动：%s" % info["tag"], 18, Color("f7f4ff"))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tag)
		var copy := _label(info["copy"], 15, Color("bdc5d9"))
		copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(copy)
		var choose := _button("选择 %s" % role_id, func(): _begin_run(role_id), info["color"])
		box.add_child(choose)
	screen_root.add_child(_button("返回标题", Callable(self, "_show_title"), Color("30384f")))

func _begin_run(role_id: String) -> void:
	selected_role = role_id
	run_state = rules.make_run(role_id, run_seed)
	battle_log = ["RUN seed=%d", "已选择 %s：%s"]
	battle_log[0] = battle_log[0] % run_seed
	battle_log[1] = battle_log[1] % [role_id, ROLE_COPY[role_id]["tag"]]
	_start_battle("missing_attachment", "ordinary", run_seed ^ 0x13579)

func _start_battle(enemy_id: String, kind: String, battle_seed: int) -> void:
	current_battle_kind = kind
	selected_action = ""
	battle_state = rules.start_battle(run_state, kind, [selected_role], enemy_id, battle_seed)
	if battle_state.has("error"):
		_show_fatal("无法开始战斗：%s" % battle_state["error"])
		return
	print("[未尽之托] battle=%s seed=%d role=%s" % [kind, battle_seed, selected_role])
	battle_log.append("%s seed=%d" % ["普通战" if kind == "ordinary" else "Boss 战", battle_seed])
	rules.begin_turn(battle_state)
	_render_battle()

func _render_battle() -> void:
	_new_screen()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	screen_root.add_child(header)
	var encounter := "普通战" if current_battle_kind == "ordinary" else "BOSS"
	header.add_child(_pill(encounter, Color("6366f1") if current_battle_kind == "ordinary" else Color("ef476f")))
	header.add_child(_label("回合 %d" % battle_state["turn"], 20, Color("e8eaf2")))
	var seed_label := _label("seed %d" % battle_state["initial_seed"], 15, Color("7f8aa8"))
	seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(seed_label)

	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 20)
	screen_root.add_child(arena)
	var hero_panel := _status_panel()
	hero_panel.custom_minimum_size = Vector2(335, 0)
	arena.add_child(hero_panel)
	var hero_box: VBoxContainer = hero_panel.get_child(0)
	hero_box.add_child(_label(selected_role, 30, ROLE_COPY[selected_role]["color"]))
	var account: Dictionary = battle_state["accounts"][selected_role]
	var actor: Dictionary = rules.actor_status(battle_state, selected_role)
	hero_box.add_child(_label("TOKEN  %d / %d" % [account["token"], account["max"]], 24, Color("f7f4ff")))
	hero_box.add_child(_label("防护 %d   ·   %s" % [actor["shield"], "已行动" if actor["acted"] else "可行动"], 17, Color("aab2c8")))
	hero_box.add_child(_label(_passive_status(actor), 17, ROLE_COPY[selected_role]["color"]))
	hero_box.add_child(_label("支付后必须至少保留 1 token。", 14, Color("7f8aa8")))

	var enemy_panel := _status_panel()
	enemy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.add_child(enemy_panel)
	var enemy_box: VBoxContainer = enemy_panel.get_child(0)
	enemy_box.add_child(_label(str(battle_state["enemy"]["name"]), 34, Color("ff6b8a") if current_battle_kind == "boss" else Color("f7f4ff")))
	enemy_box.add_child(_label("完整度（HP）  %d / %d" % [battle_state["hp"], battle_state["enemy"]["hp"]], 24, Color("f7f4ff")))
	enemy_box.add_child(_label("锁定意图：%s" % _intent_text(), 20, Color("ffcc66")))
	enemy_box.add_child(_label("意图已在回合开始锁定；目标下线不会转火。", 14, Color("7f8aa8")))

	var actions_title := _label("本回合行动（每人一次）", 20, Color("f7f4ff"))
	screen_root.add_child(actions_title)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	screen_root.add_child(actions)
	_add_action_button(actions, GameRules.BASIC_ATTACK, "基础攻击\n费用 0 · 伤害 %d" % content["parameters"]["basicAttack"])
	_add_action_button(actions, GameRules.BASIC_GUARD, "基础防御\n费用 0 · 防护 %d" % content["parameters"]["basicGuard"])
	for card_value in battle_state["hand"]:
		var card: Dictionary = card_value
		_add_action_button(actions, str(card["uid"]), _card_button_text(card))

	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color("11172a"), Color("303a58"), 12))
	screen_root.add_child(preview_panel)
	var preview_box := HBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 18)
	preview_panel.add_child(preview_box)
	preview_label = _label("先选择一项行动；这里只预览，不会改变状态。", 16, Color("b9c1d9"))
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_box.add_child(preview_label)
	confirm_button = _button("确认执行", Callable(self, "_confirm_action"), Color("22a06b"))
	confirm_button.disabled = true
	preview_box.add_child(confirm_button)
	var end_turn := _button("结束回合 / 敌方执行意图", Callable(self, "_finish_turn"), Color("a33c5f"))
	screen_root.add_child(end_turn)
	if bool(actor["acted"]):
		preview_label.text = "本回合行动已完成。可以结束回合。"
		end_turn.grab_focus()

func _add_action_button(parent: Control, action_id: String, text: String) -> void:
	var action_button := _button(text, func(): _select_action(action_id), Color("293451"))
	action_button.custom_minimum_size = Vector2(175, 62)
	action_button.disabled = bool(rules.actor_status(battle_state, selected_role)["acted"])
	parent.add_child(action_button)

func _select_action(action_id: String) -> void:
	selected_action = action_id
	var preview := rules.preview_action(battle_state, selected_role, action_id, selected_role)
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
	preview_label.text = "%s  →  目标：%s  ｜  费用：%d  ｜  扣费后：%d token  ｜  %s" % [preview["name"], preview["target"], preview["cost"], preview["balance_after"], "，".join(effects)]
	confirm_button.disabled = false

func _confirm_action() -> void:
	if not is_instance_valid(confirm_button) or confirm_button.disabled:
		return
	confirm_button.disabled = true
	if selected_action == "":
		return
	var result := rules.try_action(battle_state, selected_role, selected_action, selected_role)
	if not result["ok"]:
		preview_label.text = "不可执行：%s。状态未改变。" % _error_text(str(result["error"]))
		confirm_button.disabled = true
		return
	var note := "回合 %d：%s" % [battle_state["turn"], result["name"]]
	if int(result["damage"]) > 0:
		note += "，造成 %d 伤害" % result["damage"]
	battle_log.append(note)
	if battle_state["result"] == "win":
		_complete_battle()
	else:
		selected_action = ""
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
			battle_log.append("锁定目标已下线，本段攻击空过。")
		else:
			battle_log.append("敌方攻击：防护吸收 %d，token 损失 %d。" % [event["absorbed"], event["lost"]])
	if battle_state["result"] == "loss":
		rules.settle_battle(run_state, battle_state)
		_show_result(false)
		return
	if battle_state["result"] != "ongoing":
		return
	var begin_result := rules.begin_turn(battle_state)
	if not begin_result["ok"]:
		_show_fatal("无法开始下一回合：%s" % _error_text(str(begin_result["error"])))
		return
	selected_action = ""
	_render_battle()

func _complete_battle() -> void:
	# finish_turn performs cleanup but sees the defeated enemy and never attacks.
	var token_before := int(battle_state["accounts"][selected_role]["token"])
	rules.finish_turn(battle_state)
	assert(int(battle_state["accounts"][selected_role]["token"]) == token_before)
	rules.settle_battle(run_state, battle_state)
	battle_log.append("敌人被击败，后续攻击立即停止；战后恢复 +%d。" % content["parameters"]["winRecovery"])
	if current_battle_kind == "ordinary":
		_show_rest()
	else:
		_show_result(true)

func _show_rest() -> void:
	rest_action_pending = false
	rest_button = null
	_new_screen()
	_add_spacer(45)
	var title := _label("休息节点", 42, Color("f7f4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(title)
	var current := int(run_state["accounts"][selected_role]["token"])
	var maximum := int(run_state["accounts"][selected_role]["max"])
	var status := _label("%s 当前 token：%d / %d" % [selected_role, current, maximum], 24, ROLE_COPY[selected_role]["color"])
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(status)
	var copy := _label("免费休息恢复 %d；回复可让 0 token 成员重新上线，且受上限截断。" % content["parameters"]["restRecovery"], 17, Color("aab2c8"))
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(copy)
	_add_spacer(26)
	if current < maximum:
		rest_button = _button("休息恢复 +%d，然后迎战 Boss" % content["parameters"]["restRecovery"], Callable(self, "_take_rest"), Color("22a06b"))
		rest_button.custom_minimum_size = Vector2(430, 64)
		rest_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen_root.add_child(rest_button)
	else:
		screen_root.add_child(_label("当前已满额；无需消耗恢复服务。", 18, Color("9ca3af")))
		var onward := _button("状态已满，迎战 Boss", Callable(self, "_start_boss"), Color("22a06b"))
		onward.custom_minimum_size = Vector2(430, 64)
		onward.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen_root.add_child(onward)

func _take_rest() -> void:
	if rest_action_pending:
		return
	rest_action_pending = true
	if is_instance_valid(rest_button):
		rest_button.disabled = true
	var result := rules.rest_recover(run_state, "rest", selected_role)
	if not result["ok"]:
		_show_fatal("休息失败：%s" % _error_text(str(result["error"])))
		return
	battle_log.append("休息恢复后：%d token。" % result["token"])
	_start_boss()

func _start_boss() -> void:
	_start_battle("submit", "boss", run_seed ^ 0x24680)

func _show_result(victory: bool) -> void:
	_new_screen()
	_add_spacer(18)
	var title := _label("委托完成" if victory else "本次交付未完成", 48, Color("63e6be") if victory else Color("ff6b8a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(title)
	var subtitle := _label("%s 已走完首个垂直切片。" % selected_role if victory else "%s 已下线，可以用相同 seed 再试一次。" % selected_role, 20, Color("d4d8e4"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(subtitle)
	var summary := _label("最终 token：%d / %d    ·    算力：%d    ·    seed：%d" % [run_state["accounts"][selected_role]["token"], run_state["accounts"][selected_role]["max"], run_state["wallet"], run_seed], 18, Color("aab2c8"))
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

func _passive_status(actor: Dictionary) -> String:
	if selected_role == "GPT":
		return "连击层数 %d / 2" % actor["streak"]
	if selected_role == "Claude":
		return "反击：%s" % ("就绪（下次攻击 +4）" if actor["counter"] else "未就绪")
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
		"action_unavailable": "本回合行动已用完",
		"not_in_hand": "卡牌不在手中",
		"wrong_owner": "专属牌只能由所属角色使用",
		"offline_target": "目标已下线",
		"self_only": "目标不合法",
		"bad_transfer": "转交目标不合法或缺口不足 2",
		"no_heal": "目标已满额",
		"personal_payment": "支付后不足 1 token",
		"run_ended": "本次委托已结束",
		"service_used": "该休息服务已使用",
		"battle_already_started": "该战斗已开始，不能重复进入"
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
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return panel

func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	screen_root.add_child(spacer)
