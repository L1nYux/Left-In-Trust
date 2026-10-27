class_name SaveManager
extends RefCounted

const SCHEMA_VERSION := 1
const LifeStagesScript = preload("res://scripts/life_stages.gd")

var save_path: String
var temp_path: String
var backup_path: String
var backup_temp_path: String
var content_version: String

func _init(path: String = "user://left_in_trust.save.json", expected_content_version: String = "0.5") -> void:
	save_path = path
	temp_path = "%s.tmp" % path
	backup_path = "%s.previous" % path
	backup_temp_path = "%s.previous.tmp" % path
	content_version = expected_content_version

func save_snapshot(snapshot: Dictionary) -> Dictionary:
	var payload_check := _validate_payload(snapshot)
	if not payload_check["ok"]:
		return payload_check
	var directory_result := _ensure_parent_directory()
	if not directory_result["ok"]:
		return directory_result
	var payload_json := JSON.stringify(snapshot)
	var checksum := payload_json.sha256_text()
	var envelope := {
		"schemaVersion": SCHEMA_VERSION,
		"checksumAlgorithm": "sha256",
		"checksum": checksum,
		"payloadJson": payload_json
	}
	var encoded := JSON.stringify(envelope, "  ") + "\n"
	var write_result := _write_text(temp_path, encoded)
	if not write_result["ok"]:
		return write_result
	var temp_check := _read_snapshot_file(temp_path)
	if not temp_check["ok"]:
		return {"ok": false, "error": "temp_validation_failed", "detail": temp_check.get("error", "invalid")}

	if FileAccess.file_exists(save_path):
		var current_check := _read_snapshot_file(save_path)
		if current_check["ok"]:
			var current_text_result := _read_text(save_path)
			if not current_text_result["ok"]:
				return current_text_result
			var backup_write := _write_text(backup_temp_path, str(current_text_result["text"]))
			if not backup_write["ok"]:
				return backup_write
			var backup_check := _read_snapshot_file(backup_temp_path)
			if not backup_check["ok"]:
				return {"ok": false, "error": "backup_validation_failed", "detail": backup_check.get("error", "invalid")}
			var backup_replace := _replace_file(backup_temp_path, backup_path)
			if not backup_replace["ok"]:
				return backup_replace

	var replace_result := _replace_file(temp_path, save_path)
	if not replace_result["ok"]:
		return replace_result
	return {"ok": true, "path": save_path, "checksum": checksum, "schemaVersion": SCHEMA_VERSION}

func load_snapshot() -> Dictionary:
	var primary := _read_snapshot_file(save_path)
	if primary["ok"]:
		primary["source"] = "primary"
		primary["recovered"] = false
		return primary
	var backup := _read_snapshot_file(backup_path)
	if backup["ok"]:
		var restore_result := _restore_backup()
		if not restore_result["ok"]:
			return {
				"ok": false,
				"error": "backup_restore_failed",
				"primary_error": primary.get("error", "invalid"),
				"detail": restore_result.get("error", "replace_failed")
			}
		backup["source"] = "backup"
		backup["recovered"] = true
		backup["primary_error"] = primary.get("error", "invalid")
		return backup
	if primary.get("error") == "not_found" and backup.get("error") == "not_found":
		return {"ok": false, "error": "not_found"}
	return {
		"ok": false,
		"error": primary.get("error", "invalid_save"),
		"backup_error": backup.get("error", "not_found"),
		"found_schema": primary.get("found_schema", null)
	}

func paths() -> Dictionary:
	return {
		"primary": save_path,
		"temp": temp_path,
		"backup": backup_path,
		"backup_temp": backup_temp_path
	}

func _restore_backup() -> Dictionary:
	var backup_text := _read_text(backup_path)
	if not backup_text["ok"]:
		return backup_text
	var write_result := _write_text(temp_path, str(backup_text["text"]))
	if not write_result["ok"]:
		return write_result
	var check := _read_snapshot_file(temp_path)
	if not check["ok"]:
		return {"ok": false, "error": "restore_validation_failed"}
	return _replace_file(temp_path, save_path)

func _read_snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "not_found"}
	var read_result := _read_text(path)
	if not read_result["ok"]:
		return read_result
	var parser := JSON.new()
	if parser.parse(str(read_result["text"])) != OK:
		return {"ok": false, "error": "invalid_json", "message": parser.get_error_message(), "line": parser.get_error_line()}
	var envelope = parser.data
	if typeof(envelope) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_envelope"}
	var schema = envelope.get("schemaVersion", null)
	if typeof(schema) != TYPE_FLOAT and typeof(schema) != TYPE_INT:
		return {"ok": false, "error": "unsupported_schema", "found_schema": schema}
	if float(schema) != float(SCHEMA_VERSION):
		return {"ok": false, "error": "unsupported_schema", "found_schema": schema}
	if str(envelope.get("checksumAlgorithm", "")) != "sha256":
		return {"ok": false, "error": "unsupported_checksum"}
	var payload_json = envelope.get("payloadJson", null)
	if typeof(payload_json) != TYPE_STRING:
		return {"ok": false, "error": "missing_payload"}
	var expected := str(envelope.get("checksum", ""))
	var actual: String = str(payload_json).sha256_text()
	if expected.is_empty() or expected != actual:
		return {"ok": false, "error": "checksum_mismatch", "expected": expected, "actual": actual}
	var payload_parser := JSON.new()
	if payload_parser.parse(str(payload_json)) != OK or typeof(payload_parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_payload"}
	var payload: Dictionary = payload_parser.data
	var payload_check := _validate_payload(payload)
	if not payload_check["ok"]:
		return payload_check
	return {"ok": true, "snapshot": payload, "checksum": actual, "schemaVersion": SCHEMA_VERSION}

func _validate_payload(snapshot: Dictionary) -> Dictionary:
	var required := ["contentVersion", "runState", "battleState", "lineup", "currentBattleKind", "mode", "flow", "runSeed", "battleLog"]
	for key in required:
		if not snapshot.has(key):
			return {"ok": false, "error": "missing_snapshot_field", "field": key}
	if str(snapshot["contentVersion"]) != content_version:
		return {"ok": false, "error": "unsupported_content_version", "found_version": snapshot["contentVersion"]}
	if typeof(snapshot["runState"]) != TYPE_DICTIONARY or typeof(snapshot["battleState"]) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_snapshot_state"}
	var run_state: Dictionary = snapshot["runState"]
	var battle_state: Dictionary = snapshot["battleState"]
	# Stage is optional in old saves; new saves must use an explicit known identity.
	if run_state.has("stage") and (typeof(run_state["stage"]) != TYPE_STRING or not LifeStagesScript.THEMES.has(run_state["stage"])):
		return {"ok": false, "error": "invalid_life_stage"}
	for key in ["accounts", "deck", "nodes", "battles", "wallet"]:
		if not run_state.has(key):
			return {"ok": false, "error": "invalid_run_state", "field": key}
	if typeof(run_state["accounts"]) != TYPE_DICTIONARY or typeof(run_state["deck"]) != TYPE_ARRAY or typeof(run_state["nodes"]) != TYPE_DICTIONARY or typeof(run_state["battles"]) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_run_state"}
	if run_state.has("story"):
		if typeof(run_state["story"]) != TYPE_DICTIONARY:
			return {"ok": false, "error": "invalid_story_state"}
		var story: Dictionary = run_state["story"]
		if typeof(story.get("seen", null)) != TYPE_DICTIONARY or typeof(story.get("lastEvent", null)) != TYPE_STRING:
			return {"ok": false, "error": "invalid_story_state"}
		for seen_key in story["seen"].keys():
			if typeof(seen_key) != TYPE_STRING or typeof(story["seen"][seen_key]) != TYPE_BOOL:
				return {"ok": false, "error": "invalid_story_state"}
	if typeof(snapshot["lineup"]) != TYPE_ARRAY or snapshot["lineup"].is_empty() or snapshot["lineup"].size() > 3:
		return {"ok": false, "error": "invalid_snapshot_lineup"}
	for role_id_value in snapshot["lineup"]:
		if typeof(role_id_value) != TYPE_STRING or not run_state["accounts"].has(str(role_id_value)):
			return {"ok": false, "error": "invalid_snapshot_lineup"}
	if str(snapshot["mode"]) not in ["standard", "test_arena"]:
		return {"ok": false, "error": "invalid_snapshot_mode"}
	if str(snapshot["currentBattleKind"]) not in ["", "ordinary", "boss", "test_arena"]:
		return {"ok": false, "error": "invalid_snapshot_battle_kind"}
	if str(snapshot["flow"]) not in ["map", "battle", "rest", "result"]:
		return {"ok": false, "error": "invalid_snapshot_flow"}
	var mode := str(snapshot["mode"])
	var battle_kind := str(snapshot["currentBattleKind"])
	var flow := str(snapshot["flow"])
	var has_battle := not battle_state.is_empty()
	if has_battle:
		for key in ["id", "result", "phase", "accounts", "actors", "draw", "hand", "discard", "consumed", "sealed"]:
			if not battle_state.has(key):
				return {"ok": false, "error": "invalid_battle_state", "field": key}
		if typeof(battle_state["accounts"]) != TYPE_DICTIONARY or typeof(battle_state["actors"]) != TYPE_ARRAY:
			return {"ok": false, "error": "invalid_battle_state"}
		for zone_name in ["draw", "hand", "discard", "consumed", "sealed"]:
			if typeof(battle_state[zone_name]) != TYPE_ARRAY:
				return {"ok": false, "error": "invalid_battle_state", "field": zone_name}
		if str(battle_state["result"]) not in ["ongoing", "win", "loss"] or str(battle_state["phase"]) not in ["between", "player", "enemy"]:
			return {"ok": false, "error": "invalid_battle_state"}
	elif flow != "map" or battle_kind != "":
		return {"ok": false, "error": "invalid_battle_state"}
	if mode == "test_arena" and (battle_kind != "test_arena" or flow in ["map", "rest"]):
		return {"ok": false, "error": "invalid_snapshot_mode_flow"}
	if mode == "standard" and battle_kind == "test_arena":
		return {"ok": false, "error": "invalid_snapshot_mode_flow"}
	if flow == "map" and mode != "standard":
		return {"ok": false, "error": "invalid_snapshot_mode_flow"}
	if flow == "battle" and not has_battle:
		return {"ok": false, "error": "invalid_snapshot_mode_flow"}
	if flow == "rest" and battle_kind != "ordinary":
		return {"ok": false, "error": "invalid_snapshot_mode_flow"}
	if (typeof(snapshot["runSeed"]) != TYPE_INT and typeof(snapshot["runSeed"]) != TYPE_FLOAT) or typeof(snapshot["battleLog"]) != TYPE_ARRAY:
		return {"ok": false, "error": "invalid_snapshot_metadata"}
	return {"ok": true}

func _ensure_parent_directory() -> Dictionary:
	var directory := save_path.get_base_dir()
	if directory.is_empty():
		return {"ok": true}
	var absolute := ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "directory_create_failed", "code": error}
	return {"ok": true}

func _write_text(path: String, text: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "write_failed", "path": path, "code": FileAccess.get_open_error()}
	file.store_string(text)
	file.flush()
	file.close()
	return {"ok": true}

func _read_text(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "read_failed", "path": path, "code": FileAccess.get_open_error()}
	var text := file.get_as_text()
	file.close()
	return {"ok": true, "text": text}

func _replace_file(source: String, destination: String) -> Dictionary:
	var source_absolute := ProjectSettings.globalize_path(source)
	var destination_absolute := ProjectSettings.globalize_path(destination)
	if FileAccess.file_exists(destination):
		var remove_error := DirAccess.remove_absolute(destination_absolute)
		if remove_error != OK:
			return {"ok": false, "error": "replace_remove_failed", "code": remove_error, "path": destination}
	var rename_error := DirAccess.rename_absolute(source_absolute, destination_absolute)
	if rename_error != OK:
		return {"ok": false, "error": "replace_rename_failed", "code": rename_error, "path": destination}
	return {"ok": true}
