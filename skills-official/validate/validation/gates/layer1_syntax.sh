#!/usr/bin/env bash
# Layer 1 Syntax Validation Gate
# Validates YAML/JSON syntax and schema compliance
# Usage: layer1_syntax.sh [AUTO_FIX]
# Exit codes: 0=success, 1=failure

set -Eeuo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# Resolve the CALLING project's root (git toplevel, falling back to cwd) -
# never the validate skill's own directory. Matches layer5_security.sh.
readonly PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
readonly SCHEMA_DIR="${HOME}/.claude/validation/schemas"
readonly AUTO_FIX="${1:-false}"

# State tracking
declare -i ERROR_COUNT=0
declare -i WARNING_COUNT=0
declare -a FAILED_FILES=()

# Color output (disabled in non-interactive mode)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# Logging functions
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$*" >&2
}

log_success() {
    printf "${GREEN}[PASS]${NC} %s\n" "$*" >&2
}

log_warning() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2
    ((WARNING_COUNT++))
}

log_error() {
    printf "${RED}[FAIL]${NC} %s\n" "$*" >&2
    ((ERROR_COUNT++))
}

# Safe Python execution wrapper
# Arguments: $1=language (yaml|json), $2=file_path, $3=operation (validate|fix)
safe_python_validate() {
    local -r lang="$1"
    local -r file_path="$2"
    local -r operation="${3:-validate}"

    # Input validation
    [[ "$lang" =~ ^(yaml|json)$ ]] || {
        log_error "Invalid language: $lang"
        return 1
    }

    [[ -f "$file_path" ]] || {
        log_error "File not found: $file_path"
        return 1
    }

    # Safe Python code (no user input in code execution)
    local python_code
    if [[ "$lang" == "yaml" ]]; then
        python_code='
import sys
import yaml
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        yaml.safe_load(f)
    print("OK")
    sys.exit(0)
except yaml.YAMLError as e:
    print(f"YAML Error: {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
'
    else  # json
        python_code='
import sys
import json
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        json.load(f)
    print("OK")
    sys.exit(0)
except json.JSONDecodeError as e:
    print(f"JSON Error: {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
'
    fi

    # Execute with safe -c flag (file path as argument, not in code)
    python3 -c "$python_code" "$file_path" 2>&1
}

# Schema validation using jsonschema
# Arguments: $1=file_path, $2=schema_path
validate_schema() {
    local -r file_path="$1"
    local -r schema_path="$2"

    [[ -f "$schema_path" ]] || {
        log_warning "Schema not found: $schema_path (skipping schema validation)"
        return 0
    }

    # Check if jsonschema is available
    if ! python3 -c "import jsonschema" 2>/dev/null; then
        log_warning "jsonschema module not available (pip install jsonschema)"
        return 0
    fi

    local python_code='
import sys
import json
import yaml
import jsonschema

try:
    # Load schema
    with open(sys.argv[2], "r", encoding="utf-8") as f:
        schema = json.load(f)

    # Load data (support both YAML and JSON)
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        if sys.argv[1].endswith((".yml", ".yaml")):
            data = yaml.safe_load(f)
        else:
            data = json.load(f)

    # Validate
    jsonschema.validate(instance=data, schema=schema)
    print("Schema validation passed")
    sys.exit(0)

except jsonschema.ValidationError as e:
    print(f"Schema validation error: {e.message}", file=sys.stderr)
    if e.path:
        print(f"  at path: {list(e.path)}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Schema validation error: {e}", file=sys.stderr)
    sys.exit(1)
'

    python3 -c "$python_code" "$file_path" "$schema_path" 2>&1
}

# Validate single file
# Arguments: $1=file_path
validate_file() {
    local -r file_path="$1"
    local -r rel_path="${file_path#$PROJECT_ROOT/}"

    [[ -f "$file_path" ]] || {
        log_warning "File not found: $rel_path"
        return 0
    }

    log_info "Validating: $rel_path"

    local lang=""
    local schema_name=""

    # Determine file type and schema
    case "$file_path" in
        */tasks.yml)
            lang="yaml"
            schema_name="tasks-schema.json"
            ;;
        */.autoflow/SPRINTS.yml)
            lang="yaml"
            schema_name="sprints-schema.json"
            ;;
        */package.json)
            lang="json"
            schema_name="package-schema.json"
            ;;
        */tsconfig.json)
            lang="json"
            schema_name="tsconfig-schema.json"
            ;;
        *.yml|*.yaml)
            lang="yaml"
            ;;
        *.json)
            lang="json"
            ;;
        *)
            log_warning "Unknown file type: $rel_path"
            return 0
            ;;
    esac

    # Syntax validation
    local result
    if result=$(safe_python_validate "$lang" "$file_path" 2>&1); then
        log_success "Syntax valid: $rel_path"
    else
        log_error "Syntax error in $rel_path:"
        printf "  %s\n" "$result" >&2
        FAILED_FILES+=("$rel_path")
        return 1
    fi

    # Schema validation (if schema exists)
    if [[ -n "$schema_name" ]]; then
        local schema_path="$SCHEMA_DIR/$schema_name"
        if [[ -f "$schema_path" ]]; then
            if result=$(validate_schema "$file_path" "$schema_path" 2>&1); then
                log_success "Schema valid: $rel_path"
            else
                log_error "Schema validation failed for $rel_path:"
                printf "  %s\n" "$result" >&2
                FAILED_FILES+=("$rel_path (schema)")
                return 1
            fi
        fi
    fi

    return 0
}

# Main validation routine
main() {
    log_info "Starting Layer 1 Syntax Validation"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Auto-fix mode: $AUTO_FIX"

    # Check Python dependencies
    if ! python3 -c "import yaml, json" 2>/dev/null; then
        log_error "Required Python modules not found (yaml, json)"
        log_error "Install with: pip3 install pyyaml"
        return 1
    fi

    # File list to validate
    local -a files=(
        "$PROJECT_ROOT/tasks.yml"
        "$PROJECT_ROOT/.autoflow/SPRINTS.yml"
        "$PROJECT_ROOT/package.json"
        "$PROJECT_ROOT/tsconfig.json"
    )

    # Validate each file
    local file
    for file in "${files[@]}"; do
        validate_file "$file" || true  # Continue on errors
    done

    # Summary
    printf "\n"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Layer 1 Syntax Validation Summary"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $ERROR_COUNT -eq 0 ]]; then
        log_success "All syntax checks passed"
    else
        log_error "Failed files ($ERROR_COUNT):"
        printf "${RED}  - %s${NC}\n" "${FAILED_FILES[@]}" >&2
    fi

    if [[ $WARNING_COUNT -gt 0 ]]; then
        log_warning "Warnings: $WARNING_COUNT"
    fi

    printf "\n"

    # Exit code
    if [[ $ERROR_COUNT -gt 0 ]]; then
        return 1
    fi

    return 0
}

# Error trap
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main
main "$@"
