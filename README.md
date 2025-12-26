# Claude Code Workspace

Personal Claude Code configuration workspace with custom commands and development workflows.

## 📋 Overview

This repository is my personal backup and configuration management for Claude Code:

- Custom slash commands for streamlined workflows
- Technology stack configurations for different projects
- LLM-optimized settings for efficient AI-assisted development
- Integrated skills from Anthropic and community collections

## 📁 Repository Structure

```
claude-code-workspace/
├── commands/              # Custom slash commands (21 commands)
│   ├── analyze.md        # Project health assessment
│   ├── branch.md         # Git branch creation with conventions
│   ├── clean-jobs.md     # Safe background job cleanup
│   ├── commit.md         # Conventional Commits with emoji
│   ├── debug.md          # Universal debugging workflow
│   ├── decide.md         # Framework-driven decision support
│   ├── explain.md        # Explain project features
│   ├── implement.md      # Document-driven task implementation
│   ├── iterative-review.md  # Multi-perspective code review
│   ├── optimize.md       # Performance optimization
│   ├── plan-review.md    # Implementation planning with review
│   ├── refactor.md       # Safe incremental refactoring
│   ├── research.md       # Systematic technology research
│   ├── review-pr.md      # GitLab MR/GitHub PR review
│   ├── review-quality.md # LLM implementation quality evaluation
│   ├── ship.md           # GitHub PR/GitLab MR creation
│   ├── todo.md           # Intelligent task management
│   ├── update-docs.md    # Documentation synchronization
│   ├── validate.md       # Multi-layer quality gate validation
│   ├── web-dev.md        # Frontend development server
│   └── worktree.md       # Git worktree management
├── rules/                 # Development rules and standards
│   └── tech-stacks/      # Technology stack configurations (10 stacks)
│       ├── backend-api.md    # Backend API development settings
│       ├── css-coding-standards.md  # CSS/SCSS coding standards
│       ├── data-science.md   # Data science workflow settings
│       ├── frontend-web.md   # Frontend web development settings
│       ├── mobile-app.md     # Mobile app development settings
│       ├── rust-cli.md       # Rust CLI development settings
│       ├── shell-cli.md      # Shell scripting standards (POSIX)
│       ├── slash-command-design.md  # Command design guidelines
│       ├── swift-macos-ios.md  # Swift development for macOS/iOS
│       └── vue-nuxt.md       # Vue 3 / Nuxt 3-4 development rules
├── skills/                # Integrated Claude skills
│   ├── anthropic-skills/ # Official Anthropic skills
│   ├── superpowers/      # Community skill collection
│   ├── i18n-check.md     # Internationalization status check
│   ├── serena.md         # Semantic code analysis (MCP)
│   └── ca-vm.md          # CA VM management skill
├── CLAUDE.md             # LLM behavior configuration
├── USER_GUIDE.md         # User-facing documentation
├── settings.json         # Claude Code system settings
├── docs/                 # Additional documentation
│   ├── decision-frameworks.md  # ICE/RICE scoring, First Principles
│   ├── llm-quality-framework.md  # LLM implementation quality standards
│   └── slash-command-security-template.md  # Security template for commands
├── projects/             # Session history and project data
└── scripts/              # Utility scripts
```

## 🚀 Setup

### Installation

Since this is already set up in my environment at `~/projects/claude-code-workspace`, commands and configurations are symlinked to `~/.claude/`.

To restore from backup or set up on a new machine:

```bash
# Clone repository
git clone <this-repo-url> ~/projects/claude-code-workspace

# Link commands
ln -sf ~/projects/claude-code-workspace/commands/*.md ~/.claude/commands/

# Link configuration files
ln -sf ~/projects/claude-code-workspace/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/projects/claude-code-workspace/settings.json ~/.claude/settings.json

# Link tech stacks
mkdir -p ~/.claude/rules/tech-stacks
ln -sf ~/projects/claude-code-workspace/rules/tech-stacks/*.md ~/.claude/rules/tech-stacks/
```

### Verify Setup

```bash
# Check available commands
/help

# Test a command
/todo list
```

## 📚 Available Commands

### Task Management & Planning

**`/todo`** - Intelligent task management with Git integration
- Usage: `/todo add "task"`, `/todo list`, `/todo complete 1`, `/todo sync`
- Git integration, interactive UI, project-wide analysis

**`/implement`** - Document-driven task implementation from tasks.yml
- Usage: `/implement [task-id]`, `/implement` (list pending)
- Automatic document context injection, acceptance criteria validation
- Updates task status on completion, dependency checking

**`/decide`** - Framework-driven decision support for tech choices
- Usage: `/decide "question-or-options"`, `/decide "A vs B"`, `/decide "priorities"`
- ICE/RICE scoring, Eisenhower Matrix, First Principles analysis
- Conclusion-first format with detailed comparison tables

**`/plan-review`** - Create implementation plan and review
- Usage: `/plan-review "feature name" [--rounds=3] [--perspectives=security,performance]`
- Task breakdown, automatic review, tasks.yml updates

### Development & Debugging

**`/debug`** - Universal debugging workflow
- Usage: `/debug "bug or issue description"`, `/debug` (interactive)
- Systematic diagnosis and fix for any bug severity
- Automated diagnostics, root cause identification

**`/analyze`** - Project health assessment and code quality analysis
- Usage: `/analyze [overview|quality] [--detailed|--quick|--report]`
- Codebase structure, quality metrics, technical debt analysis

**`/explain`** - Explain project features, components, and concepts
- Usage: `/explain ComponentName [--detailed|--usage|--examples]`
- Fast exact-match or comprehensive semantic search
- Structured explanations with usage patterns

**`/refactor`** - Safe incremental refactoring workflow
- Usage: `/refactor [file-path|component-name]`
- Impact analysis, incremental execution, quality validation

**`/optimize`** - Performance optimization
- Usage: `/optimize [optimization-target]`
- Measurement, analysis, validation workflow

**`/research`** - Systematic technology research
- Usage: `/research [research-topic]`
- Multi-source validation, knowledge documentation

**`/web-dev`** - Start frontend development server
- Usage: `/web-dev [port]`
- Framework auto-detection (Vite, Next.js, etc.)

### Code Quality & Review

**`/iterative-review`** - Multi-perspective code review
- Usage: `/iterative-review <target> [--rounds=4] [--perspectives=...] [--skip-necessity]`
- Round 0: Necessity review (deletion/simplification)
- Security, performance, maintainability analysis

**`/review-pr`** - Comprehensive GitLab MR/GitHub PR review
- Usage: `/review-pr <MR-number> [--detailed] [--security-focus] [--performance-focus]`
- Security-first systematic quality verification
- Multi-perspective analysis with actionable feedback

**`/review-quality`** - Evaluate LLM implementation quality
- Usage: `/review-quality <file-path> [--report=text|json]`
- CLAUDE.md and slash command quality evaluation
- LLM-friendly scoring with actionable feedback

**`/validate`** - Multi-layer quality gate validation
- Usage: `/validate [--layers=all|syntax,security] [--auto-fix] [--report=text|json]`
- Layer 1-2: Syntax & formatting (auto-fix)
- Layer 5: Security validation (OWASP, secrets scan)

**`/update-docs`** - Documentation synchronization and quality validation
- Usage: `/update-docs [--sync|--validate|--comprehensive] [--scope=critical|important]`
- Sync with code changes, validate quality, fix broken links

### Version Control

**`/worktree`** - Git worktree management for parallel development
- Usage: `/worktree [create|list|switch|merge|delete|status] [branch-name]`
- Parallel development workflows, port management
- Safe cleanup and merge operations

**`/branch`** - Create Git branch following Conventional Branch naming
- Usage: `/branch [type] [description]`, `/branch` (interactive)
- Branch types: feature, fix, refactor, docs, chore, hotfix
- Auto-push with upstream tracking, uncommitted changes handling

**`/commit`** - Create Conventional Commits with emoji formatting
- Usage: `/commit [message]`, `/commit` (interactive)
- Interactive type/scope selection, auto-emoji annotation
- Validates format, suggests scope from changed files

**`/ship`** - Create GitHub PR/GitLab MR with automatic platform detection
- Usage: `/ship [branch-name] [title]`, `/ship` (interactive)
- Auto-detects GitHub/GitLab, applies templates, runs quality checks
- Conventional Commits format, draft PR/MR creation

### Utilities

**`/clean-jobs`** - Safe cleanup of background jobs
- Usage: `/clean-jobs [--auto]`
- Pattern-based auto-classification (dev servers, DB, Docker)
- Session-scoped, safe cleanup operations

### Integrated Skills

**i18n-check** - Internationalization status check
- Usage: Via Skill tool
- Translation coverage, consistency, format validation
- Cultural adaptation and completeness checks

**serena** - Semantic code analysis using Serena MCP
- Usage: Via Skill tool
- Advanced semantic code search and analysis
- MCP-powered intelligent code understanding

**ca-vm** - CA VM management
- Usage: Via Skill tool
- VM lifecycle management and operations

## 🎯 Technology Stack Configurations

Available in `rules/tech-stacks/` directory:

1. **frontend-web.md** - React/Vue/Angular, component architecture, state management
2. **vue-nuxt.md** - Vue 3 / Nuxt 3-4 development rules, Composition API, SSR patterns
3. **backend-api.md** - REST/GraphQL, database patterns, API security
4. **mobile-app.md** - iOS/Android, cross-platform frameworks
5. **swift-macos-ios.md** - Swift 5.9+, SwiftUI/UIKit, macOS/iOS native development
6. **data-science.md** - Jupyter, data pipelines, ML/AI workflows
7. **rust-cli.md** - Rust patterns, CLI frameworks, error handling
8. **shell-cli.md** - POSIX compliance (52 standards), security practices
9. **css-coding-standards.md** - CSS/SCSS coding standards, accessibility, performance
10. **slash-command-design.md** - Command design guidelines for Claude Code

### Using Stack Configurations

Automatically applied based on project context, or explicitly set in project `.claude/CLAUDE.md`:

```yaml
tech_stack: frontend-web
project_type: spa
team_size: 3-5
```

## 🛠️ Configuration Files

**CLAUDE.md** - LLM behavior configuration
- Development workflows, code quality standards, security requirements

**USER_GUIDE.md** - User documentation
- Command reference, usage patterns, troubleshooting

**settings.json** - System settings
- Tool permissions, file operation rules, MCP integration

## 🔄 Backup & Sync

### Save Changes

```bash
cd ~/projects/claude-code-workspace
git add .
git commit -m "Update commands and configurations"
git push
```

### Pull Latest

```bash
cd ~/projects/claude-code-workspace
git pull
```

Changes automatically reflect via symlinks.

### Version Management

Commands follow semantic versioning in frontmatter:

```yaml
---
version: 1.1.0
last-modified: 2025-11-13
---
```

## 📖 Resources

### Documentation

- Command docs: `commands/*.md`
- Tech stack docs: `rules/tech-stacks/*.md`
- Design guide: `rules/tech-stacks/slash-command-design.md`
- Decision frameworks: `docs/decision-frameworks.md` - ICE/RICE scoring, First Principles, practical workflows
- LLM quality standards: `docs/llm-quality-framework.md`

### Integrated Skills

- **Anthropic Skills**: PDF, XLSX, Artifacts, MCP builder
- **Superpowers**: Community skill collection

Access via Skill tool in Claude Code.

### Learning & History

- Session history: `projects/`
- Learning sessions tracked for pattern recognition

## 🔒 Security

File permissions enforced by Claude Code:
- Prohibited: `.env`, credentials, secrets
- Git operations via standard commands only
- No direct `.git/` manipulation

All commands enforce OWASP Top 10, input validation, secure patterns.

## 🐛 Troubleshooting

### Commands Not Appearing

```bash
ls -la ~/.claude/commands/
chmod 644 ~/.claude/commands/*.md
# Restart Claude Code CLI
```

### Symlinks Broken

```bash
mkdir -p ~/.claude/commands/ ~/.claude/stacks/
ls -la ~/.claude/
```

### Configuration Issues

1. Verify `CLAUDE.md` syntax
2. Check `settings.json` JSON syntax
3. Review Claude Code logs

## 📄 License

MIT License - Personal use

---

**Last Updated**: 2025-12-26
**Status**: Active personal workspace
