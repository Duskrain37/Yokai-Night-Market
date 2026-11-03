extends SceneTree

func _init() -> void:
 call_deferred("run")

func capture(name: String) -> void:
 for i in 5: await process_frame
 await RenderingServer.frame_post_draw
 var file = "res://qa/patch-%s.png" % name
 var error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
 print("CAPTURE ", file, " code=", error)

func run() -> void:
 root.content_scale_size = Vector2i(1600, 900)
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.start_battle(1, ["mushroom", "lion", "lantern"])
 for i in 3:
  var p = game.sim.place_free("mushroom", 2 + i * 2, 2)
  p.arm_t = [0.0, 7.0, 14.0][i]
  p.armed = i == 2
 game.paused = true
 await capture("mushroom-growth")
 game.paused = false
 game.start_battle(1, ["lion", "lantern"])
 var lion = game.sim.place_free("lion", 1, 2)
 lion.upgrades = {1:0, 2:3, 3:0}
 for x in [lion.pos.x + 230.0, lion.pos.x + 560.0]:
  var z = game.sim.spawn_zombie("ghost", 2, {"x":x})
  z.hp = 4000.0
  z.max_hp = 4000.0
 lion.timer = 1.88
 game.sim._update_lion(lion, 0.02)
 lion.lion_wave_t = 0.17
 game.paused = true
 await capture("lion-wave")
 game.paused = false
 game.start_battle(1, ["bomb", "wall", "umbrella", "lantern"])
 game.set_setting("health_bars", "barText")
 var wall = game.sim.place_free("wall", 1, 1)
 wall.hp = wall.max_hp * 0.62
 var umbrella = game.sim.place_free("umbrella", 2, 3)
 umbrella.wish = 150.0
 umbrella.wish_t = 100.0
 var bomb = game.sim.place_free("bomb", 5, 2)
 game.sim.explode(bomb)
 game.paused = true
 await capture("health-and-bomb-start")
 game.sim.update_particles(0.16)
 await capture("health-and-bomb-mid")
 game.sim.update_particles(0.22)
 await capture("health-and-bomb-end")
 game.paused = false
 game.start_battle(11, ["lily", "gust", "firework", "judge", "lantern"])
 var sim = game.sim
 var fan = sim.place_free("gust", 2, 2)
 var fire = sim.place_free("firework", 2, 4)
 var judge = sim.place_free("judge", 1, 4)
 judge.upgrades[1] = 3
 sim.damage_plant(fire, 5000.0)
 var empty = sim.spawn_zombie("sedan", 0, {"x": 1190.0, "sedan_bride": false})
 var full = sim.spawn_zombie("sedan", 2, {"x": 1060.0, "sedan_bride": true})
 empty.anim = 0.3
 full.anim = 0.14
 var swim = sim.spawn_zombie("ghost", 1, {"x": 920.0})
 swim.water_entered = true
 swim.anim = 0.23
 var plunge = sim.spawn_zombie("tongue", 3, {"x": 1080.0})
 plunge.water_entered = true
 plunge.water_entry_t = 0.44
 sim.spawn_zombie("ghost", 4, {"x": 1010.0})
 sim._update_gust(fan, 0.62)
 sim._update_firework(fire, 3.5)
 sim.update_particles(0.22)
 sim.update_shots(0.38)
 game.paused = true
 game.hud.refresh()
 await capture("dark-river-v041")
 sim.damage_zombie(full, full.armor, true, false, "needle")
 sim.flush_pending_spawns()
 for i in 18: await process_frame
 await capture("sedan-break-v041")
 game.paused = false
 game._qa_show_boss(5)
 await capture("boss-v041")
 quit()
