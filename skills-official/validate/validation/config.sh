#!/usr/bin/env bash
# validation/config.sh - Configuration for validation system

# Default configuration values
REPORT_DIR="/tmp"
CACHE_EXPIRY_MINUTES=60
GATE_TIMEOUT_SECONDS=10

# Override with .autoflow/validation.conf if it exists
VALIDATION_CONF="${PWD}/.autoflow/validation.conf"
if [[ -f "$VALIDATION_CONF" ]]; then
    # Source the config file safely
    # shellcheck source=/dev/null
    source "$VALIDATION_CONF"
fi

# Export variables for use in other scripts
export REPORT_DIR
export CACHE_EXPIRY_MINUTES
export GATE_TIMEOUT_SECONDS
