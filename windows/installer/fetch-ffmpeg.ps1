# Fetch a Windows x64 ffmpeg.exe into third_party/ffmpeg for the Inno installer.
# Run before packaging:  powershell -File windows\installer\fetch-ffmpeg.ps1
# LGPL/GPL: gyan.dev "essentials" build — keep license attribution in distro notes.

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$destDir = Join-Path $root 'third_party\ffmpeg'
$destExe = Join-Path $destDir 'ffmpeg.exe'
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'

New-Item -ItemType Directory -Force -Path $destDir | Out-Null

if (Test-Path $destExe) {
  Write-Host "Already have $destExe"
} else {
  $zipUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
  $zipPath = Join-Path $env:TEMP 'ffmpeg-essentials.zip'
  Write-Host "Downloading $zipUrl ..."
  Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
  $extract = Join-Path $env:TEMP 'ffmpeg-essentials-extract'
  if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
  Expand-Archive -Path $zipPath -DestinationPath $extract
  $found = Get-ChildItem -Path $extract -Recurse -Filter 'ffmpeg.exe' |
    Where-Object { $_.DirectoryName -match '\\bin$' } |
    Select-Object -First 1
  if (-not $found) { throw 'ffmpeg.exe not found inside archive' }
  Copy-Item $found.FullName $destExe -Force
  Write-Host "Wrote $destExe"
}

if (Test-Path $releaseDir) {
  Copy-Item $destExe (Join-Path $releaseDir 'ffmpeg.exe') -Force
  Write-Host 'Copied into Release for local runs'
} else {
  Write-Host 'Release folder not built yet - Inno will still pick up third_party\ffmpeg\ffmpeg.exe'
}
