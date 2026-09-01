# Quality Gate Validation System

AutoFlow-style multi-layer quality gate system for Claude Code development workflows.

## Overview

This validation system provides 5-layer quality gates to catch LLM-generated code errors early:

1. **Layer 1 (Syntax)**: YAML/JSON syntax validation
2. **Layer 2 (Format)**: Markdown detection, enum normalization, auto-fix
3. **Layer 3 (Semantic)**: Business rules validation (future)
4. **Layer 4 (Integration)**: Frontend/backend sync (future)
5. **Layer 5 (Security)**: Credential scanning, OWASP Top 10, vulnerability detection

## Quick Start

```bash
# Basic validation
/validate

# Security-only check
/validate --layers=security

# Syntax with auto-fix
/validate --layers=syntax --auto-fix

# JSON output
/validate --report=json
```

## Directory Structure

```
validation/
├── config.sh                    # Configuration
├── pipeline.sh                  # Main orchestration
├── gates/
│   ├── layer1_syntax.sh        # Syntax validation
│   ├── layer2_format.sh        # Format validation
│   └── layer5_security.sh      # Security validation
├── fixers/
│   ├── yaml_fixer.py           # YAML auto-fix
│   ├── markdown_stripper.py    # Markdown removal
│   └── enum_normalizer.py      # Enum normalization
├── utils/
│   ├── logging.sh              # Logging functions
│   └── report-generator.py     # Report generation
├── patterns/
│   └── security-patterns.json  # Security patterns
└── tests/
    ├── test_layer1_syntax.sh   # Layer 1 tests
    ├── test_layer2_format.sh   # Layer 2 tests
    ├── test_layer5_security.sh # Layer 5 tests
    ├── test_pipeline.sh        # Pipeline tests
    └── run_all_tests.sh        # Run all tests
```

## Usage

### Command Line

```bash
# Direct pipeline execution
bash ~/projects/claude-code-workspace/validation/pipeline.sh \
    --layers=syntax,security \
    --auto-fix=true \
    --stop-on-failure=true
```

### Via /validate Command

```bash
# Available in Claude Code
/validate --layers=all --auto-fix
```

## Testing

```bash
cd ~/projects/claude-code-workspace/validation/tests

# Run all tests
./run_all_tests.sh

# Run specific layer tests
./test_layer1_syntax.sh
./test_layer2_format.sh
./test_layer5_security.sh
./test_pipeline.sh
```

## Test Results

- **Layer 1**: 9/10 PASS (1 SKIP - jsonschema not installed)
- **Layer 2**: 11/11 PASS
- **Layer 5**: 7/7 PASS
- **Pipeline**: 15/15 PASS
- **Total**: 42/43 PASS (97.7%)

## Performance

- **Parallel Execution**: Layer 1 + Layer 5 run simultaneously
- **npm audit Cache**: 60-minute TTL
- **Target**: < 10 seconds for full validation

## Security

All gates implement:
- Input sanitization
- Path traversal prevention
- ReDoS protection (timeout 10s)
- Safe temporary files (mktemp + chmod 600)
- No eval/exec/compile

## Documentation

- [Implementation Summary](../docs/quality-gate-implementation-summary.md)
- [Security Audit Report](../docs/validate-security-audit-report.md)
- [Command Review](../docs/validate-command-review.md)
- [Integration Plan](../docs/quality-gate-integration-plan.md)

## Configuration

Edit `config.sh` for global settings:

```bash
REPORT_DIR="/tmp"
CACHE_EXPIRY_MINUTES=60
GATE_TIMEOUT_SECONDS=10
```

Override per-project in `.autoflow/validation.conf`

## Troubleshooting

### Tests fail with "jsonschema not installed"

```bash
pip3 install jsonschema
```

### Permission denied

```bash
chmod +x ~/projects/claude-code-workspace/validation/gates/*.sh
chmod +x ~/projects/claude-code-workspace/validation/pipeline.sh
```

### Report generator not found

```bash
ls -la ~/.claude/validation
# Should show symlink to ~/projects/claude-code-workspace/validation
```

## License

MIT

## Author

Claude Code + AutoFlow Quality Gate System
