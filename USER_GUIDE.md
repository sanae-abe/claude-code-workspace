# Claude Code ユーザーガイド

Claude Codeの効率的な使い方、スラッシュコマンド、設定システムの完全ガイドです。

## 目次

- [クイックスタート](#クイックスタート)
- [ディレクトリ構造](#ディレクトリ構造)
- [設定ファイル](#設定ファイル)
- [スラッシュコマンド一覧](#スラッシュコマンド一覧)
  - [緊急対応・デバッグ](#緊急対応デバッグ)
  - [機能開発](#機能開発)
  - [開発環境](#開発環境)
  - [Git ワークフロー](#git-ワークフロー)
  - [コード分析・ドキュメント](#コード分析ドキュメント)
  - [タスク管理・レビュー](#タスク管理レビュー)
  - [研究・学習](#研究学習)
  - [プロジェクト固有](#プロジェクト固有)
  - [ユーティリティ](#ユーティリティ)
- [バックアップとメンテナンス](#バックアップとメンテナンス)
- [学習記録の活用（cldev）](#学習記録の活用cldev)
- [よく使うコマンドの組み合わせ](#よく使うコマンドの組み合わせ)
- [技術スタック別機能](#技術スタック別機能)
- [関連ドキュメント](#関連ドキュメント)
- [トラブルシューティング](#トラブルシューティング)
- [フィードバック・改善提案](#フィードバック改善提案)

## クイックスタート

```bash
# 利用可能なコマンド一覧を表示
/help

# 開発サーバーを起動
/web-dev

# 新機能を実装
/feature ユーザー認証機能

# コミットを作成
/commit
```

## ディレクトリ構造

```
~/.claude/
├── CLAUDE.md                    # LLM向け基本設定（技術中立）
├── USER_GUIDE.md                # このファイル（ユーザー向けガイド）
├── settings.json                # Claude Code システム設定
├── skills/                      # Skills定義（シンボリックリンク）
│   ├── debug -> ../skills-official/debug/
│   ├── implement -> ../skills-official/implement/
│   └── ...
├── skills-official/             # Skills実ファイル
│   ├── debug/SKILL.md
│   ├── implement/SKILL.md
│   └── ...
├── rules/                       # 開発ルール・技術スタック設定
│   ├── frontend-web.md
│   ├── backend-api.md
│   ├── mobile-app.md
│   ├── data-science.md
│   └── rust-cli.md
├── docs/                        # ドキュメント
│   ├── case-studies.md
│   ├── roadmap.md
│   └── command-dashboard.md
├── learnings/                   # 学習記録（cldevで管理）
│   └── *.md
└── scripts/                     # メンテナンススクリプト
    └── validate-links.sh
```

## 設定ファイル

### 3層設定システム

Claude Codeは以下の3層で設定を管理します：

1. **基盤層**: `~/.claude/CLAUDE.md`
   - 技術中立的な開発フロー
   - セキュリティ基準
   - コード品質基準
   - タスク管理戦略

2. **技術層**: `~/.claude/rules/tech-stacks/{tech-stack}.md`
   - Web Frontend (`frontend-web.md`)
   - API Backend (`backend-api.md`)
   - Mobile App (`mobile-app.md`)
   - Data Science (`data-science.md`)
   - Rust CLI (`rust-cli.md`)

3. **プロジェクト層**: `project/.claude/CLAUDE.md`
   - プロジェクト固有の設定
   - チーム規約
   - 特殊なワークフロー

### 設定ファイルの編集

```bash
# 基本設定を編集
code ~/.claude/CLAUDE.md

# 技術スタック別設定を編集
code ~/.claude/rules/tech-stacks/frontend-web.md

# プロジェクト設定を編集（プロジェクトルートで）
code .claude/CLAUDE.md
```

## スラッシュコマンド一覧

### 緊急対応・デバッグ

| コマンド | 用途 |
|---------|------|
| `/urgent [緊急問題・障害内容]` | 本番障害・セキュリティインシデントの5分以内初期対応と応急処置 |
| `/fix [バグ・問題内容]` | 重要バグ修正 - 迅速な根本原因特定と最小限修正による当日解決 |
| `/debug [症状・エラー内容]` | 体系的デバッグフローでReact + TypeScript問題を効率的に解決 |

### 機能開発

| コマンド | 用途 |
|---------|------|
| `/feature [機能名・要件]` | 新機能実装 - 要件確認から設計・実装・テストまでの段階的開発フロー |
| `/implement [task-id\|"自然言語要件"]` | tasks.ymlのタスクを実装、または自然言語要件から新規タスクを作成して実装 |
| `/refactor [対象・機能名]` | 安全なリファクタリング（段階的実行）でコード品質・保守性・パフォーマンスを向上 |
| `/optimize [最適化対象・パフォーマンス領域]` | パフォーマンス最適化 - 測定・分析・最適化・検証の科学的アプローチによる性能向上 |

### 開発環境

| コマンド | 用途 |
|---------|------|
| `/web-dev [ポート指定・環境設定オプション]` | フロントエンド開発環境の迅速な起動と設定 |
| `/api-dev [ポート指定・環境設定・言語指定]` | バックエンドAPI開発環境の迅速な起動と設定 |
| `/ds-notebook [ポート指定・環境指定・拡張機能オプション]` | Jupyter Notebook/Lab開発環境の迅速な起動と設定 |
| `/mobile-dev [--ios・--android・--device指定]` | iOS/Android/Cross-platformモバイルアプリ開発環境の迅速な起動 |
| `/web-build [--analyze・環境指定オプション]` | 本番環境対応の最適化されたWebアプリケーションビルド |

### Git ワークフロー

| コマンド | 用途 |
|---------|------|
| `/branch` | Conventional Branch命名規則に従ったGitブランチ作成と対話的ガイダンス |
| `/commit [message]` | 対話的ガイダンス・自動検証・絵文字フォーマットによる規約準拠コミット作成 |
| `/ship [ブランチ名] [タイトル] [--skip-checks]` | GitHub PR / GitLab MR作成 - リモートURLからプラットフォームを自動判定、品質チェック後にドラフト作成 |
| `/review-pr <PR/MR番号> [--detailed] [--security-focus] [--performance-focus] [--multi-perspective]` | GitLab MR/GitHub PRの包括的レビューワークフロー - セキュリティ最優先の体系的品質確認 |

### コード分析・ドキュメント

| コマンド | 用途 |
|---------|------|
| `/analyze [structure\|performance\|quality\|debt\|overview] [--detailed\|--quick\|--report\|--focus=area]` | プロジェクトのコードベース、品質、パフォーマンスを多角的に分析するグローバルコマンド |
| `/explain [機能名\|コンポーネント名\|概念名] [--detailed\|--usage\|--examples]` | プロジェクトの機能・コンポーネント・概念を詳細に説明するグローバルコマンド |
| `/update-docs [doc-type] \| --implementation \| --api \| --architecture \| --sync \| --validate` | 包括的ドキュメント管理システム - 自動解析・更新・品質確認 |
| `/i18n-check [language-code] [--coverage\|--consistency\|--format\|--cultural\|--complete]` | Comprehensive internationalization (i18n) status check for any project |

### タスク管理・レビュー

| コマンド | 用途 |
|---------|------|
| `/todo [action] [description] \| add \| complete \| list \| sync \| project \| interactive` | Simple project task management with interactive UI and priority handling |
| `/plan-review <task-name> [--perspectives=security,performance,maintainability] [--rounds=2] [--format=detailed\|compact]` | Create implementation plan, review with iterative-review, update todo.md |
| `/iterative-review <target> [--rounds=4] [--perspectives=necessity,security,performance,maintainability] [--skip-necessity]` | Multi-perspective review analyzing necessity, security, performance, and maintainability |

### 研究・学習

| コマンド | 用途 |
|---------|------|
| `/research [調査トピック・技術領域]` | 徹底調査 - 新技術・手法の体系的調査と学習記録による知識蓄積 |

### プロジェクト固有

| コマンド | 用途 |
|---------|------|
| `/ca-vm [create\|edit\|check\|workflow\|search] [target]` | Velocity Template management for ca-template project |
| `/serena` | MCP特殊コマンド：セマンティックコード解析・インテリジェント開発支援 |

### ユーティリティ

| コマンド | 用途 |
|---------|------|
| `/validate [--layers=syntax,security] [--auto-fix]` | 多層品質ゲート検証 - 構文・フォーマット自動修正とセキュリティ検証 |
| `/worktree [create\|merge] [branch-name]` | Git worktree管理 - 並行開発ワークフローのためのブランチ分離・統合 |
| `/clean-jobs` | バックグラウンドジョブの安全なクリーンアップ |

## バックアップとメンテナンス

### 手動バックアップ

```bash
# 日次バックアップ
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup.$(date +%Y%m%d)

# 重要な変更前のバックアップ
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup.$(date +%Y%m%d_%H%M%S)
```

### 設定の検証

```bash
# リンク切れチェック（~/.claude/ 配下への参照が実在するか検証）
cd ~/projects/claude-code-workspace && bash -c '
shopt -s nullglob
grep -rnoE "~/\.claude/[A-Za-z0-9._/-]+" --include="*.md" . | while IFS= read -r line; do
  ref="~/${line#*:~/}"; p="${ref/#\~/$HOME}"
  [ -e "$p" ] || echo "壊れた参照: $line"
done'
```

## 学習記録の活用（cldev）

過去の問題解決や技術的決定を記録・検索できます。

```bash
# キーワード検索
cldev lr find "認証"

# タグ検索
cldev lr find "JWT" --field tag

# 統計表示
cldev lr stats

# 未解決問題一覧
cldev lr problems
```

### 学習記録の保存場所

`~/.claude/learnings/*.md`

## よく使うコマンドの組み合わせ

### 新機能開発フロー

```bash
# 1. ブランチ作成
/branch

# 2. 機能実装
/feature ユーザー認証機能

# 3. コード品質確認
/analyze quality

# 4. コミット
/commit

# 5. PR/MR作成
/ship
```

### バグ修正フロー

```bash
# 1. デバッグ
/debug ログイン時にエラーが発生

# 2. 修正
/fix 認証トークンの検証ロジック

# 3. 検証
/validate --layers=all

# 4. コミット・PR/MR
/commit
/ship
```

### パフォーマンス改善フロー

```bash
# 1. パフォーマンス分析
/analyze performance

# 2. 最適化
/optimize レンダリングパフォーマンス

# 3. ビルド確認
/web-build --analyze

# 4. コミット
/commit
```

## 技術スタック別機能

各技術スタックには専用の設定とコマンドがあります：

- **Web Frontend**: Lighthouse監査、Core Web Vitals最適化
- **API Backend**: API設計、パフォーマンス監視
- **Mobile App**: iOS/Android開発環境、デバイステスト
- **Data Science**: Jupyter環境、データ分析パイプライン
- **Rust CLI**: 型安全なCLI実装、クロスコンパイル

## 関連ドキュメント

- **Skills**: `~/.claude/skills/`
- **技術スタック設定**: `~/.claude/rules/tech-stacks/`
- **ケーススタディ**: `~/.claude/docs/case-studies.md`
- **実装ロードマップ**: `~/.claude/docs/roadmap.md`
- **コマンド実装状況**: `~/.claude/docs/command-dashboard.md`

## トラブルシューティング

### 設定が反映されない

1. `CLAUDE.md` の構文エラーを確認
2. Claude Code を再起動
3. 設定ファイルのバックアップから復元

### Skillが動作しない

1. `/help` でskill一覧を確認
2. `~/.claude/skills/{skill}.md` の存在確認
3. Skillファイルの構文エラーチェック

### パフォーマンスが遅い

1. 大規模な `CLAUDE.md` を技術スタック別に分割
2. 不要な設定やコメントを削除
3. 並列実行可能な処理を明示的に指定

## フィードバック・改善提案

設定システムの改善提案や問題報告は、Claude Codeセッション内で：

```
/todo add "CLAUDE.md の○○セクションを改善"
```

または学習記録として記録：

```bash
cldev lr add "設定システム改善案"
```
