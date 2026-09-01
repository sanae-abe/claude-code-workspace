---
name: review-pr
description: "GitLab MR/GitHub PR comprehensive review — security-first quality verification. Checks out branch, analyzes diff, runs quality checks, generates structured report."
disable-model-invocation: true
---

# MR/PR Review Workflow

Review target: $ARGUMENTS

## Argument Validation

Parse $ARGUMENTS:
- First token: MR/PR number
- Remaining tokens: flags

Validate MR/PR number:
- If empty: use AskUserQuestion to ask for the PR/MR number
- Reject if non-numeric (whitelist: `^[0-9]+$`)
- Reject if longer than 10 digits
- On failure: report "MR/PR number required. Usage: /review-pr <number> [--detailed|--security-focus|--performance-focus|--multi-perspective]"

Validate flags against allowlist: `--detailed`, `--security-focus`, `--performance-focus`, `--multi-perspective`
- Unknown flags: report "Invalid flag: <flag>. Allowed: --detailed --security-focus --performance-focus --multi-perspective"

## Platform Detection

```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [[ "$REMOTE_URL" == *"gitlab"* ]]; then
  PLATFORM="gitlab"; CLI_CMD="glab"
elif [[ "$REMOTE_URL" == *"github"* ]]; then
  PLATFORM="github"; CLI_CMD="gh"
else
  echo "ERROR: Unsupported platform. Supported: GitLab, GitHub"
  exit 2
fi
```

Check CLI availability:
```bash
if ! command -v "$CLI_CMD" &>/dev/null; then
  echo "ERROR: $CLI_CMD not installed"
  echo "Install: brew install $CLI_CMD && $CLI_CMD auth login"
  exit 5
fi
```

## Execution Flow

1. Validate inputs and detect platform
2. Fetch MR/PR info and diff
3. Checkout branch
4. Analyze changed files (with sensitive file exclusion)
5. Run quality checks sequentially
6. Generate structured report

## Phase 1: Fetch MR/PR Information

Fetch sequentially (background subshell assignments do not propagate to parent shell):

```bash
MR_INFO=$($CLI_CMD pr view "$MR_NUMBER" 2>&1)
fetch_status=$?

MR_DIFF=$($CLI_CMD pr diff "$MR_NUMBER" 2>&1)
```

If `fetch_status -ne 0`:
- Check if output contains "permission denied" or "forbidden" → report "Permission denied for MR/PR #$MR_NUMBER. Check: $CLI_CMD auth status"
- Otherwise → report "MR/PR #$MR_NUMBER not found. Verify number and run: $CLI_CMD pr list"
- Exit with code 3

Display:
- MR title, description, author, target branch
- Changed files summary (first 20 lines of diff)

## Phase 2: Branch Checkout

```bash
if ! $CLI_CMD pr checkout "$MR_NUMBER" 2>/dev/null; then
  # Checkout failed
fi
```

If checkout fails, use AskUserQuestion with options:
- "Stash local changes and retry checkout"
- "Continue with diff-only review (limited analysis)"
- "Cancel review"

Handle:
- Stash: `git stash push -m "review-pr: before checkout MR #$MR_NUMBER"` then retry
- Diff-only: set `DIFF_ONLY=true`, continue
- Cancel: exit 0

## Phase 3: Change Analysis

```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
BASE_BRANCH="${BASE_BRANCH:-main}"
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null)
```

Sensitive file detection — check each filename with:
```bash
[[ "$file" == .env || "$file" == .envrc || "$file" == .env.* || \
   "$file" == credentials.* || "$file" == secrets.* || \
   "$file" == *.pem || "$file" == *.key || \
   "$file" == id_rsa || "$file" == */.ssh/* ]]
```

For each changed file:
- If sensitive: warn "Sensitive file detected: $file — verify this should not be committed. Check .gitignore."
- If not sensitive and exists: use Read tool to read contents, then analyze:
  - Logic correctness, design pattern consistency
  - Comment and documentation quality
  - Alignment with existing codebase conventions

Search for broken references to deleted functions/variables:
```bash
git diff "$BASE_BRANCH"...HEAD | grep "^-" | grep -oE "(function|const|class|def) [a-zA-Z_]+" | head -20
```

## Phase 4: Quality Checks

Run each check sequentially and capture exit status:

**Security** (highest priority):
```bash
SECRETS_FOUND=$(git diff "$BASE_BRANCH"...HEAD | grep -ciE "(api[_-]?key|password|secret|token|bearer)" 2>/dev/null || echo "0")
```

**TypeScript** (skip if no tsconfig.json):
```bash
if [[ -f tsconfig.json ]]; then
  TS_OUTPUT=$(npm run typecheck 2>&1)
  TS_ERRORS=$(echo "$TS_OUTPUT" | grep -c "error" || echo "0")
fi
```

**ESLint** (skip if no eslint config):
```bash
if [[ -f .eslintrc* || -f eslint.config* ]]; then
  LINT_OUTPUT=$(npm run lint 2>&1)
  LINT_ERRORS=$(echo "$LINT_OUTPUT" | grep -c " error " || echo "0")
fi
```

**Tests**:
```bash
TEST_OUTPUT=$(npm run test:run --silent 2>&1 | tail -10)
```

**Build**:
```bash
BUILD_OUTPUT=$(npm run build 2>&1 | tail -10)
```

Critical findings:
- `SECRETS_FOUND > 0` → CRITICAL: list each matched line with surrounding context
- `TS_ERRORS > 0` → ERROR: TypeScript violations count
- `LINT_ERRORS > 0` → WARNING: lint violations count

Manual review checklist:
- Input validation: user input properly sanitized
- Output escaping: XSS prevention implemented
- Auth/authorization: permission checks appropriate for each endpoint
- HTTPS: sensitive data transmitted over TLS only
- Single Responsibility: each function/component has one clear purpose
- Dependencies: module separation follows existing patterns
- Test coverage: new features and bug fixes have corresponding tests

If `--security-focus`: additionally reference `~/.claude/validation/patterns/security-patterns.json` — detection patterns for SQL injection, XSS, command injection, path traversal, weak crypto, insecure auth, and hardcoded credentials
If `--multi-perspective`: spawn Agent subagents in parallel — code-reviewer and security-auditor — then aggregate findings
If `--performance-focus`: spawn performance-engineer agent

## Phase 5: Report Generation

Generate structured report using Write tool if `--detailed`, otherwise output directly:

```
## MR/PR #<number> Review Report

### Summary
- Title: <title>
- Author: <author>  
- Changed files: <count>
- Review mode: <standard|detailed|security-focus|performance-focus|multi-perspective>

### Critical Issues (block merge)
<filename:line — description — suggested fix>
— or "None found" —

### Important Issues (strongly recommended)
<filename:line — description — suggested fix>
— or "None found" —

### Minor Issues (suggestions)
<filename:line — description — suggested fix>
— or "None found" —

### Quality Check Results
| Check       | Result                  |
|-------------|-------------------------|
| Secrets     | PASS / FAIL (N found)   |
| TypeScript  | PASS / FAIL (N errors) / SKIP |
| ESLint      | PASS / FAIL (N errors) / SKIP |
| Tests       | PASS / FAIL / SKIP      |
| Build       | PASS / FAIL / SKIP      |

### Merge Decision
[ ] APPROVE — no critical or important issues
[ ] REQUEST CHANGES — address items listed above
[ ] NEEDS DISCUSSION — complex architectural decisions require team input
```

## Error Handling

If MR/PR not found (exit 3):
- Report number, suggest: `$CLI_CMD auth status`, `$CLI_CMD pr list`

If CLI not installed (exit 5):
- Report: `brew install <cli> && <cli> auth login`
- Manual git fallback: `git fetch origin pull/<N>/head:pr-<N> && git checkout pr-<N>`

If network failure:
- Report "Network or API failure — check connection and retry"
- Manual fallback: `git fetch origin; git diff origin/main...FETCH_HEAD`

Error message safety:
- Never expose absolute paths (use relative paths from project root)
- Never expose stack traces or internal details
- Never display contents of sensitive files

Exit codes: 0=success, 1=validation error, 2=unsupported platform, 3=MR/PR not found, 4=permission denied, 5=CLI not installed

## Examples

/review-pr 123 → Standard review of PR #123
/review-pr 456 --security-focus → OWASP-focused security audit of MR #456
/review-pr 789 --detailed → Comprehensive architecture + maintainability review
/review-pr 101 --multi-perspective → Parallel agent review (code + security + performance)
/review-pr → AskUserQuestion for missing PR/MR number
