---
name: cpp-copy-prod-to-qa
description: 本番のCPPグループをQA環境にコピーする。名前に「阿部_」プレフィックスを付与、enabled=false（表示停止）で作成。
argument-hint: "--source 260401 --target 260601 --category 872 --start '2026-06-01 00:00:00' --end '2026-07-31 23:59:59' --settings-from S1262 --settings-to S1280"
disable-model-invocation: true
---

# CPP グループ 本番 → QA コピー

本番管理画面から CPP グループデータを取得し、QA 環境に「阿部_」プレフィックス付きで作成する。

## 事前準備

1. Chrome で **QA admin** にログイン → Chrome 終了 → `/cpp-save-qa-cookies` 実行
2. Chrome で **本番 admin** にログイン → Chrome 終了

## Execution Flow

1. `$ARGUMENTS` から必須引数を抽出する:
   - `--source`: コピー元キャンペーンコード（例: `260401`）
   - `--target`: コピー先キャンペーンコード（例: `260601`）
   - `--category`: カテゴリID（デフォルト: `872`）
   - `--start`: 開始日時（例: `2026-06-01 00:00:00`）
   - `--end`: 終了日時（例: `2026-07-31 23:59:59`）
   - `--settings-from`: extra_settings 置換前略称（例: `S1262`）
   - `--settings-to`: extra_settings 置換後略称（例: `S1280`）

2. 不足している必須引数があれば AskUserQuestion で確認する

3. dry-run で変換内容を確認してからユーザーに実行可否を確認する:

```bash
cd /Users/sanae.abe/.claude/tools/playwright-admin
node copy-prod-to-qa.js $ARGUMENTS --dry-run
```

4. ユーザーが承認したら本実行:

```bash
cd /Users/sanae.abe/.claude/tools/playwright-admin
node copy-prod-to-qa.js $ARGUMENTS
```

## 動作仕様

- 名前変換: `一休様...260401` → `阿部_一休様...260601`
- extra_settings: `S1262_SELECT-OTHERS-IKY_260401` → `S1280_SELECT-OTHERS-IKY_260601`
- enabled: false（表示停止状態で作成）
- プロキシ: `mrqa1.office.so-netm3.com:8889`（自動）
- QAクッキー: `qa-cookies.json`（自動読み込み）

## Error Handling

If "本番ログイン失敗": Chrome で本番 admin に再ログイン → Chrome 終了 → 再実行
If "QA ログイン失敗": `/cpp-save-qa-cookies` 実行後に再試行

## Examples

```
/cpp-copy-prod-to-qa --source 260401 --target 260601 --category 872 --start "2026-06-01 00:00:00" --end "2026-07-31 23:59:59" --settings-from S1262 --settings-to S1280
```
