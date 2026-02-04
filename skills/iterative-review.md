---
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, TodoWrite, AskUserQuestion, Task
argument-hint: "<target> [--rounds=4] [--perspectives=necessity,security,performance,maintainability] [--skip-necessity]"
description: Multi-perspective review analyzing necessity, security, performance, and maintainability
model: sonnet
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

## Variable Reference

**$ARGUMENTS**: Automatically populated by Claude Code slash command system
- Contains all arguments passed after `/iterative-review`
- Example: `/iterative-review foo.ts --rounds=2` → `$ARGUMENTS = "foo.ts --rounds=2"`
- Empty if no arguments provided → triggers interactive mode (see line 157-189)
- Type: string (space-separated arguments)

## Allowed Perspectives

**Default perspectives** (4 total):
- necessity, security, performance, maintainability

**Optional perspectives** (7 total):
- accessibility, i18n, testing, documentation, consistency, scalability, simplicity

**Complete list** (for validation):
necessity, security, performance, maintainability, accessibility, i18n, testing, documentation, consistency, scalability, simplicity

## Argument Validation and Parsing

Parse and validate $ARGUMENTS before execution:

### Validation Rules

**Target extraction**:
- File path: validate with `validate_path_security()` function (see Configuration Constants section)
  - Whitelist: only allow `[a-zA-Z0-9/_.-]` characters
  - Reject path traversal: `..`, `%2e%2e`, `%252e`
  - Final validation delegated to Read tool's built-in security
- Directory: validate exists and is directory (after path validation)
- MR/PR number: validate via `--mr` or `--pr` flag, range 1-999999, max 10 per day

**Optional flags**:
- `--rounds=N`: positive integer (default: 4, from `DEFAULT_ROUNDS`)
- `--perspectives=list`: validate with `validate_perspectives()` function (default: from `DEFAULT_PERSPECTIVES`)
- `--skip-necessity`: boolean flag (default: false)

**Security requirements**:
- Check for path traversal patterns before processing
- Reject unexpected flag patterns
- Never pass unsanitized input to Bash commands
- Use Grep/Glob/Read tools instead of Bash for file operations

**Failure handling**:
- Validation fails: report expected format and exit
- Target not found: report error with example usage
- Interactive mode: use AskUserQuestion if no target specified

<details>
<summary><strong>Reference Implementation (click to expand)</strong></summary>

```bash
# Initialize variables with defaults
TARGET=""
ROUNDS=$DEFAULT_ROUNDS
PERSPECTIVES="$DEFAULT_PERSPECTIVES"
SKIP_NECESSITY=false

# Parse $ARGUMENTS
IFS=' ' read -r -a args <<< "$ARGUMENTS"

for arg in "${args[@]}"; do
  case "$arg" in
    --rounds=*)
      ROUNDS="${arg#*=}"
      if [[ ! "$ROUNDS" =~ ^[0-9]+$ ]] || [[ "$ROUNDS" -lt 1 ]]; then
        echo "ERROR: rounds must be positive integer, got: $ROUNDS"
        echo "File: iterative-review.md:151-154 - Argument Validation"
        exit $EXIT_USER_ERROR
      fi
      ;;
    --perspectives=*)
      PERSPECTIVES="${arg#*=}"
      # Validation deferred to validate_perspectives()
      ;;
    --skip-necessity)
      SKIP_NECESSITY=true
      ;;
    --mr=*|--pr=*)
      MR_NUMBER="${arg#*=}"
      validate_mr_number "$MR_NUMBER"
      TARGET="MR/PR:$MR_NUMBER"
      ;;
    --*)
      echo "ERROR: Unknown flag: $arg"
      echo "File: iterative-review.md:169-171 - Argument Validation"
      echo ""
      echo "Usage: /iterative-review <target> [--rounds=N] [--perspectives=list] [--skip-necessity]"
      exit $EXIT_USER_ERROR
      ;;
    *)
      [[ -z "$TARGET" ]] && TARGET="$arg"
      ;;
  esac
done

# Apply --skip-necessity logic
if [[ "$SKIP_NECESSITY" == true ]]; then
  PERSPECTIVES="${PERSPECTIVES//necessity,/}"
  PERSPECTIVES="${PERSPECTIVES//,necessity/}"
  PERSPECTIVES="${PERSPECTIVES//necessity/}"
  [[ "${ROUNDS}" == "4" ]] && ROUNDS=3
fi

# Validate perspectives
validate_perspectives "$PERSPECTIVES"

# Interactive mode if no target
if [[ -z "$TARGET" ]]; then
  # Use AskUserQuestion to select: File/Directory/MR/PR
  echo "ERROR: No target specified"
  echo "File: iterative-review.md:192-195 - Argument Validation"
  echo ""
  echo "Use AskUserQuestion to select target type (File/Directory/MR/PR)"
  echo "Or provide target: /iterative-review <file-path>"
  exit $EXIT_USER_ERROR
fi

# Path security validation for file/directory
if [[ ! "$TARGET" =~ ^MR/PR: ]]; then
  validate_path_security "$TARGET" || exit $EXIT_SECURITY_ERROR
fi
```
</details>

## Configuration Constants

```bash
# Perspective Configuration
ALLOWED_PERSPECTIVES="necessity security performance maintainability accessibility i18n testing documentation consistency scalability simplicity"
DEFAULT_PERSPECTIVES="necessity,security,performance,maintainability"
DEFAULT_ROUNDS=4

# Rate Limiting Configuration
MAX_MR_PR_REQUESTS=10
MR_PR_COUNT_FILE="/tmp/.claude_iterative_review_mr_count_$(date +%Y%m%d)"

# File Handling Configuration
READ_CHUNK_SIZE=2000

# Exit Code Constants (aligned with Exit Code System)
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_SYSTEM_ERROR=3
```

## Validation Implementation

Implement validation using Bash and Claude Code tools:

### Path Validation

Enhanced validation with multiple attack pattern detection:

```bash
validate_path_security() {
  local path="$1"

  # 1. Whitelist validation - allow only safe characters
  if [[ ! "$path" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
    echo "ERROR: Invalid characters in path"
    echo "File: iterative-review.md:238-241 - Path Validation"
    echo ""
    echo "Allowed characters: [a-zA-Z0-9/_.-]"
    echo "Remove special characters from path"
    return $EXIT_SECURITY_ERROR
  fi

  # 2. Path traversal detection (multiple patterns)
  if [[ "$path" =~ \.\. ]] || [[ "$path" =~ %2e%2e ]] || [[ "$path" =~ %252e ]]; then
    echo "ERROR: Path traversal detected"
    echo "File: iterative-review.md:244-247 - Path Validation"
    echo ""
    echo "Security policy: Paths must not contain '..' or URL-encoded variants"
    echo "Use absolute paths or relative paths from project root"
    return $EXIT_SECURITY_ERROR
  fi

  # 3. Read tool's built-in validation (final defense layer)
  # Read tool will fail if path is outside allowed boundaries
  # This delegates final security checks to Claude Code's built-in validation
}

# Usage in main flow
if [[ ! "$TARGET" =~ ^MR/PR: ]]; then
  validate_path_security "$TARGET" || exit $EXIT_SECURITY_ERROR
fi
```

### Perspective Validation

```bash
ALLOWED_PERSPECTIVES="necessity security performance maintainability accessibility i18n testing documentation consistency scalability simplicity"

validate_perspectives() {
  local input_perspectives="$1"
  IFS=',' read -r -a perspective_array <<< "$input_perspectives"

  for perspective in "${perspective_array[@]}"; do
    if [[ ! " $ALLOWED_PERSPECTIVES " =~ " $perspective " ]]; then
      echo "ERROR: Invalid perspective '$perspective'"
      echo "File: iterative-review.md:283-291 - Perspective Validation"
      echo ""
      echo "Allowed perspectives: necessity, security, performance, maintainability, accessibility, i18n, testing, documentation, consistency, scalability, simplicity"
      echo "See iterative-review.md:86-95 for complete list"
      exit $EXIT_USER_ERROR
    fi
  done
}
```

### MR/PR Number Validation

```bash
validate_mr_number() {
  local num="$1"
  local count=0

  # Load current daily count from file
  if [[ -f "$MR_PR_COUNT_FILE" ]]; then
    count=$(cat "$MR_PR_COUNT_FILE" 2>/dev/null || echo 0)
  fi

  # Check daily rate limit
  if [[ $count -ge $MAX_MR_PR_REQUESTS ]]; then
    echo "ERROR: Daily MR/PR request limit exceeded (max: $MAX_MR_PR_REQUESTS per day)"
    echo "File: iterative-review.md:310-313 - MR/PR Rate Limiting"
    echo ""
    echo "Limit resets at midnight (00:00)"
    echo "Counter file: $MR_PR_COUNT_FILE"
    exit $EXIT_USER_ERROR
  fi

  # Validate number range: 1-999999
  if [[ ! "$num" =~ ^[0-9]+$ ]] || [[ "$num" -lt 1 ]] || [[ "$num" -gt 999999 ]]; then
    echo "ERROR: MR/PR number must be between 1 and 999999"
    echo "File: iterative-review.md:319-322 - MR/PR Number Validation"
    echo ""
    echo "Provided: $num"
    echo "Valid range: 1-999999"
    exit $EXIT_USER_ERROR
  fi

  # Increment counter (atomic operation)
  echo $((count + 1)) > "$MR_PR_COUNT_FILE"
}
```

## Error Handling

### Error Handling Pattern

When errors occur, follow this pattern:

```typescript
// 1. Detect error condition
if (!isValid) {
  // 2. Report error to user (safe message)
  reportError("Error message")

  // 3. Update TodoWrite status
  TodoWrite([...todos.map(t =>
    t.status === "in_progress" ? {...t, status: "failed"} : t
  )])

  // 4. Stop execution (do not continue)
  return
}
```

### Error Categories and Messages

**Argument errors**:
- Target missing: use AskUserQuestion to select file/directory (interactive mode)
- Invalid rounds: `"iterative-review.md:81 - rounds must be positive integer, got: [value]"`
- Invalid perspective: `"iterative-review.md:51-66 - invalid perspective '[value]'. Allowed: necessity, security, performance, maintainability, accessibility, i18n, testing, documentation, consistency, scalability, simplicity"`
- Path traversal detected: `"iterative-review.md:164-167 - invalid path: security validation failed"`

**Execution errors**:
- File read fails: `"review operation failed - verify target path"`
- Git operation fails: `"review operation failed - check MR/PR number"`
- Tool error: `"operation failed: [tool name] unavailable"`
- Unrecoverable error: `"operation failed - verify input and retry"`

**Common errors and solutions**:
- "Review operation failed": Verify target path is relative to project root or home directory
- "Invalid rounds": Use positive integer (1-10 recommended)
- "Invalid perspective": See iterative-review.md:51-66 for allowed values
- "Path traversal detected": Remove `../` patterns from path
- "Daily MR/PR limit exceeded": Max 10 requests per day, resets at midnight

**Security guidelines**:
- Never expose absolute file paths (use relative names only)
- Never expose stack traces or internal details
- Never confirm file existence/non-existence in error messages
- Report only user-actionable information

### Exit Code System

Exit codes are defined in Configuration Constants (line 218-222):

```bash
readonly EXIT_SUCCESS=0           # Review completed successfully
readonly EXIT_USER_ERROR=1        # Invalid input, argument errors
readonly EXIT_SECURITY_ERROR=2    # Path traversal, security violations
readonly EXIT_SYSTEM_ERROR=3      # Tool failures, system errors
```

LLM should handle execution outcomes as follows:

- **EXIT_SUCCESS (0)**: Continue to next todo, mark current as completed
- **EXIT_USER_ERROR (1)**: Invalid input - report error, mark todo as failed, stop execution
- **EXIT_SECURITY_ERROR (2)**: Path traversal - report error, mark todo as failed, stop execution
- **EXIT_SYSTEM_ERROR (3)**: Tool failure - report error, mark todo as failed, suggest retry

Never silently fail. Always update TodoWrite status before stopping.

#### Exit Code Implementation Pattern

```bash
# Main execution function
perform_review() {
  # Argument parsing and validation
  # ... (validation logic) ...

  # If validation fails, return appropriate exit code
  if [[ $? -ne 0 ]]; then
    return $EXIT_USER_ERROR
  fi

  # Perform review logic
  # Use Read/Grep/Glob tools for file operations

  # Check tool execution status
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Review operation failed - verify input and retry"
    echo "File: iterative-review.md:415-418 - Tool Execution"
    return $EXIT_SYSTEM_ERROR
  fi

  return $EXIT_SUCCESS
}

# Execute and capture exit code
perform_review
REVIEW_EXIT_CODE=$?

# Report to user based on exit code
case $REVIEW_EXIT_CODE in
  $EXIT_SUCCESS)
    echo "Review completed successfully"
    # Mark TodoWrite as completed
    ;;
  $EXIT_USER_ERROR)
    echo "ERROR: Invalid input provided"
    # Mark TodoWrite as failed
    ;;
  $EXIT_SECURITY_ERROR)
    echo "ERROR: Security validation failed"
    # Mark TodoWrite as failed
    ;;
  $EXIT_SYSTEM_ERROR)
    echo "ERROR: Operation failed - verify input and retry"
    # Mark TodoWrite as failed
    ;;
esac

exit $REVIEW_EXIT_CODE
```

## Basic Approach

As an experienced senior engineer, you will iteratively review targets from multiple expert perspectives.

Review attitude:
- Zero-based thinking: Ask "is this even needed?" first rather than "how to improve"
- Don't hesitate to delete: Eliminate status quo bias and actively recommend deletion of unnecessary features
- Bold proposals: Include "fundamental reconsideration" as an option, not just "safe improvements"
- Multi-angle analysis: Comprehensive evaluation from different expert perspectives
- Prioritization: Importance classification of findings (deletion > simplification > improvement)
- Integrated report: Final report consolidating all perspective results

## Execution Flow

Use TodoWrite to track progress:
1. Parse and validate arguments from $ARGUMENTS
2. Identify target (file/directory/MR/PR)
3. Determine perspectives (apply defaults or parse custom list)
4. Apply --skip-necessity if specified (remove necessity from perspectives, set rounds=3)
5. Create TodoWrite with all review rounds
6. Execute each perspective review sequentially
7. Update todo status after each round completes
8. Generate integrated report

Argument parsing logic:

Parse $ARGUMENTS string to extract:
- Target path (first non-flag argument)
- --rounds=N flag (default: 4)
- --perspectives=list flag (default: necessity,security,performance,maintainability)
- --skip-necessity flag (boolean, default: false)

If --skip-necessity is true:
  - Remove "necessity" from perspectives list
  - Set rounds to 3 (unless explicitly overridden)

## Large File Handling Strategy

For all perspectives, when reviewing files >2000 lines:

**Read tool limitation**: 2000-line limit per call (defined in `READ_CHUNK_SIZE`)

**Chunked reading pattern**:
```bash
# First chunk
Read tool with:
  - file_path: "large-file.ts"
  - offset: 0
  - limit: 2000

# Subsequent chunks
Read tool with:
  - file_path: "large-file.ts"
  - offset: 2000
  - limit: 2000

# Continue until EOF (offset + limit > file size)
```

**Apply to**: Security Perspective, Performance Perspective, Maintainability Perspective

## Review Perspective Definitions

### Round 0: Necessity Review

Purpose: Eliminate status quo bias and question the necessity of the target with zero-based thinking

Important principles:
- Ask "is this even needed?" not "how to improve it"
- Actively consider deletion/consolidation rather than protecting existing implementation
- Strictly evaluate the cost of complexity
- Always present simpler alternatives

Required check items:

Fundamental necessity evaluation:
- Real use cases: Do concrete scenarios exist where this is actually used?
  - Can you list 3+ scenarios where it's "actually used" not just "seems useful"
  - Predicted weekly/monthly usage frequency?
- Alternative means exist: Can existing features/commands/tools substitute?
- Cost of complexity: Is the value worth the added complexity?

Deletion/consolidation potential:
- Deletion impact analysis: What is the actual harm if this feature is deleted?
- Consolidation possibility: Can it be consolidated into existing features?
- Simplification potential: Can the same value be provided with simpler implementation?

Value proposition clarification:
- Clear value: Can the raison d'être of this feature be explained in one sentence?
- Priority evaluation: Should this be prioritized over other improvements/new features?

Evaluation criteria:

| Item | Recommend Deletion | Needs Review | Justified Retention |
|------|-------------------|--------------|---------------------|
| Real use cases | 0-1 cases | 2-3 cases | 4+ cases |
| Alternative means | Easily achievable | Some effort required | Difficult |
| Usage frequency | Less than monthly | Weekly | 3+ times/week |
| Maintenance cost | High | Medium | Low |

Review result expression:
- Recommend deletion: "This feature is unnecessary. Reason: [specific reason]. Alternative: [how to achieve with existing features]"
- Recommend simplification: "Current implementation is excessive. Should narrow to [X feature] only"
- Justified retention: "Clear value exists. However, [Y] improvement needed"

### Round 1: Security Perspective

Key check items:
- **Input validation**: Proper validation of all user input
- **Output escaping**: XSS/injection countermeasure implementation status
- **Authentication/Authorization**: Appropriateness of permission checks, session management
- **Sensitive information**: Hardcoded secrets, API keys, etc.
- Encrypted communication: HTTPS/TLS usage, sensitive data protection
- Dependencies: Use of libraries with known vulnerabilities
- OWASP compliance: Response status to each OWASP Top 10 item

Analysis methods:
Use Claude Code tools (NOT Bash commands) for safe, efficient analysis:

```markdown
# Search for sensitive information
Grep tool with pattern: "password|api_key|secret|token"
  - flags: {"-i": true} (case-insensitive)
  - type: "typescript"

# Check for dangerous function usage
Grep tool with pattern: "dangerouslySetInnerHTML|eval\\(|Function\\(|execSync"
  - type: "typescript"

NEVER use Bash rg/grep/find directly - security risk.
```

**Large files (>2000 lines)**: See "Large File Handling Strategy" (line 409)

### Round 2: Performance Perspective

Key check items:
- **Computational complexity**: Appropriateness of algorithm time/space complexity
- **N+1 problem**: Efficiency of database queries, API calls
- **Memory leaks**: Proper cleanup of event listeners, timers
- **Bundle size**: Unnecessary dependencies, Tree Shaking optimization
- Rendering: React rendering optimization (useMemo, useCallback)
- Async processing: Proper use of Promise, async/await
- Caching: Implementation of appropriate cache strategies

Analysis methods:
Use Claude Code tools for performance analysis:

```markdown
# Detect API calls in loops
Grep tool with pattern: "for.*await|while.*await|\\.map\\(async"
  - type: "typescript"
  - output_mode: "content" (to see context)

# Identify large files
Glob tool with pattern: "**/*.{ts,tsx}"
  - Then use Read tool to check file sizes
  - Or use Bash: wc -l on specific files only (not find)
```

**Large files (>2000 lines)**: See "Large File Handling Strategy" (line 409)

### Round 3: Maintainability Perspective

Key check items:
- **Single responsibility principle**: Clarity of each function/component responsibility
- **DRY principle**: Code duplication, appropriateness of abstraction
- **Naming conventions**: Consistency, self-documenting naming
- **Type safety**: TypeScript strict mode, type inference utilization
- Testability: Unit test ease, dependency injection
- Documentation: Appropriateness of comments, JSDoc, README
- Error handling: Exception handling, error message appropriateness
- Scalability: Response to future expansion

Analysis methods:
Use Claude Code tools for maintainability analysis:

```markdown
# Check for missing type annotations
Grep tool with pattern: ": any|as any"
  - type: "typescript"
  - output_mode: "content"

# Detect code duplication
Grep tool with pattern: "function.*\\{"
  - type: "typescript"
  - output_mode: "count" (shows frequency by file)
  - Manual analysis required for actual duplication detection
```

**Large files (>2000 lines)**: See "Large File Handling Strategy" (line 409)

## Review Mode Selection

### Default Mode: Zero-Based Thinking Review

Characteristics:
- Includes Round 0 "Necessity Review" (4 rounds)
- Asks "is this even needed?" first
- Actively considers deletion/simplification

Use cases:
- New feature proposal/design stage
- Existing feature inventory
- Organization of configuration files like CLAUDE.md
- Preventing feature bloat

### Constructive Review Mode: --skip-necessity

Characteristics:
- Skip Round 0 (3 rounds)
- Only propose improvements
- Don't consider deletion/simplification

Use cases:
- Improving features with proven value
- During new feature implementation (not yet complete)
- During refactoring (features remain)
- Security/performance improvement purposes

Usage examples:
```bash
# Quality improvement of existing critical features
/iterative-review src/auth/login.ts --skip-necessity

# Review of features under new implementation
/iterative-review src/features/new-feature.ts --skip-necessity
```

## Perspective Customization

Perspectives other than defaults can be specified. See "Allowed Perspectives" section for the complete list.

**Default**: necessity, security, performance, maintainability
**All options**: See line 51-66 for complete list and descriptions

### Custom Perspective Usage Examples

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

After all rounds complete, generate an integrated report. Format varies based on --skip-necessity flag:

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

Reason: [Specific justification for decision]
Alternative: [Specific alternative means for deletion/simplification case]

## Round 1: Security Perspective
[Findings and recommended actions]

## Round 2: Performance Perspective
[Findings and recommended actions]

## Round 3: Maintainability Perspective
[Findings and recommended actions]

## Overall Evaluation

### Round 0 Decision Result

Recommend Deletion / Recommend Simplification / Justified Retention

Note: If Round 0 recommends deletion, detailed improvements from subsequent rounds are treated as reference information
```

### Constructive Mode (--skip-necessity)

```markdown
# Iterative Review Results

## Basic Information
- Target: [filename/directory/MR number]
- Type: [TypeScript/Python/Document, etc.]
- Review Date/Time: [YYYY-MM-DD HH:MM]
- Number of Perspectives: 3 (security, performance, maintainability)
- Mode: Constructive Review (necessity evaluation skipped)

## Round 1: Security Perspective
[Findings and recommended actions]

## Round 2: Performance Perspective
[Findings and recommended actions]

## Round 3: Maintainability Perspective
[Findings and recommended actions]

## Overall Evaluation

Note: Necessity evaluation was skipped. This review focuses on improving existing implementation

### Findings Summary
- Critical: [X items]
- Important: [Y items]
- Minor: [Z items]

### Priority Action Plan

High Priority (Critical Issues):
[Response to Critical Issues with file:line references]

Medium Priority (Important Issues):
[Response to Important Issues]

Low Priority (Minor Improvements):
[Optional improvements]

### Overall Observations

Overall Assessment:
[Comprehensive improvement direction]
```

### Common Elements (Both Modes)

Both report formats include:
- Findings Summary with severity classification (Critical/Important/Minor)
- Priority Action Plan with specific file:line references
- Overall Observations with actionable guidance

For Default Mode, Priority Action Plan considers Round 0 decision:
- If deletion recommended: No need to implement subsequent improvement proposals
- If simplification recommended: Prioritize major simplification; defer minor improvements
- If retention justified: Implement all improvements in priority order


## Examples

Input: /iterative-review src/components/Button.tsx
Action: Execute 4-round review (necessity, security, performance, maintainability) on Button.tsx

Input: /iterative-review src/ --skip-necessity
Action: Execute 3-round review (security, performance, maintainability) on src directory

Input: /iterative-review feature.ts --perspectives=necessity --rounds=1
Action: Execute necessity review only on feature.ts

Input: /iterative-review
Action: Interactive mode, use AskUserQuestion to select target