---
allowed-tools: Bash, Read, Write, Edit, Grep, TodoWrite, AskUserQuestion, Task
argument-hint: "[bug or issue description]"
description: Universal debugging - systematic diagnosis and fix for any bug severity
model: sonnet
---

# Universal Debugging Command

Debug target: $ARGUMENTS

## Argument Validation

Execute validation before any operations:

```bash
# Validate bug description
validate_bug_description() {
  local description="$1"

  # Reject empty input
  if [[ -z "$description" ]]; then
    echo "ERROR: Bug description required"
    echo "Usage: /debug \"description of issue\""
    exit 1
  fi

  # Length validation (5-500 chars)
  if [[ ${#description} -lt 5 || ${#description} -gt 500 ]]; then
    echo "ERROR: Bug description must be 5-500 characters, got: ${#description}"
    exit 1
  fi

  # Reject path traversal
  if [[ "$description" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected in description"
    exit 2
  fi

  # Reject command injection characters
  local injection_pattern='[;`$()&|*?[]{}<>!\n\r]'
  if [[ "$description" =~ $injection_pattern ]]; then
    echo "ERROR: Invalid characters in bug description"
    echo "Allowed: alphanumeric, spaces, punctuation (.,!?:-'\")"
    exit 2
  fi

  # Whitelist validation
  if [[ ! "$description" =~ ^[a-zA-Z0-9\ \.\,\!\?\:\-\'\"]+$ ]]; then
    echo "ERROR: Bug description contains invalid characters"
    echo "Example: \"Login fails with 401 error when session expires\""
    exit 1
  fi
}

# Safe argument parsing
DESCRIPTION="$ARGUMENTS"
validate_bug_description "$DESCRIPTION"
```

If validation fails: exit with error code 1 (user error) or 2 (security error)

## Execution Flow

1. Parse and validate bug description from $ARGUMENTS
2. Execute automated diagnostics (TypeScript, ESLint, build, runtime errors)
3. Identify root cause with systematic investigation
4. Implement fix with appropriate quality standards
5. Verify fix and check for regressions

## Tool Usage

TodoWrite: Required for bug resolution workflow (4-5 tasks)
- Task 1: Automated diagnostics and initial assessment
- Task 2: Root cause identification and analysis
- Task 3: Fix implementation
- Task 4: Verification and regression testing
- Task 5: (Optional) Post-fix cleanup and documentation

AskUserQuestion: Use when bug type unclear or reproduction steps needed

Task (debugger agent): Use for complex systematic debugging

## Automated Diagnostics

Run parallel error detection for fast assessment:

```bash
# Parallel error checks
{
  TS_ERRORS=$(npm run typecheck 2>&1 | grep -c "error" || echo "0") &
  LINT_ERRORS=$(npm run lint 2>&1 | grep -c "error" || echo "0") &
  BUILD_STATUS=$(npm run build 2>&1 | grep -c "failed\|error" || echo "0") &
  RUNTIME_ERRORS=$(grep -r "Error\|Exception" . --include="*.log" 2>/dev/null | wc -l || echo "0") &
  wait
}

echo "Diagnostics:"
echo "  TypeScript errors: $TS_ERRORS"
echo "  ESLint errors: $LINT_ERRORS"
echo "  Build errors: $BUILD_STATUS"
echo "  Runtime errors: $RUNTIME_ERRORS"

# Suggest priority
if [[ $TS_ERRORS -gt 0 ]]; then
  echo "Priority: Fix TypeScript errors first"
elif [[ $BUILD_STATUS -gt 0 ]]; then
  echo "Priority: Fix build errors first"
elif [[ $LINT_ERRORS -gt 0 ]]; then
  echo "Priority: Fix ESLint errors first"
else
  echo "No obvious errors detected, investigate runtime behavior"
fi
```

## Bug Investigation Workflow

When bug scope unclear, use Task (Explore) agent:

```
Task agent: Explore
Purpose: Locate files and components related to [bug description]
Thoroughness: medium
```

For systematic debugging of complex issues:

```
Task agent: debugger
Purpose: Systematic root cause analysis for [bug description]
Analysis: Include error traces, state inspection, data flow analysis
```

## Common Bug Types and Solutions

**TypeScript Errors**:
- Add optional chaining (`?.`) and nullish coalescing (`??`)
- Replace `any` with proper type definitions
- Fix import paths and export statements
- Enable strict mode compliance

**React Errors**:
- Fix useEffect dependency arrays (avoid object dependencies)
- Use functional state updates for transitions
- Add unique keys to list items
- Ensure proper cleanup in useEffect return

**Performance Issues**:
- Fix infinite loops in useEffect
- Add cleanup for subscriptions and timers
- Apply React.memo, useMemo, useCallback appropriately
- Check for accidentally imported large libraries

**API/Network Errors**:
- Verify authentication tokens and headers
- Check error handling and user feedback
- Validate data schemas and transformations
- Test with network throttling

**UI/Rendering Bugs**:
- Check for undefined className or style properties
- Verify CSS conflicts and responsive design
- Test across browsers and screen sizes
- Inspect React DevTools for re-render patterns

## Quality Standards

Apply appropriate quality checks based on fix complexity:

```bash
# TypeScript validation (always required)
npm run typecheck || echo "TypeScript issues remain"

# Build check (always required)
npm run build >/dev/null 2>&1 && echo "Build successful" || echo "Build issues detected"

# Lint check (required for non-emergency fixes)
npm run lint --quiet 2>/dev/null && echo "No lint errors" || echo "Lint errors present"

# Tests (run if available)
npm run test:run --silent 2>/dev/null && echo "Tests passing" || echo "Test issues detected"
```

## Regression Prevention

Check for unintended side effects:

```bash
# Analyze change impact
git diff HEAD~1 --stat | head -5 || echo "No recent changes"

# Test related components
echo "Regression testing checklist:"
echo "1. Test components that use the fixed code"
echo "2. Test similar functionality in other areas"
echo "3. Test error handling scenarios"
echo "4. Verify no new console errors"
```

## Error Handling

Cannot reproduce bug:
- Request environment details (browser, OS, configuration)
- Request specific data or user account
- Request detailed operation steps
- Analyze logs and error history

Fix breaks other functionality:
- Rollback and consider alternative approach
- Minimize impact with incremental fix
- Apply temporary workaround if needed
- Escalate to Task agent for deep analysis

Root cause unclear:
- Perform git log analysis (code archaeology)
- Check dependency changes
- Verify system-level compatibility
- Use Task (debugger) agent for systematic investigation

Never expose:
- Stack traces in user-facing errors
- Absolute file paths
- Internal system details
- Sensitive environment information

## Examples

```
/debug "login fails with 401 error" → Investigate authentication and token handling
/debug "task creation freezes UI" → Check state updates and event handlers
/debug "data not saved to database" → Verify API calls and error handling
/debug "app crashes on mobile Safari" → Browser compatibility investigation
/debug → Interactive mode with AskUserQuestion for bug details
```

## Exit Codes

- 0: Success - Bug fixed and verified
- 1: User error - Invalid description, cannot reproduce
- 2: Security error - Validation failure, permission denied
- 3: System error - Build failure, tool unavailable
- 4: Critical issue - Requires escalation or architectural change
