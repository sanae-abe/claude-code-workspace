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

### 1. Verify Environment

Run `git rev-parse --is-inside-work-tree` before any prompt.

If it fails: report the `Not a git repository` error (see Error Handling) and stop. Never ask the user for a branch type before this check passes.

### 2. Determine Branch Type and Description

**If `$ARGUMENTS` is non-empty:**

Parse as `{type} {description...}` — first token is the type, the remainder is the description.

- Validate the type against the Branch Types table below. If it is not listed, report the `Invalid branch type` error and stop.
- If the description part is empty, fall through to the interactive prompt below instead of failing.

**If `$ARGUMENTS` is empty:**

Ask the user to select a branch type with AskUserQuestion, using the six types in the Branch Types table as the options.

Then ask for a short description as plain text in your reply — do not use AskUserQuestion for this. That tool requires 2-4 predefined options and cannot represent free-form input.

### 3. Sanitize the Description

Apply to the description from **either** path above — argument-supplied and interactively entered descriptions are sanitized identically.

1. If it contains `..`, report the `Path traversal` error and stop
2. Convert to lowercase
3. Replace every run of characters outside `a-z0-9` with a single hyphen
4. Strip leading and trailing hyphens
5. If the result is empty, report the `Empty description` error and ask for a new description

Normative specification of steps 2-4. Apply this transformation yourself — do not shell out, `allowed-tools` grants git commands only:

```
tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
```

Verified results: `Bug in API` → `bug-in-api`, `User_Login v2` → `user-login-v2`, `  --Fix  Login!! ` → `fix-login`, `!!!` → empty (triggers the `Empty description` error).

Generate the branch name: `{type}/{sanitized-description}`

Validate it against `^[a-z]+/[a-z0-9-]+$`. If it does not match, report the `Malformed branch name` error and stop.

### 4. Pre-creation Checks

Run `git status --porcelain`. If it reports uncommitted changes, ask the user with AskUserQuestion:

- **stash** — Run `git stash -u` now; after step 5 creates the branch, run `git stash pop` on it so the changes move with the branch
- **commit** — Stop without creating the branch and tell the user to commit first, then re-run this command
- **cancel** — Abort without creating the branch

Branch collision is detected by `git checkout -b` itself — no separate existence check is needed.

### 5. Create Branch

```bash
git checkout -b "{branch_name}"
```

If the command fails, report the matching error from the Error Handling table and stop.

### 6. Publish

Ask the user with AskUserQuestion:

- **push** — Run `git push -u origin {branch_name}`
- **local only** — Keep the branch local

Then print the result using the Output Format below.

## Branch Types

Single source of truth for allowed types — validation in step 2 and the interactive options both read from this table.

| Type | Purpose | Example |
|------|---------|---------|
| `feature/` | New feature development (UI, API, integrations) | `feature/user-authentication` |
| `fix/` | Bug fixes and error resolution | `fix/validation-error` |
| `refactor/` | Code improvement and refactoring | `refactor/api-optimization` |
| `docs/` | Documentation creation and updates | `docs/api-documentation` |
| `chore/` | Configuration and tooling (build, dependencies, CI/CD) | `chore/eslint-update` |
| `hotfix/` | Emergency fixes (production issues, security) | `hotfix/security-patch` |

## Error Handling

Report the message, then take the stated action. No branch is created unless step 5 succeeds.

| Trigger | Message | Action |
|---------|---------|--------|
| Not a git repository | `ERROR [branch:git] Not inside a git repository. Run this from a repository, or run 'git init' first.` | Stop |
| Invalid branch type | `ERROR [branch:validate] Invalid type '{type}'. Allowed: feature, fix, refactor, docs, chore, hotfix` | Stop |
| Path traversal | `ERROR [branch:security] Description contains a path traversal sequence ('..')` | Stop |
| Empty description | `ERROR [branch:validate] Description produced no usable characters. Use letters, digits, or hyphens.` | Ask for a new description, then resume at step 3 |
| Malformed branch name | `ERROR [branch:validate] Generated name '{name}' is not a valid branch name` | Stop |
| Branch already exists | `ERROR [branch:git] Branch '{name}' already exists. Run 'git switch {name}' to use it, or choose another name.` | Stop |
| Stash pop conflict | `ERROR [branch:git] Stashed changes conflict with the new branch. Resolve the conflict, then run 'git stash drop'.` | Stop — branch is created and checked out |
| Push failed | `ERROR [branch:git] Push failed. Verify the 'origin' remote exists and you have push access.` | Stop — branch remains created locally |

Never expose in error messages: absolute paths, stack traces, environment variables.

## Output Format

Local only:
```
Created branch: feature/user-login (from main)
```

Pushed:
```
Created branch: feature/user-login (from main)
Pushed to origin with upstream tracking
```

Stashed changes restored:
```
Created branch: feature/user-login (from main)
Restored 1 stashed change onto the new branch
```

## Examples

```
/branch feature user-login   → creates feature/user-login
/branch fix "Bug in API"     → creates fix/bug-in-api
/branch                      → interactive: select type, then enter a description
/branch feature              → interactive: type accepted, prompts for a description
/branch invalid test         → ERROR [branch:validate] Invalid type 'invalid'. Allowed: ...
/branch docs "../etc"        → ERROR [branch:security] Description contains a path traversal sequence ('..')
```
