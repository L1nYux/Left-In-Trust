class_name StoryDB
extends RefCounted

const STORY_PATH := "res://data/story.json"
const ROLE_IDS := ["GPT", "Claude", "DeepSeek"]


static func load_story() -> Dictionary:
	var file := FileAccess.open(STORY_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open runtime story: %s" % STORY_PATH)
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Invalid runtime story JSON: %s" % parser.get_error_message())
		return {}
	var data: Dictionary = parser.data
	var by_id := {}
	for event_value in data.get("events", []):
		if typeof(event_value) == TYPE_DICTIONARY:
			var event: Dictionary = event_value
			by_id[str(event.get("id", ""))] = event
	data["eventsById"] = by_id
	return data


static func has_event(data: Dictionary, event_id: String) -> bool:
	return data.get("eventsById", {}).has(event_id)


static func compose_event(data: Dictionary, event_id: String, lineup: Array, seed: int) -> Dictionary:
	var event: Dictionary = data.get("eventsById", {}).get(event_id, {})
	if event.is_empty():
		return {}
	var pages: Array = []
	var sections: Dictionary = event.get("sections", {})
	var main_speaker := _pick_role(lineup, "%s|main|%d" % [event_id, seed])
	var partner_speaker := _pick_other_role(lineup, main_speaker, "%s|partner|%d" % [event_id, seed])
	for section_value in event.get("sectionOrder", []):
		var section := str(section_value)
		var entries: Array = sections.get(section, [])
		match section:
			"main":
				_append_speaker_line(pages, entries, main_speaker, "dialogue")
			"partner":
				if not partner_speaker.is_empty():
					_append_speaker_line(pages, entries, partner_speaker, "dialogue")
			"closing":
				_append_speaker_line(pages, entries, main_speaker, "dialogue")
			"repeat":
				pass
			"fixed", "narration":
				_append_all(pages, entries, "旁白", "fixed")
			"scene":
				_append_all(pages, entries, "旁白", "scene")
			"staging":
				# 演出段按 type 分流：暗线（reality / ending）的 staging 是可直接演的画面散文，
				# 作为「画面」页显示；其余类型（如 global.prologue）的 staging 是镜头与制作说明，
				# 只作为演出实现素材，不对玩家显示。
				if str(event.get("type", "")) in ["reality", "ending"]:
					_append_all(pages, entries, "画面", "stage")
			"branch":
				# 分支段在明线（招募）与结局里是玩家可见的走向文案；
				# reality 的 branch 是写作期规则口径（例如"可补 work_value"），不得呈现给玩家。
				if str(event.get("type", "")) != "reality":
					_append_all(pages, entries, "分支", "scene")
	return {
		"id": event_id,
		"title": str(event.get("title", event_id)),
		"type": str(event.get("type", "")),
		"knowledge": str(event.get("knowledge", "none")),
		"pages": pages,
		"see": str(event.get("see", event_id)),
		"node": str(event.get("node", "")),
		"facts": str(event.get("facts", "none"))
	}


static func compose_repeat(data: Dictionary, event_id: String, lineup: Array, seed: int) -> Dictionary:
	var event: Dictionary = data.get("eventsById", {}).get(event_id, {})
	if event.is_empty():
		return {}
	var context := _context_for_node(str(event.get("node", "idle")))
	var candidates: Array = []
	for pool_value in data.get("chatPools", []):
		if typeof(pool_value) != TYPE_DICTIONARY:
			continue
		var pool: Dictionary = pool_value
		if str(pool.get("context", "")) != context or not lineup.has(str(pool.get("character", ""))):
			continue
		var target = pool.get("target", null)
		if target != null and not lineup.has(str(target)):
			continue
		candidates.append(pool)
	var pages: Array = []
	if not candidates.is_empty():
		var pool: Dictionary = candidates[_stable_index("%s|pool|%d" % [event_id, seed], candidates.size())]
		var lines: Array = pool.get("lines", [])
		if not lines.is_empty():
			var line: Dictionary = lines[_stable_index("%s|line|%d" % [event_id, seed], lines.size())]
			pages.append({"speaker": str(line.get("speaker", "")), "text": str(line.get("text", "")), "tone": "dialogue"})
	if pages.is_empty():
		for item_value in event.get("sections", {}).get("repeat", []):
			var item: Dictionary = item_value
			if str(item.get("kind", "")) == "text":
				pages.append({"speaker": "旁白", "text": str(item.get("text", "")), "tone": "scene"})
	return {"id": event_id, "title": "再次路过 · %s" % str(event.get("title", event_id)), "pages": pages, "see": str(event.get("see", event_id))}


static func _append_speaker_line(pages: Array, entries: Array, speaker: String, tone: String) -> void:
	if speaker.is_empty():
		return
	for item_value in entries:
		var item: Dictionary = item_value
		if str(item.get("kind", "")) == "line" and str(item.get("speaker", "")) == speaker:
			pages.append({"speaker": speaker, "text": str(item.get("text", "")), "tone": tone})
			return


static func _append_all(pages: Array, entries: Array, fallback_speaker: String, tone: String) -> void:
	for item_value in entries:
		var item: Dictionary = item_value
		var text := str(item.get("text", ""))
		if text.is_empty():
			continue
		var speaker := str(item.get("speaker", fallback_speaker)) if str(item.get("kind", "")) == "line" else fallback_speaker
		pages.append({"speaker": speaker, "text": text, "tone": tone})


static func _pick_role(lineup: Array, key: String) -> String:
	var eligible: Array[String] = []
	for role_value in lineup:
		var role_id := str(role_value)
		if ROLE_IDS.has(role_id):
			eligible.append(role_id)
	if eligible.is_empty():
		return ""
	return eligible[_stable_index(key, eligible.size())]


static func _pick_other_role(lineup: Array, excluded: String, key: String) -> String:
	var eligible: Array[String] = []
	for role_value in lineup:
		var role_id := str(role_value)
		if ROLE_IDS.has(role_id) and role_id != excluded:
			eligible.append(role_id)
	if eligible.is_empty():
		return ""
	return eligible[_stable_index(key, eligible.size())]


static func _stable_index(key: String, count: int) -> int:
	if count <= 1:
		return 0
	var value := 17
	for index in key.length():
		value = posmod(value * 31 + key.unicode_at(index), 2147483647)
	return value % count


static func _context_for_node(node: String) -> String:
	match node:
		"open", "prologue": return "open"
		"N1": return "brief"
		"N2": return "check"
		"N3": return "accept"
		"B1", "B2": return "battle"
		"boss", "stageBoss", "hidden": return "boss"
		"rest": return "rest"
		"shop": return "shop"
		"event": return "event"
		"ending": return "ending"
		_: return "idle"
