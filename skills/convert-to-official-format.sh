#!/bin/bash
set -euo pipefail

# スキルファイルを公式形式（ディレクトリ + SKILL.md）に変換

SKILLS_DIR="/Users/sanae.abe/projects/claude-code-workspace/skills"
OUTPUT_DIR="/Users/sanae.abe/projects/claude-code-workspace/skills-official"

mkdir -p "$OUTPUT_DIR"

# すべての .md ファイルを処理
for file in "$SKILLS_DIR"/*.md; do
  if [ ! -f "$file" ]; then
    continue
  fi

  filename=$(basename "$file" .md)
  skill_dir="$OUTPUT_DIR/$filename"

  echo "Converting: $filename"

  # ディレクトリ作成
  mkdir -p "$skill_dir"

  # Frontmatterを抽出して変換（カスタムフィールドをコメント化）
  awk '
    BEGIN { in_frontmatter=0; frontmatter_done=0; desc="" }
    /^---$/ {
      if (!frontmatter_done) {
        in_frontmatter = !in_frontmatter
        if (!in_frontmatter) {
          # Frontmatter終了時に出力
          print "---"
          print "name: '"$filename"'"
          print "description:", desc
          print "---"
          print ""
          print "<!-- Original frontmatter fields:"
          if (allowed_tools) print "  allowed-tools:", allowed_tools
          if (argument_hint) print "  argument-hint:", argument_hint
          if (model) print "  model:", model
          print "-->"
          print ""
          frontmatter_done=1
        }
      }
      next
    }
    in_frontmatter && /^description:/ {
      desc = substr($0, index($0, ":")+2)
      next
    }
    in_frontmatter && /^allowed-tools:/ {
      allowed_tools = substr($0, index($0, ":")+2)
      next
    }
    in_frontmatter && /^argument-hint:/ {
      argument_hint = substr($0, index($0, ":")+2)
      next
    }
    in_frontmatter && /^model:/ {
      model = substr($0, index($0, ":")+2)
      next
    }
    in_frontmatter { next }  # Skip other frontmatter fields
    frontmatter_done { print }
  ' "$file" > "$skill_dir/SKILL.md"

  echo "  → $skill_dir/SKILL.md"
done

echo ""
echo "✅ Conversion complete!"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  1. Review converted files: ls -la $OUTPUT_DIR"
echo "  2. Remove old symlinks: rm /Users/sanae.abe/.claude/skills/*.md"
echo "  3. Create new symlinks: ln -s $OUTPUT_DIR/* /Users/sanae.abe/.claude/skills/"
