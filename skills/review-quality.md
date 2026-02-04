---
allowed-tools: Read, Grep, Glob, TodoWrite, AskUserQuestion
argument-hint: "<file-path> [--report=text|json]"
description: Evaluate LLM implementation quality of CLAUDE.md or slash commands
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

1. Parse arguments (file path, report format)
2. Identify target type (CLAUDE.md, slash command, other)
3. Apply type-specific evaluation criteria
4. Generate quality score with evidence
5. Provide actionable improvement suggestions

## Evaluation Criteria by Type

### For Slash Commands

**Accuracy Evaluation**:
- [ ] Bash syntax examples present (IFS, parameter expansion, etc.)
- [ ] Error handling patterns shown
- [ ] Exit code propagation documented
- [ ] Input validation examples provided

**Maintainability Evaluation**:
- [ ] Code examples use standard patterns
- [ ] Validation functions defined
- [ ] Security considerations explicit
- [ ] No code duplication between sections

**Usability Evaluation**:
- [ ] Output format examples with visual elements
- [ ] Error messages include file:line references
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
Type: <CLAUDE.md / Slash Command / Other>
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
  ✅ Bash syntax examples present
  ❌ Missing error handling patterns
  ⚠️ Exit code propagation partially documented

Maintainability (XX%):
  ✅ Standard patterns used
  ❌ Code duplication in sections X and Y

Usability (XX%):
  ✅ Output format examples present
  ❌ Error messages lack file:line references

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
3. Add file:line references to errors
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

## Implementation

```bash
# Exit code constants (single source of truth)
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_SYSTEM_ERROR=3
readonly EXIT_UNRECOVERABLE=4

# Validation functions
validate_report_format() {
    local format="$1"
    if [[ ! "$format" =~ ^(text|json)$ ]]; then
        echo "ERROR: Invalid report format: $format"
        echo "File: review-quality.md:197 - Argument Parsing"
        echo ""
        echo "Valid formats: text, json"
        echo "Example: /review-quality file.md --report=json"
        return $EXIT_USER_ERROR
    fi
    return $EXIT_SUCCESS
}

validate_file_path() {
    local file_path="$1"

    # Security validation (prevent path traversal)
    if [[ "$file_path" =~ \.\. ]]; then
        echo "ERROR: Path traversal detected in file path"
        echo "File: review-quality.md:211 - Security Validation"
        echo ""
        echo "Security policy: File paths must not contain '..'"
        echo "Use absolute paths or paths relative to current directory"
        return $EXIT_SECURITY_ERROR
    fi

    # File existence check
    if [[ ! -f "$file_path" ]]; then
        echo "ERROR: File not found: $file_path"
        echo "File: review-quality.md:222 - File Validation"
        echo ""
        echo "Verify the file path is correct"
        echo "Current directory: $(pwd)"
        return $EXIT_USER_ERROR
    fi

    return $EXIT_SUCCESS
}

# Parse arguments
TARGET_FILE=""
REPORT_FORMAT="text"

IFS=' ' read -r -a args <<< "$ARGUMENTS"

for arg in "${args[@]}"; do
    case "$arg" in
        --report=*)
            REPORT_FORMAT="${arg#*=}"
            validate_report_format "$REPORT_FORMAT" || exit $?
            ;;
        *)
            if [[ -z "$TARGET_FILE" ]]; then
                TARGET_FILE="$arg"
            fi
            ;;
    esac
done

# Validate target file
if [[ -z "$TARGET_FILE" ]]; then
    echo "ERROR: No target file specified"
    echo "File: review-quality.md:238 - Argument Validation"
    echo ""
    echo "Usage: /review-quality <file-path> [--report=text|json]"
    echo "Example: /review-quality ~/.claude/commands/ship.md"
    exit $EXIT_USER_ERROR
fi

validate_file_path "$TARGET_FILE" || exit $?

# Identify type
if [[ "$TARGET_FILE" == *"CLAUDE.md" ]]; then
    TARGET_TYPE="CLAUDE.md"
elif [[ "$TARGET_FILE" == *.md ]] && [[ "$TARGET_FILE" == *"/commands/"* ]]; then
    TARGET_TYPE="slash-command"
else
    TARGET_TYPE="other"
fi

# Apply evaluation criteria
echo "🔍 Analyzing $TARGET_FILE..."
echo "Type: $TARGET_TYPE"
echo ""

# Use Read tool to analyze file content
# Evaluate against type-specific checklist (L41-87)
# Calculate scores based on criteria met
# Generate quality report with evidence

# For Slash Commands (L45-67):
# - Check Bash syntax examples: Grep for '```bash'
# - Check error handling: Grep for 'exit \$EXIT_'
# - Check file:line references: Grep for 'File:.*\.md:[0-9]'
# - Check validation functions: Grep for 'validate_.*() {'
# - Check security considerations: Grep for 'security|Security'
# - Check output examples: Grep for '# Output:'

# For CLAUDE.md (L71-87):
# - Check concrete instructions: Look for code blocks, decision trees
# - Check external references: Grep for '~/.claude/'
# - Check priorities: Grep for 'MUST|SHOULD|MAY'
# - Check structured format: Look for YAML, tables, code blocks

# Generate report in format specified by REPORT_FORMAT
# Use template from L104-169 for structure
# Include actionable recommendations based on gaps found

echo "✅ Quality review completed"
echo "Report format: $REPORT_FORMAT"
```

## Examples

```bash
# Evaluate slash command
/review-quality ~/.claude/commands/validate.md

# Evaluate CLAUDE.md with JSON output
/review-quality ~/.claude/CLAUDE.md --report=json

# Evaluate project-specific CLAUDE.md
/review-quality .claude/CLAUDE.md
```


## Exit Code System

Exit codes are defined as constants in Implementation section (L175-179):

- `EXIT_SUCCESS` (0): Quality review completed, score calculated
- `EXIT_USER_ERROR` (1): User error (file not found, invalid arguments)
- `EXIT_SECURITY_ERROR` (2): Security error (path traversal detected)
- `EXIT_SYSTEM_ERROR` (3): System error (Read tool failed, grep unavailable)
- `EXIT_UNRECOVERABLE` (4): Unrecoverable error (critical review failure)

## Performance Notes

- File size <10KB: <5 seconds
- File size 10-50KB: 5-15 seconds
- Uses Read + Grep (no external tools)

## Troubleshooting

### ERROR: File not found

**Symptoms**: Command exits with "File not found: <path>"

**Solutions**:
1. Verify file path exists:
   ```bash
   ls -l <file-path>
   ```

2. Use absolute path instead of relative:
   ```bash
   # Instead of: /review-quality ../commands/ship.md
   /review-quality ~/.claude/commands/ship.md
   ```

3. Check current directory:
   ```bash
   pwd  # Verify you're in the expected location
   ```

### ERROR: Path traversal detected

**Symptoms**: Command exits with "Path traversal detected in file path"

**Cause**: File path contains '..' which is blocked for security

**Solutions**:
1. Use absolute paths:
   ```bash
   # Instead of: /review-quality ../../.claude/CLAUDE.md
   /review-quality ~/.claude/CLAUDE.md
   ```

2. Navigate to directory first:
   ```bash
   cd ~/.claude/commands
   /review-quality validate.md
   ```

### ERROR: Invalid report format

**Symptoms**: Command exits with "Invalid report format: <format>"

**Solutions**:
1. Use valid format (text or json):
   ```bash
   /review-quality file.md --report=text
   /review-quality file.md --report=json
   ```

2. Check for typos:
   ```bash
   # Incorrect: --report=txt
   # Correct:   --report=text
   ```

### Low Quality Scores

**Symptoms**: Report shows scores <90%

**Analysis Steps**:
1. Check which dimension is low (Accuracy/Maintainability/Usability)

2. Review "Detailed Findings" section for specific gaps

3. Apply "Priority Recommendations" in order (HIGH first)

4. Re-run review after improvements:
   ```bash
   /review-quality <same-file> --report=text
   ```

### No Bash Syntax Examples Found

**Symptoms**: Accuracy score low, "Bash syntax examples" marked as missing

**Solutions** (for slash command files):
1. Add code blocks with bash syntax:
   ````markdown
   ```bash
   IFS=' ' read -r -a args <<< "$ARGUMENTS"
   ```
   ````

2. Include parameter expansion examples:
   ```bash
   PARAM="${arg#*=}"  # Remove prefix
   ```

3. Show error handling patterns:
   ```bash
   if [[ condition ]]; then
       exit $EXIT_USER_ERROR
   fi
   ```
