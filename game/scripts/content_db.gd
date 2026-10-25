class_name ContentDB
extends RefCounted

const CONTENT_PATH := "res://data/content.json"

static func load_content(path: String = CONTENT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing generated content data: %s. Run _build/sync_game_data.ps1." % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open content data: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Content data is not a JSON object: %s" % path)
		return {}
	if str(parsed.get("version", "")) != "0.5":
		push_error("Unsupported content version: %s" % parsed.get("version", "missing"))
		return {}
	return parsed
