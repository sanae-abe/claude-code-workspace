---
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, TodoWrite, Grep, Glob
argument-hint: "[action] [description] | add | complete | uncomplete | remove | list | sync | next | interactive"
description: Simple project task management with interactive UI and priority handling
model: sonnet
---

# Todo Manager

Arguments: $ARGUMENTS

## Purpose

Lightweight task management for ad-hoc, document-free tasks that don't require formal planning.

**Use /todo for**:
- Quick tasks without documentation (e.g., "Fix typo in README")
- Personal reminders and research notes (e.g., "Investigate library X")
- Short-term action items (completed within hours/days)
- Syncing important tasks from tasks.yml to personal list

**Use /implement for**:
- Formal tasks with documentation requirements (docs/, acceptance_criteria)
- Planned features requiring design/architecture
- Long-term projects with multiple stakeholders

**Key difference**: /todo manages todo.md (personal, flexible), /implement manages tasks.yml (project-wide, structured).

## Implementation Guide

### Execution Flow

1. Parse arguments from $ARGUMENTS
2. Validate and sanitize input (security check using ~/.claude/utils/todo_validation.py)
3. Determine action: add, complete, uncomplete, remove, list, sync, next, or interactive mode
4. Locate or create todo.md file in project root
5. Execute requested action (see Commands section)
6. Update todo.md file if modifications made
7. Display results to user

**Special cases**:
- $ARGUMENTS empty: use AskUserQuestion for interactive mode
- todo.md not found: create new file with empty task list
- Validation fails: report error and exit

### Arguments & Validation

### Argument Parsing

Parse $ARGUMENTS to extract:
- Action: first token (add, complete, uncomplete, remove, list, sync, next, interactive)
- Task description: quoted string for add action
- Task number: integer for complete, uncomplete, remove actions
- Options: --priority, --tags, --due, --filter, --sort

### Input Validation

**All inputs must pass validation using ~/.claude/utils/todo_validation.py**:

```python
from todo_validation import validate_path, sanitize_input, validate_task_id

safe_path = validate_path(path)        # Rejects ../, validates within project, denies .git
safe_text = sanitize_input(description) # Unicode normalize, limit 4KB bytes, 1000 chars
task_id = validate_task_id(id_str)     # Must match task-\d+ pattern
```

Validation rules:
- File paths: reject ../, validate within project root, deny .git access
- Task descriptions: Unicode normalize (NFKC), limit 4KB bytes, 1000 chars max
- Task IDs: must match task-\d+ pattern
- Priority: must be critical|high|medium|low
- Tags: alphanumeric, underscore, hyphen only; max 32 chars per tag

### Tool Usage

**TodoWrite**: Use when processing multiple tasks or complex operations

**AskUserQuestion**: Use in interactive mode when $ARGUMENTS empty
- Primary action selection: add-task, review-list, quick-complete
- Task priority selection: critical, high, medium, low
- Task tags input: free-form text (e.g., "security urgent api")

**Bash**: Use for date parsing and executing Python validation scripts

**Read/Write/Edit**: todo.md file operations

**Grep**: Search for specific tasks or patterns

## Commands

### File Format

todo.md uses markdown checklist with metadata:

```markdown
- [ ] Fix auth bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 #security #urgent
- [x] Update README | Priority: medium | Created: 2025-01-14 | Completed: 2025-01-15 #docs
```

**Field specification**:
- Priority: critical, high, medium, low (required)
- Due: YYYY-MM-DD (optional)
- Created: YYYY-MM-DD (auto-generated, required)
- Completed: YYYY-MM-DD (auto-generated on completion, completed tasks only)
- Tags: #tag1 #tag2 ... (optional, free-form, alphanumeric + underscore + hyphen)

### Actions

**LLM implements all actions directly (no Python delegation except sync/next)**:

add "description" [options]:
- **LLM**: Parse description from quoted string
- **LLM**: Validate with `sanitize_input()` from todo_validation.py
- **LLM**: Extract --priority, --tags, --due options
- **LLM**: Auto-generate Created field (current date)
- **LLM**: Append new task to todo.md using Edit tool
- Default: priority=medium, tags=none, due=none

**Bash implementation example**:
```bash
# Parse arguments
ACTION="add"
DESCRIPTION=""
PRIORITY="medium"
TAGS=""
DUE=""
CREATED=$(date +%Y-%m-%d)

# Extract description (first quoted string)
if [[ "$ARGUMENTS" =~ \"([^\"]+)\" ]]; then
    DESCRIPTION="${BASH_REMATCH[1]}"
fi

# Validate description (using Python script)
python3 -c "from todo_validation import sanitize_input; import sys; sanitize_input(sys.argv[1])" "$DESCRIPTION" || exit $EXIT_SECURITY_ERROR

# Extract options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --priority=*) PRIORITY="${1#*=}" ;;
        --tags=*) TAGS="${1#*=}" ;;
        --due=*) DUE="${1#*=}" ;;
    esac
    shift
done

# Build task line
NEW_TASK="- [ ] $DESCRIPTION | Priority: $PRIORITY"
[[ -n "$DUE" ]] && NEW_TASK="$NEW_TASK | Due: $DUE"
NEW_TASK="$NEW_TASK | Created: $CREATED"
# Convert tags to hashtag format (space-separated "tag1 tag2" → "#tag1 #tag2")
if [[ -n "$TAGS" ]]; then
    HASHTAGS=$(echo "$TAGS" | sed 's/\b/#/g')
    NEW_TASK="$NEW_TASK $HASHTAGS"
fi
# Use Edit tool to append NEW_TASK to todo.md
```

complete N | done N:
- **LLM**: Parse task number N
- **LLM**: Read todo.md, mark task N as completed ([x])
- **LLM**: Add Completed field (current date) after Created field
- **LLM**: Update todo.md using Edit tool

**Bash implementation example**:
```bash
# Parse task number
TASK_NUM=$(echo "$ARGUMENTS" | awk '{print $2}')
COMPLETED=$(date +%Y-%m-%d)

# Validate task number (integer only)
if [[ ! "$TASK_NUM" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid task number: $TASK_NUM"
    echo "File: todo.md:161 - Task Number Validation"
    echo "Usage: /todo complete N (where N is a number)"
    exit $EXIT_USER_ERROR
fi

# Read todo.md using Read tool, get line at index TASK_NUM
# 1. Replace "- [ ]" with "- [x]"
# 2. Insert " | Completed: $COMPLETED" after Created field
# Update todo.md using Edit tool with old/new strings
```

list [options]:
- **LLM**: Read todo.md file using Read tool
- **LLM**: Display all tasks with numbers
- **LLM**: Apply --filter (priority:X, context:Y) if specified
- **LLM**: Apply --sort (due, priority) if specified
- **LLM**: Format output with task numbers

**Bash implementation example**:
```bash
# Read todo.md using Read tool
# Store in variable TODOS_CONTENT

# Parse filter options
FILTER_PRIORITY=""
FILTER_CONTEXT=""
for arg in $ARGUMENTS; do
    case "$arg" in
        --filter=priority:*) FILTER_PRIORITY="${arg#*:}" ;;
        --filter=context:*) FILTER_CONTEXT="${arg#*:}" ;;
    esac
done

# Filter tasks (using Grep tool if filter specified)
FILTERED_TASKS="$TODOS_CONTENT"
if [[ -n "$FILTER_PRIORITY" ]]; then
    # Use Grep tool with pattern "Priority: $FILTER_PRIORITY"
    :
fi

# Display with numbers
echo "Tasks:"
IFS=$'\n'
TASK_NUM=1
for task in $FILTERED_TASKS; do
    echo "$TASK_NUM. $task"
    ((TASK_NUM++))
done
```

uncomplete N:
- **LLM**: Parse task number N
- **LLM**: Read todo.md, revert task N to incomplete ([ ])
- **LLM**: Update todo.md using Edit tool

remove N | delete N:
- **LLM**: Parse task number N
- **LLM**: Remove task N from todo.md using Edit tool

next:
- **LLM implementation**: Execute `python3 ~/.claude/utils/todo_next.py`
- **LLM implementation**: Parse output (NEXT_TASK_ID, PRIORITY, EFFORT, DESCRIPTION)
- **LLM implementation**: If big task (#task-N), use AskUserQuestion for /implement confirmation
- **LLM implementation**: If confirmed, execute SlashCommand("/implement task-N")
- **LLM implementation**: For lightweight tasks, display to user
- **Python script**: todo_next.py handles file parsing and task selection logic

sync:
- **LLM implementation**: Execute `python3 ~/.claude/utils/todo_sync.py`
- **LLM implementation**: Parse script output and report results to user
- **LLM implementation**: Handle errors (e.g., tasks.yml not found)
- **Python script**: todo_sync.py handles YAML parsing, validation, sanitization, file I/O
- **Note**: Idempotent (can run multiple times safely), never modifies existing tasks

## External Scripts (Python)

**LLM delegates to Python scripts for security-critical operations**:

### sync action: todo_sync.py

```bash
python3 ~/.claude/utils/todo_sync.py
```

**Script responsibilities** (DO NOT implement in LLM):
- Load and validate tasks.yml (YAML parsing)
- Extract pending tasks with validation
- O(1) optimization: read last 100 lines of todo.md for max task ID
- Sanitize goal text + shlex.quote metadata (prevent injection)
- Append new tasks to todo.md

**Security features**:
- Task ID validation (task-\d+ pattern)
- Command injection prevention (shlex.quote)
- Safe error messages (no path exposure)

**LLM implementation**: Execute script, parse output, report to user

### next action: todo_next.py

```bash
python3 ~/.claude/utils/todo_next.py
```

**Script outputs**:
- Big tasks: `NEXT_TASK_ID:task-N / PRIORITY:X / EFFORT:Y / DESCRIPTION:...`
- Lightweight tasks: `Next task (lightweight): ...`

**LLM implementation**:
1. Execute script, parse output
2. If big task (NEXT_TASK_ID present): use AskUserQuestion for /implement confirmation
3. If lightweight task: display to user

### Date parsing

**LLM implementation** (Bash, not Python):
- Detect OS date command (BSD for macOS, GNU for Linux)
- Parse: tomorrow, next week, in N days, YYYY-MM-DD
- Cache OS detection in environment variable

## Error Handling

Use safe_error_message from todo_validation.py for all errors:

```python
from todo_validation import safe_error_message

try:
    # operation
except Exception as e:
    print(safe_error_message(e, "operation context"))
```

Error handling rules:
- If no write permission: report permission error (todo.md:212), suggest checking directory permissions
- If invalid arguments: report error with usage example (todo.md:213)
- If file not found: create new todo.md file (todo.md:214)
- If security validation fails: report error type without exposing system details (todo.md:215)
- If file too large (>1MB): report size limit error (todo.md:216)

Exit code constants (define at start of implementation):
```bash
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_FILE_TOO_LARGE=3
readonly EXIT_UNRECOVERABLE=4
```

Error codes usage:
- 0: Success - Task operation completed (todo.md:219)
- 1: User error - Invalid arguments, permission denied (todo.md:220)
- 2: Security error - Injection attempt, path traversal detected (todo.md:221)
- 3: File too large - todo.md exceeds 1MB (todo.md:222)
- 4: Unrecoverable error - Critical failure (todo.md:223)

Security:
- Never expose absolute paths (use safe_error_message)
- Never expose stack traces (first line only)
- Never expose internal system details
- Report only user-actionable information

## Examples

Input: /todo add "Fix authentication bug" --priority high --tags "security urgent api" --due tomorrow
Output: - [ ] Fix authentication bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 #security #urgent #api

Input: /todo complete 1
Before: - [ ] Fix authentication bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 #security
After:  - [x] Fix authentication bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 | Completed: 2025-01-15 #security

Input: /todo uncomplete 1
Action: Revert task 1 to incomplete status, remove Completed field

Input: /todo remove 2
Action: Delete task 2 from todo.md

Input: /todo list --filter priority:high --sort due
Action: List high-priority tasks sorted by due date

Input: /todo
Action: Interactive mode - prompt for action selection

Input: /todo next
Action: Show next priority task based on due date and priority

Input: /todo sync
Action: Import pending tasks from tasks.yml to todo.md with Created=sync date, tags from type field
