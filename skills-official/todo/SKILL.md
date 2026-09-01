---
name: todo
description: Personal task list management via todo.md. Add, complete, remove, and list tasks with priorities, due dates, and tags. Use when user wants to manage their todo list, add tasks, mark tasks as done, or track personal action items.
argument-hint: "add \"<text>\" [--priority=] [--tags=] [--due=] | list [--filter=] [--sort=] | complete <N> | uncomplete <N> | remove <N> | next | sync"
allowed-tools: Read Write Edit Grep AskUserQuestion Bash(python3 *)
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

## Execution Flow

1. Parse $ARGUMENTS into action, description, and options — see Argument Parsing
2. Validate every user-supplied value — see Input Validation
3. Locate todo.md in the project root; if absent, create it with the Write tool and an empty task list
4. If todo.md exists and exceeds 1MB, stop and report the size limit — see Error Handling
5. Execute the action — see Actions
6. Report the result to the user in the format shown in Examples

**Special cases**:
- $ARGUMENTS empty: enter interactive mode — see Interactive Mode
- Any validation failure: stop before step 3; never write a partially validated task

### Dependencies

No separate probe step: the first `python3` call of the flow reports a missing dependency itself, and every action that touches user input makes one before writing anything.

| Failure text from the call | Missing |
|---|---|
| `command not found: python3` | python3 |
| `can't open file '.../todo_validation.py'` | the skill's validation module |
| `can't open file '.../todo_sync.py'` | sync script (sync action only) |
| `can't open file '.../todo_next.py'` | next script (next action only) |

Treat any of these as a stop-and-report dependency failure — see Error Handling. Report the module name only, never the resolved path.

## Argument Parsing

Parse $ARGUMENTS yourself; do not pass it to a shell command. Extract:

| Element | Source | Notes |
|---|---|---|
| Action | first token | see the alias table below |
| Description | quoted string | `add` only |
| Task number | integer | `complete`, `uncomplete`, `remove`; 1-based list position |
| Options | `--key=value` | `--priority`, `--tags`, `--due`, `--filter`, `--sort` |

**Actions and aliases** (an unlisted first token is an invalid-action error):

| Action | Aliases |
|---|---|
| add | — |
| complete | done |
| uncomplete | — |
| remove | delete |
| list | — |
| next | — |
| sync | — |
| interactive | (also entered when $ARGUMENTS is empty) |

Options always use `--key=value`. Space-separated forms (`--tags security urgent`) are not supported: reject them with the usage line for that action.

## Input Validation

**MUST**: every user-supplied value reaches `todo_validation.py` before it is written anywhere. Never interpolate `$ARGUMENTS`, a description, a tag, or a task number into a shell command — argument substitution applies inside fenced code blocks, so a description containing a quote would break out of the command and run as shell code.

The only supported channel is a **quoted heredoc** (`<<'TODO_JSON'`), which suppresses all shell expansion:

```bash
python3 "${CLAUDE_SKILL_DIR}/todo_validation.py" - <<'TODO_JSON'
{"action":"add","description":"Fix authentication bug","priority":"high","tags":"security,urgent,api","due":"tomorrow"}
TODO_JSON
```

Rules for building the request:
- Emit the JSON as a **single line** with the description JSON-escaped, so no body line can collide with the `TODO_JSON` delimiter
- Use the delimiter `TODO_JSON` verbatim, always single-quoted
- Malformed JSON exits non-zero with an error — treat that as a validation failure, never as a reason to fall back to shell string building

Request schema by action:

| Action field | Other fields |
|---|---|
| `add` | `description` (required), `priority`, `tags`, `due` |
| `complete` / `uncomplete` / `remove` | `index` (required) |
| `filter` | `priority`, `tag`, `sort` (for `list`) |

On success the script prints one JSON object to stdout; use its values, not the raw input. For `add`, `task_line` is the finished todo.md line — write it verbatim.

Validation rules are defined once, in `todo_validation.py`:

| Value | Rule | Function |
|---|---|---|
| Description | NFKC normalized, control chars collapsed, max 4KB / 1000 chars, `\|` rejected | `validate_description()` |
| Priority | `critical` \| `high` \| `medium` \| `low`, default `medium` | `validate_priority()` |
| Tags | comma-separated canonical; alphanumeric, underscore, hyphen; max 32 chars each | `parse_tags()` / `validate_tags()` |
| Due date | `YYYY-MM-DD`, `today`, `tomorrow`, `next week`, `in N days` | `validate_due()` |
| Task number | positive integer (todo.md list position) | `validate_task_index()` |
| tasks.yml task ID | `task-N` — used by sync/next only, never by complete/remove | `validate_task_id()` |
| File path | inside project root, `.git` denied | `validate_path()` |

## Tool Usage

**Read / Write / Edit**: todo.md operations. Write creates the file; Edit applies every subsequent change.

**Grep**: locate a task line by text before editing, and count matches to detect duplicates.

**Bash**: only `python3` invocations (validation and the sync/next scripts). No shell string building, no `date` — dates come from `todo_validation.py`.

**AskUserQuestion**: interactive mode, and the /implement confirmation in the `next` action.

**Note**: TodoWrite/TodoRead are Claude Code's built-in session task tools — they manage in-session checklists, NOT todo.md. Do not use them for persistent todo.md operations.

## File Format

todo.md uses a markdown checklist with inline metadata:

```markdown
- [ ] Fix auth bug | Priority: high | Due: 2026-09-02 | Created: 2026-09-01 #security #urgent
- [x] Update README | Priority: medium | Created: 2026-08-30 | Completed: 2026-09-01 #docs
```

Field order is fixed: description, `Priority`, `Due`, `Created`, `Completed`, tags.

| Field | Format | Required |
|---|---|---|
| Priority | critical/high/medium/low | yes |
| Due | YYYY-MM-DD | optional |
| Created | YYYY-MM-DD (auto) | yes |
| Completed | YYYY-MM-DD (auto) | completed tasks only |
| Tags | `#tag1 #tag2` (trailing) | optional |

## Actions

Task numbers are 1-based positions in the rendered `list` output, counting task lines only.

**add "description" [options]**
1. Validate via the heredoc request (`action: "add"`)
2. Append the returned `task_line` to todo.md with Edit
3. Report the added line

**complete N | done N**
1. Validate via the heredoc request (`action: "complete"`) to get `index` and today's date
2. Read todo.md, resolve position `index` to a task line; if it does not exist, stop and report the valid range
3. Edit that line: `- [ ]` → `- [x]`, and insert ` | Completed: <date>` directly after the `Created` field
4. Report the updated line

**uncomplete N**
1. Validate via the heredoc request (`action: "uncomplete"`)
2. Resolve position `index` as above
3. Edit that line: `- [x]` → `- [ ]`, and **remove the `Completed` field** including its leading ` | `
4. Report the updated line

**remove N | delete N**
1. Validate via the heredoc request (`action: "remove"`)
2. Resolve position `index` as above
3. Delete the whole line with Edit
4. Report the removed line so the user can re-add it if the deletion was unintended

**list [options]**
1. Validate filters via the heredoc request (`action: "filter"`) when `--filter` or `--sort` is present
2. Read todo.md
3. Keep lines matching `- [ ]` or `- [x]`; number them from 1 **before** filtering, so numbers stay stable and usable with `complete`
4. Apply the filter:
   - `--filter=priority:high` → line contains `Priority: high`
   - `--filter=tag:security` → line contains the tag token `#security` (exact token; `#security` must not match `#securityaudit`)
   - `--filter=context:X` → alias for `--filter=tag:X` (backward compat)
5. Apply `--sort`:
   - `--sort=due` → ascending by `Due`; tasks without a due date last
   - `--sort=priority` → critical, high, medium, low
   - omitted → file order
6. Render as shown in Examples

**next**
1. Run `python3 "$HOME/.claude/utils/todo_next.py"`
2. If the output contains `NEXT_TASK_ID` (a tasks.yml task), use AskUserQuestion to confirm running `/implement task-N`
3. If confirmed, invoke `/implement task-N` via the Skill tool
4. Otherwise display the lightweight task to the user

**sync**
1. Run `python3 "$HOME/.claude/utils/todo_sync.py"`
2. Report how many tasks were imported, or that tasks.yml was not found
3. Idempotent: safe to re-run; never modifies existing tasks

Both scripts own their own file parsing, YAML handling, and sanitization — see External Scripts.

## Interactive Mode

Entered when $ARGUMENTS is empty or the action is `interactive`.

1. AskUserQuestion — action: `add` / `list` / `complete`
2. For `add`: ask for the description, then priority (`critical`/`high`/`medium`/`low`), then tags (free-form; comma or space separated, both accepted by `parse_tags()`)
3. For `complete`: render `list` first so the user picks a valid number
4. Continue into the chosen action's flow above

## External Scripts

**`${CLAUDE_SKILL_DIR}/todo_validation.py`** — all input validation and the todo.md line renderer. Functions are listed in the Input Validation table. Also exposes `safe_error_message()`, which every error path uses.

**`$HOME/.claude/utils/todo_sync.py`** (sync) — loads and validates tasks.yml, extracts pending tasks, reads the last 100 lines of todo.md for the max task ID, sanitizes goal text, appends new tasks. Prevents command injection with `shlex.quote` and validates task IDs against `task-\d+`.

**`$HOME/.claude/utils/todo_next.py`** (next) — file parsing and task selection. Output:
- tasks.yml task: `NEXT_TASK_ID:task-N / PRIORITY:X / EFFORT:Y / DESCRIPTION:...`
- lightweight task: `Next task (lightweight): ...`

Do not reimplement these responsibilities inline.

## Error Handling

Every failure stops the flow and reports to the user. There is no script for the LLM to `exit` from: a `exit` inside a Bash call ends that one command only, so failure is expressed as **stop and report**, never as a process exit code.

| Condition | Behaviour |
|---|---|
| Dependency check did not print `READY` | Stop. Report which dependency is missing and that `/todo` cannot run without it |
| Invalid action | Stop. Report the token and list the valid actions |
| Validation failed (non-zero from todo_validation.py) | Stop. Show the script's stderr line verbatim — it is already sanitized — plus the usage line for that action |
| Task number out of range | Stop. Report the number and the valid range (`1-N`), and suggest `/todo list` |
| todo.md not found | Not an error: create it with Write, then continue |
| todo.md exceeds 1MB | Stop. Report the size limit and suggest archiving completed tasks |
| todo.md line is malformed | Skip the line for numbering, and report it as `todo.md:<line>: unparseable task line` so the user can fix it |
| No write permission | Stop. Report the permission failure and suggest checking directory permissions |

Script exit statuses (defined in `todo_validation.py`, not redeclared here) map to behaviour as:

| Status | Meaning | Report as |
|---|---|---|
| 0 | success | continue |
| 1 | user error — bad argument or value | the stderr line + usage |
| 2 | security error — path traversal or denied target | "input rejected for security reasons"; do not echo the offending value |
| 4 | unrecoverable | "internal validation error"; suggest re-running with simpler input |

**Security**: report only user-actionable information. `safe_error_message()` already strips absolute paths and keeps the first line of any traceback — pass script stderr through unchanged rather than re-wording it, and never add the resolved path back in.

## Examples

Normal cases:

```
/todo add "Fix authentication bug" --priority=high --tags=security,urgent,api --due=tomorrow
→ Added:
  - [ ] Fix authentication bug | Priority: high | Due: 2026-09-02 | Created: 2026-09-01 #security #urgent #api

/todo list
→ 1. [ ] Fix authentication bug | Priority: high | Due: 2026-09-02 #security #urgent #api
  2. [ ] Investigate library X   | Priority: medium
  3. [x] Update README           | Priority: medium | Completed: 2026-09-01 #docs
  3 tasks (2 open, 1 done)

/todo list --filter=priority:medium
→ 2. [ ] Investigate library X   | Priority: medium
  3. [x] Update README           | Priority: medium | Completed: 2026-09-01 #docs
  2 of 3 tasks match
  (numbers are original list positions, so /todo complete 2 still targets the right task)

/todo complete 1
→ Completed:
  - [x] Fix authentication bug | Priority: high | Due: 2026-09-02 | Created: 2026-09-01 | Completed: 2026-09-01 #security #urgent #api

/todo uncomplete 1
→ Reopened (Completed field removed):
  - [ ] Fix authentication bug | Priority: high | Due: 2026-09-02 | Created: 2026-09-01 #security #urgent #api

/todo remove 2
→ Removed:
  - [ ] Investigate library X | Priority: medium | Created: 2026-08-30

/todo next
→ NEXT_TASK_ID:task-7 / PRIORITY:high / EFFORT:M / DESCRIPTION:Add rate limiting to the login endpoint
  → AskUserQuestion: run /implement task-7 now?

/todo sync
→ Imported 3 pending tasks from tasks.yml (Created: 2026-09-01, tags from type field)
  Existing tasks unchanged.

/todo
→ AskUserQuestion: which action? (add / list / complete)
```

Error cases:

```
/todo complete abc
→ ERROR: Invalid task number: abc (expected: positive integer)
  Usage: /todo complete <N>   (N is a 1-based position from /todo list)

/todo complete 99
→ ERROR: Task 99 does not exist (valid range: 1-3)
  Run /todo list to see current task numbers.

/todo add "x" --priority=urgent
→ ERROR: Invalid priority: urgent (allowed: critical, high, medium, low)

/todo add "Fix bug" --tags=sec;rm -rf
→ ERROR: Invalid tag: sec;rm (allowed: alphanumeric, underscore, hyphen only)

/todo add "Fix a | b bug"
→ ERROR: Description cannot contain "|" (reserved as the field separator)

/todo add "Review" --due=2026-02-30
→ ERROR: Invalid due date: 2026-02-30 (not a real calendar date)

/todo deploy
→ ERROR: Invalid action: deploy
  Valid actions: add, complete (done), uncomplete, remove (delete), list, next, sync

/todo sync   # with todo_sync.py missing
→ ERROR: sync requires todo_sync.py, which was not found in the utils directory.
  /todo sync cannot run until it is restored.
```
