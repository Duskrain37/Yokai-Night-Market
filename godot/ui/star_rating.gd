extends Control
var flags: Array=[false,false,false,false]
var factor_count:=0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(190,35)
	tooltip_text="金星：通关／至多惊动一次门神／不惊动门神。红星：噩梦通关。朱印：最佳因子数。"
func _draw() -> void:paint(self,Vector2(15,17),flags,factor_count,13.0)
static func paint(canvas: CanvasItem,at: Vector2,earned: Array,badge: int,radius: float=8.0) -> void:
	for index in 4:
		var center:=at+Vector2(index*radius*2.35,0)
		var color:=Color("#da6656") if index==3 else Ui.GOLD_BRIGHT
		var vertices:=PackedVector2Array()
		for vertex in 10:
			var angle:=-PI/2+vertex*PI/5
			vertices.append(center+Vector2(cos(angle),sin(angle))*radius*(1.0 if vertex%2==0 else 0.44))
		if bool(earned[index]):
			if index==3:
				canvas.draw_circle(center,radius*1.3,Color(0.7,0.13,0.1,0.15))
				canvas.draw_arc(center,radius*1.22,0,TAU,32,Color(0.86,0.37,0.25,0.65),1.0,true)
			canvas.draw_colored_polygon(vertices,color)
		else:
			vertices.append(vertices[0]);canvas.draw_polyline(vertices,Color(0.5,0.41,0.29,0.7),1.1,true)
	if badge>0 and bool(earned[3]):
		var point:=at+Vector2(radius*10.1,0)
		Ui.draw_plate(canvas,Rect2(point-Vector2(radius*1.15,radius*1.25),Vector2(radius*2.3,radius*2.5)),Color("#741e20"),Color("#e7a775"),10,1)
		canvas.draw_arc(point,radius*.92,0,TAU,32,Color(0.94,0.66,0.4,.55),.8,true)
		for tick in 4:
			var angle:=PI*.25+tick*PI*.5
			var offset:=Vector2(cos(angle),sin(angle))
			canvas.draw_line(point+offset*radius*1.15,point+offset*radius*1.42,Color(0.87,.61,.35,.7),1.0,true)
		var text:=str(badge)
		var font:=Ui.body_font();var fs:=roundi(radius*1.5)
		canvas.draw_string(font,point+Vector2(-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x/2,fs*.34),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("#ffe0ac"))
