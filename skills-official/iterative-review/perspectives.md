# Optional Review Perspectives

Read this file only when the resolved perspective list contains one of the seven
perspectives below. The four default perspectives (necessity, security,
performance, maintainability) are defined inline in SKILL.md — do not read this
file for them.

Each perspective below follows the same contract as the default ones:
key check items, an analysis method using Claude Code tools, and a result
expression. Report findings with `file:line` references at every priority level.

---

## accessibility

Key check items:
- **Semantic markup**: correct element for the role (`button` not `div onClick`), heading order
- **Keyboard operation**: every interactive element reachable and operable by keyboard; no focus traps
- **Focus visibility**: `:focus-visible` styles present; `outline: none` / `outline: 0` absent
- **Alternative text**: `alt` on informative images, `alt=""` on decorative ones
- ARIA: `aria-label` / `aria-describedby` only where semantics are insufficient; no redundant roles
- Color: state never encoded by color alone; contrast meets WCAG 2.2 AA
- Motion: `prefers-reduced-motion` respected
- Tap targets: minimum 24x24 CSS px

Analysis methods — use Claude Code tools:

```markdown
# Non-semantic interactive elements
Grep tool with pattern: "<div[^>]*onClick|<span[^>]*onClick"

# Focus suppression and missing alt text
Grep tool with pattern: "outline:\s*(none|0)|<img(?![^>]*alt=)"
```

Authority for the detailed rules: `~/.claude/rules/tech-stacks/css-coding-standards.md`
(chapters 1-2) and `~/.claude/rules/tech-stacks/frontend-web.md` (Accessibility).

Result expression:
- Critical: "Keyboard-inaccessible control at [file:line]. Fix: [concrete change]"
- Important: "Contrast [measured ratio] below AA at [file:line]"
- Minor: "Redundant ARIA role at [file:line]"

---

## i18n

Key check items:
- **Hardcoded strings**: user-visible text embedded in source instead of a message catalog
- **Key coverage**: keys referenced in code exist in every locale file
- **Formatting**: dates, numbers, and currency via `Intl` APIs, not manual formatting
- **Pluralization**: plural forms handled by ICU MessageFormat, not string concatenation
- Layout: text expansion tolerated (no fixed-width containers around translated text)
- RTL: logical CSS properties used instead of physical left/right
- Locale detection: explicit strategy and a defined fallback locale

Analysis methods — use Claude Code tools:

```markdown
# Candidate hardcoded UI strings in JSX
Grep tool with pattern: ">[A-Z][a-zA-Z ]{3,}<"

# Translation key usage, to cross-check against locale files
Grep tool with pattern: "t\(['\"]|\$t\(['\"]|i18nKey="
```

Then Glob `**/locales/**/*.json` (or the project's catalog path) and Read each
locale file to diff the key sets.

Result expression:
- Critical: "Untranslated user-facing string at [file:line]"
- Important: "Key '[key]' missing from locale [xx] ([file:line])"
- Minor: "Manual date formatting at [file:line]; use Intl.DateTimeFormat"

---

## testing

Key check items:
- **Coverage of behavior**: every public function / exported component has at least one test
- **Boundary cases**: empty, null, maximum, and error paths tested — not only the happy path
- **Test independence**: no shared mutable state; order-independent
- **Assertion quality**: assertions verify behavior, not mock call counts
- Mocking: no mocking of the unit under test; no test-only methods in production code
- Determinism: no arbitrary sleeps or wall-clock dependence
- Regression: each fixed bug has a test that fails without the fix

Analysis methods — use Claude Code tools:

```markdown
# Locate tests corresponding to the target
Glob tool with pattern: "**/*.{test,spec}.{ts,tsx,js,py,rs}"

# Timing-dependent and skipped tests
Grep tool with pattern: "setTimeout|sleep\(|\.skip\(|\.only\("
```

Result expression:
- Critical: "No test covers [function] at [file:line]"
- Important: "Only the happy path is tested for [function] ([file:line])"
- Minor: "Arbitrary timeout at [file:line]; poll for the condition instead"

---

## documentation

Key check items:
- **Public API documented**: every exported symbol has a purpose, parameters, and return described
- **Accuracy**: documented behavior matches the implementation
- **Runnable examples**: code samples compile / execute as written
- **Setup instructions**: prerequisites and first-run steps are complete
- Comments: explain *why*, not restate *what*
- Staleness: no references to removed options, files, or versions
- Links: internal links resolve

Analysis methods — use Claude Code tools:

```markdown
# Exported symbols lacking a preceding doc comment
Grep tool with pattern: "^export (function|const|class)"

# Stale markers
Grep tool with pattern: "TODO|FIXME|deprecated|@deprecated"
```

Resolve every path referenced by the documentation with Glob; unresolved paths
are findings.

Result expression:
- Critical: "Documented behavior at [file:line] contradicts implementation at [file:line]"
- Important: "Exported [symbol] undocumented at [file:line]"
- Minor: "Comment restates the code at [file:line]"

---

## consistency

Key check items:
- **Naming**: one convention per category, applied uniformly (casing, verb prefixes, file names)
- **Structural patterns**: comparable modules organized the same way
- **Error handling**: one strategy per layer, not mixed styles side by side
- **Import style**: consistent path aliases and ordering
- Formatting: matches the project formatter output
- API shape: comparable operations expose comparable signatures
- Vocabulary: one term per concept across code, UI text, and docs

Analysis methods — use Claude Code tools:

```markdown
# Mixed error-handling styles in one file
Grep tool with pattern: "try\s*\{|\.catch\(|Result<|\?\?"

# Mixed import styles
Grep tool with pattern: "^import .* from ['\"](\.\./|@/|~/)"
```

Compare the target against two sibling files found via Glob to establish the
prevailing convention before reporting a deviation.

Result expression:
- Important: "Deviates from the convention used in [sibling:line]: [difference] ([file:line])"
- Minor: "Two terms for one concept: '[A]' at [file:line], '[B]' at [file:line]"

---

## scalability

Key check items:
- **Growth behavior**: cost as input size grows (records, users, files) — identify the limiting factor
- **Statefulness**: in-process state that prevents running multiple instances
- **Unbounded accumulation**: caches, arrays, or maps with no eviction or size cap
- **Blocking work**: long synchronous operations on a request path
- Concurrency: shared resources without a locking or partitioning strategy
- Data access: full scans, missing indexes, unbounded result sets
- Backpressure: no limit on queue depth or concurrent in-flight work

Analysis methods — use Claude Code tools:

```markdown
# Unbounded fetches and in-process state
Grep tool with pattern: "findAll\(|SELECT \*|new Map\(\)|new Set\(\)|global\."

# Nested iteration over collections
Grep tool with pattern: "for .*\{[\s\S]*?for .*\{"
```

Authority for API-side limits: `~/.claude/rules/tech-stacks/backend-api.md`
(Performance, Caching).

Result expression:
- Critical: "Unbounded [structure] at [file:line] grows with [input]; add [cap/eviction]"
- Important: "Per-process state at [file:line] blocks horizontal scaling"
- Minor: "Query at [file:line] lacks a result limit"

---

## simplicity

Key check items:
- **Unused code**: exports, parameters, branches, and dependencies with no caller
- **Speculative generality**: abstraction serving exactly one implementation
- **Indirection depth**: layers that only forward calls
- **Redundant configuration**: options that are never set to a non-default value
- Control flow: nesting depth, negated conditions, flag parameters
- Dependencies: a library used for something the standard library covers
- Deletable surface: what could be removed with no behavior change

Analysis methods — use Claude Code tools:

```markdown
# Single-implementation abstractions and forwarding layers
Grep tool with pattern: "interface |abstract class|implements |extends "

# Deep nesting and flag parameters
Grep tool with pattern: "^\s{12,}(if|for|while)|: boolean\)"
```

For each candidate, Grep for its identifier across the project to confirm the
caller count before recommending removal.

Result expression:
- Important: "[symbol] at [file:line] has one implementation and one caller; inline it"
- Important: "Unused [export/parameter] at [file:line]; delete"
- Minor: "Nesting depth [N] at [file:line]; extract or use early return"

Overlap note: `simplicity` examines the implementation as written; `necessity`
(Round 0) asks whether the feature should exist at all. When both are selected,
report structural reduction under simplicity and feature-level deletion under
necessity — do not duplicate a finding across the two.
