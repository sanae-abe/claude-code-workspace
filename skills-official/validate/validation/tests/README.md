# Validation Test Suite

Comprehensive test suite for the validation system with fixtures and test scripts.

## Structure

```
validation/tests/
├── fixtures/              # Test fixtures for all test suites
│   ├── valid.yml         # Valid YAML file
│   ├── invalid.yml       # Invalid YAML (syntax error)
│   ├── markdown.yml      # YAML with markdown code fences
│   ├── enum_issues.yml   # YAML with incorrect enum values
│   ├── valid.json        # Valid JSON file
│   ├── invalid.json      # Invalid JSON (syntax error)
│   ├── secrets.js        # Test file with hardcoded credentials
│   └── xss_vulnerable.js # Test file with XSS vulnerabilities
├── test_layer1_syntax.sh     # Layer 1: Syntax validation tests
├── test_layer2_format.sh     # Layer 2: Format validation tests
├── test_layer5_security.sh   # Layer 5: Security validation tests
├── test_pipeline.sh          # Pipeline orchestration tests
└── run_all_tests.sh          # Master test runner
```

## Running Tests

### Run all tests
```bash
cd validation/tests
./run_all_tests.sh
```

### Run with verbose output
```bash
./run_all_tests.sh --verbose
```

### Run individual test suites
```bash
# Layer 1: Syntax validation
./test_layer1_syntax.sh

# Layer 2: Format validation
./test_layer2_format.sh

# Layer 5: Security validation
./test_layer5_security.sh

# Pipeline orchestration
./test_pipeline.sh
```

## Test Coverage

### Layer 1: Syntax Validation (test_layer1_syntax.sh)
- ✓ Gate script exists
- ✓ Python YAML module availability
- ✓ Valid YAML passes validation
- ✓ Invalid YAML fails validation
- ✓ Valid JSON passes validation
- ✓ Invalid JSON fails validation
- ✓ Safe Python validation (injection prevention)
- ✓ Schema validation (if jsonschema available)
- ✓ Missing file handling
- ✓ YAML with comments

### Layer 2: Format Validation (test_layer2_format.sh)
- ✓ Gate script exists
- ✓ Markdown code fence detection
- ✓ Enum value validation
- ✓ Enum value auto-fix
- ✓ Field name validation
- ✓ Field name auto-fix
- ✓ Tab character detection
- ✓ Inconsistent indentation detection
- ✓ Backup creation
- ✓ Backup restoration on error
- ✓ Path validation (traversal prevention)

### Layer 5: Security Validation (test_layer5_security.sh)
- ✓ Gate script exists
- ✓ API key detection (hardcoded secrets)
- ✓ AWS credential detection
- ✓ Password detection
- ✓ XSS: innerHTML usage
- ✓ XSS: dangerouslySetInnerHTML
- ✓ XSS: eval() usage
- ✓ SQL injection patterns
- ✓ Command injection patterns
- ✓ Path traversal vulnerabilities
- ✓ Weak cryptography (MD5)
- ✓ CORS misconfiguration (wildcard)
- ✓ JWT secret detection
- ✓ Safe grep timeout protection
- ✓ Sensitive file detection
- ✓ Pattern extraction from JSON
- ✓ Git grep safety (excludes)

### Pipeline Orchestration (test_pipeline.sh)
- ✓ Pipeline script exists
- ✓ Help flag (--help)
- ✓ Layer selection (--layers=syntax)
- ✓ Layer selection (--layers=all)
- ✓ Multiple layer selection (--layers=syntax,security)
- ✓ Auto-fix flag (--auto-fix=true)
- ✓ Stop-on-failure flag (--stop-on-failure=true)
- ✓ Invalid layer name rejection
- ✓ Exit code 0 on success
- ✓ Exit code 1 on failure
- ✓ JSON report generation
- ✓ Report summary section
- ✓ Parallel execution detection
- ✓ Boolean argument validation
- ✓ Invalid boolean rejection

## Prerequisites

### Required
- `bash` 4.4+ (or 5.x for modern features)
- `python3` with `pyyaml` module
- `jq` for JSON processing
- `git` (for security tests)

### Optional
- `jsonschema` Python module (for schema validation tests)

### Installation

**macOS:**
```bash
brew install jq
pip3 install pyyaml jsonschema
```

**Debian/Ubuntu:**
```bash
apt-get install jq python3-yaml
pip3 install jsonschema
```

## Test Output

Each test suite provides:
- **PASS/FAIL** status for each test
- **Colored output** for better readability
- **Summary** with counts (run/passed/failed)
- **Exit code** 0 for success, 1 for failure

### Example Output
```
===========================================
Layer 1 Syntax Validation Test Suite
===========================================

[TEST] Gate script exists ... PASS
[TEST] Valid YAML passes validation ... PASS
[TEST] Invalid YAML fails validation ... PASS

===========================================
Test Summary
===========================================
Tests run:    10
Tests passed: 9
Tests failed: 0
===========================================

✓ All tests passed!
```

## Fixtures

### YAML Fixtures
- `valid.yml` - Properly formatted YAML with tasks
- `invalid.yml` - YAML with syntax errors
- `markdown.yml` - YAML wrapped in markdown code fences
- `enum_issues.yml` - YAML with incorrect enum values (Done, pending, etc.)

### JSON Fixtures
- `valid.json` - Valid package.json structure
- `invalid.json` - JSON with missing closing brace

### Security Fixtures
- `secrets.js` - Contains hardcoded API keys, AWS credentials, passwords
- `xss_vulnerable.js` - Contains XSS vulnerabilities (innerHTML, eval, etc.)

## Writing New Tests

### Test Structure
```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
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

# Test helper functions
test_start() {
    local test_name="$1"
    ((TESTS_RUN++))
    printf "[TEST] %s ... " "$test_name"
}

test_pass() {
    ((TESTS_PASSED++))
    printf "PASS\n"
}

test_fail() {
    local reason="${1:-unknown reason}"
    ((TESTS_FAILED++))
    printf "FAIL\n"
    printf "  Reason: %s\n" "$reason"
}

# Write your tests here
test_example() {
    test_start "Example test"

    if [[ -f "$FIXTURES_DIR/valid.yml" ]]; then
        test_pass
        return 0
    else
        test_fail "Fixture not found"
        return 1
    fi
}

# Main test suite
main() {
    printf "===========================================\n"
    printf "My Test Suite\n"
    printf "===========================================\n\n"

    test_example || true

    # Summary
    printf "\n===========================================\n"
    printf "Test Summary\n"
    printf "===========================================\n"
    printf "Tests run:    %d\n" "$TESTS_RUN"
    printf "Tests passed: %d\n" "$TESTS_PASSED"
    printf "Tests failed: %d\n" "$TESTS_FAILED"
    printf "===========================================\n"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "\nAll tests passed!\n"
        exit 0
    else
        printf "\nSome tests failed!\n"
        exit 1
    fi
}

main "$@"
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Validation Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq python3-yaml
          pip3 install jsonschema
      - name: Run tests
        run: |
          cd validation/tests
          ./run_all_tests.sh
```

## Maintenance

### Adding New Tests
1. Create fixture files in `fixtures/` if needed
2. Add test functions to appropriate test suite
3. Update this README with test coverage
4. Run `./run_all_tests.sh` to verify

### Updating Fixtures
- Keep fixtures minimal but representative
- Document any special cases
- Test both valid and invalid cases

## Troubleshooting

### Common Issues

**Issue:** `python3: command not found`
- **Solution:** Install Python 3: `brew install python3` or `apt-get install python3`

**Issue:** `No module named 'yaml'`
- **Solution:** Install PyYAML: `pip3 install pyyaml`

**Issue:** `jq: command not found`
- **Solution:** Install jq: `brew install jq` or `apt-get install jq`

**Issue:** Tests fail on macOS with sed errors
- **Solution:** Tests use BSD-compatible sed syntax (`sed -i ''`)

**Issue:** Permission denied
- **Solution:** Make scripts executable: `chmod +x test_*.sh run_all_tests.sh`

## References

- Main validation system: `../pipeline.sh`
- Layer 1 gate: `../gates/layer1_syntax.sh`
- Layer 2 gate: `../gates/layer2_format.sh`
- Layer 5 gate: `../gates/layer5_security.sh`
- Security patterns: `~/.claude/validation/patterns/security-patterns.json`
