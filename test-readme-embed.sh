#!/usr/bin/env bash
# Verifies both readme-format branches produce the expected block.
set -euo pipefail
cd "$(dirname "$0")"

TMP="$(mktemp -d)"
mk() { printf '# Demo\n<!-- star-history:start -->\nOLD\n<!-- star-history:end -->\n' > "$1"; }

run() {  # $1=format
  local rd="$TMP/README-$1.md"; mk "$rd"
  README="$rd" LIGHT="assets/star-history/star-history-light.svg" \
  DARK="assets/star-history/star-history-dark.svg" \
  PNG="assets/star-history/star-history.png" \
  README_FORMAT="$1" REPO="owner/repo" BRANCH="main" OUTPUT_DIR="assets/star-history" \
  python3 ./scripts/readme-embed.py
  cat "$rd"
}

# picture branch: relative <picture> with dark source.
run picture | grep -q '<picture>'
run picture | grep -q 'srcset="assets/star-history/star-history-dark.svg"'

# png branch: absolute raw URL, plain markdown, NO <picture>.
out="$(run png)"
echo "$out" | grep -q 'https://raw.githubusercontent.com/owner/repo/main/assets/star-history/star-history.png'
echo "$out" | grep -q '!\[Star History\]'
if echo "$out" | grep -q '<picture>'; then echo "FAIL: png branch used <picture>"; exit 1; fi

echo "readme-embed checks OK"
