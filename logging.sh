#!/bin/bash

# Guard to prevent redefinition of log_message if already sourced
if [ -z "${LOGGING_SH_INCLUDED+x}" ]; then
    LOGGING_SH_INCLUDED=1

    LOG_FILE="/var/log/scripts.log"

# Rotate logs if log file is larger than 1MB
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 1048576 ]; then
    mv "$LOG_FILE" "$LOG_FILE.1"
fi

# Function to log messages with a timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
fi