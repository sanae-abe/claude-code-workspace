---
name: worktree
description: Git worktree management for parallel development workflows
argument-hint: "[create|list|switch|merge|delete|status] [branch-name]"
allowed-tools: Bash(git *) TodoWrite AskUserQuestion
model: sonnet
disable-model-invocation: true
---

# Worktree Management

Arguments: $ARGUMENTS

## Argument Parsing

Parse $ARGUMENTS:
- First token: subcommand — one of `create`, `list`, `switch`, `merge`, `delete`, `status`
- Second token: branch name (required for `create`, `switch`, `merge`, `delete`)
- Flags: `--from <base-branch>` (create), `--into <target-branch>` (merge), `--detailed` (list), `--force` (delete), `--no-delete` (merge), `--no-push` (merge)

If no arguments: run the `list` subcommand, then print the usage hint from Error Handling.
If the first token is not a known subcommand: report `ERROR: Unknown subcommand: <value>` with the usage hint, and stop.
If a flag is not valid for the given subcommand: report `ERROR: Flag <flag> is not valid for <subcommand>` with the usage hint, and stop.

## Argument Validation

Run these checks yourself against the parsed values before issuing any git command. Each failure means: report the message and stop — do not run a git command, and do not continue to the next check.

Checks 1-3 apply only when a branch name was given (`create`, `switch`, `merge`, `delete`, and the `--into` / `--from` values). Check 4 applies to every subcommand.

If a subcommand that requires a branch name was given none: report `ERROR: <subcommand> requires a branch name` with the usage hint, and stop.

1. Branch name matches `^[a-zA-Z0-9/_-]+$`
   → else `ERROR: Invalid branch name. Use only: a-z A-Z 0-9 / _ -`
2. Branch name contains no `..`
   → else `ERROR: '..' not allowed in branch names`
3. Branch name does not start with `-` (option injection)
   → else `ERROR: Branch names cannot start with '-'`
4. `git rev-parse --show-toplevel` succeeds
   → else `ERROR: Not a git repository`

## Path Derivation

Derive the worktree path once, and pass that exact absolute path to every git command. Never pass a relative path such as `../worktree-<branch>` — the working directory may be a repository subdirectory, which would place the worktree somewhere other than the validated location.

```
REPO_ROOT    = output of `git rev-parse --show-toplevel`
REPO_PARENT  = REPO_ROOT with its last path segment removed
SLUG         = branch name with every "/" replaced by "-"
WORKTREE_PATH = REPO_PARENT + "/worktree-" + SLUG
```

`SLUG` flattens slashes so that `feature/auth` yields `<REPO_PARENT>/worktree-feature-auth`, one level directly under `REPO_PARENT`. The branch name itself keeps its slashes.

`git worktree add` refuses to write to an existing path, so an occupied path (including a symlink) surfaces as a git error — handle it per Error Handling rather than pre-checking.

`WORKTREE_PATH` is the creation target for `create` only. For `switch`, `merge`, `delete`, and `status`, use `<listed-path>` — the path that `git worktree list --porcelain` reports for that branch — a worktree created outside this skill may sit elsewhere.

## Execution Flow

Common flow for all subcommands:

1. Parse the subcommand and arguments (see Argument Parsing)
2. Run Argument Validation — stop on the first failure
3. Resolve the worktree path (see Path Derivation): derive `WORKTREE_PATH` for `create`; read `<listed-path>` from `git worktree list --porcelain` for the others
4. Check preconditions listed under the subcommand
5. Execute the git commands, quoting every interpolated value
6. Print the subcommand's output template

## Subcommands

### create <branch-name> [--from <base-branch>]

1. Determine the base branch: `--from` value, else the current branch (`git rev-parse --abbrev-ref HEAD`)
2. Verify the branch does not already exist: `git rev-parse --verify "refs/heads/<branch>"`
   - If it exists: stop and print the "branch exists" error (see Error Handling)
3. Create the branch and worktree:
   ```bash
   git worktree add -b "<branch>" "<WORKTREE_PATH>" "<base-branch>"
   ```
4. Print the output template

**Output**:
```
Created worktree: /Users/.../worktree-feature-auth
Branch: feature-auth (from main)

Next steps:
  cd /Users/.../worktree-feature-auth
```

### list [--detailed]

1. Run `git worktree list --porcelain`
2. Extract per entry: path, branch, lock status, and — only with `--detailed` — the commit hash
3. Print the matching template

**Output (default)**:
```
BRANCH              PATH                              STATUS
main                /Users/.../project                (current)
feature-auth        /Users/.../worktree-feature-auth
bugfix-login        /Users/.../worktree-bugfix-login  locked
```

**Output (--detailed)**:
```
BRANCH              COMMIT    PATH                              STATUS
main                a1b2c3d   /Users/.../project                (current)
feature-auth        e4f5a6b   /Users/.../worktree-feature-auth
bugfix-login        c7d8e9f   /Users/.../worktree-bugfix-login  locked
```

### switch <branch-name>

1. Run `git worktree list --porcelain` and find the entry for the branch
2. If not found: stop and print the "worktree not found" error (see Error Handling)
3. Print the output template

A skill cannot change the parent shell's working directory — emit the `cd` command for the user to run.

**Output**:
```
Worktree for 'feature-auth':

  cd /Users/.../worktree-feature-auth
```

### merge <branch-name> [--into <target-branch>] [--no-push] [--no-delete]

Track this subcommand with TodoWrite — it has multiple steps with irreversible effects.

1. Verify the worktree exists (`git worktree list --porcelain`)
   - If not found: stop and print the "worktree not found" error
2. Check for uncommitted changes in the worktree:
   `git -C "<listed-path>" status --porcelain`
   - If any output: stop and print the "uncommitted changes" error. `merge` never discards or auto-commits work
3. Determine the target branch, in order:
   - `--into` value, if given
   - else the branch checked out in the main worktree (first entry of `git worktree list --porcelain`)
   - If that resolves to the branch being merged: stop and report `ERROR: Cannot merge 'X' into itself. Specify --into <target-branch>`
4. Check out the target branch in the current directory: `git checkout "<target-branch>"`
   - If it fails because of local changes: stop and print the "uncommitted changes" error for the current directory
5. If the target branch has an upstream (`git rev-parse --abbrev-ref "<target>@{upstream}"` succeeds): `git pull --ff-only`
   - If the pull fails: stop, report the git error, and suggest resolving the divergence manually
6. Merge: `git merge --no-ff "<branch>"`
7. If the merge conflicts:
   - Run `git diff --name-only --diff-filter=U` and list every conflicting file
   - Stop and print the "merge conflict" error. Do not push, delete, or abort on the user's behalf
8. If the merge succeeded and `--no-push` was not given and the target has an upstream:
   - Ask via AskUserQuestion whether to push to the upstream
   - If declined: skip the push and note it in the output
   - If accepted: `git push`
9. Unless `--no-delete`:
   ```bash
   git worktree remove "<listed-path>"
   git branch -d "<branch>"
   ```
10. Print the output template

**Output**:
```
Merged 'feature-auth' into 'main'
Pushed to origin/main
Removed worktree: /Users/.../worktree-feature-auth
Deleted branch: feature-auth
```

Omit any line for a step that was skipped, and append `(skipped: --no-push)` or `(skipped: --no-delete)` on its own line.

### delete <branch-name> [--force]

1. Verify the worktree exists (`git worktree list --porcelain`)
   - If not found: stop and print the "worktree not found" error
2. Check for uncommitted changes: `git -C "<listed-path>" status --porcelain`
3. If there are uncommitted changes and `--force` was not given:
   - Ask via AskUserQuestion: delete anyway, or cancel
   - If the user cancels: report `Deletion cancelled. No changes were made.` and stop
4. Remove the worktree — exactly one of:
   - No uncommitted changes: `git worktree remove "<listed-path>"`
   - `--force` given, or the user confirmed at step 3: `git worktree remove --force "<listed-path>"`
5. Delete the branch:
   - `git branch -d "<branch>"`, or `git branch -D "<branch>"` when `--force` was given or the user confirmed
   - If `-d` fails because the branch is unmerged: report it and suggest `--force`
6. Print the output template

**Output**:
```
Removed worktree: /Users/.../worktree-feature-auth
Deleted branch: feature-auth
```

### status

Track this subcommand with TodoWrite — one item per worktree inspected.

1. Run `git worktree list --porcelain` to enumerate worktrees
2. For each worktree, in a single Bash call per worktree so the calls run concurrently:
   - `git -C "<path>" status --porcelain` → count of uncommitted changes
   - `git -C "<path>" rev-list --left-right --count "@{upstream}...HEAD"` → behind/ahead counts (skip when there is no upstream)
3. Print the output template

**Output**:
```
Worktrees: 3
  With uncommitted changes: 1
  Ahead of remote: 2
  Behind remote: 0
  Locked: 1

BRANCH              CHANGES  AHEAD  BEHIND  STATUS
main                0        0      0
feature-auth        4        2      0
bugfix-login        0        0      0       locked
```

## Tool Usage

**TodoWrite**: `merge` and `status` (both are multi-step); also `delete` once a confirmation branch is entered.

**AskUserQuestion**: use when — and only when —
- deleting a worktree that has uncommitted changes without `--force`
- confirming a push to a remote during `merge`

## Error Handling

Report the error, then stop. Never include shell output, stack traces, or internal skill paths in an error message; worktree and repository paths are the operative data of this skill and are shown deliberately.

| Condition | Message | Suggestions |
|---|---|---|
| Branch already exists | `ERROR: Branch '<branch>' already exists` | switch to it, use a different name, or delete it |
| Worktree not found | `ERROR: No worktree found for branch '<branch>'` | `/worktree list`, or `/worktree create <branch>` |
| Worktree path occupied | `ERROR: Path already exists: <WORKTREE_PATH>` | remove the directory, or use a different branch name |
| Uncommitted changes | `ERROR: Uncommitted changes in <path>` | commit, stash, or re-run with `--force` (delete only) |
| Merge conflict | `ERROR: Merge conflict in <n> file(s)` | list each conflicting file, then resolve and commit, or `git merge --abort` |
| No worktrees | `No worktrees found.` | `/worktree create <branch-name>` |
| Permission denied | `ERROR: Permission denied writing to <path>` | check directory permissions |
| Disk full | `ERROR: Not enough disk space` | free space, or delete unused worktrees |
| Path too long | `ERROR: Worktree path exceeds the filesystem limit` | use a shorter branch name |

**Error output template** — used for every row above:

```
ERROR: Branch 'feature-auth' already exists

Suggestions:
1. Switch to existing worktree: /worktree switch feature-auth
2. Use a different branch name:  /worktree create feature-auth-v2
3. Delete the existing one:      /worktree delete feature-auth
```

**Usage hint**:

```
Usage: /worktree [create|list|switch|merge|delete|status] [branch-name]

  create <branch> [--from <base>]                    Create a worktree and branch
  list [--detailed]                                  List worktrees
  switch <branch>                                    Print the cd command
  merge <branch> [--into <b>] [--no-push] [--no-delete]  Merge and clean up
  delete <branch> [--force]                          Remove worktree and branch
  status                                             Per-worktree change summary
```

## Examples

```
/worktree create feature-auth --from develop
→ Creates <REPO_PARENT>/worktree-feature-auth on a new branch off develop

/worktree create feature/auth
→ Branch feature/auth, directory <REPO_PARENT>/worktree-feature-auth (slash flattened)

/worktree list --detailed
→ Table with the commit hash column

/worktree merge feature-auth
→ TodoWrite-tracked: checkout target, pull, merge, AskUserQuestion before push, clean up

/worktree
→ list output, followed by the usage hint
```

Error cases:

```
/worktree create -bad
→ ERROR: Branch names cannot start with '-'

/worktree create ../escape
→ ERROR: Invalid branch name. Use only: a-z A-Z 0-9 / _ -

/worktree switch nope
→ ERROR: No worktree found for branch 'nope'

/worktree delete feature-auth        (with uncommitted changes)
→ AskUserQuestion: delete anyway or cancel; on cancel, nothing is removed

/worktree rebase feature-auth
→ ERROR: Unknown subcommand: rebase
```
