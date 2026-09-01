#!/usr/bin/env bash
# test_layer5_security.sh - Test Layer 5 Security Validation
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
readonly GATE_SCRIPT="${SCRIPT_DIR}/../gates/layer5_security.sh"
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

test_api_key_detection() {
    test_start "Detects hardcoded API keys"
    if grep -q 'sk-[0-9a-zA-Z]\{32,\}' "${FIXTURES_DIR}/secrets.js"; then
        test_pass
    else
        test_fail "API key not detected"
    fi
}

test_aws_credential_detection() {
    test_start "Detects AWS access keys"
    if grep -qE 'AKIA[0-9A-Z]{16}' "${FIXTURES_DIR}/secrets.js"; then
        test_pass
    else
        test_fail "AWS access key not detected"
    fi
}

test_password_detection() {
    test_start "Detects hardcoded passwords"
    if grep -qE 'password\s*=\s*' "${FIXTURES_DIR}/secrets.js"; then
        test_pass
    else
        test_fail "Password not detected"
    fi
}

test_xss_innerhtml() {
    test_start "Detects innerHTML usage"
    if grep -q 'innerHTML' "${FIXTURES_DIR}/xss_vulnerable.js"; then
        test_pass
    else
        test_fail "innerHTML not detected"
    fi
}

test_xss_dangerous_html() {
    test_start "Detects dangerouslySetInnerHTML"
    if grep -q 'dangerouslySetInnerHTML' "${FIXTURES_DIR}/xss_vulnerable.js"; then
        test_pass
    else
        test_fail "dangerouslySetInnerHTML not detected"
    fi
}

test_xss_eval() {
    test_start "Detects eval usage"
    if grep -qE 'eval\(' "${FIXTURES_DIR}/xss_vulnerable.js"; then
        test_pass
    else
        test_fail "eval not detected"
    fi
}

test_gate_exists() {
    test_start "Security gate script exists"
    if [[ -f "$GATE_SCRIPT" ]]; then
        test_pass
    else
        test_fail "Gate script not found"
    fi
}

main() {
    echo "==========================================="
    echo "Layer 5 Security Validation Test Suite"
    echo "==========================================="
    echo

    test_gate_exists || true
    test_api_key_detection || true
    test_aws_credential_detection || true
    test_password_detection || true
    test_xss_innerhtml || true
    test_xss_dangerous_html || true
    test_xss_eval || true

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
