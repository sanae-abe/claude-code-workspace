#!/usr/bin/env bash
# Layer 1-2: Toolchain Syntax Gate
# Type checking, linting and format verification for the detected toolchains.
# Version: 1.0.0
# Arguments: $1 = auto-fix mode (true|false)
# Exit codes: 0 = passed, 1 = failures found, 2 = issues auto-fixed (no failures)

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
readonly MAX_OUTPUT_LINES=30

readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

declare -i ERROR_COUNT=0
declare -i FIXED_COUNT=0
declare -i RAN_COUNT=0

# shellcheck source=validation/utils/detect-toolchain.sh
source "${SCRIPT_DIR}/../utils/detect-toolchain.sh"

# ============================================================================
# Utility Functions
# ============================================================================

log_error() {
    printf "${RED}[TOOLCHAIN]${NC} %s\n" "$*" >&2
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

# Run one check command, capturing output so a passing check stays quiet.
# Arguments: $1 = label, $@ = command and its arguments
run_check() {
    local label="$1"
    shift

    RAN_COUNT=$((RAN_COUNT + 1))

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

# Run a command whose purpose is to rewrite files. Its failure is reported but
# does not fail the gate: the follow-up check decides whether the fix worked.
# Arguments: $1 = label, $@ = command and its arguments
run_fixer() {
    local label="$1"
    shift

    local output
    local code=0
    output=$("$@" 2>&1) || code=$?

    if ((code == 0)); then
        FIXED_COUNT=$((FIXED_COUNT + 1))
        log_success "$label (auto-fix applied)"
        return 0
    fi

    log_warning "$label could not complete (exit $code)"
    printf '%s\n' "$output" | tail -n "$MAX_OUTPUT_LINES" >&2
    return 1
}

# ============================================================================
# Node.js / TypeScript
# ============================================================================

check_node() {
    if ! command -v npm &>/dev/null; then
        log_warning "package.json found but npm is not installed (skipping Node checks)"
        return 0
    fi

    check_node_types
    check_node_lint
    check_node_format
}

check_node_types() {
    local script
    if script=$(npm_script_name "$PROJECT_ROOT" typecheck type-check tsc); then
        run_check "npm run $script" npm run --silent "$script" || true
        return 0
    fi

    if [[ -f "$PROJECT_ROOT/tsconfig.json" ]]; then
        run_check "tsc --noEmit" npx --no-install tsc --noEmit || true
        return 0
    fi

    log_info "No TypeScript configuration detected (skipping type check)"
}

check_node_lint() {
    local script
    if [[ "$AUTO_FIX" == "true" ]]; then
        if script=$(npm_script_name "$PROJECT_ROOT" lint:fix); then
            run_fixer "npm run $script" npm run --silent "$script" || true
        elif has_eslint_config "$PROJECT_ROOT"; then
            run_fixer "eslint --fix" npx --no-install eslint . --fix || true
        fi
    fi

    if script=$(npm_script_name "$PROJECT_ROOT" lint); then
        run_check "npm run $script" npm run --silent "$script" || true
        return 0
    fi

    if has_eslint_config "$PROJECT_ROOT"; then
        run_check "eslint" npx --no-install eslint . || true
        return 0
    fi

    log_info "No ESLint configuration detected (skipping lint)"
}

check_node_format() {
    if ! has_prettier_config "$PROJECT_ROOT"; then
        log_info "No Prettier configuration detected (skipping format check)"
        return 0
    fi

    if [[ "$AUTO_FIX" == "true" ]]; then
        run_fixer "prettier --write" npx --no-install prettier --write . || true
    fi

    run_check "prettier --check" npx --no-install prettier --check . || true
}

# ============================================================================
# Rust
# ============================================================================

check_rust() {
    if ! command -v cargo &>/dev/null; then
        log_warning "Cargo.toml found but cargo is not installed (skipping Rust checks)"
        return 0
    fi

    if [[ "$AUTO_FIX" == "true" ]]; then
        run_fixer "cargo fmt" cargo fmt || true
    fi

    run_check "cargo fmt --check" cargo fmt --check || true
    run_check "cargo clippy" cargo clippy --all-features -- -D warnings || true
    run_check "cargo check" cargo check --all-features || true
}

# ============================================================================
# Python
# ============================================================================

check_python() {
    if command -v ruff &>/dev/null; then
        if [[ "$AUTO_FIX" == "true" ]]; then
            run_fixer "ruff format" ruff format . || true
            run_fixer "ruff check --fix" ruff check --fix . || true
        fi

        run_check "ruff format --check" ruff format --check . || true
        run_check "ruff check" ruff check . || true
    else
        log_warning "Python project detected but ruff is not installed (skipping lint/format)"
    fi

    check_python_types
}

check_python_types() {
    if ! command -v mypy &>/dev/null; then
        log_info "mypy not installed (skipping type check)"
        return 0
    fi

    # mypy without configuration produces noise on most codebases, so only run
    # it where the project has opted in.
    if [[ -f "$PROJECT_ROOT/mypy.ini" || -f "$PROJECT_ROOT/.mypy.ini" ]] \
        || grep -qs '^\[tool\.mypy\]' "$PROJECT_ROOT/pyproject.toml" \
        || grep -qs '^\[mypy\]' "$PROJECT_ROOT/setup.cfg"; then
        run_check "mypy" mypy . || true
    else
        log_info "No mypy configuration detected (skipping type check)"
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

    log_info "Starting Layer 1-2: Toolchain Syntax Gate"
    log_info "Auto-fix mode: $AUTO_FIX"

    local -a types=()
    local detected
    while IFS= read -r detected; do
        [[ -n "$detected" ]] && types+=("$detected")
    done < <(detect_project_types "$PROJECT_ROOT")

    if ((${#types[@]} == 0)); then
        log_warning "No supported toolchain detected (skipping toolchain checks)"
        exit 0
    fi

    log_info "Detected toolchains: ${types[*]}"

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
    log_info "Layer 1-2 Toolchain Summary"
    log_info "Checks run: $RAN_COUNT | Failed: $ERROR_COUNT | Auto-fixed: $FIXED_COUNT"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ((RAN_COUNT == 0)); then
        log_warning "Toolchain detected but no check was runnable (missing tools or configuration)"
        exit 0
    fi

    if ((ERROR_COUNT > 0)); then
        log_error "Toolchain validation FAILED: $ERROR_COUNT check(s) failed"
        exit 1
    fi

    if ((FIXED_COUNT > 0)); then
        log_success "Toolchain validation passed after auto-fix"
        exit 2
    fi

    log_success "Toolchain validation PASSED"
    exit 0
}

trap 'log_error "Gate failed unexpectedly at line $LINENO"' ERR

main "$@"
