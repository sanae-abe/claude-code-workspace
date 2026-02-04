---
allowed-tools: Bash, Read, Write, Edit, Grep, TodoWrite, AskUserQuestion, Task, WebFetch, WebSearch
argument-hint: "[research-topic]"
description: "Systematic technology research with multi-source validation and knowledge documentation"
model: sonnet
---

# Technology Research Command

Research target: $ARGUMENTS

Systematic research workflow for technology evaluation, implementation patterns, and trend analysis.

## Argument Validation and Sanitization

Parse and validate $ARGUMENTS with security-first approach:

```bash
sanitize_topic() {
  local topic="$1"

  # Reject empty topic
  if [[ -z "$topic" ]]; then
    echo "ERROR [research.md:20]: Research topic required"
    echo "  Usage: /research <topic>"
    echo "  Examples: 'Next.js 15 features', 'React Server Components'"
    exit 1
  fi

  # Remove dangerous characters for file operations
  if [[ "$topic" =~ [/\\:\*\?\"<>\|] ]]; then
    echo "ERROR [research.md:20]: Invalid characters in research topic"
    echo "  Input: $topic"
    echo "  Forbidden: / \\ : * ? \" < > |"
    echo "  Reason: File system safety"
    exit 2
  fi

  # Length validation
  if [[ ${#topic} -gt 200 ]]; then
    echo "ERROR [research.md:20]: Topic too long"
    echo "  Input length: ${#topic} characters"
    echo "  Maximum: 200 characters"
    exit 1
  fi

  echo "$topic"
}

validate_url() {
  local url="$1"

  # Reject unsafe protocols
  if [[ "$url" =~ ^(file|ftp|telnet):// ]]; then
    echo "ERROR [research.md:51]: Unsafe protocol detected"
    echo "  At: validate_url() function"
    echo "  Input: $url"
    echo "  Allowed: https:// or http:// (auto-upgraded)"
    exit 2
  fi

  # Auto-upgrade HTTP to HTTPS
  if [[ "$url" =~ ^http:// ]]; then
    url="${url/http:/https:}"
    echo "INFO: Upgraded HTTP to HTTPS: $url"
  fi

  echo "$url"
}

# Safe argument parsing with IFS
IFS=' ' read -r -a args <<< "$ARGUMENTS"
TOPIC=$(sanitize_topic "${args[0]}")
DEPTH="${args[1]:-detailed}"  # Default to detailed

# Alternative: validate before any operation
# TOPIC=$(sanitize_topic "$ARGUMENTS")
```

## Execution Flow

1. Parse and validate research topic with strict input sanitization
2. Create TodoWrite for research phases
3. Execute systematic information gathering with source validation
4. Cross-reference findings from multiple sources
5. Generate structured research report

## Research Methodologies

For detailed methodology patterns (Technology Comparison, Implementation Research, Trend Analysis), see:
- `~/.claude/stacks/research-patterns.md`

## WebFetch/WebSearch Error Handling

Execute with comprehensive error detection:

```bash
fetch_documentation() {
  local url="$1"
  local output_file="$2"
  local max_retries=3
  local retry_count=0

  while [[ $retry_count -lt $max_retries ]]; do
    if WebFetch url="$url" prompt="Extract main content and code examples" > "$output_file" 2>&1; then
      return 0
    fi

    FETCH_EXIT_CODE=$?
    retry_count=$((retry_count + 1))

    if [[ $FETCH_EXIT_CODE -eq 429 ]]; then
      echo "ERROR [research.md:131]: Rate limit exceeded"
      echo "  URL: $url"
      echo "  Retry: $retry_count/$max_retries"
      echo "  Wait: 60 seconds"
      sleep 60
    else
      echo "ERROR [research.md:131]: WebFetch failed"
      echo "  URL: $url"
      echo "  Exit code: $FETCH_EXIT_CODE"
      echo "  Retry: $retry_count/$max_retries"

      if [[ $retry_count -lt $max_retries ]]; then
        sleep $((retry_count * 10))
      fi
    fi
  done

  echo "ERROR [research.md:131]: WebFetch failed after $max_retries retries"
  echo "  Suggestion: Check URL validity and network connection"
  return 3
}

search_implementations() {
  local query="$1"
  local output_file="$2"

  if ! WebSearch query="$query" > "$output_file" 2>&1; then
    SEARCH_EXIT_CODE=$?
    echo "ERROR [research.md:161]: WebSearch failed"
    echo "  Query: $query"
    echo "  Exit code: $SEARCH_EXIT_CODE"
    echo "  Suggestion: Simplify query or check network"
    return 3
  fi
}
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

TodoWrite: Research workflow phases
- Phase 1: Information gathering (in_progress)
- Phase 2: Source validation and cross-reference (pending)
- Phase 3: Analysis and synthesis (pending)
- Phase 4: Report generation (pending)

AskUserQuestion: Research depth selection
```bash
AskUserQuestion questions='[{
  "question": "Select research depth and approach",
  "header": "Depth",
  "multiSelect": false,
  "options": [
    {"label": "Quick overview", "description": "Surface-level (15-30 min, 1-2 sources)"},
    {"label": "Detailed analysis", "description": "Comprehensive (1-2 hours, 5+ sources)"},
    {"label": "Experimental", "description": "Hands-on proof-of-concept (1-2 days)"}
  ]
}]'
```

Task: Complex exploration and analysis
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
