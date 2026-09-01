---
name: iterative-review
description: Multi-perspective review analyzing necessity, security, performance, and maintainability
argument-hint: "<target> [--perspectives=list] [--skip-necessity] [--mr=N|--pr=N]"
allowed-tools: Read Grep Glob TodoWrite AskUserQuestion Bash(gh pr view *) Bash(gh pr diff *) Bash(glab mr view *) Bash(glab mr diff *)
---

# Iterative Review System

Review Target: $ARGUMENTS

## Overview

Review code, configuration, or documentation from multiple perspectives to discover issues overlooked from single viewpoints. By default, includes Round 0 "Necessity Review" that questions whether features should exist at all before proposing improvements.

## Perspectives

**Complete list** — the single source of truth for validation:
necessity, security, performance, maintainability, accessibility, i18n, testing, documentation, consistency, scalability, simplicity

**Default set** (applied when `--perspectives` is absent):
necessity, security, performance, maintainability

The first four are defined inline under Review Perspective Definitions. The
remaining seven are defined in `${CLAUDE_SKILL_DIR}/perspectives.md` — read that
file only when the resolved perspective list contains at least one of them.

## Argument Validation and Parsing

Parse $ARGUMENTS before execution. Reject unknown flags.

**Target extraction**:
- First non-flag argument is the target (file path or directory)
- File path: allow only characters `[a-zA-Z0-9/_.~-]`; reject `..`, `%2e%2e`, `%252e` (path traversal). A leading `~` is expanded to the home directory after validation
- MR/PR: via `--mr=N` (GitLab) or `--pr=N` (GitHub); N is an integer in range 1–999999. These flags replace the file-path target; supplying both a path and `--mr`/`--pr` is an error

**Optional flags**:
- `--perspectives=list`: comma-separated, validated against the complete list above
- `--skip-necessity`: removes `necessity` from the resolved perspective list. If `necessity` is not present, the flag has no effect and is not an error
- `--rounds=N`: accepted for backward compatibility and **ignored**. Round count is always derived — see Round Count below

**Round count** (derived, never configured):

```
rounds = number of perspectives in the resolved list
```

Round numbers are assigned by position in the resolved list. `necessity`, when
present, is always Round 0 and is evaluated first; the remaining perspectives take
Rounds 1..N in the order given. If `--rounds=N` was supplied and N differs from
the derived count, proceed with the derived count and add one line to the report:
`Note: --rounds=[N] ignored; [derived] perspectives selected.`

**Interactive mode**: If no target and no `--mr`/`--pr` is provided, use AskUserQuestion to select target type (File/Directory/MR/PR)

**Security requirements**:
- Reject paths with traversal patterns before processing
- Use Grep/Glob/Read for all file operations — never Bash
- Bash is permitted only for the MR/PR fetch commands listed under Fetching an MR/PR, with the number passed as a validated integer
- Never interpolate unvalidated input into a Bash command

## Error Handling

On any validation or execution failure:
1. Report error type and user-actionable guidance (no stack traces or internal paths)
2. Use TodoWrite to mark the current task as failed
3. Stop, unless the outcome below says otherwise

**Error categories and outcomes**:

| Category | Message | Outcome |
|----------|---------|---------|
| Target missing | — | Enter interactive mode (AskUserQuestion) |
| Invalid perspective | `invalid perspective '[value]'. Allowed: [complete list from Perspectives section]` | Report, mark failed, stop |
| Unknown flag | `unknown flag: [value]` | Report, mark failed, stop |
| Conflicting target | `specify either a path or --mr/--pr, not both` | Report, mark failed, stop |
| Invalid MR/PR number | `--mr/--pr must be an integer in 1-999999, got: [value]` | Report, mark failed, stop |
| Path traversal | `invalid path: security validation failed` | Report, mark failed, stop |
| File read fails | `review operation failed - verify target path` | Report, mark failed, stop |
| MR/PR fetch fails | `could not fetch [mr/pr] [N] - verify the number and repository access` | Report, mark failed, suggest retry |
| Missing CLI | `[gh/glab] not found - install it or review a local path instead` | Report, mark failed, stop |

Never silently fail. Always update task status before stopping.

## Basic Approach

As an experienced senior engineer, iteratively review targets from multiple expert perspectives:
- Zero-based thinking: Ask "is this even needed?" first rather than "how to improve"
- Don't hesitate to delete: Actively recommend deletion of unnecessary features
- Bold proposals: Include "fundamental reconsideration" as an option
- Multi-angle analysis: Comprehensive evaluation from different expert perspectives
- Prioritization: Importance classification (deletion > simplification > improvement)

## Execution Flow

Use TodoWrite to track progress:
1. Parse and validate arguments from $ARGUMENTS
2. Identify target (file/directory/MR/PR); fetch MR/PR content if applicable
3. Resolve the perspective list (defaults or `--perspectives`), then apply `--skip-necessity`
4. Derive the round count and assign round numbers per Round Count
5. If the resolved list contains any optional perspective, read `${CLAUDE_SKILL_DIR}/perspectives.md`
6. Create one TodoWrite task per round
7. Execute each perspective review in round order
8. Update task status via TodoWrite after each round completes
9. Generate the integrated report

## Reading the Target

**Read tool limit**: 2000 lines per call.

For files >2000 lines, use chunked reading:
- First chunk: offset=0, limit=2000
- Next chunk: offset=2000, limit=2000
- Continue until EOF (when fewer lines than limit are returned)

Apply to every perspective that reads the target, including necessity.

For directory targets, use Glob to enumerate files, then apply the same strategy per file.

### Fetching an MR/PR

Check the CLI exists before use; if absent, report the Missing CLI error.

GitHub (`--pr=N`):
```bash
gh pr view N
gh pr diff N
```

GitLab (`--mr=N`):
```bash
glab mr view N
glab mr diff N
```

N is the validated integer only — never a raw argument string. Review the returned
diff as the target; `file:line` references come from the diff headers.

## Review Perspective Definitions

### Necessity (Round 0)

Purpose: Eliminate status quo bias. Ask "is this even needed?" not "how to improve it."

Required check items:

**Fundamental necessity evaluation**:
- Real use cases: Can you list 3+ concrete scenarios where this is "actually used" (not just "seems useful")?
- Predicted weekly/monthly usage frequency
- Alternative means: Can existing features/commands/tools substitute?
- Cost of complexity: Is the value worth the added complexity?

**Deletion/consolidation potential**:
- Deletion impact: What is the actual harm if this feature is deleted?
- Consolidation: Can it be merged into existing features?
- Simplification: Can the same value be provided with simpler implementation?

**Value proposition**:
- Can the raison d'être be explained in one sentence?
- Should this be prioritized over other improvements/new features?

**Evaluation criteria**:

| Item | Recommend Deletion | Needs Review | Justified Retention |
|------|-------------------|--------------|---------------------|
| Real use cases | 0-1 cases | 2-3 cases | 4+ cases |
| Alternative means | Easily achievable | Some effort required | Difficult |
| Usage frequency | Less than monthly | Weekly | 3+ times/week |
| Maintenance cost | High | Medium | Low |

**Result expression**:
- Recommend deletion: "This feature is unnecessary. Reason: [specific reason]. Alternative: [how to achieve with existing features]"
- Recommend simplification: "Current implementation is excessive. Should narrow to [X feature] only"
- Justified retention: "Clear value exists. However, [Y] improvement needed"

### Security

Key check items:
- **Input validation**: Proper validation of all user input
- **Output escaping**: XSS/injection countermeasure implementation
- **Authentication/Authorization**: Permission checks, session management
- **Sensitive information**: Hardcoded secrets, API keys, etc.
- Encrypted communication: HTTPS/TLS usage, sensitive data protection
- Dependencies: Libraries with known vulnerabilities

Authority for the detailed criteria — read the file matching the target's stack
rather than restating its rules here:
`~/.claude/rules/tech-stacks/backend-api.md` (OWASP API Top 10, authn/authz,
injection), `~/.claude/rules/tech-stacks/frontend-web.md` (XSS, CSP, token
storage), `~/.claude/rules/tech-stacks/shell-cli.md` (18 shell security items).

Analysis methods — use Claude Code tools:

```markdown
# Search for sensitive information
Grep tool with pattern: "password|api_key|secret|token" (case-insensitive)

# Check for dangerous function usage
Grep tool with pattern: "dangerouslySetInnerHTML|eval\(|Function\(|execSync"
```

### Performance

Key check items:
- **Computational complexity**: Algorithm time/space complexity
- **N+1 problem**: Database queries, API calls in loops
- **Memory leaks**: Proper cleanup of event listeners, timers
- **Bundle size**: Unnecessary dependencies, Tree Shaking optimization
- Rendering: framework-level optimization
- Async processing: Proper use of Promise, async/await
- Caching: Implementation of appropriate cache strategies

Authority for budgets and thresholds:
`~/.claude/rules/tech-stacks/frontend-web.md` (Core Web Vitals, bundle budgets),
`~/.claude/rules/tech-stacks/backend-api.md` (response-time targets, N+1, pooling).

Analysis methods — use Claude Code tools:

```markdown
# Detect API calls in loops
Grep tool with pattern: "for.*await|while.*await|\.map\(async"

# Identify large files for further inspection
Glob tool with pattern: "**/*.{ts,tsx}" → then Read tool to examine each
```

### Maintainability

Key check items:
- **Single responsibility principle**: Clarity of each function/component responsibility
- **DRY principle**: Code duplication, abstraction appropriateness
- **Naming conventions**: Consistency, self-documenting naming
- **Type safety**: strict mode enabled, type inference utilized, escape hatches avoided
- Testability: Unit test ease, dependency injection
- Documentation: Comments, JSDoc, README appropriateness
- Error handling: Exception handling, error message quality

Analysis methods — use Claude Code tools:

```markdown
# Check for missing type annotations
Grep tool with pattern: ": any|as any" (type: typescript)

# Detect potential code duplication
Grep tool with pattern: "function.*\{" (type: typescript)
```

## Mode Selection

`necessity` is included by default. Decide whether to keep it:

```
IF --skip-necessity supplied:
    remove necessity
ELIF target is under active development, has proven production value,
     or the request names a specific concern (security/performance/etc.):
    suggest --skip-necessity in the report's Overall Observations; still run necessity
ELSE:
    keep necessity (new proposals, feature inventory, CLAUDE.md and skill review,
    anything at risk of feature bloat)
```

## Target-Specific Additional Checks

Apply in addition to the selected perspectives, based on the target's type.

**Documents (.md)**:
- Structure: Hierarchy, table of contents, section division
- Links: Broken internal links, external link validity
- Consistency: Term unification, format unification
- Completeness: Sufficiency/excess of necessary information
- Currency: Old information, date appropriateness

**Configuration and instruction files (CLAUDE.md, SKILL.md, rules/*.md)**:
- Practicality: Actually usable commands/procedures
- Maintainability: Bloat, duplication, organization status
- Learning curve: Ease of understanding for new users
- Extensibility: Ease of adding new features

## Integrated Report Format

After all rounds complete, generate one report using the template below. The
round sections are generated from the resolved perspective list — one section per
perspective, in round order.

```markdown
# Iterative Review Results

## Basic Information
- Target: [file path / directory / MR or PR number]
- Type: [TypeScript/Python/Document, etc.]
- Review Date/Time: [YYYY-MM-DD HH:MM]
- Perspectives: [count] ([comma-separated resolved list])
[- Mode: Constructive Review (necessity evaluation skipped)   ← only when necessity is absent]
[- Note: --rounds=[N] ignored; [derived] perspectives selected.  ← only when --rounds was supplied and differed]

## Round [i]: [Perspective]
[Findings and recommended actions, each with file:line]
... one section per perspective, in round order ...

## Overall Evaluation

### Necessity Decision            ← only when necessity was evaluated
Recommend Deletion / Recommend Simplification / Justified Retention
Reason: [specific justification]
Alternative: [specific alternative means if deletion/simplification recommended]

Note: If necessity recommends deletion, subsequent rounds are reference only.

### Findings Summary
- Critical: [X items]
- Important: [Y items]
- Minor: [Z items]

### Priority Action Plan
High Priority (Critical Issues): [file:line] — [specific action]
Medium Priority (Important Issues): [file:line] — [specific action]
Low Priority (Minor Improvements): [file:line] — [specific action]

### Overall Observations
[Comprehensive improvement direction]
```

Every priority level carries `file:line` references. For MR/PR targets, derive
them from the diff headers.

## Examples

Input: `/iterative-review src/components/Button.tsx`
Action: 4 rounds (necessity, security, performance, maintainability) on Button.tsx

Input: `/iterative-review src/ --skip-necessity`
Action: 3 rounds (security, performance, maintainability) on the src directory

Input: `/iterative-review feature.ts --perspectives=necessity`
Action: 1 round (necessity) on feature.ts

Input: `/iterative-review components/ --perspectives=accessibility,i18n`
Action: Read `${CLAUDE_SKILL_DIR}/perspectives.md`, then 2 rounds on components/

Input: `/iterative-review --pr=456`
Action: `gh pr view 456` + `gh pr diff 456`, then 4 default rounds on the diff

Input: `/iterative-review`
Action: Interactive mode, use AskUserQuestion to select target type

Error cases:

Input: `/iterative-review file.ts --perspectives=perf`
Action: `ERROR: invalid perspective 'perf'. Allowed: necessity, security, performance, maintainability, accessibility, i18n, testing, documentation, consistency, scalability, simplicity`

Input: `/iterative-review ../../etc/passwd`
Action: `ERROR: invalid path: security validation failed`

Input: `/iterative-review file.ts --verbose`
Action: `ERROR: unknown flag: --verbose`

Input: `/iterative-review src/ --pr=456`
Action: `ERROR: specify either a path or --mr/--pr, not both`

Input: `/iterative-review --pr=0`
Action: `ERROR: --mr/--pr must be an integer in 1-999999, got: 0`

Input: `/iterative-review file.ts --perspectives=security,performance --rounds=3`
Action: 2 rounds (security, performance); report includes `Note: --rounds=3 ignored; 2 perspectives selected.`
