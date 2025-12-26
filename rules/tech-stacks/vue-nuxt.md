# Vue 3 / Nuxt 3 & 4 開発ルール

> **継承**: `frontend-web.md` の汎用ルール + Vue/Nuxt特化ルール
>
> **対応バージョン**: Nuxt 3.x / Nuxt 4.x 両対応（バージョン差異がある箇所は明記）

## 技術スタック

- **フレームワーク**: Vue 3 (Composition API) + Nuxt 3/4
- **言語**: TypeScript strict mode必須
- **状態管理**: Nuxt `useState` (SSR対応)
- **ルーティング**: File-based routing
- **テスト**: Vitest + @vue/test-utils

## Nuxt 4の主な変更点（2025年7月RC、正式版まもなく）

- **新ディレクトリ構造**: `app/` ディレクトリ導入（後方互換性あり）
- **データフェッチング改善**: `useAsyncData`, `useFetch` のキャッシング・クリーンアップ強化
- **TypeScript強化**: プロジェクトコンテキスト分離（app/server/shared/config）
- **移行**: Nuxt 2→3より容易（Vue 3のまま、自動マイグレーションツールあり）

---

## 1. コンポーネント設計

### 1.1 基本構造

**必須形式**（Vue公式推奨順序）:
```vue
<template>
  <!-- テンプレート -->
</template>

<script setup lang="ts">
// ❌ Options API禁止
// ✅ <script setup> 必須
</script>

<style scoped>
/* コンポーネント固有スタイル（CSS Layersと併用） */
</style>
```

**ブロック順序**: `<template>` → `<script setup>` → `<style>` （Vue公式・Vite推奨）

### 1.2 Props定義ルール

**判断基準**（既存プロジェクト実態に基づく）:

| 条件 | 推奨方法 | 理由 |
|-----|---------|------|
| Props 4つ以上 | ✅ Interface定義 | 可読性・保守性 |
| 複雑な型（オブジェクト、ユニオン、配列） | ✅ Interface定義 | 型の再利用・JSDoc活用 |
| `withDefaults` 使用 | ✅ Interface定義 | 型推論の正確性 |
| Props 1-2個 かつ シンプル型 | ⚠️ 直接型定義OK | 簡潔性優先 |

**✅ 推奨パターン（Interface定義）**:
```typescript
/**
 * イベントカードコンポーネントのProps
 */
interface Props {
  /** イベントID */
  eventId: string
  /** 表示モード */
  displayMode?: 'compact' | 'detailed'
  /** クリックハンドラ */
  onClick?: (id: string) => void
}

const props = withDefaults(defineProps<Props>(), {
  displayMode: 'compact',
  onClick: undefined,
})
```

**⚠️ 許容パターン（直接型定義、シンプルなケース）**:
```typescript
// 1-2個のシンプルなpropsのみ
const props = defineProps<{
  text: string
  isVisible?: boolean
}>()
```

**JSDocコメント必須**:
- 型の意図・制約を明示
- 複雑な型（ユニオン、配列）は使用例も記載

### 1.3 Emits定義ルール

**基本パターン**:
```typescript
// ✅ Interface定義（複数イベント、型安全性重視）
interface Emits {
  /** ページ変更イベント */
  (e: 'page-change', page: number): void
  /** 閉じるイベント */
  (e: 'close'): void
}
const emit = defineEmits<Emits>()

// ⚠️ 直接型定義（1-2個のシンプルなイベント）
const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
}>()
```

**命名規則**:
- kebab-case（`page-change`, `update:model-value`）
- v-modelバインディング: `update:modelValue` 形式

**型構文の注意点**:
- ✅ 関数シグネチャ形式: `(e: 'event-name', payload: Type): void`
- ❌ タプル形式は使用不可: `'event-name': [payload: Type]`

### 1.4 リアクティブ変数

**Nuxt auto-imports活用**:
```typescript
// ✅ import不要（Nuxt auto-imports）
const count = ref(0)
const doubled = computed(() => count.value * 2)

// ❌ 明示的importは不要
// import { ref, computed } from 'vue'
```

**型推論活用**:
```typescript
// ✅ 型推論で十分な場合はジェネリック省略
const message = ref('Hello') // string型に推論

// ✅ 複雑な型は明示
const user = ref<User | null>(null)
const items = ref<EventSourceType[]>([])
```

---

## 2. Composables設計

### 2.1 命名・構造

**命名規則**:
- ファイル名: `composables/useXxx.ts`
- 関数名: `export const useXxx = () => { ... }`
- camelCase必須

**戻り値パターン**（オブジェクト形式、分割代入可能）:
```typescript
export const useEventFilters = () => {
  const searchQuery = ref('')
  const selectedCategories = ref<SearchTag[]>([])

  const handleCategorySelect = (categories: SearchTag[]) => {
    selectedCategories.value = categories
  }

  // ✅ オブジェクト形式で返す
  return {
    // リアクティブ変数
    searchQuery,
    selectedCategories,
    // メソッド
    handleCategorySelect,
  }
}

// 使用側：分割代入で必要なものだけ取得
const { searchQuery, handleCategorySelect } = useEventFilters()
```

### 2.2 SSR対応（Nuxt特有）

**useState使用**（サーバー・クライアント間で状態共有）:
```typescript
import { useState } from 'nuxt/app'

export const useAuth = () => {
  // ✅ useState（SSR対応）
  const firebaseUser = useState<FirebaseUser | undefined>(
    'firebaseUser', // ユニークキー（状態識別子）
    () => undefined // 初期値ファクトリー
  )

  // ❌ 通常のref（SSR非対応、クライアントのみ）
  // const firebaseUser = ref<FirebaseUser | undefined>(undefined)

  return { firebaseUser }
}
```

**使い分け**:
- `useState`: サーバー・クライアント間で共有する状態（認証、ユーザー情報等）
- `ref`: クライアントのみの状態（UI状態、フォーム入力等）

### 2.3 非同期処理パターン

**推奨パターン（async/await）**:
```typescript
export const useAuth = () => {
  const signIn = async (email: string): Promise<void> => {
    try {
      const auth = getAuth()
      const userCredential = await signInWithEmailLink(auth, email)
      // 成功処理
      const idToken = await userCredential.user.getIdToken()
      firebaseUser.value = { id: userCredential.user.uid, token: idToken }
    } catch (error) {
      // エラーハンドリング（Sentry連携等）
      throw error
    }
  }

  return { signIn }
}
```

**エラーハンドリング必須**:
- try-catch使用（async/await）または .catch()（Promise）
- エラー監視サービス連携（Sentry等）推奨
- ユーザーフレンドリーなエラーメッセージ
- ❌ `async` + `new Promise` の混在は冗長（どちらか一方を使用）

### 2.4 単一責任原則

**良い例**（責務が明確）:
- `useAuth`: 認証関連のみ
- `useEventFilters`: フィルター状態管理のみ
- `useEventPagination`: ページネーション制御のみ

**悪い例**（責務が混在）:
- ❌ `useEventPage`: フィルター + ページネーション + ソート（分離すべき）

---

## 3. Nuxt 3特有機能

### 3.1 File-based Routing

**ディレクトリ構造（Nuxt 3/4両対応）**:
- **Nuxt 3**: `pages/`, `components/` 直下配置
- **Nuxt 4**: `app/pages/`, `app/components/` 配置（後方互換性あり）
- **移行**: `nuxt.config.ts` で `compatibilityVersion: 4` 設定後、段階的移行可能

**ルーティング例**:
```
pages/index.vue              → /
pages/events.vue             → /events
pages/event/[id]/index.vue   → /event/:id

（Nuxt 4は app/pages/ 配置）
```

**動的ルート**:
```vue
<!-- app/pages/event/[id]/index.vue または pages/event/[id]/index.vue -->
<script setup lang="ts">
const route = useRoute() // Nuxt auto-imports
const eventId = route.params.id as string
</script>
```

### 3.2 Server API Endpoints

**ファイル配置**:
```
server/
  api/
    webhooks/
      stripe.post.ts  → POST /api/webhooks/stripe
    events/
      [id].get.ts     → GET /api/events/:id
```

**型安全なAPI定義**:
```typescript
// server/api/events/[id].get.ts
export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')

  // バリデーション・認証チェック必須
  if (!id) {
    throw createError({
      statusCode: 400,
      message: 'Invalid event ID',
    })
  }

  // ビジネスロジック
  const eventData = await fetchEventById(id)
  return eventData
})
```

### 3.3 Auto-imports活用

**利用可能な関数（import不要）**:
- Vue: `ref`, `computed`, `watch`, `onMounted`, etc.
- Nuxt: `useRoute`, `useRouter`, `useState`, `useFetch`, etc.
- Composables: `useAuth`, `useEventFilters`, etc.（自動検出）

**明示的importが必要なケース**:
- 外部ライブラリ（Firebase, Stripe等）
- 型定義（`import type { ... }`）

### 3.4 データフェッチング（Nuxt 4改善）

**基本パターン（Nuxt 3/4共通）**:
```typescript
// useFetch（推奨）
const { data, pending, error, refresh } = await useFetch('/api/events')

// useAsyncData（カスタムロジック用）
const { data, pending, error } = await useAsyncData('events', () => {
  return $fetch('/api/events')
})
```

**Nuxt 4の改善点**:
- **自動キャッシング強化**: 同一キーのデータは自動でキャッシュ、再フェッチ不要
- **クリーンアップ改善**: コンポーネントアンマウント時のメモリリーク対策
- **型推論強化**: APIレスポンスの型が自動推論されやすくなった

**ベストプラクティス**:
```typescript
// ✅ キーを明示的に指定（Nuxt 4でキャッシング最適化）
const { data } = await useAsyncData(`event-${id}`, () => $fetch(`/api/events/${id}`))

// ✅ 型安全
interface Event {
  id: string
  title: string
}
const { data } = await useFetch<Event>('/api/events/1')

// ❌ キー未指定（キャッシング効率低下）
const { data } = await useAsyncData(() => $fetch('/api/events'))
```

---

## 4. TypeScript strict mode対応

### 4.1 必須設定

**nuxt.config.ts（Nuxt 3/4共通）**:
```typescript
export default defineNuxtConfig({
  typescript: {
    strict: true, // ✅ 必須
    typeCheck: true, // ✅ ビルド時型チェック
  },
})
```

**Nuxt 4の TypeScript強化**:
- **プロジェクトコンテキスト分離**: app/server/shared/config 各コンテキストで型が独立
- **型推論改善**: Auto-imports の型が正確に推論されやすくなった
- **tsconfig.json自動生成**: `.nuxt/tsconfig.json` がコンテキストごとに最適化

**Nuxt 4でのコンテキスト別型管理**:
```
app/           # クライアント・サーバー共通コード
  types/
    event.ts   # アプリケーション型定義

server/        # サーバー専用コード
  types/
    api.ts     # サーバー専用型定義

shared/        # 完全に共有される型
  types/
    common.ts  # 共通型定義
```

### 4.2 型安全性ベストプラクティス

**any禁止**:
```typescript
// ❌ any使用禁止
const data: any = fetchData()

// ✅ 適切な型定義
interface EventData {
  id: string
  title: string
}
const data: EventData = fetchData()

// ✅ 型が不明な場合はunknown
const data: unknown = fetchData()
if (isEventData(data)) {
  // 型ガード後に使用
}
```

**strictNullChecks活用**:
```typescript
// ✅ null/undefinedを明示
const user = ref<User | null>(null)

if (user.value) {
  // null除外後に安全に使用
  console.log(user.value.name)
}
```

**型ガード使用**:
```typescript
function isEventData(data: unknown): data is EventData {
  return (
    typeof data === 'object' &&
    data !== null &&
    'id' in data &&
    'title' in data
  )
}
```

---

## 5. パフォーマンス最適化

### 5.1 コンポーネントLazy Loading

**Nuxt 3推奨方法（Lazyプレフィックス）**:
```vue
<template>
  <!-- ✅ Lazy プレフィックスで自動lazy loading（Nuxt 3特有） -->
  <LazyHeavyComponent v-if="showComponent" />
</template>

<script setup lang="ts">
// import不要、Nuxtが自動でLazy Loadingを適用
const showComponent = ref(false)
</script>
```

**Vue 3標準方法（defineAsyncComponent）**:
```vue
<script setup lang="ts">
// ✅ 動的インポート（初期バンドルサイズ削減）
const HeavyComponent = defineAsyncComponent(
  () => import('~/components/HeavyComponent.vue')
)
</script>

<template>
  <HeavyComponent v-if="showComponent" />
</template>
```

**使い分け**:
- Nuxt 3プロジェクト: `Lazy`プレフィックス推奨（シンプル、設定不要）
- Vue 3単体プロジェクト: `defineAsyncComponent`使用

### 5.2 SSR最適化

```vue
<template>
  <!-- ✅ クライアントのみで実行（Hydration mismatch回避） -->
  <ClientOnly>
    <VideoPlayer :src="videoUrl" />
  </ClientOnly>
</template>
```

### 5.3 画像最適化

```vue
<template>
  <!-- ✅ Nuxt Image（自動最適化・Lazy Loading） -->
  <NuxtImg
    src="/images/hero.jpg"
    alt="Hero image"
    loading="lazy"
    width="800"
    height="600"
  />
</template>
```

---

## 6. テスト戦略

### 6.1 Composablesテスト（Vitest）

```typescript
import { describe, it, expect } from 'vitest'
import { useEventFilters } from '~/composables/useEventFilters'

describe('useEventFilters', () => {
  it('キーワード追加が正しく動作する', () => {
    const { searchQuery, selectedKeywords, addKeyword } = useEventFilters()

    searchQuery.value = 'テスト'
    addKeyword()

    expect(selectedKeywords.value).toContain('テスト')
    expect(searchQuery.value).toBe('') // リセット確認
  })
})
```

### 6.2 コンポーネントテスト

```typescript
import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import Button from '~/components/buttons/Button.vue'

describe('Button', () => {
  it('クリックイベントが発火する', async () => {
    const wrapper = mount(Button, {
      props: { label: 'テスト' },
    })

    await wrapper.trigger('click')
    expect(wrapper.emitted('click')).toBeTruthy()
  })
})
```

---

## 7. セキュリティ

### 7.1 入力検証必須

```typescript
// ✅ バリデーション関数使用
import { validateEmail } from '~/utils/validator'

const email = ref('')
const isValid = computed(() => validateEmail(email.value))
```

### 7.2 出力エスケープ

```vue
<template>
  <!-- ✅ Vue自動エスケープ（XSS対策） -->
  <p>{{ userInput }}</p>

  <!-- ❌ v-html使用禁止（信頼できるコンテンツのみ） -->
  <div v-html="dangerousHtml"></div>
</template>
```

### 7.3 環境変数管理

```typescript
// ✅ Nuxt環境変数（自動型付け）
const config = useRuntimeConfig()
const apiKey = config.public.contentfulAccessToken

// ❌ .env直接読み取り禁止
// const apiKey = process.env.NUXT_PUBLIC_CONTENTFUL_ACCESS_TOKEN
```

---

## 8. コード品質チェックリスト

実装完了後、以下を確認：

- [ ] TypeScript型エラー0件（`npx nuxt typecheck`）
- [ ] ESLint・Prettier適用（`/validate --layers=syntax --auto-fix`）
- [ ] Props/Emits適切に型定義（Interface or 直接型定義）
- [ ] Composables単一責任・useState適切使用
- [ ] 入力検証・エラーハンドリング実装
- [ ] アクセシビリティ（ARIA、キーボード操作）
- [ ] レスポンシブ対応（モバイル・タブレット・PC）
- [ ] パフォーマンス（Lazy Loading、画像最適化）
- [ ] セキュリティレビュー（OWASP対策、個人情報保護）

---

## 9. 参照ドキュメント

- Vue 3: https://vuejs.org/
- Nuxt 3: https://nuxt.com/
- Nuxt 4 公式発表: https://nuxt.com/blog/v4
- Nuxt 4 移行ガイド: https://nuxt.com/docs/getting-started/upgrade
- TypeScript: https://www.typescriptlang.org/
- Vitest: https://vitest.dev/
- CSS規約: `~/.claude/stacks/css-coding-standards.md`
