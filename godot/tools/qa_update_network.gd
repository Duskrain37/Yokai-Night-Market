extends SceneTree
const Network=preload("res://scripts/update_network.gd")
var checks=[]
var failures=0
func check(name: String,ok: bool):
	checks.append({"name":name,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",name)
func _init():run.call_deferred()
func run():
	for sample in [["127.0.0.1:10808","127.0.0.1",10808],["http://proxy.example:8080","proxy.example",8080],["proxy.example","proxy.example",80],["http://[::1]:8080/","::1",8080]]:
		var parsed=Network.parse(sample[0]);check("代理地址"+sample[0],parsed.get("host")==sample[1] and parsed.get("port")==sample[2])
	for value in ["socks5://127.0.0.1:1080","http://user:password@example:8080","host:0","host:65536","https://host:8080","host;other"]:
		check("拒绝不支持或越界代理·"+str(checks.size()),Network.parse(value).get("error",false))
	check("空代理为直连",Network.parse("").is_empty())
	check("按HTTPS选系统代理",Network.choose("http=one:80;https=two:81;ftp=three:82")=="two:81")
	check("HTTP专用代理不影响HTTPS",Network.choose("http=one:80")=="")
	for url in ["http://127.0.0.1:1234/x","http://localhost/x","http://[::1]:4567/x"]:check("本机测试不经过代理·"+url,Network.bypass(url,""))
	check("NO_PROXY域后缀",Network.bypass("https://api.github.com/x",".github.com"))
	check("Windows通配排除",Network.bypass("https://api.github.com/x","<local>;*.github.com"))
	check("其他域不误绕过代理",not Network.bypass("https://github.com/x","localhost;*.example.com"))
	var previous={}
	for key in ["HTTPS_PROXY","https_proxy","ALL_PROXY","all_proxy"]:previous[key]=OS.get_environment(key);OS.set_environment(key,"")
	var system=Network.detect();var enabled=Network.reg_value("ProxyEnable");var expected=Network.parse(Network.choose(Network.reg_value("ProxyServer")))
	if enabled=="0x1" and expected.has("host"):check("无环境变量时沿用Windows代理",system.get("host")==expected.host and system.get("port")==expected.port)
	OS.set_environment("HTTPS_PROXY","http://127.0.0.1:12345")
	check("HTTPS环境代理优先",Network.detect().get("port")==12345)
	for key in previous:OS.set_environment(key,previous[key])
	check("空数据SHA无错误",preload("res://scripts/delta_update.gd").sha(PackedByteArray())=="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	var f=FileAccess.open("res://qa/v056-proxy-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("PROXY TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
