extends SceneTree
class PreviewGame extends "res://scripts/game.gd":
	func _data_path(path:String)->String:
		var dir:="res://qa/v061-gallery-runtime";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir));return dir.path_join(path.get_file())
var game
var folder:="res://qa/v061-gallery"
var dimensions:=Vector2i(1600,1000)
var captures:Array=[]
func _initialize():run.call_deferred()
func settle(n:int=10):
	for i in n:await process_frame
func capture(label:String):
	await settle();await RenderingServer.frame_post_draw
	var path:="%s/%s-%dx%d.png"%[folder,label,dimensions.x,dimensions.y]
	var image:=root.get_texture().get_image();assert(image.get_size()==dimensions)
	image.save_png(ProjectSettings.globalize_path(path));captures.append(path);print("CAPTURE ",path)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts=arg.trim_prefix("--qa-size=").split("x");dimensions=Vector2i(int(parts[0]),int(parts[1]))
	root.content_scale_size=Vector2i(1600,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.gui_embed_subwindows=true;root.mode=Window.MODE_WINDOWED;root.size=dimensions
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game=PreviewGame.new();root.add_child(game);await settle();game.set_process(false)
	game.settings.reduced_motion=true;MarketArt.reduced_motion=true;game.settings.active_skill_mode="both"
	if "--qa-large" in OS.get_cmdline_user_args():game.settings.ui_text_size="large";game._apply_ui_text_size()
	game.open_settings();await capture("skill-release-settings")
	game.open_almanac("plant",Content.PLANT_ORDER.find("judge"));game.screen_node._expanded=true;game.screen_node._render_page();game.screen_node._jump_to_section("进化")
	await capture("judge-evolution-icons")
	game.screen_node._attribute_info();await capture("attribute-calculation")
	game.show_menu();game.start_battle(1,["shooter","judge","sky-mortar","torch","lion","year-banyan"]);game.paused=true
	var s:Sim=game.sim;s.plants.clear();s.zombies.clear();s.orbs.clear();s.shots.clear();s.time=90;s.sun=99999
	var judge=s.place_free("judge",2,0);judge.upgrades={1:0,2:3,3:2}
	var second=s.place_free("judge",4,0);second.upgrades={1:2,2:3,3:0}
	var shooter=s.place_free("shooter",2,2);shooter.upgrades={1:2,2:0,3:3}
	var mortar=s.place_free("sky-mortar",2,4);mortar.upgrades={1:0,2:2,3:3};s.attach_shell(mortar)
	var torch=s.place_free("torch",3,2);torch.upgrades={1:0,2:2,3:3};s.apply_hp_scale(torch)
	var lion=s.place_free("lion",3,3);lion.upgrades={1:2,2:0,3:3}
	var banyan=s.place_free("year-banyan",1,1);banyan.upgrades={1:0,2:2,3:3};banyan.growth_steps=4
	for item in [[2,1000],[2,1100],[4,1050],[4,1100],[1,990]]:
		var z=s.spawn_zombie("ghost",item[0],{"x":item[1]});z.hp=20000;z.max_hp=20000
	s.refresh_plant_buffs();s._lion_cheer(lion,Upgrades.EFFECTS.lion);s.refresh_plant_buffs();s.floaters.clear();game.hud.refresh()
	await capture("three-distinct-skills-ready")
	game.hud.try_open_menu(shooter,Geo.to_screen(shooter.pos));await capture("skill-in-third-evolution");game.hud.close_fan()
	s.activate_skill(shooter)
	for i in 22:s.time+=.02;s._update_shooter(shooter,.02);s.update_shots(.02);s.update_particles(.02)
	await capture("sign-rain-active")
	s.activate_skill(judge);s.floaters.clear();await capture("judge-sanctuary-active")
	shooter.skill_shots_left=0;s.shots.clear();s.time=shooter.skill_ready_at-22.5
	await capture("skill-circular-cooldowns")
	s.time=maxf(s.time+1,mortar.skill_ready_at+1);s.shots.clear();s.activate_skill(mortar)
	var shot=s.shots[0];s._update_mortar_shot(shot,1.24);await capture("mortar-before-lock")
	for z in s.zombies:
		if z.row==2:z.pos.x-=100
	s._update_mortar_shot(shot,.01);await capture("mortar-late-lock")
	s._update_mortar_shot(shot,.20);await capture("mortar-final-descent")
	game.show_menu();game.open_news();await capture("v061-announcement")
	game.free();await settle()
	var file=FileAccess.open(folder.path_join("capture-%dx%d.json"%[dimensions.x,dimensions.y]),FileAccess.WRITE);file.store_string(JSON.stringify(captures,"  "));file.close();quit()
