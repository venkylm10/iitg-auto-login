#!/bin/bash

read -p "Enter your username: " USERNAME
read -s -p "Enter your password: " PASSWORD
echo

# Create the directory for config.env if it doesn't exist
mkdir -p "$HOME/iitg-auto-login"

# Clear the contents of the file if it exists
if [ -f "$HOME/iitg-auto-login/config.env" ]; then
    truncate -s 0 "$HOME/iitg-auto-login/config.env"
else
    touch "$HOME/iitg-auto-login/config.env"
fi

# Write new content to the file
cat > "$HOME/iitg-auto-login/config.env" << EOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
EOF

# Final message to the user
echo "Credentials updated in $HOME/iitg-auto-login/config.env"
