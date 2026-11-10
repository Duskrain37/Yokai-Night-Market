## 一键构建：导入 → 跑逻辑/对局/曲线/Boss/UI/交互检查 → 导出 Windows 单文件 exe。
##
## 用法：pwsh -File build.ps1            （或 powershell -ExecutionPolicy Bypass -File build.ps1）
##   -GodotPath   指定 Godot 编辑器（默认用工作区 tmp/godot-tools 里的 4.7.2 便携版）
##   -SkipTests   跳过自动检查（不推荐）
##   -OutDir      导出目录，默认 build
param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '..\..\tmp\godot-tools\editor\Godot_v4.7.2-stable_win64_console.exe'),
    [switch]$SkipTests,
    [switch]$VerifyOnly,
    [string]$OutDir = 'build'
)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath($PSScriptRoot)
$enginePath = [IO.Path]::GetFullPath($GodotPath)
if (-not (Test-Path -LiteralPath $enginePath)) { throw "找不到 Godot 编辑器：$enginePath" }
$qa = Join-Path $projectPath 'qa'
$out = Join-Path $projectPath $OutDir
New-Item -ItemType Directory -Path $qa, $out -Force | Out-Null

Write-Host '[1/7] 导入资源…'
& $enginePath --headless --editor --path $projectPath --import `
    --log-file (Join-Path $qa 'import.log')
if ($LASTEXITCODE -ne 0) { throw '资源导入失败' }

Write-Host '[2/7] 同步立绘缓存与字体子集…'
$python = 'python'
if (Get-Command $python -ErrorAction SilentlyContinue) {
    & $python (Join-Path $projectPath 'tools\stamp_build.py')
    if ($LASTEXITCODE -ne 0) { throw 'build stamp failed' }
    & $python (Join-Path $projectPath 'tools\prepare_assets.py') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw '素材准备失败' }
    & $python (Join-Path $projectPath 'tools\subset_fonts.py') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw '字体子集生成失败' }
    & $python (Join-Path $projectPath 'tools\stamp_build.py')
    & $enginePath --headless --editor --path $projectPath --import `
        --log-file (Join-Path $qa 'import.log')
    if ($LASTEXITCODE -ne 0) { throw '字体子集导入失败' }
} else {
    Write-Warning '未找到 python，跳过立绘/字体同步（沿用现有 assets）'
}

if (-not $SkipTests) {
    Write-Host '[3/7] 逻辑检查…'
    & $enginePath --headless --path $projectPath --script res://tools/qa_logic.gd `
        --log-file (Join-Path $qa 'logic-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '逻辑检查失败' }

    Write-Host '[4/7] 自动对局检查…'
    & $enginePath --headless --path $projectPath --script res://tools/qa_battle.gd `
        --log-file (Join-Path $qa 'battle-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '自动对局检查失败' }

    & $enginePath --headless --path $projectPath --script res://tools/qa_boss.gd --log-file (Join-Path $qa 'boss-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'Boss 规则检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_boss_balance.gd --log-file (Join-Path $qa 'boss-balance.log')
    if ($LASTEXITCODE -ne 0) { throw 'Boss 数值检查失败' }

    & $enginePath --headless --path $projectPath --script res://tools/qa_special.gd --log-file (Join-Path $qa 'special-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '特殊关流程检查失败' }

    Write-Host '[5/7] 十五夜难度曲线…'
    & $enginePath --headless --path $projectPath --script res://tools/qa_sweep.gd `
        --log-file (Join-Path $qa 'curve.log')
    if ($LASTEXITCODE -ne 0) { throw '难度曲线检查失败（见 qa/curve.csv）' }

    Write-Host '[6/7] 界面联调自检…'
    & $enginePath --headless --path $projectPath --log-file (Join-Path $qa 'ui-tests.log') -- --screen=selftest
    if ($LASTEXITCODE -ne 0) { throw '界面联调自检失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_click.gd --log-file (Join-Path $qa 'click-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '交互检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_player_ui.gd --log-file (Join-Path $qa 'player-ui-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '玩家文案与界面检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_patch.gd --log-file (Join-Path $qa 'patch-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '补丁功能检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_animation.gd --log-file (Join-Path $qa 'animation-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '动画与射弹检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v050.gd --log-file (Join-Path $qa 'v050-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '新地图与双形态首领检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v051_refresh.gd --log-file (Join-Path $qa 'v051-refresh-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '存档、按键与状态检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v052.gd --log-file (Join-Path $qa 'v052-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'v0.5.2 更新检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v053.gd --log-file (Join-Path $qa 'v053-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'v0.5.3 更新检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v054.gd --log-file (Join-Path $qa 'v054-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'PC优化检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_nightmare.gd --log-file (Join-Path $qa 'nightmare-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '噩梦规则检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v054_content.gd --log-file (Join-Path $qa 'v054-content-tests.log')
    if ($LASTEXITCODE -ne 0) { throw '新增草木恶客检查失败' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v055.gd --log-file (Join-Path $qa 'v055-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'v0.5.5 rules failed' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_v056.gd --log-file (Join-Path $qa 'v056-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'v0.5.6 balance failed' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_update.gd --log-file (Join-Path $qa 'v056-update-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'v0.5.6 update failed' }
    & $enginePath --headless --path $projectPath --script res://tools/qa_update_network.gd --log-file (Join-Path $qa 'v056-proxy-tests.log')
    if ($LASTEXITCODE -ne 0) { throw 'v0.5.6 proxy failed' }




}

& $python (Join-Path $projectPath 'tools\verify_music.py')
if ($LASTEXITCODE -ne 0) { throw '五周配乐与原件不一致' }

if ($VerifyOnly) { Write-Host '本地检查完成；未封包、未上传。'; return }

Write-Host '[7/7] 导出 Windows 单文件…'
& $enginePath --headless --editor --path $projectPath --export-release 'Windows Desktop' `
    (Join-Path $out 'YokaiNightMarket.exe') --log-file (Join-Path $qa 'export.log')
if ($LASTEXITCODE -ne 0) { throw '导出失败' }
if (Select-String -LiteralPath (Join-Path $qa 'export.log') -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed' -Quiet) { throw '导出日志包含脚本错误' }
& $python (Join-Path $projectPath 'tools\trim_export.py') (Join-Path $out 'YokaiNightMarket.exe') (Join-Path $qa 'pack-audit.json')
if ($LASTEXITCODE -ne 0) { throw '发行包瘦身或逐文件校验失败' }
$exe = Get-Item -LiteralPath (Join-Path $out 'YokaiNightMarket.exe')
$hash = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash.ToLower()
Write-Host ("完成：{0}  {1:N0} 字节  SHA-256 {2}" -f $exe.FullName, $exe.Length, $hash)

& $python (Join-Path $projectPath 'tools\verify_music.py')
if ($LASTEXITCODE -ne 0) { throw '封包后五周配乐与原件不一致' }
