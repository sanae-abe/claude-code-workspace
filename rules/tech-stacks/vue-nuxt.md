# Vue 3 / Nuxt 3 & 4 開発ルール

> **継承**: `frontend-web.md` の汎用ルール + Vue/Nuxt特化ルール
>
> **対応バージョン**: Nuxt 3.x / Nuxt 4.x 両対応（バージョン差異がある箇所は明記）
>
> **読み方**: `[CRITICAL]` の章はVue/Nuxtタスクで毎回適用する。`[REFERENCE]` の章はその領域に触れるときだけ参照する。

## 技術スタック

- **フレームワーク**: Vue 3 (Composition API) + Nuxt 3/4
- **言語**: TypeScript strict mode必須
- **状態管理**: `ref` / `useState` / Pinia を用途別に選択（選択基準は 2.2）
- **ルーティング**: File-based routing
- **テスト**: Vitest + `@nuxt/test-utils`（+ @vue/test-utils）

## Nuxt 4の主な変更点（2025年7月15日 正式リリース）

- **新ディレクトリ構造**: `app/` ディレクトリ導入（後方互換性あり）
- **データフェッチング変更**: 同一キーの ref 共有、アンマウント時のデータ破棄、`data` の `shallowRef` 化（3.4）
- **TypeScript強化**: プロジェクトコンテキスト分離（app/server/shared/config）
- **移行**: Nuxt 2→3より容易（Vue 3のまま、自動マイグレーションツールあり）

---

## [CRITICAL] 1. コンポーネント設計

### 1.1 基本構造

**必須形式**:
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

**ブロック順序**: `<template>` → `<script setup>` → `<style>`

Vue Style Guide が定めているのは「順序をプロジェクト内で一貫させる」「`<style>` を最後に置く」の2点のみで、`<template>` 先頭・`<script>` 先頭はどちらも許容される。本規約では `<template>` 先頭に統一し、ESLint で強制する:

```javascript
// eslint.config.js
// eslint-plugin-vue の vue/block-order 既定値は ["script", "template"] のため明示上書きが必須
'vue/block-order': ['error', { order: ['template', 'script', 'style'] }]
```

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
- 通常イベントは kebab-case（`page-change`, `item-select`）
- **例外**: v-model は `update:modelValue` 固定（camelCase）。`defineEmits` / `emit()` に渡す文字列はこの形式のみ有効で、`update:model-value` では発火しない
- テンプレート側の受け取りは `@update:model-value` / `@update:modelValue` のどちらでも可（Vueがテンプレート内で正規化する）

**型構文の注意点**:

2つの形式が使用可能（Vue 3.3+）:

```typescript
// 関数シグネチャ形式（Interface定義時に使用）
interface Emits {
  (e: 'page-change', page: number): void
}

// タプル形式（直接型定義時に使用、Vue 3.3+）
const emit = defineEmits<{
  'page-change': [page: number]
  'close': []
}>()
```

統一性のためプロジェクト内でどちらかに揃えること。

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

## [CRITICAL] 2. Composables設計

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
export const useAuth = () => {
  // ✅ useState は Nuxt auto-imports（3.3 参照）— import 不要
  const firebaseUser = useState<FirebaseUser | undefined>(
    'firebaseUser', // ユニークキー（状態識別子）
    () => undefined // 初期値ファクトリー
  )

  return { firebaseUser }
}
```

**`ref` ではなく `useState` を使う理由**（`ref` は「SSR非対応」ではない。以下2点が問題になる）:
1. サーバーで `ref` に入れた値はSSRペイロードに載らず、クライアント側の初期値に引き継がれない（hydration mismatch の原因）
2. モジュールスコープに置いた `ref` はサーバープロセス上で全リクエストに共有される（他ユーザーの状態が漏れる）

`useState` はキーごとにリクエストスコープで隔離され、値がペイロードで転送される。

**状態管理の選択基準**:

```python
IF サーバーAPIから取得したデータ:
    → useFetch / useAsyncData（3.4）
    # 独自ストアへ詰め替えない。キャッシュ・再検証はNuxt側に任せる

ELIF サーバー・クライアント間で引き継ぐ状態（認証、ユーザー情報、テーマ）:
    → useState（キー必須、SSRペイロードで転送される）

ELIF 複数コンポーネントで共有 AND 状態遷移が複雑:
    → Pinia（defineStore + @pinia/nuxt）
    # 判定目安: ストア相当の状態が5つ以上、または更新ロジックが3関数以上

ELSE:  # 単一コンポーネント内のUI状態、フォーム入力
    → ref / reactive
```

`useState` と Pinia の併用は可。ただし同一の状態を両方に持たせない（同期漏れの原因）。

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
      // ✅ catch は「記録」または「変換」の仕事をする
      captureException(error) // 監視サービスへ送出（Sentry等）
      throw createError({     // ユーザー向けメッセージへ変換
        statusCode: 401,
        message: 'サインインに失敗しました。メールリンクの有効期限を確認してください。',
      })
    }
  }

  return { signIn }
}
```

**エラーハンドリング必須**:
- try-catch使用（async/await）または .catch()（Promise）
- catch 節は必ず「記録（監視サービスへ送出）」か「変換（ユーザー向けエラーへ）」のいずれかを行う
- ❌ `catch (error) { throw error }` は no-op。記録も変換もしない catch は書かない（try-catch ごと削除して呼び出し元に委ねる）
- ❌ 例外の握り潰し（`catch { /* 何もしない */ }`）禁止
- ❌ `async` + `new Promise` の混在は冗長（どちらか一方を使用）

### 2.4 単一責任原則

**良い例**（責務が明確）:
- `useAuth`: 認証関連のみ
- `useEventFilters`: フィルター状態管理のみ
- `useEventPagination`: ページネーション制御のみ

**悪い例**（責務が混在）:
- ❌ `useEventPage`: フィルター + ページネーション + ソート（分離すべき）

---

## [REFERENCE] 3. Nuxt 固有機能（Nuxt 3 / 4 共通）

### 3.1 File-based Routing

**ディレクトリ構造（Nuxt 3/4両対応）**:
- **Nuxt 3**: `pages/`, `components/` 直下配置
- **Nuxt 4**: `app/pages/`, `app/components/` 配置（後方互換性あり）
- **移行**: Nuxt 3 側で `future.compatibilityVersion: 4` を設定し、段階的に移行

```typescript
// nuxt.config.ts（Nuxt 3 で Nuxt 4 の挙動を先行有効化）
export default defineNuxtConfig({
  future: {
    compatibilityVersion: 4, // ❌ トップレベルに書いても無効。future 配下が正しい
  },
})
```
（Nuxt 4 本体では既定の挙動のため、この設定は不要）

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
- Vue: `ref`, `computed`, `watch`, `watchEffect`, `onMounted`, `onUnmounted`, etc.
- Nuxt (app): `useRoute`, `useRouter`, `useState`, `useFetch`, `useAsyncData`, `useLazyFetch`
- Nuxt (navigation): `navigateTo()`, `useNuxtApp()`, `definePageMeta()`
- Nuxt (error): `showError()`, `clearError()`, `createError()`
- Nuxt (server): `useRequestEvent()`, `useRequestHeaders()`（server composables内）
- Composables: `useAuth`, `useEventFilters`, etc.（`composables/` ディレクトリを自動検出）

**明示的importが必要なケース**:
- 外部ライブラリ（Firebase, Stripe等）
- 型定義（`import type { ... }`）
- `server/` 内からVue/Nuxtの関数を呼ぶ場合（サーバーコンテキストは別）

### 3.4 データフェッチング

**基本パターン（Nuxt 3/4共通）**:
```typescript
// useFetch（推奨）
// ※ await はSSRで初期データ取得をブロックする（Promise返却ではなくサスペンド）
const { data, status, error, refresh } = await useFetch('/api/events')

// useAsyncData（カスタムロジック用）
const { data, status, error } = await useAsyncData('events', () => {
  return $fetch('/api/events')
})
```

**`pending` は使わない**: Nuxt 4 で非推奨。`status`（`'idle' | 'pending' | 'success' | 'error'`）を使う。

```vue
<template>
  <LoadingSpinner v-if="status === 'pending'" />
  <ErrorMessage v-else-if="status === 'error'" :error="error" />
  <EventList v-else :events="data" />
</template>
```

**Nuxt 4 の挙動変更（重要）**:
- **アンマウント時のデータ破棄**: そのキーを使う最後のコンポーネントが unmount された時点で `data` が破棄される（Nuxt 3 はペイロードを保持し続け、メモリ使用量が増え続けていた）。**画面遷移後も値が残っている前提のコードを書かないこと**
- **同一キーの ref 共有**: 同じキーの `useAsyncData` / `useFetch` は `data` / `error` / `status` の同一 ref を共有する（重複フェッチの防止であり、永続キャッシュではない）
- **`data` が `shallowRef` 化**: オブジェクト全体の差し替えは反応するが、**内部プロパティの直接書き換えは反応しない**。ネスト内を更新する場合は新しいオブジェクトを代入するか、`deep: true` を指定する

```typescript
const { data } = await useFetch<Event>('/api/events/1')

// ❌ shallowRef のため反応しない
data.value.title = '新しいタイトル'

// ✅ 全体を差し替える
data.value = { ...data.value, title: '新しいタイトル' }
```

- **型推論強化**: Auto-imports・APIレスポンスの型が正確に推論されやすくなった

**ベストプラクティス**:
```typescript
// ✅ キーを明示的に指定（他コンポーネントからの共有・refresh・clearNuxtData に必要）
const { data } = await useAsyncData(`event-${id}`, () => $fetch(`/api/events/${id}`))

// ✅ 型安全
interface Event {
  id: string
  title: string
}
const { data } = await useFetch<Event>('/api/events/1')

// ⚠️ キー未指定（ファイル位置から自動生成される。動作はするが、
//    他所からの共有・無効化ができず、リファクタで暗黙にキーが変わる）
const { data } = await useAsyncData(() => $fetch('/api/events'))
```

---

## [CRITICAL] 4. TypeScript strict mode対応

### 4.1 必須設定

**nuxt.config.ts（Nuxt 3/4共通）**:
```typescript
export default defineNuxtConfig({
  typescript: {
    strict: true,      // ✅ 必須
    typeCheck: true,   // ⚠️ ビルド速度が大幅に低下するためCIのみ推奨
    // 開発中はnpx nuxt typecheckを手動実行するか、IDE（Volar）に委ねる
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
interface EventData {
  id: string
  title: string
}

// ❌ any使用禁止（以降の型チェックが全て無効化される）
const a: any = await fetchData()

// ✅ 戻り値の型が保証されている場合はジェネリックで明示
const b = await fetchData<EventData>()

// ✅ 外部由来で型が保証されない場合は unknown + 型ガード
const c: unknown = await fetchData()
if (isEventData(c)) {
  console.log(c.title) // ここで初めて EventData として扱える
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

## [REFERENCE] 5. パフォーマンス最適化

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

## [REFERENCE] 6. テスト戦略

### 6.1 セットアップ（必須）

`useState` / `useFetch` / auto-imports / `~` エイリアスに依存するコードは、素の Vitest では解決できず `useState is not defined` や モジュール解決エラーになる。`@nuxt/test-utils` を導入する。

```bash
npm i -D @nuxt/test-utils vitest @vue/test-utils happy-dom
```

```typescript
// vitest.config.ts
import { defineVitestConfig } from '@nuxt/test-utils/config'

export default defineVitestConfig({
  test: {
    environment: 'nuxt', // Nuxtランタイム（auto-imports・エイリアス・useState）を有効化
  },
})
```

**環境の選択基準**:

```python
IF テスト対象が Nuxt composable / auto-imports / ~ エイリアス / SFC に依存:
    → environment: 'nuxt' + mountSuspended
ELSE:  # 純粋関数、ref のみの composable、utils
    → 素の Vitest（環境指定なし。起動が速い）
```

### 6.2 Composablesテスト

```typescript
import { describe, it, expect } from 'vitest'
import { useEventFilters } from '~/composables/useEventFilters'

// environment: 'nuxt' 配下なら useState を含む composable もそのまま呼べる
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

**注意**: `useState` はキー単位でグローバルに保持されるため、テスト間で状態が持ち越される。`beforeEach` で `clearNuxtState(key)` するか、composable にキーを注入できる設計にする。

### 6.3 コンポーネントテスト

```typescript
import { describe, it, expect } from 'vitest'
import { mountSuspended } from '@nuxt/test-utils/runtime'
import Button from '~/components/buttons/Button.vue'

describe('Button', () => {
  it('クリックイベントが発火する', async () => {
    // ❌ @vue/test-utils の mount は async setup / auto-imports を解決できない
    // ✅ mountSuspended は Nuxt コンテキスト込みでマウントし、setup の解決を待つ
    const wrapper = await mountSuspended(Button, {
      props: { label: 'テスト' },
    })

    await wrapper.trigger('click')
    expect(wrapper.emitted('click')).toBeTruthy()
  })
})
```

### 6.4 Server API のモック

`useFetch` / `$fetch` の呼び先を、実サーバーを起動せずに差し替える。

```typescript
import { registerEndpoint } from '@nuxt/test-utils/runtime'

registerEndpoint('/api/events', () => [{ id: '1', title: 'テストイベント' }])
```

### 6.5 E2E

```typescript
import { setup, $fetch } from '@nuxt/test-utils/e2e'

await setup({ browser: true }) // 実際に Nuxt サーバーを起動
```

E2E は主要導線のみ（`frontend-web.md` のテストピラミッド参照）。

---

## [CRITICAL] 7. セキュリティ

汎用のXSS対策・CSP・認証トークン取り扱いは `frontend-web.md` の Security セクションに従う。本節は Nuxt 固有の項目のみ扱う。

### 7.1 runtimeConfig の公開境界

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    // 🔒 サーバー専用（クライアントバンドルに含まれない）
    stripeSecretKey: '',     // 環境変数 NUXT_STRIPE_SECRET_KEY で上書き
    firebaseAdminKey: '',    // 環境変数 NUXT_FIREBASE_ADMIN_KEY で上書き

    public: {
      // 🌐 クライアントに露出する = 公開情報のみ
      contentfulSpaceId: '', // NUXT_PUBLIC_CONTENTFUL_SPACE_ID
      apiBaseUrl: '',        // NUXT_PUBLIC_API_BASE_URL
    },
  },
})
```

**配置の判断基準**:

```python
IF 漏洩して困る値（秘密鍵、DB認証情報、管理者トークン、Webhook署名シークレット）:
    → runtimeConfig 直下（public の外）。server/ 内でのみ参照
ELSE IF ブラウザのDevToolsで見えても問題ない値（公開API URL、公開SpaceID、計測ID）:
    → runtimeConfig.public
```

- ❌ `public` 配下に `*Secret` / `*PrivateKey` / 管理者権限トークンを置かない（クライアントバンドルに平文で載る）
- ❌ `process.env` の直接読み取り禁止（クライアント側では解決されない）
- ❌ Contentful等の Delivery API キーでも、書き込み権限を持つ Management トークンは public に置かない

```typescript
// ✅ クライアント・サーバー共通
const config = useRuntimeConfig()
const spaceId = config.public.contentfulSpaceId

// ✅ server/api/** 内のみ（event を渡す）
const secret = useRuntimeConfig(event).stripeSecretKey
```

### 7.2 Cookie（useCookie）

`useCookie` はクライアント側で `document.cookie` を操作するため `httpOnly` を付けられない。**認証情報の保存先には使わない**。

```typescript
// ❌ 認証トークンを useCookie で保存（JSから読める = XSSで奪取される）
const token = useCookie('token')

// ✅ セッションはサーバー側で httpOnly を付けて発行する
// server/api/auth/login.post.ts
setCookie(event, 'session', sessionId, {
  httpOnly: true,   // JSから読めない（XSS対策）
  secure: true,     // HTTPS のみ
  sameSite: 'lax',  // CSRF対策。クロスサイト送信が必要な場合のみ 'none' + secure
  maxAge: 60 * 60 * 24 * 7,
  path: '/',
})

// ✅ useCookie は非機密なUI設定にのみ使う
const theme = useCookie<'light' | 'dark'>('theme', {
  sameSite: 'lax',
  maxAge: 60 * 60 * 24 * 365,
})
```

### 7.3 ルートミドルウェアによる認証ガード

```typescript
// app/middleware/auth.ts（Nuxt 3 は middleware/auth.ts）
export default defineNuxtRouteMiddleware((to) => {
  const { firebaseUser } = useAuth()

  if (!firebaseUser.value) {
    return navigateTo(`/login?redirect=${encodeURIComponent(to.fullPath)}`)
  }
})
```

```vue
<script setup lang="ts">
definePageMeta({ middleware: 'auth' })
</script>
```

**ミドルウェアはUI遷移の制御でしかない**。クライアントのルーティングは改竄可能なため、データ保護は必ずサーバー側（7.4）で再検証する。

### 7.4 Server API の認証・検証

```typescript
// server/api/events/[id].delete.ts
export default defineEventHandler(async (event) => {
  // 1. 認証（セッションCookie / Bearerトークンの検証）— 失敗時は 401 を throw
  const user = await requireUser(event)

  // 2. 入力検証（型と形式）
  const id = getRouterParam(event, 'id')
  if (!id || !/^[a-zA-Z0-9_-]{1,64}$/.test(id)) {
    throw createError({ statusCode: 400, message: 'Invalid event ID' })
  }

  // 3. 認可（そのリソースがこのユーザーのものか — BOLA対策）
  const eventData = await fetchEventById(id)
  if (!eventData) {
    throw createError({ statusCode: 404, message: 'Not found' })
  }
  if (eventData.ownerId !== user.id) {
    throw createError({ statusCode: 403, message: 'Forbidden' })
  }

  await deleteEventById(id)
  return { success: true }
})
```

- `createError` の `message` はクライアントに返る。内部エラー詳細・スタックトレース・DBエラー文言を載せない
- Webhook（`server/api/webhooks/*.post.ts`）は署名検証を必須にする。署名対象は生ボディのため `readRawBody(event)` で取得する（`readBody` はパース済みで署名が合わない）
- 認証方式・レート制限の実装詳細は `backend-api.md` に従う

### 7.5 入力検証・出力エスケープ

```typescript
// ✅ バリデーション関数使用（クライアント側は UX 目的。検証はサーバーでも必ず行う）
import { validateEmail } from '~/utils/validator'

const email = ref('')
const isValid = computed(() => validateEmail(email.value))
```

```vue
<template>
  <!-- ✅ Vue自動エスケープ（XSS対策） -->
  <p>{{ userInput }}</p>

  <!-- ❌ サニタイズなしの v-html は禁止 -->
  <div v-html="userInput" />
</template>
```

Markdown等でHTML描画が必要な場合のみ、DOMPurify でサニタイズしてから渡す（実装パターンは `frontend-web.md` の XSS Prevention 参照）。

---

## [REFERENCE] 8. コード品質チェックリスト

実装完了後、以下を確認：

- [ ] TypeScript型エラー0件（`npx nuxt typecheck`）
- [ ] ESLint・Prettier適用（`/validate --layers=syntax --auto-fix`）
- [ ] Props/Emits適切に型定義（Interface or 直接型定義、1.2 / 1.3）
- [ ] Composables単一責任・状態管理の選択基準に準拠（2.2 / 2.4）
- [ ] catch 節が記録または変換を行っている（no-op rethrow がない、2.3）
- [ ] `pending` 不使用・`status` を使用（3.4）
- [ ] `runtimeConfig.public` に機密値が入っていない（7.1）
- [ ] 認証情報を `useCookie` に保存していない（7.2）
- [ ] server route に認証・入力検証・認可の3段が揃っている（7.4）
- [ ] サニタイズなしの `v-html` がない（7.5）
- [ ] アクセシビリティ（ARIA、キーボード操作）
- [ ] レスポンシブ対応（モバイル・タブレット・PC）
- [ ] パフォーマンス（Lazy Loading、画像最適化）

---

## [REFERENCE] 9. 参照ドキュメント

**継承元・関連ルール**:
- Web Frontend 汎用: `~/.claude/rules/tech-stacks/frontend-web.md`（継承元。TypeScript / セキュリティ / パフォーマンス / テストピラミッドの汎用規約）
- CSS規約: `~/.claude/rules/tech-stacks/css-coding-standards.md`
- Server API: `~/.claude/rules/tech-stacks/backend-api.md`（server/ 配下の認証・レート制限）

**外部ドキュメント**:
- Vue 3: https://vuejs.org/
- Vue Style Guide: https://vuejs.org/style-guide/
- Nuxt 3/4: https://nuxt.com/
- Nuxt 4 移行ガイド: https://nuxt.com/docs/getting-started/upgrade
- Nuxt Testing: https://nuxt.com/docs/getting-started/testing
- TypeScript: https://www.typescriptlang.org/
- Vitest: https://vitest.dev/

---

## Document Metadata

- **Primary Use Case**: Vue 3 / Nuxt 3・4 の実装・レビュー（週次）
- **Secondary Use Case**: Nuxt 移行判断、セキュリティレビュー、テスト基盤構築（月次）
- **Auto-update Trigger**: Nuxt メジャーリリース、Vue メジャーリリース、`@nuxt/test-utils` の API 変更、`useAsyncData` / `useFetch` の戻り値仕様変更
- **Obsolescence Risk**: High（Nuxt のデータフェッチング API とディレクトリ構成は変更頻度が高い）
- **Related Docs**: `~/.claude/rules/tech-stacks/frontend-web.md`, `~/.claude/rules/tech-stacks/css-coding-standards.md`, `~/.claude/rules/tech-stacks/backend-api.md`
- **Target**: Claude Code AI assistant
- **Vue Version**: 3.4+
- **Nuxt Version**: 3.x / 4.x
- **Last Updated**: 2026-09-01
