---
name: decide
description: Zero-dependency decision support using embedded frameworks (ICE/RICE/First Principles)
---

<!-- Original metadata:
  allowed-tools: AskUserQuestion
  argument-hint: "<question-or-options>"
  model: sonnet
-->


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

Sanitize $ARGUMENTS:
- No sanitization needed - Read/AskUserQuestion tools only
- $ARGUMENTS used only as plain text input to AskUserQuestion
- No Bash execution, no file path processing
- Risk: Minimal - tools have built-in validation

If $ARGUMENTS empty or unclear:
- Use AskUserQuestion to clarify evaluation target
- Example: "What options or question would you like to evaluate?"

Security:
- No file path processing required
- No Bash execution needed
- All frameworks embedded in skill (no external file access)

### Implementation Example

```bash
# Parse $ARGUMENTS
IFS=' ' read -r -a args <<< "$ARGUMENTS"

QUESTION=""
for arg in "${args[@]}"; do
    if [[ -z "$QUESTION" ]]; then
        QUESTION="$arg"
    fi
done

# Detect output format
if [[ "$QUESTION" =~ "vs"|"compare" ]]; then
    OUTPUT_FORMAT="single"
elif [[ "$QUESTION" =~ "what to"|"priorities" ]]; then
    OUTPUT_FORMAT="multiple"
elif [[ "$QUESTION" =~ ^[0-9]+\. ]]; then
    OUTPUT_FORMAT="prioritization"
else
    # Auto-decide based on candidate count
    OUTPUT_FORMAT="auto"
fi

# Detect framework type
if [[ "$QUESTION" =~ library|framework|tool ]]; then
    FRAMEWORK="ice"
elif [[ "$QUESTION" =~ architecture|design|approach ]]; then
    FRAMEWORK="rice"
elif [[ "$QUESTION" =~ risk|uncertain|confidence ]]; then
    FRAMEWORK="confidence"
else
    FRAMEWORK="ice"  # Default
fi
```

Note: This is reference syntax for LLM understanding. decide.md does not execute Bash - it uses Read/AskUserQuestion tools only.

## Auto-Detection Logic

### Decision Table

| Input Pattern | Output Format | Framework | Example | Line Ref |
|---------------|---------------|-----------|---------|----------|
| "A vs B", "which is better", "compare" | Single recommendation | ICE Score | "Zod vs Yup?" | 56 |
| "what to improve", "what to add", "priorities" | Multiple proposals (top 3-5) | ICE Score | "What tests to add?" | 59 |
| Numbered list "1. A 2. B 3. C" | Prioritization (rank all) | Eisenhower + ICE | "1. Dark mode 2. Export" | 62 |
| Technology/library/tool names | (auto-detect format) | ICE Score | "validation library choice" | 71 |
| Architecture/system design/approach | (auto-detect format) | RICE + Pre-mortem | "microservices vs monolith" | 74 |
| Risk/uncertainty/confidence keywords | (auto-detect format) | Confidence + Spike | "uncertain about scaling" | 77 |
| 3+ tasks or features | (auto-detect format) | Eisenhower + ICE | Multiple feature list | 80 |
| Default (no match) | auto-decide by candidate count | ICE + First Principles | General questions | 83 |

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

**詳細な評価基準・ワークフロー・アンチパターン**: `frameworks.md` 参照


## Error Handling

### Empty $ARGUMENTS Handling

```bash
# Pattern for LLM to follow
if [[ -z "$ARGUMENTS" ]]; then
    # Use AskUserQuestion tool (not Bash)
    # AskUserQuestion({
    #   questions: [{
    #     question: "What options or question would you like to evaluate?",
    #     header: "Decision Target",
    #     multiSelect: false,
    #     options: [...]
    #   }]
    # })

    # If user cancels:
    echo "ERROR: No evaluation target specified"
    echo "File: decide.md:44 - Argument Validation"
    echo ""
    echo "Operation cancelled by user"
    exit 1
fi
```

LLM implementation:
- Check if $ARGUMENTS is empty
- Use AskUserQuestion tool for interactive input
- If cancelled, exit with code 1 (User error)

### Invalid Framework Detection

```
IF detected framework is unclear:
    echo "WARNING: Ambiguous input pattern"
    echo "File: decide.md:92 - Auto-Detection Logic"
    echo ""
    echo "Defaulting to ICE Score + First Principles framework"
    echo "For explicit framework selection, use keywords:"
    echo "  - Technology selection: mention library/framework/tool names"
    echo "  - Architecture: mention design/approach/system"
    echo "  - Risk assessment: mention uncertainty/confidence/risk"
```

LLM implementation:
- Always provide a default framework (ICE + First Principles)
- Warn user if pattern matching is ambiguous
- Continue with analysis using default

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

**Large Option Handling** (10+ items):
```
IF option count >= 10:
  Phase 1: Quick filter with Impact-only score
    - Evaluate Impact (1-10) for all options
    - Keep top 20 options

  Phase 2: Full ICE Score calculation
    - Apply Impact × Confidence × Ease to top 20
    - Rank by ICE Score

  Phase 3: First Principles for top 5 only
    - Detailed necessity verification
    - YAGNI principle application

Output:
  - Detailed table: Top 10 options only
  - Brief mention: Remaining options excluded (with count)

Complexity: O(m) for Phase 1 + O(20) for Phase 2 + O(5) for Phase 3
Where m = total option count
```

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

## Exit Code System

```bash
# 0: Success - Decision analysis completed with recommendation
# 1: User error - Arguments missing, unclear question, invalid input format
# 3: System error - Read tool failed, AskUserQuestion tool failed
```

### Usage in LLM Implementation

**Exit code 0 (Success)**:
```
IF analysis completed successfully:
    Output: Conclusion + Detailed Analysis + Final Recommendation
    Exit: 0
```

**Exit code 1 (User error)**:
```
IF $ARGUMENTS empty AND AskUserQuestion cancelled:
    Output: "ERROR: No evaluation target specified"
            "File: decide.md:44 - Argument Validation"
            "Operation cancelled by user"
    Exit: 1

IF $ARGUMENTS contains invalid characters (edge case):
    Output: "ERROR: Invalid input format"
            "File: decide.md:33 - Argument Validation"
            "Special characters or malformed input detected"
    Exit: 1
```

**Exit code 3 (System error)**:
```
IF Read tool unavailable (system failure):
    Output: "ERROR: Read tool failed"
            "File: decide.md:129 - Embedded Framework Access"
            "System error - retry or report issue"
    Exit: 3

IF AskUserQuestion tool fails (system error):
    Output: "ERROR: AskUserQuestion tool failed"
            "File: decide.md:44 - Interactive Input"
            "System error - retry or report issue"
    Exit: 3
```

### Exit Code Propagation Pattern

LLM should follow this pattern:

```typescript
// Pseudocode for LLM logic
try {
    // Step 1: Validate arguments
    if (isEmpty(ARGUMENTS)) {
        const answer = AskUserQuestion(...)
        if (cancelled) {
            reportError("No evaluation target", 1)
            return EXIT_CODE_1
        }
    }

    // Step 2: Load embedded frameworks
    // All frameworks are embedded in this skill (lines 126-388)
    // No external file reads required
    const frameworks = loadEmbeddedFrameworks()

    // Step 3: Perform analysis
    const result = analyzeWithFramework(ARGUMENTS, frameworks)

    // Step 4: Generate output
    outputResult(result)
    return EXIT_CODE_0

} catch (error) {
    reportSystemError(error)
    return EXIT_CODE_3
}
```

Key principles:
- Always return an exit code (0, 1, or 3)
- Include file:line references in all error messages
- Provide actionable resolution steps for errors
- User errors (1) are recoverable by user action
- System errors (3) require intervention or retry

## Output Format

**Success example**:
```
## Conclusion: Zod is recommended

Reason: ICE Score 18.2 (Highest priority). Superior type safety, better DX, seamless TypeScript integration.

## Detailed Analysis

### ICE Score Evaluation
| Option | Impact | Confidence | Ease | ICE Score |
|--------|--------|------------|------|-----------|
| Zod    | 8      | 90%        | 9    | 18.2      |
| Yup    | 7      | 85%        | 8    | 15.9      |

### Risk Assessment
Security Risk: LOW - Both options provide adequate validation
Technical Risk: LOW - Well-documented migration path
Development Efficiency Risk: LOW - Zod reduces boilerplate

### Final Recommendation
1. Implement Zod validation schemas
2. Migrate existing Yup schemas incrementally
3. Monitor bundle size impact
```

**Error example**:
```
ERROR: Invalid input format
File: decide.md:33 - Argument Validation

Reason: Input contains special characters or malformed syntax
Got: "Option A vs Option B @#$%"

Suggestions:
1. Remove special characters from input
2. Use plain text format
3. Example: "Option A vs Option B"
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

Reason: ICE Score 18.2 (Highest priority). Superior type safety,
better DX, seamless TypeScript integration.

## Detailed Analysis

### ICE Score Evaluation
| Option | Impact | Confidence | Ease | ICE Score |
|--------|--------|------------|------|-----------|
| Zod    | 8      | 90%        | 9    | 18.2      |
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

## Reference Documentation

**詳細なフレームワークガイド**: `frameworks.md` (同じディレクトリ内)

内容:
- フレームワーク選択ガイド（状況別推奨表）
- 詳細な評価基準（Confidence, Impact, Easeの10段階評価）
- 実践的ワークフロー（パターンA/B/C）
- 追加フレームワーク（SCAMPER, Jobs-to-be-Done）
- アンチパターン集（失敗例と対策）
- 計算テンプレート（YAMLフォーマット）

**使用方法**:
- 基本的な意思決定: SKILL.md内の埋め込みフレームワークで十分
- 詳細な評価基準が必要: frameworks.md参照
- 新しいフレームワーク学習: frameworks.md参照
