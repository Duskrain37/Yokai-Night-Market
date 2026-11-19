extends Control

const Geo = preload("res://scripts/geo.gd")
var guest: Sim.Zombie
var sim: Sim
var unit_view
var _last_tide := ""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func watch(target: Sim.Zombie) -> void:
	guest=target
	queue_redraw()

func _process(_dt: float) -> void:
	if guest != null and (not guest.alive() or not sim.zombies.has(guest)): guest=null
	var text:=_tide_notice()
	if guest != null or text!=_last_tide:
		_last_tide=text
		queue_redraw()

func _tide_notice() -> String:
	if sim==null or not sim.shore.enabled() or sim.shore.map_key()!="island": return ""
	var d: Dictionary=sim.shore.state
	return String(d.tide_text) if sim.time<float(d.tide_text_until) else ""

func _draw() -> void:
	var tide:=_tide_notice()
	if not tide.is_empty():
		var plaque:=Rect2(Vector2(size.x*.5-104,size.y*.882),Vector2(208,42))
		Ui.draw_plate(self,plaque,Color(.075,.135,.148,.92),Color("#9d875f"),12,1)
		draw_string(Ui.display_font(),plaque.position+Vector2(0,29),tide,HORIZONTAL_ALIGNMENT_CENTER,plaque.size.x,22,Color("#f1d7a0"))
	if guest==null: return
	var foot: Vector2=unit_view.guest_anchor(guest)
	var lines: Array=sim.guest_status_lines(guest)
	var dims:=Vector2(258,84+22*lines.size())
	var pos:=Vector2(foot.x+28,foot.y-dims.y-22)
	if pos.x+dims.x > size.x-20: pos.x=foot.x-dims.x-28
	pos.x=clampf(pos.x,18,maxf(18,size.x-dims.x-18))
	pos.y=clampf(pos.y,130,maxf(130,size.y-dims.y-20))
	Ui.draw_plate(self,Rect2(pos,dims),Color(.063,.106,.118,.94),Color("#9e7949"),15)
	var font:=Ui.body_font()
	var name:=String(guest.def.get("name","恶客"))
	draw_string(Ui.display_font(),pos+Vector2(15,29),name,HORIZONTAL_ALIGNMENT_LEFT,dims.x-28,23,Color("#f0d7a0"))
	Ui.draw_gauge(self,Rect2(pos+Vector2(15,38),Vector2(dims.x-30,9)),guest.hp/maxf(1,guest.max_hp),Color("#b76145"))
	var hp:="气血 %d / %d" % [ceili(guest.hp),ceili(guest.max_hp)]
	if guest.armor>0: hp+="  ·  护具 %d" % ceili(guest.armor)
	draw_string(font,pos+Vector2(15,68),hp,HORIZONTAL_ALIGNMENT_LEFT,dims.x-25,16,Color("#e7d8bf"))
	for i in lines.size():
		var line: Dictionary=lines[i]
		draw_string(font,pos+Vector2(15,90+22*i),line.text,HORIZONTAL_ALIGNMENT_LEFT,dims.x-25,16,line.ink)
