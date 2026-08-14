param(
  [string]$Version = "0.0.0"
)

$ErrorActionPreference = "Stop"
if ($Version.StartsWith("v")) { $Version = $Version.Substring(1) }
if ($Version -notmatch '^\d+(\.\d+){0,3}$') { $Version = "0.0.0" }
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$SourceDir = Join-Path $RepoRoot "build/windows/x64/runner/Release"
$OutputDir = Join-Path $RepoRoot "dist/windows"

if (-not (Test-Path (Join-Path $SourceDir "zmp3chart.exe"))) {
  throw "Windows release bundle not found at $SourceDir. Run flutter build windows --release first."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ZipPath = Join-Path $OutputDir "zingchart-windows-portable.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $SourceDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal

$IsccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
$IsccPath = if ($IsccCommand) { $IsccCommand.Source } else { $null }
if (-not $IsccPath) {
  $DefaultIscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
  if (Test-Path $DefaultIscc) { $IsccPath = $DefaultIscc }
}
if (-not $IsccPath) {
  throw "Inno Setup 6 was not found. Install it or use the portable ZIP artifact."
}

& $IsccPath "/DSourceDir=$SourceDir" "/DOutputDir=$OutputDir" "/DAppVersion=$Version" (Join-Path $PSScriptRoot "zingchart.iss")
