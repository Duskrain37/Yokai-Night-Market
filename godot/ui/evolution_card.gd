## Successive book cards add bronze scrollwork, then a vermilion crowned seal.
extends PanelContainer
var tier := 1
var color := Color("#d1bd85")
func set_tier(value: int) -> void:
	tier=clampi(value,1,3);color=[Color("#c0b68d"),Color("#e7c277"),Color("#ffcf88")][tier-1]
	var base:Color=[Color("#172b29"),Color("#382a20"),Color("#421b22")][tier-1]
	var style:=Ui.flat(base,color.darkened(.38),9,1 if tier==1 else 2)
	style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=15;style.content_margin_bottom=15
	add_theme_stylebox_override("panel",style);queue_redraw()
func _draw() -> void:
	var ink:=Color(color,.24)
	draw_style_box(Ui.flat(Color.TRANSPARENT,ink,6,1),Rect2(Vector2(6,6),size-Vector2(12,12)))
	for side in [0,1]:
		var x:=12.0 if side==0 else size.x-12;var sign_x:=1 if side==0 else -1
		for y in [12.0,size.y-12]:
			for i in tier:
				var c:=Vector2(x+sign_x*(i*8),y)
				draw_line(c-Vector2(0,4),c+Vector2(0,4),ink,1,true)
	if tier>=2:
		for i in int(size.x/75):
			var at:=Vector2(35+i*75,size.y-8)
			draw_arc(at,15,PI,TAU,12,Color(color,.16),1,true)
	if tier==3:
		var at:=Vector2(size.x*.5,8)
		draw_polyline(PackedVector2Array([at+Vector2(-28,0),at+Vector2(-16,-5),at+Vector2(-9,1),at+Vector2(0,-7),at+Vector2(9,1),at+Vector2(16,-5),at+Vector2(28,0)]),Color(color,.8),1.5,true)
static func node(value: int, selected: bool) -> Button:
	var button:=Ui.button(str(value),17,64,42,selected)
	button.set_meta("evolution_tier",value)
	button.draw.connect(func():
		var color:=Color("#f3d29a") if selected else Color("#aa936e")
		var c:=button.size*.5
		if value==1:button.draw_arc(c,14,0,TAU,28,Color(color,.65),1,true)
		elif value==2:
			button.draw_polyline(PackedVector2Array([c+Vector2(-22,0),c+Vector2(-15,-11),c+Vector2(-18,-15),c+Vector2(-9,-18)]),color,1.5,true)
			button.draw_polyline(PackedVector2Array([c+Vector2(22,0),c+Vector2(15,-11),c+Vector2(18,-15),c+Vector2(9,-18)]),color,1.5,true)
		else:
			button.draw_polyline(PackedVector2Array([c+Vector2(-23,-7),c+Vector2(-23,-16),c+Vector2(-12,-12),c+Vector2(0,-19),c+Vector2(12,-12),c+Vector2(23,-16),c+Vector2(23,-7)]),color,1.7,true)
			for x in [-12,0,12]:button.draw_circle(c+Vector2(x,-14),1.5,color))
	return button
