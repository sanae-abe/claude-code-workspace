---
name: deploy-customizearea-prod
description: 本番環境のcustomizearea_update_productionジョブを実行し、結果を表示する
---

# Deploy Customizearea Production

本番環境Jenkins（kerberos.dcb.so-netm3.com）の `customizearea_update_production` ジョブを実行する。

## IMPORTANT

本番環境へのデプロイです。実行前に必ずユーザーに確認を取ること。
AskUserQuestion で「本番環境にデプロイします。よろしいですか？」と確認してから実行する。

## Execution Flow

1. AskUserQuestion で本番デプロイ実行を確認
2. 「はい」の場合のみ続行、それ以外はキャンセル
3. Jenkins APIでジョブをPOST実行（https://kerberos.dcb.so-netm3.com）
4. HTTP 201 確認（成功）、それ以外はエラー報告
5. 5秒待機後、ビルド結果をポーリング（最大60秒）
6. 結果（SUCCESS/FAILURE/ABORTED）を表示

## Tool Usage

Bash でcurlを使いJenkins REST APIを呼び出す。
環境変数 `JENKINS_PROD_URL`, `JENKINS_PROD_USERNAME`, `JENKINS_PROD_TOKEN` を使用。

## Implementation

```bash
# Step 1: ジョブ実行
HTTP=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
  -u "${JENKINS_PROD_USERNAME}:${JENKINS_PROD_TOKEN}" \
  "${JENKINS_PROD_URL}/job/customizearea_update_production/build")

if [ "$HTTP" != "201" ]; then
  echo "ERROR: ジョブ実行失敗 HTTP=$HTTP"
  exit 1
fi

echo "✅ ジョブ実行開始（本番）"

# Step 2: ビルド番号確定まで待機
sleep 5

# Step 3: 結果ポーリング（最大12回 × 5秒 = 60秒）
for i in $(seq 1 12); do
  result=$(curl -s --connect-timeout 10 \
    -u "${JENKINS_PROD_USERNAME}:${JENKINS_PROD_TOKEN}" \
    "${JENKINS_PROD_URL}/job/customizearea_update_production/lastBuild/api/json?tree=number,result,building,duration,timestamp" \
    2>/dev/null)

  number=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('number','?'))")
  building=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('building'))")
  res=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result') or 'running')")
  dur=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('duration',0)//1000)")

  echo "[$i] ビルド #${number} | $res | ${dur}秒"

  if [ "$building" = "False" ]; then
    if [ "$res" = "SUCCESS" ]; then
      echo "✅ 本番ビルド #${number} SUCCESS (${dur}秒)"
    else
      echo "❌ 本番ビルド #${number} $res (${dur}秒)"
    fi
    break
  fi
  sleep 5
done
```

## Error Handling

If user does not confirm: cancel and report "デプロイをキャンセルしました"
If HTTP != 201: report "ERROR: ジョブ実行失敗" with status code
If polling timeout (60s): report "タイムアウト: ビルドが完了しませんでした"
If connection error: report "ERROR: Jenkins接続失敗"
