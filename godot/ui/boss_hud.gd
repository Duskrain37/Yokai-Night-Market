extends Control
var game
var frame: Texture2D
var tick_texture: Texture2D
var font: Font

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame=load("res://assets/boss/boss_bar_frame.svg")
	tick_texture=load("res://assets/boss/threshold_tick.svg")
	font=Ui.body_font()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game.sim==null or game.sim.boss==null:return
	var boss=game.sim.boss
	var left=400.0;var top=132.0;var width=820.0
	draw_texture_rect(frame,Rect2(left,top,width,68),false)
	var ratio=clampf(float(boss.hp)/maxf(1,float(boss.max_hp)),0,1)
	draw_rect(Rect2(left+24,top+32,772*ratio,17),Color("#ad5140"))
	for threshold in boss.config.major_thresholds:
		var color=Color(0.7,0.7,0.7,0.35) if boss.fired.has(threshold) else Color.WHITE
		draw_texture_rect(tick_texture,Rect2(left+24+772*float(threshold)-6,top+28,12,25),false,color)
	var status="退散" if not boss.alive() else ("破绽 · 伤害提高25%" if boss.state=="recovery" else "击中命门即可伤及首领")
	draw_string(font,Vector2(left+28,top+26),"%s · %s" % [String(boss.config.name),status],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("#f1d9ad"))
	draw_string(font,Vector2(left+width-155,top+47),"%d / %d" % [ceili(boss.hp),ceili(boss.max_hp)],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#fae7c8"))
