---
name: implement
description: "Implement a task from tasks.yml with automatic document context injection. Use for /implement [task-id] or /implement 'natural language requirement'."
---

# implement

Arguments: $ARGUMENTS

## Purpose

Document-driven task implementation with automatic context injection from tasks.yml.

## Execution Flow

1. Parse task ID from $ARGUMENTS
2. Load tasks.yml and validate
3. Extract task information and document references
4. Load referenced documents via Read tool
5. Create TodoWrite task list
6. Implement with full context
7. Update task status in tasks.yml

## Argument Routing

| $ARGUMENTS | Action |
|------------|--------|
| empty | List pending tasks |
| matches `^task-[0-9]+$` | Standard document-driven flow |
| natural language text | Interactive Mode |

## Argument Validation

```bash
validate_task_id() {
  local task_id="$1"
  [[ -z "$task_id" ]] && return 0
  if [[ ! "$task_id" =~ ^task-[0-9]+$ ]]; then
    echo "ERROR: Invalid task ID format: $task_id"
    echo "Expected: task-N (e.g., task-1, task-42)"
    exit 1
  fi
}

TASK_ID="$ARGUMENTS"
validate_task_id "$TASK_ID"
```

## Interactive Mode

Triggered when $ARGUMENTS is non-empty and does not match task-N format.

**Step 1** — Use AskUserQuestion to select implementation type:
- `ui-component`: UI components, forms, displays, interactions
- `api-integration`: REST API, GraphQL, data fetch/update
- `business-logic`: Calculations, validation, workflows
- `integration-feature`: Multi-component coordination, system integration
- `infrastructure`: Build, deploy, environment setup
- `architecture-change`: Structural improvements, new patterns

**Step 2** — Use AskUserQuestion to select complexity:
- `simple`: Single file/component, 1-2 hours
- `moderate`: Multiple files, half day
- `complex`: New patterns/libraries, 1-2 days
- `architectural`: Design changes, long-term implementation

**Step 3** — Append task to tasks.yml (substitute actual values for $ARGUMENTS, $IMPLEMENTATION_TYPE, $COMPLEXITY before running):

```python
import yaml
from datetime import datetime

try:
    with open('tasks.yml', 'r') as f:
        data = yaml.safe_load(f) or {'project': {}, 'tasks': []}
except FileNotFoundError:
    data = {'project': {'name': 'Project Tasks', 'last_updated': ''}, 'tasks': []}

existing_ids = [int(t['id'].split('-')[1]) for t in data['tasks'] if t['id'].startswith('task-')]
new_id = max(existing_ids, default=0) + 1

effort_map = {'simple': '1-2h', 'moderate': '4h', 'complex': '1-2d', 'architectural': '3-5d'}

new_task = {
    'id': f'task-{new_id}',
    'goal': '$ARGUMENTS',           # substitute actual requirement text
    'type': '$IMPLEMENTATION_TYPE', # substitute selected type
    'status': 'pending',
    'priority': 'medium',
    'effort': effort_map.get('$COMPLEXITY', '4h'),  # substitute selected complexity
    'created_at': datetime.utcnow().isoformat() + 'Z',
    'docs': [],
    'acceptance_criteria': [],
}

data['tasks'].append(new_task)
data['project']['last_updated'] = datetime.utcnow().isoformat() + 'Z'

with open('tasks.yml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

print(f"Created {new_task['id']}: {new_task['goal']}")
```

**Step 4** — Execute `/implement task-N` for the new task.

## Security

Validate before Python execution:

```bash
validate_document_reference() {
  local doc_ref="$1"
  if [[ "$doc_ref" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected: $doc_ref"
    exit 2
  fi
  if [[ "$doc_ref" =~ ^/ ]]; then
    echo "ERROR: Absolute paths not allowed: $doc_ref"
    exit 2
  fi
  local file_path="${doc_ref%%#*}"
  if [[ -n "$file_path" ]] && [[ ! -f "$file_path" ]]; then
    echo "WARNING: Document not found: $file_path — continuing"
    return 1
  fi
  return 0
}
```

**Exit codes**:
- 0: Success
- 1: User error (invalid task ID, task not found)
- 2: Security error (path traversal, absolute path)
- 3: System error (tasks.yml parse failure, Python unavailable)
- 4: Dependency error (required task not completed)

Error messages must not expose absolute paths, stack traces, or internal details.

## Load Task Context

```bash
if [ ! -f "tasks.yml" ]; then
  cat > tasks.yml << 'EOF'
project:
  name: "Project Tasks"
  last_updated: ""
tasks: []
EOF
  echo "Created empty tasks.yml"
fi

TASK_ID="$ARGUMENTS"
TEMP_FILE=$(mktemp /tmp/task-context.XXXXXX.json)
trap 'rm -f "$TEMP_FILE"' EXIT

python3 << PYTHON
import yaml, json, sys

TASK_ID = "$TASK_ID"

try:
    with open('tasks.yml', 'r') as f:
        data = yaml.safe_load(f)
except Exception as e:
    print(f"ERROR: Failed to load tasks.yml: {e}")
    sys.exit(3)

if not TASK_ID:
    print("Available pending tasks:")
    for t in data.get('tasks', []):
        if t.get('status') == 'pending':
            print(f"  {t['id']}: {t['goal']}  [{t.get('priority','medium')}, {t.get('effort','?')}]")
    print("\nUsage: /implement <task-id>")
    sys.exit(0)

task = next((t for t in data.get('tasks', []) if t['id'] == TASK_ID), None)
if not task:
    print(f"ERROR: Task {TASK_ID} not found in tasks.yml")
    sys.exit(1)

for dep_id in task.get('depends_on', []):
    dep = next((t for t in data['tasks'] if t['id'] == dep_id), None)
    if dep and dep['status'] != 'completed':
        print(f"ERROR: Dependency {dep_id} not completed (status: {dep['status']})")
        sys.exit(4)

context = {"task": task, "documents": [{"reference": r} for r in task.get('docs', [])]}
with open('$TEMP_FILE', 'w') as f:
    json.dump(context, f, ensure_ascii=False, indent=2)

print("Task context loaded successfully")
PYTHON

exit_code=$?
[ $exit_code -ne 0 ] && exit $exit_code
[ ! -s "$TEMP_FILE" ] && exit 0  # Listing mode: no task to implement
```

## Create TodoWrite Task List

```bash
python3 << PYTHON
import json

with open('$TEMP_FILE', 'r') as f:
    context = json.load(f)

task = context['task']
docs = context.get('documents', [])

print(f"Task: {task['goal']}")
print(f"Priority: {task.get('priority', 'medium')}")
print(f"Type: {task.get('type', 'implementation')}")

if docs:
    print(f"\nDocument References ({len(docs)}):")
    for doc in docs:
        print(f"  - {doc['reference']}")

if task.get('acceptance_criteria'):
    print("\nAcceptance Criteria:")
    for i, c in enumerate(task['acceptance_criteria'], 1):
        print(f"  {i}. {c}")
PYTHON
```

Use TodoWrite to create implementation steps:
1. Load task context and documents
2. Implement core functionality
3. Verify acceptance criteria
4. Update task status to completed

## Inject Document Context

Extract document references:

```bash
DOC_REFS=$(python3 << PYTHON
import json
with open('$TEMP_FILE', 'r') as f:
    context = json.load(f)
for doc in context.get('documents', []):
    print(doc['reference'])
PYTHON
)

for DOC_REF in $DOC_REFS; do
  validate_document_reference "$DOC_REF" || continue
  FILE_PATH="${DOC_REF%%#*}"
  echo "Loading: $DOC_REF"
done
```

**Use the Read tool for each FILE_PATH above.** If the reference includes `#Section`, focus on that section of the file. Document content is injected into context for the implementation phase.

## Implementation Phase

With full context loaded (task info + all referenced documents):

1. Understand requirements from task goal, acceptance criteria, and documents
2. Implement following patterns from referenced documents
3. Verify all acceptance criteria are met
4. Apply security best practices from CLAUDE.md

## Update Task Status

After successful implementation:

```bash
python3 << PYTHON
import yaml
from datetime import datetime

with open('tasks.yml', 'r') as f:
    data = yaml.safe_load(f)

for task in data.get('tasks', []):
    if task['id'] == '$TASK_ID':
        task['status'] = 'completed'
        task['completed_at'] = datetime.utcnow().isoformat() + 'Z'
        break

data['project']['last_updated'] = datetime.utcnow().isoformat() + 'Z'

with open('tasks.yml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

print(f"Task {task['id']} marked as completed")
PYTHON

if [ -f "todo.md" ]; then
  python3 << PYTHON
import sys, datetime

task_id = '$TASK_ID'

try:
    with open('todo.md', 'r') as f:
        lines = f.readlines()

    updated = False
    for i, line in enumerate(lines):
        if f'#{task_id}' in line and '- [ ]' in line:
            updated_line = line.replace('- [ ]', '- [x]')
            completed_date = datetime.date.today().isoformat()
            if 'Created:' in updated_line:
                if '#' in updated_line:
                    parts = updated_line.split('#', 1)
                    updated_line = f"{parts[0].rstrip()} | Completed: {completed_date} #{parts[1]}"
                else:
                    updated_line = updated_line.rstrip('\n') + f" | Completed: {completed_date}\n"
            lines[i] = updated_line
            updated = True
            break

    if updated:
        with open('todo.md', 'w') as f:
            f.writelines(lines)
        print(f"Updated todo.md: #{task_id}")

except Exception as e:
    print(f"Warning: todo.md update failed: {e}", file=sys.stderr)
    print("Run /todo sync to fix", file=sys.stderr)
PYTHON
fi
```

## Error Handling

| Error | Exit Code | Resolution |
|-------|-----------|------------|
| Invalid task ID format | 1 | Use `/implement` to list valid task IDs |
| Task not found | 1 | Check tasks.yml for correct ID |
| Dependency not completed | 4 | Complete dependency first: `/implement dep-id` |
| Document not found | warn | Implementation continues without missing doc |
| tasks.yml parse error | 3 | Fix YAML syntax; run `yamllint tasks.yml` |
| PyYAML not installed | 3 | `pip3 install PyYAML` |
| Path traversal detected | 2 | Use relative paths from project root only |

## Post-Implementation

Run in order after completion:
1. `/validate --layers=syntax,security --auto-fix`
2. `/commit`
3. Continue: `/implement` (list next pending tasks)

## External References

- tasks.yml schema: `~/.claude/schemas/tasks-schema.yml`
- tasks.yml template: `skills-official/implement/tasks.template.yml`
- Document-driven workflow: CLAUDE.md "基本開発フロー"
- Validation layers: `~/.claude/validation/layers/*.md`
