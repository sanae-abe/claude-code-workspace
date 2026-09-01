"""
tasks_updater.py - Append new tasks to tasks.yml from plan-review skill.

Usage:
    python3 tasks_updater.py <tasks_json_file>

Input JSON format:
    [
      {
        "goal": "Implement login endpoint",
        "priority": "high",
        "effort": "4h",
        "acceptance_criteria": ["criterion 1", "criterion 2"]
      }
    ]
"""

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml


def sanitize_yaml_string(s: str) -> str:
    """Sanitize string for safe YAML insertion."""
    if re.search(r'!!|&|\*|^[>|]|[\x00-\x1f\x7f]', s):
        raise ValueError(f"Invalid characters in YAML string: {s!r}")
    return s


def load_or_init_tasks_yml(path: Path) -> dict:
    if not path.exists():
        return {"project": {"name": "Project Tasks", "last_updated": ""}, "tasks": []}
    with path.open("r") as f:
        data = yaml.safe_load(f)
    if data is None:
        return {"project": {"name": "Project Tasks", "last_updated": ""}, "tasks": []}
    return data


def next_task_id(tasks: list) -> int:
    existing = [
        int(t["id"].split("-")[1])
        for t in tasks
        if isinstance(t.get("id"), str) and t["id"].startswith("task-")
    ]
    return max(existing, default=0) + 1


def append_tasks(new_tasks: list, tasks_yml_path: Path = Path("tasks.yml")) -> int:
    data = load_or_init_tasks_yml(tasks_yml_path)
    tasks = data.get("tasks", [])

    for task in new_tasks:
        priority = task.get("priority", "medium")
        if priority not in {"high", "medium", "low"}:
            raise ValueError(f"Invalid priority: {priority!r}. Must be high/medium/low")

        entry = {
            "id": f"task-{next_task_id(tasks)}",
            "goal": sanitize_yaml_string(task["goal"]),
            "status": "pending",
            "priority": priority,
            "effort": sanitize_yaml_string(task.get("effort", "")),
            "type": "implementation",
            "acceptance_criteria": [
                sanitize_yaml_string(c) for c in task.get("acceptance_criteria", [])
            ],
        }
        tasks.append(entry)

    data["tasks"] = tasks
    data.setdefault("project", {})["last_updated"] = (
        datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    )

    with tasks_yml_path.open("w") as f:
        yaml.safe_dump(data, f, default_flow_style=False, allow_unicode=True)

    return len(new_tasks)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python3 tasks_updater.py <tasks_json_file>", file=sys.stderr)
        sys.exit(1)

    json_path = Path(sys.argv[1])
    if not json_path.exists():
        print(f"Input file not found: {json_path.name}", file=sys.stderr)
        sys.exit(1)

    try:
        with json_path.open("r") as f:
            new_tasks = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON in input file: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        count = append_tasks(new_tasks)
        print(f"Added {count} task(s) to tasks.yml")
    except ValueError as e:
        print(f"Invalid task data: {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"Failed to update tasks.yml: {e}", file=sys.stderr)
        sys.exit(3)


if __name__ == "__main__":
    main()
