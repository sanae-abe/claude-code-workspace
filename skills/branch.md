---
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: "[branch-type] [description]"
description: Create Git branch following Conventional Branch naming rules
model: sonnet
---

# Branch Creation Command

Arguments: $ARGUMENTS

## Argument Validation and Sanitization

Parse and validate $ARGUMENTS with security-first approach:

```bash
sanitize_description() {
  local input="$1"

  # Path traversal check
  if [[ "$input" =~ \.\. ]]; then
    echo "ERROR [branch.md:sanitize]: Path traversal detected"
    echo "  Input contains: .."
    echo "  Reason: Security restriction"
    exit 2
  fi

  # Convert to lowercase
  local sanitized="${input,,}"

  # Replace spaces with hyphens
  sanitized="${sanitized// /-}"

  # Remove special characters (keep alphanumeric and hyphens)
  sanitized=$(echo "$sanitized" | tr -cd 'a-z0-9-')

  # Remove leading/trailing hyphens
  sanitized="${sanitized#-}"
  sanitized="${sanitized%-}"

  # Collapse multiple consecutive hyphens
  sanitized=$(echo "$sanitized" | sed 's/-\+/-/g')

  echo "$sanitized"
}

validate_branch_type() {
  local branch_type="$1"

  case "$branch_type" in
    feature|fix|refactor|docs|chore|hotfix)
      return 0
      ;;
    *)
      echo "ERROR [branch.md:validate]: Invalid branch type"
      echo "  Input: $branch_type"
      echo "  Allowed: feature, fix, refactor, docs, chore, hotfix"
      exit 1
      ;;
  esac
}

# Safe argument parsing with IFS
IFS=' ' read -r -a args <<< "$ARGUMENTS"

if [[ ${#args[@]} -eq 0 ]]; then
  # Interactive mode (handled in Execution Flow)
  BRANCH_TYPE=""
  DESCRIPTION=""
else
  BRANCH_TYPE="${args[0]}"
  DESCRIPTION="${args[*]:1}"  # All remaining args

  # Validate and sanitize
  validate_branch_type "$BRANCH_TYPE"
  DESCRIPTION_SANITIZED=$(sanitize_description "$DESCRIPTION")

  # Create branch name
  BRANCH_NAME="${BRANCH_TYPE}/${DESCRIPTION_SANITIZED}"

  # Final format validation
  if [[ ! "$BRANCH_NAME" =~ ^[a-z]+/[a-z0-9-]+$ ]]; then
    echo "ERROR [branch.md:validate]: Invalid branch name format"
    echo "  Generated: $BRANCH_NAME"
    echo "  Expected: {type}/{kebab-case-description}"
    exit 2
  fi
fi
```

## Execution Flow

### 1. Determine Branch Type

**If arguments provided:**
- Parse branch-type and description from $ARGUMENTS
- Validate and sanitize inputs
- Generate branch name: {type}/{kebab-case-description}

**If no arguments:**
- Use AskUserQuestion for interactive selection
- Present 6 branch types with descriptions

### 2. Pre-creation Validation

Execute minimal checks for fast execution:

```bash
# 1. Verify git repository
git rev-parse --is-inside-work-tree

# 2. Check uncommitted changes
git status --porcelain
```

If uncommitted changes detected: use AskUserQuestion with options:
- stash: temporarily save changes
- commit: commit changes before branch creation
- cancel: abort branch creation

Note: Branch collision detection deferred to `git checkout -b` (automatic error handling)

### 3. Create and Push Branch

```bash
# Create local branch (quoted for security)
git checkout -b "${branch_name}"

# Push to remote with upstream tracking
git push -u origin "${branch_name}"
```

## Branch Types

Conventional branch type definitions:

- **feature/**: New feature development
- **fix/**: Bug fixes and error resolution
- **refactor/**: Code improvement and refactoring
- **docs/**: Documentation creation and updates
- **chore/**: Configuration and tooling
- **hotfix/**: Emergency fixes for production issues

Examples:
- `feature/user-authentication`
- `fix/validation-error`
- `refactor/api-optimization`
- `docs/api-documentation`
- `chore/eslint-update`
- `hotfix/security-patch`

## Interactive Mode

When $ARGUMENTS is empty or unclear, use AskUserQuestion:

```typescript
AskUserQuestion({
  questions: [{
    question: "What type of branch do you want to create?",
    header: "Branch Type",
    multiSelect: false,
    options: [
      {
        label: "feature",
        description: "New feature development (UI, API, integrations)"
      },
      {
        label: "fix",
        description: "Bug fixes and error resolution"
      },
      {
        label: "refactor",
        description: "Code improvement and refactoring"
      },
      {
        label: "docs",
        description: "Documentation creation and updates"
      },
      {
        label: "chore",
        description: "Configuration and tooling (build, dependencies, CI/CD)"
      },
      {
        label: "hotfix",
        description: "Emergency fixes (production issues, security)"
      }
    ]
  }]
})
```

After type selection, prompt for description:
- Use Read tool if description file provided
- Otherwise, use text input from AskUserQuestion "Other" option

## Error Handling

### Validation Errors

If branch-type invalid:
```bash
echo "ERROR [branch.md:validate]: Invalid branch type"
echo "  Input: $branch_type"
echo "  Allowed: feature, fix, refactor, docs, chore, hotfix"
exit 1
```

If description contains path traversal:
```bash
echo "ERROR [branch.md:sanitize]: Path traversal detected"
echo "  Input contains: .."
echo "  Reason: Security restriction"
exit 2
```

If final format invalid:
```bash
echo "ERROR [branch.md:validate]: Invalid branch name format"
echo "  Generated: $BRANCH_NAME"
echo "  Expected: {type}/{kebab-case-description}"
exit 2
```

### Execution Errors

If not in git repository:
```bash
echo "ERROR [branch.md:git_check]: Not a git repository"
echo "  Suggestion: Run 'git init' first"
exit 3
```

If uncommitted changes detected:
```typescript
AskUserQuestion({
  questions: [{
    question: "Uncommitted changes detected. How to proceed?",
    header: "Changes",
    multiSelect: false,
    options: [
      { label: "stash", description: "Temporarily save changes" },
      { label: "commit", description: "Commit changes first" },
      { label: "cancel", description: "Cancel branch creation" }
    ]
  }]
})
```

Execute based on selection:
- stash: `git stash push -m "Auto-stash for branch ${branch_name}"`
- commit: `git add . && git commit -m "WIP: save work before ${branch_name}"`
- cancel: Exit

If branch already exists:
```bash
# git checkout -b will fail automatically with clear error
echo "ERROR [branch.md:git_create]: Branch already exists"
echo "  Branch name: $BRANCH_NAME"
echo "  Suggestions: ${BRANCH_NAME}-v2, ${BRANCH_NAME}-$(date +%Y%m%d)"
exit 3
```

If network issues during push:
```bash
echo "ERROR [branch.md:git_push]: Push failed due to network issues"
echo "  Local branch created successfully: $BRANCH_NAME"
echo "  Retry command: git push -u origin \"${BRANCH_NAME}\""
exit 3
```

### Security

Never expose in error messages:
- Absolute file paths
- Stack traces
- Internal system details
- Environment variables

Report only:
- Error type (validation, git operation, network)
- User-actionable guidance
- Sanitized branch names only

## Tool Usage

TodoWrite: Not required (< 3 steps, fast execution)
AskUserQuestion: Required for interactive mode and uncommitted changes
Bash: Required for git operations
Read: Optional for reading description from file

## Exit Code System

```bash
# 0: Success - Branch created and pushed successfully
# 1: User error - Invalid branch type, invalid format
# 2: Security error - Special characters detected, validation failure
# 3: System error - Git command failed, network error
# 4: Unrecoverable error - Critical git operation failure
```

## Examples

```bash
# Basic usage
/branch feature user-login

# With spaces (auto-sanitized to kebab-case)
/branch fix "Bug in API"  # → fix/bug-in-api

# Interactive mode (no arguments)
/branch

# Invalid type (triggers exit 1)
/branch invalid test
```
