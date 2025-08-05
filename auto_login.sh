#!/bin/bash

PROCESS_NAME="iitg-auto-login"

# Set the log file path
LOGFILE="/tmp/iitg-auto_login.log"

# Update this user home value
USERHOME="/home/<username>"

# Load configuration
if [[ -f "$USERHOME/iitg-auto-login/config.env" ]]; then
    source "$USERHOME/iitg-auto-login/config.env"
else
    echo "[*] Configuration file not found!"
    exit 1
fi

# Get username and password from environment variables
username="$USERNAME"
password="$PASSWORD"

# Global variables for session management
session_param=""
keepalive=""

# Redirect both stdout and stderr to the log file
exec > >(tee -a "$LOGFILE") 2>&1

echo "Script started at $(date)"

# Function to handle cleanup on exit
cleanup() {
    echo "[*] Cleaning up..."
    # Clean up cookies file
    rm -f /tmp/iitg_cookies.txt
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
    # Try with session parameter if available, otherwise use basic logout
    if [[ -n "$session_param" ]]; then
        rp=$(curl -k -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "https://agnigarh.iitg.ac.in:1442/logout?$session_param")
    else
        rp=$(curl -k -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "https://agnigarh.iitg.ac.in:1442/logout?")
    fi
    
    if [[ $? -ne 0 ]]; then
        echo "[*] Logout failed!"
        return 1  # Changed from exit to return to allow retry
    fi
    echo "[*] Logged out!"
}

# Function to login
login() {
    logout  # Make sure to logout first
    echo "Logging in with Username: $username"

    # Clean up any existing cookies
    rm -f /tmp/iitg_cookies.txt

    url='https://agnigarh.iitg.ac.in:1442/login?'
    rsp=$(curl -k -c /tmp/iitg_cookies.txt \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
        "$url")

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

    # POST to base URL, not login URL based on network logs
    html_content=$(curl -k -X POST \
        -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: $url" \
        -d "$data" \
        "https://agnigarh.iitg.ac.in:1442/")

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

    # Extract session parameter from keepalive URL for logout
    session_param=$(echo "$keepalive" | grep -oP '(?<=\?)[^"]*')

    echo "Keepalive URL stored: $keepalive"
    echo "Session parameter: $session_param"
}

# Function to keep the session alive
keep_session_alive() {
    while true; do
    	echo "$(date)"
        response=$(curl -k -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "$keepalive")

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
