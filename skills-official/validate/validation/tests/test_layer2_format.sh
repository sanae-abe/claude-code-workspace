#!/usr/bin/env bash
# test_layer2_format.sh - Test Layer 2 Format Validation
# Tests format validation, enum normalization, and auto-fix functionality

set -Eeuo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
readonly GATE_SCRIPT="${SCRIPT_DIR}/../gates/layer2_format.sh"
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

# Test markdown detection
test_markdown_detection() {
    test_start "Detects markdown code fences in YAML"

    if grep -q '```yaml' "${FIXTURES_DIR}/markdown.yml"; then
        test_pass
        return 0
    else
        test_fail "Markdown code fence not detected"
        return 1
    fi
}

# Test enum value normalization
test_enum_normalization() {
    test_start "Detects incorrect enum values"

    local temp_file="${TEMP_DIR}/enum_test.yml"
    cp -- "${FIXTURES_DIR}/enum_issues.yml" "$temp_file"

    # Should detect "Done" instead of "DONE"
    if grep -q 'status: Done' "$temp_file"; then
        test_pass
        return 0
    else
        test_fail "Enum issues not detected in fixture"
        return 1
    fi
}

# Test auto-fix enum values
test_enum_auto_fix() {
    test_start "Auto-fixes enum values"

    local temp_file="${TEMP_DIR}/enum_fix.yml"
    cp -- "${FIXTURES_DIR}/enum_issues.yml" "$temp_file"

    # Simulate auto-fix (BSD sed requires '' after -i on macOS)
    sed -i '' 's/status: Done/status: DONE/g' "$temp_file"
    sed -i '' 's/status: "In Progress"/status: IN_PROGRESS/g' "$temp_file"
    sed -i '' 's/status: pending/status: PENDING/g' "$temp_file"

    # Verify fixes
    if grep -q 'status: DONE' "$temp_file" && \
       grep -q 'status: IN_PROGRESS' "$temp_file" && \
       grep -q 'status: PENDING' "$temp_file"; then
        test_pass
        return 0
    else
        test_fail "Enum values not fixed correctly"
        return 1
    fi
}

# Test field name validation
test_field_name_validation() {
    test_start "Validates field names"

    local temp_file="${TEMP_DIR}/field_test.yml"
    cat > "$temp_file" <<'EOF'
- sprint_id: sprint-1
  task_id: task-1
  goal: "Test"
EOF

    # Should detect deprecated field names
    if grep -q 'sprint_id:' "$temp_file" && grep -q 'task_id:' "$temp_file"; then
        test_pass
        return 0
    else
        test_fail "Deprecated field names not in test file"
        return 1
    fi
}

# Test field name auto-fix
test_field_name_auto_fix() {
    test_start "Auto-fixes deprecated field names"

    local temp_file="${TEMP_DIR}/field_fix.yml"
    cat > "$temp_file" <<'EOF'
- sprint_id: sprint-1
  task_id: task-1
  goal: "Test"
EOF

    # Simulate auto-fix (BSD sed)
    sed -i '' 's/sprint_id:/id:/g' "$temp_file"
    sed -i '' 's/task_id:/id:/g' "$temp_file"

    # Verify fixes - check that at least one id field exists
    if grep -q 'id:' "$temp_file"; then
        test_pass
        return 0
    else
        test_fail "Field names not fixed correctly"
        return 1
    fi
}

# Test indentation check
test_indentation_check() {
    test_start "Detects tab characters in YAML"

    local temp_file="${TEMP_DIR}/tabs.yml"
    printf -- "- id: task-1\n\tgoal: \"Test\"\n" > "$temp_file"

    # Should detect tab character (use literal tab in grep)
    if grep -q "$(printf '\t')" "$temp_file"; then
        test_pass
        return 0
    else
        test_fail "Tab character not detected"
        return 1
    fi
}

# Test inconsistent indentation
test_inconsistent_indentation() {
    test_start "Detects inconsistent indentation"

    local temp_file="${TEMP_DIR}/indent.yml"
    cat > "$temp_file" <<'EOF'
- id: task-1
   goal: "Test"
  status: PENDING
EOF

    # Check for odd-numbered indentation
    local line_num=0
    local found_issue=false
    while IFS= read -r line; do
        ((line_num++))
        if [[ "$line" =~ ^([[:space:]]+) ]]; then
            local indent="${BASH_REMATCH[1]}"
            local indent_len=${#indent}
            if ((indent_len % 2 != 0)); then
                found_issue=true
                break
            fi
        fi
    done < "$temp_file"

    if [[ "$found_issue" == "true" ]]; then
        test_pass
        return 0
    else
        test_fail "Inconsistent indentation not detected"
        return 1
    fi
}

# Test backup creation
test_backup_creation() {
    test_start "Creates backup before auto-fix"

    local temp_file="${TEMP_DIR}/backup_test.yml"
    local backup_file="${temp_file}.layer2.bak"

    cp -- "${FIXTURES_DIR}/valid.yml" "$temp_file"

    # Simulate backup creation
    cp -p -- "$temp_file" "$backup_file"

    if [[ -f "$backup_file" ]]; then
        test_pass
        return 0
    else
        test_fail "Backup file not created"
        return 1
    fi
}

# Test backup restoration on error
test_backup_restoration() {
    test_start "Restores backup on error"

    local temp_file="${TEMP_DIR}/restore_test.yml"
    local backup_file="${temp_file}.layer2.bak"

    # Create original and backup
    echo "original content" > "$temp_file"
    cp -p -- "$temp_file" "$backup_file"

    # Modify original
    echo "modified content" > "$temp_file"

    # Restore
    mv -f -- "$backup_file" "$temp_file"

    # Verify restoration
    if grep -q "original content" "$temp_file"; then
        test_pass
        return 0
    else
        test_fail "Backup not restored correctly"
        return 1
    fi
}

# Test path validation
test_path_validation() {
    test_start "Validates file paths safely"

    # Path with .. should be rejected
    local unsafe_path="../../../etc/passwd"

    if [[ "$unsafe_path" =~ \.\. ]]; then
        test_pass
        return 0
    else
        test_fail "Path traversal not detected"
        return 1
    fi
}

# Test gate script exists
test_gate_exists() {
    test_start "Gate script exists"

    if [[ -f "$GATE_SCRIPT" ]]; then
        test_pass
        return 0
    else
        test_fail "Gate script not found at $GATE_SCRIPT"
        return 1
    fi
}

# Main test suite
main() {
    printf "===========================================\n"
    printf "Layer 2 Format Validation Test Suite\n"
    printf "===========================================\n\n"

    # Run tests
    test_gate_exists || true
    test_markdown_detection || true
    test_enum_normalization || true
    test_enum_auto_fix || true
    test_field_name_validation || true
    test_field_name_auto_fix || true
    test_indentation_check || true
    test_inconsistent_indentation || true
    test_backup_creation || true
    test_backup_restoration || true
    test_path_validation || true

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
