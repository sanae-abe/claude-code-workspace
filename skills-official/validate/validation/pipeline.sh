#!/usr/bin/env bash
# validation/pipeline.sh - Main quality gate pipeline orchestration
#
# Usage:
#   pipeline.sh [OPTIONS]
#
# Options:
#   --layers=LAYERS              Comma-separated layers to run (all|syntax,security)
#   --auto-fix=BOOL              Enable auto-fix for fixable issues (true|false)
#   --stop-on-failure=BOOL       Stop on critical failures (true|false)
#
# Exit codes:
#   0 - All gates passed
#   1 - General error or validation failed
#   2 - Invalid arguments
#   3 - Critical failure

set -Eeuo pipefail

# Script directory detection for reliable sourcing
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR

# Source configuration and utilities
# shellcheck source=validation/config.sh
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=validation/utils/logging.sh
source "${SCRIPT_DIR}/utils/logging.sh"

# Global variables
LAYERS="all"
AUTO_FIX="false"
STOP_ON_FAILURE="false"
REPORT_FILE=""
TEMP_DIR=""

# Counters
PASSED_COUNT=0
FAILED_COUNT=0
AUTO_FIXED_COUNT=0

# Cleanup function for temporary resources
cleanup() {
    local exit_code=$?
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
    exit "$exit_code"
}

# Register cleanup on exit
trap cleanup EXIT INT TERM

# Validate layers format: comma-separated list or 'all'
# Returns 0 if valid, 1 if invalid
safe_validate_layers() {
    local layers="$1"

    # Allow 'all' as special case
    if [[ "$layers" == "all" ]]; then
        return 0
    fi

    # Validate format: only alphanumeric, comma, underscore
    if [[ ! "$layers" =~ ^[a-zA-Z0-9_,]+$ ]]; then
        log_error "Invalid layers format: $layers"
        log_error "Must be 'all' or comma-separated list (e.g., 'syntax,security')"
        return 1
    fi

    # Validate individual layer names
    local IFS=','
    local layer
    for layer in $layers; do
        case "$layer" in
            syntax|security|integration|semantic)
                # Valid layer
                ;;
            *)
                log_error "Unknown layer: $layer"
                log_error "Valid layers: syntax, security, integration, semantic, all"
                return 1
                ;;
        esac
    done

    return 0
}

# Parse command line arguments
parse_arguments() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --layers=*)
                LAYERS="${arg#*=}"
                ;;
            --auto-fix=*)
                AUTO_FIX="${arg#*=}"
                ;;
            --stop-on-failure=*)
                STOP_ON_FAILURE="${arg#*=}"
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $arg"
                show_usage
                exit 2
                ;;
        esac
    done

    # Validate layers
    if ! safe_validate_layers "$LAYERS"; then
        exit 2
    fi

    # Validate boolean arguments
    if [[ ! "$AUTO_FIX" =~ ^(true|false)$ ]]; then
        log_error "Invalid --auto-fix value: $AUTO_FIX (must be 'true' or 'false')"
        exit 2
    fi

    if [[ ! "$STOP_ON_FAILURE" =~ ^(true|false)$ ]]; then
        log_error "Invalid --stop-on-failure value: $STOP_ON_FAILURE (must be 'true' or 'false')"
        exit 2
    fi
}

# Show usage information
show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Quality gate pipeline orchestration for validation system.

OPTIONS:
    --layers=LAYERS              Comma-separated layers to run
                                 Options: all, syntax, security, integration, semantic
                                 Default: all

    --auto-fix=BOOL              Enable auto-fix for fixable issues
                                 Options: true, false
                                 Default: false

    --stop-on-failure=BOOL       Stop pipeline on critical failures
                                 Options: true, false
                                 Default: false

    --help, -h                   Show this help message

EXAMPLES:
    # Run all layers with auto-fix
    $(basename "$0") --layers=all --auto-fix=true

    # Run only security checks, stop on failure
    $(basename "$0") --layers=security --stop-on-failure=true

    # Run syntax and security layers
    $(basename "$0") --layers=syntax,security

EXIT CODES:
    0 - All gates passed
    1 - General error or validation failed
    2 - Invalid arguments
    3 - Critical failure

REPORT:
    JSON report generated at: ${REPORT_DIR}/quality-gate-report.json
EOF
}

# Initialize report file
init_report() {
    # Create temporary directory safely
    TEMP_DIR=$(mktemp -d) || {
        log_error "Failed to create temporary directory"
        exit 1
    }

    REPORT_FILE="${REPORT_DIR}/quality-gate-report.json"

    # Initialize JSON report structure
    cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "pipeline": {
    "layers": "$LAYERS",
    "auto_fix": $AUTO_FIX,
    "stop_on_failure": $STOP_ON_FAILURE
  },
  "gates": [],
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "auto_fixed": 0
  },
  "status": "running"
}
EOF

    log_info "Report initialized at: $REPORT_FILE"
}

# Expand layers list (convert 'all' to specific layers)
expand_layers() {
    if [[ "$LAYERS" == "all" ]]; then
        echo "syntax,security,integration,semantic"
    else
        echo "$LAYERS"
    fi
}

# Map a layer name to its gate script path(s). Single source of truth for
# layer -> script resolution, shared by both the parallel and sequential
# execution paths so they can never disagree on where a layer's script lives.
# Arguments: $1 = layer name
# Outputs: space-separated list of gate script paths (may be empty)
get_gate_scripts_for_layer() {
    local layer="$1"

    case "$layer" in
        syntax)
            # Layer 2 (format) runs as part of the syntax layer
            echo "${SCRIPT_DIR}/gates/layer1_syntax.sh ${SCRIPT_DIR}/gates/layer2_format.sh"
            ;;
        security)
            echo "${SCRIPT_DIR}/gates/layer5_security.sh"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Run all gate scripts configured for a layer sequentially, merging their
# output and reducing their exit codes to a single worst-case status.
# Arguments: $@ = gate script paths
# Severity ranking: 3 (critical) > 1/other (failed) > 2 (auto_fixed) > 0 (passed)
run_gate_scripts() {
    local script
    local -i code
    local -i worst=0

    for script in "$@"; do
        if [[ ! -f "$script" ]]; then
            log_warn "Gate script not found: $script (skipping)"
            continue
        fi

        code=0
        "$script" "$AUTO_FIX" || code=$?

        if ((code == 3)); then
            worst=3
        elif ((code != 0 && code != 2 && worst != 3)); then
            worst=1
        elif ((code == 2 && worst == 0)); then
            worst=2
        fi
    done

    return "$worst"
}

# Run a single gate (all scripts configured for the given layer)
# Arguments: $1 = layer name, $2 = background flag (optional)
run_gate() {
    local layer="$1"
    local background="${2:-false}"
    local gate_result
    local gate_status
    local gate_output
    local output_file
    local -a gate_scripts
    # Guard against IFS=',' leaking in dynamically from main()'s layer-list
    # parsing loop, which would prevent the space-separated split below.
    local IFS=$' \t\n'

    read -r -a gate_scripts <<< "$(get_gate_scripts_for_layer "$layer")"

    if [[ ${#gate_scripts[@]} -eq 0 ]]; then
        log_warn "No gate script configured for layer: $layer (skipping)"
        return 0
    fi

    log_info "Running gate: $layer"

    # Run gate in background if requested
    if [[ "$background" == "true" ]]; then
        output_file="${TEMP_DIR}/${layer}.output"
        run_gate_scripts "${gate_scripts[@]}" > "$output_file" 2>&1 &
        return 0
    fi

    # Run gate synchronously and capture output
    gate_output=$(run_gate_scripts "${gate_scripts[@]}" 2>&1) || gate_result=$?
    gate_result=${gate_result:-0}

    # Determine gate status
    case "$gate_result" in
        0)
            gate_status="passed"
            ((PASSED_COUNT++))
            log_info "Gate $layer: PASSED"
            ;;
        1)
            gate_status="failed"
            ((FAILED_COUNT++))
            log_error "Gate $layer: FAILED"
            ;;
        2)
            gate_status="auto_fixed"
            ((AUTO_FIXED_COUNT++))
            log_info "Gate $layer: AUTO-FIXED"
            ;;
        3)
            gate_status="critical"
            ((FAILED_COUNT++))
            log_error "Gate $layer: CRITICAL FAILURE"

            # Stop on critical failure if configured
            if [[ "$STOP_ON_FAILURE" == "true" ]]; then
                log_error "Stopping pipeline due to critical failure"
                update_report "$layer" "$gate_status" "$gate_output"
                finalize_report "critical_failure"
                exit 3
            fi
            ;;
        *)
            gate_status="error"
            ((FAILED_COUNT++))
            log_error "Gate $layer: UNKNOWN ERROR (exit code: $gate_result)"
            ;;
    esac

    # Update report with gate result
    update_report "$layer" "$gate_status" "$gate_output"

    return "$gate_result"
}

# Process background gate result
# Arguments: $1 = layer name, $2 = exit code
process_gate_result() {
    local layer="$1"
    local gate_result="$2"
    local gate_status
    local gate_output
    local output_file="${TEMP_DIR}/${layer}.output"

    # Read output from file
    if [[ -f "$output_file" ]]; then
        gate_output=$(cat -- "$output_file")
    else
        gate_output="No output captured"
    fi

    # Determine gate status
    case "$gate_result" in
        0)
            gate_status="passed"
            ((PASSED_COUNT++))
            log_info "Gate $layer: PASSED"
            ;;
        1)
            gate_status="failed"
            ((FAILED_COUNT++))
            log_error "Gate $layer: FAILED"
            ;;
        2)
            gate_status="auto_fixed"
            ((AUTO_FIXED_COUNT++))
            log_info "Gate $layer: AUTO-FIXED"
            ;;
        3)
            gate_status="critical"
            ((FAILED_COUNT++))
            log_error "Gate $layer: CRITICAL FAILURE"
            ;;
        *)
            gate_status="error"
            ((FAILED_COUNT++))
            log_error "Gate $layer: UNKNOWN ERROR (exit code: $gate_result)"
            ;;
    esac

    # Update report with gate result
    update_report "$layer" "$gate_status" "$gate_output"

    return "$gate_result"
}

# Run independent gates in parallel
# Returns 0 if all gates passed, 1 if any failed
run_gates_parallel() {
    local -a pids=()
    local -a layers=()
    local -A pid_to_layer=()
    local failed=false
    local pid

    log_info "Running independent gates in parallel"

    # Start parallel execution for syntax and security layers
    for layer in syntax security; do
        # Run gate in background (run_gate resolves the layer's script(s) itself)
        run_gate "$layer" true &
        pid=$!
        pids+=("$pid")
        layers+=("$layer")
        pid_to_layer[$pid]="$layer"

        log_info "Started gate $layer with PID $pid"
    done

    # Wait for all background jobs and collect exit codes
    for pid in "${pids[@]}"; do
        local exit_code
        wait "$pid" || exit_code=$?
        exit_code=${exit_code:-0}

        layer="${pid_to_layer[$pid]}"

        # Process the result
        if ! process_gate_result "$layer" "$exit_code"; then
            failed=true

            # Check for critical failure
            if [[ "$exit_code" -eq 3 && "$STOP_ON_FAILURE" == "true" ]]; then
                log_error "Stopping pipeline due to critical failure in $layer"
                finalize_report "critical_failure"
                exit 3
            fi
        fi
    done

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    return 0
}

# Update report with gate result
# Arguments: $1 = layer, $2 = status, $3 = output
update_report() {
    local layer="$1"
    local status="$2"
    local output="$3"

    # Escape output for JSON
    local escaped_output
    escaped_output=$(printf '%s' "$output" | jq -Rs .)

    # Create temporary file for JSON manipulation
    local temp_report="${TEMP_DIR}/report.json"

    # Add gate result to report
    jq --arg layer "$layer" \
       --arg status "$status" \
       --argjson output "$escaped_output" \
       '.gates += [{
           "layer": $layer,
           "status": $status,
           "output": $output,
           "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
       }]' "$REPORT_FILE" > "$temp_report"

    mv -- "$temp_report" "$REPORT_FILE"
}

# Finalize report with summary
# Arguments: $1 = final status
finalize_report() {
    local final_status="$1"
    local temp_report="${TEMP_DIR}/report.json"
    local total_count=$((PASSED_COUNT + FAILED_COUNT))

    # Update summary and status
    jq --arg status "$final_status" \
       --arg total "$total_count" \
       --arg passed "$PASSED_COUNT" \
       --arg failed "$FAILED_COUNT" \
       --arg fixed "$AUTO_FIXED_COUNT" \
       '.summary.total = ($total | tonumber) |
        .summary.passed = ($passed | tonumber) |
        .summary.failed = ($failed | tonumber) |
        .summary.auto_fixed = ($fixed | tonumber) |
        .status = $status' "$REPORT_FILE" > "$temp_report"

    mv -- "$temp_report" "$REPORT_FILE"

    log_info "Report finalized at: $REPORT_FILE"
}

# Main pipeline execution
main() {
    log_info "Starting quality gate pipeline"
    log_info "Configuration: layers=$LAYERS, auto-fix=$AUTO_FIX, stop-on-failure=$STOP_ON_FAILURE"

    # Parse arguments
    parse_arguments "$@"

    # Initialize report
    init_report

    # Expand layers
    local expanded_layers
    expanded_layers=$(expand_layers)

    # Convert to array for easier processing
    local IFS=','
    local -a layer_array=()
    local layer
    for layer in $expanded_layers; do
        layer_array+=("$layer")
    done

    # Determine if we can use parallel execution
    local has_syntax=false
    local has_security=false

    for layer in "${layer_array[@]}"; do
        case "$layer" in
            syntax)
                has_syntax=true
                ;;
            security)
                has_security=true
                ;;
            *)
                # Other layers will be processed sequentially
                ;;
        esac
    done

    local pipeline_failed=false

    # Run syntax and security in parallel if both are present
    if [[ "$has_syntax" == "true" && "$has_security" == "true" ]]; then
        if ! run_gates_parallel; then
            if [[ "$STOP_ON_FAILURE" == "true" ]]; then
                pipeline_failed=true
            fi
        fi

        # Remove syntax and security from the list
        local -a remaining_layers=()
        for layer in "${layer_array[@]}"; do
            if [[ "$layer" != "syntax" && "$layer" != "security" ]]; then
                remaining_layers+=("$layer")
            fi
        done
        layer_array=("${remaining_layers[@]}")
    fi

    # Run remaining gates sequentially (run_gate resolves each layer's script(s) itself)
    if [[ "$pipeline_failed" == "false" ]]; then
        for layer in "${layer_array[@]}"; do
            if ! run_gate "$layer"; then
                if [[ "$STOP_ON_FAILURE" == "true" ]]; then
                    pipeline_failed=true
                    break
                fi
            fi
        done
    fi

    # Finalize report
    if [[ "$pipeline_failed" == "true" ]]; then
        finalize_report "failed"
        log_error "Pipeline failed with $FAILED_COUNT failures"
        exit 1
    elif [[ "$FAILED_COUNT" -gt 0 ]]; then
        finalize_report "completed_with_failures"
        log_warn "Pipeline completed with $FAILED_COUNT failures"
        exit 1
    else
        finalize_report "success"
        log_info "Pipeline completed successfully"
        log_info "Summary: $PASSED_COUNT passed, $AUTO_FIXED_COUNT auto-fixed"
        exit 0
    fi
}

# Run main function with all arguments
main "$@"
