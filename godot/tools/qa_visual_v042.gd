extends SceneTree

func _init() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var file = "res://qa/v042-%s.png" % name
	var error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
	print("CAPTURE ", file, " code=", error)

func run() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_battle(13, ["lantern", "shooter", "lily", "cat", "firework"])
	game.paused = true
	game.sim.wave_index = 15
	var rows = [0, 1, 2, 4]
	var enemies: Array = []
	for i in rows.size():
		var z = game.sim.spawn_zombie("ironjudge" if i % 2 == 0 else "bucket", rows[i],
			{"x": 680.0 + 126.0 * i})
		if i == 1:
			z.water_entered = true
		z.anim = 0.205 + 0.14 * i
		enemies.append(z)
	game.hud.refresh()
	await capture("armor-and-two-flags")
	for i in enemies.size():
		enemies[i].eating = true
		enemies[i].chomp = 0.22 + 0.015 * i
	await capture("armor-attack")
	game.show_pause()
	await capture("pause")
	game.close_pause()
	game.start_battle(0, ["shooter"], "tutorial")
	game.paused = true
	game.sim.tutorial["step"] = "almanac"
	game.hud.refresh()
	await capture("tutorial-almanac")
	game.show_menu()
	game._qa = false
	game.start_battle(0, ["shooter"], "tutorial")
	while game._loading_screen == null or game._loading_screen.modulate.a < 0.95:
		await process_frame
	await capture("loading")
	while game._loading_busy:
		await process_frame
	game._qa = true
	game.start_battle(15, ["dragon", "squash", "lantern", "lily"])
	var sim = game.sim
	sim.time = 14.0
	game.paused = true
	var dragon = sim.place_free("dragon", 2, 2)
	dragon.upgrades[3] = 3
	dragon.dragon_mode = "dual"
	dragon.dragon_near_at = sim.time - 0.09
	dragon.dragon_far_at = sim.time - 0.09
	var distant = sim.spawn_zombie("phaseguard", 2, {"x": 1080.0, "phase_form": 1})
	dragon.dragon_aim = distant.pos
	sim._dragon_fire(dragon, distant)
	sim.update_shots(0.45)
	var melon = sim.place_free("squash", 3, 4)
	melon.squash_at = sim.time - 0.39
	melon.squash_aim = melon.pos + Vector2(Geo.CELL_W * 0.85, 0)
	var lamp = sim.place_free("lantern", 1, 0)
	lamp.sleep_until = sim.time + 3.0
	sim.spawn_zombie("dreambell", 0, {"x": 1100.0})
	var revival = sim.spawn_zombie("returner", 0, {"x": 790.0})
	sim.kill_zombie(revival)
	revival.revive_at = sim.time + 0.43
	sim.spawn_zombie("shieldguard", 4, {"x": 1030.0})
	var boat = sim.spawn_zombie("reedboat", 1, {"x": 1130.0})
	boat.water_entered = true
	sim.spawn_zombie("sedan", 0, {"x": 1240.0, "sedan_bride": true})
	sim.spawn_zombie("bride", 2, {"x": 900.0, "sedan_split": true})
	sim.spawn_zombie("phaseguard", 3, {"x": 805.0, "phase_form": 0}).water_entered = true
	game.hud.refresh()
	await capture("new-guests-and-cards")
	quit()
