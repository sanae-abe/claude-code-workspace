---
name: validate
description: Multi-layer quality gate validation with auto-fix support. Use after implementation to check syntax, security, and integration quality.
argument-hint: "[--layers=all|syntax,security] [--auto-fix] [--report=text|json]"
allowed-tools: Bash Read AskUserQuestion
model: sonnet
---

# validate

Arguments: $ARGUMENTS

## Execution Flow

1. Parse and validate arguments (layers, auto-fix, report format)
2. Define security functions (see Security Functions section below)
3. Resolve pipeline paths via `${CLAUDE_SKILL_DIR}`
4. Run quality gate pipeline with sanitized arguments
5. Parse and display validation report
6. If failures: show actionable suggestions with file:line references

## Security Functions

Define these functions FIRST, before executing the Implementation section:

```bash
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

validate_auto_fix() {
  local auto_fix="$1"
  if [[ "$auto_fix" != "true" && "$auto_fix" != "false" ]]; then
    echo "ERROR: Invalid auto-fix value '$auto_fix'"
    echo "Allowed: true or false"
    exit 1
  fi
}

validate_report_format() {
  local format="$1"
  case "$format" in
    text|json) ;;
    *)
      echo "ERROR: Invalid report format '$format'"
      echo "Allowed: text, json"
      exit 2
      ;;
  esac
}

resolve_paths() {
  local SKILL_DIR="${CLAUDE_SKILL_DIR:-$HOME/.claude/skills/validate}"
  local VALIDATION_DIR="${SKILL_DIR}/validation"

  if [[ ! -d "$VALIDATION_DIR" ]]; then
    echo "ERROR: Validation directory not found"
    echo "Expected: ~/.claude/skills/validate/validation/"
    exit 1
  fi

  PIPELINE_PATH="${VALIDATION_DIR}/pipeline.sh"
  REPORT_GENERATOR="${VALIDATION_DIR}/utils/report-generator.py"

  if [[ -L "$PIPELINE_PATH" ]]; then
    echo "ERROR: Pipeline is a symbolic link (security risk)"
    exit 3
  fi

  if [[ ! -x "$PIPELINE_PATH" ]]; then
    echo "ERROR: Pipeline not found or not executable: validation/pipeline.sh"
    echo "Resolution: chmod +x ~/.claude/skills/validate/validation/pipeline.sh"
    exit 1
  fi

  if [[ -L "$REPORT_GENERATOR" ]]; then
    echo "ERROR: Report generator is a symbolic link (security risk)"
    exit 3
  fi

  if [[ ! -f "$REPORT_GENERATOR" ]]; then
    echo "ERROR: Report generator not found: validation/utils/report-generator.py"
    exit 1
  fi
}

create_secure_temp() {
  REPORT_FILE=$(mktemp)
  chmod 600 "$REPORT_FILE"
  trap "rm -f '$REPORT_FILE'" EXIT
}

check_python3() {
  if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found. Please install Python 3+"
    exit 1
  fi
}
```

## Implementation

After defining the functions above, execute:

```bash
LAYERS="all"
AUTO_FIX="false"
REPORT_FORMAT="text"

IFS=' ' read -r -a args <<< "$ARGUMENTS"

for arg in "${args[@]}"; do
    case "$arg" in
        --layers=*)  LAYERS="${arg#*=}" ;;
        --auto-fix)  AUTO_FIX="true" ;;
        --report=*)  REPORT_FORMAT="${arg#*=}" ;;
        *)           echo "Unknown argument: $arg (ignoring)" ;;
    esac
done

validate_layers "$LAYERS"
validate_auto_fix "$AUTO_FIX"
validate_report_format "$REPORT_FORMAT"

resolve_paths
create_secure_temp
check_python3

echo "Running quality gate validation..."
echo "   Layers: $LAYERS"
echo "   Auto-fix: $AUTO_FIX"
echo ""

if bash "$PIPELINE_PATH" --layers="$LAYERS" --auto-fix="$AUTO_FIX" --stop-on-failure=true; then
    VALIDATION_RESULT=0
else
    VALIDATION_RESULT=$?
fi

if [[ -f "$REPORT_FILE" ]]; then
    if [[ "$REPORT_FORMAT" == "json" ]]; then
        python3 "$REPORT_GENERATOR" "$REPORT_FILE" --format=json
    else
        python3 "$REPORT_GENERATOR" "$REPORT_FILE"
    fi
else
    echo "Warning: Report file not found, report generation skipped"
fi

exit $VALIDATION_RESULT
```

## Output Format

```
❌/✅ Quality Gate Report
════════════════════════════════════════
❌/✅ Layer N: Name - FAILED/PASSED
  Errors: (if failed)
    file:line - description
  Suggestions: (if fixable)
    Run with --auto-fix: /validate --auto-fix
════════════════════════════════════════
Total Gates: X | Passed: Y | Failed: Z

💡 Fix errors and re-run validation
```

- Show errors with file:line references
- Suggest --auto-fix for fixable errors
- Display summary counts

## Error Handling

### Exit Codes

- 0: All quality gates passed
- 1: Quality gate failures or invalid arguments
- 2: Invalid report format argument
- 3: Security error (symlink detected)

### Common Errors

```
ERROR: Invalid layer 'invalid'
Allowed: all, syntax, security, integration (comma-separated)

ERROR: Pipeline not found or not executable: validation/pipeline.sh
Resolution: chmod +x ~/.claude/skills/validate/validation/pipeline.sh

ERROR: python3 not found. Please install Python 3+
Resolution: brew install python3 (macOS) or apt install python3 (Ubuntu)

ERROR: Pipeline is a symbolic link (security risk)
Resolution: Replace symlink with actual file
```

### Security Guidelines

- Never expose absolute paths in error messages
- Never expose stack traces or internal details
- Sanitize all user input before displaying

## Layer Details

### Layer 1-2: Syntax (3-5s)

- TypeScript: `npm run typecheck`
- ESLint: `npm run lint`
- Prettier: formatting consistency

Auto-fixable: ESLint errors, Prettier formatting
Not auto-fixable: TypeScript type errors

### Layer 3-4: Integration (10-30s)

- Test execution: `npm run test:run`
- Test coverage: 80% threshold
- API type checking

Not auto-fixable (requires manual fix or new tests)

### Layer 5: Security (5-10s)

- Hardcoded secrets (`.env`, API keys, tokens)
- OWASP Top 10 compliance
- Dependency vulnerabilities: `npm audit`
- Sensitive file detection (`.env*`, `*.pem`, `*.key`)

Not auto-fixable (requires human judgment)

### Performance Guide

| Use case | Command | Time |
|----------|---------|------|
| Fast feedback during dev | `--layers=syntax` | 3-5s |
| Pre-commit check | `--layers=syntax,security` | 8-15s |
| Pre-PR full validation | `--layers=all` | 18-45s |

## Examples

```bash
# Syntax check with auto-fix (most common dev workflow)
/validate --layers=syntax --auto-fix

# Security audit only
/validate --layers=security

# Full validation before PR
/validate --layers=all

# CI/CD with JSON output
/validate --layers=all --report=json
```

## Pipeline Reference

**Location**: `~/.claude/skills/validate/validation/`

```
validation/
├── pipeline.sh              # Main pipeline
├── gates/
│   ├── layer1_syntax.sh
│   ├── layer2_format.sh
│   └── layer5_security.sh
├── fixers/
│   ├── enum_normalizer.py
│   ├── markdown_stripper.py
│   └── yaml_fixer.py
├── patterns/
│   └── security-patterns.json
└── utils/
    └── report-generator.py
```

**Direct pipeline execution** (for debugging):
```bash
cd ~/.claude/skills/validate/validation
./pipeline.sh --layers=all --auto-fix=true --stop-on-failure=true
```
