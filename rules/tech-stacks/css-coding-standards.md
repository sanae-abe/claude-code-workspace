# CSS Coding Standards

モダンWebプロジェクトのための包括的CSS記述基準。アクセシビリティ、パフォーマンス、保守性を重視。

**対象**: Vue/React/Next.js/Nuxt等のモダンフロントエンド開発

## 1. タッチデバイス対応

**ルール**: `:hover` は `@media (any-hover: hover)` で囲む

```css
/* OK */
@media (any-hover: hover) {
  .Button:hover { background-color: var(--primary, #8b5cf6); }
}

/* NG */
.Button:hover { background-color: var(--primary, #8b5cf6); }
```

## 2. アクセシビリティ

### 2.1 フォーカス表示

**ルール**: `:focus-visible` 必須、`outline: none` 絶対禁止

```css
/* OK */
.Button:focus-visible {
  outline: 2px solid var(--primary, #3b82f6);
  outline-offset: 2px;
}

/* NG */
.Button:focus { outline: none; } /* アクセシビリティ違反 */
```

### 2.2 アニメーション削減

**ルール**: `prefers-reduced-motion` 対応必須

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 2.3 カラーコントラスト

**ルール**: WCAG AA基準（4.5:1）を満たす

## 3. デザイントークン

### 3.1 CSS変数

**ルール**: カラー・スペーシング・フォントサイズは CSS変数使用、フォールバック値必須

```css
/* OK */
.Button {
  background-color: var(--primary, #3b82f6);
  padding: var(--spacing-md, 16px);
}

/* NG */
.Button {
  background-color: #3b82f6; /* ハードコード禁止 */
  color: var(--primary); /* フォールバックなし */
}
```

### 3.2 カラーパレット

```css
:root {
  /* ブランド */
  --primary: #3b82f6;
  --secondary: #64748b;

  /* セマンティック */
  --success: #28a745;
  --warning: #ffc107;
  --error: #dc3545;
  --info: #17a2b8;

  /* ニュートラル */
  --text-primary: #333;
  --text-secondary: #666;
  --border-color: #e0e0e0;
}
```

## 4. レスポンシブデザイン

### 4.1 モバイルファースト

**ルール**: デフォルト=モバイル、`min-width` で拡張

```css
/* OK - モバイルファースト */
.Container { padding: 16px; }
@media (min-width: 768px) { .Container { padding: 24px; } }
@media (min-width: 1024px) { .Container { padding: 32px; } }

/* NG - デスクトップファースト */
.Container { padding: 32px; }
@media (max-width: 1024px) { .Container { padding: 24px; } }
```

### 4.2 CSS Layers使用ルール

| ファイル種別 | @layer使用 | 理由 |
|-------------|-----------|------|
| **グローバルCSS** (`assets/styles/*.css`) | 必須 | 優先度管理 |
| **Vue SFC** (`<style scoped>`) | 禁止 | scoped属性で詳細度確保済み |
| **React CSS Modules** + utilityクラス使用 | 禁止 | modulesで詳細度確保 |
| **React CSS Modules** + utilityクラス未使用 | 可 | レイヤー管理可能 |

**グローバルCSS例**:

```css
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

**GPU加速プロパティ**: `transform`, `opacity`, `filter`
**避けるプロパティ**: `left`, `top`, `width`, `height`, `margin`, `padding`

### 5.3 will-change

**ルール**: アニメーション開始直前に追加、終了後に削除（ホバーでは不要）

```javascript
// アニメーション開始前
modal.classList.add('is-animating')
// アニメーション終了後
modal.addEventListener('transitionend', () => {
  modal.classList.remove('is-animating')
}, { once: true })
```

### 5.4 CSS Containment

```css
.ProductCard { contain: layout style paint; }
.Modal { contain: strict; }
```

## 6. 命名規則

| パターン | 形式 | 例 |
|---------|------|---|
| コンポーネントルート | PascalCase | `ProductCard` |
| 子要素 | PascalCase__camelCase | `ProductCard__image` |
| 状態 | is-kebab-case | `is-active` |
| 条件 | has-kebab-case | `has-icon` |
| ユーティリティ | u-kebab-case | `u-pc-only` |

**状態クラス例**: `is-active`, `is-disabled`, `is-loading`, `is-open`
**条件クラス例**: `has-image`, `has-icon`, `has-footer`
**ユーティリティ例**: `u-pc-only`, `u-sp-only`, `u-text-center`

**禁止**: BEM Modifier（`--`）, snake_case, ID セレクタ

## 7. wrapper / container

```
IF 背景色 OR 全幅padding OR セクション境界 THEN wrapper
ELSE IF 最大幅制限 OR 中央配置 THEN container
```

```css
.SectionWrapper { background-color: var(--bg); padding: 3rem 0; width: 100%; }
.Container { max-width: 75rem; margin: 0 auto; padding: 0 1rem; }
```

## 8. z-index管理

**ルール**: CSS変数のみ使用

```css
:root {
  --z-index-dropdown: 1000;
  --z-index-modal: 2100;
  --z-index-notification: 3000;
}

.Modal { z-index: var(--z-index-modal); }
```

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
.Card { border: 1px solid var(--border); }

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

## 10. 禁止パターン

| パターン | 代替案 |
|---------|-------|
| `!important` | 詳細度で解決（外部ライブラリ上書きのみ例外） |
| 固定幅・高さ | `max-width`, `min-height` |
| CSS変数フォールバックなし | `var(--x, fallback)` 必須 |

### CSS Injection対策

**ルール**: ユーザー入力からCSS変数生成時、ホワイトリスト検証必須

```typescript
// 共通化推奨
export const ALLOWED_COLORS = ['#3b82f6', '#64748b'] as const;

export function validateCSSColor(input: string): string {
  if (ALLOWED_COLORS.includes(input as any)) return input;
  if (/^#[0-9A-Fa-f]{6}$/.test(input)) return input;
  return '#3b82f6';
}
```

### アンチパターン一覧

| アンチパターン | 影響 | 修正方法 |
|--------------|-----|---------|
| `will-change` 常時設定 | メモリ増大 | JS動的制御 |
| `transition: all` | パフォーマンス低下 | 個別プロパティ |
| `:hover` タッチ未対応 | UI残留 | `@media (any-hover)` |
| `outline: none` | アクセシビリティ違反 | `:focus-visible` |
| px固定サイズ | ユーザー設定無視 | rem使用 |

## 11. 検証フロー

### Stylelint設定

```json
{
  "extends": "stylelint-config-standard",
  "rules": {
    "declaration-no-important": [true, { "severity": "warning" }],
    "selector-max-id": 0,
    "unit-allowed-list": ["rem", "em", "%", "vh", "vw", "px", "deg", "s", "ms"]
  }
}
```

### チェックリスト

**必須**:
- `:hover` は `@media (any-hover: hover)` で囲む
- `:focus-visible` スタイル定義
- CSS変数使用（フォールバック付き）
- `transition: all` 使用なし
- `outline: none` 使用なし
- rem単位使用

**推奨**:
- WCAGコントラスト比チェック
- GPU加速プロパティ使用
- レスポンシブ対応

## 12. セキュリティ

### 12.1 SRI（Subresource Integrity）

**ルール**: CDNからのCSS/フォントにSRIハッシュ必須

```html
<!-- OK -->
<link href="https://fonts.googleapis.com/css2?family=Roboto"
      rel="stylesheet"
      integrity="sha384-..."
      crossorigin="anonymous">

<!-- NG -->
<link href="https://fonts.googleapis.com/css2?family=Roboto" rel="stylesheet">
```

### 12.2 CSP設定

**Vue/React対応**: nonce生成必須

```typescript
// Next.js middleware例
const nonce = crypto.randomBytes(16).toString('base64');
const cspHeader = `
  style-src 'self' 'nonce-${nonce}';
  script-src 'self' 'nonce-${nonce}';
`.replace(/\s{2,}/g, ' ').trim();
```

### 12.3 Web Fonts

**size-adjust でCLS軽減**:

```css
@font-face {
  font-family: 'Inter Fallback';
  src: local('Arial');
  size-adjust: 107%; /* Inter/Arial サイズ差補正 */
}
```

**計算**: `size-adjust = (Webフォント x-height) / (フォールバック x-height) × 100%`

### セキュリティ検証（Grep自動化）

```bash
# CSS Injection検索
rg "v-bind.*userInput|:style.*userInput" --type vue

# SRI未付与検索
rg "<link.*https://.*rel=\"stylesheet\"" --type html | rg -v "integrity="

# outline削除検出
rg "outline:\s*none" --type css --type vue
```

## 13. 新機能採用基準

**基準**: ブラウザサポート80%+、プログレッシブエンハンスメント可能

| 機能 | サポート | 用途 |
|------|---------|------|
| Container Queries | 90%+ | コンポーネント単位レスポンシブ |
| `:has()` | 90%+ | 親要素セレクタ |
| CSS Nesting | 85%+ | ネストセレクタ |
| `color-mix()` | 85%+ | 動的カラー |
| Cascade Layers | 90%+ | 優先度管理 |
| Subgrid | 80%+ | グリッド入れ子 |

## 参考リンク

- WCAG: https://www.w3.org/WAI/WCAG21/quickref/
- MDN: https://developer.mozilla.org/ja/docs/Web/CSS
- CSS Triggers: https://csstriggers.com/
- Stylelint: https://stylelint.io/

---

**バージョン**: 1.4.1 | **最終更新**: 2025-11-24 | **文字数**: 約38k（最適化版）
