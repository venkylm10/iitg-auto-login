#!/bin/bash

# Check if username and password are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: ./install.sh <username> <password>"
    exit 1
fi


# Update this user home value
USERHOME=$HOME

USERNAME=$1
PASSWORD=$2

# Create the directory for config.env if it doesn't exist
mkdir -p "$USERHOME/iitg-auto-login"

touch $USERHOME/iitg-auto-login/config.env
# Create config.env file
cat > "$USERHOME/iitg-auto-login/config.env" << EOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
EOF

chmod 600 $USERHOME/iitg-auto-login/config.env

# Copy the existing auto_login.sh script to the correct directory
cp auto_login.sh "$USERHOME/iitg-auto-login/"

# Make auto_login.sh executable
chmod +x "$USERHOME/iitg-auto-login/auto_login.sh"

# Update user name
echo "nano text editor will open. Replace 'username' with your actual username."
echo "run 'whoami' in different terminal session to know your username (if needed)"
echo "Press Ctrl+S and then Ctrl+X to exit nano editor."
echo ""
echo "Update USERHOME variable [Enter to continue]"
read
nano $USERHOME/iitg-auto-login/auto_login.sh

# Create autostart directory if it doesn't exist
mkdir -p "$USERHOME/.config/autostart"

# Copy the autostart desktop file to the autostart directory
cp ./iitg-auto-login.desktop "$USERHOME/.config/autostart/"

echo ""
echo "Replace username with your actual username in Exec field [Enter to continue]"
read
nano $USERHOME/.config/autostart/iitg-auto-login.desktop

# Make the autostart desktop file executable
chmod +x "$USERHOME/.config/autostart/iitg-auto-login.desktop"

# Need sudo permissions for the following steps
sudo true

# Create a directory in /etc/NetworkManager/dispatcher.d/ if not already present
sudo mkdir -p /etc/NetworkManager/dispatcher.d/

# Copy dispatcher script (requires sudo)
sudo cp iitg-auto-login-dispatcher.sh /etc/NetworkManager/dispatcher.d/

# Set correct permissions for the script in /etc/NetworkManager/dispatcher.d/
sudo chmod +x /etc/NetworkManager/dispatcher.d/iitg-auto-login-dispatcher.sh

echo ""
echo "Replace username with your actual username in USERHOME variable [Enter to continue]"
read
sudo nano /etc/NetworkManager/dispatcher.d/iitg-auto-login-dispatcher.sh

# Final message to the user
echo "Installation complete!"
echo "Your credentials have been saved at: $USERHOME/iitg-auto-login/config.env"
echo "Your auto_login.sh script has been moved to: $USERHOME/iitg-auto-login/auto_login.sh"
echo "It will automatically run when you connect to WiFi or Ethernet."
echo "To manually trigger the script, run: $USERHOME/iitg-auto-login/auto_login.sh"
echo "Turn off and on your wifi or ethernet to test the script."
echo "If you face any issues, please create an issue on GitHub: https://github.com/venkylm10/iitg-auto-login"
echo ""
echo "Restart the device for changes to take effect."
