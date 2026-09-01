---
name: ship
description: Create GitHub PR/GitLab MR with automatic platform detection
disable-model-invocation: true
---

# Ship - PR/MR Creation

Create GitHub Pull Request or GitLab Merge Request with automatic platform detection.

Arguments: $ARGUMENTS

## Argument Processing

Security: Reject $ARGUMENTS containing `` ` $(){}; `` characters before any parsing.

Parse from $ARGUMENTS:
- First token → branch-name (optional)
- Remaining tokens → PR/MR title (optional)
- `--skip-checks` flag → skip quality checks

If $ARGUMENTS empty: interactive mode (use AskUserQuestion)

## Platform Detection

From `git remote get-url origin`:
- Contains `github.com` → GitHub, CLI: `gh`
- Contains `gitlab` → GitLab, CLI: `glab`
- Otherwise → error (exit 4): "Unsupported platform. Only GitHub and GitLab are supported."

## Validation

Run in this order BEFORE PR/MR creation:

**1. Branch name** (exit 2 on path traversal, exit 1 on format error):
- Must not contain `..`
- Must match `^[a-zA-Z0-9/_-]+$`
- Must exist: `git rev-parse --verify <branch>`

**2. PR/MR title** (exit 1 on format error, exit 2 on injection):
- Must not contain shell metacharacters: `` ` $(){}; |><& ``
- Max 200 chars total; validate BEFORE regex (ReDoS protection)
- Must follow Conventional Commits: `<type>(<scope>): <subject>`
- Allowed types: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`, `hotfix`
- Subject max 72 chars

**3. CLI authentication** (exit 3 on failure):
- Check CLI installed: `command -v gh` / `command -v glab`
- Check auth: `gh auth status` / `glab auth status`

**4. Template secrets** (before PR/MR creation):
- Scan template body for patterns: `(api[_-]?key|password|secret|token|bearer|auth).{0,10}[=:].{8,}`
- If found: warn and ask confirmation via AskUserQuestion
- If user declines: abort (exit 2)

## Exit Codes

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | EXIT_SUCCESS | Success |
| 1 | EXIT_USER_ERROR | Invalid format, branch not found |
| 2 | EXIT_SECURITY_ERROR | Path traversal, injection, secrets detected |
| 3 | EXIT_SYSTEM_ERROR | CLI not installed, auth failed |
| 4 | EXIT_UNRECOVERABLE | Platform detection failed |

## Execution Flow

1. Validate git repo and remote (`git remote get-url origin`)
2. Detect platform → get CLI command
3. Validate CLI installed and authenticated
4. Get current branch: `git branch --show-current`
5. Parse and validate arguments (or enter interactive mode)
6. Check uncommitted changes (`git status --porcelain`) — if present, warn and AskUserQuestion to continue
7. Run quality checks (unless --skip-checks)
8. Load PR/MR template (3-tier fallback)
9. Scan template for secrets
10. Create draft PR/MR
11. Open in browser

## Quality Checks

If `--skip-checks`: skip and warn "Quality checks skipped — ensure manual verification before merging."

Otherwise:
1. Invoke `/validate --layers=syntax --auto-fix` via Skill tool
2. If /validate skill unavailable: run `npm run typecheck` and `npm run lint` as fallback
3. If checks fail: report errors, halt — user must fix or use `--skip-checks` (exit 1)

## Template Loading

3-tier fallback per platform:

| Priority | GitHub | GitLab |
|----------|--------|--------|
| 1 | `.github/pull_request_template.md` | `.gitlab/merge_request_template.md` |
| 2 | `~/.github/PULL_REQUEST_TEMPLATE.md` | `~/.gitlab/merge_request_template.md` |
| 3 | Built-in auto-generated template | Built-in auto-generated template |

If `docs/PR_GUIDELINES.md` or `docs/MR_GUIDELINES.md` exists: include as reference context.

## Interactive Mode (No Arguments)

Question 1 — Change type:
```
AskUserQuestion: "Select change type"
Options: feature, fix, refactor, docs, chore, hotfix
```

Question 2 — Scope:
```
AskUserQuestion: "Select change scope"
Options: ui, api, core, config, docs, test
```

Auto-generate title: `<type>(<scope>): <description derived from branch name>`

## PR/MR Creation

```bash
# Ensure branch is pushed
git push -u origin <branch>

# GitHub (draft)
gh pr create --draft --title "<title>" --body "<template>"
gh pr view --web

# GitLab (draft)
glab mr create --draft --title "<title>" --description "<template>"
glab mr view --web
```

Always create as draft (`--draft` required).

## Update & Status Commands

```bash
# GitHub
gh pr edit <number> --title "..." --body "..."
gh pr ready <number>
gh pr edit <number> --draft

# GitLab
glab mr update <number> --title "..." --description "..."
glab mr update <number> --ready
glab mr update <number> --draft
```

## Error Handling

| Situation | Action |
|-----------|--------|
| Missing argument | AskUserQuestion for interactive input |
| Invalid Conventional Commits | Report expected format with example |
| Invalid branch name | Report error, show current branch |
| Unsupported platform | "Only GitHub and GitLab are supported." |
| CLI not found | Report installation: `brew install gh` / `brew install glab` |
| Git push failed | Report error, verify remote |
| PR/MR creation failed | Report specific CLI error |

Never expose: absolute file paths, stack traces, internal system details.

## Output Format

Success:
```
Pull Request created successfully
Platform: GitHub
Branch: <branch>
Status: Draft
URL: <url>

Next steps:
  1. Review PR checklist in the PR body
  2. Request reviews when ready
  3. Mark as ready: gh pr ready <number>
```

Error:
```
ERROR: <error type>
Expected: <correct format or action>
Got: <actual input>

<actionable fix instructions>
Exit code: <N> (<meaning>)
```

## Examples

```
/ship                                              → interactive mode
/ship feat/user-profile "feat(ui): add profile"   → direct creation
/ship --skip-checks feat/wip "feat(ui): work in progress"  → skip checks
```

See `examples.md` for complete usage scenarios including error cases.
