#!/usr/bin/env bash
# Verifies --font-family: a real family renders a PNG, and a bogus family falls
# back to the bundled font without failing the run. Requires GITHUB_TOKEN.
set -euo pipefail
cd "$(dirname "$0")/.."
R="$(pwd)/renderer"
REPO="${REPO:-nullvoidx/nullvoidx}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN (e.g. GITHUB_TOKEN=\$(gh auth token))}"
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; exit 1; }
T="$(mktemp -d)"

echo "== A: valid Google font renders a PNG =="
GITHUB_TOKEN="$GITHUB_TOKEN" "$R/node_modules/.bin/tsx" "$R/render.ts" \
  --repos "$REPO" --theme light --type Date --width 800 \
  --output "$T/a.svg" --png "$T/a.png" --font-family "Patrick Hand" 2>"$T/a.err"
test -s "$T/a.png"                       && pass "png produced with Google font" || fail "no png"
grep -q 'Using Google font' "$T/a.err"   && pass "used Google font"              || fail "did not use Google font"

echo "== B: bogus font falls back, run still succeeds =="
GITHUB_TOKEN="$GITHUB_TOKEN" "$R/node_modules/.bin/tsx" "$R/render.ts" \
  --repos "$REPO" --theme light --type Date --width 800 \
  --output "$T/b.svg" --png "$T/b.png" --font-family "No Such Family ZZZ 999" 2>"$T/b.err"
test -s "$T/b.png"                       && pass "png produced via fallback"      || fail "no png on fallback"
grep -q 'falling back' "$T/b.err"        && pass "logged fallback"                || fail "no fallback log"

echo "== C: empty font-family keeps current behavior =="
GITHUB_TOKEN="$GITHUB_TOKEN" "$R/node_modules/.bin/tsx" "$R/render.ts" \
  --repos "$REPO" --theme light --type Date --width 800 \
  --output "$T/c.svg" --png "$T/c.png" 2>"$T/c.err"
test -s "$T/c.png"                       && pass "png produced with default font" || fail "no png default"
grep -q 'Using Google font' "$T/c.err"   && fail "should not fetch when empty"    || pass "no fetch when empty"

echo "== D: font-family is in the change signature (cache invalidation) =="
GITHUB_TOKEN="$GITHUB_TOKEN" "$R/node_modules/.bin/tsx" "$R/render.ts" \
  --repos "$REPO" --theme light --type Date --width 800 \
  --output "$T/d1.svg" --png "$T/d1.png" --signature "$T/d1.sig" --font-family "" 2>/dev/null
GITHUB_TOKEN="$GITHUB_TOKEN" "$R/node_modules/.bin/tsx" "$R/render.ts" \
  --repos "$REPO" --theme light --type Date --width 800 \
  --output "$T/d2.svg" --png "$T/d2.png" --signature "$T/d2.sig" --font-family "Patrick Hand" 2>/dev/null
if ! diff -q "$T/d1.sig" "$T/d2.sig" >/dev/null; then pass "signature differs by font"; else fail "signature unchanged when font changed"; fi

echo "ALL FONT TESTS PASSED"
