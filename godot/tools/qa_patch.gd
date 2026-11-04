extends SceneTree

var total := 0
var failures := 0
func check(name: String, ok: bool) -> void:
 total += 1
 if not ok:
  failures += 1
  printerr("FAIL ", name)
 else:
  print("PASS ", name)

func button_named(node: Node, label: String) -> Button:
 if node is Button and node.text == label:
  return node
 for child in node.get_children():
  var found = button_named(child, label)
  if found != null: return found
 return null

func roster_mass(sim: Sim, queue: Array) -> float:
 var result = 0.0
 for entry in queue:
  result += sim._enemy_mass(String(entry.type)) * float(entry.get("mass_scale", 1.0))
 return result


func _init() -> void:
 call_deferred("run")

func run() -> void:
 root.content_scale_size = Vector2i(1600, 900)
 var sim = Sim.new()
 sim.setup(Content.get_level(11), ["cat", "lion", "mushroom"], "normal")
 var counts = [0, 0]
 for i in 12000:
  var row = sim.choose_spawn_row("ghost")
  counts[1 if row in [1, 3] else 0] += 1
 var ratio = float(counts[1]) / 12000.0
 check("暗河水路单行权重为陆路的三分之二", absf(ratio - 4.0 / 13.0) < 0.02)
 var only_land = true
 for type in ["mountain", "sedan", "artisan", "ironjudge"]:
  for i in 300:
   if sim.choose_spawn_row(type) in [1, 3]: only_land = false
 check("四种高阶恶客不走水路", only_land)
 Geo.set_stage("day1")
 var street_scale: Array = []
 for row in 5:
  street_scale.append(Geo.scale_at_flat(Geo.cell_center(0, row, 5), 5))
 Geo.set_stage("day3")
 for row in 5:
  check("暗河第%d行与夜市街单位缩放一致" % (row + 1),
   is_equal_approx(Geo.scale_at_flat(Geo.cell_center(0, row, 5), 5), street_scale[row]))
 var base = Sim.new()
 base.setup(Content.get_level(11), ["shooter"], "normal")
 for wave_no in 9:
  base.spawn_queue.clear()
  sim.spawn_queue.clear()
  base.rng.seed = 42 + wave_no
  sim.rng.seed = 42 + wave_no
  base.queue_roster(base.level.waves[wave_no], wave_no)
  sim.queue_wave(sim.level.waves[wave_no], wave_no)
  var base_mass = roster_mass(base, base.spawn_queue)
  var actual_mass = roster_mass(sim, sim.spawn_queue)
  check("暗河第%d拨总耐久比例" % (wave_no + 1),
   is_equal_approx(actual_mass / base_mass, Content.wave_mass_ratio(sim.level, wave_no)))
  if wave_no < 2:
   check("暗河第一大波第%d拨只有低阶" % (wave_no + 1), sim.spawn_queue.all(
    func(entry): return Content.ZOMBIES[String(entry.type)].tier == "l"))
 for level in Content.LEVELS.slice(0, 15):
  base.setup(level, ["shooter"], "normal")
  var mass_kept := true
  var before_boss := {}
  for index in level.waves.size():
   var wave: Dictionary = level.waves[index]
   base.rng.seed = 102 + index
   base.spawn_queue.clear()
   base.queue_roster({"groups": wave.budget_groups}, index)
   var initial_mass := roster_mass(base, base.spawn_queue)
   var initial_count: int = base.spawn_queue.size()
   base.rng.seed = 102 + index
   base.spawn_queue.clear()
   base.queue_roster(wave, index)
   mass_kept = mass_kept and is_equal_approx(initial_mass, roster_mass(base, base.spawn_queue)) and initial_count == base.spawn_queue.size()
   if index < level.waves.size() - 3:
    for entry in base.spawn_queue: before_boss[entry.type] = true
  check("第%d夜来客换班保留数量和耐久预算" % int(level.id), mass_kept)
  if String(level.boss_id) != "":
   var eligible: Array = Content.ZOMBIE_ORDER.filter(func(type): return type != "bride" and (type != "reedboat" or level.day == 3))
   check("第%d夜首领前各路合法恶客齐全" % int(level.id), eligible.all(func(type): return before_boss.has(type)))
 var loss = {"called": false}
 sim.on_lose = func(_z): loss.called = true
 var first = sim.spawn_zombie("ghost", 0, {"x": Geo.BREACH_X - 1.0})
 sim.update_zombies(0.016)
 check("门神触发不立即判负", bool(sim.mowers[0].active) and not loss.called)
 check("门神扫倒触发行的恶客", not first.alive())
 var second = sim.spawn_zombie("ghost", 0, {"x": Geo.BREACH_X - 20.0})
 sim.update_zombies(0.016)
 check("无门神路口继续行走而非立即判负", second.alive() and not loss.called)
 second.pos.x = Geo.BREACH_X - 98.0
 sim.update_zombies(0.016)
 check("恶客走到无人守护的路尽头才判负", loss.called)
 var mushroom = sim.place_free("mushroom", 1, 0)
 sim._update_mine(mushroom, 7.0)
 check("坟头菇半程尚未成熟", not mushroom.armed and mushroom.arm_t >= 7.0)
 sim._update_mine(mushroom, 7.0)
 check("坟头菇成熟有独立音效", mushroom.armed and sim.sounds.has("mushroom_grow"))
 for kind in ["market", "water"]:
  for i in range(1, 4):
   check("%s障碍立绘%d" % [kind, i], ResourceLoader.exists("res://assets/sprites/obstacle-%s-%d.png" % [kind, i]))
 for i in range(1, 4):
  check("坟头菇成长立绘%d" % i, ResourceLoader.exists("res://assets/sprites/mushroom-growth-%d.png" % i))
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.start_battle(1, ["shooter", "lantern"])
 await process_frame
 game.set_setting("cheats", true)
 check("局内开启作弊后按钮即刻出现", game.hud._tool_cheat.visible)
 game.hud._tool_cheat.emit_signal("pressed")
 await process_frame
 check("点击作弊后面板即刻出现", game.hud.cheat_open and is_instance_valid(game.hud._cheat_panel) and game.hud._cheat_panel.visible)
 check("正式局第一次打开作弊默认慢放且计为调整", game.hud.slow_battle and game.speed == 0.1 and game.sim.cheated)
 var slow = button_named(game.hud._cheat_panel, "常规战斗 0.1× · 已开")
 if slow != null: slow.pressed.emit()
 await process_frame
 check("关闭慢放立即恢复常规速度", not game.hud.slow_battle and game.speed >= 1.0)
 var old_sun = game.sim.sun
 var add = button_named(game.hud._cheat_panel, "香火 +500")
 check("作弊面板有香火按钮", add != null)
 if add != null: add.emit_signal("pressed")
 check("作弊点击即刻生效而无需退出面板", game.sim.sun == old_sun + 500 and game.hud.cheat_open and game.sim.cheated)
 game.set_setting("cheats", false)
 check("关闭作弊选项后按钮和面板均收起", not game.hud._tool_cheat.visible and not game.hud.cheat_open)
 var upgraded = game.sim.place_free("shooter", 1, 2)
 game.sim.sun = 3000
 for i in 3: game.sim.try_upgrade(upgraded, 1, Vector2.ZERO)
 check("三阶升级触发专属音效与符印动画", game.sim.sounds.has("capstone") and game.sim.particles.any(func(effect): return effect.kind == "capstone_seal"))
 for boss_index in 3:
  var id: String = Almanac.BOSS_ORDER[boss_index]
  game.show_prep((boss_index + 1) * 5)
  game.screen_node.skip_cinema()
  await process_frame
  check("%s可从备战出没名单打开首领录" % Almanac.boss_name(id), Almanac.boss_portrait(id) != null)
  game.screen_node.open_zombie_almanac("boss-" + id)
  await process_frame
  check("%s首领录有对应页" % Almanac.boss_name(id), game.screen_node.tab == "boss" and game.screen_node.index == boss_index)
 game.show_prep(1)
 game.screen_node.skip_cinema()
 await process_frame
 game.screen_node._picked = ["shooter", "wall"]
 game.screen_node._start()
 check("无产香草木时开战弹出警告", game.screen == "prep" and game.screen_node._producer_warning != null and game.screen_node._producer_warning.visible)
 game.screen_node._producer_warning.confirmed.emit()
 await process_frame
 check("警告确认后可继续开战", game.screen == "battle")
 game.start_battle(0, ["shooter"], "tutorial")
 game.sim.tutorial["step"] = "almanac"
 game.hud.refresh()
 var book = button_named(game.hud, "打开图鉴")
 check("教程第六步呈现图鉴入口", book != null and book.visible)
 var help = button_named(game.hud, "试用救急菜单")
 if help != null: help.pressed.emit()
 check("新手课可安全试用救急菜单", game.hud.cheat_open and not game.hud.slow_battle and game.speed == 1.0)
 game.hud._toggle_cheat()
 book.pressed.emit()
 await process_frame
 check("从教程进入签筒图鉴", game.screen == "almanac" and game.screen_node.index == 1)
 game.close_overlay()
 await process_frame
 check("关闭图鉴后显示教程通关", game.screen == "result" and game.result.won)
 var image = "res://assets/bg/map-day1.png"
 var loading_assets: Array[String] = [image]
 await game._load_transition(loading_assets, "守夜将启", "res://assets/bg/loading-menu.png", true)
 check("加载进度达到100%时实际资源已加载", game._loading_hold.has(image)
  and game._loading_screen.displayed == 1.0)
 await game._reveal_loaded()
 check("加载淡出后释放遮罩、恢复操作", not game._loading_busy and game._loading_screen == null)
 print("TOTAL ", total, " FAILURES ", failures)
 quit(0 if failures == 0 else 1)
