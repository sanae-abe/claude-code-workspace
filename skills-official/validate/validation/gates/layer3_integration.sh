#!/usr/bin/env bash
# Layer 3-4: Integration Gate
# Test execution and coverage threshold verification.
# Version: 1.0.0
# Arguments: $1 = auto-fix mode (true|false) - accepted for interface parity,
#            integration failures are never auto-fixable.
# Exit codes: 0 = passed, 1 = failures found

set -Eeuo pipefail
IFS=$'\n\t'

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
readonly PROJECT_ROOT
readonly AUTO_FIX="${1:-false}"
readonly MAX_OUTPUT_LINES=40

# Overridable from .autoflow/validation.conf via config.sh
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
readonly COVERAGE_THRESHOLD

readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

declare -i ERROR_COUNT=0
declare -i RAN_COUNT=0

# shellcheck source=validation/utils/detect-toolchain.sh
source "${SCRIPT_DIR}/../utils/detect-toolchain.sh"

# ============================================================================
# Utility Functions
# ============================================================================

log_error() {
    printf "${RED}[INTEGRATION]${NC} %s\n" "$*" >&2
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$*" >&2
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$*" >&2
}

log_info() {
    printf "[INFO] %s\n" "$*" >&2
}

# Run a test command, capturing output so a passing suite stays quiet.
# Arguments: $1 = label, $@ = command and its arguments
run_suite() {
    local label="$1"
    shift

    RAN_COUNT=$((RAN_COUNT + 1))
    log_info "Running: $label"

    local output
    local code=0
    output=$("$@" 2>&1) || code=$?

    if ((code == 0)); then
        log_success "$label"
        return 0
    fi

    ERROR_COUNT=$((ERROR_COUNT + 1))
    log_error "$label failed (exit $code)"
    printf '%s\n' "$output" | tail -n "$MAX_OUTPUT_LINES" >&2
    return 1
}

# Compare a measured coverage percentage against the configured threshold.
# Arguments: $1 = source label, $2 = percentage (may be fractional)
enforce_coverage() {
    local source_label="$1"
    local pct="$2"

    if ! python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) >= float(sys.argv[2]) else 1)" \
        "$pct" "$COVERAGE_THRESHOLD"; then
        ERROR_COUNT=$((ERROR_COUNT + 1))
        log_error "Coverage ${pct}% is below the ${COVERAGE_THRESHOLD}% threshold (${source_label})"
        return 1
    fi

    log_success "Coverage ${pct}% meets the ${COVERAGE_THRESHOLD}% threshold (${source_label})"
    return 0
}

# ============================================================================
# Coverage Readers
# ============================================================================

# Print total line coverage from Istanbul's coverage-summary.json, or nothing.
read_istanbul_coverage() {
    local summary="$PROJECT_ROOT/coverage/coverage-summary.json"
    [[ -f "$summary" ]] || return 1

    python3 - "$summary" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
    print(data["total"]["lines"]["pct"])
except (OSError, ValueError, KeyError, TypeError):
    sys.exit(1)
PY
}

# Print total line coverage from a Cobertura XML report, or nothing.
read_cobertura_coverage() {
    local report="$1"
    [[ -f "$report" ]] || return 1

    python3 - "$report" <<'PY'
import sys
import xml.etree.ElementTree as ET

try:
    root = ET.parse(sys.argv[1]).getroot()
    print(round(float(root.attrib["line-rate"]) * 100, 2))
except (OSError, ET.ParseError, KeyError, ValueError):
    sys.exit(1)
PY
}

# ============================================================================
# Node.js
# ============================================================================

check_node() {
    if ! command -v npm &>/dev/null; then
        log_warning "package.json found but npm is not installed (skipping Node tests)"
        return 0
    fi

    local script
    if ! script=$(npm_script_name "$PROJECT_ROOT" test:run test:ci test); then
        log_info "No test script in package.json (skipping Node tests)"
        return 0
    fi

    # CI=true keeps watch-mode runners (vitest, jest, react-scripts) from hanging.
    CI=true run_suite "npm run $script" npm run --silent "$script" || true

    local pct
    if pct=$(read_istanbul_coverage); then
        enforce_coverage "coverage/coverage-summary.json" "$pct" || true
    else
        log_info "No Istanbul coverage summary found (coverage threshold not enforced)"
    fi
}

# ============================================================================
# Rust
# ============================================================================

check_rust() {
    if ! command -v cargo &>/dev/null; then
        log_warning "Cargo.toml found but cargo is not installed (skipping Rust tests)"
        return 0
    fi

    run_suite "cargo test" cargo test --all-features || true

    local pct
    if pct=$(read_cobertura_coverage "$PROJECT_ROOT/cobertura.xml"); then
        enforce_coverage "cobertura.xml" "$pct" || true
    else
        log_info "No Cobertura report found (coverage threshold not enforced)"
    fi
}

# ============================================================================
# Python
# ============================================================================

check_python() {
    if ! command -v pytest &>/dev/null; then
        log_warning "Python project detected but pytest is not installed (skipping Python tests)"
        return 0
    fi

    run_suite "pytest" pytest || true

    local pct
    if pct=$(read_cobertura_coverage "$PROJECT_ROOT/coverage.xml"); then
        enforce_coverage "coverage.xml" "$pct" || true
    else
        log_info "No Cobertura report found (coverage threshold not enforced)"
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    if [[ "$AUTO_FIX" != "true" && "$AUTO_FIX" != "false" ]]; then
        log_error "Invalid auto-fix value: $AUTO_FIX (must be 'true' or 'false')"
        exit 1
    fi

    if ! cd -- "$PROJECT_ROOT" 2>/dev/null; then
        log_error "Cannot access project directory"
        exit 1
    fi

    log_info "Starting Layer 3-4: Integration Gate"
    log_info "Coverage threshold: ${COVERAGE_THRESHOLD}%"

    local -a types=()
    local detected
    while IFS= read -r detected; do
        [[ -n "$detected" ]] && types+=("$detected")
    done < <(detect_project_types "$PROJECT_ROOT")

    if ((${#types[@]} == 0)); then
        log_warning "No supported toolchain detected (skipping integration checks)"
        exit 0
    fi

    local type
    for type in "${types[@]}"; do
        case "$type" in
            node)   check_node ;;
            rust)   check_rust ;;
            python) check_python ;;
        esac
    done

    printf "\n" >&2
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Layer 3-4 Integration Summary"
    log_info "Suites run: $RAN_COUNT | Failed checks: $ERROR_COUNT"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ((RAN_COUNT == 0)); then
        log_warning "Toolchain detected but no test suite was runnable"
        exit 0
    fi

    if ((ERROR_COUNT > 0)); then
        log_error "Integration validation FAILED: $ERROR_COUNT check(s) failed"
        exit 1
    fi

    log_success "Integration validation PASSED"
    exit 0
}

trap 'log_error "Gate failed unexpectedly at line $LINENO"' ERR

main "$@"
