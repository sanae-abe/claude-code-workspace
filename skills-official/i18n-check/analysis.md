# i18n Analysis Scripts

Reference Bash scripts for each analysis scope. Run via Bash tool in the project root.

## Completeness Analysis

```bash
# Auto-detect base language directory (prefer en, fallback to first found)
I18N_DIR=""
for d in locales i18n lang public/locales; do
  [ -d "$d" ] && I18N_DIR="$d" && break
done

BASE_DIR=$(ls -d "$I18N_DIR/en" "$I18N_DIR/en-US" 2>/dev/null | head -1)
[ -z "$BASE_DIR" ] && BASE_DIR=$(ls -d "$I18N_DIR"/*/  2>/dev/null | head -1)

echo "Base language: $(basename "$BASE_DIR")"

# Count keys recursively (nested JSON support via jq paths)
base_keys() {
  jq -r '[paths(scalars) | join(".")]' "$1" 2>/dev/null | jq length
}

# Get base key count
BASE_COUNT=0
for f in "$BASE_DIR"/*.json; do
  [ -f "$f" ] || continue
  count=$(base_keys "$f")
  BASE_COUNT=$((BASE_COUNT + count))
done
echo "Total base keys: $BASE_COUNT"

# Compare each language
for lang_dir in "$I18N_DIR"/*/; do
  lang=$(basename "$lang_dir")
  [ "$lang_dir" = "$BASE_DIR/" ] && continue

  lang_count=0
  for f in "$lang_dir"*.json; do
    [ -f "$f" ] || continue
    c=$(jq -r '[paths(scalars) | join(".")]' "$f" 2>/dev/null | jq length)
    lang_count=$((lang_count + c))
  done

  pct=$((BASE_COUNT > 0 ? lang_count * 100 / BASE_COUNT : 0))
  echo "$lang: $lang_count/$BASE_COUNT ($pct%)"
done

# Find missing keys per language (requires matching filenames)
echo ""
echo "Missing key detection:"
for base_file in "$BASE_DIR"/*.json; do
  fname=$(basename "$base_file")
  base_keys_list=$(jq -r '[paths(scalars) | join(".")][]' "$base_file" 2>/dev/null | sort)

  for lang_dir in "$I18N_DIR"/*/; do
    lang=$(basename "$lang_dir")
    [ "$lang_dir" = "$BASE_DIR/" ] && continue
    lang_file="$lang_dir$fname"
    [ -f "$lang_file" ] || { echo "$lang/$fname: MISSING FILE"; continue; }

    lang_keys=$(jq -r '[paths(scalars) | join(".")][]' "$lang_file" 2>/dev/null | sort)
    missing=$(comm -23 <(echo "$base_keys_list") <(echo "$lang_keys"))
    [ -n "$missing" ] && echo "$lang/$fname missing keys:" && echo "$missing" | head -10
  done
done
```

## Consistency Analysis

```bash
I18N_DIR=""
for d in locales i18n lang; do [ -d "$d" ] && I18N_DIR="$d" && break; done

echo "Terminology Consistency Check:"

# Check common UI terms for multiple distinct translations
for term in "error" "success" "cancel" "submit" "loading" "button"; do
  echo ""
  echo "=== '$term' ==="
  grep -rh "\"$term\"" "$I18N_DIR"/ 2>/dev/null \
    | sort -u | head -10
done

# Detect same key with different values across languages
echo ""
echo "Cross-language value divergence (same key, different values):"
for base_file in "$I18N_DIR/en/"*.json 2>/dev/null; do
  fname=$(basename "$base_file")
  jq -r 'to_entries[] | "\(.key)=\(.value)"' "$base_file" 2>/dev/null | while IFS='=' read -r key val; do
    for lang_dir in "$I18N_DIR"/*/; do
      lang=$(basename "$lang_dir")
      [ "$lang" = "en" ] && continue
      lang_val=$(jq -r --arg k "$key" '.[$k] // empty' "$lang_dir$fname" 2>/dev/null)
      [ -z "$lang_val" ] && continue
      # Flag if value is suspiciously similar to English (possible untranslated)
      [ "$lang_val" = "$val" ] && echo "Possibly untranslated in $lang: $key = $val"
    done
  done
done
```

## Format / Technical Quality Analysis

```bash
I18N_DIR=""
for d in locales i18n lang; do [ -d "$d" ] && I18N_DIR="$d" && break; done

echo "=== Placeholder Syntax Validation ==="
# Find files where placeholder counts differ (e.g. {0} missing in translation)
find "$I18N_DIR" -name "*.json" 2>/dev/null | while read -r f; do
  placeholders=$(grep -oE '\{[0-9]+\}|\{[a-z_]+\}|%[sd]|\{\{[^}]+\}\}' "$f" 2>/dev/null | sort | uniq -c)
  [ -n "$placeholders" ] && echo "$(basename "$(dirname "$f")")/$(basename "$f"): $placeholders"
done

echo ""
echo "=== Encoding Validation ==="
find "$I18N_DIR" -name "*.json" -exec file {} \; 2>/dev/null | grep -v "UTF-8" \
  | sed "s|$PWD/||" || echo "All files: UTF-8"

echo ""
echo "=== Hardcoded User-Facing Strings ==="
grep -rE '(alert|confirm|window\.alert)\(' src/ \
  --include="*.ts" --include="*.tsx" --include="*.vue" --include="*.js" 2>/dev/null \
  | grep -v "//.*alert\|t(\|i18n" \
  | sed "s|$PWD/||" | head -10

echo ""
echo "=== Potential Untranslated Strings in Source ==="
# Find quoted strings directly in JSX/Vue templates (heuristic)
grep -rE '"[A-Z][a-z].*"' src/ \
  --include="*.tsx" --include="*.vue" 2>/dev/null \
  | grep -v "className=\|import \|require\|//\|\.svg\|\.png\|\.jpg\|aria-" \
  | sed "s|$PWD/||" | head -10
```

## Cultural Appropriateness Analysis

```bash
I18N_DIR=""
for d in locales i18n lang; do [ -d "$d" ] && I18N_DIR="$d" && break; done

echo "=== Date/Time Format Check ==="
grep -rE "DateTimeFormat|toLocaleDate|toLocaleTime|date.*format|format.*date" \
  "$I18N_DIR"/ src/ 2>/dev/null | sed "s|$PWD/||" | head -5

echo ""
echo "=== Number/Currency Format Check ==="
grep -rE "NumberFormat|toLocaleNumber|currency.*format|format.*currency" \
  "$I18N_DIR"/ src/ 2>/dev/null | sed "s|$PWD/||" | head -5

echo ""
echo "=== Japanese Formality Check (です/ます vs だ/である) ==="
if [ -d "$I18N_DIR/ja" ]; then
  formal=$(grep -c "です\|ます\|ください" "$I18N_DIR"/ja/*.json 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
  informal=$(grep -c "だ。\|である\|しろ" "$I18N_DIR"/ja/*.json 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
  echo "Formal (です/ます): $formal instances"
  echo "Informal (だ/である): $informal instances"
  [ "$informal" -gt 0 ] && echo "WARNING: Mixed formality detected"
fi

echo ""
echo "=== Potential Literal English Idiom Translation ==="
# Common English idioms that are often literally translated
for idiom in "piece of cake" "break a leg" "hit the nail" "spill the beans"; do
  grep -ri "$idiom" "$I18N_DIR"/ 2>/dev/null | sed "s|$PWD/||" | grep -v "/en/"
done
```

## Documentation Coverage Analysis

```bash
echo "=== README Coverage ==="
I18N_DIR=""
for d in locales i18n lang; do [ -d "$d" ] && I18N_DIR="$d" && break; done

# Detect languages from i18n directory
LANGS=$(ls -1 "$I18N_DIR"/ 2>/dev/null)

for lang in $LANGS; do
  for path in "README.$lang.md" "docs/README.$lang.md" "README.${lang,,}.md"; do
    if [ -f "$path" ]; then
      age=$(git log -1 --format="%cr" -- "$path" 2>/dev/null || echo "unknown")
      echo "Found: $path (last updated: $age)"
      break
    fi
  done
done

echo ""
echo "=== Docs Directory Coverage ==="
if [ -d "docs" ]; then
  find docs/ -name "*.md" 2>/dev/null | sed "s|$PWD/||" | head -20
else
  echo "No docs/ directory found"
fi
```
