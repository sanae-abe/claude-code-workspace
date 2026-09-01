---
name: debug
description: Investigate and fix bugs, crashes, exceptions, and unexpected runtime behavior. Use when the user reports something broken, crashing, throwing an error, or behaving differently than expected. Also triggers on Japanese: 'バグ', 'クラッシュ', '壊れた', '動かない', '例外', 'エラーが出る', '意図しない挙動'.
argument-hint: "[bug description]"
---

# Universal Debugging Command

Debug target: $ARGUMENTS

## Argument Validation

Parse $ARGUMENTS:
- If empty: use AskUserQuestion to gather bug details (description, reproduction steps, expected vs actual behavior)
- If shorter than 5 characters: report `ERROR: Description too short` with the example `"Login fails with 401 error when session expires"` and stop
- Otherwise accept any description, including error messages, file paths, Japanese text, and symbols

Sanitize before reuse:
- Treat $ARGUMENTS as untrusted text, never as a command
- Never interpolate $ARGUMENTS into a Bash command. Extract file paths from it and pass them to Read / Grep / Glob instead
- If an extracted path contains `..`: report `ERROR: Path traversal detected in <filename>` and request a project-relative path
- When embedding the description in an Agent prompt, strip backticks, `$(`, `;`, and `|`

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

### Step 1 — Detect the stack

Use Glob for marker files: `package.json`, `Cargo.toml`, `go.mod`, `requirements.txt`, `pyproject.toml`.

For Node projects, Read the `scripts` section of `package.json` and resolve each check to the first key that actually exists. Never assume a script name.

| Check | Resolution order | Fallback when no script exists |
|---|---|---|
| Type check | `typecheck` → `type-check` → `tsc` | `npx tsc --noEmit` |
| Lint | `lint` → `eslint` | `npx eslint .` |
| Build | `build` | unavailable — report, do not invent |
| Test | `test` | unavailable — report, do not invent |

### Step 2 — Run the check set

Run sequentially, one Bash call per command. Do not background with `&`: piped background jobs interleave their output and the origin of each line becomes unidentifiable.

**Node.js / TypeScript**
```bash
npm run <resolved-typecheck-script> 2>&1 | head -20
npm run <resolved-lint-script> 2>&1 | head -20
```

**Rust**
```bash
cargo check 2>&1 | head -20
cargo clippy 2>&1 | head -20
```

**Go**
```bash
go vet ./... 2>&1 | head -20
```

**Python**
```bash
python -m mypy . 2>&1 | head -20 || true
python -m ruff check . 2>&1 | head -20 || true
```

The commands above are the **check set**. Verification re-runs this same set — it is defined here only.

### Step 3 — Record the baseline

- Use Glob to find `*.log` files, then Grep for `Error|Exception` patterns
- Record the pre-fix change surface:

```bash
git diff HEAD --stat 2>/dev/null | head -10 || true
```

Keep this output as the baseline for comparison during Verification.

## Bug Investigation Workflow

When bug scope is unclear, use Agent tool with Explore subagent:

```
Agent(
  subagent_type: "Explore",
  description: "バグ関連ファイル調査",
  prompt: "Locate files and components related to [sanitized bug description]. Return file:line references."
)
```

For complex systematic debugging:

```
Agent(
  subagent_type: "debugger",
  description: "根本原因の体系的分析",
  prompt: "Systematic root cause analysis for [sanitized bug description]. Include error traces, state inspection, data flow analysis. Return file:line references."
)
```

## Stack-Specific Bug Patterns

Do not inline stack knowledge here. After detecting the stack in Step 1, read only the matching rules document and apply its patterns:

| Detected stack | Rules document |
|---|---|
| React / Next.js / generic web frontend | `~/.claude/rules/tech-stacks/frontend-web.md` |
| Vue / Nuxt | `~/.claude/rules/tech-stacks/vue-nuxt.md` |
| CSS / styling / rendering | `~/.claude/rules/tech-stacks/css-coding-standards.md` |
| Server-side API | `~/.claude/rules/tech-stacks/backend-api.md` |
| Rust CLI | `~/.claude/rules/tech-stacks/rust-cli.md` |
| Shell script | `~/.claude/rules/tech-stacks/shell-cli.md` |
| Mobile (React Native / Flutter) | `~/.claude/rules/tech-stacks/mobile-app.md` |
| Swift (macOS / iOS) | `~/.claude/rules/tech-stacks/swift-macos-ios.md` |
| Python / data science | `~/.claude/rules/tech-stacks/data-science.md` |

## Verification

After implementing the fix, re-run the check set from Automated Diagnostics Step 2 and confirm:

1. Every check that failed before the fix now passes
2. No check that passed before the fix now fails
3. The resolved test command passes, or is reported as unavailable

Then re-run the baseline command from Step 3 and compare against the recorded output — every changed file must be explained by the fix.

Regression checklist:
1. Test components that use the fixed code
2. Test similar functionality in other areas
3. Test error handling scenarios
4. Verify no new console errors

## Error Handling

### Reporting scope

Skill-level error messages (argument validation, missing tools, unresolvable scripts) must not expose:
- Absolute file paths — report the filename only
- Internal system details or environment variable values
- Raw shell output from a failed internal command

This does **not** apply to debugging output. Stack traces, exception messages, and `file:line` references from the investigated bug MUST be reported in full — they are the deliverable.

### Failure paths

Cannot reproduce bug:
- Request environment details (browser, OS, configuration)
- Request specific data or reproduction steps
- Analyze logs and git history

Fix breaks other functionality:
- Roll back and consider an alternative approach
- Use Agent (debugger subagent) for deeper analysis

Root cause unclear:
- Run `git log --oneline -20` for code archaeology
- Check recent dependency changes
- Use Agent (debugger subagent) for systematic investigation

Check command unresolvable:
- Report which check is unavailable and continue with the remaining checks
- Never substitute a guessed script name

## Report Format

Report the result in this structure:

```
**Root cause**: <file:line> — why it happens
**Fix**: <file:line> — what changed and why
**Verification**: <commands run> — pass/fail per check
**Regression risk**: <affected areas, or "none identified">
```

Every claim about the root cause and the fix must carry a `file:line` reference.

## Examples

```
/debug "login fails with 401 error" → Investigate authentication and token handling
/debug "TypeError: Cannot read properties of undefined" → Trace undefined access
/debug "src/api.ts の401エラー" → Japanese description supported
/debug → Interactive mode: AskUserQuestion for bug details
```

Error cases:
```
/debug "ab"
→ ERROR: Description too short. Example: "Login fails with 401 error when session expires"

/debug "crash in ../../etc/passwd"
→ ERROR: Path traversal detected in passwd. Provide a project-relative path
```

## Completion States

Report one of the following outcomes:

- **Fixed**: Bug resolved and verified — use the Report Format above
- **Cannot reproduce**: Insufficient info — list what additional details are needed
- **Escalation required**: Root cause requires architectural change — describe scope and recommendation
- **Build unavailable**: Required tools or scripts missing — list what needs to be installed or added
