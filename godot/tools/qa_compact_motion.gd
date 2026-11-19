extends SceneTree
const Storage=preload("res://scripts/motion_storage.gd")
const MANIFEST="res://data/actor_motion.json"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	var result := {}
	var pack := args.size()>1 and args[1]=="packed"
	var references:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[2])) if pack else {}
	var motion:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var failures := 0
	# Exercise the same threaded ResourceLoader path used by the battle loading screen.
	var sample:="res://"+String(motion["dragon"].file)
	var native_sample:=Storage.path_for(sample)
	var future_test:=native_sample
	if not pack:
		future_test="res://qa/motion-storage-probe.nma"
		assert(not FileAccess.file_exists(future_test))
		var staged:=FileAccess.open(future_test,FileAccess.WRITE)
		staged.store_buffer(FileAccess.get_file_as_bytes(sample));staged.close()
		ResourceLoader.add_resource_format_loader(Storage.CompactLoader.new())
	if ResourceLoader.load_threaded_request(future_test)!=OK:
		failures+=1
	else:
		while ResourceLoader.load_threaded_get_status(future_test)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await process_frame
		if ResourceLoader.load_threaded_get_status(future_test)!=ResourceLoader.THREAD_LOAD_LOADED:
			failures+=1
		else:
			var threaded:Texture2D=ResourceLoader.load_threaded_get(future_test)
			if threaded==null:failures+=1
			else:
				var original:Texture2D=load(native_sample)
				if threaded.get_image().get_data()!=original.get_image().get_data():failures+=1
	if not pack:DirAccess.remove_absolute(ProjectSettings.globalize_path(future_test))
	for actor in motion:
		var path:="res://"+String(motion[actor].file)
		var actual_path:=Storage.path_for(path)
		var tex:Texture2D=load(actual_path)
		if tex==null:failures+=1;printerr("FAILED asset ",path);continue
		var want:=tex.get_image()
		want.convert(Image.FORMAT_RGBA8)
		var h:=HashingContext.new()
		h.start(HashingContext.HASH_SHA256);h.update(want.get_data())
		var digest:=h.finish().hex_encode()
		if pack:
			if references.get(path,{}).get("pixels","")!=digest:failures+=1;printerr("FAILED pixels ",path)
			if references.get(path,{}).get("compact",false) and actual_path==path:failures+=1;printerr("FAILED compact load ",path)
			result[path]=digest
		else:
			var source:=FileAccess.get_file_as_bytes(path)
			var have:=Storage.CompactLoader.decode(source)
			var sh:=HashingContext.new()
			sh.start(HashingContext.HASH_SHA256);sh.update(source)
			result[path]={"compact":have!=null and have.get_size()==want.get_size() and have.get_data()==want.get_data(),
				"source_sha":sh.finish().hex_encode(),"pixels":digest}
		var tree_h:=want.get_height()
		var tree_w:=want.get_width()
		for frames in motion[actor].clips.values():
			if frames.size()!=32:failures+=1
			for frame in frames:
				var r:Array=frame.rect
				if r[0]<0 or r[1]<0 or r[0]+r[2]>tree_w or r[1]+r[3]>tree_h:failures+=1
	var writer:=FileAccess.open(args[0],FileAccess.WRITE)
	writer.store_string(JSON.stringify(result));writer.close()
	print("MOTION TOTAL ",result.size()," FAILURES ",failures)
	quit(1 if failures else 0)
