---
allowed-tools: Bash, AskUserQuestion, TodoWrite, Read
argument-hint: "[branch-name] [title]"
description: Create GitHub PR/GitLab MR with automatic platform detection
---

# Ship - Unified PR/MR Creation Command

Create GitHub Pull Request or GitLab Merge Request with automatic platform detection.

Arguments: $ARGUMENTS

## Platform Detection

Automatically detect platform from git remote URL:
```bash
# Platform detection function (single source of truth)
detect_platform() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null) || {
    echo "ERROR: Git remote not found"
    echo "File: ship.md:16 - detect_platform()"
    echo ""
    echo "Ensure you are in a git repository with a remote configured"
    echo "Run: git remote -v"
    exit $EXIT_UNRECOVERABLE
  }

  case "$remote_url" in
    *github.com*)
      echo "github gh"
      ;;
    *gitlab*)
      echo "gitlab glab"
      ;;
    *)
      echo "ERROR: Unsupported platform: $remote_url"
      echo "File: ship.md:16 - detect_platform()"
      echo ""
      echo "Supported platforms:"
      echo "  - GitHub (github.com)"
      echo "  - GitLab (gitlab.com, self-hosted GitLab)"
      exit $EXIT_UNRECOVERABLE
      ;;
  esac
}

# Usage
read -r PLATFORM CLI_CMD <<< "$(detect_platform)"
```

## Argument Processing

Parse from $ARGUMENTS:
- Extract branch-name (first token, optional)
- Extract title (remaining tokens, optional)
- If $ARGUMENTS empty: interactive mode
- Validate title format: `<type>(<scope>): <subject>` pattern

## Security Implementation

**MANDATORY: Execute these validations BEFORE ANY PR/MR creation**

```bash
# Exit code constants (single source of truth)
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_SYSTEM_ERROR=3
readonly EXIT_UNRECOVERABLE=4

# 1. Validate branch name (prevent path traversal)
validate_branch_name() {
  local branch="$1"

  # Empty check
  if [[ -z "$branch" ]]; then
    echo "ERROR: Branch name required"
    echo "File: ship.md:55 - validate_branch_name()"
    exit $EXIT_USER_ERROR
  fi

  # Path traversal detection
  if [[ "$branch" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected in branch name: $branch"
    echo "File: ship.md:61 - validate_branch_name()"
    echo ""
    echo "Security policy: Branch names must not contain '..'"
    exit $EXIT_SECURITY_ERROR
  fi

  # Whitelist validation: alphanumeric, -, _, /
  if [[ ! "$branch" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
    echo "ERROR: Invalid branch name format: $branch"
    echo "File: ship.md:70 - validate_branch_name()"
    echo ""
    echo "Allowed characters: a-z, A-Z, 0-9, -, _, /"
    echo "Example: feature/user-profile, fix/auth-bug"
    exit $EXIT_USER_ERROR
  fi

  # Verify branch exists
  if ! git rev-parse --verify "$branch" &>/dev/null; then
    echo "ERROR: Branch does not exist: $branch"
    echo "File: ship.md:81 - validate_branch_name()"
    echo ""
    echo "Available branches:"
    git branch --list | head -10
    exit $EXIT_USER_ERROR
  fi

  echo "✓ Branch validation passed ($branch)"
  return 0
}

# 2. Validate PR/MR title format (Conventional Commits)
validate_title_format() {
  local title="$1"

  # Empty check
  if [[ -z "$title" ]]; then
    echo "ERROR: PR/MR title required"
    echo "File: ship.md:97 - validate_title_format()"
    exit $EXIT_USER_ERROR
  fi

  # Input length check BEFORE regex (ReDoS protection)
  if [[ ${#title} -gt 200 ]]; then
    echo "ERROR: Title too long (${#title} chars, max 200)"
    echo "File: ship.md:104 - validate_title_format()"
    echo ""
    echo "Conventional Commits titles should be concise"
    echo "Recommended length: 50-72 characters"
    exit $EXIT_USER_ERROR
  fi

  # Centralized type definitions (single source of truth)
  local allowed_types=("feat" "fix" "refactor" "docs" "style" "test" "chore" "perf" "hotfix")
  local type_regex=$(IFS="|"; echo "${allowed_types[*]}")

  # Conventional Commits format: type(scope): subject (with bounded quantifier)
  if [[ ! "$title" =~ ^($type_regex)(\([a-z0-9_-]+\))?:[[:space:]].{1,150}$ ]]; then
    echo "ERROR: Invalid Conventional Commits format"
    echo "File: ship.md:120 - validate_title_format()"
    echo ""
    echo "Expected: <type>(<scope>): <subject>"
    echo "Got: $title"
    echo ""
    echo "Valid types: ${allowed_types[*]}"
    echo "Example: feat(ui): add user profile editor"
    exit $EXIT_USER_ERROR
  fi

  # Subject length validation (max 72 characters after type/scope)
  local subject="${title#*: }"
  if [[ ${#subject} -gt 72 ]]; then
    echo "ERROR: Subject too long (${#subject} chars, max 72)"
    echo "File: ship.md:134 - validate_title_format()"
    echo ""
    echo "Subject: $subject"
    exit $EXIT_USER_ERROR
  fi

  # Detect command injection attempts (comprehensive)
  local dangerous_pattern='[`$(){};|><&]'
  if [[ "$title" =~ $dangerous_pattern ]]; then
    echo "ERROR: Dangerous characters detected in title"
    echo "File: ship.md:143 - validate_title_format()"
    echo ""
    echo "Security policy: Special shell characters not allowed"
    echo "Blocked characters: \` \$ ( ) { } ; | > < &"
    echo ""
    echo "Example valid title: feat(ui): add user profile editor"
    exit $EXIT_SECURITY_ERROR
  fi

  echo "✓ Title format validation passed"
  return 0
}

# 3. Validate CLI authentication
validate_cli_authentication() {
  local cli_cmd="$1"
  local platform="$2"

  # Check CLI availability
  if ! command -v "$cli_cmd" &>/dev/null; then
    echo "ERROR: $platform CLI not installed ($cli_cmd)"
    echo "File: ship.md:164 - validate_cli_authentication()"
    echo ""
    echo "Installation:"
    if [[ "$platform" == "github" ]]; then
      echo "  brew install gh"
      echo "  gh auth login"
    else
      echo "  brew install glab"
      echo "  glab auth login"
    fi
    exit $EXIT_SYSTEM_ERROR
  fi

  # Check authentication status
  if ! "$cli_cmd" auth status &>/dev/null; then
    echo "ERROR: $platform CLI not authenticated"
    echo "File: ship.md:179 - validate_cli_authentication()"
    echo ""
    echo "Authentication required:"
    echo "  $cli_cmd auth login"
    echo ""
    echo "Follow the prompts to authenticate with $platform"
    exit $EXIT_SYSTEM_ERROR
  fi

  echo "✓ CLI authentication verified ($cli_cmd)"
  return 0
}

# 4. Template secret detection
detect_template_secrets() {
  local template_content="$1"

  # Hardcoded secrets patterns (from commit.md)
  if echo "$template_content" | grep -qiE "(api[_-]?key|password|secret|token|bearer|auth).{0,10}[=:].{8,}"; then
    echo "WARNING: Possible secret detected in PR/MR template"
    echo ""
    echo "Security risk: Secrets in templates are publicly visible"
    echo "Review template carefully before creating PR/MR"
    echo ""
    read -p "Continue anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "PR/MR creation aborted"
      exit 2
    fi
  fi

  return 0
}

# 5. Safe argument parsing
# Sanitize input BEFORE array expansion
ARGUMENTS_SAFE=$(echo "$ARGUMENTS" | tr -d '\n\r\t' | xargs)

# Global validation BEFORE parsing
dangerous_args_pattern='[`${}()]'
if [[ "$ARGUMENTS_SAFE" =~ $dangerous_args_pattern ]]; then
  echo "ERROR: Dangerous characters in arguments"
  echo "File: ship.md:207 - Argument Processing"
  echo ""
  echo "Security policy: Command substitution and variable expansion not allowed"
  exit $EXIT_SECURITY_ERROR
fi

# Safe array expansion
IFS=' ' read -r -a args <<< "$ARGUMENTS_SAFE"
BRANCH_NAME="${args[0]}"
TITLE="${args[*]:1}"

# Validate inputs
if [[ -n "$BRANCH_NAME" ]]; then
  validate_branch_name "$BRANCH_NAME"
fi

if [[ -n "$TITLE" ]]; then
  validate_title_format "$TITLE"
fi
```

**Execution order**:
1. validate_branch_name "$BRANCH_NAME" (if provided)
2. validate_title_format "$TITLE" (if provided)
3. validate_cli_authentication "$CLI_CMD" "$PLATFORM"
4. detect_template_secrets "$TEMPLATE_CONTENT" (before PR/MR creation)

**Exit codes** (use constants defined at L43-47):
- EXIT_SUCCESS (0): Success
- EXIT_USER_ERROR (1): User error (invalid format, branch not found)
- EXIT_SECURITY_ERROR (2): Security error (path traversal, command injection, secrets detected)
- EXIT_SYSTEM_ERROR (3): System error (CLI not installed, authentication failed)
- EXIT_UNRECOVERABLE (4): Unrecoverable error (platform detection failed)

## Execution Flow

### 1. Platform & Branch Detection
1. Detect platform (GitHub/GitLab) from remote URL
2. Verify CLI tool installed (gh/glab)
3. Get current branch: `git branch --show-current`
4. Validate git repository and remote

### 2. Argument Handling
**If arguments provided:**
- Validate current branch matches `[branch-name]` from $ARGUMENTS
- Parse and validate `[title]` from $ARGUMENTS for Conventional Commits format
- Auto-detect project type and requirements

**If no arguments (interactive mode):**
- Detect current branch automatically
- Use AskUserQuestion for PR/MR details
- Guide through quality checklist

### 3. Pre-Ship Quality Checks
**Automated validation:**
- Uncommitted changes check: `git status --porcelain`
- Branch push status verification
- Project-specific quality commands execution

### 4. PR/MR Creation with Template
**Template detection priority:**

For GitHub:
1. `.github/pull_request_template.md` (project-specific)
2. `~/.github/PULL_REQUEST_TEMPLATE.md` (global fallback)
3. Built-in template (auto-generated)

For GitLab:
1. `.gitlab/merge_request_template.md` (project-specific)
2. `~/.gitlab/merge_request_template.md` (global fallback)
3. Built-in template (auto-generated)

**Template loading logic:**
```bash
# Unified template loading function (eliminates GitHub/GitLab duplication)
load_template() {
  local platform="$1"
  local project_template local_template

  # Platform-specific paths
  if [[ "$platform" == "github" ]]; then
    project_template=".github/pull_request_template.md"
    local_template="$HOME/.github/PULL_REQUEST_TEMPLATE.md"
  else
    project_template=".gitlab/merge_request_template.md"
    local_template="$HOME/.gitlab/merge_request_template.md"
  fi

  # 3-tier fallback: Project → Global → Built-in
  if [[ -f "$project_template" ]]; then
    cat "$project_template"
  elif [[ -f "$local_template" ]]; then
    cat "$local_template"
  else
    echo "[Auto-generated built-in template]"
  fi
}

# Usage
TEMPLATE=$(load_template "$PLATFORM")

# Security check: Detect secrets in template
detect_template_secrets "$TEMPLATE"
```

### 5. Draft Creation & Verification
```bash
# GitHub
gh pr create --draft --title "title" --body "template"
gh pr view --web

# GitLab
glab mr create --draft --title "title" --description "template"
glab mr view --web
```

## Template Priority & Detection

### Template Sources
1. **Project-specific template**: Platform-specific location (highest priority)
2. **Global template**: User home directory (fallback)
3. **Built-in template**: Auto-generated with detailed quality checklist
4. **Detailed guidelines**: `@<project>/docs/{PR,MR}_GUIDELINES.md` (reference)

## Interactive Creation (AskUserQuestion Integration)

### Primary Question: Type & Title
```typescript
AskUserQuestion({
  questions: [{
    question: "Select change type and set title",
    header: "Ship Type",
    multiSelect: false,
    options: [
      {
        label: "feature",
        description: "New feature (UI, API, integration)"
      },
      {
        label: "fix",
        description: "Bug fix (functional issues, performance problems)"
      },
      {
        label: "refactor",
        description: "Code improvement (structure, optimization)"
      },
      {
        label: "docs",
        description: "Documentation (README, API specs, comments)"
      },
      {
        label: "chore",
        description: "Configuration (build, dependencies, CI/CD)"
      },
      {
        label: "hotfix",
        description: "Critical fix (production issues, security)"
      }
    ]
  }]
})
```

### Secondary Question: Scope & Priority
```typescript
AskUserQuestion({
  questions: [{
    question: "Select change scope",
    header: "Scope",
    multiSelect: false,
    options: [
      { label: "ui", description: "UI components, frontend" },
      { label: "api", description: "API, backend, data layer" },
      { label: "core", description: "Core logic, business logic" },
      { label: "config", description: "Configuration, build, infrastructure" },
      { label: "docs", description: "Documentation, comments" },
      { label: "test", description: "Testing, quality assurance" }
    ]
  }]
})
```

## Required Rules & Quality Gates

### Basic Requirements
- [ ] Create as draft (`--draft` option required)
- [ ] Conventional Commits format for title (`<type>(<scope>): <subject>`)
- [ ] Use `--set-upstream` on first push (`git push -u origin <branch>`)
- [ ] Complete checklist following template

### Project Quality Checks
- [ ] TypeScript projects: `npm run typecheck` success
- [ ] ESLint: `npm run lint` zero errors (warnings acceptable)
- [ ] Tests: `npm test` or `npm run test` success
- [ ] Build: `npm run build` success
- [ ] Other project-specific CI/CD checks

## Automated Pre-Ship Quality Execution

### Quality Command Execution Flow

**Delegate to /validate command for consistency:**

```bash
# 1. Uncommitted changes check (prerequisite, must run first)
UNCOMMITTED=$(git status --porcelain)
if [[ -n "$UNCOMMITTED" ]]; then
  echo "WARNING: Uncommitted changes detected"
  echo "File: ship.md:448 - Pre-Ship Quality Checks"
  echo ""
  echo "$UNCOMMITTED"
  echo ""
  read -p "Continue with uncommitted changes? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "PR/MR creation aborted"
    exit $EXIT_USER_ERROR
  fi
fi

# 2. Delegate quality checks to /validate command
# Benefits:
# - Single source of truth for quality standards
# - Automatic updates when /validate improves
# - Consistent behavior across all commands
echo "🔍 Running quality checks..."
SlashCommand("/validate --layers=syntax --auto-fix")
VALIDATE_EXIT=$?

if [[ $VALIDATE_EXIT -ne 0 ]]; then
  echo "❌ Quality checks failed"
  echo "File: ship.md:465 - Pre-Ship Quality Checks"
  echo ""
  echo "Fix errors before creating PR/MR, or use --skip-checks flag"
  exit $EXIT_USER_ERROR
fi

echo "✅ All quality checks passed"
```

**Benefits of delegation:**
- **Maintainability:** Single source of truth (70 lines reduced to 10 lines)
- **Consistency:** Same quality standards across `/validate`, `/ship`, `/commit`
- **Evolution:** Automatic improvements when `/validate` is enhanced

### General Project Examples

#### Frontend Development
```bash
# Branch: feature/user-profile-page
# Title: feat(ui): add user profile management page
# Scope: ui
# Focus: UI components, styling, user interactions
```

#### Backend Development
```bash
# Branch: fix/api-authentication-bug
# Title: fix(api): resolve authentication token validation
# Scope: api
# Focus: API endpoints, data validation, security
```

#### Infrastructure/Config
```bash
# Branch: chore/ci-pipeline-optimization
# Title: chore(config): optimize CI/CD pipeline performance
# Scope: config
# Focus: Build tools, deployment, configuration
```

## Enhanced Command Flow

### 1. Automated Branch Analysis
```bash
# Current branch detection
CURRENT_BRANCH=$(git branch --show-current)

# Branch type extraction (using safe parameter expansion)
BRANCH_TYPE="${CURRENT_BRANCH%%/*}"

# Description extraction (using safe parameter expansion)
BRANCH_DESC="${CURRENT_BRANCH#*/}"
```

### 2. Interactive Creation (No Arguments)
```bash
# If no arguments provided, guide through interactive process:
# 1. AskUserQuestion for type
# 2. AskUserQuestion for scope
# 3. Auto-generate title from selections
# 4. Execute quality checks
# 5. Create draft PR/MR with template
```

### 3. Direct Creation (With Arguments)
```bash
# Validate provided arguments
# Execute quality checks
# Create PR/MR immediately

# GitHub
gh pr create --draft --title "provided-title" --body "template"

# GitLab
glab mr create --draft --title "provided-title" --description "template"
```

## Conventional Commits Format

**Type definitions are centralized in validate_title_format() function (L116).**

Supported types: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`, `hotfix`

**Examples:**
- `feat(auth): implement login functionality`
- `fix(api): resolve response error handling`
- `refactor(ui): improve component structure`

## Update & Edit

### GitHub - Update PR Title/Description
```bash
# Update both title and description
gh pr edit <PR-number> --title "New title" --body "New description"

# Update title only
gh pr edit <PR-number> --title "New title"

# Update description only
gh pr edit <PR-number> --body "New description"
```

### GitLab - Update MR Title/Description
```bash
# Update both title and description
glab mr update <MR-number> --title "New title" --description "New description"
```

### Status Changes
```bash
# GitHub: Mark ready for review
gh pr ready <PR-number>

# GitHub: Convert to draft
gh pr edit <PR-number> --draft

# GitLab: Mark ready for review
glab mr update <MR-number> --ready

# GitLab: Convert to draft
glab mr update <MR-number> --draft
```

## Exit Code System

```bash
# 0: Success - PR/MR created successfully
# 1: User error - Invalid arguments, Conventional Commits format error
# 2: Security error - Branch name validation failed
# 3: System error - CLI tool not found, git push failed
# 4: Unrecoverable error - Platform detection failed, critical error
```

## Output Format

**Success example**:
```
✓ Pull Request created successfully
✓ Platform: GitHub
✓ Branch: feature/user-profile-edit
✓ Status: Draft
✓ URL: https://github.com/org/repo/pull/123

Quality Checks:
  ✓ TypeScript: 0 errors
  ✓ ESLint: 0 errors
  ✓ Tests: All passed

Next steps:
  1. Review PR checklist
  2. Request reviews when ready
  3. Mark as ready: gh pr ready 123
```

**Error example**:
```
ERROR: Conventional Commits format invalid
File: ship.md:validate_commit_format

Reason: PR title does not follow Conventional Commits format
Got: "Add user profile feature"
Expected: "feat(profile): add user profile editing feature"

Suggestions:
1. Use format: <type>(<scope>): <subject>
2. Valid types: feat, fix, refactor, docs, chore, hotfix
3. Example: feat(ui): add dark mode toggle
```

## Bash Syntax Examples

```bash
# Safe branch name extraction
CURRENT_BRANCH=$(git branch --show-current)
BRANCH_TYPE="${CURRENT_BRANCH%%/*}"
BRANCH_DESC="${CURRENT_BRANCH#*/}"

# Platform detection (use detect_platform() function defined at L18-46)
read -r PLATFORM CLI_CMD <<< "$(detect_platform)"

# Safe PR/MR creation with heredoc
if [[ "$PLATFORM" == "github" ]]; then
  gh pr create --draft --title "$TITLE" --body "$(cat <<'EOF'
$TEMPLATE_CONTENT
EOF
)"
fi
```

## Error Handling

### Argument validation errors
If required argument missing: use AskUserQuestion for interactive input
If invalid Conventional Commits format: report expected format with example
If branch name invalid: report error and show current branch

### Execution errors
If platform unsupported: report "Unsupported git platform. Only GitHub and GitLab are supported."
If CLI tool not found (gh/glab): report installation command for detected platform
If git push fails: report push error and verify remote branch exists
If PR/MR creation fails: report specific error from CLI output

### Security
Never expose absolute file paths in error messages
Never expose stack traces or internal details
Report only user-actionable information (command syntax, required format, etc.)

## Project-Specific Requirements

If project has `docs/PR_GUIDELINES.md` or `docs/MR_GUIDELINES.md`, refer to those documents for additional requirements.

## Command Examples

### Example 1: Complete Ship Flow (Interactive Mode)
```bash
# 1. Create branch
git checkout -b feat/user-profile-edit

# 2. Make changes and commit
git add .
git commit -m "feat(profile): add user profile editing feature"

# 3. Push to remote
git push -u origin feat/user-profile-edit

# 4. Create PR/MR (interactive mode)
/ship

# Output:
# ✓ Platform detected: GitHub
# ✓ Current branch: feat/user-profile-edit
# ✓ CLI authentication verified (gh)
# 🔍 Running quality checks in parallel...
#
# Quality Check Results:
#   TypeScript: 0 errors
#   ESLint: 0 errors
#   Tests: 0 failures
#   Build: 0 errors
#
# ✅ All quality checks passed
#
# [AskUserQuestion prompts for type and scope]
# ✓ Pull Request created successfully
# ✓ Status: Draft
# ✓ URL: https://github.com/org/repo/pull/123

# 5. Mark ready when review-ready
gh pr ready 123
```

### Example 2: Direct Creation with Arguments (GitHub)

**Success case:**
```bash
/ship feat/user-profile-edit "feat(profile): add user profile editing feature"

# Output:
# ✓ Branch validation passed (feat/user-profile-edit)
# ✓ Title format validation passed
# ✓ CLI authentication verified (gh)
# ✓ Template loaded from .github/pull_request_template.md
# ✅ All quality checks passed
# ✓ Pull Request created successfully
# ✓ URL: https://github.com/org/repo/pull/124
```

**Error case - Security validation:**
```bash
/ship ../../../etc/passwd "feat: malicious PR"

# Output:
# ERROR: Path traversal detected in branch name: ../../../etc/passwd
# File: ship.md:61 - validate_branch_name()
#
# Security policy: Branch names must not contain '..'
# Exit code: 2 (Security error)
```

### Example 3: GitLab MR Creation
```bash
# On GitLab repository
git checkout -b fix/api-timeout-issue
git add .
git commit -m "fix(api): resolve timeout in payment processing"
git push -u origin fix/api-timeout-issue

/ship

# Output:
# ✓ Platform detected: GitLab
# ✓ Current branch: fix/api-timeout-issue
# ✓ CLI authentication verified (glab)
# ✅ All quality checks passed
# ✓ Merge Request created successfully
# ✓ Status: Draft
# ✓ URL: https://gitlab.com/org/project/-/merge_requests/45

# Mark ready
glab mr update --ready
```

### Example 4: Security - CLI Authentication Required
```bash
/ship feat/new-feature "feat(ui): add dashboard"

# Output (if not authenticated):
# ERROR: github CLI not authenticated
#
# Authentication required:
#   gh auth login
#
# Follow the prompts to authenticate with github
# Exit code: 3 (System error)

# Recovery:
gh auth login
# [Follow authentication flow]
/ship feat/new-feature "feat(ui): add dashboard"
# ✅ Success
```

### Example 6: Quality Checks Failure
```bash
/ship feat/broken-feature "feat(ui): add feature"

# Output:
# ✓ Branch validation passed (feat/broken-feature)
# ✓ Title format validation passed
# ✓ CLI authentication verified (gh)
# 🔍 Running quality checks in parallel...
#
# Quality Check Results:
#   TypeScript: 5 errors
#   ESLint: 12 errors
#   Tests: 3 failures
#   Build: 2 errors
#
# ❌ Quality checks failed (22 issues)
# Fix errors before creating PR/MR, or use --skip-checks flag
# Exit code: 1 (User error)

# Fix errors, then retry:
npm run typecheck  # Fix TS errors
npm run lint:fix   # Auto-fix ESLint
npm run test       # Fix failing tests
/ship feat/broken-feature "feat(ui): add feature"
# ✅ Success after fixes
```

### Example 7: Conventional Commits Format Error
```bash
/ship feat/user-settings "Add user settings page"

# Output:
# ✓ Branch validation passed (feat/user-settings)
# ERROR: Invalid Conventional Commits format
# Expected: <type>(<scope>): <subject>
# Got: Add user settings page
#
# Valid types: feat fix refactor docs style test chore perf hotfix
# Example: feat(ui): add user profile editor
# Exit code: 1 (User error)

# Correct format:
/ship feat/user-settings "feat(ui): add user settings page"
# ✅ Success
```

## Important Notes

1. **Always create as draft** (until review-ready)
2. **Prepare detailed description using template** (avoid interactive mode)
3. **Follow Conventional Commits for branch names and commit messages**
4. **Complete checklist following project template**
5. **Platform auto-detection** (supports both GitHub and GitLab)

## Platform-Specific Notes

### GitHub
- CLI: `gh` (GitHub CLI)
- Update command: `gh pr edit`
- Ready command: `gh pr ready`
- Template: `.github/pull_request_template.md`

### GitLab
- CLI: `glab` (GitLab CLI)
- Update command: `glab mr update`
- Ready command: `glab mr update --ready`
- Template: `.gitlab/merge_request_template.md`
