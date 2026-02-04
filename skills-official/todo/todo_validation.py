"""
Input validation utilities for /todo command

Provides security-focused validation for file paths, user input, and task IDs.
"""

import os
import re
import unicodedata
from typing import Optional


def validate_path(path: str) -> str:
    """
    Validate file path is within project and not in .git directory.

    Args:
        path: File path to validate

    Returns:
        Validated absolute path

    Raises:
        ValueError: If path is invalid or insecure
    """
    if '..' in path:
        raise ValueError("Path cannot contain ..")

    real_path = os.path.realpath(os.path.abspath(path))
    cwd = os.getcwd()

    if not real_path.startswith(cwd):
        raise ValueError("Path outside project")

    if '/.git/' in real_path or real_path.endswith('/.git'):
        raise ValueError(".git access denied")

    return real_path


def sanitize_input(text: str, max_bytes: int = 4096, max_chars: int = 1000) -> str:
    """
    Sanitize user input with Unicode normalization and length limits.

    Args:
        text: User input text
        max_bytes: Maximum size in bytes (default: 4KB)
        max_chars: Maximum length in characters (default: 1000)

    Returns:
        Sanitized text

    Raises:
        ValueError: If input exceeds limits
    """
    # Unicode normalization (NFKC)
    normalized = unicodedata.normalize('NFKC', text)

    # Check byte size
    if len(normalized.encode('utf-8')) > max_bytes:
        raise ValueError(f"Input exceeds {max_bytes} byte limit")

    # Check character count
    if len(normalized) > max_chars:
        raise ValueError(f"Input exceeds {max_chars} character limit")

    return normalized


def validate_task_id(task_id: str) -> str:
    """
    Validate task ID follows task-N pattern.

    Args:
        task_id: Task ID string

    Returns:
        Validated task ID

    Raises:
        ValueError: If task ID is invalid
    """
    if not re.match(r'^task-\d+$', task_id):
        raise ValueError(f"Invalid task ID format: {task_id} (expected: task-N)")

    return task_id


def safe_error_message(error: Exception, context: str) -> str:
    """
    Generate user-safe error message without exposing internals.

    Args:
        error: Exception object
        context: Context description (e.g., "reading todo.md")

    Returns:
        Sanitized error message
    """
    # Get error message
    msg = str(error)

    # Remove absolute paths
    msg = msg.replace(os.getcwd(), '<project>')
    msg = re.sub(r'/Users/[^/]+/', '<home>/', msg)
    msg = re.sub(r'/home/[^/]+/', '<home>/', msg)
    msg = re.sub(r'C:\\Users\\[^\\]+\\', '<home>\\', msg)

    # Remove stack traces (keep first line only)
    msg = msg.split('\n')[0]

    return f"Error in {context}: {msg}"


def validate_priority(priority: str) -> str:
    """
    Validate priority value.

    Args:
        priority: Priority string

    Returns:
        Validated priority

    Raises:
        ValueError: If priority is invalid
    """
    allowed_priorities = ['critical', 'high', 'medium', 'low']

    if priority not in allowed_priorities:
        raise ValueError(
            f"Invalid priority: {priority} "
            f"(allowed: {', '.join(allowed_priorities)})"
        )

    return priority


def validate_tags(tags: str) -> str:
    """
    Validate tags (free-form, alphanumeric + underscore + hyphen).

    Args:
        tags: Space-separated tags (e.g., "security urgent api")

    Returns:
        Validated tags string

    Raises:
        ValueError: If tags contain invalid characters
    """
    if not tags:
        return ""

    tag_list = tags.split()

    for tag in tag_list:
        # Alphanumeric, underscore, hyphen only
        if not re.match(r'^[a-zA-Z0-9_-]+$', tag):
            raise ValueError(
                f"Invalid tag: {tag} "
                f"(allowed: alphanumeric, underscore, hyphen only)"
            )

        # Max 32 chars per tag
        if len(tag) > 32:
            raise ValueError(
                f"Tag too long: {tag} "
                f"(max: 32 characters, got: {len(tag)})"
            )

    return tags
