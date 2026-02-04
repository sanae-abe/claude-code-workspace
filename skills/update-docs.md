---
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, TodoWrite, Task
argument-hint: "[--sync|--validate|--comprehensive] [--scope=critical|important|routine]"
description: Streamlined documentation synchronization and quality validation
model: sonnet
---

# Documentation Update System

Arguments: $ARGUMENTS

## Argument Validation

Execute validation before any operations:

```bash
# Validate and sanitize update type
validate_update_type() {
  local type="$1"
  local allowed_types="--sync --validate --comprehensive"

  # Empty input defaults to --sync
  if [[ -z "$type" ]]; then
    echo "--sync"
    return 0
  fi

  # Validate against whitelist
  if [[ ! "$allowed_types" =~ "$type" ]]; then
    echo "ERROR: Invalid update type: $type"
    echo "Allowed types: --sync, --validate, --comprehensive"
    exit 1
  fi

  # Reject command injection characters
  local injection_pattern='[;`$()&|*?[]{}<>!]'
  if [[ "$type" =~ $injection_pattern ]]; then
    echo "ERROR: Invalid characters in update type"
    exit 2
  fi

  echo "$type"
}

# Parse and validate flags
parse_flags() {
  local args="$1"
  local allowed_flags="--sync --validate --comprehensive --scope"
  local allowed_scopes="critical important routine comprehensive"

  for arg in $args; do
    if [[ "$arg" =~ ^-- ]]; then
      if [[ ! "$allowed_flags" =~ "$arg" ]]; then
        echo "ERROR: Unknown flag: $arg"
        echo "Allowed flags: $allowed_flags"
        exit 1
      fi
    elif [[ -n "$SCOPE_FLAG" ]]; then
      if [[ ! "$allowed_scopes" =~ "$arg" ]]; then
        echo "ERROR: Invalid scope: $arg"
        echo "Allowed scopes: $allowed_scopes"
        exit 1
      fi
      unset SCOPE_FLAG
    elif [[ "$arg" == "--scope" ]]; then
      SCOPE_FLAG=1
    fi
  done
}

# Safe argument parsing
IFS=' ' read -r -a args <<< "$ARGUMENTS"
UPDATE_TYPE=$(validate_update_type "${args[0]}")
FLAGS="${args[@]:1}"

parse_flags "$FLAGS"
```

If validation fails: exit with error code 1 (user error) or 2 (security error)

## Execution Flow

1. Analyze documentation state with TodoWrite
   - Detect documentation structure (docs/, specs/, README.md)
   - Scan for outdated files (>30 days since modification)
   - Compare recent code changes with documentation
   - Check for broken links and format issues

2. Execute update strategy based on argument
   - **--sync**: Synchronize with recent code changes (default)
   - **--validate**: Quality checks only (no modifications)
   - **--comprehensive**: Full systematic review and update

3. Apply updates (skip if --validate)
   - Update affected files based on strategy
   - Fix broken links and format issues
   - Update timestamps and status indicators

4. Validate quality
   - Markdown syntax: Use external tool (markdownlint)
   - Link integrity: Use external tool (markdown-link-check)
   - UTF-8 encoding: Built-in check
   - Generate quality report

5. Prepare for commit
   - Show git diff for review
   - Suggest commit message
   - Recommend related commands (/commit, /ship)

## Tool Usage

TodoWrite: Track multi-step documentation updates
Task (Explore): Analyze documentation structure and dependencies
Grep/Glob: Search for outdated content and broken references
Edit/Write: Apply documentation updates

## Update Strategies

### --sync (Synchronize with code changes)
Default mode for regular updates:
- Compare git log with documentation timestamps
- Update implementation status indicators
- Reflect API changes in documentation
- Document new features and deprecated items
- Fix obvious formatting issues

### --validate (Quality checks only)
Read-only validation without modifications:
- Run markdownlint for syntax validation
- Run markdown-link-check for link integrity
- Check UTF-8 encoding compliance
- Generate quality report with actionable items

### --comprehensive (Full systematic review)
Deep review and update (use sparingly):
- Execute sync strategy first
- Review all documentation for accuracy
- Update README, installation guides, FAQ
- Fix all broken links and formatting issues
- Update component diagrams if needed
- Generate detailed quality report

## External Tools Reference

For advanced validation, consider using external tools:

**Markdown syntax validation**:
```bash
npx markdownlint-cli '**/*.md' --ignore node_modules
```

**Link integrity check**:
```bash
npx markdown-link-check README.md
npx markdown-link-check docs/**/*.md
```

**Table of contents generation**:
```bash
npx doctoc README.md --github
```

**UTF-8 encoding validation** (built-in):
```bash
file -b --mime-encoding *.md | grep -v utf-8 || echo "All UTF-8"
```

## Documentation Quality Standards

**Structure**:
- Hierarchical headers (H1 → H2 → H3)
- Cross-references between related sections
- Code examples with language hints
- Last updated timestamp

**Content**:
- Completed items clearly marked
- Warnings for limitations and known issues
- Pending features labeled explicitly
- Dates for schedules and release plans

**Validation** (built-in checks):
- UTF-8 encoding compliance
- Basic Markdown syntax
- Internal link integrity

## Error Handling

**Documentation structure not found**:
- Offer to create standard structure (docs/, README.md)
- Detect existing custom structure
- Suggest minimal setup or cancel

**Implementation mismatch detected**:
- Prioritize code as source of truth
- Report specific mismatches with file paths
- Suggest manual review if complex

**Validation fails**:
- Report specific syntax or format errors with line numbers
- Suggest correction with examples
- Reference external tools for advanced fixes

**Broken links found**:
- Report broken URLs with context
- Suggest alternatives or removal
- Skip external link validation if network unavailable

Security:
Never expose absolute paths in error messages
Report only relative paths from project root

## Examples

```
/update-docs → Sync documentation with recent code changes (default)
/update-docs --sync → Explicit sync mode
/update-docs --validate → Quality checks only, no modifications
/update-docs --comprehensive → Full systematic review and update
/update-docs --sync --scope=critical → Sync critical documentation only
```
