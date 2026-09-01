---
name: optimize
description: "Performance optimization: analyze and improve bundle size, runtime speed, memory usage, or network efficiency. Use when user says 'optimize', 'slow', 'performance issue', 'bundle size', 'memory leak', or 'speed up'."
when_to_use: "User says 'optimize', 'too slow', 'performance issue', 'bundle size too large', 'memory leak', 'speed up', or asks to improve performance of a specific file or area."
---

# Performance Optimization

$ARGUMENTS

## Argument Handling

Parse $ARGUMENTS to determine the optimization target:

**If $ARGUMENTS is empty:**
Use AskUserQuestion to select scope. Options:
- Bundle size (code splitting, tree-shaking, dependency reduction)
- Runtime performance (rendering speed, CPU, latency)
- Memory usage (leak detection, allocation optimization)
- Network efficiency (request batching, caching, compression)

**If $ARGUMENTS looks like a file or directory path** (contains `/`, `.tsx`, `.ts`, `.js`, `.vue`, `.py`, etc.):
1. Check the target exists within the current working directory
2. If target resolves outside the working directory: report "ERROR: Target must be within the project directory" and stop
3. If target does not exist: report "ERROR: Target not found" and stop
4. Proceed with path-based optimization

**If $ARGUMENTS is a natural language description** (e.g. "bundle size reduction", "React rendering", "memory leak"):
- Treat as scope description; skip path validation entirely
- Map to optimization scope: bundle / runtime / memory / network
- Proceed directly to scope-based analysis

## Optimization Scope Threshold

Decide between direct implementation and agent delegation:

**Direct implementation** (implement immediately, no agent):
- Single file change (< 50 lines)
- Remove a single unused dependency from package.json
- Add memoization to 1-2 React components
- Other straightforward quick wins with minimal risk

**Agent delegation** (launch performance-engineer agent):
- Changes spanning 3 or more files
- Bundle analysis and code splitting strategy
- Comprehensive React or Vue performance audit
- Memory leak investigation
- Complex profiling requiring multiple tools

## Agent Integration

When delegating, launch via the Agent tool with:

- subagent_type: "performance-engineer"
- model: "sonnet"
- description: "Optimize [target area]"
- prompt must include:
  - Working directory: [absolute path of project root]
  - Target: [validated file path or scope description]
  - Scope: bundle / runtime / memory / network
  - Baseline measurement: measure current metrics before making any changes
  - Success criteria: [specific metrics, e.g., bundle < 250KB, build time < 30s]
  - Expected deliverables:
    1. Baseline measurement results
    2. Bottleneck analysis and optimization strategy
    3. Implementation of optimizations
    4. Post-optimization validation
    5. Summary with before/after metrics
  - On failure: report "ERROR: [specific reason]" with rollback recommendation

### After Agent Completes

1. If output contains "ERROR:" — stop and report to user; ask for next action
2. If output is empty — report "ERROR: Agent produced no output"
3. Otherwise — summarize improvements in 1-2 sentences with before/after metrics

## Error Handling

**Critical** (rollback required):
- Functionality breaks after optimization
- Build fails after optimization
- Test suite failures introduced by changes

Recovery: suggest `git restore .`, then use AskUserQuestion with options: selective rollback / gradual reapply / alternative strategy / full rollback

**Warning** (investigation required):
- Improvement under 5%
- Regression in non-target metrics

Recovery: report current metrics, re-run profiling, use AskUserQuestion for next steps

**Info** (non-blocking):
- Minor errors with an available fallback
- Missing optional tools (e.g., no `npm audit`)

Recovery: log the issue, continue with an alternative approach

## Security Considerations

- Path inputs: validate only when $ARGUMENTS looks like a file path; never apply path validation to natural language inputs
- Measurement data: store in `.performance/` directory; add to `.gitignore`
- Error messages: never include raw user input or absolute internal paths in error output
- Dependency scanning: run `npm audit` before optimization when available

## Examples

```
/optimize                                    → AskUserQuestion for scope selection
/optimize src/components/Button.tsx          → single-file optimization
/optimize bundle size reduction              → agent delegation for bundle analysis
/optimize React rendering optimization       → agent delegation for React audit
/optimize memory leak                        → agent delegation for memory investigation
```
