---
allowed-tools: TodoWrite, Bash, Read, Edit, Write, AskUserQuestion
argument-hint: "[task-id]"
description: "Implement a task from tasks.yml with automatic document context injection"
model: sonnet
---

# implement

Arguments: $ARGUMENTS

## Purpose

Document-driven task implementation with automatic context injection from tasks.yml.

## Execution Flow

1. Parse task ID from $ARGUMENTS
2. Load tasks.yml and validate
3. Extract task information
4. Load document references automatically
5. Create TodoWrite task list
6. Implement with full context
7. Update task status in tasks.yml

## Argument Validation

Execute validation before any operations:

```bash
# Validate task ID format
validate_task_id() {
  local task_id="$1"

  # Empty is OK (will list tasks)
  if [[ -z "$task_id" ]]; then
    return 0
  fi

  # Validate format: task-N (prevent injection)
  if [[ ! "$task_id" =~ ^task-[0-9]+$ ]]; then
    echo "ERROR: Invalid task ID format: $task_id"
    echo "Expected: task-N (e.g., task-1, task-42)"
    echo "Example: /implement task-1"
    exit 1
  fi
}

# Safe argument parsing
TASK_ID="$ARGUMENTS"
validate_task_id "$TASK_ID"
```

If validation fails: exit with error code 1 (user error)
If no argument: list pending tasks via Python script (line 104-116)

## Interactive Mode (New Feature Creation)

**Purpose**: Create new features interactively when task-id not specified and $ARGUMENTS contains natural language requirements.

**Trigger conditions**:
```bash
# Detect interactive mode
if [[ -z "$TASK_ID" ]] && [[ -n "$ARGUMENTS" ]]; then
  # $ARGUMENTS contains natural language (e.g., "user profile editing")
  INTERACTIVE_MODE=true
fi
```

**Execution flow**:

1. **Parse natural language requirements** from $ARGUMENTS
2. **Use AskUserQuestion** to determine implementation approach
3. **Auto-generate tasks.yml entry** based on selections
4. **Execute /implement task-N** automatically with new task

**Implementation Type Selection**:

Use AskUserQuestion to determine feature type:

```typescript
AskUserQuestion({
  questions: [{
    question: "Select the type of feature to implement",
    header: "Implementation Type",
    multiSelect: false,
    options: [
      {
        label: "ui-component",
        description: "UI components and screen features (forms, displays, interactions)"
      },
      {
        label: "api-integration",
        description: "API integration and data processing (REST API, GraphQL, data fetch/update)"
      },
      {
        label: "business-logic",
        description: "Business logic and state management (calculations, validation, workflows)"
      },
      {
        label: "integration-feature",
        description: "Integrated features (multiple component coordination, system integration)"
      },
      {
        label: "infrastructure",
        description: "Infrastructure and configuration (build, deploy, environment setup)"
      },
      {
        label: "architecture-change",
        description: "Architecture changes (structural improvements, new pattern introduction)"
      }
    ]
  }]
})
```

**Complexity Level Selection**:

Use AskUserQuestion to determine scope:

```typescript
AskUserQuestion({
  questions: [{
    question: "Select the implementation scope and complexity",
    header: "Complexity",
    multiSelect: false,
    options: [
      {
        label: "simple",
        description: "Simple (single file/component, 1-2 hours)"
      },
      {
        label: "moderate",
        description: "Moderate (multiple files, related feature updates, half day)"
      },
      {
        label: "complex",
        description: "Complex (new patterns/libraries, 1-2 days)"
      },
      {
        label: "architectural",
        description: "Architectural level (design changes, long-term implementation)"
      }
    ]
  }]
})
```

**Auto-generate tasks.yml entry**:

```python
# Python script to append new task
import yaml
from datetime import datetime

# Read existing tasks.yml or create new one
try:
    with open('tasks.yml', 'r') as f:
        data = yaml.safe_load(f) or {'project': {}, 'tasks': []}
except FileNotFoundError:
    data = {
        'project': {
            'name': 'Project Tasks',
            'last_updated': ''
        },
        'tasks': []
    }

# Generate new task ID
existing_ids = [int(t['id'].split('-')[1]) for t in data['tasks'] if t['id'].startswith('task-')]
new_id = max(existing_ids, default=0) + 1

# Map complexity to effort
complexity_to_effort = {
    'simple': '1-2h',
    'moderate': '4h',
    'complex': '1-2d',
    'architectural': '3-5d'
}

# Create new task entry
new_task = {
    'id': f'task-{new_id}',
    'goal': '$ARGUMENTS',  # Natural language requirement
    'type': '$IMPLEMENTATION_TYPE',  # From AskUserQuestion
    'status': 'pending',
    'priority': 'medium',
    'effort': complexity_to_effort['$COMPLEXITY'],  # From AskUserQuestion
    'created_at': datetime.utcnow().isoformat() + 'Z',
    'docs': [],  # LLM can populate based on implementation type
    'acceptance_criteria': []  # LLM can generate based on requirement
}

data['tasks'].append(new_task)
data['project']['last_updated'] = datetime.utcnow().isoformat() + 'Z'

# Write back to tasks.yml
with open('tasks.yml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

print(f"✅ Created {new_task['id']}: {new_task['goal']}")
```

**Execute implementation**:

After tasks.yml creation, automatically execute:
```bash
/implement task-N
```

This triggers the standard document-driven implementation flow (lines 17-24).

**Example usage**:

```bash
# Interactive mode with natural language
/implement "user profile editing feature"

# Output:
# [AskUserQuestion: Select implementation type]
# User selects: ui-component
# [AskUserQuestion: Select complexity]
# User selects: moderate
# ✅ Created task-5: user profile editing feature
# [Automatically executes: /implement task-5]
# [Standard implementation flow with document context injection]
```

**Integration with feature.md**:

This Interactive Mode replaces the standalone `/feature` command, providing:
- Same AskUserQuestion workflow
- Enhanced with automatic document context injection
- Seamless transition to implementation
- tasks.yml-based tracking (vs. ephemeral TodoWrite in `/feature`)

## Security Implementation

**MANDATORY: Execute these validations BEFORE Python execution**

```bash
# 1. Validate task ID format (already in Argument Validation)
# See lines 31-47 above

# 2. Validate document references (prevent path traversal)
validate_document_reference() {
  local doc_ref="$1"

  # Reject path traversal
  if [[ "$doc_ref" =~ \.\. ]]; then
    echo "ERROR: Path traversal detected in document reference: $doc_ref"
    echo "Security policy: relative paths within project only"
    exit 2
  fi

  # Reject absolute paths
  if [[ "$doc_ref" =~ ^/ ]]; then
    echo "ERROR: Absolute paths not allowed in document references: $doc_ref"
    echo "Use relative paths from project root"
    exit 2
  fi

  # Extract file path (before #)
  local file_path="${doc_ref%%#*}"

  # Validate file exists (warn if not, but don't fail)
  if [[ -n "$file_path" ]] && [[ ! -f "$file_path" ]]; then
    echo "WARNING: Document not found: $file_path"
    echo "Continuing without this reference..."
    return 1
  fi

  return 0
}

# 3. Validate tasks.yml (prevent YAML injection)
# Python handles YAML parsing with safe_load (line 99)
# yaml.safe_load() prevents arbitrary Python object execution
```

**Execution order**:
1. validate_task_id "$TASK_ID" (Argument Validation section)
2. Auto-create tasks.yml if missing (line 68-79)
3. Load and validate tasks.yml with Python yaml.safe_load (line 99)
4. validate_document_reference for each doc reference (before Read)
5. Execute implementation

**Exit codes**:
- 0: Success
- 1: User error (invalid task ID format)
- 2: Security error (path traversal, absolute path)
- 3: System error (tasks.yml parsing failed, Python unavailable)
- 4: Dependency not met (required task not completed)

## Tool Usage

TodoWrite: Create implementation task list:
1. Load task from tasks.yml
2. Extract document references
3. Create implementation steps
4. Execute implementation
5. Update task status

Bash: Execute Python scripts:
- Load tasks.yml
- Validate schema
- Extract task context
- Update task status

Read: Load document sections:
- Read referenced documents
- Extract specific sections
- Inject into context

## Load Task Context

Step 1: Validate tasks.yml exists and load task information

Combined Python script for efficiency (single interpreter startup):

```bash
# Auto-create tasks.yml if missing
if [ ! -f "tasks.yml" ]; then
  echo "⚠️  tasks.yml not found. Creating empty tasks.yml..."
  cat > tasks.yml << 'EOF'
project:
  name: "Project Tasks"
  last_updated: ""

tasks: []
EOF
  echo "✅ Created empty tasks.yml"
  echo ""
fi

# Extract and validate task ID
TASK_ID="$ARGUMENTS"

# Unified Python script: list tasks, validate, load context, check dependencies
TEMP_FILE=$(mktemp /tmp/task-context.XXXXXX.json)
trap 'rm -f "$TEMP_FILE"' EXIT

python3 << PYTHON
import yaml
import json
import sys
from datetime import datetime

TASK_ID = "$TASK_ID"

# Load tasks.yml
try:
    with open('tasks.yml', 'r') as f:
        data = yaml.safe_load(f)
except Exception as e:
    print(f"ERROR: Failed to load tasks.yml: {e}")
    sys.exit(1)

# If no task ID provided, list pending tasks
if not TASK_ID:
    print("Available pending tasks:")
    print()
    pending = [t for t in data['tasks'] if t['status'] == 'pending']
    for t in pending:
        priority = t.get('priority', 'medium')
        effort = t.get('effort', '?')
        print(f"  {t['id']}: {t['goal']}")
        print(f"    Priority: {priority}, Effort: {effort}")
        print()
    print("Usage: /implement <task-id>")
    sys.exit(1)

# Find task
task = next((t for t in data['tasks'] if t['id'] == TASK_ID), None)
if not task:
    print(json.dumps({"error": f"Task {TASK_ID} not found in tasks.yml"}))
    sys.exit(1)

# Check dependencies
if 'depends_on' in task and task['depends_on']:
    for dep_id in task['depends_on']:
        dep = next((t for t in data['tasks'] if t['id'] == dep_id), None)
        if dep and dep['status'] != 'completed':
            print(json.dumps({"error": f"Dependency {dep_id} not completed (status: {dep['status']})"}))
            sys.exit(1)

# Build context
context = {
    "task": task,
    "documents": [{"reference": ref} for ref in task.get('docs', [])]
}

# Save to temporary file
with open('$TEMP_FILE', 'w') as f:
    json.dump(context, f, ensure_ascii=False, indent=2)

print("✅ Task context loaded successfully")
PYTHON

# Check if Python script failed
if [ $? -ne 0 ]; then
  exit 1
fi
```

## Create TodoWrite Task List

Parse task context and create implementation steps:

```bash
python3 << PYTHON
import json
import sys

with open('$TEMP_FILE', 'r') as f:
    context = json.load(f)

task = context['task']
docs = context.get('documents', [])

print(f"Task: {task['goal']}")
print(f"Priority: {task.get('priority', 'medium')}")
print(f"Type: {task.get('type', 'implementation')}")
print()

if docs:
    print(f"Document References ({len(docs)}):")
    for doc in docs:
        print(f"  - {doc['reference']}")
    print()

if 'acceptance_criteria' in task:
    print("Acceptance Criteria:")
    for i, criteria in enumerate(task['acceptance_criteria'], 1):
        print(f"  {i}. {criteria}")
    print()

if 'depends_on' in task and task['depends_on']:
    print("Dependencies:")
    for dep in task['depends_on']:
        print(f"  - {dep}")
    print()
PYTHON
```

Use TodoWrite to create implementation steps:
1. "Load task context and documents"
2. "Implement core functionality"
3. "Verify acceptance criteria"
4. "Update task status to completed"

## Inject Document Context

For each document reference in task.docs:

```bash
# Extract document references
DOC_REFS=$(python3 << PYTHON
import json
with open('$TEMP_FILE', 'r') as f:
    context = json.load(f)
for doc in context.get('documents', []):
    print(doc['reference'])
PYTHON
)

# For each document reference
for DOC_REF in $DOC_REFS; do
  # Parse "file.md#Section" format
  FILE_PATH=$(echo "$DOC_REF" | cut -d'#' -f1)
  SECTION=$(echo "$DOC_REF" | cut -d'#' -f2)
  
  echo "Loading: $DOC_REF"
  
  # Use Read tool to load the file
  # The Read tool call will be made by the LLM executing this command
  # Document content will be automatically available in context
done
```

## Implementation Phase

With full context loaded (task info + all referenced documents):

1. **Understand requirements**:
   - Task goal
   - Acceptance criteria
   - Referenced design documents
   - API specifications
   - Security requirements

2. **Implement solution**:
   - Follow patterns from referenced documents
   - Meet all acceptance criteria
   - Apply security best practices
   - Write clean, maintainable code

3. **Verify implementation**:
   - Check all acceptance criteria met
   - Run tests if applicable
   - Validate security requirements

## Update Task Status

After successful implementation:

```bash
# Update task status to completed
python3 << PYTHON
import yaml
from datetime import datetime

with open('tasks.yml', 'r') as f:
    data = yaml.safe_load(f)

for task in data['tasks']:
    if task['id'] == '$TASK_ID':
        task['status'] = 'completed'
        task['completed_at'] = datetime.utcnow().isoformat() + 'Z'
        break

data['project']['last_updated'] = datetime.utcnow().isoformat() + 'Z'

with open('tasks.yml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

print(f"✅ Task {task['id']} marked as completed")
PYTHON

# Update todo.md if it exists
if [ -f "todo.md" ]; then
  python3 << 'PYTHON'
import re
import sys
import datetime

task_id = '$TASK_ID'

try:
    # Read todo.md
    with open('todo.md', 'r') as f:
        lines = f.readlines()

    # Find and update #task-N line
    updated = False
    for i, line in enumerate(lines):
        if f'#{task_id}' in line and '- [ ]' in line:
            # 1. Replace checkbox
            updated_line = line.replace('- [ ]', '- [x]')

            # 2. Add Completed field after Created field
            completed_date = datetime.date.today().isoformat()

            if 'Created:' in updated_line:
                # Find position to insert Completed field
                if '#' in updated_line:
                    # Has tags: insert before first tag
                    parts = updated_line.split('#', 1)
                    updated_line = f"{parts[0].rstrip()} | Completed: {completed_date} #{parts[1]}"
                else:
                    # No tags: append at end
                    updated_line = updated_line.rstrip('\n') + f" | Completed: {completed_date}\n"

            lines[i] = updated_line
            updated = True
            break

    # Write back if updated
    if updated:
        with open('todo.md', 'w') as f:
            f.writelines(lines)
        print(f"✅ todo.mdも更新しました: #{task_id}")
    else:
        # Task not found in todo.md (not an error)
        pass

except Exception as e:
    # Log warning but don't fail
    print(f"⚠️  Warning: todo.md更新に失敗しました: {e}", file=sys.stderr)
    print(f"⚠️  次回 /todo sync で修正されます", file=sys.stderr)
    # Continue execution (don't exit)
PYTHON
fi
```

## Error Handling

**Note**: Most error handling (tasks.yml not found, task not found, dependencies not met) is now integrated into the unified Python script in the "Load Task Context" section above.

### Invalid Task ID Format

```bash
# Invalid task ID (detected by validate_task_id)
ERROR: Invalid task ID format: task-abc
Expected: task-N (e.g., task-1, task-42)
Example: /implement task-1

Resolution:
  - Use numeric task ID from tasks.yml
  - List available tasks: /implement (no arguments)
  - Verify task ID format: ^task-[0-9]+$
```

### Task Not Found

```bash
# Task ID not found in tasks.yml
ERROR: Task task-99 not found in tasks.yml

Resolution:
  - List available pending tasks: /implement
  - Check tasks.yml for correct task ID
  - Verify task hasn't been deleted or renamed
  - Example: /implement task-1
```

### Dependency Not Completed

```bash
# Required dependency not completed (detected by Python script)
ERROR: Dependency task-1 not completed (status: pending)

Resolution:
  - Complete dependency first: /implement task-1
  - Check dependency chain in tasks.yml:
    tasks:
      - id: task-2
        depends_on: [task-1]
  - Adjust task order if needed
  - Verify dependency status: status: completed
```

### Document Reference Not Found

```bash
# Document file doesn't exist
WARNING: Document not found: docs/design.md
Continuing without this reference...

Resolution:
  - Verify document path in tasks.yml:
    docs: ["docs/design.md#Section"]
  - Create missing document if needed
  - Update docs array to remove invalid reference
  - Implementation continues without the document
```

### tasks.yml Parsing Failed

```bash
# YAML syntax error
ERROR: Failed to load tasks.yml: mapping values are not allowed here
  in "tasks.yml", line 12, column 18

Resolution:
  - Check YAML syntax at line 12
  - Validate YAML structure:
    - Proper indentation (2 spaces)
    - No tabs
    - Correct array/object syntax
  - Use YAML validator: yamllint tasks.yml
  - Example of valid structure:
    tasks:
      - id: task-1
        goal: "Description"
        status: pending
```

### PyYAML Not Installed

```bash
# Python YAML library missing
ERROR: Failed to load tasks.yml: No module named 'yaml'

Resolution:
  - Install PyYAML:
    pip3 install PyYAML
  - Verify installation:
    python3 -c "import yaml; print(yaml.__version__)"
  - Alternative: Use conda/venv if project requires
```

### Security Guidelines

**Error message safety**:
- Never expose absolute paths in error messages (use relative paths from project root)
- Never expose stack traces or internal details
- Report only user-actionable information
- Sanitize all user input before displaying

**Exit codes**:
- 0: Success - Task implemented successfully, status updated
- 1: User error - Invalid task ID, task not found
- 2: Security error - Path traversal, absolute path detected
- 3: System error - tasks.yml parsing failed, Python unavailable
- 4: Dependency error - Required task not completed

## Examples

### Implement task-1
```
/implement task-1
```

Output:
```
Task: Implement user authentication system
Priority: high
Type: implementation

Document References (3):
  - docs/design.md#Authentication
  - docs/api-spec.md#Auth-Endpoints
  - docs/security.md#JWT-Implementation

Acceptance Criteria:
  1. User can login with email/password
  2. JWT token issued on successful login
  3. Token refresh endpoint working
  4. Logout invalidates token
  5. Protected routes return 401 for invalid tokens

[Loads all 3 document sections automatically]
[Implements with full context]
✅ Task task-1 marked as completed
```

### List pending tasks
```
/implement
```

Output:
```
Available pending tasks:

  task-1: Implement user authentication system
    Priority: high, Effort: 8h

  task-2: Write unit tests for authentication
    Priority: high, Effort: 4h

  task-3: Refactor user service
    Priority: medium, Effort: 6h

Usage: /implement <task-id>
```

### Dependency chain handling
```
/implement task-2
```

Output:
```
ERROR: Dependency task-1 not completed (status: pending)

Resolution:
  - Complete dependency first: /implement task-1
  - Check dependency chain in tasks.yml:
    tasks:
      - id: task-2
        goal: "Write unit tests for authentication"
        depends_on: [task-1]
        status: pending
  - Adjust task order if needed
  - Verify dependency status: status: completed

# After completing task-1:
/implement task-2

Output:
✅ Task context loaded successfully
Task: Write unit tests for authentication
Priority: high
Type: test
Dependencies: task-1 (completed)

Document References (1):
  - docs/testing.md#Unit-Testing-Patterns

[Implements unit tests]
✅ Task task-2 marked as completed
✅ todo.mdも更新しました: #task-2
```

### Document reference with section extraction
```
/implement task-3
```

tasks.yml configuration:
```yaml
- id: task-3
  goal: "Implement payment processing"
  docs:
    - "docs/design.md#Payment-Architecture"
    - "docs/api-spec.md#Payment-Endpoints"
    - "docs/security.md#PCI-Compliance"
  acceptance_criteria:
    - "Credit card data encrypted at rest"
    - "Payment API returns transaction ID"
    - "Failed payments logged securely"
```

Output:
```
✅ Task context loaded successfully
Task: Implement payment processing
Priority: critical
Type: implementation

Document References (3):
  - docs/design.md#Payment-Architecture
  - docs/api-spec.md#Payment-Endpoints
  - docs/security.md#PCI-Compliance

Loading: docs/design.md#Payment-Architecture
Loading: docs/api-spec.md#Payment-Endpoints
Loading: docs/security.md#PCI-Compliance

Acceptance Criteria:
  1. Credit card data encrypted at rest
  2. Payment API returns transaction ID
  3. Failed payments logged securely

[All 3 document sections loaded automatically]
[Implements payment processing with full context]
✅ Task task-3 marked as completed

Next steps:
  1. Run /validate --layers=all
  2. Create commit with /commit
  3. Continue with /implement task-4
```

### Error handling demonstration
```
/implement task-abc
```

Output:
```
ERROR: Invalid task ID format: task-abc
Expected: task-N (e.g., task-1, task-42)
Example: /implement task-1

Resolution:
  - Use numeric task ID from tasks.yml
  - List available tasks: /implement (no arguments)
  - Verify task ID format: ^task-[0-9]+$
```

```
/implement task-999
```

Output:
```
ERROR: Task task-999 not found in tasks.yml

Resolution:
  - List available pending tasks: /implement
  - Check tasks.yml for correct task ID
  - Verify task hasn't been deleted or renamed
  - Example: /implement task-1
```

### Document reference not found (warning mode)
```
/implement task-4
```

tasks.yml configuration:
```yaml
- id: task-4
  goal: "Update user profile UI"
  docs:
    - "docs/design.md#Profile-UI"  # This file doesn't exist
    - "docs/components.md#ProfileForm"  # This exists
```

Output:
```
✅ Task context loaded successfully
Task: Update user profile UI

Document References (2):
  - docs/design.md#Profile-UI
  - docs/components.md#ProfileForm

Loading: docs/design.md#Profile-UI
WARNING: Document not found: docs/design.md
Continuing without this reference...

Loading: docs/components.md#ProfileForm
[Loads ProfileForm component documentation]

[Implementation continues with available context]
✅ Task task-4 marked as completed

Note: Implementation completed despite missing docs/design.md
Recommendation: Update tasks.yml to remove invalid reference
```

## External References

**Related workflows**:
- `/validate --layers=all` - Multi-layer quality gate validation after implementation
- `/commit` - Conventional Commits creation after task completion
- `/ship` - Create PR/MR with task implementation
- `/todo` - Task management integration (automatic todo.md sync)

**Task management**:
- tasks.yml schema: See `~/.claude/schemas/tasks-schema.yml` for valid structure
- Document-driven workflow: See CLAUDE.md "基本開発フロー" section
- Acceptance criteria patterns: See `~/.claude/templates/acceptance-criteria.yml`

**Document reference formats**:
- Markdown sections: `docs/design.md#Section-Name`
- API specifications: `docs/api.md#Endpoint-Name`
- Security requirements: `docs/security.md#Requirement-Name`
- Multiple references: `["docs/a.md#S1", "docs/b.md#S2"]`

**Python dependencies**:
- PyYAML 5.x+: YAML safe loading with injection prevention
- Installation: `pip3 install PyYAML`
- Verification: `python3 -c "import yaml; print(yaml.__version__)"`

**Validation patterns**:
- Input validation: See `~/.claude/validation/input-patterns.sh`
- Security checks: See `~/.claude/validation/security-patterns.json`
- Path traversal prevention: Whitelist validation approach

**Agent delegation**:
- Explore agent: Task(subagent_type=Explore) for codebase discovery
- Implementation agents: fullstack-developer, backend-developer, frontend-developer
- Review agents: code-reviewer (post-implementation quality check)

```


## Exit Code System

```bash
# 0: Success - Task implemented successfully, status updated
# 1: User error - Invalid task ID, task not found
# 2: Security error - (Minimal risk - YAML validation only)
# 3: System error - tasks.yml parsing failed, Python unavailable
# 4: Unrecoverable error - Dependency not met, critical failure
```

## Output Format

**Success example**:
```
✓ Task implementation completed
✓ Task: task-1 (Implement user authentication system)
✓ Documents loaded: 3 references
✓ Acceptance criteria: All 5 met
✓ Status updated: pending → completed

Implementation Summary:
  - Files modified: 8
  - Tests added: 12
  - Documentation updated: README.md, API-SPEC.md

Next steps:
  1. Run /validate --layers=all
  2. Create commit with /commit
  3. Continue with /implement task-2
```

**Error example**:
```
ERROR: Dependency not completed
File: implement.md:check_dependencies

Reason: Required dependency task not yet completed
Got: task-1 depends on task-0 (status: pending)

Suggestions:
1. Complete task-0 first: /implement task-0
2. Check task dependencies in tasks.yml
3. Adjust task order if needed
```

## Configuration

Optional: Create .claude/implement.json for project-specific settings:

```json
{
  "auto_validate": true,
  "auto_commit": false,
  "document_base_path": "docs/",
  "require_all_criteria": true
}
```
