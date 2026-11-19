extends AcceptDialog
const Delta = preload("res://scripts/delta_update.gd")
var game
var updater
var auto_start := true
var completion_pending := false
var _committing := false
var _text: Label
var _bar: ProgressBar
var _detail: Label
var _action: Button
var _close: Button
var _leaving := false
var _previous_auto_quit := true

func _ready():
	transient = true
	exclusive = true
	dialog_close_on_escape = false
	dialog_hide_on_ok = false
	Ui.style_dialog(self)
	title = "夜市新讯 · 检查更新"
	min_size = Vector2i(840, 480)
	get_ok_button().hide()
	size = Vector2i(840, 480)
	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(780, 360)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var box := Ui.vbox(18)
	margin.add_child(box)
	box.add_child(Ui.title("为下一夜备好新笺", 30, Ui.GOLD_BRIGHT))
	_text = Ui.label("", 21, Ui.TEXT)
	_text.custom_minimum_size.x = 700
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_text)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 28)
	_bar.show_percentage = true
	_bar.add_theme_stylebox_override("background", Ui.flat(Color("#101b1d"), Ui.GOLD_DIM, 11, 1))
	_bar.add_theme_stylebox_override("fill", Ui.flat(Color("#bc8c47"), Ui.GOLD_BRIGHT, 11, 1))
	box.add_child(_bar)
	_detail = Ui.label("", 16, Ui.TEXT_DIM)
	_detail.custom_minimum_size.x = 700
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail)
	box.add_child(Ui.spacer(8))
	var row := Ui.hbox(14)
	box.add_child(row)
	_action = Ui.button("检查更新", 22, 330, 54, true)
	row.add_child(_action)
	_close = Ui.button("返回夜市", 19, 230, 48)
	row.add_child(_close)
	updater = Delta.new()
	add_child(updater)
	updater.changed.connect(_refresh)
	_action.pressed.connect(_act)
	_close.pressed.connect(_secondary)
	canceled.connect(_leave)
	visibility_changed.connect(_protect_completion)
	game.get_window().close_requested.connect(_main_close)
	_refresh()
	if auto_start: call_deferred("_act")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		set_input_as_handled()
		if not completion_pending: _leave()

func _act():
	if completion_pending: _complete(true)
	else: updater.start(game.VERSION, OS.get_executable_path())

func _secondary() -> void:
	if completion_pending: _complete(false)
	else: _leave()

func _begin_completion() -> void:
	if completion_pending: return
	completion_pending = true
	_previous_auto_quit = game.get_tree().auto_accept_quit
	game.get_tree().auto_accept_quit = false
	borderless = true
	title = "更新已就绪"

func _complete(restart: bool) -> void:
	if _committing: return
	_committing = true
	_action.disabled = true
	_close.disabled = true
	if not _install_and_quit(restart):
		_committing = false
		completion_pending = false
		borderless = false
		title = "夜市新讯 · 检查更新"
		game.get_tree().auto_accept_quit = _previous_auto_quit
		_refresh()

func _install_and_quit(restart: bool) -> bool:
	game.save_progress()
	game.save_settings()
	game.save_records()
	if not updater.install(restart): return false
	game.get_tree().quit()
	return true

func _main_close() -> void:
	if completion_pending: _protect_completion()

func _protect_completion() -> void:
	if completion_pending and not visible and not _committing: call_deferred("popup_centered")

func _leave():
	if completion_pending:
		_protect_completion()
		return
	if updater.phase in ["checking", "scanning", "downloading", "assembling"]:
		_leaving = true
		updater.cancel()
		_refresh()
		return
	hide()
	queue_free()

func _refresh():
	if _leaving and updater.phase in ["cancelled", "failed", "idle"]:
		hide()
		call_deferred("queue_free")
		return
	_text.text = updater.message
	_bar.value = updater.progress * 100
	var busy: bool = updater.phase in ["checking", "scanning", "downloading", "assembling"]
	_action.disabled = busy
	_action.text = "重新检查" if updater.phase in ["failed", "cancelled"] else "检查更新"
	_close.disabled = false
	_close.text = "停止更新" if busy else "返回夜市"
	_bar.visible = busy or updater.phase == "ready"
	_detail.text = "当前版本 v%s · %s" % [game.VERSION, updater.work_detail()]
	if updater.phase == "ready":
		_begin_completion()
		_action.text = "完成更新并重启"
		_close.text = "完成更新"
		_close.disabled = _committing
		_action.disabled = _committing
		_detail.text = "v%s · 两种选项都会保存记录并关闭当前游戏。选择「完成更新」后，下次打开即进入更新后的游戏。" % updater.latest_version

func _exit_tree() -> void:
	if completion_pending and not _committing: game.get_tree().auto_accept_quit = _previous_auto_quit

