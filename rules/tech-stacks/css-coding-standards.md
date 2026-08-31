# CSS Coding Standards

モダンWebプロジェクトのための包括的CSS記述基準。アクセシビリティ、パフォーマンス、保守性を重視。

**対象**: Vue/React/Next.js/Nuxt等のモダンフロントエンド開発

**適用範囲**:

| 実装方式 | 適用される章 |
|---------|-------------|
| 生CSS / CSS Modules / SFC `<style>` | 全章 |
| Tailwind CSS 主体 | 1, 2, 3.3, 5, 12, 13（6章命名規則・9章単位規則は適用外。`@apply` を含むカスタムCSSと `tailwind.config` のトークン定義には3章を適用） |
| CSS-in-JS (styled-components 等) | 6章の命名規則を除き全章 |

## 1. タッチデバイス対応

**ルール**: `:hover` は `@media (any-hover: hover)` で囲む

```css
/* OK */
@media (any-hover: hover) {
  .Button:hover { background-color: var(--primary, #3b82f6); }
}

/* NG */
.Button:hover { background-color: var(--primary, #3b82f6); }
```

## 2. アクセシビリティ

### 2.1 フォーカス表示

**ルール**: `:focus-visible` 必須、`outline: none` / `outline: 0` 絶対禁止

```css
/* OK */
.Button:focus-visible { outline: 2px solid var(--focus-ring, #3b82f6); outline-offset: 2px; }

/* NG */
.Button:focus { outline: none; } /* アクセシビリティ違反 */
```

`outline` を別表現に置き換える場合は `box-shadow` で同等の可視性（コントラスト比3:1以上・厚み2px以上）を確保する。

### 2.2 アニメーション削減

**ルール**: `prefers-reduced-motion` 対応必須

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important; /* 無限ループ停止に必須 */
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

`animation-iteration-count` を省略すると `infinite` なアニメーションが 0.01ms 間隔で回り続けCPU負荷が増大する。

### 2.3 カラーコントラスト

**ルール**: WCAG 2.2 AA を満たす

| 対象 | 最小比 | 達成基準 |
|-----|-------|---------|
| 通常テキスト（< 24px、または < 18.66px かつ太字） | 4.5:1 | 1.4.3 |
| 大きいテキスト（>= 24px、または >= 18.66px かつ太字） | 3:1 | 1.4.3 |
| UIコンポーネント境界・状態表示・アイコン | 3:1 | 1.4.11 |
| 装飾目的のみの要素 | 対象外 | 1.4.11 |

ダークモードのトークンも同一基準で個別に検証する（3.3参照）。

### 2.4 タップターゲット

**ルール**: インタラクティブ要素は最小 24x24 CSS px（WCAG 2.2 / 2.5.8）、推奨 44x44

視覚サイズを小さく保つ場合は擬似要素で当たり判定のみ拡張する。

```css
.IconButton { position: relative; width: 1.5rem; height: 1.5rem; }
.IconButton::after { content: ''; position: absolute; inset: -0.625rem; } /* 44px相当に拡張 */
```

### 2.5 強制カラーモード

**ルール**: 状態を背景色のみで表現しない（強制カラーモードで背景が上書きされ状態が消える）

```css
.Chip.is-selected { background-color: var(--primary, #3b82f6); border: 1px solid transparent; }

@media (forced-colors: active) {
  .Chip.is-selected { border-color: Highlight; color: HighlightText; }
}
```

境界線・アイコン・テキストラベルのいずれかを状態表現に併用する。

## 3. デザイントークン / ダークモード

### 3.1 CSS変数

**ルール**: カラー・スペーシング・フォントサイズは CSS変数使用、フォールバック値必須

```css
/* OK */
.Button { background-color: var(--primary, #3b82f6); padding: var(--spacing-md, 1rem); }

/* NG */
.Button {
  background-color: #3b82f6; /* ハードコード禁止 */
  color: var(--primary);     /* フォールバックなし */
}
```

フォールバックはトークン未定義時の保険で、正となる値は常に `:root` の定義。トークン値の変更時はフォールバックも同時更新する（更新漏れは静かに旧色を表示する）。

### 3.2 カラーパレット

**ルール**: セマンティックな役割名で定義する（`--blue-500` のような色名ベースはダークモードで破綻する）

```css
:root {
  color-scheme: light;
  /* ブランド */
  --primary: #3b82f6;
  --secondary: #64748b;
  /* セマンティック（白背景で4.5:1以上の濃度） */
  --success: #15803d;
  --warning: #a16207;
  --error: #b91c1c;
  --info: #0e7490;
  /* サーフェス / テキスト */
  --bg: #ffffff;
  --surface: #f8fafc;
  --text-primary: #1f2937;
  --text-secondary: #4b5563;
  --border-color: #e0e0e0;
  --focus-ring: #3b82f6;
}
```

注: `#28a745` は白背景で約2.5:1 のためテキスト用途に不足する。

### 3.3 ダークモード

**ルール**: 3状態（明示light / 明示dark / システム追従）すべてに対応し、切り替えるのはトークンの**値のみ**（プロパティ名・セレクタは不変）

```css
/* 1. ライト = bare :root。全トークンを必ずここで定義する */
:root {
  color-scheme: light;
  --bg: #ffffff; --surface: #f8fafc; --text-primary: #1f2937;
  --border-color: #e0e0e0; --shadow-card: 0 1px 3px rgb(0 0 0 / 12%);
}

/* 2. 明示切替（トグルが両方向で勝つ） */
:root[data-theme="dark"] {
  color-scheme: dark;
  --bg: #16181c; --surface: #1f2226; --text-primary: #e8e8e8; /* 純白はハレーションのため避ける */
  --border-color: #3a3f45; --shadow-card: 0 1px 3px rgb(0 0 0 / 60%);
}

/* 3. システム追従 — 2 と同一の宣言を適用（SCSS/PostCSSでは mixin で共通化） */
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { /* ↑ 2 と同じ宣言ブロック */ }
}

body { background-color: var(--bg, #fff); color: var(--text-primary, #1f2937); }
```

**必須要件**:

| 項目 | 内容 |
|-----|------|
| `color-scheme` | 必須。フォームコントロール・スクロールバー等のネイティブ配色が追従する |
| トークン定義位置 | 全トークンを bare `:root` に定義。メディアクエリ/属性セレクタ内**だけ**の定義は禁止（片方の状態で未定義になる） |
| `body` の背景 | 明示指定必須（透過のままだとブラウザ既定色が透ける） |
| コントラスト | ダーク側の全組み合わせを2.3の基準で再検証 |
| 影 | 不透明度を上げるか境界線に置換（暗背景上の淡い影は視認できない） |
| 画像 | `filter: brightness()` の一括減光は禁止。ダーク用アセットか `<picture>` で切替 |
| FOUC | SSR時に `<html data-theme>` をサーバー側で埋め込む（クライアントJSの後付けは初回描画でちらつく） |

```javascript
// 'light' | 'dark' | null（null = システム追従）
const applyTheme = (theme) => {
  if (theme) document.documentElement.dataset.theme = theme
  else delete document.documentElement.dataset.theme
  localStorage.setItem('theme', theme ?? 'system')
}
```

## 4. レスポンシブデザイン

### 4.1 モバイルファースト

**ルール**: デフォルト=モバイル、`min-width` で拡張

```css
/* OK - モバイルファースト */
.Container { padding: 1rem; }
@media (min-width: 768px) { .Container { padding: 1.5rem; } }
@media (min-width: 1024px) { .Container { padding: 2rem; } }

/* NG - デスクトップファースト */
.Container { padding: 2rem; }
@media (max-width: 1024px) { .Container { padding: 1.5rem; } }
```

### 4.2 CSS Layers使用ルール

| ファイル種別 | @layer使用 | 理由 |
|-------------|-----------|------|
| **グローバルCSS** (`assets/styles/*.css`) | 必須 | 優先度管理 |
| **Vue SFC** (`<style scoped>`) | 禁止 | scoped属性で詳細度確保済み |
| **React CSS Modules** + utilityクラス使用 | 禁止 | modulesで詳細度確保 |
| **React CSS Modules** + utilityクラス未使用 | 可 | レイヤー管理可能 |

**ルール**: レイヤー順序をエントリCSSの先頭で宣言する（宣言がないと出現順依存になり優先度管理が成立しない）

```css
/* assets/styles/index.css 先頭 — 後方のレイヤーが強い */
@layer reset, base, layout, components, utilities;

@layer layout {
  .Container { padding: 1rem; }
  @media (min-width: 768px) { .Container { padding: 1.5rem; } }
}
```

**Vue SFC例（@layer禁止）**:

```vue
<style scoped>
/* @layerを使用しない */
.Container { display: grid; }
@media (min-width: 768px) { .Container { grid-template-columns: repeat(2, 1fr); } }
</style>
```

### 4.3 ブレークポイント

```css
/* モバイル: < 768px */
/* タブレット: 768px-1023px */
@media (min-width: 768px) { }
/* PC: 1024px-1439px */
@media (min-width: 1024px) { }
/* ワイド: 1440px+ */
@media (min-width: 1440px) { }
```

### 4.4 論理プロパティ

**ルール**: 新規実装は論理プロパティ優先（RTL言語・縦書きへ無改修で対応できる）

| 物理 | 論理 |
|-----|------|
| `padding-left` / `padding-right` | `padding-inline`（`-start` / `-end`） |
| `margin-top` / `margin-bottom` | `margin-block`（`-start` / `-end`） |
| `border-left` | `border-inline-start` |
| `text-align: left` | `text-align: start` |
| `width` / `height` | `inline-size` / `block-size` |
| `top` / `right` / `bottom` / `left` | `inset-block` / `inset-inline`（一括は `inset`） |

```css
/* OK */
.Card { padding-inline: 1rem; border-inline-start: 2px solid var(--primary, #3b82f6); }

/* NG（RTLで左右が反転しない） */
.Card { padding-left: 1rem; border-left: 2px solid var(--primary, #3b82f6); }
```

物理プロパティは書字方向に依存せず物理方向を固定する場合のみ使用（例: 画面下部固定のトースト）。

### 4.5 Container Queries

**判断基準**:
```
IF 同一コンポーネントが複数の幅コンテキストに配置される THEN container query
ELSE IF ページ全体のレイアウト切替 THEN media query
```

```css
.CardList { container-type: inline-size; container-name: cardlist; }
@container cardlist (min-width: 400px) { .Card { grid-template-columns: 8rem 1fr; } }
```

注: `container-type: inline-size` は inline方向の size containment を含むため、コンテナ自身の幅を内容から決める指定（`width: max-content` 等）とは併用できない。

## 5. パフォーマンス

### 5.1 トランジション

**ルール**: `transition: all` 禁止、個別プロパティ指定

```css
/* OK */
.Button { transition: background-color 0.15s ease, transform 0.15s ease; }

/* NG */
.Button { transition: all 0.3s; }
```

### 5.2 GPU加速

**GPU加速プロパティ**: `transform`, `opacity`, `filter`（`blur` は半径が大きいほど高コスト）
**避けるプロパティ**: `left`, `top`, `width`, `height`, `margin`, `padding`

### 5.3 will-change

**ルール**: アニメーション開始直前に追加、終了後に削除（ホバーでは不要）

```css
/* .is-animating が付いている間だけ will-change を有効化 */
.Modal.is-animating { will-change: transform, opacity; }
```

```javascript
const clear = () => modal.classList.remove('is-animating')

modal.classList.add('is-animating')
// transitionend はプロパティごとに発火するため、最後に完了するプロパティを指定する
modal.addEventListener('transitionend', (e) => {
  if (e.target === modal && e.propertyName === 'opacity') clear()
})
modal.addEventListener('transitioncancel', clear) // 中断時は transitionend が発火しない
setTimeout(clear, 600)                            // transition未発生時の保険（duration より長く）
```

**禁止**: `transitionend` + `{ once: true }` のみでの解除（1つ目のプロパティ完了時点で解除され残りに `will-change` が残る／中断時は永久に残り「常時設定」アンチパターンになる）。

### 5.4 CSS Containment

```css
.ProductCard { contain: layout style paint; }

/* contain: strict は size containment を含むため、明示的な width / height が必須。
   未指定の場合、要素サイズが 0 になる。 */
.Modal { contain: strict; width: 37.5rem; height: 25rem; }
```

サイズが内容依存のコンポーネントでは `contain: strict` を使わず `contain: layout style paint` を選ぶ（10章「固定幅・高さ禁止」との整合）。

### 5.5 CLS対策

**ルール**: 遅延読み込みされるメディアは寸法を予約する

```css
.Thumbnail { aspect-ratio: 16 / 9; width: 100%; height: auto; }
img, video { max-width: 100%; height: auto; }
```

HTML側の `width` / `height` 属性も必須（CSS適用前の初回描画で予約が効く）。フォント起因のCLSは12.4参照。

## 6. 命名規則

| パターン | 形式 | 例 |
|---------|------|---|
| コンポーネントルート | PascalCase | `ProductCard` |
| 子要素 | PascalCase__camelCase | `ProductCard__imageWrapper` |
| 状態 | is-kebab-case | `is-active` |
| 条件 | has-kebab-case | `has-icon` |
| ユーティリティ | u-kebab-case | `u-pc-only` |

**状態クラス例**: `is-active`, `is-disabled`, `is-loading`, `is-open`
**条件クラス例**: `has-image`, `has-icon`, `has-footer`
**ユーティリティ例**: `u-pc-only`, `u-sp-only`, `u-text-center`

**ルール**: 状態・条件クラスは単独でスタイルを定義せず、必ずコンポーネントクラスに連結する

```css
/* OK */
.ProductCard.is-active { border-color: var(--primary, #3b82f6); }

/* NG（グローバル衝突する） */
.is-active { border-color: var(--primary, #3b82f6); }
```

**禁止**: BEM Modifier（`--`）, snake_case, ID セレクタ

## 7. wrapper / container

```
IF 背景色 OR 全幅padding OR セクション境界 THEN wrapper
ELSE IF 最大幅制限 OR 中央配置 THEN container
```

両方の役割が必要な場合は入れ子にする（1要素に兼務させない）。

```html
<section class="SectionWrapper">
  <div class="Container">...</div>
</section>
```

```css
.SectionWrapper { background-color: var(--surface, #f8fafc); padding-block: 3rem; width: 100%; }
.Container { max-width: 75rem; margin-inline: auto; padding-inline: 1rem; }
```

## 8. z-index管理

**ルール**: CSS変数のみ使用（数値の直接指定禁止）

```css
:root {
  --z-index-base: 0;
  --z-index-dropdown: 1000;
  --z-index-sticky-header: 1100;
  --z-index-overlay: 2000;   /* モーダル背面の遮蔽層 */
  --z-index-modal: 2100;
  --z-index-popover: 2200;
  --z-index-tooltip: 2300;
  --z-index-notification: 3000;
}

.Modal { z-index: var(--z-index-modal, 2100); }
```

**注意**: `z-index` は `position` が `static` 以外の要素、または flex/grid item にのみ有効。`transform` / `filter` / `opacity < 1` / `will-change` / `contain: paint` は新しいスタッキングコンテキストを生成し、その子要素は親の階層を超えられない（モーダルが祖先の `transform` に閉じ込められる典型的原因）。

## 9. 単位統一

### 9.1 rem推奨

**判断基準**:
```
IF フォントサイズ OR スペーシング THEN rem
ELSE IF ボーダー幅（1-3px） THEN px
ELSE IF 装飾アイコン（固定サイズ） THEN px
ELSE IF box-shadow, outline-offset THEN px
ELSE rem
```

```css
/* OK */
.Text { font-size: 1rem; padding: 1.5rem; }
.Card { border: 1px solid var(--border-color, #e0e0e0); }

/* NG */
.Text { font-size: 16px; padding: 24px; }
```

**rem換算**: `0.75rem=12px`, `1rem=16px`, `1.5rem=24px`, `2rem=32px`

### 9.2 line-height

**ルール**: 単位なし数値

```css
/* OK */
.Text { line-height: 1.5; }

/* NG */
.Text { line-height: 24px; }
```

## 10. 禁止パターン・アンチパターン

| パターン | 影響 | 代替案 |
|---------|-----|-------|
| `!important` | 優先度の破綻 | 詳細度・`@layer` で解決（例外: 外部ライブラリ上書き、`prefers-reduced-motion` リセット） |
| 固定幅・高さ | ズーム・翻訳で破綻 | `max-width`, `min-height`（例外: 5.4の size containment 適用時は指定必須） |
| CSS変数フォールバックなし | 未定義時に無効値 | `var(--x, fallback)` 必須（3.1） |
| `will-change` 常時設定 | メモリ増大 | JS動的制御（5.3） |
| `transition: all` | パフォーマンス低下 | 個別プロパティ（5.1） |
| `:hover` タッチ未対応 | UI残留 | `@media (any-hover: hover)`（1章） |
| `outline: none` / `0` | アクセシビリティ違反 | `:focus-visible`（2.1） |
| px固定サイズ | ユーザー設定無視 | rem使用（9.1） |
| 色名ベースのトークン | ダークモードで破綻 | セマンティック命名（3.2） |
| メディアクエリ内のみのトークン定義 | 片方の状態で未定義 | bare `:root` に定義（3.3） |
| 状態クラスの単独定義 | グローバル衝突 | コンポーネントクラスに連結（6章） |

## 11. 検証フロー

### Stylelint設定

```json
{
  "extends": ["stylelint-config-standard"],
  "overrides": [
    { "files": ["**/*.vue"], "customSyntax": "postcss-html" },
    { "files": ["**/*.scss"], "customSyntax": "postcss-scss" }
  ],
  "rules": {
    "selector-class-pattern": [
      "^(([A-Z][a-zA-Z0-9]*)(__[a-z][a-zA-Z0-9]*)?|(is|has|u)-[a-z0-9]+(-[a-z0-9]+)*)$",
      { "message": "PascalCase / PascalCase__camelCase / is- has- u- prefix のいずれか（6章）" }
    ],
    "declaration-no-important": [true, { "severity": "warning" }],
    "selector-max-id": 0,
    "unit-allowed-list": ["rem", "em", "%", "fr", "vh", "vw", "dvh", "svh", "px", "deg", "s", "ms"],
    "declaration-property-unit-allowed-list": {
      "font-size": ["rem", "em", "%"],
      "/^padding/": ["rem", "em", "%"],
      "/^margin/": ["rem", "em", "%"]
    }
  }
}
```

必須依存: `stylelint`, `stylelint-config-standard`, `postcss-html`（Vue SFC検査に必須）, `postcss-scss`（SCSS使用時）

```bash
npx stylelint "**/*.{css,scss,vue}" --fix
```

注:
- `.stylelintrc.json` はJSON形式のためコメント記述不可
- `selector-class-pattern` の上書きは**必須**。`stylelint-config-standard` の既定は kebab-case で、6章のPascalCaseが全件エラーになる
- `customSyntax: postcss-html` 未設定だと `.vue` の `<style scoped>` が一切検査されない
- `unit-allowed-list` から `fr` を落とすと Grid の `repeat(2, 1fr)` がエラーになる
- `px` の許可範囲はボーダー幅（1-3px）・box-shadow・outline-offset・装飾アイコン固定サイズのみ（9.1参照）。`declaration-property-unit-allowed-list` で font-size / padding / margin のpxを機械的に禁止している

### チェックリスト

**必須（Stylelintで自動検証）**:
- 命名規則準拠
- font-size / padding / margin は rem
- ID セレクタ不使用

**必須（12.5のコマンドで検出 → 手動確認）**:
- `:hover` は `@media (any-hover: hover)` で囲む
- `outline: none` / `outline: 0` 使用なし
- 外部CSSにSRI付与
- ユーザー入力由来の動的スタイルにホワイトリスト検証

**必須（手動レビュー）**:
- `:focus-visible` スタイル定義
- CSS変数使用（フォールバック付き）
- `transition: all` 使用なし
- ダークモードのトークン定義漏れなし（bare `:root` に全定義）

**推奨**:
- コントラスト比の実測（2.3の表と照合。Chrome DevTools > Elements > Accessibility または axe DevTools）
- アニメーションは `transform` / `opacity` のみで実装（5.2）
- 320px / 768px / 1024px / 1440px の4幅で崩れなし

## 12. セキュリティ

### 12.1 CSS Injection対策

**ルール**: ユーザー入力からCSS変数・`style` 属性を生成する場合、ホワイトリスト検証必須

```typescript
// 共通化推奨（ホワイトリストのみで検証 — 任意hexを通すregexフォールバックは検証を無効化するため禁止）
export const ALLOWED_COLORS = ['#3b82f6', '#64748b'] as const;
type AllowedColor = (typeof ALLOWED_COLORS)[number];

export function validateCSSColor(input: string): AllowedColor {
  if ((ALLOWED_COLORS as readonly string[]).includes(input)) {
    return input as AllowedColor;
  }
  return '#3b82f6'; // 不正入力はデフォルト色にフォールバック
}
```

**禁止事項**:
- `innerHTML` / `v-html` による `<style>` 要素の生成
- ユーザー入力の `style` 属性・CSS変数への直接代入（`el.style.setProperty('--x', userInput)`）
- ユーザー入力を含むURLの `background-image: url()` への代入（外部リクエストによる情報漏洩）

数値入力は範囲検証後に単位を付与して使用する（例: `Math.min(Math.max(n, 0), 100) + '%'`）。

### 12.2 SRI（Subresource Integrity）

**ルール**: CDNからのCSS/フォントにSRIハッシュ必須

**注意**: Google Fonts は User-Agent に応じて CSS を動的生成するため SRI が機能しない。
セルフホスティング（`fontsource` 等）または静的ファイルを提供する CDN を使用すること。

```html
<!-- OK: 静的ファイルを配信する CDN（jsdelivr 等）-->
<link href="https://cdn.jsdelivr.net/npm/normalize.css@8.0.1/normalize.css"
      rel="stylesheet"
      integrity="sha384-..."
      crossorigin="anonymous">

<!-- OK: Google Fonts はセルフホスティングで回避 -->
<!-- npm install @fontsource/roboto -->
<link rel="stylesheet" href="/fonts/roboto.css">

<!-- NG: Google Fonts に SRI は機能しない（動的生成のため毎回ハッシュが変わる）-->
<!-- <link href="https://fonts.googleapis.com/css2?family=Roboto"
      integrity="sha384-..." crossorigin="anonymous"> -->

<!-- NG: SRI なしで外部 CDN -->
<link href="https://cdn.example.com/lib.css" rel="stylesheet">
```

SRIハッシュ生成:
```bash
curl -s https://cdn.example.com/lib.css | openssl dgst -sha384 -binary | openssl base64 -A
```

### 12.3 CSP設定

**Vue/React対応**: nonce生成必須

```typescript
// Next.js middleware例（Edge runtimeでは node:crypto 不可 — グローバルの Web Crypto を使用）
const nonce = Buffer.from(crypto.randomUUID()).toString('base64');
const cspHeader = `
  style-src 'self' 'nonce-${nonce}';
  script-src 'self' 'nonce-${nonce}';
`.replace(/\s{2,}/g, ' ').trim();
// nonceはrequest headers経由でページに渡す（詳細: frontend-web.md CSPセクション）
```

注: `Buffer` は Next.js が Edge runtime に提供するポリフィルに依存する。Next.js以外のEdge環境（Cloudflare Workers 等）では `btoa(crypto.randomUUID())` を使用。

### 12.4 Web Fonts

**size-adjust でCLS軽減**: フォールバックフォントのメトリクスをWebフォントに合わせる

```css
@font-face {
  font-family: 'Inter Fallback';
  src: local('Arial');
  size-adjust: 107%;      /* Inter/Arial のサイズ差補正 */
  ascent-override: 90%;
  descent-override: 22%;
  line-gap-override: 0%;
}

/* 定義した fallback をスタックに入れないと効果がない */
body { font-family: 'Inter', 'Inter Fallback', sans-serif; }
```

**計算**: `size-adjust = (Webフォント x-height) / (フォールバック x-height) × 100%`

数値の自動算出は `fontaine`（Nuxt/Vite）または `next/font`（Next.js、fallback自動生成）を使用する。

### 12.5 検証コマンド

すべての `rg` にパス（`.`）を明示する。パス省略時、非対話シェル（スクリプト・Git hook・CI）では ripgrep が標準入力を読み待ちしてハングする。

```bash
# SRI未付与の外部stylesheet（属性順序・複数行タグに対応）
rg -l -g '*.{html,vue,jsx,tsx,astro}' 'rel=.?.?stylesheet' . | while IFS= read -r f; do
  perl -0777 -ne 'while (/<link\b[^>]*>/gs) { $t = $&; next unless $t =~ /stylesheet/ && $t =~ m{https?://}; next if $t =~ /integrity=/; $t =~ s/\s+/ /g; print "$ARGV: $t\n" }' "$f"
done

# CSS Injection の候補箇所（ヒットは全て手動レビュー対象 — 値の由来がユーザー入力かを確認）
rg -n -g '*.vue' -e ':style="' -e 'v-bind\(' .
rg -n -g '*.{jsx,tsx}' -e 'style=\{' .
rg -n -g '*.{ts,js,vue,jsx,tsx}' -e 'style\.setProperty\(' -e 'innerHTML\s*=' -e 'v-html' .

# outline削除の検出
rg -n -e 'outline:\s*(none|0)\b' -g '*.{css,scss,vue,jsx,tsx}' .

# any-hover 未対応の :hover 候補（ヒット行の前後を目視確認）
rg -n ':hover' -g '*.{css,scss,vue}' .
```

いずれのコマンドも「ヒット0件 = 違反なし」であり、終了コードは1になる（CIで `|| true` を付けるか、件数で判定する）。

## 13. 新機能採用基準

**基準**: ブラウザサポート90%+（Baseline Widely available 相当）、かつプログレッシブエンハンスメント可能

サポート率は変動するため実装前に https://caniuse.com で確認する。以下は目安。

| 機能 | サポート（2026年時点） | 用途 |
|------|-------------------|------|
| Container Queries | ~96% | コンポーネント単位レスポンシブ（4.5） |
| `:has()` | ~96% | 親要素セレクタ |
| CSS Nesting | ~97% | ネストセレクタ |
| `color-mix()` | ~95% | 動的カラー |
| Cascade Layers | ~96% | 優先度管理（4.2） |
| 論理プロパティ | ~97% | RTL対応（4.4） |
| Subgrid | ~90% | グリッド入れ子 |

## 参考リンク

- WCAG 2.2: https://www.w3.org/WAI/WCAG22/quickref/
- MDN: https://developer.mozilla.org/ja/docs/Web/CSS
- Rendering Performance: https://web.dev/articles/rendering-performance
- Stylelint: https://stylelint.io/

---

## Document Metadata

- **Primary Use Case**: CSS実装・レビュー時の規約参照（週次）
- **Secondary Use Case**: Stylelint設定・アクセシビリティ監査・ダークモード実装（月次）
- **Auto-update Trigger**: ブラウザサポート表の年次更新、WCAG改訂、Stylelintメジャーリリース
- **Obsolescence Risk**: Medium（CSS新機能の採用基準は年次見直しが必要）
- **Related Docs**: `~/.claude/rules/tech-stacks/frontend-web.md`, `~/.claude/rules/tech-stacks/vue-nuxt.md`
- **Target**: Claude Code AI assistant
- **Version**: 1.7.0
- **Last Updated**: 2026-08-31
