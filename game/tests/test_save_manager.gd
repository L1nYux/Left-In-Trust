extends SceneTree

const ContentDBScript = preload("res://scripts/content_db.gd")
const RulesScript = preload("res://scripts/game_rules.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

var rules
var passed := 0
var base_directory: String

func _init() -> void:
	var content: Dictionary = ContentDBScript.load_content()
	if content.is_empty():
		_fail("generated content is missing")
		return
	rules = RulesScript.new(content)
	base_directory = ProjectSettings.globalize_path("res://../_build/test_saves")
	DirAccess.make_dir_recursive_absolute(base_directory)
	var cases := [
		["save exit and continue round-trip", _test_round_trip],
		["truncated temporary file leaves primary valid", _test_truncated_temp],
		["corrupt primary JSON restores previous valid snapshot", _test_corrupt_primary],
		["checksum mismatch restores previous valid snapshot", _test_checksum_recovery],
		["settlement interrupted before save remains idempotent", _test_settlement_reload],
		["unsupported schema is explicit and preserves file", _test_unsupported_schema]
	]
	for test_case in cases:
		if not _run(test_case[0], test_case[1]):
			return
	print("[SAVE TESTS] PASS %d/%d" % [passed, cases.size()])
	quit(0)

func _run(test_name: String, callable: Callable) -> bool:
	var result = callable.call()
	if typeof(result) != TYPE_BOOL or not bool(result):
		_fail("%s: %s" % [test_name, result])
		return false
	passed += 1
	print("[PASS] %s" % test_name)
	return true

func _fail(message: String) -> void:
	push_error("[SAVE FAIL] %s" % message)
	quit(1)

func _manager(name: String):
	var path := base_directory.path_join("%s.json" % name)
	var manager = SaveManagerScript.new(path, "0.5")
	for candidate in manager.paths().values():
		if FileAccess.file_exists(str(candidate)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(candidate)))
	return manager

func _snapshot(seed: int, wallet: int = 0) -> Dictionary:
	var run_state: Dictionary = rules.make_run_for_roles(["GPT", "Claude"], seed)
	run_state["wallet"] = wallet
	var battle_state: Dictionary = rules.start_battle(run_state, "ordinary", ["GPT", "Claude"], "missing_attachment", seed ^ 99)
	rules.begin_turn(battle_state)
	return {
		"contentVersion": "0.5",
		"runState": run_state,
		"battleState": battle_state,
		"lineup": ["GPT", "Claude"],
		"selectedActor": "GPT",
		"selectedTarget": "GPT",
		"currentBattleKind": "ordinary",
		"mode": "standard",
		"flow": "battle",
		"runSeed": seed,
		"battleLog": ["saved"]
	}

func _test_round_trip():
	var manager = _manager("round_trip")
	var snapshot := _snapshot(201, 7)
	var saved: Dictionary = manager.save_snapshot(snapshot)
	if not saved["ok"] or int(saved.get("schemaVersion", 0)) != 1:
		return "save failed: %s" % saved
	var restarted = SaveManagerScript.new(manager.paths()["primary"], "0.5")
	var loaded: Dictionary = restarted.load_snapshot()
	if not loaded["ok"] or loaded.get("source") != "primary":
		return "continue failed: %s" % loaded
	var restored: Dictionary = loaded["snapshot"]
	return int(restored["runSeed"]) == 201 \
		and int(restored["runState"]["wallet"]) == 7 \
		and restored["lineup"] == ["GPT", "Claude"] \
		and restored["flow"] == "battle" \
		and restored["battleState"]["id"] == "ordinary"

func _test_truncated_temp():
	var manager = _manager("truncated_temp")
	var snapshot := _snapshot(211, 4)
	manager.save_snapshot(snapshot)
	_write_text(manager.paths()["temp"], "{\"schemaVersion\":1")
	var loaded: Dictionary = manager.load_snapshot()
	if not loaded["ok"] or loaded.get("source") != "primary":
		return "truncated temp affected primary: %s" % loaded
	return int(loaded["snapshot"]["runState"]["wallet"]) == 4

func _test_corrupt_primary():
	var manager = _manager("corrupt_primary")
	manager.save_snapshot(_snapshot(221, 3))
	manager.save_snapshot(_snapshot(222, 9))
	_write_text(manager.paths()["primary"], "{broken")
	var loaded: Dictionary = manager.load_snapshot()
	if not loaded["ok"] or not loaded.get("recovered", false) or loaded.get("primary_error") != "invalid_json":
		return "corrupt primary was not recovered: %s" % loaded
	if int(loaded["snapshot"]["runState"]["wallet"]) != 3:
		return "did not restore previous valid snapshot"
	var second: Dictionary = manager.load_snapshot()
	return second["ok"] and second.get("source") == "primary"

func _test_checksum_recovery():
	var manager = _manager("checksum")
	manager.save_snapshot(_snapshot(231, 2))
	manager.save_snapshot(_snapshot(232, 8))
	var envelope: Dictionary = JSON.parse_string(_read_text(manager.paths()["primary"]))
	envelope["checksum"] = "0000"
	_write_text(manager.paths()["primary"], JSON.stringify(envelope))
	var loaded: Dictionary = manager.load_snapshot()
	if not loaded["ok"] or loaded.get("primary_error") != "checksum_mismatch":
		return "checksum failure was not reported and recovered: %s" % loaded
	return int(loaded["snapshot"]["runState"]["wallet"]) == 2

func _test_settlement_reload():
	var manager = _manager("settlement")
	var snapshot := _snapshot(241, 0)
	var state: Dictionary = snapshot["battleState"]
	state["hp"] = 3
	rules.try_action(state, "GPT", RulesScript.BASIC_ATTACK, "GPT")
	rules.finish_turn(state)
	if state["result"] != "win":
		return "fixture did not win"
	manager.save_snapshot(snapshot)
	var interrupted: Dictionary = manager.load_snapshot()["snapshot"]
	var first: Dictionary = rules.settle_battle(interrupted["runState"], interrupted["battleState"])
	if not first["ok"] or first.get("duplicate", true):
		return "first recovery settlement did not apply"
	interrupted["flow"] = "result"
	manager.save_snapshot(interrupted)
	var once_wallet: int = interrupted["runState"]["wallet"]
	var once_tokens := {}
	for role_id in interrupted["runState"]["accounts"].keys():
		once_tokens[role_id] = int(interrupted["runState"]["accounts"][role_id]["token"])
	for unused in 2:
		var reloaded: Dictionary = manager.load_snapshot()["snapshot"]
		var duplicate: Dictionary = rules.settle_battle(reloaded["runState"], reloaded["battleState"])
		if not duplicate["ok"] or not duplicate.get("duplicate", false):
			return "reloaded settlement was not recognized as duplicate"
		if int(reloaded["runState"]["wallet"]) != once_wallet:
			return "duplicate settlement changed rewards"
		for role_id in once_tokens.keys():
			if int(reloaded["runState"]["accounts"][role_id]["token"]) != int(once_tokens[role_id]):
				return "duplicate settlement changed %s token" % role_id
	return once_wallet == 4

func _test_unsupported_schema():
	var manager = _manager("unsupported_schema")
	manager.save_snapshot(_snapshot(251, 5))
	var envelope: Dictionary = JSON.parse_string(_read_text(manager.paths()["primary"]))
	envelope["schemaVersion"] = 99
	var unsupported_text := JSON.stringify(envelope)
	_write_text(manager.paths()["primary"], unsupported_text)
	var loaded: Dictionary = manager.load_snapshot()
	if loaded["ok"] or loaded.get("error") != "unsupported_schema" or int(loaded.get("found_schema", 0)) != 99:
		return "unsupported schema result was not explicit: %s" % loaded
	if not FileAccess.file_exists(manager.paths()["primary"]):
		return "unsupported save was deleted"
	return _read_text(manager.paths()["primary"]) == unsupported_text

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.flush()
	file.close()

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return text
