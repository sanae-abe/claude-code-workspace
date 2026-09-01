---
name: commit
description: Create Conventional Commits with emoji formatting
argument-hint: "[message] [--no-verify] [--amend]"
allowed-tools: Bash(git *) AskUserQuestion
model: sonnet
disable-model-invocation: true
---

# Git Commit Command

Create well-formatted commit: $ARGUMENTS

## Execution Flow

1. Parse arguments from $ARGUMENTS
2. Run pre-commit security validations
3. If message provided: validate Conventional Commits format, then prepend the type emoji
   (skip prepending if the message already starts with the correct emoji)
4. If no message: use AskUserQuestion to select commit type and scope
5. Generate commit message with appropriate emoji
6. Execute git commit with generated message
7. Verify commit created and report next steps

## Pre-commit Validations

Execute these checks before any commit operation.

**Branch protection**: Run `git rev-parse --abbrev-ref HEAD`. If branch matches `main` or `master`, report error and stop. There is no override — this is a hard policy.

```
ERROR: Direct commits to 'main' are not allowed.
Security policy: Use feature branches for development.

Create a feature branch:
  git checkout -b feature/your-feature-name
```

**Staged files check**: Skip this check when `--amend` is present in $ARGUMENTS — amending a message is valid with an empty index. Otherwise run `git diff --cached --name-only`; if output is empty, report error and stop.

```
ERROR: No staged files. Use 'git add' to stage changes first.
```

**Sensitive file detection**: Check each staged file against these patterns: `.env`, `.envrc`, `.env.*`, `credentials.*`, `secrets.*`, `*.pem`, `*.key`, `id_rsa`, `.ssh/*`. If matched, report error and stop.

```
ERROR: Sensitive file detected: <filename>
Resolution:
  1. Unstage: git reset HEAD <filename>
  2. Add to .gitignore: echo '<filename>' >> .gitignore
  3. Use environment variables instead
```

**Message injection prevention**: Never interpolate the message into a double-quoted shell string. Always commit through a single-quoted heredoc (see Git Commit Execution) — under that form backticks, `$`, and `(` are literal and safe, so do not reject them. Reject only a message containing a line equal to `COMMIT_MSG`, which would terminate the heredoc early.

```
ERROR: Commit message contains the heredoc delimiter on its own line.
Fix: rewrite the message without a line consisting solely of COMMIT_MSG.
```

**Secret pattern check**: Apply to the final message on both paths — the argument-supplied message and the subject collected via AskUserQuestion. If it matches `(api[_-]?key|password|secret|token|bearer|auth).{0,10}[=:].{8,}`, warn the user and use AskUserQuestion to confirm before continuing.

**GPG signature check**: If `git config commit.gpgsign` returns `true`, verify `git config user.signingkey` is set. If missing, report error and stop.

```
ERROR: GPG signing enabled but no signing key configured.
Fix: git config user.signingkey YOUR_KEY_ID
```

**Pre-commit hook failure**: If `git commit` exits non-zero due to a hook, identify likely cause from staged file extensions and suggest fix commands (e.g. `npm run type-check` for `.ts` files, `npm run lint:fix` for `.js/.ts` files). Name the failing files from the hook output when it reports them.

## Argument Validation

Parse $ARGUMENTS:
- Flags: `--no-verify`, `--amend`. Recognize them anywhere in the argument list.
- Message: everything that is not a flag. A quoted argument is one message even when it
  contains spaces; unquoted words are joined with single spaces. Empty means interactive mode.

If a message is present, validate it against the rules in Message Generation. If validation fails: report error with the correct format and an example, and stop.

## Commit Type Selection

Use AskUserQuestion (max 4 options per question). Step 2 is one of two mutually exclusive questions, chosen by the Step 1 answer.

**Step 1: Select primary category**

Question: "Select commit type"
Header: "Type"
Options:
1. feat ✨ - New feature (user-facing functionality)
2. fix 🐛 - Bug fix (user-facing issue resolution)
3. refactor ♻️ - Internal change with no behavior change (restructuring or optimization)
4. other 📦 - Documentation, tests, config, build, formatting

**Step 2a (only if "refactor" selected):**

Question: "Select detail type"
Header: "Detail"
Options:
1. refactor ♻️ - Restructuring only, no measurable performance goal
2. perf ⚡️ - Speed or resource optimization

**Step 2b (only if "other" selected):**

Question: "Select detail type"
Header: "Detail"
Options:
1. docs 📝 - Documentation changes only
2. test ✅ - Add or modify tests
3. chore 🔧 - Build, configuration, dependency updates
4. style 💄 - Formatting only, no logic change

Type-to-emoji mapping (single source of truth for both the allowed type list and the emoji):

| type | emoji |
|---|---|
| feat | ✨ |
| fix | 🐛 |
| refactor | ♻️ |
| perf | ⚡️ |
| docs | 📝 |
| style | 💄 |
| test | ✅ |
| chore | 🔧 |

## Scope Selection

Run `git diff --cached --name-only` and infer the most likely scope from the file paths.

Build exactly 4 options in this order:
1. The inferred scope, labeled `<scope> (Recommended)` — omit this entry if inference is inconclusive
2. Fill the remaining slots from `ui`, `api`, `core` in that order, skipping the one already used in slot 1
3. Always place `none` last

Question: "Select scope (area of change)"
Header: "Scope"
Option descriptions:
- ui - UI components, styling changes
- api - API, backend, data layer changes
- core - Core logic, business logic changes
- none - No specific scope (multiple areas or global)
- Any inferred scope - the directory or package the staged files belong to

## Message Generation

Format: `<emoji> <type>(<scope>): <subject>`, or `<emoji> <type>: <subject>` when scope is `none`.

Validation rules (apply to both the interactive and argument-supplied paths):
- Type is present in the Type-to-emoji mapping table
- Subject starts with lowercase, except proper nouns
- Subject is under 72 characters
- Subject has no trailing period

Example generated messages:
- `✨ feat(ui): add user profile editor`
- `🐛 fix(api): resolve authentication timeout`
- `📝 docs: update installation guide`
- `♻️ refactor(core): optimize state management`

## Git Commit Execution

Commit through a single-quoted heredoc so the message is never subject to shell expansion:

```bash
git commit -F - <<'COMMIT_MSG'
<generated-message>
COMMIT_MSG
```

Flags:
- If `--no-verify` in $ARGUMENTS: add `--no-verify` to skip pre-commit hooks
- If `--amend` in $ARGUMENTS: add `--amend` to amend last commit

After commit: run `git show --stat --oneline HEAD` and report the hash, the message, and the file/insertion/deletion counts taken from that output. Do not report counts that the command did not produce.

## Error Handling

Argument errors — see Message Generation for the rules being enforced:
- Invalid format: report "Conventional Commits format required: type(scope): subject"
- Unknown type: report "Allowed types: see the Type-to-emoji mapping table"
- Subject too long: report "Subject must be under 72 characters, got: [length]"

Execution errors:
- Pre-commit validation failures: use the messages defined in Pre-commit Validations
- git commit fails: report the git error message and suggest a resolution

Security:
- Never expose absolute file paths in error messages
- Never expose stack traces or internal details
- Report only user-actionable information

## Examples

```
/commit "feat(ui): add user profile component" → Execute commit with "✨ feat(ui): add user profile component"
/commit → Interactive mode, use AskUserQuestion to select type and scope
/commit --amend → Amend the last commit; the staged files check is skipped
/commit "fix(api): retry on timeout" --no-verify → Commit while skipping pre-commit hooks
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
