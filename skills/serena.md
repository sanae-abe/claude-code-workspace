---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, TodoWrite, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: Semantic code analysis using Serena MCP
model: sonnet
---

# Serena MCP Command

Semantic code operations using AST-based analysis. Use Model Context Protocol for advanced code understanding and manipulation.

Arguments: $ARGUMENTS

## Core Use Cases

Use Serena MCP for:
- **Multi-file refactoring**: Symbol-aware code changes across codebase
- **Dependency analysis**: Reference tracking and impact assessment
- **Complex debugging**: Semantic code understanding for root cause analysis
- **Architecture exploration**: Project structure and symbol relationships

Use standard commands for:
- Single-file edits within one location
- Git operations (branch, commit, PR)
- Configuration updates (package.json, etc.)
- Emergency fixes requiring rapid response

## Argument Validation and Sanitization

Parse and validate $ARGUMENTS with security-first approach:

```bash
validate_arguments() {
  local args="$1"

  # Empty check (minimum 10 characters)
  if [[ ${#args} -lt 10 ]]; then
    echo "ERROR [serena.md:32]: Problem description too short"
    echo "  Minimum: 10 characters"
    echo "  Example: /serena \"fix login authentication bug\""
    exit 1
  fi

  # Dangerous character check
  local dangerous_pattern='[;`$()&|]'
  if [[ "$args" =~ $dangerous_pattern ]]; then
    echo "ERROR [serena.md:32]: Dangerous shell characters detected"
    echo "  Input: $args"
    echo "  Forbidden: ; \` \$() & |"
    echo "  Reason: Command injection prevention"
    exit 2
  fi

  # Path traversal check
  if [[ "$args" =~ \.\. ]]; then
    echo "ERROR [serena.md:32]: Path traversal detected"
    echo "  Input: $args"
    echo "  Reason: Security restriction"
    exit 2
  fi

  echo "$args"
}

parse_flags() {
  local args="$1"
  CREATE_TODOS=false
  INCLUDE_RESEARCH=false
  VERBOSE=false

  # Parse supported flags
  if [[ "$args" =~ -t ]]; then CREATE_TODOS=true; fi
  if [[ "$args" =~ -r ]]; then INCLUDE_RESEARCH=true; fi
  if [[ "$args" =~ -v ]]; then VERBOSE=true; fi

  # Remove flags from problem description
  PROBLEM=$(echo "$args" | sed 's/-[trv]//g' | xargs)
  echo "$PROBLEM"
}

# Validate and parse arguments
VALIDATED_ARGS=$(validate_arguments "$ARGUMENTS")
PROBLEM=$(parse_flags "$VALIDATED_ARGS")
```

## Execution Flow

1. Parse and validate problem description with strict input sanitization
2. Verify MCP server availability and connectivity
3. Use appropriate Serena MCP tools for semantic analysis
4. Synthesize actionable solution with specific next steps
5. Create TodoWrite if `-t` flag provided

## Available Flags

**Essential Flags**:
- `-t`: Create implementation todos after analysis (useful for complex features)
- `-r`: Include Context7 research for library documentation (technology decisions)
- `-v`: Verbose output showing detailed analysis (debugging purposes)

**Examples**:
```bash
/serena "fix login bug"                        # Basic debugging
/serena "refactor auth module" -t              # Refactoring with todos
/serena "implement OAuth flow" -r -t           # Feature with research and todos
/serena "analyze performance bottleneck" -v    # Detailed performance analysis
```

## Core MCP Operations

Primary Serena MCP tools for semantic code analysis:

**Symbol Operations**:
- `mcp__serena__find_symbol`: Locate function/class definitions by name
- `mcp__serena__find_referencing_symbols`: Understand usage and dependencies
- `mcp__serena__get_symbols_overview`: Project-wide structure comprehension

**Code Modification**:
- `mcp__serena__replace_symbol_body`: Refactor functions/classes semantically
- `mcp__serena__insert_after_symbol`: Add methods/logic after existing symbols
- `mcp__serena__insert_before_symbol`: Add methods/logic before existing symbols

**Search and Analysis**:
- `mcp__serena__search_for_pattern`: Find code patterns across codebase
- `mcp__serena__list_dir`: Directory structure exploration
- `mcp__serena__find_file`: Semantic file search

**Memory and Context**:
- `mcp__serena__write_memory`: Store project insights
- `mcp__serena__read_memory`: Retrieve stored knowledge
- `mcp__serena__list_memories`: View available memories

**Context7 Integration** (with `-r` flag):
- `mcp__context7__resolve-library-id`: Find library documentation
- `mcp__context7__get-library-docs`: Fetch official documentation

## Problem-Solving Patterns

For structured problem-solving approaches, see:
- **Agent Selection**: `~/.claude/CLAUDE.md` (Agent選択フロー)
- **Tool Selection**: `~/.claude/CLAUDE.md` (Tool usage policy)

Serena automatically applies appropriate analysis patterns based on problem type.

## Error Handling

**Validation failures**:
- If problem description empty or too short: Request detailed description (min 10 chars)
- If dangerous characters detected: Report security risk with forbidden characters
- If path traversal attempt: Reject with security error (exit 2)

**MCP operation failures**:
- If MCP server unavailable: Check server status and provide restart instructions
- If symbol not found: Suggest pattern search as alternative approach
- If AST parsing fails: Validate file syntax and encoding
- If memory quota exceeded: Provide cleanup instructions

**Recovery strategies**:
- If MCP server not responding: Check logs, restart server
- If semantic analysis fails: Fall back to pattern-based search
- If operation timeout: Break into smaller operations

**Security principles**:
- Never expose absolute file paths in error messages
- Report only relative paths from project root
- Never expose stack traces to end users
- Never expose internal MCP server details
- Never expose sensitive project information

Error message format:
```bash
echo "ERROR [serena.md:LINE]: Error description"
echo "  Context: Additional information"
echo "  Suggestion: User-actionable fix"
```

## Exit Codes

- 0: Success - MCP operation completed successfully
- 1: User error - Invalid pattern, symbol not found, empty query, description too short
- 2: Security error - Validation failure, dangerous characters, path traversal
- 3: System error - MCP server not responding, network failure
- 4: Unrecoverable - AST parsing failed, data corruption

## Examples

```bash
# Debugging
/serena "memory leak in production login flow"
/serena "fix authentication error on API endpoint" -v

# Refactoring
/serena "refactor user service to use repository pattern" -t
/serena "split large component into smaller modules" -t

# Feature Implementation
/serena "add OAuth2 authentication with refresh tokens" -r -t
/serena "implement caching layer for database queries" -r -t

# Analysis
/serena "analyze dependencies of payment module" -v
/serena "find all usages of deprecated API"
/serena "review code for security vulnerabilities"

# Architecture
/serena "design microservices migration strategy" -r -v
/serena "evaluate framework alternatives for frontend" -r
```
