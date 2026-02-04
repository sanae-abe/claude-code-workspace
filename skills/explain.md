---
allowed-tools: Bash, Read, Grep, Glob, Task
argument-hint: "[feature-name|component-name|concept] [--detailed|--usage|--examples]"
description: Explain project features, components, and architectural concepts
model: sonnet
---

# Explain Project Elements

Arguments: $ARGUMENTS

## Argument Validation

Execute validation before any operations:

```bash
# Validate and sanitize target name
validate_target() {
  local target="$1"

  # Reject empty input
  if [[ -z "$target" ]]; then
    echo "ERROR: Target name required"
    echo "Usage: /explain ComponentName [--detailed|--usage|--examples]"
    exit 1
  fi

  # Length validation (1-100 chars)
  if [[ ${#target} -lt 1 || ${#target} -gt 100 ]]; then
    echo "ERROR: Target name must be 1-100 characters, got: ${#target}"
    exit 1
  fi

  # Reject path traversal
  if [[ "$target" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected in target name"
    exit 2
  fi

  # Reject command injection characters
  local injection_pattern='[;`$()&|*?[]{}<>!]'
  if [[ "$target" =~ $injection_pattern ]]; then
    echo "ERROR: Invalid characters in target name"
    echo "Allowed: alphanumeric, spaces, hyphens, underscores only"
    exit 2
  fi

  # Whitelist validation
  if [[ ! "$target" =~ ^[a-zA-Z0-9\ _-]+$ ]]; then
    echo "ERROR: Target name contains invalid characters"
    echo "Format: 'ComponentName' or 'Feature Description'"
    exit 1
  fi
}

# Parse and validate flags
parse_flags() {
  local args="$1"
  local allowed_flags="--detailed --usage --examples"

  for arg in $args; do
    if [[ "$arg" =~ ^-- ]]; then
      if [[ ! "$allowed_flags" =~ "$arg" ]]; then
        echo "ERROR: Unknown flag: $arg"
        echo "Allowed flags: $allowed_flags"
        exit 1
      fi
    fi
  done
}

# Safe argument parsing
IFS=' ' read -r -a args <<< "$ARGUMENTS"
TARGET="${args[0]}"
FLAGS="${args[@]:1}"

validate_target "$TARGET"
parse_flags "$FLAGS"
```

If validation fails: exit with error code 1 (user error) or 2 (security error)

## Execution Flow

1. Parse arguments from $ARGUMENTS
   - Extract target (feature/component/concept name)
   - Extract option flags (--detailed, --usage, --examples)
   - If no target: use AskUserQuestion to prompt for target name

2. Locate target in codebase (optimized search strategy)
   - **Fast path**: Use Grep for exact match in standard locations:
     - Components: src/components/, src/ui/, components/
     - Features: src/features/, src/pages/, features/
     - Utilities: src/utils/, src/lib/, lib/
     - Documentation: docs/, README.md
   - **Comprehensive search**: If not found, use Task (Explore) with directory scope:
     - Scope to relevant directories based on target type
     - Component names → component directories only
     - Feature names → feature/page directories only
     - Technical concepts → search documentation first, then code
   - Validate search results exist and are accessible

3. Analyze and explain
   - For UI components: structure, props, interactions, visual behavior
   - For technical concepts: implementation, dependencies, architecture decisions
   - For features: functionality, use cases, configuration

4. Generate structured explanation
   - Overview: role, purpose, main benefits
   - Implementation: technical details, configuration options
   - Usage: basic operation, common patterns
   - Considerations: limitations, known issues, best practices

## Output Format Template

Generate explanations in this structure:

```markdown
# [Target Name]

## Overview
- **Purpose**: [What it does in one sentence]
- **Type**: [Component/Feature/Concept/Utility]
- **Location**: [Relative path from project root]

## Implementation Details
[Technical explanation, dependencies, architecture]

## Usage
[How to use it, common patterns, code examples if applicable]

## Considerations
- **Limitations**: [Known limitations]
- **Best Practices**: [Recommended usage patterns]
- **Related**: [Links to related components/features]
```

## Tool Usage and Selection Criteria

**When to use each tool:**

- **Grep**: Fast exact-match search when target follows naming conventions
  - Use for: Components with standard names (ComponentName.tsx)
  - Directories: Known locations (src/components/, src/features/)
  - Speed: 0.5-1 second for most projects

- **Task (Explore)**: Comprehensive search when location unknown or semantic understanding needed
  - Use for: Complex searches, architectural concepts, ambiguous names
  - Scope: Specify directory scope to limit search time
  - Speed: 2-5 seconds depending on project size

- **Read**: Detailed file analysis when exact path already known
  - Use for: Follow-up analysis after Grep/Explore finds target
  - Speed: Instant (single file read)

## Error Handling

If target not found:
- Report "Component not found"
- Suggest similar names from codebase
- Provide search alternatives

If ambiguous match (multiple files):
- List all matching locations
- Ask user to specify exact path or context

If validation fails:
- Report specific validation error
- Show expected format with examples

Security:
Never expose absolute paths in error messages
Report only relative paths from project root

## Examples

/explain "AuthProvider" → Explain authentication provider component
/explain "State Management" --detailed → Detailed explanation of state management architecture
/explain → Interactive selection of common project elements
