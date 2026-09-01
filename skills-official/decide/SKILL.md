---
name: decide
description: Framework-driven decision support for technology selection, feature prioritization, and architecture evaluation. Applies ICE/RICE scoring, Eisenhower Matrix, Pre-mortem, Spike, and First Principles to produce a conclusion-first recommendation. Use before implementation when comparing options, ranking a task list, or deciding what to build next.
argument-hint: "<question or options to evaluate>"
allowed-tools: Read AskUserQuestion
---

# /decide - Decision Support Command

Arguments: $ARGUMENTS

Purpose:
- Systematic decision making with quantitative frameworks
- Pre-implementation option comparison and idea generation
- Conclusion-first output with an explicit recommendation

Timing: before implementation, when comparing options.

## Execution Flow

1. Parse and validate $ARGUMENTS — see Argument Validation
2. Detect output format and framework — see Auto-Detection
3. Load scoring criteria from the reference file when scoring — see Framework Reference
4. Apply the selected framework and emit the matching output pattern — see Output Patterns

## Argument Validation

Parse $ARGUMENTS as plain text:
- Extract the question or the option list
- Detect output format and framework per Auto-Detection

$ARGUMENTS is never passed to a shell, a file path, or a URL — it is analyzed as text only. No sanitization beyond the checks below is required.

If $ARGUMENTS is empty:
  Use AskUserQuestion: "What options or question would you like to evaluate?"
  Accept the answer as the evaluation target and continue.

If $ARGUMENTS names no comparable candidate and no decision question (for example a single bare noun):
  Use AskUserQuestion to offer the interpretations you can act on (compare against an alternative / rank a list / evaluate necessity).
  If the user cancels: emit the user-error message from Error Handling and stop.

## Auto-Detection

Apply in order. The first matching row wins.

| Input pattern | Output format | Framework | Example |
|---|---|---|---|
| Numbered list `1. A 2. B 3. C` | Pattern C (rank all) | Eisenhower + ICE | "1. Dark mode 2. Export" |
| "A vs B", "which is better", "compare" | Pattern A (single) | ICE | "Zod vs Yup?" |
| "what to improve", "what to add", "priorities" | Pattern B (multiple) | ICE | "What tests to add?" |
| Architecture / system design / approach | Pattern D (single) | RICE + Pre-mortem | "microservices vs monolith" |
| Risk / uncertainty / low-confidence keywords | Pattern D (single) | RICE + Spike | "uncertain about scaling" |
| Technology / library / tool names | by candidate count | ICE | "validation library choice" |
| 3+ tasks or features | Pattern C | Eisenhower + ICE | Multiple feature list |
| No match | by candidate count | ICE + First Principles | General questions |

Candidate-count rule (used only by rows that say "by candidate count"):
- 2 or fewer candidates → Pattern A
- 3 or more candidates → Pattern B

Framework precedence when a row matches on both domain and shape: the row order above is the precedence. A numbered list of architecture options is Pattern C ranked with Eisenhower + ICE, not Pattern D.

## Framework Reference

Formulas — use these directly, no file read needed:

**ICE Score**: `(Impact × Confidence × Ease) / 3`
- Impact 1-10, Confidence 0-100% (use as 0.0-1.0), Ease 1-10 (10 = easiest)
- Priority: 20 and above = Highest, 10 to under 20 = High, 5 to under 10 = Medium, under 5 = Low

**RICE Score**: `(Reach × Impact × Confidence) / Effort`
- Reach = users or executions per period, Impact ∈ {0.25, 0.5, 1, 2, 3}, Effort = person-months
- Priority: relative ranking within the candidate set (top 20% = highest)

**Eisenhower Matrix**: Q1 urgent+important = do now, Q2 important only = schedule, Q3 urgent only = delegate, Q4 neither = drop

**First Principles**: state the premise, decompose it, rebuild from fundamentals, decide MUST / YAGNI / CONDITIONAL

Read `${CLAUDE_SKILL_DIR}/frameworks.md` when — and only when — you need any of:
- Impact / Ease / Confidence rating rubrics (before assigning numeric scores)
- The Pre-mortem procedure (Pattern D, architecture decisions)
- The Spike procedure (Pattern D, Confidence below 50%)
- Eisenhower urgency and importance criteria (Pattern C)
- Scoring anti-patterns, when a score looks implausible

Do not read it for a Pattern A comparison whose scores you can already justify from the formulas above.

If the file cannot be read: state `NOTE: frameworks.md unavailable — scoring rubric not applied` in the output, score from the formulas above, and continue. This is not a fatal error.

## Output Patterns

All patterns are conclusion-first: recommendation and reason before analysis.

### Pattern A: Single Recommendation

Used when comparing 2 candidates or an explicit "A vs B" question.

```
## Conclusion: [Option] is recommended

Reason: ICE Score [value] ([priority level]). [1-2 sentence rationale]

## Detailed Analysis

### ICE Score Evaluation
[Comparison table: Option | Impact | Confidence | Ease | ICE Score]
[Rationale per axis]

### First Principles Verification
[Premise / decomposition / decision]

### Alternative Comparison
[Cost-benefit table]

### Risk Assessment
[Security / Technical / Development — see Risk Assessment Template]

### Final Recommendation
[Action items]
```

### Pattern B: Multiple Proposals

Used for "what to improve" / "what should we do" questions.

If more than 10 candidates: rank by Impact alone to reach a shortlist of 10, then apply full ICE to that shortlist. Report the final 3-5 in the conclusion regardless of shortlist size, and state how many candidates were dropped at the Impact-only stage.

```
## Conclusion: Implement in the following order

1. [Proposal] (ICE [score]) - Highest priority
   Reason: [Impact / Confidence / Ease rationale]
2. [Proposal] (ICE [score]) - High priority
   Reason: [...]
3. [Proposal] (ICE [score]) - Medium priority
   Reason: [...]

Recommended action: [scope for the current sprint]

## Detailed Analysis

### ICE Score Evaluation (shortlist)
[Comparison table]

### First Principles Verification (top 3)
### Risk Assessment (top 3)
### Final Recommendation
[Categorize: Immediate / Next sprint / Backlog / Reject]
```

### Pattern C: Prioritization

Used when $ARGUMENTS contains a numbered list, or 3+ tasks.

```
## Conclusion: Priority ranking

1. [Task] (ICE [score]) - Immediate
2. [Task] (ICE [score]) - Next sprint
3. [Task] (ICE [score]) - Rejected (YAGNI)

Reason: [Eisenhower + ICE + First Principles integration]

## Detailed Analysis

### Phase 1: Eisenhower Matrix (rough filter)
[Quadrant table]

### Phase 2: ICE Score (detailed evaluation)
[Comparison table]

### Phase 3: First Principles Verification (top 3)
### Final Priority
[Categorized action plan]
```

### Pattern D: Architecture / High-Uncertainty Decision

Used for architecture and approach decisions, and for decisions whose Confidence is below 50%.

Score with RICE, not ICE — architecture decisions differ mainly in Effort and blast radius, which ICE's Ease axis flattens.

```
## Conclusion: [Option] is recommended
[or] ## Conclusion: Decision deferred — run a Spike first

Reason: RICE [value], [rank] of [n]. [1-2 sentence rationale]

## Detailed Analysis

### RICE Score Evaluation
[Table: Option | Reach | Impact | Confidence | Effort | RICE]
[Rationale per axis, Effort in person-months]

### Pre-mortem (recommended option)
[3-5 failure scenarios, each with probability / detectability / mitigation]
[If any scenario has no viable mitigation: recommend the runner-up instead]

### Spike Plan (only when Confidence < 50%)
Question: [one sentence]
Success criteria: [numeric]
Timebox: [1-3 days]
Confidence after: re-evaluate and re-run this skill

### Risk Assessment
### Final Recommendation
[Action items, including the reversal cost of this decision]
```

## Scoring Requirements

Every score carries a rationale:
- **Impact**: the specific effect on system or users
- **Confidence**: the evidence source (past case, data, or stated reasoning)
- **Ease / Effort**: a time estimate and a complexity note

Compute every score with the formula in Framework Reference and show the arithmetic operands in the table. A stated score that does not match its own operands is a defect.

Apply First Principles to the top candidates before recommending: a high score is not proof of necessity. Decide MUST / YAGNI / CONDITIONAL.

### Risk Assessment Template

```
Security Risk:    [HIGH/MEDIUM/LOW] - [details] - Mitigation: [...]
Technical Risk:   [HIGH/MEDIUM/LOW] - [details] - Mitigation: [...]
Development Risk: [HIGH/MEDIUM/LOW] - [details] - Mitigation: [...]
```

### Final Recommendation Contents

Include implementation steps, success metrics, and a rollback or reversal path.

## Error Handling

**Success**: Conclusion + Detailed Analysis + Final Recommendation.

**User error** (no evaluation target, or user cancelled the clarification):
```
ERROR: No evaluation target specified (Section: Argument Validation)
Provide options or a question to evaluate, e.g. /decide "Zod vs Yup?"
```

**Tool failure** (AskUserQuestion unavailable):
```
ERROR: AskUserQuestion tool failed (Section: Argument Validation)
Re-run with the evaluation target as an argument, e.g. /decide "Zod vs Yup?"
```

**Degraded** (frameworks.md unreadable): not an error. Emit the NOTE line from Framework Reference and continue with the formulas.

Never include absolute paths, file system details, or tool output in these messages.

## Examples

### Example 1: Technology Selection

Input: `/decide "Data validation library choice. Zod vs Yup?"`

Detection: "vs" → Pattern A; library names → ICE.

```
## Conclusion: Zod is recommended

Reason: ICE Score 21.6 (Highest priority). Superior type inference and
seamless TypeScript integration outweigh Yup's larger install base.

## Detailed Analysis

### ICE Score Evaluation
| Option | Impact | Confidence | Ease | ICE Score |
|--------|--------|------------|------|-----------|
| Zod    | 8      | 90%        | 9    | 21.6      |
| Yup    | 7      | 85%        | 8    | 15.9      |

Impact rationale:
- Zod: type inference removes duplicate type declarations (8/10)
- Yup: established library, wide adoption (7/10)

Confidence rationale:
- Zod: 90% - migration cases documented in the ecosystem
- Yup: 85% - proven track record, well-known patterns
```

### Example 2: Feature Prioritization

Input: `/decide "What tests should we add to improve coverage?"`

Detection: "what to add" → Pattern B; testing domain → ICE.

```
## Conclusion: Implement in the following order

1. Integration tests for API endpoints (ICE 14.0) - High priority
   Reason: Impact 8, Confidence 75%, Ease 7 → (8 × 0.75 × 7) / 3

2. Unit tests for utility functions (ICE 12.8) - High priority
   Reason: Impact 6, Confidence 80%, Ease 8 → (6 × 0.80 × 8) / 3

3. E2E tests for checkout flow (ICE 10.5) - High priority
   Reason: Impact 9, Confidence 70%, Ease 5 → (9 × 0.70 × 5) / 3

Recommended action: implement the top 2 in the current sprint
```

### Example 3: Task Prioritization

Input: `/decide "Priority for these features: 1. Dark mode 2. Export 3. Notifications"`

Detection: numbered list → Pattern C; Eisenhower + ICE.

```
## Conclusion: Priority ranking

1. Notifications (ICE 18.0) - Immediate (Q1: urgent and important)
2. Export (ICE 12.5) - Next sprint (Q2: important, not urgent)
3. Dark mode (ICE 8.0) - Rejected (YAGNI - cosmetic preference)

Reason: Notifications drive user engagement, Export unblocks a critical
workflow, Dark mode changes no user outcome.
```

### Example 4: Architecture Decision

Input: `/decide "Should we split the monolith into microservices?"`

Detection: architecture keywords → Pattern D; RICE + Pre-mortem.

```
## Conclusion: Modular monolith is recommended

Reason: RICE 96, rank 1 of 2. Microservices cost 5x the Effort without a
matching Reach gain at current scale.

### RICE Score Evaluation
| Option           | Reach | Impact | Confidence | Effort | RICE |
|------------------|-------|--------|------------|--------|------|
| Modular monolith | 120   | 2      | 60%        | 1.5    | 96   |
| Microservices    | 120   | 2      | 50%        | 8.0    | 15   |

Effort rationale: monolith module boundaries are an in-place refactor
(1.5 person-months); microservices add deploy, discovery, and observability
infrastructure (8 person-months).

### Pre-mortem (microservices, the rejected option)
- Distributed transactions break: probability HIGH, detectability LOW
  (surfaces as data inconsistency after deploy) - no viable mitigation
  at current team size → decisive against adoption
```

### Example 5: Missing Argument

Input: `/decide`

Action: AskUserQuestion — "What options or question would you like to evaluate?"
If the user cancels:
```
ERROR: No evaluation target specified (Section: Argument Validation)
Provide options or a question to evaluate, e.g. /decide "Zod vs Yup?"
```
