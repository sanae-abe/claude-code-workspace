---
argument-hint: "<file-path> [--report=text|json]"
description: Evaluate LLM implementation quality of CLAUDE.md or skill files. Use when asked to review, score, or assess quality of a skill or CLAUDE.md configuration.
model: sonnet
---

# review-quality

Arguments: $ARGUMENTS

## Purpose

Quantitatively evaluate whether documentation/commands are optimized for LLM implementation quality using a standardized framework.

## Evaluation Framework

### Three Quality Dimensions

1. **Accuracy (正確性)**: 90%+ probability of correct implementation
2. **Maintainability (保守性)**: Code withstands future modifications
3. **Usability (ユーザビリティ)**: Users understand errors when they occur

### Scoring Criteria

| Score | Accuracy | Maintainability | Usability | Overall |
|-------|----------|-----------------|-----------|---------|
| 95-100% | Excellent | Excellent | Excellent | ✅ Optimal |
| 90-94% | Good | Good | Good | ✅ Acceptable |
| 85-89% | Fair | Fair | Fair | ⚠️ Needs Improvement |
| <85% | Poor | Poor | Poor | ❌ Inadequate |

## Execution Flow

1. Parse arguments from $ARGUMENTS (file path, report format)
2. Validate file path (reject `..`, confirm file exists)
3. Identify target type (CLAUDE.md, skill, other)
4. Read target file with Read tool
5. Apply type-specific evaluation criteria
6. Generate quality score with evidence
7. Output report in requested format

## Argument Parsing

Extract from $ARGUMENTS:
- First non-flag token → `TARGET_FILE`
- `--report=text|json` → `REPORT_FORMAT` (default: `text`)

Validation rules:
- If `TARGET_FILE` is empty: report error and exit (code 1)
- If `TARGET_FILE` contains `..`: report security error and exit (code 2)
- If `TARGET_FILE` does not exist (Read tool returns error): report file-not-found error and exit (code 1)
- If `--report=<value>` is not `text` or `json`: report invalid format error and exit (code 1)

## Identify Type

```
if TARGET_FILE ends with "CLAUDE.md" → TARGET_TYPE = "CLAUDE.md"
elif TARGET_FILE ends with ".md" AND path contains "/skills/" → TARGET_TYPE = "skill"
else → TARGET_TYPE = "other"
```

## Evaluation Criteria by Type

### For Skills

**Accuracy Evaluation**:
- [ ] Implementation examples present (code blocks with concrete syntax)
- [ ] Error handling patterns shown
- [ ] Exit/return code propagation documented
- [ ] Input validation examples provided

**Maintainability Evaluation**:
- [ ] Examples use standard patterns for the target language/environment
- [ ] Validation logic is defined or referenced
- [ ] Security considerations are explicit
- [ ] No duplication between sections

**Usability Evaluation**:
- [ ] Output format examples with visual structure
- [ ] Error messages are actionable (include location context)
- [ ] Suggestions provided for common errors
- [ ] User-actionable guidance present

**Scoring**:
- All criteria met: 95%+
- 75-90% criteria met: 90-94%
- 50-74% criteria met: 85-89%
- <50% criteria met: <85%

### For CLAUDE.md

**Accuracy Evaluation**:
- [ ] Concrete implementation instructions (not abstract principles)
- [ ] Specific examples for complex operations
- [ ] Decision trees with clear conditions
- [ ] No ambiguous "should/consider" without specifics

**Maintainability Evaluation**:
- [ ] Structured format (YAML, tables, code blocks)
- [ ] External references instead of duplication
- [ ] Version-controlled patterns
- [ ] Clear section hierarchy

**Usability Evaluation**:
- [ ] LLM-focused (no user-facing instructions)
- [ ] Token-efficient (no redundant examples)
- [ ] Clear priorities (MUST vs SHOULD vs MAY)
- [ ] Actionable steps (not explanations)

## Risk Assessment

For each low-scoring dimension, identify:

**Impact**:
- Accuracy <90%: LLM generates incorrect code
- Maintainability <90%: Future edits break functionality
- Usability <90%: Users cannot debug issues

**Mitigation**:
- Add concrete examples
- Define validation functions
- Provide output templates
- Remove ambiguous language

## Output Format

```
🔍 LLM Implementation Quality Report

File: <file-path>
Type: <CLAUDE.md / Skill / Other>
Date: <YYYY-MM-DD>

═══════════════════════════════════════
Quality Scores
═══════════════════════════════════════

✅/⚠️/❌ Accuracy:        XX% (Good/Fair/Poor)
✅/⚠️/❌ Maintainability: XX% (Good/Fair/Poor)
✅/⚠️/❌ Usability:       XX% (Good/Fair/Poor)

Overall: XX% - Optimal/Acceptable/Needs Improvement/Inadequate

═══════════════════════════════════════
Detailed Findings
═══════════════════════════════════════

Accuracy (XX%):
  ✅ Implementation examples present
  ❌ Missing error handling patterns
  ⚠️ Exit code propagation partially documented

Maintainability (XX%):
  ✅ Standard patterns used
  ❌ Code duplication in sections X and Y

Usability (XX%):
  ✅ Output format examples present
  ❌ Error messages lack location context

═══════════════════════════════════════
Priority Recommendations
═══════════════════════════════════════

HIGH (Critical for quality):
1. Add error handling patterns (lines XX-XX)
   Impact: Accuracy +10%
   Example: [concrete code example]

2. Remove code duplication (lines XX, YY)
   Impact: Maintainability +5%
   Action: Move to shared section

MEDIUM (Quality improvement):
3. Add location context to errors
   Impact: Usability +5%
   Pattern: "file:line - description"

═══════════════════════════════════════
Token Efficiency Analysis
═══════════════════════════════════════

Current lines: XXX
Redundant content: XX lines (X%)
Optimal target: XXX lines

Suggested deletions:
- Lines XX-XX: User-facing instructions (move to USER_GUIDE.md)
- Lines XX-XX: Duplicate examples (consolidate)
```

If `REPORT_FORMAT=json`: output a JSON object with keys `file`, `type`, `scores` (object with `accuracy`, `maintainability`, `usability`, `overall`), `findings` (array), `recommendations` (array).

## Exit Code System

- `0` (SUCCESS): Quality review completed, score calculated
- `1` (USER_ERROR): File not found or invalid arguments
- `2` (SECURITY_ERROR): Path traversal detected
- `3` (SYSTEM_ERROR): Read tool failed
- `4` (UNRECOVERABLE): Critical review failure

## Examples

```bash
/review-quality ~/.claude/skills/validate.md
/review-quality ~/.claude/CLAUDE.md --report=json
/review-quality .claude/CLAUDE.md
```
