# IITG Auto Login - Installation Script (Windows PowerShell)
# This script sets up the auto-login service and scheduled task

param(
    [switch]$Uninstall,
    [switch]$Help
)

if ($Help) {
    Write-Host "IITG Auto Login - Installation Script" -ForegroundColor Cyan
    Write-Host "Usage: .\install.ps1 [-Uninstall] [-Help]"
    Write-Host "  -Uninstall   Remove the scheduled task and service"
    Write-Host "  -Help        Show this help"
    exit 0
}

$TASK_NAME = "IITG Auto Login"
$SCRIPT_PATH = Join-Path $PSScriptRoot "auto_login.ps1"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to create scheduled task
function New-AutoLoginTask {
    Write-Host "Creating scheduled task for auto-login..." -ForegroundColor Yellow
    
    try {
        # Create action
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SCRIPT_PATH`""
        
        # Create triggers
        $triggerStartup = New-ScheduledTaskTrigger -AtStartup
        $triggerLogon = New-ScheduledTaskTrigger -AtLogOn
        $triggerNetworkChange = New-ScheduledTaskTrigger -AtStartup  # Will be modified for network events
        
        # Create settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        
        # Create principal (run as current user)
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
        
        # Register the task
        Register-ScheduledTask -TaskName $TASK_NAME -Action $action -Trigger @($triggerStartup, $triggerLogon) -Settings $settings -Principal $principal -Force | Out-Null
        
        Write-Host "✓ Scheduled task created successfully!" -ForegroundColor Green
        Write-Host "  Task Name: $TASK_NAME" -ForegroundColor White
        Write-Host "  Script Path: $SCRIPT_PATH" -ForegroundColor White
        
        # Create network change event task using XML
        $xmlTask = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>IITG Auto Login - Network Change Handler</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10000)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$env:USERNAME</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
    <RestartOnFailure>
      <Interval>PT1M</Interval>
      <Count>3</Count>
    </RestartOnFailure>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>PowerShell.exe</Command>
      <Arguments>-WindowStyle Hidden -ExecutionPolicy Bypass -File "$SCRIPT_PATH"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
        
        # Save XML to temp file and register
        $tempXmlPath = "$env:TEMP\iitg-network-task.xml"
        Set-Content -Path $tempXmlPath -Value $xmlTask -Encoding UTF8
        
        try {
            schtasks /create /tn "IITG Auto Login - Network Change" /xml $tempXmlPath /f | Out-Null
            Write-Host "✓ Network change task created successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Network change task creation failed, but main task is working" -ForegroundColor Yellow
        }
        finally {
            Remove-Item $tempXmlPath -Force -ErrorAction SilentlyContinue
        }
        
        return $true
    }
    catch {
        Write-Host "✗ Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to remove scheduled task
function Remove-AutoLoginTask {
    Write-Host "Removing scheduled task..." -ForegroundColor Yellow
    
    try {
        # Remove main task
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue
        
        # Remove network change task
        schtasks /delete /tn "IITG Auto Login - Network Change" /f 2>$null | Out-Null
        
        Write-Host "✓ Scheduled tasks removed successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Failed to remove scheduled task: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to create desktop shortcut
function New-DesktopShortcut {
    Write-Host "Creating desktop shortcut..." -ForegroundColor Yellow
    
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcutPath = "$env:USERPROFILE\Desktop\IITG Auto Login.lnk"
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "PowerShell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$SCRIPT_PATH`""
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.WindowStyle = 7  # Minimized
        $shortcut.Description = "IITG Auto Login Service"
        $shortcut.Save()
        
        Write-Host "✓ Desktop shortcut created!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "⚠ Failed to create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Function to remove desktop shortcut
function Remove-DesktopShortcut {
    $shortcutPath = "$env:USERPROFILE\Desktop\IITG Auto Login.lnk"
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Host "✓ Desktop shortcut removed!" -ForegroundColor Green
    }
}

# Main installation logic
Write-Host ""
Write-Host "IITG Auto Login - Installation Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $SCRIPT_PATH)) {
    Write-Host "✗ auto_login.ps1 not found in current directory!" -ForegroundColor Red
    Write-Host "Please run this script from the same directory as auto_login.ps1" -ForegroundColor Yellow
    exit 1
}

if ($Uninstall) {
    Write-Host "Uninstalling IITG Auto Login..." -ForegroundColor Yellow
    Write-Host ""
    
    Remove-AutoLoginTask | Out-Null
    Remove-DesktopShortcut
    
    Write-Host ""
    Write-Host "✓ IITG Auto Login uninstalled successfully!" -ForegroundColor Green
    Write-Host "Configuration files in $env:USERPROFILE\iitg-auto-login are preserved." -ForegroundColor Yellow
}
else {
    Write-Host "Installing IITG Auto Login..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check if configuration exists
    $configFile = "$env:USERPROFILE\iitg-auto-login\config.env"
    if (-not (Test-Path $configFile)) {
        Write-Host "⚠ Configuration file not found!" -ForegroundColor Yellow
        Write-Host "Please run .\update_creds.ps1 first to set up your credentials." -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "Do you want to set up credentials now? (y/n)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            & "$PSScriptRoot\update_creds.ps1"
        }
        else {
            Write-Host "Installation aborted. Please run update_creds.ps1 first." -ForegroundColor Red
            exit 1
        }
    }
    
    $success = $true
    
    # Create scheduled task
    if (-not (New-AutoLoginTask)) {
        $success = $false
    }
    
    # Create desktop shortcut
    New-DesktopShortcut | Out-Null
    
    Write-Host ""
    if ($success) {
        Write-Host "✓ IITG Auto Login installed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The service will:" -ForegroundColor Cyan
        Write-Host "  • Start automatically when Windows starts" -ForegroundColor White
        Write-Host "  • Start when you log in" -ForegroundColor White
        Write-Host "  • Restart when network changes are detected" -ForegroundColor White
        Write-Host "  • Retry automatically on failures" -ForegroundColor White
        Write-Host ""
        Write-Host "You can:" -ForegroundColor Cyan
        Write-Host "  • Use the desktop shortcut to start manually" -ForegroundColor White
        Write-Host "  • Check Task Scheduler for 'IITG Auto Login' tasks" -ForegroundColor White
        Write-Host "  • Run .\install.ps1 -Uninstall to remove" -ForegroundColor White
        Write-Host ""
        Write-Host "Starting the service now..." -ForegroundColor Yellow
        Start-ScheduledTask -TaskName $TASK_NAME
        Write-Host "✓ Service started!" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Installation completed with some errors." -ForegroundColor Red
        Write-Host "Please check the output above for details." -ForegroundColor Yellow
    }
}

Write-Host ""
