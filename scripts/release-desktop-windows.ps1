# Build Windows desktop release (Inno Setup installer) and copy to gekychat public/downloads.
# Usage: .\scripts\release-desktop-windows.ps1
# Optional: -InstallLocal runs the installer silently

param(
    [switch]$InstallLocal
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$pubspec = Get-Content (Join-Path $root "pubspec.yaml") -Raw
if ($pubspec -notmatch 'version:\s*([\d.]+)\+(\d+)') {
    throw "Could not parse version from pubspec.yaml"
}
$versionName = $Matches[1]
$buildNumber = $Matches[2]
$setupName = "GekyChat-Setup-$versionName.exe"

$isccCandidates = @(
    "C:\InnoSetup6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    Write-Host "Inno Setup not found - installing to C:\InnoSetup6 ..." -ForegroundColor Yellow
    $installer = Join-Path $env:TEMP "innosetup-6.7.3.exe"
    if (-not (Test-Path $installer)) {
        Invoke-WebRequest -Uri "https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe" -OutFile $installer
    }
    Start-Process -FilePath $installer -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/DIR=C:\InnoSetup6" -Wait
    $iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $iscc) { throw "ISCC.exe not found. Install Inno Setup 6 and retry." }

Write-Host "Building GekyChat Desktop $versionName for Windows..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$iss = Join-Path $root "windows\installer\gekychat.iss"
Write-Host "Compiling installer with Inno Setup..." -ForegroundColor Cyan
& $iscc "/DMyAppVersion=$versionName" $iss
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$installerDir = Join-Path $root "build\windows\x64\installer\Release"
$builtInstaller = Join-Path $installerDir "GekyChat-x64-$versionName-Installer.exe"
if (-not (Test-Path $builtInstaller)) {
    throw "Installer not found: $builtInstaller"
}

$gekychatPublic = Join-Path (Split-Path -Parent $root) "gekychat\public\downloads"
New-Item -ItemType Directory -Force -Path $gekychatPublic | Out-Null

$setupPath = Join-Path $gekychatPublic $setupName
Copy-Item -Path $builtInstaller -Destination $setupPath -Force

$sizeMb = [math]::Round((Get-Item $setupPath).Length / 1048576, 1)
Write-Host ""
Write-Host ('Installer: {0} ({1} MB)' -f $setupPath, $sizeMb) -ForegroundColor Green
Write-Host ('URL:       https://gekychat.com/downloads/{0}' -f $setupName) -ForegroundColor Green
Write-Host ""
Write-Host ('Set production: APP_VERSION_WINDOWS_LATEST={0}+{1}' -f $versionName, $buildNumber) -ForegroundColor Yellow
Write-Host ('                APP_VERSION_WINDOWS_URL=https://gekychat.com/downloads/{0}' -f $setupName) -ForegroundColor Yellow

if ($InstallLocal) {
    Write-Host "Running installer silently..." -ForegroundColor Cyan
    Start-Process -FilePath $setupPath -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait
    Write-Host "Installed (check Start Menu for GekyChat)." -ForegroundColor Green
}
