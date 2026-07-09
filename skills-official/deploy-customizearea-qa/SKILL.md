---
name: deploy-customizearea-qa
description: QA環境のcustomizearea_update_qa_gitジョブを実行し、結果を表示する
---

# Deploy Customizearea QA

QA環境Jenkins（ci1:8081）の `customizearea_update_qa_git` ジョブを実行する。

## Execution Flow

1. Jenkins APIでジョブをPOST実行（http://ci1:8081）
2. HTTP 201 確認（成功）、それ以外はエラー報告
3. 5秒待機後、ビルド結果をポーリング（最大60秒）
4. 結果（SUCCESS/FAILURE/ABORTED）を表示

## Tool Usage

Bash でcurlを使いJenkins REST APIを呼び出す。
環境変数 `JENKINS_QA_URL`, `JENKINS_QA_USERNAME`, `JENKINS_QA_TOKEN` を使用。

## Implementation

```bash
# Step 1: ジョブ実行
HTTP=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
  -u "${JENKINS_QA_USERNAME}:${JENKINS_QA_TOKEN}" \
  "${JENKINS_QA_URL}/job/customizearea_update_qa_git/build")

if [ "$HTTP" != "201" ]; then
  echo "ERROR: ジョブ実行失敗 HTTP=$HTTP"
  exit 1
fi

echo "✅ ジョブ実行開始"

# Step 2: ビルド番号確定まで待機
sleep 5

# Step 3: 結果ポーリング（最大12回 × 5秒 = 60秒）
for i in $(seq 1 12); do
  result=$(curl -s --connect-timeout 10 \
    -u "${JENKINS_QA_USERNAME}:${JENKINS_QA_TOKEN}" \
    "${JENKINS_QA_URL}/job/customizearea_update_qa_git/lastBuild/api/json?tree=number,result,building,duration,timestamp" \
    2>/dev/null)

  number=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('number','?'))")
  building=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('building'))")
  res=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result') or 'running')")
  dur=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('duration',0)//1000)")

  echo "[$i] ビルド #${number} | $res | ${dur}秒"

  if [ "$building" = "False" ]; then
    if [ "$res" = "SUCCESS" ]; then
      echo "✅ ビルド #${number} SUCCESS (${dur}秒)"
    else
      echo "❌ ビルド #${number} $res (${dur}秒)"
    fi
    break
  fi
  sleep 5
done
```

## Error Handling

If HTTP != 201: report "ERROR: ジョブ実行失敗" with status code
If polling timeout (60s): report "タイムアウト: ビルドが完了しませんでした"
If connection error: report "ERROR: Jenkins接続失敗"
