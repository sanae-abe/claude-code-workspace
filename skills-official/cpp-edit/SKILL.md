---
name: cpp-edit
description: CPPグループを編集する。VMファイル一括変更・バトルID一括変更・enabled切替・日時変更・名前変更・extra_settings更新に対応。QA・本番両対応。
argument-hint: "--group-id 189722 [--prod] [--vm-from OLD.vm --vm-to NEW.vm] [--bid-from 11,12 --bid-to 11] [--enabled false] [--start '2026-06-01 00:00:00'] [--end '2026-07-31 23:59:59'] [--name '新名前'] [--extra-settings '...']"
disable-model-invocation: true
---

# CPP グループ編集

CPP グループの各種設定を変更する汎用スキル。複数操作を1回のコマンドで組み合わせ可能。

## Execution Flow

1. `$ARGUMENTS` から引数を抽出する:
   - `--group-id`: 対象グループID（必須）
   - `--prod`: 本番環境で実行（省略時はQA）
   - `--media`: メディア種別（デフォルト: WEB）
   - `--vm-from` / `--vm-to`: VMファイル一括変更（前/後）
   - `--bid-from` / `--bid-to`: バトルID一括変更（前/後）
   - `--enabled`: 表示状態変更（`true`=表示/`false`=停止）
   - `--start`: 開始日時変更
   - `--end`: 終了日時変更
   - `--name`: グループ名変更
   - `--extra-settings`: extra_settings全体を置換

2. `--group-id` が不明な場合は AskUserQuestion で確認する

3. 実行:

```bash
cd /Users/sanae.abe/.claude/tools/playwright-admin
node edit-cpp-group.js $ARGUMENTS
```

## 操作一覧

| 操作 | 引数 | 対象 |
|------|------|------|
| VMファイル一括変更 | `--vm-from OLD.vm --vm-to NEW.vm` | 全CPP |
| バトルID一括変更 | `--bid-from 11,12,16 --bid-to 11,12` | 全CPP |
| 表示停止/開始 | `--enabled false/true` | グループ |
| 日時変更 | `--start "..." --end "..."` | グループ |
| 名前変更 | `--name "新しい名前"` | グループ |
| extra_settings更新 | `--extra-settings "key=val,..."` | グループ |

## Error Handling

If "QA ログイン失敗": `/cpp-save-qa-cookies` 実行後に再試行
If "本番ログイン失敗": Chrome で本番 admin に再ログイン → Chrome 終了 → 再実行

## Examples

```
# VMファイルを新バージョンに変更（QA）
/cpp-edit --group-id 189722 --vm-from 260326_unit4_select_ikkyu_pc.vm --vm-to 260601_unit4_select_ikkyu_pc_01.vm

# バトルIDから16を削除（QA）
/cpp-edit --group-id 189722 --bid-from 11,12,13,14,15,16 --bid-to 11,12,13,14,15

# 表示停止（本番）
/cpp-edit --group-id 308244 --prod --enabled false

# 日時変更とVM変更を同時に（QA）
/cpp-edit --group-id 189722 --start "2026-06-01 00:00:00" --end "2026-07-31 23:59:59" --vm-from OLD.vm --vm-to NEW.vm
```
