extends SceneTree
var checks=[]
var failures=0
var game
func check(label: String,ok: bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func _init():run.call_deferred()
func settle():
	for i in 8:await process_frame
func capture(name: String):
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/TempD/PersonalData/神秘创作/nightmarket/godot/qa/v056-"+name+".png")
	print("CAPTURE ",name)
func run():
	root.gui_embed_subwindows=true
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle();game.show_menu();await settle()
	var button=game.screen_node.find_child("CheckUpdate",true,false)
	check("封面有检查更新入口",button!=null and button.get_global_rect().end.x<1496)
	await capture("menu")
	for scale in [1.0,1.2]:
		Ui.text_scale=scale
		var dialog=load("res://ui/update_dialog.gd").new();dialog.game=game;game.screen_node.add_child(dialog);dialog.popup_centered();await settle()
		print("POPUP ",dialog.size," pos ",dialog.position," root ",root.get_visible_rect()," text ",dialog._text.size," min ",dialog._text.get_combined_minimum_size())
		for phase in ["checking","downloading","ready","failed"]:
			dialog.updater.latest_version="0.5.7";dialog.updater.required=65000000;dialog.updater.received=23000000;dialog.updater.progress=.35
			dialog.updater.state(phase,{"checking":"正在核对本地已有内容……","downloading":"已复用805.7 MB，本次约需下载62.0 MB。","ready":"更新已准备好。重启后即可进入 v0.5.7。","failed":"下载暂时中断或校验未通过。已校验内容会保留，下次检查可接着更新。"}[phase]);await settle()
			check("字号%.1f·%s完整窗口在视野内"%[scale,phase],dialog.position.y>=30 and dialog.position.y+dialog.size.y<root.get_visible_rect().size.y)
			check("字号%.1f·%s底部按钮在窗内"%[scale,phase],dialog._close.get_global_rect().end.y<dialog.size.y and dialog._action.get_global_rect().end.x<dialog.size.x)
			check("字号%.1f·%s按钮主次正确"%[scale,phase],dialog._action.size.x>dialog._close.size.x and dialog._action.disabled==(phase in ["checking","downloading"]))
			if scale==1.2:await capture("update-"+phase)
		dialog.updater.phase="failed";dialog._leave();await settle()
	Ui.text_scale=1.0;game.open_news();await capture("news")
	game.close_overlay();game.show_menu();game.free();await process_frame
	var f=FileAccess.open("res://qa/v056-ui-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("V056 UI TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
