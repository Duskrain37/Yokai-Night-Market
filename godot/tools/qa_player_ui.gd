## Inspect instantiated player text and all prep launch bounds; no OS input.
extends SceneTree
var checks: Array=[]
var failures=0
var game
const BLOCKED=["白板","原稿","批复","公共控制","预算","写盘","短哈希","构建","主射弹","次级弹","每帧","开发者","DPS","地效","共享恶首生命"]
func check(name: String,ok: bool,detail: String="") -> void:
	checks.append({"name":name,"ok":ok,"detail":detail})
	if not ok:failures+=1;printerr("FAIL ",name," ",detail)
func text_of(node: Node) -> String:
	var result=""
	if node is Label or node is BaseButton or node is RichTextLabel:result+=String(node.text)+"\n"
	for child in node.get_children():result+=text_of(child)
	return result
func forbidden(value: String) -> String:
	var found: Array=[]
	for word in BLOCKED:
		if value.contains(word):found.append(word)
	return ",".join(found)
func buttons(node: Node) -> Array:
	var result: Array=[]
	if node is Button:result.append(node)
	for child in node.get_children():result.append_array(buttons(child))
	return result
func _init() -> void:call_deferred("run")
func run() -> void:
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	for id in range(1,17):
		game.show_prep(id);game.screen_node.skip_cinema()
		for i in 3:await process_frame
		var text=text_of(game.screen_node)
		check("关%d备战面向玩家" % id,forbidden(text)=="",forbidden(text))
		check("关%d不显示凶险系数" % id,not text.contains("威胁") and not text.contains("2.0×") and not text.contains("2.5×") and not text.contains("3.5×"))
		var launch=buttons(game.screen_node).filter(func(b):return b.text=="开战")
		check("关%d开战按钮完整可见" % id,launch.size()==1 and launch[0].get_global_rect().end.y<=Geo.VIEW.y)
	for tab in ["plant","zombie"]:
		game.open_almanac(tab,0)
		var book=game.screen_node
		for index in book._entries().size():
			book._select_entry(index)
			for i in 2:await process_frame
			var text=text_of(book)
			check("图鉴%s%d用语" % [tab,index],forbidden(text)=="",forbidden(text))
	for kind in Upgrades.TREES:
		for path in Upgrades.paths_for(kind):
			for tier in path.tiers:
				check("进化%s·%s" % [kind,String(tier.name)],forbidden(String(tier.desc))=="",String(tier.desc))
	game.open_settings()
	for i in 2:await process_frame
	var text=text_of(game.screen_node)
	check("设置不显示实现信息",forbidden(text)=="",forbidden(text))
	check("设置不列难度倍率",not text.contains("×1.25") and not text.contains("×1.5"))
	var f=FileAccess.open("res://qa/player-ui-tests.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "))
	print("PLAYER UI ",checks.size()," FAILURES ",failures)
	quit(0 if failures==0 else 1)
