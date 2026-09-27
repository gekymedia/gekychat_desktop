# Sync shipped app version to GekyChat server (Admin → App Versions equivalent).
# Usage:
#   .\scripts\sync-server-app-version.ps1 -Platform windows -Version "1.0.0+14" -DownloadUrl "https://gekychat.com/downloads/GekyChat-Setup-1.0.0-14.exe"
#
# Credentials:
#   - $env:APP_VERSION_DEPLOY_TOKEN
#   - .deploy.env at project root (APP_VERSION_DEPLOY_TOKEN=...)
#
# API base URL from .env API_BASE_URL (e.g. https://api.gekychat.com/api/v1).

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("android", "ios", "windows", "macos", "linux")]
    [string]$Platform,

    [string]$Version = "",

    [string]$DownloadUrl = "",

    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Get-Location }

function Read-DotEnvValue {
    param([string]$FilePath, [string]$Key)
    if (-not (Test-Path $FilePath)) { return $null }
    foreach ($line in Get-Content $FilePath) {
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.+?)\s*$") {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

$pubspecPath = Join-Path $root "pubspec.yaml"
if ($Version -eq "") {
    if (-not (Test-Path $pubspecPath)) {
        Write-Host "ERROR: pubspec.yaml not found and -Version not provided." -ForegroundColor Red
        exit 1
    }
    $pubspec = Get-Content $pubspecPath -Raw
    if ($pubspec -notmatch 'version:\s*([\d.]+\+\d+)') {
        Write-Host "ERROR: Could not parse version from pubspec.yaml." -ForegroundColor Red
        exit 1
    }
    $Version = $Matches[1]
}

$token = $env:APP_VERSION_DEPLOY_TOKEN
if (-not $token) {
    $token = Read-DotEnvValue (Join-Path $root ".deploy.env") "APP_VERSION_DEPLOY_TOKEN"
}

if (-not $token) {
    $msg = "Skipping server version sync: APP_VERSION_DEPLOY_TOKEN not set."
    if ($Strict) {
        Write-Host "ERROR: $msg" -ForegroundColor Red
        exit 1
    }
    Write-Host "WARNING: $msg" -ForegroundColor Yellow
    exit 0
}

$apiBase = Read-DotEnvValue (Join-Path $root ".env") "API_BASE_URL"
if (-not $apiBase) {
    $apiBase = "https://api.gekychat.com/api/v1"
}

$apiBase = $apiBase.TrimEnd("/")
$uri = "$apiBase/app/version/latest"
$bodyHash = @{
    platform = $Platform
    latest_version = $Version
}
if ($DownloadUrl -ne "") {
    $bodyHash.download_url = $DownloadUrl
}
$body = $bodyHash | ConvertTo-Json

Write-Host "Syncing server latest version: $Platform -> $Version" -ForegroundColor Cyan
if ($DownloadUrl -ne "") {
    Write-Host "  download_url: $DownloadUrl" -ForegroundColor Cyan
}

try {
    $response = Invoke-RestMethod `
        -Method Patch `
        -Uri $uri `
        -Headers @{ Authorization = "Bearer $token" } `
        -ContentType "application/json" `
        -Body $body

    Write-Host "Server updated: latest_version=$($response.data.latest_version)" -ForegroundColor Green
    if ($response.data.download_url) {
        Write-Host "  download_url=$($response.data.download_url)" -ForegroundColor Green
    }
} catch {
    $detail = $_.Exception.Message
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        $detail = $_.ErrorDetails.Message
    }
    if ($Strict) {
        Write-Host "ERROR: Server version sync failed: $detail" -ForegroundColor Red
        exit 1
    }
    Write-Host "WARNING: Server version sync failed: $detail" -ForegroundColor Yellow
    exit 0
}
