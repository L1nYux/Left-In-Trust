extends SceneTree

## Deterministically slices the generated 2 x 3 GPT parts sheet. Keeping this
## small tool in the project makes later source-sheet revisions reproducible.

const SOURCE := "res://assets/actors/gpt/gpt_parts_sheet_v1.png"
const OUTPUT_DIR := "res://assets/actors/gpt/layers"
const PARTS := [
	{"name": "back", "column": 0, "row": 0},
	{"name": "body", "column": 1, "row": 0},
	{"name": "head", "column": 0, "row": 1},
	{"name": "near_arm", "column": 1, "row": 1},
	{"name": "prop", "column": 0, "row": 2},
	{"name": "front", "column": 1, "row": 2}
]


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if source == null or source.is_empty():
		push_error("Unable to load GPT parts sheet: %s" % SOURCE)
		quit(1)
		return
	if source.get_width() % 2 != 0 or source.get_height() % 3 != 0:
		push_error("GPT parts sheet must use an exact 2 x 3 grid")
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_path)
	var cell_width := source.get_width() / 2
	var cell_height := source.get_height() / 3
	for part_value in PARTS:
		var part: Dictionary = part_value
		var region := Rect2i(
			int(part["column"]) * cell_width,
			int(part["row"]) * cell_height,
			cell_width,
			cell_height
		)
		var image := source.get_region(region)
		_cleanup_cell(str(part["name"]), image)
		var error := image.save_png(output_path.path_join("gpt_%s_v1.png" % part["name"]))
		if error != OK:
			push_error("Unable to save GPT layer %s: %s" % [part["name"], error_string(error)])
			quit(1)
			return
	print("[GPT LAYERS] source=%dx%d cell=%dx%d count=%d" % [source.get_width(), source.get_height(), cell_width, cell_height, PARTS.size()])
	quit(0)


func _cleanup_cell(part_name: String, image: Image) -> void:
	# Some generated silhouettes intentionally overrun their grid cell. Remove
	# only spill from the preceding row; the useful component remains untouched.
	var clear := Color(0, 0, 0, 0)
	match part_name:
		"body":
			image.fill_rect(Rect2i(0, 0, 18, image.get_height()), clear)
		"head":
			image.fill_rect(Rect2i(0, 0, image.get_width(), 72), clear)
		"near_arm":
			image.fill_rect(Rect2i(0, 0, image.get_width(), 104), clear)
		"prop":
			image.fill_rect(Rect2i(0, 0, image.get_width(), 28), clear)
