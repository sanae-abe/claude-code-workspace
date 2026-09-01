---
name: refactor
description: Safely refactor code files or components with incremental execution and validation. Use when asked to refactor, improve code quality, split a large file, reduce technical debt, or clean up implementation.
argument-hint: "[file-path|component-name]"
allowed-tools: Skill Bash(npm run *) Bash(npx *) Bash(cargo *) Bash(pytest) Bash(pytest *) Bash(ruff *) Bash(mypy *) Bash(git status) Bash(git stash) Bash(git stash pop) Read Grep Write Edit TodoWrite AskUserQuestion Agent
disable-model-invocation: true
model: sonnet
---

# Safe Refactoring Command

Refactoring target: $ARGUMENTS

Systematic refactoring workflow with incremental execution and comprehensive validation.

## Argument Validation

Parse $ARGUMENTS before any operations:
- Empty input is valid: it selects interactive mode — proceed to Execution Flow step 2
- Reject path traversal (..): report "Path traversal detected in target" and stop
- Reject command injection characters (`;`, `` ` ``, `$`, `(`, `)`, `&`, `|`, `*`): report "Invalid characters in target" and stop
- Validate: alphanumeric, spaces, hyphens, underscores, slashes, dots only
- Length: at most 200 characters

If validation fails: report the error type and the expected format
(`<file-path|component-name>`), then stop without reading or modifying any file

## Execution Flow

1. Parse and validate the refactoring target from $ARGUMENTS (see Argument Validation)
2. If the target is empty, resolve it interactively: use the Agent tool (subagent_type: Explore)
   to map the project structure and surface improvement candidates, then use AskUserQuestion
   to have the user pick one. Do not proceed until a concrete target is selected
3. Check repository state with `git status` — if uncommitted changes exist, use AskUserQuestion
   to confirm `git stash` or abort. If stashed, restore it with `git stash pop` in step 8
4. Establish a green baseline: invoke `/validate --layers=syntax,integration` via Skill tool.
   If it fails, report the pre-existing failures with file:line references and stop — refactoring
   on top of a red working tree makes introduced errors indistinguishable from existing ones
5. Analyze target and determine refactoring scope
6. Create tasks with TodoWrite for incremental refactoring phases
7. Execute refactoring with validation at each step
8. Verify quality metrics and functionality preservation, then restore the step 3 stash if one exists

## Refactoring Analysis

### Impact Scope Analysis

Analyze using Grep and Read:
- Import/export usage detection
- Component usage context analysis
- Cross-file dependency mapping
- Risk assessment for changes

The target is always concrete at this point — Execution Flow step 2 resolves an empty target
via Explore + AskUserQuestion before analysis begins.

### Code Quality Diagnosis

Analyze using Read and Grep:
- Complexity: split candidates are files well above the repository's own norm — compare against
  sibling files of the same kind, and treat 300+ lines as a candidate when no norm is discernible
- Type safety: `any` type and type assertion usage
- Duplication: identical function/component patterns
- Dependencies: coupling evaluation by import frequency

For language-specific thresholds and patterns, see External References section

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

After each refactoring phase, invoke `/validate --layers=syntax,integration` via Skill tool.
It detects the project type and runs type check, linter, formatter and tests for it.

If /validate is unavailable, fall back to the per-toolchain commands directly:

```
package.json present → npm run typecheck / npm run lint / npm run test:run
Cargo.toml present   → cargo check --all-features / cargo clippy -- -D warnings / cargo test
pyproject.toml or setup.py present → mypy . / ruff check . / pytest
```

Build verification is not covered by /validate — run it separately after the final phase
(`npm run build` / `cargo build`; not applicable to Python).

If a per-phase check fails: stop refactoring, report "ERROR: Critical issues detected" with file:line references, and present recovery options.

## Quality Verification

### Automated Quality Checks

After all refactoring phases complete, invoke `/validate --layers=all` via Skill tool —
this adds the security layer on top of the per-phase checks.

If /validate reports failures: report the error count with the file:line references from its output.

Dependency hygiene is not covered by /validate — run these when the tools are available:
```bash
npx depcheck      # Node.js: unused dependencies
cargo machete     # Rust: unused dependencies
```

### Final Checklist

- All per-phase checks pass: type check, linter, tests (see Validation at Each Step) (required)
- Build succeeds after the final phase: `npm run build` / `cargo build`; N/A for Python (required)
  If the build fails: stop, report "ERROR: Build failed" with file:line references, and present recovery options
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

If the run stops before all phases complete, report in this format instead:

```markdown
## Refactoring Aborted: <target>

### Stopped at
Phase <n>/<total>: <what was being changed>

### Reason
<failing check> — <file:line>: <error>

### Working tree state
- Applied: <files already changed>
- Stash from step 3: <present / none>

### Next step
<the single concrete action the user should take>
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
Skill: invoke /validate for type check, lint, format and test verification
Bash: build verification, dependency hygiene, fallback when /validate is unavailable
Read: analyze existing code
Write: create new files when splitting a file or extracting a module
Edit: apply refactoring changes to existing files
Grep: find usage patterns and dependencies

## Error Handling

**Pre-refactor validation failures** (Execution Flow step 4):
- Report the failing checks with file:line references from the /validate output
- Do not start refactoring — pre-existing failures make introduced errors indistinguishable
- Use AskUserQuestion: fix the pre-existing failures first, or abort

**Type errors during refactoring**:
- Use AskUserQuestion to determine approach
- Options: fix first, gradual fix, temporary suppression, cancel

**Large scope refactoring detected**:
- Split into multiple phases using TodoWrite
- Use a dedicated feature branch
- Commit at each phase boundary so every phase has its own rollback point
- Never run `git stash` mid-refactor: step 3 already cleared the working tree, so stashing
  here would shelve the in-progress refactoring itself
- Reduce scope for safer execution

**Build failure during refactoring**:
- Show the build error with file:line references and surrounding context
- If the failing phase touched 3 files or fewer and created no new files: present the exact
  revert command for the user to run (`git checkout -- <files>`), then retry the phase
- Otherwise: leave the working tree untouched and use AskUserQuestion — fix forward, or abort
- This skill has no grant to discard work; never run a revert or reset on the user's behalf

**Security**:
- Never expose absolute paths in error messages
- Report only relative paths from project root
- Never expose stack traces or internal details

## Examples

/refactor src/components/TaskCard.tsx → Refactor specific file
/refactor "RichTextEditor component split" → Split large component
/refactor "Task type definition strictness" → Improve type safety
/refactor → Interactive mode: Explore the project, then AskUserQuestion for target selection
/refactor "" → Interactive mode (same as no argument)
/refactor "../../etc/passwd" → Report error: "Path traversal detected in target" and stop
