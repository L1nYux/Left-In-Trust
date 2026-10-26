extends Control
class_name LayeredActor2D

## Reusable layered action puppet.
## GPT is the reference profile; Claude and DeepSeek only override visual and
## motion parameters while keeping exactly the same layer and motion contract.

const LayerScript = preload("res://scripts/layered_actor_layer.gd")
const LAYER_IDS := ["shadow", "aura", "back", "body", "head", "prop", "front", "effect"]
const MOTION_TAGS := ["basic", "light_attack", "heavy_attack", "guard", "support", "transfer"]

const BASE_PROFILE := {
	"accent": "6ea8fe",
	"secondary": "c4b5fd",
	"body": "315aa9",
	"dark": "111d42",
	"outline": "dbeafe",
	"skin": "f3d7c5",
	"hair": "24305d",
	"formal_art": false,
	"motif": "segments",
	"motion": {"advance": 25.0, "lift": 9.0, "prop_swing": -0.18, "guard_scale": 1.1}
}

const ROLE_OVERRIDES := {
	"GPT": {
		"accent": "6ea8fe", "secondary": "c4b5fd", "body": "315aa9", "dark": "111d42",
		"outline": "dbeafe", "hair": "29366e", "formal_art": true, "motif": "segments",
		"motion": {"advance": 30.0, "lift": 8.0, "prop_swing": -0.24, "guard_scale": 1.08}
	},
	"Claude": {
		"accent": "fd9a5f", "secondary": "f6c453", "body": "a94722", "dark": "3b1b17",
		"outline": "ffedd5", "hair": "5d3028", "formal_art": true, "motif": "book",
		"motion": {"advance": 22.0, "lift": 6.0, "prop_swing": -0.12, "guard_scale": 1.18}
	},
	"DeepSeek": {
		"accent": "52d6c9", "secondary": "8ecbff", "body": "127d79", "dark": "082f3d",
		"outline": "ccfbf1", "hair": "12445f", "formal_art": true, "motif": "ripple",
		"motion": {"advance": 27.0, "lift": 11.0, "prop_swing": -0.3, "guard_scale": 1.14}
	}
}

@export_enum("GPT", "Claude", "DeepSeek") var role_id := "GPT"

var profile: Dictionary = {}
var layers: Dictionary = {}
var _motion_tween: Tween
var _motion_playing := false
var _elapsed := 0.0
var _selected := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = false
	_build_layers()
	configure(role_id)
	resized.connect(_update_layer_geometry)
	_update_layer_geometry()


func _process(delta: float) -> void:
	if _motion_playing or layers.is_empty():
		return
	_elapsed += delta
	var breath := sin(_elapsed * 2.2)
	var body: Control = layers["body"]
	var head: Control = layers["head"]
	var prop: Control = layers["prop"]
	body.position = Vector2(0, breath * 0.7)
	head.position = Vector2(0, breath * 1.15 - 0.4)
	head.rotation = breath * 0.008
	prop.position = Vector2(0, breath * 1.4)


func configure(next_role_id: String) -> void:
	role_id = next_role_id if ROLE_OVERRIDES.has(next_role_id) else "GPT"
	profile = BASE_PROFILE.duplicate(true)
	profile.merge(ROLE_OVERRIDES[role_id], true)
	if layers.is_empty():
		return
	for layer_id_value in LAYER_IDS:
		var layer_id := str(layer_id_value)
		layers[layer_id].configure(layer_id, role_id, profile)
	set_visual_state(_selected, true, false)


func set_visual_state(is_selected: bool, is_online: bool, has_acted: bool) -> void:
	_selected = is_selected
	if layers.is_empty():
		return
	layers["aura"].set_selected(is_selected)
	var tone := Color.WHITE
	if not is_online:
		tone = Color(0.58, 0.62, 0.7, 0.58)
	elif has_acted:
		tone = Color(0.8, 0.82, 0.88, 0.82)
	for layer_id_value in LAYER_IDS:
		var layer: Control = layers[str(layer_id_value)]
		layer.modulate = tone if str(layer_id_value) != "effect" else Color(1, 1, 1, layer.modulate.a)


func play_motion(requested_tag: String) -> void:
	var motion_tag := requested_tag if MOTION_TAGS.has(requested_tag) else "basic"
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_reset_pose()
	_motion_playing = true
	var body: Control = layers["body"]
	var head: Control = layers["head"]
	var prop: Control = layers["prop"]
	var back: Control = layers["back"]
	var aura: Control = layers["aura"]
	var effect: Control = layers["effect"]
	var motion: Dictionary = profile["motion"]
	var advance := float(motion["advance"])
	var lift := float(motion["lift"])
	var prop_swing := float(motion["prop_swing"])
	effect.set_effect(motion_tag)
	effect.modulate.a = 0.0
	effect.scale = Vector2(0.78, 0.78)

	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_QUAD)
	_motion_tween.set_ease(Tween.EASE_OUT)
	match motion_tag:
		"heavy_attack":
			_motion_tween.tween_property(body, "position", Vector2(-advance * 0.16, 2), 0.12)
			_motion_tween.parallel().tween_property(prop, "rotation", -prop_swing * 0.45, 0.12)
			_motion_tween.tween_property(body, "position", Vector2(advance, -3), 0.2)
			_motion_tween.parallel().tween_property(body, "rotation", 0.022, 0.2)
			_motion_tween.parallel().tween_property(head, "rotation", 0.055, 0.2)
			_motion_tween.parallel().tween_property(prop, "position", Vector2(advance * 0.82, -lift), 0.2)
			_motion_tween.parallel().tween_property(prop, "rotation", prop_swing, 0.2)
			_reveal_effect(_motion_tween, effect, 0.18)
		"light_attack", "basic":
			_motion_tween.tween_property(body, "position", Vector2(advance * 0.72, -2), 0.12)
			_motion_tween.parallel().tween_property(body, "rotation", 0.012, 0.12)
			_motion_tween.parallel().tween_property(head, "rotation", 0.032, 0.12)
			_motion_tween.parallel().tween_property(prop, "position", Vector2(advance, -lift * 0.55), 0.12)
			_motion_tween.parallel().tween_property(prop, "rotation", prop_swing, 0.12)
			_reveal_effect(_motion_tween, effect, 0.13)
		"guard":
			_motion_tween.tween_property(body, "position", Vector2(0, -lift * 0.34), 0.16)
			_motion_tween.parallel().tween_property(prop, "position", Vector2(6, -lift), 0.16)
			_motion_tween.parallel().tween_property(back, "scale", Vector2.ONE * float(motion["guard_scale"]), 0.16)
			_motion_tween.parallel().tween_property(aura, "scale", Vector2.ONE * float(motion["guard_scale"]), 0.16)
			_reveal_effect(_motion_tween, effect, 0.2)
		"support":
			_motion_tween.tween_property(body, "position", Vector2(0, -lift), 0.16)
			_motion_tween.parallel().tween_property(head, "position", Vector2(0, -lift * 1.15), 0.16)
			_motion_tween.parallel().tween_property(prop, "rotation", prop_swing * 0.55, 0.16)
			_reveal_effect(_motion_tween, effect, 0.22)
		"transfer":
			_motion_tween.tween_property(prop, "position", Vector2(advance * 0.92, -lift * 0.45), 0.18)
			_motion_tween.parallel().tween_property(body, "position", Vector2(advance * 0.24, 0), 0.18)
			_motion_tween.parallel().tween_property(prop, "rotation", prop_swing * 0.7, 0.18)
			_reveal_effect(_motion_tween, effect, 0.22)

	_motion_tween.tween_interval(0.1)
	_motion_tween.tween_callback(Callable(self, "_return_to_idle"))


func get_layer_names() -> Array:
	return LAYER_IDS.duplicate()


func get_supported_motions() -> Array:
	return MOTION_TAGS.duplicate()


func get_profile() -> Dictionary:
	return profile.duplicate(true)


func motion_signature() -> String:
	return "%s:%s" % [role_id, profile.get("motif", "segments")]


func current_motion_tag() -> String:
	if layers.is_empty():
		return ""
	return str(layers["effect"].effect_tag)


func _build_layers() -> void:
	if not layers.is_empty():
		return
	for layer_id_value in LAYER_IDS:
		var layer_id := str(layer_id_value)
		var layer = LayerScript.new()
		layer.name = layer_id.capitalize()
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		layers[layer_id] = layer
	layers["effect"].modulate.a = 0.0


func _update_layer_geometry() -> void:
	for layer_id_value in LAYER_IDS:
		var layer_id := str(layer_id_value)
		var layer: Control = layers.get(layer_id)
		if layer == null:
			continue
		layer.pivot_offset = Vector2(size.x * (0.52 if layer_id == "prop" else 0.5), size.y * (0.58 if layer_id == "prop" else 0.55))
		layer.queue_redraw()


func _reveal_effect(tween: Tween, effect: Control, duration: float) -> void:
	tween.parallel().tween_property(effect, "modulate:a", 1.0, duration)
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration)


func _return_to_idle() -> void:
	var effect: Control = layers["effect"]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	for layer_id_value in ["body", "head", "prop", "back", "aura"]:
		var layer: Control = layers[str(layer_id_value)]
		tween.parallel().tween_property(layer, "position", Vector2.ZERO, 0.2)
		tween.parallel().tween_property(layer, "rotation", 0.0, 0.2)
		tween.parallel().tween_property(layer, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.16)
	tween.tween_callback(Callable(self, "_finish_motion"))
	_motion_tween = tween


func _finish_motion() -> void:
	_motion_playing = false
	_reset_pose()
	layers["effect"].set_effect("idle")


func _reset_pose() -> void:
	if layers.is_empty():
		return
	for layer_id_value in LAYER_IDS:
		var layer: Control = layers[str(layer_id_value)]
		layer.position = Vector2.ZERO
		layer.rotation = 0.0
		layer.scale = Vector2.ONE
	if str(layers["effect"].effect_tag) != "idle":
		layers["effect"].modulate.a = 0.0
