---
allowed-tools: Bash, Read, TodoWrite, AskUserQuestion
argument-hint: "[--layers=all|syntax,security] [--auto-fix] [--report=text|json]"
description: Multi-layer quality gate validation with auto-fix support
model: sonnet
---

# validate

Arguments: $ARGUMENTS

## Argument Validation

Execute validation before any operations (already implemented in Security Implementation section):

1. Parse $ARGUMENTS safely with IFS to avoid command injection
2. Validate --layers values (allowed: all, syntax, security, integration)
3. Validate --auto-fix values (allowed: true, false, or flag presence)
4. Validate --report values (allowed: text, json)

All validation functions are implemented in the Security Implementation section below.

**Validation functions**:
- `validate_layers()`: Whitelist validation for layer names
- `validate_auto_fix()`: Boolean value validation
- `validate_report_format()`: Report format whitelist validation

If validation fails: exit with error code 1 (user error) or 2 (security error) and display allowed values

## Execution Flow

1. Parse arguments (layers, auto-fix, report format)
2. Run quality gate pipeline: `~/projects/claude-code-workspace/validation/pipeline.sh`
3. Parse validation report
4. Display results to user
5. If failures: show actionable suggestions
6. If auto-fix enabled: show what was fixed

## Implementation

```bash
# Parse arguments with safe handling
LAYERS="all"
AUTO_FIX="false"
REPORT_FORMAT="text"

# Split $ARGUMENTS into array safely
IFS=' ' read -r -a args <<< "$ARGUMENTS"

for arg in "${args[@]}"; do
    case "$arg" in
        --layers=*)
            LAYERS="${arg#*=}"
            ;;
        --auto-fix)
            AUTO_FIX="true"
            ;;
        --report=*)
            REPORT_FORMAT="${arg#*=}"
            ;;
        *)
            echo "⚠️  Unknown argument: $arg (ignoring)"
            ;;
    esac
done

# SECURITY: Validate inputs (see Security Implementation section)
validate_layers "$LAYERS"
validate_auto_fix "$AUTO_FIX"
validate_report_format "$REPORT_FORMAT"

# SECURITY: Resolve paths safely (see Security Implementation section)
resolve_paths
# This sets: WORKSPACE_ROOT, PIPELINE_PATH, REPORT_GENERATOR

# SECURITY: Create secure temp file and verify python3 (see Security Implementation section)
create_secure_temp
check_python3
# This sets: REPORT_FILE with auto-cleanup trap

# Run quality gate pipeline
echo "🔍 Running quality gate validation..."
echo "   Layers: $LAYERS"
echo "   Auto-fix: $AUTO_FIX"
echo ""

if bash "$PIPELINE_PATH" --layers="$LAYERS" --auto-fix="$AUTO_FIX" --stop-on-failure=true; then
    VALIDATION_RESULT=0
else
    VALIDATION_RESULT=$?
fi

# Display report
if [[ -f "$REPORT_FILE" ]]; then
    if [[ "$REPORT_FORMAT" == "json" ]]; then
        python3 "$REPORT_GENERATOR" "$REPORT_FILE" --format=json
    else
        python3 "$REPORT_GENERATOR" "$REPORT_FILE"
    fi
else
    echo "⚠️  Report generation failed: Report file not found"
fi

# Temp file cleanup handled automatically by trap
exit $VALIDATION_RESULT
```

## Output Format

Use this structure with emojis for clarity:

```
❌/✅ Quality Gate Report
════════════════════════════════════════
❌/✅ Layer N: Name - FAILED/PASSED
  Errors: (if failed)
    file:line - description
  Suggestions: (if fixable)
    Run with --auto-fix: /validate --auto-fix
    Or manually fix the reported issues
════════════════════════════════════════
Total Gates: X | Passed: Y | Failed: Z

💡 Fix errors and re-run validation
```

- Show errors with file:line references
- Suggest --auto-fix for fixable errors
- Display summary counts

## Security Implementation

**MANDATORY: Execute these validations BEFORE ANY pipeline execution**

```bash
# 1. Validate layers argument
validate_layers() {
  local layers="$1"
  IFS=',' read -ra layer_array <<< "$layers"

  for layer in "${layer_array[@]}"; do
    case "$layer" in
      all|syntax|security|integration) ;;
      *)
        echo "ERROR: Invalid layer '$layer'"
        echo "Allowed: all, syntax, security, integration (comma-separated)"
        exit 1
        ;;
    esac
  done
}

# 2. Validate auto-fix argument
validate_auto_fix() {
  local auto_fix="$1"
  if [[ "$auto_fix" != "true" && "$auto_fix" != "false" ]]; then
    echo "ERROR: Invalid auto-fix value '$auto_fix'"
    echo "Allowed: true or false"
    exit 1
  fi
}

# 3. Validate report format
validate_report_format() {
  local format="$1"
  case "$format" in
    text|json) ;;
    *)
      echo "ERROR: Invalid report format '$format'"
      echo "Allowed: text, json"
      echo "Example: /validate --report=json"
      exit 2
      ;;
  esac
}

# 4. Resolve paths safely
resolve_paths() {
  WORKSPACE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -z "$WORKSPACE_ROOT" ]]; then
    if [[ -d "$HOME/.claude/validation" ]]; then
      WORKSPACE_ROOT="$HOME/.claude"
    else
      echo "ERROR: Not in git repo and ~/.claude/validation not found"
      exit 1
    fi
  fi

  PIPELINE_PATH="${WORKSPACE_ROOT}/validation/pipeline.sh"
  REPORT_GENERATOR="${WORKSPACE_ROOT}/validation/utils/report-generator.py"

  # Verify pipeline.sh is not a symlink (prevent arbitrary script execution)
  if [[ -L "$PIPELINE_PATH" ]]; then
    echo "ERROR: Pipeline is a symbolic link (security risk)"
    echo "Use real file: validation/pipeline.sh"
    exit 3
  fi

  if [[ ! -x "$PIPELINE_PATH" ]]; then
    echo "ERROR: Pipeline not found or not executable: validation/pipeline.sh"
    exit 1
  fi

  # Verify report-generator.py is not a symlink
  if [[ -L "$REPORT_GENERATOR" ]]; then
    echo "ERROR: Report generator is a symbolic link (security risk)"
    echo "Use real file: validation/utils/report-generator.py"
    exit 3
  fi

  if [[ ! -f "$REPORT_GENERATOR" ]]; then
    echo "ERROR: Report generator not found: validation/utils/report-generator.py"
    exit 1
  fi
}

# 5. Create secure temp file
create_secure_temp() {
  # Use system default secure location (not /tmp)
  REPORT_FILE=$(mktemp)
  trap "rm -f '$REPORT_FILE'" EXIT
}

# 6. Verify python3 availability
check_python3() {
  if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found. Please install Python 3.6+"
    exit 1
  fi
}
```

**Execution order**:
1. validate_layers "$LAYERS"
2. validate_auto_fix "$AUTO_FIX"
3. validate_report_format "$REPORT_FORMAT"
4. resolve_paths
5. create_secure_temp
6. check_python3
7. Execute pipeline.sh with validated arguments

## Error Handling

### Invalid Arguments

```bash
# Invalid layer
ERROR: Invalid layer 'invalid'
Allowed: all, syntax, security, integration (comma-separated)
Example: /validate --layers=syntax,security

# Invalid auto-fix value (if --auto-fix=value is used)
ERROR: Invalid auto-fix value 'maybe'
Allowed: true or false
Example: /validate --auto-fix

# Invalid report format
ERROR: Invalid report format 'xml'
Allowed: text, json
Example: /validate --report=json
```

### Missing Dependencies

```bash
# Pipeline not found
ERROR: Pipeline not found or not executable: validation/pipeline.sh
Resolution:
  - Verify ~/projects/claude-code-workspace/validation/pipeline.sh exists
  - Check file permissions: chmod +x validation/pipeline.sh
  - Verify you're in correct directory: git rev-parse --show-toplevel

# Pipeline is symbolic link (security risk)
ERROR: Pipeline is a symbolic link (security risk)
Use real file: validation/pipeline.sh
Resolution:
  - Replace symlink with actual file
  - Security policy: symlinks not allowed for executable scripts

# Report generator not found
ERROR: Report generator not found: validation/utils/report-generator.py
Resolution:
  - Verify validation/utils/report-generator.py exists
  - Check Python 3.6+ installation: python3 --version
  - Verify file permissions

# Python 3 not found
ERROR: python3 not found. Please install Python 3.6+
Resolution:
  - macOS: brew install python3
  - Ubuntu: sudo apt install python3
  - Verify: python3 --version
```

### Git Repository Detection

```bash
# Not in git repo and fallback failed
ERROR: Not in git repo and ~/.claude/validation not found
Resolution:
  - Run from git repository root: cd $(git rev-parse --show-toplevel)
  - Or ensure ~/.claude/validation directory exists:
    mkdir -p ~/.claude/validation
    # Copy validation pipeline to ~/.claude/validation/
  - Verify: git rev-parse --show-toplevel
```

### Security Guidelines

**Error message safety**:
- Never expose absolute paths in error messages (use relative paths from project root)
- Never expose stack traces or internal details
- Report only user-actionable information
- Sanitize all user input before displaying

**Exit codes**:
- 0: All quality gates passed
- 1: Validation failed (quality gate errors)
- 2: Invalid arguments (validation error)
- 3: Security error (symlink detected, permission issue)
- 4: Missing dependencies (pipeline.sh, report-generator.py, python3)
- 5: Git repository detection failed

## Performance Notes

- Early exit on failures (--stop-on-failure=true)

## External References

**Required dependencies**:
- Bash 4.0+: Array support (`IFS=' ' read -r -a`)
- Git: Repository detection (`git rev-parse`)
- Python 3.6+: Report generation
- Execute permissions: `chmod +x validation/pipeline.sh`

**External scripts**:
- Pipeline: `~/projects/claude-code-workspace/validation/pipeline.sh` (15KB)
  - Purpose: Execute quality gate layers
  - Layers: syntax, security, integration
  - Auto-fix: TypeScript, ESLint, Prettier

- Report generator: `~/projects/claude-code-workspace/validation/utils/report-generator.py` (12KB)
  - Purpose: Format validation results
  - Output formats: text (default), json
  - Language: Python 3.6+

**Installation**:
```bash
# Verify dependencies
git --version  # Git 2.0+
python3 --version  # Python 3.6+
bash --version  # Bash 4.0+

# Ensure pipeline exists
ls ~/projects/claude-code-workspace/validation/pipeline.sh

# Make executable (if needed)
chmod +x ~/projects/claude-code-workspace/validation/pipeline.sh
chmod +x ~/projects/claude-code-workspace/validation/utils/report-generator.py
```

**Related workflows**:
- `/review-pr` - PR/MR review with quality checks
- `code-reviewer` agent - Code quality and best practices
- `security-auditor` agent - Security-focused audit

**Quality gate layers**:
- Layer 1-2 (syntax): `~/.claude/validation/layers/syntax.md`
- Layer 3-4 (integration): `~/.claude/validation/layers/integration.md`
- Layer 5 (security): `~/.claude/validation/layers/security.md`

## Layer Details

### Layer 1-2: Syntax

**Checks**:
- TypeScript: `npm run typecheck` - Type safety validation
- ESLint: `npm run lint` - Code quality linting
- Prettier: Code formatting consistency
- Import organization

**Auto-fix capable**:
- ✅ ESLint errors (where applicable)
- ✅ Prettier formatting
- ✅ Import organization
- ❌ TypeScript type errors (manual fix required)

**Typical execution time**: 3-5 seconds

**Use cases**:
- Pre-commit quick check
- Fast feedback during development
- Syntax error detection before full validation

### Layer 3-4: Integration

**Checks**:
- Test execution: `npm run test:run`
- Test coverage: 80% threshold validation
- API type checking: Contract validation between frontend/backend
- Integration tests: Multi-component interaction tests

**Auto-fix capable**:
- ❌ All checks require manual fix
- Test failures indicate logic errors
- Coverage issues require new tests

**Typical execution time**: 10-30 seconds (depends on test suite size)

**Use cases**:
- Pre-PR validation
- Full feature verification
- Regression testing

### Layer 5: Security

**Checks**:
- Hardcoded secrets: `.env`, `credentials.*`, API keys, tokens
- OWASP Top 10 compliance: XSS, injection, authentication issues
- Dependency vulnerabilities: `npm audit` for known CVEs
- Authentication/authorization patterns: Permission check validation
- Sensitive file detection: `.env*`, `*.pem`, `*.key`

**Auto-fix capable**:
- ❌ All security issues require manual review and fix
- Security violations need human judgment
- Automated fixes could introduce new vulnerabilities

**Typical execution time**: 5-10 seconds

**Use cases**:
- Pre-commit security audit
- PR security review
- Compliance verification

### Combined (--layers=all)

**Total execution time**: 18-45 seconds
**Early exit**: Stops at first failure (--stop-on-failure=true)
**Layer sequence**: syntax → security → integration (fail-fast order)

**Performance optimization**:
- Use `--layers=syntax` for fastest feedback (3-5s, 70-80% time saving)
- Use `--layers=syntax,security` for security-focused development (8-15s, 50-60% time saving)
- Use `--layers=all` for comprehensive validation before PR (18-45s)

## Examples

### Basic usage

```bash
# All layers (default)
/validate

# Output:
# 🔍 Running quality gate validation...
#    Layers: all
#    Auto-fix: false
#
# ✅ Quality Gate Report
# ════════════════════════════════════════
# ✅ Layer 1-2: Syntax - PASSED
# ✅ Layer 3-4: Integration - PASSED
# ✅ Layer 5: Security - PASSED
# ════════════════════════════════════════
# Total Gates: 3 | Passed: 3 | Failed: 0
```

### Security-focused validation

```bash
# Security layer only (fast security audit)
/validate --layers=security

# Output:
# 🔍 Running quality gate validation...
#    Layers: security
#    Auto-fix: false
#
# ✅ Quality Gate Report
# ════════════════════════════════════════
# ✅ Layer 5: Security - PASSED
#   Checks completed:
#     - Hardcoded secrets: 0 found
#     - OWASP compliance: OK
#     - Dependency vulnerabilities: 0 critical
# ════════════════════════════════════════
# Total Gates: 1 | Passed: 1 | Failed: 0
#
# 💡 Security validation completed in 7s
```

### Auto-fix mode

```bash
# Auto-fix syntax issues
/validate --layers=syntax --auto-fix

# Output:
# 🔍 Running quality gate validation...
#    Layers: syntax
#    Auto-fix: true
#
# ✅ Quality Gate Report
# ════════════════════════════════════════
# ✅ Layer 1-2: Syntax - PASSED (auto-fixed 5 issues)
#   Auto-fixed:
#     - ESLint errors: 3 (import/order, no-unused-vars)
#     - Prettier formatting: 2 files reformatted
#   Manual fixes required:
#     - TypeScript errors: 0
# ════════════════════════════════════════
# Total Gates: 1 | Passed: 1 | Failed: 0
#
# 💡 5 issues automatically fixed
#    Run tests to verify: npm run test
```

### CI/CD integration

```bash
# JSON output for CI/CD parsing
/validate --layers=all --report=json

# Output (JSON format):
# {
#   "total_gates": 3,
#   "passed": 2,
#   "failed": 1,
#   "layers": [
#     {"name": "syntax", "status": "passed", "errors": 0},
#     {"name": "security", "status": "passed", "errors": 0},
#     {"name": "integration", "status": "failed", "errors": 3}
#   ],
#   "errors": [
#     {
#       "layer": "integration",
#       "file": "src/utils/api.test.ts",
#       "line": 45,
#       "message": "Test failed: API timeout"
#     }
#   ]
# }
#
# Use in CI/CD:
# - GitHub Actions: jq '.failed' to check failures
# - GitLab CI: upload JSON as artifact for analysis
# - Jenkins: parse JSON, fail build if failed > 0
```

### Multiple layers (incremental validation)

```bash
# Syntax + Security only (skip slow integration tests)
/validate --layers=syntax,security --auto-fix

# Use case:
# - Pre-commit quick check (8-15s vs 18-45s for --layers=all)
# - Focus on code quality + security
# - Skip time-consuming integration tests
#
# Output:
# 🔍 Running quality gate validation...
#    Layers: syntax,security
#    Auto-fix: true
#
# ✅ Quality Gate Report
# ════════════════════════════════════════
# ✅ Layer 1-2: Syntax - PASSED (auto-fixed 2 issues)
# ✅ Layer 5: Security - PASSED
# ════════════════════════════════════════
# Total Gates: 2 | Passed: 2 | Failed: 0
#
# 💡 Fast validation completed in 12s (60% faster than --layers=all)
```
