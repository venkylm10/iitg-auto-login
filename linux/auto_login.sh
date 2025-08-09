#!/bin/bash

PROCESS_NAME="iitg-auto-login"

# Set the log file path
LOGFILE="/tmp/iitg-auto_login.log"
# Max lines allowed in log before truncating
LOG_MAX_LINES=5000

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
# Store last HTTP response body for logging on failures only
RESPONSE_FILE="/tmp/iitg_auto_login_last_response.html"

# Redirect both stdout and stderr to the log file
exec > >(tee -a "$LOGFILE") 2>&1

# Ensure log doesn't grow indefinitely (truncate when too large)
rotate_log_if_large() {
    if [[ -f "$LOGFILE" ]]; then
        local lines
        lines=$(wc -l < "$LOGFILE" 2>/dev/null | tr -d ' ')
        if [[ -n "$lines" && "$lines" -ge "$LOG_MAX_LINES" ]]; then
            : > "$LOGFILE"  # truncate
            echo "[*] Log truncated at $(date)" >> "$LOGFILE"
        fi
    fi
}

echo "Script started at $(date)"

# Function to handle cleanup on exit
cleanup() {
    echo "[*] Cleaning up..."
    # Clean up cookies file
    rm -f /tmp/iitg_cookies.txt
    # Clean up last response file
    rm -f "$RESPONSE_FILE"
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
        http_code=$(curl -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "https://agnigarh.iitg.ac.in:1442/logout?$session_param")
    else
        http_code=$(curl -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "https://agnigarh.iitg.ac.in:1442/logout?")
    fi

    if [[ $? -ne 0 || "$http_code" != "200" ]]; then
        echo "[*] Logout failed! (HTTP $http_code)"
        rotate_log_if_large
        echo "--- Response (logout) ---" >> "$LOGFILE"
        cat "$RESPONSE_FILE" >> "$LOGFILE"
        return 1  # allow retry
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
    http_code=$(curl -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -c /tmp/iitg_cookies.txt \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
        "$url")

    if [[ $? -ne 0 || "$http_code" != "200" ]]; then
        echo "[*] Error fetching login page (HTTP $http_code)"
        rotate_log_if_large
        echo "--- Response (login page) ---" >> "$LOGFILE"
        cat "$RESPONSE_FILE" >> "$LOGFILE"
        exit 1
    fi

    rsp=$(cat "$RESPONSE_FILE")
    magic=$(echo "$rsp" | grep -oE 'name="magic" value="([^"]+)' | sed 's/.*value="\([^"]*\).*/\1/')
    if [[ -z "$magic" ]]; then
        echo "[*] Magic value not found!"
        rotate_log_if_large
        echo "--- Response (no magic) ---" >> "$LOGFILE"
        cat "$RESPONSE_FILE" >> "$LOGFILE"
        exit 1
    fi

    data="4Tredir=http%3A%2F%2Fspeedtest.net%2F&magic=$magic&username=$username&password=$password"

    # POST to base URL, not login URL based on network logs
    http_code=$(curl -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -X POST \
        -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: $url" \
        -d "$data" \
        "https://agnigarh.iitg.ac.in:1442/")

    if [[ $? -ne 0 || "$http_code" != "200" ]]; then
        echo "[*] Error logging in (HTTP $http_code)"
        rotate_log_if_large
        echo "--- Response (login POST) ---" >> "$LOGFILE"
        cat "$RESPONSE_FILE" >> "$LOGFILE"
        exit 1
    fi

    echo "Login successful"
    html_content=$(cat "$RESPONSE_FILE")
    keepalive=$(echo "$html_content" | grep -oP '(?<=window\.location=").*?(?=";)')

    if [[ -z "$keepalive" ]]; then
        echo "[*] Keepalive URL not found."
        rotate_log_if_large
        echo "--- Response (no keepalive) ---" >> "$LOGFILE"
        cat "$RESPONSE_FILE" >> "$LOGFILE"
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
        http_code=$(curl -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "$keepalive")

        if [[ $? -ne 0 || "$http_code" != "200" ]]; then
            echo "[*] Error in keepalive request (HTTP $http_code). Attempting to login again."
            rotate_log_if_large
            echo "--- Response (keepalive) ---" >> "$LOGFILE"
            cat "$RESPONSE_FILE" >> "$LOGFILE"
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
