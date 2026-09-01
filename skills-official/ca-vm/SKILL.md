---
name: ca-vm
description: "Velocity Template management for VM-based projects"
argument-hint: "[create|edit|check|workflow|search] [target]"
model: sonnet
disable-model-invocation: true
allowed-tools: Bash(git branch *) Bash(git add *) Bash(git commit *) Bash(git status *) Read Write Edit Grep Glob TodoWrite AskUserQuestion
---

# Velocity Template Manager

Arguments: $ARGUMENTS

Specialized command for managing Velocity Template (.vm) files in projects using Apache Velocity for templating.

**Working directory**: Project root (the directory containing `customPagePart/`).
If `customPagePart/` is not found in current directory: report "customPagePart/ not found. Run from project root." and exit.

## Argument Validation

Parse $ARGUMENTS:
- Sanitize subcommand: validate against allowed list (create|edit|check|workflow|search)
- Sanitize file paths: reject ../, validate .vm extension, verify category directory exists
- Sanitize description: remove special characters, lowercase, replace spaces with hyphens
- Escape all arguments before passing to Bash

Validation functions (execute before any operation):
- validate_subcommand: reject invalid subcommands
- validate_vm_path: prevent directory traversal, verify path under customPagePart/
- sanitize_description: remove dangerous characters for filename generation
- parse_sequence: safely extract sequence numbers from filenames

## Execution Flow

1. Verify `customPagePart/` exists in current directory; abort if missing
2. Parse subcommand and arguments from $ARGUMENTS
3. Validate inputs (call validation functions)
4. If empty arguments: use AskUserQuestion for operation selection
5. Execute subcommand with validated inputs
6. Run quality checks if file modified
7. Report results with next steps

## Subcommands

### create [category] [description]

Create new VM file with auto-generated sequence number.

Steps:
1. Extract category from $ARGUMENTS or use AskUserQuestion
2. Validate category directory exists: `customPagePart/{category}/`
3. Get latest sequence for base name via Glob
4. Generate filename: YYMMDD{description}_{next_seq}.vm
5. Use AskUserQuestion to select template:
   - options: [Blank file] [Copy from existing file]
6. Create file via Write
7. Run check subcommand on new file
8. Report success with file path

### edit [file-path]

Edit existing VM by creating new version (sequence increment).

Steps:
1. Parse file path from $ARGUMENTS
2. If missing: search with Grep and use AskUserQuestion
3. Validate file exists via Read
4. Parse filename components: date, description, sequence
5. Use AskUserQuestion to select edit type:
   - options: [New version (increment sequence: 02→03)] [Variant (add suffix: 02→02a)]
6. Generate new filename based on selection
7. Copy content via Read then Write
8. Open new file for editing via Edit
9. Run check subcommand on new file
10. Report success with commit suggestion

### check [file-path]

Run validation on VM files.

Steps:
1. Parse target from $ARGUMENTS (file, directory, or empty for all files)
2. Locate validation script in order:
   - `scripts/vm_validate.sh`
   - `bin/vm_validate.sh`
   If neither found: report "Validation script not found. Expected at scripts/vm_validate.sh or bin/vm_validate.sh" and exit
3. Execute: `Bash scripts/vm_validate.sh {target}` (omit target argument to check all files)
4. Check exit code:
   - Exit 0: report "Validation passed"
   - Non-zero: show violation details and use AskUserQuestion:
     - options: [Show details] [Auto-fix (if supported)] [Skip and continue] [Abort]

### workflow

Guided workflow from branch to commit.

Steps:
1. Create tasks via TodoWrite: [Verify branch, Select operation, Run validation, Commit]
2. Check current branch: `git branch --show-current`
3. If on main or master: use AskUserQuestion:
   - "Currently on main. Create a feature branch?"
   - options: [Yes, create branch] [No, continue on main]
   - If yes: prompt for branch name, execute `git branch {name}` then `git checkout {name}`
4. Use AskUserQuestion to select operation:
   - options: [Create new VM] [Edit existing VM]
5. Execute selected operation (delegate to create or edit subcommand)
6. Run check subcommand
7. If validation passed:
   - Stage files: `git add customPagePart/{category}/{filename}.vm`
   - Commit with format: `feat(vm): {description} [seq={sequence}]`
8. Report: branch name, committed files, and next step (push / merge request)

### search [keyword]

Search VM files by content or filename.

Steps:
1. Parse keyword from $ARGUMENTS
2. If missing: use AskUserQuestion for keyword input
3. Search file content: Grep keyword in `customPagePart/**/*.vm`
4. Search filenames: Glob `customPagePart/**/*{keyword}*.vm`
5. Combine and deduplicate results, group by category
6. Show matches with file:line context
7. Use AskUserQuestion for next action:
   - options: [View file] [Edit file (delegates to edit subcommand)] [Copy path] [Done]

## File Naming Pattern

Pattern: YYMMDD{description}_{sequence}.vm

Examples:
- 170406campaignListInner_01.vm
- 110527readmoreex_detail_02.vm
- 190613webcontoplist_12a.vm (variant)

Sequence format:
- 2-digit zero-padded: 01, 02, ..., 10, 11
- Variants append a letter suffix: 02a, 10b, 10b2

## Sequence Number Detection

Algorithm:
1. Glob pattern: `customPagePart/{category}/{basepattern}_*.vm`
2. Extract matching filenames
3. Parse sequence with regex: `_(\d{2}[a-z0-9]*)\.vm$`
4. Extract numeric part only (strip variant suffix: `10b` → `10`)
5. Find max numeric value
6. Candidate = max + 1, zero-padded to 2 digits
7. Edge case — candidate already exists: increment candidate and recheck until unique
8. Edge case — no existing files: start at `01`

## Error Handling

Invalid subcommand:
Report "Invalid subcommand. Valid: create, edit, check, workflow, search"

File not found:
Search similar filenames with Grep; suggest closest matches

Sequence conflict:
Re-scan directory, recalculate candidate; retry up to 3 times; report error if still conflicted

Path validation error:
Report expected format: `customPagePart/{category}/{filename}.vm`
Never expose absolute paths in error messages

Validation script not found:
Report "Validation script not found. Expected at scripts/vm_validate.sh or bin/vm_validate.sh"

Validation failures:
Present remediation options via AskUserQuestion (non-blocking)

## Velocity Template Reference

Common syntax patterns: see `${CLAUDE_SKILL_DIR}/VELOCITY_PATTERNS.md`

## Examples

/ca-vm create detail "campaign list update" → Create new VM in detail category
/ca-vm edit customPagePart/detail/file_10.vm → Edit existing VM file
/ca-vm check → Run validation on all files
/ca-vm workflow → Guided branch → create/edit → commit flow
/ca-vm create → AskUserQuestion for category selection
/ca-vm unknown → Report error: "Invalid subcommand. Valid: create, edit, check, workflow, search"
/ca-vm edit ../../../etc/passwd → Report error: "Path traversal detected. Use paths under customPagePart/"
