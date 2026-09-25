# Build Windows desktop release (Inno Setup installer) and copy to gekychat public/downloads.
# Usage: .\scripts\release-desktop-windows.ps1
# Optional: -InstallLocal runs the installer silently
#
# Artifacts:
#   GekyChat-Setup-{version}-{build}.exe  — versioned, never overwritten across releases
#   downloads/archive/                    — previous Setup*.exe moved here before replace
#   GekyChat-Setup-latest.exe             — always the newest (convenience / landing page)

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
# Public filename includes build so each release is unique (1.0.0-2, not just 1.0.0).
$versionedSetupName = "GekyChat-Setup-$versionName-$buildNumber.exe"
$latestSetupName = "GekyChat-Setup-latest.exe"
# Inno "AppVersion" display (Windows-style 4-part when possible).
$innoVersion = "$versionName.$buildNumber"

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

Write-Host "Building GekyChat Desktop $versionName+$buildNumber for Windows..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$iss = Join-Path $root "windows\installer\gekychat.iss"
Write-Host "Compiling installer with Inno Setup..." -ForegroundColor Cyan
& $iscc "/DMyAppVersion=$innoVersion" $iss
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$installerDir = Join-Path $root "build\windows\x64\installer\Release"
$builtInstaller = Join-Path $installerDir "GekyChat-x64-$innoVersion-Installer.exe"
if (-not (Test-Path $builtInstaller)) {
    # Fallback if ISS still used marketing version only
    $builtInstaller = Join-Path $installerDir "GekyChat-x64-$versionName-Installer.exe"
}
if (-not (Test-Path $builtInstaller)) {
    throw "Installer not found under $installerDir"
}

$gekychatPublic = Join-Path (Split-Path -Parent $root) "gekychat\public\downloads"
$archiveDir = Join-Path $gekychatPublic "archive"
New-Item -ItemType Directory -Force -Path $gekychatPublic | Out-Null
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

function Move-ToArchiveIfExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $name = Split-Path $Path -Leaf
    $dest = Join-Path $archiveDir $name
    if (Test-Path $dest) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $dest = Join-Path $archiveDir ("{0}.{1}" -f [IO.Path]::GetFileNameWithoutExtension($name), "$stamp.exe")
    }
    Move-Item -Path $Path -Destination $dest -Force
    Write-Host "Archived previous: $name -> archive\" -ForegroundColor DarkYellow
}

# Archive prior convenience "latest" and any same versioned name (rebuilds).
Move-ToArchiveIfExists (Join-Path $gekychatPublic $latestSetupName)
Move-ToArchiveIfExists (Join-Path $gekychatPublic $versionedSetupName)
# Also archive the legacy unversioned name if present.
Move-ToArchiveIfExists (Join-Path $gekychatPublic "GekyChat-Setup-$versionName.exe")

$versionedPath = Join-Path $gekychatPublic $versionedSetupName
$latestPath = Join-Path $gekychatPublic $latestSetupName
Copy-Item -Path $builtInstaller -Destination $versionedPath -Force
Copy-Item -Path $builtInstaller -Destination $latestPath -Force

$sizeMb = [math]::Round((Get-Item $versionedPath).Length / 1048576, 1)
$publicUrl = "https://gekychat.com/downloads/$versionedSetupName"
Write-Host ""
Write-Host ('Installer (versioned): {0} ({1} MB)' -f $versionedPath, $sizeMb) -ForegroundColor Green
Write-Host ('Installer (latest):    {0}' -f $latestPath) -ForegroundColor Green
Write-Host ('URL:                   {0}' -f $publicUrl) -ForegroundColor Green
Write-Host ""
Write-Host ('Set production: APP_VERSION_WINDOWS_LATEST={0}+{1}' -f $versionName, $buildNumber) -ForegroundColor Yellow
Write-Host ('                APP_VERSION_WINDOWS_URL={0}' -f $publicUrl) -ForegroundColor Yellow

# EXEs are gitignored — scp them to production so versioned URLs do not 404.
$sshHost = if ($env:GEKYCHAT_SSH_HOST) { $env:GEKYCHAT_SSH_HOST } else { "root@159.195.249.203" }
$remoteDownloads = "/var/www/chat.gekychat.com/public/downloads"
$appUser = "gekychat"
Write-Host ""
Write-Host "Uploading installers to $sshHost:$remoteDownloads ..." -ForegroundColor Cyan
ssh $sshHost "mkdir -p $remoteDownloads/archive && chown -R ${appUser}:${appUser} $remoteDownloads"
if ($LASTEXITCODE -ne 0) { throw "ssh mkdir downloads failed" }
scp $versionedPath "${sshHost}:${remoteDownloads}/"
if ($LASTEXITCODE -ne 0) { throw "scp failed for $versionedSetupName" }
scp $latestPath "${sshHost}:${remoteDownloads}/"
if ($LASTEXITCODE -ne 0) { throw "scp failed for $latestSetupName" }
ssh $sshHost "chown -R ${appUser}:${appUser} $remoteDownloads 2>/dev/null || true; chmod 644 $remoteDownloads/$versionedSetupName $remoteDownloads/$latestSetupName 2>/dev/null || true"
Write-Host "Desktop downloads uploaded." -ForegroundColor Green

# Sync version + download URL when deploy token is available (same as mobile).
$syncScript = Join-Path $root "scripts\sync-server-app-version.ps1"
if (-not (Test-Path $syncScript)) {
    # Shared script lives in the mobile repo sibling.
    $syncScript = Join-Path (Split-Path -Parent $root) "gekychat_mobile\scripts\sync-server-app-version.ps1"
}
if (Test-Path $syncScript) {
    & $syncScript -Platform windows -Version ("{0}+{1}" -f $versionName, $buildNumber) -DownloadUrl $publicUrl
}

if ($InstallLocal) {
    Write-Host "Running installer silently..." -ForegroundColor Cyan
    Start-Process -FilePath $versionedPath -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait
    Write-Host "Installed (check Start Menu for GekyChat)." -ForegroundColor Green
}
