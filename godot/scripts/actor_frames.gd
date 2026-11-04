extends RefCounted

const MANIFEST = "res://data/actor_frames.json"
const MOTION_MANIFEST = "res://data/actor_motion.json"
const MOTION_STEPS_PER_KEY := 8
var catalog: Dictionary = {}
var motion: Dictionary = {}
var motion_sheets: Dictionary = {}
var _prefix := ""
var sheets: Dictionary = {}


func load_sheets(prefix: String = "") -> void:
	_prefix = prefix
	if not FileAccess.file_exists(MANIFEST):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary:
		return
	catalog = data
	if FileAccess.file_exists(MOTION_MANIFEST):
		var motion_data = JSON.parse_string(FileAccess.get_file_as_string(MOTION_MANIFEST))
		if motion_data is Dictionary:
			motion = motion_data


func key_sheet(actor: String) -> Texture2D:
	if not catalog.has(actor):
		return null
	if not sheets.has(actor):
		var path = "res://" + String(catalog[actor]["file"])
		if ResourceLoader.exists(path):
			sheets[actor] = load(path)
	return sheets.get(actor)


func draw_pose(canvas: CanvasItem, actor: String, clip: String, key_position: float,
		foot: Vector2, height: float, facing_left: bool, tint: Color, deform := Vector2.ONE) -> bool:
	if not catalog.has(actor):
		return false
	if _prefix.is_empty() and actor.begins_with("boss-"):
		return false
	if not _prefix.is_empty() and not actor.begins_with(_prefix):
		return false
	var info: Dictionary = catalog[actor]
	var texture: Texture2D = null
	var frame_index = int(floor(key_position))
	if motion.has(actor):
		if not motion_sheets.has(actor):
			var path = "res://" + String(motion[actor]["file"])
			if ResourceLoader.exists(path):
				motion_sheets[actor] = load(path)
		if motion_sheets.has(actor):
			info = motion[actor]
			texture = motion_sheets[actor]
			frame_index = int(floor(key_position * MOTION_STEPS_PER_KEY))
	if texture == null:
		texture = key_sheet(actor)
	if texture == null:
		return false
	var sequence: Array = info["clips"].get(clip, [])
	var submerged := false
	if sequence.is_empty() and clip in ["swim", "swim_bite"]:
		sequence = info["clips"].get("walk" if clip == "swim" else "attack", [])
		submerged = true
	if sequence.is_empty():
		return false
	var frame: Dictionary = sequence[posmod(frame_index, sequence.size())]
	var r: Array = frame["rect"]
	var anchor: Array = frame["anchor"]
	var scale = height / maxf(1.0, float(info["body_px"]))
	var flip = (String(info["facing"]) == "left") != facing_left
	var size = Vector2(r[2], r[3])
	if submerged:
		var lower := float(info["body_px"]) * 0.34
		size.y = minf(size.y, anchor[1] - lower)
		anchor = [anchor[0], size.y]
	canvas.draw_set_transform(foot, 0.0, Vector2(-scale if flip else scale, scale) * deform)
	canvas.draw_texture_rect_region(texture, Rect2(-Vector2(anchor[0], anchor[1]), size),
		Rect2(r[0], r[1], size.x, size.y), tint, false, true)
	canvas.draw_set_transform(Vector2.ZERO)
	return true
