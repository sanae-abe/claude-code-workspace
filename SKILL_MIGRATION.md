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
  └── ...

claude-code-workspace/
  ├── skills-official/               # シンボリックリンクの集合
  │   ├── commit -> ~/.claude/skills/commit
  │   ├── decide -> ~/.claude/skills/decide
  │   ├── implement -> ~/.claude/skills/implement
  │   ├── todo -> ~/.claude/skills/todo
  │   └── ...
  └── .gitattributes                # 改行コード設定
```

**構造の意図**:
- `~/.claude/skills/`: 標準的なスキル配置場所（実体ファイル）
- `skills-official/`: プロジェクト固有の参照（シンボリックリンク）
- 関連ファイルも `~/.claude/skills/` 配下に配置（自己完結型）

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
- スラッシュコマンド設計: `~/.claude/rules/tech-stacks/slash-command-design.md`

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

1. **~/.claude/skills/ に直接作成**:
   ```bash
   mkdir ~/.claude/skills/new-skill
   cat > ~/.claude/skills/new-skill/SKILL.md <<'EOF'
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

2. **プロジェクトからシンボリックリンク作成**（オプション）:
   ```bash
   cd /path/to/claude-code-workspace/skills-official
   ln -s ~/.claude/skills/new-skill new-skill
   git add new-skill
   ```

3. **関連ファイルの追加**:
   ```bash
   # 関連ファイルはスキルディレクトリ内に配置
   cp config.json ~/.claude/skills/new-skill/

   # SKILL.mdから相対パスで参照
   # 例: `config.json` (同じディレクトリ内)
   ```
