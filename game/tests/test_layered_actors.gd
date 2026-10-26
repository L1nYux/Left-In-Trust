extends SceneTree

const ROLE_SCENES := {
	"GPT": preload("res://scenes/actors/GPTActor.tscn"),
	"Claude": preload("res://scenes/actors/ClaudeActor.tscn"),
	"DeepSeek": preload("res://scenes/actors/DeepSeekActor.tscn")
}
const ENEMY_SCENE = preload("res://scenes/enemies/MissingAttachmentActor.tscn")
const EXPECTED_MOTIFS := {"GPT": "segments", "Claude": "book", "DeepSeek": "ripple"}
const EXPECTED_LAYERS := ["shadow", "aura", "back", "body", "head", "prop", "front", "effect"]
const EXPECTED_MOTIONS := ["basic", "light_attack", "heavy_attack", "guard", "support", "transfer"]
const FORMAL_PARTS := ["back", "body", "head", "near_arm", "prop", "front"]
const ENEMY_LAYERS := ["shadow", "back", "legs", "body", "core", "effect"]
const ENEMY_MOTIONS := ["idle", "attack", "hit"]
const ENEMY_PARTS := ["back", "body", "legs", "core"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var records: Array = []
	for role_id_value in ROLE_SCENES.keys():
		var role_id := str(role_id_value)
		var actor = ROLE_SCENES[role_id].instantiate()
		root.add_child(actor)
		await process_frame
		if actor.role_id != role_id:
			_fail("%s scene did not preserve its profile id" % role_id)
			return
		if actor.get_layer_names() != EXPECTED_LAYERS:
			_fail("%s does not use the shared eight-layer contract" % role_id)
			return
		if actor.get_supported_motions() != EXPECTED_MOTIONS:
			_fail("%s does not use the shared motion-tag contract" % role_id)
			return
		var profile: Dictionary = actor.get_profile()
		if str(profile.get("motif", "")) != EXPECTED_MOTIFS[role_id]:
			_fail("%s motif override was not applied" % role_id)
			return
		if not bool(profile.get("formal_art", false)):
			_fail("%s formal art profile is not active" % role_id)
			return
		var role_slug := role_id.to_lower()
		var master_path := "res://assets/actors/%s/%s_master_v1.png" % [role_slug, role_slug]
		var master_texture := load(master_path) as Texture2D
		if master_texture == null or master_texture.get_image() == null or not master_texture.get_image().has_mipmaps():
			_fail("%s coherent master is missing mipmaps: %s" % [role_id, master_path])
			return
		for part_value in FORMAL_PARTS:
			var asset_path := "res://assets/actors/%s/layers/%s_%s_v1.png" % [role_slug, role_slug, str(part_value)]
			if not ResourceLoader.exists(asset_path):
				_fail("%s formal layer is missing: %s" % [role_id, asset_path])
				return
			var texture := load(asset_path) as Texture2D
			if texture == null or texture.get_image() == null or not texture.get_image().has_mipmaps():
				_fail("%s formal layer is missing mipmaps: %s" % [role_id, asset_path])
				return
		for motion_tag_value in EXPECTED_MOTIONS:
			var motion_tag := str(motion_tag_value)
			actor.play_motion(motion_tag)
			if actor.current_motion_tag() != motion_tag:
				_fail("%s did not route motion tag %s" % [role_id, motion_tag])
				return
		records.append({"role": role_id, "signature": actor.motion_signature(), "layers": actor.get_layer_names().size(), "motions": actor.get_supported_motions().size(), "formal_art": bool(profile.get("formal_art", false))})
		root.remove_child(actor)
		actor.free()
	var enemy = ENEMY_SCENE.instantiate()
	root.add_child(enemy)
	await process_frame
	if enemy.get_layer_names() != ENEMY_LAYERS:
		_fail("Missing Attachment does not use the six-layer enemy contract")
		return
	if enemy.get_supported_motions() != ENEMY_MOTIONS:
		_fail("Missing Attachment does not expose idle/attack/hit motions")
		return
	for part_value in ENEMY_PARTS:
		var asset_path := "res://assets/enemies/missing_attachment/layers/missing_attachment_%s_v1.png" % str(part_value)
		if not ResourceLoader.exists(asset_path):
			_fail("Missing Attachment formal layer is missing: %s" % asset_path)
			return
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_image() == null or not texture.get_image().has_mipmaps():
			_fail("Missing Attachment formal layer is missing mipmaps: %s" % asset_path)
			return
	for motion_tag_value in ["attack", "hit"]:
		var motion_tag := str(motion_tag_value)
		enemy.play_motion(motion_tag)
		if enemy.current_motion_tag() != motion_tag:
			_fail("Missing Attachment did not route motion tag %s" % motion_tag)
			return
	records.append({"enemy": "missing_attachment", "layers": enemy.get_layer_names().size(), "motions": enemy.get_supported_motions().size(), "formal_art": true})
	root.remove_child(enemy)
	enemy.free()
	print("[LAYERED ACTORS] %s" % JSON.stringify(records))
	quit(0)


func _fail(message: String) -> void:
	push_error("[LAYERED ACTOR FAIL] %s" % message)
	quit(1)
