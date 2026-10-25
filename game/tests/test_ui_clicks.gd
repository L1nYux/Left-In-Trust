extends SceneTree

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
		await _press(game, "开始新的委托")
		await _press(game, "加入小队")
		await _press(game, "加入小队")
		await _press(game, "开始常规委托")
		await _press(game, "基础攻击")
		await _press(game, "确认执行")
		await _press(game, "基础攻击")
		await _press(game, "确认执行")
		if game.battle_state.get("result") == "ongoing":
			await _press(game, "结束回合")
		if failed:
			return
		root.remove_child(game)
		game.queue_free()
		await process_frame
		await process_frame
	print("[UI CLICK TESTS] PASS %d signal-driven transition loops" % ITERATIONS)
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
