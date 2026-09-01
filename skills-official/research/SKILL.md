---
name: research
description: "Systematic technology research with multi-source validation and knowledge documentation"
argument-hint: "[research-topic]"
allowed-tools: Bash Read Write Edit Grep TodoWrite AskUserQuestion Agent WebFetch WebSearch
model: sonnet
---


# Technology Research Command

Research target: $ARGUMENTS

Systematic research workflow for technology evaluation, implementation patterns, and trend analysis.

## Argument Validation and Sanitization

Parse and validate $ARGUMENTS with security-first approach.

**Validation rules (LLM instruction — not executable shell):**

```
TOPIC = $ARGUMENTS (treat entire argument string as the topic)

Reject if:
- Empty: report "Research topic required. Usage: /research <topic>"
- Contains / \ : * ? " < > | → report "Invalid characters in research topic"
- Length > 200 characters → report "Topic too long (max 200 characters)"

For any WebFetch URL:
- Reject file://, ftp://, telnet:// → report "Unsafe protocol"
- Auto-upgrade http:// → https://
```

## Execution Flow

1. Parse and validate research topic with strict input sanitization
2. Create tasks with TodoWrite for research phases
3. Execute systematic information gathering with source validation
4. Cross-reference findings from multiple sources
5. Generate structured research report

## Research Methodologies

Apply the pattern matching the research type:

- **Technology Comparison**: define evaluation axes first, then score each candidate on the same axes; record which axes were decisive
- **Implementation Research**: locate the official docs, then at least one production example; note version drift between them
- **Trend Analysis**: distinguish adoption signals (downloads, releases, maintainer activity) from opinion signals (blog posts, social)

## WebFetch/WebSearch Error Handling

Execute with comprehensive error detection (LLM instruction — pseudocode, not executable shell):

```
fetch_documentation() {
  local url="$1"
  local output_file="$2"
  local max_retries=3
  local retry_count=0

  Retry up to 3 times:
    Call WebFetch with url and prompt="Extract main content and code examples"
    If success: return result

    If rate limit (429):
      Report "Rate limit exceeded. URL: {url}. Retry: {n}/3. Wait: 60s"
      Wait 60 seconds before retry
    Else:
      Report "WebFetch failed. URL: {url}. Retry: {n}/3"
      Wait n*10 seconds before retry

  If all retries exhausted:
    Report "WebFetch failed after 3 retries. Check URL validity and network."
    Return error code 3
}

search_implementations(query):
  Call WebSearch with query
  If WebSearch fails:
    Report "WebSearch failed. Query: {query}"
    Report "Suggestion: Simplify query or check network"
    Return error code 3
```

## Documentation Structure

Research report template:

```markdown
# Research Report: [Topic]

**Date**: [YYYY-MM-DD]
**Research Type**: [technology-comparison/implementation/trend-analysis]
**Research Depth**: [surface/detailed/comprehensive/experimental]

## Executive Summary
[3-4 sentence summary of key findings and recommendations]

## Research Objectives
- [Primary research question]
- [Secondary questions]
- [Success criteria]

## Methodology
- **Information Sources**: [List of sources with credibility scores]
- **Research Approach**: [Methodology used]
- **Validation Method**: [Cross-reference, experimental validation]

## Key Findings
### Finding 1
- **Details**: [Explanation with evidence]
- **Evidence**: [Source citations with URLs]
- **Implications**: [Project impact assessment]

## Technology Analysis
### Advantages
- [Benefits with supporting evidence and sources]

### Disadvantages
- [Limitations with evidence and sources]

### Trade-offs
- [Analysis with specific recommendations]

## Recommendations
### Immediate Actions
- [Short-term actionable steps]

### Long-term Strategy
- [Strategic recommendations with timeline]

### Risk Mitigation
- [Identified risks and specific mitigation strategies]

## References
- [Source 1]: [URL] (Credibility: X/10)
- [Source 2]: [URL] (Credibility: X/10)
```

## Tool Usage

TodoWrite: Create tasks for research workflow phases
- Phase 1: Information gathering
- Phase 2: Source validation and cross-reference
- Phase 3: Analysis and synthesis
- Phase 4: Report generation

Mark each phase in_progress when starting, completed when done (TodoWrite).

AskUserQuestion: If $ARGUMENTS is empty, ask for research depth before starting:
- "Quick overview" — Surface-level (15-30 min, 1-2 sources)
- "Detailed analysis" — Comprehensive (1-2 hours, 5+ sources)
- "Experimental" — Hands-on proof-of-concept (1-2 days)

Agent: Complex exploration and analysis
WebFetch: Official documentation and technical resources
WebSearch: Community content and implementation examples
Write: Create research documentation

## Error Handling

**Invalid topic or missing arguments**:
- Report required format with examples
- Suggest topic templates

**WebFetch rate limit**:
- Implement exponential backoff (60s, 120s, 180s)
- Retry up to 3 times
- Report rate limit status and wait time

**URL validation failure**:
- Report unsafe protocol or invalid format
- Suggest corrected HTTPS URL

**Network failure**:
- Check connectivity
- Provide offline alternatives (cached docs, local examples)
- Suggest retry with simpler query

**File write failure**:
- Check permissions and disk space
- Report target directory and file path
- Suggest alternative output location

Error message format:
```bash
echo "ERROR [research.md:LINE]: Error description"
echo "  Context: Additional information"
echo "  Suggestion: User-actionable fix"
```

Security:
- Never expose absolute file paths
- Report only relative paths from project root
- Sanitize topic for file system safety

## Exit Codes

- 0: Success - Research completed, documentation generated
- 1: User error - Invalid topic, missing arguments, topic too long
- 2: Security error - Unsafe URL protocol, invalid characters in topic
- 3: Network error - WebFetch/WebSearch failure, rate limit exceeded
- 4: System error - File write failure, unrecoverable error

## Examples

```bash
# Technology comparison research
/research "Next.js 15 new features"

# Implementation pattern research
/research "React Server Components patterns"

# Interactive mode with depth selection
/research
```
