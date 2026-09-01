---
name: branch
description: Create Git branch following Conventional Branch naming rules
argument-hint: "[type] [description]"
allowed-tools: Bash(git *) AskUserQuestion
disable-model-invocation: true
---

# Branch Creation Command

Arguments: $ARGUMENTS

## Execution Flow

### 1. Determine Branch Type and Description

**If arguments provided** (`$ARGUMENTS` is non-empty):

Parse `$ARGUMENTS` as: `{type} {description...}`

Validate branch type against allowed list. If invalid, report error and exit 1.

Sanitize description:
1. Reject input containing `..` (path traversal) → exit 2
2. Convert to lowercase
3. Replace spaces with hyphens
4. Remove all characters except `a-z`, `0-9`, `-`
5. Strip leading/trailing hyphens
6. Collapse consecutive hyphens to single hyphen

Generate branch name: `{type}/{sanitized-description}`

Validate final format matches `^[a-z]+/[a-z0-9-]+$` → if not, exit 2

**If no arguments:**

Ask user to select branch type:
- **feature** — New feature development (UI, API, integrations)
- **fix** — Bug fixes and error resolution
- **refactor** — Code improvement and refactoring
- **docs** — Documentation creation and updates
- **chore** — Configuration and tooling (build, dependencies, CI/CD)
- **hotfix** — Emergency fixes (production issues, security)

Then prompt for a short description (use "Other" free text input).

### 2. Pre-creation Checks

Run in order:
1. Verify git repository: `git rev-parse --is-inside-work-tree`
2. Check for uncommitted changes: `git status --porcelain`

If uncommitted changes detected, ask user:
- **stash** — Temporarily save changes (`git stash`)
- **commit** — Commit before branching
- **cancel** — Abort

Branch collision is detected automatically by `git checkout -b` (no separate check needed).

### 3. Create Branch

```bash
git checkout -b "{branch_name}"
```

After creation, ask user:
- **push** — Push and set upstream tracking (`git push -u origin {branch_name}`)
- **local only** — Keep branch local for now

## Branch Types

| Type | Purpose | Example |
|------|---------|---------|
| `feature/` | New feature development | `feature/user-authentication` |
| `fix/` | Bug fixes | `fix/validation-error` |
| `refactor/` | Code improvement | `refactor/api-optimization` |
| `docs/` | Documentation | `docs/api-documentation` |
| `chore/` | Config and tooling | `chore/eslint-update` |
| `hotfix/` | Emergency production fixes | `hotfix/security-patch` |

## Error Handling

| Code | Trigger | Message format |
|------|---------|----------------|
| 1 | Invalid branch type | `ERROR [branch:validate]` + allowed types |
| 2 | Path traversal or format failure | `ERROR [branch:security]` + reason |
| 3 | Git command failure | `ERROR [branch:git]` + user-actionable guidance |

Never expose in error messages: absolute paths, stack traces, environment variables.

## Examples

```
/branch feature user-login        → feature/user-login
/branch fix "Bug in API"          → fix/bug-in-api
/branch                           → interactive mode
/branch invalid test              → error: invalid type
```
