---
allowed-tools: Read, Grep, AskUserQuestion, Task
argument-hint: "[optimization-target]"
description: "Performance optimization through measurement, analysis, and validation"
model: sonnet
---

# Performance Optimization Command

Optimization target: $ARGUMENTS

## Argument Validation and Sanitization

Parse and validate $ARGUMENTS with security-first approach:

```bash
validate_target() {
  local target="$1"

  # Whitelist validation: allow only safe characters
  if [[ ! "$target" =~ ^[a-zA-Z0-9/_. -]+$ ]]; then
    echo "ERROR [optimize.md:21]: Invalid characters in target"
    echo "  At: validate_target() function"
    echo "  Input: $target"
    echo "  Allowed: alphanumeric, hyphen, underscore, slash, dot, space"
    exit 2
  fi

  # Path normalization and traversal prevention
  local normalized=$(realpath -m "$target" 2>/dev/null)
  local project_root=$(pwd)

  if [[ -z "$normalized" ]] || [[ "$normalized" =~ \.\. ]] || [[ ! "$normalized" =~ ^"$project_root" ]]; then
    echo "ERROR [optimize.md:31]: Path must be within project directory"
    echo "  At: validate_target() function"
    echo "  Input: $target"
    echo "  Project root: $project_root"
    exit 2
  fi

  # Existence verification
  if [[ ! -e "$normalized" ]]; then
    echo "ERROR [optimize.md:40]: Target does not exist"
    echo "  At: validate_target() function"
    echo "  Input: $target"
    exit 2
  fi

  echo "$normalized"
}

# Validate before any operation
TARGET=$(validate_target "$ARGUMENTS")
```

## Execution Flow

1. Parse and validate optimization target with strict input sanitization
2. Determine optimization scope (bundle/runtime/memory/network)
3. Apply scope threshold to decide direct implementation vs agent delegation
4. Launch performance-engineer agent or implement directly
5. Handle errors with classified recovery strategies

## Optimization Scope Threshold

Decision criteria for implementation approach:

**Direct implementation** (without agent):
- Single file optimization (< 50 lines changed)
- Single dependency removal from package.json
- Simple memoization addition (1-2 React components)
- Quick wins with minimal complexity

**Agent delegation** (performance-engineer):
- Multi-file optimization (≥ 3 files)
- Bundle analysis and code splitting
- Comprehensive React performance audit
- Memory leak investigation
- Complex performance profiling

## Agent Integration

Task tool with subagent_type=performance-engineer:

```markdown
description: "Optimize [target area]"
model: sonnet

prompt: |
  Working directory: [absolute project root path]

  Performance optimization task:
  - Target: [validated target path]
  - Scope: [bundle/runtime/memory/network]
  - Current baseline: Measure before optimization
  - Success criteria: [specific metrics, e.g., bundle size < 250KB, build time < 30s]

  Expected deliverables:
  1. Baseline measurement results
  2. Bottleneck analysis and optimization strategy
  3. Implementation of optimizations
  4. Post-optimization validation
  5. Performance improvement report

  If optimization fails or breaks functionality:
  - Report: "ERROR: [specific reason]"
  - Include: rollback recommendation
```

### Agent Error Handling Pattern

Execute agent with error detection and recovery:

```bash
# Launch agent and capture output
AGENT_OUTPUT=$(mktemp)
trap "rm -f '$AGENT_OUTPUT'" EXIT

if Task tool subagent_type=performance-engineer \
     description="Optimize $TARGET" \
     prompt="..." > "$AGENT_OUTPUT" 2>&1; then
  # Agent succeeded
  echo "✅ Optimization completed successfully"
else
  AGENT_EXIT_CODE=$?

  # Check for agent-reported errors
  if grep -q "^ERROR:" "$AGENT_OUTPUT"; then
    echo "ERROR [optimize.md:108]: Agent reported failure"
    echo "  Agent exit code: $AGENT_EXIT_CODE"
    echo "  Agent message: $(grep "^ERROR:" "$AGENT_OUTPUT" | head -1)"

    # Check for specific error patterns
    if grep -q "rollback" "$AGENT_OUTPUT"; then
      echo ""
      echo "💡 Rollback recommended by agent"
      echo "   Run: git restore ."
    fi

    exit 3
  else
    # Agent failed without error message
    echo "ERROR [optimize.md:108]: Agent failed unexpectedly"
    echo "  Exit code: $AGENT_EXIT_CODE"
    echo "  Check agent output for details"
    exit 3
  fi
fi

# Verify agent deliverables
if [[ ! -s "$AGENT_OUTPUT" ]]; then
  echo "ERROR [optimize.md:108]: Agent produced no output"
  exit 3
fi
```

Exit codes:
- 0: Success - Optimization completed
- 2: Validation failure (invalid input, path traversal, file not found)
- 3: Agent failure (optimization failed, deliverables missing)

## Error Classification and Handling

Three-level error handling with appropriate recovery:

**Critical** (rollback required):
- Functionality breaks after optimization
- Build failure during or after optimization
- Test suite failures introduced by changes

Recovery:
1. Automatic rollback to last known good state
2. AskUserQuestion for recovery approach selection
3. Options: selective rollback, gradual reapply, alternative strategy, full rollback

**Warning** (investigation required):
- Performance improvement insufficient (< 5% gain)
- Metrics regression in non-target areas

Recovery:
1. Report performance gap and current metrics
2. Re-run profiling with detailed analysis
3. AskUserQuestion for next steps: retry with different strategy, accept results, investigate further

**Info** (non-blocking):
- General errors without functionality impact
- Tool availability issues (fallback available)

Recovery:
1. Log error details for reference
2. Continue with alternative strategies
3. Report informational message only

## Security Considerations

Performance optimization security requirements:

- Input validation: Whitelist-based path validation (implemented above)
- Measurement data: Store in .performance/ directory (add to .gitignore)
- Sensitive information: Redact URLs and internal paths in logs
- Tool execution: Only through performance-engineer agent (no direct Bash execution)
- Dependency scanning: Run npm audit before optimization if available
- File permissions: Set restrictive permissions on measurement logs (chmod 600)

## Examples

```bash
# Interactive mode with scope selection
/optimize

# Direct target specification
/optimize "src/components/Button.tsx"

# Bundle size optimization
/optimize "bundle size reduction"

# React rendering performance
/optimize "React rendering optimization"
```
