# スキル構造移行ガイド

## 概要

Claude Code公式のスキル構造に準拠するため、すべての自作スキルをディレクトリ型に変換しました。

## 変更内容

### 1. スキル構造の変更

**変更前（非公式形式）**:
```
~/.claude/skills/
  commit.md          # 単一ファイル
  branch.md
  ...
```

**変更後（公式形式）**:
```
~/.claude/skills/
  commit/            # ディレクトリ
    SKILL.md         # ファイル名固定
  branch/
    SKILL.md
  ...
```

### 2. Frontmatter形式の変更

**変更前**:
```yaml
---
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: "[message] [--no-verify]"
description: Create Conventional Commits with emoji formatting
model: sonnet
---
```

**変更後**:
```yaml
---
name: commit
description: Create Conventional Commits with emoji formatting
---

<!-- Original metadata:
  allowed-tools: Bash, Read, AskUserQuestion
  argument-hint: "[message] [--no-verify]"
  model: sonnet
-->
```

### 3. 改行コード統一

- すべての SKILL.md ファイルを LF 改行コードに統一
- `.gitattributes` 追加で今後の CRLF 問題を防止

### 4. ディレクトリ構造の反転（2025-02-04追加）

**目的**: ディレクトリ構成を一般的なパターンに準拠させる

**変更前**:
- 実体: `skills-official/`
- シンボリックリンク: `~/.claude/skills/ -> skills-official/`

**変更後**:
- 実体: `~/.claude/skills/`（標準的なスキル配置場所）
- シンボリックリンク: `skills-official/ -> ~/.claude/skills/`（プロジェクト固有参照）

**利点**:
- 標準的なClaude Codeスキル配置（`~/.claude/skills/`）に準拠
- 他プロジェクトでも `~/.claude/skills/` を直接利用可能
- 関連ファイルも含めて自己完結型スキル構造

### 4-2. ディレクトリ構造の再反転（2026-09-01追加）

**背景**: §4 の構成では `skills-official/` が symlink の集合だったため、git が追跡するのは symlink（mode 120000）のみで **SKILL.md の中身がバージョン管理されていなかった**。スキルを編集しても `git status` はクリーンのままで、差分確認も revert もできない状態だった。

**変更前**（§4 の構成）:
- 実体: `~/.claude/skills/`
- シンボリックリンク: `skills-official/ -> ~/.claude/skills/`
- git 追跡: symlink のみ（内容は追跡外）

**変更後**（現行）:
- 実体: `skills-official/`（git 管理下、内容ごと追跡）
- シンボリックリンク: `~/.claude/skills/skill-name -> skills-official/skill-name`
- git 追跡: SKILL.md と関連ファイルすべて

**利点**:
- スキル内容がバージョン管理される（差分確認・revert・レビューが可能）
- 既に同構成だった `deploy-customizearea-*` とパターンが統一される
- `~/.claude/skills/` から読み込まれる動作は変わらない（symlink 経由）

**付随変更**:
- `validation/` の参照経路からリポジトリ→`~/.claude`→リポジトリの迂回を解消（`validation -> skills-official/validate/validation` の相対 symlink へ）
- 移行前のフラット形式 `skills/*.md`（24ファイル）を削除。どこにもデプロイされていない残骸だった

### 5. 最終ディレクトリ構成

```
~/.claude/skills/                   # マスターリポジトリ（実体）
  ├── commit/
  │   ├── SKILL.md
  │   └── （関連ファイル）
  ├── decide/
  │   ├── SKILL.md
  │   └── frameworks.md              # 関連ファイル
  ├── implement/
  │   ├── SKILL.md
  │   ├── tasks.schema.json          # 関連ファイル
  │   └── tasks.template.yml         # 関連ファイル
  ├── todo/
  │   ├── SKILL.md
  │   └── todo_validation.py         # 関連ファイル
  ├── validate/
  │   ├── SKILL.md
  │   └── validation/                # validation/ディレクトリ全体
  │       ├── pipeline.sh
  │       ├── config.sh
  │       ├── gates/
  │       ├── fixers/
  │       ├── patterns/
  │       ├── utils/
  │       └── tests/
  └── ...

claude-code-workspace/
  ├── skills-official/               # シンボリックリンクの集合
  │   ├── commit -> ~/.claude/skills/commit
  │   ├── decide -> ~/.claude/skills/decide
  │   ├── implement -> ~/.claude/skills/implement
  │   ├── validate -> ~/.claude/skills/validate
  │   ├── todo -> ~/.claude/skills/todo
  │   └── ...
  ├── validation -> ~/.claude/skills/validate/validation  # validation/ディレクトリのシンボリックリンク
  └── .gitattributes                # 改行コード設定

~/.claude/
  └── validation -> ~/.claude/skills/validate/validation  # validation/ディレクトリのシンボリックリンク
```

**構造の意図**:
- `~/.claude/skills/`: 標準的なスキル配置場所（実体ファイル）
- `skills-official/`: プロジェクト固有の参照（シンボリックリンク）
- 関連ファイルも `~/.claude/skills/` 配下に配置（自己完結型）

### 6. validateスキルの特殊対応（2025-02-04追加）

**背景**: validation/ディレクトリ（26ファイル、7サブディレクトリ）はvalidateスキルの品質ゲートパイプラインを実装。

**変更内容**:
- validation/ディレクトリ全体を `~/.claude/skills/validate/validation/` に移動
- プロジェクトルートとClaude設定ディレクトリにシンボリックリンク作成:
  - `~/projects/claude-code-workspace/validation → ~/.claude/skills/validate/validation`
  - `~/.claude/validation → ~/.claude/skills/validate/validation`

**理由**:
- 他のスキル（decide, implement, todo）と同様の自己完結型構造
- validation/ディレクトリもvalidateスキルに内包
- 既存の参照パス（`~/.claude/validation`）も維持（シンボリックリンク経由）

**影響**:
- validateスキルが完全に自己完結（validation/ディレクトリを含む）
- 他のスキル（review-pr等）からの `~/.claude/validation` 参照は引き続き機能

## 変換されたスキル（24個）

- analyze
- branch
- ca-vm
- clean-jobs
- commit
- debug
- decide
- explain
- i18n-check
- implement
- iterative-review
- optimize
- plan-review
- refactor
- research
- review-pr
- review-quality
- serena
- ship
- todo
- update-docs
- validate
- web-dev
- worktree

## ~/.claude/CLAUDE.md の更新

以下のパス参照を更新:

1. **スキル構造セクション**:
   ```markdown
   **スキル構造（Claude Code公式形式）**:
   - **ディレクトリ型**: `~/.claude/skills/skill-name/SKILL.md` 形式必須
   - **Frontmatter**: `name` と `description` のみ
   - **配置**: `~/.claude/skills/` に実ファイル、`skills-official/` はシンボリックリンク
   - **関連ファイル**: スキルディレクトリ内に配置（`frameworks.md`, `todo_validation.py`等）
   ```

2. **パス参照**:
   - プロジェクト内から: `skills-official/skill-name/SKILL.md` （シンボリックリンク経由）
   - 直接参照: `~/.claude/skills/skill-name/SKILL.md` （実体）
   - 関連ファイル: `~/.claude/skills/skill-name/関連ファイル名`

## 参考資料

- Claude Code公式スキル: `~/.claude/skills/anthropic-skills/*/SKILL.md`
- スキル仕様: https://support.claude.com/en/articles/12512198-creating-custom-skills
- スラッシュコマンド設計: `~/.claude/rules/slash-command-design.md`

## トラブルシューティング

### スキルが認識されない場合

1. **ディレクトリ構造確認**:
   ```bash
   ls -la ~/.claude/skills/commit/
   # SKILL.md が存在するか確認
   ```

2. **Frontmatter確認**:
   ```bash
   head -5 ~/.claude/skills/commit/SKILL.md
   # name: commit
   # description: ... があるか確認
   ```

3. **改行コード確認**:
   ```bash
   file ~/.claude/skills/commit/SKILL.md
   # UTF-8 text (CRLF なし) であることを確認
   ```

4. **Claude Code 再起動**:
   - 新しい会話を開始
   - スキルリストに表示されるか確認

## 新しいスキルの追加方法

1. **リポジトリ内に実ファイルとして作成**:
   ```bash
   REPO=~/projects/claude-code-workspace
   mkdir -p "$REPO/skills-official/new-skill"
   cat > "$REPO/skills-official/new-skill/SKILL.md" <<'EOF'
   ---
   name: new-skill
   description: New skill description
   ---

   # New Skill

   Arguments: $ARGUMENTS

   ## Execution Flow
   ...
   EOF
   ```

2. **~/.claude/skills/ からシンボリックリンク作成**（必須 — これがないと Claude Code が読み込まない）:
   ```bash
   ln -s "$REPO/skills-official/new-skill" ~/.claude/skills/new-skill
   ```

3. **関連ファイルの追加**:
   ```bash
   # 関連ファイルはスキルディレクトリ内（リポジトリ側）に配置
   cp config.json "$REPO/skills-official/new-skill/"

   # SKILL.mdから相対パスで参照
   # 例: `config.json` (同じディレクトリ内)
   ```

4. **コミット**:
   ```bash
   cd "$REPO" && git add skills-official/new-skill && git commit
   ```

**注意**: 実体はリポジトリ側にある。`~/.claude/skills/new-skill/SKILL.md` を編集しても symlink 経由で同一ファイルを編集することになるが、パス指定は実体側（`skills-official/`）を使うこと。
