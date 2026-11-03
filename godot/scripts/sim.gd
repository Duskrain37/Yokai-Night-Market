## 对局模拟：与绘制、界面完全解耦的纯逻辑层。
##
## 数值与规则移植自 v0.2.4 的 www/src/game/game.js（18 草木 / 12 恶客 / 三天地图 /
## 十二波 / 三路升阶 / 训练场 / 教学关）。渲染与 UI 只读这里的状态，测试也可以在
## 无窗口模式下直接跑这一层。
##
## 必须守住的设计不变量：
##  1. 状态（减速/易伤/灼烧/恶客加速）一律「更强才覆盖、同强才续时、弱效果不延长也不回退」。
##  2. 护具先于本体：攻击先扣 armor，破具后才伤 hp。
##  3. 每座最多开两路，每路逐级，只有一路能到三级（见 Upgrades.path_status）。
##  4. 尸体在死亡动画期间仍然挡射弹，但不啃食。
##  5. 训练场不刷波次、不判负、不写存档；教学关不写存档。
class_name Sim
extends RefCounted


class Plant:
	var uid = ""
	var paid_incense = 0
	var sealed_until = 0.0
	var sleep_until = 0.0
	var boss_recycled = false
	var type = ""
	var def: Dictionary = {}
	var row = 0
	var col = 0
	var pos = Vector2.ZERO
	var hp = 0.0
	var max_hp = 0.0
	var timer = 0.0
	var phase = 0.0
	var action_at = -10.0
	var recoil = 0.0
	var pulse = 0.0
	var charge = 0.0
	var bite_t = 0.0
	var dead = false
	var buff_damage = 0.0
	var haste = 0.0
	var upgrades: Dictionary = {}
	var shell = 0.0
	var shell_max = 0.0
	var shell_pulse = 0.0
	var is_lily = false
	var on_lily = false
	var chew_t = 0.0
	var chew_max = 0.0
	var chew_prey = ""
	var echoes: Array = []               # 铜铃余音：[{t, duration, radius, final}]
	var ash = false                      # 香灰堆：被拆后的香炉，仍占格
	var secondary: Dictionary = {}         # 半开：副收妖槽 {busy, t, max}
	var tertiary: Dictionary = {}          # 双开：第二个副收妖槽
	var busy_flag = false                  # 本拍是否已经用掉主槽
	var pull_until = 0.0
	var bone_until = 0.0
	var income_until = 0.0
	var reflect_paid = 0.0                 # 本拍已经付出去的整伞反伤额度
	var save_used = 0                      # 不破：已经用掉的免死层数
	var save_until = 0.0
	var chew_armor = 0.0
	var wish = 0.0                         # 愿盾：替这一株挡在伤害前面的点数
	var wish_t = 0.0
	var wish_guard = 0.0
	var umbrella_shield_unlocked = false
	var lob_heat_stacks = 0
	var lob_heat_until = 0.0
	var lob_followup_at = -1.0
	var lob_followup_aim = Vector2.ZERO
	var censer_followup_at = -1.0
	var censer_followup_ready = 0.0
	var lion_throw_until = 0.0
	var dragon_mode = "near"
	var dragon_from = "near"
	var dragon_switch_at = -10.0
	var dragon_switch_until = 0.0
	var dragon_near_at = -10.0
	var dragon_far_at = -10.0
	var dragon_near_timer = 0.0
	var dragon_far_timer = 0.0
	var dragon_volley_left = 0
	var dragon_volley_at = 0.0
	var dragon_aim = Vector2.ZERO
	var squash_at = -1.0
	var squash_aim = Vector2.ZERO
	var squash_target: Zombie = null
	var lion_charge = 0.0                  # 吞煞：狮头里存着的煞
	var brace_t = 0.0                      # 踩街：蹲桩剩余时长
	var brace_until = 0.0
	var large_strip_until = 0.0
	var dance_t = 0.0                      # 最后一舞：延迟退场剩余秒数
	var danced = false
	var cheer = 0                          # 喝彩层数
	var cheer_t = 0.0
	var cheer_value = 0.0
	var spark_window = 0.0                 # 掉星：每盆每秒的火星预算
	var oil_until = 0.0                    # 泼油：同一盆的触发冷却
	var no_bite_t = 0.0                    # 火墙：脱离啃食的计时
	var needle_shots = 0                   # 无影：这株针已经放过几轮
	var volley_count = 0                   # 三更：这株汤圆已经抛过几轮
	var star_round = 0                     # 灯轮：重灯转到第几道
	var judge_named: Zombie = null         # 点名：上一轮点的是谁
	var arm_t = 0.0
	var armed = false
	var pull_t = 0.0
	var burst: Dictionary = {}
	var adj_flip = 0
	var tutorial_idle = false
	var death_t = -1.0
	var heal_t = 0.0
	var guard = 0.0
	var guard_t = 0.0
	var halve_next = false
	var ten_flames_ready_at = 0.0
	var lion_wave_t = 0.0
	var lion_wave_end = 0.0
	var bell_hits: Dictionary = {}
	var ward_spent = false
	var ward_until = 0.0
	var firework_extra_at = -1.0
	var firework_extra_aim = Vector2.ZERO
	var firework_seek_timer = 0.0
	var star_guardian_until = 0.0
	var star_morale_stacks = 0
	var star_morale_until = 0.0

	func tier(path_id: int) -> int:
		return int(upgrades.get(path_id, 0))


class Zombie:
	var uid = ""
	var boss_role = ""
	var boss_meta: Dictionary = {}
	var type = ""
	var def: Dictionary = {}
	var row = 0
	var pos = Vector2.ZERO
	var hp = 0.0
	var max_hp = 0.0
	var armor = 0.0
	var max_armor = 0.0
	var armor_type = ""
	var armor_name = ""
	var speed = 0.0
	var slow_t = 0.0
	var slow_amount = 0.0
	var vuln_t = 0.0
	var armor_vuln_until = 0.0
	var gust_left = 0.0
	var gust_speed = 0.0
	var vuln = 0.0
	var burn_t = 0.0
	var burn_dps = 0.0
	var burn_src = ""
	var rage_t = 0.0
	var rage_mult = 1.0
	var stun_t = 0.0
	var cc_log: Array = []               # 共享控制账本：[时间, 秒数]
	var cc_immune = 0.0                  # 再控免疫：刚被控完的一小段内不再吃新硬控
	var mv_log: Array = []               # 位移账本：[时间, 格数]（绝对值，正负不抵销）
	var reverse_t = 0.0                  # 回头：移动方向暂时反转（引客 3-1）
	var reverse_icd = 0.0                # 同一名敌人的"回头"内置冷却
	var bleed_t = 0.0
	var bleed_dps = 0.0
	var marks: Dictionary = {}             # 香印／狐记／死印／针穴：kind -> {stacks, t}
	var punish_until = 0.0                 # 处决类效果的每敌冷却
	var nail_walk = 0.0                    # 钉住：挨钉之后往前挪了多少（击退与拖回不记账）
	var collide_until = 0.0                # 带人／相撞：同一名的碰撞冷却
	var wall_until = 0.0                   # 巡街：撞进场边界的定身冷却
	var execute_until = 0.0                # 死印：同一名的处决结算冷却
	var spread_until = 0.0                 # 连坐：同一名的分印冷却
	var strip_until = 0.0                  # 判死：同一名的剥甲冷却
	var suppress_t = 0.0                   # 显灵：增益被按住的剩余秒数
	var suppress_until = 0.0              # 显灵：同一名的封益冷却
	var attach_until = 0.0                # 贴馅：同一名的附着冷却
	var debris_until = 0.0                # 砸飞：同一名的残片冷却
	var heavy_until = 0.0                 # 灯轮：重灯推人的每敌冷却
	var bomb_t = 0.0                      # 贴馅：身上那颗还要几秒炸
	var bomb_damage = 0.0
	var ignite_until = 0.0                 # 点火：同一目标的引爆冷却
	var lock_until = 0.0                   # 锁魂：同一目标的三层结算冷却
	var throw_until = 0.0                # 同一名敌人吃重摔的冷却
	var step_until = 0.0                 # 同一名敌人被拉近的冷却
	var step_hit_until = 0.0             # 前探踩伤的一轮去重
	var eating = false
	var chomp = 0.0
	var eat_bite = 0.0
	var eat_snd_t = 0.0
	var anim = 0.0
	var phase = 0.0
	var hurt = 0.0
	var armor_pulse = 0.0
	var aura_t = 0.0
	var aura_pulse = 0.0
	var support_t = 0.0
	var support_pulse = 0.0
	var wail_t = 0.0
	var dying = false
	var dead = false
	var death_t = 0.0
	var death_dur = 0.5
	var breached = false
	var wave_no = -1
	var water_entered = false
	var water_entry_t = 0.0
	var vaulted = false
	var vault_t = 0.0
	var vault_from = 0.0
	var vault_to = 0.0
	var vault_arc = 0.0
	var last_object = ""
	var object_hop = 0.0
	var split_done = false
	var sedan_has_bride = false
	var guest_action_at = -10.0
	var guest_special_at = 0.0
	var revive_at = -1.0
	var revived = false
	var phase_form = 0
	var phase_switched = false

	func alive() -> bool:
		return not dead and not dying

	func is_large() -> bool:
		return bool(def.get("large", false))


class Shot:
	var uid = ""
	var kind = "pea"       # pea / homing / lob / star
	var src = ""            # 开火草木的类型，结算页按它归因
	var look = ""           # 只影响画法：巡灯的折返弹仍是一团灯焰
	var pos = Vector2.ZERO
	var row = 0
	var speed = 0.0
	var damage = 0.0
	var base_damage = 0.0
	var lantern_buff = 0.0
	var torch_buff = 0.0
	var firework_radius = 0.0
	var armor_vulnerability = 0.0
	var pierce_all = false
	var torch_splash_ratio = 0.0
	var torch_splash_radius = 0.0
	var owner_uid = ""
	var dead = false
	var big = false
	var pierce_armor = false
	var vuln = 0.0
	var vuln_duration = 2.0
	var burn = 0.0
	var burn_duration = 2.0
	var slow = 0.0
	var slow_duration = 1.5
	var knock = 0.0
	var root_chance = 0.0
	var root_duration = 0.0
	var blast = 0.0
	var armor_double = false
	var speed_boosted = false
	var fire = false
	var fire_t = 0.0
	# homing
	var target: Zombie = null
	var hit_ids: Array = []
	var hits_left = 1
	var delay = 0.0                 # 排队发射：一串／连抛
	var orbit = 0.0                 # 绕：绕目标转半圈的半径（px）
	var orbit_done = 0.0
	var graze = 0.0                 # 擦伤一下多少
	var volley: Dictionary = {}     # 同一轮共享：{grazed: [], marked: [], graze_cap: n}
	var mark = 0.0                  # 狐记：留下多少易伤
	var mark_duration = 0.0
	var ignite = 0.0                # 点火：第二层炸一下多少
	var ignite_radius = 0.0
	var ignite_targets = 0
	var ignite_icd = 0.0
	var lock_root = 0.0             # 锁魂：第三层定身
	var lock_large_root = 0.0
	var lock_vuln = 0.0
	var lock_vuln_duration = 0.0
	var lock_icd = 0.0
	var retarget = 0                # 回魂：目标中途死亡时允许改追几次
	# 直弹的穿堂与补针（透骨针）
	var pierce_left = 0             # 这根针还能再穿几名
	var pierce_factors: Array = []  # 每一档吃多少比例的主伤
	var armor_strip = 0.0           # 排针：穿过去时另削的护具
	var pin = 0.0                   # 无影：钉一下多少秒
	var pin_large = 0.0
	var nail = 0.0                  # 钉住：拔针受多少本体伤害
	var nail_cap = 0
	var nail_life = 0.0
	var move_threshold = 0.0        # 往前挪多少格拔一根（0 = 不留针）
	var share_radius = 0.0          # 同穴：记号分享给身边多远的
	var share_targets = 0
	var split_factor = 0.0          # 三向：补针是主针的几成
	var split_radius = 0.0
	var split_targets = 0
	var glow = 0.0                # 余光：穿过灯焰余辉后另加的一档增幅
	var counted = false           # 聚照：这一束有没有在目标身上记过名
	var heavy = false             # 灯轮：这一束是不是重灯
	var heavy_knock = 0.0
	var heavy_knock_icd = 0.0
	var focus = 1.0               # 侧照：这一道主束的基础倍率
	var converge = 0.0            # 聚照：第二道起每道加几成
	# lob
	var start = Vector2.ZERO
	var tx = 0.0
	var ty = 0.0
	var t = 0.0
	var flight = 0.9
	var crowd = 0.0               # 数馅：这一颗落地上涨几成，只放大直接命中
	var big_soup = false          # 三更：这一颗是大汤
	var splash_radius = 0.0
	var splash_ratio = 0.0
	var splash_targets = 0
	var payload: Dictionary = {}  # 落点要办的事：砸甲／残片／贴馅／一摊汤
	# star
	var dir = Vector2.ZERO
	var life = 5.0
	var seek = false
	var seek_factor = 1.0


const DIFFICULTY = {
	"easy": {"count": 1.0, "hp": 1.0},
	"normal": {"count": 1.25, "hp": 1.25},
	"hard": {"count": 1.5, "hp": 1.5},
}

const MAX_LOADOUT = 10

var level: Dictionary = {}
var level_id = 1
var rows = 5
var tiles: Array = []                 # rows × COLS，元素 {kind, obj, water}
var cells: Array = []                 # rows × COLS，主植物或 null
var lilies: Dictionary = {}           # "r:c" -> Plant
var plants: Array = []
var zombies: Array = []
var shots: Array = []
var orbs: Array = []
var particles: Array = []
var floaters: Array = []
var mowers: Array = []
var cards: Array = []                 # [{id, def, cd}]
var sun = 100
var time = 0.0
var wave_index = 0
var last_group = -1
var spawn_queue: Array = []
var pending_spawns: Array = []
var kills = 0
var plants_lost = 0
var lane_breaches: Array = []           # 每行被突破几次（门神动过）
var damage_by_type: Dictionary = {}     # 各草木造成的总伤害，结算页用它评「主力」
var wave_peak: Dictionary = {}          # 每一波的战况记录，用来找「最险一波」
var rows_planted: Dictionary = {}
var bell_death_until = 0.0              # 满街铃：同名全图事件共享冷却       # 哪些行至少守过一次（复盘用它找"整夜没人守的行"）
var natural_timer = 3.0
var shake = 0.0
var result: Dictionary = {}
var boss = null
var special_bosses_completed = 0
var wave_time_offset = 0.0
var special_rest_until = 0.0
var boss_history: Array=[]

var difficulty = "easy"
var count_mul = 1.0
var hp_mul = 1.0
var training = false
var tutorial: Variant = null
var no_cooldown = false
var cheated = false                     # 这一夜动过作弊面板：纪录另册，不进难度最好成绩
var auto_collect = true
var collect_delay = 0.0

var sounds: Array = []                # 本帧要播的音效名（含可选的品种）
var sound_detail: Array = []
var banner: Dictionary = {}
var rng = RandomNumberGenerator.new()

# 回调用：由 game.gd 接管胜负与存档
var on_win = Callable()
var on_lose = Callable()
var on_banner = Callable()


## User's revised ranges are the actual stage coefficients; no hidden water surcharge.
const WATER_THREAT_BONUS = 0.0


static func effective_threat(p_level: Dictionary) -> float:
	var value = float(p_level.get("threat", 1.0))
	if bool(p_level.get("special",false)):return value
	if String(p_level.get("map", "")) == "water":
		value += WATER_THREAT_BONUS
	return value


func setup(p_level: Dictionary, loadout: Array, p_difficulty: String = "easy") -> void:
	level = p_level
	level_id = int(p_level.get("id", 1))
	rows = clampi(int(p_level.get("rows", 5)), 5, 6)
	difficulty = p_difficulty if DIFFICULTY.has(p_difficulty) else "easy"
	var scale = sqrt(maxf(0.1, effective_threat(p_level)))
	count_mul = scale
	hp_mul = scale
	training = false
	tutorial = null
	no_cooldown = false
	cheated = false
	rng.seed = hash("%d:%s" % [level_id, difficulty])
	_reset(loadout)


func _reset(loadout: Array) -> void:
	tiles = _make_tiles()
	lilies.clear()
	cells = []
	for r in rows:
		var line: Array = []
		line.resize(Geo.COLS)
		line.fill(null)
		cells.append(line)
	plants.clear()
	zombies.clear()
	shots.clear()
	grounds.clear()
	orbs.clear()
	particles.clear()
	floaters.clear()
	spawn_queue.clear()
	pending_spawns.clear()
	mowers = []
	for r in rows:
		mowers.append({"row": r, "ready": true, "active": false, "x": Geo.MOWER_X})
	rows_planted = {}
	lane_breaches = []
	for r in rows:
		lane_breaches.append(0)
	damage_by_type = {}
	wave_peak = {}
	rows_planted = {}
	cards = []
	for id in loadout:
		if Content.PLANTS.has(id):
			cards.append({"id": id, "def": Content.PLANTS[id], "cd": 0.0})
	sun = int(level.get("start_sun", 100))
	time = 0.0
	wave_index = 0
	last_group = -1
	kills = 0
	plants_lost = 0
	plants_lost = 0
	natural_timer = 3.0
	shake = 0.0
	result = {}
	boss = null
	special_bosses_completed=0;wave_time_offset=0.0;special_rest_until=0.0;boss_history.clear()
	banner = {}


func _make_tiles() -> Array:
	var grid: Array = []
	for r in rows:
		var line: Array = []
		for c in Geo.COLS:
			line.append({"kind": "land", "obj": 0, "water": ""})
		grid.append(line)
	var map = String(level.get("map", "street"))
	if map == "water":
		for r in level.get("water_rows", []):
			if r < 0 or r >= rows:
				continue
			for c in Geo.COLS:
				grid[r][c] = {"kind": "water", "obj": -1,
					"water": "river" if r == 1 else "ditch"}
		for pair in level.get("object_cells", []):
			var r: int = pair[0]
			var c: int = pair[1]
			if r >= 0 and r < rows and c >= 0 and c < Geo.COLS:
				grid[r][c] = {"kind": "object", "obj": (r + c) % 3,
					"water": "river" if r == 1 else "ditch"}
	elif map == "market":
		# 靠右四列随机 5 个障碍格；种子由关卡 id 固定，存档读回后位置不变。
		var local = RandomNumberGenerator.new()
		local.seed = hash("market-blocks:%d" % level_id)
		var pool: Array = []
		for c in range(Geo.COLS - 4, Geo.COLS):
			for r in rows:
				pool.append(Vector2i(c, r))
		for i in range(pool.size() - 1, 0, -1):
			var j = local.randi_range(0, i)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		for i in mini(5, pool.size()):
			var p: Vector2i = pool[i]
			grid[p.y][p.x] = {"kind": "blocked", "obj": i % 3, "water": ""}
	return grid


# ── 坐标与小工具 ────────────────────────────────────────────────────────────
func row_y(row: int) -> float:
	return Geo.row_y(row, rows)


func cell_pos(col: int, row: int) -> Vector2:
	return Geo.cell_center(col, row, rows)


func tile_at(col: int, row: int) -> Dictionary:
	if row < 0 or row >= rows or col < 0 or col >= Geo.COLS:
		return {"kind": "land", "obj": 0, "water": ""}
	return tiles[row][col]


func main_plant_at(col: int, row: int) -> Plant:
	if row < 0 or row >= rows or col < 0 or col >= Geo.COLS:
		return null
	return cells[row][col]


func lily_at(col: int, row: int) -> Plant:
	return lilies.get("%d:%d" % [row, col], null)


func unit_scale() -> float:
	return Geo.unit_scale(rows)


func difficulty_mult() -> Dictionary:
	return DIFFICULTY.get(difficulty, DIFFICULTY["easy"])


# ── 音效与特效队列 ──────────────────────────────────────────────────────────
func sfx(name: String, detail: Dictionary = {}) -> void:
	sounds.append(name)
	sound_detail.append(detail)


func spark(pos: Vector2, color: Color, count: int, power: float = 1.0) -> void:
	for i in count:
		var a = rng.randf() * TAU
		var sp = (40.0 + rng.randf() * 90.0) * power
		particles.append({
			"x": pos.x, "y": pos.y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 30.0 * power,
			"life": 0.3 + rng.randf() * 0.25, "max": 0.55,
			"size": 1.6 + rng.randf() * 2.2, "color": color, "kind": "circle",
		})


func ring(pos: Vector2, color: Color, radius: float, life: float = 0.5) -> void:
	particles.append({
		"x": pos.x, "y": pos.y, "vx": 0.0, "vy": 0.0,
		"life": life, "max": life, "size": radius, "color": color, "kind": "ring",
	})


func float_text(pos: Vector2, text: String, color: Color = Color(1, 0.88, 0.63),
		size: int = 18, life: float = 1.2) -> void:
	floaters.append({
		"x": pos.x, "y": pos.y, "text": text, "color": color,
		"life": life, "max": life, "size": size,
	})


func deny(text: String, at: Vector2) -> void:
	float_text(at, text, Color("#ff9d7a"), 17, 1.15)
	sfx("deny")


# ── 种植 ────────────────────────────────────────────────────────────────────
func can_place_at(type: String, col: int, row: int) -> Dictionary:
	if col < 0 or col >= Geo.COLS or row < 0 or row >= rows:
		return {"ok": false, "reason": "这里不能种"}
	var def: Dictionary = Content.PLANTS.get(type, {})
	if def.is_empty() or bool(def.get("attach", false)):
		return {"ok": false, "reason": "这里不能种"}
	var tile = tile_at(col, row)
	var main = main_plant_at(col, row)
	var lily = lily_at(col, row)
	if tile["kind"] == "blocked":
		return {"ok": false, "reason": "障碍挡住了，不能种"}
	if tile["kind"] == "object":
		return {"ok": false, "reason": "这里有物件，不能种"}
	if bool(def.get("lily", false)):
		if tile["kind"] != "water":
			return {"ok": false, "reason": "夜莲只能放在水面"}
		if main != null or lily != null:
			return {"ok": false, "reason": "这里已经摆了东西"}
		return {"ok": true, "reason": ""}
	if bool(def.get("water_only", false)):
		if tile["kind"] != "water":
			return {"ok": false, "reason": "缠魂藻只能种在水面"}
		if main != null or lily != null:
			return {"ok": false, "reason": "这里已经摆了东西"}
		return {"ok": true, "reason": ""}
	if tile["kind"] == "water":
		if lily == null:
			return {"ok": false, "reason": "水面要先放夜莲"}
		if main != null:
			return {"ok": false, "reason": "这里已经摆了东西"}
		return {"ok": true, "reason": ""}
	if main != null:
		return {"ok": false, "reason": "这里已经摆了东西"}
	return {"ok": true, "reason": ""}


func place_free(type: String, col: int, row: int) -> Plant:
	var check = can_place_at(type, col, row)
	if not bool(check["ok"]):
		return null
	var def: Dictionary = Content.PLANTS[type]
	var plant = Plant.new()
	plant.uid="p%d" % plant.get_instance_id()
	plant.type = type
	plant.paid_incense = int(def.get("cost", 0))
	plant.def = def
	plant.row = row
	plant.col = col
	plant.pos = cell_pos(col, row)
	plant.hp = float(def.get("hp", 300))
	plant.max_hp = plant.hp
	plant.phase = rng.randf() * TAU
	plant.upgrades = Upgrades.init_upgrades()
	if def.has("produce"):
		plant.timer = float(def["produce"]["interval"]) - float(def["produce"]["first"])
	elif def.has("shot"):
		plant.timer = float(def["shot"]["interval"])
	if bool(def.get("lily", false)):
		plant.is_lily = true
		lilies["%d:%d" % [row, col]] = plant
	else:
		cells[row][col] = plant
		if lily_at(col, row) != null:
			plant.on_lily = true
	plants.append(plant)
	rows_planted[row] = true
	refresh_plant_buffs()
	return plant


func try_place_card(index: int, col: int, row: int, at: Vector2) -> bool:
	if index < 0 or index >= cards.size():
		return false
	var card: Dictionary = cards[index]
	var def: Dictionary = card["def"]
	if float(card["cd"]) > 0.0 and not no_cooldown:
		deny("还没缓过手来", at)
		return false
	if sun < int(def["cost"]):
		deny("香火不够", at)
		return false
	if bool(def.get("attach", false)):
		var host = main_plant_at(col, row)
		if host == null:
			deny("先种一株草木，再罩龟甲", at)
			return false
		if host.shell > 0.0:
			deny("这里已经罩了龟甲", at)
			return false
		sun -= int(def["cost"])
		card["cd"] = 0.0 if no_cooldown else float(def["cooldown"])
		attach_shell(host)
		sfx("place")
		return true
	var check = can_place_at(card["id"], col, row)
	if not bool(check["ok"]):
		deny(String(check["reason"]), at)
		return false
	sun -= int(def["cost"])
	card["cd"] = 0.0 if no_cooldown else float(def["cooldown"])
	var plant = place_free(card["id"], col, row)
	if plant == null:
		return false
	ring(plant.pos + Vector2(0, 8), Color(1, 0.78, 0.42, 0.55), 46.0, 0.4)
	spark(plant.pos, Color(0.93, 0.76, 0.4), 9)
	sfx("place")
	if tutorial != null:
		var step = String(tutorial["step"])
		if step == "plant" and card["id"] == "shooter":
			tutorial["shooter"] = plant
			tutorial["row"] = plant.row
			tutorial["step"] = "upgrade"
		elif step == "wall" and card["id"] == "wall":
			# 第四课：请石磨挡在签筒前面，然后恶客上门
			tutorial["wall"] = plant
			tutorial["step"] = "battle"
			tutorial["battle_t"] = 1.6
	return true


func attach_shell(host: Plant) -> void:
	var hp = float(Upgrades.EFFECTS["shell"]["hp"])
	host.shell = hp
	host.shell_max = hp
	host.shell_pulse = 0.6
	float_text(host.pos + Vector2(0, -60), "龟甲罩上了", Color("#cfe0b0"), 16)
	spark(host.pos + Vector2(0, -20), Color("#c8d6a4"), 10)


func remove_shell(host: Plant) -> void:
	if host == null or host.shell <= 0.0:
		return
	host.shell = 0.0
	float_text(host.pos + Vector2(0, -52), "拆下龟甲罩", Color("#dce7c4"), 15)
	spark(host.pos + Vector2(0, -16), Color("#bfd0a0"), 8)
	sfx("shell")


func damage_plant(plant: Plant, amount: float, from: Zombie = null) -> void:
	if plant == null or plant.dead or amount <= 0.0:
		return
	if bool(plant.ash) or time < plant.ward_until:
		return
	amount *= 1.0 - plant_guard(plant)
	if from != null:
		plant.bite_t = maxf(plant.bite_t, 0.2)
	if plant.wish_t > 0.0 and plant.wish > 0.0:
		var eaten = minf(plant.wish, amount)
		plant.wish -= eaten
		amount -= eaten
		if plant.wish <= 0.001:
			plant.wish = 0.0
			plant.wish_t = 0.0
			plant.wish_guard = 0.0
			float_text(plant.pos + Vector2(0, -66), "愿伞碎了", Color("#ffe1a1"), 15, 1.0)
		if amount <= 0.0:
			return
	if plant.hp - amount <= 0.0 and _umbrella_death_save(plant, amount, from):
		return
	if plant.shell > 0.0:
		plant.shell -= amount
		plant.shell_pulse = 0.25
		if plant.shell <= 0.0:
			plant.shell = 0.0
			sfx("shell")
			float_text(plant.pos + Vector2(0, -54), "龟甲碎了", Color("#e8d6a8"), 15)
			for i in 10:
				particles.append({
					"x": plant.pos.x + rng.randf_range(-15, 15),
					"y": plant.pos.y - 8.0 - rng.randf() * 26.0,
					"vx": rng.randf_range(-65, 65), "vy": -40.0 - rng.randf() * 100.0,
					"life": 0.5 + rng.randf() * 0.4, "max": 0.9,
					"size": 3.0 + rng.randf() * 4.0,
					"color": Color("#d8cfae") if i % 2 else Color("#9e9a78"),
					"kind": "shard",
				})
		return
	if plant.guard_t > 0.0:
		amount *= 1.0 - plant.guard
	if plant.hp <= amount and not plant.ward_spent:
		for source in plants:
			if source.type == "judge" and source.tier(1) >= 3 and _judge_covers(source, plant):
				plant.ward_spent = true
				plant.ward_until = time + 3.0
				plant.hp = 1.0
				ring(plant.pos + Vector2(0, -20), Color("#ffe2a2"), 34.0, 0.6)
				sfx("shell")
				return
	plant.hp -= amount
	plant.bite_t = maxf(plant.bite_t, 0.2)
	_torch_oil(plant, from)
	if plant.hp <= 0.0:
		kill_plant(plant)


func kill_plant(plant: Plant, silent: bool = false) -> void:
	if plant == null or plant.dead:
		return
	if not silent and String(plant.type) == "lion" and _start_last_dance(plant):
		plant.hp = 1.0
		return
	# 火墙（3-3）：被恶客啃塌才炸，铲走的盆不欠这一圈火
	if not silent and String(plant.type) == "torch" and plant.tier(3) >= 3:
		_torch_wall(plant)
	plant.dead = true
	plant.shell = 0.0
	if plant.is_lily:
		lilies.erase("%d:%d" % [plant.row, plant.col])
	else:
		if cells[plant.row][plant.col] == plant:
			cells[plant.row][plant.col] = null
		if not silent:
			plants_lost += 1
	if not silent:
		sfx("plant_down")
		if String(plant.type) == "bell":
			bell_death_ring(plant)
	for i in 8:
		particles.append({
			"x": plant.pos.x + rng.randf_range(-12, 12), "y": plant.pos.y - 8.0,
			"vx": rng.randf_range(-60, 60), "vy": -40.0 - rng.randf() * 100.0,
			"life": 0.5, "max": 0.5, "size": 3.0 + rng.randf() * 3.0,
			"color": Color("#c9a15c"), "kind": "shard",
		})
	if not silent and plant.type == "wall":
		wall_blast(plant)
	refresh_plant_buffs()


func shovel_at(col: int, row: int) -> Dictionary:
	"""返回被铲掉的东西：{ok, text, shell}。龟甲罩与浮台可单独拆。"""
	var main = main_plant_at(col, row)
	var lily = lily_at(col, row)
	if tutorial != null:
		# 教学道具铲掉就没了这一课，直接不让铲（评测实测：误铲会把教程卡死）
		for key in ["shooter", "wall"]:
			var lesson: Plant = tutorial[key]
			if lesson != null and not lesson.dead and lesson.col == col and lesson.row == row:
				return {"ok": false, "text": "这一株还要用来上课，先别铲"}
	if main != null and main.shell > 0.0:
		shovel_effect(main, true)
		remove_shell(main)
		return {"ok": true, "text": "拆下龟甲罩"}
	if main != null:
		shovel_effect(main)
		kill_plant(main, true)
		return {"ok": true, "text": "已铲除"}
	if lily != null:
		if main_plant_at(col, row) != null:
			return {"ok": false, "text": "先移除上面的草木"}
		shovel_effect(lily)
		kill_plant(lily, true)
		return {"ok": true, "text": "已拆下夜莲"}
	return {"ok": false, "text": "这里没有东西"}


func shovel_effect(plant: Plant, shell_only: bool = false) -> void:
	particles.append({"x": plant.pos.x, "y": plant.pos.y, "plant": plant,
		"life": 0.52, "max": 0.52, "color": Color("#ba8c5e"), "kind": "shovel_lift", "shell_only": shell_only})
	sfx("shovel")


# ── 升阶 ────────────────────────────────────────────────────────────────────
func try_upgrade(plant: Plant, path_id: int, at: Vector2) -> Dictionary:
	if plant == null or plant.dead:
		return {"ok": false, "reason": "草木已经不在了"}
	var status = Upgrades.path_status(plant.type, plant.upgrades, path_id)
	if not bool(status["ok"]):
		var reason = String(status["reason"])
		deny(reason, at)
		return {"ok": false, "reason": reason}
	var cost = int(status["cost"])
	if sun < cost:
		deny("香火不够", at)
		return {"ok": false, "reason": "香火不够"}
	sun -= cost
	var next_tier = int(status["next_tier"])
	plant.upgrades[path_id] = next_tier
	plant.paid_incense += cost
	apply_hp_scale(plant)
	# 满阶是一次投资兑现：字更大、光罩更宽、震屏更重，让 225 香火花得有声响
	var capstone = next_tier == 3
	var path_color = Color(String(status["path"]["color"]))
	for i in range(floaters.size() - 1, -1, -1):
		if floaters[i].get("upgrade_plant") == plant.uid:
			floaters.remove_at(i)
	float_text(plant.pos + Vector2(0, -66),
		"%s·%s" % [String(status["path"]["name"]), String(status["name"])] if capstone
		else "%d-%d %s" % [path_id, next_tier, String(status["name"])],
		Color("#ffe1a1"), 21 if capstone else 18, 1.6 if capstone else 1.4)
	floaters.back()["upgrade_plant"] = plant.uid
	spark(plant.pos + Vector2(0, -18), path_color, 22 if capstone else 12)
	if capstone:
		particles.append({"x": plant.pos.x, "y": plant.pos.y, "life": 1.08, "max": 1.08,
			"color": path_color, "kind": "capstone_seal"})
	shake = maxf(shake, 2.0 if capstone else 3.0)
	plant.pulse = 0.5
	refresh_plant_buffs()
	sfx("capstone" if capstone else "upgrade")
	if tutorial != null and String(tutorial["step"]) == "upgrade" \
			and tutorial["shooter"] == plant:
		tutorial["step"] = "wall"
	return {"ok": true, "tier": int(status["next_tier"]), "cost": cost}


func refresh_plant_buffs() -> void:
	for plant in plants:
		if plant.dead:
			continue
		plant.buff_damage = 0.0
		plant.haste = 0.0
		if plant.cheer_t > 0.0:
			plant.haste += float(plant.cheer) * float(plant.cheer_value)
	var lantern_fx: Dictionary = Upgrades.EFFECTS["lantern"]
	for source in plants:
		if source.dead or source.sleep_until > time:
			continue
		if source.type == "judge" and source.tier(3) > 0:
			var judge_fx: Dictionary = Upgrades.EFFECTS["judge"]
			for target in plants:
				if _judge_covers(source, target):
					target.buff_damage = maxf(target.buff_damage, float(judge_fx["damage_buff"][source.tier(3)]))
					target.haste = maxf(target.haste, float(judge_fx["haste"][source.tier(3)]))
		if source.type == "lantern":
			var tier = source.tier(3)
			if tier <= 0:
				continue
			var reach: int = lantern_fx["buff_range"][tier]
			var value: float = lantern_fx["buff_damage"][tier]
			for target in plants:
				if target.dead or target == source or target.row != source.row:
					continue
				if tier < 3 and (target.col <= source.col or target.col - source.col > reach):
					continue
				target.buff_damage = maxf(target.buff_damage, value)
		# 铜铃不再给友军攻速：批复后三条路全做在铃声本身（回声／摄心／引客）

# ── 经济与波次 ──────────────────────────────────────────────────────────────
func update_economy(dt: float) -> void:
	if tutorial != null:
		return
	natural_timer -= dt
	if natural_timer <= 0.0:
		natural_timer = 8.0 + rng.randf() * 2.0
		orbs.append({
			"x": Geo.BOARD_X + 50.0 + rng.randf() * (Geo.BOARD_W - 100.0),
			"y": -24.0,
			"target_y": Geo.BOARD_Y + 70.0 + rng.randf() * (Geo.BOARD_H - 120.0),
			"landed": false, "life": 10.0, "value": 25,
			"phase": rng.randf() * TAU, "dead": false, "auto_t": 0.0,
		})


func update_waves() -> void:
	if training:
		return
	if boss != null:
		if boss.alive():
			_release_queued_zombies()
		elif bool(level.get("special", false)) and boss.finished():
			_finish_checkpoint()
		return
	var waves: Array = level.get("waves", [])
	while wave_index < waves.size() and time >= float(waves[wave_index]["t"])+wave_time_offset \
			and not checkpoint_waiting() and time>=special_rest_until:
		var wave: Dictionary = waves[wave_index]
		wave_index += 1
		var wave_no = wave_index - 1
		queue_wave(wave, wave_no)
	_release_queued_zombies()
	if checkpoint_waiting() and spawn_queue.is_empty() and pending_spawns.is_empty() and active_zombies()==0:
		boss=preload("res://scripts/boss_encounter.gd").new()
		boss.begin(self,String(level.boss_checkpoints[special_bosses_completed]))


func _release_queued_zombies() -> void:
	var keep: Array = []
	for entry in spawn_queue:
		if time < float(entry["t"]):
			keep.append(entry)
			continue
		var boss_wave = bool(entry.get("boss_wave", false))
		var z = spawn_zombie(String(entry["type"]), int(entry["row"]), {
			"wave_no": int(entry.get("wave_no", -1)),
			"mass_scale": float(entry.get("mass_scale", 1.0)), "boss_wave": boss_wave,
		})
		if boss_wave and z != null and boss != null:
			boss.add_count += 1
	spawn_queue = keep


func checkpoint_waiting() -> bool:
	return bool(level.get("special",false)) and special_bosses_completed<3 \
		and wave_index>=(special_bosses_completed+1)*12


func _finish_checkpoint() -> void:
	boss_history.append({"id":boss.id,"combat_s":maxf(0,float(boss.died_at)-float(boss.combat_at)),
		"direct_losses":boss.destruction_used,"damage":boss.total_damage})
	special_bosses_completed+=1
	special_rest_until = time
	if wave_index < Array(level.waves).size():
		var first_wave_lead = float(level.waves[0].t)
		wave_time_offset = time + first_wave_lead - float(level.waves[wave_index].t)
	boss=null
	# Preserve the actual surviving army, card timers and incense; no free field reset.
	if special_bosses_completed<3:
		var threat=float([2.0,2.5,3.5][special_bosses_completed])
		count_mul=sqrt(threat);hp_mul=sqrt(threat)
		banner={"text":"首领退散 · 继续深入鬼市", "t":4.0,"max":4.0}


func queue_wave(wave: Dictionary, wave_no: int = -1) -> void:
	if wave_no < 0:
		wave_no = maxi(0, wave_index - 1)
	if not training and tutorial == null and String(level.get("boss_id", "")) != "" \
			and wave_no >= Array(level["waves"]).size() - Content.WAVES_PER_GROUP:
		if boss == null:
			boss = preload("res://scripts/boss_encounter.gd").new()
			boss.begin(self, String(level["boss_id"]))
		return
	# 12 小波仍按原节奏出怪；旗帜波每三小波一面，报幕只在旗帜波上放
	var group_now = Content.wave_group_of(level, wave_no)
	var new_group = bool(wave.get("flag", false))
	last_group = group_now
	sfx("alert" if new_group else "wave")
	queue_roster(wave, wave_no, Content.wave_mass_ratio(level, wave_no), Content.wave_low_only(level, wave_no))
	if new_group:
		banner = {"text": "一大波恶客正在靠近", "group": group_now + 1,
			"groups": Content.wave_groups(level), "t": 3.6, "max": 3.6}
		shake = maxf(shake, 7.0)
		if on_banner.is_valid():
			on_banner.call(banner["text"])


## Adjust the sum of enemy HP and armor, including when a whole tier is excluded.
func queue_roster(wave: Dictionary, wave_no: int, mass_ratio: float = 1.0,
		low_only: bool = false, boss_wave: bool = false, delay: float = 0.0) -> void:
	var count_mult = count_mul * float(difficulty_mult()["count"])
	var original: Array = []
	var mass = 0.0
	var budget_groups: Array = wave.get("budget_groups", wave["groups"])
	var guest_slots: Array = wave.get("guest_slots", [])
	var actual_mass := 0.0
	for index in budget_groups.size():
		var group: Array = budget_groups[index]
		var expected = float(group[1]) * count_mult
		var count = maxi(1, int(floor(expected)) + int(rng.randf() < fposmod(expected, 1.0)))
		var source = String(group[0])
		var picks: Array = guest_slots[index] if not guest_slots.is_empty() else [source]
		for i in count:
			var type := String(picks[mini(picks.size() - 1, int(float(i) * picks.size() / count))])
			original.append({
				"t": time + delay + original.size() * 0.38 + rng.randf() * 0.25,
				"type": type, "row": choose_spawn_row(type), "wave_no": wave_no,
				"boss_wave": boss_wave,
			})
			actual_mass += _enemy_mass(type)
		mass += _enemy_mass(source) * count
	if mass_ratio >= 1.0:
		if actual_mass > 0.0 and not is_equal_approx(actual_mass, mass):
			for entry in original:
				entry["mass_scale"] = mass / actual_mass
		spawn_queue.append_array(original)
		return
	var roster: Array[String] = []
	for entry in original:
		roster.append(String(entry["type"]))
	var durability = 1.0
	if mass_ratio < 1.0:
		var budget = mass * mass_ratio
		var kept: Array[String] = []
		var kept_mass = 0.0
		var pool: Array[String] = roster.duplicate()
		while not pool.is_empty():
			var type: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			if low_only and String(Content.ZOMBIES[type]["tier"]) != "l":
				type = "ghost" if rng.randf() < 0.65 else "tongue"
			kept.append(type)
			kept_mass += _enemy_mass(type)
			if kept_mass >= budget:
				break
		while low_only and kept_mass < budget:
			var type = "ghost" if rng.randf() < 0.65 else "tongue"
			kept.append(type)
			kept_mass += _enemy_mass(type)
		roster = kept
		durability = budget / kept_mass if kept_mass > 0.0 else 1.0
	for i in roster.size():
		var type = roster[i]
		spawn_queue.append({
			"t": time + delay + i * 0.38 + rng.randf() * 0.25,
			"type": type, "row": choose_spawn_row(type), "wave_no": wave_no,
			"mass_scale": durability, "boss_wave": boss_wave,
		})


func _enemy_mass(type: String) -> float:
	var def: Dictionary = Content.ZOMBIES[type]
	return float(def["hp"]) + float(def.get("armor", 0.0))


func special_opening() -> bool:
	return bool(level.get("special", false)) and boss == null and special_bosses_completed in [1, 2] \
		and wave_index == special_bosses_completed * 12


func displayed_wave_count() -> int:
	return wave_index + 1 if special_opening() else wave_index


func completed_major_waves() -> int:
	var first_uncleared = wave_index
	for entry in spawn_queue:
		var index = int(entry.get("wave_no", -1))
		if index >= 0:
			first_uncleared = mini(first_uncleared, index)
	for z in zombies:
		if (z.alive() or (not z.dead and z.revive_at >= 0.0)) and z.wave_no >= 0:
			first_uncleared = mini(first_uncleared, z.wave_no)
	if boss != null and boss.alive() and not bool(level.get("special", false)):
		first_uncleared = mini(first_uncleared, wave_index - Content.WAVES_PER_GROUP)
	return maxi(0, int(first_uncleared / Content.WAVES_PER_GROUP))


func summon_next_wave() -> bool:
	if training or boss!=null or checkpoint_waiting() or time<special_rest_until:
		return false
	var waves: Array = level.get("waves", [])
	if wave_index >= waves.size():
		return false
	var wave: Dictionary = waves[wave_index]
	wave_index += 1
	var wave_no = wave_index - 1
	queue_wave(wave, wave_no)
	shake = maxf(shake, 4.0)
	return true


const PROJECTILE_SPEED_SCALE = 0.6


## 暗河两条水路各按陆路的 2/3 抽取。高阶恶客只走石台。
func choose_spawn_row(type: String) -> int:
	var water: Array = level.get("water_rows", [])
	if bool(Content.ZOMBIES.get(type, {}).get("water_only", false)):
		return int(water[rng.randi_range(0, water.size() - 1)]) if not water.is_empty() else -1
	if String(level.get("map", "")) != "water":
		return rng.randi_range(0, rows - 1)
	var high_tier = String(Content.ZOMBIES.get(type, {}).get("tier", "")) == "h"
	var choices: Array = []
	var total = 0.0
	for row in rows:
		if water.has(row) and high_tier:
			continue
		var weight = 2.0 / 3.0 if water.has(row) else 1.0
		total += weight
		choices.append([row, total])
	var draw = rng.randf() * total
	for choice in choices:
		if draw < float(choice[1]):
			return int(choice[0])
	return int(choices.back()[0])


func spawn_zombie(type: String, row: int, opts: Dictionary = {}) -> Zombie:
	if boss != null and boss.alive() and not bool(opts.get("sedan_split", false)) and not bool(opts.get("boss_wave", false)) \
			and not bool(opts.get("guest_summoned", false)) \
			and active_zombies() >= int(boss.config.adds.live_cap):
		return null
	var def: Dictionary = Content.ZOMBIES.get(type, {})
	if def.is_empty() or (bool(def.get("sedan_only", false)) and not bool(opts.get("sedan_split", false))):
		return null
	var hp_mult = hp_mul * float(difficulty_mult()["hp"]) * float(opts.get("mass_scale", 1.0))
	var hp_factor = float(opts.get("hp_factor", 1.0))
	var z = Zombie.new()
	z.uid="z%d" % z.get_instance_id()
	z.type = type
	z.def = def
	z.wave_no = int(opts.get("wave_no", -1))
	if type == "sedan":
		z.sedan_has_bride = bool(opts["sedan_bride"]) if opts.has("sedan_bride") else rng.randf() < 0.5
	z.row = clampi(row, 0, rows - 1)
	if bool(def.get("water_only", false)) and z.row not in level.get("water_rows", []):
		z.row = choose_spawn_row(type)
		if z.row < 0:
			return null
	if String(level.get("map", "")) == "water" and z.row in level.get("water_rows", []) \
			and String(def.get("tier", "")) == "h":
		z.row = choose_spawn_row(type)
	z.pos = Vector2(float(opts.get("x", Geo.SPAWN_X + rng.randf() * 70.0)),
		row_y(z.row) + 4.0)
	z.hp = maxf(1.0, round(float(def["hp"]) * hp_mult * hp_factor))
	z.max_hp = z.hp
	z.armor = maxf(0.0, round(float(def.get("armor", 0.0)) * hp_mult))
	z.max_armor = z.armor
	z.armor_type = String(def.get("armor_type", ""))
	z.armor_name = String(def.get("armor_name", ""))
	z.speed = float(def["speed"])
	if def.has("special_period"):
		z.guest_special_at = time + 4.0
	if type == "phaseguard":
		z.phase_form = int(opts["phase_form"]) if opts.has("phase_form") else rng.randi_range(0, 1)
	z.death_dur = 1.0 if bool(def.get("large", false)) else 0.5
	z.anim = rng.randf() * TAU
	z.phase = rng.randf() * TAU
	z.aura_t = 0.8 + rng.randf() * float(def["aura"]["interval"]) if def.has("aura") else 0.0
	z.support_t = 1.5 + rng.randf() * float(def["support"]["interval"]) \
		if def.has("support") else 0.0
	zombies.append(z)
	return z


func make_boss_proxy(role: String, row: int, x: float, health: float, extra: Dictionary) -> Zombie:
	var z=Zombie.new()
	z.uid="z%d" % z.get_instance_id()
	z.type="boss_"+role
	z.boss_role=role
	z.boss_meta=extra
	z.row=clampi(row,0,rows-1)
	z.pos=Vector2(x,row_y(z.row)+4.0)
	z.hp=health;z.max_hp=health
	z.def={"name":"首领本体" if role=="body" else "首领机关","hp":health,"large":role=="body",
		"speed":0.0,"damage":0.0,"tier":"h" if role=="body" else "l","sprite_h":70}
	zombies.append(z)
	return z


func flush_pending_spawns() -> void:
	if pending_spawns.is_empty():
		return
	var list = pending_spawns
	pending_spawns = []
	for entry in list:
		var options = Dictionary(entry).duplicate()
		options["hp_factor"] = float(entry.get("hp_factor", 1.0))
		spawn_zombie(String(entry["type"]), int(entry["row"]), options)


# ── 状态（不叠加）────────────────────────────────────────────────────────────
func apply_slow(z: Zombie, duration: float, amount: float = 0.5) -> void:
	if z == null or not z.alive() or duration <= 0.0:
		return
	var slow = clampf(amount, 0.0, 0.9)
	var current = z.slow_amount if z.slow_t > 0.0 else 0.0
	if slow > current + 0.0001:
		z.slow_amount = slow
		z.slow_t = duration
	elif absf(slow - current) <= 0.0001:
		z.slow_t = maxf(z.slow_t, duration)


func apply_vulnerable(z: Zombie, duration: float, amount: float) -> void:
	if z == null or not z.alive() or duration <= 0.0 or amount <= 0.0:
		return
	var current = z.vuln if z.vuln_t > 0.0 else 0.0
	if amount > current + 0.0001:
		z.vuln = amount
		z.vuln_t = duration
	elif absf(amount - current) <= 0.0001:
		z.vuln_t = maxf(z.vuln_t, duration)


func apply_burn(z: Zombie, duration: float, dps: float, src: String = "") -> void:
	if z == null or not z.alive() or duration <= 0.0 or dps <= 0.0:
		return
	var current = z.burn_dps if z.burn_t > 0.0 else 0.0
	z.burn_src = src if src != "" else String(z.burn_src)
	if dps > current + 0.0001:
		z.burn_dps = dps
		z.burn_t = duration
	elif absf(dps - current) <= 0.0001:
		z.burn_t = maxf(z.burn_t, duration)


## ── 共享控制账本（批复 §3：防止错峰永久控制）───────────────────────────────
## 新增的硬控制按受害者共享：滚动 4 秒内普通累计最多 1 秒、大型 0.5 秒；
## 已在控制中不刷新时长；控完普通 0.3 秒、大型 0.6 秒免疫再控；
## 剩余额度不足 0.1 秒直接拒绝事件——被拒的判死不能剥甲，也不排队补触发。
const CC_WINDOW = 4.0
const CC_BUDGET = [1.0, 0.5]            # [普通, 大型]
const CC_IMMUNE = [0.3, 0.6]
const CC_MIN = 0.1


func _ledger_prune(z: Zombie) -> void:
	var keep: Array = []
	for entry in z.cc_log:
		if float(entry[0]) + CC_WINDOW > time:
			keep.append(entry)
	z.cc_log = keep
	keep = []
	for entry in z.mv_log:
		if float(entry[0]) + MV_WINDOW > time:
			keep.append(entry)
	z.mv_log = keep


func try_hard_cc(z: Zombie, duration: float) -> bool:
	if z == null or not z.alive() or duration <= 0.0:
		return false
	# 用 0.0001 而不是 0：逐帧减 dt 会留下 1e-17 的尾巴，免疫期就永远走不完
	if z.stun_t > 0.0001 or z.cc_immune > 0.0001:
		return false
	var large = 1 if z.is_large() else 0
	_ledger_prune(z)
	var used = 0.0
	for entry in z.cc_log:
		used += float(entry[1])
	var left = float(CC_BUDGET[large]) - used
	if duration < CC_MIN or left < CC_MIN:
		return false
	var granted = minf(duration, left)
	z.cc_log.append([time, granted])
	apply_stun(z, granted)
	z.cc_immune = float(CC_IMMUNE[large])
	return true


## 位移另记一本账：滚动 6 秒内普通 0.6 格、大型 0.2 格，超额截短、不累积到下一次。
## 拉近与反向行走都消耗绝对额度，不能正负抵销刷预算。
## 受保护的旧石磨击退传 truncate=false：只记消耗、不截短。
const MV_WINDOW = 6.0
const MV_BUDGET = [0.6, 0.2]


func move_zombie(z: Zombie, cells: float, truncate: bool = true) -> float:
	if z == null or not z.alive() or absf(cells) <= 0.0001:
		return 0.0
	if z.boss_role != "":
		return 0.0
	var large = 1 if z.is_large() else 0
	var amount = absf(cells)
	_ledger_prune(z)
	if truncate:
		var used = 0.0
		for entry in z.mv_log:
			used += float(entry[1])
		amount = minf(amount, maxf(0.0, float(MV_BUDGET[large]) - used))
		if amount <= 0.0001:
			return 0.0
	z.mv_log.append([time, amount])
	var delta = amount if cells > 0.0 else -amount
	z.pos.x = clampf(z.pos.x + delta * Geo.CELL_W, Geo.BOARD_X, Geo.RETREAT_MAX_X)
	return amount


func apply_stun(z: Zombie, duration: float) -> void:
	if z == null or not z.alive() or duration <= 0.0:
		return
	if z.boss_role == "body":
		if boss != null:
			boss.control(duration)
		return
	z.stun_t = maxf(z.stun_t, duration)
	z.eating = false
	for i in 4:
		particles.append({
			"x": z.pos.x + rng.randf_range(-11, 11),
			"y": z.pos.y - 54.0 + rng.randf_range(-6, 6),
			"vx": rng.randf_range(-25, 25), "vy": -20.0 - rng.randf() * 40.0,
			"life": 0.5, "max": 0.5, "size": 2.0 + rng.randf() * 2.0,
			"color": Color("#ffe09a"), "kind": "circle",
		})


func apply_shot_statuses(z: Zombie, shot: Shot) -> void:
	if shot.vuln > 0.0:
		apply_vulnerable(z, shot.vuln_duration, shot.vuln)
	if shot.burn > 0.0:
		apply_burn(z, shot.burn_duration, shot.burn, String(shot.src))
	if shot.slow > 0.0:
		apply_slow(z, shot.slow_duration, shot.slow)
	if shot.root_chance > 0.0 and rng.randf() < shot.root_chance:
		apply_stun(z, shot.root_duration)


## 燎原（炭火盆 2-3）：射弹命中后爆炸，把灼烧一类的状态溅给旁边的恶客。
func apply_shot_blast(shot: Shot, victim: Zombie) -> void:
	if shot.blast <= 0.0 and shot.torch_splash_ratio <= 0.0 and shot.firework_radius <= 0.0:
		return
	var touched = false
	for z in zombies:
		if not z.alive() or z == victim:
			continue
		var distance = z.pos.distance_to(victim.pos)
		if shot.firework_radius > 0.0 and distance <= shot.firework_radius:
			damage_zombie(z, shot.damage * 0.30, false, false, String(shot.src), "", false, shot.kind)
			touched = true
		if shot.torch_splash_ratio > 0.0 and distance <= shot.torch_splash_radius:
			damage_zombie(z, shot.damage * shot.torch_splash_ratio, false, false, String(shot.src), "", false, shot.kind)
			touched = true
		if shot.blast <= 0.0 or distance > shot.blast:
			continue
		apply_shot_statuses(z, shot)
		z.hurt = 0.14
		touched = true
	ring(shot.pos + Vector2(0, -6), Color(1.0, 0.66, 0.3, 0.5),
		maxf(shot.firework_radius, maxf(shot.blast, shot.torch_splash_radius)) * 0.9, 0.34)
	spark(shot.pos, Color("#ffab52"), 9 if touched else 5)


# ── 主循环 ──────────────────────────────────────────────────────────────────
func tick(dt: float) -> void:
	for card in cards:
		if no_cooldown:
			card["cd"] = 0.0
		else:
			card["cd"] = maxf(0.0, float(card["cd"]) - dt)
	if not banner.is_empty():
		banner["t"] = float(banner["t"]) - dt
		if float(banner["t"]) <= 0.0:
			banner = {}
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 34.0)
	time += dt
	update_economy(dt)
	update_waves()
	update_plants(dt)
	update_zombies(dt)
	update_grounds(dt)
	update_shots(dt)
	# 先结算玩家伤害，再落 Boss 延迟伤害；同帧击败优先，杜绝死后拆卡。
	if boss != null:
		boss.tick(dt)
	update_mowers(dt)
	update_orbs(dt)
	update_particles(dt)
	flush_pending_spawns()
	note_wave_peak()
	_cleanup()
	if tutorial != null:
		update_tutorial(dt)
	elif is_cleared() and on_win.is_valid():
		on_win.call()


func _cleanup() -> void:
	var keep_plants: Array = []
	for p in plants:
		if not p.dead:
			keep_plants.append(p)
	plants = keep_plants
	var keep_zombies: Array = []
	for z in zombies:
		if not z.dead:
			keep_zombies.append(z)
	zombies = keep_zombies
	var keep_shots: Array = []
	for s in shots:
		if not s.dead:
			keep_shots.append(s)
	shots = keep_shots
	var keep_orbs: Array = []
	for o in orbs:
		if not bool(o["dead"]):
			keep_orbs.append(o)
	orbs = keep_orbs
	var keep_particles: Array = []
	for p in particles:
		if float(p["life"]) > 0.0:
			keep_particles.append(p)
	particles = keep_particles
	var keep_floaters: Array = []
	for f in floaters:
		if float(f["life"]) > 0.0:
			keep_floaters.append(f)
	floaters = keep_floaters


## 每一波记一笔战况：恶客峰值、最贴门的那个敌人、累计倒下的草木、门神出手次数。
func note_wave_peak() -> void:
	var row: Dictionary = {}
	var old = wave_peak.get(str(wave_index))
	if old is Dictionary:
		row = old
	var alive = active_zombies()
	var nearest = 1.0e9
	for z in zombies:
		if not z.dead:
			nearest = minf(nearest, z.pos.x)
	row["peak"] = maxi(int(row.get("peak", 0)), alive)
	if alive > 0:
		row["deep"] = minf(float(row.get("deep", 1.0e9)), nearest)
	if not row.has("lost_start"):row["lost_start"]=plants_lost
	row["lost"] = maxi(0,plants_lost-int(row.lost_start))
	var touched = 0
	for mower in mowers:
		if not bool(mower["ready"]):
			touched += 1
	if not row.has("mowers_start"):row["mowers_start"]=touched
	row["mowers"] = maxi(0,touched-int(row.mowers_start))
	wave_peak[str(wave_index)] = row


## 结算页的复盘数据：主力输出、最险一波、被突破的行、门神余量与星级。
func battle_summary() -> Dictionary:
	var top_type = ""
	var top_damage = 0.0
	for key in damage_by_type:
		if float(damage_by_type[key]) > top_damage:
			top_damage = float(damage_by_type[key])
			top_type = String(key)
	# 「最险」不等于「最多」：一个贴到门神的高阶恶客，比十个远处的小鬼紧急。
	# 分数 = 数量 + 贴门程度 + 倒下的草木 + 门神出手，四项里谁响听谁的。
	var riskiest = 0
	var risk_peak = 0
	var best_score = -1.0
	var span = maxf(1.0, float(Geo.BOARD_W))
	for key in wave_peak:
		var row: Dictionary = wave_peak[key]
		var alive = int(row.get("peak", 0))
		var deep = 0.0
		if row.has("deep"):
			deep = clampf(1.0 - (float(row["deep"]) - float(Geo.BOARD_X)) / span, 0.0, 1.0)
		var score = float(alive) * 0.35 + deep * 26.0 			+ float(int(row.get("lost", 0))) * 2.0 + float(int(row.get("mowers", 0))) * 6.0
		if score > best_score:
			best_score = score
			riskiest = int(key)
			risk_peak = alive
	var breached_rows: Array = []
	for r in lane_breaches.size():
		if int(lane_breaches[r]) > 0:
			breached_rows.append(r + 1)
	var mowers_used = 0
	for mower in mowers:
		if not bool(mower["ready"]):
			mowers_used += 1
	# 整夜一次都没种过草木的行：失败时最该说的一句话往往就是这个
	var empty_rows: Array = []
	for r in rows:
		if not rows_planted.has(r):
			empty_rows.append(r + 1)
	return {
		"top_type": top_type,
		"top_damage": roundi(top_damage),
		"riskiest_wave": riskiest,
		"risk_peak": risk_peak,
		"breached_rows": breached_rows,
		"mowers_used": mowers_used,
		"stars": 3 if mowers_used == 0 else (2 if mowers_used == 1 else 1),
		"left_sun": int(sun),
		"plants_lost": plants_lost,
		"empty_rows": empty_rows,
		"bosses_defeated":boss_history.size() if bool(level.get("special",false)) else (1 if boss!=null and not boss.alive() else 0),
		"boss_history":boss_history.duplicate(true),
	}


func active_zombies() -> int:
	var count = 0
	for z in zombies:
		if (z.alive() or (not z.dead and z.revive_at >= 0.0)) and z.boss_role not in ["body", "prop"]:
			count += 1
	return count


func is_cleared() -> bool:
	if training or tutorial != null:
		return false
	if bool(level.get("special",false)) and special_bosses_completed<3:return false
	if boss != null:
		return boss.finished()
	var waves: Array = level.get("waves", [])
	return wave_index >= waves.size() and spawn_queue.is_empty() and zombies.is_empty()


# ── 草木行为 ────────────────────────────────────────────────────────────────
func update_plants(dt: float) -> void:
	refresh_plant_buffs()
	for plant in plants:
		if plant.dead:
			continue
		if boss!=null:boss.damage_token="plant:%d:%.6f" % [plant.get_instance_id(),time]
		plant.recoil = maxf(0.0, plant.recoil - dt * 3.0)
		plant.lion_wave_t = maxf(0.0, plant.lion_wave_t - dt)
		plant.pulse = maxf(0.0, plant.pulse - dt)
		plant.bite_t = maxf(0.0, plant.bite_t - dt)
		plant.charge = 0.0
		plant.heal_t += dt
		if plant.cheer_t>0:
			plant.cheer_t=maxf(0,plant.cheer_t-dt)
			if plant.cheer_t<=0:plant.cheer=0
		if plant.sealed_until > time or plant.sleep_until > time:
			continue
		if plant.guard_t > 0.0:
			plant.guard_t = maxf(0.0, plant.guard_t - dt)
		if plant.shell_pulse > 0.0:
			plant.shell_pulse = maxf(0.0, plant.shell_pulse - dt)
		var def = plant.def
		if def.has("produce"):
			_update_producer(plant, dt)
		elif def.has("shot"):
			_update_shooter(plant, dt)
		elif def.has("pulse"):
			_update_bell(plant, dt)
		elif def.has("censer"):
			_update_censer(plant, dt)
		elif def.has("chomp"):
			_update_umbrella(plant, dt)
		elif def.has("melee"):
			_update_lion(plant, dt)
		elif def.has("mine"):
			_update_mine(plant, dt)
		elif def.has("tangle"):
			_update_kelp(plant, dt)
		elif def.has("homing"):
			_update_cat(plant, dt)
		elif def.has("lob"):
			_update_lobber(plant, dt)
		elif def.has("star"):
			_update_star(plant, dt)
		elif def.has("needle"):
			_update_needle(plant, dt)
		elif def.has("gust"):
			_update_gust(plant, dt)
		elif def.has("firework"):
			_update_firework(plant, dt)
		elif def.has("squash"):
			_update_squash(plant)
		elif def.has("dragon"):
			_update_dragon(plant, dt)
		elif def.has("judge"):
			_update_judge(plant, dt)
		elif def.has("torch"):
			plant.pulse = 0.18 + sin((time + plant.phase) * 3.2) * 0.08
			var tfx: Dictionary = Upgrades.EFFECTS["torch"]
			# 掉星（1-2）：每盆一秒攒回两颗火星的预算，攒不满就不掉
			var cap = float(tfx["sparks_per_second_cap"][plant.tier(1)])
			if cap > 0.0:
				plant.spark_window = minf(cap, plant.spark_window + cap * dt)
			# 火墙（3-3）：火胎养得住炭，但刚被啃过的 3 秒里不回填
			plant.no_bite_t = 0.0 if plant.bite_t > 0.0 else plant.no_bite_t + dt
			var t3 = plant.tier(3)
			if t3 >= 3 and plant.no_bite_t >= float(tfx["heal_delay"][t3]) \
					and plant.hp < plant.max_hp:
				plant.hp = minf(plant.max_hp, plant.hp + float(tfx["heal_dps"][t3]) * dt)
		elif plant.type == "wall":
			_update_wall(plant, dt)
		elif def.has("bomb"):
			plant.timer += dt
			if plant.timer >= float(def["bomb"]["fuse"]):
				explode(plant)
	if boss!=null:boss.damage_token=""


func lantern_value(plant: Plant) -> int:
	return int(Upgrades.EFFECTS["lantern"]["value"][plant.tier(1)])


func lantern_interval(plant: Plant) -> float:
	return float(Upgrades.EFFECTS["lantern"]["interval"][plant.tier(2)])


func _update_producer(plant: Plant, dt: float) -> void:
	if plant.tutorial_idle:
		return
	var interval = lantern_interval(plant)
	plant.timer += dt
	if plant.timer >= interval:
		plant.timer -= interval
		plant.action_at = time
		plant.pulse = 0.45
		sfx("produce")
		orbs.append({
			"x": plant.pos.x + rng.randf_range(-22, 22),
			"y": plant.pos.y - 30.0,
			"target_y": plant.pos.y - 30.0,
			"landed": true, "life": 9.0, "value": lantern_value(plant),
			"phase": rng.randf() * TAU, "dead": false, "auto_t": 0.0,
		})
		# 火树（2-3）：每次产出香火顺手甩出一枚灯焰
		var ember = float(Upgrades.EFFECTS["lantern"]["produce_shot"][plant.tier(2)])
		if ember > 0.0:
			plant.action_at = time
			plant.recoil = 0.8
			var shot = Shot.new()
			shot.pos = plant.pos + Vector2(16.0, -16.0)
			shot.row = plant.row
			shot.speed = 460.0
			_prepare_shot(shot, plant, ember)
			shot.fire = true
			shot.fire_t = 0.5
			shots.append(shot)


func lane_target(plant: Plant) -> Zombie:
	var nearest: Zombie=null
	for z in zombies:
		if z.alive() and z.row == plant.row and z.pos.x > plant.pos.x + 6.0:
			if nearest==null or z.pos.x<nearest.pos.x:nearest=z
	return nearest


func _update_shooter(plant: Plant, dt: float) -> void:
	if not plant.burst.is_empty():
		plant.burst["timer"] = float(plant.burst["timer"]) - dt
		if int(plant.burst["left"]) > 0 and float(plant.burst["timer"]) <= 0.0:
			fire_volley_shot(plant)
		if plant.burst.is_empty() or int(plant.burst.get("left", 0)) <= 0:
			plant.burst = {}
			plant.timer = 0.0
		return
	plant.timer += dt
	var target = lane_target(plant)
	var interval = float(plant.def["shot"]["interval"]) / (1.0 + plant.haste)
	if target != null:
		if plant.timer >= interval:
			plant.timer = 0.0
			start_volley(plant)
		else:
			plant.charge = minf(1.0, plant.timer / interval)
	else:
		plant.timer = minf(plant.timer, interval)


func start_volley(plant: Plant) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["shooter"]
	var adjacent = plant.tier(2)
	var volley = int(fx["volley"][plant.tier(1)])
	var bonus = int(fx["volley_bonus"][plant.tier(1)])
	if bonus > volley and rng.randf() < float(fx["volley_bonus_chance"][plant.tier(1)]):
		volley = bonus
	var lanes: Array = []
	var lane_shots: Array = []
	if adjacent > 0:
		if plant.row > 0:
			lanes.append(plant.row - 1)
		if plant.row < rows - 1:
			lanes.append(plant.row + 1)
		if adjacent == 1 and lanes.size() > 1:
			plant.adj_flip += 1
			lanes = [lanes[plant.adj_flip % 2]]
		# 全力（2-3）：补射总数 = 主行数 −1，两侧分摊，每侧最低一发
		var total = lanes.size()
		if bool(fx["adjacent_split"][adjacent]):
			total = maxi(lanes.size(), volley - 1)
		for i in lanes.size():
			lane_shots.append(int(total / lanes.size()) + (1 if i < total % lanes.size() else 0))
	plant.burst = {
		"left": volley,
		"index": 0,
		"timer": 0.0,
		"lanes": lanes,
		"lane_shots": lane_shots,
		"crit_chance": float(fx["crit_chance"][plant.tier(3)]),
		"crit_slow": float(fx["crit_slow"][plant.tier(3)]),
	}
	fire_volley_shot(plant)
	if plant.burst.is_empty() or int(plant.burst.get("left", 0)) <= 0:
		plant.burst = {}
		plant.timer = 0.0


func fire_volley_shot(plant: Plant) -> void:
	if plant.burst.is_empty():
		return
	var index = int(plant.burst["index"])
	var raw = float(plant.def["shot"]["damage"])
	var big = index == 0 and rng.randf() < float(plant.burst["crit_chance"])
	sfx("shoot")
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(20.0, -12.0 + (-2.0 if index % 2 == 0 else 2.0))
	shot.row = plant.row
	shot.speed = float(plant.def["shot"]["speed"])
	_prepare_shot(shot, plant, raw * (2.0 if big else 1.0))
	shot.big = big
	if float(plant.burst["crit_slow"]) > 0.0:
		shot.slow = 0.5
		shot.slow_duration = float(plant.burst["crit_slow"])
	shots.append(shot)
	if index == 0 and not plant.burst["lanes"].is_empty():
		var lane_index = 0
		for lane in plant.burst["lanes"]:
			var count = int(plant.burst["lane_shots"][lane_index])
			lane_index += 1
			for k in count:
				var extra = Shot.new()
				extra.pos = Vector2(plant.pos.x + 20.0, row_y(int(lane)) - 12.0)
				extra.row = int(lane)
				extra.speed = float(plant.def["shot"]["speed"])
				_prepare_shot(extra, plant, raw)
				shots.append(extra)
	plant.action_at = time
	plant.recoil = 1.0
	plant.charge = 0.0
	plant.burst["index"] = index + 1
	plant.burst["left"] = int(plant.burst["left"]) - 1
	plant.burst["timer"] = 0.09


## 冷炉（香炉 3-3）：塌成香灰堆，仍占着这一格，只放白板半径、白板四成的灰雾。
## 不继承任何升级、盖印、控制；香灰自己不能再产出香灰。再铲一次才腾格。
func _collapse_to_ash(plant: Plant) -> void:
	plant.ash = true
	plant.upgrades = {1: 0, 2: 0, 3: 0}
	plant.timer = 0.0
	plant.hp = 1.0e9
	plant.max_hp = 1.0e9
	plant.dead = false
	float_text(plant.pos + Vector2(0, -60), "塌成香灰", Color("#cfc7b4"), 17, 1.2)
	spark(plant.pos + Vector2(0, -10), Color("#cfc7b4"), 14)
	sfx("plant_down")


## 不破（3-3）：致命伤触发一层免死——该击结算后回到新上限的 30%，
## 上限永久 -200、最低 300；每层至少隔 2 秒；把被阻止的那部分按 50% 反弹（上限 150）。
func _umbrella_death_save(plant: Plant, amount: float, from: Zombie) -> bool:
	var fx: Dictionary = Upgrades.EFFECTS["umbrella"]
	var tier3 = plant.tier(3)
	if String(plant.type) != "umbrella" or tier3 < 3:
		return false
	var left = int(fx["death_saves"][tier3]) - int(plant.save_used)
	if left <= 0 or time < float(plant.save_until):
		return false
	plant.save_used = int(plant.save_used) + 1
	plant.save_until = time + float(fx["save_icd"][tier3])
	var prevented = maxf(0.0, amount - plant.hp)
	plant.max_hp = maxf(float(fx["hp_max_floor"][tier3]),
		float(plant.max_hp) - float(fx["hp_max_loss"][tier3]))
	plant.hp = float(plant.max_hp) * float(fx["restore_ratio"][tier3])
	float_text(plant.pos + Vector2(0, -80), "不破", Color("#ffe1a1"), 19, 1.2)
	ring(plant.pos + Vector2(0, -30), Color(0.98, 0.82, 0.5, 0.7), 46.0, 0.6)
	if from != null and prevented > 0.0:
		damage_zombie(from, minf(prevented * float(fx["reflect_ratio"][tier3]),
			float(fx["reflect_cap"][tier3])), false, false, plant.type)
	return true


func bell_slow(plant: Plant) -> float:
	return float(plant.def["pulse"]["slow"])


## 铜铃：一声主铃 + 若干声余音。主铃管减速与判定，余音只补减速。
func _update_bell(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["bell"]
	var pulse: Dictionary = plant.def["pulse"]
	var tier1 = plant.tier(1)
	var tier2 = plant.tier(2)
	var tier3 = plant.tier(3)
	_update_echoes(plant, dt)
	plant.timer += dt
	var interval = float(fx["main_interval"][tier1]) if tier1 > 0 \
		else float(pulse["interval"])
	interval /= 1.0 + plant.haste
	if plant.timer < interval:
		return
	var root_chance = float(fx["root_chance"][tier2])
	var root_duration = float(fx["root_duration"][tier2])
	var eater_chance = float(fx["eater_root_chance"][tier2])
	var eater_cap = int(fx["eater_target_cap"][tier2])
	var large_root = float(fx["large_root_duration"][tier2])
	var hit_any = false
	var eaters_taken = 0
	for z in zombies:
		if not z.alive() or z.row != plant.row or z.pos.x <= plant.pos.x - 8.0:
			continue
		var previous_hit = float(plant.bell_hits.get(z.uid, -1000.0))
		var repeated = previous_hit >= time - interval * 1.75
		plant.bell_hits[z.uid] = time
		var slow = float(fx["repeat_slow"][tier1]) if repeated else bell_slow(plant)
		apply_slow(z, float(pulse["slow_duration"]), slow)
		hit_any = true
		# 摄心：只有主铃判定、每敌一次；所有硬控都走共享控制账本
		if z.is_large():
			if large_root > 0.0:
				try_hard_cc(z, large_root)
		elif eater_chance > 0.0 and z.eating and eaters_taken < eater_cap:
			if try_hard_cc(z, root_duration):
				eaters_taken += 1
		elif root_chance > 0.0 and rng.randf() < root_chance:
			try_hard_cc(z, root_duration)
	if not hit_any:
		plant.timer = minf(plant.timer, interval)
		return
	plant.timer = 0.0
	plant.action_at = time
	plant.pulse = 0.55
	sfx("bell")
	ring(plant.pos + Vector2(0, -6), Color(0.56, 0.82, 0.85, 0.55), 26.0, 0.5)
	_bell_pull(plant, fx, tier3)
	var offsets: Array = fx["echo_offsets"][tier1]
	for i in offsets.size():
		plant.echoes.append({
			"t": float(offsets[i]),
			"duration": float(fx["echo_duration"][tier1]),
			"radius": float(fx["adjacent_radius"][tier1]),
			"final": i == offsets.size() - 1,
		})


## 余音：只补减速，不结算伤害、不触发摄心与引客（批复：子事件不得递归母事件效果）。
## 绕梁起相邻两行各收到半格的局部圆域，而不是整条邻行都被覆盖。
func _update_echoes(plant: Plant, dt: float) -> void:
	if plant.echoes.is_empty():
		return
	var fx: Dictionary = Upgrades.EFFECTS["bell"]
	var keep: Array = []
	for echo in plant.echoes:
		echo["t"] = float(echo["t"]) - dt
		if float(echo["t"]) > 0.0:
			keep.append(echo)
			continue
		var radius = float(echo["radius"]) * Geo.CELL_W
		for z in zombies:
			if not z.alive():
				continue
			if z.row == plant.row:
				if z.pos.x > plant.pos.x - 8.0:
					apply_slow(z, float(echo["duration"]), bell_slow(plant))
			elif radius > 0.0 and absi(z.row - plant.row) == 1 and absf(z.pos.x - plant.pos.x) <= radius:
				apply_slow(z, float(echo["duration"]), bell_slow(plant))
		if bool(echo.get("final", false)):
			_echo_drag(plant, fx)
		ring(plant.pos + Vector2(0, -6), Color(0.56, 0.82, 0.85, 0.3), 30.0, 0.4)
	plant.echoes = keep


## 三叠：末声把本行最靠前的一名非大型敌人往回拖 0.3 格（走位移账本，大型不位移）。
func _echo_drag(plant: Plant, fx: Dictionary) -> void:
	var tier1 = plant.tier(1)
	var cells = float(fx["knock_cells"][tier1])
	var wanted = int(fx["knock_targets"][tier1])
	if cells <= 0.0:
		return
	for z in zombies:
		if wanted <= 0:
			return
		if not z.alive() or z.is_large() or z.row != plant.row:
			continue
		if z.pos.x <= plant.pos.x - 8.0:
			continue
		if move_zombie(z, cells) > 0.0:
			wanted -= 1


## 引客：主铃把前方最远的一名敌人"叫回头"，成群再顺手带上他身边的同伴。
func _bell_pull(plant: Plant, fx: Dictionary, tier3: int) -> void:
	if tier3 <= 0:
		return
	var reach = float(fx["range_cells"][tier3]) * Geo.CELL_W
	var target: Zombie = null
	for z in zombies:
		if not z.alive() or z.is_large() or z.row != plant.row or z.reverse_icd > 0.0:
			continue
		if z.pos.x <= plant.pos.x - 8.0 or z.pos.x - plant.pos.x > reach:
			continue
		if target == null or z.pos.x > target.pos.x:
			target = z
	if target == null:
		return
	target.reverse_t = float(fx["reverse_duration"][tier3])
	target.reverse_icd = float(fx["reverse_icd"][tier3])
	float_text(target.pos + Vector2(0, -70), "回头", Color("#cfe0f0"), 15, 0.8)
	var cap = int(fx["companion_targets"][tier3])
	if cap <= 0:
		return
	var radius = float(fx["companion_radius"][tier3]) * Geo.CELL_W
	var slowed = 0
	for z in zombies:
		if slowed >= cap or z == target or not z.alive() or z.row != target.row:
			continue
		if absf(z.pos.x - target.pos.x) <= radius:
			apply_slow(z, float(fx["companion_duration"][tier3]),
				float(fx["companion_slow"][tier3]))
			slowed += 1


## 魂断：大型敌人啃铜铃时，把这次有效啃食伤害的 25% 变成自己的流血（上限 35/秒）。
## 流血是独立状态：不与灼烧混算，也不会再触发一次反伤。
func bell_backlash(plant: Plant, z: Zombie, bite_dps: float) -> float:
	if plant == null or String(plant.type) != "bell" or not z.is_large():
		return 0.0
	var fx: Dictionary = Upgrades.EFFECTS["bell"]
	var tier2 = plant.tier(2)
	var ratio = float(fx["backlash_ratio"][tier2])
	if ratio <= 0.0:
		return 0.0
	return minf(bite_dps * ratio, float(fx["backlash_dps_cap"][tier2]))


func apply_bleed(z: Zombie, dps: float, duration: float) -> void:
	if z == null or not z.alive() or dps <= 0.0:
		return
	z.bleed_dps = maxf(z.bleed_dps, dps)
	z.bleed_t = maxf(z.bleed_t, duration)


## 满街铃（铜铃 3-3）：被恶客啃毁时发出最后一声，全图定身一次。
## 同名全图事件共享冷却；铲除走 silent 分支，不触发。
func bell_death_ring(plant: Plant) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["bell"]
	var tier3 = plant.tier(3)
	if tier3 < 3:
		return
	if time < bell_death_until:
		return
	bell_death_until = time + float(fx["global_death_icd"][tier3])
	for z in zombies:
		if not z.alive():
			continue
		if z.is_large():
			try_hard_cc(z, float(fx["death_root_large"][tier3]))
		else:
			try_hard_cc(z, float(fx["death_root"][tier3]))
	banner = {"text": "满街铃 · 最后一声", "t": 1.6, "max": 1.6}
	shake = maxf(shake, 9.0)


## ── 地效与标记（批复 §3 的两套通用结算件）────────────────────────────────
## 地效：烟径、汤摊、火线、余光共用一条记录。同一敌人对同一条地效按 icd 节流，
## 所以"站在浓汤上"是按秒结算，不会逐帧各扣一次。
var grounds: Array = []


## extras 里可以带：cap（一次最多结算几名）、eater（站着啃草的额外每秒伤）、
## trip（绊住普通几秒）、trip_slow（大型只减速多少）。
func add_ground(kind: String, pos: Vector2, radius: float, life: float, damage: float,
		icd: float, slow: float = 0.0, slow_duration: float = 0.0,
		src: String = "censer", extras: Dictionary = {}) -> void:
	grounds.append({
		"kind": kind, "pos": pos, "radius": radius, "life": life, "damage": damage,
		"icd": icd, "slow": slow, "slow_duration": slow_duration, "src": src,
		"cap": int(extras.get("cap", 0)),
		"eater_damage": float(extras.get("eater", 0.0)),
		"large_slow": float(extras.get("large_slow", -1.0)),
		"trip": float(extras.get("trip", 0.0)),
		"trip_slow": float(extras.get("trip_slow", 0.0)),
		"trip_slow_duration": float(extras.get("trip_slow_duration", 0.0)),
		"buff": float(extras.get("buff", 0.0)),
		"hit": {},
	})


func update_grounds(_dt: float) -> void:
	var keep: Array = []
	for g in grounds:
		if boss!=null:boss.damage_token="ground:%d:%.6f" % [grounds.find(g),time]
		g["life"] = float(g["life"]) - _dt
		if float(g["life"]) <= 0.0:
			continue
		# 地效是一圈，不是一列：按平面距离算，免得火盆边上的一小团火烧穿整片夜市
		var pool: Array = []
		for z in zombies:
			if not z.alive():
				continue
			if Vector2(z.pos.x, z.pos.y - 20.0).distance_to(g["pos"]) > float(g["radius"]):
				continue
			pool.append(z)
		# 每摊同时只结算有限几名，优先离门神近的那几个
		pool.sort_custom(func(a, b): return float(a.pos.x) < float(b.pos.x))
		var limit = int(g["cap"])
		if limit > 0 and pool.size() > limit:
			pool = pool.slice(0, limit)
		for z in pool:
			if time - float(g["hit"].get(String(z.uid), -100000.0)) < float(g["icd"]):
				continue
			g["hit"][String(z.uid)] = time
			if float(g["damage"]) > 0.0:
				damage_zombie(z, float(g["damage"]), false, false, String(g["src"]))
			if float(g["eater_damage"]) > 0.0 and z.eating:
				damage_zombie(z, float(g["eater_damage"]), false, false, String(g["src"]))
			var slow = float(g["slow"])
			var large_slow = float(g.get("large_slow", -1.0))
			if z.is_large() and large_slow >= 0.0:
				slow = large_slow
			if slow > 0.0:
				apply_slow(z, float(g["slow_duration"]), slow)
			# 绊脚残片：普通直接被绊一下（走公共控制额度），大型只吃减速
			if float(g["trip"]) > 0.0:
				if z.is_large():
					apply_slow(z, float(g["trip_slow_duration"]), float(g["trip_slow"]))
				else:
					try_hard_cc(z, float(g["trip"]))
		keep.append(g)
	grounds = keep


## 标记：敌人身上按来源分层的计数（香印／狐记／死印／针穴）。
## 层数只决定触发条件，倍率不按层数相乘——易伤一律走 apply_vulnerable 的"取最强"。
## refresh=false 只继承剩余时长，不把它刷新成完整时长（传印用）。
func add_mark(z: Zombie, kind: String, stacks: int, duration: float,
		refresh: bool = true, value: float = 0.0) -> int:
	if z == null or not z.alive():
		return 0
	var mark: Dictionary = {}
	var old = z.marks.get(kind)
	if old is Dictionary:
		mark = old
	mark["stacks"] = mini(int(mark.get("stacks", 0)) + stacks, 3)
	if refresh or float(mark.get("t", 0.0)) <= 0.0:
		mark["t"] = duration
	z.marks[kind] = mark
	if value > 0.0:
		apply_vulnerable(z, float(mark["t"]), value)
	return int(mark["stacks"])


func mark_stacks(z: Zombie, kind: String) -> int:
	var old = z.marks.get(kind)
	return int(old["stacks"]) if old is Dictionary else 0


func clear_marks(z: Zombie, kind: String) -> void:
	z.marks.erase(kind)


func update_marks(z: Zombie, dt: float) -> void:
	for kind in z.marks.keys():
		var mark: Dictionary = z.marks[kind]
		mark["t"] = maxf(0.0, float(mark["t"]) - dt)
		if float(mark["t"]) <= 0.0:
			z.marks.erase(kind)


## 传印：带印的敌人倒下时把一层印传给身边最多 2 名同伴。
## 一条链最多 2 跳，同一名敌人在同一条链里只被感染一次（chain 就是到访名单）。
func spread_marks_on_death(z: Zombie, chain: Dictionary, hops: int) -> void:
	if mark_stacks(z, "incense") <= 0:
		return
	var best_tier = 0
	for source in plants:
		if source.dead or String(source.type) != "censer" or bool(source.ash):
			continue
		var tier2 = source.tier(2)
		if tier2 >= 2 and tier2 > best_tier:
			best_tier = tier2
	if best_tier <= 0:
		return
	var fx: Dictionary = Upgrades.EFFECTS["censer"]
	if hops >= int(fx["spread_hops"][best_tier]):
		return
	var radius = float(fx["spread_radius"][best_tier]) * Geo.CELL_W
	var count = 0
	for other in zombies:
		if count >= int(fx["spread_targets"][best_tier]):
			break
		if other == z or not other.alive() or other.pos.distance_to(z.pos) > radius:
			continue
		var key = other.get_instance_id()
		if chain.has(key):
			continue
		chain[key] = true
		count += 1
		add_mark(other, "incense", 1, float(fx["mark_duration"][best_tier]), false,
			float(fx["vuln"][best_tier]))
		spread_marks_on_death(other, chain, hops + 1)


func censer_effect(plant: Plant) -> Dictionary:
	var base: Dictionary = plant.def["censer"]
	var fx: Dictionary = Upgrades.EFFECTS["censer"]
	return {
		"damage": float(base["damage"]),
		"radius": float(base["radius"]) if plant.tier(1) == 0 else float(fx["radius"][plant.tier(1)]) * Geo.CELL_W,
		"interval": float(fx["interval"][plant.tier(3)]),
	}


func _update_censer(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["censer"]
	if plant.ash:
		plant.timer += dt
		if plant.timer >= float(fx["ash_interval"][3]):
			plant.timer = 0.0
			for z in _censer_targets(plant, float(fx["ash_radius"][3]) * Geo.CELL_W):
				damage_zombie(z, float(fx["ash_damage"][3]), false, false, plant.type, "ash_censer")
		return
	var effect := censer_effect(plant)
	if plant.censer_followup_at >= 0.0:
		if time >= plant.censer_followup_at:
			plant.censer_followup_at = -1.0
			plant.timer = 0.0
			_censer_attack(plant, effect, fx)
		return
	var interval = float(effect["interval"]) / (1.0 + plant.haste)
	plant.timer += dt
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	var hits = _censer_attack(plant, effect, fx)
	if plant.tier(3) == 3 and hits >= 3 and time >= plant.censer_followup_ready:
		plant.censer_followup_at = time + 0.3
		plant.censer_followup_ready = plant.censer_followup_at + 4.0


func _censer_targets(plant: Plant, radius: float) -> Array:
	var targets: Array = []
	for z in zombies:
		if z.alive() and plant.pos.distance_to(z.pos) <= radius:
			targets.append(z)
	return targets


func _censer_attack(plant: Plant, effect: Dictionary, fx: Dictionary) -> int:
	plant.action_at = time
	plant.pulse = 0.7
	sfx("censer")
	var tier = plant.tier(2)
	var hits := 0
	var hit_boss := false
	for z in _censer_targets(plant, float(effect["radius"])):
		if not z.alive():
			continue
		var marked = mark_stacks(z, "incense") > 0
		var dealt = damage_zombie(z, float(effect["damage"]) * (1.0 + plant.buff_damage),
			false, false, plant.type, "incense_primary" if tier == 3 else "")
		if dealt > 0.0 and (z.boss_role != "body" or not hit_boss):
			hits += 1
		if z.boss_role == "body":
			hit_boss = true
		if tier <= 0:
			continue
		if z.alive():
			add_mark(z, "incense", 1, float(fx["mark_duration"][tier]), true, float(fx["vuln"][tier]))
		elif tier == 3 and marked:
			_censer_blast(z.pos, plant, fx)
	ring(plant.pos + Vector2(0, -4), Color(0.84, 0.78, 0.64, 0.34),
		float(effect["radius"]), 0.6)
	return hits


func _censer_blast(at: Vector2, plant: Plant, fx: Dictionary) -> void:
	var radius = 0.8 * Geo.CELL_W
	for z in zombies:
		if not z.alive() or z.pos.distance_to(at) > radius:
			continue
		damage_zombie(z, 100.0, false, false, plant.type, "incense_blast")
		if z.alive():
			add_mark(z, "incense", 1, float(fx["mark_duration"][3]), true, float(fx["vuln"][3]))
	ring(at, Color("#e8b579"), radius, 0.5)
	spark(at, Color("#ffe2a6"), 12)
	sfx("censer")


## 同类庇护取最高值；随伤害即时查询，拆除或封印后立即失效。
func plant_guard(target: Plant) -> float:
	var result = float(target.wish_guard) if target.wish_t > 0.0 and target.wish > 0.0 else 0.0
	for source in plants:
		if source.type == "judge" and _judge_covers(source, target):
			result = maxf(result, float(Upgrades.EFFECTS["judge"]["reduction"][source.tier(1)]))
	return result


func _judge_covers(source: Plant, target: Plant) -> bool:
	if source.dead or target.dead or source.sealed_until > time or source.sleep_until > time:
		return false
	var dx = absi(source.col - target.col)
	var dy = absi(source.row - target.row)
	var tier = source.tier(2)
	if tier < 2:
		return dx + dy <= 1
	var reach = tier - 1
	return maxi(dx, dy) <= reach


## 反伤：石磨走粗粝（2 路），炭火盆走铜胎（3 路），纸伞走护纸（3 路，只在收妖期间）。
## 反伤：石磨走粗粝（2 路），炭火盆走铜胎（3 路）；纸伞的刺手另走一本账。
func plant_reflect(target: Plant) -> float:
	if target.type == "wall":
		return float(Upgrades.EFFECTS["wall"]["reflect"][target.tier(2)])
	if target.type == "torch":
		return float(Upgrades.EFFECTS["torch"]["reflect_total_dps"][target.tier(3)])
	return 0.0


## 火胎（炭火盆 3 路）改的是耐久上限，升阶当场把差值一次性补进当前耐久，不按比例满血。
func apply_hp_scale(plant: Plant) -> void:
	var want = float(plant.def.get("hp", 300))
	if plant.type == "torch":
		var cap = float(Upgrades.EFFECTS["torch"]["max_hp"][plant.tier(3)])
		if cap > 0.0:
			want = cap
	if absf(want - plant.max_hp) < 0.01:
		return
	plant.hp += want - plant.max_hp
	plant.max_hp = want
	plant.hp = clampf(plant.hp, 1.0, plant.max_hp)


func flytrap_target(plant: Plant) -> Zombie:
	var reach = float(plant.def["chomp"]["reach"])
	var best: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x < plant.pos.x - 14.0 or z.pos.x - plant.pos.x > reach:
			continue
		if best == null or z.pos.x < best.pos.x:
			best = z
	return best


## 纸伞：主槽收妖 + 副槽、吸引、伞骨、愿盾、反噬与免死。
## 三条路分别是"收放（怎么吃）""愿力（吃完留下什么）""伞骨（吃的时候在挨打）"。
func _update_umbrella(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["umbrella"]
	plant.reflect_paid = 0.0
	if plant.tier(2) >= 3 and plant.umbrella_shield_unlocked \
			and plant.bite_t <= 0.0 and plant.wish < float(fx["wish_hp"][3]):
		plant.wish = minf(float(fx["wish_hp"][3]),
			plant.wish + float(fx["wish_regen"][3]) * dt)
		if plant.wish > 0.0:
			plant.wish_t = 1.0e9
	if plant.chew_t > 0.0:
		plant.chew_t = maxf(0.0, plant.chew_t - dt)
		plant.charge = 1.0 - plant.chew_t / plant.chew_max if plant.chew_max > 0.0 else 0.0
		if plant.chew_t <= 0.0:
			_umbrella_finish(plant, fx, false)
	var secondary: Dictionary = plant.secondary
	if not secondary.is_empty() and bool(secondary.get("busy", false)):
		secondary["t"] = float(secondary["t"]) - dt
		if float(secondary["t"]) <= 0.0:
			plant.secondary = {}
			_umbrella_finish(plant, fx, true)
	var tertiary: Dictionary = plant.tertiary
	if not tertiary.is_empty() and bool(tertiary.get("busy", false)):
		tertiary["t"] = float(tertiary["t"]) - dt
		if float(tertiary["t"]) <= 0.0:
			plant.tertiary = {}
			_umbrella_finish(plant, fx, true)
	plant.charge = maxf(plant.charge, 0.0 if secondary.is_empty()
		else 1.0 - float(secondary["t"]) / float(secondary["max"]))
	plant.charge = maxf(plant.charge, 0.0 if tertiary.is_empty()
		else 1.0 - float(tertiary["t"]) / float(tertiary["max"]))
	if plant.chew_t>0:
		_try_umbrella_secondary(plant,fx)
		return
	plant.timer += dt
	var target = flytrap_target(plant)
	if target == null:
		plant.timer = minf(plant.timer, 0.35)
		return
	var base = float(plant.def["chomp"]["large_interval"]) if target.is_large() or target.boss_role!="" else 0.35
	var interval = base / (1.0 + plant.haste)
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer >= interval:
		plant.timer = 0.0
		plant.charge = 0.0
		flytrap_bite(plant, target, fx)
		_try_umbrella_secondary(plant,fx)


func _try_umbrella_secondary(plant: Plant,fx: Dictionary) -> void:
	# Independent clocks: a busy secondary slot never blocks the main slot.
	if plant.tier(3)<1 or plant.chew_t<=0:return
	var slot = "secondary" if plant.secondary.is_empty() else "tertiary"
	if slot == "tertiary" and (plant.tier(3)<3 or not plant.tertiary.is_empty()):return
	var reach=float(plant.def["chomp"]["reach"])
	for z in zombies:
		if not z.alive() or z.is_large() or z.boss_role!="" or z.row!=plant.row:continue
		if z.pos.x<plant.pos.x-14 or z.pos.x>plant.pos.x+reach:continue
		kill_zombie(z)
		plant.set(slot, {"busy":true,"t":float(fx.secondary_duration[plant.tier(3)]),
			"max":float(fx.secondary_duration[plant.tier(3)])})
		_umbrella_shield(plant, fx)
		break


## 副收妖只吐骨不产钱、不剥甲（批复：副槽不领主槽收益）。
func _umbrella_finish(plant: Plant, fx: Dictionary, secondary: bool) -> void:
	plant.pulse = 0.5
	plant.charge = 0.0
	var value = float(fx["capture_income"][plant.tier(2)])
	if value > 0.0:
		orbs.append({
			"x": plant.pos.x + rng.randf_range(-13, 13),
			"y": plant.pos.y - 24.0, "target_y": plant.pos.y - 24.0,
			"landed": true, "life": 9.0, "value": int(value),
			"phase": rng.randf() * TAU, "dead": false, "auto_t": 0.0,
		})
	if not secondary:
		plant.chew_prey = ""
		plant.chew_armor = 0.0
	_umbrella_bone(plant, fx)


## 一伞收（1-3）：收完吐一根直线伞骨，命中第一名非大型并定身 0.3 秒。
## 骨钉的完成事件在同伞共享 4 秒冷却，副槽完成也不额外多吐。
func _umbrella_bone(plant: Plant, fx: Dictionary) -> void:
	var tier1 = plant.tier(1)
	if tier1 < 3:
		return
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(20, -16)
	shot.row = plant.row
	shot.speed = 420.0
	_prepare_shot(shot, plant, float(fx["bone_damage"][tier1]))
	shots.append(shot)
	plant.action_at = time
	plant.recoil = 0.8
	sfx("gravel_shot")


## 吸（1-1）：空闲且正要开吃时，把前方 1 格内一名非大型往伞口拖 0.4 格。
## 走位移账本，且同伞 6 秒一次，不能每帧拖。撞骨（1-2）只在真的拖动时结算 40。
func _umbrella_pull(plant: Plant, fx: Dictionary) -> void:
	var tier1 = plant.tier(1)
	if tier1 <= 0 or time < float(plant.pull_until):
		return
	var reach = float(fx["pull_range"][tier1]) * Geo.CELL_W
	var target: Zombie = null
	for z in zombies:
		if not z.alive() or z.is_large() or z.row != plant.row:
			continue
		var dx = z.pos.x - plant.pos.x
		if dx < 0.0 or dx > reach:
			continue
		if target == null or z.pos.x < target.pos.x:
			target = z
	if target == null:
		return
	plant.pull_until = time + float(fx["pull_icd"][tier1])
	if move_zombie(target, -float(fx["pull_cells"][tier1])) > 0.0 \
			and float(fx["pull_damage"][tier1]) > 0.0:
		damage_zombie(target, float(fx["pull_damage"][tier1]), false, false, plant.type)


## 愿伞（2-1／2-2）：为本行一株友军挂 200 点临时盾；让伞改挂给最靠近恶客的那株。
## 同一时刻只保留一把，各来源取最高而不累加。
func _wish_shield(plant: Plant, fx: Dictionary, tier2: int) -> void:
	if tier2 <= 0:
		return
	_umbrella_shield(plant, fx)


func _umbrella_shield(plant: Plant, fx: Dictionary) -> void:
	var tier2 = plant.tier(2)
	if tier2 <= 0:
		return
	plant.wish = maxf(plant.wish, float(fx["wish_hp"][tier2]))
	plant.umbrella_shield_unlocked = true
	plant.wish_t = 1.0e9
	plant.wish_guard = 0.0
	ring(plant.pos + Vector2(0, -30), Color(0.95, 0.78, 0.45, 0.5), 34.0, 0.5)


func flytrap_bite(plant: Plant, target: Zombie, fx: Dictionary) -> void:
	sfx("umbrella")
	plant.action_at = time
	plant.recoil = 1.0
	plant.pulse = 0.5
	if target.is_large() or target.boss_role!="":
		damage_zombie(target, float(plant.def["chomp"]["large_damage"])
			* (1.0 + plant.buff_damage), false, false, plant.type)
		spark(plant.pos + Vector2(22, -22), Color("#7a8f55"), 5)
		return
	plant.chew_prey = String(target.def.get("tier", "l"))
	plant.chew_armor = maxf(0.0, target.armor)
	kill_zombie(target)
	var speed = float(plant.def["chomp"]["chew_speed"])
	plant.chew_max = float(plant.def["chomp"]["chew"]) * (1.0 - speed)
	plant.chew_max *= 1.0 - float(fx["chew_reduction"][plant.tier(1)])
	plant.chew_t = plant.chew_max
	_umbrella_shield(plant, fx)
	float_text(plant.pos + Vector2(0, -74), "收了", Color("#cfe0a0"), 16, 1.0)


## 刺手（3-2）：只要有槽在忙，实际啃这把伞的敌人每人 30/秒，整伞合计封顶 60/秒。
func umbrella_thorns(plant: Plant, bite_dps: float) -> float:
	if String(plant.type) != "umbrella":
		return 0.0
	var fx: Dictionary = Upgrades.EFFECTS["umbrella"]
	var tier3 = plant.tier(3)
	if tier3 < 2 or (plant.chew_t <= 0.0 and plant.secondary.is_empty()
			and plant.tertiary.is_empty()):
		return 0.0
	return float(fx["chew_reflect_dps"][tier3])


func _update_mine(plant: Plant, dt: float) -> void:
	if not plant.armed:
		plant.arm_t += dt
		if plant.arm_t < float(plant.def["mine"]["arm"]):
			return
		plant.armed = true
		plant.pulse = 0.5
		sfx("mushroom_grow")
		spark(plant.pos + Vector2(0, 12), Color("#d8e8a5"), 10)
		for i in 9:
			var a = rng.randf() * TAU
			var sp = 30.0 + rng.randf() * 70.0
			particles.append({
				"x": plant.pos.x + rng.randf_range(-12, 12), "y": plant.pos.y + 20.0,
				"vx": cos(a) * sp, "vy": -30.0 - rng.randf() * 65.0,
				"life": 0.45 + rng.randf() * 0.35, "max": 0.8,
				"size": 2.2 + rng.randf() * 3.0,
				"color": Color("#c9d99a") if i % 3 == 0 else Color("#7d6a4a"),
				"kind": "shard",
			})
		return
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x >= plant.pos.x - 16.0 and z.pos.x - plant.pos.x <= 44.0:
			mine_explode(plant, z)
			return


func mine_explode(plant: Plant, target: Zombie) -> void:
	plant_action_effect(plant)
	plant.dead = true
	cells[plant.row][plant.col] = null
	sfx("mine")
	damage_zombie(target, float(plant.def["mine"]["damage"]) * (1.0 + plant.buff_damage),
		false, false, plant.type)
	for i in 22:
		var a = rng.randf() * TAU
		var sp = 70.0 + rng.randf() * 190.0
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 45.0,
			"life": 0.4 + rng.randf() * 0.4, "max": 0.8,
			"size": 2.5 + rng.randf() * 4.0,
			"color": Color("#b58a52") if rng.randf() < 0.5 else Color("#e0c087"),
			"kind": "shard",
		})
	shake = maxf(shake, 9.0)


func _update_kelp(plant: Plant, dt: float) -> void:
	var reach = float(plant.def["tangle"]["range"])
	var target: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x < plant.pos.x - 24.0 or z.pos.x > plant.pos.x + reach:
			continue
		if target == null or z.pos.x < target.pos.x:
			target = z
	if target == null:
		plant.pull_t = maxf(0.0, plant.pull_t - dt)
		return
	if plant.pull_t <= 0.0:
		plant.action_at = time
	plant.pull_t += dt
	target.eating = false
	target.pos.x += (plant.pos.x + 8.0 - target.pos.x) * minf(1.0, dt * 4.0)
	if rng.randf() < dt * 24.0:
		particles.append({
			"x": target.pos.x + rng.randf_range(-12, 12),
			"y": target.pos.y - 20.0 + rng.randf() * 20.0,
			"vx": rng.randf_range(-20, 20), "vy": -18.0 - rng.randf() * 30.0,
			"life": 0.4 + rng.randf() * 0.3, "max": 0.7,
			"size": 2.0 + rng.randf() * 2.0,
			"color": Color("#7ea998") if rng.randf() < 0.5 else Color("#b7d4bd"),
			"kind": "circle",
		})
	if plant.pull_t < float(plant.def["tangle"]["drag"]):
		return
	damage_zombie(target, float(plant.def["tangle"]["damage"]), false, false, plant.type)
	plant.dead = true
	cells[plant.row][plant.col] = null
	for i in 16:
		var a = rng.randf() * TAU
		var sp = 30.0 + rng.randf() * 110.0
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y + 8.0,
			"vx": cos(a) * sp, "vy": -40.0 - rng.randf() * 60.0,
			"life": 0.5 + rng.randf() * 0.4, "max": 0.9,
			"size": 2.0 + rng.randf() * 4.0,
			"color": Color("#5f8f7c") if i % 3 else Color("#c7e0bd"),
			"kind": "circle",
		})
	float_text(plant.pos + Vector2(0, -40), "沉底了", Color("#bfe0cf"), 16)


func nearest_zombies(pos: Vector2, limit: int, exclude: Array = []) -> Array:
	var pool: Array = []
	for z in zombies:
		if not z.alive() or exclude.has(z):
			continue
		pool.append({"z": z, "d": pos.distance_squared_to(z.pos)})
	pool.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var out: Array = []
	for entry in pool.slice(0, limit):
		out.append(entry["z"])
	return out


func nearest_any(plant: Plant) -> Zombie:
	var best: Zombie = null
	var best_d = INF
	for z in zombies:
		if not z.alive():
			continue
		var d = z.pos.distance_squared_to(plant.pos)
		if d < best_d:
			best_d = d
			best = z
	return best


## 射弹的伤害由「基准值 × (1 + 取最高的增幅)」得到，红灯笼、炭火盆与余光同一条规则。
func _shot_damage(shot: Shot) -> float:
	return shot.base_damage * (1.0 + maxf(maxf(shot.lantern_buff, shot.torch_buff), shot.glow))


func _prepare_shot(shot: Shot, plant: Plant, raw: float) -> void:
	shot.src = plant.type
	shot.base_damage = raw
	shot.lantern_buff = plant.buff_damage
	shot.damage = _shot_damage(shot)


func _update_cat(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["cat"]
	var interval = maxf(0.2, float(plant.def["homing"]["interval"])
		- float(fx["interval_reduction"][plant.tier(1)])) / (1.0 + plant.haste)
	plant.timer += dt
	var target = nearest_any(plant)
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	fire_cat(plant, target)


## 尾形缩短出手间隔，三级有受六秒内冷却限制的十焰连发。
## 回魂（2-3）每团命中后可再追最近的另一名，无须击杀第一名。
func fire_cat(plant: Plant, main: Zombie) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["cat"]
	var home: Dictionary = plant.def["homing"]
	var tier1 = plant.tier(1)
	var tier2 = plant.tier(2)
	var tier3 = plant.tier(3)
	var count = int(fx["count"][tier2])
	if count <= 0:
		count = int(home["count"])
	var tail_damage = float(fx["volley_damage"][tier2])
	if tail_damage <= 0.0:
		tail_damage = float(home["damage"])
	var ten_flames = tier1 >= 3 and time >= plant.ten_flames_ready_at \
		and rng.randf() < float(fx["ten_flames_chance"][tier1])
	if ten_flames:
		plant.ten_flames_ready_at = time + float(fx["ten_flames_cooldown"])
		count = 10
	var picks: Array = [main]
	for z in nearest_zombies(plant.pos, count * 3):
		if picks.size() >= count:
			break
		if not picks.has(z):
			picks.append(z)
	sfx("cat_shot")
	for i in count:
		var shot = Shot.new()
		shot.kind = "homing"
		shot.target = picks[mini(i, picks.size() - 1)]
		shot.pos = plant.pos + Vector2(12, -22)
		shot.row = shot.target.row
		shot.speed = float(home["speed"])
		shot.hits_left = int(fx["hits"][tier2])
		shot.retarget = 1 if tier2 >= 3 else 0
		if ten_flames:
			shot.delay = 0.09 * float(i)
		_prepare_shot(shot, plant, tail_damage)
		# 狐记（3-1）：只有主尾火留记号，一轮至多加一层，末团与擦伤不另加
		if tier3 >= 1 and i == 0:
			shot.mark = float(fx["mark_vuln"][tier3])
			shot.mark_duration = float(fx["mark_duration"][tier3])
		if tier3 >= 2:
			shot.ignite = float(fx["explosion_damage"][tier3])
			shot.ignite_radius = float(fx["explosion_radius"][tier3]) * Geo.CELL_W
			shot.ignite_targets = int(fx["explosion_targets"][tier3])
			shot.ignite_icd = float(fx["explosion_icd"][tier3])
		if tier3 >= 3:
			shot.lock_root = float(fx["root"][tier3])
			shot.lock_large_root = float(fx["large_root"][tier3])
			shot.lock_vuln = float(fx["vuln"][tier3])
			shot.lock_vuln_duration = float(fx["reveal_duration"][tier3])
			shot.lock_icd = float(fx["proc_icd"][tier3])
		shots.append(shot)
	plant.action_at = time
	plant.recoil = 0.7
	if ten_flames:
		ring(plant.pos + Vector2(0, -28), Color("#ffbd69"), 36, 0.48)


## 绕（1-1／1-2）：尾火贴着一个圆绕半圈再收，绕过去的路上擦伤旁边的敌人。
func _orbit_cat(shot: Shot, center: Vector2, dt: float) -> void:
	var radius = shot.orbit
	var from = shot.pos - center
	var angle = from.angle() if from.length() > 1.0 else PI
	shot.pos = center + Vector2(cos(angle), sin(angle)) * radius
	var step = (shot.speed * dt * PROJECTILE_SPEED_SCALE) / maxf(radius, 1.0)
	shot.orbit_done += step
	var moved = angle + step
	shot.pos = center + Vector2(cos(moved), sin(moved)) * radius
	_cat_graze(shot)
	if shot.orbit_done >= PI:
		shot.orbit = 0.0


func _cat_graze(shot: Shot) -> void:
	if shot.graze <= 0.0 or shot.volley.is_empty():
		return
	var done: Array = shot.volley.get("grazed", [])
	var cap = int(shot.volley.get("graze_cap", 0))
	for z in zombies:
		if done.size() >= cap:
			return
		if not z.alive() or z == shot.target or done.has(z):
			continue
		if Vector2(z.pos.x, z.pos.y - 24.0).distance_to(shot.pos) > 22.0:
			continue
		done.append(z)
		damage_zombie(z, shot.graze, false, false, String(shot.src), "fox_graze", false, shot.kind)
		spark(shot.pos, Color("#ffd9a0"), 3)


## 回魂（2-3）：目标在半路倒下时，转追最近的另一名。
## 巡灯的回焰借的是同一套追踪，它用 retarget = -1 表示「一直追最近的」。
func _homing_retarget(shot: Shot) -> Zombie:
	if shot.retarget == 0:
		return null
	if shot.retarget < 0:
		var pool = nearest_zombies(shot.pos, 1, shot.hit_ids)
		return pool[0] if not pool.is_empty() else null
	shot.retarget -= 1
	var pool = nearest_zombies(shot.pos, 1, shot.hit_ids)
	return pool[0] if not pool.is_empty() else null


## 狐记／点火／锁魂（3-1／3-2／3-3）：主尾火命中留一层记号；
## 叠到两层当场引爆一次，叠到三层消耗记号把人定住并把易伤顶到 20%。
func _cat_mark(z: Zombie, shot: Shot) -> void:
	if not z.alive() or shot.mark <= 0.0:
		return
	var stacks = add_mark(z, "fox", 1, shot.mark_duration, true, shot.mark)
	if stacks == 2 and shot.ignite > 0.0 and time >= float(z.ignite_until):
		z.ignite_until = time + shot.ignite_icd
		_cat_ignite(z, shot)
	elif stacks >= 3 and shot.lock_root > 0.0 and time >= float(z.lock_until):
		z.lock_until = time + shot.lock_icd
		clear_marks(z, "fox")
		var stopped = try_hard_cc(z, shot.lock_large_root if z.is_large() else shot.lock_root)
		apply_vulnerable(z, shot.lock_vuln_duration, 0.40 if z.is_large() and stopped else shot.lock_vuln)


func _cat_ignite(z: Zombie, shot: Shot) -> void:
	var hit = 0
	for other in zombies:
		if hit >= shot.ignite_targets or not other.alive():
			return
		if Vector2(other.pos.x, other.pos.y - 24.0).distance_to(
				Vector2(z.pos.x, z.pos.y - 24.0)) > shot.ignite_radius:
			continue
		hit += 1
		# 爆炸只结算伤害，不再留记号，免得引爆自己把自己点下去
		damage_zombie(other, shot.ignite, false, false, String(shot.src),"fox_ignite")
	var at = Vector2(z.pos.x, z.pos.y - 24.0)
	ring(at, Color(1.0, 0.72, 0.3, 0.62), shot.ignite_radius, 0.32)
	spark(at, Color("#ffb63c"), 10)
	float_text(at + Vector2(0, -20), "点火", Color("#ffd08a"), 15, 0.8)
	sfx("cat_shot")


func _update_lobber(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["lobber"]
	var tier2 = plant.tier(2)
	var interval = float(fx["interval"][tier2]) / (1.0 + plant.haste)
	var target = _lobber_target(plant)
	if time >= plant.lob_heat_until:
		plant.lob_heat_stacks = 0
	if plant.lob_followup_at >= 0.0:
		if time >= plant.lob_followup_at:
			plant.lob_followup_at = -1.0
			_throw_soup(plant, target, plant.lob_followup_aim)
			plant.timer = 0.0
		return
	plant.timer = minf(plant.timer + dt, interval)
	plant.charge = minf(1.0, plant.timer / interval)
	if target == null or plant.timer < interval:
		return
	plant.timer = 0.0
	_throw_soup(plant, target, target.pos)
	if tier2 == 3 and rng.randf() < 0.4:
		plant.lob_followup_at = time + 0.4
		plant.lob_followup_aim = target.pos


func _lobber_target(plant: Plant) -> Zombie:
	var tail: Zombie = null
	for z in zombies:
		if z.alive() and z.row == plant.row and z.pos.x > plant.pos.x + 6.0:
			if tail == null or z.pos.x > tail.pos.x:
				tail = z
	return tail


func _throw_soup(plant: Plant, target: Zombie, fallback: Vector2) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["lobber"]
	var tier1 = plant.tier(1)
	var tier3 = plant.tier(3)
	var shot = _make_lob(plant, target, fallback, float(plant.def["lob"]["flight"]))
	var heat = plant.lob_heat_stacks if time < plant.lob_heat_until else 0
	_prepare_shot(shot, plant, float(fx["damage"][tier1]) * (1.0 + 0.1 * heat))
	shot.owner_uid = plant.uid
	shot.payload = {
		"heat": tier1 == 3,
		"pool": float(fx["pool_radius"][tier3]) * Geo.CELL_W,
		"pool_life": float(fx["pool_duration"][tier3]),
		"pool_dps": float(fx["pool_dps"][tier3]),
		"pool_slow": float(fx["pool_slow"][tier3]),
		"large_slow": 0.25 if tier3 == 3 else -1.0,
		"merged": float(fx["merged_radius"][tier3]) * Geo.CELL_W,
		"merged_dps": float(fx["merged_dps"][tier3]),
		"merged_slow": float(fx["pool_slow"][tier3]),
	}
	shots.append(shot)
	plant.action_at = time
	plant.recoil = 0.9
	sfx("lob_shot")


func _make_lob(plant: Plant, target: Zombie, fallback: Vector2, flight: float) -> Shot:
	var shot = Shot.new()
	shot.kind = "lob"
	shot.target = target
	shot.row = plant.row
	shot.pos = plant.pos + Vector2(10, -22)
	shot.start = shot.pos
	var aim = target.pos if target != null and target.alive() else fallback
	shot.tx = aim.x
	shot.ty = aim.y - 14.0
	shot.flight = flight
	return shot


func _lob_heat_on_hit(shot: Shot) -> void:
	if not bool(shot.payload.get("heat", false)):
		return
	for plant in plants:
		if plant.dead or plant.uid != shot.owner_uid:
			continue
		if time >= plant.lob_heat_until:
			plant.lob_heat_stacks = 0
		if plant.lob_heat_stacks < 5:
			plant.lob_heat_stacks += 1
			plant.lob_heat_until = time + 5.0
		return


func _star_interval(fx: Dictionary, def: Dictionary, tier2: int) -> float:
	return float(def["interval"]) / (1.0 + float(fx["speed_bonus"][tier2]))


## 借风只认烟、火、汤三类地效；冷炉塌下来的灰雾与灯焰的余光都不算。
func star_direction_count(origin: Vector2, dir: Vector2) -> int:
	var n = 0
	for z in zombies:
		if not z.alive():
			continue
		var delta = Vector2(z.pos.x - origin.x, (z.pos.y - 26.0) - origin.y)
		if delta.dot(dir) <= 0.0:
			continue
		if absf(delta.x * dir.y - delta.y * dir.x) <= 34.0:
			n += 1
	return n


## 发灯间隔。借风（2-1）看场上有没有烟／火／汤，连转与灯轮各给一个上限，
## 三者取最快的一档——灯轮写得很明白：与借风取更快者，不再相乘。
func star_direction_has_target(origin: Vector2, dir: Vector2) -> bool:
	for z in zombies:
		if not z.alive():
			continue
		var delta = Vector2(z.pos.x - origin.x, (z.pos.y - 26.0) - origin.y)
		var along = delta.dot(dir)
		if along <= 0.0:
			continue
		if absf(delta.x * dir.y - delta.y * dir.x) <= 34.0:
			return true
	return false


func _update_star(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["star"]
	var def: Dictionary = plant.def["star"]
	var tier1 = plant.tier(1)
	var tier2 = plant.tier(2)
	var tier3 = plant.tier(3)
	var seeking = tier3 >= 3
	var interval = _star_interval(fx, def, tier2) / (1.0 + plant.haste)
	if plant.star_morale_stacks > 0 and time >= plant.star_morale_until:
		plant.star_morale_stacks = 0
	if tier2 >= 3 and time < plant.star_guardian_until:
		interval /= 1.0 + float(fx["guardian_speed_bonus"][tier2])
	plant.timer += dt
	var all = bool(fx["all_dirs"][tier3])
	var has_target = false
	for z in zombies:
		if not z.alive():
			continue
		if all or z.pos.x > plant.pos.x:
			has_target = true
			break
	if not has_target:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	var origin = plant.pos + Vector2(0, -22)
	var dirs: Array = []
	var targets: Array = []
	if seeking:
		# 天网（3-3）：像狐尾灯一样，五团灯焰各自咬住场上最近的恶客
		targets = nearest_zombies(plant.pos, int(def["dirs"]))
		if targets.is_empty():
			return
		for i in int(def["dirs"]):
			var target: Zombie = targets[i % targets.size()]
			dirs.append(Vector2(target.pos.x, target.pos.y - 26.0) - origin)
	else:
		dirs = [
			Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1),
			Vector2(cos(PI / 3.0), -sin(PI / 3.0)),
			Vector2(cos(PI / 3.0), sin(PI / 3.0)),
		]
	# 侧照（1-1）：五道里朝向敌人最多的那一道主束 +50%，平局按这个固定方向序
	var focus_index = -1
	var focus_best = 0
	if int(fx["focus_beams"][tier1]) > 0:
		for i in dirs.size():
			var n = star_direction_count(origin, Vector2(dirs[i]).normalized())
			if n > focus_best:
				focus_best = n
				focus_index = i
	# 灯轮（2-3）：每轮只有一道是重灯，方向一轮挪一格
	plant.star_round += 1
	var heavy_index = -1
	if int(fx["heavy_per_volley"][tier2]) > 0:
		heavy_index = plant.star_round % dirs.size()
	# 一轮五束共用同一份点名记录：同一名被第二道、第三道撞上才逐道加钱
	var round_log: Dictionary = {"hits": {}}
	var any = false
	for i in dirs.size():
		var unit = Vector2(dirs[i])
		if unit.length_squared() < 0.0001:
			continue
		if not all and not seeking and not star_direction_has_target(origin, unit):
			continue
		any = true
		var shot = Shot.new()
		shot.kind = "star"
		shot.dir = unit.normalized()
		shot.pos = origin + shot.dir * 16.0
		shot.row = plant.row
		shot.speed = 560.0
		var raw = float(def["damage"]) * (1.0 + float(fx["damage_bonus"][tier1])
			+ 0.1 * float(plant.star_morale_stacks))
		shot.owner_uid = plant.uid
		shot.heavy = i == heavy_index
		if shot.heavy:
			raw *= float(fx["heavy_multiplier"][tier2])
			shot.heavy_knock = float(fx["heavy_knock"][tier2])
			shot.heavy_knock_icd = float(fx["heavy_knock_icd"][tier2])
		shot.converge = float(fx["converge_bonus"][tier1])
		shot.volley = round_log
		shot.payload = {
			"glow_r": float(fx["glow_radius"][tier1]) * Geo.CELL_W,
			"glow_life": float(fx["glow_duration"][tier1]),
			"glow_buff": float(fx["glow_buff"][tier1]),
		}
		_prepare_shot(shot, plant, raw)
		# 回焰（3-2）：飞出界的灯焰折回来追人，代价是伤害减半；天网不再减半
		shot.seek = bool(fx["seek"][tier3])
		shot.seek_factor = float(fx["seek_factor"][tier3])
		shots.append(shot)
	if any:
		sfx("star_shot")
		plant.action_at = time
		plant.recoil = 0.7
		plant.pulse = 0.45


func _update_needle(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["needle"]
	var def: Dictionary = plant.def["needle"]
	var interval = float(fx["interval"][plant.tier(2)]) / (1.0 + plant.haste)
	plant.timer += dt
	if lane_target(plant) == null or plant.timer < interval:
		plant.timer = minf(plant.timer, interval)
		plant.charge = plant.timer / interval
		return
	plant.timer = 0.0
	plant.needle_shots += 1
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(22, -16)
	shot.row = plant.row
	shot.speed = float(def["speed"])
	_prepare_shot(shot, plant, float(def["damage"]))
	shot.pierce_armor = true
	shot.pierce_left = int(fx["pierce_targets"][plant.tier(1)]) - 1
	shot.pierce_all = plant.tier(1) >= 3
	shot.mark = float(fx["vuln"][plant.tier(3)])
	shot.armor_vulnerability = 0.40 if plant.tier(3) >= 3 else 0.0
	if plant.tier(2) >= 3 and plant.needle_shots % 4 == 0:
		shot.pin = 0.3
		shot.pin_large = 0.15
	shots.append(shot)
	plant.action_at = time
	plant.recoil = 0.6
	sfx("needle_shot")


func _needle_impact(shot: Shot, victim: Zombie) -> void:
	if shot.src != "needle" or not victim.alive():
		return
	if shot.mark > 0.0:
		apply_vulnerable(victim, 2.5, shot.mark)
	if shot.armor_vulnerability > 0.0:
		victim.armor_vuln_until = time + 2.5
	if shot.pin > 0.0 and shot.hit_ids.size() == 1:
		apply_stun(victim, shot.pin_large if victim.is_large() else shot.pin)


func _update_judge(plant: Plant, dt: float) -> void:
	if plant.tier(2) < 1:
		return
	var def: Dictionary = plant.def["judge"]
	var interval = float(def["interval"]) / (1.0 + plant.haste)
	plant.timer = minf(plant.timer + dt, interval)
	if plant.timer < interval or lane_target(plant) == null:
		return
	plant.timer = 0.0
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(22, -23)
	shot.row = plant.row
	shot.speed = float(def["speed"])
	_prepare_shot(shot, plant, float(def["damage"]))
	shots.append(shot)
	plant.action_at = time
	plant.recoil = 0.7
	sfx("shoot")


func _update_firework(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["firework"]
	var t1 = plant.tier(1)
	var t2 = plant.tier(2)
	var t3 = plant.tier(3)
	var target = lane_target(plant)
	var interval = float(fx["interval"][t1]) / (1.0 + plant.haste)
	plant.timer = minf(plant.timer + dt, interval)
	if plant.firework_extra_at >= 0.0 and time >= plant.firework_extra_at:
		plant.firework_extra_at = -1.0
		_firework_launch(plant, target, float(fx["damage"][t2]) * 0.5, float(fx["radius"][t2]),
			false, plant.firework_extra_aim)
		plant.timer = 0.0
	if target != null and plant.timer >= interval:
		_firework_launch(plant, target, float(fx["damage"][t2]), float(fx["radius"][t2]))
		plant.timer = 0.0
		if t1 >= 3 and rng.randf() < 0.3:
			plant.firework_extra_at = time + 0.6
			plant.firework_extra_aim = target.pos
	if t3 <= 0:
		return
	var seek_interval = 1.6 / (1.0 + plant.haste)
	plant.firework_seek_timer = minf(seek_interval, plant.firework_seek_timer + dt)
	if plant.firework_seek_timer >= seek_interval:
		var nearest = nearest_any(plant)
		if nearest != null:
			_firework_launch(plant, nearest, float(fx["damage"][t2]) if t3 == 3 else 40.0 * t3,
				float(fx["radius"][t2]) if t3 == 3 else 0.0, true)
			plant.firework_seek_timer = 0.0


func _firework_launch(plant: Plant, target: Zombie, raw: float, radius: float,
		homing: bool = false, fallback: Vector2 = Vector2.ZERO) -> void:
	var shot = Shot.new()
	shot.kind = "homing" if homing else "lob"
	shot.look = "firework"
	shot.pos = plant.pos + Vector2(22, -26)
	shot.start = shot.pos
	var aim = target.pos if target != null else fallback
	shot.row = target.row if target != null else plant.row
	shot.target = target
	shot.speed = 460.0
	shot.flight = clampf(absf(aim.x - plant.pos.x) / 570.0, 0.34, 0.9)
	shot.tx = aim.x
	shot.ty = aim.y - 14.0
	shot.firework_radius = radius * Geo.CELL_W
	_prepare_shot(shot, plant, raw)
	shots.append(shot)
	plant.action_at = time
	plant.recoil = 0.75
	sfx("lob_shot")


const SQUASH_WINDUP := 0.28
const SQUASH_LEAP := 0.26
const DRAGON_SWITCH_TIME := 0.40


func _update_squash(plant: Plant) -> void:
	if plant.squash_at < 0.0:
		var target: Zombie = null
		var nearest := Geo.CELL_W + 0.01
		for z in zombies:
			if not z.alive() or z.row != plant.row or bool(z.def.get("ash_immune", false)):
				continue
			var distance = absf(z.pos.x - plant.pos.x)
			if distance < nearest:
				target = z
				nearest = distance
		if target == null:
			return
		plant.squash_target = target
		plant.squash_aim = Vector2(target.pos.x, plant.pos.y)
		plant.squash_at = time
		plant.action_at = time
		return
	var age = time - plant.squash_at
	if age < SQUASH_WINDUP and plant.squash_target != null and plant.squash_target.alive():
		var x = clampf(plant.squash_target.pos.x, plant.pos.x - Geo.CELL_W, plant.pos.x + Geo.CELL_W)
		plant.squash_aim.x = x
	if age < SQUASH_WINDUP + SQUASH_LEAP:
		return
	var at = plant.squash_aim
	plant.dead = true
	cells[plant.row][plant.col] = null
	for z in zombies:
		if z.alive() and z.pos.distance_to(at) <= Geo.CELL_W:
			damage_zombie(z, 1800.0, false, false, "squash")
	ring(at, Color("#d4bd73"), Geo.CELL_W, 0.45)
	spark(at, Color("#b0a374"), 24)
	particles.append({"x": at.x, "y": at.y + Geo.cell_h(rows) * 0.3,
		"vx": 0.0, "vy": 0.0, "life": 0.24, "max": 0.24, "size": 88.0,
		"color": Color.WHITE, "kind": "plant_action", "actor": "squash"})
	shake = maxf(shake, 6.0)
	sfx("lion")


func _dragon_near_targets(plant: Plant, reach: float) -> Array:
	var targets: Array = []
	for z in zombies:
		var dx = z.pos.x - plant.pos.x
		if z.alive() and z.row == plant.row and dx >= -4.0 and dx <= reach:
			targets.append(z)
	return targets


func _update_dragon(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["dragon"]
	var t3 = plant.tier(3)
	var reach = float(fx["near_range"][plant.tier(1)]) * Geo.CELL_W
	var targets = _dragon_near_targets(plant, reach)
	var distant = _lobber_target(plant)
	var mode = "near"
	if t3 > 0:
		if targets.is_empty() and (distant != null or plant.dragon_mode != "near"):
			mode = "far"
		elif t3 == 3 and not targets.is_empty():
			mode = "dual"
	if plant.dragon_volley_left > 0:
		mode = plant.dragon_mode
	if mode != plant.dragon_mode:
		plant.dragon_from = plant.dragon_mode
		plant.dragon_mode = mode
		plant.dragon_switch_at = time
		plant.dragon_switch_until = time + DRAGON_SWITCH_TIME
	if time < plant.dragon_switch_until:
		return

	var near_interval = 0.25 / (1.0 + plant.haste)
	plant.dragon_near_timer = minf(plant.dragon_near_timer + dt, near_interval)
	if mode != "far" and not targets.is_empty() and plant.dragon_near_timer >= near_interval:
		plant.dragon_near_timer = 0.0
		var damage = float(fx["near_damage"][plant.tier(2)]) * (1.0 + plant.buff_damage)
		for z in targets:
			damage_zombie(z, damage, true, false, plant.type, "dragon_breath", plant.tier(2) == 3)
		plant.dragon_near_at = time
		plant.action_at = time
		plant.pulse = 0.35
		if time - plant.dragon_far_at > 0.1:
			sfx("censer")
	if t3 <= 0 or mode == "near":
		return

	var rate = 1.4 if t3 >= 3 and targets.is_empty() else 1.0
	var interval = 2.0 / (rate * (1.0 + plant.haste))
	if plant.dragon_volley_left > 0:
		if time >= plant.dragon_volley_at:
			_dragon_fire(plant, distant)
			plant.dragon_volley_left -= 1
			plant.dragon_volley_at += 0.15
			if plant.dragon_volley_left == 0:
				plant.dragon_far_timer = 0.0
		return
	plant.dragon_far_timer = minf(plant.dragon_far_timer + dt, interval)
	if distant == null or plant.dragon_far_timer < interval:
		return
	plant.dragon_aim = distant.pos
	_dragon_fire(plant, distant)
	plant.dragon_volley_left = 2
	plant.dragon_volley_at = time + 0.15


func _dragon_fire(plant: Plant, target: Zombie) -> void:
	var factor = 1
	if plant.tier(3) >= 2:
		var roll = rng.randf()
		factor = 3 if roll < 0.30 else (2 if roll < 0.60 else 1)
	var flight = float(Content.PLANTS["lobber"]["lob"]["flight"]) * 2.0
	var shot = _make_lob(plant, target, plant.dragon_aim, flight)
	shot.look = "dragon_%d" % factor
	_prepare_shot(shot, plant, 40.0 * factor)
	shots.append(shot)
	plant.dragon_far_at = time
	plant.action_at = time
	plant.recoil = 0.72
	sfx("lob_shot")


func _update_gust(plant: Plant, dt: float) -> void:
	plant.timer += dt
	if plant.timer < float(plant.def["gust"]["fuse"]):
		return
	plant_action_effect(plant)
	plant.dead = true
	cells[plant.row][plant.col] = null
	sfx("bell")
	for z in zombies:
		if not z.alive() or z.boss_role != "":
			continue
		z.gust_left = 0.8
		z.gust_speed = Geo.CELL_W * (1.0 if z.is_large() else 2.0) / z.gust_left
	for row in rows:
		particles.append({"x": Geo.BOARD_X - 8.0, "y": row_y(row) - 12.0,
			"vx": Geo.BOARD_W / 0.8, "vy": 0.0, "life": 0.8, "max": 0.8,
			"size": 36.0, "color": Color("#9ecfc7"), "kind": "gust_trail"})


func _step_gust(z: Zombie, dt: float) -> void:
	var elapsed = minf(z.gust_left, dt)
	var end_x = z.pos.x + elapsed * z.gust_speed
	var start_col = maxi(0, int(floor((z.pos.x - Geo.BOARD_X) / Geo.CELL_W)))
	var end_col = mini(Geo.COLS - 1, int(floor((end_x - Geo.BOARD_X) / Geo.CELL_W)))
	for col in range(start_col + 1, end_col + 1):
		if String(tile_at(col, z.row)["kind"]) in ["blocked", "object"]:
			z.pos.x = Geo.BOARD_X + col * Geo.CELL_W - 0.1
			z.gust_left = 0.0
			return
	z.pos.x = end_x
	z.gust_left -= elapsed


## 醒狮：街面上最横的一块石头。三条路分别管"嘴里存什么"、"撞完站在哪"、
## "倒下之前还能为别人做什么"。伤害、间隔与白板击退都在 content 的 melee 里。
func _update_lion(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["lion"]
	var melee: Dictionary = plant.def["melee"]
	var tier1 = plant.tier(1)
	var tier2 = plant.tier(2)
	var tier3 = plant.tier(3)
	if plant.dance_t > 0.0:
		plant.dance_t = maxf(0.0, plant.dance_t - dt)
		plant.haste = maxf(plant.haste, 1.0)
	var interval = float(melee["interval"]) / (0.8 if tier2 >= 3 else 1.0) \
		/ (1.0 + plant.haste)
	plant.timer += dt
	var reach = float(melee["reach"])
	if tier2 == 1:
		reach = 3.0 * Geo.CELL_W
	elif tier2 >= 2:
		reach = Geo.BOARD_W
	var target: Zombie = null
	var candidates: Array = []
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if tier2 < 2 and (z.pos.x < plant.pos.x - 12.0 or z.pos.x - plant.pos.x > reach):
			continue
		candidates.append(z)
		if target == null or z.pos.x < target.pos.x:
			target = z
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	sfx("lion")
	if tier2 >= 1:
		plant.lion_wave_t = 0.34
		plant.lion_wave_end = maxf(plant.pos.x + 32.0,
			Geo.BOARD_X + Geo.BOARD_W if tier2 >= 3 else target.pos.x)
	var raw = float(melee["damage"]) if tier1 == 0 else float(fx["head_damage"][tier1])
	if plant.dance_t > 0.0:
		raw *= 2.0
	var damage = raw * (1.0 + plant.buff_damage)
	plant.action_at = time
	plant.recoil = 1.0
	var hit = false
	for victim in (candidates if tier2 >= 3 else [target]):
		if not victim.alive():
			continue
		var armored = victim.armor > 0.0
		hit = damage_zombie(victim, damage, false, false, plant.type) > 0.0 or hit
		if tier1 >= 3 and victim.alive():
			_lion_throw(plant, victim, armored)
	var recovery = float(fx["heal_per_attack"][tier3])
	if hit and recovery > 0.0:
		plant.hp = minf(plant.max_hp, plant.hp + recovery)
		if tier3 == 3:
			for col in [plant.col - 1, plant.col + 1]:
				var ally = main_plant_at(col, plant.row)
				if ally != null and not ally.dead:
					ally.hp = minf(ally.max_hp, ally.hp + recovery)


func _lion_throw(plant: Plant, target: Zombie, armored: bool) -> void:
	if target.is_large() or target.boss_role != "" or time < plant.lion_throw_until:
		return
	if not armored and rng.randf() >= 0.30:
		return
	if move_zombie(target, 1.0, false) > 0.0:
		plant.lion_throw_until = time + 3.0
		_lion_cheer(plant, Upgrades.EFFECTS["lion"])
		ring(target.pos, Color("#f0cb81"), 34.0, 0.38)


## 狮步：一阶把目标往自己这边带一点；二阶换成踩伤与推回；三阶留下蹲桩。
func _lion_step(plant: Plant, target: Zombie, fx: Dictionary, tier2: int, large: bool) -> void:
	if tier2 <= 0:
		return
	if tier2 == 1:
		if time >= float(target.step_until):
			target.step_until = time + float(fx["pull_icd"][1])
			move_zombie(target, -float(fx["pull_cells"][1]))
		return
	if not large and move_zombie(target, float(fx["knock_cells"][tier2])) > 0.0:
		_lion_cheer(plant, fx)
	# 前探路径上至多 2 名敌人各吃一次踩伤，一轮每敌只算一次
	var cap = int(fx["step_target_cap"][tier2])
	var reach = float(plant.def["melee"]["reach"])
	var hit = 0
	for z in zombies:
		if hit >= cap or not z.alive() or z.row != plant.row:
			continue
		if z.pos.x < plant.pos.x - 12.0 or z.pos.x - plant.pos.x > reach:
			continue
		if time < float(z.step_hit_until):
			continue
		z.step_hit_until = time + 1.0
		hit += 1
		damage_zombie(z, float(fx["step_damage"][tier2]), false, false, plant.type,"lion_step")


## 踩街（2-3）：撞后蹲桩 0.8 秒，贴身的敌人每次蹲桩最多 2 名各受 60，共享 3 秒触发间隔。
func _lion_brace(plant: Plant, fx: Dictionary, dt: float) -> void:
	if plant.brace_t <= 0.0:
		return
	plant.brace_t = maxf(0.0, plant.brace_t - dt)
	if plant.brace_t > 0.0 or time < float(plant.brace_until):
		return
	var tier2 = plant.tier(2)
	plant.brace_until = time + float(fx["brace_icd"][tier2])
	var hit = 0
	for z in zombies:
		if hit >= int(fx["brace_targets"][tier2]) or not z.alive() or z.row != plant.row:
			continue
		if absf(z.pos.x - plant.pos.x) > 52.0:
			continue
		hit += 1
		damage_zombie(z, float(fx["brace_damage"][tier2]), false, false, plant.type,"lion_brace")
	ring(plant.pos + Vector2(0, -12), Color(0.9, 0.62, 0.3, 0.5), 44.0, 0.5)


## 喝彩（3-2）：把击退换来的气势传给同一行左右相邻的友军，最多三层，仍与其他攻速取最高。
func _lion_cheer(plant: Plant, fx: Dictionary) -> void:
	var tier3 = plant.tier(3)
	if tier3 < 2:
		return
	var range_cells = float(fx["haste_range"][tier3]) * Geo.CELL_W
	for ally in plants:
		if ally.dead or ally == plant or ally.row != plant.row \
				or absf(ally.pos.x - plant.pos.x) > range_cells:
			continue
		if int(ally.cheer) < int(fx["haste_stacks"][tier3]):
			ally.cheer = int(ally.cheer) + 1
		ally.cheer_t = float(fx["haste_duration"][tier3])
		ally.cheer_value = float(fx["haste_per_stack"][tier3])


## 最后一舞（3-3）：被恶客击倒时进入 3 秒延迟退场，攻速翻倍、每撞回 100，
## 第 3 秒强制退场；一个生命周期只触发一次，铲除不触发，治疗不能续期。
func _start_last_dance(plant: Plant) -> bool:
	var fx: Dictionary = Upgrades.EFFECTS["lion"]
	if plant.tier(3) < 3 or bool(plant.danced):
		return false
	plant.danced = true
	plant.dance_t = float(fx["last_dance_seconds"][3])
	plant.timer = 0.0
	float_text(plant.pos + Vector2(0, -86), "最后一舞", Color("#ffe1a1"), 20, 1.4)
	ring(plant.pos + Vector2(0, -20), Color(0.98, 0.76, 0.4, 0.7), 56.0, 0.8)
	return true


func _finish_dance(plant: Plant) -> void:
	plant.dance_t = 0.0
	plant.haste = 0.0
	plant.dead = true
	kill_plant(plant, true)


func _update_wall(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["wall"]
	var heal_tier = plant.tier(1)
	if heal_tier > 0 and plant.hp < plant.max_hp and (
			bool(fx["heal_while_eaten"][heal_tier]) or plant.bite_t <= 0.0):
		plant.hp = minf(plant.max_hp, plant.hp + float(fx["heal"][heal_tier]) * dt)
		if rng.randf() < dt * 1.8:
			particles.append({
				"x": plant.pos.x + rng.randf_range(-12, 12),
				"y": plant.pos.y - 4.0 - rng.randf() * 18.0,
				"vx": rng.randf_range(-5, 5), "vy": -18.0 - rng.randf() * 20.0,
				"life": 0.5, "max": 0.5, "size": 1.6 + rng.randf() * 1.6,
				"color": Color("#9fc7a4"), "kind": "circle",
			})
	var tier = plant.tier(3)
	if tier <= 0:
		return
	plant.timer += dt
	var interval = float(fx["gravel_interval"]) / (1.0 + plant.haste)
	var target = lane_target(plant)
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer -= interval
	plant.charge = 0.0
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(24, -10)
	shot.row = plant.row
	shot.speed = 430.0
	_prepare_shot(shot, plant, float(fx["gravel_damage"][tier]))
	shot.vuln = float(fx["vuln"][tier])
	shot.vuln_duration = float(fx["vuln_duration"])
	shot.knock = float(fx["knock_cells"][tier])
	shots.append(shot)
	plant.action_at = time
	plant.recoil = 0.8
	sfx("gravel_shot")


## 碾磨（石磨 2-3）：被啃毁时炸一圈石屑，代价是磨盘自己散掉。
func wall_blast(plant: Plant) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["wall"]
	var damage = float(fx["bomb_damage"][plant.tier(2)])
	if damage <= 0.0:
		return
	var radius = float(fx["bomb_radius"][plant.tier(2)])
	sfx("explode")
	for z in zombies:
		if z.alive() and z.pos.distance_to(plant.pos) <= radius:
			damage_zombie(z, damage * (1.0 + plant.buff_damage), false, false, plant.type, "ash_wall")
	for i in 24:
		var a = rng.randf() * TAU
		var sp = 60.0 + rng.randf() * 200.0
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 50.0,
			"life": 0.4 + rng.randf() * 0.4, "max": 0.8,
			"size": 2.6 + rng.randf() * 4.0,
			"color": Color("#a8a294") if rng.randf() < 0.6 else Color("#e0d6bd"),
			"kind": "shard",
		})
	shake = maxf(shake, 10.0)


func plant_action_effect(plant: Plant) -> void:
	particles.append({
		"x": plant.pos.x, "y": plant.pos.y + Geo.cell_h(rows) * 0.3,
		"vx": 0.0, "vy": 0.0, "life": 0.40, "max": 0.40,
		"size": float(plant.def.get("sprite_h", 92)), "color": Color.WHITE,
		"kind": "plant_action", "actor": plant.type,
	})


func explode(plant: Plant) -> void:
	plant_action_effect(plant)
	plant.dead = true
	cells[plant.row][plant.col] = null
	sfx("explode")
	var radius = float(plant.def["bomb"]["radius"])
	var damage = float(plant.def["bomb"]["damage"]) * (1.0 + plant.buff_damage)
	for layer in 3:
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y - 18.0,
			"vx": 0.0, "vy": 0.0,
			"life": 0.45 + layer * 0.11, "max": 0.45 + layer * 0.11,
			"size": radius * (0.56 + layer * 0.22),
			"color": Color("#fff0bd") if layer == 0 else Color("#ff9c46")
				if layer == 1 else Color("#a3442c"),
			"kind": "bomb_blast", "delay": layer * 0.055,
		})
	for z in zombies:
		if not z.alive():
			continue
		if z.pos.distance_to(plant.pos) <= radius:
			damage_zombie(z, damage, false, false, plant.type)
	for i in 30:
		var a = rng.randf() * TAU
		var sp = 80.0 + rng.randf() * 260.0
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 60.0,
			"life": 0.45 + rng.randf() * 0.45, "max": 0.9,
			"size": 3.0 + rng.randf() * 5.0,
			"color": Color("#ff8b3d") if rng.randf() < 0.5 else Color("#ffd36b"),
			"kind": "circle",
		})
	for i in 16:
		var a = TAU * float(i) / 16.0 + rng.randf_range(-0.1, 0.1)
		var speed = rng.randf_range(65.0, 145.0)
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y - 18.0,
			"vx": cos(a) * speed, "vy": sin(a) * speed - 32.0,
			"life": 0.55, "max": 0.55,
			"size": rng.randf_range(5.0, 10.0),
			"color": Color("#b2a19a"), "kind": "bomb_smoke",
		})
	shake = maxf(shake, 14.0)


# ── 恶客行为 ────────────────────────────────────────────────────────────────
func eat_target(z: Zombie) -> Plant:
	var reach = float(z.def.get("reach", 38.0))
	var best: Plant = null
	for plant in plants:
		if plant.dead or plant.row != z.row:
			continue
		if plant.is_lily and main_plant_at(plant.col, plant.row) != null:
			continue
		if plant.pos.x <= z.pos.x + 2.0 and z.pos.x - plant.pos.x <= reach:
			if best == null or plant.pos.x > best.pos.x:
				best = plant
	return best


func _tick_guest_special(z: Zombie) -> void:
	if not z.def.has("special_period") or time < z.guest_special_at:
		return
	z.guest_special_at = time + float(z.def["special_period"])
	z.guest_action_at = time
	if z.type == "matchmaker":
		pending_spawns.append({"type": "sedan", "row": z.row, "x": z.pos.x + 24.0,
			"wave_no": z.wave_no, "sedan_bride": true, "guest_summoned": true})
		ring(z.pos, Color("#b65a65"), 34.0, 0.42)
		sfx("bell")
	elif z.type == "tamer":
		for i in 2:
			var row = choose_spawn_row("phaseguard")
			pending_spawns.append({"type": "phaseguard", "row": row, "x": z.pos.x + 26.0 + i * 28.0,
				"wave_no": z.wave_no, "guest_summoned": true})
		ring(z.pos, Color("#d7a36a"), 38.0, 0.48)
		sfx("bell")
	elif z.type == "dreambell":
		var available: Array = []
		for plant in plants:
			if not plant.dead and not plant.is_lily and not plant.ash and plant.row == z.row:
				available.append(plant)
		if not available.is_empty():
			var target = available[rng.randi_range(0, available.size() - 1)]
			target.sleep_until = maxf(target.sleep_until, time + 3.0)
			ring(target.pos, Color("#b6a2d7"), 34.0, 0.6)
			sfx("bell")


func _revive_guest(z: Zombie) -> void:
	z.revive_at = -1.0
	z.revived = true
	z.dying = false
	z.death_t = 0.0
	z.hp = z.max_hp
	z.speed *= 1.5
	z.slow_t = 0.0
	z.stun_t = 0.0
	z.vuln_t = 0.0
	z.burn_t = 0.0
	z.bleed_t = 0.0
	z.reverse_t = 0.0
	z.marks.clear()
	ring(z.pos, Color("#eac179"), 36.0, 0.55)
	sfx("bell")


func update_zombies(dt: float) -> void:
	for z in zombies:
		if z.dead:
			continue
		if z.boss_role!="":
			continue
		if z.revive_at >= 0.0:
			if time >= z.revive_at:
				_revive_guest(z)
			continue
		if z.dying:
			z.death_t += dt
			if z.death_t >= z.death_dur:
				z.dead = true
				z.dying = false
			continue
		_tick_guest_special(z)
		z.hurt = maxf(0.0, z.hurt - dt)
		z.water_entry_t = maxf(0.0, z.water_entry_t - dt)
		if not z.water_entered and String(level.get("map", "")) == "water" \
				and z.row in level.get("water_rows", []) and z.pos.x <= Geo.BOARD_X + Geo.BOARD_W:
			z.water_entered = true
			z.water_entry_t = 0.68
			ring(z.pos + Vector2(0, 22), Color(0.45, 0.75, 0.78, 0.7), 24, 0.6)
			for i in 12:
				particles.append({"x": z.pos.x + rng.randf_range(-18, 18),
					"y": z.pos.y + 24, "vx": rng.randf_range(-46, 46),
					"vy": rng.randf_range(-72, -20), "life": 0.45,
					"max": 0.45, "size": rng.randf_range(1.5, 3.5),
					"color": Color("#8cbdc0"), "kind": "circle"})
		if z.slow_t > 0.0:
			z.slow_t = maxf(0.0, z.slow_t - dt)
			if z.slow_t <= 0.0:
				z.slow_amount = 0.0
		if z.vuln_t > 0.0:
			z.vuln_t = maxf(0.0, z.vuln_t - dt)
			if z.vuln_t <= 0.0:
				z.vuln = 0.0
		if z.burn_t > 0.0:
			z.burn_t = maxf(0.0, z.burn_t - dt)
			damage_zombie(z, z.burn_dps * dt, true, false, String(z.burn_src))
			if not z.alive():
				continue
			if z.burn_t <= 0.0:
				z.burn_dps = 0.0
		if z.suppress_t > 0.0:
			z.suppress_t = maxf(0.0, z.suppress_t - dt)
		# 封益（钟馗像 2-3）：按住的这几秒里增益不走表也不新增，护具与负面状态照旧
		if z.rage_t > 0.0 and z.suppress_t <= 0.0:
			z.rage_t = maxf(0.0, z.rage_t - dt)
		# 贴馅（汤圆仔 1-3）：挂上去的那颗两秒后炸，按本体最大生命结算
		if z.bomb_t > 0.0:
			z.bomb_t = maxf(0.0, z.bomb_t - dt)
			if z.bomb_t <= 0.0 and z.alive():
				var boom = z.bomb_damage
				z.bomb_damage = 0.0
				if boom > 0.0:
					damage_zombie(z, boom, false, true, "lobber")
					ring(Vector2(z.pos.x, z.pos.y - 24.0), Color(1.0, 0.7, 0.35, 0.62),
						44.0, 0.45)
					sfx("lob_shot")
		z.aura_pulse = maxf(0.0, z.aura_pulse - dt)
		z.support_pulse = maxf(0.0, z.support_pulse - dt)
		z.armor_pulse = maxf(0.0, z.armor_pulse - dt)
		z.wail_t = maxf(0.0, z.wail_t - dt)
		if z.gust_left > 0.0:
			z.eating = false
			_step_gust(z, dt)
			continue
		if z.stun_t > 0.0:
			z.stun_t = maxf(0.0, z.stun_t - dt)
			z.eating = false
			if rng.randf() < dt * 2.5:
				particles.append({
					"x": z.pos.x + rng.randf_range(-10, 10),
					"y": z.pos.y - 48.0 + rng.randf_range(-5, 5),
					"vx": 8.0, "vy": -18.0, "life": 0.4, "max": 0.4,
					"size": 1.8, "color": Color("#ffe09a"), "kind": "circle",
				})
			continue
		# 再控免疫从"控完"那一刻才开始走，不能在被控期间就偷偷耗掉
		z.cc_immune = maxf(0.0, z.cc_immune - dt)
		z.reverse_icd = maxf(0.0, z.reverse_icd - dt)
		update_marks(z, dt)
		if z.bleed_t > 0.0:
			z.bleed_t = maxf(0.0, z.bleed_t - dt)
			damage_zombie(z, z.bleed_dps * dt, true, false, "bell")
			if z.bleed_t <= 0.0:
				z.bleed_dps = 0.0
		if z.def.has("aura"):
			z.aura_t -= dt
			if z.aura_t <= 0.0:
				mourner_wail(z)
		if z.def.has("support"):
			z.support_t -= dt
			if z.support_t <= 0.0:
				artisan_grant(z)
		if z.vault_t > 0.0:
			z.vault_t = maxf(0.0, z.vault_t - dt)
			var dur = float(z.def["vault"]["duration"])
			var k = 1.0 - z.vault_t / dur
			z.pos.x = lerpf(z.vault_from, z.vault_to, k)
			z.vault_arc = sin(PI * clampf(k, 0.0, 1.0))
			z.anim += dt * 2.4
			z.eating = false
			if z.vault_t <= 0.0:
				z.vaulted = true
				z.speed = float(z.def["vault"]["speed_after"])
				z.vault_arc = 0.0
				for i in 7:
					particles.append({
						"x": z.pos.x + rng.randf_range(-13, 13), "y": z.pos.y + 24.0,
						"vx": rng.randf_range(-40, 40), "vy": -20.0 - rng.randf() * 40.0,
						"life": 0.4 + rng.randf() * 0.3, "max": 0.7,
						"size": 2.0 + rng.randf() * 3.0,
						"color": Color(0.72, 0.65, 0.52, 0.8), "kind": "circle",
					})
				shake = maxf(shake, 2.5)
			continue
		if z.def.has("vault") and not z.vaulted:
			var obstacle = eat_target(z)
			if obstacle != null:
				z.vault_from = z.pos.x
				z.vault_to = maxf(Geo.BOARD_X + 8.0, obstacle.pos.x - 42.0)
				z.vault_t = float(z.def["vault"]["duration"])
				z.vault_arc = 0.0
				z.eating = false
				for i in 6:
					particles.append({
						"x": z.pos.x + rng.randf_range(-11, 11), "y": z.pos.y + 26.0,
						"vx": rng.randf_range(-45, 45), "vy": -35.0 - rng.randf() * 50.0,
						"life": 0.35 + rng.randf() * 0.3, "max": 0.65,
						"size": 2.0 + rng.randf() * 3.0,
						"color": Color(0.77, 0.69, 0.55, 0.8), "kind": "circle",
					})
				float_text(z.pos + Vector2(0, -66), "跳幡！", Color("#f0d59a"), 15, 0.9)
				continue
		var target = eat_target(z)
		if target != null:
			z.eating = true
			z.chomp += dt
			z.eat_bite = maxf(0.0, z.eat_bite - dt * 8.0)
			z.eat_snd_t -= dt
			if z.eat_snd_t <= 0.0:
				z.eat_bite = 1.0
				target.bite_t = 0.2
				sfx("eat")
				z.eat_snd_t = 0.3 + rng.randf() * 0.12
				for i in 4:
					particles.append({
						"x": z.pos.x - 26.0 + rng.randf_range(-8, 8),
						"y": z.pos.y - 22.0 + rng.randf_range(-7, 7),
						"vx": -30.0 - rng.randf() * 60.0, "vy": -35.0 - rng.randf() * 70.0,
						"life": 0.32 + rng.randf() * 0.22, "max": 0.54,
						"size": 2.0 + rng.randf() * 2.6,
						"color": Color("#c7cba8") if target.shell > 0.0 else Color("#e0c58c"),
						"kind": "shard" if i % 2 else "circle",
					})
			var guard = plant_guard(target)
			damage_plant(target, float(z.def["dps"]) * dt, z)
			var reflect = plant_reflect(target)
			if reflect > 0.0:
				damage_zombie(z, reflect * (1.0 + target.buff_damage) * dt, true, false,
					target.type)
			var bleed = bell_backlash(target, z, float(z.def["dps"]) * (1.0 - guard))
			if bleed > 0.0:
				apply_bleed(z, bleed, float(
					Upgrades.EFFECTS["bell"]["backlash_duration"][target.tier(2)]))
			var thorns = umbrella_thorns(target, float(z.def["dps"]) * (1.0 - guard))
			if thorns > 0.0:
				damage_zombie(z, thorns * dt, true, false, target.type)
			if rng.randf() < dt * 4.0:
				particles.append({
					"x": target.pos.x + rng.randf_range(-10, 10), "y": target.pos.y - 6.0,
					"vx": rng.randf_range(-20, 20), "vy": -30.0 - rng.randf() * 40.0,
					"life": 0.5, "max": 0.5, "size": 2.0 + rng.randf() * 2.0,
					"color": Color("#c7cba8") if target.shell > 0.0 else Color("#d9c08a"),
					"kind": "circle",
				})
			continue
		z.eating = false
		z.eat_bite = 0.0
		z.eat_snd_t = 0.0
		var slow_mult = (1.0 - z.slow_amount) if z.slow_t > 0.0 else 1.0
		var rage = maxf(1.0, z.rage_mult) if z.rage_t > 0.0 and z.suppress_t <= 0.0 else 1.0
		var armor_speed = float(z.def.get("armor_speed", 1.0)) if z.armor > 0.0 else 1.0
		var step = z.speed * armor_speed * slow_mult * rage * dt
		if z.reverse_t > 0.0:
			# 回头：往进场方向走一小段，不传送、不换行、不强制停止啃食
			z.reverse_t = maxf(0.0, z.reverse_t - dt)
			z.pos.x = minf(Geo.RETREAT_MAX_X, z.pos.x + step)
		else:
			z.pos.x -= step
		z.anim += dt * slow_mult * rage
		var col = int((z.pos.x - Geo.BOARD_X) / Geo.CELL_W)
		if col >= 0 and col < Geo.COLS:
			var tile = tile_at(col, z.row)
			if tile["kind"] == "object":
				var key = "%d:%d" % [z.row, col]
				if z.last_object != key:
					z.last_object = key
					z.pos.x = maxf(Geo.BOARD_X + 6.0, z.pos.x - Geo.CELL_W * 0.62)
					z.object_hop = 0.34
					for i in 5:
						particles.append({
							"x": z.pos.x + rng.randf_range(-11, 11), "y": z.pos.y + 22.0,
							"vx": rng.randf_range(-35, 35), "vy": -18.0 - rng.randf() * 35.0,
							"life": 0.35 + rng.randf() * 0.25, "max": 0.6,
							"size": 2.0 + rng.randf() * 2.5,
							"color": Color(0.71, 0.78, 0.75, 0.75), "kind": "circle",
						})
			else:
				z.last_object = ""
		if z.object_hop > 0.0:
			z.object_hop = maxf(0.0, z.object_hop - dt)
		if z.pos.x < Geo.BREACH_X and not z.breached \
				and (bool(mowers[z.row]["ready"]) or z.pos.x < Geo.BREACH_X - 96.0):
			breach(z)


func mourner_wail(z: Zombie) -> void:
	var aura: Dictionary = z.def["aura"]
	z.aura_t = float(aura["interval"])
	z.aura_pulse = 0.85
	z.wail_t = 0.95
	var buffed = false
	for other in zombies:
		if not other.alive() or other == z:
			continue
		if other.pos.distance_to(z.pos) > float(aura["radius"]):
			continue
		var current = maxf(1.0, other.rage_mult) if other.rage_t > 0.0 else 1.0
		var haste = float(aura["haste"])
		if haste > current + 0.0001:
			other.rage_mult = haste
			other.rage_t = float(aura["duration"])
		elif absf(haste - current) <= 0.0001:
			other.rage_t = maxf(other.rage_t, float(aura["duration"]))
		buffed = true
	ring(z.pos + Vector2(0, -6), Color(0.77, 0.49, 0.4, 0.4) if buffed
		else Color(0.59, 0.51, 0.47, 0.32), maxf(30.0, float(aura["radius"]) - 26.0), 0.7)
	for i in 8:
		particles.append({
			"x": z.pos.x + rng.randf_range(-13, 13),
			"y": z.pos.y - 32.0 - rng.randf() * 22.0,
			"vx": rng.randf_range(-18, 18) - 18.0, "vy": -24.0 - rng.randf() * 30.0,
			"life": 0.55 + rng.randf() * 0.35, "max": 0.9,
			"size": 1.8 + rng.randf() * 2.4,
			"color": Color(0.69, 0.84, 0.89, 0.75) if i % 2 else Color(0.86, 0.91, 0.93, 0.55),
			"kind": "circle",
		})
	sfx("wail")


## 纸扎匠优先给没有护具、护具最薄的低阶恶客发甲。
static func _later_armor_first(a: Zombie, b: Zombie) -> bool:
	var aa = 1 if a.armor > 0.0 else 0
	var bb = 1 if b.armor > 0.0 else 0
	if aa != bb:
		return aa < bb
	return a.armor < b.armor


func artisan_grant(z: Zombie) -> void:
	var support: Dictionary = z.def["support"]
	z.support_t = float(support["interval"])
	z.support_pulse = 0.85
	var hp_mult = hp_mul * float(difficulty_mult()["hp"])
	var armor_value = maxf(40.0, round(float(support["armor"]) * hp_mult))
	var pool: Array = []
	for other in zombies:
		if not other.alive() or other == z:
			continue
		if String(other.def.get("tier", "")) != "l":
			continue
		if other.pos.distance_to(z.pos) > float(support["radius"]):
			continue
		pool.append(other)
	pool.sort_custom(_later_armor_first)
	for other in pool.slice(0, int(support["targets"])):
		other.max_armor = maxf(other.max_armor, armor_value)
		other.armor = minf(other.max_armor, maxf(other.armor, armor_value))
		other.armor_type = "charm"
		other.armor_name = String(support["name"])
		other.armor_pulse = 0.9
		float_text(other.pos + Vector2(0, -62), "纸甲", Color("#e5d6a4"), 14, 1.1)
	ring(z.pos + Vector2(0, -20), Color(0.88, 0.8, 0.59, 0.55) if not pool.is_empty()
		else Color(0.67, 0.63, 0.55, 0.3), 54.0, 0.65)
	sfx("grant")


func breach(z: Zombie) -> void:
	z.breached = true
	if z.row < lane_breaches.size():
		lane_breaches[z.row] = int(lane_breaches[z.row]) + 1
	var mower: Dictionary = mowers[z.row]
	if bool(mower["ready"]):
		mower["ready"] = false
		for plant in plants:
			if not plant.dead and plant.type == "star" and plant.tier(2) >= 3:
				plant.star_guardian_until = time + 10.0
		mower["active"] = true
		mower["x"] = Geo.MOWER_X
		sfx("mower")
		shake = maxf(shake, 8.0)
		float_text(Vector2(Geo.BOARD_X + 60.0, row_y(z.row) - 40.0), "门神显灵！",
			Color("#ffd98a"), 18, 1.4)
		# 冲门的恶客由门神当场扫倒；后续恶客须走完无人守护的路才算失守。
		damage_zombie(z, z.hp + z.armor + 100000.0, false, true, "mower")
		return
	if training:
		z.dead = true
		z.dying = false
		float_text(Vector2(Geo.BOARD_X + 80.0, row_y(z.row) - 36.0), "训练场不判负",
			Color("#ffd98a"), 16, 1.4)
		return
	if on_lose.is_valid():
		on_lose.call(z)


# ── 射弹 ────────────────────────────────────────────────────────────────────
func update_shots(dt: float) -> void:
	for shot in shots:
		if shot.dead:
			continue
		if shot.uid=="":shot.uid="s%d" % shot.get_instance_id()
		if boss!=null:boss.damage_token="shot:"+shot.uid
		_apply_glow_pass(shot)
		match shot.kind:
			"homing":
				_update_homing(shot, dt)
			"lob":
				_update_lob_shot(shot, dt)
			"star":
				_update_star_shot(shot, dt)
			_:
				_update_straight(shot, dt)
	if boss!=null:boss.damage_token=""


## 满城（1-3）：友军射弹穿过一盏余光就被点亮，+15% 与红灯笼、炭火盆取最高，不相加。
func _apply_glow_pass(shot: Shot) -> void:
	for g in grounds:
		if String(g["kind"]) != "glow":
			continue
		var buff = float(g.get("buff", 0.0))
		if buff <= 0.0 or shot.glow >= buff:
			continue
		if Vector2(shot.pos.x, shot.pos.y).distance_to(g["pos"]) > float(g["radius"]):
			continue
		shot.glow = buff
		shot.damage = _shot_damage(shot)


func _apply_torch_pass(shot: Shot, previous: Vector2) -> void:
	for plant in plants:
		if plant.dead or plant.type != "torch" or plant.sleep_until > time:
			continue
		var crossed = false
		if shot.kind == "star":
			crossed = shot.pos.distance_to(plant.pos + Vector2(0, -18)) < 52.0
		else:
			var same_lane = absf(shot.pos.y - plant.pos.y) < 64.0 \
				if shot.kind == "homing" else shot.row == plant.row
			if not same_lane:
				continue
			crossed = (previous.x - plant.pos.x) * (shot.pos.x - plant.pos.x) <= 0.0
			if not crossed:
				crossed = absf(shot.pos.x - plant.pos.x) < 12.0
		if not crossed:
			continue
		if time - plant.action_at >= 0.42:
			plant.action_at = time
		var fx: Dictionary = Upgrades.EFFECTS["torch"]
		var tier1 = plant.tier(1)
		var tier2 = plant.tier(2)
		# 多盆只取最高：火盆增幅与红灯笼增幅同样「取最高不叠加」。
		var buff = float(fx["buff"][tier1])
		if buff > shot.torch_buff + 0.0001:
			shot.torch_buff = buff
			shot.damage = shot.base_damage * (1.0 + maxf(shot.lantern_buff, buff))
		# 灼烧有两处来源：火色（1 路）的火箭与余烬（2 路）的余烬，取最强的一份
		var burn = float(fx["burn_dps"][tier1])
		var burn_dur = float(fx["burn_duration"][tier1])
		if float(fx["ember"][tier2]) > burn:
			burn = float(fx["ember"][tier2])
			burn_dur = float(fx["ember_duration"][tier2])
		if burn > shot.burn + 0.0001:
			shot.burn = burn
			shot.burn_duration = burn_dur
		# 不熄（1-3）：既把弹推得更快，也把主射弹磨穿——斗笠石帽陶瓮铁面都挡不住。
		# 穿的只是这一发本体：灼烧、火星和溅射各算各的账。
		if float(fx["shot_speed"][tier1]) > 0.0 and not shot.speed_boosted:
			shot.speed *= 1.0 + float(fx["shot_speed"][tier1])
			shot.speed_boosted = true
		if bool(fx["pierce_main"][tier1]):
			shot.pierce_armor = true
		if float(fx["splash_ratio"][tier1]) > 0.0:
			shot.torch_splash_ratio = maxf(shot.torch_splash_ratio,
				float(fx["splash_ratio"][tier1]))
			shot.torch_splash_radius = maxf(shot.torch_splash_radius,
				float(fx["splash_radius"][tier1]) * Geo.CELL_W)
		_torch_sparks(plant, shot, fx, tier1)
		# 燎原（2-3）：命中后炸开，状态溅给 0.5 格内的恶客
		shot.blast = maxf(shot.blast, float(fx["explode_radius"][tier2]))
		if shot.torch_buff > 0.0 or shot.burn > 0.0:
			shot.fire = true
			shot.fire_t = maxf(shot.fire_t, 0.6)


## 掉星（1-2）：穿过火盆的射弹在盆边落火星，每颗是一块 1 秒的小地火。
## 一颗一颗地从盆的每秒预算里扣，所以再密的弹幕也只能每秒掉两颗。
func _torch_sparks(plant: Plant, shot: Shot, fx: Dictionary, tier1: int) -> void:
	var per = int(fx["sparks_per_projectile"][tier1])
	var radius = float(fx["spark_radius"][tier1]) * Geo.CELL_W
	var dropped = 0
	while dropped < per and plant.spark_window >= 1.0:
		plant.spark_window -= 1.0
		dropped += 1
		add_ground("spark", Vector2(plant.pos.x + rng.randf_range(-18, 18), plant.pos.y - 18.0),
			radius, float(fx["spark_duration"][tier1]), float(fx["spark_dps"][tier1]),
			1.0, 0.0, 0.0, "torch")
	if dropped > 0:
		spark(shot.pos, Color("#ffcf7a"), 4)


## 泼油（3-2）：真被啃到才往啃它的家伙脚下一摊油。同一盆 2 秒一次，
## 油本身按 icd 每秒结算一次，所以站上去不会被同一片油连扣两下。
func _torch_oil(plant: Plant, from: Zombie) -> void:
	var tier3 = plant.tier(3)
	if String(plant.type) != "torch" or from == null or tier3 < 2:
		return
	var fx: Dictionary = Upgrades.EFFECTS["torch"]
	if time < float(plant.oil_until):
		return
	plant.oil_until = time + float(fx["oil_icd"][tier3])
	add_ground("oil", Vector2(from.pos.x, from.pos.y - 20.0),
		float(fx["oil_radius"][tier3]) * Geo.CELL_W,
		float(fx["oil_duration"][tier3]), float(fx["oil_dps"][tier3]),
		1.0, 0.0, 0.0, "torch")


## 火墙（3-3）：被啃塌的那一下炸开一圈 1.5 格、烧 3 秒的火。
func _torch_wall(plant: Plant) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["torch"]
	var radius = float(fx["wall_radius"][3]) * Geo.CELL_W
	add_ground("wall", plant.pos + Vector2(0, -18), radius,
		float(fx["wall_duration"][3]), float(fx["wall_dps"][3]), 1.0, 0.0, 0.0, "torch")
	ring(plant.pos + Vector2(0, -18), Color(1.0, 0.56, 0.22, 0.72), radius, 0.6)
	sfx("torch")


func _update_straight(shot: Shot, dt: float) -> void:
	var previous = shot.pos
	shot.pos.x += shot.speed * dt * PROJECTILE_SPEED_SCALE
	_apply_torch_pass(shot, previous)
	var victim: Zombie = null
	for z in zombies:
		if z.dead or z.row != shot.row or shot.hit_ids.has(z):
			continue
		if shot.pos.x + 8.0 >= z.pos.x - 24.0 and shot.pos.x - 8.0 <= z.pos.x + 24.0:
			if victim == null or z.pos.x < victim.pos.x:
				victim = z
	if victim != null:
		_strike_straight(shot, victim)
		return
	if shot.pos.x > 1360.0:
		shot.dead = true


## 直弹结算。透骨针的穿堂（1 路）让同一根针接着往前穿：
## 每一档按 pierce_factors 吃主伤，一根针不会重复命中同一名。
func _strike_straight(shot: Shot, victim: Zombie) -> void:
	shot.hit_ids.append(victim)
	var factor = 1.0
	var step = shot.hit_ids.size() - 1
	if not shot.pierce_factors.is_empty() and step < shot.pierce_factors.size():
		factor = float(shot.pierce_factors[step])
	shot.damage = _shot_damage(shot) * factor
	if victim.dying:
		shot.dead = true
		spark(shot.pos, Color("#c9bda0"), 3)
		return
	var large = victim.is_large()
	var damage = shot.damage * 2.0 if (shot.knock > 0.0 and large) else shot.damage
	if shot.armor_double and victim.armor > 0.0:
		damage *= 2.0
	damage_zombie(victim, damage, false, shot.pierce_armor, String(shot.src), "", false, shot.kind)
	# 排针（1-3）：针过去时另削 40 护具，削不完的留在护具上，不溢出本体
	if shot.armor_strip > 0.0:
		victim.armor = maxf(0.0, victim.armor - shot.armor_strip)
	_needle_impact(shot, victim)
	apply_shot_statuses(victim, shot)
	apply_shot_blast(shot, victim)
	if shot.knock > 0.0 and not large and victim.alive():
		victim.pos.x = minf(Geo.RETREAT_MAX_X, victim.pos.x + shot.knock * Geo.CELL_W)
		ring(Vector2(victim.pos.x, victim.pos.y + 8.0), Color(0.78, 0.7, 0.55, 0.6), 18.0, 0.4)
	spark(shot.pos, Color("#ffe9a8") if shot.big else Color("#f0dca8"),
		8 if shot.big else 3)
	if shot.pierce_all or shot.hit_ids.size() <= shot.pierce_left:
		return
	shot.dead = true


func _update_homing(shot: Shot, dt: float) -> void:
	if shot.delay > 0.0:
		shot.delay = maxf(0.0, shot.delay - dt)
		return
	var previous = shot.pos
	_apply_torch_pass(shot, previous)
	if shot.target == null or not shot.target.alive():
		shot.target = _homing_retarget(shot)
	if shot.target == null:
		shot.dead = true
		return
	var aim = Vector2(shot.target.pos.x, shot.target.pos.y - 24.0)
	var delta = aim - shot.pos
	var distance = delta.length()
	# 绕（1-1／1-2）：进了圈子就先把半圈绕完，绕完才落到目标身上
	if shot.orbit > 0.0 and (shot.orbit_done > 0.0 or distance <= shot.orbit + 16.0):
		_orbit_cat(shot, aim, dt)
		return
	if distance < 15.0:
		var victim = shot.target
		shot.hit_ids.append(victim)
		if shot.look == "star":
			_star_impact(shot, victim)
		else:
			damage_zombie(victim, shot.damage, false, false, String(shot.src), "", false, shot.kind)
			_cat_mark(victim, shot)
			apply_shot_statuses(victim, shot)
			apply_shot_blast(shot, victim)
		spark(shot.pos, Color("#ffd08a"), 5)
		shot.hits_left -= 1
		if shot.hits_left > 0:
			var next = nearest_zombies(shot.pos, 1, shot.hit_ids)
			if not next.is_empty():
				shot.target = next[0]
				# 换人之后重新绕一圈：上一名的半圈已经绕完了
				shot.orbit_done = 0.0
				return
		shot.dead = true
		return
	shot.pos = shot.pos.move_toward(aim, shot.speed * dt * PROJECTILE_SPEED_SCALE)
	_apply_torch_pass(shot, previous)
	if rng.randf() < dt * 24.0:
		particles.append({
			"x": shot.pos.x, "y": shot.pos.y,
			"vx": rng.randf_range(-8, 8), "vy": -12.0 - rng.randf() * 16.0,
			"life": 0.35, "max": 0.35, "size": 1.8 + rng.randf() * 1.4,
			"color": Color("#ffb45e"), "kind": "circle",
		})
	for z in zombies:
		if not z.dying:
			continue
		# 已经被这团尾火咬过的尸体不再挡它——回魂要能带着尾火继续追下一个
		if shot.hit_ids.has(z):
			continue
		if Vector2(z.pos.x, z.pos.y - 24.0).distance_to(shot.pos) > 22.0:
			continue
		shot.dead = true
		return


func _update_lob_shot(shot: Shot, dt: float) -> void:
	if shot.delay > 0.0:
		shot.delay = maxf(0.0, shot.delay - dt)
		return
	if shot.target != null and shot.target.alive():
		shot.tx = shot.target.pos.x
		shot.ty = shot.target.pos.y - 14.0
	var previous = shot.pos
	var fire_speed = 1.0 + float(Upgrades.EFFECTS["torch"]["shot_speed"][3]) if shot.speed_boosted else 1.0
	shot.t += dt * PROJECTILE_SPEED_SCALE * fire_speed
	var k = minf(1.0, shot.t / shot.flight)
	shot.pos.x = lerpf(shot.start.x, shot.tx, k)
	var base_y = lerpf(shot.start.y, shot.ty, k)
	shot.pos.y = base_y - 108.0 * 4.0 * k * (1.0 - k)
	_apply_torch_pass(shot, previous)
	if k < 1.0:
		return
	shot.dead = true
	var victim: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != shot.row:
			continue
		if victim == null or absf(z.pos.x - shot.tx) < absf(victim.pos.x - shot.tx):
			victim = z
	if shot.src == "lobber":
		_soup_ground(shot)
	if victim == null or absf(victim.pos.x - shot.tx) > 54.0:
		if shot.src == "firework":
			_firework_ground_splash(shot)
		else:
			spark(shot.pos, Color("#e8d6a8"), 4)
		return
	if shot.src == "firework":
		damage_zombie(victim, shot.damage, false, false, shot.src, "", false, shot.kind)
		apply_shot_blast(shot, victim)
		spark(shot.pos, Color("#ffd080"), 18)
	elif shot.src == "dragon":
		damage_zombie(victim, shot.damage, false, false, shot.src, "", false, shot.kind)
		apply_shot_statuses(victim, shot)
		apply_shot_blast(shot, victim)
		spark(shot.pos, Color("#efc07f"), 9)
	else:
		_soup_impact(shot, victim)


func _firework_ground_splash(shot: Shot) -> void:
	var center = Vector2(shot.tx, shot.ty + 14.0)
	for z in zombies:
		if z.alive() and z.pos.distance_to(center) <= shot.firework_radius:
			damage_zombie(z, shot.damage * 0.3, false, false, "firework", "", false, shot.kind)
	ring(shot.pos, Color("#f5b461"), shot.firework_radius, 0.36)
	spark(shot.pos, Color("#ffd080"), 15)


## 落点砸中人的那一本账：数馅只涨这一笔、砸飞削护具、贴馅挂在大个身上、大汤溅开。
func _soup_impact(shot: Shot, victim: Zombie) -> void:
	var p: Dictionary = shot.payload
	damage_zombie(victim, shot.damage * (1.0 + shot.crowd), false, false, String(shot.src), "", false, shot.kind)
	_lob_heat_on_hit(shot)
	# 砸飞（1-2）：带甲的这一下最多削 40，剩下的护具还在；一击剥不掉整件
	var chip = float(p.get("chip", 0.0))
	if chip > 0.0 and victim.alive() and victim.armor > 0.0:
		victim.armor = maxf(0.0, victim.armor - chip)
		if victim.armor <= 0.0:
			_soup_debris(victim, p, String(shot.src))
	# 贴馅（1-3）：大型躲不开那一口——挂一颗两秒后炸的，按最大生命 8%、封顶 160
	if float(p.get("attach", 0.0)) > 0.0 and victim.alive() and victim.is_large() \
			and time >= float(victim.attach_until) and victim.bomb_t <= 0.0:
		victim.attach_until = time + float(p.get("attach_icd", 0.0))
		victim.bomb_t = float(p.get("attach", 0.0))
		victim.bomb_damage = minf(float(victim.max_hp) * float(p.get("attach_ratio", 0.0)),
			float(p.get("attach_cap", 0.0)))
		float_text(Vector2(victim.pos.x, victim.pos.y - 108), "贴馅",
			Color("#f0c26e"), 15, 1.0)
	# 三更（2-3）：大汤溅开，额外目标各吃基础直伤的四成，至多 3 名
	if shot.big_soup and shot.splash_radius > 0.0:
		var extra = 0
		for z in zombies:
			if extra >= shot.splash_targets:
				break
			if not z.alive() or z == victim:
				continue
			if Vector2(z.pos.x, z.pos.y - 20.0).distance_to(
					Vector2(victim.pos.x, victim.pos.y - 20.0)) > shot.splash_radius:
				continue
			extra += 1
			damage_zombie(z, shot.base_damage * shot.splash_ratio, false, false,
				String(shot.src), "", false, shot.kind)
		ring(shot.pos + Vector2(0, 8), Color(0.94, 0.76, 0.5, 0.55), shot.splash_radius, 0.5)
	apply_shot_statuses(victim, shot)
	apply_shot_blast(shot, victim)
	spark(shot.pos, Color("#f0dca8"), 7)
	ring(shot.pos + Vector2(0, 8), Color(0.9, 0.82, 0.67, 0.5), 18.0, 0.4)


## 砸飞（1-2）：护具被打穿的那一下掉一地残片，4 秒里普通绊 0.2 秒、大型只减速。
## 同一名 4 秒最多一片，免得一轮汤圆把街口铺满碎壳。
func _soup_debris(victim: Zombie, p: Dictionary, src: String) -> void:
	if time < float(victim.debris_until):
		return
	victim.debris_until = time + float(p.get("debris_icd", 0.0))
	add_ground("debris", Vector2(victim.pos.x, victim.pos.y - 20.0), 30.0,
		float(p.get("debris_life", 0.0)), 0.0, 1.0, 0.0, 0.0, src,
		{"trip": float(p.get("trip", 0.0)),
			"trip_slow": float(p.get("trip_slow", 0.0)),
			"trip_slow_duration": float(p.get("trip_slow_duration", 0.0))})
	float_text(Vector2(victim.pos.x, victim.pos.y - 92), "砸飞", Color("#e8d6a8"), 15, 0.9)


## 一摊（3-1）／合流（3-2）／封口（3-3）：汤摊落在落点上，两摊相交熬成一锅浓汤。
## 新摊能刷新浓汤的时间，但不会再把它摊大、摊烫；三摊也不会连成一片。
func _soup_ground(shot: Shot) -> void:
	var p: Dictionary = shot.payload
	var radius = float(p.get("pool", 0.0))
	if radius <= 0.0:
		return
	var at = Vector2(shot.tx, shot.ty + 6.0)
	var merged = float(p.get("merged", 0.0))
	var broth: Dictionary = {}
	var thin: Dictionary = {}
	for g in grounds:
		if String(g["kind"]) == "broth":
			if Vector2(g["pos"].x, g["pos"].y).distance_to(at) \
					<= float(g["radius"]) + radius:
				broth = g
				break
		elif String(g["kind"]) == "soup" and merged > 0.0:
			if Vector2(g["pos"].x, g["pos"].y).distance_to(at) <= float(g["radius"]) + radius:
				thin = g
	if not broth.is_empty():
		# 已经熬成一锅：新汤只能续火，不能改锅的大小和温度
		broth["life"] = float(broth["life"]) + float(p.get("pool_life", 0.0))
		return
	if merged > 0.0 and not thin.is_empty():
		grounds.erase(thin)
		add_ground("broth", (Vector2(thin["pos"].x, thin["pos"].y) + at) * 0.5, merged,
			float(p.get("pool_life", 0.0)), float(p.get("merged_dps", 0.0)), 1.0,
			float(p.get("merged_slow", 0.0)), 1.5, String(shot.src),
			{"cap": int(p.get("cap", 0)), "eater": float(p.get("eater", 0.0)),
				"large_slow": float(p.get("large_slow", -1.0))})
		ring(at + Vector2(0, -6), Color(0.86, 0.62, 0.32, 0.5), merged, 0.45)
		return
	add_ground("soup", at, radius, float(p.get("pool_life", 0.0)),
		float(p.get("pool_dps", 0.0)), 1.0, float(p.get("pool_slow", 0.0)), 1.5,
		String(shot.src), {"cap": int(p.get("cap", 0)), "large_slow": float(p.get("large_slow", -1.0))})


func _update_star_shot(shot: Shot, dt: float) -> void:
	var previous = shot.pos
	shot.pos += shot.dir * shot.speed * dt * PROJECTILE_SPEED_SCALE
	shot.life -= dt * PROJECTILE_SPEED_SCALE
	_apply_torch_pass(shot, previous)
	var off = shot.pos.x < -100.0 or shot.pos.x > 1380.0 \
			or shot.pos.y < -100.0 or shot.pos.y > Geo.BOARD_Y + Geo.BOARD_H + 100.0
	if shot.life <= 0.0 or off:
		# 回焰 / 天网：撞到地图边界的灯焰折回来，改成追踪弹继续咬住最近的恶客
		if shot.seek:
			var next = nearest_zombies(shot.pos, 1)
			if not next.is_empty():
				shot.pos = Vector2(
					clampf(shot.pos.x, Geo.BOARD_X - 30.0, Geo.SPAWN_X + 30.0),
					clampf(shot.pos.y, Geo.BOARD_Y - 30.0,
						Geo.BOARD_Y + Geo.BOARD_H + 30.0))
				shot.kind = "homing"
				shot.look = "star"
				shot.target = next[0]
				shot.row = next[0].row
				shot.speed = 340.0 * (1.5 if shot.speed_boosted else 1.0)
				shot.retarget = -1
				shot.seek = false
				shot.damage = shot.damage * shot.seek_factor
				shot.seek_factor = 1.0
				spark(shot.pos, Color("#ffe08a"), 3)
				return
		shot.dead = true
		return
	var victim: Zombie = null
	for z in zombies:
		if not z.alive():
			continue
		if absf(z.pos.x - shot.pos.x) <= 28.0 and absf((z.pos.y - 26.0) - shot.pos.y) <= 40.0:
			if victim == null or absf(z.pos.x - shot.pos.x) < absf(victim.pos.x - shot.pos.x):
				victim = z
	if victim == null:
		return
	shot.dead = true
	_star_impact(shot, victim)
	spark(shot.pos, Color("#ffcf7a") if shot.fire else Color("#ffe08a"), 5)


## 灯焰落身的那一下：聚照按「这一轮第几道撞同一名」加钱，重灯把小型推回半格，
## 满城的灯焰在落点留一秒余光，让后面经过的友军射弹被点亮。
func _star_impact(shot: Shot, victim: Zombie) -> void:
	var damage = shot.damage
	if shot.converge > 0.0 and not shot.counted and not shot.volley.is_empty():
		var hits: Dictionary = shot.volley.get("hits", {})
		var key = victim.get_instance_id()
		var seen = int(hits.get(key, 0)) + 1
		hits[key] = seen
		shot.counted = true
		if seen >= 2:
			damage *= 1.0 + shot.converge
	var dealt = damage_zombie(victim, damage, false, false, String(shot.src), "", false, shot.kind)
	if not victim.alive() and shot.owner_uid != "":
		for plant in plants:
			if plant.uid == shot.owner_uid and not plant.dead and plant.tier(1) >= 3:
				if time >= plant.star_morale_until:
					plant.star_morale_stacks = 0
				if plant.star_morale_stacks < 3:
					plant.star_morale_stacks += 1
					plant.star_morale_until = time + 5.0
				break
	# 灯轮（2-3）：重灯多推 0.3 格，走公共位移账本，同一名 3 秒一次
	if shot.heavy and shot.heavy_knock > 0.0 and victim.alive() \
			and not victim.is_large() and time >= float(victim.heavy_until):
		victim.heavy_until = time + shot.heavy_knock_icd
		if move_zombie(victim, shot.heavy_knock) > 0.0:
			ring(Vector2(victim.pos.x, victim.pos.y + 6.0),
				Color(0.98, 0.82, 0.44, 0.55), 26.0, 0.4)
	var p: Dictionary = shot.payload
	var radius = float(p.get("glow_r", 0.0))
	if radius > 0.0 and dealt > 0.0:
		add_ground("glow", Vector2(victim.pos.x, victim.pos.y - 26.0), radius,
			float(p.get("glow_life", 0.0)), 0.0, 1.0, 0.0, 0.0, String(shot.src),
			{"buff": float(p.get("glow_buff", 0.0))})
	apply_shot_statuses(victim, shot)
	apply_shot_blast(shot, victim)


# ── 伤害与死亡 ──────────────────────────────────────────────────────────────
func damage_zombie(z: Zombie, amount: float, silent: bool = false,
		pierce_armor: bool = false, source: String = "", event_key: String = "",
		parallel_armor: bool = false, delivery: String = "") -> float:
	if z == null or not z.alive():
		return 0.0
	if bool(z.def.get("ash_immune", false)) and (source in ["bomb", "mushroom", "kelp", "squash"]
			or event_key.begins_with("ash_")):
		return 0.0
	if z.boss_role=="body":
		z.hurt=0.08
		if boss==null:return 0.0
		var previous=String(boss.damage_token)
		if previous!="" and event_key!="":boss.damage_token=previous+":"+event_key
		var dealt_boss=float(boss.damage(z,amount,source))
		boss.damage_token=previous
		return dealt_boss
	if not silent and amount >= 8.0:
		# 打在本体上和打在护具上是两种声音：护具还带着自己的材质
		sfx("hit", {"armor": String(z.armor_type), "armor_left": z.armor,
			"heavy": amount >= 40.0})
		if z.armor <= 0.0 and float(z.get_meta("armor_was", 0.0)) > 0.0:
			sfx("armor_break", {"armor": String(z.armor_type)})
	z.set_meta("armor_was", z.armor)
	var damage = amount
	if z.type == "phaseguard":
		var resisted = delivery != "" if z.phase_form == 0 else delivery == "lob"
		damage *= 0.5 if resisted else 1.2
	if bool(z.def.get("projectile_shield", false)):
		pierce_armor = delivery.is_empty()
	if z.vuln_t > 0.0 and z.vuln > 0.0:
		damage *= 1.0 + z.vuln
	var dealt = 0.0
	if not pierce_armor and z.armor > 0.0:
		var body_factor = 1.0 + z.vuln if z.vuln_t > 0.0 else 1.0
		var armor_factor = maxf(1.4, body_factor) / body_factor if time < z.armor_vuln_until else 1.0
		var absorbed = minf(z.armor, damage * armor_factor)
		z.armor -= absorbed
		if not parallel_armor:
			damage = maxf(0.0, damage - absorbed / armor_factor)
		dealt += absorbed
		if z.armor <= 0.0:
			z.armor = 0.0
			break_armor(z)
	if damage > 0.0 and z.alive():
		z.hp -= damage
		dealt += damage
	if z.type == "phaseguard" and not z.phase_switched and z.hp > 0.0 and z.hp <= z.max_hp * 0.5:
		z.phase_switched = true
		z.phase_form = 1 - z.phase_form
		z.guest_action_at = time
		ring(z.pos, Color("#d0b68c"), 32.0, 0.45)
	z.hurt = 0.14
	if source != "" and dealt > 0.0:
		damage_by_type[source] = float(damage_by_type.get(source, 0.0)) + dealt
	if z.hp <= 0.0:
		kill_zombie(z, event_key != "incense_primary")
	return dealt


func break_armor(z: Zombie) -> void:
	sfx("shell")
	if z.type == "reedboat":
		z.water_entry_t = 0.42
	var colors = {
		"shield": Color("#a88b61"), "raft": Color("#a18d65"),
		"paper": Color("#efe6cf"), "sedan": Color("#c77a55"), "straw": Color("#d7b26a"),
		"stonehat": Color("#a8a69a"), "urn": Color("#b07a4e"), "mask": Color("#7d858a"),
		"charm": Color("#e5d6a4"),
	}
	var color: Color = colors.get(z.armor_type, Color("#efe6cf"))
	for i in 10:
		particles.append({
			"x": z.pos.x + rng.randf_range(-14, 14),
			"y": z.pos.y - 24.0 - rng.randf() * 22.0,
			"vx": rng.randf_range(-70, 70), "vy": -40.0 - rng.randf() * 100.0,
			"life": 0.55, "max": 0.75, "size": 3.0 + rng.randf() * 5.0,
			"color": color,
			"kind": "shard" if z.armor_type in ["paper", "charm"] else "circle",
		})
	if z.def.has("split") and not z.split_done:
		z.split_done = true
		var split: Dictionary = z.def["split"]
		var count = int(split["count"])
		for i in count:
			pending_spawns.append({
				"type": split["type"], "row": z.row,
				"x": z.pos.x + (i - (count - 1) * 0.5) * 20.0,
				"hp_factor": float(split["hp"]), "wave_no": z.wave_no, "sedan_split": true,
			})
		if z.sedan_has_bride:
			pending_spawns.append({"type": "bride", "row": z.row,
				"x": z.pos.x + 23.0, "hp_factor": 1.0, "wave_no": z.wave_no, "sedan_split": true})
		float_text(z.pos + Vector2(0, -76), "轿子散了！", Color("#ffd0a0"), 17, 1.4)
		shake = maxf(shake, 6.0)
		kill_zombie(z)
		z.death_dur = 0.22


func kill_zombie(z: Zombie, spread_incense: bool = true) -> void:
	if not z.alive():
		return
	if z.boss_role=="body":
		# Instant capture/execute cannot remove a shared-health boss.
		return
	if z.boss_role!="":
		if boss!=null:boss.break_prop(z)
		return
	if z.type == "returner" and not z.revived:
		z.hp = 0.0
		z.dying = true
		z.eating = false
		z.revive_at = time + 1.0
		z.guest_action_at = time
		ring(z.pos, Color("#a3743d"), 27.0, 0.4)
		return
	z.dying = true
	z.death_t = 0.0
	z.hp = 0.0
	z.eating = false
	if spread_incense:
		spread_marks_on_death(z, {z.get_instance_id(): true}, 0)
	z.stun_t = 0.0
	z.breached = true
	sfx("zombie_die")
	kills += 1
	sfx("kill")
	var colors = {
		"mountain": Color("#5a4030"), "paper": Color("#efe6cf"),
		"mourner": Color("#d8d2c4"), "sedan": Color("#a83a2e"),
		"tongue": Color("#87a87d"), "straw": Color("#c9a45e"),
		"stonehat": Color("#9a978b"), "bucket": Color("#8f999b"),
		"vault": Color("#a98252"), "artisan": Color("#e8ddc1"),
		"ironjudge": Color("#6f7679"),
	}
	var color: Color = colors.get(z.type, Color("#9fb3a2"))
	for i in 10:
		particles.append({
			"x": z.pos.x + rng.randf_range(-13, 13),
			"y": z.pos.y - 10.0 - rng.randf() * 30.0,
			"vx": rng.randf_range(-70, 70), "vy": -30.0 - rng.randf() * 120.0,
			"life": 0.5 + rng.randf() * 0.4, "max": 0.9,
			"size": 3.0 + rng.randf() * 4.0, "color": color, "kind": "shard",
		})
	if bool(z.def.get("large", false)):
		shake = maxf(shake, 5.0)
	if tutorial != null and String(tutorial["step"]) == "battle" and tutorial["zombie"] == z:
		tutorial["step"] = "finishing"
		tutorial["done_t"] = 0.9
		float_text(z.pos + Vector2(0, -58), "干得漂亮", Color("#ffe1a1"), 22, 1.4)


# ── 门神与太阳 ──────────────────────────────────────────────────────────────
func update_mowers(dt: float) -> void:
	for mower in mowers:
		if not bool(mower["active"]):
			continue
		mower["x"] = float(mower["x"]) + 640.0 * dt
		for z in zombies:
			if z.alive() and z.boss_role!="body" and z.row == int(mower["row"]) \
					and absf(z.pos.x - float(mower["x"])) < 56.0:
				kill_zombie(z)
		if float(mower["x"]) > 1360.0:
			mower["active"] = false


func restore_mowers() -> void:
	for mower in mowers:
		mower["ready"] = true
		mower["active"] = false
		mower["x"] = Geo.MOWER_X


func update_orbs(dt: float) -> void:
	for orb in orbs:
		if bool(orb["dead"]):
			continue
		if not bool(orb["landed"]):
			orb["y"] = float(orb["y"]) + 130.0 * dt
			if float(orb["y"]) >= float(orb["target_y"]):
				orb["y"] = float(orb["target_y"])
				orb["landed"] = true
			continue
		orb["life"] = float(orb["life"]) - dt
		# 教学关的香火不设时限，也不能被自动拾取（v0.2.4 曾在这里把 life 改回 10 卡死教学）。
		if auto_collect and tutorial == null:
			orb["auto_t"] = float(orb["auto_t"]) + dt
			if float(orb["auto_t"]) >= collect_delay:
				collect_orb(orb)
				continue
		if float(orb["life"]) <= 0.0:
			orb["dead"] = true


func collect_orb(orb: Dictionary) -> void:
	if bool(orb["dead"]):
		return
	orb["dead"] = true
	sun += int(orb["value"])
	float_text(Vector2(float(orb["x"]), float(orb["y"]) - 12.0),
		"+%d" % int(orb["value"]), Color("#ffd98a"), 18, 0.9)
	spark(Vector2(float(orb["x"]), float(orb["y"])), Color("#ffcf7a"), 6)
	sfx("collect")
	if tutorial != null and String(tutorial["step"]) == "collect" and tutorial["orb"] == orb:
		tutorial["step"] = "plant"
		tutorial["orb"] = {}


func pick_orb(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d = 44.0
	for orb in orbs:
		if bool(orb["dead"]):
			continue
		var d = Vector2(float(orb["x"]), float(orb["y"])).distance_to(at)
		if d < best_d:
			best_d = d
			best = orb
	return best


func update_particles(dt: float) -> void:
	for p in particles:
		if String(p["kind"]) in ["ring", "bomb_blast", "plant_action", "shovel_lift", "capstone_seal"]:
			p["life"] = float(p["life"]) - dt
			continue
		if String(p["kind"]) != "gust_trail":
			p["vy"] = float(p["vy"]) + (260.0 if String(p["kind"]) == "shard" else 180.0) * dt
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		p["life"] = float(p["life"]) - dt
	for f in floaters:
		f["y"] = float(f["y"]) - 26.0 * dt
		f["life"] = float(f["life"]) - dt


func auto_collect_enabled() -> bool:
	return auto_collect


# ── 训练场 ──────────────────────────────────────────────────────────────────
func summon_training(type: String, count: int, lane: int) -> void:
	if not training:
		return
	var def: Dictionary = Content.ZOMBIES.get(type, Content.ZOMBIES["ghost"])
	for i in count:
		var row = clampi(lane, 0, rows - 1) if lane >= 0 else rng.randi_range(0, rows - 1)
		spawn_zombie(String(def.get("id", type)), row,
			{"x": 1250.0 + i * 48.0 + rng.randf() * 24.0})
	floaters.append({
		"x": Geo.VIEW.x * 0.5, "y": 300.0,
		"text": "召来 %s ×%d" % [String(def["name"]), count],
		"color": Color("#ffd0a0"), "life": 1.6, "max": 1.6, "size": 20,
	})
	sfx("wave")


func clear_plants() -> void:
	if not training:
		return
	for plant in plants.duplicate():
		kill_plant(plant, true)
	plants.clear()
	lilies.clear()
	for r in rows:
		for c in Geo.COLS:
			cells[r][c] = null
	floaters.append({
		"x": Geo.VIEW.x * 0.5, "y": 310.0, "text": "草木已清空",
		"color": Color("#ffe1a1"), "life": 1.6, "max": 1.6, "size": 20,
	})
	sfx("explode")


func kill_all_zombies() -> int:
	var count = 0
	if boss!=null and boss.alive():
		boss.damage_token="";boss.damage(null,boss.max_hp*2)
		return 1
	for z in zombies:
		if z.alive():
			kill_zombie(z)
			count += 1
	return count


# ── 教学关 ──────────────────────────────────────────────────────────────────
func start_tutorial() -> void:
	level = {
		"id": 0, "day": 1, "day_name": "第一天", "day_sub": "夜市街",
		"map": "street", "rows": 5, "water_rows": [], "object_cells": [],
		"name": "新手教程", "tag": "第一课", "threat": 1.0,
		# 300 = 签筒 100 + 升阶 100 + 石磨 50，再留一点余量给手滑的玩家
		"start_sun": 300, "waves": [],
	}
	level_id = 0
	rows = 5
	difficulty = "easy"
	count_mul = 1.0
	hp_mul = 1.0
	training = false
	no_cooldown = false
	tutorial = {
		"step": "collect", "orb": {}, "lantern": null, "shooter": null, "wall": null,
		"zombie": null, "battle_t": 0.0, "done_t": 0.0, "t": 0.0, "row": 2,
	}
	# 教学自带卡组，不看外面的 loadout：第四课要请石磨出来挡一次
	_reset(["shooter", "wall"])
	var lantern = place_free("lantern", 0, 2)
	if lantern != null:
		lantern.tutorial_idle = true
	var orb = {
		"x": (lantern.pos.x if lantern != null else 400.0) + 78.0,
		"y": (lantern.pos.y if lantern != null else 460.0) - 56.0,
		"target_y": (lantern.pos.y if lantern != null else 460.0) - 12.0,
		"landed": false, "life": 999999.0, "value": 25,
		"phase": 0.0, "dead": false, "auto_t": 0.0, "tutorial": true,
	}
	# v0.2.4 在落地时统一把 life 改成 10，教学香火因此会过期；本作教学香火不设时限。
	orbs.append(orb)
	tutorial["orb"] = orb
	tutorial["lantern"] = lantern


func spawn_tutorial_zombie() -> void:
	if tutorial == null:
		return
	var shooter: Plant = tutorial["shooter"]
	var row = shooter.row if shooter != null else 2
	var base_x = shooter.pos.x if shooter != null else Geo.BOARD_X + 300.0
	var x = minf(Geo.BOARD_X + Geo.BOARD_W - 12.0, maxf(1000.0, base_x + 260.0))
	var z = spawn_zombie("ghost", row, {"x": x})
	if z == null:
		return
	z.hp = 120.0
	z.max_hp = 120.0
	z.speed = 14.0
	tutorial["zombie"] = z
	banner = {"text": "恶客上门 · 看签筒出手", "t": 2.2, "max": 2.2}


func update_tutorial(dt: float) -> void:
	tutorial["t"] = float(tutorial["t"]) + dt
	_tutorial_fix()
	if String(tutorial["step"]) == "battle" and float(tutorial["battle_t"]) > 0.0:
		tutorial["battle_t"] = float(tutorial["battle_t"]) - dt
		if float(tutorial["battle_t"]) <= 0.0:
			spawn_tutorial_zombie()
	if String(tutorial["step"]) == "finishing":
		tutorial["done_t"] = float(tutorial["done_t"]) - dt
		if float(tutorial["done_t"]) <= 0.0:
			tutorial["step"] = "almanac"


func finish_tutorial_almanac() -> void:
	if tutorial_step() == "almanac":
		tutorial["step"] = "done"
		if on_win.is_valid():
			on_win.call()


func tutorial_step() -> String:
	return String(tutorial["step"]) if tutorial != null else ""


## 教学容错：目标株没了（被吃、被别的机制弄死）就退回还能继续的那一步，并把香火补够。
## 铲子那一侧已经在 shovel_at 里挡掉了，这里兜住剩下的所有情况。
func _tutorial_fix() -> void:
	var step = String(tutorial["step"])
	var shooter: Plant = tutorial["shooter"]
	var gone = shooter == null or shooter.dead
	if step in ["upgrade", "wall"] and gone:
		tutorial["shooter"] = null
		tutorial["step"] = "plant"
		# 补够"签筒 + 升一级 + 石磨"三样，退回上一步不该反而买不起后面的课
		var need = float(Content.PLANTS["shooter"]["cost"]) \
			+ float(Upgrades.tier_cost("shooter", 1, 1)) \
			+ float(Content.PLANTS["wall"]["cost"])
		sun = maxf(sun, need)
		float_text(Vector2(Geo.BOARD_X + 260.0, 320.0), "再来一次：先种下签筒",
			Color("#ffe1a1"), 18)
	elif step == "battle" and gone:
		# 已经开打了就没有再等的道理：直接在后排补一株免费的签筒
		for col in [2, 1, 3, 4]:
			var fresh = place_free("shooter", col, int(tutorial["row"]))
			if fresh != null:
				tutorial["shooter"] = fresh
				float_text(fresh.pos + Vector2(0, -74), "补一株签筒", Color("#ffe1a1"), 17)
				break


# ── 快照（存档）──────────────────────────────────────────────────────────────
func serialize() -> Dictionary:
	var plant_rows: Array = []
	for plant in plants:
		if plant.dead or plant.is_lily:
			continue
		plant_rows.append({
			"type": plant.type, "c": plant.col, "r": plant.row,
			"hp": plant.hp, "shell": plant.shell,
			"up": plant.upgrades.duplicate(), "timer": plant.timer,
			"armed": plant.armed, "arm_t": plant.arm_t,
			"chew_t": plant.chew_t, "chew_max": plant.chew_max,
			"ash": plant.ash, "echoes": plant.echoes.duplicate(true),
			"save_used": plant.save_used, "wish": plant.wish, "wish_t": plant.wish_t,
			"lion_charge": plant.lion_charge, "cheer": plant.cheer,
			"cheer_t": plant.cheer_t, "danced": plant.danced,
			"wish_guard": plant.wish_guard, "chew_prey": plant.chew_prey,
			"state_v040":pack_unit(plant),
		})
	var lily_rows: Array = []
	for key in lilies:
		var lily: Plant = lilies[key]
		if lily.dead:
			continue
		lily_rows.append({"c": lily.col, "r": lily.row, "hp": lily.hp, "ward_spent": lily.ward_spent, "ward_until": lily.ward_until})
	var zombie_rows: Array = []
	for z in zombies:
		if z.dead or z.boss_role!="":
			continue
		zombie_rows.append({
			"type": z.type, "r": z.row, "x": z.pos.x, "hp": z.hp,
			"max_hp": z.max_hp, "armor": z.armor, "max_armor": z.max_armor,
			"armor_type": z.armor_type, "armor_name": z.armor_name,
			"speed": z.speed, "slow_t": z.slow_t, "slow": z.slow_amount,
			"vuln_t": z.vuln_t, "vuln": z.vuln, "burn_t": z.burn_t,
			"burn_dps": z.burn_dps, "vaulted": z.vaulted,
			"split_done": z.split_done,
			"cc_immune": z.cc_immune, "cc_log": z.cc_log.duplicate(true),
			"mv_log": z.mv_log.duplicate(true), "stun_t": z.stun_t,
			"reverse_t": z.reverse_t, "reverse_icd": z.reverse_icd,
			"bleed_t": z.bleed_t, "bleed_dps": z.bleed_dps,
			"marks": z.marks.duplicate(true), "punish_until": z.punish_until,
			"ignite_until": z.ignite_until, "lock_until": z.lock_until,
			"nail_walk": z.nail_walk, "suppress_t": z.suppress_t,
			"suppress_until": z.suppress_until, "execute_until": z.execute_until,
			"attach_until": z.attach_until, "bomb_t": z.bomb_t, "bomb_damage": z.bomb_damage,
			"state_v040":pack_unit(z),
		})
	var orb_rows: Array = []
	for orb in orbs:
		if bool(orb["dead"]):
			continue
		orb_rows.append({
			"x": orb["x"], "y": orb["y"], "target_y": orb["target_y"],
			"landed": orb["landed"], "life": orb["life"], "value": orb["value"],
		})
	var mower_rows: Array = []
	for mower in mowers:
		mower_rows.append({"ready": mower["ready"]})
	var cooldowns: Dictionary = {}
	for card in cards:
		cooldowns[card["id"]] = card["cd"]
	var shot_rows: Array=[]
	var volleys: Array=[]
	for shot in shots:
		if shot.dead:continue
		if shot.uid=="":shot.uid="s%d" % shot.get_instance_id()
		var item=pack_unit(shot)
		var group=-1
		if not shot.volley.is_empty():
			for i in volleys.size():
				if is_same(volleys[i],shot.volley):group=i;break
			if group<0:group=volleys.size();volleys.append(shot.volley)
		item.volley_group=group;shot_rows.append(item)
	return {
		"level_id": level_id, "rows": rows, "time": time, "sun": sun,
		"wave_index": wave_index, "kills": kills, "plants_lost": plants_lost,
		"difficulty": difficulty, "count_mul": count_mul, "hp_mul": hp_mul,
		"plants": plant_rows, "lilies": lily_rows, "zombies": zombie_rows,
		"orbs": orb_rows, "mowers": mower_rows, "cooldowns": cooldowns,
		"cards": cards.map(func(c): return String(c["id"])),
		"spawn_queue": spawn_queue.duplicate(true),
		"training": training, "no_cooldown": no_cooldown,
		"cheated": cheated,
		"format":4,"level_snapshot":level.duplicate(true),
		"boss":boss.serialize() if boss!=null else {},
		"rng_state":str(rng.state),"rng_seed":str(rng.seed),
		"grounds":_pack_value(grounds),"damage_by_type":damage_by_type.duplicate(true),
		"wave_peak":wave_peak.duplicate(true),"rows_planted":rows_planted.duplicate(true),
		"lane_breaches":lane_breaches.duplicate(),"bell_death_until":bell_death_until,
		"shots_v040":shot_rows,"pending_spawns":_pack_value(pending_spawns),
		"natural_timer":natural_timer,"orbs_v040":_pack_value(orbs),"mowers_v040":_pack_value(mowers),
		"special_bosses_completed":special_bosses_completed,"wave_time_offset":wave_time_offset,
		"special_rest_until":special_rest_until,"boss_history":boss_history.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	var lvl = Content.get_level(int(data.get("level_id", 1)))
	# Existing v0.3 runs keep their saved wave schedule instead of suddenly gaining new waves.
	if data.has("level_snapshot"):lvl=Dictionary(data.level_snapshot)
	elif int(data.get("format",0))<4:
		lvl=lvl.duplicate(true);lvl.waves=Content.build_waves(String(lvl.band),4)
		lvl.wave_groups=4;lvl.boss_id=""
	setup(lvl, data.get("cards", []), String(data.get("difficulty", "easy")))
	time = float(data.get("time", 0.0))
	sun = int(data.get("sun", 100))
	wave_index = int(data.get("wave_index", 0))
	kills = int(data.get("kills", 0))
	plants_lost = int(data.get("plants_lost", 0))
	count_mul = float(data.get("count_mul", count_mul))
	hp_mul = float(data.get("hp_mul", hp_mul))
	training = bool(data.get("training", false))
	no_cooldown = bool(data.get("no_cooldown", false))
	cheated = bool(data.get("cheated", false))
	spawn_queue = data.get("spawn_queue", []).duplicate(true)
	var cooldowns: Dictionary = data.get("cooldowns", {})
	for card in cards:
		card["cd"] = float(cooldowns.get(card["id"], 0.0))
	for row_data in data.get("lilies", []):
		var lily = place_free("lily", int(row_data["c"]), int(row_data["r"]))
		if lily != null:
			lily.hp = float(row_data.get("hp", lily.hp))
			lily.ward_spent = bool(row_data.get("ward_spent", false))
			lily.ward_until = float(row_data.get("ward_until", 0.0))
	for row_data in data.get("plants", []):
		var plant = place_free(String(row_data["type"]), int(row_data["c"]),
			int(row_data["r"]))
		if plant == null:
			continue
		var upgrades: Dictionary = row_data.get("up", {})
		for key in upgrades:
			plant.upgrades[int(key)] = int(upgrades[key])
		# 铜胎抬的是上限，先把上限立起来再回填存档里的当前血量
		apply_hp_scale(plant)
		plant.hp = minf(float(row_data.get("hp", plant.hp)), plant.max_hp)
		plant.shell = float(row_data.get("shell", 0.0))
		plant.shell_max = float(Upgrades.EFFECTS["shell"]["hp"])
		plant.timer = float(row_data.get("timer", 0.0))
		plant.armed = bool(row_data.get("armed", false))
		plant.arm_t = float(row_data.get("arm_t", 0.0))
		plant.chew_t = float(row_data.get("chew_t", 0.0))
		plant.chew_max = float(row_data.get("chew_max", 0.0))
		plant.ash = bool(row_data.get("ash", false))
		plant.save_used = int(row_data.get("save_used", 0))
		plant.lion_charge = float(row_data.get("lion_charge", 0.0))
		plant.cheer = int(row_data.get("cheer", 0))
		plant.cheer_t = float(row_data.get("cheer_t", 0.0))
		plant.danced = bool(row_data.get("danced", false))
		plant.wish = float(row_data.get("wish", 0.0))
		plant.wish_t = float(row_data.get("wish_t", 0.0))
		plant.wish_guard = float(row_data.get("wish_guard", 0.0))
		plant.chew_prey = String(row_data.get("chew_prey", ""))
		plant.echoes = Array(row_data.get("echoes", []))
		if row_data.has("state_v040"):unpack_unit(plant,Dictionary(row_data.state_v040))
		else:
			for path in Upgrades.paths_for(plant.type):
				for i in plant.tier(int(path.id)):plant.paid_incense+=int(path.tiers[i].cost)
	refresh_plant_buffs()
	for row_data in data.get("zombies", []):
		var z = spawn_zombie(String(row_data["type"]), int(row_data["r"]),
			{"x": float(row_data["x"]), "hp_factor": 1.0, "sedan_split": true})
		if z == null:
			continue
		z.hp = float(row_data.get("hp", z.hp))
		z.max_hp = float(row_data.get("max_hp", z.max_hp))
		z.armor = float(row_data.get("armor", z.armor))
		z.max_armor = float(row_data.get("max_armor", z.max_armor))
		z.armor_type = String(row_data.get("armor_type", z.armor_type))
		z.armor_name = String(row_data.get("armor_name", z.armor_name))
		z.speed = float(row_data.get("speed", z.speed))
		z.slow_t = float(row_data.get("slow_t", 0.0))
		z.slow_amount = float(row_data.get("slow", 0.0))
		z.vuln_t = float(row_data.get("vuln_t", 0.0))
		z.vuln = float(row_data.get("vuln", 0.0))
		z.burn_t = float(row_data.get("burn_t", 0.0))
		z.cc_immune = float(row_data.get("cc_immune", 0.0))
		z.cc_log = Array(row_data.get("cc_log", []))
		z.mv_log = Array(row_data.get("mv_log", []))
		z.stun_t = float(row_data.get("stun_t", 0.0))
		z.reverse_t = float(row_data.get("reverse_t", 0.0))
		z.reverse_icd = float(row_data.get("reverse_icd", 0.0))
		z.bleed_t = float(row_data.get("bleed_t", 0.0))
		z.bleed_dps = float(row_data.get("bleed_dps", 0.0))
		z.marks = Dictionary(row_data.get("marks", {}))
		z.punish_until = float(row_data.get("punish_until", 0.0))
		z.ignite_until = float(row_data.get("ignite_until", 0.0))
		z.lock_until = float(row_data.get("lock_until", 0.0))
		z.nail_walk = float(row_data.get("nail_walk", 0.0))
		z.suppress_t = float(row_data.get("suppress_t", 0.0))
		z.suppress_until = float(row_data.get("suppress_until", 0.0))
		z.execute_until = float(row_data.get("execute_until", 0.0))
		z.attach_until = float(row_data.get("attach_until", 0.0))
		z.bomb_t = float(row_data.get("bomb_t", 0.0))
		z.bomb_damage = float(row_data.get("bomb_damage", 0.0))
		z.burn_dps = float(row_data.get("burn_dps", 0.0))
		z.vaulted = bool(row_data.get("vaulted", false))
		z.split_done = bool(row_data.get("split_done", false))
		if row_data.has("state_v040"):unpack_unit(z,Dictionary(row_data.state_v040))
	orbs.clear()
	for row_data in data.get("orbs", []):
		orbs.append({
			"x": row_data["x"], "y": row_data["y"],
			"target_y": row_data["target_y"], "landed": row_data["landed"],
			"life": row_data["life"], "value": row_data["value"],
			"phase": 0.0, "dead": false, "auto_t": 0.0,
		})
	var saved_mowers: Array = data.get("mowers", [])
	for i in mini(saved_mowers.size(), mowers.size()):
		mowers[i]["ready"] = bool(saved_mowers[i]["ready"])
		mowers[i]["active"] = false
		mowers[i]["x"] = Geo.MOWER_X
	grounds=Array(_unpack_value(data.get("grounds",[])))
	damage_by_type=Dictionary(data.get("damage_by_type",{})).duplicate(true)
	wave_peak=Dictionary(data.get("wave_peak",{})).duplicate(true)
	rows_planted={}
	for key in Dictionary(data.get("rows_planted",{})):rows_planted[int(key)]=true
	lane_breaches=Array(data.get("lane_breaches",lane_breaches))
	bell_death_until=float(data.get("bell_death_until",0.0))
	special_bosses_completed=int(data.get("special_bosses_completed",0))
	wave_time_offset=float(data.get("wave_time_offset",0.0));special_rest_until=float(data.get("special_rest_until",0.0))
	boss_history=Array(data.get("boss_history",[])).duplicate(true)
	if not Dictionary(data.get("boss",{})).is_empty():
		boss=preload("res://scripts/boss_encounter.gd").new()
		var queued = spawn_queue.duplicate(true)
		boss.restore(self,Dictionary(data.boss))
		spawn_queue = queued
	# Resolve references only after all normal enemies and boss proxies exist.
	for row_data in data.get("plants",[]):
		var p=main_plant_at(int(row_data.c),int(row_data.r))
		if p!=null and row_data.has("state_v040"):unpack_unit(p,Dictionary(row_data.state_v040))
	shots.clear()
	var volleys: Dictionary={}
	for row in data.get("shots_v040",[]):
		var shot=Shot.new();var item=Dictionary(row).duplicate(true)
		var group=int(item.get("volley_group",-1));item.erase("volley_group")
		unpack_unit(shot,item)
		if group>=0:
			if volleys.has(group):shot.volley=volleys[group]
			else:volleys[group]=shot.volley
		shots.append(shot)
	if data.has("orbs_v040"):orbs=Array(_unpack_value(data.orbs_v040))
	if data.has("mowers_v040"):mowers=Array(_unpack_value(data.mowers_v040))
	natural_timer=float(data.get("natural_timer",natural_timer))
	pending_spawns=Array(_unpack_value(data.get("pending_spawns",[])))
	if data.has("rng_seed"):rng.seed=int(String(data.rng_seed))
	if data.has("rng_state"):rng.state=int(String(data.rng_state))


func pack_unit(unit) -> Dictionary:
	var data: Dictionary={}
	for prop in unit.get_property_list():
		var key=String(prop.name)
		if (int(prop.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0 or key=="def":continue
		var value=unit.get(key)
		if value is Zombie:data[key]=_pack_value(value);continue
		if value is Object or value is Callable:continue
		if value is Vector2:data[key]=[value.x,value.y]
		elif value is Dictionary or value is Array:data[key]=_pack_value(value)
		else:data[key]=value
	return data


func unpack_unit(unit, data: Dictionary) -> void:
	for key in data:
		if String(key)=="def":continue
		var current=unit.get(String(key))
		if current is Vector2:
			unit.set(String(key),Vector2(float(data[key][0]),float(data[key][1])))
		elif String(key)=="upgrades":
			var up: Dictionary={}
			for k in data[key]:up[int(k)]=int(data[key][k])
			unit.set(String(key),up)
		else:unit.set(String(key),_unpack_value(data[key]))


func _pack_value(value):
	if value is Vector2:return {"__xy":[value.x,value.y]}
	if value is Color:return {"__color":value.to_html()}
	if value is Array:
		var out: Array=[]
		for v in value:out.append(_pack_value(v))
		return out
	if value is Dictionary:
		var out: Dictionary={}
		for key in value:
			var k="__enemy_key:"+String(key.uid) if key is Zombie else str(key)
			out[k]=_pack_value(value[key])
		return out
	if value is Zombie:return {"__enemy":value.uid}
	if value is Object:return null
	return value


func _unpack_value(value):
	if value is Array:
		var out: Array=[]
		for v in value:out.append(_unpack_value(v))
		return out
	if value is Dictionary:
		if value.has("__xy"):return Vector2(float(value.__xy[0]),float(value.__xy[1]))
		if value.has("__color"):return Color(String(value.__color))
		if value.has("__enemy"):
			for z in zombies:
				if z.uid==String(value.__enemy):return z
			return null
		var out: Dictionary={}
		for key in value:
			var actual=key
			if String(key).begins_with("__enemy_key:"):
				for z in zombies:
					if z.uid==String(key).trim_prefix("__enemy_key:"):actual=z;break
			out[actual]=_unpack_value(value[key])
		return out
	return value
