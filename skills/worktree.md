---
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, TodoWrite, AskUserQuestion
argument-hint: "[create|list|switch|merge|delete|status] [branch-name]"
description: Git worktree management for parallel development workflows
model: sonnet
---

# Worktree Management

Arguments: $ARGUMENTS

## Execution Flow

**Common flow for ALL subcommands**:
1. Parse subcommand and arguments from $ARGUMENTS
2. **SECURITY: Validate inputs** (call validate_branch_name, validate_worktree_path)
3. Check preconditions (git status, existing worktrees, etc.)
4. Execute git operation with proper quoting (see Security Implementation)
5. Verify result and provide user-actionable output

## Subcommands

### create <branch-name> [--from <base-branch>]

Create new worktree for parallel development:

1. Validate branch name (call validate_branch_name)
2. Validate worktree path (call validate_worktree_path)
3. Determine base branch (default: current branch or main)
4. Create new branch and worktree with proper quoting:
   ```bash
   git worktree add -b "${BRANCH}" "../worktree-${BRANCH}" "${BASE_BRANCH}"
   ```
5. Output worktree path and next steps

**Error handling**:
- If branch exists: offer to switch instead
- If path exists: suggest alternative path or cleanup
- If git error: show error and suggest `git worktree list`

### list [--detailed]

List all worktrees:

1. Run `git worktree list --porcelain` for machine-readable output
2. Parse output to extract:
   - Worktree path
   - Branch name
   - Commit hash (if --detailed)
   - Lock status
3. Format as table with clear headers

**Output format**:
```
BRANCH              PATH                           STATUS
main                /Users/.../project             (main)
feature-auth        /Users/.../worktree-auth
bugfix-login        /Users/.../worktree-login      locked
```

### switch <branch-name>

Switch to existing worktree:

1. List worktrees to find target branch
2. If found: output `cd` command for user
3. If not found: suggest creating with `create` subcommand

**Note**: Cannot change directory in parent shell, output instruction instead

### merge <branch-name> [--no-delete]

Merge worktree branch to main and cleanup:

1. Verify worktree exists
2. Check for uncommitted changes in worktree
3. Switch to main branch in current directory
4. Pull latest changes: `git pull origin main`
5. Merge worktree branch: `git merge <branch-name>`
6. If merge successful and no conflicts:
   - Push to remote: `git push origin main`
   - Unless --no-delete: delete worktree and branch
7. If conflicts: halt and instruct user to resolve

**Cleanup steps** (unless --no-delete):
```bash
git worktree remove "../worktree-${BRANCH}"
git branch -d "${BRANCH}"
```

### delete <branch-name> [--force]

Remove worktree and branch:

1. Verify worktree exists
2. Check for uncommitted changes
3. If uncommitted changes and not --force:
   - Warn user and ask for confirmation via AskUserQuestion
4. Remove worktree: `git worktree remove <path>`
5. If --force or confirmed: `git worktree remove --force <path>`
6. Delete branch: `git branch -d <branch-name>` (or `-D` if --force)

### status

Show comprehensive worktree status:

1. List all worktrees with TodoWrite tracking:
   - For each worktree: check git status
   - Count uncommitted changes
   - Check if branch is ahead/behind remote
2. Output summary:
   - Total worktrees
   - Worktrees with uncommitted changes
   - Worktrees ahead/behind remote
   - Locked worktrees

## Tool Usage

**TodoWrite**: Use for multi-step operations (merge, delete with conflicts)

**AskUserQuestion**: Use when:
- Uncommitted changes detected (confirm deletion)
- Merge conflicts require user decision
- Ambiguous arguments (multiple matches)

## Security Implementation

**MANDATORY: Execute these validations BEFORE ANY git command**

```bash
validate_branch_name() {
  local branch_name="$1"

  # Check allowed characters
  if [[ ! "$branch_name" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
    echo "ERROR: Invalid branch name. Use only: a-z A-Z 0-9 / _ -"
    exit 1
  fi

  # Prevent directory traversal
  if [[ "$branch_name" =~ \.\. ]]; then
    echo "ERROR: '..' not allowed in branch names"
    exit 1
  fi

  # Prevent branch names starting with dash (option injection)
  if [[ "$branch_name" =~ ^- ]]; then
    echo "ERROR: Branch names cannot start with '-'"
    exit 1
  fi
}

validate_worktree_path() {
  local branch_name="$1"
  local repo_parent

  # Get repository root
  repo_parent=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_parent" ]]; then
    echo "ERROR: Not a git repository"
    exit 1
  fi

  # Worktree must be in parent directory of repo
  repo_parent=$(dirname "$repo_parent")
  local worktree_path="${repo_parent}/worktree-${branch_name}"

  # Verify path is directly under repo parent (no subdirectories)
  if [[ "$(dirname "$worktree_path")" != "$repo_parent" ]]; then
    echo "ERROR: Worktree must be in repository parent directory"
    exit 1
  fi

  # Reject symbolic links
  if [[ -e "$worktree_path" && -L "$worktree_path" ]]; then
    echo "ERROR: Worktree path cannot be a symbolic link"
    exit 1
  fi
}
```

**Safe git command execution**:
```bash
# After validation, always use proper quoting
git worktree add -b "${BRANCH}" "../worktree-${BRANCH}" "${BASE_BRANCH}"

# NEVER use unquoted variables:
# ❌ git worktree add -b $BRANCH ../worktree-$BRANCH $BASE_BRANCH
```

## Error Handling

**Git errors**:
- Branch already exists: suggest `switch` or use different name
- Worktree path exists: offer cleanup or alternative path
- No worktrees found: suggest creating first worktree
- Uncommitted changes: warn and require --force or confirmation

**File system errors**:
- Permission denied: check directory permissions
- Disk full: report error and suggest cleanup
- Path too long: suggest shorter branch name

**User-actionable error format**:
```
Error: Branch 'feature-auth' already exists

Suggestions:
1. Switch to existing worktree: /worktree switch feature-auth
2. Use different branch name: /worktree create feature-auth-v2
3. Delete existing: /worktree delete feature-auth
```


## Output Format Examples

**Success example**:
```
✓ Created worktree: ../worktree-feature-name
✓ Branch: feature-name (from main)

Next steps:
  cd ../worktree-feature-name
  # Start development
```

**Error example**:
```
ERROR: Branch 'feature-name' already exists

Suggestions:
1. Switch to existing: /worktree switch feature-name
2. Use different name: /worktree create feature-name-v2
3. Delete existing: /worktree delete feature-name
```

## Performance Notes

- Use parallel execution when checking status of multiple worktrees
- Minimize git command calls where possible

## Argument Parsing

- First argument: subcommand (create, list, switch, merge, delete, status)
- Remaining arguments: subcommand-specific
- Flags: `--force`, `--detailed`, `--from`, `--no-delete`
- **No arguments**: Show `list` output and usage hint
