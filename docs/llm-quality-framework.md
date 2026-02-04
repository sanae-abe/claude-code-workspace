# LLM Implementation Quality Framework

> **目的**: CLAUDE.md・スラッシュコマンドの品質を定量的に評価し、LLM実装の成功率を90%以上に維持する

## 評価の3次元

### 1. Accuracy（正確性）

**定義**: LLMが仕様通りのコードを生成する確率

**測定方法**:
```
正確性 = (正しく実装される確率) × 100%

例:
- 具体的なコード例あり → 95%
- 抽象的な指示のみ → 60%
```

**判定基準**:
- **95-100%**: 完璧（具体例+検証関数+エラーハンドリング）
- **90-94%**: 良好（具体例+検証関数）
- **85-89%**: 要改善（具体例のみ）
- **<85%**: 不適格（抽象的指示のみ）

**向上策**:
- Bash微妙な構文の例示（IFS, parameter expansion, etc.）
- エラーハンドリングパターンの明示
- 終了コード伝播の実装例
- 入力検証の具体的コード

### 2. Maintainability（保守性）

**定義**: 生成コードが将来の修正に耐えられる度合い

**測定方法**:
```
保守性 = (標準パターン使用率 + テスト容易性 + コード重複なし) / 3 × 100%
```

**判定基準**:
- **95-100%**: 完璧（標準パターン+関数分離+DRY原則）
- **90-94%**: 良好（標準パターン+関数分離）
- **85-89%**: 要改善（標準パターンのみ）
- **<85%**: 不適格（非標準パターン）

**向上策**:
- 検証関数の定義と再利用
- セキュリティパターンの標準化
- コード重複の排除（セクション間統合）
- 構造化フォーマット（YAML, tables, code blocks）

### 3. Usability（ユーザビリティ）

**定義**: エラー時にユーザーが原因を理解できる度合い

**測定方法**:
```
ユーザビリティ = (明確なエラーメッセージ + 出力フォーマット例 + 代替手段提示) / 3 × 100%
```

**判定基準**:
- **95-100%**: 完璧（file:line参照+具体例+Suggestions）
- **90-94%**: 良好（file:line参照+具体例）
- **85-89%**: 要改善（具体例のみ）
- **<85%**: 不適格（抽象的エラー）

**向上策**:
- 出力フォーマットの視覚的テンプレート
- エラーメッセージにfile:line参照
- Suggestions（代替手段）の必須化
- ユーザー操作可能な指示

---

## 対象別評価チェックリスト

### スキル構造の前提知識

**Claude Code公式形式**:
```
~/.claude/skills/
  skill-name/           # ディレクトリ型（公式形式）
    SKILL.md            # ファイル名固定
```

**Frontmatter形式**:
```yaml
---
name: skill-name
description: What this skill does
---
```

**非推奨フィールド**: `allowed-tools`, `argument-hint`, `model`（公式仕様にない）

**参考**: `~/.claude/skills/anthropic-skills/*/SKILL.md` （公式スキル例）

---

### スキル評価チェックリスト

**対象**: `~/.claude/skills/*/SKILL.md` ファイル（Claude Code公式形式）

#### Accuracy（正確性）

- [ ] **Bash構文例の存在**: IFS操作、パラメータ展開（`${var#pattern}`）等
- [ ] **エラーハンドリングパターン**: 複数条件の丁寧なエラー表示
- [ ] **終了コード伝播**: `VALIDATION_RESULT=$?` → `exit $VALIDATION_RESULT`
- [ ] **入力検証の具体例**: validate_*() 関数の定義
- [ ] **セキュリティ実装**: クォート処理、パス検証の実装例

#### Maintainability（保守性）

- [ ] **標準パターン使用**: 一般的なBash/Python/Node.jsパターン
- [ ] **関数分離**: 検証ロジックを関数として定義
- [ ] **DRY原則**: コード重複なし（セクション間統合）
- [ ] **明示的な依存関係**: 他セクション・ファイルへの参照
- [ ] **構造化**: 一貫したセクション構成

#### Usability（ユーザビリティ）

- [ ] **出力フォーマット例**: 視覚的要素（罫線、絵文字）含む
- [ ] **file:line参照**: エラーメッセージに位置情報
- [ ] **Suggestions**: 各エラーに代替手段提示
- [ ] **Next steps**: 成功時の次アクション明示
- [ ] **ユーザー操作可能**: `cd`, `/command`等の具体的指示

**採点**:
- 全て満たす（15/15）: 95%+
- 12-14満たす: 90-94%
- 9-11満たす: 85-89%
- <9満たす: <85%

---

### CLAUDE.md評価チェックリスト

#### Accuracy（正確性）

- [ ] **具体的実装指示**: 抽象的原則ではなく、コード・手順
- [ ] **複雑操作の例示**: 判断が必要な箇所に具体例
- [ ] **判断基準の明確化**: IF-THEN-ELSE形式の決定木
- [ ] **曖昧表現の排除**: "should", "consider"に具体条件追加
- [ ] **外部参照の完全性**: 参照先ファイルが実在・最新

#### Maintainability（保守性）

- [ ] **構造化フォーマット**: YAML, tables, code blocks優先
- [ ] **外部参照活用**: 重複排除、技術スタック別分離
- [ ] **バージョン管理**: 変更履歴が追跡可能
- [ ] **明確な階層**: セクション・サブセクションの論理構造
- [ ] **トークン効率**: 不要な装飾・冗長表現の排除

#### Usability（ユーザビリティ）

- [ ] **LLM特化**: ユーザー向け情報の分離（USER_GUIDE.md等）
- [ ] **優先度明示**: MUST / SHOULD / MAY の使い分け
- [ ] **実行可能ステップ**: 説明ではなくアクション
- [ ] **エラー回避**: よくある誤りへの事前対策
- [ ] **検索性**: キーワードで必要情報に到達可能

**採点**:
- 全て満たす（15/15）: 95%+
- 12-14満たす: 90-94%
- 9-11満たす: 85-89%
- <9満たす: <85%

---

## 品質スコアの解釈

### 総合スコア算出

```
Overall Score = (Accuracy + Maintainability + Usability) / 3
```

### 判定とアクション

| Overall Score | 判定 | アクション |
|--------------|------|-----------|
| **95-100%** | ✅ Optimal | 現状維持、定期レビュー |
| **90-94%** | ✅ Acceptable | 低スコア次元を優先改善 |
| **85-89%** | ⚠️ Needs Improvement | 全次元の改善必須、再評価 |
| **<85%** | ❌ Inadequate | 全面書き直し推奨 |

### 次元別の重み付け（用途別）

**セキュリティクリティカル**（認証・決済等）:
```
Overall = Accuracy × 0.5 + Maintainability × 0.3 + Usability × 0.2
最低基準: Accuracy 95%+
```

**ユーザー向けコマンド**（/validate, /worktree等）:
```
Overall = Accuracy × 0.3 + Maintainability × 0.3 + Usability × 0.4
最低基準: Usability 90%+
```

**内部ツール**（自動化スクリプト等）:
```
Overall = Accuracy × 0.4 + Maintainability × 0.4 + Usability × 0.2
最低基準: Maintainability 90%+
```

---

## 実践例：validateコマンドの評価

### 評価結果

**Accuracy: 95%**
- ✅ Bash構文例（IFS操作、パラメータ展開）保持
- ✅ エラーハンドリングパターン（79-84行目）
- ✅ 終了コード伝播（68-72, 86行目）
- ✅ 入力検証（validate_layers, validate_auto_fix関数）
- ✅ セキュリティ実装（Security Implementationセクション）

**Maintainability: 90%**
- ✅ 標準パターン使用
- ✅ 関数分離（5つの検証関数）
- ⚠️ 一部コード重複（Implementationセクションと関数定義）
- ✅ 明示的な依存関係（"see Security Implementation"）
- ✅ 構造化フォーマット

**Usability: 90%**
- ✅ 出力フォーマット例（絵文字、罫線）
- ⚠️ file:line参照は間接的（report-generator.pyに委譲）
- ✅ Suggestions（--auto-fix提示）
- ✅ Next steps（Fix errors and re-run）
- ✅ ユーザー操作可能な指示

**Overall: 92% - Acceptable ✅**

### 改善提案

1. **コード重複の削除**（Maintainability +5%）
   - Implementationセクションから関数定義を削除
   - Security Implementationセクションのみに統合

2. **file:line参照の明示**（Usability +5%）
   - Output Formatに`file:line - description`形式を強調

---

## 使用方法

### 1. 新規作成時

```bash
# スキルディレクトリ作成
mkdir -p ~/.claude/skills/new-skill

# SKILL.md作成（公式形式）
cat > ~/.claude/skills/new-skill/SKILL.md << 'EOF'
---
name: new-skill
description: Brief description of what this skill does
---

# Skill Name

[Instructions here]
EOF

# 品質評価
/review-quality ~/.claude/skills/new-skill/SKILL.md

# スコア90%未満の場合は改善後に再評価
```

### 2. 既存スキル改善時

```bash
# 改善案をiterative-reviewで評価
/iterative-review ~/.claude/skills/existing-skill/SKILL.md

# 修正後に品質確認
/review-quality ~/.claude/skills/existing-skill/SKILL.md
```

### 3. CLAUDE.md編集時

```bash
# 編集
vi ~/.claude/CLAUDE.md

# 品質評価（特にLLM最適化セクション）
/review-quality ~/.claude/CLAUDE.md

# トークン効率も確認
wc -l ~/.claude/CLAUDE.md
```

---

## 参照

- `/review-quality` スキル: 自動評価ツール (`~/.claude/skills/review-quality/SKILL.md`)
- `/iterative-review` スキル: 多角的レビュー (`~/.claude/skills/iterative-review/SKILL.md`)
- CLAUDE.md編集ルール: LLM最適化の原則
- スキル構造仕様: `SKILL_MIGRATION.md` （スキル移行ガイド）
- 公式スキル例: `~/.claude/skills/anthropic-skills/*/SKILL.md`
