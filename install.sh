#!/bin/bash

# Check if username and password are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: ./install.sh <username> <password>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

# Create the directory for config.env if it doesn't exist
mkdir -p "$HOME/iitg-auto-login"

touch ~/iitg-auto-login/config.env
# Create config.env file
cat > "$HOME/iitg-auto-login/config.env" << EOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
EOF

chmod 600 ~/iitg-auto-login/config.env

# Copy the existing auto_login.sh script to the correct directory
cp ./auto_login.sh "$HOME/iitg-auto-login/"

# Make auto_login.sh executable
chmod +x "$HOME/iitg-auto-login/auto_login.sh"

# Create autostart directory if it doesn't exist
mkdir -p "$HOME/.config/autostart"

# Copy the autostart desktop file to the autostart directory
cp ./iitg-auto-login.desktop "$HOME/.config/autostart/"

# Update user name
echo "nano text editor will open. Replace 'username' with your actual username."
echo "run 'whoami' in different terminal session to know your username (if needed)"
echo "Press Ctrl+S and then Ctrl+X to exit nano editor. [Enter to continue]"
read
nano ~/.config/autostart/iitg-auto-login.desktop

# Make the autostart desktop file executable
chmod +x "$HOME/.config/autostart/iitg-auto-login.desktop"

# Create the systemd/user directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Update your user name
cp ./iitg-auto-login.service ~/.config/systemd/user/
nano ~/.config/systemd/user/iitg-auto-login.service

# Enable the systemd service
systemctl --user enable iitg-auto-login.service

# Final message to the user
echo "Installation complete!"
echo "Your credentials have been saved at: $HOME/iitg-auto-login/config.env"
echo "Your auto_login.sh script has been moved to: $HOME/iitg-auto-login/auto_login.sh"
echo "It will automatically run when you connect to WiFi or Ethernet."
echo "To manually trigger the script, run: $HOME/iitg-auto-login/auto_login.sh"
echo "Turn off and on your wifi or ethernet to test the script."
echo "If you face any issues, please create an issue on GitHub: https://github.com/venkylm10/iitg-auto-login"
echo "Restart the device for changes to take effect."
