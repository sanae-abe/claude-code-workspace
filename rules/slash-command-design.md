# Skill Design Guidelines

Guidelines for creating Claude Code skills (slash commands) optimized for LLM parsing and execution.

> **Note**: Custom commands (`.claude/commands/`) and skills (`.claude/skills/<name>/SKILL.md`) are equivalent. Skills are preferred: they support supporting files, richer frontmatter, and Claude auto-invocation.

## Core Principles

- Write in English
- Minimize decorative elements
- Use direct, imperative instructions
- Avoid project-specific information
- Avoid roadmaps and future plans
- Avoid internal cross-references

## YAML Frontmatter Format

All fields are optional. Only `description` is strongly recommended.

```yaml
---
name: my-skill
description: What this skill does and when to use it. Claude uses this for auto-invocation.
when_to_use: Additional trigger phrases or example requests that should activate this skill.
argument-hint: "<required> [--optional-flag]"
arguments: [target, format]
disable-model-invocation: true
user-invocable: false
allowed-tools: Bash(git add *) Bash(git commit *) Read
disallowed-tools: AskUserQuestion
model: sonnet
effort: high
context: fork
agent: Explore
paths: ["src/**/*.ts", "tests/**"]
---
```

### Field Specifications

**description** (strongly recommended)
- What the skill does and when Claude should invoke it automatically
- Put the key use case first (truncated at 1,536 characters in Claude's context)
- Claude matches this against natural language requests to auto-invoke

**when_to_use** (optional)
- Additional trigger phrases or example requests
- Appended to `description` for Claude's matching, counts toward 1,536-char cap

**disable-model-invocation** (optional, default: false)
- Set to `true` for any skill with side effects: deploy, commit, send messages
- Prevents Claude from deciding autonomously to run the skill
- Skill description is excluded from Claude's context entirely

**user-invocable** (optional, default: true)
- Set to `false` for background knowledge Claude should apply but users shouldn't invoke directly
- Hides the skill from the `/` menu

**allowed-tools** (optional)
- Grant minimum necessary tools without per-use approval
- Use tool constraints for precision: `Bash(git *)`, `Bash(npm run *)`, `Read`
- Review and justify each tool before finalizing

Common combinations:
- Read-only: `Read Grep Glob`
- Git operations: `Bash(git *) Read`
- Code editing: `Read Edit Bash`
- Interactive: `AskUserQuestion`
- Complex workflows: `Bash Read Edit Grep Glob AskUserQuestion`
- Subagents: add `Agent` to any combination above (named `Task` in older Claude Code versions)

**disallowed-tools** (optional)
- Explicitly block tools while this skill is active
- Useful for autonomous loops: `disallowed-tools: AskUserQuestion`

**model** (optional)
- Accepts the same values as `/model`, or `inherit` to keep the active model
- Guideline: `haiku` = simple lookup (< 3 steps), `sonnet` = most skills, `opus` = deep reasoning or complex multi-step tasks
- Override applies for current turn only; session model resumes after

**effort** (optional)
- Override reasoning depth: `low`, `medium`, `high`, `xhigh`, `max`

**context** (optional)
- `fork`: run in an isolated subagent; skill content becomes the task prompt
- Subagent has no access to your conversation history

**agent** (optional, requires `context: fork`)
- `Explore`: read-only codebase exploration (no CLAUDE.md loaded)
- `Plan`: planning without implementation
- `general-purpose`: default subagent
- Any custom agent name from `.claude/agents/`

**paths** (optional)
- Glob patterns; Claude auto-invokes only when working with matching files
- Example: `["src/**/*.ts"]` activates when editing TypeScript files

**argument-hint** (optional)
- Shown during autocomplete to indicate expected arguments
- Use `<required>` and `[--optional]`

**arguments** (optional)
- Named positional arguments: `arguments: [issue, branch]`
- Enables `$issue` and `$branch` substitution in skill content

## Dynamic Context Injection

Run shell commands before Claude sees the skill content. Output replaces the placeholder.

Inline (single command):
```markdown
## Current diff
!`git diff HEAD`

## PR context
!`gh pr view --comments`
```

Multi-line block (use ` ```! ` opener):
````markdown
## Environment
```!
node --version
git status --short
cat package.json | jq '.scripts'
```
````

Rules:
- `!` must appear at line start or immediately after whitespace
- Commands run once at skill load, not re-executed on later turns
- Output is plain text; no nested injection

## String Substitutions

| Variable | Description |
|---|---|
| `$ARGUMENTS` | All arguments as typed |
| `$ARGUMENTS[0]` / `$0` | First argument (0-based index) |
| `$ARGUMENTS[1]` / `$1` | Second argument |
| `$name` | Named argument from `arguments:` frontmatter |
| `${CLAUDE_SKILL_DIR}` | Absolute path to the skill directory |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_EFFORT}` | Active effort level |

Multi-word arguments require quoting: `/my-skill "hello world" second` → `$0 = "hello world"`, `$1 = "second"`

## Document Structure

Minimal template:

```markdown
---
description: [what it does and when to use it]
---

# Skill Name

$ARGUMENTS

## Execution Flow

1. Parse arguments from $ARGUMENTS
2. Execute main logic
3. Handle errors

## Error Handling

If [condition]: [action]
If unrecoverable error: report error type and user-actionable guidance
```

Full error handling pattern: see the Error Handling section below.

Avoid:
- Table of contents
- Version numbers or dates
- Emoji headers
- Related commands sections

## Invocation Control

| Scenario | Configuration |
|---|---|
| Deploy, commit, send messages (side effects) | `disable-model-invocation: true` |
| Background conventions Claude should apply | `user-invocable: false` |
| Autonomous loop (no user interaction) | `disallowed-tools: AskUserQuestion` |
| Research in isolated context | `context: fork` + `agent: Explore` |

## Subagent Pattern

Use `context: fork` instead of the `Task` tool when the entire skill is a delegated task:

```yaml
---
description: Research implementation patterns for a topic
context: fork
agent: Explore
---

Research $ARGUMENTS:

1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Return findings with specific file:line references
```

## Security Guidelines

### Security Risks

**HIGH**: Command injection via $ARGUMENTS
- Mitigation: Sanitize paths (reject `../`), escape before Bash execution

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

If path contains ..: report error and exit
If flag not in [allowed-flags]: report error and exit
```

### Tool Permission Security

Apply least privilege principle:
- Use tool constraints: `Bash(git *)` not `Bash`
- Avoid `Write` if command only reads
- Avoid `Bash` if other tools suffice
- Review tool list before finalizing

### Error Message Security

Never expose in user-facing errors:
- Stack traces
- Absolute file paths (report filename only)
- Internal system details
- Sensitive environment information

Full error handling pattern: see the Error Handling section.

## Argument Processing

Simple positional:
```markdown
Extract target from $ARGUMENTS (first token)
If empty: use AskUserQuestion to select target
```

Named arguments (with frontmatter `arguments: [target, format]`):
```markdown
Migrate $target to $format.
```

Multiple flags:
```markdown
Parse flags from $ARGUMENTS:
- --detailed: enable verbose output
- --output=format: json|yaml|text (default: text)
- --skip-tests: skip test execution

If invalid flag: report error with available flags
```

## Tool Usage Patterns

**AskUserQuestion**: Missing/ambiguous arguments, multiple approaches, user decisions
**Agent (subagents)**: Complex exploration, specialized analysis — or use `context: fork` in frontmatter instead

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
5. If scope unclear: use `context: fork` + `agent: Explore`

Interactive selection:
1. Check $ARGUMENTS
2. If missing: AskUserQuestion with 2-4 options
3. Validate selection
4. Execute based on choice

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
Report only user-actionable information (see Error Message Security)
```

## Examples

Provide 2-3 concrete examples covering normal, interactive, and error cases:

```markdown
## Examples

/command target-name --flag → Execute with flag on target-name
/command → AskUserQuestion for target selection
/command invalid → Report error: "Invalid target format. Use: <name> or <path>"
```

## Skill Naming

Use kebab-case, verb-based names:
- Good: `/analyze`, `/review-mr`, `/clean-jobs`
- Avoid: `/Analysis`, `/MRReview`, `/cleanJobs`

Prefixes:
- No prefix: general-purpose skills
- Tech-specific prefix: only when 3+ skills target the same tool/stack and name collisions are likely

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

- `description` written so Claude matches natural language requests correctly
- Side-effect skills have `disable-model-invocation: true`
- `allowed-tools` uses constraint syntax (`Bash(git *)`) not broad grants
- `$ARGUMENTS` validation and error handling specified
- Security considerations applied (input sanitization, path validation)
- Examples provided with concrete input/output
- Direct, imperative English instructions
- No emojis, TOC, version numbers, or project-specific details
- SKILL.md under 500 lines (move reference material to supporting files)
