# Agent Metadata Parser

## Purpose

Parse frontmatter metadata from .agent.md files to extract:
- Model configuration
- Tool restrictions (whitelist/blacklist)
- Security constraints
- Path restrictions
- Execution limits

## Frontmatter Format

Agent files use YAML frontmatter:

```markdown
---
model: claude-sonnet-4-5-20250929
tools: [Read, Grep, Glob]
forbidden_paths: [~/.ssh, ~/.aws, .env*]
security_level: high
readonly: true
max_turns: 10
description: "Read-only security audit agent"
---

# Agent Instructions

Your actual agent prompt here...
```

## Parse Frontmatter

```python
#!/usr/bin/env python3
import re
import yaml

def parse_agent_metadata(agent_file_path):
    """
    Parse frontmatter from .agent.md file.
    
    Returns:
        dict: Parsed metadata or None if no frontmatter
    """
    with open(agent_file_path, 'r') as f:
        content = f.read()
    
    # Extract frontmatter (between --- markers)
    match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
    if not match:
        return None
    
    frontmatter = match.group(1)
    metadata = yaml.safe_load(frontmatter)
    
    return metadata
```

## Validate Metadata

```python
import json
import jsonschema

def validate_agent_metadata(metadata):
    """
    Validate metadata against schema.
    
    Returns:
        tuple: (is_valid, error_message)
    """
    schema_path = os.path.expanduser('~/.claude/schemas/agent-metadata.schema.json')
    with open(schema_path, 'r') as f:
        schema = json.load(f)
    
    try:
        jsonschema.validate(metadata, schema)
        return (True, None)
    except jsonschema.ValidationError as e:
        return (False, e.message)
```

## Generate Tool Restrictions

```python
def get_tool_restrictions(metadata):
    """
    Generate tool restriction list from metadata.
    
    Returns:
        dict: {
            "allowed": [...],
            "forbidden": [...],
            "mode": "whitelist" | "blacklist"
        }
    """
    restrictions = {
        "allowed": [],
        "forbidden": [],
        "mode": "none"
    }
    
    # Whitelist approach (tools field)
    if 'tools' in metadata:
        restrictions["allowed"] = metadata['tools']
        restrictions["mode"] = "whitelist"
    
    # Blacklist approach (forbidden_tools field)
    if 'forbidden_tools' in metadata:
        restrictions["forbidden"] = metadata['forbidden_tools']
        if restrictions["mode"] == "none":
            restrictions["mode"] = "blacklist"
    
    # Security level presets
    if metadata.get('security_level') == 'high':
        # High security: only Read/Grep/Glob
        restrictions["allowed"] = ["Read", "Grep", "Glob"]
        restrictions["forbidden"] = ["Write", "Edit", "Bash"]
        restrictions["mode"] = "whitelist"
    
    # Read-only mode
    if metadata.get('readonly', False):
        restrictions["forbidden"].extend(["Write", "Edit"])
        if restrictions["mode"] == "none":
            restrictions["mode"] = "blacklist"
    
    return restrictions
```

## Generate Path Restrictions

```python
def get_path_restrictions(metadata):
    """
    Generate path restriction rules.
    
    Returns:
        dict: {
            "forbidden": [...],  # Paths agent cannot access
            "allowed": [...],    # Paths agent is restricted to
            "mode": "whitelist" | "blacklist" | "none"
        }
    """
    restrictions = {
        "forbidden": [],
        "allowed": [],
        "mode": "none"
    }
    
    # Always forbidden (security baseline)
    baseline_forbidden = [
        "~/.ssh",
        "~/.aws",
        "~/.env*",
        ".env",
        ".env.*",
        "credentials.json",
        "secrets.*"
    ]
    restrictions["forbidden"] = baseline_forbidden.copy()
    
    # Add custom forbidden paths
    if 'forbidden_paths' in metadata:
        restrictions["forbidden"].extend(metadata['forbidden_paths'])
        restrictions["mode"] = "blacklist"
    
    # Whitelist approach
    if 'allowed_paths' in metadata:
        restrictions["allowed"] = metadata['allowed_paths']
        restrictions["mode"] = "whitelist"
    
    return restrictions
```

## Generate Command Restrictions

```python
def get_command_restrictions(metadata):
    """
    Generate shell command restrictions.
    
    Returns:
        list: Forbidden command patterns
    """
    # Baseline forbidden commands (security)
    baseline_forbidden = [
        "rm -rf /",
        "dd if=",
        ":(){ :|:& };:",  # Fork bomb
        "curl * | sh",
        "wget * | sh",
        "eval",
        "chmod 777"
    ]
    
    forbidden = baseline_forbidden.copy()
    
    if 'forbidden_commands' in metadata:
        forbidden.extend(metadata['forbidden_commands'])
    
    return forbidden
```

## Check Tool Allowed

```python
def is_tool_allowed(tool_name, restrictions):
    """
    Check if a tool is allowed based on restrictions.
    
    Args:
        tool_name: Tool to check (e.g., "Write")
        restrictions: From get_tool_restrictions()
    
    Returns:
        bool: True if allowed, False if forbidden
    """
    mode = restrictions["mode"]
    
    if mode == "whitelist":
        return tool_name in restrictions["allowed"]
    elif mode == "blacklist":
        return tool_name not in restrictions["forbidden"]
    else:
        # No restrictions
        return True
```

## Check Path Allowed

```python
import fnmatch

def is_path_allowed(file_path, restrictions):
    """
    Check if a file path is allowed.
    
    Args:
        file_path: Path to check
        restrictions: From get_path_restrictions()
    
    Returns:
        bool: True if allowed, False if forbidden
    """
    import os
    file_path = os.path.expanduser(file_path)
    
    mode = restrictions["mode"]
    
    # Check forbidden paths (always checked)
    for pattern in restrictions["forbidden"]:
        pattern = os.path.expanduser(pattern)
        if fnmatch.fnmatch(file_path, pattern):
            return False
    
    # Whitelist mode
    if mode == "whitelist":
        for pattern in restrictions["allowed"]:
            pattern = os.path.expanduser(pattern)
            if fnmatch.fnmatch(file_path, pattern):
                return True
        return False  # Not in whitelist
    
    # Blacklist mode or no restrictions
    return True
```

## Usage in Slash Commands

```markdown
# In slash command that uses the Agent tool

## Load Agent Metadata

Before spawning agent:

```bash
# Parse agent metadata
AGENT_FILE="~/.claude/agents/security-reviewer.agent.md"

python3 << PYTHON
import sys
sys.path.append(os.path.expanduser('~/.claude/utils'))
from agent_metadata_parser import (
    parse_agent_metadata,
    validate_agent_metadata,
    get_tool_restrictions,
    get_path_restrictions
)

metadata = parse_agent_metadata('$AGENT_FILE')
if not metadata:
    print("ERROR: No frontmatter found")
    sys.exit(1)

valid, error = validate_agent_metadata(metadata)
if not valid:
    print(f"ERROR: Invalid metadata: {error}")
    sys.exit(1)

tool_restrictions = get_tool_restrictions(metadata)
path_restrictions = get_path_restrictions(metadata)

print(f"Model: {metadata['model']}")
print(f"Tools: {tool_restrictions}")
print(f"Paths: {path_restrictions}")
PYTHON
```

## Generate Agent Prompt

Inject restrictions into agent prompt:

```python
def generate_agent_prompt(metadata, restrictions):
    """
    Generate agent prompt with embedded restrictions.
    
    Returns:
        str: Prompt with constraints
    """
    prompt = f"""
You are operating under the following constraints:

**Tool Restrictions**:
Mode: {restrictions['tools']['mode']}
"""
    
    if restrictions['tools']['mode'] == 'whitelist':
        prompt += f"Allowed tools: {', '.join(restrictions['tools']['allowed'])}\n"
    elif restrictions['tools']['mode'] == 'blacklist':
        prompt += f"Forbidden tools: {', '.join(restrictions['tools']['forbidden'])}\n"
    
    prompt += f"""
**Path Restrictions**:
Mode: {restrictions['paths']['mode']}
Forbidden paths: {', '.join(restrictions['paths']['forbidden'])}
"""
    
    if restrictions['paths']['mode'] == 'whitelist':
        prompt += f"Allowed paths: {', '.join(restrictions['paths']['allowed'])}\n"
    
    prompt += f"""
**Execution Limits**:
Max turns: {metadata.get('max_turns', 50)}
Timeout: {metadata.get('timeout_seconds', 300)}s
"""
    
    if metadata.get('readonly', False):
        prompt += "\n**READ-ONLY MODE**: You cannot modify any files.\n"
    
    if metadata.get('requires_approval', False):
        prompt += "\n**APPROVAL REQUIRED**: All actions require user confirmation.\n"
    
    return prompt
```
```

## Complete Parser Script

```python
#!/usr/bin/env python3
"""
Agent Metadata Parser
Extract and validate frontmatter from .agent.md files
"""
import re
import yaml
import json
import jsonschema
import os
import sys
import fnmatch

def parse_agent_metadata(agent_file_path):
    """Parse frontmatter from .agent.md file."""
    with open(agent_file_path, 'r') as f:
        content = f.read()
    
    match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
    if not match:
        return None
    
    frontmatter = match.group(1)
    metadata = yaml.safe_load(frontmatter)
    return metadata

def validate_agent_metadata(metadata):
    """Validate metadata against schema."""
    schema_path = os.path.expanduser('~/.claude/schemas/agent-metadata.schema.json')
    with open(schema_path, 'r') as f:
        schema = json.load(f)
    
    try:
        jsonschema.validate(metadata, schema)
        return (True, None)
    except jsonschema.ValidationError as e:
        return (False, e.message)

def get_tool_restrictions(metadata):
    """Generate tool restriction list."""
    restrictions = {
        "allowed": [],
        "forbidden": [],
        "mode": "none"
    }
    
    if 'tools' in metadata:
        restrictions["allowed"] = metadata['tools']
        restrictions["mode"] = "whitelist"
    
    if 'forbidden_tools' in metadata:
        restrictions["forbidden"] = metadata['forbidden_tools']
        if restrictions["mode"] == "none":
            restrictions["mode"] = "blacklist"
    
    if metadata.get('security_level') == 'high':
        restrictions["allowed"] = ["Read", "Grep", "Glob"]
        restrictions["forbidden"] = ["Write", "Edit", "Bash"]
        restrictions["mode"] = "whitelist"
    
    if metadata.get('readonly', False):
        restrictions["forbidden"].extend(["Write", "Edit"])
        if restrictions["mode"] == "none":
            restrictions["mode"] = "blacklist"
    
    return restrictions

def get_path_restrictions(metadata):
    """Generate path restriction rules."""
    restrictions = {
        "forbidden": [
            "~/.ssh",
            "~/.aws",
            "~/.env*",
            ".env",
            ".env.*",
            "credentials.json",
            "secrets.*"
        ],
        "allowed": [],
        "mode": "none"
    }
    
    if 'forbidden_paths' in metadata:
        restrictions["forbidden"].extend(metadata['forbidden_paths'])
        restrictions["mode"] = "blacklist"
    
    if 'allowed_paths' in metadata:
        restrictions["allowed"] = metadata['allowed_paths']
        restrictions["mode"] = "whitelist"
    
    return restrictions

def is_tool_allowed(tool_name, restrictions):
    """Check if tool is allowed."""
    mode = restrictions["mode"]
    
    if mode == "whitelist":
        return tool_name in restrictions["allowed"]
    elif mode == "blacklist":
        return tool_name not in restrictions["forbidden"]
    else:
        return True

def is_path_allowed(file_path, restrictions):
    """Check if path is allowed."""
    file_path = os.path.expanduser(file_path)
    
    for pattern in restrictions["forbidden"]:
        pattern = os.path.expanduser(pattern)
        if fnmatch.fnmatch(file_path, pattern):
            return False
    
    if restrictions["mode"] == "whitelist":
        for pattern in restrictions["allowed"]:
            pattern = os.path.expanduser(pattern)
            if fnmatch.fnmatch(file_path, pattern):
                return True
        return False
    
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: agent-metadata-parser.py <agent-file.md>")
        sys.exit(1)
    
    agent_file = sys.argv[1]
    
    metadata = parse_agent_metadata(agent_file)
    if not metadata:
        print(json.dumps({"error": "No frontmatter found"}))
        sys.exit(1)
    
    valid, error = validate_agent_metadata(metadata)
    if not valid:
        print(json.dumps({"error": f"Invalid metadata: {error}"}))
        sys.exit(1)
    
    tool_restrictions = get_tool_restrictions(metadata)
    path_restrictions = get_path_restrictions(metadata)
    
    output = {
        "metadata": metadata,
        "restrictions": {
            "tools": tool_restrictions,
            "paths": path_restrictions
        }
    }
    
    print(json.dumps(output, indent=2))
