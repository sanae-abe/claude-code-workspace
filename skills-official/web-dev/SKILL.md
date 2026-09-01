---
name: web-dev
description: "Start frontend development server with framework auto-detection"
disable-model-invocation: true
---

# Web Development Server Startup

## Argument Validation and Sanitization

Parse and validate $ARGUMENTS with security-first approach:

```bash
validate_port() {
  local port="$1"

  # Default ports if no argument
  if [[ -z "$port" ]]; then
    echo "3000"  # Default
    return 0
  fi

  # Numeric validation only
  if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Port must be numeric"
    echo "  Input: $port"
    echo "  Allowed: numbers only (1024-65535)"
    exit 2
  fi

  # Range validation
  if [[ "$port" -lt 1024 || "$port" -gt 65535 ]]; then
    echo "ERROR: Port out of range"
    echo "  Input: $port"
    echo "  Allowed: 1024-65535"
    exit 2
  fi

  echo "$port"
}

PORT=$(validate_port "$ARGUMENTS")
```

## Execution Flow

1. Parse and validate port argument with strict input sanitization
2. Detect frontend framework (Vite/Next.js/Vue/React)
3. Start development server on specified port
4. Report server URL and health status

## Framework Detection and Startup

Automatically detect framework and start development server:

```bash
detect_package_manager() {
  if [[ -f "bun.lockb" ]]; then echo "bun"
  elif [[ -f "pnpm-lock.yaml" ]]; then echo "pnpm"
  elif [[ -f "yarn.lock" ]]; then echo "yarn"
  else echo "npm"
  fi
}

detect_framework() {
  # Priority order: config files first (most reliable)
  if [[ -f "vite.config.ts" ]] || [[ -f "vite.config.js" ]]; then
    echo "vite"
  elif [[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]] || [[ -f "next.config.mjs" ]]; then
    echo "next"
  elif [[ -f "nuxt.config.ts" ]] || [[ -f "nuxt.config.js" ]]; then
    echo "nuxt"
  elif [[ -f "vue.config.js" ]] || [[ -f "vue.config.ts" ]]; then
    echo "vue"
  elif [[ -f "package.json" ]]; then
    # Fall back to package.json dependency inspection
    if grep -q '"react"' package.json; then echo "react"
    elif grep -q '"vue"' package.json; then echo "vue"
    else echo "unknown"
    fi
  else
    echo "unknown"
  fi
}

start_server() {
  local framework="$1"
  local port="$2"
  local pm="$3"

  case "$framework" in
    vite|next|nuxt|vue)
      echo "Starting $framework development server on port $port (using $pm)"
      "$pm" run dev -- --port "$port"
      ;;
    react)
      echo "Starting React development server on port $port (using $pm)"
      PORT="$port" "$pm" start
      ;;
    *)
      echo "ERROR: Unsupported framework"
      echo "  Supported: Vite, Next.js, Nuxt, Vue, React"
      echo "  Detection: Check for vite.config.ts/js, next.config.js/ts, nuxt.config.ts/js, vue.config.js, package.json"
      exit 3
      ;;
  esac
}

# Execute
PM=$(detect_package_manager)
FRAMEWORK=$(detect_framework)
start_server "$FRAMEWORK" "$PORT" "$PM"
```

## Error Handling

Error classification and recovery:

**Port conflicts**:
- Check process using port: `lsof -i :PORT`
- Suggest kill command: `kill -9 PID`
- Alternative: Try different port

**Missing dependencies**:
- Report missing packages with installation command
- Run: `npm install` / `pnpm install` / `yarn install` / `bun install`

**Framework detection failure**:
- Verify project structure (config files, src directory)
- Supported frameworks: Vite, Next.js, Nuxt, Vue, React

**Server startup failure**:
- Check error message for specific cause
- Common issues: port conflict, missing dependencies, invalid configuration
- Recovery: reinstall dependencies, clear cache, check configuration files

Error message format:
```bash
echo "ERROR: Error description"
echo "  Context: Additional information"
echo "  Solution: User-actionable fix"
```

Security:
- Never expose absolute file paths
- Report only relative paths from project root
- Never expose internal configuration details

## Quality Checks

After server startup, suggest running quality checks:

```
Run quality checks: /validate --layers=syntax,security
```

Note: Quality and security checks are delegated to `/validate` command to avoid duplication.

## Examples

```bash
# Start with default port (3000 for React, 5173 for Vite)
/web-dev

# Start on specific port
/web-dev 3001

# Start on port 8080
/web-dev 8080
```

## Exit Codes

- 0: Success - Development server started successfully
- 2: Validation failure - Invalid port, out of range
- 3: System error - Unsupported framework, server startup failed
