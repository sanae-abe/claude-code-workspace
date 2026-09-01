# Claude Code 設定

> **このファイルについて**: LLM向けに最適化された設定ファイル。編集時もLLM最適化を維持すること。ユーザー向け情報は `~/.claude/USER_GUIDE.md` に記載。

## 基本開発フロー

### 1. 要件分析・計画
1. タスク受領 → 要件明確化質問
2. 要件確認 → AskUserQuestionで選択肢提示
3. 影響範囲分析 → 依存関係ファイル確認
4. 実装計画立案 → TodoWrite活用

**不明点がある場合の対応**:
- **曖昧指示**: AskUserQuestionで選択肢提示
- **技術不明**: WebFetch仕様確認 + 複数案提示
- **認識齟齬**: 停止 → 事実確認 → 学習記録作成
- **緊急時**: セキュリティ優先、他簡略化可

### 2. 段階的実装

#### 実装フェーズのデフォルト動作原則

**専用ツール優先**（ハーネス側モードの指示が最優先。衝突時はモード指示に従う）:
- ファイル操作: Read/Edit/Write（Bash cat/sed/echo禁止）
- 検索: Grep/Glob（Bash find/grep禁止）
- コード編集: Serena MCP（対象ファイル ≥ 5 OR 総変更行数 ≥ 300、トークン効率向上）

**並列実行の最大化**:
- 独立タスク = ファイル依存関係なし、実行順序関係なし
- 例外: Edit後のRead、Write後のBash実行は順次実行
- 判定迷い時 = 安全側で順次実行
- 複数ファイル読み取り、独立した検索・分析は同時処理
- 並列実行可能なagentは同時起動

#### TodoWrite使用基準

**必須（3つ以上のステップ）**:
- 機能実装（設計→実装→テスト）
- バグ修正（調査→修正→検証）
- リファクタリング（分析→変更→確認）

**不要（単一・簡単なタスク）**:
- ファイル1つの修正
- 情報検索・質問への回答
- 単純なコマンド実行

**進捗の可視化**:
- 各ステップ完了時に即座に TodoWrite で status 更新
- コードコメントやBash echoでの説明禁止、直接出力のみ

#### ドキュメント駆動実装（tasks.yml使用時）

**前提**: `/implement [task-id]` 実行時、tasks.ymlの該当タスクが読み込まれる

**LLM動作**:
1. `docs`配列の全ドキュメントを事前Read
   - 例: `"docs/design.md#API仕様"` → design.mdの「API仕様」セクションのみ読む
2. `acceptance_criteria`を完了判断基準とする
3. 完了時に`status: completed`に自動更新

**tasks.yml例**:
```yaml
docs: ["docs/design.md#SectionName", "docs/api.md#Endpoint"]
acceptance_criteria: ["基準1", "基準2"]
```

**Interactive Mode（新機能作成）**:

`/implement "自然言語要件"` 実行時、tasks.ymlに自動追加して実装開始

**動作**:
1. AskUserQuestion: implementation type（ui/api/logic/infrastructure等）
2. AskUserQuestion: complexity（simple/moderate/complex/architectural）
3. tasks.ymlに新規task追加（自動採番）
4. `/implement task-N` 自動実行（ドキュメント駆動フローに移行）

**詳細**: `~/.claude/skills/implement/SKILL.md` "Interactive Mode" section

#### 並行開発の判定（最優先で評価）

```python
IF 以下のいずれか該当:
    - 作業中のブランチあり AND 緊急バグ修正が割り込み
    - 複数機能を同時開発（影響範囲が独立）
    - 実験的実装の並行試行（複数アプローチ比較）
    - レビュー待ち機能あり AND 新規開発開始
THEN:
    1. Skill tool実行: `/worktree create [branch-name]`
       # branch-name = feature-*/bugfix-*/experiment-*/hotfix-*
    2. ユーザーに "cd ../worktree-[branch-name]" 提示
    3. ポート管理: 3001, 3002, 3003... を指示
    4. 完了後は `/worktree merge [branch-name]` でクリーンアップ
    SKIP 以下の実装方法判定（worktree内で並行作業）
```

**タスク種別とAgent選択の判定フロー**（上から順に評価）:

```python
# 1. TDD適用判定（新規機能のみ）
IF タスク種別 == "新規機能実装" AND 以下のいずれか:
    - ビジネスロジック（決済、税計算、料金計算、割引ルール等）
    - アルゴリズム実装（ソート、検索、暗号化、圧縮等）
    - 状態機械・ワークフロー
    - バリデーションロジック（複雑なルール）
    - データ変換処理（API応答変換、フォーマット変換等）
    - project設定.development_methodology == "tdd"
    - ユーザーが明示的にTDD要求（"TDDで〜" "テスト駆動で〜"）
THEN:
    tdd-orchestrator agent起動
    SKIP 以下の判定

# 2. 探索・分析タスク
ELIF タスク種別 == "探索・検索・調査・アーキテクチャ理解":
    Agent tool (subagent_type=Explore)
    # 判定基準:
    # - ファイル数 ≥ 2 の横断検索
    # - "どこで〜" "〜の実装箇所" 系の質問
    # - アーキテクチャ・設計パターンの理解
    # - Grep/Glob 2回以上の試行が予想される
    SKIP 以下の実装判定

# 3. 単純な実装
ELIF ファイル数 == 1 AND 変更行数 < 50 AND 既存パターンの踏襲:
    自分で実装（Read → Edit → フォーマッター → テスト）

# 4. セキュリティリスクあり
ELIF セキュリティリスクあり（認証・認可・入力検証・暗号化・ユーザー入力・外部データ）:
    security-auditor agent → 実装agent（backend/frontend）

# 5. デバッグ・バグ修正
ELIF タスク種別 == "バグ調査・エラー解析・修正":
    IF ビジネスロジック AND project設定.development_methodology == "tdd":
        tdd-orchestrator agent起動
    ELSE:
        debugger agent → 根本原因特定 → 修正実装

# 6. リファクタリング
ELIF タスク種別 == "リファクタリング・コード改善":
    refactoring-specialist agent

# 7. パフォーマンス最適化
ELIF タスク種別 == "パフォーマンス改善・最適化":
    performance-engineer agent

# 8. コードレビュー（実装を伴わない）
ELIF タスク種別 == "コードレビュー・PRレビュー・セキュリティ監査・既存コード評価":
    IF セキュリティ重視 OR 認証・認可・入力検証含む:
        security-auditor agent → code-reviewer agent（順次実行）
    ELSE:
        code-reviewer agent

# 9. CLI/スクリプト実装判定（独立プロジェクトのみ）
ELIF タスク種別 == "CLI実装・スクリプト作成・自動化ツール" AND
     プロジェクト言語検出不可（package.json, Cargo.toml, go.mod等が存在しない）:
    # 詳細: ~/.claude/rules/tech-stacks/{rust,shell}-cli.md
    IF データ処理・API連携（CSV/JSON/YAML、REST API、統計計算）:
        python-pro agent
    ELIF 高パフォーマンス必須（GB単位データ、並行処理、バイナリ配布）:
        rust-pro agent
    ELIF 軽量自動化（< 50行 AND 外部入力なし）:
        # < 20行 → 自分で実装（Shell）、20-50行 → bash-pro agent
        bash-pro agent OR 自分で実装（Shell）
    ELSE:
        python-pro agent

# 10. 技術スタック別実装agent
ELIF tech_stack設定あり OR tech_stack自動検出成功:
    # プロジェクト/.claude/CLAUDE.md の tech_stack を参照
    # OR 以下のファイルから自動検出:
    #   - package.json → 内容で判定（下記参照）
    #   - Cargo.toml → rust-pro
    #   - go.mod → golang-pro
    #   - requirements.txt, pyproject.toml → python-pro
    #   - composer.json → php-pro
    #   - Gemfile → ruby-pro

    IF tech_stack == "frontend-web":
        # React/Next.js検出 → react-specialist、Vue/Nuxt検出 → vue-expert、それ以外 → frontend-developer
        frontend-developer OR react-specialist/vue-expert
    ELIF tech_stack == "backend-api":
        # 言語特化の最適化・イディオムが必要 → python-pro/golang-pro/rust-pro、汎用API設計 → backend-developer
        backend-developer OR (python-pro/golang-pro/rust-pro)
    ELIF tech_stack == "mobile-app":
        # Swift/SwiftUIネイティブ → ios-developer、React Native/Flutter → mobile-developer
        mobile-developer OR ios-developer
    ELIF package.json検出:
        # package.jsonの内容で判定:
        #   - react/vue/angular/next/nuxt依存あり → frontend-developer
        #   - express/nestjs/fastify/koa依存あり → backend-developer
        #   - 両方あり → fullstack-developer
        #   - 判定不可 → fullstack-developer
        内容に基づきagent選択
    ELIF Cargo.toml検出:
        rust-pro agent
    ELIF go.mod検出:
        golang-pro agent
    ELIF (requirements.txt OR pyproject.toml)検出:
        python-pro agent
    ELIF composer.json検出:
        php-pro agent
    ELIF Gemfile検出:
        ruby-pro agent
    ELSE:
        fullstack-developer

# 11. 複雑な実装（デフォルト）
ELSE:
    IF ファイル数 ≥ 3 OR ドメインロジック変更:
        # フロントエンド変更を含む → fullstack-developer、サーバーサイドのみ → backend-developer
        fullstack-developer OR backend-developer
    ELSE:
        自分で実装
```

**Agent起動時の必須パラメータ**:

- description: "〜の実装/調査/修正/最適化" （5-10語）
- model: "haiku" (探索・検証) OR "sonnet" (実装・リファクタリング・複雑なタスク)
  - コスト方針: 上位モデル（opus等）はユーザー明示指示時のみ使用
- prompt必須要素: 作業ディレクトリ、期待する成果、失敗報告形式 `"ERROR: [理由]"`、変更対象ファイルリスト（実装系のみ）

**Agent完了時の検証フロー**（必須実行）:

```python
# Step 1: エラー出力の確認（最優先）
IF agent出力に "ERROR:" 含む:
    作業停止 → ユーザー報告 → 再実行判断

# Step 2: Agent種別に応じた検証
ELIF subagent_type == "Explore":
    IF 出力にファイルパス:行番号パターンあり → 成功
    ELSE → Grep/Glob直接実行に切替

ELSE:  # 実装系・最適化系agent
    # Step 3: 期待成果物の実在確認（必須）
    FOR each 期待ファイル IN 変更対象ファイルリスト:
        IF ファイルが実在しない → 検証失敗 → ユーザーに報告

    # Step 4: 「実装完了後の必須フロー」へ移行（型チェック・レビューはそこで一括実行）
```

**Agent報告の簡潔化**:
- Agent完了時は結果を1-2文で要約し、次アクション明示
- 報告が長文の場合は要点3つ以内に絞る

**実装完了後の必須フロー**（順次実行）:
```
1. Skill tool実行: `/validate --layers=all --auto-fix`
   # Layer 1-2: 型チェック・lint・フォーマット（自動修正）
   # Layer 3-4: テスト実行・カバレッジ閾値
   # Layer 5: セキュリティ検証
   # 速度優先時のみ `--layers=syntax,security`（テストを省略）
   # スキル未対応の場合: 言語標準の型チェッカー・リンター・テストを直接実行
   # IF 失敗 → エラー報告 → 修正要求 → SKIP 以下

2. code-reviewer agent起動（PROACTIVE、全実装で必須）

3. IF code-reviewer が test coverage 不足を指摘:
       test-automator agent起動
```

### 3. 品質確認（技術スタック別）

#### コード品質基準

**レビュー指摘の一貫性**:
- 他者に指摘したルール・ガイドラインを自分の出力にも適用
- ダブルスタンダード禁止

**型安全言語（TypeScript, Rust, Go等）**:
- 型安全性: any回避・strictモード有効化・型推論活用
- コンパイルエラー・リンター警告: 0件必須
- フォーマッター: 言語標準ツールで統一
- エラーハンドリング: 型システム活用（Result<T>, Option<T>等、unwrap禁止）

**動的言語（JavaScript, Python, Ruby等）**:
- リンター・フォーマッター: 0件必須・統一整形
- テストカバレッジ: 新規コード 80% 以上

**全言語共通**:
- 命名規則・コメント: プロジェクト内で一貫性確保
- 依存関係: 不要な依存排除・脆弱性回避
- 編集後フロー: フォーマッター → リンター → テスト
- セキュリティ: OWASP対応・入力検証・出力エスケープ
- テスト: 新機能カバレッジ・既存機能影響確認
- 詳細: `~/.claude/rules/tech-stacks/{tech}.md`

#### 5層品質ゲートシステム

**多層検証による段階的品質保証**（実行コマンドは「実装完了後の必須フロー」参照）:
1. **Layer 1-2 (syntax)**: 型チェック・lint・フォーマット・YAML/JSON構文（lint/フォーマットは自動修正可能）
2. **Layer 3-4 (integration)**: テスト実行・カバレッジ閾値（既定80%。カバレッジレポートが存在する場合のみ判定）
3. **Layer 5 (security)**: セキュリティ（最重要）- .env検出、認証情報スキャン、インジェクション検出、依存脆弱性

**対象**: Node / Rust / Python をマーカーファイルで自動検出。ツール・設定が無い検査は「スキップ」として報告され、成功扱いにはならない。

**詳細**: `~/.claude/skills/validate/SKILL.md`

### 4. タスク完了・クリーンアップ

**バックグラウンドプロセス自動停止**:

```python
IF タスク完了（以下のいずれか）:
    - TodoWrite の全タスクが completed
    - ユーザーが「完了」「done」「finish」明示
THEN:
    Skill tool実行: `/clean-jobs --auto`
    # パターンベース自動分類:
    #   - 開発サーバー・watchモード → 自動停止
    #   - DB・Docker・ビルド → 継続実行
    # 詳細: ~/.claude/skills/clean-jobs/SKILL.md
```

---

## セキュリティ基準

**必須対応**:
- OWASP Top 10対応
- 機密情報: 環境変数使用（.env*/credentials.* 禁止）
- 脆弱性スキャン: 依存関係の定期確認
- セキュリティテスト: 認証・認可・入力検証の検証

**詳細**: `~/.claude/rules/tech-stacks/{tech}.md`

## リスク評価の必須記載

### 全技術提案での必須フォーマット
すべての技術提案・実装案には以下フォーマットでリスク評価を**必ず含める**。リスク評価なしの提案は不完全とみなす：

```markdown
## リスク評価

### セキュリティリスク **（最重要）**
- **[HIGH/MEDIUM/LOW]**: [認証、機密情報、入力検証等の具体的リスク]
- **軽減策**: [暗号化、サニタイズ、権限制御等の対策]

### 技術的リスク
- **[HIGH/MEDIUM/LOW]**: [破綻的変更、パフォーマンス、保守性への影響]
- **軽減策**: [段階的移行、テスト、rollback戦略]

### 開発効率リスク
- **[HIGH/MEDIUM/LOW]**: [工数増加、学習コスト、複雑性増大]
- **軽減策**: [段階実装、ドキュメント整備、チーム共有]
```

### リスクレベル判定基準
- **HIGH**: 本番環境・セキュリティ・データに重大な影響
- **MEDIUM**: 開発効率・保守性に一定の影響
- **LOW**: 軽微な影響、既知の対策で解決可能

---

## ファイル操作権限

### 絶対禁止操作

- `.env`, `.envrc`, `.env.*`, `credentials.*`, `secrets.*` の読み書き
- `.git/` ディレクトリ内の直接操作（git コマンド経由のみ可）
- `.DS_Store`, `Thumbs.db` 等のOS固有ファイル作成
- ホームディレクトリ外（`~/`以外）への書き込み（例外: セッションのscratchpadディレクトリ）

---

## Agentセキュリティ制約

**運用ルール**（Claude Codeが自動適用するものではなく、promptで遵守する規約）:

- **読み取り専用agent**（Explore, code-reviewer等）: Read/Grep/Globのみ使用
- **実装agent**: Write/Edit許可、forbidden_pathsを遵守
- **全agent共通の禁止パス**: `~/.ssh/*`, `~/.aws/*`, `.env*`, `credentials.*`, `secrets.*`

---

## WebFetch使用時の重要原則
- [禁止] HTTP成功を「エラー」と報告しない
- [必須] 大容量処理は「処理中」として正確に報告
- [必須] 具体的なエラー内容を明示

---

## このファイルの編集ルール

### LLM最適化の原則

CLAUDE.mdを編集する際は以下の原則を厳守：

1. **ユーザー向け情報の除外**
   - コマンド使用例は削除
   - 使い方・トラブルシューティングは `USER_GUIDE.md` へ

2. **LLM動作指示に特化**
   - 具体的な動作指示・判断基準のみ記載
   - 技術的な条件分岐・アルゴリズムを明示

3. **構造化と簡潔性**
   - 装飾的な文章を避け、箇条書き・表・コードブロックを活用
   - 冗長な説明を削除し、必要最小限の情報のみ

4. **トークン効率**
   - 全会話で読み込まれるため、不要な情報は徹底削除
   - 重複する内容は統合
   - 外部ファイル参照を活用（技術スタック別設定等）

5. **参照の実在性**
   - 記載前に参照先パス・コマンドの実在を `ls` / `command -v` で確認

---

## 設定ファイル構造

- `~/.claude/settings.json` - Claude Code システム設定
- `~/.claude/CLAUDE.md` - LLM向け動作設定（このファイル。実体は `~/projects/claude-code-workspace/CLAUDE.md` への symlink — 編集時は実体パスを指定）
- `~/.claude/USER_GUIDE.md` - ユーザー向けガイド
- `~/.claude/rules/tech-stacks/*.md` - 技術スタック別設定
- `project/.claude/CLAUDE.md` - プロジェクト固有設定

---

## 技術スタック設定システム

### 設定継承メカニズム

**3層構造**（下位層が上位層を上書き）:
1. **基盤層**: `~/.claude/CLAUDE.md` (技術中立的な開発フロー・セキュリティ基準)
2. **技術層**: `~/.claude/rules/tech-stacks/{tech-stack}.md` (技術スタック別設定)
3. **プロジェクト層**: `project/.claude/CLAUDE.md` (プロジェクト固有設定)

#### プロジェクト設定での技術指定
```yaml
# project/.claude/CLAUDE.md 冒頭
tech_stack: frontend-web  # 継承する技術スタック指定
project_type: spa        # プロジェクト種別
team_size: 3-5           # チーム規模
development_methodology: tdd  # 開発手法（tdd / test-after）デフォルト: test-after
```

### 技術スタック別設定ファイル

- `~/.claude/rules/tech-stacks/frontend-web.md` - Web Frontend開発
- `~/.claude/rules/tech-stacks/vue-nuxt.md` - Vue 3 / Nuxt 3・4開発（frontend-webを継承）
- `~/.claude/rules/tech-stacks/backend-api.md` - API Backend開発
- `~/.claude/rules/tech-stacks/mobile-app.md` - Mobile App開発
- `~/.claude/rules/tech-stacks/swift-macos-ios.md` - Swift（macOS/iOS）開発
- `~/.claude/rules/tech-stacks/data-science.md` - Data Science開発
- `~/.claude/rules/tech-stacks/rust-cli.md` - Rust CLI開発
- `~/.claude/rules/tech-stacks/shell-cli.md` - Shell CLI開発（Bash 4.0+対象）
- `~/.claude/rules/tech-stacks/css-coding-standards.md` - CSS規約（アクセシビリティ・パフォーマンス重視）

### 設計・開発ガイドライン

**スキル構造（Claude Code公式形式）**:
- **ディレクトリ型**: `~/.claude/skills/skill-name/SKILL.md` 形式必須
- **Frontmatter**: `description` を必ず記載。`allowed-tools`, `argument-hint`, `model`, `disable-model-invocation` 等はオプション（仕様は slash-command-design.md 参照）
- **配置**: `~/projects/claude-code-workspace/skills-official/skill-name/` に実ファイル（git 管理下）。`~/.claude/skills/skill-name` はそこへの symlink — 編集時は実体パスを指定
- **参考**: `~/.claude/skills/anthropic-skills/*/SKILL.md` （公式スキル例）
- **設計指針**: `~/.claude/rules/slash-command-design.md`

---

## 外部設定参照

**開発補助**:
- スキーマ定義: `~/.claude/schemas/*.json`
- テンプレート: `~/.claude/templates/*.yml`
- エージェント: `~/.claude/agents/*.agent.md`

**意思決定・機能別**:
- 意思決定フレームワーク: `~/.claude/docs/decision-frameworks.md`
- Figma連携: `~/.claude/docs/mcp-figma-rules.md`

**主要スキル実装**:
- /implement: `~/.claude/skills/implement/SKILL.md`
- /validate: `~/.claude/skills/validate/SKILL.md`
- /commit: `~/.claude/skills/commit/SKILL.md`
- /ship: `~/.claude/skills/ship/SKILL.md`

---

## 学習記録参照

- 参照タイミング: エラー調査・技術決定時
- 検索コマンド: `cldev lr suggest "[エラーメッセージ]"` または `cldev lr find "[キーワード]"`

---
