---
allowed-tools: Bash, Read, Grep, Glob, Task, TodoWrite
argument-hint: "[overview|quality] [--detailed|--quick|--report|--focus=area]"
description: Project health assessment and code quality analysis
model: sonnet
---

# Codebase Analysis

Arguments: $ARGUMENTS

## Argument Validation

Execute validation before any operations:

```bash
# Validate and sanitize subcommand
validate_subcommand() {
  local cmd="$1"
  local allowed="overview quality"

  # Default to overview if empty
  if [[ -z "$cmd" ]]; then
    echo "overview"
    return 0
  fi

  # Validate against whitelist
  if [[ ! "$allowed" =~ (^|[[:space:]])"$cmd"($|[[:space:]]) ]]; then
    echo "ERROR: Invalid subcommand: $cmd"
    echo "Allowed subcommands: overview, quality"
    exit 1
  fi

  # Reject command injection characters
  local injection_pattern='[;`$()&|*?[]{}<>!]'
  if [[ "$cmd" =~ $injection_pattern ]]; then
    echo "ERROR: Invalid characters in subcommand"
    exit 2
  fi

  echo "$cmd"
}

# Validate flags
validate_flags() {
  local flags="$1"
  local allowed_flags="--detailed --quick --report"

  for flag in $flags; do
    if [[ "$flag" =~ ^--focus= ]]; then
      local focus="${flag#--focus=}"
      # Whitelist: alphanumeric and dash only
      if [[ ! "$focus" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "ERROR: Invalid focus area: $focus"
        echo "Allowed characters: alphanumeric and dash"
        exit 2
      fi
    elif [[ "$flag" =~ ^-- ]]; then
      if [[ ! "$allowed_flags" =~ "$flag" ]]; then
        echo "ERROR: Invalid flag: $flag"
        echo "Allowed flags: $allowed_flags, --focus=<area>"
        exit 1
      fi
    fi
  done
}

# Safe argument parsing
IFS=' ' read -r -a args <<< "$ARGUMENTS"
SUBCOMMAND=$(validate_subcommand "${args[0]}")
FLAGS="${args[@]:1}"
validate_flags "$FLAGS"
```

If validation fails: exit with error code 1 (user error) or 2 (security error)

## Execution Flow

1. Parse arguments and detect project type
   - Extract subcommand (default: overview)
   - Parse option flags
   - Auto-detect project type from package.json, file structure, config files

2. Select analysis strategy
   - overview: comprehensive project health assessment (default)
   - quality: code quality, type safety, test coverage, security audit

3. Execute analysis with TodoWrite
   - Create tasks for multi-step analysis
   - Use Task tool for specialized analysis (Explore, performance-engineer, code-reviewer)
   - Collect metrics and generate report

4. Generate actionable report
   - Summary dashboard with key metrics
   - Detailed findings by category
   - Prioritized action plan
   - Improvement recommendations

## Tool Usage

TodoWrite: Track multi-step analysis workflow
Task (Explore): Project structure analysis and dependency mapping
Task (code-reviewer): Code quality and best practices review
Task (security-auditor): Security vulnerability assessment
Grep/Glob: File search and pattern matching
Bash: Execute quality checks and external tools

## Subcommand Details

### overview (Default)
Comprehensive project health assessment:
- Project structure summary (file count, directory organization)
- Quality metrics (type safety, lint compliance, test coverage)
- Critical issues ranked by priority
- Technology stack detection
- Recommended action plan

Analysis method:
```bash
# Parallel agent execution for comprehensive assessment
{
  Task(Explore, "Project structure and dependencies") &
  Task(code-reviewer, "Code quality assessment") &
  Task(security-auditor, "Security vulnerability scan") &
  wait
}
```

### quality
Detailed code quality and security analysis:
- TypeScript strict mode compliance and type safety
- ESLint/Prettier compliance status
- Test coverage and test quality metrics
- Security vulnerability scan (dependencies, code patterns)
- Accessibility compliance (if applicable)

Analysis method:
```bash
# Parallel quality checks
{
  TS_ERRORS=$(npm run typecheck 2>&1 | grep -c "error" || echo "0") &
  LINT_ERRORS=$(npm run lint 2>&1 | grep -c "error" || echo "0") &
  npm audit --production &
  wait
}

# Security auditor agent for deep analysis
Task(security-auditor, "Comprehensive security audit")
```

## Delegated Analysis (Use these instead)

For specialized analysis, use dedicated commands or agents:

**Structure Analysis**:
- Use: `Task(Explore, "Project structure and dependencies")`
- Thoroughness: medium or very thorough
- Output: File paths, dependency graphs, circular dependency detection

**Performance Analysis**:
- Use: `/optimize [target]` command
- Focus: Bundle size, memory usage, optimization opportunities
- Output: Performance metrics, optimization recommendations

**Technical Debt Analysis**:
- Use: `Task(refactoring-specialist, "Technical debt assessment")`
- Focus: High complexity files, code duplication, deprecated patterns
- Output: Refactoring candidates, prioritized improvement plan

## External Tool References

For professional-grade analysis, consider using external tools:

**Comprehensive Quality Analysis**:
```bash
# SonarQube - Enterprise code quality and security
sonar-scanner -Dsonar.projectKey=myproject

# CodeClimate - Automated code review and maintainability
codeclimate analyze
```

**Performance and Accessibility**:
```bash
# Lighthouse - Performance, accessibility, SEO audit
npx lighthouse https://example.com --view

# Webpack Bundle Analyzer - Bundle size analysis
npx webpack-bundle-analyzer stats.json
```

**Security Scanning**:
```bash
# Snyk - Vulnerability scanning for dependencies
npm install -g snyk
snyk test

# npm audit - Built-in security audit
npm audit --production
npm audit fix
```

**Code Quality Tools**:
```bash
# ESLint - Linting
npm run lint

# Prettier - Code formatting
npm run format

# TypeScript - Type checking
npm run typecheck
```

## Error Handling

If project type detection fails:
- Report "No recognized project structure"
- Suggest manual specification or initialization

If analysis tool unavailable:
- Report missing tool
- Suggest installation command
- Provide manual analysis alternatives

If validation fails:
- Report expected format with examples
- List valid subcommands and flags
- Exit with appropriate error code (1 for user error, 2 for security error)

Security:
- Never expose absolute paths in error messages
- Report only relative paths from project root
- Never expose stack traces or internal details
- Report only user-actionable information

## Examples

```
/analyze → Comprehensive project health assessment (default: overview)
/analyze overview → Explicit overview mode
/analyze quality → Detailed code quality and security analysis
/analyze quality --detailed → Comprehensive quality analysis with detailed reports
/analyze overview --report → Generate health assessment report
/analyze quality --focus=security → Focus on security-specific quality checks
```

For specialized analysis:
```
# Structure analysis
Task(Explore, "Project structure and dependencies")

# Performance analysis
/optimize src/components/

# Technical debt analysis
Task(refactoring-specialist, "Technical debt assessment")
```
