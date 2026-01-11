# Fix Build Lock Error for GekyChat Desktop
# This script kills any running instances of the app that might be locking the build files
# Usage: . .\fix_build_lock.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Fixing Build Lock Issue " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory (should be gekychat_desktop)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Find and kill any running GekyChat Desktop processes
Write-Host "Checking for running GekyChat Desktop processes..." -ForegroundColor Yellow

$processes = Get-Process | Where-Object {
    $_.ProcessName -like "*gekychat_desktop*" -or 
    $_.ProcessName -like "*gekychat*desktop*" -or
    $_.MainWindowTitle -like "*GekyChat*Desktop*" -or
    $_.MainWindowTitle -like "*GekyChat Desktop*"
} | Where-Object {
    # Exclude Flutter itself to avoid killing the build process
    $_.ProcessName -notlike "*flutter*" -and $_.Path -like "*gekychat_desktop*"
}

if ($processes) {
    Write-Host "Found $($processes.Count) running process(es):" -ForegroundColor Yellow
    foreach ($proc in $processes) {
        Write-Host "  - $($proc.ProcessName) (PID: $($proc.Id)) - $($proc.Path)" -ForegroundColor White
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Host "    ✓ Terminated" -ForegroundColor Green
        } catch {
            Write-Host "    ✗ Failed to terminate: $_" -ForegroundColor Red
        }
    }
    Start-Sleep -Seconds 2
} else {
    Write-Host "  ✓ No running GekyChat Desktop processes found" -ForegroundColor Green
}

Write-Host ""

# Check if the build file exists and try to remove it
$buildExe = Join-Path $scriptDir "build\windows\x64\runner\Debug\gekychat_desktop.exe"
if (Test-Path $buildExe) {
    Write-Host "Removing existing build executable..." -ForegroundColor Yellow
    try {
        # Try to remove with retry logic
        $retries = 3
        $removed = $false
        for ($i = 1; $i -le $retries; $i++) {
            try {
                Remove-Item $buildExe -Force -ErrorAction Stop
                Write-Host "  ✓ Build executable removed" -ForegroundColor Green
                $removed = $true
                break
            } catch {
                if ($i -lt $retries) {
                    Write-Host "  ⚠ Attempt $i failed, retrying in 2 seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                } else {
                    Write-Host "  ✗ Could not remove build executable after $retries attempts" -ForegroundColor Red
                    Write-Host "    Error: $_" -ForegroundColor Red
                    Write-Host "    Please manually close the app and delete: $buildExe" -ForegroundColor Yellow
                }
            }
        }
    } catch {
        Write-Host "  ✗ Error checking build file: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ✓ No existing build executable found" -ForegroundColor Green
}

Write-Host ""

# Clean Flutter build
Write-Host "Cleaning Flutter build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Build cleaned successfully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Build clean failed" -ForegroundColor Red
}

Write-Host ""

# Get dependencies
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Dependencies fetched successfully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to get dependencies" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Ready to Build! ✓" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Make sure no GekyChat Desktop app is running" -ForegroundColor White
Write-Host "  2. Run: flutter run" -ForegroundColor White
Write-Host "  OR" -ForegroundColor White
Write-Host "  2. Run: flutter build windows" -ForegroundColor White
Write-Host ""
