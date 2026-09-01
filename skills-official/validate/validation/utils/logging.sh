#!/usr/bin/env bash
# validation/utils/logging.sh - Logging functions for validation system

# Log error message to stderr with [ERROR] prefix
# Usage: log_error "message"
log_error() {
    local message="$1"
    printf "[ERROR] %s\n" "$message" >&2
}

# Log warning message to stderr with [WARN] prefix
# Usage: log_warn "message"
log_warn() {
    local message="$1"
    printf "[WARN] %s\n" "$message" >&2
}

# Log info message to stdout with [INFO] prefix
# Usage: log_info "message"
log_info() {
    local message="$1"
    printf "[INFO] %s\n" "$message"
}
