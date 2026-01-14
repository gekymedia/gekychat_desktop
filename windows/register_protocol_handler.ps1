# PowerShell script to register gekychat:// protocol handler
# Run this script as Administrator or during installation

param(
    [Parameter(Mandatory=$true)]
    [string]$AppPath
)

$ErrorActionPreference = "Stop"

Write-Host "Registering gekychat:// protocol handler..." -ForegroundColor Green

# Registry paths
$protocolPath = "HKCU:\Software\Classes\gekychat"
$shellPath = "$protocolPath\shell\open\command"

try {
    # Create protocol key
    New-Item -Path $protocolPath -Force | Out-Null
    Set-ItemProperty -Path $protocolPath -Name "(Default)" -Value "URL:GekyChat Protocol" -Type String
    Set-ItemProperty -Path $protocolPath -Name "URL Protocol" -Value "" -Type String
    
    # Create DefaultIcon
    New-Item -Path "$protocolPath\DefaultIcon" -Force | Out-Null
    Set-ItemProperty -Path "$protocolPath\DefaultIcon" -Name "(Default)" -Value "`"$AppPath`"" -Type String
    
    # Create shell\open\command
    New-Item -Path "$protocolPath\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path "$protocolPath\shell\open\command" -Name "(Default)" -Value "`"$AppPath`" `"%1`"" -Type String
    
    Write-Host "✅ Protocol handler registered successfully!" -ForegroundColor Green
    Write-Host "   Protocol: gekychat://" -ForegroundColor Cyan
    Write-Host "   App Path: $AppPath" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Error registering protocol handler: $_" -ForegroundColor Red
    exit 1
}
