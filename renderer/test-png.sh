#!/usr/bin/env bash
# Smoke test: render.ts must produce a valid PNG when --png is passed.
# Requires GITHUB_TOKEN with access to the repo it charts.
set -euo pipefail
cd "$(dirname "$0")"

REPO="${1:-star-history/star-history}"
OUT="$(mktemp -d)"

node_modules/.bin/tsx render.ts \
  --repos "$REPO" \
  --theme light --type Date --width 800 \
  --output "$OUT/chart.svg" \
  --png "$OUT/chart.png"

# SVG still written.
test -s "$OUT/chart.svg"
grep -qi '<svg' "$OUT/chart.svg"

# PNG written and starts with the PNG magic bytes (\x89 P N G).
test -s "$OUT/chart.png"
head -c 4 "$OUT/chart.png" | od -An -tx1 | grep -qi '89 50 4e 47'

echo "PNG smoke test OK"
