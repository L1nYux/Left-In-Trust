extends SceneTree

## Reproducible slicer for the remaining Demo character and enemy source sheets.
## Every sheet is generated as a strict grid, so no image-editor dependency is
## needed to rebuild the individual transparent layers.

const JOBS := [
	{
		"source": "res://assets/actors/claude/claude_parts_sheet_v1.png",
		"output": "res://assets/actors/claude/layers",
		"prefix": "claude",
		"columns": 2,
		"rows": 3,
		"parts": ["back", "body", "head", "near_arm", "prop", "front"]
	},
	{
		"source": "res://assets/actors/deepseek/deepseek_parts_sheet_v1.png",
		"output": "res://assets/actors/deepseek/layers",
		"prefix": "deepseek",
		"columns": 2,
		"rows": 3,
		"parts": ["back", "body", "head", "near_arm", "prop", "front"]
	},
	{
		"source": "res://assets/enemies/missing_attachment/missing_attachment_parts_sheet_v1.png",
		"output": "res://assets/enemies/missing_attachment/layers",
		"prefix": "missing_attachment",
		"columns": 2,
		"rows": 2,
		"parts": ["back", "body", "legs", "core"]
	}
]


func _init() -> void:
	var total := 0
	for job_value in JOBS:
		var job: Dictionary = job_value
		var result := _slice_job(job)
		if not bool(result.get("ok", false)):
			push_error(str(result.get("error", "unknown slice failure")))
			quit(1)
			return
		total += int(result["count"])
	print("[DEMO ART LAYERS] jobs=%d layers=%d" % [JOBS.size(), total])
	quit(0)


func _slice_job(job: Dictionary) -> Dictionary:
	var source_path := str(job["source"])
	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if source == null or source.is_empty():
		return {"ok": false, "error": "Unable to load parts sheet: %s" % source_path}
	var columns := int(job["columns"])
	var rows := int(job["rows"])
	if source.get_width() % columns != 0 or source.get_height() % rows != 0:
		return {"ok": false, "error": "%s does not match its %dx%d grid" % [source_path, columns, rows]}
	var parts: Array = job["parts"]
	if parts.size() != columns * rows:
		return {"ok": false, "error": "%s has an invalid part manifest" % source_path}
	var output_path := ProjectSettings.globalize_path(str(job["output"]))
	DirAccess.make_dir_recursive_absolute(output_path)
	var cell_width := source.get_width() / columns
	var cell_height := source.get_height() / rows
	for index in parts.size():
		var row := floori(float(index) / float(columns))
		var region := Rect2i(
			(index % columns) * cell_width,
			row * cell_height,
			cell_width,
			cell_height
		)
		var image := source.get_region(region)
		_cleanup_actor_cell(str(job["prefix"]), str(parts[index]), image)
		var file_name := "%s_%s_v1.png" % [job["prefix"], parts[index]]
		var error := image.save_png(output_path.path_join(file_name))
		if error != OK:
			return {"ok": false, "error": "Unable to save %s: %s" % [file_name, error_string(error)]}
	return {"ok": true, "count": parts.size()}


func _cleanup_actor_cell(prefix: String, part_name: String, image: Image) -> void:
	if prefix not in ["claude", "deepseek"]:
		return
	var clear := Color(0, 0, 0, 0)
	match part_name:
		"body":
			image.fill_rect(Rect2i(0, 0, 14, image.get_height()), clear)
		"head":
			# Claude's source cell contains a narrow remnant of the body-cell hem.
			# Its hair begins lower than DeepSeek's, so this role needs a larger
			# deterministic crop while preserving the actual head silhouette.
			var clear_height := 150 if prefix == "claude" else 90
			image.fill_rect(Rect2i(0, 0, image.get_width(), clear_height), clear)
			if prefix == "deepseek":
				image.fill_rect(Rect2i(400, 0, image.get_width() - 400, 132), clear)
		"near_arm":
			image.fill_rect(Rect2i(0, 0, image.get_width(), 108), clear)
		"prop":
			var clear_height := 70 if prefix == "claude" else 32
			image.fill_rect(Rect2i(0, 0, image.get_width(), clear_height), clear)
			if prefix == "deepseek":
				image.fill_rect(Rect2i(500, 0, image.get_width() - 500, image.get_height()), clear)
