---
name: cpp-copy-qa-to-prod
description: QA環境のCPPグループ（「阿部_」プレフィックス付き）を本番環境にコピーする。「阿部_」を除去した名前で enabled=false で作成。
argument-hint: "--source 260601 --category 872 --start '2026-06-01 00:00:00' --end '2026-07-31 23:59:59'"
disable-model-invocation: true
---

# CPP グループ QA → 本番 コピー

QA 環境から CPP グループデータを取得し、「阿部_」プレフィックスを除去して本番環境に作成する。

## 事前準備

1. Chrome で **QA admin** にログイン → Chrome 終了 → `/cpp-save-qa-cookies` 実行
2. Chrome で **本番 admin** にログイン → Chrome 終了

## Execution Flow

1. `$ARGUMENTS` から必須引数を抽出する:
   - `--source`: QAのコピー元キャンペーンコード（例: `260601`）
   - `--target`: 本番のコピー先コード（省略時は source と同じ）
   - `--category`: カテゴリID（デフォルト: `872`）
   - `--start`: 本番での開始日時（例: `2026-06-01 00:00:00`）
   - `--end`: 本番での終了日時（例: `2026-07-31 23:59:59`）
   - `--settings-from`: extra_settings 置換前略称（省略可）
   - `--settings-to`: extra_settings 置換後略称（省略可）
   - `--status`: QA検索ステータス（デフォルト: `active`）

2. 不足している必須引数があれば AskUserQuestion で確認する

3. dry-run で変換内容を確認してからユーザーに実行可否を確認:

```bash
cd /Users/sanae.abe/.claude/tools/playwright-admin
node copy-qa-to-prod.js $ARGUMENTS --dry-run
```

4. ユーザーが承認したら本実行:

```bash
cd /Users/sanae.abe/.claude/tools/playwright-admin
node copy-qa-to-prod.js $ARGUMENTS
```

## 動作仕様

- 名前変換: `阿部_一休様...260601` → `一休様...260601`
- enabled: false（表示停止状態で作成）
- QAへのアクセス: プロキシ + `qa-cookies.json`（自動）
- 本番へのアクセス: Chrome Profile 1 クッキー（自動）

## Error Handling

If "QA ログイン失敗": `/cpp-save-qa-cookies` 実行後に再試行
If "本番ログイン失敗": Chrome で本番 admin に再ログイン → Chrome 終了 → 再実行

## Examples

```
/cpp-copy-qa-to-prod --source 260601 --category 872 --start "2026-06-01 00:00:00" --end "2026-07-31 23:59:59"
```
