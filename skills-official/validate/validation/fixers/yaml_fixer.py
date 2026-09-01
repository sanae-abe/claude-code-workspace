#!/usr/bin/env python3
"""
YAML Auto-Fixer
Fixes common YAML issues in task files.
"""

import sys
import re
from pathlib import Path


def remove_markdown_blocks(content: str) -> str:
    """Remove markdown code blocks (```yaml, ```)."""
    # Remove opening ```yaml or ```yml
    content = re.sub(r'^```ya?ml\s*\n', '', content, flags=re.MULTILINE)
    # Remove closing ```
    content = re.sub(r'\n```\s*$', '', content, flags=re.MULTILINE)
    content = re.sub(r'^```\s*$', '', content, flags=re.MULTILINE)
    return content


def fix_field_names(content: str) -> str:
    """Fix field names (sprint_id: → id:, task_id: → id:)."""
    # Fix sprint_id and task_id to id
    content = re.sub(r'^(\s*)sprint_id:', r'\1id:', content, flags=re.MULTILINE)
    content = re.sub(r'^(\s*)task_id:', r'\1id:', content, flags=re.MULTILINE)
    return content


def normalize_enum_values(content: str) -> str:
    """Normalize enum values to SCREAMING_SNAKE_CASE."""
    # Status values
    status_mapping = {
        'Done': 'DONE',
        'done': 'DONE',
        'Pending': 'PENDING',
        'pending': 'PENDING',
        'In Progress': 'IN_PROGRESS',
        'in progress': 'IN_PROGRESS',
        'in_progress': 'IN_PROGRESS',
        'InProgress': 'IN_PROGRESS',
        'Blocked': 'BLOCKED',
        'blocked': 'BLOCKED',
        'Cancelled': 'CANCELLED',
        'cancelled': 'CANCELLED',
    }

    for old_value, new_value in status_mapping.items():
        # Match status: "value" or status: value
        content = re.sub(
            rf'^(\s*status:\s*["\']?){re.escape(old_value)}(["\']?\s*)$',
            rf'\1{new_value}\2',
            content,
            flags=re.MULTILINE | re.IGNORECASE
        )

    return content


def fix_yaml_file(file_path: Path) -> bool:
    """
    Fix YAML file issues.

    Args:
        file_path: Path to the YAML file

    Returns:
        True if changes were made, False otherwise
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()

        # Apply fixes
        content = original_content
        content = remove_markdown_blocks(content)
        content = fix_field_names(content)
        content = normalize_enum_values(content)

        # Check if changes were made
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True

        return False

    except FileNotFoundError:
        print(f"ERROR: File not found: {file_path}", file=sys.stderr)
        return False
    except PermissionError:
        print(f"ERROR: Permission denied: {file_path}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"ERROR: Failed to process file: {e}", file=sys.stderr)
        return False


def main() -> int:
    """Main entry point."""
    if len(sys.argv) != 2:
        print("Usage: yaml_fixer.py <file.yml>", file=sys.stderr)
        return 1

    file_path = Path(sys.argv[1])

    if not file_path.exists():
        print(f"ERROR: File does not exist: {file_path}", file=sys.stderr)
        return 1

    if not file_path.is_file():
        print(f"ERROR: Not a file: {file_path}", file=sys.stderr)
        return 1

    # Fix the file
    changes_made = fix_yaml_file(file_path)

    if changes_made:
        print(f"Fixed: {file_path}")
        return 0
    else:
        print(f"No changes needed: {file_path}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
