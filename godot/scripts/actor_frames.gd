extends RefCounted

const MANIFEST = "res://data/actor_frames.json"
var catalog: Dictionary = {}
var sheets: Dictionary = {}


func load_sheets(prefix: String = "") -> void:
	if not FileAccess.file_exists(MANIFEST):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary:
		return
	catalog = data
	for actor in catalog:
		if prefix.is_empty() and String(actor).begins_with("boss-"):
			continue
		if not prefix.is_empty() and not String(actor).begins_with(prefix):
			continue
		var path = "res://" + String(catalog[actor]["file"])
		if ResourceLoader.exists(path):
			sheets[actor] = load(path)


func draw_pose(canvas: CanvasItem, actor: String, clip: String, frame_index: int,
		foot: Vector2, height: float, facing_left: bool, tint: Color) -> bool:
	if not sheets.has(actor):
		return false
	var info: Dictionary = catalog[actor]
	var sequence: Array = info["clips"].get(clip, [])
	if sequence.is_empty():
		return false
	var frame: Dictionary = sequence[posmod(frame_index, sequence.size())]
	var r: Array = frame["rect"]
	var anchor: Array = frame["anchor"]
	var scale = height / maxf(1.0, float(info["body_px"]))
	var flip = (String(info["facing"]) == "left") != facing_left
	var size = Vector2(r[2], r[3])
	canvas.draw_set_transform(foot, 0.0, Vector2(-scale if flip else scale, scale))
	canvas.draw_texture_rect_region(sheets[actor], Rect2(-Vector2(anchor[0], anchor[1]), size),
		Rect2(r[0], r[1], size.x, size.y), tint, false, true)
	canvas.draw_set_transform(Vector2.ZERO)
	return true
