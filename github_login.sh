#!/bin/bash

# Source the logging function
if [ -f "$(dirname "$0")/logging.sh" ]; then
    . "$(dirname "$0")/logging.sh"
else
    echo "ERROR: logging.sh not found in script directory"
    exit 1
fi

# Guard to prevent redefinition of login_to_github if already sourced
if [ -z "${GITHUBLOGIN_SH_INCLUDED+x}" ]; then
    GITHUBLOGIN_SH_INCLUDED=1
    login_to_github() {
      # Load sensitive data from environment variables or exit if not set
      CR_PAT="${CR_PAT:-}"
      HF_TOKEN="${HF_TOKEN:-}"
      CR_USER="${CR_USER:-}"
      if [ -z "$CR_PAT" ] || [ -z "$HF_TOKEN" ] || [ -z "$CR_USER" ]; then
          log_message "ERROR: CR_USER, CR_PAT, and HF_TOKEN environment variables must be set"
          log_message "Example: export CR_USER='your_github_email' CR_PAT='your_github_token' HF_TOKEN='your_hf_token'"
          exit 1
      fi

      # Login to GitHub Container Registry
      log_message "Logging into ghcr.io..."
      echo "$CR_PAT" | podman login ghcr.io -u $CR_USER --password-stdin
      if [ $? -ne 0 ]; then
          log_message "ERROR: Failed to login to ghcr.io"
          exit 1
      fi
    }
fi