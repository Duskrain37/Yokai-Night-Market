param(
    [string]$Version = '0.2',
    [string]$WwwSource = '',
    [string]$OutputDir = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$shellDir = $PSScriptRoot
$root = Split-Path $shellDir -Parent
if (-not $WwwSource) {
    $WwwSource = Join-Path $root 'www'
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $root "releases\v$Version"
}

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) {
    throw "csc.exe not found. This build expects Windows .NET Framework 4.x."
}

$core = Join-Path $shellDir 'lib\net462\Microsoft.Web.WebView2.Core.dll'
$winforms = Join-Path $shellDir 'lib\net462\Microsoft.Web.WebView2.WinForms.dll'
$loader = Join-Path $shellDir 'lib\win-x64\WebView2Loader.dll'

foreach ($file in @($core, $winforms, $loader)) {
    if (-not (Test-Path $file)) {
        throw "Missing WebView2 dependency: $file"
    }
}
if (-not (Test-Path (Join-Path $WwwSource 'index.html'))) {
    throw "www source not found: $WwwSource"
}

$gameName = ([string][char]0x5996) + [char]0x602A + [char]0x591C + [char]0x5E02
$exeName = $gameName + "v$Version.exe"
$outExe = Join-Path $OutputDir $exeName
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if ((Test-Path $outExe) -and -not $Force) {
    throw "$exeName is already sealed. Use -Force to rebuild this version."
}

$running = Get-Process | Where-Object { $_.Path -eq $outExe }
if ($running) {
    throw "Close the game before rebuilding."
}

$build = Join-Path $shellDir "build\v$Version"
if (Test-Path $build) {
    Remove-Item $build -Recurse -Force
}
$payload = Join-Path $build 'payload'
$wwwDest = Join-Path $payload 'www'
New-Item -ItemType Directory -Force -Path $wwwDest | Out-Null

Copy-Item (Join-Path $WwwSource '*') $wwwDest -Recurse -Force
Copy-Item $core (Join-Path $payload 'Microsoft.Web.WebView2.Core.dll') -Force
Copy-Item $winforms (Join-Path $payload 'Microsoft.Web.WebView2.WinForms.dll') -Force
Copy-Item $loader (Join-Path $payload 'WebView2Loader.dll') -Force

$zip = Join-Path $build 'payload.zip'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $payload,
    $zip,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false)

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.Substring(0, 12).ToLowerInvariant()
$buildInfo = Join-Path $build 'BuildInfo.cs'
$code = @"
namespace YaoguaiNightMarket
{
    internal static class BuildInfo
    {
        public const string Version = "$Version";
        public const string Revision = "$hash";
    }
}
"@
[System.IO.File]::WriteAllText($buildInfo, $code, [System.Text.Encoding]::ASCII)

$tempExe = Join-Path $OutputDir "nightmarket_v$Version.exe"
& $csc /nologo /target:winexe /platform:x64 /optimize+ `
    /win32icon:"$shellDir\app.ico" `
    /win32manifest:"$shellDir\app.manifest" `
    /out:"$tempExe" `
    /reference:System.dll `
    /reference:System.Core.dll `
    /reference:System.Drawing.dll `
    /reference:System.Windows.Forms.dll `
    /reference:System.IO.Compression.dll `
    /reference:"$core" `
    /reference:"$winforms" `
    /resource:"$zip",YaoguaiNightMarket.payload.zip `
    "$shellDir\Program.cs" `
    "$buildInfo"

if ($LASTEXITCODE -ne 0) {
    throw "csc failed with exit code $LASTEXITCODE"
}

if (Test-Path $outExe) {
    Remove-Item $outExe -Force
}
Move-Item $tempExe $outExe
Remove-Item $build -Recurse -Force

$size = [math]::Round((Get-Item $outExe).Length / 1MB, 2)
Write-Host "Built: $outExe ($size MB, payload $hash)"
