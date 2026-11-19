## Generate the production Windows installer for isolated test executable paths.
extends SceneTree
const Installer=preload("res://scripts/update_installer.gd")

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var jobs: Array=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for job in jobs:
		var script:=Installer.script(job.exe,job.candidate,job.target,int(job.parent),job.result,bool(job.restart))
		var file:=FileAccess.open(job.script,FileAccess.WRITE)
		if file==null:quit(2);return
		file.store_string(script);file.close()
	quit()
