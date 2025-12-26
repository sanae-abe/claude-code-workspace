# Slash Command Design Guidelines

Guidelines for creating Claude Code slash commands optimized for LLM parsing and execution.

## Core Principles

- Write in English
- Minimize decorative elements
- Use direct, imperative instructions
- Avoid project-specific information
- Avoid roadmaps and future plans
- Avoid internal cross-references

## YAML Frontmatter Format

Required frontmatter structure:

```yaml
---
allowed-tools: Bash, Read, Write, Edit
argument-hint: "<required> [--optional-flag]"
description: Single-line description shown in command list
model: sonnet
---
```

### Field Specifications

**allowed-tools** (required)
- Grant minimum necessary tools only
- Review and justify each tool before finalizing
- Avoid "full access" unless genuinely required

Common combinations:
- Read-only: `Bash, Read, Grep, Glob`
- Code editing: `Read, Edit, Bash`
- Interactive: `AskUserQuestion, TodoWrite`
- Complex workflows: `Bash, Read, Edit, Grep, Glob, TodoWrite, AskUserQuestion`
- With subagents: add `Task` to any combination above

**argument-hint** (optional)
- Show expected argument syntax
- Use `<required>` and `[--optional]`
- Example: `"<file-path> [--detailed] [--output-format]"`

**description** (required)
- Single line, under 100 characters
- Describes what the command does, not how

**model** (optional)
- `haiku`: < 3 steps, no analysis needed
- `sonnet`: default for most commands
- `opus`: deep reasoning required
- Omit to use user's default model

## Document Structure

Minimal template:

```markdown
---
allowed-tools: [tool list]
argument-hint: "[syntax]"
description: [one-line description]
---

# Command Name

Arguments: $ARGUMENTS

## Execution Flow

1. Parse arguments from $ARGUMENTS
2. Execute main logic
3. Handle errors

## Tool Usage

TodoWrite: Use when 3+ steps required
AskUserQuestion: Use when arguments unclear

## Error Handling

If [condition]: [action]
If unrecoverable error: report error type and user-actionable guidance

Avoid: stack traces, file paths, internal details in user-facing errors
```

Avoid:
- Table of contents
- Version numbers or dates
- Emoji headers
- Related commands sections

## Security Guidelines

### Security Risks in Slash Commands

**HIGH**: Command injection via $ARGUMENTS
- Mitigation: Sanitize paths (reject ../), escape before Bash execution

**MEDIUM**: Path traversal, sensitive file exposure
- Mitigation: Validate against project root, grant minimum necessary tools

**LOW**: Information disclosure in error messages
- Mitigation: Report error types only, never stack traces/absolute paths

### Input Validation

Always validate $ARGUMENTS before use:

```markdown
## Argument Validation

Parse $ARGUMENTS:
- Sanitize file paths: reject ../, validate against project root
- Validate flags against allowed list
- Escape arguments before passing to Bash
- Reject unexpected patterns

Example validation:
If path contains ..: report error and exit
If flag not in [allowed-flags]: report error and exit
```

### Tool Permission Security

Apply least privilege principle:
- Grant only tools actually used in execution flow
- Avoid `Write` if command only reads
- Avoid `Bash` if other tools suffice
- Review tool list before finalizing

### Error Message Security

```markdown
## Error Handling

If validation fails: report error type and required format
If file not found: report filename only, not full path
If command fails: report user-actionable guidance

Never expose:
- Stack traces
- Absolute file paths
- Internal system details
- Sensitive environment information
```

## Argument Processing

Access user input via `$ARGUMENTS` variable.

Simple positional:
```markdown
Extract target from $ARGUMENTS (first token)
If empty: use AskUserQuestion to select target
```

Multiple flags:
```markdown
Parse flags from $ARGUMENTS:
- --detailed: enable verbose output
- --output=format: json|yaml|text (default: text)
- --skip-tests: skip test execution

If invalid flag: report error with available flags
```

Key-value pairs:
```markdown
Parse from $ARGUMENTS:
- Extract key=value pairs
- Validate values against constraints
- Apply defaults for omitted keys
```

## Tool Usage Patterns

**TodoWrite**: 3+ steps, long operations, progress tracking
**AskUserQuestion**: Missing/ambiguous arguments, multiple approaches, user decisions
**Task (subagents)**: Complex exploration (Explore), specialized analysis (code-reviewer, security-auditor, performance-engineer)

**Workflow patterns:**

Git operations:
1. Validate repo: `git rev-parse --git-dir`
2. Check state: `git status --porcelain`
3. Execute command
4. Verify: `git log -1` or `git status`
5. If not repo or uncommitted changes: use AskUserQuestion

Code analysis:
1. Parse target from $ARGUMENTS
2. Locate files: Grep (patterns) or Glob (file types)
3. Read and analyze
4. Generate report
5. If scope unclear: Task tool with Explore subagent

Interactive selection:
1. Check $ARGUMENTS
2. If missing: AskUserQuestion with 2-4 options
3. Validate selection
4. TodoWrite for multi-step execution
5. Execute based on choice

## Error Handling

Always specify error handling behavior:

```markdown
## Error Handling

Argument validation:
If required argument missing: use AskUserQuestion or report required format
If invalid format: report expected format with example

Execution errors:
If tool operation fails: report what failed and how to fix
If recoverable: suggest correction and retry
If unrecoverable: report error type and exit

Security:
Never expose absolute paths, stack traces, or internal details
Report only user-actionable information
```

## Examples

Provide 2-3 concrete examples covering normal, interactive, and error cases:

```markdown
## Examples

/command target-name --flag → Execute with flag on target-name
/command → AskUserQuestion for target selection
/command invalid → Report error: "Invalid target format. Use: <name> or <path>"
```

## Command Naming

Use kebab-case, verb-based names:
- Good: `/analyze`, `/review-mr`, `/clean-jobs`
- Avoid: `/Analysis`, `/MRReview`, `/cleanJobs`

Prefixes:
- No prefix: general-purpose commands
- Avoid tech-specific prefixes unless necessary

## Writing Style

Direct and imperative:
```markdown
Good: "Parse arguments from $ARGUMENTS"
Bad: "You should parse the arguments that the user provided"

Good: "If validation fails: report error and exit"
Bad: "In case the validation doesn't succeed, consider reporting an error"
```

Structured and scannable:
```markdown
Good:
1. Parse arguments
2. Validate input
3. Execute operation

Bad:
First parse the arguments, then validate the input, and finally execute the operation.
```

## Quality Checklist

Before finalizing:

- YAML frontmatter valid with minimum necessary tools
- $ARGUMENTS validation and error handling specified
- Security considerations applied (input sanitization, path validation)
- Examples provided with concrete input/output
- Direct, imperative English instructions
- No emojis, TOC, version numbers, or project-specific details

