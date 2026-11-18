## One short player-facing introduction on the first ordinary visit to each chapter.
extends Control
signal acknowledged
const Art = preload("res://ui/market_art.gd")
const NOTES = [
	["守住这条街", "五条街道都从右边来客。先请红灯笼攒香火，再给每一行安排能出手的草木。", "前排留给石磨，火力放在后面。香火够了别忘升阶，路尽头的门神只能替你挡一次。"],
	["杂物后的来客", "河埠口有六条栈道，靠右的杂物会占住一些位置，恶客却能翻过去。", "先看清能种的位置。逐云鸢、汤圆仔的抛射能越过杂物，别只守最顺手的几行。"],
	["水上也要留灯", "第二、第四行是水路。大多数草木需要先铺一叶夜莲，才能在水面落脚。", "记得携带夜莲，也给水路留火力。缠魂藻能拖沉水中的恶客，追魂与抛射可以照应邻行。"],
	["窄处留后手", "孤岛两侧摊面较窄，中间两行最宽。落石也会占住摊位，恶客能翻过去。", "先从宽处布阵，再补齐两翼。不能种的边角仍能走过，六行都要守到同一条门线。"],
	["辨清水与断台", "洞窟里的水道会沿街弯折，断裂的石台不能种植，恶客会跨过断口。", "先看地面再落子：水面先铺夜莲，坑口后方留拦路草木。分开安置火力，别把一行的希望全押在一株上。"],
	["铜铃响，云台换", "右侧三列石台始终稳固。通常开局两台都升着，七十秒后先落下一台，此后每四十秒轮换；每三十秒，两台还会前后各错开两格。铜铃会提前八秒报升降。", "草木随台移动；落入云中仍可种植、铲除和升阶。产能草木在云中照常运作，其余草木要等浮台升起。开启噩梦因子「云中绝香」后，产能草木也会暂歇。"],
	["听锣，留意借道", "第七、八列是戏班通道，不能种草木。挥袖引路时，三组斜巷同时借道：第二、四、六行转往上一行，或反过来。借道途中仍能打中，但只承受一半伤害。", "相邻两行互相照应。催场锣会让通道中所有恶客的脚步快五成，用石磨接住，或用铜铃缓一缓。"],
	["灯亮处，客将来", "开市前，三盏市灯中的一盏会先报信。哪一盏亮起由市灯自己决定，随后一半客人会涌向它照着的两条街。", "灯光不会替草木助战。给六行都留底子，再用留下的香火支援亮灯的两路；客潮散去后，准备下一次转灯。"],
]
var week := 1
var _done := false

func _ready() -> void:
	name = "ChapterGuide"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	var shade := ColorRect.new()
	shade.color = Color(.015,.035,.045,.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = Ui.panel()
	panel.custom_minimum_size = Vector2(730,0)
	center.add_child(panel)
	var box = Ui.vbox(17)
	panel.add_child(box)
	var data: Array = NOTES[clampi(week-1,0,7)]
	box.add_child(Ui.label("初到%s · 守夜小记" % Content.DAYS[week-1].sub,17,Ui.TEXT_DIM))
	box.add_child(Ui.title(data[0],36))
	box.add_child(Ui.hline(Color(Ui.GOLD_DIM,.5)))
	for index in [1,2]:
		var line = Ui.label(data[index],21)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 680
		box.add_child(line)
	var note = Ui.label("看完再开张，这会儿街上的时间是停着的。",16,Ui.TEXT_DIM)
	box.add_child(note)
	var go = Ui.button("记下了 · 点灯开张",23,0,60,true)
	go.pressed.connect(_acknowledge)
	box.add_child(go)
	go.grab_focus()
	Art.enter(panel)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11: return
		if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not event.echo: _acknowledge()
		get_viewport().set_input_as_handled()

func _acknowledge() -> void:
	if _done: return
	_done = true
	acknowledged.emit()
	queue_free()
