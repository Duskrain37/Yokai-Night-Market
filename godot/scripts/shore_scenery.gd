extends RefCounted
## Local props follow board projection; the island tide uses aligned whole-scene frames.
const Geo = preload("res://scripts/geo.gd")
const ROOT = "res://assets/scenery/shore/"
var art: Dictionary = {}

func texture(id: String) -> Texture2D:
	if not art.has(id):
		var file := ROOT + id + ".webp"
		if not ResourceLoader.exists(file): return null
		art[id] = load(file)
	return art[id]

func at(s, x: float, row: int) -> Vector2:
	return Geo.to_screen(Vector2(x, s.row_y(row)), s.rows)

func cell(s, c: int, r: int) -> Vector2:
	return Geo.to_screen(s.cell_pos(c, r), s.rows)

func _sprite(canvas: CanvasItem, id: String, foot: Vector2, width: float, tint: Color = Color.WHITE, squish: float = 1.0) -> void:
	var tex := texture(id)
	if tex == null: return
	var h := width * float(tex.get_height()) / float(tex.get_width()) * squish
	canvas.draw_texture_rect(tex, Rect2(foot - Vector2(width*.5,h),Vector2(width,h)),false,tint)

func _label(canvas: CanvasItem, p: Vector2, text: String, ink: Color = Color("#f0d8a0")) -> void:
	var f := Ui.body_font()
	var w := f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	var pos := p-Vector2(w*.5,0)
	canvas.draw_rect(Rect2(pos+Vector2(-6,-16),Vector2(w+12,21)),Color(.065,.081,.079,.84))
	canvas.draw_string(f,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)

const TIDE_FRAMES := Vector2(416,484)

const GROUPS := {"day2":["dock","cargo","incense-boat","freight-boat"],"day3":["mat","buoy"],
		"day4":["island-ebb","island-flood","island-turn","fog-watch-lamp"],
		"day5":["cave-deck","cave-broken","cave-splinter","cave-gate-stone","cave-gate-grille"]}
static func resource_paths(key: String) -> Array[String]:
	var paths: Array[String] = []
	for name in GROUPS.get(key,[]): paths.append(ROOT+String(name)+".webp")
	if key=="day4": paths.append_array(["res://scripts/island_fog.gdshader","res://assets/scenery/cloud-veil.png"])
	return paths

func warm(key: String) -> void:
	for name in GROUPS.get(key,[]): texture(name)

func background(canvas: CanvasItem, s) -> void:
	if not s.shore.enabled() or s.shore.map_key() != "island": return
	var d: Dictionary = s.shore.state
	var age: float = float(s.time) - (float(d.tide_at) - s.shore.TIDE_TURN_TIME)
	var transition: bool = float(d.tide_at) >= 0 and age >= 0.0 and age < s.shore.TIDE_TURN_TIME
	var tex := texture("island-turn" if transition else ("island-flood" if d.wet else "island-ebb"))
	if tex == null: return
	var u := clampf(age/s.shore.TIDE_TURN_TIME,0,1)
	var index := roundi(31*(u if d.tide_next else 1-u)) if transition else posmod(floori(s.time*12.0),24)
	var patch := Rect2(Vector2(1075./1672.,124./941.)*Geo.canvas_size,Vector2(597./1672.,694./941.)*Geo.canvas_size)
	canvas.draw_texture_rect_region(tex,patch,Rect2(Vector2(index%8,index/8)*TIDE_FRAMES,TIDE_FRAMES))

func draw(canvas: CanvasItem, s) -> void:
	if not s.shore.enabled(): return
	match s.shore.map_key():
		"market": _market(canvas,s)
		"water": _rivers(canvas,s)
		"island": _island(canvas,s)
		"cavern": _cave(canvas,s)

func _market(canvas:CanvasItem,s) -> void:
	var d: Dictionary = s.shore.state
	var end := Geo.BOARD_X + Geo.BOARD_W
	for r in s.shore.DOCK_ROWS:
		var foot := at(s,end+(46 if int(r)==1 else 92),int(r))
		_sprite(canvas,"dock",foot+Vector2(9,20),108,Color(.85,.80,.72))
	for c in d.cargo:
		if bool(c.removed): continue
		var p := cell(s,int(c.col),int(c.row)) + Vector2(0,22)
		var width := 95.0
		if c.has("hauled_at"):
			var t := smoothstep(0,1,(s.time-float(c.hauled_at))/1.25)
			var ship_pos := at(s,end+96,int(c.row))
			for b in d.boats:
				if not b.haul.is_empty() and b.haul.row==c.row and b.haul.col==c.col:
					ship_pos=at(s,end+96,int(b.row)); break
			p = p.lerp(ship_pos,t); width = lerpf(95,49,t)
			canvas.draw_line(p+Vector2(8,-20),ship_pos-Vector2(8,8),Color("#b6a27c"),2,true)
		_sprite(canvas,"cargo",p,width,Color(.90,.88,.80))
	for b in d.boats:
		var r := int(b.row)
		var f := smoothstep(0,1,(s.time-float(b.at))/maxf(.1,float(b.until)-float(b.at)))
		var offset := 95.0
		match String(b.phase):
			"in": offset=lerpf(310,145,f)
			"wait": offset=145
			"dock": offset=lerpf(145,95,f)
			"leave": offset=lerpf(95,320,f)
		var foot := at(s,end+offset+(15 if r==1 else 39),r)+Vector2(0,18+2*sin(s.time*4+r))
		_sprite(canvas,"freight-boat" if b.cargo else "incense-boat",foot,166,Color(.85,.86,.81),1+.024*sin(s.time*3+r))
		for i in 3:
			var y := float(i*5)
			canvas.draw_line(foot+Vector2(18+y,3+y),foot+Vector2(80+y,4+y),Color(.61,.80,.78,.27),1,true)
		if b.phase == "wait":
			_label(canvas,foot+Vector2(-40,-57),"候泊 %d" % ceili(float(b.until)-s.time))

func _rivers(canvas:CanvasItem,s) -> void:
	var d: Dictionary = s.shore.state
	for m in d.mats:
		var r := int(m.row)
		var p := cell(s,int(m.ends[0]),r)
		var q := cell(s,int(m.ends[1]),r)
		var rope := PackedVector2Array()
		for i in 17:
			var u := float(i)/16
			rope.append(p.lerp(q,u)+Vector2(0,22+7*sin(u*PI)+sin(s.time*2+u*4)))
		canvas.draw_polyline(rope,Color(.07,.10,.09,.75),4,true)
		canvas.draw_polyline(rope,Color(.55,.49,.34,.84),1.6,true)
		for f in [p,q]: _sprite(canvas,"buoy",f+Vector2(0,19),42,Color(.81,.84,.74))
		var foot := p if int(m.current)==0 else q
		if float(m.end)>s.time:
			foot=foot.lerp(q if int(m.to)==1 else p,smoothstep(0,1,(s.time-float(m.start))/(float(m.end)-float(m.start))))
		_sprite(canvas,"mat",foot+Vector2(0,22+1.5*sin(s.time*3)),108,Color(.80,.86,.76))
		var notice: bool = float(d.flow_at)>s.time
		var flow := (-1 if int(d.flow)>0 else 1) if notice else int(d.flow)
		flow*=1 if r==1 else -1
		if flow == 0: continue
		for j in 10:
			var drift := fposmod(float(j)*139+s.time*(25 if flow<0 else -32),Geo.BOARD_W)
			var f := at(s,Geo.BOARD_X+drift,r)+Vector2(0,23+9*sin(j*2.5+s.time*.7))
			canvas.draw_arc(f+Vector2(8,2),12,.3,2.5,12,Color(.61,.79,.69,.25),1,true)
			var k := Vector2(6*flow,2+sin(s.time*3+j)*1.2)
			canvas.draw_colored_polygon(PackedVector2Array([f-k,f+Vector2(-1,-4),f+k,f+Vector2(1,4)]),Color(.64,.69,.42,.72))
		if notice: _label(canvas,cell(s,5,r)+Vector2(0,37),"顺流将至" if flow>0 else "逆流将至",Color("#c6d8bc"))

func _island(canvas:CanvasItem,s) -> void:
	var d: Dictionary = s.shore.state
	var foot := Vector2(Geo.canvas_size.x*.83,Geo.canvas_size.y*.944)
	var notice: bool = float(d.fog_notice) > s.time
	var fog_now: bool = s.time >= float(d.fog_at) and s.time < float(d.fog_until)
	var amount := (.7+.3*sin(s.time*9)) if notice else (.48 if fog_now else .16)
	canvas.draw_circle(foot-Vector2(0,32),31,Color(.93,.65,.28,.24*amount),true,-1,true)
	_sprite(canvas,"fog-watch-lamp",foot,48,Color(.74+amount*.26,.76+amount*.24,.73+amount*.22))
	if notice or fog_now:
		var text := "雾至 · %d 秒" % ceili(float(d.fog_notice)-s.time) if notice else "海雾未散"
		_label(canvas,foot+Vector2(2,19),text,Color("#efe0af"))
	else: _label(canvas,foot+Vector2(2,19),"候雾灯",Color("#c7be9f"))

func _cave(canvas:CanvasItem,s) -> void:
	var d: Dictionary = s.shore.state
	var gatex := Geo.BOARD_X + 8.0*Geo.CELL_W + 9
	for r in 4:
		var foot := at(s,gatex,r)+Vector2(0,20)
		var lowering := 0.0
		if r == int(d.gate_row):
			var ease_down := smoothstep(0,1,(s.time-float(d.gate_start))/.32)
			var ease_up := 1.0-smoothstep(0,1,(s.time-float(d.gate_until))/.44)
			lowering = minf(ease_up,ease_down)
		# Both ends stay on the same crossing line as the collision stop.
		var scale := Geo.scale_at_flat(Vector2(gatex,s.row_y(r)),s.rows)
		var base := foot+Vector2(0,13)*scale
		canvas.draw_line(base+Vector2(7,-54)*scale,base+Vector2(-7,-5)*scale,Color(.035,.045,.04,.58),18*scale,true)
		_sprite(canvas,"cave-gate-stone",base,42*scale,Color(.79,.83,.79),1.38)
		# Guide timbers stand at either end; the grille rises in their slots.
		for marker in [Vector2(-14,-6),Vector2(15,-51)]:
			var peg: Vector2=base+marker*scale
			canvas.draw_line(peg+Vector2(-2,0),peg+Vector2(-2,-35)*scale,Color("#172222"),6*scale,true)
			canvas.draw_line(peg,peg+Vector2(0,-35)*scale,Color("#584a36"),3*scale,true)
			canvas.draw_circle(peg+Vector2(0,-33)*scale,2.2*scale,Color("#937850"),true,-1,true)
		_sprite(canvas,"cave-gate-grille",base+Vector2(0,-34+32*lowering)*scale,34*scale,Color(.84,.80,.69),1.33)
		if lowering > .2:
			canvas.draw_line(base+Vector2(7,-54)*scale,base+Vector2(-7,-5)*scale,Color(.76,.60,.34,.33*lowering),2*scale,true)
	for b in d.bridges:
		var c := int(b.col); var r := int(b.row)
		var p := cell(s,c,r)+Vector2(0,22)
		var f := clampf((s.time-float(b.at))/.84,0,1)
		var x_scale := 1.10 if c in [6,7] else 1.0
		var w := 145.0*x_scale
		_sprite(canvas,"cave-broken",p,w,Color(.80,.78,.73),.53)
		if bool(b.intact):
			_sprite(canvas,"cave-deck",p+Vector2(0,-8*(1-f)),w,Color(.80,.78,.73,f),.53)
		elif f < 1.0:
			for i in 5:
				var q := p+Vector2((i-2)*(8+f*15),-14+43*f*f-32*f*(1-f))
				canvas.draw_set_transform(q, f*(i-2)*.72)
				_sprite(canvas,"cave-splinter",Vector2.ZERO,25-i*2,Color(.80,.74,.68,1-f))
				canvas.draw_set_transform(Vector2.ZERO)
		elif int(d.wood)>0:
			_label(canvas,p+Vector2(0,6),"补桥",Color("#dec394"))
	if int(d.wood)>0:
		_label(canvas,cell(s,7,0)-Vector2(0,56),"木材  %d" % int(d.wood))
