# Frontend Web Development

## Quick Start

```bash
# Development
npm run dev              # Vite/Webpack dev server
npm run type-check       # TypeScript type check
npm run lint:fix         # ESLint auto-fix

# Quality
npm run test             # Run tests (Vitest/Jest)
npm run format           # Prettier formatting
npm run build            # Production build

# Analysis
npm run build -- --analyze  # Bundle size analysis
npm run lighthouse          # Core Web Vitals
npm run test:coverage       # Test coverage
```

## Framework Selection

**By project size**:
- **Vue**: Components < 50 (1-week learning curve)
- **React**: 50-200 components (rich ecosystem)
- **Angular**: 200+ components (type safety, DI, enterprise)

**By rendering strategy**:
- **Next.js / Nuxt**: SSR required (SEO optimization)
- **Astro**: Static site (zero JS by default)
- **Svelte**: Interactive docs (minimal bundle)

## Build Tools

### Package Managers (2024-2025)

- **pnpm**: Fast, efficient (Monorepo recommended)
- **Bun**: Fastest (New projects)
- **npm**: Standard (Legacy projects)
- **Yarn**: Legacy (Migration to pnpm)

## Quality Standards

### TypeScript
- **strict mode**: `"strict": true` in tsconfig.json
- **Zero type errors**: Validate with `npm run type-check`
- **Type inference**: Minimize `any` usage

### ESLint
- **Zero errors required**: Framework-specific rules
  - React: `eslint-plugin-react`, `eslint-plugin-react-hooks`
  - Vue: `eslint-plugin-vue`
  - Angular: `@angular-eslint`
- **Auto-fix first**: Use `npm run lint:fix`

### Prettier
- **Unified format**: Consistent code style
- **Auto-format**: On save or pre-commit

### Bundler Selection (2024-2025)

- **Vite**: Fastest DX (New projects, recommended)
- **Turbopack**: 700x Webpack (Next.js App Router)
- **Rspack**: 10x Webpack (Webpack migration)
- **esbuild**: Ultra-fast (Simple projects)
- **Webpack**: Customizable (Legacy large-scale only)

## Security

### Authentication & Authorization

**JWT Security**:
- **Storage**: httpOnly cookie (NOT localStorage)
  ```tsx
  // Bad: Vulnerable to XSS
  localStorage.setItem('token', jwt);

  // Good: Secure
  // Set via Set-Cookie header from backend
  Set-Cookie: token=xxx; HttpOnly; Secure; SameSite=Strict
  ```
- **Refresh token**: Separate, short-lived access token (15min), long-lived refresh token (7d)
- **Algorithm**: RS256 or ES256 (NOT HS256 with shared secret in frontend)

**Session Management**:
- **CSRF protection**: Required for cookie-based auth (CSRF token, SameSite=Strict)
- **Logout**: Proper token invalidation on server side (blacklist or short expiry)

**Role-Based Access Control (RBAC)**:
- **Frontend**: UI hiding only (NOT security boundary)
  ```tsx
  // Hide UI, but validate on backend
  {user.role === 'admin' && <AdminPanel />}
  ```
- **Backend**: API-level authorization required (verify role on every request)

### XSS Prevention
- **React auto-escape**: Default escaping with `{variable}`
- **DOMPurify**: Required for raw HTML
  ```tsx
  import DOMPurify from 'dompurify';
  const clean = DOMPurify.sanitize(dirtyHTML);
  ```
- **dangerouslySetInnerHTML**: Forbidden except with DOMPurify

### Sensitive Data Protection

**NEVER store in frontend**:
- **API keys, secrets, credentials**: Backend only
- **Personal Identifiable Information (PII)**: Minimize client-side storage
- **Payment information**: Use tokenization (Stripe, PayPal)

**localStorage/sessionStorage**:
- NEVER store: **Auth tokens** (use httpOnly cookie)
- NEVER store: **API keys** (backend only)
- NEVER store: **Credit card numbers, SSN, passwords**
- OK to store: **User preferences, UI state, non-sensitive data**

**Environment variables**:
```bash
# DANGER: Exposed to client (bundle contains these)
VITE_API_URL=https://api.example.com  # OK - public URL
VITE_SECRET_KEY=abc123                # NEVER - leaked in bundle

# Good: Backend-only (NOT in frontend bundle)
DATABASE_URL=postgresql://...
SECRET_KEY=abc123
```

**Detection**:
- Search codebase: `rg -i "api_key|secret|password|ssn|credit" --type typescript`
- Bundle analysis: Check if sensitive strings appear in `dist/` output

### CSP (Content Security Policy)

**HTTP Header preferred** (meta tag can be removed by XSS):
```http
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-abc123'; object-src 'none'; base-uri 'self'
```

**Nonce generation** (Server-side required):
```tsx
// Next.js middleware example
import { NextResponse } from 'next/server';
import crypto from 'crypto';

export function middleware(request) {
  const nonce = crypto.randomBytes(16).toString('base64');
  const response = NextResponse.next();

  response.headers.set('Content-Security-Policy',
    `script-src 'self' 'nonce-${nonce}'; object-src 'none'`);

  // Pass nonce to page
  response.headers.set('X-Nonce', nonce);
  return response;
}
```

**Forbidden directives** (common security mistakes):
- NEVER use `'unsafe-inline'` - Allows inline scripts (enables XSS)
- NEVER use `'unsafe-eval'` - Allows eval() (enables code injection)
- NEVER use `*` - Allows any source (defeats purpose of CSP)

### HTTPS
- **All traffic encrypted**: HTTPS in dev environment recommended
- **Mixed content**: Avoid HTTP/HTTPS mix

### Dependencies
- **Zero vulnerabilities**: `npm audit` must pass
- **Regular updates**: Dependabot, Renovate
- **CI/CD scanning**: Snyk integration

### Subresource Integrity (SRI)

**CDN scripts**: Integrity hash required to prevent CDN tampering
```html
<script src="https://cdn.example.com/lib@1.0.0.js"
        integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxYA=="
        crossorigin="anonymous"></script>

<link rel="stylesheet" href="https://cdn.example.com/style.css"
      integrity="sha384-rbsA2VBKQhggwzxH7pPCaAqO46MgnOM80zW1RWuH61DG"
      crossorigin="anonymous">
```

**Generate hash**:
```bash
# For local files
cat library.js | openssl dgst -sha384 -binary | openssl base64 -A

# Online tool (for CDN resources)
# https://www.srihash.org/
```

## Performance

### Core Web Vitals (Targets)
- **LCP (Largest Contentful Paint)**: < 2.5s (Good)
- **INP (Interaction to Next Paint)**: < 200ms (Good)
- **CLS (Cumulative Layout Shift)**: < 0.1 (Good)

Note: INP replaced FID in March 2024

### Bundle Size Standards (2024-2025)

**Targets**:
- **Critical JS**: < 100KB (Brotli), < 130KB (gzip), < 400KB (uncompressed)
- **Critical CSS**: < 20KB (Brotli), < 25KB (gzip), < 80KB (uncompressed)
- **Total initial**: < 170KB (Brotli), < 200KB (gzip), < 600KB (uncompressed)

**Network timing** (3G Fast - 1.6 Mbps):
- Critical JS (100KB Brotli): ~500ms download
- Total initial (170KB): ~850ms download
- **Target**: < 1s for initial bundle download

**Compression preference**:
1. **Brotli** (level 4-5): 10-20% better than gzip
2. **gzip** (fallback): Wider support (legacy browsers)

**Bundle monitoring**:
```bash
# CI/CD check (fail if > 10% increase)
npm run build
npm run bundlesize  # Uses bundlesize.config.json

# Manual analysis
npx vite-bundle-visualizer  # or webpack-bundle-analyzer
```

### Critical Rendering Path

**Priority order** (optimize for first paint):
1. **Critical CSS**: Inline in `<head>` (< 14KB for first packet)
2. **Preload critical resources**: `<link rel="preload">`
3. **Defer non-critical JS**: `<script defer>` or `<script type="module">`
4. **Preconnect to origins**: `<link rel="preconnect">`

**Example**:
```html
<head>
  <!-- 1. Inline critical CSS (above-the-fold styles) -->
  <style>
    /* Critical CSS < 14KB */
    .header { /* ... */ }
    .hero { /* ... */ }
  </style>

  <!-- 2. Preconnect to external origins -->
  <link rel="preconnect" href="https://api.example.com">
  <link rel="dns-prefetch" href="https://cdn.example.com">

  <!-- 3. Preload critical resources -->
  <link rel="preload" href="/app.js" as="script">
  <link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>

  <!-- 4. Defer non-critical CSS -->
  <link rel="stylesheet" href="/non-critical.css" media="print"
        onload="this.media='all'">
</head>
<body>
  <!-- 5. Defer JavaScript -->
  <script src="/app.js" defer></script>
</body>
```

**Metrics impact**:
- Optimized Critical Path → FCP < 1.0s, LCP < 2.0s
- Poor Critical Path → FCP > 2.0s, LCP > 4.0s

### Memory Management
- **Prevent leaks**: useEffect cleanup required
  ```tsx
  useEffect(() => {
    const sub = subscribe();
    return () => sub.unsubscribe();
  }, []);
  ```
- **Memoization**: useMemo, useCallback, React.memo

### Image Optimization

**Modern formats**:
- **WebP**: 25-35% smaller than JPEG/PNG (98% browser support)
- **AVIF**: 50% smaller than JPEG (limited support: 90% desktop, 85% mobile)
- **Fallback**: Use `<picture>` element for progressive enhancement

```html
<picture>
  <source type="image/avif" srcset="hero.avif">
  <source type="image/webp" srcset="hero.webp">
  <img src="hero.jpg" alt="Hero" loading="lazy"
       width="800" height="600">
</picture>
```

**Responsive images**:
```html
<img
  src="small.jpg"
  srcset="small.jpg 400w, medium.jpg 800w, large.jpg 1200w"
  sizes="(max-width: 600px) 400px, (max-width: 1000px) 800px, 1200px"
  alt="Responsive image"
  loading="lazy"
  width="1200" height="800">
```

**Lazy loading**:
- **Above the fold**: `loading="eager"` or no attribute (default)
- **Below the fold**: `loading="lazy"` (native browser support)

**CDN optimization** (automatic format/size conversion):
- **Imgix**: `?auto=format,compress&w=800`
- **Cloudinary**: `f_auto,q_auto,w_800`
- **Next.js Image**: `<Image src="/pic.jpg" width={800} height={600} />`

### Font Loading Optimization

**Preload critical fonts**:
```html
<head>
  <link rel="preload" href="/fonts/inter-var.woff2" as="font"
        type="font/woff2" crossorigin>
</head>
```

**font-display strategy**:
```css
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter-var.woff2') format('woff2');
  font-display: swap; /* Show fallback immediately, swap when loaded */
  font-weight: 100 900; /* Variable font range */
}
```

**font-display options**:
- `swap`: Show fallback immediately (prevents invisible text, may cause layout shift)
- `optional`: Use font if cached, otherwise use fallback (best for performance)
- `fallback`: Brief block period, then fallback if not loaded

**Variable fonts** (single file for multiple weights/styles):
- **Example**: Inter Variable (1 file) vs Inter (9 files for different weights)
- **Size reduction**: 70-80% compared to multiple static fonts
- **Popular**: Inter Variable, Roboto Flex, Source Sans Variable

**WOFF2 format** (best compression):
- 30% smaller than WOFF
- 98% browser support (all modern browsers)

## State Management

### Client State

- **Zustand** (1KB): Small-medium projects
- **Redux Toolkit** (12KB): Large-scale, TypeScript
- **Jotai** (3KB): Atomic state, fine-grained reactivity
- **Nanostores** (300B): Ultra-lightweight, framework-agnostic

### Server State (Required for API)

- **TanStack Query**: Cache, refetch, optimistic updates (Complex data fetching)
- **SWR**: Simple, Next.js friendly (Basic data fetching)

**Rule**: Never use useState for server data. Always use TanStack Query or SWR.

## Styling

### CSS Frameworks

- **Tailwind CSS**: Utility-first, fast (Modern projects, recommended)
- **CSS Modules**: Lightweight, scoped (Simple projects)
- **Panda CSS**: Type-safe, zero-runtime (TypeScript-heavy)
- **StyleX**: Meta's solution, atomic (Large-scale)
- **Styled-components**: Legacy CSS-in-JS (Existing projects only)

### CSS Coding Standards

**包括的なCSS規約**: [CSS Coding Standards](./css-coding-standards.md)

**主要ルール**:
- `:hover` は `@media (any-hover: hover)` で囲む（タッチデバイス対応）
- `:focus-visible` 必須（アクセシビリティ）
- `prefers-reduced-motion` 尊重（前庭障害・てんかん対応）
- CSS変数必須（デザイントークン）、フォールバック値付き
- `rem` 単位推奨（ユーザー設定尊重）
- `transition: all` 禁止（個別プロパティ指定）
- `outline: none` 絶対禁止（アクセシビリティ違反）

**命名規則**:
- 状態: `is-active`, `is-disabled`（is- Prefix）
- 条件: `has-icon`, `has-image`（has- Prefix）
- ユーティリティ: `u-pc-only`, `u-sp-only`（u- Prefix）
- Vueコンポーネント: `ProductCard`（PascalCase）
- BEM Modifier（`--`）: 禁止（is-/has- Prefixに移行）

**詳細**: [~/.claude/stacks/css-coding-standards.md](./css-coding-standards.md)

## Testing

### Test Pyramid

```
       /\
      /E2E\     10%  - Playwright, Cypress
     /------\
    /Integration\ 30% - Testing Library
   /------------\
  /  Unit Tests  \ 60% - Vitest, Jest
 /----------------\
```

### Unit & Integration
- **Framework**: Vitest (Vite) or Jest (Webpack)
- **Library**: Testing Library (React/Vue/Angular)
- **Coverage**: 80%+ for critical paths

### E2E Testing
- **Tool**: Playwright (recommended) or Cypress
- **Scope**: Critical user flows only
- **CI**: Run on PR, not on every commit

### Visual Regression
- **Tool**: Chromatic or Percy
- **Use**: Design system components
- **Frequency**: Per PR for UI changes

## Accessibility

### WCAG 2.2 Compliance

**Required checks**:
- **Keyboard navigation**: All interactive elements accessible
- **ARIA labels**: Proper semantic HTML + ARIA when needed
- **Color contrast**: 4.5:1 for text, 3:1 for large text
- **Screen reader**: Test with NVDA (Windows) or VoiceOver (Mac)

**Tools**:
- `eslint-plugin-jsx-a11y` (React)
- `axe-core` (runtime testing)
- Lighthouse accessibility audit

## Error Handling & Monitoring

### Error Boundaries (React)

**Purpose**: Catch rendering errors and prevent whole app crash

```tsx
import { Component, ReactNode } from 'react';

class ErrorBoundary extends Component<
  { children: ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Report to monitoring service
    console.error('Error caught:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return <h1>Something went wrong.</h1>;
    }
    return this.props.children;
  }
}
```

### Error Tracking Services

- **Sentry**: Error tracking, performance monitoring (Production recommended)
- **LogRocket**: Session replay, error tracking (Debugging user issues)
- **Datadog RUM**: Full-stack monitoring (Enterprise)

**Integration**:
```tsx
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: 'YOUR_DSN',
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1, // 10% performance monitoring
});
```

### Frontend Logging

**Console levels** (development):
- `console.error`: Critical errors
- `console.warn`: Warnings
- `console.info`: Informational
- `console.debug`: Debug only

**Production**:
- Disable `console.log` via bundler (strip in production)
- Enable error tracking only
- Include user context: user ID, timestamp, page URL

## Forms & Validation

### Form Libraries

- **React Hook Form** (9KB): Performance-focused, minimal re-renders (recommended)
- **Formik** (13KB): Feature-rich, mature
- **TanStack Form** (13KB): Framework-agnostic

### Validation Libraries

- **Zod** (TypeScript-first): Type inference, schema-based (recommended)
- **Yup**: Mature, widely adopted (Legacy projects)
- **Valibot** (1KB): Modular, bundle size-sensitive

**Best practice**: Schema-based validation (Zod + React Hook Form)

```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

function LoginForm() {
  const { register, handleSubmit, formState: { errors } } = useForm({
    resolver: zodResolver(schema),
  });

  return (
    <form onSubmit={handleSubmit((data) => console.log(data))}>
      <input {...register('email')} />
      {errors.email && <span>{errors.email.message}</span>}

      <input {...register('password')} type="password" />
      {errors.password && <span>{errors.password.message}</span>}

      <button type="submit">Submit</button>
    </form>
  );
}
```

## Internationalization (i18n)

### i18n Libraries

**By framework**:
- **React**: react-i18next (Most popular, ICU MessageFormat)
- **Vue**: vue-i18n (Official Vue integration)
- **Next.js**: next-intl (App Router support, RSC compatible)

**Setup example** (react-i18next):
```tsx
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

i18n.use(initReactI18next).init({
  resources: {
    en: { translation: { welcome: 'Welcome' } },
    ja: { translation: { welcome: 'ようこそ' } },
  },
  lng: 'en',
  fallbackLng: 'en',
});
```

### Key Considerations

- **Locale detection**: Browser language, URL parameter, cookie
- **Date/time/number formatting**: Use Intl API (`Intl.DateTimeFormat`, `Intl.NumberFormat`)
- **Pluralization**: ICU MessageFormat (`{count, plural, one {# item} other {# items}}`)
- **RTL support**: Arabic, Hebrew (CSS `dir="rtl"`)

## Deployment & Hosting

### Hosting Platforms

- **Vercel**: Next.js best support, Edge functions, Preview deploys
- **Netlify**: All frameworks, Form handling, Serverless functions
- **Cloudflare Pages**: Global edge network, Fastest performance
- **AWS Amplify**: AWS integration, Full-stack deployment

**Environment variables**: See [Security > Sensitive Data Protection](#security)

**Deployment checklist**:
- Build optimization: `npm run build`
- Environment variables: Set in platform dashboard
- Custom domain: Configure DNS
- HTTPS: Automatic (all platforms)
- Preview deployments: Per PR/branch

## Optimization Examples

### Bundle Size Reduction

```tsx
// Before: 800KB bundle (lodash 500KB)
import _ from 'lodash';
_.debounce(fn, 100);

// After: 200KB bundle (-75%)
import debounce from 'lodash-es/debounce';
debounce(fn, 100);

// Code Splitting
const Heavy = React.lazy(() => import('./Heavy'));
<Suspense fallback={<Loading />}>
  <Heavy />
</Suspense>
```

### Core Web Vitals Improvement

**Problem**: LCP 4.5s, INP 150ms

**Solution**:
- WebP images + lazy loading
- Critical CSS inline
- React.lazy for non-critical components

**Result**: LCP 1.1s, INP 45ms, Lighthouse 95/100

### XSS Prevention

```tsx
// Dangerous
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// Safe (React auto-escape)
<div>{userInput}</div>

// Safe (Markdown with DOMPurify)
import DOMPurify from 'dompurify';
import marked from 'marked';

const html = marked(markdown);
const clean = DOMPurify.sanitize(html);
<div dangerouslySetInnerHTML={{ __html: clean }} />
```

## Performance Optimization Patterns

### React Runtime Performance

**Memoization strategies**:

```typescript
// 1. React.memo for component-level memoization
const TaskCard = memo<TaskCardProps>(({ task, onUpdate }) => {
  return <Card>{task.title}</Card>
});

// 2. useMemo for expensive calculations
const memoizedValue = useMemo(() => {
  return expensiveCalculation(data);
}, [data]);

// 3. useCallback for stable function references
const memoizedCallback = useCallback(() => {
  handleClick(id);
}, [id]);

// 4. State optimization with useReducer
const [state, dispatch] = useReducer(reducer, initialState);
// Better than multiple useState for complex state
```

**Virtualization for large lists**:

```tsx
import { FixedSizeList } from 'react-window';

// Render only visible items (10,000 items → 10 rendered)
<FixedSizeList
  height={600}
  itemCount={10000}
  itemSize={50}
  width="100%">
  {({ index, style }) => (
    <div style={style}>Item {index}</div>
  )}
</FixedSizeList>
```

**Code splitting strategies**:

```tsx
// Route-based splitting
const Dashboard = lazy(() => import('./Dashboard'));
const Settings = lazy(() => import('./Settings'));

// Component-based splitting (heavy components)
const Chart = lazy(() => import('./Chart'));

// Vendor bundle separation (webpack/vite config)
// splitChunks: { chunks: 'all', cacheGroups: { vendor: ... } }
```

### Bundle Optimization Strategies

**Tree shaking enablement**:

```typescript
// Bad: Wildcard imports prevent tree shaking
import * as utils from './utils';

// Good: Named imports enable tree shaking
import { formatDate, parseDate } from './utils';

// Mark packages as side-effect free (package.json)
{
  "sideEffects": false,
  // or specify files with side effects
  "sideEffects": ["*.css", "*.scss"]
}
```

**Dynamic imports for code splitting**:

```tsx
// Route-based
const routes = [
  { path: '/', component: lazy(() => import('./Home')) },
  { path: '/about', component: lazy(() => import('./About')) },
];

// Feature-based
if (user.isPremium) {
  const PremiumFeature = await import('./PremiumFeature');
  render(<PremiumFeature.default />);
}
```

**Asset optimization**:

```javascript
// Image compression (vite.config.ts / webpack.config.js)
import imagemin from 'vite-plugin-imagemin';

export default {
  plugins: [
    imagemin({
      gifsicle: { optimizationLevel: 3 },
      mozjpeg: { quality: 80 },
      pngquant: { quality: [0.65, 0.8] },
      svgo: { plugins: [{ removeViewBox: false }] },
    }),
  ],
};

// Font subsetting (only include used characters)
pyftsubset font.ttf \
  --output-file=font-subset.woff2 \
  --flavor=woff2 \
  --unicodes=U+0020-007E  # Basic Latin

// CSS purging (remove unused styles)
// Tailwind CSS: automatic in production build
// PurgeCSS: configure in postcss.config.js
```

### Memory Optimization

**Prevent memory leaks**:

```tsx
useEffect(() => {
  // Event listeners: always cleanup
  const handler = () => console.log('resize');
  window.addEventListener('resize', handler);
  return () => window.removeEventListener('resize', handler);
}, []);

useEffect(() => {
  // Subscriptions: cleanup required
  const subscription = observable.subscribe();
  return () => subscription.unsubscribe();
}, []);

useEffect(() => {
  // Timers: clear on unmount
  const timer = setInterval(() => {}, 1000);
  return () => clearInterval(timer);
}, []);

useEffect(() => {
  // Async operations: cancel if component unmounts
  let cancelled = false;

  fetchData().then(data => {
    if (!cancelled) setState(data);
  });

  return () => { cancelled = true; };
}, []);
```

**Efficient data structures**:

```typescript
// WeakMap for objects (automatic garbage collection)
const cache = new WeakMap<object, CachedData>();
cache.set(obj, data);  // obj GC → data also GC

// WeakSet for object presence checking
const visited = new WeakSet<Node>();
visited.add(node);

// Object pooling for frequent allocations
class ObjectPool<T> {
  private pool: T[] = [];

  acquire(factory: () => T): T {
    return this.pool.pop() || factory();
  }

  release(obj: T): void {
    this.pool.push(obj);
  }
}
```

### Network Optimization

**Request deduplication and caching**:

```tsx
// TanStack Query: automatic deduplication
import { useQuery } from '@tanstack/react-query';

const { data } = useQuery({
  queryKey: ['user', id],
  queryFn: () => fetchUser(id),
  staleTime: 5 * 60 * 1000,  // 5 minutes
  cacheTime: 10 * 60 * 1000, // 10 minutes
});

// SWR: similar deduplication
import useSWR from 'swr';
const { data } = useSWR(`/api/user/${id}`, fetcher);
```

**Lazy loading and progressive loading**:

```tsx
// Image lazy loading (native)
<img src="image.jpg" loading="lazy" />

// Component lazy loading
const HeavyComponent = lazy(() => import('./Heavy'));

// Progressive image loading (LQIP - Low Quality Image Placeholder)
<Image
  src="high-res.jpg"
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>
```

**API call batching**:

```typescript
// GraphQL: batch multiple queries
const [user, posts] = await Promise.all([
  client.query({ query: GET_USER }),
  client.query({ query: GET_POSTS }),
]);

// REST: implement batching endpoint
const ids = [1, 2, 3, 4, 5];
const users = await fetch(`/api/users?ids=${ids.join(',')}`);
```

### Performance Testing and Monitoring

**Measurement tools**:

```bash
# Build analysis
npm run build
npx vite-bundle-visualizer  # or webpack-bundle-analyzer

# Lighthouse CI (performance regression detection)
npm install -g @lhci/cli
lhci autorun --config=lighthouserc.json

# Core Web Vitals (production)
# web-vitals library
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

getCLS(console.log);
getLCP(console.log);
// Send to analytics endpoint
```

**Performance budgets**:

```json
// budgets.json (Lighthouse CI)
[
  {
    "path": "/*",
    "resourceSizes": [
      { "resourceType": "script", "budget": 250 },
      { "resourceType": "stylesheet", "budget": 50 },
      { "resourceType": "total", "budget": 400 }
    ],
    "timings": [
      { "metric": "first-contentful-paint", "budget": 1500 },
      { "metric": "largest-contentful-paint", "budget": 2500 },
      { "metric": "interactive", "budget": 3500 }
    ]
  }
]
```
