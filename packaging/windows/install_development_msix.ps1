param(
  [string]$PackageDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
$Principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run this development installer from an elevated PowerShell window."
}

$CertificatePath = Join-Path $PackageDirectory "zingchart-development.cer"
$PackagePath = Join-Path $PackageDirectory "zingchart-windows-development.msix"
$DependencyDirectory = Join-Path $PackageDirectory "dependencies"
$DependencyMetadataPath = Join-Path $DependencyDirectory "vclibs-dependency.json"

if (-not (Test-Path $CertificatePath)) { throw "Development certificate not found: $CertificatePath" }
if (-not (Test-Path $PackagePath)) { throw "Development MSIX not found: $PackagePath" }
if (-not (Test-Path $DependencyMetadataPath)) { throw "VCLibs dependency metadata was not found: $DependencyMetadataPath" }

$DependencyMetadata = Get-Content $DependencyMetadataPath -Raw | ConvertFrom-Json
$DependencyPath = Join-Path $DependencyDirectory $DependencyMetadata.fileName
if (-not (Test-Path $DependencyPath)) { throw "VCLibs x64 dependency was not found: $DependencyPath" }

$RequiredDependencyVersion = [version]$DependencyMetadata.minVersion
$InstalledDependency = Get-AppxPackage -Name $DependencyMetadata.name |
  Where-Object { $_.Architecture -eq "X64" } |
  Sort-Object { [version]$_.Version } -Descending |
  Select-Object -First 1

$ImportedCertificate = Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople"
try {
  if (-not $InstalledDependency -or [version]$InstalledDependency.Version -lt $RequiredDependencyVersion) {
    Add-AppxPackage -Path $DependencyPath
  } else {
    Write-Host "VCLibs $($InstalledDependency.Version) is already installed; dependency install skipped."
  }
  Add-AppxPackage -Path $PackagePath
  Write-Host "#zingChart development MSIX installed successfully."
  Write-Host "Remove the test certificate after evaluation: Remove-Item 'Cert:\LocalMachine\TrustedPeople\$($ImportedCertificate.Thumbprint)'"
} catch {
  Remove-Item "Cert:\LocalMachine\TrustedPeople\$($ImportedCertificate.Thumbprint)" -Force -ErrorAction SilentlyContinue
  throw
}
