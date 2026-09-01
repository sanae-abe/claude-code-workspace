---
name: debug
description: Debug bugs, errors, crashes, and unexpected behavior. Use when user says 'bug', 'error', 'broken', 'fix', 'crash', 'not working', 'fails', or describes unexpected behavior. Also triggers on Japanese: 'バグ', 'エラー', '壊れた', '動かない', 'おかしい', '直して', '修正して', 'クラッシュ', '失敗'.
---

# Universal Debugging Command

Debug target: $ARGUMENTS

## Argument Validation

Parse $ARGUMENTS:
- If empty: use AskUserQuestion to gather bug details (description, reproduction steps, expected vs actual behavior)
- If too short (< 5 chars): report error with example — `"Login fails with 401 error when session expires"`
- Proceed with any valid description including error messages, file paths, Japanese, symbols

## Execution Flow

1. Parse bug description from $ARGUMENTS (or gather via AskUserQuestion)
2. Detect project type and run automated diagnostics
3. Identify root cause with systematic investigation
4. Implement fix
5. Verify fix and check for regressions

## Task Tracking

Create tasks with TodoWrite for bug resolution workflow:
- Task 1: Automated diagnostics and initial assessment
- Task 2: Root cause identification and analysis
- Task 3: Fix implementation
- Task 4: Verification and regression testing
- Mark each completed with TodoWrite as work progresses

## Automated Diagnostics

First detect project type using Glob tool, then run appropriate checks:

- Use Glob to check for `package.json`, `Cargo.toml`, `go.mod`, `requirements.txt`, `pyproject.toml`
- Use Read to inspect `package.json` scripts section for available commands (typecheck, type-check, lint, build, test)

Run checks based on detected project type:

**Node.js / TypeScript**:
```bash
npm run typecheck 2>&1 | head -20 &
npm run lint 2>&1 | head -20 &
wait
```

**Rust**:
```bash
cargo check 2>&1 | head -20
cargo clippy 2>&1 | head -20
```

**Go**:
```bash
go vet ./... 2>&1 | head -20
```

**Python**:
```bash
python -m mypy . 2>&1 | head -20 || true
python -m ruff check . 2>&1 | head -20 || true
```

**All projects** — check logs and git state:
- Use Glob to find `*.log` files, then Grep for `Error|Exception` patterns
```bash
git diff HEAD --stat 2>/dev/null | head -10 || true
```

## Bug Investigation Workflow

When bug scope is unclear, use Agent tool with Explore subagent:

```
Agent(
  subagent_type: "Explore",
  description: "バグ関連ファイル調査",
  prompt: "Locate files and components related to [bug description]. Return file:line references."
)
```

For complex systematic debugging:

```
Agent(
  subagent_type: "debugger",
  description: "根本原因の体系的分析",
  prompt: "Systematic root cause analysis for [bug description]. Include error traces, state inspection, data flow analysis."
)
```

## Common Bug Types and Solutions

**TypeScript Errors**:
- Add optional chaining (`?.`) and nullish coalescing (`??`)
- Replace `any` with proper type definitions
- Fix import paths and export statements

**React / Vue Errors**:
- Fix useEffect dependency arrays
- Use functional state updates
- Add unique keys to list items
- Ensure proper cleanup in useEffect return

**Performance Issues**:
- Fix infinite loops in useEffect / watchers
- Add cleanup for subscriptions and timers
- Check for accidentally imported large libraries

**API / Network Errors**:
- Verify authentication tokens and headers
- Check error handling and user feedback
- Validate data schemas and transformations

**UI / Rendering Bugs**:
- Check for undefined className or style properties
- Verify CSS conflicts and responsive design
- Inspect DevTools for re-render patterns

## Quality Standards

After implementing fix, run appropriate checks for the detected stack:

- TypeScript: `npm run typecheck`
- Build: `npm run build` or `cargo build` or `go build ./...`
- Lint: `npm run lint` or `cargo clippy` or `ruff check .`
- Tests: run available test command if tests exist

## Regression Prevention

After fixing, verify no unintended side effects:

```bash
git diff HEAD --stat | head -10
```

Regression checklist:
1. Test components that use the fixed code
2. Test similar functionality in other areas
3. Test error handling scenarios
4. Verify no new console errors

## Error Handling

Cannot reproduce bug:
- Request environment details (browser, OS, configuration)
- Request specific data or reproduction steps
- Analyze logs and git history

Fix breaks other functionality:
- Roll back and consider alternative approach
- Use Agent (debugger subagent) for deeper analysis

Root cause unclear:
- Run `git log --oneline -20` for code archaeology
- Check recent dependency changes
- Use Agent (debugger subagent) for systematic investigation

Never expose in user-facing errors:
- Stack traces
- Absolute file paths
- Internal system details
- Sensitive environment information

## Examples

```
/debug "login fails with 401 error" → Investigate authentication and token handling
/debug "TypeError: Cannot read properties of undefined" → Trace undefined access
/debug "src/api.ts の401エラー" → Japanese description supported
/debug "task creation freezes UI" → Check state updates and event handlers
/debug → Interactive mode: AskUserQuestion for bug details
```

## Completion States

Report one of the following outcomes:

- **Fixed**: Bug resolved and verified — describe what was changed and why
- **Cannot reproduce**: Insufficient info — list what additional details are needed
- **Escalation required**: Root cause requires architectural change — describe scope and recommendation
- **Build unavailable**: Required tools missing — list what needs to be installed
