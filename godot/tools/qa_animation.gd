extends SceneTree

var checks: Array = []
var failures := 0


func _init() -> void:
	call_deferred("run")


func check(label: String, condition: bool) -> void:
	checks.append({"name": label, "ok": condition})
	if not condition:
		failures += 1
		printerr("FAIL ", label)


func check_actor(catalog: Dictionary, id: String, clips: Array, frames: int = 4) -> void:
	var actor: Dictionary = catalog.get(id, {})
	var art := "res://" + String(actor.get("file", ""))
	check(id + " 图集可加载", not actor.is_empty() and ResourceLoader.exists(art))
	if actor.is_empty():
		return
	var texture: Texture2D = load(art)
	if texture == null:
		return
	var image := texture.get_image()
	for clip in clips:
		var sequence: Array = actor.clips.get(clip, [])
		var poses: Dictionary = {}
		for frame in sequence:
			var rect: Array = frame["rect"]
			var region := Rect2i(rect[0], rect[1], rect[2], rect[3])
			if Rect2i(Vector2i.ZERO, image.get_size()).encloses(region):
				var pose := image.get_region(region)
				if pose.get_used_rect().has_area():
					poses[hash(pose.get_data())] = true
		check("%s %s 有%d帧且不同画面不少于75%%" % [id, clip, frames],
			sequence.size() == frames and poses.size() >= ceili(frames * 0.75))


func check_sedan() -> void:
	var sim := Sim.new()
	sim.setup(Content.get_level(11), ["lantern", "bomb"], "normal")
	check("鬼新娘不能被普通刷怪入口直接创建", sim.spawn_zombie("bride", 0) == null)
	var loaded := 0
	for i in 400:
		var wagon = sim.spawn_zombie("sedan", 1)
		loaded += int(wagon.sedan_has_bride)
		wagon.dead = true
	check("载客与空轿按各50%抽取", absi(loaded - 200) < 37)
	for has_bride in [false, true]:
		var wagon = sim.spawn_zombie("sedan", 1, {"sedan_bride": has_bride, "x": 900.0})
		check("轿子只能走陆路", wagon.row not in [1, 3])
		sim.damage_zombie(wagon, wagon.armor, true, false, "shooter")
		check("轿壳碎裂后只留下乘客和轿夫",
			not wagon.alive() and sim.pending_spawns.size() == (3 if has_bride else 2))
		sim.flush_pending_spawns()
		var ghosts := 0
		var brides := 0
		for z in sim.zombies:
			if not z.alive():
				continue
			if z.type == "ghost":
				ghosts += 1
			if z.type == "bride":
				brides += 1
				var hp: float = z.hp
				sim.damage_zombie(z, 1800.0, true, false, "bomb")
				sim.damage_zombie(z, 1800.0, true, false, "mushroom")
				sim.damage_zombie(z, 900.0, true, false, "wall", "ash_wall")
				check("鬼新娘免疫灰烬伤害", z.hp == hp)
				sim.damage_zombie(z, 20.0, true, false, "shooter")
				check("鬼新娘正常承受竹签伤害", z.hp == hp - 20.0)
			z.dead = true
		check("两只饿鬼和对应的鬼新娘", ghosts == 2 and brides == int(has_bride))


func check_projectiles() -> void:
	var sim := Sim.new()
	sim.setup(Content.get_level(1), ["lantern"], "normal")
	var direct := Sim.Shot.new()
	direct.pos = Vector2(400.0, 300.0)
	direct.speed = 100.0
	sim._update_straight(direct, 0.1)
	check("直弹飞行速度为原来的60%", is_equal_approx(direct.pos.x, 406.0))
	var star := Sim.Shot.new()
	star.pos = Vector2(400.0, 300.0)
	star.speed = 100.0
	star.dir = Vector2.RIGHT
	sim._update_star_shot(star, 0.1)
	check("灯焰飞行速度为原来的60%", is_equal_approx(star.pos.x, 406.0))
	var lob := Sim.Shot.new()
	lob.start = Vector2(400.0, 300.0)
	lob.tx = 500.0
	lob.ty = 300.0
	lob.flight = 1.0
	sim._update_lob_shot(lob, 0.1)
	check("抛射进度为原来的60%", is_equal_approx(lob.pos.x, 406.0))
	var seeking := Sim.Shot.new()
	seeking.target = sim.spawn_zombie("ghost", 0, {"x": 1000.0})
	seeking.pos = seeking.target.pos - Vector2(200.0, 24.0)
	seeking.speed = 100.0
	var x: float = seeking.pos.x
	sim._update_homing(seeking, 0.1)
	check("追踪弹飞行速度为原来的60%", is_equal_approx(seeking.pos.x, x + 6.0))


func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_frames.json"))
	for type in Content.PLANT_ORDER:
		check_actor(catalog, type, ["idle", "action", "switch", "far_idle", "far", "dual"] if type == "dragon" else ["idle", "action"])
		if type == "ember-cicada":
			check_actor(catalog, type, ["reload_enter", "reload", "reload_exit"])
		if type in ["firework", "dragon", "sky-kite", "wish-till", "ember-cicada"]:
			# These actors use their full base animation set at every tier.
			continue
		for path in Upgrades.paths_for(type):
			check_actor(catalog, "%s-e%d" % [type, int(path.id)], ["idle", "action"])
	for type in Content.ZOMBIE_ORDER:
		var clips := ["walk", "attack"]
		var def: Dictionary = Content.ZOMBIES[type]
		if def.tier != "h" and not bool(def.get("sedan_only", false)):
			clips += ["swim", "swim_bite"]
		if type == "returner":
			clips.append("revive")
		if type == "phaseguard":
			check_actor(catalog, "phase-veil", clips)
			check_actor(catalog, "phase-kite", clips)
		else:
			check_actor(catalog, type, clips)
	for variant in ["sedan-empty", "sedan-loaded"]:
		check_actor(catalog, variant, ["walk", "attack"])
	for boss in ["earth", "paper", "river"]:
		for pose in ["idle", "anticipation", "small", "major", "hurt", "defeat"]:
			check_actor(catalog, "boss-%s-%s" % [boss, pose], ["idle", "action"])
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json"))
	check("所有原画角色都已烘焙32帧动作", catalog.size() == motion.size())
	for actor in catalog:
		check_actor(motion, actor, catalog[actor]["clips"].keys(), 32)
	check_sedan()
	check_projectiles()
	var out := FileAccess.open("res://qa/animation-tests.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"total": checks.size(), "failures": failures, "checks": checks}, "\t"))
	print("ANIMATION ", checks.size(), " FAILURES ", failures)
	quit(0 if failures == 0 else 1)
