# Backend API Development

## Quality Standards

### API Design
- RESTful principles: Resource-based URLs, appropriate HTTP methods
- OpenAPI 3.0+ specification: Required, auto-generated with swagger-ui
- Versioning: `/api/v1/` format, version bump on breaking changes
- Unified error responses: RFC 7807 Problem Details format recommended
- Idempotency: Use `Idempotency-Key` header for POST/PUT on payment/order endpoints

### Type Safety
- TypeScript (Node.js): strict mode, zero type errors
- Python: Type Hints + mypy, Pydantic v2 usage
- Go: Static typing, nil safety
- Rust: Ownership system, careful unwrap() usage

### Testing Strategy
- Unit tests: Function/method level, 80%+ coverage
- Integration tests: API endpoints, database integration
- E2E tests: User scenario-based
- Load tests: Production-level RPS (Requests Per Second) verification

## Security

### OWASP API Security Top 10 2023 Compliance
1. **Broken Object Level Authorization (BOLA)**: Verify user authorization for accessed objects, prevent unauthorized access to other users' data
2. **Broken Authentication**: JWT + Refresh Token with expiration, OAuth 2.0, multi-factor authentication
3. **Broken Object Property Level Authorization**: Property-level access control, prevent mass assignment and excessive data exposure
4. **Unrestricted Resource Consumption**: Rate limiting (IP/user-based), request size limits, timeout configuration, prevent DoS
5. **Broken Function Level Authorization**: RBAC implementation, endpoint-level authorization checks
6. **Unrestricted Access to Sensitive Business Flows**: Business logic rate limiting, CAPTCHA, anomaly detection for critical flows
7. **Server-Side Request Forgery (SSRF)**: Validate and sanitize URLs, whitelist allowed domains, disable unnecessary protocols
8. **Security Misconfiguration**: Secure defaults, environment variables for secrets, disable debug mode in production
9. **Improper Inventory Management**: API versioning, deprecation policies, documentation of all endpoints and data flows
10. **Unsafe Consumption of APIs**: Validate responses from external APIs, implement timeout and circuit breakers

### Secrets Management

**Never** store secrets in code or `.env` files committed to Git. Use a secrets manager:

```javascript
// Production: AWS Secrets Manager
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

const client = new SecretsManagerClient({ region: 'ap-northeast-1' });

async function getSecret(secretName) {
  const { SecretString } = await client.send(
    new GetSecretValueCommand({ SecretId: secretName })
  );
  return JSON.parse(SecretString);
}

// Startup: load secrets once
const secrets = await getSecret('myapp/production');
process.env.JWT_SECRET = secrets.jwtSecret;
```

**Alternatives**: GCP Secret Manager, HashiCorp Vault, Azure Key Vault

### Authentication & Authorization

#### JWT Authentication (with algorithm pinning)
```javascript
const jwt = require('jsonwebtoken');

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.sendStatus(401);
  }
  const token = authHeader.split(' ')[1];

  // Always specify algorithm to prevent alg:none attacks
  jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] }, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
}

// Token generation: always specify algorithm explicitly
const token = jwt.sign(
  { userId: user.id, role: user.role },
  process.env.JWT_SECRET,
  { algorithm: 'HS256', expiresIn: '15m' }
);
```

#### Refresh Token Management (with Redis invalidation)
```javascript
const redis = require('redis');
const redisClient = redis.createClient();

// Generate Refresh Token and store in Redis
async function issueRefreshToken(userId) {
  const refreshToken = jwt.sign(
    { userId },
    process.env.REFRESH_TOKEN_SECRET,
    { algorithm: 'HS256', expiresIn: '7d' }
  );

  // Store in Redis with 7-day TTL; key allows per-user invalidation
  const key = `refresh_token:${userId}:${refreshToken}`;
  await redisClient.setEx(key, 7 * 24 * 60 * 60, '1');

  return refreshToken;
}

// Refresh endpoint: validate, rotate, invalidate old token
app.post('/api/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.sendStatus(401);

  let payload;
  try {
    payload = jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET, {
      algorithms: ['HS256'],
    });
  } catch {
    return res.sendStatus(403);
  }

  // Verify token exists in Redis (not revoked)
  const key = `refresh_token:${payload.userId}:${refreshToken}`;
  const exists = await redisClient.get(key);
  if (!exists) return res.sendStatus(403);

  // Rotate: delete old token, issue new pair
  await redisClient.del(key);
  const newAccessToken = jwt.sign(
    { userId: payload.userId },
    process.env.JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '15m' }
  );
  const newRefreshToken = await issueRefreshToken(payload.userId);

  res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
});

// Logout: invalidate refresh token
app.post('/api/auth/logout', authenticateToken, async (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) {
    const key = `refresh_token:${req.user.userId}:${refreshToken}`;
    await redisClient.del(key);
  }
  res.sendStatus(204);
});

// Revoke all sessions (password change, account compromise)
async function revokeAllSessions(userId) {
  const keys = await redisClient.keys(`refresh_token:${userId}:*`);
  if (keys.length > 0) await redisClient.del(keys);
}
```

#### Authorization Check (RBAC + BOLA)
```javascript
// Role-based authorization (RBAC)
function authorizeRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return res.sendStatus(401); // Guard against missing authenticateToken
    if (!roles.includes(req.user.role)) {
      return res.sendStatus(403);
    }
    next();
  };
}

app.get('/api/admin/users',
  authenticateToken,
  authorizeRole('admin'),
  getUsers
);

// Object-level authorization (BOLA prevention — OWASP API #1)
app.get('/api/orders/:id', authenticateToken, async (req, res) => {
  const order = await Order.findByPk(req.params.id);
  if (!order) return res.sendStatus(404);

  // Always verify the resource belongs to the requesting user
  if (order.userId !== req.user.userId) {
    return res.sendStatus(403); // Do NOT return 404 to avoid resource enumeration
  }
  res.json(order);
});

// Mass Assignment prevention (OWASP API #3)
app.put('/api/users/:id', authenticateToken, async (req, res) => {
  // Allowlist: only permit safe fields, never trust req.body directly
  const { displayName, bio, avatarUrl } = req.body;
  await User.update({ displayName, bio, avatarUrl }, { where: { id: req.params.id } });
  res.json({ success: true });
  // Never: User.update(req.body, ...) — allows overwriting role, password, etc.
});
```

#### Password Hashing
```javascript
// Node.js + bcrypt
const bcrypt = require('bcrypt');

async function createUser(username, password) {
  const saltRounds = 12;
  const hashedPassword = await bcrypt.hash(password, saltRounds);
  return User.create({ username, password: hashedPassword });
}

async function verifyPassword(inputPassword, hashedPassword) {
  return bcrypt.compare(inputPassword, hashedPassword);
}
```

```python
# Python: bcrypt directly (passlib is unmaintained since 2020)
import bcrypt

def hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode(), salt).decode()

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())

# Alternative: argon2-cffi (preferred for new projects)
# pip install argon2-cffi
from argon2 import PasswordHasher
ph = PasswordHasher(time_cost=2, memory_cost=65536, parallelism=2)

def hash_password_argon2(password: str) -> str:
    return ph.hash(password)

def verify_password_argon2(password: str, hashed: str) -> bool:
    return ph.verify(hashed, password)
```

### Security Headers
```javascript
// helmet.js (Node.js + Express)
const helmet = require('helmet');

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

### CORS Configuration
```javascript
// Node.js + Express
const cors = require('cors');

const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

if (allowedOrigins.length === 0) {
  throw new Error('ALLOWED_ORIGINS must be set');
}

app.use(cors({
  origin: allowedOrigins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

```python
# Python + FastAPI
import os
from fastapi.middleware.cors import CORSMiddleware

allowed_origins_raw = os.getenv("ALLOWED_ORIGINS", "")
allowed_origins = [o.strip() for o in allowed_origins_raw.split(",") if o.strip()]

if not allowed_origins:
    raise RuntimeError("ALLOWED_ORIGINS must be set")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Content-Type", "Authorization"],
)
```

### CSRF Protection

Cookie-based auth requires CSRF protection. JWT in `Authorization` header is CSRF-safe by default.

```javascript
// Node.js + Express: CSRF token middleware
const crypto = require('crypto');

// Generate CSRF token on session start
app.use((req, res, next) => {
  if (!req.session.csrfToken) {
    req.session.csrfToken = crypto.randomBytes(32).toString('hex');
  }
  next();
});

// Validate CSRF token on state-changing requests
function validateCsrf(req, res, next) {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
  const token = req.headers['x-csrf-token'] || req.body._csrf;
  if (!token || token !== req.session.csrfToken) {
    return res.status(403).json({ error: 'Invalid CSRF token' });
  }
  next();
}

app.use(validateCsrf);
// Frontend: include X-CSRF-Token header from session endpoint
```

**Alternative**: Set `SameSite=Strict` on session cookies (blocks cross-site submission without a token).

### Input Validation
```python
# Pydantic v2 input validation (Python + FastAPI)
from pydantic import BaseModel, EmailStr, field_validator
from pydantic import StringConstraints
from typing import Annotated

class UserCreate(BaseModel):
    username: Annotated[str, StringConstraints(min_length=3, max_length=20)]
    email: EmailStr
    password: Annotated[str, StringConstraints(min_length=8)]

    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError('At least one uppercase letter required')
        if not any(c.isdigit() for c in v):
            raise ValueError('At least one digit required')
        return v

@app.post("/users")
async def create_user(user: UserCreate):
    return {"username": user.username}
```

### Injection Prevention

#### SQL Injection
```python
# Bad: string interpolation
def get_user(username):
    return db.execute(f"SELECT * FROM users WHERE username = '{username}'")

# Good: parameterized query
def get_user(username):
    return db.execute("SELECT * FROM users WHERE username = ?", (username,))

# Good: ORM (SQLAlchemy 2.x style)
from sqlalchemy import select
def get_user(username: str):
    return session.execute(select(User).where(User.username == username)).scalar_one_or_none()
```

#### NoSQL Injection (MongoDB)
```javascript
// Bad: user input directly in query operator
app.post('/api/login', async (req, res) => {
  const user = await User.findOne({ password: req.body.password }); // $where injection possible
});

// Good: strict type validation before query
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;
  if (typeof username !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ error: 'Invalid input' });
  }
  const user = await User.findOne({ username }); // separate lookup then bcrypt compare
  if (!user || !(await bcrypt.compare(password, user.password))) {
    return res.sendStatus(401);
  }
  res.json({ token: issueToken(user) });
});
```

#### Command Injection
```javascript
// Bad: user input in shell command
const { exec } = require('child_process');
exec(`convert ${req.body.filename} output.png`); // rm -rf / possible

// Good: use argument arrays, never string interpolation
const { execFile } = require('child_process');
execFile('convert', [req.body.filename, 'output.png']); // shell never invoked
```

### SSRF Prevention
```javascript
// API7: Server-Side Request Forgery prevention
const dns = require('dns').promises;

// Whitelist of allowed domains (explicit allowlist, not blocklist)
const ALLOWED_DOMAINS = new Set(['api.trusted-service.com', 'data.partner.com']);

// Private IP ranges: IPv4 + IPv6 loopback/link-local/private
function isPrivateIP(ip) {
  return /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.)/.test(ip)
    || /^(::1|fc[0-9a-f]{2}:|fd[0-9a-f]{2}:)/.test(ip); // IPv6 private
}

async function fetchExternalResource(userProvidedUrl) {
  let parsed;
  try {
    parsed = new URL(userProvidedUrl); // WHATWG URL API (url.parse is deprecated)
  } catch {
    throw new Error('Invalid URL format');
  }

  if (parsed.protocol !== 'https:') {
    throw new Error('Only HTTPS protocol is allowed');
  }

  if (!ALLOWED_DOMAINS.has(parsed.hostname)) {
    throw new Error('Domain not allowed');
  }

  // Resolve all IPs; block if any resolves to private range (DNS Rebinding note below)
  const addresses = await dns.resolve(parsed.hostname).catch(() => {
    throw new Error('DNS resolution failed');
  });
  for (const ip of addresses) {
    if (isPrivateIP(ip)) {
      throw new Error('Access to private IP ranges is forbidden');
    }
  }

  // NOTE: DNS Rebinding risk remains between this check and the actual request.
  // For high-security contexts use a dedicated SSRF-safe HTTP library
  // (e.g. node-ssrf-filter) that binds to the resolved IP directly.
  return fetch(userProvidedUrl, { signal: AbortSignal.timeout(5000) });
}
```

### Business Flow Protection
```javascript
// API6: Unrestricted Access to Sensitive Business Flows
// IMPORTANT: RateLimiterMemory is single-process only.
// In multi-server/multi-process deployments use RateLimiterRedis instead.
const { RateLimiterRedis } = require('rate-limiter-flexible');
const redis = require('redis');
const redisClient = redis.createClient();

const purchaseLimiter = new RateLimiterRedis({
  storeClient: redisClient,
  points: 5,      // 5 purchases
  duration: 3600, // per hour per user
  keyPrefix: 'purchase',
});

const accountCreationLimiter = new RateLimiterRedis({
  storeClient: redisClient,
  points: 3,       // 3 accounts
  duration: 86400, // per day per IP
  keyPrefix: 'account_creation',
});

app.post('/api/purchase', authenticateToken, async (req, res) => {
  try {
    await purchaseLimiter.consume(req.user.id);
  } catch {
    return res.status(429).json({ error: 'Too many purchase attempts' });
  }

  try {
    const recentPurchases = await getUserRecentPurchases(req.user.id, 10);
    if (detectAnomalousPattern(recentPurchases, req.body)) {
      return res.status(429).json({
        error: 'Unusual activity detected. Please verify your identity.'
      });
    }
    const result = await processPurchase(req.body);
    res.json(result);
  } catch (error) {
    throw error; // bubble up to error handler
  }
});

function detectAnomalousPattern(recentPurchases, currentPurchase) {
  if (recentPurchases.length === 0) return false; // No history: no baseline to compare
  const avgAmount = recentPurchases.reduce((sum, p) => sum + p.amount, 0) / recentPurchases.length;
  return currentPurchase.amount > avgAmount * 10;
}
```

### External API Consumption Safety
```javascript
// API10: Unsafe Consumption of APIs
const axios = require('axios');
const Joi = require('joi');

const userResponseSchema = Joi.object({
  id: Joi.number().required(),
  email: Joi.string().email().required(),
  name: Joi.string().max(100).required(),
  role: Joi.string().valid('user', 'admin').required()
});

async function fetchExternalUserData(userId) {
  try {
    const response = await axios.get(`https://external-api.com/users/${userId}`, {
      timeout: 5000,
      maxRedirects: 0,
      validateStatus: (status) => status === 200
    });

    const { error, value } = userResponseSchema.validate(response.data, {
      stripUnknown: true
    });

    if (error) {
      throw new Error(`Invalid response format from external API`); // Don't leak details
    }

    return value;
  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      throw new Error('External API timeout');
    }
    throw error;
  }
}

// Circuit breaker — NOTE: this is an in-memory singleton.
// In Serverless (AWS Lambda, Cloud Functions) each invocation may create a new instance,
// defeating the breaker. Use a Redis-backed implementation (e.g. opossum + Redis store)
// for Serverless or multi-instance deployments.
class CircuitBreaker {
  constructor(threshold = 5, timeout = 60000) {
    this.failureCount = 0;
    this.successCount = 0;
    this.threshold = threshold;
    this.timeout = timeout;
    this.state = 'CLOSED';
    this.nextAttempt = Date.now();
  }

  async execute(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() < this.nextAttempt) {
        throw new Error('Circuit breaker is OPEN');
      }
      this.state = 'HALF_OPEN';
      this.successCount = 0;
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= 2) { // require 2 successes to close
        this.state = 'CLOSED';
        this.failureCount = 0;
      }
    } else {
      this.failureCount = 0;
    }
  }

  onFailure() {
    this.failureCount++;
    if (this.state === 'HALF_OPEN' || this.failureCount >= this.threshold) {
      this.state = 'OPEN';
      this.nextAttempt = Date.now() + this.timeout;
      this.failureCount = 0;
    }
  }
}

const externalApiBreaker = new CircuitBreaker();

app.get('/api/external-user/:id', async (req, res) => {
  try {
    const userData = await externalApiBreaker.execute(() =>
      fetchExternalUserData(req.params.id)
    );
    res.json(userData);
  } catch (error) {
    res.status(503).json({ error: 'External service unavailable' });
  }
});
```

## Performance

### Response Time Targets
- P95: < 200ms (95% of requests within 200ms)
- P99: < 500ms (99% of requests within 500ms)
- Maximum: < 2000ms (timeout setting)
- Note: targets are for typical CRUD endpoints; heavy analytics queries may have separate SLOs

### Throughput
- Small scale (<10K users): 100-500 RPS
- Medium scale (10K-100K users): 500-2000 RPS
- Large scale (100K+ users): 2000+ RPS
- Scaling: Horizontal scaling support, stateless design

### Database Optimization

#### N+1 Problem Resolution
```javascript
// Bad: N+1 problem
const users = await User.findAll();
for (const user of users) {
  user.posts = await Post.findAll({ where: { userId: user.id } });
}
// Query count: 1 + N

// Good: Eager Loading (Sequelize issues a JOIN or separate IN-query depending on association type)
const users = await User.findAll({
  include: [{
    model: Post,
    attributes: ['id', 'title', 'createdAt']
  }]
});
// Query count: 1-2 (JOIN or batched IN), not N+1
```

#### Connection Pooling
```javascript
// Node.js + PostgreSQL
const { Pool } = require('pg');

// Sizing formula: max = Math.floor(max_connections / (num_services * processes_per_service))
// PostgreSQL default max_connections = 100
// Example: 2 services × 2 processes = pool max 25 each
const pool = new Pool({
  max: 20,                      // Adjust based on formula above
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
```

#### Transaction Management
```javascript
// Always wrap multi-step writes in a transaction to prevent partial failures
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, fromId]);
  await client.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, toId]);
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
}
```

```python
# SQLAlchemy 2.x transaction
from sqlalchemy.orm import Session

with Session(engine) as session:
    with session.begin():
        session.execute(
            update(Account).where(Account.id == from_id)
            .values(balance=Account.balance - amount)
        )
        session.execute(
            update(Account).where(Account.id == to_id)
            .values(balance=Account.balance + amount)
        )
    # Commits on exit, rolls back on exception
```

#### Bulk Operations
```javascript
// Bad: N INSERTs
for (const item of items) {
  await db.insert(item);
}

// Good: Single bulk INSERT
await User.bulkCreate(items);
```

#### Index Placement Criteria
- WHERE clause usage: Required
- JOIN conditions: Required
- ORDER BY: Recommended if query frequency > 10/sec
- Cardinality < 10%: Not required

### Caching Strategy
- Redis: Sessions, Refresh Tokens, frequent query results (with explicit TTL + invalidation)
- CDN: Static assets, API GET responses (with proper Cache-Control headers)
- In-memory cache: In-process caching (short TTL, single-process only)

### Idempotency for Critical Operations
```javascript
// Prevent duplicate charges/orders from network retries
app.post('/api/orders', authenticateToken, async (req, res) => {
  const idempotencyKey = req.headers['idempotency-key'];
  if (!idempotencyKey) {
    return res.status(400).json({ error: 'Idempotency-Key header required' });
  }

  // Check if this key was already processed
  const cacheKey = `idempotency:${idempotencyKey}`;
  const cached = await redisClient.get(cacheKey);
  if (cached) {
    return res.status(200).json(JSON.parse(cached)); // Return same response
  }

  const order = await createOrder(req.body, req.user.id);
  const response = { orderId: order.id, status: order.status };

  // Store result for 24 hours
  await redisClient.setEx(cacheKey, 86400, JSON.stringify(response));
  res.status(201).json(response);
});
```

## Implementation Guide

### API Documentation Generation
```javascript
// Swagger UI auto-generation (Node.js + Express)
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const options = {
  definition: {
    openapi: '3.1.0',
    info: { title: 'API Documentation', version: '1.0.0' },
    servers: [{ url: '/api/v1' }],
  },
  apis: ['./routes/*.js'],
};

const specs = swaggerJsdoc(options);

// IMPORTANT: Restrict Swagger UI in production to prevent API schema exposure
if (process.env.NODE_ENV !== 'production') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs));
} else {
  // In production: protect with auth, or disable entirely
  app.use('/api-docs', authenticateToken, authorizeRole('admin'), swaggerUi.serve, swaggerUi.setup(specs));
}
```

```python
# FastAPI (auto-generated)
from fastapi import FastAPI
import os

# Disable docs in production, or protect them
app = FastAPI(
    title="API Documentation",
    version="1.0.0",
    openapi_url="/api/v1/openapi.json" if os.getenv("ENV") != "production" else None,
    docs_url="/api-docs" if os.getenv("ENV") != "production" else None,
)
```

### Error Handling
```javascript
// RFC 7807 Problem Details implementation
class ApiError extends Error {
  constructor(status, title, detail) {
    super(detail);
    this.status = status;
    this.title = title;
    this.isOperational = true; // Distinguish from unexpected errors
  }
}

// Error handler middleware: never expose internal details to clients
app.use((err, req, res, next) => {
  const isOperational = err.isOperational === true;
  const statusCode = isOperational ? err.status : 500;

  // Log full error internally (never sent to client)
  logger.error({
    err: { message: err.message, stack: err.stack },
    requestId: req.headers['x-request-id'],
    path: req.path,
    method: req.method,
  });

  res.status(statusCode).json({
    type: `https://api.example.com/errors/${statusCode}`,
    title: isOperational ? err.title : 'Internal Server Error',
    status: statusCode,
    // Only safe, user-facing messages reach the client
    detail: isOperational ? err.message : 'An unexpected error occurred',
    instance: req.path,
  });
});

// Usage
throw new ApiError(404, 'Not Found', 'User not found');
```

### Database Migrations
```javascript
// Prisma Migrate
// schema.prisma
model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  password  String
  createdAt DateTime @default(now())
}

// Run migrations
// Development: npx prisma migrate dev --name add_user_table
// Production: npx prisma migrate deploy
```

```python
# Alembic (SQLAlchemy)
# Create migration
# alembic revision --autogenerate -m "add user table"

# Run migration
# alembic upgrade head
```

### Structured Logging
```javascript
// Winston (Node.js)
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'api' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// NEVER log PII (email, phone, SSN, etc.) — use IDs only
logger.info('User created', { userId: 123 }); // OK
// logger.info('User created', { email: 'user@example.com' }); // GDPR violation risk

// Attach request ID for distributed tracing
app.use((req, res, next) => {
  req.requestId = req.headers['x-request-id'] || crypto.randomUUID();
  res.setHeader('x-request-id', req.requestId);
  next();
});
```

### Health Checks
```javascript
// /health, /ready endpoints
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/ready', async (req, res) => {
  const dbOk = await checkDatabase();
  const redisOk = await checkRedis();

  if (dbOk && redisOk) {
    res.json({ status: 'ready' });
  } else {
    res.status(503).json({ status: 'not ready' });
  }
});
```

## Practical Examples

### Case 1: N+1 Problem Resolution
```javascript
// Situation: User list retrieval is slow (5 seconds)

// Bad: N+1 problem
async function getUsers() {
  const users = await User.findAll();
  for (const user of users) {
    user.posts = await Post.findAll({ where: { userId: user.id } });
  }
  return users;
}
// Query count: 1 + N

// Good: Eager Loading
async function getUsers() {
  return await User.findAll({
    include: [{ model: Post, attributes: ['id', 'title', 'createdAt'] }]
  });
}
// Result: 5s → 0.2s (25x faster)
```

### Case 2: Rate Limiting Implementation
```javascript
// Situation: API abuse causing overload

const rateLimit = require('express-rate-limit');

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests from this IP, please try again after 15 minutes.',
  standardHeaders: true,
  legacyHeaders: false
});

// Strict limits for auth endpoints
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true
});

app.use('/api/', apiLimiter);
app.use('/api/auth/', authLimiter);
```

#### Distributed Environment (Redis) — Required for multi-server
```javascript
const RedisStore = require('rate-limit-redis');
const redis = require('redis');
const client = redis.createClient();

const limiter = rateLimit({
  store: new RedisStore({ client, prefix: 'rl:' }),
  windowMs: 15 * 60 * 1000,
  max: 100
});
```

### Case 3: SQL Injection Prevention
```python
# Bad: SQL injection vulnerability
def get_user(username):
    query = f"SELECT * FROM users WHERE username = '{username}'"
    return db.execute(query)
# Attack: username = "admin' OR '1'='1" → leaks all users

# Good: ORM (SQLAlchemy 2.x)
def get_user(username: str):
    return session.execute(select(User).where(User.username == username)).scalar_one_or_none()

# Good: Parameterized query
def get_user(username: str):
    return db.execute("SELECT * FROM users WHERE username = ?", (username,))
```

## Technology Stack Selection Guide

| Technology | Use Cases | Key Features | Considerations |
|------------|-----------|--------------|----------------|
| Node.js | High concurrency, real-time, JavaScript ecosystem | Event loop, async I/O, rich npm ecosystem | Not suitable for CPU-intensive tasks |
| Python | Data processing, ML integration, rapid development | Rich libraries, high readability | GIL (multithreading limitations) |
| Go | High performance, concurrency, cloud-native | Lightweight, fast compilation, goroutines | Verbose error handling |
| Rust | Maximum performance, memory safety, systems programming | Ownership system, zero-cost abstractions | Steep learning curve |

### Framework Selection

| Language | Framework | Features |
|----------|-----------|----------|
| Node.js | Express | Lightweight, flexible, rich ecosystem |
| Node.js | NestJS | TypeScript, DI, enterprise-ready |
| Node.js | Hono | Ultra-fast, edge-ready, TypeScript-first |
| Python | FastAPI | High performance, type-safe, auto API docs |
| Python | Django | Full-stack, ORM, admin UI |
| Go | Gin | High performance, simple |
| Go | Echo | Lightweight, rich middleware |
| Rust | Actix-web | Maximum performance |
| Rust | Axum | Type-safe, Tokio-native |
