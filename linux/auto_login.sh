#!/bin/bash

PROCESS_NAME="iitg-auto-login"

# Set the log file path
LOGFILE="/tmp/iitg_auto_login.log"
# Max lines allowed in log before truncating
LOG_MAX_LINES=5000
# Max seconds to wait for any curl connection/operation
CURL_TIMEOUT=2

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
# Store last HTTP response body (kept for future use, but no longer dumped to log)
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
    rm -f /tmp/iitg_cookies.txt
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
    if [[ -n "$session_param" ]]; then
        http_code=$(curl --connect-timeout "$CURL_TIMEOUT" --max-time "$CURL_TIMEOUT" -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "https://agnigarh.iitg.ac.in:1442/logout?$session_param")
    else
        http_code=$(curl --connect-timeout "$CURL_TIMEOUT" --max-time "$CURL_TIMEOUT" -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "https://agnigarh.iitg.ac.in:1442/logout?")
    fi

    if [[ $? -ne 0 || "$http_code" != "200" ]]; then
        echo "[*] Logout failed (HTTP $http_code). Continuing anyway."
        return 1
    fi
    echo "[*] Logged out."
}

# Function to login (with retry loop)
login() {
    while true; do
        echo "Logging in with Username: $username"
        logout >/dev/null 2>&1
        rm -f /tmp/iitg_cookies.txt

        url='https://agnigarh.iitg.ac.in:1442/login?'
        http_code=$(curl --connect-timeout "$CURL_TIMEOUT" --max-time "$CURL_TIMEOUT" -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -c /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "$url")

        if [[ $? -ne 0 || "$http_code" != "200" ]]; then
            echo "[*] Error fetching login page (HTTP $http_code). Retry in 2s..."
            rotate_log_if_large
            sleep 2
            continue
        fi

        rsp=$(cat "$RESPONSE_FILE")
        magic=$(echo "$rsp" | grep -oE 'name="magic" value="([^"]+)' | sed 's/.*value="\([^"]*\).*/\1/')
        if [[ -z "$magic" ]]; then
            echo "[*] Magic value not found. Retry in 2s..."
            rotate_log_if_large
            sleep 2
            continue
        fi

        data="4Tredir=http%3A%2F%2Fspeedtest.net%2F&magic=$magic&username=$username&password=$password"

        http_code=$(curl --connect-timeout "$CURL_TIMEOUT" --max-time "$CURL_TIMEOUT" -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -X POST \
            -c /tmp/iitg_cookies.txt -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -H "Referer: $url" \
            -d "$data" \
            "https://agnigarh.iitg.ac.in:1442/")

        if [[ $? -ne 0 || "$http_code" != "200" ]]; then
            echo "[*] Error logging in (HTTP $http_code). Retry in 2s..."
            rotate_log_if_large
            sleep 2
            continue
        fi

        html_content=$(cat "$RESPONSE_FILE")
        keepalive=$(echo "$html_content" | grep -oP '(?<=window\.location=").*?(?=";)')
        if [[ -z "$keepalive" ]]; then
            echo "[*] Keepalive URL not found. Retry in 2s..."
            rotate_log_if_large
            sleep 2
            continue
        fi

        session_param=$(echo "$keepalive" | grep -oP '(?<=\?)[^"]*')
        echo "Login successful"
        echo "Keepalive URL stored: $keepalive"
        echo "Session parameter: $session_param"
        break
    done
}

# Function to keep the session alive
keep_session_alive() {
    while true; do
        echo "$(date)"
        http_code=$(curl --connect-timeout "$CURL_TIMEOUT" --max-time "$CURL_TIMEOUT" -ksS -o "$RESPONSE_FILE" -w "%{http_code}" -b /tmp/iitg_cookies.txt \
            -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36" \
            "$keepalive")

        if [[ $? -ne 0 || "$http_code" != "200" ]]; then
            echo "[*] Keepalive failure (HTTP $http_code). Re-login in 2s..."
            rotate_log_if_large
            sleep 2
            login
        else
            echo "[*] Keepalive request successful"
        fi

        sleep 100
    done
}

# Main Script Execution
trap cleanup EXIT
terminate_old_session
login
keep_session_alive
