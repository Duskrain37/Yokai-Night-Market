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


func player_feedback_regressions() -> void:
 var sim = Sim.new()
 sim.setup(Content.get_level(1), ["mushroom", "gust", "wall", "squash"], "easy")
 var mine = sim.place_free("mushroom", 3, 0)
 var tongue = sim.spawn_zombie("tongue", 0, {"x": mine.pos.x + 58.0})
 mine.arm_t = float(mine.def.mine.arm) - 0.02
 sim.tick(0.01)
 check("长舌鬼可从碰撞触发范围以外啃未出土的坟头菇", tongue.eating and not mine.armed and not mine.dead)
 sim.tick(0.02)
 check("坟头菇一出土就炸掉正在啃它的长舌鬼", mine.armed and mine.dead and not tongue.alive())

 var wall = sim.place_free("wall", 3, 1)
 var jumper = sim.spawn_zombie("vault", 1, {"x": wall.pos.x + 25.0})
 sim.update_zombies(0.01)
 sim.update_zombies(0.20)
 var landing: float = jumper.vault_to
 var gust = sim.place_free("gust", 2, 2)
 sim._update_gust(gust, 0.61)
 sim.update_zombies(0.81)
 sim.update_zombies(0.5)
 check("乌羽扇把跳幡鬼在空中的真实落点向后推两格",
  jumper.vaulted and is_equal_approx(jumper.pos.x, landing + 2.0 * Geo.CELL_W))

 var melon = sim.place_free("squash", 3, 3)
 var lead = sim.spawn_zombie("ghost", 3, {"x": melon.pos.x + 1.1 * Geo.CELL_W})
 var extra = sim.spawn_zombie("ghost", 3, {"x": lead.pos.x + 1.1 * Geo.CELL_W})
 var far = sim.spawn_zombie("ghost", 3, {"x": lead.pos.x + 1.3 * Geo.CELL_W})
 sim._update_squash(melon)
 sim.time += 0.60
 sim._update_squash(melon)
 check("镇煞瓜在1.2格内触发并砸中落点边缘，范围外不受伤",
  melon.dead and not lead.alive() and not extra.alive() and far.alive())

 sim.setup(Content.get_level(11), ["kelp"], "easy")
 var kelp = sim.place_free("kelp", 2, 3)
 var bride = sim.spawn_zombie("bride", 3, {"x": kelp.pos.x + 30.0, "sedan_split": true})
 sim._update_kelp(kelp)
 check("免疫灰烬的鬼新娘不触发缠魂藻", bride.alive() and not kelp.dead)
 var armored = sim.spawn_zombie("paper", 3, {"x": kelp.pos.x + 80.0})
 armored.hp = 5000.0
 armored.armor = 5000.0
 sim._update_kelp(kelp)
 check("缠魂藻同一帧拖沉厚甲恶客，鬼新娘安然通过",
  not armored.alive() and kelp.dead and bride.alive())

 for level in Content.LEVELS:
  var opening_ok := true
  for wave_index in range(3 * Content.WAVES_PER_GROUP):
   for group in level.waves[wave_index].groups:
    opening_ok = opening_ok and Content.ZOMBIES[group[0]].tier != "h"
  check("第%d关前3大波无高阶排波" % int(level.id), opening_ok)
 sim.setup(Content.get_level(1), ["shooter"], "easy")
 sim.queue_roster({"groups": [["mountain", 1]]}, 8)
 check("第三大波最后一拨实际刷中阶替换", sim.spawn_queue.front().type == "paper")
 sim.spawn_queue.clear()
 sim.queue_roster({"groups": [["mountain", 1]]}, 9)
 check("第四大波第一拨可实际刷高阶", sim.spawn_queue.front().type == "mountain")
 sim.spawn_queue = [{"type": "mountain", "row": 0, "wave_no": 8, "t": sim.time}]
 sim._release_queued_zombies()
 check("旧存档前三大波尚未放出的高阶也换成中阶", sim.zombies.size() == 1 and sim.zombies[0].type == "paper")
 sim.setup(Content.get_level(15), ["shooter"], "easy")
 for wave_index in range(2, 3 * Content.WAVES_PER_GROUP):
  sim.queue_roster(sim.level.waves[wave_index], -1, 1.0, false, true)
 check("首领已入场后，援军可使用原本的高阶来客",
  sim.spawn_queue.any(func(entry): return Content.ZOMBIES[entry.type].tier == "h"))
 for mode in ["easy", "normal", "hard"]:
  sim.setup(Content.get_level(1), ["shooter"], mode)
  var expected: float = {"easy": 1.0, "normal": 1.1, "hard": 1.25}[mode]
  var ghost = sim.spawn_zombie("ghost", 0)
  sim.rng.seed = 521
  var total_enemies := 0
  for sample in 1500:
   sim.spawn_queue.clear()
   sim.queue_roster({"groups": [["ghost", 1]]}, 9)
   total_enemies += sim.spawn_queue.size()
  check("模式 %s 的实际血量与期望出怪密度按指定倍率" % mode,
   is_equal_approx(ghost.max_hp, roundf(90.0 * sim.hp_mul * expected))
   and absf(float(total_enemies) / 1500.0 - expected) < 0.03)


func v051_content_regressions() -> void:
 var sim = Sim.new()
 sim.setup(Content.get_level(1), ["shooter"], "easy")
 for col in range(4):
  var donor = sim.place_free("shooter", col, 0)
  donor.upgrades[1] = 3
 var shooter = sim.place_free("shooter", 4, 0)
 sim.start_volley(shooter)
 check("四个满阶签筒只为全队叠加三发", sim._shooter_team_bonus() == 3 and shooter.burst.left == 3)
 var lamp = sim.place_free("lantern", 1, 2)
 var weak_lamp = sim.place_free("lantern", 2, 2)
 var judge = sim.place_free("judge", 4, 2)
 var star = sim.place_free("star", 3, 2)
 lamp.upgrades[3] = 3
 weak_lamp.upgrades[3] = 1
 judge.upgrades[3] = 3
 star.upgrades[1] = 3
 star.star_morale_stacks = 3
 star.star_morale_until = 5.0
 sim.refresh_plant_buffs()
 sim.spawn_zombie("ghost", 0, {"x": star.pos.x + 100.0})
 sim.shots.clear()
 sim._update_star(star, 2.0)
 check("巡灯50%自身、红灯笼25%和钟馗像25%相加，弱灯笼不叠加",
  is_equal_approx(star.buff_damage, 0.5) and not sim.shots.is_empty() and is_equal_approx(sim.shots[0].damage, 40.0))
 var pod = sim.place_free("cash-pod", 6, 0)
 var start = sim.sun
 sim.damage_plant(pod, 99.0)
 sim.damage_plant(pod, 1.0)
 check("铜钱荚按累计实际伤害发香火", sim.sun - start == 25)
 sim.damage_plant(pod, 2000.0)
 check("铜钱荚400耐久一共发四次，被毁额外再发一次", sim.sun - start == 125)
 var ruin = sim.place_free("ruin-cap", 4, 3)
 var inside = sim.spawn_zombie("ghost", 1, {"x": ruin.pos.x + Geo.CELL_W * 2.0})
 var outside = sim.spawn_zombie("ghost", 1, {"x": ruin.pos.x + Geo.CELL_W * 3.0})
 sim._update_ruin_cap(ruin, 1.2)
 check("劫火芝只覆盖五行五列内的恶客", not inside.alive() and outside.alive())
 sim.setup(Content.get_level(1), ["sky-kite", "wish-till", "ember-cicada"], "easy")
 var kite = sim.place_free("sky-kite", 2, 2)
 var near = sim.spawn_zombie("ghost", 2, {"x": kite.pos.x + Geo.CELL_W})
 var far = sim.spawn_zombie("tamer", 2, {"x": kite.pos.x + 3.0 * Geo.CELL_W})
 kite.upgrades[1] = 3
 sim._update_sky_kite(kite, 1.5)
 check("逐云鸢三级四发，缺少目标时重复瞄准最远恶客",
  sim.shots.size() == 4 and sim.shots[1].target == near
  and sim.shots[0].target == far and sim.shots[2].target == far and sim.shots[3].target == far)
 sim.shots.clear()
 kite.upgrades = {1: 0, 2: 0, 3: 3}
 sim._update_sky_kite(kite, 1.5)
 sim._update_lob_shot(sim.shots[0], 2.0)
 far.guest_special_at = sim.time
 sim._tick_guest_special(far)
 check("逐云鸢实际命中后减速并沉默巡相师，期间无法召唤",
  is_equal_approx(far.slow_amount, 0.30) and far.silence_until == sim.time + 2.0 and sim.pending_spawns.is_empty())
 var till = sim.place_free("wish-till", 4, 2)
 till.upgrades[2] = 3
 till.upgrades[3] = 2
 var guest = sim.spawn_zombie("ghost", 1, {"x": till.pos.x})
 sim._update_wish_till(till, 0.1)
 sim.time += 0.26
 sim._step_lane_pull(guest)
 check("清账匣拉人时有逐步横移并切到目标行", guest.row == till.row and guest.pull_row == till.row
  and guest.pos.y != sim.row_y(till.row) + 4.0)
 sim.time += 0.26
 sim._step_lane_pull(guest)
 start = sim.sun
 sim.shots.clear()
 sim.kill_zombie(guest)
 sim.kill_zombie(near)
 check("清账匣同行两次击退各给5香火，0.4秒只发一弹",
  sim.sun - start == 10 and sim.shots.size() == 1 and sim.shots[0].damage == 80.0)
 var ember = sim.place_free("ember-cicada", 5, 2)
 sim.shots.clear()
 for index in range(4):
  sim._update_ember(ember, 1.2)
 check("烬翼蝉四发后开始4.8秒蓄火", sim.shots.size() == 4 and ember.ember_ammo == 0
  and is_equal_approx(ember.ember_ready_at - sim.time, 4.8))
 sim.time = ember.ember_ready_at
 sim._update_ember(ember, 0.01)
 check("烬翼蝉蓄火结束补满四发并可立即出手", sim.shots.size() == 5 and ember.ember_ammo == 3)
 ember.upgrades[3] = 3
 var dying = sim.spawn_zombie("ghost", 2, {"x": ember.pos.x + 40.0})
 dying.hp = 0.2
 sim.apply_burn(dying, 2.5, 40.0, "ember-cicada", ember.uid)
 sim.update_zombies(0.02)
 check("烬翼蝉点燃击杀只返还给原本发射的草木", ember.ember_ammo == 4 and ember.timer >= 0.6)
 sim.setup(Content.get_level(1), ["shooter", "wall"], "easy")
 var flinch = sim.spawn_zombie("flinch", 0, {"x": 900.0})
 var slow: float = flinch.speed
 sim.damage_zombie(flinch, 5.0)
 check("惊巷鬼受伤后比饿鬼走得快", slow < Content.ZOMBIES.ghost.speed and flinch.speed > Content.ZOMBIES.ghost.speed)
 var mud = sim.spawn_zombie("formless", 1, {"x": 900.0})
 mud.hp = 1000.0
 var evaded := 0
 for index in range(100):
  if sim.damage_zombie(mud, 1.0) == 0.0:
   evaded += 1
 mud.eating = true
 check("泥影约半数免伤，啃食时必受伤", evaded >= 30 and evaded <= 70 and sim.damage_zombie(mud, 1.0) == 1.0)
 var reed = sim.spawn_zombie("reed-shot", 2, {"x": 950.0})
 var first = sim.place_free("wall", 3, 2)
 var second = sim.place_free("wall", 1, 2)
 reed.pos.x = reed.reed_stop_x
 sim._update_reed_guest(reed, 0.01)
 sim.time += 1.2
 sim.shots.clear()
 sim._update_reed_guest(reed, 0.01)
 sim.update_shots(3.0)
 check("芦管客停在进场1.5格，射弹只击中同行第一株并造成40伤害",
  is_equal_approx(reed.pos.x, 950.0 - 1.5 * Geo.CELL_W) and first.hp == first.max_hp - 40.0 and second.hp == second.max_hp)
 var flags := 0
 for batch in range(12):
  sim.spawn_queue.clear()
  sim.summon_next_wave()
  var count: int = sim.spawn_queue.filter(func(entry): return entry.type == "wave-herald").size()
  if count == 1 and Content.is_flag_batch(batch) and sim.banner.get("text", "") == "一大波恶客正在靠近":
   flags += 1
  elif count != 0:
   flags -= 100
 check("四大波各一名执幡客，其他小拨不会刷出", flags == 4)
 for week in range(4, 6):
  for night in range(5):
   var level := Content.get_level(Content.level_id_for(week, night))
   var theme_guest: String = level.theme_zombie
   var actual := Content.plants_in_level(level)
   check("第%d周第%d夜有本夜教学和对应来客" % [week, night + 1],
    not String(level.theme).is_empty() and (theme_guest.is_empty() or actual.has(theme_guest)))
 var featured := {}
 for map in ["street", "market", "water", "island", "cavern"]:
  var picks := Content.loadout_tips(map)
  var ranks := {}
  for type in picks:
   ranks[type] = Content.tip_rank(map, type)
  check("%s 的全部草木各有明确推荐顺位" % map,
   picks.size() == 27 and ranks.size() == 27 and not ranks.values().has(999))
  for type in picks.slice(0, 10):
   featured[type] = true
 check("五株新草木各有适合入选推荐前十的地图",
  ["ruin-cap", "sky-kite", "wish-till", "cash-pod", "ember-cicada"].all(func(type): return featured.has(type)))


func run() -> void:
 root.content_scale_size = Vector2i(1600, 900)
 player_feedback_regressions()
 v051_content_regressions()
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
   if index < level.waves.size() - 1:
    for entry in base.spawn_queue: before_boss[entry.type] = true
  check("第%d夜来客换班保留数量和耐久预算" % int(level.id), mass_kept)
  if String(level.boss_id) != "":
   var eligible: Array = Content.ZOMBIE_ORDER.filter(func(type): return type not in ["bride", "wave-herald"] and (type != "reedboat" or level.day == 3))
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
