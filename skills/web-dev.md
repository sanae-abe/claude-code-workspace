---
allowed-tools: Bash, Read, AskUserQuestion, TodoWrite
argument-hint: "[port]"
description: "Start frontend development server with framework auto-detection"
model: sonnet
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
    echo "ERROR [web-dev.md:17]: Port must be numeric"
    echo "  Input: $port"
    echo "  Allowed: numbers only (1024-65535)"
    exit 2
  fi

  # Range validation
  if [[ "$port" -lt 1024 || "$port" -gt 65535 ]]; then
    echo "ERROR [web-dev.md:17]: Port out of range"
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
detect_framework() {
  # Priority order: Vite > Next.js > Vue > React
  if [[ -f "vite.config.ts" ]] || [[ -f "vite.config.js" ]]; then
    echo "vite"
  elif [[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]]; then
    echo "next"
  elif [[ -f "vue.config.js" ]] || [[ -f "src/main.js" ]]; then
    echo "vue"
  elif [[ -f "src/index.js" ]] || [[ -f "src/App.js" ]]; then
    echo "react"
  else
    echo "unknown"
  fi
}

start_server() {
  local framework="$1"
  local port="$2"

  case "$framework" in
    vite)
      echo "Starting Vite development server on port $port"
      npm run dev -- --port "$port" || yarn dev --port "$port"
      ;;
    next)
      echo "Starting Next.js development server on port $port"
      npm run dev -- --port "$port" || yarn dev --port "$port"
      ;;
    vue)
      echo "Starting Vue.js development server on port $port"
      npm run serve -- --port "$port" || npm run dev -- --port "$port"
      ;;
    react)
      echo "Starting React development server on port $port"
      PORT="$port" npm start || PORT="$port" yarn start
      ;;
    *)
      echo "ERROR [web-dev.md:52]: Unsupported framework"
      echo "  Supported: Vite, Next.js, Vue, React"
      echo "  Detection: Check for vite.config.ts, next.config.js, vue.config.js, src/index.js"
      exit 3
      ;;
  esac
}

# Execute
FRAMEWORK=$(detect_framework)
start_server "$FRAMEWORK" "$PORT"
```

## Error Handling

Error classification and recovery:

**Port conflicts**:
- Check process using port: `lsof -i :PORT`
- Suggest kill command: `kill -9 PID`
- Alternative: Try different port

**Missing dependencies**:
- Report missing packages with installation command
- Run: `npm install` or `yarn install`

**Framework detection failure**:
- Verify project structure (config files, src directory)
- Supported frameworks: Vite, Next.js, Vue, React

**Server startup failure**:
- Check error message for specific cause
- Common issues: port conflict, missing dependencies, invalid configuration
- Recovery: reinstall dependencies, clear cache, check configuration files

Error message format:
```bash
echo "ERROR [web-dev.md:LINE]: Error description"
echo "  Context: Additional information"
echo "  Solution: User-actionable fix"
```

Security:
- Never expose absolute file paths
- Report only relative paths from project root
- Never expose internal configuration details

## Quality Checks

After server startup, run quality validation:

```bash
# Delegate to /validate command
echo ""
echo "💡 Run quality checks: /validate --layers=syntax,security"
echo "   This will verify TypeScript types, ESLint rules, and security"
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
