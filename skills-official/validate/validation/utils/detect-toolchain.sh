#!/usr/bin/env bash
# validation/utils/detect-toolchain.sh - Project toolchain detection
#
# Sourced by gate scripts; defines functions only, no side effects.
#
# Provides:
#   detect_project_types <root>        Prints one toolchain per line: node|rust|python
#   has_npm_script <root> <name>       Exit 0 if package.json defines the script
#   npm_script_name <root> <a> <b>...  Prints the first script name that exists

# Print every toolchain detected at the given project root, one per line.
# A monorepo can legitimately match several; callers iterate over all of them.
detect_project_types() {
    local root="$1"

    if [[ -f "$root/package.json" ]]; then
        echo "node"
    fi

    if [[ -f "$root/Cargo.toml" ]]; then
        echo "rust"
    fi

    if [[ -f "$root/pyproject.toml" || -f "$root/requirements.txt" || -f "$root/setup.py" ]]; then
        echo "python"
    fi

    return 0
}

# Exit 0 when package.json declares the named script.
# Parsing is delegated to python3 so a malformed package.json is a clean
# non-zero exit rather than a shell parse accident.
has_npm_script() {
    local root="$1"
    local script="$2"

    [[ -f "$root/package.json" ]] || return 1

    python3 - "$root/package.json" "$script" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
except (OSError, ValueError):
    sys.exit(1)

if not isinstance(data, dict):
    sys.exit(1)

scripts = data.get("scripts")
if not isinstance(scripts, dict):
    sys.exit(1)

sys.exit(0 if sys.argv[2] in scripts else 1)
PY
}

# Print the first script name that package.json actually defines.
# Returns 1 (printing nothing) when none of the candidates exist.
npm_script_name() {
    local root="$1"
    shift

    local candidate
    for candidate in "$@"; do
        if has_npm_script "$root" "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

# Exit 0 when the project has an ESLint configuration in any supported form.
has_eslint_config() {
    local root="$1"

    local pattern
    for pattern in \
        "$root"/eslint.config.* \
        "$root"/.eslintrc \
        "$root"/.eslintrc.*
    do
        [[ -f "$pattern" ]] && return 0
    done

    return 1
}

# Exit 0 when the project has a Prettier configuration in any supported form.
has_prettier_config() {
    local root="$1"

    local pattern
    for pattern in \
        "$root"/.prettierrc \
        "$root"/.prettierrc.* \
        "$root"/prettier.config.*
    do
        [[ -f "$pattern" ]] && return 0
    done

    return 1
}
