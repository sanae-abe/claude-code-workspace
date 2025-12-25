---
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, TodoWrite, AskUserQuestion, Task
argument-hint: "[language-code] [--coverage|--consistency|--format|--cultural|--complete]"
description: Comprehensive internationalization (i18n) status check for any project
model: sonnet
---

# i18n Completeness Check

Comprehensive internationalization (i18n) status check for any project.

Usage: `/i18n-check [language-code] [options]`

Examples:
- `/i18n-check` (Full completeness check for all languages)
- `/i18n-check --coverage` (Coverage-focused analysis)
- `/i18n-check ja --consistency` (Japanese terminology consistency check)
- `/i18n-check --cultural --detailed` (Detailed cultural adaptation review)

## Current i18n Project State

- Translation files: !`find . -name "*.json" -path "*/locales/*" -o -path "*/i18n/*" -o -path "*/lang/*" 2>/dev/null | wc -l || echo "0"` files found
- i18n Library: !`grep -E "i18next|vue-i18n|react-intl|gettext" package.json 2>/dev/null | head -1 || echo "Not detected"`
- Supported languages: !`ls -1 locales/ i18n/ lang/ 2>/dev/null || echo "No standard i18n directory"`
- Recent translations: !`git log --oneline --since="1 week ago" -- "**/locales/**" "**/i18n/**" | head -3 || echo "No recent updates"`
- Git status: !`git status --porcelain | grep -E "(locales|i18n|lang)" | wc -l || echo "0"` uncommitted translation changes

## Exit Code Constants

```bash
# Exit code definitions (single source of truth)
readonly EXIT_SUCCESS=0
readonly EXIT_USER_ERROR=1
readonly EXIT_SECURITY_ERROR=2
readonly EXIT_SYSTEM_ERROR=3
readonly EXIT_UNRECOVERABLE=4
```

## Execution Flow

### 1. Argument Validation

#### Argument Parsing Implementation

```bash
# Parse $ARGUMENTS into structured variables
LANG_CODE=""
CHECK_SCOPE=""

# IFS-based argument splitting
IFS=' ' read -r -a args <<< "$ARGUMENTS"

# Parameter expansion patterns
for arg in "${args[@]}"; do
    case "$arg" in
        --coverage|--consistency|--format|--cultural|--complete)
            CHECK_SCOPE="$arg"
            ;;
        *)
            if [[ -z "$LANG_CODE" ]]; then
                LANG_CODE="$arg"
            fi
            ;;
    esac
done

# Extract flag value using parameter expansion
FLAG_VALUE="${CHECK_SCOPE#--}"  # --coverage → coverage
```

#### Validation Functions

```bash
validate_language_code() {
    local code="$1"

    # ISO 639-1 (2-letter) or BCP 47 (language-region) validation
    if [[ ! "$code" =~ ^[a-z]{2}(-[A-Z]{2})?$ ]]; then
        echo "ERROR: Invalid language code format"
        echo "File: i18n-check.md:validate_language_code - Language Code Validation"
        echo ""
        echo "Got: '$code'"
        echo "Expected: ISO 639-1 format (e.g., 'en', 'ja') or BCP 47 (e.g., 'zh-CN')"
        return $EXIT_USER_ERROR
    fi

    return $EXIT_SUCCESS
}

validate_flag() {
    local flag="$1"
    local allowed="--coverage --consistency --format --cultural --complete"

    if [[ ! " $allowed " =~ " $flag " ]]; then
        echo "ERROR: Invalid flag: $flag"
        echo "File: i18n-check.md:validate_flag - Flag Validation"
        echo ""
        echo "Allowed flags: --coverage, --consistency, --format, --cultural, --complete"
        echo "Example: /i18n-check --coverage"
        return $EXIT_USER_ERROR
    fi

    return $EXIT_SUCCESS
}

validate_path_security() {
    local path="$1"

    # Path traversal detection
    if [[ "$path" =~ \.\. ]]; then
        echo "ERROR: Path traversal detected"
        echo "File: i18n-check.md:validate_path_security - Security Validation"
        echo ""
        echo "Security policy: File paths must not contain '..'"
        return $EXIT_SECURITY_ERROR
    fi

    return $EXIT_SUCCESS
}
```

#### Validation Execution

Parse and validate $ARGUMENTS:
- Sanitize language codes: validate against ISO 639-1 standard (2-letter codes) or BCP 47 (e.g., zh-CN)
- Validate flags against allowed list: --coverage, --consistency, --format, --cultural, --complete
- Reject unexpected patterns or characters
- If language code contains suspicious patterns (../, special chars): report error and exit with $EXIT_SECURITY_ERROR
- If flag not in allowed list: report error with available options and exit with $EXIT_USER_ERROR

```bash
# Execute validation
if [[ -n "$LANG_CODE" ]]; then
    validate_language_code "$LANG_CODE" || exit $?
fi

if [[ -n "$CHECK_SCOPE" ]]; then
    validate_flag "$CHECK_SCOPE" || exit $?
fi
```

### 2. Initial Diagnosis and Check Strategy Decision

Create TodoWrite with tasks:
1. Analyze i18n project structure
2. Detect translation file format and framework
3. Select check strategy interactively
4. Organize incremental checking

### 3. Check Scope Determination

Auto-determine from check target:
- **Urgent**: Pre-release completeness verification
- **Important**: After new language addition or major updates
- **Periodic**: Weekly/monthly maintenance
- **Comprehensive**: All languages, all perspectives check

### Automated i18n Diagnosis

#### Common Functions (DRY Principle)

```bash
# Constants for i18n directory patterns
readonly I18N_DIRS="locales i18n lang"
readonly I18N_FILE_PATTERNS="*.json *.yaml *.po"

# Find i18n translation files (reusable function)
find_i18n_files() {
    local file_type="${1:-*.json}"
    find . -name "$file_type" \( \
        -path "*/locales/*" -o \
        -path "*/i18n/*" -o \
        -path "*/lang/*" \
    \) 2>/dev/null
}

# Detect i18n directory (reusable function)
detect_i18n_dir() {
    if [[ -d "locales" ]]; then
        echo "locales"
    elif [[ -d "i18n" ]]; then
        echo "i18n"
    elif [[ -d "public/locales" ]]; then
        echo "public/locales"
    else
        echo ""
    fi
}
```

Automated i18n project analysis:
```bash
# i18n framework detection
echo "i18n Framework Detection:"
if [[ -f "package.json" ]]; then
    echo "React i18next:" && grep -c "react-i18next" package.json 2>/dev/null || echo "0"
    echo "Vue i18n:" && grep -c "vue-i18n" package.json 2>/dev/null || echo "0"
    echo "React Intl:" && grep -c "react-intl" package.json 2>/dev/null || echo "0"
    echo "i18next:" && grep -c "i18next" package.json 2>/dev/null || echo "0"
fi

# Translation file structure detection (using common function)
echo "Translation File Structure:"
I18N_FILES=$(find_i18n_files "*.json")
echo "$I18N_FILES" | head -5 || echo "No translation files found"

# Supported languages detection (using common function)
echo "Supported Languages:"
I18N_DIR=$(detect_i18n_dir)
if [[ -n "$I18N_DIR" ]]; then
    ls -1 "$I18N_DIR/"
else
    echo "ERROR: No standard i18n directory structure detected"
    echo "File: i18n-check.md:detect_i18n_dir - Directory Detection"
    echo ""
    echo "Searched directories: locales/, i18n/, public/locales/"
    echo "Please create one of these directories for translation files"
    exit $EXIT_USER_ERROR
fi

# Translation file format analysis (using common function)
echo "Translation File Formats:"
find_i18n_files "*.json" | wc -l | sed 's/^/JSON files: /'
find_i18n_files "*.yaml" | wc -l | sed 's/^/YAML files: /'
find_i18n_files "*.po" | wc -l | sed 's/^/PO files: /'

# Recent translation activity
echo "Recent Translation Activity:"
MODIFIED_COUNT=$(git log --since="1 month ago" --name-only --pretty=format: | grep -E "(locales|i18n|lang)" | sort | uniq | wc -l)
echo "Files modified: $MODIFIED_COUNT"
```

## Interactive i18n Check Management (AskUserQuestion Integration)

### Primary Question: Check Scope Selection
```typescript
AskUserQuestion({
  questions: [{
    question: "Please select the scope and focus of the i18n check",
    header: "Check Scope",
    multiSelect: true,
    options: [
      {
        label: "completeness",
        description: "Translation completeness (missing key detection, coverage calculation)"
      },
      {
        label: "consistency",
        description: "Terminology consistency (unified translation of same concepts, inconsistency detection)"
      },
      {
        label: "format",
        description: "Technical quality (placeholder validation, encoding)"
      },
      {
        label: "cultural",
        description: "Cultural adaptation (language appropriateness, date/time formats, idioms)"
      },
      {
        label: "documentation",
        description: "Documentation translation (README, guides, examples)"
      },
      {
        label: "complete",
        description: "All-perspective comprehensive check (takes time)"
      }
    ]
  }]
})
```

### Secondary Question: Target Language Selection
```typescript
AskUserQuestion({
  questions: [{
    question: "Select languages to check (leave blank for all languages)",
    header: "Target Languages",
    multiSelect: true,
    options: [
      { label: "all", description: "All languages (all supported languages)" },
      { label: "en", description: "English" },
      { label: "ja", description: "Japanese (日本語)" },
      { label: "zh-CN", description: "Simplified Chinese (简体中文)" },
      { label: "zh-TW", description: "Traditional Chinese (繁體中文)" }
    ]
  }]
})
```

## Analysis Tasks

### 1. **Translation Completeness**
```bash
# Automated completeness check
echo "Translation Completeness Analysis:"

# Extract all keys from base language (usually English)
BASE_LANG_FILE="locales/en/common.json"  # Auto-detect
if [[ -f "$BASE_LANG_FILE" ]]; then
    BASE_KEYS=$(jq -r 'keys[]' "$BASE_LANG_FILE" 2>/dev/null | wc -l)
    echo "Base language keys: $BASE_KEYS"
else
    echo "Base language file not found, scanning for reference..."
    BASE_LANG_FILE=$(find . -name "*.json" -path "*/locales/en/*" -o -path "*/i18n/en/*" | head -1)
fi

# Compare keys across all languages
for lang_file in locales/*/common.json i18n/*/common.json; do
    if [[ -f "$lang_file" ]]; then
        LANG_CODE=$(basename $(dirname "$lang_file"))
        LANG_KEYS=$(jq -r 'keys[]' "$lang_file" 2>/dev/null | wc -l)
        COVERAGE=$((LANG_KEYS * 100 / BASE_KEYS))
        echo "$LANG_CODE: $LANG_KEYS/$BASE_KEYS keys ($COVERAGE%)"
    fi
done
```

Analysis steps:
1. Extract all message keys from translation files
2. Compare keys across all supported languages
3. Report missing translations per language
4. Calculate coverage percentage

### 2. **Terminology Consistency**
```bash
# Automated consistency check
echo "Terminology Consistency Analysis:"

# Check for inconsistent translations
for term in "button" "error" "success" "cancel"; do
    echo "Term: $term"
    grep -r "\"$term\":" locales/ i18n/ 2>/dev/null | head -3
done

# Detect ambiguous translations
echo "Ambiguous Translation Detection:"
# Find same key with different values across languages
# (requires custom script based on project structure)
```

Analysis steps:
1. Check for inconsistent translations of same concept
2. Verify technical terms are translated consistently
3. Flag ambiguous or conflicting translations

### 3. **Cultural Appropriateness**
```bash
# Cultural appropriateness check
echo "Cultural Appropriateness Analysis:"

# Date/time format check
grep -r "format.*date\|format.*time" locales/ i18n/ 2>/dev/null | head -3

# Number format check
grep -r "format.*number\|format.*currency" locales/ i18n/ 2>/dev/null | head -3

# Formal vs informal language detection
# (language-specific logic needed)
```

Analysis steps:
1. Review formal vs informal language choices
2. Check idioms and metaphors are culturally adapted
3. Verify date/time/number formats are locale-appropriate

### 4. **Technical Quality**
```bash
# Technical quality validation
echo "Technical Quality Validation:"

# Validate placeholder syntax
echo "Placeholder validation:"
grep -r "\{[0-9]\+\}\|%s\|%d\|{{.*}}" locales/ i18n/ 2>/dev/null | wc -l

# Check for hardcoded user-facing strings
echo "Hardcoded string detection:"
grep -r "console\.log\|alert\|confirm" src/ --include="*.ts" --include="*.tsx" | grep -v "i18n\|t(" | head -3

# Verify UTF-8 encoding
echo "Encoding validation:"
find locales/ i18n/ -name "*.json" -exec file {} \; | grep -v "UTF-8" || echo "All files UTF-8"

# Test language switching functionality (manual test required)
echo "Language switching test required (manual)"
```

Analysis steps:
1. Validate placeholder syntax ({0}, {1}, etc.) preserved
2. Check for hardcoded user-facing strings
3. Verify UTF-8 encoding throughout
4. Test language switching functionality

### 5. **Documentation**
```bash
# Documentation translation check
echo "Documentation Translation Analysis:"

# Check README files for all languages
for lang in en ja zh-CN zh-TW; do
    if [[ -f "README.$lang.md" || -f "docs/README.$lang.md" ]]; then
        echo "README.$lang.md found"
    else
        echo "README.$lang.md missing"
    fi
done

# Verify user guides
find docs/ -name "*.md" 2>/dev/null | grep -E "(en|ja|zh)" | head -5

# Validate code examples (language-neutral check)
grep -r "```" docs/ 2>/dev/null | wc -l | sed 's/^/Code examples: /'
```

Analysis steps:
1. Check README files for all languages
2. Verify user guides are translated
3. Validate code examples work for all locales

## Error Handling & Validation

### Pre-check Validation
```bash
# Check i18n project structure (using common function)
I18N_DIR=$(detect_i18n_dir)
if [[ -z "$I18N_DIR" ]]; then
    echo "ERROR: No standard i18n directory detected"
    echo "File: i18n-check.md:pre_check_validation - Structure Detection"
    echo ""
    echo "Searching for translation files..."
    FOUND_FILES=$(find . -name "*.json" | grep -E "(locale|i18n|lang|translation)" | head -5)
    if [[ -n "$FOUND_FILES" ]]; then
        echo "Found potential translation files:"
        echo "$FOUND_FILES"
        echo ""
        echo "Suggestion: Move files to standard directory (locales/, i18n/, or lang/)"
    else
        echo "No translation files found"
        echo "Suggestion: Create i18n directory and add translation files"
    fi
    exit $EXIT_USER_ERROR
fi

# Verify translation file format (using common function with error handling)
echo "Validating JSON syntax..."
INVALID_FILES=""
for file in $(find_i18n_files "*.json"); do
    if [[ -f "$file" ]]; then
        if ! jq . "$file" >/dev/null 2>&1; then
            INVALID_FILES="${INVALID_FILES}${file}\n"
        fi
    fi
done

if [[ -n "$INVALID_FILES" ]]; then
    echo "ERROR: Invalid JSON detected in translation files"
    echo "File: i18n-check.md:pre_check_validation - JSON Validation"
    echo ""
    echo "Invalid files:"
    echo -e "$INVALID_FILES"
    echo ""
    echo "Suggestion: Run 'jq . <file>' to identify syntax errors"
    exit $EXIT_SYSTEM_ERROR
fi

# Check git repository status
if ! git status >/dev/null 2>&1; then
    echo "WARNING: Not a git repository"
    echo "File: i18n-check.md:pre_check_validation - Git Detection"
    echo ""
    echo "Git tracking recommended for translation file history"
fi
```

### Error Message Security

When reporting errors:
- Report only user-actionable information
- Do not expose absolute file paths (use relative paths from project root)
- Do not expose internal system details
- Provide clear guidance on how to fix the issue

Example secure error messages:
- "Invalid language code 'xyz'. Expected ISO 639-1 format (e.g., 'en', 'ja')"
- "Translation files not found in standard directories. Use --help for directory structure"
- "Invalid JSON in translation file. Run validation for details"

### Common Issues & Solutions

#### Issue: "Translation files not found"

Detect and auto-resolve:
```typescript
AskUserQuestion({
  questions: [{
    question: "Translation files not found. What would you like to do?",
    header: "File Detection",
    multiSelect: false,
    options: [
      { label: "auto-detect", description: "Auto-detect non-standard structure" },
      { label: "manual-specify", description: "Manually specify file paths" },
      { label: "create-structure", description: "Create standard i18n structure" },
      { label: "cancel", description: "Cancel check" }
    ]
  }]
})
```

#### Issue: "Invalid JSON format detected"

Recover from error:
```bash
# Automated JSON validation and repair suggestions
for file in locales/**/*.json i18n/**/*.json; do
    if ! jq . "$file" >/dev/null 2>&1; then
        echo "Invalid JSON: $file"
        echo "Error details:"
        jq . "$file" 2>&1 | head -3
        echo "Suggested action: Review file syntax"
    fi
done
```

#### Issue: "Encoding errors detected"

Fix encoding issues:
```bash
# Detect non-UTF-8 files
find locales/ i18n/ -name "*.json" -exec file {} \; | grep -v "UTF-8" > /tmp/encoding_issues.txt
if [[ -s /tmp/encoding_issues.txt ]]; then
    echo "Non-UTF-8 files detected:"
    cat /tmp/encoding_issues.txt
    echo "Recommended: Convert to UTF-8 encoding"
fi
```

## Output Format

Generate a detailed report in this format:

```markdown
## i18n Status Report

### Supported Languages
- English (en) - 100% complete (450/450 keys)
- Japanese (ja) - 100% complete (450/450 keys)
- Chinese Simplified (zh-CN) - 98% complete (441/450 keys)
- Chinese Traditional (zh-TW) - 98% complete (441/450 keys)

### Translation Coverage
- **Total message keys**: 450
- **Fully translated languages**: 2/4
- **Missing translations**:
  - zh-CN: 9 keys (buttons.advanced, errors.network.*, help.faq.q3)
  - zh-TW: 9 keys (buttons.advanced, errors.network.*, help.faq.q3)

### Terminology Consistency
- Technical terms: Consistent across all languages
- "button" translation: 3 different translations in ja (ボタン/釦/押しボタン)
- "error" translation: Inconsistent formality (エラー vs ご不便をおかけします)

### Cultural Appropriateness
- Date formats: Properly localized (en: MM/DD/YYYY, ja: YYYY年MM月DD日)
- Number formats: Correct decimal/thousand separators
- Formal language: Mixed formal/informal in ja (needs unification)
- Idioms: English idiom "piece of cake" literally translated in zh-CN

### Technical Quality
- Placeholder syntax: All {0}, {1} placeholders preserved
- Encoding: All files UTF-8
- Hardcoded strings: 12 instances found in src/components/
- Language switching: Not tested (manual testing required)

### Documentation
- README.en.md - Complete
- README.ja.md - Complete
- README.zh-CN.md - Outdated (last updated 3 months ago)
- README.zh-TW.md - Missing

### Issues Found
1. **Missing translations (Priority: High)**
   - 9 keys missing in zh-CN and zh-TW
   - Files: locales/zh-CN/common.json, locales/zh-TW/common.json
   - Impact: Users will see English fallback

2. **Terminology inconsistency (Priority: Medium)**
   - "button" has 3 different translations in Japanese
   - Recommended: Use consistent "ボタン" across all instances

3. **Hardcoded strings (Priority: High)**
   - 12 user-facing strings not using i18n
   - Files: src/components/Header.tsx, src/pages/Dashboard.tsx
   - Impact: Cannot be translated

4. **Cultural adaptation issue (Priority: Low)**
   - English idioms literally translated
   - Files: locales/zh-CN/messages.json
   - Recommended: Use culturally appropriate equivalents

### Recommendations
1. **Immediate Actions**
   - Complete missing translations in zh-CN and zh-TW
   - Replace hardcoded strings with i18n keys
   - Standardize "button" translation in Japanese

2. **Short-term Improvements**
   - Update outdated README.zh-CN.md
   - Create README.zh-TW.md
   - Review and adapt culturally inappropriate translations

3. **Long-term Maintenance**
   - Implement automated i18n testing in CI/CD
   - Create terminology glossary for consistency
   - Regular i18n audits (monthly)
```

## Agent Execution Strategy

Execute agents in sequence:

### Phase 1: Translation File Analysis
```bash
# Agent: code-reviewer
# Task: Analyze translation file structure and completeness
# Focus:
- Extract all translation files
- Parse JSON/YAML/PO formats
- Compare keys across languages
- Calculate coverage percentages
```

### Phase 2: Documentation Review
```bash
# Agent: documentation-engineer
# Task: Review translated documentation
# Focus:
- Check README files for all languages
- Verify user guide translations
- Validate code example compatibility
```

### Phase 3: Quality Analysis
```bash
# Agent: code-reviewer + security-auditor
# Task: Technical quality and security check
# Focus:
- Validate encoding (UTF-8)
- Check placeholder syntax
- Detect hardcoded strings
- Security: Verify no sensitive data in translation files
```

### Phase 4: Comprehensive Report
```bash
# Main agent: Consolidate all findings
# Task: Generate comprehensive status report
# Output:
- Structured markdown report
- Actionable recommendations
- Priority-ranked issues
```

## Execution Start

**Goal**: Achieve automated system for comprehensive analysis of all project i18n status, efficiently checking translation quality, completeness, and cultural adaptation

Arguments: $ARGUMENTS

Parse arguments to identify check scope and target languages, auto-detect project i18n structure.

## Exit Code System

```bash
# 0: Success - i18n check completed, report generated
# 1: User error - Invalid language code, no translation files found
# 2: Security error - Path traversal detected, validation failure
# 3: System error - JSON parsing failed, jq not available
# 4: Unrecoverable error - Critical i18n structure corruption
```

## Output Format Examples

**Success example**:
```
✓ i18n check completed
✓ Languages analyzed: 4 (en, ja, zh-CN, zh-TW)
✓ Translation coverage: 98% average

Key Findings:
  - Missing translations: 9 keys in zh-CN, zh-TW
  - Terminology consistency: 3 issues in Japanese
  - Technical quality: PASSED

Next steps:
  1. Complete missing translations
  2. Standardize terminology
  3. Update README.zh-CN.md
```

**Error example**:
```
ERROR: Invalid language code format
File: i18n-check.md:validate_language_code

Reason: Language code does not follow ISO 639-1 or BCP 47 format
Got: "xyz-123"
Expected: "en", "ja", "zh-CN", "zh-TW"

Suggestions:
1. Use 2-letter ISO 639-1 codes (en, ja)
2. Or BCP 47 format for regions (zh-CN, zh-TW)
3. Use --help to list supported language codes
```

## i18n Check Execution

Analyze current project i18n structure and launch appropriate specialized agents for comprehensive i18n check.
