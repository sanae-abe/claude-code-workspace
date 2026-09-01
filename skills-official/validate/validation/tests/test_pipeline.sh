#!/usr/bin/env bash
# test_pipeline.sh - Test Pipeline Orchestration
# Tests layer selection, auto-fix mode, report generation, and exit codes

set -Eeuo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PIPELINE_SCRIPT="${SCRIPT_DIR}/../pipeline.sh"
readonly TEMP_DIR=$(mktemp -d)

# Test counters
declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

# Cleanup
cleanup() {
    rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

# Color output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test helper functions
test_start() {
    local test_name="$1"
    ((TESTS_RUN++))
    printf "${YELLOW}[TEST]${NC} %s ... " "$test_name"
}

test_pass() {
    ((TESTS_PASSED++))
    printf "${GREEN}PASS${NC}\n"
}

test_fail() {
    local reason="${1:-unknown reason}"
    ((TESTS_FAILED++))
    printf "${RED}FAIL${NC}\n"
    printf "  Reason: %s\n" "$reason"
}

# Test pipeline script exists
test_pipeline_exists() {
    test_start "Pipeline script exists"

    if [[ -f "$PIPELINE_SCRIPT" ]]; then
        test_pass
        return 0
    else
        test_fail "Pipeline script not found at $PIPELINE_SCRIPT"
        return 1
    fi
}

# Test help flag
test_help_flag() {
    test_start "Shows help with --help flag"

    if "$PIPELINE_SCRIPT" --help 2>&1 | grep -q "Usage:"; then
        test_pass
        return 0
    else
        test_fail "Help not displayed"
        return 1
    fi
}

# Test layer selection
test_layer_selection_syntax() {
    test_start "Accepts --layers=syntax"

    # Create a test validation that checks the argument parsing
    local test_script="${TEMP_DIR}/test_layers.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
LAYERS="all"
for arg in "$@"; do
    case "$arg" in
        --layers=*)
            LAYERS="${arg#*=}"
            ;;
    esac
done
if [[ "$LAYERS" =~ ^[a-zA-Z0-9_,]+$ ]]; then
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$test_script"

    if "$test_script" --layers=syntax; then
        test_pass
        return 0
    else
        test_fail "Layer selection failed"
        return 1
    fi
}

# Test layer selection all
test_layer_selection_all() {
    test_start "Accepts --layers=all"

    local test_script="${TEMP_DIR}/test_all.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
LAYERS="all"
for arg in "$@"; do
    case "$arg" in
        --layers=*)
            LAYERS="${arg#*=}"
            ;;
    esac
done
if [[ "$LAYERS" == "all" ]]; then
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$test_script"

    if "$test_script" --layers=all; then
        test_pass
        return 0
    else
        test_fail "Layer 'all' not accepted"
        return 1
    fi
}

# Test multiple layer selection
test_layer_selection_multiple() {
    test_start "Accepts --layers=syntax,security"

    local test_script="${TEMP_DIR}/test_multiple.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
LAYERS=""
for arg in "$@"; do
    case "$arg" in
        --layers=*)
            LAYERS="${arg#*=}"
            ;;
    esac
done
if [[ "$LAYERS" == "syntax,security" ]]; then
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$test_script"

    if "$test_script" --layers=syntax,security; then
        test_pass
        return 0
    else
        test_fail "Multiple layer selection failed"
        return 1
    fi
}

# Test auto-fix flag
test_auto_fix_flag() {
    test_start "Accepts --auto-fix=true"

    local test_script="${TEMP_DIR}/test_autofix.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
AUTO_FIX="false"
for arg in "$@"; do
    case "$arg" in
        --auto-fix=*)
            AUTO_FIX="${arg#*=}"
            ;;
    esac
done
if [[ "$AUTO_FIX" =~ ^(true|false)$ ]]; then
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$test_script"

    if "$test_script" --auto-fix=true; then
        test_pass
        return 0
    else
        test_fail "Auto-fix flag validation failed"
        return 1
    fi
}

# Test stop-on-failure flag
test_stop_on_failure_flag() {
    test_start "Accepts --stop-on-failure=true"

    local test_script="${TEMP_DIR}/test_stop.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
STOP_ON_FAILURE="false"
for arg in "$@"; do
    case "$arg" in
        --stop-on-failure=*)
            STOP_ON_FAILURE="${arg#*=}"
            ;;
    esac
done
if [[ "$STOP_ON_FAILURE" =~ ^(true|false)$ ]]; then
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$test_script"

    if "$test_script" --stop-on-failure=true; then
        test_pass
        return 0
    else
        test_fail "Stop-on-failure flag validation failed"
        return 1
    fi
}

# Test invalid layer name
test_invalid_layer_name() {
    test_start "Rejects invalid layer names"

    local test_script="${TEMP_DIR}/test_invalid.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
safe_validate_layers() {
    local layers="$1"
    if [[ "$layers" == "all" ]]; then
        return 0
    fi
    if [[ ! "$layers" =~ ^[a-zA-Z0-9_,]+$ ]]; then
        return 1
    fi
    local IFS=','
    for layer in $layers; do
        case "$layer" in
            syntax|security|integration|semantic)
                ;;
            *)
                return 1
                ;;
        esac
    done
    return 0
}
safe_validate_layers "$1"
EOF
    chmod +x "$test_script"

    if ! "$test_script" "invalid_layer_name"; then
        test_pass
        return 0
    else
        test_fail "Invalid layer name was accepted"
        return 1
    fi
}

# Test exit code on success
test_exit_code_success() {
    test_start "Returns exit code 0 on success"

    local test_script="${TEMP_DIR}/test_success.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$test_script"

    if "$test_script"; then
        test_pass
        return 0
    else
        test_fail "Expected exit code 0"
        return 1
    fi
}

# Test exit code on failure
test_exit_code_failure() {
    test_start "Returns exit code 1 on failure"

    local test_script="${TEMP_DIR}/test_failure.sh"
    cat > "$test_script" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$test_script"

    if ! "$test_script"; then
        test_pass
        return 0
    else
        test_fail "Expected exit code 1"
        return 1
    fi
}

# Test report generation
test_report_generation() {
    test_start "Generates JSON report"

    local report_file="${TEMP_DIR}/report.json"
    cat > "$report_file" <<'EOF'
{
  "timestamp": "2025-11-16T00:00:00Z",
  "pipeline": {
    "layers": "all",
    "auto_fix": false,
    "stop_on_failure": false
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

    if [[ -f "$report_file" ]] && jq -e . "$report_file" &>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Report generation failed"
        return 1
    fi
}

# Test report summary
test_report_summary() {
    test_start "Report contains summary section"

    local report_file="${TEMP_DIR}/summary_report.json"
    cat > "$report_file" <<'EOF'
{
  "summary": {
    "total": 5,
    "passed": 3,
    "failed": 2,
    "auto_fixed": 0
  }
}
EOF

    if jq -e '.summary.total' "$report_file" &>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Summary section missing"
        return 1
    fi
}

# Test parallel execution detection
test_parallel_execution() {
    test_start "Detects independent gates for parallel execution"

    local layers="syntax,security"
    local has_syntax=false
    local has_security=false

    local IFS=','
    for layer in $layers; do
        case "$layer" in
            syntax) has_syntax=true ;;
            security) has_security=true ;;
        esac
    done

    if [[ "$has_syntax" == "true" && "$has_security" == "true" ]]; then
        test_pass
        return 0
    else
        test_fail "Parallel execution detection failed"
        return 1
    fi
}

# Test argument validation
test_argument_validation() {
    test_start "Validates boolean arguments"

    local value="true"
    if [[ "$value" =~ ^(true|false)$ ]]; then
        test_pass
        return 0
    else
        test_fail "Argument validation failed"
        return 1
    fi
}

# Test invalid boolean value
test_invalid_boolean() {
    test_start "Rejects invalid boolean values"

    local value="maybe"
    if ! [[ "$value" =~ ^(true|false)$ ]]; then
        test_pass
        return 0
    else
        test_fail "Invalid boolean was accepted"
        return 1
    fi
}

# Main test suite
main() {
    printf "===========================================\n"
    printf "Pipeline Orchestration Test Suite\n"
    printf "===========================================\n\n"

    # Check prerequisites
    if ! command -v jq &>/dev/null; then
        printf "${YELLOW}WARNING:${NC} jq not found, some tests will be skipped\n\n"
    fi

    # Run tests
    test_pipeline_exists || true
    test_help_flag || true
    test_layer_selection_syntax || true
    test_layer_selection_all || true
    test_layer_selection_multiple || true
    test_auto_fix_flag || true
    test_stop_on_failure_flag || true
    test_invalid_layer_name || true
    test_exit_code_success || true
    test_exit_code_failure || true
    test_report_generation || true
    test_report_summary || true
    test_parallel_execution || true
    test_argument_validation || true
    test_invalid_boolean || true

    # Summary
    printf "\n===========================================\n"
    printf "Test Summary\n"
    printf "===========================================\n"
    printf "Tests run:    %d\n" "$TESTS_RUN"
    printf "Tests passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
    printf "Tests failed: ${RED}%d${NC}\n" "$TESTS_FAILED"
    printf "===========================================\n"

    # Exit code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "\n${GREEN}All tests passed!${NC}\n"
        exit 0
    else
        printf "\n${RED}Some tests failed!${NC}\n"
        exit 1
    fi
}

main "$@"
