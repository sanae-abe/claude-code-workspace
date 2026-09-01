#!/usr/bin/env bash
# validation/gates/layer2_format.sh - Layer 2: Format validation gate
# Validates YAML formatting, enum values, and field names with auto-fix support

set -Eeuo pipefail

# Get script directory for sourcing utilities
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR

# Source utility functions
# shellcheck source=../utils/logging.sh
source "${SCRIPT_DIR}/../utils/logging.sh"

# Configuration
# Resolve the CALLING project's root (git toplevel, falling back to cwd) -
# never the validate skill's own directory. Matches layer1_syntax.sh / layer5_security.sh.
readonly PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
readonly AUTO_FIX="${1:-false}"
readonly TARGET_FILE="${2:-tasks.yml}"
readonly BACKUP_SUFFIX=".layer2.bak"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1

# Validation state
declare -i ERRORS=0
declare -i WARNINGS=0
declare -i FIXES_APPLIED=0

# Initialize backup file path
BACKUP_FILE=""

#######################################
# Validates file path safety
# Arguments:
#   $1 - File path to validate
# Returns:
#   0 if safe, 1 otherwise
#######################################
validate_file_path() {
    local file_path="$1"

    # Check for path traversal attempts
    if [[ "$file_path" =~ \.\. ]]; then
        log_error "Invalid file path: contains '..' (path traversal)"
        return 1
    fi

    # Check for absolute paths outside workspace (basic check)
    if [[ "$file_path" == /* ]] && [[ ! "$file_path" =~ ^/Users/|^/home/|^/tmp/ ]]; then
        log_error "Invalid file path: suspicious absolute path"
        return 1
    fi

    return 0
}

#######################################
# Creates backup of target file
# Globals:
#   TARGET_FILE - File to backup
#   BACKUP_FILE - Set to backup file path
# Returns:
#   0 on success, 1 on failure
#######################################
create_backup() {
    BACKUP_FILE="${TARGET_FILE}${BACKUP_SUFFIX}"

    if ! cp -p -- "$TARGET_FILE" "$BACKUP_FILE" 2>/dev/null; then
        log_error "Failed to create backup file: $BACKUP_FILE"
        return 1
    fi

    log_info "Created backup: $BACKUP_FILE"
    return 0
}

#######################################
# Restores from backup file
# Globals:
#   BACKUP_FILE - Backup file to restore from
#   TARGET_FILE - File to restore to
#######################################
restore_backup() {
    if [[ -n "$BACKUP_FILE" ]] && [[ -f "$BACKUP_FILE" ]]; then
        if mv -f -- "$BACKUP_FILE" "$TARGET_FILE" 2>/dev/null; then
            log_info "Restored from backup: $BACKUP_FILE"
        else
            log_error "Failed to restore from backup"
        fi
    fi
}

#######################################
# Removes backup file
# Globals:
#   BACKUP_FILE - Backup file to remove
#######################################
cleanup_backup() {
    if [[ -n "$BACKUP_FILE" ]] && [[ -f "$BACKUP_FILE" ]]; then
        rm -f -- "$BACKUP_FILE" 2>/dev/null || true
        log_info "Removed backup file"
    fi
}

#######################################
# Detects markdown code blocks in YAML
# Checks for ```yaml, ```yml markers
# Returns:
#   0 if no markdown found, 1 if found
#######################################
check_markdown_in_yaml() {
    local -i line_num=0
    local line
    local -i found=0

    while IFS= read -r line; do
        ((line_num++))

        # Check for markdown code fence markers (using literal string match)
        if [[ "$line" == '```yaml'* ]] || [[ "$line" == '```yml'* ]]; then
            log_error "Line $line_num: Markdown code fence found in YAML (\`\`\`yaml or \`\`\`yml)"
            ((ERRORS++))
            ((found++))
        elif [[ "$line" == '```' ]] && ((found > 0)); then
            log_error "Line $line_num: Closing markdown code fence found"
            ((ERRORS++))
        fi
    done < "$TARGET_FILE"

    if ((found > 0)); then
        log_warn "Found $found markdown code fence(s) in YAML - remove them manually"
        return 1
    fi

    return 0
}

#######################################
# Validates and fixes enum values
# Checks: status values (Done→DONE, etc.)
# Globals:
#   AUTO_FIX - If true, applies fixes
#   ERRORS - Incremented on errors
#   FIXES_APPLIED - Incremented on fixes
# Returns:
#   0 if valid or fixed, 1 if errors remain
#######################################
check_enum_values() {
    local -i line_num=0
    local line
    local -i found_errors=0

    # Enum mappings: incorrect -> correct
    declare -A status_enum=(
        ["Done"]="DONE"
        ["done"]="DONE"
        ["In Progress"]="IN_PROGRESS"
        ["in progress"]="IN_PROGRESS"
        ["in_progress"]="IN_PROGRESS"
        ["Pending"]="PENDING"
        ["pending"]="PENDING"
        ["Blocked"]="BLOCKED"
        ["blocked"]="BLOCKED"
    )

    while IFS= read -r line; do
        ((line_num++))

        # Check status field values
        if [[ "$line" =~ ^[[:space:]]*status:[[:space:]]*(.+)$ ]]; then
            local value="${BASH_REMATCH[1]}"
            # Remove quotes if present
            value="${value#\"}"
            value="${value#\'}"
            value="${value%\"}"
            value="${value%\'}"
            value="${value%%#*}"  # Remove comments
            value="${value%"${value##*[![:space:]]}"}"  # Trim trailing whitespace

            # Check if value needs correction
            if [[ -n "${status_enum[$value]:-}" ]]; then
                local correct="${status_enum[$value]}"

                if [[ "$AUTO_FIX" == "true" ]]; then
                    # Create backup if first fix
                    if ((FIXES_APPLIED == 0)); then
                        create_backup || return 1
                    fi

                    # Use sed with backup for safe replacement
                    # Escape special characters in patterns
                    local escaped_value="${value//\//\\/}"
                    local escaped_correct="${correct//\//\\/}"

                    if sed -i "${BACKUP_SUFFIX}.tmp" "${line_num}s/status:[[:space:]]*[\"']*${escaped_value}[\"']*/status: ${escaped_correct}/" "$TARGET_FILE" 2>/dev/null; then
                        log_info "Fixed: status: $value -> $correct (line $line_num)"
                        ((FIXES_APPLIED++))
                        rm -f -- "${TARGET_FILE}${BACKUP_SUFFIX}.tmp" 2>/dev/null || true
                    else
                        log_error "Line $line_num: Invalid status enum '$value' (should be '$correct') - auto-fix failed"
                        ((ERRORS++))
                        ((found_errors++))
                        rm -f -- "${TARGET_FILE}${BACKUP_SUFFIX}.tmp" 2>/dev/null || true
                    fi
                else
                    log_error "Line $line_num: Invalid status enum '$value' (should be '$correct')"
                    ((ERRORS++))
                    ((found_errors++))
                fi
            fi
        fi
    done < "$TARGET_FILE"

    if ((found_errors > 0)); then
        return 1
    fi

    return 0
}

#######################################
# Validates and fixes field names
# Checks: sprint_id→id, task_id→id, etc.
# Globals:
#   AUTO_FIX - If true, applies fixes
#   ERRORS - Incremented on errors
#   FIXES_APPLIED - Incremented on fixes
# Returns:
#   0 if valid or fixed, 1 if errors remain
#######################################
check_field_names() {
    local -i line_num=0
    local line
    local -i found_errors=0

    # Field name mappings: incorrect -> correct
    declare -A field_names=(
        ["sprint_id"]="id"
        ["task_id"]="id"
        ["story_id"]="id"
        ["issue_id"]="id"
    )

    while IFS= read -r line; do
        ((line_num++))

        # Check for incorrect field names
        for old_name in "${!field_names[@]}"; do
            local new_name="${field_names[$old_name]}"

            # Match field names with or without YAML list marker (-)
            if [[ "$line" =~ ^[[:space:]]*(-[[:space:]]*)?${old_name}:[[:space:]] ]]; then
                if [[ "$AUTO_FIX" == "true" ]]; then
                    # Create backup if first fix
                    if ((FIXES_APPLIED == 0)); then
                        create_backup || return 1
                    fi

                    # Use sed with backup for safe replacement
                    # Handle both "field:" and "- field:" patterns
                    # Try list marker pattern first, then fallback to regular pattern
                    if sed -i "${BACKUP_SUFFIX}.tmp" "${line_num}s/^\\([[:space:]]*-[[:space:]]*\\)${old_name}:/\\1${new_name}:/" "$TARGET_FILE" 2>/dev/null || \
                       sed -i "${BACKUP_SUFFIX}.tmp" "${line_num}s/^\\([[:space:]]*\\)${old_name}:/\\1${new_name}:/" "$TARGET_FILE" 2>/dev/null; then
                        log_info "Fixed: $old_name -> $new_name (line $line_num)"
                        ((FIXES_APPLIED++))
                        rm -f -- "${TARGET_FILE}${BACKUP_SUFFIX}.tmp" 2>/dev/null || true
                    else
                        log_error "Line $line_num: Deprecated field name '$old_name' (should be '$new_name') - auto-fix failed"
                        ((ERRORS++))
                        ((found_errors++))
                        rm -f -- "${TARGET_FILE}${BACKUP_SUFFIX}.tmp" 2>/dev/null || true
                    fi
                else
                    log_error "Line $line_num: Deprecated field name '$old_name' (should be '$new_name')"
                    ((ERRORS++))
                    ((found_errors++))
                fi
            fi
        done
    done < "$TARGET_FILE"

    if ((found_errors > 0)); then
        return 1
    fi

    return 0
}

#######################################
# Validates YAML indentation consistency
# Checks: consistent spacing, no tabs
# Returns:
#   0 if valid, 1 if errors found
#######################################
check_indentation() {
    local -i line_num=0
    local line
    local -i found_errors=0

    while IFS= read -r line; do
        ((line_num++))

        # Check for tab characters
        if [[ "$line" =~ $'\t' ]]; then
            log_error "Line $line_num: Tab character found (use spaces for YAML indentation)"
            ((ERRORS++))
            ((found_errors++))
        fi

        # Check for inconsistent indentation (not multiple of 2)
        if [[ "$line" =~ ^([[:space:]]+) ]]; then
            local indent="${BASH_REMATCH[1]}"
            local indent_len=${#indent}

            if ((indent_len % 2 != 0)); then
                log_warn "Line $line_num: Inconsistent indentation (not multiple of 2 spaces)"
                ((WARNINGS++))
            fi
        fi
    done < "$TARGET_FILE"

    if ((found_errors > 0)); then
        return 1
    fi

    return 0
}

#######################################
# Main validation function
# Returns:
#   0 if all checks pass, 1 otherwise
#######################################
main() {
    # Validate arguments
    if [[ "$AUTO_FIX" != "true" ]] && [[ "$AUTO_FIX" != "false" ]]; then
        log_error "Invalid AUTO_FIX value: $AUTO_FIX (must be 'true' or 'false')"
        return "$EXIT_FAILURE"
    fi

    # Resolve relative TARGET_FILE (default "tasks.yml") against the calling
    # project's root, not whatever directory happened to be current.
    if ! cd -- "$PROJECT_ROOT" 2>/dev/null; then
        log_error "Cannot access project directory: $PROJECT_ROOT"
        return "$EXIT_FAILURE"
    fi

    # Validate file path
    if ! validate_file_path "$TARGET_FILE"; then
        return "$EXIT_FAILURE"
    fi

    # Check if file exists. Not every project uses tasks.yml (e.g. non-autoflow
    # projects), so a missing target is a skip, not a failure - the same
    # convention layer1_syntax.sh uses for files it can't find.
    if [[ ! -f "$TARGET_FILE" ]]; then
        log_warn "Target file not found: $TARGET_FILE (skipping Layer 2 format checks)"
        return "$EXIT_SUCCESS"
    fi

    # Check if file is readable
    if [[ ! -r "$TARGET_FILE" ]]; then
        log_error "Target file not readable: $TARGET_FILE"
        return "$EXIT_FAILURE"
    fi

    log_info "Starting Layer 2 format validation: $TARGET_FILE"
    if [[ "$AUTO_FIX" == "true" ]]; then
        log_info "Auto-fix mode: ENABLED"
    else
        log_info "Auto-fix mode: DISABLED"
    fi

    # Run validation checks
    check_markdown_in_yaml || true
    check_enum_values || true
    check_field_names || true
    check_indentation || true

    # Report results
    echo ""
    log_info "=== Layer 2 Format Validation Results ==="
    log_info "Errors: $ERRORS"
    log_info "Warnings: $WARNINGS"

    if [[ "$AUTO_FIX" == "true" ]] && ((FIXES_APPLIED > 0)); then
        log_info "Fixes applied: $FIXES_APPLIED"
        cleanup_backup
    fi

    # Exit with appropriate code
    if ((ERRORS > 0)); then
        log_error "Layer 2 validation FAILED"

        # Restore backup if auto-fix was attempted but errors remain
        if [[ "$AUTO_FIX" == "true" ]] && ((FIXES_APPLIED > 0)); then
            restore_backup
        fi

        return "$EXIT_FAILURE"
    else
        log_info "Layer 2 validation PASSED"
        return "$EXIT_SUCCESS"
    fi
}

# Run main function
main "$@"
