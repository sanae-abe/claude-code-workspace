#!/usr/bin/env python3
"""
Markdown Stripper
Extracts YAML content from markdown code blocks.
"""

import sys
import re
from pathlib import Path


def strip_markdown_blocks(content: str) -> tuple[str, bool]:
    """
    Remove markdown code block markers from content.

    Args:
        content: File content potentially containing markdown blocks

    Returns:
        Tuple of (cleaned content, whether changes were made)
    """
    original_content = content

    # Remove opening ```yaml or ```yml markers
    content = re.sub(r'^```ya?ml\s*\n', '', content, flags=re.MULTILINE)

    # Remove closing ``` markers
    content = re.sub(r'\n```\s*$', '', content, flags=re.MULTILINE)
    content = re.sub(r'^```\s*$', '', content, flags=re.MULTILINE)

    # Remove any standalone ``` on a line
    content = re.sub(r'^\s*```\s*\n', '', content, flags=re.MULTILINE)

    # Clean up extra blank lines that might result
    content = re.sub(r'\n\n\n+', '\n\n', content)

    changes_made = content != original_content

    return content, changes_made


def process_file(file_path: Path) -> bool:
    """
    Process a file to remove markdown blocks.

    Args:
        file_path: Path to the file

    Returns:
        True if changes were made, False otherwise
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()

        cleaned_content, changes_made = strip_markdown_blocks(original_content)

        if changes_made:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)
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
        print("Usage: markdown_stripper.py <file>", file=sys.stderr)
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
        print(f"Stripped markdown blocks from: {file_path}")
        return 0
    else:
        print(f"No markdown blocks found: {file_path}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
