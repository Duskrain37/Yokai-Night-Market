## One short player-facing introduction on the first ordinary visit to each chapter.
extends Control
signal acknowledged
const Art = preload("res://ui/market_art.gd")
const NOTES = [
	["守住这条街", "五条街道都从右边来客。先请红灯笼攒香火，再给每一行安排能出手的草木。", "前排留给石磨，火力放在后面。香火够了别忘升阶，路尽头的门神只能替你挡一次。"],
	["船来之前，清一清码头", "靠右的货垛不能种植。香船与货船轮流来，靠岸前会选一个泊位；附近两格有来客，船只等八秒。", "清出泊位，香船能卸三百香火，货船会拖走一个货垛。留一手抛射，别让货垛挡了布阵。"],
	["听水声，看浮标", "第二、第四行是水路。漂叶会提前报信，顺流的恶客来得快，逆流的来得慢。", "夜莲可以承托草木；每条渠还各有一张浮席。拖向另一头空泊位，也可以直接点空泊位，浮席上的草木靠稳便接着出手。"],
	["雾落岸时，别只盯着中间", "海雾里的恶客容易躲开射弹，把草木摆近些能驱散周围的雾。涨潮时，外侧来客会游过右岸。", "退潮前会有岸灯报信。露出的低栈会让一小批恶客来得更快，给两翼留一手。"],
	["石闸可借，断桥能补", "点右侧石闸可以把还没过闸的客人拦在闸前五秒，给抛射和穿透一个机会。石闸每三十秒能用一次。", "旧木桥会在后半夜塌落。遇见旗帜波里的衔木客，打退它便可拾木补桥；点断口即可。"],
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
