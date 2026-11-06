extends UpgradeFan

var _built := false
var _signature := ""
var _selected := 0
var _panel: PanelContainer
var _routes: Array[Button] = []
var _description: Label
var _effects: Label
var _confirm: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=5
	_panel=Ui.panel(0.98,Ui.GOLD,22,2)
	_panel.position=Vector2(280,205)
	_panel.size=Vector2(1160,650)
	add_child(_panel)
	var outer:=Ui.vbox(14)
	_panel.add_child(outer)
	var head:=Ui.hbox(16)
	outer.add_child(head)
	var title:=Ui.title("%s · 进化" % plant.def.name,42)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close:=Ui.button("收起",34,170,90)
	close.pressed.connect(func(): dismissed.emit())
	head.add_child(close)
	var row:=Ui.hbox(12)
	outer.add_child(row)
	for i in 3:
		var route:=Ui.button("",34,335,96)
		route.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		route.pressed.connect(func(): _selected=i;_refresh_preview())
		row.add_child(route)
		_routes.append(route)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var content:=Ui.vbox(18)
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_description=Ui.label("",36,Ui.TEXT)
	_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description)
	_effects=Ui.label("",30,Ui.JADE_LIGHT)
	_effects.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_effects)
	_confirm=Ui.button("",36,800,104,true)
	_confirm.pressed.connect(func():
		if _selected<entries.size() and bool(entries[_selected].ok) and bool(entries[_selected].affordable): picked.emit(int(entries[_selected].id)))
	outer.add_child(_confirm)
	_built=true

func _process(_delta: float) -> void:
	if not _built:return
	var signature:=JSON.stringify(entries)+str(roundi(sim.sun))
	if signature!=_signature:
		_signature=signature
		_refresh_preview()
	_effects.text="当前状态\n"+"\n".join(sim.plant_effect_lines(plant))

func _refresh_preview() -> void:
	if not _built or entries.is_empty(): return
	_selected=clampi(_selected,0,entries.size()-1)
	for i in _routes.size():
		_routes[i].visible=i<entries.size()
		if i<entries.size():
			_routes[i].text="%s · %d阶" % [entries[i].name,entries[i].tier]
			Ui.set_button_active(_routes[i],i==_selected)
	var entry: Dictionary=entries[_selected]
	_description.text="%s\n%s" % [entry.next_name,entry.next_desc]
	_confirm.disabled=not bool(entry.ok) or not bool(entry.affordable)
	_confirm.text="花%d香火进化" % int(entry.cost) if entry.ok else String(entry.reason)
	if entry.ok and not entry.affordable: _confirm.text="需要%d香火" % int(entry.cost)

func hit_test(at: Vector2) -> int:
	if _panel!=null and _panel.get_global_rect().has_point(at): return 0
	return -1
func _has_point(_at: Vector2) -> bool: return false
func _input(_event: InputEvent) -> void: pass
func _gui_input(_event: InputEvent) -> void: pass
func _draw() -> void: pass
