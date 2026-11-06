## Pure presentation: projections come from Geo; all events/clocks come from BossEncounter.
extends Node2D
const ActorFrames = preload("res://scripts/actor_frames.gd")
var actor_frames = ActorFrames.new()
var skill_frames = ActorFrames.new()
var sim: Sim
var textures: Dictionary={}
var sheets: Dictionary={}
var frames: Dictionary={}
var font: Font
var _boss_ref: WeakRef
var _pose="idle"
var _last_boss = null
var _defeated_boss = null
var _previous="idle"
var _pose_at=0.0

func _ready() -> void:
	z_index=20
	actor_frames.load_sheets("boss-")
	skill_frames.load_sheets("v052-")
	font=Ui.body_font()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_art_manifest.json"))
	for sheet in manifest.atlases:
		var name=String(sheet.file).get_file()
		sheets[name]=load("res://assets/boss/"+name)
		for f in sheet.frames:frames[name+":"+String(f.name)]=f
	for key in ["telegraph_tile","telegraph_ring","telegraph_lane","repair_mark","ground_shadow"]:
		textures[key]=load("res://assets/boss/"+key+".svg")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func _process(_delta: float) -> void:
	if sim != null:
		if _last_boss != null and not _last_boss.alive():
			_defeated_boss = _last_boss
		_last_boss = sim.boss
		if _defeated_boss != null and sim.time - float(_defeated_boss.died_at) >= 1.8:
			_defeated_boss = null
	if sim != null and sim.visual_hold:
		return
	queue_redraw()

func _point(flat: Vector2) -> Vector2:
	return Geo.to_screen(flat+Vector2(0,Geo.cell_h(sim.rows)*0.28),sim.rows)

func _frame(sheet: String, name: String, foot: Vector2, height: float, alpha: float=1.0, idle_scale: bool=false,deform: Vector2=Vector2.ONE) -> void:
	var f: Dictionary=frames.get(sheet+":"+name,{})
	if f.is_empty():return
	var r: Array=f.region
	var b: Array=f.alpha_bbox_local
	var anchor: Array=f.anchor_px
	if idle_scale:b=frames[sheet+":idle"].alpha_bbox_local
	var scale=height/maxf(1,float(b[3])-float(b[1]))
	draw_set_transform(foot,0,deform)
	draw_texture_rect_region(sheets[sheet],Rect2(-Vector2(anchor[0],anchor[1])*scale,Vector2(r[2],r[3])*scale),
		Rect2(r[0],r[1],r[2],r[3]),Color(1,1,1,alpha),false,true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _text(value: String,point: Vector2,size: int=20,color: Color=Color("#f0d9a9")) -> void:
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	if sim == null or sheets.is_empty(): return
	var boss = sim.boss if sim.boss != null else _defeated_boss
	if boss == null: return
	var body_foot = _body_foot(boss.body_row, boss)
	var sheet="boss_%s_atlas.png" % String(boss.id)
	var pose=String(boss.pose())
	if _boss_ref == null or _boss_ref.get_ref() != boss:
		_boss_ref = weakref(boss)
		_previous = pose
		_pose = pose
		_pose_at = sim.time - 0.1
	elif pose != _pose:
		_previous = _pose
		_pose = pose
		_pose_at = sim.time
	var mix=clampf((sim.time-_pose_at)/0.1,0,1)
	var alpha=1.0
	if not boss.alive():alpha=1.0-smoothstep(0.7,2.0,sim.time-float(boss.died_at))
	elif sim.time<float(boss.combat_at):alpha=clampf((sim.time-float(boss.began_at))/0.8,0,1)
	var bob=sin(sim.time*2.4)*1.4 if pose=="idle" else 0.0
	var upper_edge := _point(Vector2(boss.body_x(), sim.row_y(boss.body_row) - Geo.cell_h(sim.rows) * 0.5))
	var body_height := maxf(120.0, body_foot.y - upper_edge.y)
	draw_texture_rect(textures.ground_shadow,Rect2(body_foot-Vector2(105,40),Vector2(210,80)),false,Color(1,1,1,alpha))
	if _previous != _pose and mix < 1.0 and pose != "blink":
		_frame(sheet,_previous,body_foot,body_height,alpha*(1-mix),true)
	var impact=0.0
	for event in boss.effects:
		var age=sim.time-float(event.at)
		if age>=0 and age<.18 and String(event.kind) in ["earth","paper","water"]:impact=maxf(impact,sin(age/.18*PI))
	var action_pose = pose in ["anticipation", "small", "major", "hurt", "defeat"]
	var index = clampf((sim.time - _pose_at) * 8.0, 0.0, 3.99) if action_pose else sim.time * 5.0
	var actor = "boss-%s-%s" % [boss.id, pose]
	var combined: bool = not boss.id in ["earth", "paper", "river"]
	if combined:
		actor = "boss-%s" % boss.id
	var clip := "action" if action_pose else "idle"
	if combined:
		clip = "major" if pose == "major" and boss.id != "magistrate-bound" else ("small" if action_pose else "idle")
	if pose == "blink":
		_draw_blink(boss, body_foot, body_height)
	elif not actor_frames.draw_pose(self, actor, clip, index,
			body_foot, body_height, true, Color(1, 1, 1, alpha * mix)):
		_frame(sheet,pose,body_foot+Vector2(0,bob),body_height,alpha*mix,true,Vector2(1+impact*.035,1-impact*.06))
	for z in boss.props:
		if not z.alive():continue
		var at=_point(z.pos)
		var name=String(z.boss_meta.kind)
		if name=="crab":name="crab_charge"
		elif name=="paper_seal":
			at.y-=34
		_frame("props_atlas.png",name,at,72 if name=="paper_seal" else 83)
		var ratio=clampf(z.hp/maxf(1,z.max_hp),0,1)
		draw_rect(Rect2(at+Vector2(-25,5),Vector2(50,4)),Color(0.03,0.05,0.06,0.8))
		draw_rect(Rect2(at+Vector2(-25,5),Vector2(50*ratio,4)),Color("#c7a269"))
	if not boss.action.is_empty() and String(boss.state) in ["small_warning","major_warning","major_hits"]:
		_warning(boss)
		if String(boss.state) != "major_hits":
			_draw_cast_bar(boss, body_foot)
	for mark in boss.repair_marks:
		var at=_point(sim.cell_pos(int(mark.c),int(mark.r)))
		var a=clampf(float(mark.until)-sim.time,0,1)
		draw_texture_rect(textures.repair_mark,Rect2(at-Vector2(19,39),Vector2(38,38)),false,Color(1,1,1,a*0.8))
	for fx in boss.effects:
		var at=_point(Vector2(float(fx.x),float(fx.y)))
		var age=sim.time-float(fx.at)
		if age >= 0.0 and age < 1.15 and String(fx.kind) in ["earth", "paper", "water"]:
			var fx_clip := String({"magistrate-bound":"bound", "magistrate-full":"full"}.get(boss.id, boss.id))
			var opacity := minf(1.0, (1.15 - age) * 3.0)
			skill_frames.draw_pose(self, "v052-boss-fx", fx_clip, minf(3.99, age / 1.15 * 4.0),
				at + Vector2(0, 28), 220.0, false, Color(1, 1, 1, opacity))
		if String(fx.kind)=="break":_break(String(fx.prop),at,age)
		else:_effect(String(fx.kind),at,age)
	if not boss.alive():_effect("release",body_foot-Vector2(0,70),sim.time-float(boss.died_at),240)


func _body_foot(row: int, owner = null) -> Vector2:
	var boss = owner if owner != null else sim.boss
	return _point(Vector2(boss.body_x(), sim.row_y(row + 1) + Geo.cell_h(sim.rows) * 0.37))


func _draw_cast_bar(boss, foot: Vector2) -> void:
	var started := float(boss.action.get("warning_start", sim.time))
	var ends := float(boss.action.get("warning_end", sim.time))
	var ratio := clampf((sim.time - started) / maxf(0.01, ends - started), 0.0, 1.0)
	var rect := Rect2(foot + Vector2(-61.0, 7.0), Vector2(122.0, 12.0))
	Ui.draw_gauge(self, rect, ratio, Color("#d6a85b") if boss.state == "small_warning" else Color("#c85c48"))


func _draw_blink(boss, destination: Vector2, height: float) -> void:
	var elapsed = sim.time - float(boss.blink_at)
	var length = maxf(0.01, float(boss.state_end) - float(boss.blink_at))
	var t = clampf(elapsed / length, 0.0, 1.0)
	var origin = _body_foot(boss.blink_from)
	var actor = "boss-%s-anticipation" % boss.id
	var clip := "action"
	var landing = "boss-%s-idle" % boss.id
	if not boss.id in ["earth", "paper", "river"]:
		actor = "boss-%s" % boss.id
		landing = actor
		clip = "blink" if boss.id != "magistrate-full" else "idle"
	for i in 3:
		var progress = clampf(t * 1.4 - i * 0.15, 0.0, 1.0)
		var at = origin.lerp(destination, progress)
		actor_frames.draw_pose(self, actor, clip, minf(3.99, progress * 4.0),
			at, height, true, Color(0.67, 0.83, 0.88, sin(t * PI) * (0.58 - 0.12 * i)))
	actor_frames.draw_pose(self, landing, "idle", t * 7.0, destination, height,
		true, Color(1, 1, 1, smoothstep(0.43, 1.0, t)))

func _warning(boss) -> void:
	var action: Dictionary=boss.action
	var major=String(action.kind)=="major"
	var fx_clip := String({"magistrate-bound":"bound", "magistrate-full":"full"}.get(boss.id, boss.id))
	var age: float = sim.time - float(action.get("warning_start", sim.time))
	var end := float(action.get("warning_end", sim.time))
	var span := maxf(0.01, end - float(action.get("warning_start", sim.time)))
	var power := clampf(age / span, 0.0, 1.0)
	skill_frames.draw_pose(self, "v052-boss-fx", fx_clip, power * 1.4,
		_body_foot(boss.body_row) + Vector2(-38, -18), 185.0 + 65.0 * power,
		false, Color(1, 1, 1, 0.45 + power * 0.35))
	for i in Array(action.targets).size():
		var cell: Dictionary=action.targets[i]
		var impact=float(action.warning_end)+(i*float(boss.config.major.hit_spacing_s) if major else 0.0)
		if sim.time>impact+0.18:continue
		var corners: PackedVector2Array=Geo.screen_cell_polygon(int(cell.c),int(cell.r),sim.rows)
		var at=_point(sim.cell_pos(int(cell.c),int(cell.r)))
		var rect=Rect2(corners[0],Vector2.ZERO)
		for p in corners:rect=rect.expand(p)
		draw_texture_rect(textures.telegraph_tile,rect,false)
		var center=rect.get_center()
		draw_texture_rect(textures.telegraph_ring,Rect2(center-Vector2(30,30),Vector2(60,60)),false)
		var remaining=clampf((impact-sim.time)/maxf(0.1,impact-float(action.warning_start)),0,1)
		draw_arc(center,34,-PI/2,-PI/2+TAU*remaining,40,Color("#f5daa5"),3,true)
		_text(str(i+1) if major else "!",center+Vector2(-8,9),26)
		if String(action.kind)=="crab" or (major and String(boss.id)!="earth"):
			var edge=_point(Vector2(Geo.SPAWN_X,sim.row_y(int(cell.r))))
			draw_texture_rect(textures.telegraph_lane,Rect2(Vector2(at.x+40,center.y-12),Vector2(maxf(10,edge.x-at.x-40),24)),false)

func _effect(kind: String, at: Vector2,age: float,size_px: float=140) -> void:
	if age<0 or age>0.75:return
	var first=mini(2,int(age/0.75*3))
	var blend=age/0.75*3-first
	var scale=lerpf(0.8,1.12,age/0.75)
	var families=["earth","paper","water","release"]
	if not families.has(kind):return
	for i in 2:
		var f: Dictionary=frames["fx_atlas.png:%s_%d" % [kind,first+i]]
		var r: Array=f.region
		var sz=size_px*scale
		var weight=1-blend if i==0 else blend
		draw_texture_rect_region(sheets["fx_atlas.png"],Rect2(at-Vector2(sz/2,sz*0.85),Vector2(sz,sz)),
			Rect2(r[0],r[1],r[2],r[3]),Color(1,1,1,weight*(1-smoothstep(0.55,0.75,age))),false,true)

func _break(kind: String, at: Vector2,age: float) -> void:
	var paper=kind in ["paper_ferry","paper_seal"]
	var duration=0.9 if paper else 0.65
	if age>duration:return
	var name={"tunnel":"tunnel_broken","paper_ferry":"paper_ferry_broken","paper_seal":"paper_seal","crab":"crab_broken"}.get(kind,"tunnel_broken")
	var f: Dictionary=frames["props_atlas.png:"+String(name)]
	var b: Array=f.alpha_bbox_local
	var r: Array=f.region
	var width=float(b[2]-b[0]);var height=float(b[3]-b[1])
	var scale=90/maxf(width,height)
	for i in 5:
		var source=Rect2(r[0]+b[0]+width*i/5.0,r[1]+b[1],width/5.0,height)
		var spin=(-1 if i<2 else 1)*(1.2+i*0.16)
		var pos=at+Vector2((i-2)*width*scale/5.0+(i-2)*28*age,-height*scale/2-(70+i*9)*age+190*age*age)
		draw_set_transform(pos,spin*age,Vector2(scale,scale))
		draw_texture_rect_region(sheets["props_atlas.png"],Rect2(-source.size/2,source.size),source,
			Color(1,1,1,1-smoothstep(duration*0.5,duration,age)),false,true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	_effect("paper" if paper else ("water" if kind=="crab" else "earth"),at,age,105)
