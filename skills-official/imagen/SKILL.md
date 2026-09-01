---
description: Vertex AI 画像生成 — モデル一覧・料金確認、または PNG 保存
argument-hint: '[--list] [--model エイリアス] [--out パス] [--aspect 比率(Imagen系のみ)] プロンプト'
disable-model-invocation: true
allowed-tools: Bash
---

# imggen — Vertex AI 画像生成

ユーザー入力: `$ARGUMENTS`

## モデル一覧

### Imagen 系（`generate_images` API）

| エイリアス | モデル ID | 料金/枚 (USD) | 料金/枚 (JPY) | 説明 |
|-----------|----------|--------------|--------------|------|
| `i4u` | `imagen-4.0-ultra-generate-001` | USD 0.06 | 約¥9.5 | Imagen 4 Ultra — 最高品質 |
| `i4`  | `imagen-4.0-generate-001`       | USD 0.04 | 約¥6.4 | Imagen 4 標準（**デフォルト**） |
| `i4f` | `imagen-4.0-fast-generate-001`  | USD 0.02 | 約¥3.2 | Imagen 4 Fast — 速度重視 |
| `i3`  | `imagen-3.0-generate-002`       | USD 0.04 | 約¥6.4 | Imagen 3（プロンプト追従性に難あり） |
| `i3f` | `imagen-3.0-fast-generate-001`  | USD 0.02 | 約¥3.2 | Imagen 3 Fast（品質不安定） |

### Gemini Image 系（`generate_content` API）

| エイリアス | モデル ID | 料金/枚 (USD) | 料金/枚 (JPY) | 説明 |
|-----------|----------|--------------|--------------|------|
| `g25f` | `gemini-2.5-flash-image`         | ~USD 0.039 | 約¥6.2  | Gemini 2.5 Flash — 低コスト、旧世代 |
| `g31f` | `gemini-3.1-flash-image-preview` | ~USD 0.067 | 約¥10.7 | Gemini 3.1 Flash — 速度・品質バランス ★推奨 |
| `g3p`  | `gemini-3-pro-image-preview`     | ~USD 0.134 | 約¥21.3 | Gemini 3 Pro — 最高品質・テキスト組み合わせ強 |

> **Gemini Image 系の注意点**:
> - **`--aspect` 非対応**（API パラメータ未サポート）。アスペクト比を指定したい場合はプロンプトに含める（例: `"16:9 wide landscape"`）
> - 料金は入力トークン数・解像度により変動する場合あり
> - モデル ID は Vertex AI コンソールで最新状態を確認することを推奨
>
> 為替レート: 1 USD ≈ 159 JPY（変動あり）  
> 料金出典: [Vertex AI 料金ページ](https://cloud.google.com/vertex-ai/generative-ai/pricing)

アスペクト比オプション（**Imagen 系のみ**）: `1:1`（デフォルト）/ `16:9` / `9:16` / `4:3` / `3:4`

---

## 引数バリデーション

`$ARGUMENTS` を解析する前に以下を検証する:

- `--model` エイリアスは `i4u / i4 / i4f / i3 / i3f / g25f / g31f / g3p` のいずれかのみ許可。不一致の場合はエラーを表示してモデル一覧を出力し終了
- `--aspect` は `1:1 / 16:9 / 9:16 / 4:3 / 3:4` のいずれかのみ許可。Gemini 系モデル（`g25f` / `g31f` / `g3p`）が指定された場合は `--aspect` を無視してその旨を警告表示
- `--out` パスは `[a-zA-Z0-9/_.-]+` にマッチするもののみ許可。`..` を含む場合はセキュリティエラーとして終了

---

## 実行ロジック

### ケース A：`--list` または引数なし

上記のモデル一覧を出力して終了。画像は生成しない。

### ケース B：プロンプトあり（画像生成）

**1. 引数を解析・バリデーションする**

`$ARGUMENTS` から以下を抽出:
- `--model エイリアス` → 上表でモデル ID を引く（省略時: `i4` → `imagen-4.0-generate-001`）
- `--out パス` → 出力先ファイルパス（省略時: `assets/imggen_YYYYMMDD_HHMMSS.png`、タイムスタンプは `date +%Y%m%d_%H%M%S` で取得）
- `--aspect 比率` → アスペクト比（省略時: `1:1`）。Gemini 系モデルの場合は無視して警告を表示
- 残りのテキスト → プロンプト

エイリアスが `g25f` / `g31f` / `g3p` なら **Gemini Image 系 API** を使う。それ以外は **Imagen 系 API** を使う。

**2. `assets/` ディレクトリを作成**

```bash
mkdir -p assets
```

**3. Python スクリプトで画像を生成**

#### Imagen 系（i4u / i4 / i4f / i3 / i3f）

```python
import struct
import sys
import time
from pathlib import Path

from google import genai
from google.genai import types

PROJECT_ID = "m3-design-aiagent"
LOCATION   = "us-central1"

model_id  = "<解析したモデル ID>"
prompt    = "<解析したプロンプト>"
out_path  = Path("<解析した出力パス>")
aspect    = "<解析したアスペクト比>"

client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)

try:
    start = time.time()
    response = client.models.generate_images(
        model=model_id,
        prompt=prompt,
        config=types.GenerateImagesConfig(
            number_of_images=1,
            aspect_ratio=aspect,
        ),
    )
    elapsed = time.time() - start
except Exception as e:
    print(f"ERROR: API 呼び出し失敗 — {e}", file=sys.stderr)
    sys.exit(1)

image_bytes = response.generated_images[0].image.image_bytes
out_path.write_bytes(image_bytes)

try:
    with open(out_path, 'rb') as f:
        sig = f.read(8)
        if sig == b'\x89PNG\r\n\x1a\n':
            f.read(8)  # IHDR chunk length (4) + type "IHDR" (4)
            w = struct.unpack('>I', f.read(4))[0]
            h = struct.unpack('>I', f.read(4))[0]
            size_info = f"{w}×{h}px"
        else:
            size_info = "（非PNG形式のためサイズ取得不可）"
except Exception:
    size_info = "（サイズ取得不可）"

print(f"完了: {out_path}")
print(f"サイズ: {size_info}  ({len(image_bytes):,} bytes)")
print(f"生成時間: {elapsed:.1f}秒")
```

#### Gemini Image 系（g25f / g31f / g3p）

```python
import struct
import sys
import time
from pathlib import Path

from google import genai
from google.genai import types

PROJECT_ID = "m3-design-aiagent"
LOCATION   = "global"  # Gemini Image 系は global のみ対応

model_id  = "<解析したモデル ID>"
prompt    = "<解析したプロンプト>"
out_path  = Path("<解析した出力パス>")

client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)

try:
    start = time.time()
    response = client.models.generate_content(
        model=model_id,
        contents=prompt,
        config=types.GenerateContentConfig(
            response_modalities=["IMAGE"],
        ),
    )
    elapsed = time.time() - start
except Exception as e:
    print(f"ERROR: API 呼び出し失敗 — {e}", file=sys.stderr)
    sys.exit(1)

image_bytes = None
for part in response.candidates[0].content.parts:
    if part.inline_data is not None:
        image_bytes = part.inline_data.data
        break

if image_bytes is None:
    print("ERROR: 画像が返されませんでした", file=sys.stderr)
    sys.exit(1)

out_path.write_bytes(image_bytes)

try:
    with open(out_path, 'rb') as f:
        sig = f.read(8)
        if sig == b'\x89PNG\r\n\x1a\n':
            f.read(8)  # IHDR chunk length (4) + type "IHDR" (4)
            w = struct.unpack('>I', f.read(4))[0]
            h = struct.unpack('>I', f.read(4))[0]
            size_info = f"{w}×{h}px"
        else:
            size_info = "（非PNG形式のためサイズ取得不可）"
except Exception:
    size_info = "（サイズ取得不可）"

print(f"完了: {out_path}")
print(f"サイズ: {size_info}  ({len(image_bytes):,} bytes)")
print(f"生成時間: {elapsed:.1f}秒")
```

**4. 結果を日本語で出力**

スクリプト完了後、以下を日本語でまとめて表示:
- 保存先パス
- 画像サイズ（px）
- 使用モデル（エイリアス + モデル ID）
- 今回の料金（単価 USD + JPY）
- 生成時間（秒）

---

## エラーハンドリング

- `--model` に未知のエイリアスを指定: エラーを報告してモデル一覧を表示し終了
- `--aspect` に無効な比率を指定: 許可値（`1:1 / 16:9 / 9:16 / 4:3 / 3:4`）を表示してエラー終了
- Gemini 系モデルに `--aspect` を指定: 警告を表示して `--aspect` を無視して続行
- `--out` に `..` を含むパスを指定: "セキュリティエラー: パストラバーサルが検出されました" を表示して終了
- API 認証エラー: エラー内容を表示し `gcloud auth application-default login` を案内
- API エラー（クォータ超過・タイムアウト等）: エラーメッセージを表示して終了
- 画像が返されなかった: "ERROR: 画像が返されませんでした" を表示して終了

---

## 使用例

```
/imggen --list
/imggen quiet minimalist medical workspace, navy and white palette
/imggen --model i4u --aspect 16:9 夕暮れの山岳風景、シネマティック
/imggen --model i4f --out assets/hero.png abstract geometric pattern
/imggen --model g31f 夕暮れの山岳風景、シネマティック、16:9 wide
/imggen --model g3p 複雑なテキスト入りポスターデザイン
```
