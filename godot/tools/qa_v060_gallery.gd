extends SceneTree
class PreviewGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var dir := "res://qa/v060-gallery-runtime"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		return dir.path_join(path.get_file())
var game
var folder := "res://qa/v060-gallery"
var dimensions := Vector2i(1600,1000)
var captures: Array=[]
func _initialize(): run.call_deferred()
func settle(n: int = 12):
	for i in n: await process_frame
func capture(label: String):
	await settle(); await RenderingServer.frame_post_draw
	var path := "%s/%s-%dx%d.png" % [folder,label,dimensions.x,dimensions.y]
	var image := root.get_texture().get_image()
	assert(image.get_size()==dimensions)
	image.save_png(ProjectSettings.globalize_path(path)); captures.append(path); print("CAPTURE ",path)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts=arg.trim_prefix("--qa-size=").split("x"); dimensions=Vector2i(int(parts[0]),int(parts[1]))
	root.content_scale_size=Vector2i(1600,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.gui_embed_subwindows=true;root.mode=Window.MODE_WINDOWED;root.size=dimensions
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game=PreviewGame.new();root.add_child(game);await settle()
	game.settings.reduced_motion=true;MarketArt.reduced_motion=true;game.settings.difficulty="normal"
	if "--qa-large" in OS.get_cmdline_user_args():game.settings.ui_text_size="large";game._apply_ui_text_size()
	game.open_almanac("plant",0);await settle();await capture("almanac-row-order")
	game.open_almanac("plant",Content.PLANT_ORDER.find("sky-mortar"));await settle()
	game.screen_node._jump_to_section("进化");await capture("mortar-evolution")
	game.open_almanac("zombie",Content.ZOMBIE_ORDER.find("sky-ferry"));await capture("ferry-almanac")
	game.start_battle(1,["lantern","shooter","wall","shell","sky-mortar"]);game.paused=true
	var s:Sim=game.sim;s.plants.clear();s.zombies.clear();s.orbs.clear();s.shots.clear();s.sun=99999
	for pair in [["lantern",0],["shooter",1],["wall",2]]:
		var plant=s.place_free(pair[0],2,pair[1]);s.attach_shell(plant)
	var cannon=s.place_free("sky-mortar",4,3);cannon.upgrades={1:0,2:0,3:3};s.attach_shell(cannon)
	var thief=s.spawn_zombie("incense-thief",1,{"x":960});thief.guest_action_at=s.time-.4
	var rider=s.spawn_zombie("ghost",2,{"x":1050});var ferry=s.spawn_zombie("sky-ferry",2,{"x":1075});s._try_pickup(ferry)
	var giant=s.spawn_zombie("mountain",4,{"x":1160});var second=s.spawn_zombie("sky-ferry",4,{"x":1185});s._try_pickup(second)
	var shield=s.spawn_zombie("shieldguard",0,{"x":1180});shield.hp=459;shield.max_hp=459;shield.armor=1458;shield.max_armor=1458
	game.units.health_bars="barText"
	s.floaters.clear();game.hud.refresh()
	await capture("battle-shell-ferry-thief")
	game.hud.show_shell(s.plants[0]);await capture("shell-details");game.hud.close_fan()
	s.activate_skill(cannon)
	for step in 12:
		s.time+=1.0/60;s._update_mortar(cannon,0);s.update_shots(1.0/60)
	await capture("mortar-active-launch")
	for step in 94:
		s.time+=1.0/60;s._update_mortar(cannon,0);s.update_shots(1.0/60)
	await capture("mortar-active-impact")
	game.show_pause();await capture("pause");game.close_pause()
	game.show_menu()
	var dialog=load("res://ui/update_dialog.gd").new();dialog.game=game;dialog.auto_start=false
	game.screen_node.add_child(dialog);dialog.popup_centered();await settle()
	dialog.updater.state("downloading","正在下载新版本的资源差异……")
	dialog.updater.progress=.42;dialog.updater.required=24000000;dialog.updater.received=10080000;dialog.updater.download_part=3;dialog.updater.download_parts=8;dialog._refresh()
	await capture("update-progress")
	dialog.updater.latest_version="0.6.0";dialog.updater.state("ready","完成");dialog.set_process(false)
	await capture("update-restart-required")
	dialog.restart_required=false;auto_accept_quit=true;dialog.hide();dialog.queue_free()
	game.free();await settle()
	var file=FileAccess.open(folder.path_join("capture-%dx%d.json"%[dimensions.x,dimensions.y]),FileAccess.WRITE)
	file.store_string(JSON.stringify(captures,"  "));file.close();quit()
