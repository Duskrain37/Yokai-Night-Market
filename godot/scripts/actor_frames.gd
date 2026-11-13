extends RefCounted

const MANIFEST = "res://data/actor_frames.json"
const MOTION_MANIFEST = "res://data/actor_motion.json"
const MOTION_STEPS_PER_KEY := 8
var catalog: Dictionary = {}
var motion: Dictionary = {}
var motion_sheets: Dictionary = {}
var _prefix := ""
var _pending: Dictionary = {}
var _last_use: Dictionary = {}
var _mobile := OS.has_feature("android") or "--mobile" in OS.get_cmdline_user_args()
var sheets: Dictionary = {}


func load_sheets(prefix: String = "") -> void:
	_prefix = prefix
	if not FileAccess.file_exists(MANIFEST):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary:
		return
	catalog = data
	var motion_path = "res://data/actor_motion_mobile.json" if _mobile and FileAccess.file_exists("res://data/actor_motion_mobile.json") else MOTION_MANIFEST
	if FileAccess.file_exists(motion_path):
		var motion_data = JSON.parse_string(FileAccess.get_file_as_string(motion_path))
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
		foot: Vector2, height: float, facing_left: bool, tint: Color, deform := Vector2.ONE, rotation: float=0.0,
		crop: Rect2 = Rect2(0, 0, 1, 1)) -> bool:
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
		var resolved_clip := clip
		if not motion[actor].clips.has(resolved_clip):resolved_clip="walk" if clip=="swim" else "attack"
		var sheet_key: String=actor+"#"+resolved_clip if _mobile and motion[actor].has("clip_files") else actor
		var path: String="res://"+String(motion[actor].get("clip_files",{}).get(resolved_clip,motion[actor].file))
		_last_use[sheet_key]=Time.get_ticks_msec()
		if not motion_sheets.has(sheet_key):
			if ResourceLoader.exists(path):
				if not _mobile or ResourceLoader.has_cached(path):
					motion_sheets[sheet_key]=load(path)
				elif not _pending.has(sheet_key):
					ResourceLoader.load_threaded_request(path)
					_pending[sheet_key]=true
					return false
				elif ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:
					motion_sheets[sheet_key]=ResourceLoader.load_threaded_get(path)
					_pending.erase(sheet_key)
				else:return false
		if motion_sheets.has(sheet_key):
			info = motion[actor]
			texture = motion_sheets[sheet_key]
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
	canvas.draw_set_transform(foot, rotation, Vector2(-scale if flip else scale, scale) * deform)
	var inset: Vector2 = size * crop.position
	var cropped: Vector2 = size * crop.size
	canvas.draw_texture_rect_region(texture, Rect2(-Vector2(anchor[0], anchor[1]) + inset, cropped),
		Rect2(Vector2(r[0], r[1]) + inset, cropped), tint, false, true)
	canvas.draw_set_transform(Vector2.ZERO)
	return true


func release_unused(age_ms: int = 8000) -> void:
	if not _mobile:return
	var now:=Time.get_ticks_msec()
	for actor in motion_sheets.keys():
		if now-int(_last_use.get(actor,now))>age_ms:
			motion_sheets.erase(actor)
			_last_use.erase(actor)
