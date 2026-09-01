---
name: cpp-save-qa-cookies
description: Chrome Profile 1 の現在のクッキーを QA クッキーファイルに保存する。QA admin にログイン後 Chrome を終了してから実行すること。
disable-model-invocation: true
---

# Save QA Cookies

Chrome Profile 1 の `admin.m3.com` クッキーを `~/.claude/tools/playwright-admin/qa-cookies.json` に保存する。

## 前提条件

1. Chrome で QA admin にログイン済み
2. Chrome を終了済み（SQLite DB ロック解除のため）

## Execution Flow

```bash
node /Users/sanae.abe/.claude/tools/playwright-admin/save-qa-cookies.js
```

## Error Handling

If "クッキー数: 0件": Chrome が起動中 → Chrome を終了して再実行を促す
If error: Chrome で QA admin に再ログインするよう促す
