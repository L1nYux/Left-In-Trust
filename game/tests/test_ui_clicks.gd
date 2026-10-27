extends SceneTree

## Signal-driven UI smoke test: title -> role select -> map -> battle ->
## drag a basic attack onto the enemy -> end turn -> settings -> title.
## 12 loops keep catching "stale node / freed callback" style regressions.

const SaveManagerScript = preload("res://scripts/save_manager.gd")
const ITERATIONS := 12

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path := ProjectSettings.globalize_path("res://../_build/test_saves/ui_clicks.json")
	for iteration in ITERATIONS:
		var scene: PackedScene = load("res://scenes/Main.tscn")
		var game = scene.instantiate()
		root.add_child(game)
		await process_frame
		game.save_manager = SaveManagerScript.new(save_path, "0.5")
		game.last_load_result = {"ok": false, "error": "not_found"}
		game.call("_show_title")
		await process_frame
		await _press(game, "开始新的委托")
		await _press(game, "加入小队")
		await _press(game, "加入小队")
		await _press(game, "开始常规委托")
		await _press_node(game, "MapRoot/MapOrdinary")
		if failed:
			return
		if game.battle_state.is_empty() or game.battle_state.get("result") != "ongoing":
			_fail("ordinary battle did not start from the map icon")
			return
		var hp_before := int(game.battle_state["hp"])
		if not game.call("_begin_drag", "basic_attack"):
			_fail("basic attack drag could not start")
			return
		var enemy_center: Vector2 = game.call("_enemy_drop_center")
		game.call("_update_drag", enemy_center)
		if not game.call("_drop_drag_at", enemy_center):
			_fail("dropping the basic attack on the enemy was rejected")
			return
		if int(game.battle_state["hp"]) >= hp_before:
			_fail("dragged basic attack did not damage the enemy")
			return
		if game.call("_begin_drag", "basic_attack"):
			_fail("basic attack could be dragged twice in one turn")
			return
		if game.battle_state.get("result") == "ongoing":
			await _press_node(game, "BattleRoot/EndTurnButton")
		if failed:
			return
		await _press_node(game, "BattleRoot/SettingsButton")
		await _press(game, "返回标题界面")
		if failed:
			return
		if game.flow != "title":
			_fail("settings return to title did not land on the title screen")
			return
		root.remove_child(game)
		game.queue_free()
		await process_frame
		await process_frame
	print("[UI CLICK TESTS] PASS %d node/drag-driven transition loops" % ITERATIONS)
	quit(0)

func _press(game: Node, text_prefix: String) -> void:
	var button := _find_button(game, text_prefix)
	if button == null:
		_fail("button not found: %s" % text_prefix)
		return
	if button.disabled:
		_fail("button unexpectedly disabled: %s" % text_prefix)
		return
	button.emit_signal("pressed")
	await process_frame
	await process_frame

func _press_node(game: Node, path: String) -> void:
	var button := game.get_node_or_null(path)
	if button == null or not (button is Button):
		_fail("button node not found: %s" % path)
		return
	if button.disabled:
		_fail("button node unexpectedly disabled: %s" % path)
		return
	button.emit_signal("pressed")
	await process_frame
	await process_frame

func _find_button(node: Node, text_prefix: String) -> Button:
	if node is Button and str(node.text).begins_with(text_prefix):
		return node
	for child in node.get_children():
		var found := _find_button(child, text_prefix)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error("[UI CLICK FAIL] %s" % message)
	quit(1)
