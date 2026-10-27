extends Control

const DEFAULT_SEED := 20261025
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const CardArtScript = preload("res://scripts/card_art.gd")
const BattleUIDecorScript = preload("res://scripts/battle_ui_decor.gd")
const MapRouteCanvasScript = preload("res://scripts/map_route_canvas.gd")
const LifeStagesScript = preload("res://scripts/life_stages.gd")
const StoryDBScript = preload("res://scripts/story_db.gd")
const BATTLE_BACKGROUND = preload("res://assets/battle/paper_arena_placeholder.svg")
const MAP_ICONS := {
	"battle_ordinary": preload("res://assets/map_icons/route_v2/battle_ordinary.svg"),
	"battle_elite": preload("res://assets/map_icons/route_v2/battle_elite.svg"),
	"event_clue": preload("res://assets/map_icons/route_v2/event_clue.svg"),
	"rest": preload("res://assets/map_icons/route_v2/rest.svg"),
	"shop_supply": preload("res://assets/map_icons/route_v2/shop_supply.svg"),
	"recruit": preload("res://assets/map_icons/route_v2/recruit.svg"),
	"memory_clue": preload("res://assets/map_icons/route_v2/memory_clue.svg"),
	"boss_acceptance": preload("res://assets/map_icons/route_v2/boss_acceptance.svg")
}
const MAP_NODE_SIZE := 72.0
const DRAG_THRESHOLD := 7.0
const HAND_CARD_SIZE := Vector2(132, 184)
const BASIC_CARD_SIZE := Vector2(96, 138)
const DRAG_CARD_LIFT := Vector2(0, -16)
const DRAG_CARD_SCALE := Vector2(1.07, 1.07)
const MISSING_ATTACHMENT_SCENE = preload("res://scenes/enemies/MissingAttachmentActor.tscn")
const ACTOR_SCENES := {
	"GPT": preload("res://scenes/actors/GPTActor.tscn"),
	"Claude": preload("res://scenes/actors/ClaudeActor.tscn"),
	"DeepSeek": preload("res://scenes/actors/DeepSeekActor.tscn")
}
const ROLE_IDS := ["GPT", "Claude", "DeepSeek"]
const ROLE_COPY := {
	"GPT": {"tag": "连击", "color": Color("6ea8fe"), "portrait": "res://assets/actors/gpt/gpt_master_v1.png", "copy": "连续使用攻击牌，伤害逐步提高。"},
	"Claude": {"tag": "保护反击", "color": Color("fd9a5f"), "portrait": "res://assets/actors/claude/claude_master_v1.png", "copy": "防护实际挡伤后，下一次攻击强化。"},
	"DeepSeek": {"tag": "白饭", "color": Color("52d6c9"), "portrait": "res://assets/actors/deepseek/deepseek_master_v1.png", "copy": "回合末蓄积白饭，可提前兑现或满层爆发。"}
}

var content: Dictionary
var rules: GameRules
var save_manager
var run_state: Dictionary = {}
var battle_state: Dictionary = {}
var lineup: Array = []
var selected_role := ""
var selected_stage := LifeStagesScript.DEFAULT
var selected_actor := ""
var selected_target := ""
var selected_action := ""
var current_battle_kind := ""
var current_mode := "standard"
var flow := "title"
var run_seed := DEFAULT_SEED
var screen_root: VBoxContainer
var battle_root: Control
var map_root: Control
var rest_button: Button
var rest_buttons: Array[Button] = []
var rest_action_pending := false
var legal_target_cache: Dictionary = {}
var battle_log: Array[String] = []
var last_load_result: Dictionary = {"ok": false, "error": "not_found"}
var save_notice := ""
var actor_visuals: Dictionary = {}
var actor_buttons: Dictionary = {}
var last_motion_actor := ""
var last_motion_tag := ""
var enemy_visual: Control
var enemy_hit_rect: Control
var last_enemy_motion_tag := ""
# Card / drag state (STS-style: cards are dragged onto their target).
var hand_card_buttons: Dictionary = {}
var card_definitions: Dictionary = {}
var hand_layer: Control
var card_detail_panel: PanelContainer
var card_detail_title: Label
var card_detail_body: Label
var detail_action_id := ""
var drag_action_id := ""
var drag_actor := ""
var drag_origin := Vector2.ZERO
var drag_position := Vector2.ZERO
var drag_active := false
var drag_source_card: Button
var drag_card_rest: Dictionary = {}
var drag_press := Vector2.ZERO
var drag_aim: Control
var drag_legal_targets: Array = []
var drag_highlights: Array = []
var battle_hint_label: Label
var battle_hint_text := ""
var settings_overlay: Control
var settings_origin_flow := ""
var map_path_layer: Control
var story_data: Dictionary = {}
var story_overlay: Control
var story_pages: Array = []
var story_page_index := 0
var story_event_id := ""
var story_mark_seen := false
var story_sequence: Array[String] = []
var story_title_label: Label
var story_speaker_label: Label
var story_body_label: Label
var story_progress_label: Label
var story_next_button: Button


class DragAimLayer extends Control:
	var from_pos := Vector2.ZERO
	var to_pos := Vector2.ZERO
	var active := false
	var valid := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not active:
			return
		var color := Color("8ef3d8", 0.95) if valid else Color("ff9aa6", 0.9)
		var distance := from_pos.distance_to(to_pos)
		if distance <= 1.0:
			return
		# A shallow arc reads as an aimed throw rather than a straight wire.
		var control := (from_pos + to_pos) * 0.5 + Vector2(0, -clampf(distance * 0.28, 42.0, 150.0))
		var points := PackedVector2Array()
		for step in 25:
			var t := float(step) / 24.0
			points.append(from_pos.lerp(control, t).lerp(control.lerp(to_pos, t), t))
		draw_polyline(points, Color(color.r, color.g, color.b, 0.16), 18.0, true)
		draw_polyline(points, Color(color.r, color.g, color.b, 0.52), 9.0, true)
		draw_polyline(points, color, 4.0, true)
		var direction := (to_pos - points[points.size() - 2])
		if direction.length() <= 0.001:
			direction = to_pos - from_pos
		direction = direction.normalized()
		var head := 20.0
		var normal := Vector2(-direction.y, direction.x)
		var tip := to_pos + direction * 6.0
		var left := tip - direction * head + normal * (head * 0.58)
		var right := tip - direction * head - normal * (head * 0.58)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
		draw_circle(from_pos, 12.0, Color(color.r, color.g, color.b, 0.22))
		draw_circle(from_pos, 6.0, color)


func _ready() -> void:
	content = ContentDB.load_content()
	if content.is_empty():
		_show_fatal("内容数据缺失。请先在仓库根目录运行 _build\\sync_game_data.ps1。")
		return
	rules = GameRules.new(content)
	story_data = StoryDBScript.load_story()
	if story_data.is_empty():
		push_warning("剧情运行数据缺失；战斗可继续，但剧情演出已禁用。")
	run_seed = _read_seed()
	selected_stage = LifeStagesScript.normalize(_read_argument("--life-stage="))
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
	var capture_map_team := _read_argument("--capture-map-team=")
	var capture_boss_team := _read_argument("--capture-boss-team=")
	if not capture_boss_team.is_empty():
		call_deferred("_run_boss_capture_verification", capture_boss_team, _read_argument("--capture="))
	elif not capture_map_team.is_empty():
		call_deferred("_run_map_capture_verification", capture_map_team, _read_argument("--capture="))
	elif not capture_team.is_empty():
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
	_reset_story_overlay_state()
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
	margin.name = "CardContent"
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

func _new_battle_screen() -> Control:
	_reset_story_overlay_state()
	_reset_battle_interaction()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	battle_root = Control.new()
	battle_root.name = "BattleRoot"
	battle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(battle_root)
	var background := TextureRect.new()
	background.name = "PaperArenaPlaceholder"
	background.texture = BATTLE_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_root.add_child(background)
	var wash := ColorRect.new()
	wash.color = Color("07101f", 0.08)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_root.add_child(wash)
	var decor = BattleUIDecorScript.new()
	decor.name = "BattleUIDecor"
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.configure(int(battle_state.get("turn", 1)))
	battle_root.add_child(decor)
	actor_visuals.clear()
	enemy_visual = null
	return battle_root

func _new_map_screen() -> Control:
	_reset_story_overlay_state()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	map_root = Control.new()
	map_root.name = "MapRoot"
	map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map_root)
	var background := MapRouteCanvasScript.new()
	background.name = "ChapterMapBackground"
	background.configure(str(run_state.get("stage", LifeStagesScript.DEFAULT)))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_root.add_child(background)
	settings_overlay = null
	map_path_layer = background
	return map_root


func _reset_battle_interaction() -> void:
	drag_action_id = ""
	drag_actor = ""
	drag_active = false
	drag_source_card = null
	drag_card_rest.clear()
	drag_press = Vector2.ZERO
	drag_aim = null
	drag_legal_targets.clear()
	hand_card_buttons.clear()
	card_definitions.clear()
	card_detail_panel = null
	detail_action_id = ""
	actor_buttons.clear()
	enemy_hit_rect = null
	settings_overlay = null


func _reset_story_overlay_state() -> void:
	story_overlay = null
	story_pages.clear()
	story_page_index = 0
	story_event_id = ""
	story_mark_seen = false
	story_sequence.clear()
	story_title_label = null
	story_speaker_label = null
	story_body_label = null
	story_progress_label = null
	story_next_button = null


func _story_state() -> Dictionary:
	if not run_state.has("story") or typeof(run_state["story"]) != TYPE_DICTIONARY:
		run_state["story"] = {"seen": {}, "lastEvent": ""}
	var state: Dictionary = run_state["story"]
	if not state.has("seen") or typeof(state["seen"]) != TYPE_DICTIONARY:
		state["seen"] = {}
	if not state.has("lastEvent"):
		state["lastEvent"] = ""
	return state


func _story_seen(event_id: String) -> bool:
	if run_state.is_empty():
		return false
	return bool(_story_state()["seen"].get(event_id, false))


func _story_stage_id() -> String:
	var stage_id := str(run_state.get("stage", selected_stage))
	return stage_id if story_data.get("supportedStoryStages", []).has(stage_id) else ""


func _play_story_sequence(event_ids: Array, only_new: bool = true) -> void:
	if story_data.is_empty() or run_state.is_empty():
		return
	# 演出进行中又触发新序列时追加到队尾，而不是清空队列：
	# 清空会让排队未播的事件既不显示也不记账，等于静默丢弃。
	if story_overlay == null or not is_instance_valid(story_overlay):
		story_sequence.clear()
	for event_value in event_ids:
		var event_id := str(event_value)
		if not StoryDBScript.has_event(story_data, event_id):
			continue
		if only_new and _story_seen(event_id):
			continue
		if story_sequence.has(event_id):
			continue
		story_sequence.append(event_id)
	_show_next_story_event()


func _show_next_story_event() -> void:
	if story_sequence.is_empty():
		return
	# 上一段演出还开着时不要 pop：队列保留，等当前演出收起后由 _finish_story_event()
	# 再次调用本函数继续播放，避免事件被吞掉且漏记 seen。
	if story_overlay != null and is_instance_valid(story_overlay):
		return
	var event_id: String = story_sequence.pop_front()
	_show_story_event(event_id, true)


func _show_story_event(event_id: String, mark_seen: bool, repeat_visit: bool = false) -> bool:
	if story_overlay != null and is_instance_valid(story_overlay):
		return false
	var presentation: Dictionary
	if repeat_visit:
		presentation = StoryDBScript.compose_repeat(story_data, event_id, _available_lineup(), run_seed)
	else:
		presentation = StoryDBScript.compose_event(story_data, event_id, _available_lineup(), run_seed)
	if presentation.is_empty() or presentation.get("pages", []).is_empty():
		if not story_sequence.is_empty():
			call_deferred("_show_next_story_event")
		return false
	story_event_id = event_id
	story_mark_seen = mark_seen
	story_pages = presentation["pages"].duplicate(true)
	story_page_index = 0

	var overlay := Control.new()
	overlay.name = "StoryOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 300
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color("03060f", 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "StoryPanel"
	panel.position = Vector2(170, 92)
	panel.size = Vector2(940, 536)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0b1220", 0.98), Color("d7c9a8", 0.72), 22))
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	story_title_label = _label(str(presentation.get("title", event_id)), 25, Color("f2e7cd"))
	story_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(story_title_label)
	story_speaker_label = _label("", 19, Color("9ca3af"))
	box.add_child(story_speaker_label)
	var body_scroll := ScrollContainer.new()
	body_scroll.custom_minimum_size = Vector2(0, 280)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body_scroll)
	story_body_label = _label("", 25, Color("f7f4ff"))
	story_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_body_label.custom_minimum_size = Vector2(820, 260)
	story_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_scroll.add_child(story_body_label)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	story_progress_label = _label("", 14, Color("7f8aa8"))
	story_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(story_progress_label)
	var skip := _button("跳过演出", Callable(self, "_skip_story_sequence"), Color("30384f"))
	skip.name = "StorySkip"
	skip.custom_minimum_size = Vector2(132, 46)
	footer.add_child(skip)
	story_next_button = _button("继续", Callable(self, "_advance_story_page"), Color("6366f1"))
	story_next_button.name = "StoryNext"
	story_next_button.custom_minimum_size = Vector2(132, 46)
	footer.add_child(story_next_button)
	story_overlay = overlay
	_render_story_page()
	return true


func _render_story_page() -> void:
	if story_pages.is_empty() or story_page_index < 0 or story_page_index >= story_pages.size():
		return
	var page: Dictionary = story_pages[story_page_index]
	var speaker := str(page.get("speaker", "旁白"))
	story_speaker_label.text = speaker
	story_speaker_label.add_theme_color_override("font_color", ROLE_COPY[speaker]["color"] if ROLE_COPY.has(speaker) else Color("b9c1d9"))
	story_body_label.text = str(page.get("text", ""))
	story_progress_label.text = "%d / %d" % [story_page_index + 1, story_pages.size()]
	story_next_button.text = "完成" if story_page_index + 1 >= story_pages.size() else "继续"


func _advance_story_page() -> void:
	if story_page_index + 1 < story_pages.size():
		story_page_index += 1
		_render_story_page()
		return
	_finish_story_event()


func _skip_story_sequence() -> void:
	if story_mark_seen:
		_mark_story_seen(story_event_id)
		for queued_id in story_sequence:
			_mark_story_seen(queued_id)
	story_sequence.clear()
	_close_story_overlay()
	_save_story_progress_if_possible()


func _finish_story_event() -> void:
	if story_mark_seen:
		_mark_story_seen(story_event_id)
	_close_story_overlay()
	_save_story_progress_if_possible()
	if not story_sequence.is_empty():
		call_deferred("_show_next_story_event")


func _mark_story_seen(event_id: String) -> void:
	if event_id.is_empty() or run_state.is_empty():
		return
	var state := _story_state()
	state["seen"][event_id] = true
	state["lastEvent"] = event_id
	var review := get_node_or_null("MapRoot/StoryReviewButton") as Button
	if review != null:
		review.disabled = false
	var chat := get_node_or_null("MapRoot/StoryChatButton") as Button
	if chat != null:
		chat.disabled = false


func _close_story_overlay() -> void:
	if story_overlay != null and is_instance_valid(story_overlay):
		remove_child(story_overlay)
		story_overlay.queue_free()
	story_overlay = null
	story_pages.clear()
	story_page_index = 0
	story_event_id = ""
	story_mark_seen = false


func _save_story_progress_if_possible() -> void:
	if flow in ["map", "battle", "rest", "result"] and not run_state.is_empty():
		_save_progress(flow)


func _offer_map_story() -> void:
	if current_mode != "standard" or run_state.is_empty():
		return
	var ids: Array[String] = []
	var stage_id := _story_stage_id()
	if stage_id.is_empty():
		return
	var ordinary_done: bool = run_state.get("nodes", {}).get("ordinary", "") == "win"
	if not ordinary_done:
		ids.append("global.prologue")
		ids.append("ch1.report.%s.open" % stage_id)
	elif run_state.get("nodes", {}).get("boss", "") != "win":
		ids.append("ch1.report.%s.N2" % stage_id)
	_play_story_sequence(ids)


func _offer_battle_story() -> void:
	if current_mode != "standard":
		return
	var stage_id := _story_stage_id()
	if stage_id.is_empty():
		return
	if current_battle_kind == "ordinary":
		_play_story_sequence(["ch1.%s.B1" % stage_id])
	elif current_battle_kind == "boss":
		_play_story_sequence(["ch1.report.%s.N3" % stage_id, "ch1.%s.boss" % stage_id])


func _offer_rest_story() -> void:
	var stage_id := _story_stage_id()
	if current_mode == "standard" and not stage_id.is_empty():
		_play_story_sequence(["ch1.%s.rest" % stage_id])


func _offer_result_story(victory: bool) -> void:
	var stage_id := _story_stage_id()
	if current_mode != "standard" or stage_id.is_empty():
		return
	var event_id := "ch1.report.%s.success" % stage_id if victory else "ch1.%s.prepFail" % stage_id
	if not victory and current_battle_kind == "boss":
		event_id = "ch1.report.%s.acceptFail" % stage_id
	_play_story_sequence([event_id])


func _review_last_story() -> void:
	if run_state.is_empty():
		return
	var last_event := str(_story_state().get("lastEvent", ""))
	if not last_event.is_empty():
		_show_story_event(last_event, false)


func _chat_last_story() -> void:
	if run_state.is_empty():
		return
	var last_event := str(_story_state().get("lastEvent", ""))
	if not last_event.is_empty():
		_show_story_event(last_event, false, true)


func _show_title() -> void:
	flow = "title"
	_new_screen()
	_add_spacer(65)
	var eyebrow := _label("离线卡牌战术 · Demo 垂直切片", 18, Color("9ca3af"))
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
	var scope := _label("常规：路线图、1–2 人两战与休息 · 独立测试场：三人战斗", 16, Color("7f8aa8"))
	scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(scope)

func _show_role_select(reset_selection: bool = true) -> void:
	if reset_selection:
		lineup = []
		selected_stage = LifeStagesScript.DEFAULT
	_new_screen()
	var selection_header := HBoxContainer.new()
	selection_header.name = "SelectionHeader"
	selection_header.add_theme_constant_override("separation", 16)
	screen_root.add_child(selection_header)
	var title := _label("编成同行小队", 36, Color("f7f4ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_header.add_child(title)
	selection_header.add_child(_label("玩家身份", 17, Color("b5bdc8")))
	var stage_selector := OptionButton.new()
	stage_selector.name = "LifeStageSelector"
	stage_selector.custom_minimum_size = Vector2(190, 44)
	stage_selector.add_theme_font_size_override("font_size", 18)
	stage_selector.tooltip_text = "选择人生身份。当前影响地图外观，不改变 AI 技能或 token。"
	for stage_id in LifeStagesScript.IDS:
		stage_selector.add_item(LifeStagesScript.display_name(stage_id))
	stage_selector.select(LifeStagesScript.IDS.find(selected_stage))
	stage_selector.item_selected.connect(func(index: int): _select_life_stage(LifeStagesScript.IDS[index]))
	selection_header.add_child(stage_selector)
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

func _select_life_stage(stage_id: String) -> void:
	selected_stage = LifeStagesScript.normalize(stage_id)
	_show_role_select(false)

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
	current_battle_kind = ""
	battle_state = {}
	run_state = rules.make_run_for_roles(lineup, run_seed)
	if run_state.is_empty():
		_show_fatal("无法建立编队。")
		return
	run_state["stage"] = LifeStagesScript.normalize(selected_stage)
	battle_log = ["RUN seed=%d" % run_seed, "编队：%s" % " + ".join(lineup)]
	if mode == "test_arena":
		_start_battle("missing_attachment", "test_arena", run_seed ^ 0x35791)
	else:
		_save_progress("map")
		_show_map()

func _show_map() -> void:
	flow = "map"
	_new_map_screen()
	var ordinary_done: bool = run_state.get("nodes", {}).get("ordinary", "") == "win"
	var rest_done: bool = run_state.get("services", {}).has("rest")
	var boss_done: bool = run_state.get("nodes", {}).get("boss", "") == "win"

	var ink := MapRouteCanvasScript.INK
	var title := _label("第一章 · 纸页旷野", 24, ink)
	title.position = Vector2(32, 18)
	map_root.add_child(title)
	var subtitle := _label("任务路线 · %s" % LifeStagesScript.display_name(str(run_state.get("stage", LifeStagesScript.DEFAULT))), 13, Color(ink, 0.72))
	subtitle.position = Vector2(34, 51)
	map_root.add_child(subtitle)
	var party_info := _label("小队  %s" % " + ".join(lineup), 16, ink)
	party_info.position = Vector2(758, 28)
	map_root.add_child(party_info)
	var wallet := _label("算力  %d" % int(run_state.get("wallet", 0)), 16, ink)
	wallet.position = Vector2(1080, 28)
	map_root.add_child(wallet)
	var settings := _add_settings_button(map_root, Vector2(1204, 18))
	settings.add_theme_stylebox_override("normal", _panel_style(Color("707c73", 0.30), Color(ink, 0.2), 8))
	settings.add_theme_stylebox_override("hover", _panel_style(Color("c9cabe", 0.35), Color(ink, 0.6), 8))
	settings.add_theme_color_override("font_color", ink)
	settings.add_theme_color_override("font_hover_color", ink)
	map_path_layer.set_progress(ordinary_done, rest_done, boss_done)

	var endpoint := _label("终点验收", 14, Color(ink, 0.65))
	endpoint.position = Vector2(516, 117)
	endpoint.size.x = 120
	endpoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_root.add_child(endpoint)

	var ordinary_tooltip := "缺失附件 · 普通战 · HP 16"
	if ordinary_done:
		ordinary_tooltip = "缺失附件 · 普通战 · 已完成。"
	else:
		ordinary_tooltip += " / 点击开始战斗"
	_add_map_node(
		"MapOrdinary", MapRouteCanvasScript.ORDINARY, MAP_ICONS["battle_ordinary"], ordinary_tooltip,
		not ordinary_done, Callable(self, "_start_ordinary"), ordinary_done
	)
	var rest_tooltip := "休息节点 · 单人恢复 +%d" % int(content["parameters"]["restRecovery"])
	if rest_done:
		rest_tooltip = "休息节点 · 已完成。"
	elif not ordinary_done:
		rest_tooltip += " / 尚未解锁"
	else:
		rest_tooltip += " / 点击休息"
	_add_map_node(
		"MapRest", MapRouteCanvasScript.REST, MAP_ICONS["rest"], rest_tooltip,
		ordinary_done and not rest_done and not boss_done, Callable(self, "_enter_rest"), rest_done
	)
	var boss_tooltip := "本次提交版 · 终点验收 · HP 30"
	if boss_done:
		boss_tooltip = "本次提交版 · 已完成。"
	elif not ordinary_done:
		boss_tooltip += " / 尚未解锁"
	else:
		boss_tooltip += " / 点击开始验收"
	_add_map_node(
		"MapBoss", MapRouteCanvasScript.BOSS, MAP_ICONS["boss_acceptance"], boss_tooltip,
		ordinary_done and not boss_done, Callable(self, "_start_boss"), boss_done
	)

	var optional := _label("可选休息", 13, Color(ink, 0.64))
	optional.position = MapRouteCanvasScript.REST + Vector2(-129, -9)
	optional.size.x = 90
	optional.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	optional.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(optional)
	_add_map_legend()
	var route_hint := _label("选择圈起的节点继续", 14, Color(ink, 0.76))
	route_hint.position = Vector2(34, 615)
	map_root.add_child(route_hint)
	var team_parts: Array[String] = []
	for role_id_value in lineup:
		var role_id := str(role_id_value)
		var account: Dictionary = run_state["accounts"][role_id]
		team_parts.append("%s %d/%d" % [role_id, account["token"], account["max"]])
	var team_status := _label("TOKEN  %s" % "  ·  ".join(team_parts), 14, ink)
	team_status.position = Vector2(32, 681)
	map_root.add_child(team_status)
	var review := _button("回看最近剧情", Callable(self, "_review_last_story"), Color("707c73", 0.72))
	review.name = "StoryReviewButton"
	review.position = Vector2(1044, 652)
	review.size = Vector2(158, 42)
	review.disabled = str(_story_state().get("lastEvent", "")).is_empty()
	map_root.add_child(review)
	var chat := _button("旅途闲聊", Callable(self, "_chat_last_story"), Color("707c73", 0.72))
	chat.name = "StoryChatButton"
	chat.position = Vector2(870, 652)
	chat.size = Vector2(158, 42)
	chat.disabled = review.disabled
	map_root.add_child(chat)
	call_deferred("_offer_map_story")


func _add_map_node(node_name: String, center: Vector2, icon: Texture2D, tooltip_text: String, enabled: bool, callback: Callable, completed: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = ""
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	button.position = center - Vector2(MAP_NODE_SIZE, MAP_NODE_SIZE) * 0.5
	button.size = Vector2(MAP_NODE_SIZE, MAP_NODE_SIZE)
	button.custom_minimum_size = button.size
	button.pivot_offset = button.size * 0.5
	button.tooltip_text = tooltip_text
	button.disabled = not enabled
	button.add_theme_stylebox_override("normal", _map_node_style(Color(1, 1, 1, 0), Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _map_node_style(Color("f2efe7", 0.25), Color("303b38", 0.45)))
	button.add_theme_stylebox_override("pressed", _map_node_style(Color("303b38", 0.09), Color("303b38", 0.65)))
	button.add_theme_stylebox_override("disabled", _map_node_style(Color(1, 1, 1, 0), Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("focus", _map_node_style(Color(1, 1, 1, 0), Color("303b38", 0.72)))
	if node_name == "MapBoss":
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 4
			style.content_margin_bottom = 4
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_focus_color", Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.72 if completed else 0.46))
	button.set_meta("completed", completed)
	button.pressed.connect(callback)
	map_root.add_child(button)
	return button


func _map_node_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(fill, border, 36)
	style.set_border_width_all(1)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	return style


func _add_map_legend() -> void:
	var ink := MapRouteCanvasScript.INK
	var legend := Control.new()
	legend.name = "MapLegend"
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(legend)
	var title := _label("路线图例", 17, ink)
	title.position = Vector2(978, 248)
	legend.add_child(title)
	# Only the three room types present in this run appear here.
	var entries := [["battle_ordinary", "普通战斗"], ["rest", "休息"], ["boss_acceptance", "终点验收"]]
	for index in entries.size():
		var at := Vector2(974, 306 + index * 44)
		var symbol := TextureRect.new()
		symbol.name = "LegendIcon_%d" % index
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.texture = MAP_ICONS[entries[index][0]]
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(symbol)
		symbol.position = at
		symbol.size = Vector2(30, 30)
		var caption := _label(str(entries[index][1]), 16, ink)
		caption.position = at + Vector2(42, 4)
		legend.add_child(caption)

func _start_ordinary() -> void:
	_start_battle("missing_attachment", "ordinary", run_seed ^ 0x13579)


func _add_settings_button(parent: Control, at_position: Vector2) -> Button:
	var button := Button.new()
	button.name = "SettingsButton"
	button.text = "Ⅱ"
	button.tooltip_text = "暂停 / 设置"
	button.position = at_position
	button.size = Vector2(46, 46)
	button.custom_minimum_size = button.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("e8eefc"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("07101f", 0.82), Color("dbe7f5", 0.42), 23))
	button.add_theme_stylebox_override("hover", _panel_style(Color("13203a", 0.94), Color("dbe7f5", 0.72), 23))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("1d2b48", 0.96), Color("f2efe7", 0.85), 23))
	button.pressed.connect(_open_settings)
	parent.add_child(button)
	return button


func _open_settings() -> void:
	if settings_overlay != null and is_instance_valid(settings_overlay):
		return
	settings_origin_flow = flow
	var overlay := Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200
	add_child(overlay)
	var dim := ColorRect.new()
	dim.name = "SettingsDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color("03060f", 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.position = Vector2(410, 196)
	panel.size = Vector2(460, 328)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0a1222", 0.98), Color("dbe7f5", 0.5), 18))
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := _label("设置", 30, Color("f7f4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := _label("当前进度会先保存，再返回标题界面。", 15, Color("9ca3af"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var back := _button("返回标题界面", Callable(self, "_settings_return_to_title"), Color("a7274c"))
	back.custom_minimum_size = Vector2(0, 58)
	box.add_child(back)
	var resume := _button("继续游戏", Callable(self, "_close_settings"), Color("2f6f8f"))
	resume.custom_minimum_size = Vector2(0, 58)
	box.add_child(resume)
	var shortcut := _label("按 ESC 关闭", 13, Color("7f8aa8"))
	shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(shortcut)
	settings_overlay = overlay


func _close_settings() -> void:
	if settings_overlay != null and is_instance_valid(settings_overlay):
		remove_child(settings_overlay)
		settings_overlay.queue_free()
	settings_overlay = null


func _settings_return_to_title() -> void:
	var current_flow := flow
	_close_settings()
	if not run_state.is_empty():
		var save_flow := current_flow
		if save_flow == "battle" and battle_state.get("result", "ongoing") != "ongoing":
			save_flow = "map"
		if save_flow != "battle" and save_flow != "rest":
			save_flow = "map"
		_save_progress(save_flow)
	_show_title()


func _input(event: InputEvent) -> void:
	if story_overlay != null and is_instance_valid(story_overlay):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
			_advance_story_page()
			get_viewport().set_input_as_handled()
		return
	if settings_overlay != null and is_instance_valid(settings_overlay):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_settings()
			get_viewport().set_input_as_handled()
		return
	if flow != "battle" or battle_state.is_empty() or battle_state.get("result", "ongoing") != "ongoing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			var hit := _action_id_at_point(mouse_button.position)
			if not hit.is_empty():
				if _begin_drag(hit):
					drag_press = mouse_button.position
					drag_position = mouse_button.position
					get_viewport().set_input_as_handled()
		elif not drag_action_id.is_empty():
			_drop_drag_at(mouse_button.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not drag_action_id.is_empty():
		_update_drag((event as InputEventMouseMotion).position)


func _enter_rest() -> void:
	_save_progress("rest")
	_show_rest()

func _return_to_map() -> void:
	_save_progress("map")
	_show_map()

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
	call_deferred("_offer_battle_story")

func _ensure_selected_actor() -> void:
	var current := rules.actor_status(battle_state, selected_actor)
	if not current.is_empty() and bool(current.get("online", false)):
		return
	for actor_value in battle_state.get("actors", []):
		if bool(actor_value.get("online", false)):
			selected_actor = str(actor_value["id"])
			selected_target = selected_actor
			return
	if selected_actor.is_empty() and not battle_state.get("actors", []).is_empty():
		selected_actor = str(battle_state["actors"][0]["id"])
		selected_target = selected_actor

func _render_battle() -> void:
	_ensure_selected_actor()
	_new_battle_screen()
	_add_battle_header()
	var actors: Array = battle_state.get("actors", [])
	for index in actors.size():
		_add_actor_unit(actors[index], index, actors.size())
	_add_enemy_unit()
	_add_shared_hand()
	if not last_motion_actor.is_empty():
		call_deferred("_play_last_action_motion")
	if not last_enemy_motion_tag.is_empty():
		call_deferred("_play_last_enemy_motion")

func _add_battle_header() -> void:
	var round_label := _label("第 %d 回合" % int(battle_state["turn"]), 22, Color("f2efe7"))
	round_label.name = "RoundLabel"
	round_label.position = Vector2(28, 16)
	round_label.add_theme_constant_override("outline_size", 8)
	round_label.add_theme_color_override("font_outline_color", Color("050a14", 0.92))
	battle_root.add_child(round_label)
	_add_settings_button(battle_root, Vector2(1206, 14))

func _actor_unit_position(index: int, total: int) -> Vector2:
	if total <= 1:
		return Vector2(228, 102)
	if total == 2:
		return [Vector2(126, 122), Vector2(318, 98)][index]
	return [Vector2(54, 128), Vector2(220, 110), Vector2(386, 116)][index]

func _add_actor_unit(actor_value: Dictionary, index: int, total: int) -> void:
	var role_id := str(actor_value["id"])
	var actor: Dictionary = actor_value
	var account: Dictionary = battle_state["accounts"][role_id]
	var role_color: Color = ROLE_COPY[role_id]["color"]
	var unit := Button.new()
	unit.name = "Actor_%s" % role_id
	unit.text = role_id
	unit.position = _actor_unit_position(index, total)
	unit.size = Vector2(166, 306)
	unit.pivot_offset = unit.size * 0.5
	unit.focus_mode = Control.FOCUS_NONE
	unit.tooltip_text = "%s｜点击切换当前行动角色；把牌拖到角色身上即可释放" % role_id
	var selected_border := role_color if role_id == selected_actor else Color(0, 0, 0, 0)
	unit.add_theme_stylebox_override("normal", _panel_style(Color(role_color, 0.055) if role_id == selected_actor else Color(0, 0, 0, 0), selected_border, 22))
	unit.add_theme_stylebox_override("hover", _panel_style(Color(role_color, 0.10), Color(role_color, 0.64), 22))
	unit.add_theme_stylebox_override("pressed", _panel_style(Color(role_color, 0.16), Color("f2efe7", 0.7), 22))
	unit.add_theme_stylebox_override("disabled", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 22))
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		unit.add_theme_color_override(color_key, Color(1, 1, 1, 0))
	var captured_role := role_id
	unit.pressed.connect(func(): _on_actor_unit_pressed(captured_role))
	battle_root.add_child(unit)
	actor_buttons[role_id] = unit
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	unit.add_child(stack)
	var portrait: Control = ACTOR_SCENES[role_id].instantiate()
	portrait.name = "LayeredActor"
	portrait.custom_minimum_size = Vector2(158, 230)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(portrait)
	portrait.call("set_visual_state", role_id == selected_actor, bool(actor["online"]), false)
	var status := PanelContainer.new()
	status.custom_minimum_size = Vector2(162, 64)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_stylebox_override("panel", _panel_style(Color("07101f", 0.94), role_color if role_id == selected_actor else Color("52607a", 0.82), 8))
	stack.add_child(status)
	var status_box := VBoxContainer.new()
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_theme_constant_override("separation", 0)
	status.add_child(status_box)
	var name_label := _label(role_id, 13, role_color if bool(actor["online"]) else Color("697386"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_child(name_label)
	var token_label := _label("TOKEN %d/%d　 ◇ %d" % [account["token"], account["max"], actor["shield"]], 12, Color("f2efe7"))
	token_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	token_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_child(token_label)
	var action_state := "下线" if not bool(actor["online"]) else _passive_status(role_id, actor)
	var state_label := _label(action_state, 10, role_color if bool(actor["online"]) else Color("697386"))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_child(state_label)
	if not bool(actor["online"]):
		unit.modulate = Color(0.55, 0.58, 0.65, 0.62)
	elif role_id == selected_actor:
		var marker := _label("▼", 20, role_color)
		marker.name = "ActorMarker"
		marker.position = unit.position + Vector2(72, -24)
		marker.add_theme_constant_override("outline_size", 6)
		marker.add_theme_color_override("font_outline_color", Color("050a14", 0.95))
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		battle_root.add_child(marker)
	actor_visuals[role_id] = portrait

func _on_actor_unit_pressed(role_id: String) -> void:
	_select_actor(role_id)

func _add_enemy_unit() -> void:
	var enemy_id := str(battle_state["enemy"].get("id", "missing_attachment"))
	if enemy_id in ["missing_attachment", "submit"]:
		enemy_visual = MISSING_ATTACHMENT_SCENE.instantiate()
		enemy_visual.name = "EnemyArt"
		enemy_visual.position = Vector2(788, 64)
		enemy_visual.size = Vector2(405, 350)
		enemy_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		battle_root.add_child(enemy_visual)
		enemy_visual.call("configure", enemy_id)
	else:
		var enemy_art := TextureRect.new()
		enemy_art.name = "EnemyArt"
		enemy_art.texture = load("res://assets/enemies/submit_placeholder.svg")
		enemy_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		enemy_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_art.position = Vector2(788, 64)
		enemy_art.size = Vector2(405, 350)
		enemy_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		battle_root.add_child(enemy_art)
	var drop_zone := Control.new()
	drop_zone.name = "EnemyDropZone"
	drop_zone.position = Vector2(768, 36)
	drop_zone.size = Vector2(452, 420)
	drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_root.add_child(drop_zone)
	enemy_hit_rect = drop_zone
	var intent_panel := PanelContainer.new()
	intent_panel.position = Vector2(1006, 60)
	intent_panel.size = Vector2(160, 68)
	intent_panel.add_theme_stylebox_override("panel", _panel_style(Color("4a0c19", 0.96), Color("ff5572"), 30))
	battle_root.add_child(intent_panel)
	var intent_label := _label(_intent_stage_text(), 15, Color("fff4f5"))
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intent_panel.add_child(intent_label)
	var enemy_panel := PanelContainer.new()
	enemy_panel.position = Vector2(805, 365)
	enemy_panel.size = Vector2(380, 64)
	enemy_panel.add_theme_stylebox_override("panel", _panel_style(Color("120a14", 0.96), Color("ff5572"), 7))
	battle_root.add_child(enemy_panel)
	var enemy_box := VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 1)
	enemy_panel.add_child(enemy_box)
	var enemy_row := HBoxContainer.new()
	enemy_box.add_child(enemy_row)
	var enemy_name := _label(str(battle_state["enemy"]["name"]), 17, Color("f2efe7"))
	enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_row.add_child(enemy_name)
	var enemy_hp_text := _label("%d / %d" % [battle_state["hp"], battle_state["enemy"]["hp"]], 15, Color("ffb0ae"))
	enemy_row.add_child(enemy_hp_text)
	var hp_bar := ProgressBar.new()
	hp_bar.name = "EnemyHP"
	hp_bar.max_value = float(battle_state["enemy"]["hp"])
	hp_bar.value = float(battle_state["hp"])
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(342, 10)
	hp_bar.add_theme_stylebox_override("background", _panel_style(Color("260b13"), Color("612034"), 3))
	hp_bar.add_theme_stylebox_override("fill", _panel_style(Color("e4495e"), Color("ff7a86"), 3))
	enemy_box.add_child(hp_bar)

func _intent_stage_text() -> String:
	if battle_state["intents"].is_empty():
		return "休整\n○"
	var parts: Array[String] = []
	var target := ""
	for intent_value in battle_state["intents"]:
		parts.append(str(intent_value["raw"]))
		target = str(intent_value["target"])
	return "攻击 %s\n→ %s" % ["+".join(parts), target]

func _add_shared_hand() -> void:
	var attack_def := {
		"name": "基础攻击", "kind": "attack", "cost": 0,
		"damage": int(content["parameters"]["basicAttack"]), "id": "basic_attack"
	}
	var guard_def := {
		"name": "基础防御", "kind": "guard", "cost": 0,
		"shield": int(content["parameters"]["basicGuard"]), "target": "self", "id": "basic_guard"
	}
	var attack_card := _add_battle_card(battle_root, GameRules.BASIC_ATTACK, attack_def, true)
	attack_card.position = Vector2(24, 548)
	attack_card.set_meta("rest_position", attack_card.position)
	attack_card.set_meta("rest_z", 0)
	var guard_card := _add_battle_card(battle_root, GameRules.BASIC_GUARD, guard_def, true)
	guard_card.position = Vector2(128, 548)
	guard_card.set_meta("rest_position", guard_card.position)
	guard_card.set_meta("rest_z", 0)
	var deck_label := _label("抽 %d · 弃 %d" % [battle_state["draw"].size(), battle_state["discard"].size()], 14, Color("cbd5e6"))
	deck_label.name = "DeckCounter"
	deck_label.position = Vector2(26, 686)
	deck_label.add_theme_constant_override("outline_size", 5)
	deck_label.add_theme_color_override("font_outline_color", Color("050a14", 0.9))
	battle_root.add_child(deck_label)

	hand_layer = Control.new()
	hand_layer.name = "SharedHand"
	hand_layer.position = Vector2(0, 492)
	hand_layer.size = Vector2(1280, 228)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	battle_root.add_child(hand_layer)
	var hand_count: int = battle_state["hand"].size()
	var spacing := 106.0
	if hand_count > 5:
		spacing = maxf(72.0, 570.0 / float(hand_count - 1))
	var total_width := HAND_CARD_SIZE.x + spacing * float(maxi(hand_count - 1, 0))
	var start_x := (1280.0 - total_width) * 0.5
	for card_index in hand_count:
		var card_value = battle_state["hand"][card_index]
		var card: Dictionary = card_value
		var action_id := str(card["uid"])
		var card_button := _add_battle_card(hand_layer, action_id, rules.resolved_card(card), false)
		var center_offset := float(card_index) - float(hand_count - 1) * 0.5
		card_button.position = Vector2(start_x + float(card_index) * spacing, 10.0 + absf(center_offset) * 4.0)
		card_button.rotation = deg_to_rad(center_offset * 1.8)
		card_button.pivot_offset = Vector2(HAND_CARD_SIZE.x * 0.5, HAND_CARD_SIZE.y)
		card_button.z_index = card_index
		card_button.set_meta("rest_position", card_button.position)
		card_button.set_meta("rest_z", card_index)

	var end_turn := _button("↑", Callable(self, "_finish_turn"), Color("3c7ba3"))
	end_turn.name = "EndTurnButton"
	end_turn.tooltip_text = "发送本回合（结束回合）"
	end_turn.position = Vector2(1190, 626)
	end_turn.size = Vector2(62, 62)
	end_turn.custom_minimum_size = end_turn.size
	end_turn.add_theme_font_size_override("font_size", 31)
	end_turn.add_theme_stylebox_override("normal", _panel_style(Color("25658e", 0.96), Color("a9ddf0", 0.74), 31))
	end_turn.add_theme_stylebox_override("hover", _panel_style(Color("347fa8", 1.0), Color("d8f5ff"), 31))
	end_turn.add_theme_stylebox_override("pressed", _panel_style(Color("174c70", 1.0), Color("ffffff"), 31))
	battle_root.add_child(end_turn)

	var hint := _label(battle_hint_text, 15, Color("ffcc66"))
	hint.name = "BattleHint"
	hint.position = Vector2(330, 686)
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_color_override("font_outline_color", Color("050a14", 0.9))
	hint.visible = not battle_hint_text.is_empty()
	battle_root.add_child(hint)
	battle_hint_label = hint

	card_detail_panel = PanelContainer.new()
	card_detail_panel.name = "CardDetailPanel"
	card_detail_panel.position = Vector2(516, 354)
	card_detail_panel.size = Vector2(248, 104)
	card_detail_panel.z_index = 90
	card_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_detail_panel.visible = false
	card_detail_panel.add_theme_stylebox_override("panel", _panel_style(Color("07101f", 0.97), Color("9db2d6", 0.8), 12))
	battle_root.add_child(card_detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_box.add_theme_constant_override("separation", 6)
	card_detail_panel.add_child(detail_box)
	card_detail_title = _label("", 18, Color("f7f4ff"))
	card_detail_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_box.add_child(card_detail_title)
	card_detail_body = _label("", 15, Color("cbd5e6"))
	card_detail_body.custom_minimum_size = Vector2(218, 0)
	card_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_box.add_child(card_detail_body)

func _add_battle_card(parent: Control, action_id: String, definition: Dictionary, compact: bool) -> Button:
	var captured_action := action_id
	var owner := str(definition.get("owner", ""))
	var owner_color := Color("9aa7bd") if owner.is_empty() else Color(ROLE_COPY[owner]["color"])
	var actor_id := owner if not owner.is_empty() else selected_actor
	var actor := rules.actor_status(battle_state, actor_id)
	var legal_targets: Array = []
	if not actor.is_empty() and bool(actor.get("online", false)) and not _basic_used(actor_id, action_id):
		legal_targets = rules.legal_targets(battle_state, actor_id, action_id)
	var usable := not legal_targets.is_empty()
	var card_size := BASIC_CARD_SIZE if compact else HAND_CARD_SIZE
	var button := Button.new()
	button.name = "Card_%s" % action_id
	button.text = ""
	button.custom_minimum_size = card_size
	button.size = card_size
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.tooltip_text = str(definition["name"])
	button.disabled = not usable
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(color_key, Color(1, 1, 1, 0))
	button.add_theme_stylebox_override("normal", _panel_style(Color("f2efe7"), owner_color, 10))
	button.add_theme_stylebox_override("hover", _panel_style(Color("fffaf0"), owner_color.lightened(0.2), 10))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("e6e4df"), Color("69d7e7"), 10))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("727884"), Color("4d5466"), 10))
	button.mouse_entered.connect(func(): _show_card_detail(captured_action))
	button.mouse_exited.connect(func(): _hide_card_detail(captured_action))
	parent.add_child(button)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	button.add_child(margin)
	var stack := VBoxContainer.new()
	stack.name = "CardStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var art = CardArtScript.new()
	art.custom_minimum_size = Vector2(84, 76) if compact else Vector2(120, 108)
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.configure(str(definition.get("kind", "attack")), owner, owner_color, str(definition.get("id", "")))
	stack.add_child(art)
	var title := _label(str(definition["name"]), 13 if compact else 16, Color("111827"))
	title.name = "CardTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)
	var cost_color := Color("334155") if owner.is_empty() else owner_color.darkened(0.28)
	var cost_label := _label("token  %d" % int(definition.get("cost", 0)), 11 if compact else 12, cost_color)
	cost_label.name = "TokenCost"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(cost_label)
	hand_card_buttons[action_id] = button
	card_definitions[action_id] = definition
	return button

# ---- Card hover / drag-to-target (Slay the Spire style) ----

func _effect_text(definition: Dictionary) -> String:
	var parts: Array[String] = []
	if int(definition.get("damage", 0)) > 0:
		parts.append("伤害 %d" % int(definition.get("damage", 0)))
	if int(definition.get("shield", 0)) > 0:
		parts.append("防护 %d" % int(definition.get("shield", 0)))
	if int(definition.get("heal", 0)) > 0:
		parts.append("恢复 %d" % int(definition.get("heal", 0)))
	if int(definition.get("riceGain", 0)) > 0:
		parts.append("白饭 +%d" % int(definition.get("riceGain", 0)))
	if bool(definition.get("cashRice", false)):
		parts.append("兑现白饭")
	if str(definition.get("kind", "")) == "transfer":
		parts.append("转移额度")
	if parts.is_empty():
		parts.append("无直接数值效果")
	return " · ".join(parts)

func _compact_effect_text(definition: Dictionary) -> String:
	var parts: Array[String] = []
	if int(definition.get("damage", 0)) > 0:
		parts.append("伤害%d" % int(definition.get("damage", 0)))
	if int(definition.get("shield", 0)) > 0:
		parts.append("防护%d" % int(definition.get("shield", 0)))
	var kind := str(definition.get("kind", ""))
	if kind == "transfer":
		parts.append("转交%d" % int(definition.get("heal", 0)))
	elif int(definition.get("heal", 0)) > 0:
		parts.append("恢复%d" % int(definition.get("heal", 0)))
	if int(definition.get("riceGain", 0)) > 0:
		parts.append("白饭%d" % int(definition.get("riceGain", 0)))
	if bool(definition.get("cashRice", false)):
		parts.append("兑现白饭")
	if parts.is_empty():
		parts.append("特殊效果")
	return "  ".join(parts)

func _target_hint(definition: Dictionary) -> String:
	var kind := str(definition.get("kind", "attack"))
	if kind == "attack":
		return "拖到敌人身上释放"
	if str(definition.get("target", "")) == "self":
		return "拖到自己身上释放"
	if kind == "heal":
		return "拖到友方角色身上释放（可治疗自己）"
	if kind == "transfer":
		return "拖到另一名友方角色身上释放"
	return "拖到友方角色身上释放（可给自己）"

func _basic_used(actor_id: String, action_id: String) -> bool:
	if action_id != GameRules.BASIC_ATTACK and action_id != GameRules.BASIC_GUARD:
		return false
	if battle_state.is_empty() or actor_id.is_empty():
		return false
	if rules.has_method("basic_used"):
		return bool(rules.call("basic_used", battle_state, actor_id, action_id))
	return false

func _has_legal_action(actor_id: String) -> bool:
	if battle_state.is_empty() or actor_id.is_empty():
		return false
	if rules.has_method("has_legal_action"):
		return bool(rules.call("has_legal_action", battle_state, actor_id))
	var actor := rules.actor_status(battle_state, actor_id)
	if actor.is_empty() or not bool(actor.get("online", false)):
		return false
	if bool(actor.get("acted", false)):
		return false
	var options: Array = [GameRules.BASIC_ATTACK, GameRules.BASIC_GUARD]
	for card_value in battle_state.get("hand", []):
		options.append(str(card_value["uid"]))
	for action_id_value in options:
		var action_id := str(action_id_value)
		if _basic_used(actor_id, action_id):
			continue
		if not rules.legal_targets(battle_state, actor_id, action_id).is_empty():
			return true
	return false

func _show_battle_hint(text: String) -> void:
	battle_hint_text = text
	if is_instance_valid(battle_hint_label):
		battle_hint_label.text = text
		battle_hint_label.visible = not text.is_empty()

func _show_card_detail(action_id: String) -> void:
	var definition: Dictionary = card_definitions.get(action_id, {})
	if definition.is_empty() or not is_instance_valid(card_detail_panel):
		return
	var owner := str(definition.get("owner", ""))
	detail_action_id = action_id
	card_detail_title.text = "通用" if owner.is_empty() else owner
	card_detail_body.text = _compact_effect_text(definition)
	var height := card_detail_panel.get_combined_minimum_size().y
	if height < 94.0:
		height = 94.0
	# The concise detail stays in the neutral gap between both sides instead of
	# following the hovered card and covering actor status plates.
	card_detail_panel.position = Vector2(516, 354)
	card_detail_panel.size = Vector2(248, height)
	card_detail_panel.visible = true
	_raise_card(action_id)

func _hide_card_detail(action_id: String = "") -> void:
	var target := action_id if not action_id.is_empty() else detail_action_id
	if not target.is_empty():
		_lower_card(target)
	detail_action_id = ""
	if is_instance_valid(card_detail_panel):
		card_detail_panel.visible = false

func _raise_card(action_id: String) -> void:
	var button: Button = hand_card_buttons.get(action_id)
	if not is_instance_valid(button) or not button.has_meta("rest_position"):
		return
	if detail_action_id == action_id and button.scale != Vector2.ONE:
		return
	button.position = button.get_meta("rest_position") + Vector2(0, -14)
	button.scale = Vector2(1.05, 1.05)
	button.z_index = 80

func _lower_card(action_id: String) -> void:
	var button: Button = hand_card_buttons.get(action_id)
	if not is_instance_valid(button) or not button.has_meta("rest_position"):
		return
	button.position = button.get_meta("rest_position")
	button.scale = Vector2.ONE
	button.z_index = int(button.get_meta("rest_z", 0))

func _action_id_at_point(point: Vector2) -> String:
	var best := ""
	var best_z := -99999
	for action_id_value in hand_card_buttons.keys():
		var button: Button = hand_card_buttons[action_id_value]
		if not is_instance_valid(button):
			continue
		if button.get_global_rect().has_point(point) and int(button.z_index) >= best_z:
			best = str(action_id_value)
			best_z = int(button.z_index)
	return best

func _enemy_drop_center() -> Vector2:
	if is_instance_valid(enemy_hit_rect):
		return enemy_hit_rect.get_global_rect().get_center()
	return Vector2(994, 246)

func _actor_drop_center(role_id: String) -> Vector2:
	var button: Button = actor_buttons.get(role_id)
	if is_instance_valid(button):
		return button.get_global_rect().get_center()
	return Vector2.ZERO

func _enemy_contains(point: Vector2) -> bool:
	return is_instance_valid(enemy_hit_rect) and enemy_hit_rect.get_global_rect().has_point(point)

func _drag_targets(action_id: String) -> Array:
	var definition: Dictionary = card_definitions.get(action_id, {})
	if definition.is_empty():
		return []
	if str(definition.get("kind", "attack")) == "attack":
		return ["enemy"]
	return rules.legal_targets(battle_state, drag_actor, action_id)

func _drag_hit_target(point: Vector2) -> String:
	var definition: Dictionary = card_definitions.get(drag_action_id, {})
	if definition.is_empty():
		return ""
	if str(definition.get("kind", "attack")) == "attack":
		return "enemy" if _enemy_contains(point) else ""
	for target_value in drag_legal_targets:
		var target_id := str(target_value)
		var button: Button = actor_buttons.get(target_id)
		if is_instance_valid(button) and button.get_global_rect().has_point(point):
			return target_id
	return ""

func _begin_drag(action_id: String) -> bool:
	if flow != "battle" or battle_state.is_empty() or battle_state.get("result", "ongoing") != "ongoing":
		return false
	var definition: Dictionary = card_definitions.get(action_id, {})
	if definition.is_empty():
		return false
	var owner := str(definition.get("owner", ""))
	var actor_id := owner if not owner.is_empty() else selected_actor
	if actor_id.is_empty():
		return false
	selected_actor = actor_id
	selected_role = actor_id
	selected_target = actor_id
	drag_actor = actor_id
	if _basic_used(actor_id, action_id):
		_show_battle_hint("该角色本回合已使用过这一基础动作。")
		return false
	var targets := rules.legal_targets(battle_state, actor_id, action_id)
	if targets.is_empty():
		_show_battle_hint("该角色本回合无法使用这张牌。")
		return false
	_hide_card_detail()
	drag_action_id = action_id
	drag_active = false
	drag_legal_targets = _drag_targets(action_id)
	_build_drag_visual(definition, actor_id)
	_highlight_drag_source(action_id, definition)
	_highlight_drag_targets(true)
	return true

func _update_drag(screen_pos: Vector2) -> void:
	if drag_action_id.is_empty():
		return
	drag_position = screen_pos
	if not drag_active and drag_press.distance_to(screen_pos) >= DRAG_THRESHOLD:
		drag_active = true
	if not drag_active:
		return
	var hit := _drag_hit_target(screen_pos)
	if is_instance_valid(drag_aim):
		drag_aim.from_pos = drag_origin
		drag_aim.to_pos = screen_pos
		drag_aim.active = true
		drag_aim.valid = not hit.is_empty()
		drag_aim.queue_redraw()
	if is_instance_valid(drag_source_card):
		drag_source_card.modulate = Color(1, 1, 1, 1) if not hit.is_empty() else Color(1, 0.9, 0.86, 1)
	_update_target_highlights(hit)

func _drop_drag_at(screen_pos: Vector2) -> bool:
	if drag_action_id.is_empty():
		return false
	drag_position = screen_pos
	if not drag_active and drag_press.distance_to(screen_pos) >= DRAG_THRESHOLD:
		drag_active = true
	var action_id := drag_action_id
	var actor_id := drag_actor
	var hit := _drag_hit_target(screen_pos)
	_clear_drag()
	if hit.is_empty():
		_show_battle_hint("请把牌拖到目标身上再松手。")
		return false
	var target_id := actor_id if hit == "enemy" else hit
	return _play_action(actor_id, action_id, target_id)

func _play_at_point(actor_id: String, action_id: String, screen_pos: Vector2) -> bool:
	if not _begin_drag(action_id):
		return false
	drag_actor = actor_id
	drag_press = drag_origin
	return _drop_drag_at(screen_pos)

func _drag_definition_kind(action_id: String) -> String:
	var definition: Dictionary = card_definitions.get(action_id, {})
	return str(definition.get("kind", "attack"))

func _drag_card_style(definition: Dictionary) -> StyleBoxFlat:
	var owner := str(definition.get("owner", ""))
	var owner_color := Color("9aa7bd") if owner.is_empty() else Color(ROLE_COPY[owner]["color"])
	var highlight := Color("ffe08a").lerp(owner_color, 0.45)
	var style := _panel_style(Color("fffaf0"), highlight, 10)
	style.set_border_width_all(5)
	return style

func _highlight_drag_source(action_id: String, definition: Dictionary) -> void:
	var card: Button = hand_card_buttons.get(action_id)
	drag_source_card = card
	drag_card_rest.clear()
	drag_press = Vector2.ZERO
	if not is_instance_valid(card):
		drag_origin = Vector2(640, 430)
		return
	drag_card_rest = {
		"position": card.position,
		"scale": card.scale,
		"z": card.z_index,
		"modulate": card.modulate,
	}
	card.add_theme_stylebox_override("normal", _drag_card_style(definition))
	card.add_theme_stylebox_override("hover", _drag_card_style(definition))
	card.add_theme_stylebox_override("pressed", _drag_card_style(definition))
	card.position = (drag_card_rest["position"] as Vector2) + DRAG_CARD_LIFT
	card.scale = DRAG_CARD_SCALE
	card.z_index = 120
	var rect := card.get_global_rect()
	drag_origin = Vector2(rect.get_center().x, rect.position.y + 54.0)

func _restore_drag_source() -> void:
	if is_instance_valid(drag_source_card) and not drag_card_rest.is_empty():
		drag_source_card.position = drag_card_rest["position"]
		drag_source_card.scale = drag_card_rest["scale"]
		drag_source_card.z_index = int(drag_card_rest["z"])
		drag_source_card.modulate = drag_card_rest["modulate"]
		var definition: Dictionary = card_definitions.get(drag_action_id, {})
		if not definition.is_empty():
			var owner := str(definition.get("owner", ""))
			var owner_color := Color("9aa7bd") if owner.is_empty() else Color(ROLE_COPY[owner]["color"])
			var normal := _panel_style(Color("f2efe7"), owner_color, 10)
			normal.set_border_width_all(1)
			drag_source_card.add_theme_stylebox_override("normal", normal)
			var hover := _panel_style(Color("fffaf0"), owner_color.lightened(0.2), 10)
			hover.set_border_width_all(1)
			drag_source_card.add_theme_stylebox_override("hover", hover)
			var pressed := _panel_style(Color("e6e4df"), Color("69d7e7"), 10)
			pressed.set_border_width_all(1)
			drag_source_card.add_theme_stylebox_override("pressed", pressed)
	drag_source_card = null
	drag_card_rest.clear()

func _build_drag_visual(definition: Dictionary, actor_id: String) -> void:
	var aim := DragAimLayer.new()
	aim.name = "DragAim"
	aim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aim.z_index = 140
	battle_root.add_child(aim)
	aim.from_pos = drag_origin
	aim.to_pos = drag_origin
	aim.active = false
	drag_aim = aim

func _update_target_highlights(hit: String) -> void:
	if hit == "enemy":
		pass
	for index in drag_highlights.size():
		var panel: Control = drag_highlights[index]
		if not is_instance_valid(panel):
			continue
		var target_id := str(panel.get_meta("target_id", ""))
		panel.modulate = Color(1, 1, 1, 1) if target_id == hit else Color(1, 1, 1, 0.35)

func _highlight_drag_targets(active: bool) -> void:
	for panel_value in drag_highlights:
		if is_instance_valid(panel_value):
			panel_value.queue_free()
	drag_highlights.clear()
	if not active:
		return
	var color := Color("ff5572") if _drag_definition_kind(drag_action_id) == "attack" else Color("7ef0d0")
	var rects: Array = []
	if _drag_definition_kind(drag_action_id) == "attack":
		rects.append({"id": "enemy", "rect": enemy_hit_rect.get_global_rect() if is_instance_valid(enemy_hit_rect) else Rect2(768, 36, 452, 420)})
	else:
		for target_value in drag_legal_targets:
			var target_id := str(target_value)
			var button: Button = actor_buttons.get(target_id)
			if is_instance_valid(button):
				rects.append({"id": target_id, "rect": button.get_global_rect()})
	for rect_value in rects:
		var info: Dictionary = rect_value
		var panel := PanelContainer.new()
		panel.name = "DropTarget_%s" % str(info["id"])
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.position = (info["rect"] as Rect2).position
		panel.size = (info["rect"] as Rect2).size
		panel.z_index = 70
		panel.set_meta("target_id", str(info["id"]))
		var style := _panel_style(Color(color.r, color.g, color.b, 0.10), color, 20)
		style.set_border_width_all(4)
		panel.add_theme_stylebox_override("panel", style)
		battle_root.add_child(panel)
		drag_highlights.append(panel)

func _clear_drag() -> void:
	for panel_value in drag_highlights:
		if is_instance_valid(panel_value):
			panel_value.queue_free()
	drag_highlights.clear()
	_restore_drag_source()
	if is_instance_valid(drag_aim):
		drag_aim.queue_free()
	drag_aim = null
	drag_action_id = ""
	drag_actor = ""
	drag_active = false
	drag_press = Vector2.ZERO
	drag_legal_targets.clear()

func _play_action(actor_id: String, action_id: String, target_id: String) -> bool:
	if battle_state.is_empty() or battle_state.get("result", "ongoing") != "ongoing":
		return false
	if action_id != GameRules.BASIC_ATTACK and action_id != GameRules.BASIC_GUARD:
		if not battle_state.get("hand", []).any(func(card): return str(card.get("uid", "")) == action_id):
			_show_battle_hint("手牌中已经没有这张牌了。")
			return false
	var owner := _action_owner(action_id)
	if not owner.is_empty():
		actor_id = owner
	if actor_id.is_empty():
		actor_id = selected_actor
	if _basic_used(actor_id, action_id):
		_show_battle_hint("该角色本回合已使用过这一基础动作。")
		return false
	var motion_tag := _motion_tag_for_action(action_id)
	var result := rules.try_action(battle_state, actor_id, action_id, target_id)
	if not result.get("ok", false):
		_show_battle_hint("不可执行：%s。" % _error_text(str(result.get("error", ""))))
		return false
	selected_actor = actor_id
	selected_role = actor_id
	selected_target = target_id
	selected_action = ""
	battle_hint_text = ""
	last_motion_actor = actor_id
	last_motion_tag = motion_tag
	last_enemy_motion_tag = "hit" if int(result.get("damage", 0)) > 0 else ""
	var note := "回合 %d：%s 使用 %s" % [int(battle_state["turn"]), actor_id, str(result.get("name", action_id))]
	if int(result.get("damage", 0)) > 0:
		note += "，造成 %d 伤害" % int(result["damage"])
	battle_log.append(note)
	if battle_state["result"] == "win":
		_complete_battle()
		return true
	_save_progress("battle")
	_render_battle()
	return true

func _play_last_action_motion() -> void:
	var actor_id := last_motion_actor
	var motion := last_motion_tag
	last_motion_actor = ""
	last_motion_tag = ""
	if actor_id.is_empty() or not actor_visuals.has(actor_id):
		return
	var actor_visual: Control = actor_visuals[actor_id]
	if not is_instance_valid(actor_visual):
		return
	actor_visual.call("play_motion", motion)


func _play_last_enemy_motion() -> void:
	var motion := last_enemy_motion_tag
	last_enemy_motion_tag = ""
	if motion.is_empty() or not is_instance_valid(enemy_visual):
		return
	enemy_visual.call("play_motion", motion)

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
	action_button.disabled = actor.is_empty() or not bool(actor.get("online", false)) or legal_targets.is_empty()
	parent.add_child(action_button)

func _select_actor(actor_id: String) -> void:
	var actor := rules.actor_status(battle_state, actor_id)
	if actor.is_empty() or not bool(actor.get("online", false)):
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

func _select_action(action_id: String) -> void:
	var owner := _action_owner(action_id)
	if not owner.is_empty():
		var owner_actor := rules.actor_status(battle_state, owner)
		if owner_actor.is_empty() or not bool(owner_actor.get("online", false)):
			return
		selected_actor = owner
		selected_role = owner
		selected_target = owner
		legal_target_cache.clear()
	selected_action = action_id
	_show_card_detail(action_id)

func _action_owner(action_id: String) -> String:
	for card_value in battle_state.get("hand", []):
		var card: Dictionary = card_value
		if str(card.get("uid", "")) == action_id:
			return str(rules.resolved_card(card).get("owner", ""))
	return ""

func _action_definition(action_id: String) -> Dictionary:
	if action_id == GameRules.BASIC_ATTACK:
		return {"kind": "attack", "damage": int(content["parameters"]["basicAttack"]), "cost": 0}
	if action_id == GameRules.BASIC_GUARD:
		return {"kind": "guard", "shield": int(content["parameters"]["basicGuard"]), "cost": 0}
	for card_value in battle_state.get("hand", []):
		var card: Dictionary = card_value
		if str(card.get("uid", "")) == action_id:
			return rules.resolved_card(card)
	return {}

func _motion_tag_for_action(action_id: String) -> String:
	var definition := _action_definition(action_id)
	var kind := str(definition.get("kind", ""))
	if kind == "transfer":
		return "transfer"
	if int(definition.get("heal", 0)) > 0:
		return "support"
	if int(definition.get("damage", 0)) > 0:
		return "heavy_attack" if int(definition.get("damage", 0)) >= 8 else "light_attack"
	if int(definition.get("shield", 0)) > 0:
		return "guard"
	return "basic"

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
	if not result["events"].is_empty():
		last_enemy_motion_tag = "attack"
	if battle_state["result"] == "loss":
		rules.settle_battle(run_state, battle_state)
		_save_progress("result")
		_show_result(false)
		return
	var begin_result := rules.begin_turn(battle_state)
	if not begin_result["ok"]:
		_show_fatal("无法开始回合：%s" % _error_text(str(begin_result["error"])))
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
		_save_progress("map")
		_show_map()
	else:
		_save_progress("result")
		_show_result(true)

func _show_rest() -> void:
	flow = "rest"
	rest_action_pending = false
	rest_button = null
	rest_buttons.clear()
	_new_screen()
	call_deferred("_offer_rest_story")
	_add_spacer(25)
	var title := _label("休息节点", 42, Color("f7f4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(title)
	if run_state.get("services", {}).has("rest"):
		screen_root.add_child(_label("本休息节点已经结算，不会再次提供恢复。", 18, Color("ffcc66")))
		var continue_button := _button("返回路线图", Callable(self, "_return_to_map"), Color("22a06b"))
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
		var onward := _button("全员满额，返回路线图", Callable(self, "_return_to_map"), Color("22a06b"))
		onward.custom_minimum_size = Vector2(430, 58)
		onward.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen_root.add_child(onward)
	else:
		var skip := _button("暂不休息，返回路线图", Callable(self, "_return_to_map"), Color("30384f"))
		skip.custom_minimum_size = Vector2(430, 50)
		skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen_root.add_child(skip)

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
	_save_progress("map")
	_show_map()

func _start_boss() -> void:
	_start_battle("submit", "boss", run_seed ^ 0x24680)

func _show_result(victory: bool) -> void:
	flow = "result"
	_new_screen()
	_add_spacer(150)
	var title := _label("委托完成" if victory else "本次交付未完成", 52, Color("63e6be") if victory else Color("ff6b8a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(title)
	_add_spacer(26)
	var team_row := HBoxContainer.new()
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	team_row.add_theme_constant_override("separation", 22)
	screen_root.add_child(team_row)
	for role_id_value in lineup:
		var role_id := str(role_id_value)
		var role_color: Color = ROLE_COPY[role_id]["color"]
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _panel_style(Color(role_color, 0.12), role_color, 14))
		var chip_box := VBoxContainer.new()
		chip_box.add_theme_constant_override("separation", 0)
		chip.add_child(chip_box)
		var name_label := _label(role_id, 26, role_color)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_box.add_child(name_label)
		team_row.add_child(chip)
	_add_spacer(64)
	var again := _button("返回标题", Callable(self, "_show_title"), Color("6366f1"))
	again.custom_minimum_size = Vector2(260, 58)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen_root.add_child(again)
	call_deferred("_offer_result_story", victory)

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
	selected_stage = LifeStagesScript.normalize(str(run_state.get("stage", LifeStagesScript.DEFAULT)))
	run_state["stage"] = selected_stage
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
	elif flow == "map":
		_show_map()
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
		"basic_used": "该角色本回合已使用过这一基础动作。",
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
	if mode == "standard":
		_start_ordinary()
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
	var shot := _read_argument("--capture-shot=")
	_begin_run_with_lineup(requested, mode)
	if mode == "standard":
		_start_ordinary()
	if battle_state.has("error"):
		print("[EXE CAPTURE] battle failed: %s" % str(battle_state["error"]))
		get_tree().quit(1)
		return
	for _frame in 3:
		await get_tree().process_frame
	if shot == "hover":
		var hover_id := GameRules.BASIC_ATTACK
		if not battle_state["hand"].is_empty():
			hover_id = str(battle_state["hand"][0]["uid"])
		_show_card_detail(hover_id)
		for _frame in 2:
			await get_tree().process_frame
	elif shot == "drag":
		var drag_id := GameRules.BASIC_ATTACK
		if not battle_state["hand"].is_empty():
			drag_id = str(battle_state["hand"][0]["uid"])
		_begin_drag(drag_id)
		_update_drag(_enemy_drop_center())
		for _frame in 2:
			await get_tree().process_frame
	elif shot == "settings":
		_open_settings()
		for _frame in 2:
			await get_tree().process_frame
	elif shot == "result":
		_show_result(true)
		for _frame in 2:
			await get_tree().process_frame
	elif shot == "result_loss":
		_show_result(false)
		for _frame in 2:
			await get_tree().process_frame
	if path.is_empty():
		print("[EXE CAPTURE] missing capture path")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[EXE CAPTURE] %s" % JSON.stringify({"ok": error == OK, "path": path, "lineup": requested, "mode": mode, "shot": shot, "error": error}))
	get_tree().quit(0 if error == OK else 1)

func _run_map_capture_verification(value: String, path: String) -> void:
	var requested: Array = []
	for role_id in value.split(",", false):
		requested.append(str(role_id))
	var shot := _read_argument("--capture-shot=")
	var capture_stage := _read_argument("--capture-stage=")
	if not capture_stage.is_empty():
		selected_stage = LifeStagesScript.normalize(capture_stage)
	_begin_run_with_lineup(requested, "standard")
	if shot == "progress":
		_start_ordinary()
		if battle_state.has("error"):
			print("[EXE MAP CAPTURE] battle failed: %s" % str(battle_state["error"]))
			get_tree().quit(1)
			return
		var first := _auto_play_current_battle()
		if first.get("result") != "win":
			print("[EXE MAP CAPTURE] ordinary battle failed: %s" % JSON.stringify(first))
			get_tree().quit(1)
			return
		if battle_state.get("phase") == "player":
			rules.finish_turn(battle_state)
		rules.settle_battle(run_state, battle_state)
		_save_progress("map")
		_show_map()
	elif shot == "settings":
		_open_settings()
	for _frame in 4:
		await get_tree().process_frame
	if path.is_empty():
		print("[EXE MAP CAPTURE] missing capture path")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[EXE MAP CAPTURE] %s" % JSON.stringify({"ok": error == OK, "path": path, "lineup": requested, "shot": shot, "error": error}))
	get_tree().quit(0 if error == OK else 1)

func _run_boss_capture_verification(value: String, path: String) -> void:
	var requested: Array = []
	for role_id in value.split(",", false):
		requested.append(str(role_id))
	var shot := _read_argument("--capture-shot=")
	_begin_run_with_lineup(requested, "standard")
	_start_ordinary()
	var first := _auto_play_current_battle()
	if first.get("result") != "win":
		print("[EXE BOSS CAPTURE] ordinary battle failed: %s" % JSON.stringify(first))
		get_tree().quit(1)
		return
	if battle_state.get("phase") == "player":
		rules.finish_turn(battle_state)
	rules.settle_battle(run_state, battle_state)
	_start_boss()
	if battle_state.has("error"):
		print("[EXE BOSS CAPTURE] boss battle failed: %s" % str(battle_state["error"]))
		get_tree().quit(1)
		return
	for _frame in 3:
		await get_tree().process_frame
	if shot == "settings":
		_open_settings()
		for _frame in 2:
			await get_tree().process_frame
	elif shot == "hover":
		var hover_id := GameRules.BASIC_ATTACK
		if not battle_state["hand"].is_empty():
			hover_id = str(battle_state["hand"][0]["uid"])
		_show_card_detail(hover_id)
		for _frame in 2:
			await get_tree().process_frame
	if path.is_empty():
		print("[EXE BOSS CAPTURE] missing capture path")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[EXE BOSS CAPTURE] %s" % JSON.stringify({"ok": error == OK, "path": path, "lineup": requested, "shot": shot, "error": error}))
	get_tree().quit(0 if error == OK else 1)

func _run_save_and_exit_verification(value: String) -> void:
	var requested: Array = []
	for role_id in value.split(",", false):
		requested.append(str(role_id))
	_begin_run_with_lineup(requested, "standard")
	_start_ordinary()
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
			if not bool(actor_value.get("online", false)):
				continue
			var actions_this_turn := 0
			while battle_state["result"] == "ongoing" and actions_this_turn < 12 and _has_legal_action(actor_id):
				var choice := _auto_choice(actor_id)
				var action: Dictionary = rules.try_action(battle_state, actor_id, str(choice["action"]), str(choice["target"]))
				if not action.get("ok", false):
					return {"result": "error", "error": action.get("error"), "turn": battle_state["turn"]}
				actions_this_turn += 1
				counts[actor_id] = int(counts.get(actor_id, 0)) + 1
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
		if _basic_used(actor_id, action_id):
			continue
		for target_id_value in rules.legal_targets(battle_state, actor_id, action_id):
			var target_id := str(target_id_value)
			var preview := rules.preview_action(battle_state, actor_id, action_id, target_id)
			var score := int(preview.get("damage", 0)) * 100 + int(preview.get("shield", 0)) * 2 + int(preview.get("heal", 0))
			if score > int(best["score"]):
				best = {"action": action_id, "target": target_id, "score": score}
	return best
