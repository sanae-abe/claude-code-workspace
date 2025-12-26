# Backend API Development

## Quality Standards

### API Design
- RESTful principles: Resource-based URLs, appropriate HTTP methods
- OpenAPI 3.0+ specification: Required, auto-generated with swagger-ui
- Versioning: `/api/v1/` format, version bump on breaking changes
- Unified error responses: RFC 7807 Problem Details format recommended

### Type Safety
- TypeScript (Node.js): strict mode, zero type errors
- Python: Type Hints + mypy, Pydantic usage
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

### Authentication & Authorization

#### JWT Authentication (with expiration)
```javascript
const jwt = require('jsonwebtoken');

function authenticateToken(req, res, next) {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.sendStatus(401);

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
}

// Token generation (15 min expiration)
const token = jwt.sign(
  { userId: user.id, role: user.role },
  process.env.JWT_SECRET,
  { expiresIn: '15m' }
);

// Refresh Token (7 day expiration)
const refreshToken = jwt.sign(
  { userId: user.id },
  process.env.REFRESH_TOKEN_SECRET,
  { expiresIn: '7d' }
);
```

#### Authorization Check
```javascript
function authorizeRole(...roles) {
  return (req, res, next) => {
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
```

#### Password Hashing
```javascript
// Node.js + bcrypt
const bcrypt = require('bcrypt');

// User registration
async function createUser(username, password) {
  const saltRounds = 12;
  const hashedPassword = await bcrypt.hash(password, saltRounds);

  return User.create({
    username,
    password: hashedPassword
  });
}

// Login verification
async function verifyPassword(inputPassword, hashedPassword) {
  return await bcrypt.compare(inputPassword, hashedPassword);
}
```

```python
# Python + passlib
from passlib.hash import bcrypt

# User registration
def create_user(username: str, password: str):
    hashed = bcrypt.hash(password)
    return User(username=username, password=hashed)

# Login verification
def verify_password(input_password: str, hashed: str) -> bool:
    return bcrypt.verify(input_password, hashed)
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

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS.split(','),
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

```python
# Python + FastAPI
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS").split(","),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Content-Type", "Authorization"],
)
```

### Input Validation
```python
# Pydantic input validation (Python + FastAPI)
from pydantic import BaseModel, EmailStr, constr, validator

class UserCreate(BaseModel):
    username: constr(min_length=3, max_length=20)
    email: EmailStr
    password: constr(min_length=8)

    @validator('password')
    def validate_password(cls, v):
        if not any(c.isupper() for c in v):
            raise ValueError('At least one uppercase letter required')
        if not any(c.isdigit() for c in v):
            raise ValueError('At least one digit required')
        return v

@app.post("/users")
async def create_user(user: UserCreate):
    return {"username": user.username}
```

### SSRF Prevention
```javascript
// API7: Server-Side Request Forgery prevention
const url = require('url');

// Whitelist of allowed domains
const ALLOWED_DOMAINS = ['api.trusted-service.com', 'data.partner.com'];

async function fetchExternalResource(userProvidedUrl) {
  const parsed = url.parse(userProvidedUrl);

  // Validate protocol (only allow HTTPS)
  if (parsed.protocol !== 'https:') {
    throw new Error('Only HTTPS protocol is allowed');
  }

  // Validate domain against whitelist
  if (!ALLOWED_DOMAINS.includes(parsed.hostname)) {
    throw new Error('Domain not allowed');
  }

  // Prevent access to private IP ranges
  const ip = await dns.resolve(parsed.hostname);
  if (isPrivateIP(ip)) {
    throw new Error('Access to private IP ranges is forbidden');
  }

  return fetch(userProvidedUrl, { timeout: 5000 });
}

function isPrivateIP(ip) {
  return /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.)/.test(ip);
}
```

### Business Flow Protection
```javascript
// API6: Unrestricted Access to Sensitive Business Flows
const { RateLimiterMemory } = require('rate-limiter-flexible');

// Business logic rate limiting for sensitive operations
const purchaseLimiter = new RateLimiterMemory({
  points: 5, // 5 purchases
  duration: 3600, // per hour per user
});

const accountCreationLimiter = new RateLimiterMemory({
  points: 3, // 3 accounts
  duration: 86400, // per day per IP
});

app.post('/api/purchase', authenticateToken, async (req, res) => {
  try {
    // Check purchase rate limit
    await purchaseLimiter.consume(req.user.id);

    // Anomaly detection: check for unusual patterns
    const recentPurchases = await getUserRecentPurchases(req.user.id, 10);
    if (detectAnomalousPattern(recentPurchases, req.body)) {
      return res.status(429).json({
        error: 'Unusual activity detected. Please verify your identity.'
      });
    }

    // Process purchase
    const result = await processPurchase(req.body);
    res.json(result);
  } catch (error) {
    res.status(429).json({ error: 'Too many purchase attempts' });
  }
});

function detectAnomalousPattern(recentPurchases, currentPurchase) {
  // Example: detect if purchase amount is significantly higher than average
  const avgAmount = recentPurchases.reduce((sum, p) => sum + p.amount, 0) / recentPurchases.length;
  return currentPurchase.amount > avgAmount * 10;
}
```

### External API Consumption Safety
```javascript
// API10: Unsafe Consumption of APIs
const axios = require('axios');
const Joi = require('joi');

// Define expected response schema
const userResponseSchema = Joi.object({
  id: Joi.number().required(),
  email: Joi.string().email().required(),
  name: Joi.string().max(100).required(),
  role: Joi.string().valid('user', 'admin').required()
});

async function fetchExternalUserData(userId) {
  try {
    const response = await axios.get(`https://external-api.com/users/${userId}`, {
      timeout: 5000, // 5 second timeout
      maxRedirects: 0, // Prevent redirect attacks
      validateStatus: (status) => status === 200 // Only accept 200
    });

    // Validate response structure
    const { error, value } = userResponseSchema.validate(response.data, {
      stripUnknown: true // Remove unexpected fields
    });

    if (error) {
      throw new Error(`Invalid response format: ${error.message}`);
    }

    return value;
  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      throw new Error('External API timeout');
    }
    throw error;
  }
}

// Circuit breaker pattern for failing external APIs
class CircuitBreaker {
  constructor(threshold = 5, timeout = 60000) {
    this.failureCount = 0;
    this.threshold = threshold;
    this.timeout = timeout;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.nextAttempt = Date.now();
  }

  async execute(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() < this.nextAttempt) {
        throw new Error('Circuit breaker is OPEN');
      }
      this.state = 'HALF_OPEN';
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
    this.failureCount = 0;
    this.state = 'CLOSED';
  }

  onFailure() {
    this.failureCount++;
    if (this.failureCount >= this.threshold) {
      this.state = 'OPEN';
      this.nextAttempt = Date.now() + this.timeout;
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
// Query count: 1 + N (101 queries for 100 users)

// Good: Eager Loading
const users = await User.findAll({
  include: [{
    model: Post,
    attributes: ['id', 'title', 'createdAt']
  }]
});
// Query count: 1 (using JOIN)
```

#### Connection Pooling
```javascript
// Node.js + PostgreSQL
const { Pool } = require('pg');

const pool = new Pool({
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
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
- Redis: Sessions, frequent query results
- CDN: Static assets, API GET responses (with proper Cache-Control headers)
- In-memory cache: In-process caching (short TTL)

## Implementation Guide

### API Documentation Generation
```javascript
// Swagger UI auto-generation (Node.js + Express)
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const options = {
  definition: {
    openapi: '3.1.0',
    info: {
      title: 'API Documentation',
      version: '1.0.0',
    },
    servers: [{ url: '/api/v1' }],
  },
  apis: ['./routes/*.js'],
};

const specs = swaggerJsdoc(options);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs));
```

```python
# FastAPI (auto-generated)
from fastapi import FastAPI

app = FastAPI(
    title="API Documentation",
    version="1.0.0",
    openapi_url="/api/v1/openapi.json",
    docs_url="/api-docs"
)

# Swagger UI auto-generated at /api-docs
```

### Error Handling
```javascript
// RFC 7807 Problem Details implementation
class ApiError extends Error {
  constructor(status, title, detail) {
    super(detail);
    this.status = status;
    this.title = title;
  }
}

// Error handler middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    type: `https://api.example.com/errors/${err.status}`,
    title: err.title || 'Internal Server Error',
    status: err.status || 500,
    detail: err.message,
    instance: req.path
  });
});

// Usage example
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

logger.info('User created', { userId: 123, email: 'user@example.com' });
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
// Query count: 1 + N (101 queries for 100 users)

// Good: Eager Loading
async function getUsers() {
  return await User.findAll({
    include: [{
      model: Post,
      attributes: ['id', 'title', 'createdAt']
    }]
  });
}
// Query count: 1 (using JOIN)
// Result: 5s → 0.2s (25x faster)
```

### Case 2: Rate Limiting Implementation
```javascript
// Situation: API abuse causing overload

const rateLimit = require('express-rate-limit');

// IP-based rate limiting
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

#### Distributed Environment (Redis)
```javascript
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

const client = redis.createClient();

const limiter = rateLimit({
  store: new RedisStore({
    client: client,
    prefix: 'rl:'
  }),
  windowMs: 15 * 60 * 1000,
  max: 100
});
```

### Case 3: SQL Injection Prevention
```python
# Situation: User input used directly in SQL

# Bad: SQL injection vulnerability
def get_user(username):
    query = f"SELECT * FROM users WHERE username = '{username}'"
    return db.execute(query)
# Attack: username = "admin' OR '1'='1"
# Executed SQL: SELECT * FROM users WHERE username = 'admin' OR '1'='1'
# Result: All user data leaked

# Good: ORM usage
def get_user(username):
    return User.query.filter_by(username=username).first()

# Good: Parameterized query
def get_user(username):
    query = "SELECT * FROM users WHERE username = ?"
    return db.execute(query, (username,))
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
| Python | FastAPI | High performance, type-safe, auto API docs |
| Python | Django | Full-stack, ORM, admin UI |
| Go | Gin | High performance, simple |
| Go | Echo | Lightweight, rich middleware |
| Rust | Actix-web | Maximum performance |
| Rust | Rocket | Type-safe, user-friendly |
