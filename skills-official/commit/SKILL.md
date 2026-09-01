---
name: commit
description: Create Conventional Commits with emoji formatting
argument-hint: "[message] [--no-verify] [--amend]"
allowed-tools: Bash(git *) Read AskUserQuestion
model: sonnet
disable-model-invocation: true
---

# Git Commit Command

Create well-formatted commit: $ARGUMENTS

## Execution Flow

1. Parse arguments from $ARGUMENTS
2. Run pre-commit security validations
3. If message provided: validate Conventional Commits format and add emoji
4. If no message: use AskUserQuestion to select commit type and scope
5. Generate commit message with appropriate emoji
6. Execute git commit with generated message
7. Verify commit created and report next steps

## Pre-commit Validations

Execute these checks before any commit operation:

**Branch protection**: Run `git rev-parse --abbrev-ref HEAD`. If branch matches `main` or `master`, report error and exit.

```
ERROR: Direct commits to 'main' are not allowed.
Security policy: Use feature branches for development.

Create a feature branch:
  git checkout -b feature/your-feature-name
```

**Staged files check**: Run `git diff --cached --name-only`. If output is empty, report error and exit.

```
ERROR: No staged files. Use 'git add' to stage changes first.
```

**Sensitive file detection**: Check each staged file against these patterns: `.env`, `.envrc`, `.env.*`, `credentials.*`, `secrets.*`, `*.pem`, `*.key`, `id_rsa`, `.ssh/*`. If matched, report error and exit.

```
ERROR: Sensitive file detected: <filename>
Resolution:
  1. Unstage: git reset HEAD <filename>
  2. Add to .gitignore: echo '<filename>' >> .gitignore
  3. Use environment variables instead
```

**Message injection check** (if message provided): Reject messages containing backticks, `$`, or `(` characters. Report "Dangerous characters detected in commit message" and exit.

**Secret pattern check** (if message provided): If message matches `(api[_-]?key|password|secret|token|bearer|auth).{0,10}[=:].{8,}`, warn the user and use AskUserQuestion to confirm before continuing.

**GPG signature check**: If `git config commit.gpgsign` returns `true`, verify `git config user.signingkey` is set. If missing, report error.

```
ERROR: GPG signing enabled but no signing key configured.
Fix: git config user.signingkey YOUR_KEY_ID
```

**Pre-commit hook failure**: If `git commit` exits non-zero due to a hook, identify likely cause from staged file extensions and suggest fix commands (e.g. `npm run type-check` for `.ts` files, `npm run lint:fix` for `.js/.ts` files).

## Argument Validation

Parse $ARGUMENTS:
- Extract message if provided (first token before flags)
- Detect flags: `--no-verify`, `--amend`

If message provided:
- Check Conventional Commits format: `type(scope): subject`
- Validate type against allowed list
- Ensure subject length under 72 characters

If validation fails: report error with correct format and examples.

## Commit Type Selection

Use AskUserQuestion in two steps (max 4 options per question).

**Step 1: Select primary category**

Question: "Select commit type"
Header: "Type"
Options:
1. feat ✨ - New feature (user-facing functionality)
2. fix 🐛 - Bug fix (user-facing issue resolution)
3. refactor ♻️ - Refactoring / performance / style changes
4. other 📦 - Documentation, tests, config, build

**Step 2 (only if "other" selected):**

Question: "Select detail type"
Header: "Detail"
Options:
1. docs 📝 - Documentation changes only
2. test ✅ - Add or modify tests
3. chore 🔧 - Build, configuration, dependency updates
4. style 💄 - Code style / formatting changes

Type-to-emoji mapping:
- feat: ✨, fix: 🐛, refactor: ♻️, docs: 📝, style: 💄, test: ✅, chore: 🔧, perf: ⚡️

## Scope Selection

Run `git diff --cached --name-only` and infer the most likely scope from file paths before asking. Pre-select the most relevant option in the question.

Question: "Select scope (area of change)"
Header: "Scope"
Options:
1. ui - UI components, styling changes
2. api - API, backend, data layer changes
3. core - Core logic, business logic changes
4. none - No specific scope (multiple areas or global)

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

Execute: `git commit -m "<generated-message>"`

Flags:
- If `--no-verify` in $ARGUMENTS: add `--no-verify` to skip pre-commit hooks
- If `--amend` in $ARGUMENTS: add `--amend` to amend last commit

After commit: verify with `git log -1 --oneline` and report hash and message.

## Error Handling

Argument errors:
- Invalid format: report "Conventional Commits format required: type(scope): subject"
- Unknown type: report "Allowed types: feat, fix, refactor, docs, style, test, chore, perf"
- Subject too long: report "Subject must be under 72 characters, got: [length]"

Execution errors:
- No staged files: report "No staged files. Use 'git add' to stage changes first"
- git commit fails: report git error message and suggest resolution

Security:
- Never expose absolute file paths in error messages
- Never expose stack traces or internal details
- Report only user-actionable information

## Examples

```
/commit "feat(ui): add user profile component" → Execute commit with "✨ feat(ui): add user profile component"
/commit → Interactive mode, use AskUserQuestion to select type and scope
/commit "update docs" → Report error "Conventional Commits format required: type(scope): subject"
```

## Output Format

**Success**:
```
✓ Commit created successfully

Commit details:
  Hash: a3f7b2c
  Message: ✨ feat(ui): add user profile editor
  Files: 3 modified, 128 insertions, 45 deletions

Next steps:
  1. Review commit: git show
  2. Amend if needed: /commit --amend
  3. Push changes: git push
  4. Create PR: /ship
```

**Hook failure**:
```
ERROR: Pre-commit hook failed

Likely cause: TypeScript type errors
Fix: npm run type-check

Or skip hooks (not recommended): /commit --no-verify
```
