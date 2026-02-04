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

### 4. ディレクトリ構成

```
claude-code-workspace/
  ├── skills/                        # 元のスキルファイル（後方互換性のため保持）
  │   ├── commit.md
  │   ├── branch.md
  │   └── ...
  ├── skills-official/               # 公式形式のスキル
  │   ├── commit/
  │   │   └── SKILL.md
  │   ├── branch/
  │   │   └── SKILL.md
  │   └── ...
  └── .gitattributes                # 改行コード設定

~/.claude/skills/
  ├── commit -> /path/to/skills-official/commit/      # シンボリックリンク
  ├── branch -> /path/to/skills-official/branch/
  └── ...
```

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

1. **スキル構造セクション追加**:
   ```markdown
   **スキル構造（Claude Code公式形式）**:
   - **ディレクトリ型**: `~/.claude/skills/skill-name/SKILL.md` 形式必須
   - **Frontmatter**: `name` と `description` のみ
   - **配置**: `skills-official/` ディレクトリに実ファイル、`~/.claude/skills/` にシンボリックリンク
   ```

2. **パス参照更新**（5箇所）:
   - `skills/implement.md` → `skills-official/implement/SKILL.md`
   - `skills/validate.md` → `skills-official/validate/SKILL.md`
   - `skills/clean-jobs.md` → `skills-official/clean-jobs/SKILL.md`

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

## 変換スクリプト

将来的に新しいスキルを追加する場合、`skills/convert-to-official-format.sh` を使用できます。

```bash
# 使用例
cd /path/to/claude-code-workspace/skills
./convert-to-official-format.sh
```
