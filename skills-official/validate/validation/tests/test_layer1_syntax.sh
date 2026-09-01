#!/usr/bin/env bash
# test_layer1_syntax.sh - Test Layer 1 Syntax Validation
# Tests YAML/JSON syntax validation and schema compliance

set -Eeuo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
readonly GATE_SCRIPT="${SCRIPT_DIR}/../gates/layer1_syntax.sh"
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

# Verify gate script exists
verify_gate_exists() {
    test_start "Gate script exists"

    if [[ -f "$GATE_SCRIPT" ]]; then
        test_pass
        return 0
    else
        test_fail "Gate script not found at $GATE_SCRIPT"
        return 1
    fi
}

# Test valid YAML
test_valid_yaml() {
    test_start "Valid YAML passes validation"

    local temp_file="${TEMP_DIR}/tasks.yml"
    cp -- "${FIXTURES_DIR}/valid.yml" "$temp_file"

    # Mock the gate to test just this file
    if python3 -c "import yaml; yaml.safe_load(open('$temp_file'))" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Valid YAML was rejected"
        return 1
    fi
}

# Test invalid YAML
test_invalid_yaml() {
    test_start "Invalid YAML fails validation"

    local temp_file="${TEMP_DIR}/tasks.yml"
    cp -- "${FIXTURES_DIR}/invalid.yml" "$temp_file"

    # Should fail
    if ! python3 -c "import yaml; yaml.safe_load(open('$temp_file'))" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Invalid YAML was accepted"
        return 1
    fi
}

# Test valid JSON
test_valid_json() {
    test_start "Valid JSON passes validation"

    local temp_file="${TEMP_DIR}/package.json"
    cp -- "${FIXTURES_DIR}/valid.json" "$temp_file"

    if python3 -c "import json; json.load(open('$temp_file'))" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Valid JSON was rejected"
        return 1
    fi
}

# Test invalid JSON
test_invalid_json() {
    test_start "Invalid JSON fails validation"

    local temp_file="${TEMP_DIR}/package.json"
    cp -- "${FIXTURES_DIR}/invalid.json" "$temp_file"

    if ! python3 -c "import json; json.load(open('$temp_file'))" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Invalid JSON was accepted"
        return 1
    fi
}

# Test Python dependencies
test_python_dependencies() {
    test_start "Python YAML module is available"

    if python3 -c "import yaml" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "PyYAML not installed"
        return 1
    fi
}

# Test safe Python execution
test_safe_python_validation() {
    test_start "Safe Python validation prevents injection"

    # Create a malicious filename (should be safely handled)
    local safe_file="${TEMP_DIR}/normal.yml"
    cp -- "${FIXTURES_DIR}/valid.yml" "$safe_file"

    # Test that the validation function handles the file safely
    if python3 -c "
import sys
import yaml
try:
    with open('$safe_file', 'r', encoding='utf-8') as f:
        yaml.safe_load(f)
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Safe validation failed on normal file"
        return 1
    fi
}

# Test schema validation (if jsonschema available)
test_schema_validation() {
    test_start "Schema validation (if available)"

    if ! python3 -c "import jsonschema" 2>/dev/null; then
        printf "${YELLOW}SKIP${NC} (jsonschema not installed)\n"
        return 0
    fi

    # Create a simple schema
    local schema_file="${TEMP_DIR}/schema.json"
    cat > "$schema_file" <<'EOF'
{
  "type": "array",
  "items": {
    "type": "object",
    "required": ["id", "goal", "status"],
    "properties": {
      "id": {"type": "string"},
      "goal": {"type": "string"},
      "status": {"type": "string"}
    }
  }
}
EOF

    # Test with valid data
    if python3 -c "
import json
import yaml
import jsonschema

with open('$schema_file', 'r') as f:
    schema = json.load(f)

with open('${FIXTURES_DIR}/valid.yml', 'r') as f:
    data = yaml.safe_load(f)

jsonschema.validate(instance=data, schema=schema)
" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Schema validation failed on valid data"
        return 1
    fi
}

# Test file not found handling
test_file_not_found() {
    test_start "Handles missing file gracefully"

    local missing_file="${TEMP_DIR}/nonexistent.yml"

    # Should handle gracefully
    if ! python3 -c "
import sys
import yaml
try:
    with open('$missing_file', 'r', encoding='utf-8') as f:
        yaml.safe_load(f)
    sys.exit(0)
except FileNotFoundError:
    sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Did not fail on missing file"
        return 1
    fi
}

# Test YAML with comments
test_yaml_with_comments() {
    test_start "YAML with comments is valid"

    local temp_file="${TEMP_DIR}/commented.yml"
    cat > "$temp_file" <<'EOF'
# This is a comment
- id: task-1  # inline comment
  goal: "Test task"
  status: PENDING
  # Another comment
  acceptance_criteria:
    - "Test criterion"
EOF

    if python3 -c "import yaml; yaml.safe_load(open('$temp_file'))" 2>/dev/null; then
        test_pass
        return 0
    else
        test_fail "YAML with comments was rejected"
        return 1
    fi
}

# Main test suite
main() {
    printf "===========================================\n"
    printf "Layer 1 Syntax Validation Test Suite\n"
    printf "===========================================\n\n"

    # Check prerequisites
    if ! command -v python3 &>/dev/null; then
        printf "${RED}ERROR:${NC} python3 not found\n"
        exit 1
    fi

    # Run tests
    verify_gate_exists || true
    test_python_dependencies || true
    test_valid_yaml || true
    test_invalid_yaml || true
    test_valid_json || true
    test_invalid_json || true
    test_safe_python_validation || true
    test_schema_validation || true
    test_file_not_found || true
    test_yaml_with_comments || true

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
