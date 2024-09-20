#!/bin/bash

# Remove the systemd service
systemctl --user disable iitg-auto-login.service
rm $HOME/.config/systemd/user/iitg-auto-login.service

# Remove the auto_login.sh script
rm -r "$HOME/iitg-auto-login"

# Remove the autostart entry
rm -f $HOME/.config/autostart/iitg-auto-login.desktop

# Final message to the user
echo "Uninstallation complete!"
echo "You will always find it at : https://github.com/venkylm10/iitg-auto-login"
echo "Thank you for using iitg-auto-login!"
