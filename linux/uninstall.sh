#!/bin/bash

sudo true
sudo rm -f /etc/NetworkManager/dispatcher.d/iitg-auto-login-dispatcher.sh

sudo systemctl restart NetworkManager

# Remove the auto_login.sh script
rm -r "$HOME/iitg-auto-login"

# Remove the autostart entry
rm -f $HOME/.config/autostart/iitg-auto-login.desktop

# Final message to the user
echo "Uninstallation complete!"
echo "You will always find it at : https://github.com/venkylm10/iitg-auto-login"
echo "Thank you for using iitg-auto-login!"
