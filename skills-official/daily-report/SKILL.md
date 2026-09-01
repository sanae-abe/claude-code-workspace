---
name: daily-report
description: 今日のSlackメッセージから日報を自動生成する（プロジェクト名はチャンネル名から自動取得）
---

# Daily Report Generator

Arguments: $ARGUMENTS (optional: channel-to-project name overrides, e.g. "channel-name=ProjectName")

## Execution Flow

1. Calculate yesterday's date in YYYY-MM-DD format for the Slack search query
2. Use mcp__slack__slack_search_messages with:
   - query: "from:@sanae-abe after:[yesterday]"
   - sort: "timestamp", sort_dir: "desc", count: 50
3. Extract unique channels from the results
4. Skip non-project channels: design-勤怠連絡, unit3-pf, design-ai, and any channel containing 勤怠
5. Map remaining channel names to project names using Channel Name Cleanup Rules below
   (priority: $ARGUMENTS overrides > fixed mappings > cleaned channel name)
6. Group messages by project and summarize into concise bullet points (1-3 per project)
7. Output formatted report

## Channel Name Cleanup Rules

Apply in order (later rules take precedence):
1. Clean up channel name: remove `pj-wj-` prefix, `-運用` suffix
2. Apply fixed mappings:
   - `club-canow-px` → `Club CaNoW`
   - `dxクリニック_hp` → `患者目線`
   - `k-mesen` → `患者目線`（NOTE: private channel — MCP cannot fetch messages; ask user for content）
   - `ask総研-デザイン関連` → `ask総研`
   - `新領域ca` → `新領域CA`
3. Apply overrides from $ARGUMENTS if provided (format: "channel=ProjectName")
   Overrides take highest priority, overriding fixed mappings above.

## Report Format

```
終業します。お疲れ様でした。

本日：
[チャンネルから取得したプロジェクト名1]
・[作業内容]

[チャンネルから取得したプロジェクト名2]
・[作業内容]

明日：
[プロジェクト名1]
・[次ステップが明確なら記載、なければ「対応継続」]

[プロジェクト名2]
・[次ステップが明確なら記載、なければ「対応継続」]
```

## Analysis Rules

- Slack user: sanae-abe (ID: U017YA5U6P6)
- Write bullet points in concise Japanese
- For "明日" section: use context from messages if available, otherwise "・対応継続"
- Exclude reaction-only activity; focus on sent messages

## Error Handling

- Slack MCP failure: report "Slackメッセージの取得に失敗しました" and stop
- Zero messages found: output "本日の作業履歴が見つかりませんでした"
- k-mesen channel detected: notify user "k-mesenはプライベートチャンネルのため内容を確認して追記してください"
- Invalid $ARGUMENTS format: skip the invalid override, proceed with default mapping

## Examples

/daily-report
→ チャンネル名から自動取得（引数不要）

/daily-report pj-wj-別チャンネル=患者目線
→ 別チャンネルを「患者目線」として表示（$ARGUMENTS override）
