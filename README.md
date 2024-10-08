# IITG Auto Login

This project automates the login process for the IITG LAN and keeps the session alive when connected to the network. Currently available for Debian-based Linux distributions.

## Prerequisites

- Ubuntu (or any Debian-based distribution)

## Installation

Follow the steps below to install and configure the IITG Auto Login:
If you already have installed previous version. Uninstall it using the previous uninstall.sh script

1. **Download the repository**:  
   Clone this repository or download the files to your local machine.
   ```
   git clone https://github.com/venkylm10/iitg-auto-login.git
   ```

2. **Navigate to the directory**:  
   Change to the directory where the scripts are located:
   ```bash
   cd iitg-auto-login
   ```

3. **Make install.sh executable**:
    ```bash
    chmod +x install.sh
    ```

4. **Run the installation script**:
    Use the installation script to set up the auto login.
    (Don't include '< >' in the command)
    ```bash
    ./install.sh
    ```
    You will be prompted to enter username and password.

5. **Verify the installation**:
    - Your credentials will be stored in `~/iitg-auto-login/config.env`.
    - The `auto_login.sh` script will be located at `~/iitg-auto-login/auto_login.sh`.
    - A new dispatcher script `iitg-auto-login-dispatcher.sh` should be present at
      `/etc/NetworkManager/dispatcher.d/`

## Update Credentials
    
   You can update your creds anytime from the same directory:
   ```
   chmod +x update_creds.sh
   ./update_creds
   ```
   You will be prompted to enter username and password

## Usage

   - Automatically Logs you in to the wifi network, when you login to your device.
   - If at all it gets logged out. All you need to do is just turn wifi off and on or disconnect and plug ethernet cable back again, will try to remove this hardle too in upcoming releases.
   - That's it.

## Logging

The status of the auto login process is maintained in a log file located at `/tmp/iitg-auto-login.log`. When raising an issue on GitHub, please provide the last 100 lines of this log file for better troubleshooting:

```bash
tail -n 100 /tmp/iitg-auto-login.log
```

## Uninstallation

To remove the auto-login setup, run the uninstallation script in the extracted folder:

```bash
./uninstall.sh
```
