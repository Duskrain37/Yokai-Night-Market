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

func background(canvas: CanvasItem, s) -> void:
	if not s.shore.enabled() or s.shore.map_key() != "island": return
	var d: Dictionary = s.shore.state
	var tex := texture("tide")
	if tex == null: return
	var u := clampf((s.time - float(d.tide_anim))/2.1,0,1)
	var index := clampi(roundi(31*(u if bool(d.wet) else 1-u)),0,31)
	var patch := Rect2(Vector2(1168./1672.,144./941.)*Geo.canvas_size,Vector2(504./1672.,666./941.)*Geo.canvas_size)
	canvas.draw_texture_rect_region(tex,patch,Rect2((index%8)*336,(index/8)*444,336,444))

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
	if float(d.fog_notice)>s.time:
		_label(canvas,at(s,Geo.BOARD_X+Geo.CELL_W*(float(d.fog_next_col)+.55),0)-Vector2(0,22),"岸雾将至",Color("#c7dbd5"))
	if float(d.tide_at)>s.time:
		var row := int(d.tide_lane) if int(d.tide_lane)>=0 else 0
		var p := at(s,Geo.BOARD_X+Geo.BOARD_W+24,row)
		var strength := float(.70+.15*sin(s.time*8))
		canvas.draw_circle(p,17,Color(.84,.49,.20,.17*strength),true,-1,true)
		canvas.draw_circle(p,5,Color(.94,.65,.32,strength),true,-1,true)
		_label(canvas,p-Vector2(43,15),"涨潮将至" if bool(d.tide_next) else "潮退 · 低栈将露")

func _cave(canvas:CanvasItem,s) -> void:
	var d: Dictionary = s.shore.state
	var gatex := Geo.BOARD_X + 8.0*Geo.CELL_W + 9
	for r in 4:
		var foot := at(s,gatex,r)+Vector2(0,22)
		var lowering := 0.0
		if r == int(d.gate_row):
			var ease_down := smoothstep(0,1,(s.time-float(d.gate_start))/.32)
			var ease_up := 1.0-smoothstep(0,1,(s.time-float(d.gate_until))/.44)
			lowering = minf(ease_up,ease_down)
		_sprite(canvas,"gate-panel",foot+Vector2(0,-41.0*(1-lowering)),28,Color(.76,.74,.65),1.3)
		_sprite(canvas,"gate",foot,78,Color(.76,.75,.69))
		if lowering > 0:
			canvas.draw_line(foot+Vector2(-19,-4),foot+Vector2(19,-4),Color(.76,.59,.40,.50*lowering),3,true)
	for b in d.bridges:
		var p := cell(s,int(b.col),int(b.row))+Vector2(0,17)
		var f := clampf((s.time-float(b.at))/.87,0,1)
		if bool(b.intact):
			_sprite(canvas,"bridge",p+Vector2(0,10*(1-f)),132,Color(.70,.69,.61,minf(1,.24+f)))
		elif f < 1.0:
			_sprite(canvas,"bridge",p+Vector2(4*f,28*f),132*(1-.19*f),Color(.65,.63,.58,1-f),1-.36*f)
			for i in 5:
				var q := p+Vector2((i-2)*(6+f*13),10+32*f-f*(1-f)*(15+i*4))
				canvas.draw_line(q,q+Vector2(6,i*1.3),Color(.60,.45,.28,1-f),2.3,true)
		elif int(d.wood)>0:
			_label(canvas,p+Vector2(0,6),"补桥",Color("#dec394"))
	if int(d.wood)>0:
		_label(canvas,cell(s,7,0)-Vector2(0,56),"木材  %d" % int(d.wood))
