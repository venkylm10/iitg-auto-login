#!/bin/bash

# Check if username and password are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: ./update_creds.sh <username> <password>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

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
