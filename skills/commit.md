---
name: commit
description: Create Conventional Commits with emoji formatting
disable-model-invocation: true
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

### 1. Protected Branch Check

Run: `git rev-parse --abbrev-ref HEAD`

If not in a git repository: report "ERROR: Not in a git repository" and exit 3

If branch matches `main` or `master`:
- Report: "ERROR: Direct commits to '[branch]' are not allowed"
- Suggest: `/branch feature your-feature-name` or `git checkout -b feature/your-feature-name`
- Exit with code 2

### 2. Sensitive File Check

Run: `git diff --cached --name-only`

If no output: report "ERROR: No staged files. Stage changes first: git add <files>" and exit 1

If any staged file matches: `.env`, `.envrc`, `.env.*`, `credentials.*`, `secrets.*`, `*.pem`, `*.key`, `id_rsa`, `.ssh/*`:
- Report: "ERROR: Sensitive file detected: [filename only, never full path]"
- Suggest: `git reset HEAD <file>`, add to `.gitignore`, use environment variables instead
- Exit with code 2

### 3. Commit Message Sanitization

If message provided in $ARGUMENTS:
- Detect dangerous characters (backtick, `$`, `(`): report error and exit 2
- Detect secret patterns (`api_key=`, `password:`, `token=` followed by 8+ chars): warn and require user confirmation before proceeding

### 4. Pre-commit Hook Handling

After `git commit` execution, if exit code != 0:
- Check staged file types and suggest likely cause:
  - `.ts`/`.tsx` files staged → suggest `npm run type-check`
  - `.js`/`.jsx`/`.ts`/`.tsx` files staged → suggest `npm run lint:fix`
- Never auto-retry with `--no-verify` unless it is explicitly present in $ARGUMENTS

### 5. GPG Signature Check

Run: `git config --get commit.gpgsign`

If value is `true` and `git config --get user.signingkey` returns empty:
- Report: "ERROR: GPG signing enabled but no signing key configured"
- Suggest: `git config user.signingkey YOUR_KEY_ID`
- Exit with code 2

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

# Execute commit and propagate exit code
git commit -m "$COMMIT_MSG" "${COMMIT_FLAGS[@]}"
COMMIT_RESULT=$?
if [[ $COMMIT_RESULT -ne 0 ]]; then
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
