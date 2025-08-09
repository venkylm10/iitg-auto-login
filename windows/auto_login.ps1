# IITG Auto Login Script - Windows PowerShell Version
# Direct port of Linux bash script functionality

param(
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\auto_login.ps1 [-Help]"
    Write-Host "  -Help    Show this help"
    exit 0
}

# Configuration
$PROCESS_NAME = "auto_login"
$LOGFILE = "$env:TEMP\iitg-auto_login.log"
$LOG_MAX_LINES = 5000  # log rotation threshold
$USERHOME = $env:USERPROFILE
$CONFIG_FILE = "$USERHOME\iitg-auto-login\config.env"
$COOKIES_FILE = "$env:TEMP\iitg_cookies.txt"

# Global variables for session management
$global:session_param = ""
$global:keepalive = ""
$global:username = ""
$global:password = ""

function Rotate-LogIfLarge {
    if (Test-Path $LOGFILE) {
        try {
            $lineCount = (Get-Content -Path $LOGFILE -ErrorAction Stop | Measure-Object -Line).Lines
            if ($lineCount -ge $LOG_MAX_LINES) {
                try { Stop-Transcript | Out-Null } catch { }
                Set-Content -Path $LOGFILE -Value "Log truncated at $(Get-Date) (`$lineCount lines exceeded $LOG_MAX_LINES)`n"
                Start-Transcript -Path $LOGFILE -Append | Out-Null
            }
        } catch { }
    }
}

# Start logging
Start-Transcript -Path $LOGFILE -Append | Out-Null
Rotate-LogIfLarge
Write-Host "Script started at $(Get-Date)"

# Load configuration
if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "[*] Configuration file not found!"
    exit 1
}

try {
    $config = Get-Content $CONFIG_FILE | Where-Object { $_ -match '^[^#]' } | ConvertFrom-StringData
    $global:username = $config.USERNAME
    $global:password = $config.PASSWORD
    
    if (-not $global:username -or -not $global:password) {
        Write-Host "[*] Username or password not found in configuration!"
        exit 1
    }
}
catch {
    Write-Host "[*] Error loading configuration: $($_.Exception.Message)"
    exit 1
}

# Function to handle cleanup on exit
function Invoke-Cleanup {
    Write-Host "[*] Cleaning up..."
    if (Test-Path $COOKIES_FILE) {
        Remove-Item $COOKIES_FILE -Force
    }
    try { Stop-Transcript | Out-Null } catch { }
    exit 0
}

# Function to terminate any previous instance of the script
function Stop-PreviousInstances {
    Write-Host "[*] Terminating any previous instances of the script..."
    $currentPID = $PID
    
    Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
        $_.Id -ne $currentPID -and $_.CommandLine -like "*auto_login.ps1*"
    } | ForEach-Object {
        Stop-Process -Id $_.Id -Force
        Write-Host "[*] Terminated previous instance with PID: $($_.Id)"
    }
}

# Function to logout from the IITG portal
function Invoke-Logout {
    Write-Host "[*] Logging out..."
    
    try {
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
        }
        
        $logoutUrl = if ($global:session_param) {
            "https://agnigarh.iitg.ac.in:1442/logout?$global:session_param"
        } else {
            "https://agnigarh.iitg.ac.in:1442/logout?"
        }
        
        $response = Invoke-WebRequest -Uri $logoutUrl -Headers $headers -UseBasicParsing -ErrorAction Stop
        Write-Host "[*] Logged out!"
        return $true
    }
    catch {
        Write-Host "[*] Logout failed!"
        return $false
    }
}

# Function to login
function Invoke-Login {
    Invoke-Logout | Out-Null  # Make sure to logout first
    Write-Host "Logging in with Username: $global:username"

    # Clean up any existing cookies
    if (Test-Path $COOKIES_FILE) {
        Remove-Item $COOKIES_FILE -Force
    }

    try {
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
        }
        
        $loginUrl = "https://agnigarh.iitg.ac.in:1442/login?"
        
        # Get login page
        $loginPage = Invoke-WebRequest -Uri $loginUrl -Headers $headers -UseBasicParsing -ErrorAction Stop
        
        # Extract magic value
        if ($loginPage.Content -match 'name="magic" value="([^"]+)"') {
            $magic = $matches[1]
        }
        else {
            Write-Host "[*] Magic value not found!"
            exit 1
        }

        # Prepare POST data
        $data = "4Tredir=http%3A%2F%2Fspeedtest.net%2F&magic=$magic&username=$global:username&password=$global:password"
        
        $headers["Content-Type"] = "application/x-www-form-urlencoded"
        $headers["Referer"] = $loginUrl

        # POST to base URL, not login URL based on network logs
        $loginResponse = Invoke-WebRequest -Uri "https://agnigarh.iitg.ac.in:1442/" -Method POST -Body $data -Headers $headers -UseBasicParsing -ErrorAction Stop

        Write-Host "Login successful"
        
        # Extract keepalive URL
        if ($loginResponse.Content -match 'window\.location="([^"]+)"') {
            $global:keepalive = $matches[1]
            
            # Extract session parameter from keepalive URL for logout
            if ($global:keepalive -match '\?([^"]*)') {
                $global:session_param = $matches[1]
            }
            
            Write-Host "Keepalive URL stored: $global:keepalive"
            Write-Host "Session parameter: $global:session_param"
        }
        else {
            Write-Host "[*] Keepalive URL not found."
            exit 1
        }
    }
    catch {
        Write-Host "[*] Error fetching login page"
        exit 1
    }
}

# Function to keep the session alive
function Start-KeepSessionAlive {
    while ($true) {
        Rotate-LogIfLarge
        Write-Host "$(Get-Date)"
        
        try {
            $headers = @{
                "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
            }
            
            $response = Invoke-WebRequest -Uri $global:keepalive -Headers $headers -UseBasicParsing -ErrorAction Stop
            Write-Host "[*] Keepalive request successful"
        }
        catch {
            Write-Host "[*] Error in keepalive request. Attempting to login again."
            Invoke-Login  # Re-login if keepalive fails
        }

        Start-Sleep -Seconds 100
    }
}

# Register cleanup on exit
Register-EngineEvent PowerShell.Exiting -Action { Invoke-Cleanup }

# Main Script Execution
try {
    Stop-PreviousInstances  # Handle previous instances
    Invoke-Login  # Initial login
    Start-KeepSessionAlive  # Keep session alive
}
catch {
    Write-Host "[*] Unexpected error: $($_.Exception.Message)"
    exit 1
}
finally {
    Invoke-Cleanup
}
