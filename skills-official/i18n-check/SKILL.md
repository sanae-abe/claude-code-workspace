---
name: i18n-check
description: >
  Comprehensive i18n status check: translation completeness, terminology consistency,
  cultural adaptation, and technical quality. Use when asked to check i18n, verify
  translations, audit localization coverage, or find missing translation keys.
---

# i18n Completeness Check

Comprehensive internationalization (i18n) status check for any project.

Usage: `/i18n-check [language-code] [options]`

Examples:
- `/i18n-check` — Full check for all languages
- `/i18n-check --coverage` — Coverage-focused analysis
- `/i18n-check ja --consistency` — Japanese terminology consistency
- `/i18n-check --cultural` — Cultural adaptation review

## Current i18n Project State

- Translation files: !`find . \( -path "*/locales/*" -o -path "*/i18n/*" -o -path "*/lang/*" \) \( -name "*.json" -o -name "*.yaml" -o -name "*.po" \) 2>/dev/null | wc -l || echo "0"` files found
- i18n Library: !`grep -E "i18next|vue-i18n|react-intl|gettext" package.json 2>/dev/null | head -1 || echo "Not detected"`
- Supported languages: !`ls -1 locales/ i18n/ lang/ 2>/dev/null | head -20 || echo "No standard i18n directory"`
- Recent translations: !`git log --oneline --since="1 week ago" -- "**/locales/**" "**/i18n/**" 2>/dev/null | head -3 || echo "No recent updates"`
- Uncommitted changes: !`git status --porcelain 2>/dev/null | grep -E "(locales|i18n|lang)" | wc -l || echo "0"` files

## Execution Flow

### Step 1: Parse Arguments

Parse `$ARGUMENTS`:
- **Language code** (first non-flag token): validate against `^[a-z]{2}(-[A-Z]{2})?$`
- **Check flag**: must be one of `--coverage`, `--consistency`, `--format`, `--cultural`, `--complete`

Validation rules:
- Language code doesn't match pattern → report expected format (ISO 639-1 / BCP 47) and stop
- Flag not in allowed list → report available flags and stop
- Argument contains `..` or special chars → report security error and stop

### Step 2: Detect i18n Structure

Check for i18n directories in order: `locales/`, `i18n/`, `lang/`, `public/locales/`

```bash
for dir in locales i18n lang public/locales; do
  [ -d "$dir" ] && echo "Found: $dir" && break
done
```

If no directory found: use AskUserQuestion to offer recovery options:
- Question: "翻訳ファイルが標準ディレクトリに見つかりません。どうしますか？"
- Header: "File Detection"
- multiSelect: false
- Options: auto-detect（非標準構造を自動探索） / specify（パスを手動指定） / cancel

Validate JSON syntax for all detected `.json` translation files using `jq`. If any are invalid, report relative file path with fix suggestion (`jq . <file>`) and stop.

### Step 3: Select Check Scope

If `$ARGUMENTS` contains a valid flag, use it directly.

Otherwise use AskUserQuestion:
- Question: "チェックするスコープを選択してください"
- Header: "Check Scope"
- multiSelect: true
- Options:
  - `completeness` — 翻訳完全性（欠落キー検出・カバレッジ計算）
  - `consistency` — 用語統一性（同一概念の訳語ゆれ検出）
  - `format` — 技術品質（プレースホルダー検証・エンコーディング確認）
  - `cultural` — 文化的適応（日時フォーマット・イディオム確認）
  - `documentation` — ドキュメント翻訳（README・ガイド確認）
  - `complete` — 全観点の包括的チェック

Then confirm target languages with AskUserQuestion:
- Question: "チェック対象の言語を選択してください（all=全言語）"
- Header: "Target Languages"
- multiSelect: true
- Options: Populate dynamically from detected language directories + `all` option

### Step 4: Execute Analysis

Use TodoWrite to track analysis tasks:
1. Translation file analysis
2. Documentation review (if `documentation` or `complete`)
3. Technical quality check (if `format` or `complete`)
4. Compile report

Run analysis scripts from `${CLAUDE_SKILL_DIR}/analysis.md` based on selected scope. Key scripts:

**Completeness** — Compare key count across all languages vs base language (usually `en`).
Record coverage percentage per language and list missing keys.

**Consistency** — Search for same-concept terms with different translations.
Flag cases where identical keys have more than one distinct value across files.

**Format** — Validate placeholder syntax (`{0}`, `{name}`, `%s`), check UTF-8 encoding,
detect hardcoded user-facing strings in `src/` that bypass i18n.

**Cultural** — Verify locale-appropriate date/time/number formats,
detect idioms that may be literally translated, check formal/informal language mixing.

**Documentation** — Check README files for each detected language, verify docs/ coverage.

### Step 5: Generate Report

Output a structured report using the template in `${CLAUDE_SKILL_DIR}/report-format.md`.

Prioritize issues:
- **HIGH**: Missing translations affecting production users, hardcoded strings
- **MEDIUM**: Terminology inconsistency, outdated documentation
- **LOW**: Cultural adaptation issues, minor formatting inconsistencies

## Error Handling

| Situation | Action |
|-----------|--------|
| Invalid language code | Report expected format with example, stop |
| Flag not in allowed list | List valid flags, stop |
| Path traversal in argument | Report security error, stop |
| No i18n directory found | AskUserQuestion: auto-detect / specify / cancel |
| Invalid JSON in file | Report relative filename + `jq . <file>` fix, stop |
| `jq` not installed | Report "`jq` required", suggest `brew install jq`, stop |
| Not a git repository | Warn (non-fatal), continue without git history |

Error message rules:
- Relative paths only (never absolute)
- User-actionable guidance always included
- No stack traces or internal system details

## Examples

```
/i18n-check                    → AskUserQuestion for scope and languages
/i18n-check --coverage         → Coverage analysis for all languages
/i18n-check ja --consistency   → Japanese terminology consistency
/i18n-check --complete         → Full analysis, all languages
/i18n-check xyz                → Error: invalid language code format
/i18n-check --unknown          → Error: unknown flag, list valid flags
```
