# Ship Skill - Usage Examples

## Example 1: Interactive Mode (No Arguments)

```bash
git checkout -b feat/user-profile-edit
git add .
git commit -m "feat(profile): add user profile editing"
git push -u origin feat/user-profile-edit
/ship
```

Expected flow:
```
Platform detected: GitHub
Current branch: feat/user-profile-edit
CLI authentication verified (gh)
Running quality checks...
All quality checks passed

[AskUserQuestion: select type]
[AskUserQuestion: select scope]

Pull Request created successfully
Status: Draft
URL: https://github.com/org/repo/pull/123
```

---

## Example 2: Direct Creation with Arguments (GitHub)

```bash
/ship feat/user-profile-edit "feat(profile): add user profile editing"
```

Success output:
```
Branch validation passed (feat/user-profile-edit)
Title format validation passed
CLI authentication verified (gh)
Template loaded from .github/pull_request_template.md
All quality checks passed
Pull Request created successfully
URL: https://github.com/org/repo/pull/124
```

---

## Example 3: GitLab MR Creation

```bash
git checkout -b fix/api-timeout-issue
git push -u origin fix/api-timeout-issue
/ship
```

Expected output:
```
Platform detected: GitLab
Current branch: fix/api-timeout-issue
CLI authentication verified (glab)
All quality checks passed
Merge Request created successfully
Status: Draft
URL: https://gitlab.com/org/project/-/merge_requests/45
```

Mark ready:
```bash
glab mr update --ready
```

---

## Example 4: Security Validation — Path Traversal

```bash
/ship ../../../etc/passwd "feat: malicious PR"
```

Error output:
```
ERROR: Path traversal detected in branch name: ../../../etc/passwd
Security policy: Branch names must not contain '..'
Exit code: 2 (Security error)
```

---

## Example 5: Authentication Required

```bash
/ship feat/new-feature "feat(ui): add dashboard"
```

If not authenticated:
```
ERROR: github CLI not authenticated
Authentication required:
  gh auth login
Follow the prompts to authenticate with github
Exit code: 3 (System error)
```

Recovery:
```bash
gh auth login
/ship feat/new-feature "feat(ui): add dashboard"
```

---

## Example 6: Quality Checks Failure

```bash
/ship feat/broken-feature "feat(ui): add feature"
```

Output:
```
Branch validation passed (feat/broken-feature)
Title format validation passed
CLI authentication verified (gh)
Running quality checks...

Quality checks failed
Fix errors before creating PR/MR, or use --skip-checks flag
Exit code: 1 (User error)
```

Recovery:
```bash
npm run typecheck   # Fix TS errors
npm run lint:fix    # Auto-fix ESLint
npm run test        # Fix failing tests
/ship feat/broken-feature "feat(ui): add feature"
```

---

## Example 7: Invalid Title Format

```bash
/ship feat/user-settings "Add user settings page"
```

Error output:
```
ERROR: Invalid Conventional Commits format
Expected: <type>(<scope>): <subject>
Got: Add user settings page

Valid types: feat fix refactor docs style test chore perf hotfix
Example: feat(ui): add user settings page
Exit code: 1 (User error)
```

Correct command:
```bash
/ship feat/user-settings "feat(ui): add user settings page"
```

---

## Example 8: Skip Quality Checks

Emergency deployment:
```bash
/ship --skip-checks feat/urgent-fix "fix(critical): emergency patch"
```

Output:
```
Quality checks skipped (--skip-checks flag)

Pull Request created successfully
URL: https://github.com/org/repo/pull/150

Warning: Quality checks were skipped
Ensure manual verification before merging
```
