---
name: iterative-review
description: Multi-perspective review analyzing necessity, security, performance, and maintainability
---

# Iterative Review System

Review Target: $ARGUMENTS

## Overview

Review code, configuration, or documentation from multiple perspectives to discover issues overlooked from single viewpoints. By default, includes Round 0 "Necessity Review" that questions whether features should exist at all before proposing improvements.

## Quick Start

```bash
/iterative-review src/components/Button.tsx
/iterative-review README.md
/iterative-review file.ts --perspectives=necessity --rounds=1
/iterative-review file.ts --skip-necessity
/iterative-review file.ts --perspectives=necessity,security,accessibility
/iterative-review src/components/
/iterative-review --mr 123
/iterative-review --pr 456
```

## Allowed Perspectives

**Default perspectives** (4 total):
- necessity, security, performance, maintainability

**Optional perspectives** (7 total):
- accessibility, i18n, testing, documentation, consistency, scalability, simplicity

**Complete list** (for validation):
necessity, security, performance, maintainability, accessibility, i18n, testing, documentation, consistency, scalability, simplicity

## Argument Validation and Parsing

Parse $ARGUMENTS before execution.

**Default values**:
- rounds: 4
- perspectives: necessity,security,performance,maintainability
- skip-necessity: false
- Max MR/PR requests per day: 10
- Max MR/PR number: 999999

**Target extraction**:
- First non-flag argument is the target (file path or directory)
- File path: allow only characters `[a-zA-Z0-9/_.-]`; reject `..`, `%2e%2e`, `%252e` (path traversal)
- MR/PR: via `--mr=N` or `--pr=N` flag; validate range 1–999999 and daily rate limit

**Optional flags**:
- `--rounds=N`: positive integer
- `--perspectives=list`: comma-separated list validated against the complete list above
- `--skip-necessity`: removes "necessity" from perspectives; sets rounds to 3 (unless explicitly overridden)

**Interactive mode**: If no target provided, use AskUserQuestion to select target type (File/Directory/MR/PR)

**Security requirements**:
- Reject paths with traversal patterns before processing
- Reject unknown flags
- Never pass unsanitized input to Bash commands
- Use Grep/Glob/Read tools instead of Bash for file operations

## Error Handling

On any validation or execution failure:
1. Report error type and user-actionable guidance (no stack traces or internal paths)
2. Use TodoWrite to mark the current task as failed
3. Stop execution

**Error categories**:
- Target missing: use AskUserQuestion (interactive mode)
- Invalid rounds: `"rounds must be positive integer, got: [value]"`
- Invalid perspective: `"invalid perspective '[value]'. Allowed: [complete list from Allowed Perspectives section]"`
- Path traversal: `"invalid path: security validation failed"`
- File read fails: `"review operation failed - verify target path"`
- MR/PR daily limit exceeded: `"Daily MR/PR request limit exceeded (max: 10 per day, resets at midnight)"`

**Exit codes**:

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Mark task completed, continue |
| 1 | User error (invalid input) | Report error, mark failed, stop |
| 2 | Security error (path traversal) | Report error, mark failed, stop |
| 3 | System error (tool failure) | Report error, mark failed, suggest retry |

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
2. Identify target (file/directory/MR/PR)
3. Determine perspectives (apply defaults or parse custom list)
4. Apply --skip-necessity if specified (remove necessity from perspectives, set rounds=3)
5. Create tasks for all review rounds via TodoWrite
6. Execute each perspective review sequentially
7. Update task status via TodoWrite after each round completes
8. Generate integrated report

## Large File Handling Strategy

**Read tool limit**: 2000 lines per call.

For files >2000 lines, use chunked reading:
- First chunk: offset=0, limit=2000
- Next chunk: offset=2000, limit=2000
- Continue until EOF (when fewer lines than limit are returned)

Apply to: Security, Performance, Maintainability perspectives.

## Review Perspective Definitions

### Round 0: Necessity Review

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

### Round 1: Security Perspective

Key check items:
- **Input validation**: Proper validation of all user input
- **Output escaping**: XSS/injection countermeasure implementation
- **Authentication/Authorization**: Permission checks, session management
- **Sensitive information**: Hardcoded secrets, API keys, etc.
- Encrypted communication: HTTPS/TLS usage, sensitive data protection
- Dependencies: Libraries with known vulnerabilities
- OWASP compliance: Response to each OWASP Top 10 item

Analysis methods — use Claude Code tools (NOT Bash commands):

```markdown
# Search for sensitive information
Grep tool with pattern: "password|api_key|secret|token" (case-insensitive)

# Check for dangerous function usage
Grep tool with pattern: "dangerouslySetInnerHTML|eval\(|Function\(|execSync"
```

For files >2000 lines: see Large File Handling Strategy.

### Round 2: Performance Perspective

Key check items:
- **Computational complexity**: Algorithm time/space complexity
- **N+1 problem**: Database queries, API calls in loops
- **Memory leaks**: Proper cleanup of event listeners, timers
- **Bundle size**: Unnecessary dependencies, Tree Shaking optimization
- Rendering: React optimization (useMemo, useCallback)
- Async processing: Proper use of Promise, async/await
- Caching: Implementation of appropriate cache strategies

Analysis methods — use Claude Code tools:

```markdown
# Detect API calls in loops
Grep tool with pattern: "for.*await|while.*await|\.map\(async"

# Identify large files for further inspection
Glob tool with pattern: "**/*.{ts,tsx}" → then Read tool to examine each
```

For files >2000 lines: see Large File Handling Strategy.

### Round 3: Maintainability Perspective

Key check items:
- **Single responsibility principle**: Clarity of each function/component responsibility
- **DRY principle**: Code duplication, abstraction appropriateness
- **Naming conventions**: Consistency, self-documenting naming
- **Type safety**: TypeScript strict mode, type inference utilization
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

For files >2000 lines: see Large File Handling Strategy.

## Review Mode Selection

**Default mode** (with Round 0 — Zero-Based Thinking):
- 4 rounds: necessity, security, performance, maintainability
- Actively considers deletion/simplification
- Best for: new feature proposals, existing feature inventory, CLAUDE.md review, preventing feature bloat

**Constructive mode** (`--skip-necessity`):
- 3 rounds: security, performance, maintainability
- Proposes improvements only
- Best for: features with proven value, features under active development, security/performance improvement purposes

## Perspective Customization

Perspectives other than defaults can be specified. See Allowed Perspectives section for the complete list.

```bash
# Accessibility + i18n focus
/iterative-review components/ --perspectives=accessibility,i18n

# Comprehensive 5-perspective review
/iterative-review src/ --perspectives=necessity,security,performance,maintainability,testing
```

## Target-Specific Reviews

### Document Review (.md)

Additional check items:
- Structure: Hierarchy, table of contents, section division
- Links: Broken internal links, external link validity
- Consistency: Term unification, format unification
- Completeness: Sufficiency/excess of necessary information
- Currency: Old information, date appropriateness

### Configuration File Review (CLAUDE.md, etc.)

Additional check items:
- Practicality: Actually usable commands/procedures
- Maintainability: Bloat, duplication, organization status
- Learning curve: Ease of understanding for new users
- Extensibility: Ease of adding new features

## Integrated Report Format

After all rounds complete, generate an integrated report. Format varies based on --skip-necessity flag.

### Default Mode (with Round 0)

```markdown
# Iterative Review Results

## Basic Information
- Target: [filename/directory/MR number]
- Type: [TypeScript/Python/Document, etc.]
- Review Date/Time: [YYYY-MM-DD HH:MM]
- Number of Perspectives: 4 (necessity, security, performance, maintainability)

## Round 0: Necessity Review

### Final Decision: Recommend Deletion / Recommend Simplification / Justified Retention
Reason: [Specific justification]
Alternative: [Specific alternative means if deletion/simplification recommended]

## Round 1: Security Perspective
[Findings and recommended actions]

## Round 2: Performance Perspective
[Findings and recommended actions]

## Round 3: Maintainability Perspective
[Findings and recommended actions]

## Overall Evaluation

### Round 0 Decision Result
Recommend Deletion / Recommend Simplification / Justified Retention

Note: If Round 0 recommends deletion, subsequent rounds are treated as reference only.

### Priority Action Plan
High Priority (Critical Issues): [file:line references]
Medium Priority (Important Issues): [specific actions]
Low Priority (Minor Improvements): [optional]

### Overall Observations
[Comprehensive improvement direction]
```

### Constructive Mode (--skip-necessity)

Same structure, omitting Round 0 section. Additional header field:
- `Mode: Constructive Review (necessity evaluation skipped)`

Add Findings Summary before Priority Action Plan:
- Critical: [X items]
- Important: [Y items]
- Minor: [Z items]

## Examples

Input: `/iterative-review src/components/Button.tsx`
Action: Execute 4-round review (necessity, security, performance, maintainability) on Button.tsx

Input: `/iterative-review src/ --skip-necessity`
Action: Execute 3-round review (security, performance, maintainability) on src directory

Input: `/iterative-review feature.ts --perspectives=necessity --rounds=1`
Action: Execute necessity review only on feature.ts

Input: `/iterative-review`
Action: Interactive mode, use AskUserQuestion to select target
