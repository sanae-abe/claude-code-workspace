#!/usr/bin/env bash
# Layer 5: Security Validation Gate
# Comprehensive security scanning with OWASP Top 10 coverage
# Version: 1.0.0
# Exit codes: 0 = success, 1 = security issues found

set -Eeuo pipefail
IFS=$'\n\t'

# ============================================================================
# Configuration
# ============================================================================

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
readonly SECURITY_PATTERNS="${SCRIPT_DIR}/../patterns/security-patterns.json"
readonly TIMEOUT_SECONDS=10
readonly MAX_FILE_SIZE_MB=10

# Color codes for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Counters
declare -i CRITICAL_COUNT=0
declare -i HIGH_COUNT=0
declare -i MEDIUM_COUNT=0
declare -i TOTAL_ISSUES=0

# ============================================================================
# Utility Functions
# ============================================================================

log_error() {
    printf "${RED}[SECURITY]${NC} %s\n" "$*" >&2
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$*" >&2
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$*" >&2
}

log_info() {
    printf "[INFO] %s\n" "$*" >&2
}

# Report security finding with severity
report_finding() {
    local severity="$1"
    local category="$2"
    local file="$3"
    local line="$4"
    local message="$5"

    ((TOTAL_ISSUES++))

    case "$severity" in
        CRITICAL)
            ((CRITICAL_COUNT++))
            printf "${RED}[CRITICAL]${NC} %s:%s - %s: %s\n" "$file" "$line" "$category" "$message"
            ;;
        HIGH)
            ((HIGH_COUNT++))
            printf "${RED}[HIGH]${NC} %s:%s - %s: %s\n" "$file" "$line" "$category" "$message"
            ;;
        MEDIUM)
            ((MEDIUM_COUNT++))
            printf "${YELLOW}[MEDIUM]${NC} %s:%s - %s: %s\n" "$file" "$line" "$category" "$message"
            ;;
    esac
}

# Safe pattern matching with timeout protection (ReDoS prevention)
# Resolve a timeout command once. GNU coreutils ships `timeout`; Homebrew on
# macOS installs it as `gtimeout`. With neither available the command must still
# run — silently returning failure would turn every scan into "no findings".
if command -v timeout &>/dev/null; then
    readonly TIMEOUT_CMD="timeout"
elif command -v gtimeout &>/dev/null; then
    readonly TIMEOUT_CMD="gtimeout"
else
    readonly TIMEOUT_CMD=""
    log_warning "No timeout command found (install coreutils for ReDoS protection); scans run unbounded"
fi

# Run a command under the resolved timeout, or directly when none is available.
run_with_timeout() {
    if [[ -n "$TIMEOUT_CMD" ]]; then
        "$TIMEOUT_CMD" "${TIMEOUT_SECONDS}s" "$@"
    else
        "$@"
    fi
}

safe_grep() {
    local pattern="$1"
    local file="$2"

    # Skip binary files and files larger than MAX_FILE_SIZE_MB
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    if ! file --mime "$file" 2>/dev/null | grep -q 'text'; then
        return 1
    fi

    local file_size_mb
    file_size_mb=$(( $(stat -f%z "$file" 2>/dev/null || echo "0") / 1024 / 1024 ))
    if [[ $file_size_mb -gt $MAX_FILE_SIZE_MB ]]; then
        log_warning "Skipping large file: $file (${file_size_mb}MB)"
        return 1
    fi

    # Use timeout to prevent ReDoS attacks
    run_with_timeout grep -nE "$pattern" "$file" 2>/dev/null || return 1
}

# Safe git grep with timeout
safe_git_grep() {
    local pattern="$1"
    shift

    run_with_timeout git grep -nE "$pattern" "$@" 2>/dev/null || return 1
}

# Extract JSON patterns safely
get_patterns_from_json() {
    local category="$1"

    if [[ ! -f "$SECURITY_PATTERNS" ]]; then
        log_error "Security patterns file not found: $SECURITY_PATTERNS"
        return 1
    fi

    # Use jq for safe JSON parsing
    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed"
        return 1
    fi

    jq -r "$category" "$SECURITY_PATTERNS" 2>/dev/null || echo "[]"
}

# ============================================================================
# Security Checks
# ============================================================================

# Check 1: Credential Scanner
check_credentials() {
    log_info "Running credential scanner..."

    local findings=0

    # API Keys
    local api_key_patterns
    api_key_patterns=$(get_patterns_from_json '.patterns.credentials.api_keys | .. | select(type == "array") | .[]')

    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue

        if safe_git_grep "$pattern" -- ':(exclude)*.min.js' ':(exclude)*.min.css' ':(exclude)node_modules/*' ':(exclude).git/*'; then
            while IFS=: read -r file line content; do
                report_finding "CRITICAL" "Hardcoded API Key" "$file" "$line" "Possible API key found"
                ((findings++))
            done < <(safe_git_grep "$pattern" -- ':(exclude)*.min.js' ':(exclude)*.min.css' ':(exclude)node_modules/*' ':(exclude).git/*')
        fi
    done <<< "$api_key_patterns"

    # AWS Credentials
    if safe_git_grep "AKIA[0-9A-Z]{16}" -- ':(exclude)node_modules/*'; then
        while IFS=: read -r file line content; do
            report_finding "CRITICAL" "AWS Access Key" "$file" "$line" "AWS access key detected"
            ((findings++))
        done < <(safe_git_grep "AKIA[0-9A-Z]{16}" -- ':(exclude)node_modules/*')
    fi

    # GitHub Tokens
    if safe_git_grep "gh[pousr]_[a-zA-Z0-9]{36}" -- ':(exclude)node_modules/*'; then
        while IFS=: read -r file line content; do
            report_finding "CRITICAL" "GitHub Token" "$file" "$line" "GitHub token detected"
            ((findings++))
        done < <(safe_git_grep "gh[pousr]_[a-zA-Z0-9]{36}" -- ':(exclude)node_modules/*')
    fi

    # Generic secrets
    if safe_git_grep "secret[_-]?key\s*[:=]\s*[\"'][^\"']{8,}[\"']" -- ':(exclude)node_modules/*' ':(exclude)*.test.*' ':(exclude)*.spec.*'; then
        while IFS=: read -r file line content; do
            # Filter out safe patterns
            if ! echo "$content" | grep -qE "(your[_-]?secret|example|test|placeholder|process\.env)"; then
                report_finding "CRITICAL" "Hardcoded Secret" "$file" "$line" "Secret key detected"
                ((findings++))
            fi
        done < <(safe_git_grep "secret[_-]?key\s*[:=]\s*[\"'][^\"']{8,}[\"']" -- ':(exclude)node_modules/*' ':(exclude)*.test.*' ':(exclude)*.spec.*')
    fi

    # Hardcoded passwords
    if safe_git_grep "password\s*[:=]\s*[\"'][^\"']{4,}[\"']" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            if ! echo "$content" | grep -qE "(your[_-]?password|example|test|placeholder|process\.env|\*\*\*\*\*)"; then
                report_finding "CRITICAL" "Hardcoded Password" "$file" "$line" "Password detected"
                ((findings++))
            fi
        done < <(safe_git_grep "password\s*[:=]\s*[\"'][^\"']{4,}[\"']" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # JWT tokens
    if safe_git_grep "eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "CRITICAL" "JWT Token" "$file" "$line" "JWT token detected"
            ((findings++))
        done < <(safe_git_grep "eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # Private keys
    if safe_git_grep "-----BEGIN.*PRIVATE KEY-----" -- ':(exclude)node_modules/*'; then
        while IFS=: read -r file line content; do
            report_finding "CRITICAL" "Private Key" "$file" "$line" "Private key detected"
            ((findings++))
        done < <(safe_git_grep "-----BEGIN.*PRIVATE KEY-----" -- ':(exclude)node_modules/*')
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No hardcoded credentials found"
    else
        log_error "Found $findings credential issues"
    fi

    return 0
}

# Check 2: OWASP Top 10 - SQL Injection
check_sql_injection() {
    log_info "Checking for SQL injection vulnerabilities..."

    local findings=0

    # String concatenation in SQL queries
    if safe_git_grep "(SELECT|INSERT|UPDATE|DELETE).*\+.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "SQL Injection" "$file" "$line" "SQL query with string concatenation detected"
            ((findings++))
        done < <(safe_git_grep "(SELECT|INSERT|UPDATE|DELETE).*\+.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # Direct execute with concatenation
    if safe_git_grep "execute\(.*\+.*\)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "SQL Injection" "$file" "$line" "Direct SQL execution with concatenation"
            ((findings++))
        done < <(safe_git_grep "execute\(.*\+.*\)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No SQL injection vulnerabilities found"
    else
        log_error "Found $findings SQL injection issues"
    fi

    return 0
}

# Check 3: OWASP Top 10 - XSS (Cross-Site Scripting)
check_xss() {
    log_info "Checking for XSS vulnerabilities..."

    local findings=0

    # innerHTML usage
    if safe_git_grep "innerHTML\s*=" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "XSS" "$file" "$line" "innerHTML usage detected - potential XSS"
            ((findings++))
        done < <(safe_git_grep "innerHTML\s*=" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # dangerouslySetInnerHTML
    if safe_git_grep "dangerouslySetInnerHTML" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "XSS" "$file" "$line" "dangerouslySetInnerHTML usage - ensure proper sanitization"
            ((findings++))
        done < <(safe_git_grep "dangerouslySetInnerHTML" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # document.write
    if safe_git_grep "document\.write\(" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "XSS" "$file" "$line" "document.write() usage - potential XSS"
            ((findings++))
        done < <(safe_git_grep "document\.write\(" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # eval usage
    if safe_git_grep "[^a-zA-Z]eval\(" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "XSS/Code Injection" "$file" "$line" "eval() usage detected"
            ((findings++))
        done < <(safe_git_grep "[^a-zA-Z]eval\(" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No XSS vulnerabilities found"
    else
        log_error "Found $findings XSS issues"
    fi

    return 0
}

# Check 4: Command Injection
check_command_injection() {
    log_info "Checking for command injection vulnerabilities..."

    local findings=0

    # exec/execSync with user input
    if safe_git_grep "(exec|execSync|spawn)\(.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "Command Injection" "$file" "$line" "Command execution with user input"
            ((findings++))
        done < <(safe_git_grep "(exec|execSync|spawn)\(.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # Python os.system/subprocess
    if safe_git_grep "(os\.system|subprocess\.call)\(.*request\." -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "Command Injection" "$file" "$line" "Command execution with user input (Python)"
            ((findings++))
        done < <(safe_git_grep "(os\.system|subprocess\.call)\(.*request\." -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No command injection vulnerabilities found"
    else
        log_error "Found $findings command injection issues"
    fi

    return 0
}

# Check 5: Path Traversal
check_path_traversal() {
    log_info "Checking for path traversal vulnerabilities..."

    local findings=0

    # Direct path.join with user input
    if safe_git_grep "path\.join\(.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "Path Traversal" "$file" "$line" "Unsafe path construction with user input"
            ((findings++))
        done < <(safe_git_grep "path\.join\(.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # readFile with user input
    if safe_git_grep "readFile\(.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "Path Traversal" "$file" "$line" "File read with user input"
            ((findings++))
        done < <(safe_git_grep "readFile\(.*req\.(body|params|query)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No path traversal vulnerabilities found"
    else
        log_error "Found $findings path traversal issues"
    fi

    return 0
}

# Check 6: Deprecated Cryptography
check_deprecated_crypto() {
    log_info "Checking for deprecated cryptographic algorithms..."

    local findings=0

    # MD5 usage
    if safe_git_grep "createHash\([\"']md5[\"']\)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "MEDIUM" "Weak Cryptography" "$file" "$line" "MD5 is deprecated, use SHA-256 or better"
            ((findings++))
        done < <(safe_git_grep "createHash\([\"']md5[\"']\)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # SHA1 usage
    if safe_git_grep "createHash\([\"']sha1[\"']\)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "MEDIUM" "Weak Cryptography" "$file" "$line" "SHA1 is deprecated, use SHA-256 or better"
            ((findings++))
        done < <(safe_git_grep "createHash\([\"']sha1[\"']\)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # Python hashlib.md5/sha1
    if safe_git_grep "hashlib\.(md5|sha1)\(" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "MEDIUM" "Weak Cryptography" "$file" "$line" "Weak hash algorithm detected"
            ((findings++))
        done < <(safe_git_grep "hashlib\.(md5|sha1)\(" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No deprecated cryptography found"
    else
        log_warning "Found $findings weak cryptography issues"
    fi

    return 0
}

# Check 7: Sensitive Files
check_sensitive_files() {
    log_info "Checking for sensitive files..."

    local findings=0

    # Find .env files not in .gitignore
    while IFS= read -r -d '' file; do
        local rel_path="${file#$PROJECT_ROOT/}"

        if [[ -f "${PROJECT_ROOT}/.gitignore" ]]; then
            if ! git check-ignore -q "$file" 2>/dev/null; then
                report_finding "CRITICAL" "Sensitive File" "$rel_path" "0" "Sensitive file not in .gitignore"
                ((findings++))
            fi
        else
            report_finding "CRITICAL" "Sensitive File" "$rel_path" "0" "Sensitive file found and no .gitignore exists"
            ((findings++))
        fi
    done < <(find "$PROJECT_ROOT" -type f \( -name ".env*" -o -name "credentials.json" -o -name "secrets.yaml" -o -name "secrets.yml" -o -name "*.pem" -o -name "*.key" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 2>/dev/null)

    if [[ $findings -eq 0 ]]; then
        log_success "No sensitive files exposed"
    else
        log_error "Found $findings sensitive file issues"
    fi

    return 0
}

# Check 8: Dependency Vulnerabilities
check_dependency_vulnerabilities() {
    log_info "Checking for dependency vulnerabilities..."

    local findings=0

    # npm audit (Node.js) with caching
    if [[ -f "${PROJECT_ROOT}/package.json" ]]; then
        log_info "Running npm audit..."

        # Generate cache key from package-lock.json hash
        local cache_key=""
        local cache_file=""
        local use_cache=false

        if [[ -f "${PROJECT_ROOT}/package-lock.json" ]]; then
            # Generate MD5 hash of package-lock.json for cache key
            if command -v md5sum &>/dev/null; then
                cache_key=$(md5sum "${PROJECT_ROOT}/package-lock.json" | awk '{print $1}')
            elif command -v md5 &>/dev/null; then
                # macOS fallback
                cache_key=$(md5 -q "${PROJECT_ROOT}/package-lock.json")
            fi

            if [[ -n "$cache_key" ]]; then
                cache_file="/tmp/npm-audit-cache-${cache_key}.json"

                # Check if cache exists and is valid (less than 60 minutes old)
                if [[ -f "$cache_file" ]]; then
                    if find "$cache_file" -mmin -60 2>/dev/null | grep -q .; then
                        log_info "Using cached npm audit results (cache key: ${cache_key:0:8}...)"
                        use_cache=true
                    else
                        log_info "Cache expired, running fresh npm audit"
                        rm -f -- "$cache_file" 2>/dev/null || true
                    fi
                fi
            fi
        fi

        local audit_output
        if [[ "$use_cache" == true ]]; then
            # Read from cache
            audit_output=$(cat "$cache_file" 2>/dev/null)
        else
            # Run npm audit and cache the results
            if audit_output=$(cd "$PROJECT_ROOT" && npm audit --audit-level=moderate --json 2>/dev/null); then
                # Save to cache with secure permissions
                if [[ -n "$cache_file" ]]; then
                    (umask 077; echo "$audit_output" > "$cache_file") 2>/dev/null || true
                fi
            else
                log_warning "npm audit failed or not available"
            fi
        fi

        if [[ -n "$audit_output" ]]; then
            local vulnerabilities
            vulnerabilities=$(echo "$audit_output" | jq -r '(.metadata.vulnerabilities.moderate // 0) + (.metadata.vulnerabilities.high // 0) + (.metadata.vulnerabilities.critical // 0)' 2>/dev/null)
            [[ "$vulnerabilities" =~ ^[0-9]+$ ]] || vulnerabilities=0

            if [[ $vulnerabilities -gt 0 ]]; then
                report_finding "HIGH" "Dependency Vulnerability" "package.json" "0" "Found $vulnerabilities npm vulnerabilities"
                ((findings++))
            else
                log_success "No npm vulnerabilities found"
            fi
        fi
    fi

    # pip-audit (Python)
    if [[ -f "${PROJECT_ROOT}/requirements.txt" ]] || [[ -f "${PROJECT_ROOT}/Pipfile" ]]; then
        if command -v pip-audit &>/dev/null; then
            log_info "Running pip-audit..."

            local pip_audit_output
            if pip_audit_output=$(cd "$PROJECT_ROOT" && pip-audit --format=json 2>/dev/null); then
                local pip_vulnerabilities
                pip_vulnerabilities=$(echo "$pip_audit_output" | jq -r '.vulnerabilities | length' 2>/dev/null || echo "0")

                if [[ $pip_vulnerabilities -gt 0 ]]; then
                    report_finding "HIGH" "Dependency Vulnerability" "requirements.txt" "0" "Found $pip_vulnerabilities Python vulnerabilities"
                    ((findings++))
                else
                    log_success "No Python vulnerabilities found"
                fi
            else
                log_warning "pip-audit failed"
            fi
        else
            log_info "pip-audit not installed, skipping Python dependency check"
        fi
    fi

    return 0
}

# Check 9: Insecure Authentication
check_insecure_auth() {
    log_info "Checking for insecure authentication patterns..."

    local findings=0

    # Hardcoded JWT secrets
    if safe_git_grep "jwt\.sign\(.*[\"'][^\"']{8,}[\"']" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            if ! echo "$content" | grep -qE "process\.env"; then
                report_finding "HIGH" "Insecure Auth" "$file" "$line" "Hardcoded JWT secret detected"
                ((findings++))
            fi
        done < <(safe_git_grep "jwt\.sign\(.*[\"'][^\"']{8,}[\"']" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # Weak session secrets
    if safe_git_grep "session.*secret.*[\"'](test|secret|12345|password)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "HIGH" "Insecure Auth" "$file" "$line" "Weak session secret detected"
            ((findings++))
        done < <(safe_git_grep "session.*secret.*[\"'](test|secret|12345|password)" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No insecure authentication patterns found"
    else
        log_error "Found $findings authentication issues"
    fi

    return 0
}

# Check 10: CORS Misconfigurations
check_cors() {
    log_info "Checking for CORS misconfigurations..."

    local findings=0

    # Overly permissive CORS
    if safe_git_grep "Access-Control-Allow-Origin.*\*" -- ':(exclude)node_modules/*' ':(exclude)*.test.*'; then
        while IFS=: read -r file line content; do
            report_finding "MEDIUM" "CORS Misconfiguration" "$file" "$line" "Overly permissive CORS policy (wildcard)"
            ((findings++))
        done < <(safe_git_grep "Access-Control-Allow-Origin.*\*" -- ':(exclude)node_modules/*' ':(exclude)*.test.*')
    fi

    # CORS with credentials and wildcard
    if safe_git_grep "Access-Control-Allow-Credentials.*true" -- ':(exclude)node_modules/*'; then
        if safe_git_grep "Access-Control-Allow-Origin.*\*" -- ':(exclude)node_modules/*'; then
            report_finding "HIGH" "CORS Misconfiguration" "multiple files" "0" "Credentials with wildcard CORS is dangerous"
            ((findings++))
        fi
    fi

    if [[ $findings -eq 0 ]]; then
        log_success "No CORS misconfigurations found"
    else
        log_warning "Found $findings CORS issues"
    fi

    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log_info "Starting Layer 5: Security Validation"
    log_info "Working directory: $PROJECT_ROOT"

    cd "$PROJECT_ROOT" || {
        log_error "ERROR: Cannot access project directory: $PROJECT_ROOT"
        exit 1
    }

    # Verify git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "ERROR: Not a git repository"
        exit 1
    fi

    # Run all security checks
    check_credentials
    check_sql_injection
    check_xss
    check_command_injection
    check_path_traversal
    check_deprecated_crypto
    check_sensitive_files
    check_dependency_vulnerabilities
    check_insecure_auth
    check_cors

    # Summary
    echo ""
    echo "========================================"
    echo "Security Validation Summary"
    echo "========================================"
    printf "Critical Issues: %d\n" "$CRITICAL_COUNT"
    printf "High Severity:   %d\n" "$HIGH_COUNT"
    printf "Medium Severity: %d\n" "$MEDIUM_COUNT"
    printf "Total Issues:    %d\n" "$TOTAL_ISSUES"
    echo "========================================"

    # Exit with appropriate code
    if [[ $CRITICAL_COUNT -gt 0 ]] || [[ $HIGH_COUNT -gt 0 ]]; then
        log_error "Security validation FAILED: Critical or high severity issues found"
        exit 1
    elif [[ $MEDIUM_COUNT -gt 0 ]]; then
        log_warning "Security validation passed with warnings"
        exit 0
    else
        log_success "Security validation PASSED: No issues found"
        exit 0
    fi
}

# Trap errors
trap 'log_error "ERROR: Script failed at line $LINENO"' ERR

# Run main function
main "$@"
