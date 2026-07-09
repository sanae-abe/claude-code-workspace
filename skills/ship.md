---
name: ship
description: Create GitHub PR/GitLab MR with automatic platform detection. Use for PR/MR creation, draft management, and branch status checking.
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(gh *) Bash(glab *) Bash(npm run *) Bash(command -v *) AskUserQuestion Read
argument-hint: "[branch-name] [--skip-checks] [title]"
---

# Ship - Unified PR/MR Creation Command

Create GitHub Pull Request or GitLab Merge Request with automatic platform detection.

Arguments: $ARGUMENTS

## Exit Code Constants

Define these FIRST — referenced throughout:

```bash
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_SYSTEM_ERROR=3
readonly EXIT_UNRECOVERABLE=4
```

## Platform Detection

```bash
detect_platform() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null) || {
    echo "ERROR: Git remote not found. Run: git remote -v" >&2
    exit $EXIT_UNRECOVERABLE
  }

  case "$remote_url" in
    *github.com*)            echo "github gh" ;;
    *gitlab.com* | *gitlab.*) echo "gitlab glab" ;;
    *)
      echo "ERROR: Unsupported platform. Supported: GitHub (github.com), GitLab (gitlab.com or self-hosted)" >&2
      exit $EXIT_UNRECOVERABLE
      ;;
  esac
}

read -r PLATFORM CLI_CMD <<< "$(detect_platform)"
```

## Argument Processing

Parse from $ARGUMENTS:
- First token: branch-name (optional)
- `--skip-checks`: skip quality gate validation
- Remaining tokens: PR/MR title (optional)
- Empty $ARGUMENTS: interactive mode

```bash
ARGUMENTS_SAFE=$(printf '%s' "$ARGUMENTS" | tr -d '\n\r\t' | xargs 2>/dev/null || printf '%s' "$ARGUMENTS")

dangerous_args_pattern='[`${}()]'
if [[ "$ARGUMENTS_SAFE" =~ $dangerous_args_pattern ]]; then
  echo "ERROR: Dangerous characters in arguments (shell metacharacters not allowed)" >&2
  exit $EXIT_SECURITY_ERROR
fi

IFS=' ' read -r -a args <<< "$ARGUMENTS_SAFE"
BRANCH_NAME="${args[0]:-}"
SKIP_CHECKS=false
TITLE_ARGS=()

for arg in "${args[@]:1}"; do
  if [[ "$arg" == "--skip-checks" ]]; then
    SKIP_CHECKS=true
  else
    TITLE_ARGS+=("$arg")
  fi
done
TITLE="${TITLE_ARGS[*]:-}"
```

## Security Validation

**Execute in this order before PR/MR creation:**

```bash
# 1. Branch name validation
validate_branch_name() {
  local branch="$1"
  [[ -z "$branch" ]] && { echo "ERROR: Branch name required" >&2; exit $EXIT_USER_ERROR; }

  if [[ "$branch" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected in branch name" >&2
    echo "Branch names must not contain '..'" >&2
    exit $EXIT_SECURITY_ERROR
  fi

  # Allows: a-z A-Z 0-9 / . _ -  (dots permitted for e.g. feat/v2.0)
  if [[ ! "$branch" =~ ^[a-zA-Z0-9/._-]+$ ]]; then
    echo "ERROR: Invalid branch name: $branch" >&2
    echo "Allowed characters: a-z A-Z 0-9 / . _ -" >&2
    echo "Example: feature/v2.0, fix/auth-bug" >&2
    exit $EXIT_USER_ERROR
  fi

  if ! git rev-parse --verify "$branch" &>/dev/null; then
    echo "ERROR: Branch does not exist: $branch" >&2
    echo "Available branches:" >&2
    git branch --list | head -10 >&2
    exit $EXIT_USER_ERROR
  fi
}

# 2. Title format validation (Conventional Commits + ReDoS protection)
validate_title_format() {
  local title="$1"
  [[ -z "$title" ]] && { echo "ERROR: PR/MR title required" >&2; exit $EXIT_USER_ERROR; }

  # Length check BEFORE regex (ReDoS protection)
  if [[ ${#title} -gt 200 ]]; then
    echo "ERROR: Title too long (${#title}/200 chars max)" >&2
    exit $EXIT_USER_ERROR
  fi

  local dangerous_pattern='[`$(){};|><&]'
  if [[ "$title" =~ $dangerous_pattern ]]; then
    echo "ERROR: Dangerous characters in title (shell metacharacters not allowed)" >&2
    exit $EXIT_SECURITY_ERROR
  fi

  local allowed_types=("feat" "fix" "refactor" "docs" "style" "test" "chore" "perf" "hotfix")
  local type_regex
  type_regex=$(IFS="|"; echo "${allowed_types[*]}")

  if [[ ! "$title" =~ ^($type_regex)(\([a-z0-9_-]+\))?:[[:space:]].{1,150}$ ]]; then
    echo "ERROR: Invalid Conventional Commits format" >&2
    echo "Expected: <type>(<scope>): <subject>" >&2
    echo "Valid types: ${allowed_types[*]}" >&2
    echo "Example: feat(ui): add user profile editor" >&2
    exit $EXIT_USER_ERROR
  fi

  local subject="${title#*: }"
  if [[ ${#subject} -gt 72 ]]; then
    echo "ERROR: Subject too long (${#subject}/72 chars): $subject" >&2
    exit $EXIT_USER_ERROR
  fi
}

# 3. CLI availability and authentication
validate_cli_authentication() {
  local cli_cmd="$1" platform="$2"

  if ! command -v "$cli_cmd" &>/dev/null; then
    echo "ERROR: $platform CLI not installed ($cli_cmd)" >&2
    if [[ "$platform" == "github" ]]; then
      echo "Install: brew install gh && gh auth login" >&2
    else
      echo "Install: brew install glab && glab auth login" >&2
    fi
    exit $EXIT_SYSTEM_ERROR
  fi

  if ! "$cli_cmd" auth status &>/dev/null; then
    echo "ERROR: $platform CLI not authenticated" >&2
    echo "Run: $cli_cmd auth login" >&2
    exit $EXIT_SYSTEM_ERROR
  fi
}

# 4. Template secret detection
detect_template_secrets() {
  local content="$1"
  if echo "$content" | grep -qiE "(api[_-]?key|password|secret|token|bearer|auth).{0,10}[=:].{8,}"; then
    echo "WARNING: Possible secret detected in PR/MR template" >&2
    echo "Secrets in templates are publicly visible on the remote" >&2
    read -t 30 -p "Continue anyway? (y/N): " confirm || confirm="N"
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { echo "Aborted"; exit $EXIT_SECURITY_ERROR; }
  fi
}
```

## Execution Flow

### 1. Initialize

```bash
CURRENT_BRANCH=$(git branch --show-current)
BRANCH_TYPE="${CURRENT_BRANCH%%/*}"
BRANCH_DESC="${CURRENT_BRANCH#*/}"
```

Then validate CLI: `validate_cli_authentication "$CLI_CMD" "$PLATFORM"`

### 2. Validate inputs

```bash
[[ -n "$BRANCH_NAME" ]] && validate_branch_name "$BRANCH_NAME"
[[ -n "$TITLE"       ]] && validate_title_format "$TITLE"
```

### 3. Interactive mode (when $ARGUMENTS is empty)

```typescript
// Step 1: change type
AskUserQuestion({ questions: [{ question: "Select change type", header: "Ship Type", multiSelect: false,
  options: [
    { label: "feat",     description: "New feature (UI, API, integration)" },
    { label: "fix",      description: "Bug fix (functional issues, performance)" },
    { label: "refactor", description: "Code improvement (structure, optimization)" },
    { label: "docs",     description: "Documentation (README, API specs)" },
    { label: "chore",    description: "Configuration (build, dependencies, CI/CD)" },
    { label: "hotfix",   description: "Critical fix (production issues, security)" }
  ]
}]})

// Step 2: scope
AskUserQuestion({ questions: [{ question: "Select change scope", header: "Scope", multiSelect: false,
  options: [
    { label: "ui",     description: "UI components, frontend" },
    { label: "api",    description: "API, backend, data layer" },
    { label: "core",   description: "Core/business logic" },
    { label: "config", description: "Configuration, build, infrastructure" },
    { label: "docs",   description: "Documentation, comments" },
    { label: "test",   description: "Testing, quality assurance" }
  ]
}]})
```

Auto-generate title from selections: `{type}({scope}): {description-derived-from-branch-name}`

### 4. Pre-flight checks

```bash
UNCOMMITTED=$(git status --porcelain)
if [[ -n "$UNCOMMITTED" ]]; then
  echo "WARNING: Uncommitted changes detected:" >&2
  echo "$UNCOMMITTED" >&2
  read -t 30 -p "Continue with uncommitted changes? (y/N): " confirm || confirm="N"
  [[ ! "$confirm" =~ ^[Yy]$ ]] && exit $EXIT_USER_ERROR
fi
```

### 5. Quality checks

Unless `$SKIP_CHECKS` is true, invoke the `/validate --layers=syntax --auto-fix` skill, then run project-specific commands if they exist:

```bash
# Detect and run available quality commands
for cmd in "typecheck" "lint" "test" "build"; do
  if npm run "$cmd" --dry-run &>/dev/null 2>&1; then
    npm run "$cmd" || { echo "ERROR: npm run $cmd failed" >&2; exit $EXIT_USER_ERROR; }
  fi
done
```

### 6. Load template and check for secrets

```bash
load_template() {
  local platform="$1"
  local project_tpl local_tpl

  if [[ "$platform" == "github" ]]; then
    project_tpl=".github/pull_request_template.md"
    local_tpl="$HOME/.github/PULL_REQUEST_TEMPLATE.md"
  else
    project_tpl=".gitlab/merge_request_template.md"
    local_tpl="$HOME/.gitlab/merge_request_template.md"
  fi

  if   [[ -f "$project_tpl" ]]; then cat "$project_tpl"
  elif [[ -f "$local_tpl"   ]]; then cat "$local_tpl"
  else echo "[Auto-generated template — fill in description, checklist, and testing notes]"
  fi
}

TEMPLATE=$(load_template "$PLATFORM")
detect_template_secrets "$TEMPLATE"
```

### 7. Create PR/MR (always as draft)

```bash
if [[ "$PLATFORM" == "github" ]]; then
  gh pr create --draft --title "$TITLE" --body "$TEMPLATE"
  PR_URL=$(gh pr view --json url --jq '.url' 2>/dev/null || echo "(URL unavailable)")
  echo "✓ Pull Request created (draft): $PR_URL"
else
  glab mr create --draft --title "$TITLE" --description "$TEMPLATE"
  echo "✓ Merge Request created (draft)"
fi
```

## Exit Code Reference

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | EXIT_SUCCESS | PR/MR created successfully |
| 1 | EXIT_USER_ERROR | Invalid format, branch not found, uncommitted changes |
| 2 | EXIT_SECURITY_ERROR | Path traversal, injection attempt, secret in template |
| 3 | EXIT_SYSTEM_ERROR | CLI not installed or unauthenticated |
| 4 | EXIT_UNRECOVERABLE | Platform detection failed |

## Error Handling

Argument validation:
- Missing argument → use AskUserQuestion for interactive input
- Invalid Conventional Commits format → report expected format with example
- Branch not found → list available branches

Execution errors:
- CLI not found → report platform-specific install command
- Auth failure → report `$cli_cmd auth login`
- Push failure → suggest `git push -u origin <branch>`
- API failure → surface specific CLI error output

Security: Never expose absolute file paths, stack traces, or internal implementation details in user-facing messages.

## Required Checklist

- [ ] Created as draft (`--draft`)
- [ ] Conventional Commits title: `<type>(<scope>): <subject>`
- [ ] Branch pushed before creating PR/MR (`git push -u origin <branch>` on first push)
- [ ] Quality checks passed (or `--skip-checks` intentionally set)
- [ ] Template checklist completed before marking ready for review

## Platform Reference

| | GitHub | GitLab |
|--|--------|--------|
| CLI | `gh` | `glab` |
| Edit | `gh pr edit <N> --title "..." --body "..."` | `glab mr update <N> --title "..." --description "..."` |
| Mark ready | `gh pr ready <N>` | `glab mr update <N> --ready` |
| Template | `.github/pull_request_template.md` | `.gitlab/merge_request_template.md` |

If project has `docs/PR_GUIDELINES.md` or `docs/MR_GUIDELINES.md`, read those for additional requirements before creating the PR/MR.
