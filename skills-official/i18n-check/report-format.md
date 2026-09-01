# i18n Status Report Template

Use this template when generating the final report in Step 5.
Fill in actual data from analysis results. Omit sections not covered by the selected scope.

---

```markdown
## i18n Status Report

**Project**: [project name]
**Check scope**: [completeness | consistency | format | cultural | documentation | complete]
**Target languages**: [list]
**Date**: [YYYY-MM-DD]

---

### Supported Languages

| Language | Code | Keys | Coverage | Status |
|----------|------|------|----------|--------|
| English  | en   | 450  | 100%     | Base   |
| Japanese | ja   | 448  | 99%      | OK     |
| Simplified Chinese | zh-CN | 441 | 98% | Needs update |
| Traditional Chinese | zh-TW | 430 | 96% | Needs update |

---

### Translation Coverage

- **Total keys (base language)**: 450
- **Fully translated languages**: 1 / 4
- **Missing translations**:
  - `zh-CN` (9 keys): `buttons.advanced`, `errors.network.timeout`, `help.faq.q3`
  - `zh-TW` (20 keys): see details below

---

### Terminology Consistency

- Technical terms: Consistent across all languages
- **Issues detected**:
  - `ja` "button" → 3 distinct translations found: `ボタン`, `釦`, `押しボタン`
    - Recommendation: Standardize to `ボタン`
  - `ja` "error" → Mixed formality: `エラー` (formal) vs `ご不便をおかけします` (very formal)
    - Recommendation: Use `エラー` consistently

---

### Technical Quality

- **Placeholder syntax**: All `{0}`, `{1}` placeholders preserved ✓
- **Encoding**: All files UTF-8 ✓
- **Hardcoded strings**: 12 instances found
  - `src/components/Header.tsx` (3 instances)
  - `src/pages/Dashboard.tsx` (9 instances)
  - Action: Replace with `t('key')` calls
- **Language switching**: Manual testing required

---

### Cultural Appropriateness

- Date formats: Properly localized ✓
  - `en`: MM/DD/YYYY
  - `ja`: YYYY年MM月DD日
- Number formats: Correct separators ✓
- **Issues**:
  - `zh-CN` `messages.json`: English idiom "piece of cake" literally translated
    - Recommendation: Use culturally appropriate equivalent `轻而易举`
  - `ja`: Mixed formal/informal tone in same file
    - Recommendation: Unify to polite form (です/ます)

---

### Documentation

| File | Status | Last Updated |
|------|--------|-------------|
| `README.en.md` | Complete | 2 days ago |
| `README.ja.md` | Complete | 1 week ago |
| `README.zh-CN.md` | Outdated | 3 months ago |
| `README.zh-TW.md` | Missing | — |

---

### Issues Found

#### HIGH Priority

1. **Missing translations** — 29 keys untranslated in `zh-CN` and `zh-TW`
   - Impact: Users see English fallback text
   - Files: `locales/zh-CN/common.json`, `locales/zh-TW/common.json`

2. **Hardcoded strings** — 12 user-facing strings bypass i18n system
   - Impact: Cannot be translated for any language
   - Files: `src/components/Header.tsx`, `src/pages/Dashboard.tsx`

#### MEDIUM Priority

3. **Terminology inconsistency** — "button" has 3 Japanese translations
   - Impact: Inconsistent user experience
   - Recommendation: Standardize to `ボタン`

4. **Outdated documentation** — `README.zh-CN.md` not updated in 3 months
   - Impact: Incorrect setup instructions for Chinese users

#### LOW Priority

5. **Cultural adaptation** — Literal idiom translation in `zh-CN`
   - Files: `locales/zh-CN/messages.json`
   - Recommendation: Use `轻而易举` instead of literal translation

---

### Recommendations

**Immediate (this sprint)**
- Complete missing translations in `zh-CN` and `zh-TW`
- Replace 12 hardcoded strings in `src/` with `t()` calls
- Standardize "button" translation to `ボタン` in all `ja` files

**Short-term (next sprint)**
- Update `README.zh-CN.md` to reflect current setup
- Create `README.zh-TW.md`
- Review and fix culturally inappropriate translations

**Long-term**
- Add i18n lint to CI/CD (e.g., `i18next-scanner` missing-key check)
- Create terminology glossary for consistent translations
- Schedule monthly i18n audits
```
