# IITG Auto Login - Service Dispatcher (Windows PowerShell)
# This script acts as a lightweight dispatcher for the main auto-login service

param(
    [switch]$Start,
    [switch]$Stop,
    [switch]$Restart,
    [switch]$Status,
    [switch]$Help
)

if ($Help) {
    Write-Host "IITG Auto Login - Service Dispatcher" -ForegroundColor Cyan
    Write-Host "Usage: .\dispatcher.ps1 [-Start] [-Stop] [-Restart] [-Status] [-Help]"
    Write-Host "  -Start     Start the auto-login service"
    Write-Host "  -Stop      Stop the auto-login service"
    Write-Host "  -Restart   Restart the auto-login service"
    Write-Host "  -Status    Show service status"
    Write-Host "  -Help      Show this help"
    exit 0
}

$SCRIPT_PATH = Join-Path $PSScriptRoot "auto_login.ps1"

# Function to get running instances
function Get-AutoLoginProcesses {
    return Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*auto_login.ps1*"
    }
}

# Function to start the service
function Start-AutoLoginService {
    Write-Host "Starting IITG Auto Login service..." -ForegroundColor Yellow
    
    $runningProcesses = Get-AutoLoginProcesses
    if ($runningProcesses) {
        Write-Host "Service is already running (PID: $($runningProcesses.Id -join ', '))" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-Path $SCRIPT_PATH)) {
        Write-Host "✗ auto_login.ps1 not found!" -ForegroundColor Red
        return
    }
    
    try {
        # Start the service in a new window (hidden)
        $process = Start-Process -FilePath "PowerShell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SCRIPT_PATH`"" -PassThru
        
        # Wait a moment to check if it started successfully
        Start-Sleep -Seconds 2
        
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
            Write-Host "✓ Service started successfully (PID: $($process.Id))" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Service failed to start" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Failed to start service: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to stop the service
function Stop-AutoLoginService {
    Write-Host "Stopping IITG Auto Login service..." -ForegroundColor Yellow
    
    $runningProcesses = Get-AutoLoginProcesses
    if (-not $runningProcesses) {
        Write-Host "Service is not running" -ForegroundColor Yellow
        return
    }
    
    foreach ($process in $runningProcesses) {
        try {
            Stop-Process -Id $process.Id -Force
            Write-Host "✓ Stopped process PID: $($process.Id)" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to stop process PID: $($process.Id)" -ForegroundColor Red
        }
    }
}

# Function to show service status
function Show-ServiceStatus {
    Write-Host "IITG Auto Login Service Status" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    
    $runningProcesses = Get-AutoLoginProcesses
    
    if ($runningProcesses) {
        Write-Host "Status: RUNNING" -ForegroundColor Green
        Write-Host "Processes:" -ForegroundColor White
        foreach ($process in $runningProcesses) {
            $startTime = $process.StartTime
            $runtime = (Get-Date) - $startTime
            Write-Host "  PID: $($process.Id), Started: $($startTime.ToString('yyyy-MM-dd HH:mm:ss')), Runtime: $($runtime.ToString('dd\.hh\:mm\:ss'))" -ForegroundColor White
        }
    }
    else {
        Write-Host "Status: STOPPED" -ForegroundColor Red
    }
    
    # Check scheduled task status
    Write-Host ""
    Write-Host "Scheduled Task Status:" -ForegroundColor Cyan
    try {
        $task = Get-ScheduledTask -TaskName "IITG Auto Login" -ErrorAction SilentlyContinue
        if ($task) {
            Write-Host "  Main Task: $($task.State)" -ForegroundColor White
        }
        else {
            Write-Host "  Main Task: NOT FOUND" -ForegroundColor Red
        }
        
        $networkTask = schtasks /query /tn "IITG Auto Login - Network Change" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Network Task: READY" -ForegroundColor White
        }
        else {
            Write-Host "  Network Task: NOT FOUND" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Error checking tasks: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Check configuration
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    $configFile = "$env:USERPROFILE\iitg-auto-login\config.env"
    if (Test-Path $configFile) {
        Write-Host "  Config File: FOUND" -ForegroundColor Green
        try {
            $config = Get-Content $configFile | Where-Object { $_ -match '^[^#]' } | ConvertFrom-StringData
            if ($config.USERNAME) {
                Write-Host "  Username: $($config.USERNAME)" -ForegroundColor White
            }
        }
        catch {
            Write-Host "  Config File: ERROR READING" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  Config File: NOT FOUND" -ForegroundColor Red
    }
}

# Main execution
Write-Host ""

if ($Status -or (-not $Start -and -not $Stop -and -not $Restart)) {
    Show-ServiceStatus
}
elseif ($Start) {
    Start-AutoLoginService
}
elseif ($Stop) {
    Stop-AutoLoginService
}
elseif ($Restart) {
    Stop-AutoLoginService
    Start-Sleep -Seconds 2
    Start-AutoLoginService
}

Write-Host ""
