---
name: cpp-deprecate
description: CPPグループを廃止状態にする（削除の代替）。名前に「不使用_」を付加し、開始日時・終了日時を過去（2000-01-01）に変更。QA・本番両対応。
argument-hint: "[--ids 189746,189747 | --name キャンペーン名 [--category 872]] [--prod] [--dry-run]"
disable-model-invocation: true
---

# CPP グループ廃止

CPP グループを削除の代替として廃止状態にする。
- 名前: `不使用_` プレフィックスを付加
- 日時: 開始・終了を `2000-01-01` に変更
- 表示: `enabled=false`

## Execution Flow

1. `$ARGUMENTS` から引数を抽出する:
   - `--ids`: 廃止するグループIDのカンマ区切りリスト（例: `189746,189747`）
   - `--name`: 名前で検索して一括廃止（例: `260601`）
   - `--category`: カテゴリID（`--name` 使用時、デフォルト: `872`）
   - `--prod`: 本番環境で実行（省略時は QA）
   - `--dry-run`: 確認のみ

2. `--ids` か `--name` どちらかが必須。なければ AskUserQuestion で確認する

3. dry-run で確認:

```bash
cd /Users/sanae.abe/.claude/tools/playwright-admin
node deprecate-cpp-groups.js $ARGUMENTS --dry-run
```

4. ユーザーが承認したら本実行:

```bash
cd /Users/sanae.abe/.claude/tools/playwright-admin
node deprecate-cpp-groups.js $ARGUMENTS
```

## Error Handling

If "QA ログイン失敗": `/cpp-save-qa-cookies` 実行後に再試行
If "本番ログイン失敗": Chrome で本番 admin に再ログイン → Chrome 終了 → 再実行

## Examples

```
/cpp-deprecate --ids 189746,189747,189748
/cpp-deprecate --name 不要なグループ名 --category 872
/cpp-deprecate --prod --ids 308239,308240
/cpp-deprecate --name 260601 --dry-run
```
