#!/usr/bin/env bash
# test_layer1_toolchain.sh - Test Layer 1-2 Toolchain Syntax Gate
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GATE_SCRIPT="${SCRIPT_DIR}/../gates/layer1_toolchain.sh"
readonly DETECT_UTIL="${SCRIPT_DIR}/../utils/detect-toolchain.sh"
readonly TEMP_DIR=$(mktemp -d)

declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

cleanup() {
    rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

test_start() {
    local test_name="$1"
    ((TESTS_RUN++))
    echo -n "[TEST] $test_name ... "
}

test_pass() {
    ((TESTS_PASSED++))
    echo "PASS"
}

test_fail() {
    local reason="${1:-unknown reason}"
    ((TESTS_FAILED++))
    echo "FAIL"
    echo "  Reason: $reason"
}

test_skip() {
    local reason="${1:-unknown reason}"
    echo "SKIP ($reason)"
}

# Create an isolated project directory and echo its path.
# Arguments: $1 = directory name
make_project() {
    local name="$1"
    local dir="${TEMP_DIR}/${name}"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
}

# Run the gate against a project root and echo its exit code.
# Arguments: $1 = project root, $2 = auto-fix value
run_gate() {
    local root="$1"
    local auto_fix="${2:-false}"
    local code=0

    PROJECT_ROOT="$root" "$GATE_SCRIPT" "$auto_fix" >/dev/null 2>&1 || code=$?
    printf '%s\n' "$code"
}

test_gate_exists() {
    test_start "Gate script exists and is executable"
    if [[ -x "$GATE_SCRIPT" ]]; then
        test_pass
    else
        test_fail "Gate script missing or not executable"
    fi
}

test_no_toolchain_passes() {
    test_start "Project without a supported toolchain is skipped"
    local dir
    dir=$(make_project "empty")

    if [[ "$(run_gate "$dir")" == "0" ]]; then
        test_pass
    else
        test_fail "Expected exit 0 for a project with no toolchain"
    fi
}

test_failing_typecheck_fails() {
    test_start "Failing typecheck script fails the gate"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_project "node-fail")
    cat > "$dir/package.json" <<'JSON'
{ "name": "fixture", "version": "1.0.0", "scripts": { "typecheck": "exit 1" } }
JSON

    if [[ "$(run_gate "$dir")" == "1" ]]; then
        test_pass
    else
        test_fail "Expected exit 1 when typecheck fails"
    fi
}

test_passing_typecheck_passes() {
    test_start "Passing typecheck script passes the gate"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_project "node-pass")
    cat > "$dir/package.json" <<'JSON'
{ "name": "fixture", "version": "1.0.0", "scripts": { "typecheck": "exit 0" } }
JSON

    if [[ "$(run_gate "$dir")" == "0" ]]; then
        test_pass
    else
        test_fail "Expected exit 0 when typecheck passes"
    fi
}

test_invalid_auto_fix_rejected() {
    test_start "Invalid auto-fix value is rejected"
    local dir
    dir=$(make_project "bad-arg")

    if [[ "$(run_gate "$dir" "maybe")" == "1" ]]; then
        test_pass
    else
        test_fail "Expected exit 1 for an invalid auto-fix value"
    fi
}

test_detect_project_types() {
    test_start "detect_project_types identifies node, rust and python"
    # shellcheck source=validation/utils/detect-toolchain.sh
    source "$DETECT_UTIL"

    local dir
    dir=$(make_project "multi")
    : > "$dir/package.json"
    : > "$dir/Cargo.toml"
    : > "$dir/pyproject.toml"

    local detected
    detected=$(detect_project_types "$dir" | tr '\n' ' ')

    if [[ "$detected" == "node rust python " ]]; then
        test_pass
    else
        test_fail "Expected 'node rust python', got '$detected'"
    fi
}

test_has_npm_script() {
    test_start "has_npm_script detects declared scripts only"
    # shellcheck source=validation/utils/detect-toolchain.sh
    source "$DETECT_UTIL"

    local dir
    dir=$(make_project "scripts")
    cat > "$dir/package.json" <<'JSON'
{ "name": "fixture", "version": "1.0.0", "scripts": { "lint": "eslint ." } }
JSON

    if has_npm_script "$dir" "lint" && ! has_npm_script "$dir" "typecheck"; then
        test_pass
    else
        test_fail "Script presence was reported incorrectly"
    fi
}

test_malformed_package_json() {
    test_start "Malformed package.json does not crash detection"
    # shellcheck source=validation/utils/detect-toolchain.sh
    source "$DETECT_UTIL"

    local dir
    dir=$(make_project "malformed")
    echo '{ this is not json' > "$dir/package.json"

    if ! has_npm_script "$dir" "lint"; then
        test_pass
    else
        test_fail "Malformed package.json should report no scripts"
    fi
}

main() {
    echo "Testing Layer 1-2 Toolchain Gate"
    echo "================================="
    echo

    test_gate_exists || true
    test_no_toolchain_passes || true
    test_failing_typecheck_fails || true
    test_passing_typecheck_passes || true
    test_invalid_auto_fix_rejected || true
    test_detect_project_types || true
    test_has_npm_script || true
    test_malformed_package_json || true

    echo
    echo "==========================================="
    echo "Test Summary"
    echo "==========================================="
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "==========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo
        echo "All tests passed!"
        exit 0
    else
        echo
        echo "Some tests failed!"
        exit 1
    fi
}

main "$@"
