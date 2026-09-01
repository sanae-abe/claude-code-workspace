---
name: update-docs
description: Streamlined documentation synchronization and quality validation. Use when syncing docs with code changes, validating doc quality, or running a comprehensive doc review.
argument-hint: "[--sync|--validate|--comprehensive] [--scope=critical|important|routine]"
allowed-tools: Bash(npx *) Bash(git *) Bash(file *) Read Write Edit Grep Glob
model: sonnet
---

# Documentation Update System

Received arguments: `$ARGUMENTS`

## Argument Validation

Parse $ARGUMENTS before any operations:

**Update type** (first argument):
- Allowed: `--sync`, `--validate`, `--comprehensive`
- Default if omitted: `--sync`
- If invalid value: report `"Invalid update type: [value]. Allowed: --sync, --validate, --comprehensive"` and stop

**Scope flag** (optional, `--scope=VALUE`):
- Allowed scope values: `critical`, `important`, `routine`
- If invalid scope: report `"Invalid scope: [value]. Allowed: critical, important, routine"` and stop

**Unknown flags**: report `"Unknown flag: [flag]. Allowed: --sync, --validate, --comprehensive, --scope"` and stop

**Security**: reject any argument containing `;`, `` ` ``, `$()`, `&`, `|`, `*`, `?` — report `"Invalid characters in argument"` and stop

If validation fails: use relative paths only in error messages, never expose absolute paths

## Execution Flow

Create tasks with TodoWrite for each step before starting:
1. Analyze documentation state
2. Execute update strategy
3. Apply updates (skip if --validate)
4. Validate quality
5. Prepare commit summary

Mark each task completed with TodoWrite as work progresses.

1. **Analyze documentation state**
   - Detect documentation structure (`docs/`, `specs/`, `README.md`)
   - Run `git log --since="30 days ago" --name-only` to find recently changed source files
   - Compare changed files with corresponding documentation
   - Check for broken internal links and format issues

2. **Execute update strategy** based on argument:
   - `--sync`: Synchronize with recent code changes (default)
   - `--validate`: Quality checks only, no modifications
   - `--comprehensive`: Full systematic review and update

3. **Apply updates** (skip entirely if `--validate`):
   - Update affected docs based on strategy
   - Fix broken links and format issues
   - Update timestamps and status indicators

4. **Validate quality**:
   - UTF-8 encoding: `find . -name '*.md' -not -path '*/node_modules/*' -exec file -b --mime-encoding {} \; | grep -v utf-8` (always available)
   - Markdown syntax: `npx markdownlint-cli '**/*.md' --ignore node_modules` (if available)
   - Link integrity: `npx markdown-link-check README.md` (if available)
   - If external tools unavailable: run built-in checks only and note which checks were skipped

5. **Prepare commit summary**:
   - Show `git diff --stat` for review
   - Suggest commit message following Conventional Commits
   - Recommend `/commit` or `/ship` for next steps

## Tool Usage

- **Read/Grep/Glob**: Analyze documentation structure and find outdated content
- **Edit/Write**: Apply documentation updates
- **Bash(git \*)**: Detect recently changed files, show diff
- **Bash(npx \*)**: Run markdownlint, markdown-link-check when available
- **Bash(file \*)**: UTF-8 encoding check

## Update Strategies

### --sync (Synchronize with code changes)
Default mode for regular updates:
- Compare `git log` timestamps with documentation modification dates
- Update implementation status indicators
- Reflect API changes in documentation
- Document new features and deprecated items
- Fix obvious formatting issues

**--scope behavior**:
- `critical`: sync only README, API specs, and security-related docs
- `important`: include design docs, architecture guides, and setup instructions
- `routine`: all docs (default when --scope is omitted)

### --validate (Quality checks only)
Read-only, no modifications:
- Run markdownlint for syntax validation (skip if not installed)
- Run markdown-link-check for link integrity (skip if not installed)
- Check UTF-8 encoding compliance
- Generate quality report with actionable items

**--scope behavior**:
- `critical`: validate only high-priority docs (README, API specs)
- `important`: include mid-priority docs
- `routine`: validate all docs (default when --scope is omitted)

### --comprehensive (Full systematic review)
Deep review and update (use sparingly):
- Execute sync strategy first
- Review all documentation for accuracy
- Update README, installation guides, FAQ
- Fix all broken links and formatting issues
- Update component diagrams if needed
- Generate detailed quality report

**--scope behavior**:
- `critical`: deep review of README, API specs, and changelogs only
- `important`: include design and architecture documents
- `routine`: full review of all docs (default when --scope is omitted)

## External Tools

Run with `npx` — skip gracefully if unavailable:

```bash
# Markdown syntax validation
npx markdownlint-cli '**/*.md' --ignore node_modules

# Link integrity check
npx markdown-link-check README.md

# Table of contents generation (--sync and --comprehensive only, not --validate)
npx doctoc README.md --github

# UTF-8 encoding check (built-in, always available)
find . -name '*.md' -not -path '*/node_modules/*' -exec file -b --mime-encoding {} \; | grep -v utf-8 || echo "All UTF-8"
```

If a tool is unavailable: note `"[tool] not available — skipping [check name]"` in the report. Do not fail the entire run.

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

## Error Handling

**Documentation structure not found**:
- Offer to create standard structure (`docs/`, `README.md`)
- Detect existing custom structure
- Suggest minimal setup or cancel

**Implementation mismatch detected**:
- Prioritize code as source of truth
- Report specific mismatches with relative file paths only
- Suggest manual review if complex

**External tool unavailable**:
- Skip that check and note it in the quality report
- Continue with remaining checks

**Validation fails**:
- Report specific errors with line numbers
- Suggest correction with examples

Security: Never expose absolute paths — use relative paths from project root only

## Examples

```
/update-docs                          → sync (default)
/update-docs --sync                   → explicit sync
/update-docs --validate               → quality checks only, no edits
/update-docs --comprehensive          → full review and update
/update-docs --sync --scope=critical  → sync critical docs only
```
