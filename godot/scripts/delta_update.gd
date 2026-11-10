## Windows standalone updater. Reuse resource-aligned local chunks; fetch only missing ranges.
extends Node
signal changed
const Installer=preload("res://scripts/update_installer.gd")
const API="https://api.github.com/repos/Duskrain37/Yokai-Night-Market/releases/latest"
const DOWNLOAD_PREFIX="https://github.com/Duskrain37/Yokai-Night-Market/releases/download/"
const EXE="YokaiNightMarket-win64.exe"
const MAP="YokaiNightMarket-update-map.json"
const CHUNK=1048576
var phase="idle"
var message="点击检查更新，下载时会复用本地已有内容。"
var progress=0.0
var received=0
var required=0
var reused=0
var current_version=""
var executable=""
var latest_version=""
var manifest: Dictionary={}
var local_chunks: Dictionary={}
var candidate=""
var cache=""
var http: HTTPRequest
var thread: Thread
var _job=""
var _cancelled=false
var _waiting=false
var _installing=false
var _mutex=Mutex.new()
var _fixture=false
var fixture_cache=""
var _download_url=""

static func sha(bytes: PackedByteArray) -> String:
	var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
static func semver(value: String) -> Array:
	var r=RegEx.new();r.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
	var match=r.search(value)
	return [int(match.get_string(1)),int(match.get_string(2)),int(match.get_string(3))] if match!=null else []
static func newer(a: String,b: String) -> bool:
	var x=semver(a);var y=semver(b)
	if x.size()!=3 or y.size()!=3:return false
	for i in 3:
		if x[i]!=y[i]:return x[i]>y[i]
	return false
static func hex_digest(value: String) -> bool:
	var r=RegEx.new();r.compile("^[0-9a-f]{64}$");return r.search(value)!=null
static func valid_manifest(data: Dictionary,asset: Dictionary,version: String) -> bool:
	if int(data.get("schema",0))!=1 or String(data.get("version",""))!=version or String(data.get("asset",""))!=EXE:return false
	if int(data.get("chunk_size",0))!=CHUNK or not hex_digest(String(data.get("sha256",""))):return false
	if String(asset.get("digest",""))!="sha256:"+String(data.sha256) or int(data.get("size",0))!=int(asset.get("size",-1)):return false
	var build_pattern=RegEx.new();build_pattern.compile("^[0-9a-f]{7,40}$")
	if build_pattern.search(String(data.get("build","")))==null:return false
	if int(data.size)<=0 or int(data.size)>=2147483648:return false
	if not data.get("segments") is Array or data.segments.size()>100000 or data.segments.is_empty():return false
	var at=0
	for segment in data.segments:
		if not segment is Dictionary:return false
		if int(segment.get("offset",-1))!=at or int(segment.get("size",0))<=0 or int(segment.size)>CHUNK or not hex_digest(String(segment.get("sha256",""))):return false
		at+=int(segment.size)
	return at==int(data.size)
static func release_assets(release: Dictionary) -> Dictionary:
	var tag=String(release.get("tag_name",""))
	if semver(tag).is_empty() or bool(release.get("draft",false)) or bool(release.get("prerelease",false)):return {}
	var result={}
	if not release.get("assets",[]) is Array:return {}
	for asset in release.get("assets",[]):
		if not asset is Dictionary:return {}
		if String(asset.get("name","")) in [EXE,MAP] and String(asset.get("state",""))=="uploaded":
			var name=String(asset.name);var url=String(asset.get("browser_download_url",""))
			if url!=DOWNLOAD_PREFIX+tag+"/"+name or not String(asset.get("digest","")).begins_with("sha256:"):return {}
			result[name]=asset
	return result if result.size()==2 else {}
static func bytes_text(value: int) -> String:
	return "%.1f MB"%(value/1048576.0) if value>=1048576 else "%.1f KB"%(value/1024.0)

func _ready():
	http=HTTPRequest.new();http.use_threads=true;http.accept_gzip=false;http.timeout=30;http.max_redirects=8;add_child(http)
func state(next: String,text: String):
	phase=next;message=text;changed.emit()
func cancelled() -> bool:
	_mutex.lock();var result=_cancelled;_mutex.unlock();return result
func cancel():
	_mutex.lock();_cancelled=true;_mutex.unlock()
	if _waiting:
		http.cancel_request();http.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED,0,PackedStringArray(),PackedByteArray())
	if thread==null or not thread.is_started():state("cancelled","已停止更新。已校验的下载内容会保留，方便下次接着更新。")
func _process(_dt):
	if phase=="downloading":
		progress=clampf(float(received+http.get_downloaded_bytes())/maxi(1,required),0,1);changed.emit()
	if thread!=null and thread.is_started() and not thread.is_alive():
		var result=thread.wait_to_finish();thread=null
		if cancelled():state("cancelled","已停止更新，当前版本未更改。");return
		if result.has("error"):
			if not candidate.is_empty() and FileAccess.file_exists(candidate):DirAccess.remove_absolute(candidate)
			state("failed",String(result.error));return
		if _job=="scan":
			local_chunks=result.index;_download_missing()
		else:progress=1;state("ready","更新已准备好。重启后即可进入 v%s。"%latest_version)
func _exit_tree():
	_mutex.lock();_cancelled=true;_mutex.unlock()
	if thread!=null and thread.is_started():thread.wait_to_finish()
	if not _installing and not candidate.is_empty() and FileAccess.file_exists(candidate):DirAccess.remove_absolute(candidate)
func _worker_progress(done: int,total: int):
	progress=clampf(float(done)/maxi(1,total),0,1);changed.emit()
func _request(url: String,headers: PackedStringArray,limit: int) -> Array:
	if cancelled():return []
	http.body_size_limit=limit;_waiting=true
	var err=http.request(url,headers)
	if err!=OK:_waiting=false;return []
	var response=await http.request_completed;_waiting=false
	return response if not cancelled() else []
func start(version: String,path: String,endpoint: String=API,fixture: bool=false):
	if phase not in ["idle","current","failed","cancelled"]:return
	_fixture=fixture and endpoint.begins_with("http://127.0.0.1:")
	if endpoint!=API and not _fixture:state("failed","更新地址无效。");return
	if not _fixture and (OS.get_name()!="Windows" or OS.has_feature("editor")):
		state("failed","请在下载的 Windows 游戏成品中检查更新。");return
	_mutex.lock();_cancelled=false;_mutex.unlock()
	current_version=version;executable=path;progress=0;received=0;required=0
	state("checking","正在查看夜市的新消息……")
	var response=await _request(endpoint,["Accept: application/vnd.github+json","User-Agent: YokaiNightMarket/"+version],2097152)
	if response.size()!=4 or response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]!=200:
		if not cancelled():state("failed","暂时连不上更新消息，请稍后重试。")
		return
	var release=JSON.parse_string(response[3].get_string_from_utf8())
	if not release is Dictionary:state("failed","收到的更新消息不完整，请稍后重试。");return
	var tag=String(release.get("tag_name",""));latest_version=tag.trim_prefix("v")
	if semver(tag).is_empty() or bool(release.get("prerelease",false)) or bool(release.get("draft",false)):
		state("failed","没有可用的正式更新。");return
	if not newer(tag,version):state("current","已经是最新版本，今夜安心守夜。")
	else:
		var assets=release_assets(release)
		if _fixture:assets=_fixture_assets(release,endpoint)
		if assets.is_empty():state("failed","新版本的更新资料尚未备齐，请稍后重试。");return
		_download_url=String(assets[EXE].browser_download_url)
		response=await _request(String(assets[MAP].browser_download_url),["Accept-Encoding: identity","User-Agent: YokaiNightMarket/"+version],8388608)
		if response.size()!=4 or response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]!=200:
			if not cancelled():state("failed","更新资料下载中断，请稍后重试。")
			return
		if "sha256:"+sha(response[3])!=String(assets[MAP].digest):state("failed","更新资料校验未通过，当前版本未更改。");return
		var data=JSON.parse_string(response[3].get_string_from_utf8())
		if not data is Dictionary or not valid_manifest(data,assets[EXE],latest_version):state("failed","更新资料校验未通过，当前版本未更改。");return
		manifest=data;candidate=executable+".update-"+String(manifest.sha256).left(12)+".part"
		cache=fixture_cache if _fixture and not fixture_cache.is_empty() else ProjectSettings.globalize_path("user://updates/"+String(manifest.sha256))
		if DirAccess.make_dir_recursive_absolute(cache)!=OK:state("failed","无法保存更新内容，请检查可用空间。");return
		var folder=DirAccess.open(executable.get_base_dir())
		if folder==null or folder.get_space_left()<int(manifest.size)+8388608:state("failed","游戏所在磁盘空间不足，请空出至少%s后重试。"%bytes_text(int(manifest.size)+8388608));return
		var test=FileAccess.open(candidate,FileAccess.WRITE)
		if test==null:state("failed","游戏所在目录不能写入，请把游戏移到可写入的位置后重试。");return
		test.close();DirAccess.remove_absolute(candidate)
		state("scanning","正在核对本地已有内容……");_job="scan";thread=Thread.new();thread.start(_scan.bind(executable))

func _fixture_assets(release: Dictionary,endpoint: String) -> Dictionary:
	var origin=endpoint.get_slice("/",0)+"//"+endpoint.get_slice("/",2)+"/";var result={}
	for a in release.get("assets",[]):
		if String(a.get("name","")) in [EXE,MAP] and String(a.get("browser_download_url","")).begins_with(origin):result[a.name]=a
	return result if result.size()==2 else {}
static func _append_blocks(target: Array,start: int,end: int):
	while start<end:
		var length=mini(CHUNK,end-start);target.append([start,length]);start+=length
static func spans(path: String) -> Array:
	var f=FileAccess.open(path,FileAccess.READ)
	if f==null or f.get_length()<4096:return []
	var size=f.get_length();f.seek(size-12);var length=f.get_64();var magic=f.get_buffer(4).get_string_from_ascii();var start=size-12-length
	if magic!="GDPC" or start<4096:return []
	f.seek(start);if f.get_buffer(4).get_string_from_ascii()!="GDPC" or f.get_32()!=4:return []
	f.seek(start+24);var base=f.get_64();var table=f.get_64()
	if base<48 or table<=base or table>=length:return []
	f.seek(start+table);var count=f.get_32()
	if count>100000:return []
	var unique={}
	for i in count:
		var name_size=f.get_32()
		if name_size>65536:return []
		f.seek(f.get_position()+name_size)
		var offset=f.get_64();var bytes=f.get_64();f.seek(f.get_position()+16);var flags=f.get_32()
		if flags!=0 or offset+bytes>table-base:return []
		if bytes>0:unique[str(offset)+":"+str(bytes)]=[start+base+offset,bytes]
	var resources=unique.values();resources.sort_custom(func(a,b):return a[0]<b[0])
	var result=[];var at=0
	for resource in resources:
		if int(resource[0])<at:return []
		_append_blocks(result,at,int(resource[0]));_append_blocks(result,int(resource[0]),int(resource[0])+int(resource[1]));at=int(resource[0])+int(resource[1])
	_append_blocks(result,at,size);f.close();return result
func _scan(path: String) -> Dictionary:
	var blocks=spans(path)
	if blocks.is_empty():return {"error":"无法识别当前游戏文件，请使用正式的 Windows 成品。"}
	var f=FileAccess.open(path,FileAccess.READ);var index={};var processed=0;var total=f.get_length()
	for block in blocks:
		if cancelled():return {"error":"已取消"}
		f.seek(int(block[0]));var bytes=f.get_buffer(int(block[1]))
		if bytes.size()!=int(block[1]):return {"error":"读取本地游戏失败，当前版本未更改。"}
		index[sha(bytes)]=block;processed+=bytes.size()
		if bytes.size()>65536:_worker_progress.call_deferred(processed,total)
	f.close();return {"index":index}
func _download_missing():
	var missing=[];var seen={};reused=0;required=0;received=0
	for segment in manifest.segments:
		var key=String(segment.sha256)
		if local_chunks.has(key):reused+=int(segment.size);continue
		if seen.has(key):continue
		seen[key]=true;var path=cache.path_join(key+".bin")
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path)==key:continue
		missing.append(segment)
	var groups=[]
	for segment in missing:
		var end=int(segment.offset)+int(segment.size)
		if not groups.is_empty() and int(segment.offset)-int(groups[-1].end)<=1024 and end-int(groups[-1].start)<=4194304:
			groups[-1].end=end;groups[-1].segments.append(segment)
		else:groups.append({"start":int(segment.offset),"end":end,"segments":[segment]})
	for group in groups:required+=int(group.end)-int(group.start)
	var destination=DirAccess.open(executable.get_base_dir());var storage=DirAccess.open(cache)
	if destination==null or storage==null or destination.get_space_left()<int(manifest.size)+8388608 or storage.get_space_left()<required+8388608:
		state("failed","磁盘空间不足，请清理后重试。当前版本未更改。");return
	state("downloading","已复用%s，本次约需下载%s。"%[bytes_text(reused),bytes_text(required)])
	for group in groups:
		if cancelled():state("cancelled","已停止更新，当前版本未更改。");return
		var start=int(group.start);var length=int(group.end)-start;var good=false
		for attempt in 3:
			var response=await _request(_download_url,["Range: bytes=%d-%d"%[start,start+length-1],"Accept-Encoding: identity","User-Agent: YokaiNightMarket/"+current_version],length)
			if response.size()==4 and response[0]==HTTPRequest.RESULT_SUCCESS and response[1]==206 and response[3].size()==length:
				var content_range=""
				for header in response[2]:
					if String(header).to_lower().begins_with("content-range:"):content_range=String(header).get_slice(":",1).strip_edges()
				if content_range=="bytes %d-%d/%d"%[start,start+length-1,int(manifest.size)]:
					good=true
					for segment in group.segments:
						var bytes=response[3].slice(int(segment.offset)-start,int(segment.offset)-start+int(segment.size))
						if sha(bytes)!=String(segment.sha256):good=false;break
					if good:
						for segment in group.segments:
							var f=FileAccess.open(cache.path_join(String(segment.sha256)+".bin"),FileAccess.WRITE)
							if f==null:good=false;break
							f.store_buffer(response[3].slice(int(segment.offset)-start,int(segment.offset)-start+int(segment.size)));f.close()
			if good:received+=length;break
			if cancelled():state("cancelled","已停止更新，已校验部分会保留。");return
			await get_tree().create_timer(.7+attempt).timeout
		if not good:state("failed","下载暂时中断或校验未通过。已校验内容会保留，下次检查可接着更新。");return
	state("assembling","下载完成，正在合拢新的夜市……");_job="assemble";thread=Thread.new();thread.start(_assemble)
func _assemble() -> Dictionary:
	var source=FileAccess.open(executable,FileAccess.READ);var target=FileAccess.open(candidate,FileAccess.WRITE)
	if source==null or target==null:return {"error":"无法准备新版本，当前游戏未更改。"}
	var done=0
	for segment in manifest.segments:
		if cancelled():source.close();target.close();DirAccess.remove_absolute(candidate);return {"error":"已取消"}
		var bytes=PackedByteArray();var key=String(segment.sha256)
		if local_chunks.has(key):source.seek(int(local_chunks[key][0]));bytes=source.get_buffer(int(segment.size))
		else:bytes=FileAccess.get_file_as_bytes(cache.path_join(key+".bin"))
		if (done==0 and bytes.slice(0,2).get_string_from_ascii()!="MZ") or bytes.size()!=int(segment.size) or sha(bytes)!=key:source.close();target.close();return {"error":"本地内容校验未通过，当前游戏未更改。"}
		target.store_buffer(bytes);done+=bytes.size()
		if bytes.size()>65536:_worker_progress.call_deferred(done,int(manifest.size))
	source.close();target.close()
	if FileAccess.get_sha256(candidate)!=String(manifest.sha256):return {"error":"新版本完整校验未通过，当前游戏未更改。"}
	return {"ok":true}
func install() -> bool:
	if phase!="ready" or _fixture:return false
	var pid=Installer.launch(executable,candidate,manifest)
	if pid<=0:state("failed","未能启动更新，请稍后重试。当前版本未更改。");return false
	_installing=true
	return true
