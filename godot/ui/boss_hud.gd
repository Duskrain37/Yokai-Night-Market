extends Control
var game
var font: Font

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=Ui.body_font()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game.sim==null or game.sim.boss==null:return
	var members: Array=game.sim.active_bosses()
	if members.size()>1:
		for index in members.size():_draw_member(members[index],index,members.size())
		return
	var boss=game.sim.boss
	if game.mobile:
		if game.hud!=null and game.hud._banner_band!=null and game.hud._banner_band.visible:return
		_draw_mobile(boss)
		return
	var left = 400.0
	var top = 148.0
	var width = 820.0
	draw_style_box(MarketArt.surface("panel", "normal", Vector2.ZERO), Rect2(left, top, width, 61.0))
	var ratio = clampf(float(boss.hp) / maxf(1.0, float(boss.max_hp)), 0.0, 1.0)
	var trough = Rect2(left + 24.0, top + 33.0, width - 48.0, 16.0)
	Ui.draw_gauge(self, trough, ratio, Color("#a94c36"))
	for threshold in boss.config.major_thresholds:
		var color = Color("#806446") if boss.fired.has(threshold) else Color("#f3ce8b")
		draw_circle(Vector2(trough.position.x + trough.size.x * float(threshold),
			trough.get_center().y), 3.5, color)
	var status = " · 退散" if not boss.alive() else (" · 破绽 · 伤害提高25%" if boss.state == "recovery" else "")
	draw_string(font,Vector2(left+28,top+26),String(boss.config.name) + status,HORIZONTAL_ALIGNMENT_LEFT,-1,Ui.font_size(17),Color("#f1d9ad"))
	draw_string(font,Vector2(left+width-158,top+25),"%d / %d" % [ceili(boss.hp),ceili(boss.max_hp)],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#fae7c8"))

func _draw_mobile(boss) -> void:
	var rect:=Rect2(300,138,1116,84)
	Ui.draw_plate(self,rect,Color("#151c23"),Color("#a78353"),22,2)
	var ratio:=clampf(float(boss.hp)/maxf(1.0,float(boss.max_hp)),0,1)
	var trough:=Rect2(rect.position+Vector2(24,55),Vector2(rect.size.x-48,18))
	Ui.draw_gauge(self,trough,ratio,Color("#a94c36"))
	for threshold in boss.config.major_thresholds:
		draw_circle(Vector2(trough.position.x+trough.size.x*float(threshold),trough.get_center().y),4,Color("#806446") if boss.fired.has(threshold) else Color("#f3ce8b"))
	var suffix:=" · 退散" if not boss.alive() else (" · 破绽" if boss.state=="recovery" else "")
	draw_string(font,rect.position+Vector2(24,37),String(boss.config.name)+suffix,HORIZONTAL_ALIGNMENT_LEFT,750,Ui.font_size(28),Ui.GOLD_BRIGHT)
	draw_string(font,rect.position+Vector2(820,36),"%d / %d" % [ceili(boss.hp),ceili(boss.max_hp)],HORIZONTAL_ALIGNMENT_LEFT,-1,Ui.font_size(23),Ui.TEXT)

func member_rect(index: int,count: int) -> Rect2:
	var columns:=mini(2,count)
	var width:=1110.0/columns-10.0
	return Rect2(350.0+(index%columns)*(width+10.0),148.0+int(index/columns)*64.0,width,60)

func _draw_member(boss,index: int,count: int) -> void:
	var rect:=member_rect(index,count)
	draw_style_box(MarketArt.surface("panel", "normal", Vector2.ZERO), rect)
	var trough:=Rect2(rect.position+Vector2(18,37),Vector2(rect.size.x-36,13))
	Ui.draw_gauge(self,trough,clampf(boss.hp/maxf(1.0,boss.max_hp),0,1),Color("#ae493d") if index%2==0 else Color("#965b94"))
	var status: String="退散" if not boss.alive() else ("蓄势" if boss.state in ["small_warning","major_warning","major_hits"] else "")
	draw_string(font,rect.position+Vector2(18,25),"%s · %s %s" % [String(boss.config.name),str(index+1),status],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-170,Ui.font_size(16),Ui.GOLD_BRIGHT)
	draw_string(font,rect.position+Vector2(rect.size.x-160,25),"%d / %d" % [ceili(boss.hp),ceili(boss.max_hp)],HORIZONTAL_ALIGNMENT_LEFT,150,14,Ui.TEXT)
	for threshold in boss.config.major_thresholds:
		draw_circle(Vector2(trough.position.x+trough.size.x*float(threshold),trough.get_center().y),3,Color("#806446") if boss.fired.has(threshold) else Ui.GOLD_BRIGHT)
