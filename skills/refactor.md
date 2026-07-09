---
allowed-tools: Bash(npm run *) Bash(pnpm run *) Bash(bun run *) Bash(yarn *) Bash(cargo *) Bash(go *) Bash(python *) Bash(git *) Bash(npx *) Read Grep Edit Write AskUserQuestion Task
argument-hint: "<file-path|component-name>"
description: Safe incremental refactoring workflow with quality validation
model: sonnet
---

# Safe Refactoring Command

Refactoring target: $ARGUMENTS

Systematic refactoring workflow with incremental execution and comprehensive validation.

## Argument Validation

Execute validation before any operations:

```bash
# Validate and sanitize refactoring target
validate_target() {
  local target="$1"

  # Reject empty input
  if [[ -z "$target" ]]; then
    echo "ERROR: Refactoring target required"
    echo "Usage: /refactor <file-path|component-name>"
    exit 1
  fi

  # Length validation (1-200 chars)
  if [[ ${#target} -lt 1 || ${#target} -gt 200 ]]; then
    echo "ERROR: Target must be 1-200 characters, got: ${#target}"
    exit 1
  fi

  # Reject path traversal
  if [[ "$target" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected in target"
    exit 2
  fi

  # Reject command injection characters
  local injection_pattern='[;`$()&|*?[]{}<>!]'
  if [[ "$target" =~ $injection_pattern ]]; then
    echo "ERROR: Invalid characters in target"
    echo "Allowed: alphanumeric, spaces, hyphens, underscores, slashes, dots"
    exit 2
  fi

  # Whitelist validation
  if [[ ! "$target" =~ ^[a-zA-Z0-9\ /_.-]+$ ]]; then
    echo "ERROR: Target contains invalid characters"
    echo "Example: 'src/components/TaskCard.tsx' or 'authentication module'"
    exit 1
  fi
}

# Safe argument parsing
TARGET="$ARGUMENTS"
validate_target "$TARGET"
```

If validation fails: exit with error code 1 (user error) or 2 (security error)

## Execution Flow

1. **Git state check**: run `git status --porcelain` — if uncommitted changes exist, warn the user and ask whether to stash/commit first or proceed at their own risk
2. Parse refactoring target from $ARGUMENTS
3. Validate and sanitize inputs
4. Analyze target and determine refactoring scope
5. Create TodoWrite for incremental refactoring phases
6. Execute refactoring with per-phase validation (see Validation at Each Step)
7. Run full quality verification after all phases complete (see Quality Verification)

## Refactoring Analysis

### Impact Scope Analysis

Automated dependency analysis:
- Import/export usage detection
- Component usage context analysis
- Cross-file dependency mapping
- Risk assessment for changes

If target unspecified:
Use Task agent (Explore mode) for project structure understanding and improvement candidate identification.

### Code Quality Diagnosis

Automated analysis:
- File size and complexity (files >100 lines)
- Type safety validation (any types, type assertions)
- Code duplication patterns
- Import/dependency analysis

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
```typescript
// Example: Component splitting with backward compatibility
export const LegacyComponent = OriginalImplementation; // Backward compatibility
export const Component = NewImplementation; // New implementation
```

For technology-specific patterns, see External References section

### Validation at Each Step

Lightweight per-phase check — run after each individual refactoring phase to catch regressions early before proceeding to the next phase.

First, detect the project type and resolve the correct commands:

```
IF Cargo.toml exists    → type_check="cargo check", lint="cargo clippy", test="cargo test", build="cargo build"
ELIF go.mod exists      → type_check="go vet ./...", lint="golangci-lint run", test="go test ./...", build="go build ./..."
ELIF pyproject.toml OR setup.py exists → type_check="mypy .", lint="ruff check .", test="pytest", build=(skip)
ELIF package.json exists:
  IF pnpm-lock.yaml    → prefix="pnpm run"
  ELIF bun.lockb       → prefix="bun run"
  ELIF yarn.lock       → prefix="yarn"
  ELSE                 → prefix="npm run"
  type_check="{prefix} typecheck", lint="{prefix} lint", test="{prefix} test:run", build="{prefix} build"
```

Execute in order (stop on first failure):
1. Type check — zero errors required
2. Linter — no new errors introduced
3. Tests — all existing tests pass

See Quality Verification for the comprehensive final check after all phases.

## Quality Verification

### Automated Quality Checks

Comprehensive final check run after all refactoring phases complete. Use the same project-type detection as "Validation at Each Step" to resolve commands.

Parallel execution for efficiency (exit code based — no false positives from output parsing):

```bash
# Resolve commands via project detection (same logic as Validation at Each Step)
# TYPE_CHECK_CMD / LINT_CMD / TEST_CMD / BUILD_CMD set by detection above

# Run type check and build in parallel (critical checks)
{ $TYPE_CHECK_CMD; echo $? > /tmp/tc_exit; } &
{ $BUILD_CMD; echo $? > /tmp/build_exit; } &
wait

TC_EXIT=$(cat /tmp/tc_exit)
BUILD_EXIT=$(cat /tmp/build_exit)

# Fail fast on critical issues
if [[ $TC_EXIT -ne 0 || $BUILD_EXIT -ne 0 ]]; then
  echo "ERROR: Critical issues detected, refactoring verification failed"
  [[ $TC_EXIT -ne 0 ]]    && echo "  Type check failed (exit $TC_EXIT)"
  [[ $BUILD_EXIT -ne 0 ]] && echo "  Build failed (exit $BUILD_EXIT)"
  exit 3
fi

# Lint (non-blocking: report but continue)
$LINT_CMD && echo "Lint: OK" || echo "WARN: Lint issues detected"

# Tests (non-blocking: report but continue)
$TEST_CMD && echo "Tests: passing" || echo "WARN: Test issues detected"

# Security audit (Node.js only)
if [[ -f package.json ]]; then
  npm audit --production 2>/dev/null && echo "Security: OK" || echo "WARN: Security issues detected"
fi

# Dependency check (Node.js only, if available)
if [[ -f package.json ]]; then
  npx depcheck 2>/dev/null | head -20 || echo "Depcheck unavailable"
fi
```

### Final Checklist

- Type check: zero errors (required)
- Linter: no new errors introduced (required)
- Tests: all existing tests pass (required)
- Build: success with no degradation (required — skip for interpreted languages without a build step)
- Security: no new vulnerabilities (required — Node.js: `npm audit`; Python: `pip-audit`; Rust: `cargo audit`)
- Dependencies: no unused imports (recommended)

For performance optimization, use `/optimize` command instead of manual checks

### Documentation Updates

- Components: add TSDoc format comments
- README: explain changes and new patterns
- CHANGELOG: record breaking changes and notes
- Type definitions: explanatory comments for complex types

## External References

For technology-specific refactoring patterns, refer to:
- **Frontend (React/TypeScript)**: `~/.claude/rules/tech-stacks/frontend-web.md`
- **Backend**: `~/.claude/rules/tech-stacks/backend-api.md`
- **Mobile**: `~/.claude/rules/tech-stacks/mobile-app.md`
- **Rust**: `~/.claude/rules/tech-stacks/rust-cli.md`

For complex refactoring requiring deep analysis:
- **Use refactoring-specialist agent**: Handles complex refactoring with systematic approach
- **Example**: `Task(subagent_type=refactoring-specialist, description="Refactor authentication module")`

For performance optimization:
- **Use /optimize command**: Dedicated performance optimization workflow
- **Example**: `/optimize src/components/TaskList.tsx`

## Tool Usage

TodoWrite: for multi-phase refactoring workflow
AskUserQuestion: refactoring approach selection, scope clarification
Task: for code analysis and impact assessment
Bash: quality checks, build verification
Read: analyze existing code
Edit: apply refactoring changes
Grep: find usage patterns and dependencies

## Error Handling

**Pre-refactor validation failures**:
- Check repository status with `git status`
- Verify no uncommitted changes exist
- Report TypeScript/build errors with file:line references
- Suggest fixing critical issues before refactoring

**TypeScript errors during refactoring**:
- Use AskUserQuestion to determine approach
- Options: fix first, gradual fix, temporary suppression, cancel

**Large scope refactoring detected**:
- Split into multiple phases with TodoWrite
- Use dedicated feature branch (`/worktree` or manual branch)
- Create backup before execution (`git stash` or commit)
- Reduce scope for safer execution

**Build failure during refactoring**:
- Detect automatic rollback opportunity
- Provide recovery options (git stash, manual fix)
- Show build error preview with context

**Security**:
- Never expose absolute paths in error messages
- Report only relative paths from project root
- Never expose stack traces or internal details
- Report only user-actionable information

## Examples

/refactor src/components/TaskCard.tsx → Refactor specific file
/refactor "RichTextEditor component split" → Split large component
/refactor "Task type definition strictness" → Improve type safety
