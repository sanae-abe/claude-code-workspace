#!/usr/bin/env bash
# Simple test runner
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

echo "=========================================="
echo "Running Validation Test Suite"
echo "=========================================="
echo

passed=0
failed=0

# Test 1
echo "Running test_layer1_syntax..."
if "${SCRIPT_DIR}/test_layer1_syntax.sh" > /dev/null 2>&1; then
    echo "  ✓ PASSED"
    ((passed++))
else
    echo "  ✗ FAILED"
    ((failed++))
fi

# Test 2
echo "Running test_layer2_format..."
if "${SCRIPT_DIR}/test_layer2_format.sh" > /dev/null 2>&1; then
    echo "  ✓ PASSED"
    ((passed++))
else
    echo "  ✗ FAILED"
    ((failed++))
fi

# Test 5
echo "Running test_layer5_security..."
if "${SCRIPT_DIR}/test_layer5_security.sh" > /dev/null 2>&1; then
    echo "  ✓ PASSED"
    ((passed++))
else
    echo "  ✗ FAILED"
    ((failed++))
fi

# Test Pipeline
echo "Running test_pipeline..."
if "${SCRIPT_DIR}/test_pipeline.sh" > /dev/null 2>&1; then
    echo "  ✓ PASSED"
    ((passed++))
else
    echo "  ✗ FAILED"
    ((failed++))
fi

echo
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Passed: $passed"
echo "Failed: $failed"
echo "=========================================="

if [[ $failed -eq 0 ]]; then
    echo
    echo "✓ All tests passed!"
    exit 0
else
    echo
    echo "✗ Some tests failed"
    exit 1
fi
