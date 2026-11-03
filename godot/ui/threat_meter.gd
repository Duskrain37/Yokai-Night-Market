## Player-facing danger indication. The numeric coefficient never becomes UI text.
extends Control
var values: Array=[]
func _ready() -> void:
	custom_minimum_size=Vector2(220,16)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var count=maxi(1,values.size())
	var segment=(size.x-(count-1)*8)/count
	for i in values.size():
		var start=Vector2(i*(segment+8),4)
		draw_rect(Rect2(start,Vector2(segment,8)),Color(.1,.12,.12,.9))
		draw_rect(Rect2(start,Vector2(segment*clampf(float(values[i])/3.5,0,1),8)),Color("#b65d43"))
		draw_rect(Rect2(start,Vector2(segment,8)),Color("#997a50"),false,1)
