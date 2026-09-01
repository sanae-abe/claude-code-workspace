---
name: review-quality
description: Evaluate LLM implementation quality of CLAUDE.md, skills, or any other LLM instruction document (e.g. rules/*.md). Use when checking whether a skill, CLAUDE.md, or instruction document is concrete and consistent enough for an LLM to execute without guessing.
when_to_use: "CLAUDE.md quality check, skill evaluation, rules document review, LLM optimization review"
argument-hint: "<file-path>"
allowed-tools: Read Glob
model: sonnet
---

# review-quality

Arguments: $ARGUMENTS

## Purpose

Evaluate whether an instruction document is optimized for LLM execution, using a standardized checklist.

This measures **completeness and internal consistency** — whether the required instructions are present, concrete, and free of contradictions. It is not a measured probability of correct output. A document can score high on completeness and still contain wrong instructions, so the contradiction checks are mandatory, not optional.

Authority for skill structure and frontmatter rules: `~/.claude/rules/slash-command-design.md`. When this checklist and that document disagree, that document wins — report the divergence as a finding.

## Evaluation Framework

### Three Quality Dimensions

1. **Accuracy**: instructions are concrete and mutually consistent — an LLM can execute them without guessing or choosing between conflicting statements
2. **Maintainability**: structure withstands future edits without silent drift
3. **Usability**: users can understand and act on failures when they occur

### Scoring Criteria

| Score | Label | Action |
|-------|-------|--------|
| 95-100% | Optimal | No action needed |
| 90-94% | Acceptable | Minor improvements |
| 85-89% | Needs Improvement | Address medium issues |
| <85% | Inadequate | Major revision required |

Bands apply to the **overall pooled score** only — see Scoring Method for how that score is derived and why dimension scores are not mapped to this table.

## Scoring Method

Single source of truth for all target types:

- Fully met = 1 point, partially met = 0.5, not met = 0
- N/A items are excluded from the denominator; state the reason in findings
- **Overall (authoritative)**: total points / total applicable items across all three dimensions, pooled
- **Per dimension (indicative)**: dimension points / dimension applicable items
- Map only the overall score to the Scoring Criteria table. Dimension percentages are indicative: with a 6-item dimension the smallest step is 8.3 points, so some bands are unreachable at dimension level

Do not average the three dimension percentages — the dimensions have unequal item counts, so the average diverges from the pooled total.

## Execution Flow

1. Parse and validate arguments — see Argument Validation
2. Identify target type:
   - **CLAUDE.md**: basename is `CLAUDE.md`
   - **Skill**: basename is `SKILL.md`, or path contains `/skills/` or `/skills-official/`
   - **Other** (LLM instruction docs, e.g. `rules/tech-stacks/*.md`): apply the CLAUDE.md checklist; mark inapplicable items N/A
3. Read target file with Read tool
4. Resolve every file path the target references, using Glob. Paths that do not resolve are a Maintainability finding under "Referenced paths exist"
5. Apply the type-specific checklist — count items met per dimension
6. Cross-check instruction sections against each other and against the Examples section. Every contradiction found caps the **"No contradictions"** item at 0. If a contradiction also makes a different item unexecutable, score that item separately on its own merits and report both
7. Calculate scores per the Scoring Method section
8. Generate quality report with evidence (specific line references)
9. Provide actionable improvement suggestions ordered by impact

## Argument Validation

Parse $ARGUMENTS:
- First token: file path (required)
- No other arguments are accepted

If file path missing:
  Report: `ERROR: No target file specified`
  Show: `Usage: /review-quality <file-path>`
  Stop — do not read any file

If file path contains `..`:
  Report: `ERROR: Path traversal detected in file path`
  Show: `Use a full path rooted at ~ or / (e.g. ~/.claude/skills/ship/SKILL.md)`
  Stop — do not read any file

If extra arguments are present:
  Report: `ERROR: Unexpected argument: <value>`
  Show: `Usage: /review-quality <file-path>`
  Stop — do not read any file

If the file extension is not `.md`:
  Report: `ERROR: Unsupported target type: <path>`
  Show: `Only Markdown instruction documents are supported`
  Stop

If file not found:
  Report: `ERROR: File not found: <path>`
  Show: the path exactly as given — never the resolved absolute path, the working directory, or shell output
  Stop

If the file cannot be read (permission denied, or content is not text):
  Report: `ERROR: Cannot read target file: <path>`
  Show: the path exactly as given, plus the reason category only (`permission` or `not text`)
  Stop

If the file is empty or whitespace only:
  Report: `ERROR: Target file is empty: <path>`
  Show: `Provide a CLAUDE.md, SKILL.md, or other Markdown instruction document`
  Stop

If the target is a Skill and has no YAML frontmatter:
  Do not stop. Score the frontmatter-dependent Accuracy items ("Tool grants are minimal",
  "Argument substitution usage shown") as NOT MET, and report the missing frontmatter as a
  HIGH recommendation

## Evaluation Criteria by Type

### For Skills

**Accuracy (9 items)** — items marked "shell-only" are N/A for instruction-only skills that run no shell commands:
- [ ] Shell syntax examples present (code blocks with `IFS`, parameter expansion, etc.) — shell-only
- [ ] Error handling patterns shown (error conditions and messages)
- [ ] Failure behavior is expressible by an LLM (stop / report / retry — not process exit codes) — shell-only for actual scripts
- [ ] Input validation examples provided
- [ ] Argument parsing logic shown
- [ ] Security considerations addressed (no absolute paths or shell output in error messages)
- [ ] Tool grants are minimal — every tool in `allowed-tools` is actually used, and Bash is constrained (`Bash(git *)` not `Bash`) — N/A if no tools granted
- [ ] Argument substitution usage shown (the ARGUMENTS placeholder appears and is processed) — N/A if the skill takes no arguments
- [ ] No contradictions between instruction sections, or between instructions and Examples

**Maintainability (7 items)**:
- [ ] Code examples use standard patterns
- [ ] No duplicated rules across sections (a rule is stated once and referenced)
- [ ] Clear section hierarchy
- [ ] External references instead of inline duplication (notably `rules/slash-command-design.md` for skill conventions)
- [ ] Referenced paths exist — supporting files, `${CLAUDE_SKILL_DIR}` targets, and referenced docs all resolve (verified with Glob in Execution Flow step 4)
- [ ] Under 500 lines (or supporting files used)
- [ ] LLM instructions separated from user-facing content

**Usability (6 items)**:
- [ ] Output format examples cover every output mode the interface advertises
- [ ] Error messages include file:line references
- [ ] User-actionable guidance present
- [ ] Examples section with 2-3 concrete patterns
- [ ] Error cases shown in Examples section
- [ ] Expected failure modes documented

N/A note: "Shell syntax examples" and "Failure behavior" are N/A together — a skill either runs shell commands or it does not.

### For CLAUDE.md

**Accuracy (9 items)**:
- [ ] Concrete implementation instructions (not abstract principles)
- [ ] Specific examples for complex operations
- [ ] Decision trees with clear conditions
- [ ] No ambiguous "should/consider" without specifics
- [ ] Code blocks for technical patterns
- [ ] Conditions for agent selection specified — N/A for tech-stack docs (agent selection belongs to the base CLAUDE.md)
- [ ] File paths are absolute or clearly relative
- [ ] Priority levels explicit (MUST vs SHOULD vs MAY)
- [ ] No contradictions between sections, or between instructions and examples

**Maintainability (6 items)**:
- [ ] Structured format (YAML, tables, code blocks)
- [ ] External references instead of duplication
- [ ] Clear section hierarchy
- [ ] Referenced paths exist (verified with Glob in Execution Flow step 4)
- [ ] Token-efficient (no redundant examples)
- [ ] No user-facing troubleshooting content

**Usability (5 items)**:
- [ ] LLM-focused (no user-facing instructions)
- [ ] Actionable steps (not explanations)
- [ ] Clear priorities visible at section level
- [ ] Examples embedded in decision trees
- [ ] No user-facing commands or guides

### Reference Scoring Scope (both checklists)

"External references instead of duplication" scores *whether* the document delegates instead of inlining. "Referenced paths exist" scores whether those targets resolve. They are distinct items — do not collapse them, and do not score reference resolution anywhere else. Command existence (`command -v`) is out of scope: this skill grants no shell access, so score a referenced command only on whether the document names it concretely enough for a reader to verify.

## Risk Assessment

Dimension scores below 90% flag where to look — this threshold is an internal detection trigger, not a band from the Scoring Criteria table (only the overall score maps to that table).

For each dimension scoring <90%, identify:

**Impact**:
- Accuracy <90%: LLM guesses, or follows the wrong side of a contradiction
- Maintainability <90%: future edits drift out of sync silently
- Usability <90%: users cannot debug failures

**Mitigation**:
- Add concrete examples with line references
- Extract duplicated rules to a single section and reference it
- Provide output templates for every advertised output mode
- Remove ambiguous language; replace with conditions

## Output Format

```
LLM Implementation Quality Report

File: <file-path>
Type: <CLAUDE.md / Skill / Other>
Date: <YYYY-MM-DD>

═══════════════════════════════════════
Quality Scores
═══════════════════════════════════════

Accuracy:        XX% (X/Y applicable, Z N/A)
Maintainability: XX% (X/Y applicable)
Usability:       XX% (X/Y applicable)

Overall: XX% (X/Y applicable items) - Optimal/Acceptable/Needs Improvement/Inadequate

═══════════════════════════════════════
Detailed Findings
═══════════════════════════════════════

Accuracy (XX%):
  MET     Error handling patterns present (lines XX-XX)
  NOT MET Contradiction: line XX says <A>, line YY says <B>
  PARTIAL Tool grants include unused <tool> (line XX)
  N/A     Shell syntax examples — instruction-only skill

Maintainability (XX%):
  MET     Standard patterns used
  NOT MET Rule duplicated at lines XX and YY

Usability (XX%):
  MET     Output format examples present
  NOT MET Error messages lack file:line references

═══════════════════════════════════════
Priority Recommendations
═══════════════════════════════════════

HIGH (Critical for quality):
1. <specific issue> (lines XX-XX)
   Impact: +X pt (overall); <Dimension>
   Action: <concrete fix with example>

MEDIUM (Quality improvement):
2. <specific issue>
   Impact: +X pt (overall); <Dimension>
   Pattern: <template or example>

═══════════════════════════════════════
Token Efficiency Analysis
═══════════════════════════════════════

Current lines: XXX (measured)

Deletion candidates — list only content verified redundant, with both line ranges:
- Lines XX-XX duplicate lines YY-YY: <the rule stated twice>
- Lines XX-XX: user-facing content → move to USER_GUIDE.md
```

Notes on the template above — these are instructions, never emitted into the report:
- `Date`: use the session date; omit the line entirely if no date is available
- Report measured line counts only; do not estimate an "optimal" line count
- State point impact in overall points (`+X pt`), never in dimension percentages (see Scoring Method)

## Examples

```
/review-quality ~/.claude/skills/validate/SKILL.md
/review-quality ~/.claude/CLAUDE.md
/review-quality ~/.claude/rules/tech-stacks/frontend-web.md
/review-quality ~/projects/claude-code-workspace/skills-official/ship/SKILL.md
```

Error cases:
```
/review-quality
→ ERROR: No target file specified. Usage: /review-quality <file-path>

/review-quality ../../etc/passwd
→ ERROR: Path traversal detected in file path. Use a full path rooted at ~ or / (e.g. ~/.claude/skills/ship/SKILL.md)

/review-quality missing.md
→ ERROR: File not found: missing.md

/review-quality notes.txt
→ ERROR: Unsupported target type: notes.txt. Only Markdown instruction documents are supported

/review-quality empty.md
→ ERROR: Target file is empty: empty.md. Provide a CLAUDE.md, SKILL.md, or other Markdown instruction document

/review-quality file.md --report=json
→ ERROR: Unexpected argument: --report=json. Usage: /review-quality <file-path>
```
