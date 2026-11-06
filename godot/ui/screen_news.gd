extends Control

var game = null
var page := 0
var _content: VBoxContainer
var _tabs: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.04,0.05,0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var frame := Ui.panel(0.98,Ui.GOLD,18,2)
	frame.position=Vector2(70,45)
	frame.size=Vector2(1460,810)
	add_child(frame)
	var outer := Ui.vbox(12)
	frame.add_child(outer)
	var head := Ui.hbox(12)
	outer.add_child(head)
	head.add_child(Ui.seal("新"))
	var title := Ui.title("夜市新笺 · v%s" % game.VERSION,42 if game.mobile else 34)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := Ui.button("合上",32 if game.mobile else 22,170,86 if game.mobile else 56)
	back.pressed.connect(game.close_overlay)
	head.add_child(back)
	outer.add_child(Ui.hline(Ui.GOLD_DIM))
	var columns := Ui.hbox(24)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	outer.add_child(columns)
	var nav := Ui.vbox(14)
	nav.custom_minimum_size.x=230
	columns.add_child(nav)
	for i in 2:
		var tab := Ui.button(["更新公告","下载与反馈"][i],32 if game.mobile else 25,230,94 if game.mobile else 68)
		tab.pressed.connect(func(): select_page(i))
		nav.add_child(tab)
		_tabs.append(tab)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)
	_content=Ui.vbox(16)
	_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	select_page(0)

func select_page(value: int) -> void:
	page=value
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for i in _tabs.size(): _tabs[i].modulate=Color.WHITE if i==page else Color(0.7,0.7,0.7)
	if page==1:
		_content.add_child(Ui.title("下载正式版本",36))
		_add_text("电脑下载Windows可执行文件，双击即可开始；安卓手机下载APK并安装后，就能随时守夜。请从本项目的GitHub发布页获取更新。")
		for item in [["Windows 64位下载","https://github.com/Duskrain37/Yokai-Night-Market/releases/download/v0.5.3/YokaiNightMarket-win64.exe"],["安卓APK下载","https://github.com/Duskrain37/Yokai-Night-Market/releases/download/v0.5.3-mobile/YokaiNightMarket-android.apk"],["查看全部发布","https://github.com/Duskrain37/Yokai-Night-Market/releases"]]:
			_add_link(item[0],item[1])
		_content.add_child(Ui.title("欢迎来信",36))
		_add_text("无论是游玩感受、平衡建议，还是遇到的异常，都欢迎在GitHub提出Issue。遇到异常时，带上游戏版本、设备型号、截图和出现问题前的操作，会更方便查清缘由。")
		_add_link("在GitHub反馈建议","https://github.com/Duskrain37/Yokai-Night-Market/issues/new")
		return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/news_v053.json"))
	for section in data.sections:
		_content.add_child(Ui.title(String(section.title),36 if game.mobile else 28))
		for item in section.items:
			var panel := Ui.panel(0.64,Color(Ui.GOLD_DIM,0.45),12,1)
			_content.add_child(panel)
			var lines := Ui.vbox(7)
			panel.add_child(lines)
			lines.add_child(Ui.strong(String(item[0]),34 if game.mobile else 22,Ui.GOLD))
			var body := Ui.label(String(item[1]),32 if game.mobile else 20,Ui.TEXT)
			body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			lines.add_child(body)

func _add_text(value: String) -> void:
	var label := Ui.label(value,32 if game.mobile else 23,Ui.TEXT)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)

func _add_link(title: String, url: String) -> void:
	var button := Ui.button(title,32 if game.mobile else 25,500,96 if game.mobile else 64)
	button.pressed.connect(func(): OS.shell_open(url))
	_content.add_child(button)
	var label := Ui.label(url,24 if game.mobile else 17,Ui.TEXT_DIM)
	label.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
	_content.add_child(label)
