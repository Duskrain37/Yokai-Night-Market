extends AcceptDialog
const Delta=preload("res://scripts/delta_update.gd")
var game
var updater
var _text: Label
var _bar: ProgressBar
var _detail: Label
var _action: Button
var _close: Button
var _leaving=false
func _ready():
	transient=true;exclusive=true
	Ui.style_dialog(self);title="夜市新讯 · 检查更新";min_size=Vector2i(840,480)
	get_ok_button().hide()
	size=Vector2i(840,480)
	var margin=MarginContainer.new();margin.custom_minimum_size=Vector2(780,360)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,26)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var box=Ui.vbox(18);margin.add_child(box)
	box.add_child(Ui.title("为下一夜备好新笺",30,Ui.GOLD_BRIGHT))
	_text=Ui.label("",21,Ui.TEXT);_text.custom_minimum_size.x=700;_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(_text)
	_bar=ProgressBar.new();_bar.custom_minimum_size=Vector2(0,22);_bar.show_percentage=false
	_bar.add_theme_stylebox_override("background",Ui.flat(Color("#101b1d"),Ui.GOLD_DIM,11,1))
	_bar.add_theme_stylebox_override("fill",Ui.flat(Color("#bc8c47"),Ui.GOLD_BRIGHT,11,1));box.add_child(_bar)
	_detail=Ui.label("",16,Ui.TEXT_DIM);_detail.custom_minimum_size.x=700;_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(_detail)
	box.add_child(Ui.spacer(8))
	var row=Ui.hbox(14);box.add_child(row)
	_action=Ui.button("检查更新",22,330,54,true);row.add_child(_action)
	_close=Ui.button("返回夜市",19,230,48);row.add_child(_close)
	updater=Delta.new();add_child(updater);updater.changed.connect(_refresh)
	_action.pressed.connect(_act);_close.pressed.connect(_leave);canceled.connect(_leave)
	_refresh();call_deferred("_act")
func _act():
	if updater.phase=="ready":
		if updater.install():game.save_progress();game.get_tree().quit()
	else:updater.start(game.VERSION,OS.get_executable_path())
func _leave():
	if updater.phase in ["checking","scanning","downloading","assembling"]:
		_leaving=true;updater.cancel();_refresh();return
	hide();queue_free()
func _refresh():
	if _leaving and updater.phase in ["cancelled","failed","idle"]:
		hide();call_deferred("queue_free");return
	_text.text=updater.message;_bar.value=updater.progress*100
	var busy=updater.phase in ["checking","scanning","downloading","assembling"]
	_action.disabled=busy;_action.text="重启并完成更新" if updater.phase=="ready" else "重新检查" if updater.phase in ["failed","cancelled"] else "检查更新"
	_close.text="停止更新" if busy else "返回夜市"
	_bar.visible=busy or updater.phase=="ready"
	_detail.text="当前版本 v%s"%game.VERSION
	if updater.phase=="downloading":_detail.text+=" · 已下载%s / 约%s"%[Delta.bytes_text(updater.received+updater.http.get_downloaded_bytes()),Delta.bytes_text(updater.required)]
	elif updater.phase=="ready":_detail.text+=" · 准备就绪，重启前不会替换当前游戏。"
