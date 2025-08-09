<#!
IITG Auto Login Windows CLI Wrapper
Commands:
  install              Run installer (register tasks, etc.)
  install-cli          Install this CLI into user PATH
  update-cli           Update the installed CLI copy
  creds                Show saved credentials (password masked)
  creds --show         Show saved credentials (password plain)
  creds --update       Update credentials
  logs [-n N] [-f]     Show / follow log (default N=100)
  uninstall            Uninstall (delegates to install.ps1 -Uninstall)
  help                 Show help
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $env:USERPROFILE 'iitg-auto-login\config.env'
$LogPath    = Join-Path $env:TEMP 'iitg-auto_login.log'
$Installer  = Join-Path $ScriptDir 'install.ps1'
$CliTargetDir = Join-Path $env:LocalAppData 'IITGAuto'
$CliPs1 = Join-Path $CliTargetDir 'iitgauto.ps1'
$CliCmd = Join-Path $CliTargetDir 'iitgauto.cmd'

function Show-Help {
@"
IITG Auto Login (Windows) CLI

Usage: iitgauto <command> [options]

Commands:
  install              Install auto-login (scheduled tasks)
  install-cli          Install this CLI into user PATH
  update-cli           Update previously installed CLI files
  creds                Show saved credentials (password masked)
  creds --show         Show credentials (password visible)
  creds --update       Update credentials
  logs [-n N] [-f]     Show (and optionally follow) log. Default N=100
  uninstall            Uninstall (scheduled tasks) via install.ps1 -Uninstall
  help                 Show this help

Examples:
  iitgauto install
  iitgauto install-cli
  iitgauto creds --show
  iitgauto logs -n 200 -f
  iitgauto update-cli
  iitgauto uninstall
"@
}

function Read-CredsFile {
    if (-not (Test-Path $ConfigPath)) { return $null }
    $raw = Get-Content $ConfigPath -ErrorAction Stop
    $result = @{}
    foreach ($line in $raw) {
        if ($line -match '^(USERNAME|PASSWORD)="?([^"\r\n]+)') {
            $result[$matches[1]] = $matches[2]
        }
    }
    return $result
}

function Show-Creds {
    param([switch]$Show)
    $creds = Read-CredsFile
    if (-not $creds) { Write-Host "No config found at $ConfigPath"; return }
    $u = $creds['USERNAME']
    $p = $creds['PASSWORD']
    Write-Host "Config file: $ConfigPath"
    if ($u) { Write-Host "Username: $u" } else { Write-Host 'Username: (not set)' }
    if ($p) {
        if ($Show) { Write-Host "Password: $p" }
        else {
            $masked = ('*' * $p.Length)
            Write-Host "Password: $masked (length: $($p.Length))"
        }
    } else { Write-Host 'Password: (not set)' }
}

function Update-Creds {
    Write-Host 'Enter new credentials:' -ForegroundColor Cyan
    $u = Read-Host 'Username'
    $secure = Read-Host 'Password' -AsSecureString
    $p = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    New-Item -ItemType Directory -Path (Split-Path $ConfigPath) -Force | Out-Null
    @(
        'USERNAME="' + $u + '"'
        'PASSWORD="' + $p + '"'
    ) | Set-Content -Path $ConfigPath -Encoding UTF8
    Write-Host "Credentials updated in $ConfigPath" -ForegroundColor Green
}

function Invoke-Install {
    if (-not (Test-Path $Installer)) { Write-Host 'install.ps1 not found.' -ForegroundColor Red; exit 1 }
    & $Installer
}

function Invoke-Uninstall {
    if (-not (Test-Path $Installer)) { Write-Host 'install.ps1 not found.' -ForegroundColor Red; exit 1 }
    & $Installer -Uninstall
}

function Show-Logs {
    param([int]$Lines = 100, [switch]$Follow)
    if (-not (Test-Path $LogPath)) {
        Write-Host "Log file not found at $LogPath" -ForegroundColor Yellow
        Write-Host 'Tip: run auto_login.ps1 once or let the scheduled task trigger.' -ForegroundColor DarkYellow
        return
    }
    if ($Follow) { Get-Content -Path $LogPath -Tail $Lines -Wait }
    else { Get-Content -Path $LogPath -Tail $Lines }
}

# New: Install / Update CLI into PATH
function Install-Cli {
    New-Item -ItemType Directory -Path $CliTargetDir -Force | Out-Null
    Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $CliPs1 -Force
    $cmdContent = "@echo off`r`nPowerShell -NoLogo -ExecutionPolicy Bypass -File \"%~dp0iitgauto.ps1\" %*"
    Set-Content -Path $CliCmd -Value $cmdContent -Encoding ASCII
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    if (-not $userPath) { $userPath = '' }
    $added = $false
    if (-not ($userPath.Split(';') -contains $CliTargetDir)) {
        $newPath = ($userPath.TrimEnd(';') + ';' + $CliTargetDir).Trim(';')
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $added = $true
    }
    Write-Host "CLI files installed to $CliTargetDir" -ForegroundColor Green
    if ($added) { Write-Host "Path updated. Open a new terminal to use 'iitgauto'." -ForegroundColor Yellow }
}
function Update-Cli { Install-Cli }

# --- Command Dispatcher ---
if ($args.Count -eq 0) { Show-Help; exit 0 }
$cmd = $args[0].ToLowerInvariant()
$rest = @()
if ($args.Count -gt 1) { $rest = $args[1..($args.Count-1)] }

switch ($cmd) {
    'help' { Show-Help }
    'install' { Invoke-Install }
    'install-cli' { Install-Cli }
    'update-cli' { Update-Cli }
    'uninstall' { Invoke-Uninstall }
    'creds' {
        if ($rest -contains '--update' -or $rest -contains 'update') { Update-Creds }
        elseif ($rest -contains '--show' -or $rest -contains 'show') { Show-Creds -Show }
        else { Show-Creds }
    }
    'logs' {
        $lines = 100; $follow = $false
        for ($i=0; $i -lt $rest.Count; $i++) {
            $tok = $rest[$i]
            switch -Regex ($tok) {
                '^(--)?-?n$' { if ($i+1 -lt $rest.Count -and $rest[$i+1] -as [int]) { $lines = [int]$rest[$i+1]; $i++ } }
                '^(--)?-?f$' { $follow = $true }
            }
        }
        Show-Logs -Lines $lines -Follow:$follow
    }
    Default { Write-Host "Unknown command: $cmd" -ForegroundColor Red; Show-Help; exit 1 }
}
