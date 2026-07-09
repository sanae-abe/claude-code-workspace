---
name: branch
description: Create Git branch following Conventional Branch naming rules
disable-model-invocation: true
---

# Branch Creation

Arguments: $ARGUMENTS

## Execution Flow

### 1. Parse and Validate Arguments

**If arguments provided** (e.g., `/branch feature user-login`):

Parse `$ARGUMENTS`:
- First token = branch type
- Remaining tokens = description

Validate branch type against allowed list:
- Allowed: `feature`, `fix`, `refactor`, `docs`, `chore`, `hotfix`
- If invalid: report error and exit (code 1)

Sanitize description:
- Reject if contains `..` (path traversal) → exit (code 2)
- Convert to lowercase
- Replace spaces with hyphens
- Remove all characters except `a-z`, `0-9`, `-`
- Remove leading/trailing hyphens
- Collapse consecutive hyphens to single hyphen

Generate branch name: `{type}/{sanitized-description}`

Validate final format matches `^[a-z]+/[a-z0-9-]+$`:
- If invalid: report error with expected format and exit (code 2)

**If no arguments** — proceed to Interactive Mode section.

### 2. Pre-creation Checks

```bash
# Verify git repository
git rev-parse --is-inside-work-tree

# Check for uncommitted changes
git status --porcelain
```

If uncommitted changes detected, use AskUserQuestion with options:
- **stash**: `git stash push -m "Auto-stash for branch {branch_name}"`
- **commit**: Instruct user to stage and commit manually, then re-run `/branch`
- **cancel**: Exit without creating branch

### 3. Create and Push Branch

```bash
git switch -c "{branch_name}"
git push -u origin "{branch_name}"
```

## Branch Types

| Type | Purpose |
|------|---------|
| `feature/` | New feature development |
| `fix/` | Bug fixes and error resolution |
| `refactor/` | Code improvement and refactoring |
| `docs/` | Documentation creation and updates |
| `chore/` | Configuration and tooling |
| `hotfix/` | Emergency fixes for production issues |

**Examples**:
- `feature/user-authentication`
- `fix/validation-error`
- `refactor/api-optimization`
- `docs/api-documentation`
- `chore/eslint-update`
- `hotfix/security-patch`

## Interactive Mode

When `$ARGUMENTS` is empty, ask for branch type:

```typescript
AskUserQuestion({
  questions: [{
    question: "What type of branch do you want to create?",
    header: "Branch Type",
    multiSelect: false,
    options: [
      { label: "feature",  description: "New feature development (UI, API, integrations)" },
      { label: "fix",      description: "Bug fixes and error resolution" },
      { label: "refactor", description: "Code improvement and refactoring" },
      { label: "docs",     description: "Documentation creation and updates" },
      { label: "chore",    description: "Configuration and tooling (build, dependencies, CI/CD)" },
      { label: "hotfix",   description: "Emergency fixes (production issues, security)" }
    ]
  }]
})
```

After type selection, ask for description with a second AskUserQuestion free-text ("Other") prompt. Apply the same sanitization rules as the argument path.

## Error Handling

**Invalid branch type**:
```
ERROR [branch]: Invalid branch type
  Input: {branch_type}
  Allowed: feature, fix, refactor, docs, chore, hotfix
```

**Path traversal in description**:
```
ERROR [branch]: Path traversal detected in description
  Input contains: ..
  Reason: Security restriction
```

**Invalid final format**:
```
ERROR [branch]: Invalid branch name format
  Generated: {branch_name}
  Expected: {type}/{kebab-case-description}
```

**Not in git repository**:
```
ERROR [branch]: Not a git repository
  Suggestion: Run 'git init' first
```

**Branch already exists**:
```
ERROR [branch]: Branch already exists
  Branch: {branch_name}
  Suggestions: {branch_name}-v2, {branch_name}-{YYYYMMDD}
```

**Push failed**:
```
ERROR [branch]: Push failed
  Local branch created: {branch_name}
  Retry: git push -u origin "{branch_name}"
```

Never expose in error messages: absolute paths, stack traces, environment variables, or internal system details.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — branch created and pushed |
| 1 | User error — invalid type or format |
| 2 | Security error — path traversal or validation failure |
| 3 | System error — git command or network failure |

## Tool Usage

TaskCreate: 不要（3ステップ未満、高速実行）
AskUserQuestion: インタラクティブモードと未コミット変更の確認に使用
Bash: git 操作に使用
Read: 不使用

## Examples

```
/branch feature user-login      → feature/user-login
/branch fix "Bug in API"        → fix/bug-in-api
/branch                         → interactive mode
/branch invalid test            → ERROR: invalid branch type
```
