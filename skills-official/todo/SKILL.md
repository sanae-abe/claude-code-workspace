---
name: todo
description: Personal task list management via todo.md. Add, complete, remove, and list tasks with priorities, due dates, and tags. Use when user wants to manage their todo list, add tasks, mark tasks as done, or track personal action items.
argument-hint: "[action] [description] | add | complete | uncomplete | remove | list | sync | next | interactive"
allowed-tools: Read Write Edit Bash AskUserQuestion Grep Glob
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

1. Check dependencies: verify `python3` is available and `todo_validation.py` exists in skill directory
2. Parse arguments from $ARGUMENTS
3. Validate and sanitize input (security check using todo_validation.py)
4. Locate or create todo.md file in project root
4a. If todo.md exists, check file size (>1MB: report size limit error, exit EXIT_FILE_TOO_LARGE)
5. Determine action: add, complete, uncomplete, remove, list, sync, next, or interactive mode
6. Execute requested action (see Commands section)
7. Update todo.md file if modifications made
8. Display results to user

**Special cases**:
- $ARGUMENTS empty: use AskUserQuestion for interactive mode
- todo.md not found: create new file with empty task list
- Validation fails: report error and exit
- Dependency check fails: report missing dependency and exit with code 127

**Dependency check (run before any action)**:
```bash
command -v python3 &>/dev/null || { echo "ERROR: python3 is required but not found"; exit 127; }
[[ -f "${CLAUDE_SKILL_DIR}/todo_validation.py" ]] || { echo "ERROR: todo_validation.py not found in skill directory"; exit 127; }
# For sync/next actions only (scripts live in ~/.claude/utils/, separate from skill dir)
[[ "$ACTION" == "sync" ]] && { [[ -f "$HOME/.claude/utils/todo_sync.py" ]] || { echo "ERROR: todo_sync.py not found"; exit 127; }; }
[[ "$ACTION" == "next" ]] && { [[ -f "$HOME/.claude/utils/todo_next.py" ]] || { echo "ERROR: todo_next.py not found"; exit 127; }; }
```

### Argument Parsing

Parse $ARGUMENTS to extract:
- Action: first token (add, complete, uncomplete, remove, list, sync, next, interactive)
- Task description: quoted string for add action
- Task number: integer for complete, uncomplete, remove actions
- Options: --priority, --tags, --due, --filter, --sort

### Input Validation

**All inputs must pass validation using todo_validation.py**:

```python
import sys
sys.path.insert(0, '${CLAUDE_SKILL_DIR}')
from todo_validation import validate_path, sanitize_input, validate_task_id

safe_path = validate_path(path)         # Rejects ../, validates within project, denies .git
safe_text = sanitize_input(description) # Unicode normalize, limit 4KB bytes, 1000 chars
task_id = validate_task_id(id_str)      # Must match task-\d+ pattern
```

Validation rules:
- File paths: reject ../, validate within project root, deny .git access
- Task descriptions: Unicode normalize (NFKC), limit 4KB bytes, 1000 chars max
- Task IDs: must match task-\d+ pattern
- Priority: must be critical|high|medium|low
- Tags: alphanumeric, underscore, hyphen only; max 32 chars per tag

### Tool Usage

**Note**: TodoWrite/TodoRead are Claude Code's built-in session task tools — they manage in-session checklists, NOT todo.md. Do not use them for persistent todo.md operations.

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

**Exit code constants must be defined at script start before any action logic** (see Error Handling section for values).

**LLM implements all actions directly (no Python delegation except sync/next)**:

add "description" [options]:
- **LLM**: Parse description from quoted string
- **LLM**: Validate with `sanitize_input()` from todo_validation.py
- **LLM**: Extract --priority, --tags, --due options
- **LLM**: Auto-generate Created field (current date)
- **LLM**: Append new task to todo.md using Edit tool
- Default: priority=medium, tags=none, due=none

**Tag format**: Use `--tags=security,urgent,api` (comma-separated, no spaces) to avoid shell word-splitting issues.

**Bash implementation example**:
```bash
# Exit code constants must be defined first (see Error Handling section)
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_FILE_TOO_LARGE=3
readonly EXIT_UNRECOVERABLE=4

# Parse arguments
DESCRIPTION=""
PRIORITY="medium"
TAGS=""
DUE=""
CREATED=$(date +%Y-%m-%d)

# Extract description (first quoted string)
if [[ "$ARGUMENTS" =~ \"([^\"]+)\" ]]; then
    DESCRIPTION="${BASH_REMATCH[1]}"
fi

# Validate description via Python (skill dir added to sys.path)
python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_SKILL_DIR}')
from todo_validation import sanitize_input
sanitize_input(sys.argv[1])
" "$DESCRIPTION" || exit $EXIT_SECURITY_ERROR

# Extract options — use = syntax to avoid word-splitting (e.g. --tags=security,urgent)
for arg in $ARGUMENTS; do
    case "$arg" in
        --priority=*) PRIORITY="${arg#*=}" ;;
        --tags=*)     TAGS="${arg#*=}" ;;   # comma-separated: security,urgent,api
        --due=*)      DUE="${arg#*=}" ;;
    esac
done

# Build task line
NEW_TASK="- [ ] $DESCRIPTION | Priority: $PRIORITY"
[[ -n "$DUE" ]] && NEW_TASK="$NEW_TASK | Due: $DUE"
NEW_TASK="$NEW_TASK | Created: $CREATED"
# Convert comma-separated tags to hashtag format (IFS-safe, macOS/Linux compatible)
if [[ -n "$TAGS" ]]; then
    HASHTAGS=""
    IFS=',' read -ra TAG_ARRAY <<< "$TAGS"
    for tag in "${TAG_ARRAY[@]}"; do
        HASHTAGS="$HASHTAGS #${tag// /}"   # strip any accidental spaces
    done
    NEW_TASK="$NEW_TASK${HASHTAGS}"
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
    echo "Usage: /todo complete N (where N is a positive integer)"
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
- **LLM**: Apply --filter if specified:
  - `--filter=priority:high` → show only high priority tasks
  - `--filter=tag:security` → show only tasks tagged `#security`
  - `--filter=context:X` → alias for `--filter=tag:X` (backward compat)
- **LLM**: Apply --sort (due, priority) if specified
- **LLM**: Format output with task numbers

**Bash implementation example**:
```bash
# Read todo.md content using Read tool first, then pass as heredoc
# TODOS_CONTENT = result from Read tool on todo.md

# Parse filter options — = syntax avoids word-splitting
FILTER_PRIORITY=""
FILTER_TAG=""
for arg in $ARGUMENTS; do
    case "$arg" in
        --filter=priority:*) FILTER_PRIORITY="${arg#*priority:}" ;;
        --filter=tag:*)      FILTER_TAG="${arg#*tag:}" ;;   # --filter=tag:security
        --filter=context:*)  FILTER_TAG="${arg#*context:}" ;; # alias for --filter=tag:
    esac
done

# Display tasks with numbers, applying filters inline
# Process $TODOS_CONTENT (from Read tool) rather than reading file directly
TASK_NUM=1
while IFS= read -r line; do
    # Skip non-task lines
    [[ "$line" =~ ^-\ \[.?\] ]] || continue
    # Apply priority filter if set
    if [[ -n "$FILTER_PRIORITY" ]] && [[ "$line" != *"Priority: $FILTER_PRIORITY"* ]]; then
        continue
    fi
    # Apply tag/context filter if set (matches #tagname)
    if [[ -n "$FILTER_TAG" ]] && [[ "$line" != *"#$FILTER_TAG"* ]]; then
        continue
    fi
    echo "$TASK_NUM. $line"
    ((TASK_NUM++))
done <<< "$TODOS_CONTENT"
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
- **LLM implementation**: If confirmed, invoke `/implement task-N` via Skill tool
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
3. If confirmed: invoke `/implement task-N` via Skill tool
4. If lightweight task: display to user

### Date parsing

**LLM implementation** (Bash, not Python):
- Detect OS date command (BSD for macOS, GNU for Linux)
- Parse: tomorrow, next week, in N days, YYYY-MM-DD
- Cache OS detection in environment variable

## Error Handling

Use safe_error_message from todo_validation.py for all errors:

```python
import sys
sys.path.insert(0, '${CLAUDE_SKILL_DIR}')
from todo_validation import safe_error_message

try:
    # operation
except Exception as e:
    print(safe_error_message(e, "operation context"))
```

Error handling rules:
- If dependency missing (python3 or todo_validation.py): report missing dependency, exit 127
- If no write permission: report permission error, suggest checking directory permissions
- If invalid arguments: report error with usage example
- If file not found: create new todo.md file
- If security validation fails: report error type without exposing system details
- If file too large (>1MB): report size limit error

Exit code constants (define at start of implementation):
```bash
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_FILE_TOO_LARGE=3
readonly EXIT_UNRECOVERABLE=4
```

Error codes:
- 0: Success - Task operation completed
- 1: User error - Invalid arguments, permission denied
- 2: Security error - Injection attempt, path traversal detected
- 3: File too large - todo.md exceeds 1MB
- 4: Unrecoverable error - Critical failure

Security:
- Never expose absolute paths (use safe_error_message)
- Never expose stack traces (first line only)
- Never expose internal system details
- Report only user-actionable information

## Examples

Input: /todo add "Fix authentication bug" --priority=high --tags=security,urgent,api --due=tomorrow
Output: - [ ] Fix authentication bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 #security #urgent #api

Input: /todo complete 1
Before: - [ ] Fix authentication bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 #security
After:  - [x] Fix authentication bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 | Completed: 2025-01-15 #security

Input: /todo uncomplete 1
Action: Revert task 1 to incomplete status, remove Completed field

Input: /todo remove 2
Action: Delete task 2 from todo.md

Input: /todo list --filter=priority:high --sort=due
Action: List high-priority tasks sorted by due date

Input: /todo list --filter=tag:security
Action: List tasks tagged #security

Input: /todo add "Fix auth bug" --priority=high --tags=security,urgent --due=2025-01-16
Output: - [ ] Fix auth bug | Priority: high | Due: 2025-01-16 | Created: 2025-01-15 #security #urgent

Input: /todo
Action: Interactive mode - prompt for action selection

Input: /todo next
Action: Show next priority task based on due date and priority

Input: /todo sync
Action: Import pending tasks from tasks.yml to todo.md with Created=sync date, tags from type field

---

## Reference Files

**Input validation utilities**: `${CLAUDE_SKILL_DIR}/todo_validation.py`
- Security-focused validation for file paths, user input, task IDs
- Functions:
  - `validate_path()`: Path traversal prevention
  - `sanitize_input()`: Unicode normalization, length limits
  - `validate_task_id()`: task-N format validation
  - `safe_error_message()`: Sanitize error messages
  - `validate_priority()`: Priority value validation
  - `validate_tags()`: Tag format validation

**Usage**: All user inputs in /todo command must pass validation before processing
