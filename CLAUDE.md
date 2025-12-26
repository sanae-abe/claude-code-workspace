# Claude Code 設定

> **このファイルについて**: LLM向けに最適化された設定ファイル。編集時もLLM最適化を維持すること。ユーザー向け情報は `~/.claude/USER_GUIDE.md` に記載。

## コミュニケーション言語

**ユーザーとの会話言語**: 日本語
- 全ての応答、質問、説明を日本語で行う
- AskUserQuestionの質問・選択肢も日本語

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

**専用ツール優先**:
- ファイル操作: Read/Edit/Write（Bash cat/sed/echo禁止）
- 検索: Grep/Glob（Bash find/grep禁止）
- コード編集: Serena MCP（大規模変更時、トークン効率向上）

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
- 各ステップ完了時に即座に status 更新
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

**例**:
```bash
/implement "ユーザープロフィール編集機能"
# → AskUserQuestion実行
# → tasks.ymlにtask-N追加
# → /implement task-N自動実行
# → docsも自動読込
```

**詳細**: `commands/implement.md` "Interactive Mode" section

#### 並行開発の判定（最優先で評価）

```python
IF 以下のいずれか該当:
    - 作業中 AND 緊急バグ修正が割り込み
    - 複数機能を同時開発（影響範囲が独立）
    - 実験的実装の並行試行（複数アプローチ比較）
    - レビュー待ち機能あり AND 新規開発開始
    - 現在ブランチ == "main" AND 未コミット変更あり
THEN:
    1. SlashCommand("/worktree create [branch-name]") 実行
       # branch-name = feature-*/bugfix-*/experiment-*/hotfix-*
    2. ユーザーに "cd ../worktree-[branch-name]" 提示
    3. ポート管理: 3001, 3002, 3003... を指示
    4. 完了後は /worktree merge [branch-name] でクリーンアップ
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
    # Red-Green-Refactorサイクル実施
    # テスト先行 → 最小実装 → リファクタリング
    SKIP 以下の判定

# 2. 探索・分析タスク
ELIF タスク種別 == "探索・検索・調査・アーキテクチャ理解":
    Task tool (subagent_type=Explore)
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
        # TDD適用バグ修正
        tdd-orchestrator agent起動
        # 修正テスト追加（Red） → 修正実装（Green） → リファクタリング
    ELSE:
        # 通常バグ修正
        debugger agent → 根本原因特定 → 修正実装

# 6. リファクタリング
ELIF タスク種別 == "リファクタリング・コード改善":
    refactoring-specialist agent

# 7. パフォーマンス最適化
ELIF タスク種別 == "パフォーマンス改善・最適化":
    performance-engineer agent

# 8. コードレビュー（実装を伴わない）
ELIF タスク種別 == "コードレビュー・PRレビュー・セキュリティ監査・既存コード評価":
    # 品質基準参照: 「3. 品質確認（技術スタック別）」
    IF セキュリティ重視 OR 認証・認可・入力検証含む:
        security-auditor agent → code-reviewer agent（順次実行）
    ELSE:
        code-reviewer agent
    # レビュー観点: 設計、アーキテクチャ、ベストプラクティス、保守性

# 9. CLI/スクリプト実装判定（独立プロジェクトのみ）
ELIF タスク種別 == "CLI実装・スクリプト作成・自動化ツール" AND
     プロジェクト言語検出不可（package.json, Cargo.toml, go.mod等が存在しない）:
    # 独立CLI/スクリプトの場合のみ言語選択ロジック適用
    # 既存プロジェクト内のCLI追加は #10 技術スタック判定で処理
    # 詳細: ~/.claude/rules/tech-stacks/{rust,python,shell}-cli.md
    # セキュリティリスク判定は #4 で既に処理済み
    IF データ処理・API連携（CSV/JSON/YAML、REST API、統計計算）:
        python-pro agent
    ELIF 高パフォーマンス必須（GB単位データ、並行処理、バイナリ配布）:
        rust-pro agent
    ELIF 軽量自動化（< 50行 AND 外部入力なし）:
        bash-pro agent OR 自分で実装（Shell）
    ELSE:
        python-pro agent

# 10. 技術スタック別実装agent
ELIF tech_stack設定あり OR tech_stack自動検出成功:
    # プロジェクト/.claude/CLAUDE.md の tech_stack を参照
    # OR 以下のファイルから自動検出:
    #   - package.json → frontend-web / fullstack-developer
    #   - Cargo.toml → rust-pro
    #   - go.mod → golang-pro
    #   - requirements.txt, pyproject.toml → python-pro
    #   - composer.json → php-pro
    #   - Gemfile → ruby-pro

    # 自動検出時の判定ロジック:
    # 1. プロジェクトルートでファイル存在確認（Glob "**/package.json" 等）
    # 2. 検出結果からagent選択
    # 3. 複数検出時は優先度: package.json > Cargo.toml > go.mod > pyproject.toml

    IF tech_stack == "frontend-web" OR package.json検出:
        frontend-developer OR react-specialist/vue-expert
    ELIF tech_stack == "backend-api":
        backend-developer OR (python-pro/golang-pro/rust-pro)
    ELIF tech_stack == "mobile-app":
        mobile-developer OR ios-developer
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
        fullstack-developer OR backend-developer
    ELSE:
        自分で実装
```

**Agent起動時の必須パラメータ**:

**共通パラメータ**:
- description: "〜の実装/調査/修正/最適化" （5-10語）
- model: "haiku" (探索・検証) OR "sonnet" (実装・リファクタリング・複雑なタスク)

**prompt必須要素**:
- 作業ディレクトリ: [プロジェクトルート絶対パス]
- 期待する成果（agentタイプ別）:
  - Explore: ファイルパス・行番号を含む検索結果
  - 実装系: 実装完了 + テスト通過 + リンター0件
  - debugger: 根本原因特定 + 修正案提示
  - refactoring-specialist: リファクタリング完了 + 既存機能維持
  - performance-engineer: ボトルネック特定 + 最適化実装 + ベンチマーク結果
  - tdd-orchestrator: Red-Green-Refactorサイクル完了 + 全テスト通過
- 失敗報告形式: "ERROR: [理由]" で開始
- 実装ファイル: [変更対象ファイルリスト]（実装系agentのみ）

**Agent完了時の検証フロー**（必須実行）:

```python
# Step 1: エラー出力の確認（最優先）
IF agent出力に "ERROR:" 含む:
    作業停止 → ユーザー報告 → 再実行判断
    SKIP 以下の検証

# Step 2: Agent種別に応じた検証
ELIF subagent_type == "Explore":
    IF 出力に正規表現 `[^:]+:\d+` マッチあり:
        成功 → 次タスク続行
    ELSE:
        Grep/Glob直接実行に切替

ELSE:  # 実装系・最適化系agent
    # Step 3: 期待成果物の実在確認（必須）
    期待ファイルリスト = prompt内で指定した変更対象ファイル

    FOR each 期待ファイル IN 期待ファイルリスト:
        IF ファイルが実在しない:
            検証失敗 → ユーザーに報告:
                "Agent実行後の検証失敗: {ファイルパス} が作成されていません"
            RETURN  # 以降の処理をスキップ

    # Step 4: 型チェック・動作確認（ファイル実在確認後）
    IF 実装系agent（refactoring-specialist, frontend-developer等）:
        型チェック実行（言語に応じたコマンド）
        IF 新規エラー検出:
            ユーザーに報告 → 修正判断
        ELSE:
            開発サーバー動作確認（該当する場合）

    # Step 5: code-reviewer起動（実装完了時）
    IF 実装完了 AND 型エラーなし:
        code-reviewer agent起動（PROACTIVE）
```

**検証の具体例**:

```typescript
// 悪い例：Agent報告を鵜呑みにする
agent.execute("components/Foo.vue作成")
// ✗ ファイル実在確認なし → 報告と実態が乖離する可能性

// 良い例：検証フロー実行
agent.execute("components/Foo.vue作成")
IF NOT file_exists("components/Foo.vue"):
    報告: "Agent実行後の検証失敗: components/Foo.vue が作成されていません"
    手動で作成 OR Agent再実行
ELSE:
    型チェック実行 → 動作確認 → code-reviewer起動
```

**Agent報告の簡潔化**:
- Agent完了時は結果を1-2文で要約し、次アクション明示
- 例: "3ファイルでエラー検出。修正が必要なのは auth.ts のみ"
- 報告が長文の場合は要点3つ以内に絞る

**実装完了後の必須フロー**（順次実行）:
```
1. SlashCommand("/validate --layers=syntax,security --auto-fix")
   # Layer 1-2: 構文・フォーマット自動修正（TypeScript, ESLint, Prettier）
   # Layer 5: セキュリティ検証（.env変更, 認証情報スキャン, OWASP）
   # IF 失敗 → エラー報告 → 修正要求 → SKIP 以下

2. code-reviewer agent起動（PROACTIVE、全実装で必須）
   # 設計、アーキテクチャ、ベストプラクティス評価
   # validateで機械的検証済み → 主観的評価に集中

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
- テストカバレッジ: 新機能の適切なカバレッジ

**全言語共通**:
- 命名規則・コメント: プロジェクト内で一貫性確保
- 依存関係: 不要な依存排除・脆弱性回避
- 編集後フロー: フォーマッター → リンター → テスト
- セキュリティ: OWASP対応・入力検証・出力エスケープ
- テスト: 新機能カバレッジ・既存機能影響確認
- 詳細: `~/.claude/rules/tech-stacks/{tech}.md`

#### 5層品質ゲートシステム

**多層検証による段階的品質保証**:
1. **Layer 1-2 (syntax)**: 構文・フォーマット（自動修正可能）
2. **Layer 3-4 (integration)**: テストカバレッジ、API型整合性
3. **Layer 5 (security)**: セキュリティ（最重要）- .env検出、認証情報スキャン、OWASP

**実行**: `/validate --layers=syntax,security --auto-fix`（実装完了後の必須フロー）
**詳細**: `commands/validate.md`

### 4. タスク完了・クリーンアップ

**バックグラウンドプロセス自動停止**:

```python
IF タスク完了（以下のいずれか）:
    - TodoWrite最終todo completed
    - ユーザーが「完了」「done」「finish」明示
THEN:
    SlashCommand("/clean-jobs --auto")
    # パターンベース自動分類:
    #   - 開発サーバー・watchモード → 自動停止
    #   - DB・Docker・ビルド → 継続実行
    # 詳細: commands/clean-jobs.md
```

---

## セキュリティ基準

**必須対応**:
- OWASP Top 10対応
- 機密情報: 環境変数使用（.env*/credentials.* 禁止）
- 脆弱性スキャン: 依存関係の定期確認
- セキュリティテスト: 認証・認可・入力検証の検証

**詳細**: `~/.claude/stacks/{tech}.md`

## リスク評価の必須記載

### 全技術提案での必須フォーマット
すべての技術提案・実装案には以下フォーマットでリスク評価を**必ず含める**。リスク評価なしの提案は不完全とみなす：

```markdown
## 🛡️ リスク評価

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
- ホームディレクトリ外（`~/`以外）への書き込み

---

## Agentセキュリティ制約

### エージェントメタデータによる安全性制御

**フロントマターによる安全性制御**:

**.agent.md ファイル構造**:
```yaml
---
model: claude-sonnet-4-5-20250929
tools: [Read, Grep, Glob]
security_level: high
readonly: true
forbidden_paths: [~/.ssh/*, ~/.aws/*, .env*]
max_turns: 20
---
```

**セキュリティレベル別制約**:
- `high`: Read/Grep/Globのみ許可（読み取り専用）
- `medium`: Write/Edit許可、Bash/WebFetch禁止
- `low`: 全ツール許可、forbidden_pathsのみ制限

**パス制限パターン**:
- `~/.ssh/*`, `~/.aws/*` - 認証情報ディレクトリ
- `.env*`, `credentials.*`, `secrets.*` - 環境変数・機密ファイル
- `/etc/*`, `/usr/*` - システムディレクトリ

**実行フロー**:
1. `.agent.md` のフロントマターをパース
2. `tools` リストから許可ツールを抽出
3. `forbidden_paths` でパスアクセスを制限
4. ツール実行時に制約を検証

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
   - コマンド使用例（`cldev lr find "認証"` 等）は削除
   - 「/helpで確認」等のユーザー案内は削除
   - 使い方・トラブルシューティングは `USER_GUIDE.md` へ

2. **LLM動作指示に特化**
   - 具体的な動作指示・判断基準のみ記載
   - 技術的な条件分岐・アルゴリズムを明示
   - チェックリスト・フォーマット定義を優先

3. **構造化と簡潔性**
   - 装飾的な文章を避け、箇条書き・表・コードブロックを活用
   - 冗長な説明を削除し、必要最小限の情報のみ

4. **トークン効率**
   - 全会話で読み込まれるため、不要な情報は徹底削除
   - 重複する内容は統合
   - 外部ファイル参照を活用（技術スタック別設定等）

### 編集時のチェックリスト

- ユーザー向け情報を含んでいないか？
- 具体的な動作指示・判断基準になっているか？
- トークン効率を考慮した簡潔な記述か？
- 外部ファイルへの参照で代替できないか？

---

## 設定ファイル管理

### 設定ファイル構造

- `~/.claude/settings.json` - Claude Code システム設定
- `~/.claude/CLAUDE.md` - LLM向け動作設定（このファイル）
- `~/.claude/USER_GUIDE.md` - ユーザー向けガイド
- `~/.claude/rules/tech-stacks/*.md` - 技術スタック別設定
- `project/.claude/CLAUDE.md` - プロジェクト固有設定

---

## 技術スタック設定システム

### 設定継承メカニズム

**3層構造**:
1. **基盤層**: `~/.claude/CLAUDE.md` (技術中立的な開発フロー・セキュリティ基準)
2. **技術層**: `~/.claude/rules/tech-stacks/{tech-stack}.md` (技術スタック別設定)
3. **プロジェクト層**: `project/.claude/CLAUDE.md` (プロジェクト固有設定)

**継承例**:
- `/feature` → 基盤層の段階的実装フロー
- `/web:lighthouse` → 技術層のWeb特化機能
- プロジェクト固有コマンド → プロジェクト層の専用機能

#### プロジェクト設定での技術指定
```yaml
# project/.claude/CLAUDE.md 冒頭
tech_stack: frontend-web  # 継承する技術スタック指定
project_type: spa        # プロジェクト種別
team_size: 3-5           # チーム規模
development_methodology: tdd  # 開発手法（tdd / test-after）デフォルト: test-after
```

### 技術スタック別設定ファイル

技術スタック別の詳細設定は以下のファイルを参照：
- `~/.claude/rules/tech-stacks/frontend-web.md` - Web Frontend開発
- `~/.claude/rules/tech-stacks/backend-api.md` - API Backend開発
- `~/.claude/rules/tech-stacks/mobile-app.md` - Mobile App開発
- `~/.claude/rules/tech-stacks/data-science.md` - Data Science開発
- `~/.claude/rules/tech-stacks/rust-cli.md` - Rust CLI開発
- `~/.claude/rules/tech-stacks/shell-cli.md` - Shell CLI開発（POSIX準拠の完全基準）
- `~/.claude/rules/tech-stacks/css-coding-standards.md` - CSS規約（アクセシビリティ・パフォーマンス重視）

### 設計・開発ガイドライン

**スラッシュコマンド開発**:
- `~/.claude/rules/tech-stacks/slash-command-design.md` - LLM最適化されたコマンド設計指針

**CSS開発**:
- `~/.claude/rules/tech-stacks/css-coding-standards.md` - 包括的CSS規約
- `~/.claude/rules/tech-stacks/.stylelintrc.json` - Stylelint設定（共有用）
- `~/.claude/rules/tech-stacks/.prettierrc` - Prettier設定（共有用）
- `~/.claude/rules/tech-stacks/README-css-configs.md` - CSS設定ファイル使用ガイド


---

## MCP統合

### 利用可能なMCP関数

#### IDE MCP Server
- `mcp__ide__executeCode` - コード実行（Jupyter等）
- `mcp__ide__getDiagnostics` - 診断情報取得（ESLint、TypeScript等）

#### Figma Dev Mode MCP
- 詳細ルール: `~/.claude/docs/mcp-figma-rules.md`（Figmaプロジェクトのみ）

---

## 外部設定参照

**開発時参照**:
- 技術判断: `~/.claude/rules/tech-stacks/{tech}.md`
- 品質検証: `~/.claude/validation/layers/*.md`
- セキュリティパターン: `~/.claude/validation/security-patterns.json`
- OWASPチェックリスト: `~/.claude/validation/owasp-top10-checklist.md`
- スキーマ定義: `~/.claude/schemas/*.json`
- テンプレート: `~/.claude/templates/*.yml`
- ユーティリティ: `~/.claude/utils/*.py`
- エージェント: `~/.claude/agents/*.agent.md`
- エラー調査: `~/.claude/learnings/*.md`

**意思決定・アイデア創出**:
- 意思決定フレームワーク: `~/.claude/docs/decision-frameworks.md`
- ICE/RICE スコアリング基準、First Principles等の実践的手法

**機能別参照**:
- AutoFlow統合: `~/.claude/docs/autoflow-integration-guide.md`
- Figma連携: `~/.claude/docs/mcp-figma-rules.md`

**コマンド実装**:
- /implement: `commands/implement.md`
- /validate: `commands/validate.md`

---

## 学習記録参照

- 参照タイミング: エラー調査・技術決定時
- 検索コマンド: `cldev lr suggest "[エラーメッセージ]"` または `cldev lr find "[キーワード]"`
- 記録場所: `~/.claude/learnings/*.md`

---
