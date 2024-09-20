#!/bin/bash

PROCESS_NAME="iitg-auto-login"

# Set the log file path
LOGFILE="/tmp/iitg-auto_login.log"

# Load configuration
if [[ -f "$HOME/iitg-auto-login/config.env" ]]; then
    source "$HOME/iitg-auto-login/config.env"
else
    echo "[*] Configuration file not found!"
    exit 1
fi

# Get username and password from environment variables
username="$USERNAME"
password="$PASSWORD"

# Redirect both stdout and stderr to the log file
exec > >(tee -a "$LOGFILE") 2>&1

echo "Script started at $(date)"

# Function to handle cleanup on exit
cleanup() {
    echo "[*] Cleaning up..."
    exit 0
}

# Function to terminate any previous instance of the script
terminate_old_session() {
    echo "[*] Terminating any previous instances of the script..."
    current_pid=$$
    for pid in $(pgrep -f "$PROCESS_NAME"); do
        if [[ "$pid" -ne "$current_pid" ]]; then
            kill "$pid"
            echo "[*] Terminated previous instance with PID: $pid"
        fi
    done
}

# Function to logout from the IITG portal
logout() {
    echo "[*] Logging out..."
    rp=$(curl -k "https://agnigarh.iitg.ac.in:1442/logout?030403030f050d06")
    if [[ $? -ne 0 ]]; then
        echo "[*] Logout failed!"
        exit 1
    fi
    echo "[*] Logged out!"
}

# Function to login
login() {
    logout  # Make sure to logout first
    echo "Logging in with Username: $username"

    url='https://agnigarh.iitg.ac.in:1442/login?a=b'
    rsp=$(curl -k "$url")

    if [[ $? -ne 0 ]]; then
        echo "[*] Error fetching login page"
        exit 1
    fi

    magic=$(echo "$rsp" | grep -oE 'name="magic" value="([^"]+)"' | sed 's/.*value="\([^"]*\)".*/\1/')
    if [[ -z "$magic" ]]; then
        echo "[*] Magic value not found!"
        exit 1
    fi

    data="4Tredir=http%3A%2F%2Fspeedtest.net%2F&magic=$magic&username=$username&password=$password"

    html_content=$(curl -k -X POST -d "$data" -H "referer: $url" "$url")

    if [[ $? -ne 0 ]]; then
        echo "[*] Error logging in"
        exit 1
    fi

    echo "Login successful"
    keepalive=$(echo "$html_content" | grep -oP '(?<=window\.location=").*?(?=";)')

    if [[ -z "$keepalive" ]]; then
        echo "[*] Keepalive URL not found."
        exit 1
    fi

    echo "Keepalive URL stored: $keepalive"
}

# Function to keep the session alive
keep_session_alive() {
    while true; do
        response=$(curl -k "$keepalive")

        if [[ $? -ne 0 ]]; then
            echo "[*] Error in keepalive request. Attempting to login again."
            login  # Re-login if keepalive fails
        else
            echo "[*] Keepalive request successful"
        fi

        sleep 100
    done
}

# Main Script Execution
trap cleanup EXIT  # Ensure cleanup is called on script exit
terminate_old_session  # Handle previous instances
login  # Initial login
keep_session_alive  # Keep session alive
