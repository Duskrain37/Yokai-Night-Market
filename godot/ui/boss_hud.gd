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
	var boss=game.sim.boss
	var left = 400.0
	var top = 132.0
	var width = 820.0
	Ui.draw_plate(self, Rect2(left, top, width, 61.0), Color("#151c23"),
		Color("#a78353"), 20, 2)
	var ratio = clampf(float(boss.hp) / maxf(1.0, float(boss.max_hp)), 0.0, 1.0)
	var trough = Rect2(left + 24.0, top + 33.0, width - 48.0, 16.0)
	Ui.draw_gauge(self, trough, ratio, Color("#a94c36"))
	for threshold in boss.config.major_thresholds:
		var color = Color("#806446") if boss.fired.has(threshold) else Color("#f3ce8b")
		draw_circle(Vector2(trough.position.x + trough.size.x * float(threshold),
			trough.get_center().y), 3.5, color)
	var status = "退散" if not boss.alive() else ("破绽 · 伤害提高25%" if boss.state == "recovery"
		else "守住首领所在的两行")
	draw_string(font,Vector2(left+28,top+26),"%s · %s" % [String(boss.config.name),status],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("#f1d9ad"))
	draw_string(font,Vector2(left+width-158,top+25),"%d / %d" % [ceili(boss.hp),ceili(boss.max_hp)],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#fae7c8"))
