# IITG Auto Login - Uninstall Script (Windows PowerShell)

Write-Host ""
Write-Host "IITG Auto Login - Uninstall Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This will remove the IITG Auto Login service from your system." -ForegroundColor Yellow
Write-Host "Configuration files will be preserved unless you choose to remove them." -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "Do you want to continue? (y/n)"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Uninstall cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Uninstalling IITG Auto Login..." -ForegroundColor Yellow

# Stop any running instances
Write-Host "Stopping running instances..." -ForegroundColor Yellow
Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*auto_login.ps1*"
} | ForEach-Object {
    Write-Host "  Stopping process PID: $($_.Id)"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# Remove scheduled tasks
Write-Host "Removing scheduled tasks..." -ForegroundColor Yellow
try {
    Unregister-ScheduledTask -TaskName "IITG Auto Login" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  ✓ Main task removed"
}
catch {
    Write-Host "  ⚠ Main task not found or already removed"
}

try {
    schtasks /delete /tn "IITG Auto Login - Network Change" /f 2>$null | Out-Null
    Write-Host "  ✓ Network change task removed"
}
catch {
    Write-Host "  ⚠ Network change task not found or already removed"
}

# Remove desktop shortcut
Write-Host "Removing desktop shortcut..." -ForegroundColor Yellow
$shortcutPath = "$env:USERPROFILE\Desktop\IITG Auto Login.lnk"
if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Host "  ✓ Desktop shortcut removed"
}
else {
    Write-Host "  ⚠ Desktop shortcut not found"
}

# Clean up temporary files
Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
$tempFiles = @(
    "$env:TEMP\iitg_cookies.txt",
    "$env:TEMP\iitg-auto_login.log"
)

foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed $file"
    }
}

Write-Host ""
Write-Host "✓ IITG Auto Login uninstalled successfully!" -ForegroundColor Green

# Ask about configuration files
Write-Host ""
$configDir = "$env:USERPROFILE\iitg-auto-login"
if (Test-Path $configDir) {
    Write-Host "Configuration directory found: $configDir" -ForegroundColor Yellow
    $removeConfig = Read-Host "Do you want to remove configuration files (including saved credentials)? (y/n)"
    
    if ($removeConfig -eq 'y' -or $removeConfig -eq 'Y') {
        Remove-Item $configDir -Recurse -Force
        Write-Host "✓ Configuration files removed" -ForegroundColor Green
    }
    else {
        Write-Host "Configuration files preserved for future use" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Uninstall complete!" -ForegroundColor Green
Write-Host ""
