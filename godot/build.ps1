## 一键构建：导入 → 跑三套自动检查 → 导出 Windows 单文件 exe。
##
## 用法：pwsh -File build.ps1            （或 powershell -ExecutionPolicy Bypass -File build.ps1）
##   -GodotPath   指定 Godot 编辑器（默认用工作区 tmp/godot-tools 里的 4.7.2 便携版）
##   -SkipTests   跳过自动检查（不推荐）
##   -OutDir      导出目录，默认 build
param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '..\..\tmp\godot-tools\editor\Godot_v4.7.2-stable_win64_console.exe'),
    [switch]$SkipTests,
    [string]$OutDir = 'build'
)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath($PSScriptRoot)
$enginePath = [IO.Path]::GetFullPath($GodotPath)
if (-not (Test-Path -LiteralPath $enginePath)) { throw "找不到 Godot 编辑器：$enginePath" }
$qa = Join-Path $projectPath 'qa'
$out = Join-Path $projectPath $OutDir
New-Item -ItemType Directory -Path $qa, $out -Force | Out-Null

Write-Host '[1/5] 导入资源…'
& $enginePath --headless --editor --path $projectPath --import `
    --log-file (Join-Path $qa 'import.log')
if ($LASTEXITCODE -ne 0) { throw '资源导入失败' }

Write-Host '[2/5] 同步立绘缓存与字体子集…'
$python = 'python'
if (Get-Command $python -ErrorAction SilentlyContinue) {
    & $python (Join-Path $projectPath 'tools\prepare_assets.py') | Out-Null
    & $python (Join-Path $projectPath 'tools\subset_fonts.py') | Out-Null
    & $enginePath --headless --editor --path $projectPath --import `
        --log-file (Join-Path $qa 'import.log')
    if ($LASTEXITCODE -ne 0) { throw '字体子集导入失败' }
} else {
    Write-Warning '未找到 python，跳过立绘/字体同步（沿用现有 assets）'
}

if (-not $SkipTests) {
    Write-Host '[3/5] 逻辑检查…'
    & $enginePath --headless --path $projectPath --script res://tools/qa_logic.gd `
        --log-file (Join-Path $qa 'logic-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '逻辑检查失败' }

    Write-Host '[4/5] 自动对局检查…'
    & $enginePath --headless --path $projectPath --script res://tools/qa_battle.gd `
        --log-file (Join-Path $qa 'battle-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '自动对局检查失败' }

    Write-Host '[4/5] 界面联调自检…'
    & $enginePath --headless --path $projectPath -- --screen=selftest `
        --log-file (Join-Path $qa 'ui-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '界面联调自检失败' }
}

Write-Host '[5/5] 导出 Windows 单文件…'
& $enginePath --headless --editor --path $projectPath --export-release 'Windows Desktop' `
    (Join-Path $out 'YokaiNightMarket.exe') --log-file (Join-Path $qa 'export.log')
if ($LASTEXITCODE -ne 0) { throw '导出失败' }
$exe = Get-Item -LiteralPath (Join-Path $out 'YokaiNightMarket.exe')
$hash = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash.ToLower()
Write-Host ("完成：{0}  {1:N0} 字节  SHA-256 {2}" -f $exe.FullName, $exe.Length, $hash)
