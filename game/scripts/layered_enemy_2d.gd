extends Control
class_name LayeredEnemy2D

const LayerScript = preload("res://scripts/layered_enemy_layer.gd")
const LAYER_IDS := ["shadow", "back", "legs", "body", "core", "effect"]
const MOTION_TAGS := ["idle", "attack", "hit"]

var layers: Dictionary = {}
var enemy_id := "missing_attachment"
var _motion_tween: Tween
var _motion_playing := false
var _elapsed := 0.0
var _current_motion_tag := "idle"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = false
	_build_layers()
	resized.connect(_update_geometry)
	_update_geometry()


func configure(next_enemy_id: String) -> void:
	enemy_id = next_enemy_id if next_enemy_id in ["missing_attachment", "submit"] else "missing_attachment"
	for layer_id_value in LAYER_IDS:
		var layer_id := str(layer_id_value)
		if layers.has(layer_id):
			layers[layer_id].configure(layer_id, enemy_id)


func _process(delta: float) -> void:
	if _motion_playing or layers.is_empty():
		return
	_elapsed += delta
	var hover := sin(_elapsed * 1.7)
	layers["back"].position.y = hover * 1.4
	layers["body"].position.y = hover * 0.8
	layers["core"].scale = Vector2.ONE * (1.0 + sin(_elapsed * 2.8) * 0.012)


func play_motion(requested_tag: String) -> void:
	var motion_tag := requested_tag if MOTION_TAGS.has(requested_tag) else "idle"
	_current_motion_tag = motion_tag
	if motion_tag == "idle":
		return
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_reset_pose()
	_motion_playing = true
	var body: Control = layers["body"]
	var core: Control = layers["core"]
	var legs: Control = layers["legs"]
	var back: Control = layers["back"]
	var effect: Control = layers["effect"]
	effect.set_effect(motion_tag)
	effect.modulate.a = 0.0
	_motion_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if motion_tag == "attack":
		_motion_tween.tween_property(body, "position:x", -28.0, 0.16)
		_motion_tween.parallel().tween_property(core, "position:x", -34.0, 0.16)
		_motion_tween.parallel().tween_property(back, "position:x", -18.0, 0.16)
		_motion_tween.parallel().tween_property(legs, "scale", Vector2(1.05, 0.96), 0.16)
	else:
		_motion_tween.tween_property(body, "position:x", 12.0, 0.07)
		_motion_tween.parallel().tween_property(core, "position:x", 16.0, 0.07)
		_motion_tween.tween_property(body, "position:x", -8.0, 0.08)
		_motion_tween.parallel().tween_property(core, "position:x", -10.0, 0.08)
	_motion_tween.parallel().tween_property(effect, "modulate:a", 1.0, 0.12)
	_motion_tween.tween_interval(0.12)
	_motion_tween.tween_callback(Callable(self, "_return_to_idle"))


func get_layer_names() -> Array:
	return LAYER_IDS.duplicate()


func get_supported_motions() -> Array:
	return MOTION_TAGS.duplicate()


func current_motion_tag() -> String:
	return _current_motion_tag


func _build_layers() -> void:
	for layer_id_value in LAYER_IDS:
		var layer_id := str(layer_id_value)
		var layer = LayerScript.new()
		layer.name = layer_id.capitalize()
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		layer.configure(layer_id, enemy_id)
		layers[layer_id] = layer
	layers["effect"].modulate.a = 0.0


func _update_geometry() -> void:
	for layer_value in layers.values():
		var layer: Control = layer_value
		layer.pivot_offset = Vector2(size.x * 0.5, size.y * 0.56)
		layer.queue_redraw()


func _return_to_idle() -> void:
	var effect: Control = layers["effect"]
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for layer_id_value in ["back", "legs", "body", "core"]:
		var layer: Control = layers[str(layer_id_value)]
		tween.parallel().tween_property(layer, "position", Vector2.ZERO, 0.18)
		tween.parallel().tween_property(layer, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.14)
	tween.tween_callback(Callable(self, "_finish_motion"))
	_motion_tween = tween


func _finish_motion() -> void:
	_motion_playing = false
	_current_motion_tag = "idle"
	_reset_pose()
	layers["effect"].set_effect("idle")


func _reset_pose() -> void:
	for layer_value in layers.values():
		var layer: Control = layer_value
		layer.position = Vector2.ZERO
		layer.rotation = 0.0
		layer.scale = Vector2.ONE
