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
├── skills-official/       # Symlinks to ~/.claude/skills/ (project reference)
│   ├── analyze -> ~/.claude/skills/analyze
│   ├── branch -> ~/.claude/skills/branch
│   ├── commit -> ~/.claude/skills/commit
│   ├── decide -> ~/.claude/skills/decide
│   ├── implement -> ~/.claude/skills/implement
│   ├── todo -> ~/.claude/skills/todo
│   └── ... (24 skills total)
├── rules/                 # Development rules and standards
│   ├── slash-command-design.md  # Skill / slash-command design guidelines
│   └── tech-stacks/      # Technology stack configurations (9 stacks)
│       ├── backend-api.md    # Backend API development settings
│       ├── css-coding-standards.md  # CSS/SCSS coding standards
│       ├── data-science.md   # Data science workflow settings
│       ├── frontend-web.md   # Frontend web development settings
│       ├── mobile-app.md     # Mobile app development settings
│       ├── rust-cli.md       # Rust CLI development settings
│       ├── shell-cli.md      # Shell scripting standards (POSIX)
│       ├── swift-macos-ios.md  # Swift development for macOS/iOS
│       └── vue-nuxt.md       # Vue 3 / Nuxt 3-4 development rules
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

**Note**: Skills are now directly managed in `~/.claude/skills/` (not in this repository). This repository provides:
- Project-specific symlinks in `skills-official/` (for reference)
- Configuration files (`CLAUDE.md`, `settings.json`)
- Tech stack rules and documentation

To restore from backup or set up on a new machine:

```bash
# Clone repository
git clone <this-repo-url> ~/projects/claude-code-workspace

# Skills are managed in ~/.claude/skills/ directly
# (No need to link skills - they're already there)

# Link configuration files
ln -sf ~/projects/claude-code-workspace/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/projects/claude-code-workspace/settings.json ~/.claude/settings.json

# Link rules
mkdir -p ~/.claude/rules/tech-stacks
ln -sf ~/projects/claude-code-workspace/rules/*.md ~/.claude/rules/
ln -sf ~/projects/claude-code-workspace/rules/tech-stacks/*.md ~/.claude/rules/tech-stacks/
```

**Skills Location**: All custom skills (24 total) are in `~/.claude/skills/skill-name/SKILL.md` format.
- `skills-official/` in this repo contains symlinks for reference only
- See `SKILL_MIGRATION.md` for directory structure details

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

Not a tech stack, located at `rules/slash-command-design.md`:

- **slash-command-design.md** - Skill / slash-command design guidelines for Claude Code

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

- Skill docs: `~/.claude/skills/*/SKILL.md` (master), `skills-official/` (symlinks)
- Skill migration guide: `SKILL_MIGRATION.md` - Directory structure details
- Tech stack docs: `rules/tech-stacks/*.md`
- Design guide: `rules/slash-command-design.md`
- Decision frameworks: `~/.claude/skills/decide/frameworks.md` - ICE/RICE scoring, First Principles
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

### Skills Not Appearing

```bash
# Check if skills exist and are readable
ls -la ~/.claude/skills/
ls -la ~/.claude/skills/*/SKILL.md

# Fix permissions if needed
chmod 755 ~/.claude/skills/*/
chmod 644 ~/.claude/skills/*/SKILL.md

# Restart Claude Code CLI
```

### Symlinks Broken (skills-official/)

```bash
# Check if ~/.claude/skills/ exists
ls -la ~/.claude/skills/

# Verify symlinks in project
ls -la ~/projects/claude-code-workspace/skills-official/

# If symlinks are broken, they point to wrong location
# Fix by recreating symlinks (if needed)
```

**Note**: `skills-official/` symlinks are project-specific references only. Skills work from `~/.claude/skills/` directly.

### Configuration Issues

1. Verify `CLAUDE.md` syntax
2. Check `settings.json` JSON syntax
3. Review Claude Code logs

## 📄 License

MIT License - Personal use

---

**Last Updated**: 2025-12-26
**Status**: Active personal workspace
