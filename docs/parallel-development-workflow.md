# Git Worktree Parallel Development Workflow

Git worktreeを使った並列開発で開発速度を向上させるワークフロー。

## 概要

Git worktreeは、同じリポジトリの複数ブランチを同時に異なるディレクトリで作業できる機能です。従来のブランチ切り替え（`git checkout`）と異なり、ファイルシステム上に複数の作業ディレクトリを作成できるため、以下のメリットがあります。

**利点**:
- 複数機能を同時並行で開発可能
- ブランチ切り替え時のビルド再実行不要
- 緊急バグ修正と機能開発を同時進行
- コンテキストスイッチのコスト削減

**従来の問題**:
```bash
# 機能開発中に緊急バグ修正が発生
git stash              # 作業を退避
git checkout main      # ブランチ切り替え
git checkout -b bugfix # バグ修正開始
npm install            # 依存関係再インストール
npm run build          # ビルド再実行
# ... バグ修正後
git checkout feature   # 元のブランチに戻る
npm install            # 再度依存関係
npm run build          # 再度ビルド
git stash pop          # 作業復元
```

**Worktreeでの解決**:
```bash
# 機能開発は継続したまま
/worktree create bugfix-urgent
cd ../worktree-bugfix-urgent
# 即座にバグ修正開始（別ディレクトリで並行作業）
```

## セットアップ

### 前提条件

- Git 2.5+ (worktree機能サポート)
- プロジェクトはGitリポジトリで管理されている

### コマンドインストール

```bash
# シンボリックリンクで有効化（既に実行済み）
ln -s ~/projects/claude-code-workspace/skills-official/worktree ~/.claude/skills/worktree

# コマンド確認
/worktree
```

## 基本ワークフロー

### 1. メイン作業ディレクトリの位置づけ

現在のディレクトリ（メインworktree）は安定版・統合ブランチ（main/develop）で運用:

```bash
# 現在のディレクトリ = メインworktree
pwd
# /Users/sanae.abe/projects/claude-code-workspace

git branch
# * main  ← 安定版コードを保持
```

### 2. 並列開発の開始

新機能・バグ修正はそれぞれ独立したworktreeで作業:

```bash
# 機能A開発用worktree
/worktree create feature-authentication

# 機能B開発用worktree
/worktree create feature-payment

# バグ修正用worktree
/worktree create bugfix-login-error
```

**結果のディレクトリ構造**:
```
projects/
├── claude-code-workspace/          # メインworktree (main)
├── worktree-feature-authentication/ # 機能A
├── worktree-feature-payment/        # 機能B
└── worktree-bugfix-login-error/     # バグ修正
```

### 3. 作業ディレクトリの切り替え

ターミナルタブ/ペインごとに異なるworktreeで作業:

```bash
# ターミナル1: 機能A開発
cd ../worktree-feature-authentication
npm run dev  # ポート3000で開発サーバー起動

# ターミナル2: 機能B開発
cd ../worktree-feature-payment
npm run dev -- --port 3001  # 別ポートで並行起動

# ターミナル3: バグ修正
cd ../worktree-bugfix-login-error
npm test -- --watch
```

### 4. 完了後のマージとクリーンアップ

```bash
# メインworktreeに戻る
cd ~/projects/claude-code-workspace

# 機能Aをマージして自動クリーンアップ
/worktree merge feature-authentication
# → mainにマージ、push、worktree削除、ブランチ削除

# 機能Bもマージ
/worktree merge feature-payment

# バグ修正もマージ
/worktree merge bugfix-login-error
```

## 実践的なユースケース

### ケース1: 緊急バグ修正の割り込み

**状況**: 機能開発中に本番バグが発生

```bash
# 現在: feature-dashboardで開発中
cd ~/projects/worktree-feature-dashboard
# コードを大量に変更中、コミットしていない状態

# 緊急バグ修正が必要
cd ~/projects/claude-code-workspace  # メインに戻る
/worktree create hotfix-payment-error --from main

cd ../worktree-hotfix-payment-error
# 即座にバグ修正開始（feature-dashboardの作業は無傷）

# 修正完了
git add . && git commit -m "fix: payment processing error"
cd ~/projects/claude-code-workspace
/worktree merge hotfix-payment-error

# 機能開発に戻る
cd ../worktree-feature-dashboard
# 作業は元のまま継続
```

### ケース2: 複数機能の並行レビュー

**状況**: 2つの機能を並行してレビュー・テスト

```bash
# 機能1: 認証システム
/worktree create feature-auth
cd ../worktree-feature-auth
# 実装完了、レビュー待ち
npm run dev -- --port 3001 &  # バックグラウンド起動

# 機能2: 決済システム
cd ~/projects/claude-code-workspace
/worktree create feature-checkout
cd ../worktree-feature-checkout
# 実装完了、レビュー待ち
npm run dev -- --port 3002 &

# ブラウザで両方同時にテスト
# localhost:3001 - 認証機能
# localhost:3002 - 決済機能

# 問題なければ順次マージ
cd ~/projects/claude-code-workspace
/worktree merge feature-auth
/worktree merge feature-checkout
```

### ケース3: 実験的実装の並行試行

**状況**: 複数のアプローチを試して最適解を選択

```bash
# アプローチ1: REST API
/worktree create experiment-rest-api

# アプローチ2: GraphQL
/worktree create experiment-graphql

# アプローチ3: gRPC
/worktree create experiment-grpc

# それぞれで実装・ベンチマーク
cd ../worktree-experiment-rest-api
npm run benchmark  # 結果: 1000 req/s

cd ../worktree-experiment-graphql
npm run benchmark  # 結果: 1500 req/s

cd ../worktree-experiment-grpc
npm run benchmark  # 結果: 2000 req/s

# 最適解をマージ、他は削除
cd ~/projects/claude-code-workspace
/worktree merge experiment-grpc
/worktree delete experiment-rest-api
/worktree delete experiment-graphql
```

## 高度な運用パターン

### ポート管理戦略

複数の開発サーバーを同時起動する場合のポート割り当て:

```bash
# メインworktree: 3000
# worktree-1: 3001
# worktree-2: 3002
# worktree-3: 3003

# package.jsonでポート指定
{
  "scripts": {
    "dev:3001": "vite --port 3001",
    "dev:3002": "vite --port 3002",
    "dev:3003": "vite --port 3003"
  }
}
```

### CI/CD統合

Worktreeブランチの自動テスト:

```yaml
# .github/workflows/worktree-ci.yml
name: Worktree CI

on:
  push:
    branches:
      - 'feature-**'
      - 'bugfix-**'
      - 'experiment-**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm test
      - run: npm run build
```

### 依存関係の最適化

Worktree間でnode_modulesを共有してディスク節約:

```bash
# シンボリックリンクで共有（実験的）
cd ~/projects/worktree-feature-auth
rm -rf node_modules
ln -s ../claude-code-workspace/node_modules node_modules

# 注意: 異なるNode.jsバージョンや依存関係の場合は非推奨
```

**推奨**: 各worktreeで独立したnode_modulesを維持（安全性優先）

## トラブルシューティング

### Worktreeが削除できない

**エラー**: `fatal: 'worktree-xxx' is locked`

```bash
# ロック解除
git worktree unlock ../worktree-xxx

# 強制削除
/worktree delete xxx --force
```

### ディスク容量不足

複数worktreeでディスク使用量が増加:

```bash
# 未使用worktreeの確認
/worktree status

# 完了済みworktreeを削除
/worktree delete feature-completed
/worktree delete bugfix-merged

# 全worktreeの容量確認
du -sh ../worktree-*
```

### ブランチの依存関係

**問題**: feature-Bがfeature-Aに依存する場合

```bash
# feature-Aから派生してfeature-B作成
cd ../worktree-feature-a
git checkout -b feature-b
cd ~/projects/claude-code-workspace
/worktree create feature-b --from feature-a

# feature-Aマージ後、feature-Bをrebase
cd ../worktree-feature-b
git rebase main
```

## パフォーマンス比較

**従来のブランチ切り替え**:
```
機能開発 → バグ修正 → 機能開発再開
├─ git stash (5秒)
├─ git checkout (3秒)
├─ npm install (30秒)
├─ npm run build (60秒)
├─ バグ修正 (10分)
├─ git checkout (3秒)
├─ npm install (30秒)
├─ npm run build (60秒)
└─ git stash pop (5秒)

合計: 約13分 (作業10分 + オーバーヘッド3分)
```

**Worktree使用時**:
```
機能開発 → バグ修正 → 機能開発再開
├─ /worktree create (5秒)
├─ cd (即座)
├─ バグ修正 (10分)
└─ /worktree merge (10秒)

合計: 約10分15秒 (作業10分 + オーバーヘッド15秒)
```

**効率改善**: 約2分45秒短縮（20%高速化）

## ベストプラクティス

1. **メインworktreeは安定版を保持**
   - main/developブランチ専用
   - 直接コード変更しない
   - マージ・リリース作業のみ

2. **worktree命名規則**
   - `worktree-feature-*` - 新機能
   - `worktree-bugfix-*` - バグ修正
   - `worktree-experiment-*` - 実験的実装
   - `worktree-hotfix-*` - 緊急修正

3. **定期的なクリーンアップ**
   - 週次で未使用worktreeを削除
   - マージ済みブランチは即座に削除
   - `/worktree status`で状況確認

4. **ポート衝突回避**
   - 各worktreeで異なるポート使用
   - 環境変数でポート管理
   - README.mdにポート一覧記載

5. **ディスク容量管理**
   - 同時稼働worktreeは3-5個まで
   - 大規模プロジェクトは2-3個推奨
   - 定期的に`du -sh`で確認

## スクリプト例

### 自動セットアップスクリプト

```bash
#!/bin/bash
# setup-worktree.sh - worktree作成と環境セットアップ

BRANCH_NAME=$1
PORT=${2:-3001}

if [ -z "$BRANCH_NAME" ]; then
  echo "Usage: ./setup-worktree.sh <branch-name> [port]"
  exit 1
fi

# Worktree作成
/worktree create "$BRANCH_NAME"

# 環境セットアップ
cd "../worktree-${BRANCH_NAME}"
npm install
cp ../.env.example .env
echo "PORT=$PORT" >> .env

echo "✓ Worktree ready: worktree-${BRANCH_NAME}"
echo "✓ Dev server port: $PORT"
echo ""
echo "Next: cd ../worktree-${BRANCH_NAME} && npm run dev"
```

### 一括クリーンアップスクリプト

```bash
#!/bin/bash
# cleanup-merged-worktrees.sh - マージ済みworktreeを削除

git branch --merged main | grep -v "^\* main$" | while read branch; do
  if [[ "$branch" =~ ^[[:space:]]*(feature-|bugfix-|experiment-) ]]; then
    echo "Deleting merged worktree: $branch"
    /worktree delete "${branch// /}"
  fi
done
```

## まとめ

Git worktreeを活用することで:
- **開発速度20%向上** (ブランチ切り替えオーバーヘッド削減)
- **コンテキストスイッチコスト削減** (複数タスクの並行作業)
- **緊急対応の柔軟性向上** (作業中断不要)
- **実験的開発の促進** (複数アプローチの並行試行)

`/worktree`コマンドで簡単に並列開発環境を構築し、生産性を向上させましょう。
