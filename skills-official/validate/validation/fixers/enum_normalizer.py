#!/usr/bin/env python3
"""
Enum Normalizer
Normalizes enum values to SCREAMING_SNAKE_CASE format.
"""

import sys
import re
from pathlib import Path


# Enum value mappings
STATUS_MAPPING = {
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
    'Canceled': 'CANCELLED',
    'canceled': 'CANCELLED',
    'Todo': 'TODO',
    'todo': 'TODO',
    'To Do': 'TODO',
    'to do': 'TODO',
}

PRIORITY_MAPPING = {
    'High': 'HIGH',
    'high': 'HIGH',
    'Medium': 'MEDIUM',
    'medium': 'MEDIUM',
    'Low': 'LOW',
    'low': 'LOW',
    'Critical': 'CRITICAL',
    'critical': 'CRITICAL',
    'Urgent': 'URGENT',
    'urgent': 'URGENT',
}


def normalize_enum_field(content: str, field_name: str, mapping: dict[str, str]) -> str:
    """
    Normalize enum values for a specific field.

    Args:
        content: File content
        field_name: Name of the field (e.g., 'status', 'priority')
        mapping: Dictionary mapping old values to normalized values

    Returns:
        Content with normalized enum values
    """
    for old_value, new_value in mapping.items():
        # Match field: "value" or field: value
        # Support both quoted and unquoted values
        patterns = [
            # With quotes
            rf'^(\s*{field_name}:\s*["\']){re.escape(old_value)}(["\'])\s*$',
            # Without quotes
            rf'^(\s*{field_name}:\s+){re.escape(old_value)}(\s*)$',
        ]

        for pattern in patterns:
            content = re.sub(
                pattern,
                rf'\1{new_value}\2',
                content,
                flags=re.MULTILINE
            )

    return content


def normalize_enums(content: str) -> tuple[str, bool]:
    """
    Normalize all enum values in content.

    Args:
        content: File content

    Returns:
        Tuple of (normalized content, whether changes were made)
    """
    original_content = content

    # Normalize status values
    content = normalize_enum_field(content, 'status', STATUS_MAPPING)

    # Normalize priority values
    content = normalize_enum_field(content, 'priority', PRIORITY_MAPPING)

    changes_made = content != original_content

    return content, changes_made


def process_file(file_path: Path) -> bool:
    """
    Process a file to normalize enum values.

    Args:
        file_path: Path to the file

    Returns:
        True if changes were made, False otherwise
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()

        normalized_content, changes_made = normalize_enums(original_content)

        if changes_made:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(normalized_content)
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
        print("Usage: enum_normalizer.py <file>", file=sys.stderr)
        return 1

    file_path = Path(sys.argv[1])

    if not file_path.exists():
        print(f"ERROR: File does not exist: {file_path}", file=sys.stderr)
        return 1

    if not file_path.is_file():
        print(f"ERROR: Not a file: {file_path}", file=sys.stderr)
        return 1

    # Process the file
    changes_made = process_file(file_path)

    if changes_made:
        print(f"Normalized enum values in: {file_path}")
        return 0
    else:
        print(f"No enum values to normalize: {file_path}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
