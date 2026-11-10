extends SceneTree
const Delta=preload("res://scripts/delta_update.gd")
const Installer=preload("res://scripts/update_installer.gd")
var checks=[]
var failures=0
func check(label: String,ok: bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func option(key: String,fallback: String="") -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"+key+"="):return arg.get_slice("=",1)
	return fallback
func _init():run.call_deferred()
func run():
	for entry in [["0.5.10","0.5.9",true],["v0.6.0","0.5.99",true],["0.5.6","0.5.6",false],["0.5.5","0.5.6",false],["v0.5.7-mobile","0.5.6",false],["0.5.7-beta","0.5.6",false]]:
		check("语义版本 "+entry[0],Delta.newer(entry[0],entry[1])==entry[2])
	var fixture=option("fixture","res://tools/fixtures/v055-update-map.json")
	var data=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var asset={"name":Delta.EXE,"size":data.size,"digest":"sha256:"+String(data.sha256)}
	check("真实资源分块图完整有效",Delta.valid_manifest(data,asset,"0.5.5"))
	for mutation in ["offset","length","digest","build","version","total"]:
		var bad=data.duplicate(true)
		match mutation:
			"offset":bad.segments[1].offset+=1
			"length":bad.segments[0].size=Delta.CHUNK+1
			"digest":bad.segments[0].sha256="bad"
			"build":bad.build="x'; echo danger; '"
			"version":bad.version="0.5.6"
			"total":bad.size+=1
		check("拒绝篡改"+mutation,not Delta.valid_manifest(bad,asset,"0.5.5"))
	var assets=[]
	for name in [Delta.EXE,Delta.MAP]:assets.append({"name":name,"state":"uploaded","digest":"sha256:"+String(data.sha256),"browser_download_url":Delta.DOWNLOAD_PREFIX+"v0.5.6/"+name})
	var release={"tag_name":"v0.5.6","draft":false,"prerelease":false,"assets":assets}
	check("正式PC更新资料可识别",Delta.release_assets(release).size()==2)
	for flag in ["draft","prerelease"]:
		var bad=release.duplicate(true);bad[flag]=true;check("不装"+flag,Delta.release_assets(bad).is_empty())
	var bad=release.duplicate(true);bad.assets[0].browser_download_url="https://example.com/other.exe";check("不允许其他下载源",Delta.release_assets(bad).is_empty())
	bad=release.duplicate(true);bad.tag_name="v0.5.6-mobile";check("不取移动版",Delta.release_assets(bad).is_empty())
	var path=option("exe",ProjectSettings.globalize_path("res://").path_join("../releases/v0.5.5/YokaiNightMarket.exe"))
	var ranges=Delta.spans(path)
	if FileAccess.file_exists(path):check("Godot与Python分块数一致",ranges.size()==data.segments.size())
	else:print("SKIP optional archived EXE boundary audit; provide --exe=...")
	for i in ranges.size():check("资源分块位置%d"%i,ranges[i]==[int(data.segments[i].offset),int(data.segments[i].size)])
	var script=Installer.script("C:/测试 O'Neil/夜市.exe","C:/测试 O'Neil/夜市.exe.update-"+String(data.sha256).left(12)+".part",data,12345,"C:/测试/updates/result.json")
	check("路径以UTF8 base64传递",not script.contains("O'Neil") and script.contains("[Convert]::FromBase64String"))
	check("替换前等待父进程和重新验hash",script.contains("Wait-Process -Id $gamePid") and script.contains("(Hash $candidate)"))
	check("确认启动才清备份",script.find("if (-not $ready)")<script.find("Remove-Item -LiteralPath $backup -Force",script.find("if (-not $ready)")))
	check("失败恢复旧文件",script.contains("Move-Item -LiteralPath $backup -Destination $exe"))
	var out=FileAccess.open("res://qa/v056-update-tests.json",FileAccess.WRITE);out.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));out.close()
	print("UPDATE TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
