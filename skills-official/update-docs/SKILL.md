---
name: update-docs
description: Streamlined documentation synchronization and quality validation. Use when syncing docs with code changes, validating doc quality, or running a comprehensive doc review.
argument-hint: "[--sync|--validate|--comprehensive] [--scope=critical|important|routine]"
allowed-tools: Bash(npx *) Bash(git *) Bash(file *) Bash(find *) Bash(grep *) Read Write Edit Grep Glob TodoWrite
disable-model-invocation: true
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
- Default if omitted: `routine`
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

2. **Execute update strategy** based on the update type — see Update Strategies

3. **Apply updates** (skip entirely if `--validate`):
   - Update affected docs based on strategy
   - Fix broken links and format issues
   - Update timestamps and status indicators
   - Regenerate table of contents: `npx doctoc README.md --github`

4. **Validate quality**:
   - UTF-8 encoding: `find . -name '*.md' -not -path '*/node_modules/*' -exec file -b --mime-encoding {} \; | grep -v utf-8` (built-in tools only)
   - Markdown syntax: `npx markdownlint-cli '**/*.md' --ignore node_modules`
   - Link integrity: `npx markdown-link-check README.md`
   - Missing external tools: see External Tools

5. **Prepare commit summary**:
   - Show `git diff --stat` for review
   - Suggest commit message following Conventional Commits
   - Leave every change unstaged and stop — the user decides when to commit

## Tool Usage

- **TodoWrite**: Track the five execution steps
- **Read/Grep/Glob**: Analyze documentation structure and find outdated content
- **Edit/Write**: Apply documentation updates
- **Bash(git \*)**: Detect recently changed files, show diff
- **Bash(npx \*)**: Run markdownlint, markdown-link-check, doctoc
- **Bash(file \*)** + **Bash(find \*)** + **Bash(grep \*)**: UTF-8 encoding check

## Update Strategies

### --sync (Synchronize with code changes)
Default mode for regular updates:
- Compare `git log` timestamps with documentation modification dates
- Update implementation status indicators
- Reflect API changes in documentation
- Document new features and deprecated items
- Fix obvious formatting issues

### --validate (Quality checks only)
Read-only — skip step 3 entirely, including TOC regeneration:
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

### Scope targets

`--scope` selects which documents the chosen strategy touches. `important` includes everything `critical` covers.

| scope | --sync | --validate | --comprehensive |
|---|---|---|---|
| `critical` | README, API specs, security-related docs | README, API specs | README, API specs, changelogs |
| `important` | + design docs, architecture guides, setup instructions | + mid-priority docs | + design and architecture documents |
| `routine` (default) | all docs | all docs | all docs |

## External Tools

Run with `npx`. If a tool is unavailable: note `"[tool] not available — skipping [check name]"` in the Skipped checks section of the report, continue with the remaining checks, and do not fail the run. This is the only rule for missing tools — every step that names an external tool follows it.

```bash
# Markdown syntax validation
npx markdownlint-cli '**/*.md' --ignore node_modules

# Link integrity check
npx markdown-link-check README.md

# Table of contents generation (step 3 only — never under --validate)
npx doctoc README.md --github

# UTF-8 encoding check (built-in tools, no npx dependency)
find . -name '*.md' -not -path '*/node_modules/*' -exec file -b --mime-encoding {} \; | grep -v utf-8 || echo "All UTF-8"
```

## Output Format

Emit this report in every mode. Omit the `Updated files` block under `--validate`.

```
Documentation Quality Report

Mode: --sync | Scope: routine
Files examined: 24

Findings:
  docs/api.md:42      broken link → ./missing-endpoint.md
  README.md:7         MD024 duplicate heading "Setup"
  docs/setup.md:1     encoding iso-8859-1 (expected utf-8)

Skipped checks:
  markdown-link-check not available — skipping link integrity

Updated files:
  README.md, docs/api.md

Next:
  docs/api.md:42 — repoint to ./endpoints.md or delete the reference
  docs/setup.md — re-encode as UTF-8
```

Every finding carries `file:line` (or `file` alone when the issue has no line, such as encoding). Report `Findings: none` rather than omitting the section. Use paths relative to the project root.

Then the commit summary for `--sync` and `--comprehensive`:

```
Commit Summary

 README.md   | 12 +++++---
 docs/api.md |  8 ++++--
 2 files changed, 14 insertions(+), 6 deletions(-)

Suggested message:
  docs: sync API reference with recent handler changes

Left unstaged for review — no files staged, no commit created.
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

## Error Handling

**Documentation structure not found**:
- Offer to create standard structure (`docs/`, `README.md`)
- Detect existing custom structure
- Suggest minimal setup or cancel

**Implementation mismatch detected**:
- Prioritize code as source of truth
- Report specific mismatches with relative file paths only
- Suggest manual review if complex

**External tool unavailable**: see External Tools

**Validation fails**:
- Report each error as `file:line` per Output Format
- Suggest correction with examples

Security: Never expose absolute paths — use relative paths from project root only

## Examples

```
/update-docs                          → sync (default), scope routine
/update-docs --validate               → quality checks only, no edits
/update-docs --sync --scope=critical  → sync README, API specs, security docs only
/update-docs --comprehensive          → full review and update
```

Error cases:
```
/update-docs --invalid
→ Invalid update type: --invalid. Allowed: --sync, --validate, --comprehensive

/update-docs --scope=all
→ Invalid scope: all. Allowed: critical, important, routine

/update-docs --dry-run
→ Unknown flag: --dry-run. Allowed: --sync, --validate, --comprehensive, --scope

/update-docs "--sync; rm -rf ."
→ Invalid characters in argument
```
