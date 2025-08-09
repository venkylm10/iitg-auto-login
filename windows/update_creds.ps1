# IITG Auto Login - Credentials Update Script (Windows PowerShell)

Write-Host "IITG Auto Login - Credentials Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Get credentials from user
$username = Read-Host "Enter your username"
$securePassword = Read-Host "Enter your password" -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

# Create the directory for config if it doesn't exist
$configDir = "$env:USERPROFILE\iitg-auto-login"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    Write-Host "Created configuration directory: $configDir" -ForegroundColor Green
}

$configFile = "$configDir\config.env"

# Write new content to the file
$configContent = @"
USERNAME=$username
PASSWORD=$password
"@

Set-Content -Path $configFile -Value $configContent -Encoding UTF8

Write-Host ""
Write-Host "Credentials updated successfully!" -ForegroundColor Green
Write-Host "Configuration saved to: $configFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "You can now run the auto-login script with:" -ForegroundColor Cyan
Write-Host "  .\auto_login.ps1" -ForegroundColor White
Write-Host "  .\auto_login.ps1 -Test    # For testing connectivity" -ForegroundColor White
Write-Host "  .\auto_login.ps1 -Debug   # For debug output" -ForegroundColor White
