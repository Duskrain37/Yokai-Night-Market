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
 check("暗河前后单位仅差1.05倍", is_equal_approx(float(Geo.STAGES.day3.near_scale) / float(Geo.STAGES.day3.far_scale), 1.05))
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
 var old_sun = game.sim.sun
 var add = button_named(game.hud._cheat_panel, "香火 +500")
 check("作弊面板有香火按钮", add != null)
 if add != null: add.emit_signal("pressed")
 check("作弊点击即刻生效而无需退出面板", game.sim.sun == old_sun + 500 and game.hud.cheat_open and game.sim.cheated)
 game.set_setting("cheats", false)
 check("关闭作弊选项后按钮和面板均收起", not game.hud._tool_cheat.visible and not game.hud.cheat_open)
 game.show_prep(1)
 game.screen_node.skip_cinema()
 await process_frame
 game.screen_node._picked = ["shooter", "wall"]
 game.screen_node._start()
 check("无产香草木时开战弹出警告", game.screen == "prep" and game.screen_node._producer_warning != null and game.screen_node._producer_warning.visible)
 game.screen_node._producer_warning.confirmed.emit()
 await process_frame
 check("警告确认后可继续开战", game.screen == "battle")
 print("TOTAL ", total, " FAILURES ", failures)
 quit(0 if failures == 0 else 1)
