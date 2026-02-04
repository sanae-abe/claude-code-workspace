---
allowed-tools: Bash, Read, Write, Edit, Grep, TodoWrite, AskUserQuestion, Task
argument-hint: "<MR-number> [--detailed] [--security-focus] [--performance-focus] [--multi-perspective]"
description: "Comprehensive GitLab MR/GitHub PR review workflow - security-first systematic quality verification"
model: sonnet
---

# MR/PR Review Workflow

Review target: $ARGUMENTS

Comprehensive review workflow for GitLab Merge Requests and GitHub Pull Requests with security-first approach.

## Argument Validation

Execute validation before any operations:

```bash
# Validate and sanitize MR/PR number
validate_mr_number() {
  local mr_num="$1"

  # Empty check
  if [[ -z "$mr_num" ]]; then
    echo "ERROR: MR/PR number required"
    echo "Usage: /review-pr <number> [--detailed|--security-focus|--performance-focus|--multi-perspective]"
    echo "Example: /review-pr 123 --security-focus"
    exit 1
  fi

  # Numeric-only whitelist
  if [[ ! "$mr_num" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid MR/PR number format: $mr_num"
    echo "Expected: numeric value (e.g., 123)"
    exit 1
  fi

  # Length validation (max 10 digits for MR/PR numbers)
  if [[ ${#mr_num} -gt 10 ]]; then
    echo "ERROR: MR/PR number too long (max 10 digits)"
    exit 1
  fi

  echo "$mr_num"
}

# Validate flags
validate_flags() {
  local flags="$1"
  local allowed_flags="--detailed --security-focus --performance-focus --multi-perspective"

  for flag in $flags; do
    if [[ "$flag" =~ ^-- ]]; then
      if [[ ! "$allowed_flags" =~ "$flag" ]]; then
        echo "ERROR: Invalid flag: $flag"
        echo "Allowed flags: $allowed_flags"
        exit 1
      fi
    else
      echo "ERROR: Unexpected argument: $flag"
      echo "Only flags (starting with --) are allowed after MR/PR number"
      exit 1
    fi
  done
}

# Safe argument parsing
IFS=' ' read -r -a args <<< "$ARGUMENTS"
MR_NUMBER=$(validate_mr_number "${args[0]}")
FLAGS="${args[@]:1}"
validate_flags "$FLAGS"
```

If validation fails: exit with error code 1 (user error)

## Execution Flow

1. Parse MR number and options from $ARGUMENTS
2. Validate inputs (numeric MR number, valid flags)
3. Determine review mode (standard/detailed/security-focus)
4. Create TodoWrite for multi-step review plan
5. Execute review phases
6. Generate structured review report

## Review Phases

### Phase 1: MR Information and Branch Checkout

Execute parallel information gathering for efficiency (30-50% faster):

```bash
# Parallel execution: Fetch MR info and diff simultaneously
{
  MR_INFO=$($CLI_CMD pr view "$MR_NUMBER" 2>&1) &
  MR_DIFF=$($CLI_CMD pr diff "$MR_NUMBER" 2>&1) &
  wait
}

# Display MR information
echo "$MR_INFO"
echo ""
echo "Changed files preview:"
echo "$MR_DIFF" | head -20

# Sequential: Checkout branch (requires fetch to complete)
$CLI_CMD pr checkout "$MR_NUMBER"
```

1. Fetch MR information (parallel)
   - GitLab: `glab mr view {mr_number}`
   - GitHub: `gh pr view {pr_number}`
   - Diff: `glab mr diff {mr_number}` or `gh pr diff {pr_number}`

2. Checkout MR branch (sequential)
   - GitLab: `glab mr checkout {mr_number}`
   - GitHub: `gh pr checkout {pr_number}`

3. Verify basic information
   - Understand MR title and description
   - Identify change purpose and background
   - Determine impact scope

### Phase 2: Change Analysis

1. Review diff
   - GitLab: `glab mr diff {mr_number}`
   - GitHub: `gh pr diff {pr_number}`

2. Direct file verification with sensitive file exclusion

```bash
# Get changed files
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD)

# Sensitive file patterns (exclude from review)
SENSITIVE_PATTERNS=(.env .envrc .env.* credentials.* secrets.* *.pem *.key id_rsa .ssh/*)

# Read files with security filtering
for file in $CHANGED_FILES; do
  # Check if file matches sensitive patterns
  is_sensitive=false
  for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if [[ "$file" == $pattern ]]; then
      echo "WARNING: Sensitive file detected: $file (content not displayed for security)"
      echo "  - Verify this file should not be committed"
      echo "  - Check .gitignore configuration"
      is_sensitive=true
      break
    fi
  done

  # Skip sensitive files
  if [[ "$is_sensitive" == true ]]; then
    continue
  fi

  # Safe to read non-sensitive files
  if [[ -f "$file" ]]; then
    Read "$file"
    # Verify logic and design patterns
    # Check comments and documentation updates
  fi
done
```

3. Related code search
   - Verify deleted function/variable references
   - Check usage of newly added features

### Phase 3: Quality Checks

Execute parallel quality checks for efficiency (40-60% faster):

```bash
# Parallel quality checks
{
  # Security: Hardcoded secrets detection
  SECRETS_FOUND=$(git diff "$BASE_BRANCH"...HEAD | grep -iE "(api[_-]?key|password|secret|token|bearer|auth)" | wc -l) &

  # Type safety: TypeScript errors
  TS_ERRORS=$(npm run typecheck 2>&1 | grep -c "error" || echo "0") &

  # Code quality: ESLint errors
  LINT_ERRORS=$(npm run lint 2>&1 | grep -c "error" || echo "0") &

  # Tests: Execution status
  TEST_STATUS=$(npm run test:run --silent 2>&1 | grep -c "failed\\|error" || echo "0") &

  # Build verification
  BUILD_STATUS=$(npm run build 2>&1 | grep -c "failed\\|error" || echo "0") &

  wait
}

# Critical findings reporting
if [[ $SECRETS_FOUND -gt 0 ]]; then
  echo "CRITICAL: Hardcoded secrets detected ($SECRETS_FOUND instances)"
  echo "Review git diff for sensitive information"
fi

if [[ $TS_ERRORS -gt 0 ]]; then
  echo "ERROR: TypeScript errors: $TS_ERRORS"
fi

if [[ $LINT_ERRORS -gt 0 ]]; then
  echo "WARNING: ESLint errors: $LINT_ERRORS"
fi

if [[ $TEST_STATUS -gt 0 ]]; then
  echo "ERROR: Test failures detected"
fi

if [[ $BUILD_STATUS -gt 0 ]]; then
  echo "CRITICAL: Build failed"
fi
```

Security Review (Highest Priority):
- Input validation: proper user input validation
- Output escaping: XSS prevention implementation
- Authentication/Authorization: permission check appropriateness
- Secret management: no hardcoded secrets (automated check above)
- HTTPS communication: encryption for sensitive data transmission

Code Quality Review:
- TypeScript: strict mode compliance, zero type errors (automated check above)
- ESLint: zero errors, appropriate warnings (automated check above)
- Naming conventions: consistent file/variable/function naming
- Comments: appropriate explanation of complex logic

Architecture Review:
- Single Responsibility: each component single responsibility
- Dependencies: proper module separation
- Design patterns: consistency with existing patterns
- Scalability: future extensibility support

Test Review:
- Coverage: tests for new features/fixes (automated check above)
- Test quality: appropriate test cases
- Regression: verify impact on existing features
- E2E tests: verification of important flows

### Phase 4: Review Results Organization

1. Classify findings
   - Critical: security/functional failure risks
   - Important: quality/maintainability impact
   - Minor: improvement suggestions/style unification

2. Provide specific fix suggestions
   - Identify problem location (filename:line-number)
   - Provide concrete fix examples
   - Present alternatives when available

3. Overall evaluation
   - Merge approval determination
   - Conditions for conditional merge
   - Recommended additional work

## Platform Detection

Automatically detect GitLab or GitHub:
```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [[ "$REMOTE_URL" == *"gitlab"* ]]; then
  PLATFORM="gitlab"
  CLI_CMD="glab"
elif [[ "$REMOTE_URL" == *"github"* ]]; then
  PLATFORM="github"
  CLI_CMD="gh"
else
  echo "ERROR: Unsupported git platform"
  exit 2
fi
```

## Tool Usage

TodoWrite: for multi-step review workflow
AskUserQuestion: when MR number missing, review approach unclear
Task: for specialized analysis (code-reviewer, security-auditor agents)
Bash: git commands, glab/gh CLI operations
Read: verify changed files
Grep: search for references and usage
Write: generate review report

## Error Handling

### MR/PR Not Found

```bash
# MR/PR existence check
if ! $CLI_CMD pr view "$MR_NUMBER" &>/dev/null; then
  echo "ERROR: MR/PR #$MR_NUMBER not found"
  echo ""
  echo "Verify:"
  echo "  - MR/PR number is correct"
  echo "  - You have access to the repository"
  echo "  - CLI is authenticated: $CLI_CMD auth status"
  echo ""
  echo "Examples:"
  echo "  /review-pr 123           # Review MR/PR #123"
  echo "  $CLI_CMD pr list         # List available PRs"
  exit 3
fi
```

### Branch Checkout Failed

```bash
# Attempt checkout with error handling
if ! $CLI_CMD pr checkout "$MR_NUMBER" 2>/dev/null; then
  echo "WARNING: Branch checkout failed for MR/PR #$MR_NUMBER"
  echo ""
  echo "Possible causes:"
  echo "  1. Merge conflicts with current branch"
  echo "  2. Uncommitted local changes"
  echo "  3. Branch already deleted"
  echo ""

  # Offer recovery options
  read -p "Choose: [A] Stash changes & retry, [B] Diff-only review, [C] Cancel: " choice
  case "$choice" in
    A|a)
      git stash push -m "review-pr: stash before checkout MR #$MR_NUMBER"
      $CLI_CMD pr checkout "$MR_NUMBER"
      ;;
    B|b)
      echo "Proceeding with diff-only review (limited analysis)..."
      DIFF_ONLY=true
      ;;
    C|c)
      echo "Review cancelled. Resolve conflicts manually."
      exit 0
      ;;
    *)
      echo "Invalid choice. Defaulting to diff-only review."
      DIFF_ONLY=true
      ;;
  esac
fi
```

### Permission Denied

```bash
# Permission check (combined with MR existence check)
if ! $CLI_CMD pr view "$MR_NUMBER" 2>&1 | grep -q "permission denied\|forbidden"; then
  echo "ERROR: Permission denied for MR/PR #$MR_NUMBER"
  echo ""
  echo "Required permissions:"
  echo "  - Repository read access"
  echo "  - CLI authentication"
  echo ""
  echo "Resolution steps:"
  echo "  1. Check authentication:"
  echo "     $CLI_CMD auth status"
  echo ""
  echo "  2. If not authenticated, login:"
  if [[ "$PLATFORM" == "github" ]]; then
    echo "     gh auth login"
  else
    echo "     glab auth login"
  fi
  echo ""
  echo "  3. Verify repository access:"
  echo "     - Check repository settings"
  echo "     - Confirm you're a collaborator/member"
  echo ""
  echo "  4. Retry: /review-pr $MR_NUMBER"
  exit 4
fi
```

### Network/CLI Failures

```bash
# CLI availability check (at command start)
if [[ "$PLATFORM" == "github" ]]; then
  CLI_CMD="gh"
  if ! command -v gh &>/dev/null; then
    echo "ERROR: GitHub CLI not installed (gh)"
    echo ""
    echo "Installation:"
    echo "  brew install gh"
    echo "  gh auth login"
    echo ""
    echo "Manual fallback:"
    echo "  1. git fetch origin pull/$MR_NUMBER/head:pr-$MR_NUMBER"
    echo "  2. git checkout pr-$MR_NUMBER"
    echo "  3. git diff \$(git merge-base HEAD origin/main)...HEAD"
    exit 5
  fi
elif [[ "$PLATFORM" == "gitlab" ]]; then
  CLI_CMD="glab"
  if ! command -v glab &>/dev/null; then
    echo "ERROR: GitLab CLI not installed (glab)"
    echo ""
    echo "Installation:"
    echo "  brew install glab"
    echo "  glab auth login"
    echo ""
    echo "Manual fallback:"
    echo "  1. glab mr list"
    echo "  2. git fetch"
    echo "  3. Manual review of git diff"
    exit 5
  fi
fi

# Network failure handling
if ! $CLI_CMD pr view "$MR_NUMBER" 2>/dev/null; then
  echo "ERROR: Network or API failure"
  echo ""
  echo "Troubleshooting:"
  echo "  - Check internet connection"
  echo "  - Verify $PLATFORM API status"
  echo "  - Check rate limits: $CLI_CMD api rate-limit"
  echo "  - Retry in a few moments"
  echo ""
  echo "Manual fallback:"
  if [[ "$PLATFORM" == "github" ]]; then
    echo "  git fetch origin pull/$MR_NUMBER/head:pr-$MR_NUMBER"
  else
    echo "  git fetch origin merge-requests/$MR_NUMBER/head:mr-$MR_NUMBER"
  fi
  echo "  git checkout pr-$MR_NUMBER"
  echo "  git diff \$(git merge-base HEAD origin/main)...HEAD"
  exit 6
fi
```

### Security Guidelines

**Error message safety**:
- Never expose absolute paths in error messages
- Report only relative paths from project root
- Never expose stack traces or internal details
- Report only user-actionable information

**Sensitive information protection**:
- Never display sensitive file contents (.env, credentials, etc.)
- Warn users when sensitive files are detected in PR
- Never log authentication tokens or API keys
- Sanitize error messages before displaying

**Exit codes**:
- 0: Success
- 1: User input error (validation failure)
- 2: Security error (command injection, path traversal)
- 3: MR/PR not found
- 4: Permission denied
- 5: CLI not installed
- 6: Network/API failure

## External References

**Related workflows**:
- `/validate --layers=security` - Security-only validation
- `code-reviewer` agent - Code quality and best practices review
- `security-auditor` agent - Security-focused vulnerability audit

**MR/PR automation**:
- `/ship` - Create PR/MR after development
- GitHub Actions / GitLab CI - Automated review triggers

**Review checklists**:
- Security: `~/.claude/validation/owasp-top10-checklist.md`
- Code quality: `~/.claude/validation/code-quality-checklist.md`

**Validation patterns**:
- Input validation: See `~/.claude/validation/input-patterns.sh`
- Security checks: See `~/.claude/validation/security-patterns.json`

## Examples

### Basic usage

```bash
# Standard review (default mode)
/review-pr 123

# Output:
# 1. Fetches MR/PR #123 info and diff (parallel)
# 2. Checks out branch
# 3. Analyzes changes with sensitive file exclusion
# 4. Runs parallel quality checks (security, TypeScript, ESLint, tests, build)
# 5. Generates structured report (Critical/Important/Minor)
```

### Security-focused review

```bash
/review-pr 456 --security-focus

# Additional security checks:
# - OWASP Top 10 compliance verification
# - Hardcoded secrets detection (api_key, password, token, bearer, auth)
# - Authentication/authorization review
# - Input validation analysis
# - Sensitive file detection (.env, credentials, *.pem, *.key)
#
# Output prioritizes security findings (Critical severity)
```

### Detailed review mode

```bash
/review-pr 789 --detailed

# Comprehensive analysis includes:
# - Architecture impact analysis
# - Performance implications
# - Maintainability assessment
# - Test coverage evaluation
# - Design pattern consistency
# - Scalability considerations
#
# Provides extensive report with all review categories
```

### Multi-perspective review

```bash
/review-pr 101 --multi-perspective

# Parallel agent execution for comprehensive review:
# - code-reviewer agent: Best practices and maintainability
# - security-auditor agent: Vulnerability assessment
# - performance-engineer agent: Performance bottlenecks
#
# Aggregates findings from multiple specialized agents
# Best for large PRs (10+ files) or critical changes
```

### Large PR handling

```bash
# For PRs with 20+ files or 500+ lines changed
/review-pr 202 --detailed

# Automatic optimizations:
# 1. Prioritizes security-critical files (auth, permission, API)
# 2. Chunks review into phases (security → types → logic → UI)
# 3. Provides early feedback on critical issues
# 4. Progressive reporting with TodoWrite tracking
#
# Handles large-scale changes efficiently with parallel execution
```
