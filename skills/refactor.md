---
allowed-tools: Bash, Read, Grep, Edit, Write, TodoWrite, AskUserQuestion, Task
argument-hint: "[file-path|component-name]"
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

1. Parse refactoring target from $ARGUMENTS
2. Validate and sanitize inputs
3. Analyze target and determine refactoring scope
4. Create TodoWrite for incremental refactoring phases
5. Execute refactoring with validation at each step
6. Verify quality metrics and functionality preservation

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

Execute automated checks after each refactoring phase:
- Type check: `npm run typecheck` - zero errors required
- Linter: `npm run lint` - prevent new error increases
- Tests: `npm run test:run` - verify existing tests pass
- Build: `npm run build` - confirm build success

See Quality Verification section for parallel execution pattern

## Quality Verification

### Automated Quality Checks

Parallel execution for efficiency:

```bash
# Parallel quality checks (30-50% faster)
{
  TS_ERRORS=$(npm run typecheck 2>&1 | grep -c "error" || echo "0") &
  LINT_ERRORS=$(npm run lint 2>&1 | grep -c "error" || echo "0") &
  BUILD_STATUS=$(npm run build 2>&1 | grep -c "failed\|error" || echo "0") &
  wait
}

# Fail fast on critical issues
if [[ $TS_ERRORS -gt 0 || $BUILD_STATUS -gt 0 ]]; then
  echo "ERROR: Critical issues detected, refactoring verification failed"
  echo "  TypeScript errors: $TS_ERRORS"
  echo "  Build errors: $BUILD_STATUS"
  exit 3
fi

# Tests (if available)
npm run test:run --silent 2>/dev/null && echo "Tests passing" || echo "Test issues detected"

# Security audit
npm audit --production 2>/dev/null && echo "No vulnerabilities" || echo "Security issues detected"

# Dependency check (unused imports)
npx depcheck 2>/dev/null | head -20 || echo "Depcheck unavailable"
```

### Final Checklist

- TypeScript: zero errors (required)
- ESLint: no new errors (required)
- Tests: all existing tests pass (required)
- Build: success with no degradation (required)
- Security: no new vulnerabilities (required)
- Dependencies: no unused imports (recommended)

For performance optimization, use `/optimize` command instead of manual checks

### Documentation Updates

- Components: add TSDoc format comments
- README: explain changes and new patterns
- CHANGELOG: record breaking changes and notes
- Type definitions: explanatory comments for complex types

## External References

For technology-specific refactoring patterns, refer to:
- **Frontend (React/TypeScript)**: `~/.claude/stacks/frontend-web.md`
- **Backend**: `~/.claude/stacks/backend-api.md`
- **Mobile**: `~/.claude/stacks/mobile-app.md`

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
