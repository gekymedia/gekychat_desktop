# Script to help install ATL components for Windows Flutter build

Write-Host "`n=== GekyChat Desktop - ATL Component Installer ===" -ForegroundColor Cyan
Write-Host "This script will help you install the required ATL components`n" -ForegroundColor White

$vsInstaller = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"

if (-not (Test-Path $vsInstaller)) {
    Write-Host "❌ Visual Studio Installer not found!" -ForegroundColor Red
    Write-Host "`nPlease install Visual Studio Build Tools first:" -ForegroundColor Yellow
    Write-Host "  https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor Cyan
    Write-Host "`nWhen installing, select:" -ForegroundColor White
    Write-Host "  ✓ Desktop development with C++" -ForegroundColor Green
    Write-Host "  ✓ Windows SDK (latest version)" -ForegroundColor Green
    Write-Host "  ✓ C++ ATL for latest v143 build tools" -ForegroundColor Green
    exit 1
}

Write-Host "✅ Visual Studio Installer found!" -ForegroundColor Green
Write-Host "`nOpening Visual Studio Installer..." -ForegroundColor White

# Try to open the installer
Start-Process $vsInstaller

Write-Host "`n=== Manual Steps ===" -ForegroundColor Cyan
Write-Host "1. In the Visual Studio Installer window:" -ForegroundColor White
Write-Host "   → Click 'Modify' on your Visual Studio installation" -ForegroundColor Yellow
Write-Host "`n2. Go to the 'Individual components' tab" -ForegroundColor White
Write-Host "`n3. In the search box, type: ATL" -ForegroundColor White
Write-Host "`n4. Check the following box:" -ForegroundColor White
Write-Host "   ☑ C++ ATL for latest v143 build tools (x86 & x64)" -ForegroundColor Green
Write-Host "`n5. Click 'Modify' button at the bottom" -ForegroundColor White
Write-Host "`n6. Wait for installation to complete" -ForegroundColor White
Write-Host "`n7. After installation, run:" -ForegroundColor White
Write-Host "   flutter clean" -ForegroundColor Yellow
Write-Host "   flutter pub get" -ForegroundColor Yellow
Write-Host "   flutter run -d windows" -ForegroundColor Yellow
Write-Host "`n=== Done! ===" -ForegroundColor Cyan

