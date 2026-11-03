## Run in Godot with a renderer. Writes the frame sheets used by UnitView.
extends SceneTree

const Rig = preload("res://tools/plant_rig.gd")
const CELL := 224
const ANCHOR := Vector2(112, 195)
const OUT := "res://assets/sprites/animation"
const MANIFEST := "res://data/actor_frames.json"


func _init() -> void:
	call_deferred("_bake")


func _bake() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Frame baking needs a renderer. Run without --headless.")
		quit(1)
		return
	root.size = Vector2i(440, 280)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL, CELL)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var caps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/evolution_art_v040.json"))
	var catalog: Dictionary = {}
	if FileAccess.file_exists(MANIFEST):
		catalog = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var options: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0].trim_prefix("--")] = pair[1]
	if options.has("actor"):
		var actor := String(options["actor"])
		var profile := String(options.get("profile", "upright"))
		var path := String(options.get("sprite", "res://assets/sprites/" + actor + ".png"))
		if not Rig.PROFILES.has(profile) or not ResourceLoader.exists(path):
			printerr("Unknown rig profile or missing sprite: ", profile, " ", path)
			quit(1)
			return
		var result: Dictionary = await _bake_actor(viewport, actor, "wall", _single_sprite(path, profile))
		if not result.is_empty():
			catalog[actor] = result
			_save_catalog(catalog)
		quit(1 if result.is_empty() else 0)
		return
	var lily: Dictionary = await _bake_actor(viewport, "lily", "wall",
		_single_sprite("res://assets/sprites/lily.png", "canopy"))
	if lily.is_empty():
		quit(1)
		return
	catalog["lily"] = lily
	var count := 0
	for type in Rig.BY_TYPE:
		for path_id in [1, 2, 3]:
			var source := _source(caps, type, path_id)
			if source.is_empty():
				continue
			var actor := "%s-e%d" % [type, path_id]
			var result: Dictionary = await _bake_actor(viewport, actor, type, source)
			if result.is_empty():
				quit(1)
				return
			catalog[actor] = result
			count += 1
	var bosses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_art_manifest.json"))
	for sheet in bosses["atlases"]:
		var sheet_name := String(sheet["file"]).get_file()
		if not sheet_name.begins_with("boss_"):
			continue
		var id := sheet_name.trim_prefix("boss_").trim_suffix("_atlas.png")
		var texture: Texture2D = load("res://" + String(sheet["file"]))
		var idle_bounds: Array = sheet["frames"][0]["alpha_bbox_local"]
		var base_height := float(idle_bounds[3]) - float(idle_bounds[1])
		for frame in sheet["frames"]:
			var pose_name := String(frame["name"])
			var r: Array = frame["region"]
			var actor := "boss-%s-%s" % [id, pose_name]
			var source := {"texture": texture, "region": Rect2i(r[0], r[1], r[2], r[3]),
				"profile": "vessel", "base_height": base_height, "facing": "left"}
			var result: Dictionary = await _bake_actor(viewport, actor, "wall", source)
			if result.is_empty():
				quit(1)
				return
			catalog[actor] = result
	_save_catalog(catalog)
	print("CAPSTONE FRAME SETS ", count)
	quit(0 if count > 0 else 1)


func _save_catalog(catalog: Dictionary) -> void:
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog, "\t", true) + "\n")
	file.close()


func _single_sprite(path: String, profile: String) -> Dictionary:
	var texture: Texture2D = load(path)
	return {"texture": texture, "region": Rect2i(Vector2i.ZERO, texture.get_size()),
		"profile": profile}


func _source(caps: Dictionary, type: String, path_id: int) -> Dictionary:
	if caps.has(type):
		var info: Dictionary = caps[type]
		for frame in info["frames"]:
			if int(frame["path"]) == path_id:
				var r: Array = frame["region"]
				var texture: Texture2D = load("res://" + String(info["file"]))
				return {"texture": texture, "region": Rect2i(r[0], r[1], r[2], r[3])}
	var path := "res://assets/sprites/%s-e%d.png" % [type, path_id]
	if not ResourceLoader.exists(path):
		return {}
	var texture: Texture2D = load(path)
	return {"texture": texture, "region": Rect2i(Vector2i.ZERO, texture.get_size())}


func _bake_actor(viewport: SubViewport, actor: String, type: String, source: Dictionary) -> Dictionary:
	var texture: Texture2D = source["texture"]
	var region: Rect2i = source["region"]
	var used := texture.get_image().get_region(region).get_used_rect()
	if not used.has_area():
		printerr("Empty capstone source: ", actor)
		return {}
	var rect := Rect2(region.position + used.position, used.size)
	var rig := Rig.new()
	viewport.add_child(rig)
	var profile := String(source.get("profile", Rig.BY_TYPE[type]))
	rig.fit(texture, rect, profile)
	var scale := minf(159.0 / rect.size.y, 165.0 / rect.size.x)
	rig.scale = Vector2.ONE * scale
	rig.position = ANCHOR - rect.size * Vector2(0.5, 1.0) * scale
	var sheet := Image.create_empty(CELL * 4, CELL * 2, false, Image.FORMAT_RGBA8)
	var clips: Dictionary = {}
	for row in 2:
		var clip := "idle" if row == 0 else "action"
		clips[clip] = []
		for frame in 4:
			rig.pose(clip, frame)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			if not image.get_used_rect().has_area():
				printerr("Renderer returned an empty frame: ", actor, " ", clip, " ", frame)
				return {}
			var at := Vector2i(frame * CELL, row * CELL)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, viewport.size), at)
			clips[clip].append({"rect": [at.x, at.y, CELL, CELL], "anchor": [ANCHOR.x, ANCHOR.y]})
	viewport.remove_child(rig)
	rig.free()
	var path := OUT + "/" + actor + ".png"
	var err := sheet.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("Could not save ", path, ": ", err)
		return {}
	print("BAKED ", actor, " ", profile)
	return {"file": path.trim_prefix("res://"), "body_px": float(source.get("base_height", rect.size.y)) * scale,
		"facing": source.get("facing", "right"), "clips": clips}
