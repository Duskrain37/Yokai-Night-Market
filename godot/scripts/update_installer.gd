## A hidden, bounded Windows helper replaces only this executable and its reserved siblings.
extends RefCounted
static func encoded(value: String) -> String:
	return Marshalls.raw_to_base64(value.to_utf8_buffer())
static func script(exe: String,candidate: String,target: Dictionary,parent: int,result_path: String) -> String:
	var code='''$ErrorActionPreference='Stop'
function Decode($s) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }
function Hash($path) {
  $stream=[IO.File]::OpenRead($path);$hasher=[Security.Cryptography.SHA256]::Create()
  try { ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
  finally { $stream.Dispose();$hasher.Dispose() }
}
$exe=[IO.Path]::GetFullPath((Decode('__EXE__')))
$candidate=[IO.Path]::GetFullPath((Decode('__CANDIDATE__')))
$result=[IO.Path]::GetFullPath((Decode('__RESULT__')))
$expected='__DIGEST__';$build='__BUILD__';$length=__SIZE__; $gamePid=__PID__
$backup=$exe+'.previous';$ack=$exe+'.update-ack';$started=$null;$moved=$false
function SaveResult($ok,$message) {
  @{ok=$ok;message=$message;detail=$reason;version='__VERSION__';time=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $result -Encoding UTF8 -ErrorAction SilentlyContinue
}
try {
  if ([IO.Path]::GetDirectoryName($exe) -ne [IO.Path]::GetDirectoryName($candidate) -or
      $candidate -ne ($exe+'.update-'+$expected.Substring(0,12)+'.part') -or
      [IO.Path]::GetExtension($exe) -ne '.exe' -or $gamePid -le 0) { throw 'Invalid update paths' }
  if ((Get-Item -LiteralPath $candidate).Length -ne $length -or
      (Hash $candidate) -ne $expected) { throw 'Candidate check failed' }
  Wait-Process -Id $gamePid -Timeout 45 -ErrorAction SilentlyContinue
  if (Get-Process -Id $gamePid -ErrorAction SilentlyContinue) { throw 'Game did not exit' }
  if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
  if (Test-Path -LiteralPath $ack) { Remove-Item -LiteralPath $ack -Force }
  Move-Item -LiteralPath $exe -Destination $backup
  $moved=$true
  Move-Item -LiteralPath $candidate -Destination $exe
  $arg='-- "--update-ack='+$ack+'"'
  # The restarted game is interactive; only this helper is hidden.
  $started=Start-Process -FilePath $exe -ArgumentList $arg -WorkingDirectory ([IO.Path]::GetDirectoryName($exe)) -WindowStyle Normal -PassThru
  $until=[DateTime]::UtcNow.AddSeconds(90);$ready=$false
  do {
    Start-Sleep -Milliseconds 250
    if (Test-Path -LiteralPath $ack) { $ready=((Get-Content -LiteralPath $ack -Raw).Trim() -eq $build) }
    $started.Refresh()
  } while (-not $ready -and -not $started.HasExited -and [DateTime]::UtcNow -lt $until)
  if (-not $ready) { throw 'Updated game did not confirm startup' }
  Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $ack -Force -ErrorAction SilentlyContinue
  $cache=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($result)) $expected))
  if ([IO.Path]::GetDirectoryName($cache) -eq [IO.Path]::GetDirectoryName($result) -and [IO.Path]::GetFileName($cache) -eq $expected -and (Test-Path -LiteralPath $cache)) {
    Get-ChildItem -LiteralPath $cache -File -Filter '*.bin' | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    if (-not (Get-ChildItem -LiteralPath $cache -Force)) { Remove-Item -LiteralPath $cache -ErrorAction SilentlyContinue }
  }
  SaveResult $true '更新完成。'
} catch {
  $reason=$_.Exception.Message
  if ($started -and -not $started.HasExited) { Stop-Process -Id $started.Id -Force; $started.WaitForExit() }
  if ($moved -and (Test-Path -LiteralPath $backup)) {
    if (Test-Path -LiteralPath $exe) {
      if ((Hash $exe) -ne $expected) { SaveResult $false '游戏文件发生变化，请手动检查更新目录。'; exit 2 }
      Remove-Item -LiteralPath $exe -Force
    }
    Move-Item -LiteralPath $backup -Destination $exe
    SaveResult $false '新版本未能正常启动，已恢复之前的版本。'
    Start-Process -FilePath $exe -WorkingDirectory ([IO.Path]::GetDirectoryName($exe)) -WindowStyle Normal
  } else { SaveResult $false '更新未能完成，之前的版本保持不变。' }
  exit 1
}
'''
	return code.replace("__EXE__",encoded(exe)).replace("__CANDIDATE__",encoded(candidate)).replace("__RESULT__",encoded(result_path)).replace("__DIGEST__",String(target.sha256)).replace("__BUILD__",String(target.build)).replace("__VERSION__",String(target.version)).replace("__SIZE__",str(int(target.size))).replace("__PID__",str(parent))
static func launch(exe: String,candidate: String,target: Dictionary) -> int:
	var dir=ProjectSettings.globalize_path("user://updates")
	if DirAccess.make_dir_recursive_absolute(dir)!=OK:return -1
	var code=script(exe,candidate,target,OS.get_process_id(),dir.path_join("install-result.json"))
	var powershell=OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	if not FileAccess.file_exists(powershell):return -1
	return OS.create_process(powershell,["-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-EncodedCommand",Marshalls.raw_to_base64(code.to_utf16_buffer())],false)
static func acknowledge(build: String):
	var expected=OS.get_executable_path()+".update-ack"
	for arg in OS.get_cmdline_user_args()+OS.get_cmdline_args():
		if arg=="--update-ack="+expected:
			var f=FileAccess.open(expected,FileAccess.WRITE)
			if f!=null:f.store_string(build);f.close()
static func notice() -> String:
	var path="user://updates/install-result.json"
	if not FileAccess.file_exists(path):return ""
	var data=JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix("\ufeff"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return String(data.get("message","")) if data is Dictionary and not bool(data.get("ok",false)) else ""
