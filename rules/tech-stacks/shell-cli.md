# Shell CLI Implementation Guidelines

## Overview

### Purpose
This guideline provides complete quality standards for Claude Code when implementing Shell CLI tools. It defines implementation rules from four perspectives: Security, Usability, Performance, and Maintainability.

### Target Shell

**This guideline targets Bash 4.0+**

Implementation assumes use of Bash-specific features (arrays, `[[]]`, advanced string operations, etc.).

#### Shell Selection Criteria

**Bash Recommended Cases**:
- Automation scripts like Git hooks, pre-commit
- Build scripts, CI/CD automation
- Simple development tools (< 200 lines)
- Managed development environments

**POSIX sh Recommended Cases**:
- Execution on Alpine Linux, embedded systems
- Portability priority (runs on multiple UNIX-like OSes)
- Container image size minimization required
- See `~/.claude/stacks/posix-shell.md` for details (complete POSIX compliance standards)

### Target Audience
- **Primary**: Claude Code (AI development agent)
- **Secondary**: Developers implementing Shell CLI

### Application Timing
Apply when Shell CLI implementation is selected in these cases:
- Automation scripts like Git hooks, pre-commit
- Build scripts, CI/CD automation
- Simple development tools (< 200 lines)
- When minimizing dependencies

### Key Principles
1. **Security First**: Always validate and sanitize user input
2. **Explicit Error Handling**: Always use `set -euo pipefail`
3. **Leverage Bash 4.0+ Features**: Actively use arrays, `[[]]`, parameter expansion
4. **Performance Awareness**: Optimize startup time and in-loop processing

---

## Security Standards (18 Items)

### Basic Security (8 Items)

#### 1. Appropriate Error Messages

**Principle**: Do not include sensitive information (passwords, API keys, etc.) in error messages. Only abstract and useful messages.

Bad: `echo "Failed: mysql -u root -p$PASSWORD"` ← Password exposure
Good: `error "Database initialization failed. Check credentials."`

---

#### 2. Destructive Change Confirmation

**Principle**: Display confirmation prompt with `read -p` before destructive operations like `rm -rf`, `truncate`. Default is No.

Bad: `rm -rf "$directory"` ← Delete without confirmation
Good: `read -p "Delete? [y/N]"; [[ $REPLY =~ ^[yY]$ ]] && rm -rf "$directory"`

---

#### 3. Numeric Option Limits

**Principle**: Validate numeric input with `[[ "$input" =~ ^[0-9]+$ ]]`, then range check (1-1000, etc.). Prevent DoS with abnormal values.

Bad: `for i in $(seq 1 "$1")` ← No validation
Good: `[[ "$1" =~ ^[0-9]+$ ]] && (( 1 <= $1 && $1 <= 100 ))`

---

#### 4. Choice Validation

**Principle**: Prohibit direct execution of user input. Validate with `case` statement whitelist, execute only allowed operations.

Bad: `action="$1"; $action` ← Arbitrary command execution
Good: `case "$1" in start|stop|restart) ;; *) error ;; esac`

---

#### 5. Exit Code Consistency

**Principle**: Define different exit codes as constants for each error type. 0=success, 1=usage error, 2+=specific error.

Bad: All `exit 1` ← Error type unclear
Good: `readonly EXIT_FILE_NOT_FOUND=2; die "$EXIT_FILE_NOT_FOUND" "File not found"`

---

#### 6. Proper Use of Standard I/O

**Principle**: stdout=data only, stderr=logs/errors. Prevent log contamination in pipeline integration.

Bad: `echo "Processing"; echo "Error"; cat "$file"` ← Mixed output
Good: `log() { echo "$*" >&2; }; echo "$data"` (data only to stdout)

---

#### 7. Cleanup Processing

**Principle**: Register cleanup function with `trap cleanup EXIT INT TERM` to ensure temp file deletion and sensitive variable `unset`.

Bad: No cleanup ← Temp files remain
Good: `cleanup() { rm -f "$tmpfile"; unset password; }; trap cleanup EXIT`

---

#### 8. Dependency Check

**Principle**: Check dependent command existence with `command -v` at script start. Exit with code 127 when missing.

Bad: No dependency check ← Unclear error
Good: `command -v jq &>/dev/null || { error "jq required"; exit 127; }`

---

### Advanced Security (10 Items)

#### 9. Path Traversal Prevention

**Principle**: Remove directory part with `basename`, validate filename with `[a-zA-Z0-9._-]+`, access only within safe directory.

Bad: `cat "$1"` ← ../../../../etc/passwd possible
Good: `filename=$(basename "$1"); [[ "$filename" =~ ^[a-zA-Z0-9._-]+$ ]] && cat "$safe_dir/$filename"`

---

#### 10. Safe Temporary File Creation

**Principle**: Create random filename with `mktemp`, make accessible only to owner with `chmod 600`. `$$` is predictable and dangerous.

Bad: `tmpfile="/tmp/myapp.$$"` ← Predictable, TOCTOU attack
Good: `tmpfile=$(mktemp); chmod 600 "$tmpfile"`

---

#### 11. Shell Injection Prevention

**Principle**: Prohibit `eval` use. Always quote variables. Use array `("$@")` for complex cases.

Bad: `eval "cat $file"` ← Arbitrary command execution
Good: `cat "$file"` or `files=("$@"); cat "${files[@]}"`

---

#### 12. Safe Environment Variable Use

**Principle**: Do not set environment variables like PATH with user input. Add only after whitelist validation of allowed paths.

Bad: `PATH="$user_input:$PATH"` ← Arbitrary command execution possible
Good: Whitelist validation → Directory existence check → PATH addition

---

#### 13. Safe sudo Use

**Principle**: Avoid sudo use. If unavoidable, allow only specific commands in sudoers and do not pass user input.

Bad: `sudo eval "$user_command"` ← Arbitrary command execution with root privileges
Good: sudoers configuration + fixed command + fixed parameters only

---

#### 14. Password/Sensitive Information Handling

**Principle**: Do not pass via command-line arguments (visible in `ps`). Use `read -s` for hidden input, pass via environment variable and `unset` after use.

Bad: `password="$1"; mysql -p"$password"` ← Visible in ps
Good: `read -s` → environment variable → `unset`, or read from chmod 600 file

---

#### 15. Safe File Permissions

**Principle**: For sensitive files, set `umask 077` first, then `chmod 600` (files), `chmod 700` (directories) to make accessible only to owner.

Bad: `echo "$api_key" > config.txt` ← Readable by anyone
Good: `umask 077; chmod 600 config_file; chmod 700 config_dir`

---

#### 16. Command Substitution Safety

**Principle**: Prohibit `eval` use. When including user input, use fixed string options like `grep -F`, or execute directly.

Bad: `result=$(eval "$user_input")` ← Arbitrary command execution
Good: `result=$(grep -F "$pattern" file)` or direct execution

---

#### 17. Signal Handling

**Principle**: Register cleanup function with `trap cleanup EXIT INT TERM HUP`. Delete temp files, terminate processes, clear sensitive info in cleanup.

Bad: No signal handling ← Temp files remain on Ctrl+C
Good: `trap cleanup EXIT INT TERM` → Reliable resource release

---

#### 18. Secure Network Communication

**Principle**: Use HTTPS only. sha256sum verification required when downloading scripts. Prohibit direct pipe execution (`curl | bash`).

Bad: `curl http://example.com/install.sh | bash` ← HTTP + no verification
Good: HTTPS + `sha256sum -c` + content check + execution

---

## Usability Standards

#### 1. Subcommand Help {#subcommand-help}

**Principle**: Implement `show_help()` function that displays Usage, Commands, Options, Examples with `-h|--help`.

Bad: No help ← User cannot understand usage
Good: `show_help() { cat <<EOF ... EOF }; case "$1" in -h|--help) show_help; exit 0 ;; esac`

---

#### 2. Debug Mode {#debug-mode}

**Principle**: Multi-level debugging with `DEBUG` environment variable. 0=none, 1=main processing, 2=variable values, 3=`set -x` trace.

Bad: No debug feature ← Troubleshooting difficult
Good: `DEBUG=${DEBUG:-0}; debug() { (( DEBUG >= $1 )) && echo "[DEBUG] $*" >&2; }; (( DEBUG >= 3 )) && set -x`

---

#### 3. Version Information {#version-info}

**Principle**: Define `readonly VERSION="x.y.z"`, display with `-v|--version`. Including BUILD_DATE, GIT_COMMIT improves troubleshooting efficiency.

Bad: No version info ← Difficult to identify during bug reports
Good: `readonly VERSION="1.2.3"; show_version() { echo "$0 version $VERSION"; }; case "$1" in -v) show_version ;; esac`

---

## Performance Standards (4 Items)

#### 1. Startup Time Optimization

**Purpose**: Improve startup speed important for Git hooks, etc.

**Bad Example** (unnecessary initialization):
```bash
#!/bin/bash
# Heavy initialization
source /etc/profile
source ~/.bashrc
source ~/.bash_profile

# Unnecessary command execution
uname -a
hostname
date
```

**Good Example** (minimal initialization):
```bash
#!/bin/bash
# Only necessary minimum settings
set -euo pipefail

# Set only necessary environment variables
export PATH="/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C  # Speed up locale processing

# Main processing below
# ...
```

**Why Important**:
- Git hooks require fast startup (directly affects developer experience)
- Unnecessary command execution causes cumulative delays
- `LC_ALL=C` speeds up locale processing

---

#### 2. Reduce External Commands {#reduce-external-commands}

**Purpose**: Reduce process creation, improve speed

**Bad Example** (heavy external command use):
```bash
# Heavy use of external commands
basename=$(basename "$path")
dirname=$(dirname "$path")
extension=$(echo "$filename" | sed 's/.*\.//')
upper=$(echo "$text" | tr 'a-z' 'A-Z')
```

**Good Example** (Bash built-in features):
```bash
# Bash built-in parameter expansion
basename="${path##*/}"
dirname="${path%/*}"
extension="${filename##*.}"
filename_without_ext="${filename%.*}"

# Case conversion (Bash 4.0+)
upper="${text^^}"
lower="${text,,}"

# String replacement
result="${text//old/new}"       # Replace all
result="${text/old/new}"        # Replace first only
result="${text#prefix}"         # Remove prefix (shortest)
result="${text##prefix}"        # Remove prefix (longest)
result="${text%suffix}"         # Remove suffix (shortest)
result="${text%%suffix}"        # Remove suffix (longest)
```

**Why Important**:
- External command execution is slow (fork + exec)
- Bash built-in features are fast
- Especially effective in loops

---

#### 3. Optimize In-Loop Command Execution

**Purpose**: Speed up large data processing

**Bad Example** (external commands in loop):
```bash
# Execute external command per loop
for file in *.txt; do
    wc -l "$file"
done

# Subshell in loop
for i in {1..1000}; do
    result=$(date +%s)
    echo "$result"
done
```

**Good Example** (batch processing/parallelization):
```bash
# Batch processing
wc -l *.txt

# Parallel processing with xargs
printf '%s\0' *.txt | xargs -0 -P 4 wc -l

# Execute command outside loop
timestamp=$(date +%s)
for i in {1..1000}; do
    echo "$((timestamp + i))"
done

# GNU Parallel (installation required)
parallel wc -l ::: *.txt
```

**Why Important**:
- External commands in loops are cumulatively much slower
- Parallel processing effectively uses CPU cores
- Batch processing is always fastest

---

#### 4. Leverage Parallel Processing {#parallel-processing}

**Purpose**: Utilize multi-core, speed up

**Bad Example** (sequential processing):
```bash
# Process one by one (slow)
for url in "${urls[@]}"; do
    curl -O "$url"
done

for file in *.mp4; do
    ffmpeg -i "$file" "compressed_$file"
done
```

**Good Example** (parallel processing):
```bash
# Parallel processing with xargs (simple)
printf '%s\n' "${urls[@]}" | xargs -P 4 -I {} curl -O {}

# GNU Parallel (feature-rich)
parallel -j 4 curl -O ::: "${urls[@]}"

# Background jobs (when control needed)
max_jobs=4
job_count=0

for file in *.mp4; do
    # Background execution
    ffmpeg -i "$file" "compressed_$file" &

    job_count=$((job_count + 1))

    # Wait when max parallel count reached
    if (( job_count >= max_jobs )); then
        wait -n  # Wait for one job to complete
        job_count=$((job_count - 1))
    fi
done

# Wait for all jobs to complete
wait
```

**Why Important**:
- Effectively utilize CPU cores
- Hide I/O wait time with parallelization
- Dramatic speedup for large data processing

---

## Maintainability Standards (5 Items)

#### 1. Code Structuring (Function Division)

**Principle**: Divide scripts over 50 lines into functions. Configuration → Functions → Main 3-section structure. Each function has single responsibility.

Bad: 500-line single script ← Difficult to test, low readability
Good: Divide into `show_usage()`, `parse_arguments()`, `validate_input()`, `main()`

---

#### 2. Explicit Constant Definition

**Principle**: Convert magic numbers to `readonly` constants. Define all together in Configuration section at script top.

Bad: `if (( count > 100 )); sleep 30` ← Unclear meaning
Good: `readonly MAX_ITEMS=100; readonly RETRY_DELAY=30`

---

#### 3. Unified Error Handling Pattern {#error-handling}

**Principle**: Define unified error function. All to standard error output. 4 types: `error()` (continue), `die()` (exit), `warn()`, `debug()`.

Bad: Inconsistent output methods ← echo/printf mixed
Good: `error() { echo "Error: $*" >&2; return 1; }`

---

#### 4. Separate Configuration from Implementation {#config-separation}

**Principle**: Prohibit hardcoding. Priority: environment variable > user config > system config > default value.

Bad: `api_url="https://api.example.com"` ← Hardcoded
Good: `API_URL="${MYAPP_API_URL:-$DEFAULT_API_URL}"`

---

#### 5. ShellCheck Compliance {#shellcheck}

**Principle**: Run `shellcheck` in CI/CD. Major warnings: SC2086 (unquoted variable), SC2034 (unused variable), SC2155 (declare simultaneous assignment).

Bad: `files=$@; for f in $files` ← SC2086
Good: `files=("$@"); for f in "${files[@]}"` + `.shellcheckrc` configuration

---


## Application Example

### Minimal Implementation Example

```bash
#!/bin/bash
#
# minimal-tool.sh - Minimal Shell CLI implementation
# Version: 1.0.0
#

set -euo pipefail

# ========================================
# Configuration
# ========================================

readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

# ========================================
# Functions
# ========================================

show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] COMMAND

Options:
    -h, --help     Show this help
    -v, --version  Show version

Commands:
    process FILE   Process the specified file
EOF
}

show_version() {
    echo "$SCRIPT_NAME version $VERSION"
}

error() {
    echo "Error: $*" >&2
    return 1
}

cleanup() {
    # Cleanup processing
    :
}

process_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi

    # Processing
    echo "Processing: $file"
}

# ========================================
# Main
# ========================================

main() {
    # Argument check
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # Option parsing
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        process)
            shift
            process_file "$@"
            ;;
        *)
            error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

trap cleanup EXIT

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

By following this guideline, you can implement safe and maintainable Shell CLI tools.
