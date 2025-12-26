# CSS Coding Standards

モダンWebプロジェクトのための包括的CSS記述基準。アクセシビリティ、パフォーマンス、保守性を重視。

**対象**: Vue/React/Next.js/Nuxt等のモダンフロントエンド開発
**適用範囲**: 新規プロジェクト、既存プロジェクトのリファクタリング

## 1. タッチデバイス対応

### any-hover: hover の必須使用

**ルール**: `:hover` 疑似クラスは必ず `@media (any-hover: hover)` で囲む

**理由**: タッチデバイスでホバー状態が残留する問題を防止

```css
/* 良い例 - ホバー可能なデバイスのみ適用 */
@media (any-hover: hover) {
  .Button:hover {
    background-color: var(--color-primary, #8b5cf6);
    transform: translateY(-2px);
  }
}

/* 悪い例 - タッチデバイスでホバー状態が残る */
.Button:hover {
  background-color: var(--color-primary, #8b5cf6);
}
```

**例外**: `:focus-visible` との併用時は省略可能（後述）


## 2. アクセシビリティ

### 2.1 フォーカス表示の必須化

**ルール**: インタラクティブ要素には `:focus-visible` スタイル必須

**理由**: キーボード操作ユーザーのアクセシビリティ確保

```css
/* 良い例 - キーボード操作時のみフォーカス表示 */
.Button:focus-visible {
  outline: 2px solid var(--color-primary, #3b82f6);
  outline-offset: 2px;
}

/* 良い例 - ホバーとフォーカスの併用 */
.Button:focus-visible {
  background-color: var(--color-primary, #8b5cf6);
}

@media (any-hover: hover) {
  .Button:hover {
    background-color: var(--color-primary, #8b5cf6);
  }
}

/* 悪い例 - フォーカス表示の削除（アクセシビリティ違反） */
.Button:focus {
  outline: none; /* 絶対禁止 - キーボードユーザーが操作不可になる */
}

/* 悪い例 - マウス操作時もフォーカス表示（UX低下） */
.Button:focus {
  outline: 2px solid var(--color-primary, #3b82f6); /* :focus-visible を使用すべき */
}

/* 注意 - outline削除は例外なく禁止 */
/* カスタムフォーカススタイルを実装する場合も、必ず視認可能な代替手段を提供 */
```

### 2.2 アニメーション削減設定の尊重

**ルール**: `prefers-reduced-motion` 設定の尊重必須

**理由**: 前庭障害・てんかん・乗り物酔いユーザーへの配慮

```css
/* 良い例 - アニメーション削減設定を尊重 */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

/* 良い例 - 個別要素での対応 */
.Modal {
  animation: fadeIn 0.3s ease;
}

@media (prefers-reduced-motion: reduce) {
  .Modal {
    animation: none;
  }
}
```

**推奨設定**: グローバルCSS（例: `assets/styles/base/_accessibility.css`）で一括設定

### 2.3 カラーコントラスト基準

**ルール**: WCAG AA基準（コントラスト比 4.5:1）を満たす

```css
/* 良い例 - 十分なコントラスト */
.u-text-primary {
  color: #333333; /* 背景 #FFFFFF とのコントラスト比 12.6:1 */
}

/* 悪い例 - 低コントラスト */
.u-text-light {
  color: #CCCCCC; /* 背景 #FFFFFF とのコントラスト比 1.6:1（不合格） */
}
```

**検証ツール**: Chrome DevTools の Lighthouse で自動チェック


## 3. デザイントークン

### 3.1 CSS変数の必須使用

**ルール**: カラー・スペーシング・フォントサイズは CSS変数使用必須

**理由**: テーマ対応、保守性向上、デザインシステム統一

```css
/* 良い例 - CSS変数使用（フォールバック値付き） */
.Button {
  background-color: var(--primary, #3b82f6);
  padding: var(--spacing-md, 16px);
  font-size: var(--font-size-base, 1rem);
}

/* 悪い例 - ハードコーディング */
.Button {
  background-color: #3b82f6;
  padding: 16px;
  font-size: 16px;
}

/* 注意 - フォールバックなし（CSS変数未定義時に描画崩れ） */
.Button {
  color: var(--primary); /* フォールバック値がないとCSS変数未定義時に問題 */
}
```

**フォールバック値の重要性**:
- **必ず指定**: CSS変数が未定義の場合のデフォルト値として機能
- **構文**: `var(--variable-name, fallback-value)`
- **例**: `var(--primary, #3b82f6)` → `--primary`が未定義なら`#3b82f6`を使用

### 3.2 カラーパレット定義

**推奨カラーパレット例**:

```css
:root {
  /* ========================================
     1. ブランドカラー（UI基調色）
     ======================================== */
  --primary: #3b82f6;
  --primary-bg: #eff6ff;

  --secondary: #64748b;
  --secondary-bg: #f1f5f9;

  --tertiary: #8b5cf6;
  --tertiary-bg: #f5f3ff;

  /* ========================================
     2. セマンティックカラー（状態表示）
     ======================================== */
  --success: #28a745;
  --success-bg: #d4edda;
  --success-text: #155724;

  --warning: #ffc107;
  --warning-bg: #fff3cd;
  --warning-text: #856404;

  --error: #dc3545;
  --error-bg: #f8d7da;
  --error-text: #721c24;

  --info: #17a2b8;
  --info-bg: #d1ecf1;
  --info-text: #0c5460;

  /* ========================================
     3. ニュートラルカラー（テキスト・ボーダー等）
     ======================================== */
  --text-primary: #333333;
  --text-secondary: #666666;
  --text-tertiary: #999999;
  --text-disabled: #cccccc;

  --border-color: #e0e0e0;
  --border-color-hover: #b0b0b0;

  --bg-primary: #ffffff;
  --bg-secondary: #f8f9fa;
  --bg-disabled: #e9ecef;
}
```

**使用例**:

```css
/* 良い例 - 用途に応じたカラー選択 */
.Button.is-primary {
  background-color: var(--primary, #3b82f6);
  color: var(--text-primary, #333);
}

.Alert.is-success {
  background-color: var(--success-bg, #d4edda);
  color: var(--success-text, #155724);
  border: 1px solid var(--success, #28a745);
}
```

**カラー選択ガイドライン**:

| 用途 | 使用カラー | 例 |
|-----|-----------|---|
| ブランド表現 | Primary/Secondary/Tertiary | ヘッダー、CTA |
| 成功メッセージ | success系 | 送信完了通知 |
| 警告メッセージ | warning系 | 確認ダイアログ |
| エラーメッセージ | error系 | バリデーションエラー |
| 情報メッセージ | info系 | ヒント、ガイド |
| 通常テキスト | text-primary | 本文 |
| 補足テキスト | text-secondary | キャプション |


## 4. レスポンシブデザイン

### 4.1 モバイルファースト推奨

**ルール**: デフォルトスタイルはモバイル、`min-width` で拡張

```css
/* 良い例 - モバイルファースト */
.Container {
  padding: 16px; /* モバイル (< 768px) */
}

@media (min-width: 768px) {
  .Container {
    padding: 24px; /* タブレット */
  }
}

@media (min-width: 1024px) {
  .Container {
    padding: 32px; /* PC */
  }
}

/* 悪い例 - デスクトップファースト（max-width） */
.Container {
  padding: 32px;
}

@media (max-width: 1024px) {
  .Container {
    padding: 24px;
  }
}
```

### 4.2 メディアクエリ記述順序（Mobile-First + CSS Layers）

**ルール**: CSS Layersと組み合わせた段階的レスポンシブ設計

**重要な注意事項**:
- **グローバルCSS** (`assets/styles/*.css`): `@layer`使用必須
- **Vue SFC** (`<style scoped>`): **`@layer`使用禁止**
  - 理由1: scoped属性で既に詳細度確保済み（`[data-v-xxx]`自動付与）
  - 理由2: レイヤー優先度の問題（`components` < `utilities` < `overrides`）
  - 理由3: テンプレート内utilityクラス（`flex`, `justify-between`等）がcomponentsレイヤーを上書き
  - 例外: utilityクラスを全く使用しないプロジェクトでは使用可能（稀）
- **React CSS Modules**: プロジェクト構成で判断
  - utilityクラス未使用 → `@layer`使用可能
  - utilityクラス使用（Tailwind等） → `@layer`使用禁止（modulesで詳細度確保）

**理由**:
- モバイル利用者が多いサービスに最適
- CSS Layers導入済みプロジェクトで特異性管理が容易
- 小→大の順序でCSS詳細度が自然に上がる
- モバイルが最小CSS、パフォーマンス向上

#### 推奨パターン（ハイブリッド型）

```css
/* assets/styles/layout.css */
@layer layout {
  /* 1. モバイルベース（320px～） */
  .Container {
    width: 100%;
    padding: 1rem; /* 16px */
  }

  /* 2. タブレット（768px～） */
  @media (min-width: 768px) {
    .Container {
      max-width: 768px;
      padding: 1.5rem; /* 24px */
    }
  }

  /* 3. デスクトップ（1024px～） */
  @media (min-width: 1024px) {
    .Container {
      max-width: 1024px;
      padding: 2rem; /* 32px */
    }
  }

  /* 4. ワイドデスクトップ（1440px～） */
  @media (min-width: 1440px) {
    .Container {
      max-width: 1280px;
    }
  }
}
```

#### Vue/Reactコンポーネントでの実装例

**重要**: Vue SFC (`<style scoped>`) では **`@layer`を使用しない**

```vue
<!-- 良い例 - Vue SFC（@layerなし、推奨） -->
<!-- components/layouts/Container.vue -->
<template>
  <div class="Container">
    <slot />
  </div>
</template>

<style scoped>
/* 重要: Vue SFCでは@layerを使用しない */
/* 理由: scoped属性で既に詳細度確保済み、utilityクラスに上書きされる */

/* モバイルベース */
.Container {
  display: grid;
  grid-template-columns: 1fr; /* モバイル: 1列 */
  gap: 1rem; /* 16px */
}

/* タブレット */
@media (min-width: 768px) {
  .Container {
    grid-template-columns: repeat(2, 1fr); /* 2列 */
    gap: 1.5rem; /* 24px */
  }
}

/* デスクトップ */
@media (min-width: 1024px) {
  .Container {
    grid-template-columns: repeat(3, 1fr); /* 3列 */
    gap: 2rem; /* 32px */
  }
}
</style>
```

```vue
<!-- 悪い例 - Vue SFCで@layer使用（禁止） -->
<template>
  <div class="Container flex justify-between">
    <!-- utilityクラス（flex, justify-between）がcomponentsレイヤーを上書き -->
  </div>
</template>

<style scoped>
@layer components {
  /* このスタイルはutilitiesレイヤーに負ける */
  .Container {
    display: block; /* flex に上書きされる */
    justify-content: flex-start; /* justify-between に上書きされる */
  }
}
</style>
```

```jsx
// React例（utilityクラス未使用）: components/layouts/Container.jsx
import styles from './Container.module.css';

export const Container = ({ children }) => {
  return <div className={styles.Container}>{children}</div>;
};

/* Container.module.css */
@layer components {
  .Container {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  @media (min-width: 768px) {
    .Container {
      grid-template-columns: repeat(2, 1fr);
      gap: 1.5rem;
    }
  }

  @media (min-width: 1024px) {
    .Container {
      grid-template-columns: repeat(3, 1fr);
      gap: 2rem;
    }
  }
}
```

```jsx
// React例（utilityクラス使用）: components/layouts/Container.jsx
import styles from './Container.module.css';

export const Container = ({ children }) => {
  return <div className={`${styles.Container} flex justify-between`}>{children}</div>;
};

/* Container.module.css */
/* @layerを使用しない - CSS Modulesで詳細度確保 */
.Container {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}

@media (min-width: 768px) {
  .Container {
    grid-template-columns: repeat(2, 1fr);
    gap: 1.5rem;
  }
}

@media (min-width: 1024px) {
  .Container {
    grid-template-columns: repeat(3, 1fr);
    gap: 2rem;
  }
}
```

### 4.3 Vue SFC での CSS Layers 使用禁止

**ルール**: Vue Single File Component の `<style scoped>` では `@layer` を使用しない

**理由**:

1. **scoped属性で詳細度確保済み**: Vueが自動的にユニーク属性（`[data-v-xxx]`）を追加
2. **レイヤー優先度の問題**: `@layer components` で囲むと、`utilities` レイヤーに上書きされる
   - レイヤー優先度: `components` < `utilities` < `overrides`
   - テンプレート内の `flex`, `justify-between` 等のutilityクラスが優先される
3. **BEM命名で衝突回避済み**: `ComponentName__element` 形式で既に固有性確保

**@layer使用箇所の区別**:

| ファイル種別 | @layer使用 | 理由 |
|-------------|-----------|------|
| **Vue SFC** (`components/*.vue`) | 使用禁止 | scoped属性で詳細度確保済み |
| **グローバルCSS** (`assets/styles/*.css`) | 使用必須 | レイヤー戦略による優先度管理 |
| **レガシーCSS** (`public/assets/css/*.css`) | `@layer legacy` で囲む | 段階的移行戦略 |

**グローバルCSS例**:

```css
/* assets/styles/components.css */
@layer components {
  /* グローバルコンポーネントスタイル */
  .Button.is-primary {
    background-color: var(--color-primary, #3b82f6);
    padding: 0.75rem 1.5rem;
  }
}
```

#### レイヤー別メディアクエリ管理

```css
/* assets/styles/tokens.css */
@layer tokens {
  :root {
    /* ブレークポイント参考値（JavaScript使用推奨） */
    --breakpoint-sm: 640px;  /* スマホ横向き */
    --breakpoint-md: 768px;  /* タブレット */
    --breakpoint-lg: 1024px; /* デスクトップ */
    --breakpoint-xl: 1280px; /* ワイドデスクトップ */
    --breakpoint-2xl: 1536px; /* 超ワイド */
  }
}
```

#### 禁止パターン

```css
/* 禁止 - Desktop-First（max-width） */
.Element {
  font-size: 1.125rem; /* デスクトップベース */
}

@media (max-width: 1023px) {
  .Element {
    font-size: 1rem; /* タブレット */
  }
}

@media (max-width: 767px) {
  .Element {
    font-size: 0.875rem; /* モバイル */
  }
}

/* 禁止 - グローバルCSSでレイヤー未使用（特異性混乱） */
/* グローバルCSS（assets/styles/*.css）では必ず@layer指定 */
@media (min-width: 768px) {
  .Container {
    padding: 24px; /* CSS Layers未適用 */
  }
}

/* 禁止 - utilityクラス使用プロジェクトでのコンポーネント内@layer */
/* Vue SFC / CSS Modules */
<template>
  <div class="Container flex justify-between">
    <!-- utilityクラス使用時 -->
  </div>
</template>

<style scoped>
@layer components {
  /* このスタイルはutilitiesレイヤーに上書きされる */
  .Container {
    display: block; /* flex に上書きされる */
    justify-content: flex-start; /* justify-between に上書きされる */
  }
}
</style>
```

#### 判断基準

| アプローチ | 採用条件 | 利用場面 |
|-----------|---------|---------|
| **Mobile-First + CSS Layers** | OK: 推奨 | 新規プロジェクト、モバイル利用者多数、CSS Layers導入済み |
| Desktop-First | 注意: 非推奨 | 既存サイトの段階的移行、デスクトップ優先のサービス |

### 4.3 ブレークポイント統一

**推奨ブレークポイント**:

```css
/* モバイル: デフォルト (< 768px) */
/* タブレット: 768px - 1023px */
@media (min-width: 768px) { }

/* PC: 1024px - 1439px */
@media (min-width: 1024px) { }

/* 大画面PC: 1440px以上 */
@media (min-width: 1440px) { }
```

**コンテナ最大幅**:

```css
.Container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 16px;
}

@media (min-width: 768px) {
  .Container {
    padding: 0 24px;
  }
}

@media (min-width: 1024px) {
  .Container {
    padding: 0 32px;
  }
}
```


## 5. パフォーマンス

### 5.1 トランジションプロパティ指定

**ルール**: `transition: all` 禁止、個別プロパティ指定必須

**理由**: パフォーマンス低下防止（不要なプロパティのアニメーション防止）

```css
/* 良い例 - 個別プロパティ指定 */
.Button {
  transition:
    background-color 0.15s ease,
    transform 0.15s ease;
}

/* 悪い例 - transition: all（全プロパティをアニメーション） */
.Button {
  transition: all 0.3s; /* 絶対禁止 */
}
```

**推奨トランジション時間**:
- 小要素（ボタン等）: `0.15s`
- 中要素（カード等）: `0.25s`
- 大要素（モーダル等）: `0.3s`

### 5.2 GPU加速プロパティ優先

**ルール**: レイアウト変更プロパティ（`left`, `top`, `width`）を避け、`transform` 使用

**理由**: リフロー回避、GPU加速によるスムーズなアニメーション

```css
/* 良い例 - transform（GPU加速） */
.Modal {
  transform: translateX(100%);
  transition: transform 0.3s ease;
}

.Modal.is-open {
  transform: translateX(0);
}

/* 悪い例 - left（リフロー発生） */
.Modal {
  left: 100%;
  transition: left 0.3s ease;
}

.Modal.is-open {
  left: 0;
}
```

**GPU加速プロパティ一覧**:
- `transform` (translate, scale, rotate)
- `opacity`
- `filter`

**レイアウト変更プロパティ（避ける）**:
- `left`, `top`, `right`, `bottom`
- `width`, `height`
- `margin`, `padding`

### 5.3 will-change の適切な使用

**ルール**: アニメーション開始直前に `will-change` 追加、終了後に削除

**重要**: `will-change` は通常のホバーエフェクトでは不要。複雑なアニメーション（モーダル表示等）でのみ使用。

```css
/* 良い例 - モーダルアニメーション（JavaScriptで制御） */
.Modal {
  transform: translateY(100%);
  opacity: 0;
  transition: transform 0.3s ease, opacity 0.3s ease;
}

/* アニメーション開始直前にJavaScriptで追加 */
.Modal.is-animating {
  will-change: transform, opacity;
}

/* アニメーション完了後 */
.Modal.is-open {
  transform: translateY(0);
  opacity: 1;
  will-change: auto; /* アニメーション終了後に削除 */
}

/* 悪い例 - ホバー時のwill-change（不要＆タイミングが遅い） */
.Button:hover {
  will-change: transform; /* ホバー後に設定では遅く、効果なし */
}

/* 悪い例 - 常時 will-change（メモリ消費増大） */
.Button {
  will-change: transform; /* 絶対禁止 - 全要素でメモリ確保 */
}
```

**JavaScript連携例**:

```javascript
// アニメーション開始前に will-change 設定
modal.classList.add('is-animating')

// アニメーション開始
requestAnimationFrame(() => {
  modal.classList.add('is-open')
})

// アニメーション終了後に will-change 削除
modal.addEventListener('transitionend', () => {
  modal.classList.remove('is-animating')
}, { once: true })
```

**使用判断基準**:

| アニメーション種類 | will-change 必要性 |
|-------------------|-------------------|
| ボタンホバー（transform: scale） | NG: 不要 |
| カードホバー（transform: translateY） | NG: 不要 |
| モーダル表示（transform + opacity） | OK: 推奨 |
| 無限スクロール（transform: translateY） | OK: 推奨 |
| ページ遷移アニメーション | OK: 推奨 |

### 5.4 CSS Containment によるレンダリング最適化

**ルール**: 独立したコンポーネントには `contain` プロパティ使用

**理由**: レンダリング範囲の最適化、再計算コスト削減

```css
/* 良い例 - カード要素の独立性を宣言 */
.ProductCard {
  contain: layout style paint;
}

/* 良い例 - モーダルの完全な独立 */
.Modal {
  contain: strict;
}

/* 良い例 - 大量リスト項目の最適化 */
.ListItem {
  contain: layout paint;
}
```

**使用判断基準**:

| `contain`値 | 効果 | 使用場面 |
|------------|------|---------|
| `layout` | レイアウト計算を内部に限定 | カード、リスト項目 |
| `paint` | 描画範囲を限定 | 独立したコンポーネント |
| `size` | サイズ計算を独立 | 固定サイズ要素 |
| `strict` | `layout size paint` 全て適用 | モーダル、オーバーレイ |

**注意**: `contain: size` は要素の内在サイズを無視するため、明示的なサイズ指定が必要

### 5.5 Critical CSS 戦略

**ルール**: ファーストビューのCSSを優先読み込み

**理由**: 初期表示パフォーマンス向上、First Contentful Paint (FCP) 改善

**実装方法**:

```html
<!DOCTYPE html>
<html>
<head>
  <!-- 良い例 - Critical CSSインライン化 -->
  <style>
    /* ファーストビューのみのCSS（約14KB以下推奨） */
    .Header { /* ... */ }
    .Hero { /* ... */ }
    .MainNav { /* ... */ }
  </style>

  <!-- 非Critical CSSは非同期読み込み -->
  <link rel="preload" href="/css/non-critical.css" as="style" onload="this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/css/non-critical.css"></noscript>
</head>
<body>
  <!-- コンテンツ -->
</body>
</html>
```

**ツール支援**:
- **Critical**: https://github.com/addyosmani/critical
- **Critters**: https://github.com/GoogleChromeLabs/critters (Webpack/Viteプラグイン)

**手順**:
1. **Critical CSS抽出**: ツールでファーストビュー CSS を自動抽出
2. **インライン化**: `<style>`タグでHTMLに埋め込み（約14KB以下推奨）
3. **非Critical CSS遅延読み込み**: `preload` + `onload`で非同期化

```bash
# Critical CLI使用例
npx critical index.html --base . --inline --minify > index-critical.html
```


## 6. 命名規則

### 6.1 命名パターンの優先順位

| 優先度 | パターン | 形式 | 例 | 用途 |
|-------|---------|------|---|------|
| **1** | コンポーネントルート | PascalCase | `ProductCard` | コンポーネントルート |
| **2** | コンポーネント子要素 | PascalCase__camelCase | `ProductCard__image` | コンポーネント内要素 |
| **3** | 状態クラス | is-kebab-case | `is-active`, `is-disabled` | 状態表現 |
| **4** | 条件クラス | has-kebab-case | `has-icon`, `has-image` | 要素の有無 |
| **5** | ユーティリティ | u-kebab-case | `u-pc-only`, `u-sp-only` | 汎用ヘルパー |

### 6.2 状態クラス（is- Prefix）

**ルール**: 要素の状態を表す場合は `is-` を使用

```css
/* 良い例 - 状態クラス */
.Button.is-active { }
.Button.is-disabled { }
.Button.is-loading { }
.Modal.is-open { }
.Modal.is-closing { }
.Nav.is-sticky { }
.Accordion.is-expanded { }

/* 悪い例 - Prefix なし */
.Button.active { } /* 非推奨 */
.Button.disabled { } /* 非推奨 */
```

**状態クラス一覧**:

| クラス名 | 用途 | 使用例 |
|---------|-----|-------|
| `is-active` | アクティブ状態 | ナビゲーション選択項目、タブ |
| `is-disabled` | 無効状態 | 入力不可ボタン、フォーム項目 |
| `is-loading` | ローディング中 | データ取得中ボタン |
| `is-open` | 開いている状態 | モーダル、ドロップダウン |
| `is-closed` | 閉じている状態 | アコーディオン |
| `is-visible` | 表示状態 | トースト通知 |
| `is-hidden` | 非表示状態 | 折りたたみコンテンツ |
| `is-selected` | 選択状態 | チェックボックス、リスト項目 |
| `is-error` | エラー状態 | バリデーションエラー |
| `is-success` | 成功状態 | 送信完了メッセージ |
| `is-animating` | アニメーション中 | トランジション実行中 |

### 6.3 条件クラス（has- Prefix）

**ルール**: 子要素の有無、特定条件の保持を表す場合は `has-` を使用

```css
/* 良い例 - 条件クラス */
.Card.has-image { }
.Card.has-footer { }
.List.has-children { }
.Article.has-sidebar { }
.Button.has-icon { }

/* 悪い例 - Prefix なし */
.Card.with-image { } /* 非推奨 */
.Card.image { } /* 非推奨 */
```

**条件クラス一覧**:

| クラス名 | 用途 | 使用例 |
|---------|-----|-------|
| `has-image` | 画像を持つ | カード、記事 |
| `has-icon` | アイコンを持つ | ボタン、リンク |
| `has-footer` | フッターを持つ | カード |
| `has-sidebar` | サイドバーを持つ | レイアウト |
| `has-children` | 子要素を持つ | ナビゲーション |
| `has-badge` | バッジを持つ | 通知アイコン |
| `has-tooltip` | ツールチップを持つ | インフォアイコン |
| `has-error` | エラーを持つ | フォーム |

### 6.4 ユーティリティクラス（u- Prefix）

**ルール**: 汎用的なヘルパークラスは `u-` を使用

```css
/* 良い例 - ユーティリティクラス */
.u-pc-only { display: block; }
.u-sp-only { display: none; }
.u-tablet-only { display: none; }
.u-text-center { text-align: center; }
.u-mt-16 { margin-top: 1rem; }
.u-visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
}

@media (max-width: 767px) {
  .u-pc-only { display: none; }
  .u-sp-only { display: block; }
}

@media (min-width: 768px) and (max-width: 1023px) {
  .u-tablet-only { display: block; }
}
```

**ユーティリティクラス一覧**:

| カテゴリ | クラス名 | 用途 |
|---------|---------|-----|
| **レスポンシブ** | `u-pc-only` | PC表示のみ（768px以上） |
| | `u-sp-only` | スマホ表示のみ（767px以下） |
| | `u-tablet-only` | タブレット表示のみ（768px-1023px） |
| **テキスト** | `u-text-center` | 中央揃え |
| | `u-text-left` | 左揃え |
| | `u-text-right` | 右揃え |
| **スペーシング** | `u-mt-{size}` | マージントップ |
| | `u-mb-{size}` | マージンボトム |
| | `u-p-{size}` | パディング |
| **アクセシビリティ** | `u-visually-hidden` | スクリーンリーダー用（視覚的非表示） |

**スペーシングサイズ**:
- `u-mt-4` → `margin-top: 0.25rem` (4px)
- `u-mt-8` → `margin-top: 0.5rem` (8px)
- `u-mt-16` → `margin-top: 1rem` (16px)
- `u-mt-24` → `margin-top: 1.5rem` (24px)
- `u-mt-32` → `margin-top: 2rem` (32px)

### 6.5 複合クラスの使用例

```html
<!-- 良い例 - 複数クラスの組み合わせ -->
<div class="ProductCard is-active has-image u-pc-only">
  <img class="ProductCard__image" />
  <div class="ProductCard__content">
    <h3 class="ProductCard__title"></h3>
  </div>
</div>

<button class="primaryButton is-loading is-disabled">
  送信中...
</button>

<nav class="headerNavigation is-sticky">
  <a class="headerNavigation__link is-active">ホーム</a>
  <a class="headerNavigation__link">セミナー</a>
</nav>
```

### 6.6 禁止パターン

#### BEM Modifier（--）

```css
/* 禁止 - BEM形式 */
.Card__title { } /* Block__Element */
.Card--large { } /* Block--Modifier */
.Card__title--bold { } /* Block__Element--Modifier */

/* OK: 代替案 */
.Card__title { } /* Vueコンポーネント形式 */
.Card.is-large { } /* 状態クラス */
.Card__title.is-bold { } /* 状態クラス併用 */
```

#### snake_case

```css
/* 禁止 - snake_case */
.hero_section { }
.primary_button { }

/* OK: 代替案 */
.HeroSection { }
.PrimaryButton { }
```

#### ID セレクタ

```css
/* 禁止 - ID セレクタ */
#header { }
#main-content { }

/* OK: 代替案 */
.Header { }
.MainContent { }
```

**例外**: JavaScriptのアンカーリンク（`<a href="#section1">`）のみ許可


## 7. wrapper / container 判定フロー

**ルール**: セクション全体 = wrapper、コンテンツ幅制限 = container

**判定アルゴリズム**:
```
IF 背景色 OR 全幅padding OR セクション境界 THEN
    クラス = *-wrapper
    CSS = background-color, padding, width: 100%
ELSE IF コンテンツ最大幅制限 OR 中央配置 THEN
    クラス = container
    CSS = max-width, margin: 0 auto, padding
ELSE IF 特定コンポーネント専用 THEN
    クラス = *-container
```

**構造パターン**:
```html
<!-- OK: wrapper → container 入れ子 -->
<section class="section-wrapper">
  <div class="container">content</div>
</section>

<!-- NG: 逆転・二重ラップ禁止 -->
<div class="container"><div class="wrapper">...</div></div>
<div class="wrapper"><div class="inner-wrapper"><div class="container">...</div></div></div>
```

**CSS実装**:
```css
@layer components {
  .SectionWrapper {
    background-color: var(--v2-Background); padding: 3rem 0; width: 100%;
  }
  .Container {
    max-width: 75rem; margin: 0 auto; padding: 0 1rem;
  }
}

/* レスポンシブ: wrapper = padding調整、container = max-width調整 */
@media (min-width: 48rem) {
  .SectionWrapper { padding: 4rem 0; }
  .Container { max-width: 45rem; }
}
@media (min-width: 64rem) { .Container { max-width: 60rem; } }
@media (min-width: 80rem) { .Container { max-width: 75rem; } }
```


## 8. z-index 管理

### 8.1 標準化された階層定義

**ルール**: `z-index` は定義済みCSS変数のみ使用

**理由**: z-index競合防止、保守性向上

```css
/* 推奨 z-index 定義例 */
:root {
  --z-index-base: 0;
  --z-index-dropdown: 1000;
  --z-index-sticky: 1100;
  --z-index-modal-backdrop: 2000;
  --z-index-modal: 2100;
  --z-index-notification: 3000;
  --z-index-tooltip: 4000;
}

/* 良い例 - CSS変数使用 */
.Modal {
  z-index: var(--z-index-modal);
}

.ModalBackdrop {
  z-index: var(--z-index-modal-backdrop);
}

/* 悪い例 - ランダムな値 */
.Modal {
  z-index: 9999; /* 絶対禁止 */
}
```

**階層ルール**:
- **0-99**: 通常要素
- **1000-1999**: ドロップダウン、スティッキー要素
- **2000-2999**: モーダル、オーバーレイ
- **3000-3999**: 通知、トースト
- **4000-4999**: ツールチップ、ポップオーバー


## 9. 単位統一

### 9.1 rem 推奨、px 非推奨

**ルール**: フォントサイズ・スペーシングは `rem` 使用（`px` は例外のみ）

**理由**: ユーザーのブラウザ設定（文字サイズ拡大）を尊重、アクセシビリティ向上

#### 単位選択の判断フロー（決定木）

**IF-THEN-ELSE形式の判断基準**:

```
IF 対象 == "フォントサイズ" OR "スペーシング（margin/padding）" THEN
    単位 = rem
ELSE IF 対象 == "ボーダー幅" AND 値 <= 3px THEN
    単位 = px  # 例外: 1px, 2px, 3px（1px未満は描画不可）
ELSE IF 対象 == "装飾的アイコン" AND サイズ固定 AND レイアウトに影響なし THEN
    単位 = px  # 例外: 16px, 24px, 32px, 48px, 64px（固定サイズ）
ELSE IF 対象 == "box-shadow" OR "outline-offset" OR "border-radius（装飾）" THEN
    単位 = px  # 例外: 装飾的要素、ユーザー設定の影響不要
ELSE
    単位 = rem  # デフォルト（迷ったらrem）
```

**判断例（具体的ケーススタディ）**:

| ケース | 単位 | 理由 | 具体例 |
|-------|-----|------|-------|
| フォントサイズ | **rem** | ユーザーのブラウザ設定尊重 | `font-size: 1rem` |
| padding, margin | **rem** | ユーザーのブラウザ設定尊重 | `padding: 1.5rem` |
| ボーダー幅 | **px** | 1px未満は描画不可、固定値適切 | `border: 1px solid` |
| 装飾アイコン（固定） | **px** | レイアウトに影響なし、サイズ固定 | `.icon { width: 24px; }` |
| UI要素アイコン | **rem** | ユーザー設定に連動すべき | `.button-icon { width: 1.5rem; }` |
| box-shadow | **px** | 装飾的要素、固定値適切 | `box-shadow: 0 2px 4px rgba(0,0,0,0.1)` |
| outline-offset | **px** | フォーカス表示の装飾、固定値 | `outline-offset: 2px` |
| border-radius（UI） | **rem** | ボタン等のUIは相対サイズ適切 | `border-radius: 0.25rem` |
| border-radius（装飾） | **px** | 円形アイコン等は固定値 | `border-radius: 50%` or `12px` |

**迷った場合の判断基準**:

| 質問 | YES → rem | NO → px |
|-----|-----------|---------|
| ユーザーがフォントサイズを変更した時、この要素もサイズ変更すべき？ | OK: | NG: |
| この要素はテキストと密接に関連している？ | OK: | NG: |
| レイアウトに影響を与える要素？ | OK: | NG: |
| 純粋に装飾的な要素？ | NG: | OK: |

```css
/* 良い例 - rem使用 */
.Text {
  font-size: 1rem; /* 16px（ブラウザデフォルト） */
  padding: 1.5rem; /* 24px */
  margin-bottom: 2rem; /* 32px */
}

/* 悪い例 - px固定（ユーザー設定無視） */
.Text {
  font-size: 16px; /* 非推奨 */
  padding: 24px; /* 非推奨 */
}

/* OK: 例外 - px許可パターン */

/* 1. ボーダー幅（1px, 2px, 3px） */
.Card {
  border: 1px solid var(--border-color);
  outline: 2px solid var(--color-primary, #3b82f6);
}

/* 2. 装飾的アイコン（16px, 24px, 32px, 48px, 64px固定サイズ） */
.Icon.is-decorative {
  width: 24px;
  height: 24px;
  flex-shrink: 0; /* サイズ固定を明示 */
}

/* 3. レイアウトに影響しない装飾要素 */
.Card {
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* 注意: UI要素のサイズはremを使用（ユーザー設定尊重） */
.Button__icon {
  width: 1.5rem; /* 24px相当、ユーザーのフォントサイズに連動 */
  height: 1.5rem;
}
```

**rem 換算表**:
- `0.75rem` = 12px
- `0.875rem` = 14px
- `1rem` = 16px（デフォルト）
- `1.125rem` = 18px
- `1.25rem` = 20px
- `1.5rem` = 24px
- `2rem` = 32px

### 9.2 line-height の単位なし推奨

**ルール**: `line-height` は単位なし数値使用

```css
/* 良い例 - 単位なし（フォントサイズの倍率） */
.Text {
  font-size: 1rem;
  line-height: 1.5; /* 1rem × 1.5 = 1.5rem */
}

/* 悪い例 - 単位付き（継承時に問題） */
.Text {
  font-size: 1rem;
  line-height: 24px; /* 子要素で固定されてしまう */
}
```


## 9. 禁止パターン

### 9.1 !important の使用制限

**ルール**: `!important` は最終手段（外部ライブラリ上書きのみ許可）

```css
/* OK: 例外 - 外部ライブラリ上書き */
.swiper-button-next {
  color: var(--color-primary, #3b82f6) !important; /* Swiperデフォルトスタイル上書き */
}

/* 悪い例 - 通常スタイルで使用 */
.Button {
  background-color: var(--color-primary, #8b5cf6) !important; /* 禁止 */
}
```

**代替案**: 詳細度を上げる

```css
/* 良い例 - 詳細度で解決 */
.Modal .Button {
  background-color: var(--color-primary, #8b5cf6);
}
```

### 9.2 固定幅・高さの制限

**ルール**: `width`, `height` は固定値を避け、`max-width`, `min-height` 使用

```css
/* 良い例 - 柔軟なサイズ */
.Card {
  max-width: 400px;
  min-height: 200px;
  width: 100%;
}

/* 悪い例 - 固定サイズ（レスポンシブ対応不可） */
.Card {
  width: 400px;
  height: 200px;
}
```

### 9.3 CSS変数の動的生成時のバリデーション

**ルール**: ユーザー入力からCSS変数を生成する場合は必ずバリデーション実施

**理由**: CSS Injection脆弱性の防止

```javascript
/* NG: 危険 - ユーザー入力をそのまま使用（CSS Injection の可能性） */
const userColor = getUserInput() // 例: "red; background: url(evil.com)"
element.style.setProperty('--user-color', userColor)

/* OK: 安全 - ホワイトリスト検証 */
const ALLOWED_COLORS = ['#3b82f6', '#64748b', '#8b5cf6', '#28a745', '#dc3545']
const userColor = getUserInput()

if (ALLOWED_COLORS.includes(userColor)) {
  element.style.setProperty('--user-color', userColor)
} else {
  // デフォルト値を使用
  element.style.setProperty('--user-color', '#3b82f6')
}

/* OK: 安全 - 正規表現検証（16進数カラーコードのみ許可） */
const userColor = getUserInput()
const isValidHex = /^#[0-9A-Fa-f]{6}$/.test(userColor)

if (isValidHex) {
  element.style.setProperty('--user-color', userColor)
}
```

**検証方法**:
1. **ホワイトリスト方式**: 許可された値のリストで検証（最も安全）
2. **正規表現方式**: 想定される形式のみ許可
3. **サニタイズ**: DOMPurifyなどのライブラリ使用

#### Vue/React対応のCSS Injection対策

**Vue例**:

```vue
<!-- NG: 危険 - ユーザー入力を直接使用（CSS Injection の可能性） -->
<script setup>
const userInput = ref('#ff0000; background: url(evil.com)');
</script>
<template>
  <div :style="{ '--user-color': userInput }"></div>
</template>

<!-- OK: 安全 - ホワイトリスト検証 -->
<script setup>
const ALLOWED_COLORS = ['#3b82f6', '#64748b', '#8b5cf6', '#28a745', '#dc3545'];
const userInput = ref('#3b82f6');

const validatedColor = computed(() =>
  ALLOWED_COLORS.includes(userInput.value) ? userInput.value : '#3b82f6'
);
</script>
<template>
  <div :style="{ '--user-color': validatedColor }"></div>
</template>

<!-- OK: 安全 - 正規表現検証（16進数カラーコードのみ） -->
<script setup>
const userInput = ref('#3b82f6');

const validatedColor = computed(() => {
  const isValidHex = /^#[0-9A-Fa-f]{6}$/.test(userInput.value);
  return isValidHex ? userInput.value : '#3b82f6';
});
</script>
<template>
  <div :style="{ '--user-color': validatedColor }"></div>
</template>
```

**React例**:

```tsx
// NG: 危険 - ユーザー入力を直接使用
function BadComponent({ userInput }: { userInput: string }) {
  return (
    <div style={{ '--user-color': userInput } as React.CSSProperties}></div>
  );
}

// OK: 安全 - ホワイトリスト検証
const ALLOWED_COLORS = ['#3b82f6', '#64748b', '#8b5cf6', '#28a745', '#dc3545'];

function SafeComponent({ userInput }: { userInput: string }) {
  const validatedColor = ALLOWED_COLORS.includes(userInput)
    ? userInput
    : '#3b82f6';

  return (
    <div style={{ '--user-color': validatedColor } as React.CSSProperties}></div>
  );
}

// OK: 安全 - 正規表現検証（16進数カラーコードのみ）
function SafeRegexComponent({ userInput }: { userInput: string }) {
  const isValidHex = /^#[0-9A-Fa-f]{6}$/.test(userInput);
  const validatedColor = isValidHex ? userInput : '#3b82f6';

  return (
    <div style={{ '--user-color': validatedColor } as React.CSSProperties}></div>
  );
}
```

**検証ロジックの共通化**（推奨）:

```typescript
// utils/css-validator.ts
export const ALLOWED_COLORS = [
  '#3b82f6', '#64748b', '#8b5cf6',
  '#28a745', '#dc3545', '#ffc107', '#17a2b8'
] as const;

export function validateCSSColor(input: string): string {
  // 1. ホワイトリスト検証
  if (ALLOWED_COLORS.includes(input as any)) {
    return input;
  }

  // 2. 正規表現検証（16進数カラーコード）
  const isValidHex = /^#[0-9A-Fa-f]{6}$/.test(input);
  if (isValidHex) {
    return input;
  }

  // 3. デフォルト値を返す
  return '#3b82f6';
}

// 使用例（Vue）
const validatedColor = computed(() => validateCSSColor(userInput.value));

// 使用例（React）
const validatedColor = validateCSSColor(userInput);
```

### 9.4 よくある誤り（アンチパターン集）

**目的**: 頻出するCSS実装ミスを事前に防止

**アンチパターン一覧表**:

| アンチパターン | 頻出度 | 影響 | 正しい実装 | 参照セクション |
|--------------|-------|-----|-----------|--------------|
| **`will-change` 常時設定** | 高 | メモリ消費増大 | JS動的追加・削除 | 5.3節 |
| **`transition: all` 使用** | 高 | パフォーマンス低下 | 個別プロパティ指定 | 5.1節 |
| **`:hover` タッチデバイス未対応** | 中 | UI残留バグ | `@media (any-hover: hover)` | 1章 |
| **`outline: none` 使用** | 中 | アクセシビリティ違反 | `:focus-visible` 代替 | 2.1節 |
| **px固定フォントサイズ** | 中 | ユーザー設定無視 | rem単位使用 | 8.1節 |
| **`!important` 乱用** | 中 | 保守性低下 | 詳細度で解決 | 9.1節 |
| **固定幅・高さ** | 低 | レスポンシブ対応不可 | max-width, min-height | 9.2節 |
| **CSS変数フォールバックなし** | 低 | 描画崩れリスク | `var(--x, fallback)` | 3.1節 |

#### 具体的なアンチパターンと修正例

**パターン1: `will-change` 常時設定**

```css
/* NG: アンチパターン - メモリ消費増大 */
.Button {
  will-change: transform; /* 常時メモリ確保 */
}

/* OK: 正しい実装 - JS動的制御 */
.Button.is-animating {
  will-change: transform;
}

/* JavaScript */
// アニメーション開始前
modal.classList.add('is-animating');

// アニメーション終了後
modal.addEventListener('transitionend', () => {
  modal.classList.remove('is-animating');
}, { once: true });
```

**パターン2: `transition: all` 使用**

```css
/* NG: アンチパターン - 全プロパティをアニメーション */
.Card {
  transition: all 0.3s; /* パフォーマンス低下 */
}

/* OK: 正しい実装 - 個別プロパティ指定 */
.Card {
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}
```

**パターン3: `:hover` タッチデバイス未対応**

```css
/* NG: アンチパターン - タッチデバイスでホバー状態が残る */
.Button:hover {
  background-color: var(--primary, #3b82f6);
}

/* OK: 正しい実装 - any-hover メディアクエリ */
@media (any-hover: hover) {
  .Button:hover {
    background-color: var(--primary, #3b82f6);
  }
}
```

**パターン4: `outline: none` 使用**

```css
/* NG: アンチパターン - アクセシビリティ違反 */
.Button:focus {
  outline: none; /* 絶対禁止 */
}

/* OK: 正しい実装 - :focus-visible 使用 */
.Button:focus-visible {
  outline: 2px solid var(--primary, #3b82f6);
  outline-offset: 2px;
}
```

**パターン5: px固定フォントサイズ**

```css
/* NG: アンチパターン - ユーザー設定無視 */
.Text {
  font-size: 16px;
  padding: 24px;
}

/* OK: 正しい実装 - rem単位使用 */
.Text {
  font-size: 1rem; /* 16px相当、ユーザー設定に連動 */
  padding: 1.5rem; /* 24px相当 */
}
```

**パターン6: `!important` 乱用**

```css
/* NG: アンチパターン - 保守性低下 */
.Button {
  background-color: var(--primary, #8b5cf6) !important;
}

/* OK: 正しい実装 - 詳細度で解決 */
.Modal .Button {
  background-color: var(--primary, #8b5cf6);
}
```

**パターン7: 固定幅・高さ**

```css
/* NG: アンチパターン - レスポンシブ対応不可 */
.Card {
  width: 400px;
  height: 200px;
}

/* OK: 正しい実装 - 柔軟なサイズ */
.Card {
  max-width: 400px;
  min-height: 200px;
  width: 100%;
}
```

**パターン8: CSS変数フォールバックなし**

```css
/* NG: アンチパターン - CSS変数未定義時に描画崩れ */
.Button {
  color: var(--primary);
}

/* OK: 正しい実装 - フォールバック値付き */
.Button {
  color: var(--primary, #3b82f6);
}
```

#### デバッグ時のチェックリスト

実装後、以下の項目を確認:

- `will-change` は `.is-animating` クラスで動的制御しているか？（常時設定禁止）
- `transition: all` を使用していないか？（個別プロパティ指定必須）
- `:hover` は `@media (any-hover: hover)` で囲んでいるか？（タッチデバイス対応）
- `outline: none` を使用せず、`:focus-visible` を定義しているか？（アクセシビリティ）
- フォントサイズ・スペーシングは `rem` 単位か？（ユーザー設定尊重）
- `!important` を乱用していないか？（外部ライブラリ上書き以外禁止）
- 固定幅・高さを使用せず、`max-width`, `min-height` を使用しているか？
- CSS変数にフォールバック値を付けているか？（`var(--x, fallback)`）


## 10. 検証フロー

### 10.1 Stylelint 設定

**推奨設定例**: `.stylelintrc.json`

```json
{
  "extends": "stylelint-config-standard",
  "rules": {
    "declaration-no-important": [true, { "severity": "warning" }],
    "selector-max-id": 0,
    "unit-allowed-list": ["rem", "em", "%", "vh", "vw", "vmin", "vmax", "px", "deg", "s", "ms"],
    "selector-class-pattern": "^[a-z][a-zA-Z0-9]*$|^is-[a-z][a-zA-Z0-9-]*$|^has-[a-z][a-zA-Z0-9-]*$|^u-[a-z][a-zA-Z0-9-]*$"
  }
}
```

**主要ルール解説**:
- `declaration-no-important`: `!important` 使用を警告
- `selector-max-id`: IDセレクタ禁止
- `unit-allowed-list`: 許可する単位のホワイトリスト
- `selector-class-pattern`: クラス名パターン（PascalCase, is-, has-, u- 許可）

### 10.2 自動フォーマッター（Prettier）

**推奨設定例**: `.prettierrc`

```json
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

**VSCode統合例**: `.vscode/settings.json`

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[vue]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}
```

### 10.3 コミット前チェックリスト

**必須チェック項目**:

- CSS リンター（Stylelint等）でエラー0件
- フォーマッター（Prettier等）でフォーマット統一
- `:hover` は `@media (any-hover: hover)` で囲んでいる
- インタラクティブ要素に `:focus-visible` スタイル定義済み
- カラー・スペーシングはCSS変数使用（フォールバック値付き）
- `transition: all` 使用なし（個別プロパティ指定）
- `!important` 使用なし（外部ライブラリ上書き以外）
- `outline: none` 使用なし（アクセシビリティ違反）
- フォント・スペーシングは `rem` 単位使用
- `z-index` はCSS変数使用
- `prefers-reduced-motion` 対応（アニメーション削減）

**推奨チェック項目**:

- WCAGコントラスト比チェック（Chrome DevTools Lighthouse）
- GPU加速プロパティ使用（`transform`, `opacity`）
- レスポンシブ対応確認（モバイル・タブレット・PC）
- ブラウザ互換性確認（Safari, Chrome, Firefox）


## 11. 外部リソースのセキュリティ

### 11.1 Subresource Integrity (SRI) の使用

**ルール**: CDNから読み込むCSS/フォントにはSRIハッシュを必ず付与

**理由**: CDN侵害時のコード改ざん防止

```html
<!-- 良い例 - SRIハッシュで検証 -->
<link
  href="https://fonts.googleapis.com/css2?family=Roboto&display=swap"
  rel="stylesheet"
  integrity="sha384-oS3vJWv+0UjzBfQzYUhtDYW+Pj2yciDJxpsK1OYPAYjqT085Qq/1cq5FLXAZQ7Ay"
  crossorigin="anonymous"
>

<!-- 悪い例 - SRIなし（CDN改ざんリスク） -->
<link
  href="https://fonts.googleapis.com/css2?family=Roboto&display=swap"
  rel="stylesheet"
>
```

**SRIハッシュ生成方法**:
```bash
# OK: 推奨 - エラーハンドリング付き
curl -f -s https://example.com/style.css > /tmp/style.css && \
openssl dgst -sha384 -binary /tmp/style.css | openssl base64 -A

# エラー時は終了コード確認
if [ $? -ne 0 ]; then
  echo "ERROR: SRI hash generation failed (curl failed or file not found)"
  exit 1
fi

# NG: 非推奨 - エラーハンドリングなし（ネットワークエラー時に無効なハッシュ生成）
# curl https://example.com/style.css | openssl dgst -sha384 -binary | openssl base64 -A
```

**オンラインツール（推奨）**: [SRI Hash Generator](https://www.srihash.org/)

### 11.2 Content Security Policy (CSP) 設定

**ルール**: `style-src`ディレクティブで外部リソースを制限

```html
<!-- HTTPヘッダーで設定（推奨） -->
Content-Security-Policy:
  style-src 'self' https://fonts.googleapis.com;
  font-src 'self' https://fonts.gstatic.com;
```

```html
<!-- meta タグで設定（代替） -->
<meta http-equiv="Content-Security-Policy"
      content="style-src 'self' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com;">
```

**段階的な強化**:
1. **開発環境**: `style-src 'unsafe-inline'` 許可（デバッグ用）
2. **ステージング**: インラインスタイルをCSS変数に移行
3. **本番環境**: `'unsafe-inline'` 削除、厳格なCSP適用

#### Vue/React Scoped CSS対応のCSP設定

**問題**: `style-src 'self'` のみではVue/ReactのScoped CSSが動作しない

**解決策**: nonce生成によるインラインスタイル許可

**推奨CSP設定**:

```http
# OK: Vue/React Scoped CSS対応（nonce使用）
Content-Security-Policy:
  default-src 'self';
  style-src 'self' 'nonce-{random}';
  script-src 'self' 'nonce-{random}';
  font-src 'self' https://fonts.gstatic.com;
  img-src 'self' data: https:;
```

**nonce生成例（Next.js middleware）**:

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import crypto from 'crypto';

export function middleware(request: NextRequest) {
  // ランダムなnonce生成
  const nonce = crypto.randomBytes(16).toString('base64');

  // CSPヘッダー構築
  const cspHeader = `
    default-src 'self';
    style-src 'self' 'nonce-${nonce}';
    script-src 'self' 'nonce-${nonce}';
    font-src 'self' https://fonts.gstatic.com;
    img-src 'self' data: https:;
  `.replace(/\s{2,}/g, ' ').trim();

  const response = NextResponse.next();
  response.headers.set('Content-Security-Policy', cspHeader);
  response.headers.set('X-Nonce', nonce); // nonceをページに渡す

  return response;
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - api (API routes)
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     */
    '/((?!api|_next/static|_next/image|favicon.ico).*)',
  ],
};
```

**Nuxt 3でのnonce生成例**:

```typescript
// server/middleware/csp.ts
export default defineEventHandler((event) => {
  // ランダムなnonce生成
  const nonce = Buffer.from(crypto.randomBytes(16)).toString('base64');

  // CSPヘッダー設定
  setHeader(
    event,
    'Content-Security-Policy',
    `default-src 'self'; style-src 'self' 'nonce-${nonce}'; script-src 'self' 'nonce-${nonce}';`
  );

  // nonceをコンテキストに保存
  event.context.nonce = nonce;
});
```

**HTMLでのnonce使用**:

```html
<!-- nonceをインラインスタイルに適用 -->
<style nonce="{{ nonce }}">
  .ScopedClass {
    color: red;
  }
</style>

<script nonce="{{ nonce }}">
  console.log('Script with nonce');
</script>
```

**注意事項**:
- nonceは**リクエストごとに生成**（再利用禁止）
- nonceは**予測不可能**な値（crypto.randomBytes使用）
- nonceは**サーバーサイドのみ**で生成（クライアントサイドNG）

### 11.3 Web Fonts の安全な読み込み

**推奨パターン**:

```html
<!-- 良い例 - セルフホスティング（最も安全） -->
<link rel="preload" href="/fonts/Roboto-Regular.woff2" as="font" type="font/woff2" crossorigin>

<style>
@font-face {
  font-family: 'Roboto';
  src: url('/fonts/Roboto-Regular.woff2') format('woff2');
  font-display: swap;
}
</style>

<!-- 良い例 - Google Fonts（SRI付き） -->
<link
  href="https://fonts.googleapis.com/css2?family=Roboto&display=swap"
  rel="stylesheet"
  integrity="sha384-..."
  crossorigin="anonymous"
>
```

**font-display 設定**:
```css
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: swap; /* FOIT（invisible text）回避 */
}
```

#### font-displayのセキュリティ影響

**問題**: `font-display: swap` は Cumulative Layout Shift (CLS) を引き起こす可能性があり、意図的なフォント遅延でフィッシングサイト構築に悪用されるリスクがあります。

**リスクシナリオ**:
1. 攻撃者が遅延したWebフォントを読み込む
2. フォールバックフォント（Arial等）で初期表示
3. Webフォント読み込み完了時にレイアウトシフト発生
4. ユーザーが意図しないリンクをクリック（Layout Shift攻撃）

**CLS軽減策（size-adjust）**:

```css
/* OK: 推奨 - フォールバックフォントのサイズ調整でCLS軽減 */
@font-face {
  font-family: 'Inter Fallback';
  src: local('Arial');
  size-adjust: 107%; /* Inter と Arial のサイズ差を補正 */
  ascent-override: 90%;
  descent-override: 22%;
  line-gap-override: 0%;
}

@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter-var.woff2') format('woff2');
  font-display: swap;
}

body {
  font-family: 'Inter', 'Inter Fallback', Arial, sans-serif;
}
```

**size-adjust計算方法**:

```
size-adjust = (Webフォントの x-height) / (フォールバックフォントの x-height) × 100%

例（Inter vs Arial）:
- Inter x-height: 536
- Arial x-height: 500
- size-adjust = 536 / 500 × 100% = 107.2% → 107%
```

**size-adjust計算ツール**:
- **Fallback Font Generator**: https://screenspan.net/fallback
- **Font Size Adjust Calculator**: https://deploy-preview-15--upbeat-shirley-608546.netlify.app/

**効果測定**:
- CLS スコア改善: 0.25 → 0.05（80%削減）
- Layout Shift攻撃リスク軽減: フォント切替時のレイアウト変動最小化

**注意事項**:
- `size-adjust` はChrome 92+, Firefox 89+でサポート
- 未サポートブラウザではフォールバック動作（影響なし）
- プロジェクトで使用するフォント全てに適用推奨

### 11.4 セキュリティ検証フロー（実装前必須）

**目的**: CSS実装時のセキュリティチェックを標準化し、脆弱性を事前に防止

#### 実装前チェックリスト

**CSS変数の動的生成**:
- ユーザー入力からCSS変数を生成する場合、ホワイトリスト検証実装済み（9.3節）
- Vue: `v-bind(css)` でユーザー入力を直接使用していない
- React: `style={{ '--var': userInput }}` でユーザー入力を直接使用していない
- 検証ロジックを共通化し、再利用可能な関数として定義（9.3節参照）

**外部リソースの読み込み**:
- CDNからのCSS読込にSRIハッシュ付与済み（11.1節）
- Web FontsにSRIハッシュ付与 or セルフホスティング（11.3節）
- 外部リソースのドメインをCSPで制限（11.2節）
- 外部リソースは HTTPS のみ使用（HTTP 禁止）

**CSP設定**:
- `'unsafe-inline'` を使用していない
- nonce生成を実装済み（サーバーサイド必須、11.2節参照）
- Vue/React Scoped CSS対応のCSP設定（11.2節）
- CSPヘッダーはHTTPヘッダーで設定（meta タグではセキュリティ低下）

**その他**:
- `:has()` セレクタでユーザー入力を属性値に使用していない
- `@import` で外部CSSを読み込む場合、SRI付与
- `font-display: swap` 使用時、size-adjust でCLS軽減（11.3節）

#### コードレビュー時の確認項目

**Grep検索で検出（自動化推奨）**:

```bash
# 1. CSS Injection リスクパターン検索
rg "v-bind.*userInput|:style.*userInput" --type vue
rg "style=\{\{.*userInput" --type tsx

# 2. SRIハッシュ未付与の外部リソース検索
rg "<link.*https://.*rel=\"stylesheet\"" --type html | rg -v "integrity="
rg "@import url\(.*https://" --type css | rg -v "integrity="

# 3. 危険なCSP設定検索
rg "unsafe-inline|unsafe-eval" nuxt.config.ts next.config.js

# 4. outline削除の検出（アクセシビリティ違反）
rg "outline:\s*none" --type css --type vue

# 5. transition: all 使用検出（パフォーマンス問題）
rg "transition:\s*all" --type css --type vue
```

#### 修正優先度

**P0（即修正必須）**:
- CSS Injection（ユーザー入力の検証なし）
- `'unsafe-inline'` 使用（CSP無効化）
- `outline: none` 使用（アクセシビリティ違反）

**P1（修正推奨）**:
- SRIハッシュ未付与（CDN改ざんリスク）
- CSP未設定（XSS攻撃リスク）
- nonce未実装（Vue/React Scoped CSS動作不可）

**P2（リファクタリング時対応）**:
- font-display最適化（size-adjust未設定）
- HTTP外部リソース（HTTPS移行推奨）
- transition: all 使用（パフォーマンス低下）

#### CI/CD統合例

**GitHub Actions**:

```yaml
name: CSS Security Check

on: [push, pull_request]

jobs:
  security-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Check CSS Injection patterns
        run: |
          rg "v-bind.*userInput|:style.*userInput" --type vue && exit 1 || true
          rg "style=\{\{.*userInput" --type tsx && exit 1 || true

      - name: Check SRI integrity
        run: |
          rg "<link.*https://.*rel=\"stylesheet\"" --type html | \
          rg -v "integrity=" && exit 1 || true

      - name: Check dangerous CSP
        run: |
          rg "unsafe-inline|unsafe-eval" nuxt.config.ts next.config.js && \
          exit 1 || true

      - name: Check outline: none
        run: |
          rg "outline:\s*none" --type css --type vue && exit 1 || true
```

**pre-commit hook**:

```bash
#!/bin/sh
# .husky/pre-commit

# CSS Injection チェック
rg "v-bind.*userInput|:style.*userInput" --type vue && \
  echo "ERROR: CSS Injection risk detected" && exit 1

# outline: none チェック
rg "outline:\s*none" --type css --type vue && \
  echo "ERROR: Accessibility violation (outline: none)" && exit 1

exit 0
```


## 12. 参考リンク

- **WCAG 2.1 ガイドライン**: https://www.w3.org/WAI/WCAG21/quickref/
- **MDN CSS リファレンス**: https://developer.mozilla.org/ja/docs/Web/CSS
- **CSS Triggers（パフォーマンス）**: https://csstriggers.com/
- **Stylelint 公式**: https://stylelint.io/
- **Prettier 公式**: https://prettier.io/


## 13. 新しいCSS機能の採用基準

### 13.1 採用判断フレームワーク

**基準**:

1. **ブラウザサポート状況**: Can I Use でグリーンライトが80%以上
2. **プログレッシブエンハンスメント可否**: フォールバックが実装可能
3. **クリティカル度**: クリティカルな機能でないこと（フォールバック困難な場合は見送り）

**判断フロー**:

```
IF ブラウザサポート < 80% THEN
    見送り（モダンブラウザ限定なら検討可）
ELSE IF クリティカル機能 AND フォールバック困難 THEN
    見送り
ELSE IF プログレッシブエンハンスメント可能 THEN
    採用
```

### 13.2 現在推奨の新機能（2025年時点）

**全機能推奨**: ブラウザサポート80%+、フォールバック可能（未サポートブラウザでは無視）

| 機能 | サポート | 用途 |
|------|---------|------|
| **Container Queries** | 90%+ | コンポーネント単位のレスポンシブ |
| **`:has()`疑似クラス** | 90%+ | 親要素セレクタ、条件付きスタイル |
| **CSS Nesting** | 85%+ | ネストされたセレクタ記述 |
| **`color-mix()`関数** | 85%+ | 動的カラー生成 |
| **Cascade Layers (@layer)** | 90%+ | CSS優先度の明示的管理 |
| **Subgrid** | 80%+ | グリッドレイアウトの入れ子 |

### 13.3 Container Queries 採用例

**推奨パターン**:

```css
/* 良い例 - コンポーネント単位のレスポンシブ */
.CardContainer {
  container-type: inline-size;
  container-name: card;
}

@container card (min-width: 400px) {
  .Card {
    display: grid;
    grid-template-columns: 1fr 2fr;
  }
}

@container card (max-width: 399px) {
  .Card {
    display: flex;
    flex-direction: column;
  }
}
```

**従来手法との比較**:

```css
/* NG: 従来手法 - ビューポート基準（コンポーネント再利用性が低い） */
@media (min-width: 768px) {
  .Card {
    display: grid;
  }
}
```

### 13.4 `:has()`疑似クラス採用例

**推奨パターン**:

```css
/* 良い例 - 親要素セレクタ */
.Card:has(.Badge) {
  padding-top: 2rem; /* バッジがある場合のみパディング調整 */
}

.Form:has(input:invalid) {
  border-color: var(--error, #dc3545); /* 無効な入力がある場合のみボーダー変更 */
}
```

**フォールバック**:

```css
/* フォールバック: JavaScriptで.has-badgeクラス追加 */
.Card.has-badge {
  padding-top: 2rem;
}
```

### 13.5 Cascade Layers (@layer) 採用例

**推奨パターン**:

```css
/* 良い例 - 明示的な優先度管理 */
@layer reset, base, components, utilities;

@layer reset {
  * { margin: 0; padding: 0; }
}

@layer base {
  body {
    font-family: var(--font-family, sans-serif);
    line-height: 1.5;
  }
}

@layer components {
  .Button {
    padding: var(--spacing-md, 1rem);
    background-color: var(--primary, #3b82f6);
  }
}

@layer utilities {
  .u-text-center { text-align: center; }
  .u-pc-only { display: block; }
}
```

**利点**:
- CSS詳細度の問題を根本的に解決
- `!important` 使用を大幅に削減可能
- レイヤー間の優先度が明確（reset < base < components < utilities）

**注意事項**:
1. **未サポートブラウザ**: Safari 15.3以前等では`@layer`が無視され、通常のCSSとして解釈される（フォールバック安全）
2. **コンポーネント内での使用**: プロジェクト構成で判断
   - **グローバルCSS** (`assets/styles/*.css`): `@layer`使用必須
   - **Vue SFC/CSS Modules**: utilityクラス使用時は`@layer`禁止（4.2節参照）
3. **レイヤー優先度**: `components` < `utilities` のため、utilityクラスがコンポーネントスタイルを上書き

### 13.6 Subgrid 採用例

**推奨パターン**:

```css
/* 良い例 - 親グリッドの列定義を継承 */
.ProductList {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
}

.ProductCard {
  display: grid;
  grid-template-rows: subgrid; /* 親のグリッドを継承 */
  gap: 0.5rem;
}
```

**利点**:
- ネストされたグリッドが親のグリッド定義を継承
- 複雑なレイアウトの簡潔な記述
- コンポーネント間の整列が容易

**注**: 未サポートブラウザ（Chrome 117以前等）では `subgrid` が無視され、通常の `grid` として動作。

**参考**: [Can I Use - CSS Feature Queries](https://caniuse.com/)


## バージョン情報

- **作成日**: 2025-11-21
- **適用範囲**: 汎用CSS規約（Vue/React/Next.js/Nuxt等）
- **現在バージョン**: 1.4.0
- **最終更新**: 2025-11-24
