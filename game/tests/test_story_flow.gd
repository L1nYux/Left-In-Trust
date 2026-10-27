extends SceneTree

const SaveManagerScript = preload("res://scripts/save_manager.gd")
const StoryDBScript = preload("res://scripts/story_db.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := StoryDBScript.load_story()
	if data.get("events", []).size() != 117 or data.get("chatPools", []).size() != 39:
		_fail("runtime story coverage is incomplete")
		return
	var solo := StoryDBScript.compose_event(data, "ch1.report.student.open", ["GPT"], 20261025)
	if solo.is_empty() or not _speakers_only(solo.get("pages", []), ["GPT", "旁白", "演出", "画面", "终端", "系统", "敌人", "我", "分支"]):
		_fail("solo story leaked an absent companion")
		return
	var pair := StoryDBScript.compose_event(data, "ch1.report.employee.open", ["GPT", "Claude"], 20261025)
	if pair.is_empty() or not _speakers_only(pair.get("pages", []), ["GPT", "Claude", "旁白", "演出", "画面", "终端", "系统", "敌人", "我", "分支"]):
		_fail("pair story leaked an absent companion")
		return
	var repeat := StoryDBScript.compose_repeat(data, "ch1.report.student.open", ["GPT"], 20261025)
	if repeat.get("pages", []).size() != 1 or str(repeat["pages"][0].get("speaker", "")) != "GPT":
		_fail("repeat chat did not respect the solo lineup")
		return
	for dark_value in ["ch1.report.student.success", "ch1.student.prepFail", "ch2.student.ending.eligible"]:
		var dark_id := str(dark_value)
		var dark := StoryDBScript.compose_event(data, dark_id, ["GPT", "Claude"], 20261025)
		if dark.is_empty() or str(dark.get("type", "")).is_empty():
			_fail("dark-line event did not expose its type: %s" % dark_id)
			return
		if not _has_speaker(dark.get("pages", []), "画面"):
			_fail("dark-line staging was dropped instead of shown as a stage page: %s" % dark_id)
			return
		if not _pages_are_clean(dark.get("pages", [])):
			_fail("heading or authoring note leaked into pages: %s" % dark_id)
			return
	var accept_fail := StoryDBScript.compose_event(data, "ch1.report.student.acceptFail", ["GPT", "Claude"], 20261025)
	if accept_fail.is_empty() or not _pages_are_clean(accept_fail.get("pages", [])):
		_fail("reality branch authoring notes leaked into player-facing pages")
		return

	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var save_path := ProjectSettings.globalize_path("res://../_build/test_saves/story_flow.json")
	game.save_manager = SaveManagerScript.new(save_path, str(game.content["version"]))
	game.selected_stage = "student"
	game.call("_begin_run_with_lineup", ["GPT", "Claude"], "standard")
	await process_frame
	await process_frame
	if game.get_node_or_null("StoryOverlay") == null or game.story_event_id != "global.prologue":
		_fail("new student run did not open the prologue")
		return
	# 演出进行中再触发序列：事件必须排队等待，不能被吞掉。
	game.call("_play_story_sequence", ["ch1.student.rest"])
	if not game.story_sequence.has("ch1.student.rest") or game.story_event_id != "global.prologue":
		_fail("a sequence triggered mid-presentation was dropped instead of queued")
		return
	game.call("_skip_story_sequence")
	await process_frame
	var seen: Dictionary = game.run_state.get("story", {}).get("seen", {})
	if not seen.get("global.prologue", false) or not seen.get("ch1.report.student.open", false):
		_fail("skipping the opening sequence did not persist both seen keys")
		return
	if game.get_node_or_null("StoryOverlay") != null:
		_fail("story overlay remained after skip")
		return
	var loaded: Dictionary = game.save_manager.load_snapshot()
	if not loaded.get("ok", false) or not loaded["snapshot"]["runState"].get("story", {}).get("seen", {}).get("global.prologue", false):
		_fail("story seen keys were not saved")
		return

	game.call("_start_ordinary")
	await process_frame
	await process_frame
	if game.flow != "battle" or game.story_event_id != "ch1.student.B1" or game.get_node_or_null("StoryOverlay") == null:
		_fail("ordinary battle did not present its story without changing battle flow")
		return
	game.call("_skip_story_sequence")
	await process_frame
	if not game.run_state.get("story", {}).get("seen", {}).get("ch1.student.B1", false):
		_fail("battle story seen key was not recorded")
		return
	root.remove_child(game)
	game.queue_free()
	await process_frame

	var extended = load("res://scenes/Main.tscn").instantiate()
	root.add_child(extended)
	await process_frame
	extended.save_manager = SaveManagerScript.new(ProjectSettings.globalize_path("res://../_build/test_saves/story_extended_identity.json"), str(extended.content["version"]))
	extended.selected_stage = "researcher"
	extended.call("_begin_run", "GPT")
	await process_frame
	await process_frame
	if extended.get_node_or_null("StoryOverlay") != null or not extended.story_event_id.is_empty() or not extended.story_sequence.is_empty():
		_fail("extended identity incorrectly received student/employee story")
		return
	root.remove_child(extended)
	extended.queue_free()
	await process_frame

	print("[STORY FLOW] PASS 117 events, lineup filtering, skip/save, battle overlay, identity boundary")
	quit(0)


func _speakers_only(pages: Array, allowed: Array) -> bool:
	for page_value in pages:
		if not allowed.has(str(page_value.get("speaker", ""))):
			return false
	return true


func _has_speaker(pages: Array, speaker: String) -> bool:
	for page_value in pages:
		if str(page_value.get("speaker", "")) == speaker:
			return true
	return false


# 玩家可见页不得混入 Markdown 标题或写作期规则口径（如 work_value、不授予）。
func _pages_are_clean(pages: Array) -> bool:
	var banned := ["work_value", "someone_waiting", "不授予"]
	for page_value in pages:
		var text := str(page_value.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		if text.begins_with("#"):
			return false
		for needle_value in banned:
			if text.find(str(needle_value)) >= 0:
				return false
	return true


func _fail(message: String) -> void:
	push_error("[STORY FLOW] %s" % message)
	quit(1)
