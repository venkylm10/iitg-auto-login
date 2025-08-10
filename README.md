# IITG Auto Login - Cross Platform

This repository provides automatic login scripts for IITG network authentication on both Linux and Windows platforms.

## Features

- Cross-platform support: Linux (Bash) and Windows (PowerShell)
- Automatic login: Connects to IITG portal automatically
- Session management: Keeps the session alive with periodic keepalive requests
- Background operation: Autostart + NetworkManager dispatcher (Linux) / Scheduled Tasks (Windows)
- Clean logging with on-failure response capture and log rotation (Linux & Windows)

## Directory Structure

```
├── linux/
│   ├── auto_login.sh               # Main auto-login script (Linux)
│   ├── iitgauto                    # CLI wrapper (Linux)
│   ├── update_creds.sh             # Legacy creds script (Linux)
│   ├── install.sh                  # Legacy installer (used by CLI)
│   ├── uninstall.sh                # Legacy uninstaller
│   ├── iitg-auto-login.desktop     # Autostart entry
│   └── iitg-auto-login-dispatcher.sh # NetworkManager dispatcher hook
├── windows/
│   ├── auto_login.ps1              # Main auto-login script (Windows)
│   ├── iitgauto.ps1                # Windows CLI wrapper
│   ├── update_creds.ps1            # Creds setup (Windows)
│   ├── install.ps1                 # Installer (Windows)
│   ├── uninstall.ps1               # Uninstaller (Windows)
│   └── dispatcher.ps1              # Service management (Windows)
└── README.md
```

## Linux (Recommended) – CLI Usage

A simple CLI is provided: `iitgauto`

First-time install (run as your normal user, do NOT prefix with sudo):

```bash
cd linux
./iitgauto install
```

After that you can use it from anywhere:

- Show credentials (password masked):
  ```bash
  iitgauto creds
  ```
- Show credentials (password visible):
  ```bash
  iitgauto creds --show
  ```
- Update credentials:
  ```bash
  iitgauto creds --update
  ```
- View logs (like tail):
  ```bash
  iitgauto logs            # last 100 lines
  iitgauto logs -n 200     # last 200 lines
  iitgauto logs -f         # follow
  iitgauto logs -n 200 -f  # combine
  ```
- Uninstall everything (dispatcher, autostart, config, CLI):
  ```bash
  iitgauto uninstall
  ```

Notes:
- Do not run `iitgauto install` with sudo. It will prompt for sudo only when needed.
- Log file (Linux): `/tmp/iitg_auto_login.log` (rotation at 5000 lines)
- Config file (Linux): `~/iitg-auto-login/config.env` (chmod 600)

## Linux (Optional) – Manual Setup

If you prefer not to use the CLI:

1) Set credentials
```bash
cd linux
./update_creds.sh
```
2) Install
```bash
./install.sh
```
3) Manual run (optional)
```bash
~/iitg-auto-login/auto_login.sh
```
4) Uninstall
```bash
./uninstall.sh
```

## Windows Setup & CLI

Use the PowerShell CLI wrapper:

```powershell
cd windows
# Install scheduled tasks
powershell -ExecutionPolicy Bypass -File .\iitgauto.ps1 install
# (Optional) install CLI into PATH for direct 'iitgauto' command
powershell -ExecutionPolicy Bypass -File .\iitgauto.ps1 install-cli
```
Then open a new terminal (if you ran install-cli) and use:

```powershell
iitgauto creds
iitgauto creds --show
iitgauto creds --update
iitgauto logs -n 200 -f
iitgauto uninstall
```
Update CLI after pulling repo changes:
```powershell
iitgauto update-cli
```

Windows details:
- Log file: `%TEMP%\iitg_auto_login.log` (rotation at 5000 lines)
- Config file: `%USERPROFILE%\iitg-auto-login\config.env`
- Scheduled tasks: "IITG Auto Login" and "IITG Auto Login - Network Change"

Manual (legacy) scripts still available (`update_creds.ps1`, `install.ps1`, etc.).

## Configuration Format

Same on both platforms:

- Linux: `~/iitg-auto-login/config.env`
- Windows: `%USERPROFILE%\iitg-auto-login\config.env`

```
USERNAME=your_username
PASSWORD=your_password
```

## How It Works

1) Login Process
- Fetch login page, extract magic token
- POST credentials to portal root with magic
- Extract keepalive URL from response

2) Session Management
- Send keepalive every ~100s
- Re-login automatically on failure

3) Background Operation
- Linux: Desktop autostart + NetworkManager dispatcher
- Windows: Scheduled tasks (startup + network change)

## Logging

- Linux log: `/tmp/iitg_auto_login.log` (rotates at 5000 lines)
- Windows log: `%TEMP%\iitg_auto_login.log` (rotates at 5000 lines)
- View quickly:
  ```bash
  iitgauto logs -n 100
  ```
  ```powershell
  iitgauto logs -n 100
  ```

## Troubleshooting

- No log file yet:
  - Reconnect to network or run the script manually once.
- Installed Linux version as root by mistake:
  - Remove root install and rerun as user (see README earlier notes).
- “Magic value not found” / login fails:
  - Check connectivity and credentials.

## Security Notes

- Config stores plaintext credentials; restrict permissions.
- Consider separate account if possible.

## License

This project is provided as-is for educational and convenience purposes.
