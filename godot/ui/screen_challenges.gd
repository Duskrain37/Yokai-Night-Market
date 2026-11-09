extends Control
var game
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=TextureRect.new();bg.texture=load("res://assets/bg/menu.jpg");bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var dim=ColorRect.new();dim.color=Color(.02,.04,.06,.86);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(dim)
	var panel=Ui.panel(.95,Ui.GOLD,20,2);panel.position=Vector2(90,55);panel.size=Vector2(1420,790);add_child(panel)
	var box=Ui.vbox(14);panel.add_child(box)
	var head=Ui.hbox(20);box.add_child(head);var title=Ui.title("一夜重签",44);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
	var back=Ui.button("回封面",22,170,52);back.pressed.connect(game.show_menu);head.add_child(back)
	var intro=Ui.label("重守已经通关的夜晚。签题、三张草木和普通难度固定，十二分钟内守到天亮，只比留下的余香。每题保留本地前五名；使用调整的对局不入榜，也不覆盖守夜存档。",22);intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(intro)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	var body=Ui.vbox(18);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
	for entry in game.ChallengeRules.ENTRIES:
		var card=Ui.panel(.7,Ui.GOLD_DIM,16,1);body.add_child(card);var lines=Ui.vbox(8);card.add_child(lines)
		lines.add_child(Ui.title(entry.name,30))
		var level=Content.get_level(int(entry.level));var names=[]
		for id in entry.cards:names.append(Content.PLANTS[id].name)
		lines.add_child(Ui.label("%s · %s　｜　%s" % [level.day_name,level.name," / ".join(names)],20,Ui.GOLD))
		lines.add_child(Ui.label(entry.note,19))
		var rankings: Array=game.challenge_scores.get(entry.id,[])
		var scores=[]
		for i in rankings.size():scores.append("第%d名 %d香火" % [i+1,int(rankings[i].sun)])
		var ranking=Ui.label("还没有守夜成绩，等你来留一笔。" if scores.is_empty() else "　·　".join(scores),18,Ui.JADE_LIGHT)
		ranking.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lines.add_child(ranking)
		var unlocked=game._night_ids(game.progress.get("cleared",[])).has(int(entry.level))
		var start=Ui.button("重抽这一签" if unlocked else "先守住对应夜晚再来",22,440,54,unlocked);start.disabled=not unlocked;start.pressed.connect(func():game.start_challenge(entry.id));lines.add_child(start)
