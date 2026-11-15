## Engraved danger plaques share one language across preparation and battle.
extends PanelContainer
var risk := 0
var accent := Color("#b5a17b")
var summary := false
static func tone(tier: int, maximum: int) -> Color:
	if tier<=0:return Color("#ab9973")
	if maximum==1:return Color("#f16e59")
	if tier==1:return Color("#edc65c")
	return Color("#df4f54") if maximum>=3 and tier==2 else Color("#e28d89")
func set_risk(tier: int, maximum: int = 3, total: bool = false) -> void:
	risk=3 if maximum==2 and tier==2 else 2 if maximum==1 and tier==1 else tier
	summary=total;accent=tone(tier,maximum)
	var base:=Color("#142323") if risk==0 and not total else Color("#38291b") if risk==1 else Color("#48191e") if risk==2 else Color("#2d0d18")
	if total and tier==0:base=Color("#421d20");accent=Color("#e8a889")
	var style:=Ui.flat(base,accent.darkened(.28),10,2)
	style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=13;style.content_margin_bottom=13
	add_theme_stylebox_override("panel",style)
	queue_redraw()
func _draw() -> void:
	var r:=Rect2(Vector2(6,6),size-Vector2(12,12));var faint:=Color(accent,.18)
	draw_style_box(Ui.flat(Color.TRANSPARENT,Color(accent,.24),7,1),r)
	for edge in [0,1]:
		var x:=12.0 if edge==0 else size.x-12
		var sign_x:=1.0 if edge==0 else -1.0
		for bottom in [false,true]:
			var y:=12.0 if not bottom else size.y-12;var sign_y:=1.0 if not bottom else -1.0
			var at:=Vector2(x,y)
			draw_polyline(PackedVector2Array([at+Vector2(0,25*sign_y),at,at+Vector2(25*sign_x,0)]),Color(accent,.72),1.5,true)
			for i in 3:
				var c:=at+Vector2((6+i*7)*sign_x,(6+i*3)*sign_y)
				draw_polyline(PackedVector2Array([c+Vector2(-3*sign_x,0),c+Vector2(0,-3*sign_y),c+Vector2(3*sign_x,0),c+Vector2(0,3*sign_y),c+Vector2(-3*sign_x,0)]),Color(accent,.32),1,true)
	for i in maxi(1,int(size.x/72)):
		var x:=42.0+i*72
		draw_arc(Vector2(x,size.y-9),15,PI,TAU,12,faint,1,true)
		if summary or risk>=2:
			draw_line(Vector2(x-7,10),Vector2(x,17),faint,1,true);draw_line(Vector2(x,17),Vector2(x+7,10),faint,1,true)
	if risk>=3:
		for i in 6:draw_line(Vector2(size.x-85+i*10,8),Vector2(size.x-105+i*10,size.y-8),Color(accent,.035),5,true)
static func emblem(id: String, width: float = 54) -> Control:
	var node:=Control.new();node.custom_minimum_size=Vector2(width,width);node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.draw.connect(func():draw_emblem(node,node.size*.5,id,width/54.0))
	return node
static func draw_emblem(c: CanvasItem, at: Vector2, id: String, scale: float = 1) -> void:
	var ink:=Color.WHITE;c.draw_set_transform(at,0,Vector2.ONE*scale)
	c.draw_arc(Vector2.ZERO,23,0,TAU,48,Color(ink,.38),1,true)
	var shape:=PackedVector2Array()
	match id:
		"light_pack":shape=PackedVector2Array([Vector2(-8,-11),Vector2(8,-11),Vector2(15,11),Vector2(8,17),Vector2(-8,17),Vector2(-15,11),Vector2(-8,-11)])
		"price":
			for i in 3:c.draw_arc(Vector2(-6+i*6,9-i*8),9,0,TAU,24,ink,2,true);c.draw_rect(Rect2(Vector2(-8+i*6,7-i*8),Vector2(4,4)),ink,false,1)
		"curfew":
			c.draw_rect(Rect2(-15,-14,30,31),ink,false,2)
			for i in 4:c.draw_line(Vector2(-11+i*7,-13),Vector2(-11+i*7,16),ink,2,true)
			c.draw_line(Vector2(-19,-17),Vector2(19,-17),ink,2,true)
		"swarm","boss_power","twins":
			for x in ([-9.0,9.0] if id=="twins" else [0.0]):
				var center:=Vector2(x,0);var k:=.65 if id=="twins" else 1.0
				c.draw_arc(center,13*k,0,TAU,24,ink,2,true)
				for sign_x in [-1,1]:
					c.draw_line(center+Vector2(sign_x*10,-9)*k,center+Vector2(sign_x*16,-19)*k,ink,2,true)
					c.draw_line(center+Vector2(sign_x*8,-3)*k,center+Vector2(sign_x*3,1)*k,ink,2,true)
				c.draw_line(center+Vector2(-5,8)*k,center+Vector2(5,8)*k,ink,2,true)
			if id=="swarm":
				for x in [-17,17]:c.draw_circle(Vector2(x,12),3,ink)
		"early","rush":
			for i in (3 if id=="rush" else 2):c.draw_polyline(PackedVector2Array([Vector2(-16+i*11,-12),Vector2(-6+i*11,0),Vector2(-16+i*11,12)]),ink,3,true)
		"dim":
			c.draw_rect(Rect2(-12,-12,24,26),ink,false,2);c.draw_line(Vector2(0,-20),Vector2(0,-12),ink,2,true)
			c.draw_line(Vector2(-17,-16),Vector2(17,18),ink,3,true)
		"loss","seeds":
			for x in ([-11,0,11] if id=="seeds" else [0]):
				c.draw_arc(Vector2(x,0),6 if id=="seeds" else 14,-PI*.8,PI*.8,20,ink,2,true)
				c.draw_line(Vector2(x,-11),Vector2(x,13),ink,2,true)
			if id=="loss":c.draw_polyline(PackedVector2Array([Vector2(-12,-14),Vector2(1,-5),Vector2(-5,3),Vector2(13,15)]),ink,2,true)
		"unguarded":
			shape=PackedVector2Array([Vector2(-15,-13),Vector2(15,-13),Vector2(12,9),Vector2(0,20),Vector2(-12,9),Vector2(-15,-13)])
			c.draw_polyline(PackedVector2Array([Vector2(0,-13),Vector2(-4,-2),Vector2(4,4),Vector2(0,18)]),ink,2,true)
		"no_capstone":
			for i in 3:c.draw_rect(Rect2(-15+i*10,10-i*10,10,8+i*10),ink,false,2)
			c.draw_line(Vector2(-17,-16),Vector2(17,17),ink,3,true)
		"one_path":
			c.draw_line(Vector2(0,18),Vector2(0,-17),ink,3,true);c.draw_polyline(PackedVector2Array([Vector2(-14,-1),Vector2(0,-12),Vector2(14,-1)]),ink,2,true)
		"no_ash":
			shape=PackedVector2Array([Vector2(-13,12),Vector2(-10,-2),Vector2(-2,3),Vector2(1,-19),Vector2(13,-2),Vector2(14,10),Vector2(4,18),Vector2(-5,18),Vector2(-13,12)])
			c.draw_line(Vector2(-17,-16),Vector2(17,18),ink,3,true)
		_:
			c.draw_arc(Vector2.ZERO,14,0,TAU,24,ink,2,true)
	if not shape.is_empty():c.draw_polyline(shape,ink,2,true)
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
static func level_bar(tier: int, maximum: int) -> Control:
	var bar:=Control.new();bar.custom_minimum_size=Vector2(118,12);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.set_meta("tier",tier);bar.set_meta("maximum",maximum)
	bar.draw.connect(func():
		var level:=int(bar.get_meta("tier"));var cap:=int(bar.get_meta("maximum"));var color:=tone(level,cap);var cell:float=(bar.size.x-5*(cap-1))/cap
		for i in cap:
			var rect:=Rect2(Vector2(i*(cell+5),1),Vector2(cell,10))
			bar.draw_style_box(Ui.flat(Color(color,.8) if i<level else Color("#172323"),Color(color,.65),3,1),rect))
	return bar
