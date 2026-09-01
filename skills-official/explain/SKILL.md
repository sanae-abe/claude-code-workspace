---
name: explain
description: Explain project features, components, and architectural concepts
argument-hint: "[feature-name|component-name|concept] [--detailed|--usage|--examples]"
---

# Explain Project Elements

Arguments: $ARGUMENTS

## Argument Validation

Validate before any operations:

- If $ARGUMENTS is empty: use AskUserQuestion to prompt for a target name
- If target exceeds 100 characters: report "Target name too long (max 100 chars)" and stop
- If target contains `..`: report "Path traversal detected in target name" and stop
- If target contains `;`, `` ` ``, `$`, `(`, `)`, `&`, `|`, `*`, `?`, `<`, `>`: report "Invalid characters in target name" and stop
- If target does not match `[a-zA-Z0-9 _-]+`: report "Target name contains invalid characters. Allowed: alphanumeric, spaces, hyphens, underscores" and stop
- If flag is not one of `--detailed`, `--usage`, `--examples`: report "Unknown flag. Allowed flags: --detailed, --usage, --examples" and stop

## Execution Flow

1. Parse arguments from $ARGUMENTS
   - Extract target (feature/component/concept name)
   - Extract option flags (--detailed, --usage, --examples)

2. Locate target in codebase (optimized search strategy)
   - **Fast path**: Use Grep for exact match in standard locations:
     - Components: src/components/, src/ui/, components/
     - Features: src/features/, src/pages/, features/
     - Utilities: src/utils/, src/lib/, lib/
     - Documentation: docs/, README.md
   - **Comprehensive search**: If not found, use Agent (subagent_type=Explore) with directory scope:
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

- **Grep**: Fast exact-match search when target follows naming conventions
  - Use for: Components with standard names (ComponentName.tsx)
  - Directories: Known locations (src/components/, src/features/)

- **Agent (subagent_type=Explore)**: Comprehensive search when location unknown or semantic understanding needed
  - Use for: Complex searches, architectural concepts, ambiguous names
  - Scope: Specify directory scope to limit search time

- **Read**: Detailed file analysis when exact path already known
  - Use for: Follow-up analysis after Grep/Explore finds target

## Error Handling

If target not found:
- Report "Component not found" (relative path only, never absolute)
- Suggest similar names from codebase
- Provide search alternatives

If ambiguous match (multiple files):
- List all matching relative paths
- Ask user to specify exact path or context

If validation fails:
- Report specific validation error with expected format

## Examples

/explain "AuthProvider" → Explain authentication provider component
/explain "State Management" --detailed → Detailed explanation of state management architecture
/explain → AskUserQuestion to select common project elements
