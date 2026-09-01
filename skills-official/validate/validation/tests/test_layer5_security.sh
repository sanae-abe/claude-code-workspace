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


# The pattern tests above only check the fixtures, not the gate. These run the
# gate itself against a throwaway repository so a scanner that silently returns
# "no findings" (e.g. a missing `timeout` binary) cannot pass unnoticed.
make_git_repo() {
    local name="$1"
    local dir="${TEMP_DIR}/${name}"

    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "test"

    printf '%s\n' "$dir"
}

run_gate() {
    local root="$1"
    local code=0

    PROJECT_ROOT="$root" "$GATE_SCRIPT" false >/dev/null 2>&1 || code=$?
    printf '%s\n' "$code"
}

test_gate_detects_aws_key() {
    test_start "Gate execution flags a committed AWS access key"
    local dir
    dir=$(make_git_repo "leak")
    echo 'const AWS_KEY = "AKIAIOSFODNN7EXAMPLE";' > "$dir/leak.js"
    git -C "$dir" add -A >/dev/null 2>&1

    if [[ "$(run_gate "$dir")" == "1" ]]; then
        test_pass
    else
        test_fail "Gate did not fail on a hardcoded AWS access key"
    fi
}

test_gate_passes_clean_repo() {
    test_start "Gate execution passes a repository with no findings"
    local dir
    dir=$(make_git_repo "clean")
    echo 'export const greeting = "hello";' > "$dir/app.js"
    git -C "$dir" add -A >/dev/null 2>&1

    if [[ "$(run_gate "$dir")" == "0" ]]; then
        test_pass
    else
        test_fail "Gate failed on a repository with no security issues"
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
    test_gate_detects_aws_key || true
    test_gate_passes_clean_repo || true

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
