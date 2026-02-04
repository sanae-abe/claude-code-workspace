---
allowed-tools: TodoWrite, SlashCommand, Read, Bash
argument-hint: "<task-name> [--perspectives=security,performance,maintainability] [--rounds=2] [--format=detailed|compact]"
description: Create implementation plan, review with iterative-review, update tasks.yml
model: sonnet
---

# plan-review

Arguments: $ARGUMENTS

## Execution Flow

1. Parse arguments from $ARGUMENTS
2. Validate all arguments
3. Create task breakdown using TodoWrite
4. Generate plan.md with task details
5. Execute /iterative-review on plan.md
6. Parse review results
7. Update tasks.yml with new tasks
8. Generate final report

## Argument Validation

Parse $ARGUMENTS to extract:
- Task name (required, first token or quoted string)
- --perspectives flag (optional, default: security,performance,maintainability)
- --rounds flag (optional, default: 2, range: 1-5)
- --format flag (optional, default: detailed, values: detailed|compact)

Validation rules:
- Task name: max 500 characters, reject control characters
- Perspectives: validate against allowed list (security, performance, maintainability, accessibility, testing, documentation)
- Rounds: must be integer 1-5
- Format: must be "detailed" or "compact"

Security validation (execute before any operations):
1. Task name path traversal check:
   - Normalize with realpath -m
   - Verify result stays within project root (git rev-parse --show-toplevel)
   - Reject if contains control characters or null bytes
2. Perspectives command injection check:
   - Split by comma, validate each against allowed list
   - Reject if contains shell metacharacters: ; | & $ ` ( ) < > \ " '
   - Use only validated perspective names in SlashCommand
3. Temporary file security:
   - Use mktemp with restrictive permissions (600)
   - Set trap 'rm -f "$TMPFILE"' EXIT INT TERM at script start
   - Never expose temp file absolute paths in error messages

If task name missing: use AskUserQuestion to collect task description
If invalid flag value: report error with allowed values and exit
If invalid format: report expected format and exit
If security validation fails: report "Invalid input detected" and exit

## Tool Usage

TodoWrite: Create 5-step task list at start:
1. Parse and validate arguments
2. Create task breakdown and plan.md
3. Execute /iterative-review
4. Parse review results
5. Update tasks.yml and generate report

Update status to "in_progress" before each step
Update status to "completed" after each step

SlashCommand: Execute dependent commands:
- /iterative-review <temp-file-basename> --skip-necessity --perspectives=<validated-perspectives> --rounds=<validated-rounds>
- Use only validated perspective values (already checked against allowed list)
- Use basename of temp file, not absolute path
- Never interpolate unvalidated variables into command

Bash: File operations and validation:
- Create temporary plan.md using mktemp
- Validate git repository if needed
- Execute jq for JSON config parsing

## Task Breakdown Process

Use TodoWrite to structure tasks:
1. Identify main task components from task name
2. Determine dependencies between components
3. Estimate time using three-point estimation (optimistic, most-likely, pessimistic)
4. Assign priority (high, medium, low)
5. Generate plan.md with structured task list

Plan.md format:
```
# Implementation Plan: [TASK_NAME]

## Tasks
1. [Task 1] - [estimate], priority: [high/medium/low], depends: [none/task-id]
2. [Task 2] - [estimate], priority: [high/medium/low], depends: [task-id]

## Dependencies
Task 1 -> Task 2

## Initial Risk Assessment
- Security: [initial concerns]
- Performance: [initial concerns]
- Maintainability: [initial concerns]
```

## Review Integration

Execute /iterative-review with --skip-necessity flag:
- Skip necessity evaluation (assume feature is needed)
- Focus on security, performance, maintainability improvements
- Generate actionable recommendations

Parse review results:
- Extract Critical issues (must fix)
- Extract Important issues (should fix)
- Extract Minor issues (nice to have)
- Identify new tasks from recommendations
- Update time estimates based on review findings

## tasks.yml Update Process

Auto-create tasks.yml if missing:
```bash
if [ ! -f "tasks.yml" ]; then
  cat > tasks.yml << 'EOF'
project:
  name: "Project Tasks"
  last_updated: ""

tasks: []
EOF
fi
```

For each task from plan and review results:
1. Generate unique task ID (find max existing task-N, increment)
2. Determine task goal from plan
3. Assign priority based on review severity (Critical -> high, Important -> medium, Minor -> low)
4. Extract effort estimate from plan
5. Identify acceptance criteria from review
6. Append to tasks.yml using Python YAML manipulation

Python implementation:
```python
import yaml
import re
from datetime import datetime

def sanitize_yaml_string(s: str) -> str:
    """Sanitize string for safe YAML insertion."""
    # Reject YAML tags, anchors, aliases, and flow indicators
    if re.search(r'!!|&|\*|^[>|]|[\x00-\x1f\x7f]', s):
        raise ValueError(f"Invalid characters in YAML string")
    return s

# Load existing tasks.yml
with open('tasks.yml', 'r') as f:
    data = yaml.safe_load(f)

# Find next task ID
existing_ids = [int(t['id'].split('-')[1]) for t in data.get('tasks', []) if t['id'].startswith('task-')]
next_id = max(existing_ids, default=0) + 1

# Sanitize all user input before insertion
new_task = {
    'id': f'task-{next_id}',
    'goal': sanitize_yaml_string(goal),
    'status': 'pending',
    'priority': priority,  # Already validated to be high/medium/low
    'effort': sanitize_yaml_string(effort),
    'type': 'implementation',
    'acceptance_criteria': [sanitize_yaml_string(c) for c in acceptance_criteria]
}

data['tasks'].append(new_task)
data['project']['last_updated'] = datetime.utcnow().isoformat() + 'Z'

# Write back using safe_dump (not dump)
with open('tasks.yml', 'w') as f:
    yaml.safe_dump(data, f, default_flow_style=False, allow_unicode=True)
```

Handle batch updates:
- Process all tasks in single Python script execution
- Track success/failure of YAML operations
- If YAML write fails: save tasks to plan-final.yml for manual merge

## Report Generation

Detailed format (default):
- Task breakdown with estimates
- Review results summary (Critical/Important/Minor counts)
- Priority action plan
- Execution timeline
- Next steps

Compact format (--format=compact):
- Task count and total estimate
- Critical/Important issues only
- Top 3 priority actions
- Next immediate step

## Error Handling

Argument validation:
If task name missing: use AskUserQuestion with prompt "Enter task description:"
If invalid perspectives: report "Invalid perspective. Allowed: security, performance, maintainability, accessibility, testing, documentation"
If invalid rounds: report "Invalid rounds value. Must be integer 1-5"
If invalid format: report "Invalid format. Must be: detailed or compact"

Execution errors:
If /iterative-review fails: report "/iterative-review failed. Plan saved to temporary file for manual review"
If tasks.yml write fails: report "tasks.yml write failed. Tasks saved to fallback file for manual merge"
If plan.md creation fails: report "Failed to create plan file" and exit
If config file invalid JSON: report "Config file invalid JSON format. Using defaults"
If YAML parsing fails: report "tasks.yml is invalid YAML. Backup created"
If YAML sanitization fails: report "Invalid characters detected in task data" and exit

Dependency errors:
If /iterative-review command not found: report "/iterative-review command not available. Install iterative-review.md"
If python3 not available: report "Python 3 required for tasks.yml manipulation"
If PyYAML not installed: report "PyYAML required. Install with: pip install pyyaml"

Security:
Never expose absolute paths in error messages
Never expose stack traces
Report only user-actionable information

## Configuration File

Optional configuration: project/.claude/plan-review.json

Expected format:
```json
{
  "defaultPerspectives": ["security", "performance", "maintainability"],
  "defaultRounds": 2,
  "defaultFormat": "detailed",
  "autoUpdateTodo": true
}
```

If config file exists:
1. Validate JSON format using jq
2. Validate field types and values
3. Apply settings if valid
4. Report warning and use defaults if invalid

## Examples

Input: /plan-review "User authentication feature"
Action: Create plan for authentication feature, review with default perspectives (security, performance, maintainability) for 2 rounds, append tasks to tasks.yml with detailed report

Output tasks.yml:
```yaml
tasks:
  - id: task-1
    goal: "Implement login endpoint with JWT"
    status: pending
    priority: high
    effort: 4h
    type: implementation
    acceptance_criteria:
      - "POST /api/login accepts email/password"
      - "Returns JWT token on success"
      - "Returns 401 on invalid credentials"
  - id: task-2
    goal: "Add token refresh mechanism"
    status: pending
    priority: high
    effort: 2h
    type: implementation
    acceptance_criteria:
      - "Refresh token stored in httpOnly cookie"
      - "Refresh endpoint returns new access token"
```

Input: /plan-review "API cache layer" --perspectives=security,performance
Action: Create plan for cache layer, review with security and performance only, append tasks to tasks.yml

Input: /plan-review "Button component refactor" --rounds=1 --format=compact
Action: Create plan for refactor, quick 1-round review, append tasks to tasks.yml with compact summary

Input: /plan-review
Action: Use AskUserQuestion to collect task description, then execute with defaults

Input: /plan-review "Large feature" --perspectives=invalid
Action: Report error: "Invalid perspective. Allowed: security, performance, maintainability, accessibility, testing, documentation" and exit

## Exit Code System

```bash
# 0: Success - Plan created, reviewed, tasks.yml updated
# 1: User error - Task name missing, invalid arguments
# 2: Security error - YAML injection detected, path traversal
# 3: System error - /iterative-review failed, PyYAML not available
# 4: Unrecoverable error - tasks.yml corruption, critical failure
```

## Output Format

**Success example**:
```
✓ Implementation plan created and reviewed
✓ Tasks added to tasks.yml: 3 new tasks
✓ Review completed: 2 rounds

Plan Summary:
  - Total tasks: 3
  - Critical issues: 0
  - Important issues: 2
  - Total effort: 10h

Next steps:
  1. Review tasks.yml
  2. Run /todo sync
  3. Start with /implement task-1
```

**Error example**:
```
ERROR: YAML sanitization failed
File: plan-review.md:sanitize_yaml_string

Reason: Invalid characters detected in task data
Got: Task description contains YAML anchor/alias characters

Suggestions:
1. Remove special YAML characters: !!, &, *, |, >
2. Use plain text descriptions only
3. Check task name for control characters
```

