## HTTP CONNECT proxies from the player's environment or Windows Internet settings.
extends RefCounted
static func parse(value: String) -> Dictionary:
	var text=value.strip_edges()
	if text.is_empty():return {}
	var pattern=RegEx.new();pattern.compile("^(?:http://)?(\\[[^\\]]+\\]|[^:/@;=\\s]+)(?::([0-9]{1,5}))?/?$")
	var found=pattern.search(text)
	if found==null:return {"error":true}
	var port=int(found.get_string(2)) if found.get_string(2)!="" else 80
	if port<1 or port>65535:return {"error":true}
	return {"host":found.get_string(1).trim_prefix("[").trim_suffix("]"),"port":port}
static func choose(server: String) -> String:
	if not server.contains("="):return server.strip_edges()
	for entry in server.split(";"):
		if entry.strip_edges().to_lower().begins_with("https="):return entry.get_slice("=",1).strip_edges()
	return ""
static func reg_value(name: String) -> String:
	if OS.get_name()!="Windows":return ""
	var command=OS.get_environment("SystemRoot").path_join("System32/reg.exe")
	if not FileAccess.file_exists(command):return ""
	var output=[]
	if OS.execute(command,["query","HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings","/v",name],output,false,false)!=0:return ""
	var pattern=RegEx.new();pattern.compile("REG_(?:SZ|EXPAND_SZ|DWORD)\\s+([^\\r\\n]+)")
	var found=pattern.search("\n".join(output))
	return found.get_string(1).strip_edges() if found!=null else ""
static func detect() -> Dictionary:
	for key in ["HTTPS_PROXY","https_proxy","ALL_PROXY","all_proxy"]:
		var value=OS.get_environment(key)
		if not value.is_empty():
			var result=parse(value);result.bypass=OS.get_environment("NO_PROXY")+","+OS.get_environment("no_proxy");return result
	var enabled=reg_value("ProxyEnable")
	if enabled.is_empty() or enabled.hex_to_int()!=1:return {}
	var result=parse(choose(reg_value("ProxyServer")));result.bypass=reg_value("ProxyOverride");return result
static func bypass(url: String,patterns: String) -> bool:
	var authority=url.get_slice("://",1).get_slice("/",0).to_lower()
	var host=authority.get_slice("]",0).trim_prefix("[") if authority.begins_with("[") else authority.get_slice(":",0)
	if host in ["localhost","127.0.0.1","::1"]:return true
	for token in patterns.replace(";",",").split(",",false):
		var item=token.strip_edges().to_lower()
		if item=="<local>" and not host.contains("."):return true
		if item.begins_with(".") and (host==item.trim_prefix(".") or host.ends_with(item)):return true
		if host.matchn(item) or host.ends_with("."+item):return true
	return false
static func apply(request: HTTPRequest,url: String,config: Dictionary):
	request.set_http_proxy("",-1);request.set_https_proxy("",-1)
	if config.has("host") and not bypass(url,String(config.get("bypass",""))):
		request.set_http_proxy(String(config.host),int(config.port));request.set_https_proxy(String(config.host),int(config.port))
