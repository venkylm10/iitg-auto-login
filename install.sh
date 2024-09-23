#!/bin/bash

read -p "Enter your username: " USERNAME
read -s -p "Enter your password: " PASSWORD
echo

USERHOME=$HOME

replace_username() {
    local template_file="$1" 
    local username=$(whoami)
    echo $username
    sudo sed -i "s|<username>|$username|g" "$template_file"
}

mkdir -p "$USERHOME/iitg-auto-login"

touch $USERHOME/iitg-auto-login/config.env
cat > "$USERHOME/iitg-auto-login/config.env" << EOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
EOF

chmod 600 $USERHOME/iitg-auto-login/config.env

cp auto_login.sh "$USERHOME/iitg-auto-login/"
chmod +x "$USERHOME/iitg-auto-login/auto_login.sh"
replace_username  $USERHOME/iitg-auto-login/auto_login.sh

# Create autostart directory if it doesn't exist
mkdir -p "$USERHOME/.config/autostart"
cp ./iitg-auto-login.desktop "$USERHOME/.config/autostart/"
replace_username $USERHOME/.config/autostart/iitg-auto-login.desktop
chmod +x "$USERHOME/.config/autostart/iitg-auto-login.desktop"

# Need sudo permissions for the following steps
sudo true
sudo mkdir -p /etc/NetworkManager/dispatcher.d/
sudo cp iitg-auto-login-dispatcher.sh /etc/NetworkManager/dispatcher.d/
replace_username /etc/NetworkManager/dispatcher.d/iitg-auto-login-dispatcher.sh
sudo chmod +x /etc/NetworkManager/dispatcher.d/iitg-auto-login-dispatcher.sh


echo "Installation complete!"
echo "Your credentials have been saved at: $USERHOME/iitg-auto-login/config.env"
echo "Your auto_login.sh script has been moved to: $USERHOME/iitg-auto-login/auto_login.sh"
echo "It will automatically run when you connect to WiFi or Ethernet."
echo "To manually trigger the script, run: $USERHOME/iitg-auto-login/auto_login.sh"
echo "Turn off and on your wifi or ethernet to test the script."
echo "If you face any issues, please create an issue on GitHub: https://github.com/venkylm10/iitg-auto-login"
echo 
echo "Restart the device for changes to take effect."
