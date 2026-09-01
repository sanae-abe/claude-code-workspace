#!/usr/bin/env bash
# test_layer3_integration.sh - Test Layer 3-4 Integration Gate
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GATE_SCRIPT="${SCRIPT_DIR}/../gates/layer3_integration.sh"
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

# Create a Node project whose test script exits with the given code.
# Arguments: $1 = directory name, $2 = test script exit code
make_node_project() {
    local name="$1"
    local exit_code="$2"
    local dir="${TEMP_DIR}/${name}"

    mkdir -p "$dir"
    cat > "$dir/package.json" <<JSON
{ "name": "fixture", "version": "1.0.0", "scripts": { "test:run": "exit ${exit_code}" } }
JSON

    printf '%s\n' "$dir"
}

# Write an Istanbul coverage summary reporting the given line percentage.
# Arguments: $1 = project root, $2 = percentage
write_coverage() {
    local dir="$1"
    local pct="$2"

    mkdir -p "$dir/coverage"
    printf '{"total":{"lines":{"pct":%s}}}\n' "$pct" > "$dir/coverage/coverage-summary.json"
}

# Run the gate against a project root and echo its exit code.
run_gate() {
    local root="$1"
    local code=0

    PROJECT_ROOT="$root" "$GATE_SCRIPT" false >/dev/null 2>&1 || code=$?
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
    local dir="${TEMP_DIR}/empty"
    mkdir -p "$dir"

    if [[ "$(run_gate "$dir")" == "0" ]]; then
        test_pass
    else
        test_fail "Expected exit 0 for a project with no toolchain"
    fi
}

test_passing_suite() {
    test_start "Passing test suite passes the gate"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_node_project "pass" 0)

    if [[ "$(run_gate "$dir")" == "0" ]]; then
        test_pass
    else
        test_fail "Expected exit 0 when the suite passes"
    fi
}

test_failing_suite() {
    test_start "Failing test suite fails the gate"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_node_project "fail" 1)

    if [[ "$(run_gate "$dir")" == "1" ]]; then
        test_pass
    else
        test_fail "Expected exit 1 when the suite fails"
    fi
}

test_coverage_below_threshold() {
    test_start "Coverage below the threshold fails the gate"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_node_project "low-coverage" 0)
    write_coverage "$dir" "42.5"

    if [[ "$(run_gate "$dir")" == "1" ]]; then
        test_pass
    else
        test_fail "Expected exit 1 when coverage is below the threshold"
    fi
}

test_coverage_above_threshold() {
    test_start "Coverage at or above the threshold passes the gate"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_node_project "high-coverage" 0)
    write_coverage "$dir" "91.2"

    if [[ "$(run_gate "$dir")" == "0" ]]; then
        test_pass
    else
        test_fail "Expected exit 0 when coverage meets the threshold"
    fi
}

test_missing_coverage_not_enforced() {
    test_start "Missing coverage report does not fail the gate"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_node_project "no-coverage" 0)

    if [[ "$(run_gate "$dir")" == "0" ]]; then
        test_pass
    else
        test_fail "Expected exit 0 when no coverage report is present"
    fi
}

test_custom_threshold() {
    test_start "COVERAGE_THRESHOLD override is honoured"
    if ! command -v npm &>/dev/null; then
        test_skip "npm not installed"
        return 0
    fi

    local dir
    dir=$(make_node_project "custom-threshold" 0)
    write_coverage "$dir" "42.5"

    local code=0
    PROJECT_ROOT="$dir" COVERAGE_THRESHOLD=40 "$GATE_SCRIPT" false >/dev/null 2>&1 || code=$?

    if [[ "$code" == "0" ]]; then
        test_pass
    else
        test_fail "Expected exit 0 with COVERAGE_THRESHOLD=40, got $code"
    fi
}

main() {
    echo "Testing Layer 3-4 Integration Gate"
    echo "==================================="
    echo

    test_gate_exists || true
    test_no_toolchain_passes || true
    test_passing_suite || true
    test_failing_suite || true
    test_coverage_below_threshold || true
    test_coverage_above_threshold || true
    test_missing_coverage_not_enforced || true
    test_custom_threshold || true

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
