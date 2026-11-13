## 战场单位层：草木、恶客、射弹、香火、粒子与飘字。
##
## 用战斗时钟选择草木、恶客与三阶形态的动画帧。
class_name UnitView
extends Node2D
const PlantRegions = preload("res://scripts/plant_regions.gd")

const ActorFrames = preload("res://scripts/actor_frames.gd")
var _actor_frames = ActorFrames.new()
var _effect_frames = ActorFrames.new()
var _buff_frames = ActorFrames.new()
var _new_frames = ActorFrames.new()
var sim: Sim = null
var health_bars = "bar"
var tier_shapes := false
var focus_plant: Sim.Plant = null
var hover_target = null
var shovel_mode = false
var _textures: Dictionary = {}
var _guardian: Texture2D = null
var _time = 0.0
var _cache_clock := 0.0
var _armor_atlas: Dictionary = {}
var _evolve_textures: Dictionary = {}
var _growth_textures: Dictionary = {}
var _guest_gear: Dictionary = {}
var _face_pins: Dictionary = {}
var _profile_armor: Dictionary = {}


func _ready() -> void:
	z_index = 10
	_actor_frames.load_sheets()
	_effect_frames.load_sheets("v05")
	_buff_frames.load_sheets("v053-")
	_new_frames=_effect_frames
	if FileAccess.file_exists("res://data/actor_attachment_pins.json"):
		_face_pins = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_attachment_pins.json"))
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for stage in [1, 2, 3]:
		_growth_textures[stage] = load("res://assets/sprites/mushroom-growth-%d.png" % stage)
	var profile_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/armor_profiles_v052.json"))
	var gear_sheet: Texture2D = load("res://" + String(profile_data.file))
	for key in profile_data.frames:
		var region: Array = profile_data.frames[key]
		var frame := AtlasTexture.new()
		frame.atlas = gear_sheet
		frame.region = Rect2(region[0], region[1], region[2], region[3])
		frame.filter_clip = true
		_profile_armor[key] = frame
	# Import once before drawing. Loading textures inside _draw can produce white rectangles.
	for art in ["straw", "stonehat", "paper", "sedan", "urn", "mask"]:
		var path = "res://assets/sprites/armor-%s-atlas.png" % art
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path)
			var cell_width = sheet.get_width() / 3.0
			for tier in [1, 2, 3]:
				var frame = AtlasTexture.new()
				frame.atlas = sheet
				frame.region = Rect2((tier - 1) * cell_width, 0, cell_width, sheet.get_height())
				_armor_atlas["%s-%d" % [art, tier]] = frame
	var gear_path := "res://assets/sprites/guest-gear-v042.png"
	if ResourceLoader.exists(gear_path):
		var sheet: Texture2D = load(gear_path)
		var size = sheet.get_size() / Vector2(2, 1)
		for i in 2:
			var gear := AtlasTexture.new()
			gear.atlas = sheet
			gear.region = Rect2(Vector2(i * size.x, 0), size)
			gear.filter_clip = true
			_guest_gear[["shield", "raft"][i]] = gear
	for id in ["sedan", "paper"]:
		var revealed = "res://assets/sprites/%s-unarmored%s.png" % [id,
			"-v2" if id == "paper" else ""]
		if ResourceLoader.exists(revealed):
			_textures[id] = load(revealed)
	if not OS.has_feature("android") and not "--mobile" in OS.get_cmdline_user_args():
		# 三阶换建模：进化到顶的那条路决定这株草木的最终形态（<id>-e<路径>.png）。
		for type in Content.PLANTS:
			for path_id in [1, 2, 3]:
				var evolve_path = "res://assets/sprites/%s-e%d.png" % [type, path_id]
				if ResourceLoader.exists(evolve_path):
					_evolve_textures["%s-e%d" % [type, path_id]] = load(evolve_path)
		# v0.4 hand-painted capstones: use measured regions, never divide generated art blindly.
		if FileAccess.file_exists("res://data/evolution_art_v040.json"):
			var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/evolution_art_v040.json"))
			for type in catalog:
				var info: Dictionary=catalog[type]
				var sheet: Texture2D=load("res://"+String(info.file))
				for f in info.frames:
					var r: Array=f.region
					var atlas=AtlasTexture.new()
					atlas.atlas=sheet
					atlas.region=Rect2(r[0],r[1],r[2],r[3])
					atlas.filter_clip=true
					_evolve_textures["%s-e%d" % [type,int(f.path)]]=atlas



func _process(delta: float) -> void:
	if sim != null and sim.visual_hold:
		return
	_time += delta
	_cache_clock+=delta
	if _cache_clock>=3.0:
		_cache_clock=0.0
		_actor_frames.release_unused()
		_effect_frames.release_unused()
		_buff_frames.release_unused()
	_update_armor_falls(delta)
	queue_redraw()


func texture_for(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var texture = Ui.sprite(name)
	_textures[name] = texture
	return texture


## 三阶换建模：点到顶的那条路给出毕业立绘，还没做新模时退回原画。
func plant_texture(plant: Sim.Plant) -> Texture2D:
	var path_id = Upgrades.capstone(plant.upgrades)
	if path_id > 0:
		var evolve: Texture2D = _evolve_textures.get("%s-e%d" % [plant.type, path_id])
		if evolve != null:
			return evolve
	return texture_for(plant.type)


## 毕业路的光色直接取数据表里那条路的颜色，不另开一张表。
func capstone_color(plant: Sim.Plant) -> Color:
	var path_id = Upgrades.capstone(plant.upgrades)
	if path_id == 0:
		return Color(0, 0, 0, 0)
	for path in Upgrades.paths_for(String(plant.type)):
		if int(path["id"]) == path_id:
			return Color(String(path["color"]))
	return Color(0, 0, 0, 0)


## 毕业脚下的阵：一条路的颜色 + 缓转的三道弧，隔着一屏也认得出这株修的是哪条道。
func _draw_capstone_ring(foot: Vector2, height: float, color: Color) -> void:
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.34))
	var spin = _time * 0.5
	for i in 3:
		var r = height * (0.30 + float(i) * 0.07)
		draw_arc(Vector2.ZERO, r, spin + float(i) * 1.2, spin + float(i) * 1.2 + 2.1,
			18, Color(color.r, color.g, color.b, 0.34 - float(i) * 0.07), 1.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 每种草木的待机节奏（幅度, 频率），差异来自这里而不是贴图。
const PLANT_IDLE = {
	"lantern": Vector2(2.6, 1.5), "shooter": Vector2(1.4, 1.8), "wall": Vector2(0.9, 0.9),
	"bomb": Vector2(3.4, 2.2), "bell": Vector2(2.2, 1.2), "censer": Vector2(1.8, 1.1),
	"umbrella": Vector2(1.6, 0.9), "lion": Vector2(2.8, 1.6), "mushroom": Vector2(1.2, 0.8),
	"cat": Vector2(3.0, 1.4), "shell": Vector2(1.0, 1.0), "lobber": Vector2(2.4, 1.7),
	"torch": Vector2(3.2, 2.6), "star": Vector2(2.0, 1.3), "needle": Vector2(1.0, 1.6),
	"judge": Vector2(1.2, 0.8), "lily": Vector2(1.4, 0.7), "kelp": Vector2(3.0, 1.2),
}

const PLANT_GLOW = {
	"lantern": Color(1.0, 0.55, 0.3), "torch": Color(1.0, 0.5, 0.2),
	"star": Color(1.0, 0.82, 0.4), "cat": Color(1.0, 0.68, 0.38),
	"judge": Color(0.92, 0.42, 0.3), "censer": Color(0.85, 0.72, 0.55),
	"bell": Color(0.6, 0.85, 0.9), "lily": Color(0.45, 0.8, 0.75),
	"mushroom": Color(0.7, 0.85, 0.5), "kelp": Color(0.4, 0.7, 0.6),
}

const ZOMBIE_GLOW = {
	"ghost": Color(0.55, 0.75, 0.7), "tongue": Color(0.6, 0.8, 0.55),
	"mourner": Color(0.6, 0.82, 0.9), "paper": Color(0.9, 0.85, 0.72),
	"artisan": Color(0.92, 0.86, 0.7), "mountain": Color(0.7, 0.5, 0.4),
	"ironjudge": Color(0.55, 0.6, 0.65), "sedan": Color(0.85, 0.4, 0.3),
}

const ARMOR_COLORS = {
	"paper": Color("#efe6cf"), "sedan": Color("#c77a55"), "straw": Color("#d7b26a"),
	"stonehat": Color("#a8a69a"), "urn": Color("#b07a4e"), "mask": Color("#7d858a"),
	"charm": Color("#e5d4a2"),
}


func _draw() -> void:
	if sim == null:
		return
	var cell_h = Geo.cell_h(sim.rows)
	_draw_shadows(cell_h)
	for plant in sim.plants:
		_draw_plant(plant, cell_h)
	var ordered = sim.zombies.duplicate()
	ordered.sort_custom(_zombie_sort)
	for z in ordered:
		if z.boss_role=="" and z.carrier_uid.is_empty():_draw_zombie(z, cell_h)
	_draw_armor_falls()
	_draw_shots()
	_draw_orbs()
	_draw_particles()
	_draw_floaters()
	# Interaction markers are painted after every actor, matching their highest hit priority.
	for plant in sim.plants:
		if not plant.dead:
			_draw_upgrade_dot(plant, _plant_foot(plant, cell_h), PlantRegions.height(plant, sim.rows))
			_draw_active_skill(plant)


static func _zombie_sort(a, b) -> bool:
	if a.row != b.row:
		return a.row < b.row
	return a.pos.x < b.pos.x


func _draw_shadows(cell_h: float) -> void:
	for plant in sim.plants:
		if plant.dead:
			continue
		var foot = _plant_foot(plant, cell_h)
		var width = 30.0 if not plant.is_lily else 40.0
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, width, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for z in sim.zombies:
		if z.dead or z.boss_role!="":
			continue
		var height = _zombie_height(z, cell_h)
		draw_set_transform(_zombie_foot(z, cell_h), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 18.0 + height * 0.16, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 平面坐标 → 屏幕坐标：单位站在台面上，位置与大小都随深度变。
func _plant_foot(plant: Sim.Plant, cell_h: float) -> Vector2:
	return Geo.to_screen(plant.pos + Vector2(0.0, cell_h * 0.3), sim.rows)


func _zombie_foot(z: Sim.Zombie, cell_h: float) -> Vector2:
	return Geo.to_screen(z.pos + Vector2(0.0, cell_h * 0.26), sim.rows)


func _zombie_height(z: Sim.Zombie, cell_h: float) -> float:
	var base = float(z.def.get("sprite_h", 104))
	return base * Geo.unit_scale(sim.rows) * Geo.scale_at_flat(z.pos, sim.rows)


# ── 草木 ────────────────────────────────────────────────────────────────────
func _draw_plant(plant: Sim.Plant, cell_h: float) -> void:
	if plant.dead:
		return
	var texture = plant_texture(plant)
	var foot = _plant_foot(plant, cell_h)
	var height = float(plant.def.get("sprite_h", 92)) * Geo.unit_scale(sim.rows) \
		* Geo.scale_at_flat(plant.pos, sim.rows)
	if plant.type=="year-banyan":
		var phase_growth:=clampf((sim.time-plant.growth_at)/.8,0,1)
		height*=1.0+.035*(maxi(0,plant.growth_steps-1)+(phase_growth if plant.growth_steps>0 else 0.0))
	var idle: Vector2 = PLANT_IDLE.get(plant.type, Vector2(1.6, 1.4))
	var phase = plant.phase
	var bob = sin(_time * idle.y + phase) * idle.x
	var sway = sin(_time * idle.y * 0.7 + phase) * 0.012
	if plant.type == "torch" or plant.type == "bomb":
		bob += sin(_time * 8.0 + phase) * 1.2
	var growth = 1.0
	if plant.type == "mushroom":
		growth = clampf(plant.arm_t / float(plant.def["mine"]["arm"]), 0.0, 1.0)
		if plant.armed:
			growth = 1.0
		height *= lerpf(0.88, 1.0, growth)
		bob -= 2.0 * sin(growth * PI)
	if plant.bite_t > 0.0:
		bob += sin(_time * 40.0) * plant.bite_t * 6.0
	var squash = Vector2.ONE
	var recoil = -plant.recoil * 6.0
	# 出手：整株往回收一下，再弹回来（蓄力时反过来鼓一下）
	if plant.pulse > 0.01:
		recoil -= plant.pulse * 5.0
		squash = Vector2(1.0 + plant.pulse * 0.06, 1.0 - plant.pulse * 0.05)
	if plant.charge > 0.01:
		squash = Vector2(1.0 - plant.charge * 0.05, 1.0 + plant.charge * 0.07)
	# 特殊一击（例如签筒的双倍签）：一圈金色冲击 + 短暂透亮
	var special = plant.recoil > 0.55 or plant.pulse > 0.85
	if special:
		var k = clampf(maxf(plant.recoil, plant.pulse), 0.0, 1.0)
		_draw_burst(foot + Vector2(0, -height * 0.55), height * (0.5 + k * 0.5), k)
	# 残血：打蔫、偏暗、身上开裂
	var hp_ratio = clampf(plant.hp / maxf(1.0, plant.max_hp), 0.0, 1.0)
	var tint = Color(1, 1, 1, 1)
	if hp_ratio < 0.4:
		var k = 1.0 - hp_ratio / 0.4
		sway += k * 0.06
		bob += k * 3.0
		tint = Color(1.0 - k * 0.18, 1.0 - k * 0.22, 1.0 - k * 0.24, 1)
	var chosen = plant == focus_plant
	if chosen:
		_draw_halo(foot, height, Color(Ui.GOLD_BRIGHT.r, Ui.GOLD_BRIGHT.g,
			Ui.GOLD_BRIGHT.b, 0.28), 1.0)
	var glow: Color = PLANT_GLOW.get(plant.type, Color(0, 0, 0, 0))
	var cap: Color = capstone_color(plant)
	if cap.a > 0.0:
		glow = cap if glow.a <= 0.0 else glow.lerp(cap, 0.7)
	if glow.a > 0.0:
		var strength = 0.18 + plant.pulse * 0.5
		if cap.a > 0.0:
			strength += 0.10
		if plant.type == "lantern" or plant.type == "torch" or plant.type == "star":
			strength += 0.08 + sin(_time * 2.2 + phase) * 0.04
		_draw_glow(foot + Vector2(0, -height * 0.55), height * 0.85,
			Color(glow.r, glow.g, glow.b, strength))
	if cap.a > 0.0:
		_draw_capstone_ring(foot, height, cap)
	if sim.time < plant.ward_until:
		var center = foot - Vector2(0, height * 0.47)
		var pulse = 0.55 + sin(_time * 7.0) * 0.13
		_draw_glow(center, height * 0.74, Color(1.0, 0.77, 0.40, 0.30))
		draw_arc(center, height * 0.53, 0.0, TAU, 32, Color(1.0, 0.85, 0.57, pulse), 2.0, true)
	if plant.type == "lion" and plant.lion_wave_t > 0.0:
		var travel = 1.0 - plant.lion_wave_t / 0.34
		var start = foot + Vector2(height * 0.3, -height * 0.48)
		var far = Geo.to_screen(Vector2(plant.lion_wave_end,
			plant.pos.y + cell_h * 0.3), sim.rows) + Vector2(0, -height * 0.48)
		var front = start.lerp(far, clampf(travel, 0.0, 1.0))
		var fade = 1.0 - travel
		draw_line(start, front, Color(0.98, 0.75, 0.32, fade * 0.34), 15.0 * fade + 2.0)
		draw_line(start, front, Color(1.0, 0.9, 0.6, fade * 0.82), 3.0)
		draw_arc(front, 13.0 + 12.0 * travel, -PI * 0.55, PI * 0.55,
			16, Color(1.0, 0.75, 0.35, fade * 0.8), 3.0)
		for trail in 3:
			var streak = start.lerp(front, clampf(travel - trail * 0.08, 0.0, 1.0))
			draw_line(streak + Vector2(-8, -8 + trail * 8), streak + Vector2(15, -15 + trail * 8),
				Color(1.0, 0.82, 0.47, fade * 0.5), 2.0)
	if plant.type == "squash" and plant.squash_at >= 0.0:
		var age = sim.time - plant.squash_at
		var progress = clampf((age - Sim.SQUASH_WINDUP) / Sim.SQUASH_LEAP, 0.0, 1.0)
		var target_foot = Geo.to_screen(plant.squash_aim + Vector2(0, cell_h * 0.3), sim.rows)
		var leap = foot.lerp(target_foot, progress) - Vector2(0, sin(progress * PI) * height * 0.84)
		var frame = clampf(age * 5.9, 0.0, 3.99)
		if _actor_frames.draw_pose(self, "squash", "action", frame, leap, height,
				target_foot.x < foot.x, tint):
			return
	_draw_shell(plant, foot, height, false)
	var drawn = false
	if plant.type != "mushroom" or plant.armed:
		var actor = String(plant.type)
		var capstone = Upgrades.capstone(plant.upgrades)
		var evolved_actor = "%s-e%d" % [actor, capstone]
		if capstone > 0 and (_evolve_textures.has(evolved_actor) or _actor_frames.motion.has(evolved_actor)):
			actor = evolved_actor
		var age = sim.time - plant.action_at
		var action = age < 0.42
		var frame = clampf(age * 9.5, 0.0, 3.99) if action else sim.time * 5.0 + phase
		if not action and plant.type == "bomb" and plant.timer > 0.6:
			action = true
			frame = minf(1.99, (plant.timer - 0.6) * 3.3)
		if not action and plant.type == "gust" and plant.timer > 0.25:
			action = true
			frame = minf(1.99, (plant.timer - 0.25) * 5.7)
		if not action and plant.bite_t > 0.0 and plant.type in ["wall", "lily"]:
			action = true
			frame = sim.time * 9.0
		if plant.type == "dragon":
			drawn = _draw_dragon(plant, foot, height, tint)
		elif plant.type == "ember-cicada":
			var pose := ember_pose(plant)
			drawn = _actor_frames.draw_pose(self, actor, pose.clip, pose.frame, foot, height, false, tint)
		else:
			drawn = _actor_frames.draw_pose(self, actor, "action" if action else "idle",
				frame, foot, height, false, tint)
	if not drawn and plant.type == "mushroom":
		var first = 1 if growth < 0.5 else 2
		var blend = clampf(growth * 2.0 - float(first - 1), 0.0, 1.0)
		var young: Texture2D = _growth_textures[first]
		var adult: Texture2D = _growth_textures[first + 1]
		if blend < 0.999:
			_sprite(young, foot + Vector2(recoil, bob), height, false,
				Color(tint.r, tint.g, tint.b, tint.a * (1.0 - blend)), sway, squash)
		if blend > 0.001:
			_sprite(adult, foot + Vector2(recoil, bob), height, false,
				Color(tint.r, tint.g, tint.b, tint.a * blend), sway, squash)
	elif not drawn and texture != null:
		_sprite(texture, foot + Vector2(recoil, bob), height, false, tint, sway, squash)
	if hp_ratio < 0.4:
		_draw_wounds(foot + Vector2(recoil, bob), height, 1.0 - hp_ratio / 0.4)
	_draw_source_buffs(plant, foot, height)
	_draw_shell(plant, foot, height)
	_draw_upgrade_pips(plant, foot, height)
	if plant.sleep_until > sim.time:
		_draw_sleep(foot, height)
	if health_bars != "off":
		_draw_plant_health_bar(plant, foot, height)


func ember_pose(plant: Sim.Plant) -> Dictionary:
	var action_age := float(sim.time - plant.action_at)
	var transition := Sim.EMBER_TRANSITION
	if plant.ember_ready_at >= 0.0:
		var elapsed := float(sim.time - plant.ember_reload_at)
		var left := float(plant.ember_ready_at - sim.time)
		if elapsed < 0.10:
			return {"clip": "action", "frame": clampf(elapsed * 32.0, 0.0, 3.99)}
		if elapsed < 0.10 + transition:
			return {"clip": "reload_enter", "frame": clampf((elapsed - 0.10) * 4.0 / transition, 0.0, 3.99)}
		if left <= transition:
			return {"clip": "reload_exit", "frame": clampf((transition - left) * 4.0 / transition, 0.0, 3.99)}
		return {"clip": "reload", "frame": elapsed * 2.8}
	var early_exit := float(sim.time - plant.ember_reloaded_at)
	if early_exit < transition:
		return {"clip": "reload_exit", "frame": clampf(early_exit * 4.0 / transition, 0.0, 3.99)}
	if action_age < 0.42:
		return {"clip": "action", "frame": clampf(action_age * 9.5, 0.0, 3.99)}
	return {"clip": "idle", "frame": sim.time * 5.0 + plant.phase}


func _draw_dragon(plant: Sim.Plant, foot: Vector2, height: float, tint: Color) -> bool:
	var clip := "idle"
	var frame = sim.time * 4.5 + plant.phase
	var asleep = plant.sleep_until > sim.time
	var near_age = sim.time - plant.dragon_near_at
	var far_age = sim.time - plant.dragon_far_at
	if sim.time < plant.dragon_switch_until and not asleep:
		clip = "switch"
		var progress = clampf((sim.time - plant.dragon_switch_at) / Sim.DRAGON_SWITCH_TIME, 0.0, 1.0)
		frame = (progress if plant.dragon_mode != "near" else 1.0 - progress) * 3.0
	elif plant.dragon_mode == "dual" and minf(near_age, far_age) < 0.26 and not asleep:
		clip = "dual"
		frame = minf(3.99, minf(near_age, far_age) * 13.0)
	elif plant.dragon_mode != "near":
		clip = "far_idle"
		if far_age < 0.3 and not asleep:
			clip = "far"
			frame = minf(3.99, far_age * 13.0)
	elif near_age < 0.24 and not asleep:
		clip = "action"
		frame = minf(3.99, near_age * 15.0)
	var drawn = _actor_frames.draw_pose(self, "dragon", clip, frame, foot, height, false, tint)
	if near_age < 0.21 and not asleep:
		var fx: Dictionary = Upgrades.EFFECTS["dragon"]
		var reach = float(fx["near_range"][plant.tier(1)]) * Geo.CELL_W
		var tip = Geo.to_screen(plant.pos + Vector2(reach, 0), sim.rows)
		var mouth = foot + Vector2(height * 0.42, -height * (0.38 if plant.dragon_mode == "dual" else 0.53))
		var travel = clampf(near_age / 0.21, 0.0, 1.0)
		var end = Vector2(tip.x, mouth.y + 8.0)
		var front = mouth.lerp(end, minf(1.0, 0.32 + travel * 1.1))
		for index in 5:
			var pos := mouth.lerp(front, (index + 0.5) / 5.0)
			_effect_frames.draw_pose(self, "v052-projectiles", "beam", travel * 3.99 + index * 0.1,
				pos + Vector2(0, 16), 33.0, false, Color(1, 1, 1, 0.7 * (1.0 - travel)))
		for i in 3:
			var offset = Vector2(0, (i - 1) * 6.0)
			draw_line(mouth + offset, front + offset * 2.0,
				Color(0.50, 0.83, 0.70, (0.35 - i * 0.07) * (1.0 - travel)), 6.0 - i, true)
	return drawn


const BUFF_CLIPS := {"红灯笼":"lantern","汤圆仔":"lobber","钟馗像":"judge","回春葫":"herb","清账匣":"till","喝彩":"cheer","铜铃":"bell"}

func _draw_source_buffs(plant: Sim.Plant, foot: Vector2, height: float) -> void:
	var clips: Array = []
	if sim.plant_bonus_sources.get(plant.uid,{}).has("喝彩"):
		for beat in 3:
			var a:float=sim.time*2.6+beat*TAU/3
			var p:Vector2=foot+Vector2(cos(a)*height*.38,-height*.5+sin(a)*8)
			draw_circle(p,5,Color("#bb4d37"));draw_arc(p,5,0,TAU,16,Color("#f2c77b"),1.3,true)
			draw_line(p+Vector2(-4,-8),p+Vector2(3,7),Color(1,.83,.5,.7),1.5,true)
	if plant.type=="judge" and plant.skill_effect_until>sim.time:
		var badge:=preload("res://ui/skill_art.gd").texture("res://assets/ui/skills/judge-sanctuary.svg")
		var sz:=height*1.5
		draw_texture_rect(badge,Rect2(foot+Vector2(-sz*.5,-height-sz*.45),Vector2(sz,sz)),false,Color(1,1,1,.22))
		for i in 8:
			var a:float=sim.time*.7+i*TAU/8
			var p:Vector2=foot+Vector2(cos(a)*height*.65,sin(a)*height*.22-height*.3)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(4,0),p+Vector2(0,7),p+Vector2(-4,0)]),Color(.55,1,.81,.6))
	if sim.plant_bonus_sources.get(plant.uid,{}).has("岁灯榕") or plant.production_reduction>0:
		for leaf in 3:
			var a: float=sim.time*.6+leaf*TAU/3
			var at: Vector2=foot+Vector2(cos(a)*height*.35,-height*.32+sin(a)*6)
			_new_frames.draw_pose(self,"v055-projectiles","seed",sim.time*1.8+leaf,at,9,false,Color(.7,.95,.6,.38))
	for source in sim.plant_bonus_sources.get(plant.uid,{}):
		if BUFF_CLIPS.has(source): clips.append(BUFF_CLIPS[source])
	if plant.production_bonus > 0.0: clips.append("torch")
	if plant.type=="lobber" and plant.lob_heat_stacks>0 and sim.time<plant.lob_heat_until and not "lobber" in clips: clips.append("lobber")
	if plant.type=="lion" and plant.dance_t>0 and not "cheer" in clips: clips.append("cheer")
	for i in clips.size():
		var alpha := 0.44 if clips.size()<3 else 0.3
		_buff_frames.draw_pose(self,"v053-buff-fx",clips[i],sim.time*2.3+plant.phase+i*0.8,
			foot+Vector2(0,-height*0.34),height*1.02,false,Color(1,1,1,alpha))



func _draw_sleep(foot: Vector2, height: float) -> void:
	_effect_frames.draw_pose(self, "v052-plant-fx", "sleep", sim.time * 2.8,
		foot + Vector2(0, -height * 0.3), height * 0.86, false, Color(1, 1, 1, 0.82))
	var center = foot - Vector2(0, height * 0.58)
	_draw_glow(center, height * 0.62, Color(0.62, 0.49, 0.82, 0.20))
	for i in 3:
		var phase = fposmod(sim.time * 1.55 + i / 3.0, 1.0)
		var pos = center + Vector2(17.0 + 27.0 * phase, -8.0 - 54.0 * phase)
		var alpha = 0.9 * sin(phase * PI)
		draw_arc(pos, 5.0 + phase * 4.0, 0.4, 4.9, 18,
			Color(0.79, 0.68, 0.96, alpha), 1.8, true)
		draw_circle(pos + Vector2(6, -5), 1.3, Color(1, 0.89, 0.65, alpha))


## 特殊一击的冲击：三圈扩散的金环 + 四散的碎光
func _draw_burst(center: Vector2, radius: float, strength: float) -> void:
	for i in 3:
		var k = clampf(strength - float(i) * 0.22, 0.0, 1.0)
		if k <= 0.0:
			continue
		draw_arc(center, radius * (0.55 + float(i) * 0.3) * (0.7 + k * 0.5),
			0.0, TAU, 26, Color(1.0, 0.86, 0.5, 0.30 * k), 2.2)
	for i in 6:
		var a = float(i) / 6.0 * TAU + _time * 2.2
		var d = radius * (0.6 + strength * 0.7)
		var p = center + Vector2(cos(a), sin(a) * 0.7) * d
		draw_circle(p, 2.2 + strength * 1.6, Color(1.0, 0.9, 0.6, 0.5 * strength))


## 能升阶又付得起的时候，头上点一颗呼吸的红点（v0.2.4 的做法）
func _draw_upgrade_dot(plant: Sim.Plant, foot: Vector2, height: float) -> void:
	if sim == null or plant.dead:
		return
	var economy = sim.sun
	var any = false
	for path in Upgrades.paths_for(String(plant.type)):
		var status = Upgrades.path_status(String(plant.type), plant.upgrades,
			int(path["id"]))
		if bool(status["ok"]) and economy >= int(status["cost"]):
			any = true
			break
	var beat = 0.5 + 0.5 * sin(_time * 3.6 + plant.phase)
	if Upgrades.paths_for(plant.type).is_empty(): return
	var at = PlantRegions.upgrade_rect(plant, sim.rows).get_center()
	var ink := Ui.GOLD_BRIGHT if any else Ui.TEXT_DIM
	draw_circle(at, 10, Color("#182d2c"))
	draw_arc(at, 10, 0, TAU, 24, Color(ink, .95), 1.3, true)
	if any: draw_circle(at, 12 + beat * 2, Color(Ui.VERMILION, .14 + beat * .12))
	draw_polyline(PackedVector2Array([at + Vector2(-4, 2), at + Vector2(0, -3), at + Vector2(4, 2)]), ink, 2, true)

func _draw_active_skill(plant: Sim.Plant) -> void:
	var status:=sim.active_skill_status(plant)
	if not status.exists:return
	var rect:=PlantRegions.skill_rect(plant,sim.rows)
	preload("res://ui/skill_art.gd").draw(self,rect,status,_time)
	if rect.grow(5).has_point(get_local_mouse_position()):
		var caption:String=String(status.name)+(" · "+String(status.summary) if status.ready else " · "+String(status.reason))
		var width:float=minf(620,Ui.body_font().get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+20)
		var box:=Rect2(rect.get_center()+Vector2(-width/2,-58),Vector2(width,30))
		box.position.x=clampf(box.position.x,20,Ui.canvas_size.x-width-20)
		draw_style_box(MarketArt.surface("paper","normal",Vector2.ZERO),box)
		draw_string(Ui.body_font(),box.position+Vector2(10,21),caption,HORIZONTAL_ALIGNMENT_LEFT,width-20,15,Color("#3e3023"))


func _draw_halo(foot: Vector2, height: float, color: Color, scale: float) -> void:
	draw_set_transform(foot + Vector2(0, -height * 0.45), 0.0,
		Vector2(1.0, height / 120.0))
	for i in 3:
		draw_arc(Vector2.ZERO, 34.0 + i * 9.0, 0.0, TAU, 40, color, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for i in 4:
		var t = float(i) / 4.0
		draw_circle(center, radius * (1.0 - t * 0.62),
			Color(color.r, color.g, color.b, color.a * (0.14 + t * 0.12)))


func _draw_shell(plant: Sim.Plant, _foot: Vector2, _height: float, front: bool = true) -> void:
	if plant.shell <= 0: return
	var texture := Ui.sprite("shell")
	if texture == null: return
	var rect := PlantRegions.shell_rect(plant, sim.rows)
	var ratio := clampf(plant.shell / maxf(1, plant.shell_max), 0, 1)
	var shade := .70 + .30 * ratio
	var tint := Color(shade, shade, shade, 1)
	if not front:
		draw_texture_rect(texture, rect, false, tint)
		return
	var uv := PlantRegions.shell_front_uv()
	var points := PackedVector2Array()
	for point in uv: points.append(rect.position + point * rect.size)
	draw_polygon(points, PackedColorArray([tint]), uv, texture)
	if plant.shell_pulse > 0:
		draw_arc(rect.get_center(), rect.size.x * .45, 0, PI, 24, Color(Ui.GOLD_BRIGHT, plant.shell_pulse * .5), 1.5, true)


func _draw_upgrade_pips(plant: Sim.Plant, foot: Vector2, height: float) -> void:
	var paths = Upgrades.paths_for(plant.type)
	if paths.is_empty():
		return
	var total = 0
	for path in paths:
		total += plant.tier(int(path["id"]))
	if total <= 0:
		return
	var x = foot.x - (paths.size() - 1) * 5.0
	for path in paths:
		var tier = plant.tier(int(path["id"]))
		var color = Color(String(path["color"]))
		for i in 3:
			var pos = Vector2(x + (int(path["id"]) - 1) * 6.0,
				foot.y + 7.0 - i * 6.0)
			if i < tier:
				draw_circle(pos, 2.4, color)
			else:
				draw_arc(pos, 2.4, 0, TAU, 10, Color(color.r, color.g, color.b, 0.28), 1.0)
	if total > 0:
		pass


# ── 恶客 ────────────────────────────────────────────────────────────────────
func _draw_zombie(z: Sim.Zombie, cell_h: float) -> void:
	if z.type=="oar-barge" and z.dying:return
	if z.dead:
		return
	if z.type == "sky-ferry" and (sim._guest_airborne(z) or (z.flight_landing_at >= 0 and sim.time - z.flight_landing_at < .7)) and not z.dying:
		_draw_ferry(z, cell_h)
		return
	var texture = texture_for(z.type)
	var foot = _zombie_foot(z, cell_h)
	var height = _zombie_height(z, cell_h)
	if z.revive_at >= 0.0:
		var phase = clampf(1.0 - (z.revive_at - sim.time), 0.0, 1.0)
		_actor_frames.draw_pose(self, "returner", "revive", minf(3.99, phase * 4.0),
			foot, height, true, Color(1, 1, 1, 0.76 + phase * 0.24))
		_draw_glow(foot - Vector2(0, height * 0.55), 25.0 * phase, Color(1, 0.63, 0.22, phase * 0.22))
		return
	var lift = 0.0
	var rotation = 0.0
	var alpha = 1.0
	var squash = Vector2.ONE
	# 步态：一个周期两步，落地时压缩、抬脚时拉长，配合前后摇摆与前倾
	var step = z.anim * 7.4 + z.phase
	var sway = 0.0
	var bob = 0.0
	var lean = 0.0
	var rock = 0.0
	var hp_ratio = clampf(z.hp / maxf(1.0, z.max_hp), 0.0, 1.0)
	if z.eating:
		# 啃食：一小口一小口地点头
		var bite = sin(_time * 11.0 + z.phase)
		lean = 0.10 + bite * 0.03
		rotation = 0.05 + bite * 0.02
		squash = Vector2(1.03, 0.97)
	elif z.stun_t <= 0.0 and z.vault_arc <= 0.0:
		var prev = sin(step - 0.35)
		var cur = sin(step)
		bob = -absf(cur) * 4.4
		sway = sin(step * 0.5) * 1.6
		lean = 0.035 + absf(cos(step)) * 0.02
		rock = sin(step * 0.5) * 0.028
		# 触地瞬间压一下（prev 与 cur 变号即落地）
		if prev * cur < 0.0 and absf(cur) < 0.28:
			squash = Vector2(1.05, 0.95)
		else:
			squash = Vector2(1.0 - absf(cur) * 0.02, 1.0 + absf(cur) * 0.03)
		# 脚底的尘土：落地那一下
		if prev * cur < 0.0 and absf(cur) < 0.2:
			var puff = (1.0 - absf(cur) / 0.2) * 0.5
			_puff(foot + Vector2(-6.0, 0.0), 4.0 + puff * 4.0, puff)
	if z.stun_t > 0.0:
		rotation = sin(_time * 2.0 + z.phase) * 0.07
		lean = 0.0
	if z.vault_arc > 0.0:
		lift = -z.vault_arc * 58.0
		rotation = z.vault_arc * 0.2
	if z.object_hop > 0.0:
		lift -= z.object_hop * 16.0
	if z.water_entry_t > 0.0:
		var plunge = 1.0 - z.water_entry_t / 0.68
		bob += sin(plunge * PI) * height * 0.16
		squash = Vector2(1.0 + sin(plunge * PI) * 0.09,
			1.0 - sin(plunge * PI) * 0.13)
	if z.dying:
		var k = clampf(z.death_t / maxf(0.01, z.death_dur), 0.0, 1.0)
		alpha = 1.0 - k * k
		rotation += k * (0.55 if bool(z.def.get("large", false)) else 0.9)
		lift += k * 14.0
		squash = Vector2(1.0 + k * 0.12, 1.0 - k * 0.18)
	# 受伤闪白；减速偏青、冻结偏蓝白
	var tint = Color(1, 1, 1, alpha)
	if z.hurt > 0.0:
		tint = Color(1.7, 1.5, 1.4, alpha)
	elif z.slow_t > 0.0 and z.slow_amount >= 0.5:
		# 冻得厉害：整只偏蓝白，像结了霜
		tint = Color(0.70, 0.88, 1.14, alpha)
	elif z.slow_t > 0.0:
		tint = Color(0.84, 0.96, 1.06, alpha)
	var glow: Color = ZOMBIE_GLOW.get(z.type, Color(0, 0, 0, 0))
	if glow.a > 0.0 and not z.dying:
		_draw_glow(foot + Vector2(0, -height * 0.5), height * 0.6,
			Color(glow.r, glow.g, glow.b, 0.12))
	var swimming = z.water_entered and z.pos.x <= Geo.BOARD_X + Geo.BOARD_W \
		and not (z.type == "reedboat" and z.armor > 0.0)
	var clip = "swim_bite" if z.eating else "swim"
	if not swimming:
		clip = "attack" if z.eating else "walk"
	var frame = z.chomp * 10.0 if z.eating else z.anim * (7.0 if swimming else 6.5)
	if (z.def.has("special_period") or z.def.has("reed_shot")) and sim.time - z.guest_action_at < 0.42:
		clip = "swim_bite" if swimming else "attack"
		frame = clampf((sim.time - z.guest_action_at) * 9.0, 0.0, 3.99)
	var actor = String(z.type)
	if z.type == "incense-thief":
		if z.dying:
			clip = "death"; frame = clampf(z.death_t / z.death_dur * 3.8, 0, 3.8)
		elif sim.time - z.guest_action_at < .85:
			clip = "steal"; frame = clampf((sim.time - z.guest_action_at) / .85 * 3.99, 0, 3.99)
	if z.type == "sky-ferry": actor = "ghost"
	if z.type == "phaseguard":
		actor = "phase-kite" if z.phase_form == 1 else "phase-veil"
	if z.type=="sky-wick":
		if sim._guest_airborne(z):clip="walk";frame=sim.time*4.0;lift-=38.0
		elif z.flight_landing_at>=0 and sim.time-z.flight_landing_at<.7:
			clip="splash" if z.flight_water else ("break" if z.flight_broken else "land");frame=clampf((sim.time-z.flight_landing_at)/.7*3.99,0,3.99)
			if z.flight_broken and not z.flight_water:lift-=38.0*(1.0-clampf((sim.time-z.flight_landing_at)/.7,0,1))
		else:actor="ghost"
	if z.type=="oar-barge":
		clip="attack" if z.eating else "walk";frame=fposmod(z.barge_clock,2.4)/2.4*4.0
	var frame_foot = foot + Vector2(0.0, lift)
	if z.raft_sink_t > 0.0:
		var raft: Texture2D = _guest_gear.get("raft")
		var sink: float = 1.0 - z.raft_sink_t / 0.52
		if raft != null:
			_sprite(raft, frame_foot + Vector2(0, 8.0 + sink * 25.0), height * 0.26,
				true, Color(0.76, 0.87, 0.89, 1.0 - sink), 0.32 * sink)
	if swimming:
		frame_foot.y += 3.0
	var cabin_drawn = false
	if z.type == "sedan" and z.armor > 0.0 and not z.dying:
		var cabin_actor = "sedan-loaded" if z.sedan_has_bride else "sedan-empty"
		var cabin_foot = frame_foot
		cabin_drawn = _actor_frames.draw_pose(self, cabin_actor, clip, frame, cabin_foot,
			height * 1.65, z.reverse_t <= 0.0, tint)
		if cabin_drawn and z.armor < z.max_armor * 0.66:
			_draw_wounds(cabin_foot, height * 0.65, 0.65 if z.armor < z.max_armor * 0.33 else 0.32)
	var drawn = cabin_drawn
	if not cabin_drawn and (not z.dying or z.type == "incense-thief" or (z.type == "sedan" and z.split_done)):
		if swimming and (z.water_entry_t > 0.0 or z.raft_sink_t > 0.0) and not (z.type == "reedboat" and z.armor <= 0.0):
			var entry = smoothstep(0.0, 0.44, 0.68 - z.water_entry_t) if z.raft_sink_t <= 0.0 else 1.0 - z.raft_sink_t / 0.52
			_actor_frames.draw_pose(self, actor, "walk", frame,
				frame_foot + Vector2(0, height * 0.32 * entry), height, z.reverse_t <= 0.0,
				Color(tint.r, tint.g, tint.b, tint.a * (1.0 - entry)))
			tint.a *= entry
		elif not swimming and z.water_exit_t > 0.0 and not (z.type == "reedboat" and z.armor > 0.0):
			var wet: float = z.water_exit_t / 0.44
			_actor_frames.draw_pose(self, actor, "swim", frame, frame_foot + Vector2(0, 3),
				height, z.reverse_t <= 0.0, Color(tint.r, tint.g, tint.b, tint.a * wet))
			tint.a *= 1.0 - wet
		if z.type == "phaseguard" and sim.time - z.guest_action_at < 0.3:
			var amount = smoothstep(0.0, 0.3, sim.time - z.guest_action_at)
			var previous = "phase-veil" if z.phase_form == 1 else "phase-kite"
			_actor_frames.draw_pose(self, previous, clip, frame, frame_foot, height,
				z.reverse_t <= 0.0, Color(tint.r, tint.g, tint.b, tint.a * (1.0 - amount)))
			tint.a *= amount
		var airborne := sin(PI * clampf(z.object_hop / 0.34, 0.0, 1.0)) if z.terrain_hop_from != z.terrain_hop_to else 0.0
		var tuck := airborne * (0.09 if String(z.def.get("tier", "")) == "h" else 0.19)
		drawn = _actor_frames.draw_pose(self, actor, clip, frame,
			frame_foot - Vector2(0, airborne * 16.0), height, z.reverse_t <= 0.0, tint, Vector2(1.0 + tuck, 1.0 - tuck))
	if not drawn and texture != null:
		_sprite(texture, foot + Vector2(sway, bob + lift), height, true, tint,
			rotation + lean * 0.35, squash)
	elif not drawn:
		# 没有立绘时的保底：画一个会走的影子
		draw_circle(foot + Vector2(0, -height * 0.3 + bob), height * 0.2,
			Color(0.6, 0.62, 0.6, 0.8))
	# 残血：身上开裂、脚下渗影
	if hp_ratio < 0.36 and not z.dying:
		_draw_wounds(foot + Vector2(sway, bob + lift), height, 1.0 - hp_ratio / 0.36)
	if drawn:
		_draw_armor(z, frame_foot, height * (0.72 if swimming else 1.0), texture, 0.0,
			Vector2.ONE, cabin_drawn, clip, frame, height)
	else:
		_draw_armor(z, foot + Vector2(sway, bob + lift), height, texture,
			rotation + lean * 0.35, squash)
	if z.water_entry_t > 0.0:
		var plunge = 1.0 - z.water_entry_t / 0.68
		var ripple = 13.0 + plunge * 30.0
		for band in 2:
			draw_arc(foot + Vector2(0, 1 + band * 3), ripple + band * 8,
				0.05 * PI, 0.95 * PI, 20,
				Color(0.59, 0.83, 0.82, (1.0 - plunge) * (0.7 - band * 0.22)), 2.0)
	if not z.dying:
		_draw_status(z, foot, height, lift)
	if health_bars != "off" and not z.dying:
		_draw_health_bar(z, foot, height)
	if tier_shapes and not z.dying:
		var tier := String(z.def.get("tier", "l"))
		var color := Color(String(Content.TIERS[tier].color))
		Ui.draw_tier_shape(self, tier, foot + Vector2(-33, -height - 13), color)


func _draw_ferry(z: Sim.Zombie, cell_h: float) -> void:
	var foot := _zombie_foot(z, cell_h)
	var height := _zombie_height(z, cell_h)
	var landing := z.flight_landing_at >= 0
	var progress := clampf((sim.time - z.flight_landing_at) / .7, 0, 1) if landing else 0.0
	var lift := 38.0 * (1.0 - progress) + sin(sim.time * 3.5 + z.phase) * (1-progress) * 2
	var at := foot - Vector2(0, lift)
	var clip := "break" if z.flight_broken else "land"
	var frame := progress * 3.99
	if not landing:
		clip = "pickup" if sim.time - z.guest_action_at < .65 else "walk"
		frame = clampf((sim.time-z.guest_action_at)/.65*3.99,0,3.99) if clip == "pickup" else sim.time * 4.0
	var tint := Color(1.5,1.4,1.2) if z.hurt > 0 else Color.WHITE
	_actor_frames.draw_pose(self, "sky-ferry", clip, frame, at, height, true, tint)
	var passenger := sim.guest_uid(z.passenger_uid)
	if passenger != null and passenger.alive():
		var body_h := height * (.84 if passenger.is_large() else .65)
		var seat := at + Vector2(-height * .30, -height * .07 + sin(sim.time*4)*1.2)
		var actor: String = passenger.type
		if actor == "phaseguard": actor = "phase-kite" if passenger.phase_form == 1 else "phase-veil"
		_actor_frames.draw_pose(self, actor, "attack", 1.0 + sin(sim.time*2)*.08, seat, body_h, true, Color.WHITE, Vector2(1,.92))
		# Occlude the passenger's lower body with the real woven basket front.
		_actor_frames.draw_pose(self, "sky-ferry", clip, frame, at, height, true, tint, Vector2.ONE, 0, Rect2(0,.68,.64,.32))
		if health_bars != "off": _draw_health_bar(passenger, seat, body_h)
	if health_bars != "off": _draw_health_bar(z, at, height)
	if tier_shapes: Ui.draw_tier_shape(self, "h", at + Vector2(-40,-height-13), Color(Content.TIERS.h.color))

## 脚底扬尘
func _puff(at: Vector2, radius: float, strength: float) -> void:
	var a = 0.16 + strength * 0.22
	draw_set_transform(at, 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, radius * 1.8, Color(0.78, 0.72, 0.6, a * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 残血的伤口：几道深色裂口 + 边缘发暗，代替"只是一个圈"
func _draw_wounds(at: Vector2, height: float, severity: float) -> void:
	var k = clampf(severity, 0.0, 1.0)
	var ink = Color(0.10, 0.05, 0.05, 0.35 + k * 0.4)
	for i in 3:
		var base = Vector2((float(i) - 1.0) * height * 0.16, -height * (0.34 + float(i) * 0.14))
		var tip = base + Vector2(height * (0.06 + 0.04 * float(i)), -height * 0.1)
		draw_line(at + base, at + tip, ink, 1.6 + k * 1.2)
		if k > 0.5:
			draw_line(at + tip, at + tip + Vector2(-height * 0.05, height * 0.07),
				ink, 1.2)


func _sprite(texture: Texture2D, foot: Vector2, height: float, flip: bool,
		tint: Color, rotation: float = 0.0, squash: Vector2 = Vector2.ONE) -> void:
	var size = texture.get_size()
	var scale = height / size.y
	var sx = -scale if flip else scale
	draw_set_transform(foot, rotation, Vector2(sx, scale) * squash)
	draw_texture_rect(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 护具不再用一圈光弧表示：按"斗笠/石帽/陶瓮/铁面"画成有形状的实物，
## 血量掉到 2/3、1/3 时出现缺口与裂纹，归零时整块掉落。
var _armor_memory: Dictionary = {}     # zid -> {ratio, falling, fall_t}
var _falling: Array = []               # 正在掉落的护具碎片


## 护具用三档破损的小图（tools/paint_armor.py 画的），按血量换档：
## 完好 → 有缺口 → 残破；打碎时整块掉下去。

const ARMOR_ART = {
	"straw": "straw", "stonehat": "stonehat", "paper": "paper", "charm": "paper",
	"sedan": "sedan", "urn": "urn", "mask": "mask", "shield": "shield", "raft": "raft",
}
## 生成图已经带了各自的材质色，这里只做很轻的偏色，别把人家的画压平
const ARMOR_TINT = {
	"stonehat": Color(1.0, 1.0, 1.0, 1.0),
	"sedan": Color(1.0, 0.97, 0.94, 1.0),
	"paper": Color(1.0, 1.0, 0.98, 1.0),
}


func _armor_art_key(armor_type: String) -> String:
	return String(ARMOR_ART.get(armor_type, "straw"))


func _armor_tier(ratio: float) -> int:
	if ratio > 0.66:
		return 1
	if ratio > 0.33:
		return 2
	return 3


## 立绘本身也有留白：先量出它真正的像素范围，护具才压得准头顶
var _sprite_content_cache: Dictionary = {}


func _sprite_content(key: String, texture: Texture2D) -> Rect2:
	if _sprite_content_cache.has(key):
		return _sprite_content_cache[key]
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	var image = texture.get_image()
	if image != null:
		var used = image.get_used_rect()
		if used.size.y > 0:
			rect = Rect2(used)
	_sprite_content_cache[key] = rect
	return rect


func _armor_texture(art: String, tier: int) -> Texture2D:
	var profile_key := "%s-%d" % [art, tier]
	if _profile_armor.has(profile_key):
		return _profile_armor[profile_key]
	if _guest_gear.has(art):
		return _guest_gear[art]
	var key = "%s-%d" % [art, tier]
	if _armor_atlas.has(key):
		return _armor_atlas[key]
	return Ui.sprite("armor-%s" % key)


func _draw_armor(z: Sim.Zombie, animated_foot: Vector2, height: float,
		body: Texture2D, rotation: float, squash: Vector2, cabin_drawn: bool = false,
		clip: String = "", key_position: float = 0.0, actor_height: float = 0.0) -> void:
	if z.type in ["sky-wick","sky-ferry","oar-barge"]:return
	var key = z.get_instance_id()
	var face = _armor_face(z, clip, key_position, animated_foot, actor_height)
	var ratio = clampf(z.armor / maxf(1.0, z.max_armor), 0.0, 1.0)
	var prev = float(_armor_memory.get(key, ratio))
	# Every armor material breaks into independently moving pieces, even on a lethal hit.
	if prev > 0.01 and z.armor <= 0.0 and z.raft_sink_t <= 0.0:
		var fall_texture: Texture2D = null
		var lift = 0.7
		if z.type == "sedan":
			var actor = "sedan-loaded" if z.sedan_has_bride else "sedan-empty"
			var sheet: Texture2D = _actor_frames.key_sheet(actor)
			if sheet != null:
				var frame: Dictionary = _actor_frames.catalog[actor]["clips"]["walk"][0]
				var r: Array = frame["rect"]
				var region := AtlasTexture.new()
				region.atlas = sheet
				region.region = Rect2(r[0], r[1], r[2], r[3])
				region.filter_clip = true
				fall_texture = region
				lift = 1.12
		for i in 5:
			_falling.append({"at": face if face != Vector2.INF else animated_foot + Vector2(0, -height * lift),
				"texture": fall_texture,
				"t": 0.0, "type": String(z.armor_type), "w": height * _armor_width(z),
				"part": i, "vx": (float(i) - 2.0) * 46.0,
				"vy": -60.0 - float((i * 7) % 3) * 25.0,
				"spin": (float(i) - 2.0) * 3.2})
	_armor_memory[key] = ratio
	if z.armor <= 0.0 or z.dying or cabin_drawn:
		return
	var art = _armor_art_key(String(z.armor_type))
	var tier = _armor_tier(ratio)
	var texture = _armor_texture(art, tier)
	if texture == null:
		return
	if art in ["shield", "raft"]:
		var source = _armor_content(art, texture)
		var body_h = actor_height if actor_height > 0.0 else height
		var w = body_h * (0.70 if art == "shield" else 1.14)
		var size = source.size * (w / maxf(1.0, source.size.x))
		var direction = -1.0 if z.reverse_t <= 0.0 else 1.0
		var center = animated_foot + Vector2(direction * body_h * 0.21, -body_h * 0.44) if art == "shield" else animated_foot - Vector2(0, 3.0)
		draw_texture_rect_region(texture, Rect2(center - size * 0.5, size), source)
		if tier > 1:
			_draw_wounds(center + Vector2(0, size.y * 0.5), size.y, 0.42 if tier == 2 else 0.84)
		return
	# Work in the body's local coordinates and reuse its flip, stride, lean and squash.
	var art_name = "armor-%s-%d" % [art, tier]
	var content = _armor_content(art_name, texture)
	var body_size = body.get_size() if body != null else Vector2(height, height)
	var width = body_size.y * _armor_width(z)
	var scale = width / maxf(1.0, content.size.x)
	var drawn = content.size * scale
	var top_of_body = -body_size.y
	if body != null:
		var body_box = _sprite_content(String(z.type), body)
		top_of_body += body_box.position.y
	var head_y = top_of_body + body_size.y * _armor_head_ratio(z)
	var tint: Color = ARMOR_TINT.get(String(z.armor_type), Color(1, 1, 1, 1))
	if z.armor_pulse > 0.01:
		tint = Color(tint.r + 0.4 * z.armor_pulse, tint.g + 0.35 * z.armor_pulse,
			tint.b + 0.25 * z.armor_pulse, tint.a)
	if face != Vector2.INF:
		var ratios := {"mask": 0.24, "urn": 0.36, "straw": 0.58, "stonehat": 0.48, "paper": 0.42}
		var face_width := actor_height * float(ratios.get(art, 0.36))
		var size: Vector2 = content.size * (face_width / maxf(1.0, content.size.x))
		var vertical := 0.88 if art in ["straw", "stonehat"] else 0.52
		draw_set_transform(face, 0.0, Vector2(-1.0 if z.reverse_t > 0.0 else 1.0, 1.0))
		draw_texture_rect_region(texture, Rect2(-size * Vector2(0.5, vertical), size), content, tint)
		draw_set_transform(Vector2.ZERO)
		return
	var body_scale = height / maxf(1.0, body_size.y)
	draw_set_transform(animated_foot, rotation, Vector2(-body_scale, body_scale) * squash)
	draw_texture_rect_region(texture, Rect2(Vector2(-drawn.x * 0.5,
		head_y - drawn.y), drawn), content, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Face centers marked on the original atlases. Interpolation follows each clip's head motion.
const ARMOR_FACE_KEYS = {
	"ironjudge": {
		"walk": [[222, 36], [667, 39], [1110, 42], [1557, 43]],
		"attack": [[228, 528], [668, 506], [1117, 574], [1556, 493]],
	},
	"bucket": {
		"walk": [[158, 39], [467, 40], [776, 42], [1091, 40]],
		"attack": [[157, 366], [499, 370], [803, 373], [1116, 384]],
		"swim": [[155, 720], [467, 719], [783, 722], [1093, 721]],
		"swim_bite": [[154, 1038], [466, 1006], [800, 1034], [1093, 1038]],
	},
}


func _armor_face(z: Sim.Zombie, clip: String, key_position: float, foot: Vector2,
		height: float) -> Vector2:
	var pins: Array = _face_pins.get(z.type, ARMOR_FACE_KEYS.get(z.type, {})).get(clip, [])
	if pins.is_empty() or height <= 0.0:
		return Vector2.INF
	var info: Dictionary = _actor_frames.catalog[z.type]
	var frames: Array = info["clips"][clip]
	var phase = fposmod(key_position, float(pins.size()))
	var first = int(floor(phase))
	var second = (first + 1) % pins.size()
	var a = _local_face(pins[first], frames[first])
	var b = _local_face(pins[second], frames[second])
	var point = a.lerp(b, phase - first) * (height / float(info["body_px"]))
	if (String(info["facing"]) == "left") != (z.reverse_t <= 0.0):
		point.x = -point.x
	return foot + point


func _local_face(pin: Array, frame: Dictionary) -> Vector2:
	var rect: Array = frame["rect"]
	var anchor: Array = frame["anchor"]
	return Vector2(pin[0] - rect[0] - anchor[0], pin[1] - rect[1] - anchor[1])


## 算出小图里真正有像素的区域，缓存起来（只在第一次用到时扫一遍）
var _armor_content_cache: Dictionary = {}


func _armor_content(key: String, texture: Texture2D) -> Rect2:
	if _armor_content_cache.has(key):
		return _armor_content_cache[key]
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	var image = texture.get_image()
	if image != null:
		var used = image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)
	_armor_content_cache[key] = rect
	return rect


## 头顶大概在身高的什么位置（立绘有留白，按实测压到 0.75 左右）
func _armor_head_ratio(z: Sim.Zombie) -> float:
	match _armor_art_key(String(z.armor_type)):
		"sedan": return 0.54
		"paper": return 0.49
		"urn": return 0.46
		"mask": return 0.47
		"stonehat": return 0.39
		_: return 0.42


## 护具该画多宽（相对身高）：帽子宽、瓮窄一点、面具更窄
func _armor_width(z: Sim.Zombie) -> float:
	match _armor_art_key(String(z.armor_type)):
		"urn":
			return 0.46
		"mask":
			return 0.44
		"stonehat":
			return 0.62
		"paper":
			return 0.56
		"sedan":
			return 1.08
		_:
			return 0.66


## 掉落中的护具：用同一张图旋转着落下去、淡出
func _update_armor_falls(delta: float) -> void:
	for i in range(_falling.size() - 1, -1, -1):
		_falling[i]["t"] += delta
		if float(_falling[i]["t"]) > 0.8:
			_falling.remove_at(i)


func _draw_armor_falls() -> void:
	for piece in _falling:
		var t = clampf(float(piece["t"]) / 0.8, 0.0, 1.0)
		var art = _armor_art_key(String(piece["type"]))
		var texture: Texture2D = piece.get("texture")
		var is_cabin = texture != null
		if not is_cabin:
			texture = _armor_texture(art, 3)
		if texture == null:
			continue
		var width = float(piece["w"])
		var content = Rect2(Vector2.ZERO, texture.get_size()) if is_cabin \
			else _armor_content("armor-%s-3" % art, texture)
		var part = int(piece["part"])
		var source = Rect2(content.position + Vector2(content.size.x * part / 5.0, 0),
			Vector2(content.size.x / 5.0, content.size.y))
		var drawn = source.size * (width / maxf(1.0, content.size.x))
		var at: Vector2 = piece["at"] + Vector2(float(piece["vx"]) * t,
			float(piece["vy"]) * t + 180.0 * t * t)
		var alpha = 1.0 - t
		draw_set_transform(at, t * float(piece["spin"]), Vector2(1.0, 0.9))
		draw_texture_rect_region(texture, Rect2(-drawn * 0.5, drawn), source,
			Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_status(z: Sim.Zombie, foot: Vector2, height: float, lift: float) -> void:
	var head = foot + Vector2(0, -height * 0.98 + lift)
	# 减速：脚踝结霜 + 飘落的霜屑（冻得狠时还会有一层薄冰边）
	if z.slow_t > 0.0:
		var strength = clampf(z.slow_amount, 0.0, 1.0)
		draw_set_transform(foot + Vector2(0, -4), 0.0, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, 20.0 + strength * 10.0,
			Color(0.62, 0.86, 0.95, 0.10 + strength * 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 3:
			var t = _time * 1.8 + i * 2.4 + z.phase
			var flake = foot + Vector2(sin(t) * 15.0,
				-height * (0.18 + float(i) * 0.22) - fmod(_time * 22.0 + i * 9.0, 26.0))
			draw_line(flake, flake + Vector2(0, 5.0),
				Color(0.78, 0.94, 1.0, 0.5 * strength + 0.2), 1.2)
			draw_line(flake + Vector2(-3, 1.5), flake + Vector2(3, 1.5),
				Color(0.78, 0.94, 1.0, 0.42 * strength + 0.16), 1.0)
		if strength >= 0.5:
			# 冻住的时候身上挂一层冰壳
			draw_rect(Rect2(foot + Vector2(-height * 0.26, -height * 0.86),
				Vector2(height * 0.52, height * 0.84)),
				Color(0.62, 0.86, 1.0, 0.10 + strength * 0.06))
	# 燃烧：火舌从脚下往上卷
	if z.burn_t > 0.0:
		for i in 4:
			var t = _time * 5.6 + i * 1.7 + z.phase
			var h = 0.2 + float(i) * 0.2
			var wobble = sin(t * 1.7) * 5.0
			var base = foot + Vector2(wobble, -height * h)
			var tip = base + Vector2(sin(t) * 4.0, -height * 0.16)
			draw_line(base, tip, Color(1.0, 0.52, 0.18, 0.55), 3.0 - float(i) * 0.4)
			draw_circle(tip, 2.6, Color(1.0, 0.82, 0.4, 0.5))
	# 眩晕：头顶转圈的星
	if z.stun_t > 0.0:
		for i in 3:
			var a = _time * 5.0 + i * TAU / 3.0
			var pos = head + Vector2(cos(a) * 16.0, -height * 0.12 + sin(a) * 5.0)
			_draw_star(pos, 3.2, Color(1, 0.9, 0.6, 0.9))
	# 易伤：身上浮起几道朱砂符纹，而不是一圈光环
	if z.vuln_t > 0.0:
		var k = clampf(z.vuln, 0.0, 1.0)
		var ink = Color(0.92, 0.28, 0.2, 0.45 + k * 0.4)
		for i in 3:
			var a = _time * 1.6 + float(i) * 2.1
			var r = height * (0.30 + 0.05 * float(i))
			var center = foot + Vector2(0, -height * 0.5)
			var glyph = center + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.45)
			draw_line(glyph + Vector2(-3, -4), glyph + Vector2(3, 4), ink, 1.6)
			draw_line(glyph + Vector2(3, -4), glyph + Vector2(-3, 4), ink, 1.6)
	# 狂暴：红色的气
	if z.rage_t > 0.0:
		for i in 2:
			var t = _time * 3.2 + i * 2.0
			var pos = foot + Vector2(sin(t) * 14.0, -height * (0.3 + 0.1 * i))
			draw_circle(pos, 5.0, Color(0.85, 0.3, 0.22, 0.16))
	if z.aura_pulse > 0.0:
		draw_arc(foot + Vector2(0, -height * 0.3), height * 0.5 + z.aura_pulse * 24.0,
			0, TAU, 30, Color(0.78, 0.5, 0.4, z.aura_pulse * 0.4), 2.0)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	for i in 8:
		var a = -PI * 0.5 + i * PI * 0.25
		var r = radius if i % 2 == 0 else radius * 0.42
		points.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, color)


func _draw_health_bar(z: Sim.Zombie, foot: Vector2, height: float) -> void:
	var width = 56.0 if not bool(z.def.get("large", false)) else 72.0
	var x = foot.x - width * 0.5
	var y = foot.y - height - 14.0
	if z.type == "sedan" and z.armor > 0.0:
		y = foot.y - height * 1.62 - 7.0
	if z.vault_arc > 0.0:
		y -= z.vault_arc * 58.0
	var hp_ratio = clampf(z.hp / maxf(1.0, z.max_hp), 0.0, 1.0)
	var armor_ratio = clampf(z.armor / maxf(1.0, z.max_armor), 0.0, 1.0) \
		if z.max_armor > 0.0 else 0.0
	draw_rect(Rect2(x - 1.0, y - 1.0, width + 2.0, 8.0), Color(0, 0, 0, 0.55))
	var hp_color = Ui.GOOD.lerp(Ui.BAD, 1.0 - hp_ratio)
	draw_rect(Rect2(x, y, width * hp_ratio, 4.0), hp_color)
	if armor_ratio > 0.0:
		draw_rect(Rect2(x, y + 4.0, width * armor_ratio, 3.0),
			ARMOR_COLORS.get(z.armor_type, Ui.GOLD))
	if health_bars == "barText":
		var text = "%d" % int(ceil(z.hp))
		if z.armor > 0.0:
			text += "+%d" % int(ceil(z.armor))
		var font = Ui.body_font()
		draw_string(font, Vector2(x - 2.0, y - 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.fit_font(font, text, width + 4.0),
			Color(1, 0.95, 0.85, 0.92))


func _draw_plant_health_bar(plant: Sim.Plant, foot: Vector2, height: float) -> void:
	var width = 54.0
	var x = foot.x - width * 0.5
	var y = foot.y - height - 14.0
	if plant.is_lily and plant.on_lily:
		y += 11.0
	var hp_ratio = clampf(plant.hp / maxf(1.0, plant.max_hp), 0.0, 1.0)
	draw_rect(Rect2(x - 1.0, y - 1.0, width + 2.0, 8.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(x, y, width * hp_ratio, 4.0), Ui.GOOD.lerp(Ui.BAD, 1.0 - hp_ratio))
	var shield = maxf(plant.shell, plant.wish)
	if shield > 0.0:
		var shield_max = maxf(plant.shell_max, shield)
		if plant.type == "umbrella":
			shield_max = maxf(shield_max,
				float(Upgrades.EFFECTS["umbrella"]["wish_hp"][plant.tier(2)]))
		draw_rect(Rect2(x, y + 4.0, width * clampf(shield / shield_max, 0.0, 1.0), 3.0),
			Color("#d6b777"))
	if health_bars == "barText":
		var label = "%d" % int(ceil(plant.hp))
		if shield > 0.0:
			label += "+%d" % int(ceil(shield))
		draw_string(Ui.body_font(), Vector2(x - 2.0, y - 5.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.fit_font(Ui.body_font(), label, width + 6.0),
			Color(1, 0.95, 0.85, 0.92))


# ── 射弹 ────────────────────────────────────────────────────────────────────
func _draw_shots() -> void:
	for shot in sim.shots:
		if shot.dead:
			continue
		var at = Geo.to_screen(shot.pos)
		if shot.kind=="mortar" and bool(shot.payload.get("locked",false)):
			var mark:Vector2=Geo.to_screen(Vector2(shot.tx,shot.ty+14))
			draw_arc(mark,31,0,TAU,40,Color(1,.73,.32,.8),2,true)
			for i in 4:
				var d:=Vector2.from_angle(i*PI/2)
				draw_line(mark+d*24,mark+d*39,Color(1,.84,.54,.9),2,true)
		var look = String(shot.look)
		if look in ["kite", "firework"] or (shot.kind == "lob" and shot.src == "lobber"):
			var clip: String = "dumpling" if shot.src == "lobber" else look
			var sprite_height := 26.0 if clip != "firework" else 23.0
			var left := bool(shot.payload.get("bounced", false))
			_effect_frames.draw_pose(self, "v052-projectiles", clip, sim.time * 7.0,
				at + Vector2(0, sprite_height * 0.45), sprite_height, left, Color.WHITE)
			continue
		if look=="sign-rain":
			draw_line(at-Vector2(19,0),at+Vector2(7,0),Color("#ffe3a0"),3,true)
			draw_line(at-Vector2(26,0),at-Vector2(7,0),Color(.5,.92,.68,.5),5,true)
			continue
		if look == "mortar-fragment":
			var direction: Vector2 = (Geo.to_screen(shot.pos + shot.dir * 10) - at).normalized()
			draw_line(at - direction * 13, at, Color("#d49257"), 3, true)
			draw_circle(at,3,Color("#f8d99a"))
			continue
		if look in ["banyan-seed","mortar-shell","mortar-heavy","mortar-soul"]:
			var clip: String={"banyan-seed":"seed","mortar-shell":"shell","mortar-heavy":"shell","mortar-soul":"soul"}[look]
			if look == "mortar-heavy":
				_draw_glow(at,29,Color(1,.34,.12,.45))
				_new_frames.draw_pose(self,"v055-projectiles",clip,sim.time*6,at,48,false,Color(1.2,.92,.7))
				continue
			_new_frames.draw_pose(self,"v055-projectiles",clip,sim.time*6.0,at,30 if clip=="shell" else 23,false,Color.WHITE)
			continue
		if look=="range-echo":
			_new_frames.draw_pose(self,"v054-relay-fx","range",sim.time*6.0,at,24,false,Color.WHITE)
			continue
		match look if look != "" else String(shot.kind):
			"dragon_1", "dragon_2", "dragon_3":
				_draw_dragon_round(at, int(look.right(1)))
			"ember":
				_draw_ember_round(at)
			"coin":
				draw_circle(at, 6.0, Color("#daa955"))
				draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color("#4f3929"))
			"reed":
				draw_line(at - Vector2(7, 0), at + Vector2(9, 2), Color("#b1c292"), 3.0, true)
			"frost-sign":
				draw_line(at - Vector2(12, 0), at + Vector2(8, 0), Color("#a6dfde"), 3.0, true)
				draw_circle(at + Vector2(7, 0), 2.0, Color("#e5ffff"))
			"homing":
				_draw_flame(at, 9.0 if not shot.fire else 11.0, Color("#ffb45e"))
			"lob":
				draw_circle(at, 6.0, Color(0.95, 0.92, 0.82, 0.95))
				draw_circle(at, 3.4, Color(1, 0.98, 0.9, 0.95))
			"star":
				_draw_glow(at, 16.0, Color(1, 0.85, 0.45, 0.4))
				_draw_star(at, 8.0, Color("#ffe9a8"))
			_:
				_draw_pea(shot)


func _draw_dragon_round(at: Vector2, tier: int) -> void:
	match tier:
		1:
			_draw_glow(at, 10.0, Color(0.96, 0.68, 0.29, 0.36))
			draw_circle(at, 5.0, Color("#a3693d"))
			draw_circle(at - Vector2(1.5, 1.5), 3.0, Color("#e9b96f"))
		2:
			_draw_glow(at, 14.0, Color(0.44, 0.81, 0.67, 0.44))
			draw_set_transform(at, -0.38)
			draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-2, -6),
				Vector2(6, -5), Vector2(9, 0), Vector2(3, 5), Vector2(-4, 5)]), Color("#5caa90"))
			draw_line(Vector2(-2, -5), Vector2(-2, 5), Color("#efd289"), 2.0, true)
			draw_set_transform(Vector2.ZERO)
		3:
			_draw_glow(at, 18.0, Color(1.0, 0.39, 0.22, 0.48))
			draw_set_transform(at, -0.36)
			draw_colored_polygon(PackedVector2Array([Vector2(-11, -7), Vector2(-4, -4),
				Vector2(3, -5), Vector2(12, 0), Vector2(3, 5), Vector2(-4, 4), Vector2(-11, 7)]), Color("#bf4e34"))
			draw_line(Vector2(-4, -4), Vector2(-4, 4), Color("#f3ca7c"), 3.0, true)
			draw_circle(Vector2(3, -1), 2.0, Color("#ffdfa6"))
			draw_set_transform(Vector2.ZERO)


func _draw_pea(shot) -> void:
	var length = 26.0 if shot.big else 18.0
	var thickness = 4.0 if shot.big else 2.6
	var color = Color("#ffe9a8") if shot.big else Color(0.86, 0.78, 0.58, 0.95)
	if shot.pierce_armor:
		color = Color(0.96, 0.95, 0.88, 0.95)
		length = 30.0
		thickness = 1.8
	var at = Geo.to_screen(shot.pos)
	var prev = Geo.to_screen(shot.pos - Vector2(length, 0.0))
	var dir = (at - prev).normalized()
	draw_line(at - dir * length, at, color, thickness)
	draw_circle(at, thickness * 0.9, Color(1, 0.96, 0.86, 0.95))
	if shot.fire:
		_draw_glow(at, 14.0, Color(1, 0.62, 0.26, 0.35))


func _draw_flame(pos: Vector2, radius: float, color: Color) -> void:
	_draw_glow(pos, radius * 2.4, Color(color.r, color.g, color.b, 0.3))
	draw_circle(pos, radius, color)
	draw_circle(pos, radius * 0.55, Color(1, 0.95, 0.8, 0.95))


# ── 香火 ────────────────────────────────────────────────────────────────────
func _draw_orbs() -> void:
	var tutorial_collect = sim.tutorial != null \
		and String(sim.tutorial["step"]) == "collect"
	for orb in sim.orbs:
		if bool(orb["dead"]):
			continue
		var pos = Geo.to_screen(Vector2(float(orb["x"]), float(orb["y"])))
		if tutorial_collect and bool(orb.get("tutorial", false)):
			# 教学第一步的香火：呼吸光环 + 指引，避免"不知道该点哪儿"
			var beat = 0.5 + 0.5 * sin(_time * 3.4)
			draw_arc(pos, 26.0 + beat * 10.0, 0.0, TAU, 36,
				Color(1.0, 0.86, 0.5, 0.35 + beat * 0.45), 2.6)
			draw_arc(pos, 40.0 + beat * 14.0, 0.0, TAU, 36,
				Color(1.0, 0.8, 0.42, 0.12 + beat * 0.18), 1.6)
			var font = Ui.medium_font()
			var label = "点这里"
			var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string(font, pos + Vector2(-width * 0.5, -40.0 - beat * 4.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.62, 0.75 + beat * 0.25))
		var life = float(orb["life"])
		var alpha = 1.0
		if life < 2.0:
			alpha = clampf(life / 2.0, 0.25, 1.0)
		var pulse = 1.0 + sin(_time * 4.0 + float(orb["phase"])) * 0.08
		_draw_glow(pos, 24.0 * pulse, Color(1, 0.72, 0.32, 0.5 * alpha))
		draw_circle(pos, 9.0 * pulse, Color(1, 0.86, 0.55, 0.95 * alpha))
		draw_circle(pos, 5.0 * pulse, Color(1, 0.97, 0.85, alpha))
		for i in 3:
			var a = _time * 2.0 + i * TAU / 3.0
			draw_circle(pos + Vector2(cos(a), sin(a)) * 14.0 * pulse, 1.6,
				Color(1, 0.9, 0.6, 0.55 * alpha))


# ── 粒子与飘字 ──────────────────────────────────────────────────────────────
func _draw_shovel_lift(event: Dictionary, remaining: float) -> void:
	var plant: Sim.Plant = event["plant"]
	var shell := bool(event["shell_only"])
	var art := texture_for("shell") if shell else plant_texture(plant)
	if art == null:
		return
	var age := 1.0 - remaining
	var foot := _plant_foot(plant, Geo.cell_h(sim.rows))
	var height := float(plant.def.get("sprite_h", 92)) * Geo.unit_scale(sim.rows) * Geo.scale_at_flat(plant.pos, sim.rows)
	var lift := sin(age * PI * 0.82)
	var displayed := height * lerpf(1.0, 0.32, smoothstep(0.15, 1.0, age))
	var shape := art.get_size() * displayed / art.get_height()
	var center := foot + Vector2(32.0 * age, -48.0 * lift - displayed * 0.50)
	if shell:
		center += Vector2(0, -height * 0.30)
	draw_set_transform(center, -0.45 * lift, Vector2.ONE)
	draw_texture_rect(art, Rect2(-shape / 2.0, shape), false, Color(1, 0.94, 0.80, 1.0 - smoothstep(0.20, 1.0, age)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 6:
		var angle := float(i) * TAU / 6.0
		var soil := foot + Vector2(cos(angle) * (12.0 + 24.0 * age), sin(angle) * (5.0 + 11.0 * age) - 11.0 * lift)
		draw_circle(soil, (3.2 + float(i % 2)) * remaining, Color(0.66, 0.45, 0.29, remaining * 0.7))


func _draw_capstone_seal(event: Dictionary, age: float) -> void:
	var flat := Vector2(event["x"], event["y"]) + Vector2(0, Geo.cell_h(sim.rows) * 0.30)
	var foot := Geo.to_screen(flat, sim.rows)
	_effect_frames.draw_pose(self, "v052-plant-fx", "ascend", age * 3.99,
		foot + Vector2(0, 12), 168.0, false, Color(1, 1, 1, sin(PI * age)))
	var path: Color = event["color"]
	var gold := Ui.GOLD_BRIGHT.lerp(path, 0.36)
	var fade := smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.38, 1.0, age))
	if fade < 0.01:
		return
	var radius := lerpf(17.0, 55.0, smoothstep(0.0, 0.65, age))
	draw_set_transform(foot, 0, Vector2(1, 0.32))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 50, Color(gold, fade * 0.78), 2.6, true)
	draw_arc(Vector2.ZERO, radius * 0.79, 0, TAU, 42, Color(path, fade * 0.65), 1.8, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for i in 12:
		var angle := i * TAU / 12.0 + age * 2.1
		var ember := foot + Vector2(cos(angle) * radius * 0.83, sin(angle) * radius * 0.22 - age * (57.0 + i % 4 * 15.0))
		var size := (1.5 + float(i % 3) * 0.7) * fade
		draw_colored_polygon(PackedVector2Array([ember + Vector2(-size, 0), ember + Vector2(0, -size * 2),
			ember + Vector2(size, 0), ember + Vector2(0, size * 2)]), Color(gold, fade * 0.85))


func _draw_particles() -> void:
	for p in sim.particles:
		var life = float(p["life"])
		var max_life = maxf(0.01, float(p["max"]))
		var k = clampf(life / max_life, 0.0, 1.0)
		var color: Color = p["color"]
		var pos = Geo.to_screen(Vector2(float(p["x"]), float(p["y"])))
		match String(p["kind"]):
			"theft":
				# Inward amber wisps, visually distinct from outward buff rings and projectiles.
				for i in 9:
					var angle: float = i * TAU / 9.0 + (1-k)*4
					var radius: float = 38*k
					var end: Vector2 = pos + Vector2(cos(angle)*radius, sin(angle)*radius*.5)
					draw_arc(end, 3+2*k, angle, angle+1.8, 8, Color(color,k), 1.5, true)
			"reed_beam":
				var start:=Vector2(float(p.x),float(p.y));var direction: Vector2=p.dir
				for segment in 7:
					var flat:=start+direction*(segment+.5)*float(p.length)/7.0
					var at:=Geo.to_screen(flat,sim.rows)
					_new_frames.draw_pose(self,"v054-relay-fx","breath",(1.0-k)*3.99,at,32,false,Color(1,1,1,k*.75),Vector2.ONE,(Geo.to_screen(flat+direction*10,sim.rows)-at).angle())
			"relay_collect":
				_new_frames.draw_pose(self,"v054-relay-fx","collect",(1.0-k)*3.99,pos,44,false,Color(1,1,1,k))
			"barge_sink":
				_actor_frames.draw_pose(self,"oar-barge","sink",(1.0-k)*3.99,pos+Vector2(0,15),110*Geo.unit_scale(sim.rows),true,Color(1,1,1,minf(1,k*4)))
			"magic":
				var effect := String(p.effect)
				if effect in ["judge-sanctuary","judge-cleanse"]:
					var radius:float=float(p.size)*(.25+(1-k)*.6)
					draw_arc(pos,radius,0,TAU,64,Color(.55,1,.8,k*.8),3,true)
					for i in 8:
						var a:float=i*TAU/8+(1-k)*.7
						var at:Vector2=pos+Vector2(cos(a),sin(a)*.5)*radius
						draw_colored_polygon(PackedVector2Array([at+Vector2(0,-12),at+Vector2(6,0),at+Vector2(0,12),at+Vector2(-6,0)]),Color(.7,1,.87,k))
				elif effect=="lion-cheer":
					for i in 3:
						var at:Vector2=pos+Vector2((i-1)*17,-(1-k)*40)
						draw_circle(at,7,Color(.75,.25,.16,k));draw_arc(at,7,0,TAU,20,Color(1,.8,.4,k),2,true)
						draw_line(at-Vector2(9,13),at+Vector2(7,-7),Color(1,.92,.68,k),2,true)
				elif effect in ["sign-quick","sign-rain-muzzle"]:
					for i in 5:
						var at:Vector2=pos+Vector2((1-k)*45,(i-2)*7)
						draw_line(at-Vector2(24,0),at,Color(.63,1,.76,k*.8),3,true)
						draw_colored_polygon(PackedVector2Array([at+Vector2(8,0),at+Vector2(-2,-3),at+Vector2(-2,3)]),Color(1,.9,.58,k))
				elif effect=="mortar-lock":
					var radius:float=30+(1-k)*15
					draw_arc(pos,radius,0,TAU,48,Color(1,.72,.3,k),2.4,true)
					for i in 4:
						var d:=Vector2.from_angle(i*PI/2)
						draw_line(pos+d*(radius+5),pos+d*(radius+16),Color(1,.88,.56,k),3,true)
				elif effect.begins_with("v055-"):
					if effect=="v055-mortar-blast":
						_new_frames.draw_pose(self,"v055-projectiles","blast",(1.0-k)*3.99,pos,float(p.size),false,Color(1,1,1,minf(1,k*3)))
					elif effect=="v055-mortar-muzzle":
						_new_frames.draw_pose(self,"v055-projectiles","blast",(1.0-k)*2,pos,float(p.size)*.65,false,Color(1,.85,.65,k*.7))
					else:
						for leaf in 5:
							var a: float=leaf*TAU/5.0+(1.0-k)*.6
							var center: Vector2=pos+Vector2(cos(a)*24,sin(a)*10-30*(1-k))
							_new_frames.draw_pose(self,"v055-projectiles","seed",(1.0-k)*3.99,center,14.0,false,Color(.8,1,.75,k*.7))
				elif effect.begins_with("buff-"):
					_buff_frames.draw_pose(self,"v053-buff-fx",effect.trim_prefix("buff-"),(1.0-k)*3.99,
						pos,float(p.size),false,Color(1,1,1,minf(1.0,k*3.0)))
				else:
					_effect_frames.draw_pose(self,"v052-plant-fx",effect,(1.0-k)*3.99,
						pos,float(p.size),false,Color(1,1,1,minf(1.0,k*3.0)))
			"shovel_lift":
				_draw_shovel_lift(p, k)
			"capstone_seal":
				_draw_capstone_seal(p, 1.0 - k)
			"plant_action":
				var actor = String(p["actor"])
				var flat = Vector2(float(p["x"]), float(p["y"]))
				var height = float(p["size"]) * Geo.unit_scale(sim.rows) * Geo.scale_at_flat(flat, sim.rows)
				var frame = minf(3.99, (1.0 - k) * 4.0)
				if actor in ["bomb", "gust", "squash"]:
					frame = 2.0 + minf(1.99, (1.0 - k) * 2.0)
				_actor_frames.draw_pose(self, actor, "action", frame, Geo.to_screen(flat, sim.rows),
					height, false, Color(1, 1, 1, minf(1.0, 2.0 * k)))
			"gust_trail":
				for strand in 3:
					var line := PackedVector2Array()
					for i in 14:
						line.append(pos + Vector2(-i * (7.0 + strand), strand * 10.0
							+ sin(i * 0.43 + strand + k * 7.0) * 5.0))
					draw_polyline(line, Color(color.r, color.g, color.b,
						0.56 * sin(PI * k)), 2.5 - 0.5 * strand, true)
			"bomb_blast":
				var elapsed = max_life - life - float(p.get("delay", 0.0))
				if elapsed < 0.0:
					continue
				var t = clampf(elapsed / (max_life - float(p.get("delay", 0.0))), 0.0, 1.0)
				var radius = float(p["size"]) * (0.15 + 0.85 * sqrt(t))
				draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.17 * (1.0 - t)))
				draw_arc(pos, radius, 0.0, TAU, 48,
					Color(color.r, color.g, color.b, 0.85 * (1.0 - t)), 8.0 * (1.0 - t) + 1.0)
			"bomb_smoke":
				draw_circle(pos, float(p["size"]) * (1.0 + 1.8 * (1.0 - k)),
					Color(color.r, color.g, color.b, 0.38 * k))
			"ring":
				draw_arc(pos, float(p["size"]), 0.0, TAU, 40,
					Color(color.r, color.g, color.b, color.a * k), 2.4)
			"shard":
				var size = float(p["size"])
				draw_set_transform(pos, _time * 3.0 + size, Vector2(1, 1))
				draw_rect(Rect2(-size * 0.5, -size * 0.5, size, size),
					Color(color.r, color.g, color.b, color.a * k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				draw_circle(pos, float(p["size"]), Color(color.r, color.g, color.b,
					color.a * k))


func _draw_floaters() -> void:
	var font = Ui.medium_font()
	for f in sim.floaters:
		var life = float(f["life"])
		var max_life = maxf(0.01, float(f["max"]))
		var k = clampf(life / max_life, 0.0, 1.0)
		var color: Color = f["color"]
		var size = int(f["size"])
		var pos = Geo.to_screen(Vector2(float(f["x"]), float(f["y"])))
		var text = String(f["text"])
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, pos - Vector2(width * 0.5, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0, 0, 0, 0.55 * k))
		draw_string(font, pos - Vector2(width * 0.5, 1.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(color.r, color.g, color.b, color.a * k))

## 瓦制火丸的棱角、铜箍和细碎火星在无彩色时也能与狐火分开。
func _draw_ember_round(at: Vector2) -> void:
	_draw_glow(at - Vector2(5, 0), 15.0, Color(0.96, 0.43, 0.13, 0.52))
	var spin := sin(sim.time * 19.0) * 0.42
	draw_set_transform(at, spin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 0), Vector2(-6, -6), Vector2(5, -7),
		Vector2(11, 0), Vector2(5, 7), Vector2(-6, 6)]), Color("#4c241d"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -5), Vector2(4, -6), Vector2(8, -2), Vector2(-3, -1)]), Color("#bd5e32"))
	draw_polyline(PackedVector2Array([Vector2(-2, -6), Vector2(2, -1), Vector2(1, 6)]),
		Color("#edbb69"), 2.2, true)
	draw_circle(Vector2(7, 1), 2.3, Color("#ffe097"))
	draw_set_transform(Vector2.ZERO)
	for index in 3:
		var t := fposmod(sim.time * 4.5 + index / 3.0, 1.0)
		draw_circle(at + Vector2(-8.0 - 21.0 * t, sin(t * TAU + index) * 4.0),
			2.0 - t, Color(1.0, 0.55, 0.23, 1.0 - t))
