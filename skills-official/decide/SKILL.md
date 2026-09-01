---
name: decide
description: Zero-dependency decision support using embedded frameworks (ICE/RICE/First Principles)
allowed-tools: AskUserQuestion
---


# /decide - Decision Support Command

Arguments: $ARGUMENTS

Framework-driven decision support using ICE/RICE scoring, Eisenhower Matrix, and First Principles for technology selection, feature prioritization, and architecture evaluation.

Purpose:
- Systematic decision making with quantitative frameworks
- Pre-implementation option comparison and idea generation
- Conclusion-first format with clear recommendations

Timing: Before implementation, when comparing options

Output: Conclusion-first format with comparison tables

## Execution Flow

1. Parse and validate $ARGUMENTS
2. Auto-detect decision type and output format
3. Apply appropriate framework (ICE/RICE/Eisenhower/First Principles - embedded in this skill)
4. Generate conclusion-first output with detailed analysis

## Argument Validation

Parse $ARGUMENTS:
- Extract question or options text
- Detect output format (single recommendation vs multiple proposals)
- Detect framework type (tech selection vs prioritization vs architecture)

If $ARGUMENTS empty or unclear:
- Use AskUserQuestion to clarify evaluation target
- Example: "What options or question would you like to evaluate?"

Input sanitization: Not required (AskUserQuestion/text analysis only, no Bash/file paths)

### Detection Flow

Detect from $ARGUMENTS as plain text:
1. **Output format**: "vs"/"compare" → single recommendation; "what to"/"priorities" → multiple proposals; numbered list (`1. A 2. B`) → prioritization; otherwise auto-detect by candidate count (≤2 → single, 3+ → multiple)
2. **Framework**: library/framework/tool keywords → ICE; architecture/design/approach → RICE + Pre-mortem; risk/uncertain/confidence → Confidence-weighted ICE; default → ICE

## Auto-Detection Logic

### Decision Table

| Input Pattern | Output Format | Framework | Example |
|---------------|---------------|-----------|---------|
| "A vs B", "which is better", "compare" | Single recommendation | ICE Score | "Zod vs Yup?" |
| "what to improve", "what to add", "priorities" | Multiple proposals (top 3-5) | ICE Score | "What tests to add?" |
| Numbered list "1. A 2. B 3. C" | Prioritization (rank all) | Eisenhower + ICE | "1. Dark mode 2. Export" |
| Technology/library/tool names | (auto-detect format) | ICE Score | "validation library choice" |
| Architecture/system design/approach | (auto-detect format) | RICE + Pre-mortem | "microservices vs monolith" |
| Risk/uncertainty/confidence keywords | (auto-detect format) | Confidence + Spike | "uncertain about scaling" |
| 3+ tasks or features | (auto-detect format) | Eisenhower + ICE | Multiple feature list |
| Default (no match) | auto-decide by candidate count | ICE + First Principles | General questions |

Auto-decide logic for output format:
- 2 or fewer candidates → single recommendation
- 3+ candidates → multiple proposals

### Implementation Flow

```
Step 1: Detect output format from $ARGUMENTS
  - Check explicit patterns (vs/compare/improve/add)
  - Check for numbered lists
  - Apply auto-decide logic if no match

Step 2: Detect framework type from $ARGUMENTS
  - Check domain keywords (tech/architecture/risk)
  - Apply default framework if no match

Step 3: Apply selected framework and generate output
```

## Framework Reference (Quick Guide)

### Available Frameworks

**1. ICE Score**: `(Impact × Confidence × Ease) / 3`
- Impact: 1-10, Confidence: 0-100%, Ease: 1-10
- Priority: 20+ = Highest, 10-20 = High, 5-10 = Medium, <5 = Low

**2. RICE Score**: `(Reach × Impact × Confidence) / Effort`
- Reach: user count/frequency, Impact: 0.25-3, Effort: person-months
- Priority: Relative ranking (top 20% = highest)

**3. Eisenhower Matrix**: Urgent/Important quadrants
- Quadrant 1: Do now, Quadrant 2: Schedule, Quadrant 3: Delegate, Quadrant 4: Don't do

**4. First Principles**: Question assumptions, reconstruct from fundamentals
- Apply YAGNI principle, verify necessity

**詳細な評価基準・ワークフロー・アンチパターン**: 以下に展開済み

```!
cat "${CLAUDE_SKILL_DIR}/frameworks.md"
```



## Output Patterns

### Pattern A: Single Recommendation

Used when: Comparing 2 options or explicit "A vs B" question

Structure:
```
## Conclusion: [Recommended Option] is recommended

Reason: ICE Score [value] ([priority level]). [1-2 sentence rationale]

## Detailed Analysis

### ICE Score Evaluation
[Comparison table]

### First Principles Verification
[Premise decomposition]

### Alternative Comparison
[Cost/benefit table]

### Risk Assessment
[Security/Technical/Development risks]

### Final Recommendation
[Action items]
```

### Pattern B: Multiple Proposals

Used when: "What to improve?" or "What should we do?" questions

For 10+ items: use Impact-only score to narrow to top 10 first, then apply full ICE + First Principles to that subset.

Structure:
```
## Conclusion: Implement in following order

1. [Proposal 1] (ICE [score]) - Highest priority
   Reason: [Impact/Confidence/Ease rationale]

2. [Proposal 2] (ICE [score]) - High priority
   Reason: [Impact/Confidence/Ease rationale]

3. [Proposal 3] (ICE [score]) - Medium priority
   Reason: [Impact/Confidence/Ease rationale]

Recommended action: Implement top 2 in current sprint

## Detailed Analysis

### ICE Score Evaluation (All Candidates)
[Comparison table with 3-5 items]

### First Principles Verification (Top 3)
[Necessity verification for each]

### Risk Assessment (Top 3)
[Risks for each proposal]

### Final Recommendation
[Categorize: Immediate/Next sprint/Backlog/Reject]
```

### Pattern C: Prioritization

Used when: Numbered list provided in $ARGUMENTS

Structure:
```
## Conclusion: Priority ranking

1. [Task A] (ICE [score]) - Immediate
2. [Task B] (ICE [score]) - Next sprint
3. [Task C] (ICE [score]) - Rejected (YAGNI)

Reason: [Eisenhower Matrix + ICE Score + First Principles integration]

## Detailed Analysis

### Phase 1: Eisenhower Matrix (Rough Filter)
[Urgency/Importance quadrant table]

### Phase 2: ICE Score (Detailed Evaluation)
[Comparison table]

### Phase 3: First Principles Verification (Top 3)
[Necessity verification]

### Final Priority
[Categorized action plan]
```

## Framework Application

### Scoring Requirements

Always include rationale for each score:
- **Impact**: Specific effect on system/users
- **Confidence**: Evidence source (past cases, data, logical reasoning)
- **Ease**: Time estimate and complexity assessment

### First Principles Verification

For top candidates, apply YAGNI principle:
```
Premise → Decomposition → Reconstruction from fundamentals
Decision: MUST/YAGNI/CONDITIONAL
```

### Risk Assessment Template

For each top option:
```
Security Risk: [HIGH/MEDIUM/LOW] - [Details] - Mitigation: [...]
Technical Risk: [HIGH/MEDIUM/LOW] - [Details] - Mitigation: [...]
Development Risk: [HIGH/MEDIUM/LOW] - [Details] - Mitigation: [...]
```

## Output Requirements

### Conclusion-First Format

```
## Conclusion: [Clear recommendation]
Reason: [Score + key rationale in 1-2 sentences]

## Detailed Analysis
[Framework-specific analysis]
```

### Quality Standards

- **Numerical Justification**: Always include rationale (e.g., "Impact: 7 (100x/week, DX improvement)")
- **Confidence**: Use criteria from frameworks.md, avoid over-estimation
- **YAGNI Principle**: High score ≠ necessity, verify with First Principles
- **Action Items**: Include implementation steps, metrics, rollback strategy, post-check with /iterative-review

## Error Handling

Unclear $ARGUMENTS:
```
IF $ARGUMENTS empty OR ambiguous:
    Use AskUserQuestion for clarification
    Example: "Please specify options or question to evaluate"
```

## Relationship with /iterative-review

Role separation:

| Command | Purpose | Timing | Output Format |
|---------|---------|--------|---------------|
| /decide | Idea generation and decision making | Pre-implementation | Conclusion-first |
| /iterative-review | Multi-perspective review | Post-implementation | Round-by-round analysis |

Recommended workflow:
```
1. /decide "Zod vs Yup"
   → Conclusion: Zod recommended

2. Implement with Zod

3. /iterative-review src/validation/schema.ts
   → Quality check and refinement
```

## Error Output Format

**Success**: Conclusion + Detailed Analysis + Final Recommendation を出力

**User error** (引数不明・キャンセル):
```
ERROR: No evaluation target specified (Section: Argument Validation)
Operation cancelled by user
```

**Tool failure**:
```
ERROR: AskUserQuestion tool failed (Section: Argument Validation)
System error - retry or report issue
```


## Examples

### Example 1: Technology Selection

**Input**: `/decide "Data validation library choice. Zod vs Yup?"`

**Detection**:
- Pattern: "vs" → Single recommendation
- Domain: library names → ICE Score framework

**Expected Output**:
```
## Conclusion: Zod is recommended

Reason: ICE Score 21.6 (Highest priority). Superior type safety,
better DX, seamless TypeScript integration.

## Detailed Analysis

### ICE Score Evaluation
| Option | Impact | Confidence | Ease | ICE Score |
|--------|--------|------------|------|-----------|
| Zod    | 8      | 90%        | 9    | 21.6      |
| Yup    | 7      | 85%        | 8    | 15.9      |

Impact rationale:
- Zod: Type inference reduces boilerplate (8/10)
- Yup: Established library with wide adoption (7/10)

Confidence rationale:
- Zod: 90% - successful migration cases documented
- Yup: 85% - well-known patterns, proven track record
```

### Example 2: Feature Prioritization

**Input**: `/decide "What tests should we add to improve coverage?"`

**Detection**:
- Pattern: "what to add" → Multiple proposals
- Domain: testing → ICE Score framework

**Expected Output**:
```
## Conclusion: Implement in following order

1. Integration tests for API endpoints (ICE 16.5) - Highest priority
   Reason: High impact (8), high confidence (75%), moderate ease (7)

2. E2E tests for checkout flow (ICE 14.0) - High priority
   Reason: Critical path (9), medium confidence (70%), lower ease (5)

3. Unit tests for utility functions (ICE 12.0) - Medium priority
   Reason: Medium impact (6), high confidence (80%), high ease (8)
```

### Example 3: Task Prioritization

**Input**: `/decide "Priority for these features: 1. Dark mode 2. Export 3. Notifications"`

**Detection**:
- Pattern: numbered list → Prioritization
- Domain: features → Eisenhower Matrix + ICE Score

**Expected Output**:
```
## Conclusion: Priority ranking

1. Notifications (ICE 18.0) - Immediate (Urgent & Important)
2. Export (ICE 12.5) - Next sprint (Important, not urgent)
3. Dark mode (ICE 8.0) - Rejected (YAGNI - nice-to-have)

Reason: Notifications directly impact user engagement (high impact),
Export enables critical workflows, Dark mode is cosmetic preference.
```

### Example 4: Interactive Mode

**Input**: `/decide`

**Action**: Use AskUserQuestion to get evaluation target
- Question: "What options or question would you like to evaluate?"
- User provides input via "Other" option
- Proceed with detection and analysis

---

