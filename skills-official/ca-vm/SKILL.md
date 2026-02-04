---
name: ca-vm
description: "Velocity Template management for VM-based projects"
---

<!-- Original metadata:
  allowed-tools: Bash, Read, Write, Edit, Grep, Glob, TodoWrite, AskUserQuestion
  argument-hint: "[create|edit|check|workflow|search] [target]"
  model: sonnet
-->


# Velocity Template Manager

Arguments: $ARGUMENTS

Specialized command for managing Velocity Template (.vm) files in projects using Apache Velocity for templating.

## Argument Validation

Parse $ARGUMENTS:
- Sanitize subcommand: validate against allowed list (create|edit|check|workflow|search)
- Sanitize file paths: reject ../, validate .vm extension, verify category directory exists
- Sanitize description: remove special characters, lowercase, replace spaces
- Escape all arguments before passing to Bash

Validation functions (execute before any operation):
- validate_subcommand: reject invalid subcommands
- validate_vm_path: prevent directory traversal, verify path under customPagePart/
- sanitize_description: remove dangerous characters for filename generation
- parse_sequence: safely extract sequence numbers from filenames

## Execution Flow

1. Parse subcommand and arguments from $ARGUMENTS
2. Validate inputs (call validation functions)
3. If empty arguments: use AskUserQuestion for operation selection
4. Execute subcommand with validated inputs
5. Run quality checks if file modified
6. Report results with next steps

## Subcommands

### create [category] [description]

Create new VM file with auto-generated sequence number.

Steps:
1. Extract category from $ARGUMENTS or use AskUserQuestion
2. Validate category exists in customPagePart/
3. Get latest sequence for base name via Glob
4. Generate filename: YYMMDD{description}_{next_seq}.vm
5. Select template approach (blank or copy from existing)
6. Create file via Write
7. Run validation checks
8. Report success with file path

### edit [file-path]

Edit existing VM by creating new version (sequence increment).

Steps:
1. Parse file path from $ARGUMENTS
2. If missing: search with Grep and use AskUserQuestion
3. Validate file exists via Read
4. Parse filename components: date, description, sequence
5. Generate new filename (increment sequence)
6. Handle variants: ask if creating variant (02a) vs new version (03)
7. Copy content via Read then Write
8. Open file for editing via Edit
9. Run validation checks
10. Report success with commit suggestion

### check [file-path]

Run validation on VM files.

Steps:
1. Parse target from $ARGUMENTS (file or empty for all)
2. Execute validation script
3. Parse exit code and output
4. If violations: show details and present remediation options
5. If no violations: report success

### workflow

Guided workflow from branch to commit.

Steps:
1. Create TodoWrite with tasks (branch verify, create/edit VM, validation, commit)
2. Check current branch: git branch --show-current
3. If on main: offer to create feature branch
4. Select create or edit operation
5. Execute selected operation
6. Run check subcommand
7. If passed: stage and commit with proper message format
8. Show merge request guidance

### search [keyword]

Search VM files by content or filename.

Steps:
1. Parse keyword from $ARGUMENTS
2. If missing: use AskUserQuestion
3. Search via Grep in customPagePart/**/*.vm
4. Group results by category
5. Show matches with file:line context
6. Offer to view, edit, or copy file

## File Naming Pattern

Pattern: YYMMDD{description}_{sequence}.vm

Examples:
- 170406campaignListInner_01.vm
- 110527readmoreex_detail_02.vm
- 190613webcontoplist_12a.vm (variant)

Sequence format:
- 2-digit zero-padded: 01, 02, ..., 10, 11
- Variants use suffix: 02a, 10b, 10b2

## Sequence Number Detection

Algorithm:
1. Glob pattern: customPagePart/{category}/{basepattern}_*.vm
2. Extract matching filenames
3. Parse sequence: pattern `_(\d{2}[a-z0-9]*)\.vm$`
4. Extract numeric part only (ignore suffix)
5. Return max + 1, zero-padded to 2 digits

## Velocity Syntax Patterns

Common patterns:

Macro definition:
```velocity
#macro(macroName $param)
  #set($var = "value")
  ## logic here
#end
```

Variable manipulation:
```velocity
#set($var = $object.property)
#set($var = $stringUtils.replace($var, '[placeholder]', "$value"))
```

Conditional:
```velocity
#if($condition && $condition != "")
  ## content
#elseif($other)
  ## content
#else
  ## content
#end
```

## Tool Usage

TodoWrite: for workflow (multi-step), create (6+ steps)
AskUserQuestion: missing args, variant choice, remediation options
Bash: git commands, validation scripts
Read: verify files, copy content
Write: create new files
Edit: modify existing files
Grep: search content
Glob: find files, detect sequences

## Error Handling

Invalid subcommand:
Report valid options: create, edit, check, workflow, search

File not found:
Search similar filenames with Grep
Suggest closest matches

Sequence conflict:
Re-scan directory and recalculate

Path validation errors:
Report expected path format
Never expose absolute paths

Validation failures:
Present remediation workflow (not blocking)

## Examples

/ca-vm create detail "campaign list update" → Create new VM in detail category
/ca-vm edit customPagePart/detail/file_10.vm → Edit existing VM file
/ca-vm check → Run validation on all files
