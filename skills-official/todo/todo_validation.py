#!/usr/bin/env python3
"""
Input validation utilities for the /todo skill.

Security-focused validation for file paths, user input, task references,
priorities, tags, and due dates.

CLI — the only supported way to hand user-supplied text to this module:

    python3 todo_validation.py <input-json-file>|-

Pass "-" to read the request from stdin. The caller MUST supply it through a
quoted heredoc (<<'TODO_JSON'), which suppresses every form of shell
expansion, so user text is never parsed by a shell. On success the validated
result is printed to stdout as a single JSON object and the exit status is 0.
On failure a single-line "Error in ..." message is printed to stderr and the
exit status is one of the EXIT_* values below.
"""

from __future__ import annotations

import datetime
import json
import os
import re
import sys
import unicodedata
from typing import Optional

# Exit statuses returned by this script. The calling skill maps these to
# user-facing behaviour; it does not re-declare them.
EXIT_SUCCESS = 0
EXIT_USER_ERROR = 1
EXIT_SECURITY_ERROR = 2
EXIT_UNRECOVERABLE = 4

PRIORITIES = ("critical", "high", "medium", "low")
DEFAULT_PRIORITY = "medium"
TAG_PATTERN = re.compile(r"^[a-zA-Z0-9_-]+$")
TAG_MAX_CHARS = 32
ISO_DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")
RELATIVE_DAYS_PATTERN = re.compile(r"^in\s+(\d{1,4})\s+days?$")

# Raised for inputs that look like an attack rather than a typo.
class SecurityError(ValueError):
    """Input rejected for security reasons (path traversal, denied target)."""


def validate_path(path: str) -> str:
    """
    Validate a file path is inside the current project and not in .git.

    Args:
        path: File path to validate

    Returns:
        Validated absolute path

    Raises:
        SecurityError: If the path escapes the project or targets .git
    """
    if ".." in path:
        raise SecurityError("Path cannot contain ..")

    real_path = os.path.realpath(os.path.abspath(path))
    root = os.path.realpath(os.getcwd())

    # Compare path components, not string prefixes: a plain startswith()
    # accepts /project-other when the root is /project.
    if real_path != root and not real_path.startswith(root + os.sep):
        raise SecurityError("Path outside project")

    parts = real_path.split(os.sep)
    if ".git" in parts:
        raise SecurityError(".git access denied")

    return real_path


def sanitize_input(text: str, max_bytes: int = 4096, max_chars: int = 1000) -> str:
    """
    Normalize user input and enforce length limits.

    The return value is the sanitized text and MUST be used in place of the
    raw input; discarding it silently skips Unicode normalization.

    Args:
        text: User input text
        max_bytes: Maximum size in bytes (default: 4KB)
        max_chars: Maximum length in characters (default: 1000)

    Returns:
        Sanitized text (NFKC normalized, control characters removed)

    Raises:
        ValueError: If the input is empty or exceeds a limit
    """
    normalized = unicodedata.normalize("NFKC", text)

    # Replace control characters with a space rather than deleting them: a
    # bare deletion would join "line1\nline2" into "line1line2". Then collapse
    # whitespace runs so the result is a single clean line.
    normalized = "".join(
        " " if unicodedata.category(ch).startswith("C") else ch for ch in normalized
    )
    normalized = re.sub(r"\s+", " ", normalized).strip()

    if not normalized:
        raise ValueError("Input is empty")

    if len(normalized.encode("utf-8")) > max_bytes:
        raise ValueError(f"Input exceeds {max_bytes} byte limit")

    if len(normalized) > max_chars:
        raise ValueError(f"Input exceeds {max_chars} character limit")

    return normalized


def validate_description(text: str) -> str:
    """
    Sanitize a task description and reject characters that corrupt the
    todo.md line format.

    Args:
        text: Raw description

    Returns:
        Sanitized description safe to render into a task line

    Raises:
        ValueError: If the description is empty, too long, or contains "|"
    """
    description = sanitize_input(text)

    # "|" is the field separator: allowing it would make the stored line
    # re-parse into the wrong fields.
    if "|" in description:
        raise ValueError(
            'Description cannot contain "|" (reserved as the field separator)'
        )

    return description


def validate_task_id(task_id: str) -> str:
    """
    Validate a tasks.yml task ID (task-N).

    This is the identifier used by the sync and next actions. It is NOT the
    todo.md list position; use validate_task_index() for that.

    Args:
        task_id: Task ID string

    Returns:
        Validated task ID

    Raises:
        ValueError: If the task ID is malformed
    """
    if not re.match(r"^task-\d+$", task_id):
        raise ValueError(f"Invalid task ID format: {task_id} (expected: task-N)")

    return task_id


def validate_task_index(value: object) -> int:
    """
    Validate a todo.md list position (1-based) as used by complete,
    uncomplete, and remove.

    Args:
        value: Task number as int or string

    Returns:
        Validated positive integer

    Raises:
        ValueError: If the value is not a positive integer
    """
    text = str(value).strip()

    if not re.match(r"^[0-9]+$", text) or int(text) < 1:
        raise ValueError(f"Invalid task number: {text} (expected: positive integer)")

    return int(text)


def validate_priority(priority: Optional[str]) -> str:
    """
    Validate a priority value.

    Args:
        priority: Priority string, or None for the default

    Returns:
        Validated priority

    Raises:
        ValueError: If the priority is not an allowed value
    """
    if priority is None or priority == "":
        return DEFAULT_PRIORITY

    normalized = str(priority).strip().lower()

    if normalized not in PRIORITIES:
        raise ValueError(
            f"Invalid priority: {priority} (allowed: {', '.join(PRIORITIES)})"
        )

    return normalized


def parse_tags(tags: Optional[str]) -> list:
    """
    Parse and validate tags.

    Comma-separated is the canonical form (--tags=security,urgent,api).
    Whitespace around and between tags is tolerated so that free-form input
    from AskUserQuestion ("security urgent api") is also accepted.

    Args:
        tags: Tag string, or None

    Returns:
        List of validated tags, duplicates removed, order preserved

    Raises:
        ValueError: If a tag has invalid characters or is too long
    """
    if not tags:
        return []

    raw_tags = [tag for tag in re.split(r"[,\s]+", str(tags).strip()) if tag]

    validated: list = []
    for tag in raw_tags:
        cleaned = tag.lstrip("#")

        if not TAG_PATTERN.match(cleaned):
            raise ValueError(
                f"Invalid tag: {tag} (allowed: alphanumeric, underscore, hyphen only)"
            )

        if len(cleaned) > TAG_MAX_CHARS:
            raise ValueError(
                f"Tag too long: {cleaned} "
                f"(max: {TAG_MAX_CHARS} characters, got: {len(cleaned)})"
            )

        if cleaned not in validated:
            validated.append(cleaned)

    return validated


def validate_tags(tags: Optional[str]) -> str:
    """
    Validate tags and return them in canonical comma-separated form.

    Args:
        tags: Tag string, or None

    Returns:
        Comma-separated tag string ("" when there are no tags)

    Raises:
        ValueError: If a tag has invalid characters or is too long
    """
    return ",".join(parse_tags(tags))


def validate_due(due: Optional[str], today: Optional[datetime.date] = None) -> Optional[str]:
    """
    Parse a due date into YYYY-MM-DD.

    Accepts: YYYY-MM-DD, today, tomorrow, next week, "in N days".
    Implemented here rather than with the date command so that behaviour does
    not depend on BSD vs GNU date.

    Args:
        due: Due date expression, or None
        today: Reference date (defaults to the current local date)

    Returns:
        ISO date string, or None when no due date was given

    Raises:
        ValueError: If the expression cannot be parsed or is not a real date
    """
    if not due:
        return None

    base = today or datetime.date.today()
    text = str(due).strip().lower()

    if ISO_DATE_PATTERN.match(text):
        try:
            return datetime.date.fromisoformat(text).isoformat()
        except ValueError:
            raise ValueError(f"Invalid due date: {due} (not a real calendar date)")

    if text == "today":
        return base.isoformat()

    if text == "tomorrow":
        return (base + datetime.timedelta(days=1)).isoformat()

    if text in ("next week", "nextweek"):
        return (base + datetime.timedelta(days=7)).isoformat()

    relative = RELATIVE_DAYS_PATTERN.match(text)
    if relative:
        return (base + datetime.timedelta(days=int(relative.group(1)))).isoformat()

    raise ValueError(
        f"Invalid due date: {due} "
        "(expected: YYYY-MM-DD, today, tomorrow, next week, or 'in N days')"
    )


def build_task_line(
    description: str,
    priority: str,
    created: str,
    due: Optional[str] = None,
    tags: Optional[list] = None,
    completed: Optional[str] = None,
) -> str:
    """
    Render a validated task as a todo.md line.

    Field order is fixed: description, Priority, Due, Created, Completed, tags.

    Args:
        description: Sanitized description
        priority: Validated priority
        created: ISO creation date
        due: ISO due date, or None
        tags: Validated tag list, or None
        completed: ISO completion date, or None

    Returns:
        A single todo.md task line
    """
    box = "[x]" if completed else "[ ]"
    line = f"- {box} {description} | Priority: {priority}"

    if due:
        line += f" | Due: {due}"

    line += f" | Created: {created}"

    if completed:
        line += f" | Completed: {completed}"

    if tags:
        line += " " + " ".join(f"#{tag}" for tag in tags)

    return line


def safe_error_message(error: Exception, context: str) -> str:
    """
    Build a user-safe error message with no absolute paths or stack traces.

    Args:
        error: Exception object
        context: Context description (e.g. "reading todo.md")

    Returns:
        Single-line sanitized error message
    """
    msg = str(error)

    msg = msg.replace(os.path.realpath(os.getcwd()), "<project>")
    msg = msg.replace(os.getcwd(), "<project>")
    # Use replacement functions: a literal backslash in a replacement string
    # is an escape sequence for re.sub and raises on a trailing backslash.
    msg = re.sub(r"/Users/[^/]+/", lambda _: "<home>/", msg)
    msg = re.sub(r"/home/[^/]+/", lambda _: "<home>/", msg)
    msg = re.sub(r"C:\\Users\\[^\\]+\\", lambda _: "<home>\\", msg)

    # Keep the first line only, so tracebacks never reach the user.
    msg = msg.split("\n")[0]

    return f"Error in {context}: {msg}"


def _handle_add(request: dict, today: datetime.date) -> dict:
    description = validate_description(str(request.get("description", "")))
    priority = validate_priority(request.get("priority"))
    tags = parse_tags(request.get("tags"))
    due = validate_due(request.get("due"), today=today)
    created = today.isoformat()

    return {
        "ok": True,
        "action": "add",
        "description": description,
        "priority": priority,
        "tags": tags,
        "due": due,
        "created": created,
        "task_line": build_task_line(description, priority, created, due, tags),
    }


def _handle_index(request: dict, today: datetime.date) -> dict:
    index = validate_task_index(request.get("index"))

    return {
        "ok": True,
        "action": request.get("action"),
        "index": index,
        "completed": today.isoformat(),
    }


def _handle_filter(request: dict, _today: datetime.date) -> dict:
    priority = request.get("priority")
    tag = request.get("tag")
    sort = request.get("sort")

    if sort not in (None, "", "due", "priority"):
        raise ValueError(f"Invalid sort key: {sort} (allowed: due, priority)")

    tags = parse_tags(tag)

    return {
        "ok": True,
        "action": "filter",
        "priority": validate_priority(priority) if priority else None,
        "tag": tags[0] if tags else None,
        "sort": sort or None,
    }


_HANDLERS = {
    "add": _handle_add,
    "complete": _handle_index,
    "uncomplete": _handle_index,
    "remove": _handle_index,
    "filter": _handle_filter,
}


def _read_request(argv: list) -> dict:
    if len(argv) != 2:
        raise ValueError("usage: todo_validation.py <input-json-file>|-")

    if argv[1] == "-":
        data = json.load(sys.stdin)
    else:
        with open(argv[1], "r", encoding="utf-8") as handle:
            data = json.load(handle)

    if not isinstance(data, dict):
        raise ValueError("Input JSON must be an object")

    return data


def main(argv: Optional[list] = None) -> int:
    argv = list(sys.argv if argv is None else argv)

    try:
        request = _read_request(argv)
        action = str(request.get("action", "")).strip()

        if action not in _HANDLERS:
            raise ValueError(
                f"Unsupported action: {action or '(missing)'} "
                f"(allowed: {', '.join(sorted(_HANDLERS))})"
            )

        today_override = request.get("today")
        today = (
            datetime.date.fromisoformat(str(today_override))
            if today_override
            else datetime.date.today()
        )

        result = _HANDLERS[action](request, today)
        print(json.dumps(result, ensure_ascii=False))
        return EXIT_SUCCESS

    except SecurityError as error:
        print(safe_error_message(error, "input validation"), file=sys.stderr)
        return EXIT_SECURITY_ERROR
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(safe_error_message(error, "input validation"), file=sys.stderr)
        return EXIT_USER_ERROR
    except Exception as error:  # noqa: BLE001 - last resort, message is sanitized
        print(safe_error_message(error, "input validation"), file=sys.stderr)
        return EXIT_UNRECOVERABLE


if __name__ == "__main__":
    sys.exit(main())
