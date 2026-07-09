---
description: Universal debugging - systematic diagnosis and fix for any bug severity. Use when asked to fix a bug, investigate an error, or debug unexpected behavior.
argument-hint: "[bug or issue description]"
model: sonnet
---

# Universal Debugging Command

Debug target: $ARGUMENTS

## Argument Validation

Validate before any operations (LLM judgment, not shell execution):

- Empty input: Use AskUserQuestion to ask for bug description
- Contains `..`: Report "ERROR: Path traversal detected" and stop
- Less than 3 characters: Ask for more details
- Accept any language (Japanese, English, etc.) and punctuation

## Execution Flow

1. Parse and validate bug description from $ARGUMENTS
2. Auto-detect tech stack, then run automated diagnostics
3. Identify root cause with systematic investigation
4. Implement fix with appropriate quality standards
5. Verify fix and check for regressions

## Tool Usage

TaskCreate: Required for bug resolution workflow (4-5 tasks)
- Task 1: Automated diagnostics and initial assessment
- Task 2: Root cause identification and analysis
- Task 3: Fix implementation
- Task 4: Verification and regression testing
- Task 5: (Optional) Post-fix cleanup and documentation

Mark each task in_progress before starting, completed immediately after finishing.

AskUserQuestion: Use when bug type unclear or reproduction steps needed

Task (debugger agent): Use for complex systematic debugging

## Tech Stack Detection

Before running diagnostics, detect project type by checking these files in order:

1. `package.json` → Node.js/TypeScript
2. `Cargo.toml` → Rust
3. `go.mod` → Go
4. `pyproject.toml` or `requirements.txt` → Python
5. `Gemfile` → Ruby
6. `composer.json` → PHP

## Automated Diagnostics

Run parallel error detection based on detected tech stack:

**Node.js/TypeScript** (package.json detected):
```bash
# Run these in parallel
TS_ERRORS=$(npm run typecheck 2>&1 | grep -c "error" || echo "0") &
LINT_ERRORS=$(npm run lint 2>&1 | grep -c "error" || echo "0") &
BUILD_STATUS=$(npm run build 2>&1 | grep -c "failed\|error" || echo "0") &
wait

echo "TypeScript errors: $TS_ERRORS"
echo "ESLint errors: $LINT_ERRORS"
echo "Build errors: $BUILD_STATUS"
```

**Rust** (Cargo.toml detected):
```bash
COMPILE_ERRORS=$(cargo check 2>&1 | grep -c "^error" || echo "0") &
CLIPPY_WARNINGS=$(cargo clippy 2>&1 | grep -c "^error\|^warning" || echo "0") &
wait

echo "Compile errors: $COMPILE_ERRORS"
echo "Clippy warnings: $CLIPPY_WARNINGS"
```

**Python** (pyproject.toml/requirements.txt detected):
```bash
TYPE_ERRORS=$(mypy . 2>&1 | grep -c "error:" || echo "0") &
LINT_ERRORS=$(ruff check . 2>&1 | grep -c "error" || echo "0") &
TEST_FAILURES=$(pytest --tb=no -q 2>&1 | grep -c "FAILED" || echo "0") &
wait

echo "Type errors: $TYPE_ERRORS"
echo "Lint errors: $LINT_ERRORS"
echo "Test failures: $TEST_FAILURES"
```

**Go** (go.mod detected):
```bash
VET_ERRORS=$(go vet ./... 2>&1 | wc -l || echo "0") &
BUILD_ERRORS=$(go build ./... 2>&1 | wc -l || echo "0") &
wait

echo "Vet errors: $VET_ERRORS"
echo "Build errors: $BUILD_ERRORS"
```

Prioritize fixing: compile/type errors → build errors → lint errors → runtime errors

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

**Rust Errors**:
- Fix borrow checker violations (ownership, lifetimes)
- Replace `unwrap()` with `?` operator or `expect("reason")`
- Check type mismatches and missing trait implementations

**Python Errors**:
- Fix type annotation mismatches detected by mypy
- Check import paths and module availability
- Verify async/await usage and event loop handling

## Quality Standards

Run checks based on detected tech stack after implementing fix:

**Node.js/TypeScript**:
```bash
npm run typecheck || echo "TypeScript issues remain"
npm run build >/dev/null 2>&1 && echo "Build OK" || echo "Build failed"
npm run lint --quiet 2>/dev/null && echo "No lint errors" || echo "Lint errors"
npm run test:run --silent 2>/dev/null && echo "Tests passing" || echo "Test issues"
```

**Rust**:
```bash
cargo check && echo "Compile OK" || echo "Compile errors"
cargo clippy -- -D warnings && echo "No warnings" || echo "Clippy issues"
cargo test 2>/dev/null && echo "Tests passing" || echo "Test failures"
```

**Python**:
```bash
mypy . && echo "Type check OK" || echo "Type errors"
ruff check . && echo "No lint errors" || echo "Lint errors"
pytest -q 2>/dev/null && echo "Tests passing" || echo "Test failures"
```

**Go**:
```bash
go vet ./... && echo "Vet OK" || echo "Vet issues"
go build ./... && echo "Build OK" || echo "Build failed"
go test ./... 2>/dev/null && echo "Tests passing" || echo "Test failures"
```

## Regression Prevention

Check for unintended side effects after fix:

```bash
git diff HEAD~1 --stat | head -5 || echo "No recent changes"
```

Regression testing checklist:
1. Test components that use the fixed code
2. Test similar functionality in other areas
3. Test error handling scenarios
4. Verify no new console errors or warnings

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
/debug "ログイン時に401エラーが発生する" → Same, Japanese input supported
/debug "task creation freezes UI" → Check state updates and event handlers
/debug "データがDBに保存されない" → Verify API calls and error handling
/debug "app crashes on mobile Safari" → Browser compatibility investigation
/debug → Interactive mode with AskUserQuestion for bug details
```

## Exit Codes

- 0: Bug fixed and verified
- 1: User error - invalid description, cannot reproduce
- 2: Security error - validation failure, permission denied
- 3: System error - build failure, tool unavailable
- 4: Critical issue - requires escalation or architectural change
