#!/usr/bin/env bash
# Simple test runner
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

readonly SUITES=(
    test_layer1_syntax
    test_layer1_toolchain
    test_layer2_format
    test_layer3_integration
    test_layer5_security
    test_pipeline
)

echo "=========================================="
echo "Running Validation Test Suite"
echo "=========================================="
echo

passed=0
failed=0
declare -a FAILED_SUITES=()

for suite in "${SUITES[@]}"; do
    echo "Running ${suite}..."

    if [[ ! -x "${SCRIPT_DIR}/${suite}.sh" ]]; then
        echo "  ✗ FAILED (missing or not executable)"
        # Counters use arithmetic assignment, not ((x++)): the latter returns a
        # non-zero status when the pre-increment value is 0, which aborts the
        # whole runner under `set -e`.
        failed=$((failed + 1))
        FAILED_SUITES+=("$suite")
        continue
    fi

    if "${SCRIPT_DIR}/${suite}.sh" > /dev/null 2>&1; then
        echo "  ✓ PASSED"
        passed=$((passed + 1))
    else
        echo "  ✗ FAILED"
        failed=$((failed + 1))
        FAILED_SUITES+=("$suite")
    fi
done

echo
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Passed: $passed"
echo "Failed: $failed"

if ((failed > 0)); then
    echo
    echo "Failed suites (re-run individually for details):"
    printf '  - %s.sh\n' "${FAILED_SUITES[@]}"
fi

echo "=========================================="

if ((failed == 0)); then
    echo
    echo "✓ All tests passed!"
    exit 0
fi

echo
echo "✗ Some tests failed"
exit 1
