---
allowed-tools: AskUserQuestion, TodoWrite
argument-hint: "[message] | --no-verify | --amend"
description: Create Conventional Commits with emoji formatting through interactive guidance
model: sonnet
---

# Git Commit Command

Create well-formatted commit: $ARGUMENTS

## Execution Flow

1. Parse arguments from $ARGUMENTS
2. If message provided: validate Conventional Commits format and add emoji
3. If no message: use AskUserQuestion to select commit type and scope
4. Generate commit message with appropriate emoji
5. Validate message format (length, structure)
6. Execute git commit with generated message
7. Verify commit created and report next steps

## Argument Validation

Parse $ARGUMENTS:
- Extract message if provided
- Detect flags: --no-verify, --amend
- Validate message format if provided

If message provided:
- Check Conventional Commits format: `type(scope): subject`
- Validate type against allowed list
- Ensure subject length under 72 characters

If validation fails: report error with correct format and examples

## Commit Type Selection

Use AskUserQuestion to determine commit type with emoji:

Question: "Select commit type"
Header: "Type"
Options:
1. feat: New feature (user-facing functionality)
2. fix: Bug fix (user-facing issue resolution)
3. refactor: Code refactoring (no functional changes)
4. docs: Documentation changes only
5. style: Code style changes (formatting, semicolons, etc.)
6. test: Add or modify tests
7. chore: Build, configuration, dependency updates
8. perf: Performance improvements

Each type has associated emoji:
- feat: ✨
- fix: 🐛
- refactor: ♻️
- docs: 📝
- style: 💄
- test: ✅
- chore: 🔧
- perf: ⚡️

## Scope Selection

Use AskUserQuestion to determine scope:

Question: "Select scope (area of change)"
Header: "Scope"
Options:
1. ui: UI components, styling changes
2. api: API, backend, data layer changes
3. core: Core logic, business logic changes
4. config: Configuration, build, tool changes
5. docs: Documentation, comment changes
6. test: Test-related changes
7. none: No specific scope (multiple areas or global changes)

LLM should analyze changed files (via git status/diff) to suggest appropriate scope.

## Message Generation

Based on selected type and scope:

1. Retrieve emoji for type
2. Format message: `<emoji> <type>(<scope>): <subject>`
   - If scope is "none": `<emoji> <type>: <subject>`
3. Validate format:
   - Subject starts with lowercase (except proper nouns)
   - Subject length under 72 characters
   - No period at end of subject

Example generated messages:
- `✨ feat(ui): add user profile editor`
- `🐛 fix(api): resolve authentication timeout`
- `📝 docs: update installation guide`
- `♻️ refactor(core): optimize state management`

## Git Commit Execution

Execute commit with generated message:

```bash
git commit -m "<generated-message>"
```

Flags:
- If --no-verify in $ARGUMENTS: add --no-verify flag (skips pre-commit hooks)
- If --amend in $ARGUMENTS: add --amend flag (amends last commit)

After commit:
- Verify commit created: `git log -1 --oneline`
- Report commit hash and message

## Error Handling

Argument errors:
If invalid format: report "Conventional Commits format required: type(scope): subject"
If unknown type: report "Allowed types: feat, fix, refactor, docs, style, test, chore, perf"
If subject too long: report "Subject must be under 72 characters, got: [length]"

Execution errors:
If no staged files: report "No staged files. Use 'git add' to stage changes first"
If git commit fails: report git error message and suggest resolution
If unrecoverable error: report error type and user-actionable guidance

Security:
Never expose absolute file paths in error messages
Never expose stack traces or internal details
Report only user-actionable information



## Examples

/commit "feat(ui): add user profile component" → Execute commit with "✨ feat(ui): add user profile component"
/commit → Interactive mode, use AskUserQuestion to select type and scope
/commit "update docs" → Report error "Conventional Commits format required: type(scope): subject"

## Security Implementation

**MANDATORY: Execute these validations BEFORE ANY commit operation**

```bash
# 1. Validate protected branches (prevent direct commits to main/master)
validate_protected_branch() {
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [[ -z "$current_branch" ]]; then
    echo "ERROR: Not in a git repository"
    exit 3
  fi

  # Protected branch patterns (use variable to avoid regex parsing issues)
  local protected_pattern='^(main|master)$'
  if [[ "$current_branch" =~ $protected_pattern ]]; then
    echo "ERROR: Direct commits to '$current_branch' are not allowed"
    echo "Security policy: Use feature branches for development"
    echo ""
    echo "Create a feature branch:"
    echo "  /branch feature your-feature-name"
    echo "  git checkout -b feature/your-feature-name"
    exit 2
  fi

  echo "✓ Branch validation passed ($current_branch)"
  return 0
}

# 2. Validate sensitive files (prevent accidental commit of secrets)
validate_sensitive_files() {
  # Sensitive file patterns (from review-pr.md)
  local sensitive_patterns=(.env .envrc .env.* credentials.* secrets.* *.pem *.key id_rsa .ssh/*)
  local staged_files=$(git diff --cached --name-only 2>/dev/null)

  if [[ -z "$staged_files" ]]; then
    echo "ERROR: No staged files"
    echo "Stage changes first: git add <files>"
    exit 1
  fi

  # Check each staged file against sensitive patterns
  for file in $staged_files; do
    for pattern in "${sensitive_patterns[@]}"; do
      if [[ "$file" == $pattern ]]; then
        echo "ERROR: Sensitive file detected: $file"
        echo "Security policy: Sensitive files must not be committed"
        echo ""
        echo "Resolution:"
        echo "  1. Unstage file: git reset HEAD $file"
        echo "  2. Add to .gitignore: echo '$file' >> .gitignore"
        echo "  3. Use environment variables instead"
        exit 2
      fi
    done
  done

  echo "✓ Sensitive file validation passed"
  return 0
}

# 3. Validate Conventional Commit format
validate_conventional_commit() {
  local message="$1"

  # Centralized type definitions (single source of truth)
  local allowed_types=("feat" "fix" "refactor" "docs" "style" "test" "chore" "perf")
  local type_regex=$(IFS="|"; echo "${allowed_types[*]}")

  # Check format: type(scope): subject (use variable to avoid regex parsing issues)
  local format_pattern="^($type_regex)(\([a-z0-9_-]+\))?:\ .+"
  if [[ ! "$message" =~ $format_pattern ]]; then
    echo "ERROR: Invalid Conventional Commit format"
    echo "Expected: type(scope): subject"
    echo "Got: $message"
    return 1
  fi

  # Check subject length (max 72 characters after type/scope)
  local subject=$(echo "$message" | sed 's/^[^:]*: //')
  if [[ ${#subject} -gt 72 ]]; then
    echo "ERROR: Subject too long (${#subject} chars, max 72)"
    return 1
  fi

  # Check subject doesn't end with period
  if [[ "$subject" =~ \.$ ]]; then
    echo "ERROR: Subject should not end with period"
    return 1
  fi

  echo "✓ Conventional Commit format valid"
  return 0
}

# 2. Handle pre-commit hook failures
handle_pre_commit_hook() {
  local hook_result="$1"

  if [[ $hook_result -eq 0 ]]; then
    echo "✓ Pre-commit hooks passed"
    return 0
  fi

  # Detect hook failure type
  echo "ERROR: Pre-commit hook failed (exit code: $hook_result)"

  # Check for common hook failures
  if git diff --cached --name-only | grep -q "\.ts$\|\.tsx$"; then
    echo "Likely cause: TypeScript type errors"
    echo "Fix: npm run type-check"
  fi

  if git diff --cached --name-only | grep -q "\.js$\|\.jsx$\|\.ts$\|\.tsx$"; then
    echo "Likely cause: ESLint errors"
    echo "Fix: npm run lint:fix"
  fi

  return $hook_result
}

# 3. Validate GPG signature (if enabled)
validate_gpg_signature() {
  # Check if commit signing is configured
  local sign_commits=$(git config --get commit.gpgsign)

  if [[ "$sign_commits" == "true" ]]; then
    # Verify GPG key is available
    if ! git config --get user.signingkey >/dev/null; then
      echo "ERROR: GPG signing enabled but no signing key configured"
      echo "Fix: git config user.signingkey YOUR_KEY_ID"
      return 2
    fi

    echo "✓ GPG signature validation enabled"
  fi

  return 0
}

# 4. Safe argument parsing
IFS=' ' read -r -a args <<< "$ARGUMENTS"
COMMIT_MSG="${args[0]}"
COMMIT_FLAGS=("${args[@]:1}")

# Sanitize commit message (allow alphanumeric, spaces, common punctuation)
if [[ -n "$COMMIT_MSG" ]]; then
  # Detect command injection attempts (use variable to avoid regex parsing issues)
  local dangerous_chars='[\`\$\(]'
  if [[ "$COMMIT_MSG" =~ $dangerous_chars ]]; then
    echo "ERROR: Dangerous characters detected in commit message"
    exit 2
  fi

  # Detect hardcoded secrets in commit message (use variable to avoid regex parsing issues)
  local secret_pattern='(api[_-]?key|password|secret|token|bearer|auth).{0,10}[=:].{8,}'
  if [[ "$COMMIT_MSG" =~ $secret_pattern ]]; then
    echo "WARNING: Possible secret detected in commit message"
    echo "Pattern matched: ${BASH_REMATCH[0]}"
    echo ""
    echo "Security risk: Secrets in commit messages are publicly visible"
    echo "Review message carefully before committing"
    echo ""
    read -p "Continue anyway? (y/N): " confirm
    local confirm_pattern='^[Yy]$'
    if [[ ! "$confirm" =~ $confirm_pattern ]]; then
      echo "Commit aborted"
      exit 2
    fi
  fi
fi
```

## Exit Code System

```bash
# 0: Success - Commit created successfully
# 1: User error - Invalid format, no staged files
# 2: Security error - Dangerous characters, GPG key missing
# 3: System error - Git command failed, hook execution error
# 4: Unrecoverable error - Repository corruption
```

## Bash Syntax Examples

```bash
# Safe IFS usage for parsing commit message parts
IFS=':' read -r type_scope subject <<< "$COMMIT_MSG"

# Safe parameter expansion for commit components
COMMIT_TYPE="${type_scope%%(*}"           # Extract type before (
COMMIT_SCOPE="${type_scope#*(}"            # Extract after (
COMMIT_SCOPE="${COMMIT_SCOPE%)*}"          # Remove trailing )

# Exit code propagation with git commit
git commit -m "$COMMIT_MSG" "${COMMIT_FLAGS[@]}"
COMMIT_RESULT=$?
if [[ $COMMIT_RESULT -ne 0 ]]; then
  handle_pre_commit_hook $COMMIT_RESULT
  exit $COMMIT_RESULT
fi

# Verify commit was created
git log -1 --oneline
```

## Output Format Examples

**Success example**:
```
✓ Commit created successfully
✓ Format: Conventional Commits
✓ Pre-commit hooks: PASSED
✓ Signature: GPG signed

Commit details:
  Hash: a3f7b2c
  Type: feat
  Scope: ui
  Subject: add user profile editor
  Files: 3 modified, 128 insertions, 45 deletions

Next steps:
  1. Review commit: git show
  2. Amend if needed: /commit --amend
  3. Push changes: git push
  4. Create PR: /ship
```

**Error example**:
```
ERROR: Pre-commit hook failed
File: commit.md:handle_pre_commit_hook

Reason: TypeScript type errors detected
Got: 5 type errors in 2 files
Hook exit code: 1

Failed checks:
  ✗ TypeScript compilation (5 errors)
  ✗ ESLint (12 warnings)
  ✓ Prettier formatting

Affected files:
  - src/components/UserProfile.tsx (3 errors)
  - src/api/users.ts (2 errors)

Suggestions:
1. Fix type errors: npm run type-check
2. Auto-fix ESLint: npm run lint:fix
3. Skip hooks (NOT recommended): /commit --no-verify
4. Review errors in detail: cat type-check-output.log
```

---
