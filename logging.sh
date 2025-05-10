#!/bin/bash

# Guard to prevent redefinition of log_message if already sourced
if [ -z "${LOGGING_SH_INCLUDED+x}" ]; then
    LOGGING_SH_INCLUDED=1

    # Function to log messages with a timestamp
    log_message() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    }
fi