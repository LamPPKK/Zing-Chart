param(
  [string]$Version = "1.0.0",
  [string]$Publisher = "CN=ZingChart Development",
  [string]$IdentityName = "ZingChart.Music.Development",
  [string]$PublisherDisplayName = "#zingChart",
  [string]$OutputName = "zingchart-windows-development",
  [switch]$SkipDependencyCopy
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Convert-ToPackageVersion([string]$InputVersion) {
  if ($InputVersion.StartsWith("v")) { $InputVersion = $InputVersion.Substring(1) }
  $CoreVersion = ($InputVersion -split '[-+]')[0]
  if ($CoreVersion -notmatch '^\d+(\.\d+){0,3}$') {
    throw "Version must contain one to four numeric components. Received: $InputVersion"
  }

  $Parts = @($CoreVersion.Split('.') | ForEach-Object { [int]$_ })
  while ($Parts.Count -lt 4) { $Parts += 0 }
  if ($Parts | Where-Object { $_ -lt 0 -or $_ -gt 65535 }) {
    throw "Every MSIX version component must be between 0 and 65535."
  }
  if ($Parts[0] -eq 0) {
    throw "The MSIX major version must be greater than zero for Microsoft Store submission."
  }
  if ($Parts[3] -ne 0) {
    throw "The fourth MSIX version component must be zero for Microsoft Store submission."
  }
  return ($Parts -join '.')
}

function Find-WindowsSdkTool([string]$ToolName) {
  $Command = Get-Command $ToolName -ErrorAction SilentlyContinue
  if ($Command) { return $Command.Source }

  $SdkBin = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
  if (-not (Test-Path $SdkBin)) {
    throw "$ToolName was not found. Install the Windows 10/11 SDK."
  }
  $Tool = Get-ChildItem $SdkBin -Filter $ToolName -Recurse |
    Where-Object { $_.FullName -match '\\x64\\' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
  if (-not $Tool) { throw "$ToolName was not found in $SdkBin." }
  return $Tool.FullName
}

function Get-VCLibsPackageInfo {
  $ExtensionRoot = Join-Path ${env:ProgramFiles(x86)} "Microsoft SDKs\Windows Kits\10\ExtensionSDKs\Microsoft.VCLibs.Desktop\14.0"
  $SdkManifestPath = Join-Path $ExtensionRoot "SDKManifest.xml"
  if (-not (Test-Path $SdkManifestPath)) {
    throw "Microsoft.VCLibs.Desktop 14.0 SDK was not found. Install the Windows UWP C++ tools component."
  }

  [xml]$SdkManifest = Get-Content $SdkManifestPath -Raw
  $FileList = $SdkManifest.FileList
  $Identity = $FileList.GetAttribute("FrameworkIdentity-Retail")
  $PackageRelativePath = $FileList.GetAttribute("AppX-Retail-x64")
  $IdentityMatch = [regex]::Match($Identity, "Name\s*=\s*([^,]+),\s*MinVersion\s*=\s*([^,]+),\s*Publisher\s*=\s*'([^']+)'")
  if (-not $IdentityMatch.Success -or
      [string]::IsNullOrWhiteSpace($PackageRelativePath)) {
    throw "The VCLibs SDK manifest does not contain the expected retail x64 package metadata."
  }

  $PackagePath = [IO.Path]::GetFullPath((Join-Path $ExtensionRoot $PackageRelativePath))
  if (-not (Test-Path $PackagePath)) {
    throw "The VCLibs retail x64 dependency was not found at $PackagePath."
  }
  return [PSCustomObject]@{
    Name = $IdentityMatch.Groups[1].Value.Trim()
    MinVersion = $IdentityMatch.Groups[2].Value.Trim()
    Publisher = $IdentityMatch.Groups[3].Value.Trim()
    PackagePath = $PackagePath
  }
}

function New-TileAsset(
  [System.Drawing.Image]$Source,
  [int]$Width,
  [int]$Height,
  [string]$Destination
) {
  $Bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
  $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
  try {
    $Graphics.Clear([System.Drawing.ColorTranslator]::FromHtml("#17181B"))
    $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    $Scale = [Math]::Min($Width / $Source.Width, $Height / $Source.Height)
    $DrawWidth = [Math]::Max(1, [int]($Source.Width * $Scale))
    $DrawHeight = [Math]::Max(1, [int]($Source.Height * $Scale))
    $X = [int](($Width - $DrawWidth) / 2)
    $Y = [int](($Height - $DrawHeight) / 2)
    $Graphics.DrawImage($Source, $X, $Y, $DrawWidth, $DrawHeight)
    $Bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $Graphics.Dispose()
    $Bitmap.Dispose()
  }
}

if ($IdentityName -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{1,48}[A-Za-z0-9]$' -or
    $IdentityName.Contains('..') -or
    $IdentityName.ToLowerInvariant().Contains('.xn--')) {
  throw "IdentityName must be 3-50 characters, start/end with a letter or digit, and contain only letters, digits, dots or hyphens."
}
if ([string]::IsNullOrWhiteSpace($Publisher)) {
  throw "Publisher cannot be empty. It must match the signing certificate subject."
}
if ([string]::IsNullOrWhiteSpace($PublisherDisplayName)) {
  throw "PublisherDisplayName cannot be empty."
}
if ($OutputName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') {
  throw "OutputName must be a safe file name containing only letters, digits, dots, underscores or hyphens."
}

$PackageVersion = Convert-ToPackageVersion $Version
$VCLibs = Get-VCLibsPackageInfo
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$SourceDir = Join-Path $RepoRoot "build/windows/x64/runner/Release"
$OutputDir = Join-Path $RepoRoot "dist/windows"
$StagingDir = Join-Path $RepoRoot "build/windows/msix-staging"
$ManifestTemplate = Join-Path $PSScriptRoot "AppxManifest.xml"
$IconSource = Join-Path $RepoRoot "web/icons/Icon-512.png"
$PackagePath = Join-Path $OutputDir "$OutputName.msix"

if (-not (Test-Path (Join-Path $SourceDir "zmp3chart.exe"))) {
  throw "Windows release bundle not found at $SourceDir. Run flutter build windows --release first."
}
if (-not (Test-Path $IconSource)) { throw "App icon not found at $IconSource." }

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null

try {
  Copy-Item (Join-Path $SourceDir "*") $StagingDir -Recurse -Force
  $AssetsDir = Join-Path $StagingDir "Assets"
  New-Item -ItemType Directory -Force -Path $AssetsDir | Out-Null

  $SourceImage = [System.Drawing.Image]::FromFile($IconSource)
  try {
    New-TileAsset $SourceImage 50 50 (Join-Path $AssetsDir "StoreLogo.png")
    New-TileAsset $SourceImage 44 44 (Join-Path $AssetsDir "Square44x44Logo.png")
    New-TileAsset $SourceImage 150 150 (Join-Path $AssetsDir "Square150x150Logo.png")
    New-TileAsset $SourceImage 310 150 (Join-Path $AssetsDir "Wide310x150Logo.png")
    New-TileAsset $SourceImage 620 300 (Join-Path $AssetsDir "SplashScreen.png")
  } finally {
    $SourceImage.Dispose()
  }

  $Manifest = Get-Content $ManifestTemplate -Raw
  $Manifest = $Manifest.Replace("__PACKAGE_IDENTITY__", [Security.SecurityElement]::Escape($IdentityName))
  $Manifest = $Manifest.Replace("__PACKAGE_PUBLISHER__", [Security.SecurityElement]::Escape($Publisher))
  $Manifest = $Manifest.Replace("__PUBLISHER_DISPLAY_NAME__", [Security.SecurityElement]::Escape($PublisherDisplayName))
  $Manifest = $Manifest.Replace("__PACKAGE_VERSION__", $PackageVersion)
  $Manifest = $Manifest.Replace("__VCLIBS_NAME__", [Security.SecurityElement]::Escape($VCLibs.Name))
  $Manifest = $Manifest.Replace("__VCLIBS_MIN_VERSION__", $VCLibs.MinVersion)
  $Manifest = $Manifest.Replace("__VCLIBS_PUBLISHER__", [Security.SecurityElement]::Escape($VCLibs.Publisher))
  Set-Content -Path (Join-Path $StagingDir "AppxManifest.xml") -Value $Manifest -Encoding UTF8

  if (Test-Path $PackagePath) { Remove-Item $PackagePath -Force }
  $MakeAppx = Find-WindowsSdkTool "MakeAppx.exe"
  & $MakeAppx pack /d $StagingDir /p $PackagePath /o
  if ($LASTEXITCODE -ne 0) { throw "MakeAppx failed with exit code $LASTEXITCODE." }
  if (-not $SkipDependencyCopy) {
    $DependencyDir = Join-Path $OutputDir "dependencies"
    New-Item -ItemType Directory -Force -Path $DependencyDir | Out-Null
    Copy-Item $VCLibs.PackagePath $DependencyDir -Force
    @{
      name = $VCLibs.Name
      minVersion = $VCLibs.MinVersion
      fileName = [IO.Path]::GetFileName($VCLibs.PackagePath)
    } | ConvertTo-Json | Set-Content (Join-Path $DependencyDir "vclibs-dependency.json") -Encoding UTF8
  }
  Write-Host "Created MSIX package: $PackagePath"
} finally {
  if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
}
