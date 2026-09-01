---
name: refactor
description: Safely refactor code files or components with incremental execution and validation. Use when asked to refactor, improve code quality, split a large file, reduce technical debt, or clean up implementation.
argument-hint: "[file-path|component-name]"
allowed-tools: Bash(npm run *) Bash(cargo *) Bash(pytest *) Bash(ruff *) Bash(mypy *) Bash(git status) Bash(git stash) Bash(git stash pop) Read Grep Edit AskUserQuestion Agent
model: sonnet
---

# Safe Refactoring Command

Refactoring target: $ARGUMENTS

Systematic refactoring workflow with incremental execution and comprehensive validation.

## Argument Validation

Parse $ARGUMENTS before any operations:
- Reject empty input: report "Usage: /refactor <file-path|component-name>" and exit (exit code 1)
- Reject path traversal (..): report security error (exit code 2)
- Reject command injection characters (`;`, `` ` ``, `$`, `(`, `)`, `&`, `|`, `*`): report invalid characters (exit code 2)
- Validate: alphanumeric, spaces, hyphens, underscores, slashes, dots only
- Length: 1–200 characters

If validation fails: report error type and expected format, then exit

## Execution Flow

1. Parse refactoring target from $ARGUMENTS
2. Validate and sanitize inputs
3. Check repository state with `git status` — if uncommitted changes exist, use AskUserQuestion to confirm stash or abort
4. Detect project type from config files (see Quality Verification section)
5. Analyze target and determine refactoring scope
6. Create tasks with TodoWrite for incremental refactoring phases
7. Execute refactoring with validation at each step
8. Verify quality metrics and functionality preservation

## Refactoring Analysis

### Impact Scope Analysis

Analyze using Grep and Read:
- Import/export usage detection
- Component usage context analysis
- Cross-file dependency mapping
- Risk assessment for changes

If target unspecified:
Use the Agent tool (subagent_type: Explore) for project structure understanding and improvement candidate identification.

### Code Quality Diagnosis

Analyze using Read and Grep:
- File size and complexity (files >100 lines)
- Type safety issues (any types, type assertions)
- Code duplication patterns
- Import/dependency coupling

Quality metrics:
- Complexity: files exceeding 100 lines are split candidates
- Type safety: any type and type assertion usage
- Duplication: identical function/component patterns
- Dependencies: coupling evaluation by import frequency

### Risk Assessment

Technical risks:
- Breaking changes, interface modifications, dependency impacts
- Mitigation: incremental migration, interface preservation, backward compatibility

Quality risks:
- Test coverage, type safety, performance impacts
- Mitigation: test additions, type definition strengthening, measurement and verification

Development efficiency risks:
- Impact on other developers, learning costs, maintainability
- Mitigation: phased migration, documentation, review processes

## Refactoring Implementation

### Implementation Priorities

1. Type definitions and interfaces: establish safety foundation
2. Common utilities: remove duplication, extract functions
3. Component/module splitting: separation based on single responsibility
4. Backward compatibility: maintain existing interfaces during migration
5. Documentation: record changes and new patterns

### Safe Implementation Pattern

Maintain backward compatibility during refactoring:
- Keep existing exports and interfaces intact while introducing new ones
- Alias old names to new implementations during transition period
- Remove legacy aliases only after all call sites are migrated

For technology-specific patterns, see External References section

### Validation at Each Step

After each refactoring phase, run the checks appropriate for the detected project type:

1. Type check — zero errors required (typecheck / cargo check / mypy)
2. Linter — no new errors (lint / clippy / ruff)
3. Tests — all existing tests must pass (test:run / cargo test / pytest)
4. Build — must succeed (build / cargo build / N/A for Python)

If type check or build fails: stop refactoring, report "ERROR: Critical issues detected" with file:line references, and present recovery options.

## Quality Verification

### Project Type Detection

Detect project type from config files before running any checks:

```
package.json present → Node.js/TypeScript project
  → npm run typecheck / npm run lint / npm run test:run / npm run build

Cargo.toml present → Rust project
  → cargo check --all-features / cargo clippy -- -D warnings / cargo test

pyproject.toml or setup.py present → Python project
  → ruff check . / mypy . / pytest

Both package.json and Cargo.toml → run checks for both
```

### Automated Quality Checks

Run using Bash tool after all refactoring phases complete (commands vary by project type above):

If `typecheck` / `cargo check` / `mypy` fails: report error count with file:line references

Optional checks when available:
```bash
# Node.js
npm audit --production
npx depcheck

# Rust
cargo audit
cargo machete
```

### Final Checklist

- All per-phase checks pass: type check, linter, tests, build (see Validation at Each Step) (required)
- Security: no new vulnerabilities (required)
- Dependencies: no unused imports (recommended)

### Documentation Updates

- Components/modules: add doc comments in the project's standard format (TSDoc / rustdoc / docstrings)
- README: explain changes and new patterns
- CHANGELOG: record breaking changes and notes
- Type definitions: explanatory comments for complex types

## Completion Report

Present results to the user in this format:

```markdown
## Refactoring Complete: <target>

### Changes
- <file>: <what changed — split / extracted / renamed / type-strengthened>

### Verification
| Check | Result |
|---|---|
| Type check | ✅ 0 errors |
| Linter | ✅ no new errors |
| Tests | ✅ <passed>/<total> passed |
| Build | ✅ success |

### Metrics (before → after)
- <file>: <lines> → <lines> lines
- <quality metric, e.g. any usage>: <n> → <n>

### Remaining Issues
- <deferred item and reason> (omit section if none)
```

## External References

For technology-specific refactoring patterns, refer to:
- **Frontend (React/TypeScript)**: `~/.claude/rules/tech-stacks/frontend-web.md`
- **Backend**: `~/.claude/rules/tech-stacks/backend-api.md`
- **Mobile**: `~/.claude/rules/tech-stacks/mobile-app.md`

For complex refactoring requiring deep analysis, use the refactoring-specialist agent via the Agent tool.

## Tool Usage

Agent: code analysis, impact assessment, complex refactoring delegation
AskUserQuestion: refactoring approach selection, scope clarification
Bash: quality checks, build verification
Read: analyze existing code
Edit: apply refactoring changes
Grep: find usage patterns and dependencies

## Error Handling

**Pre-refactor validation failures**:
- Check repository status with `git status`
- Verify no uncommitted changes exist
- Report type-check/build errors with file:line references
- Suggest fixing critical issues before refactoring

**Type errors during refactoring**:
- Use AskUserQuestion to determine approach
- Options: fix first, gradual fix, temporary suppression, cancel

**Large scope refactoring detected**:
- Split into multiple phases using TodoWrite
- Use dedicated feature branch
- Create backup before execution (`git stash`)
- Reduce scope for safer execution

**Build failure during refactoring**:
- Detect automatic rollback opportunity
- Provide recovery options (git stash, manual fix)
- Show build error preview with context

**Security**:
- Never expose absolute paths in error messages
- Report only relative paths from project root
- Never expose stack traces or internal details

## Examples

/refactor src/components/TaskCard.tsx → Refactor specific file
/refactor "RichTextEditor component split" → Split large component
/refactor "Task type definition strictness" → Improve type safety
/refactor → AskUserQuestion: target selection from project structure
/refactor "../../etc/passwd" → Report error: "Path traversal detected"
/refactor "" → Report error: "Usage: /refactor <file-path|component-name>"
