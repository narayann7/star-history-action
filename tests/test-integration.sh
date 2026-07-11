#!/usr/bin/env bash
# Local integration test for the composite action's shell logic.
#
# Runs the SAME scripts/render-charts.sh and readme-embed.py that action.yml calls, so
# it exercises change detection, stable filenames, the PNG, backward-compat
# regeneration, and both README embed formats without a real GitHub Actions run.
#
# Requires GITHUB_TOKEN with stargazers access to $REPO (a repo with zero stars
# still renders a valid empty chart, which is all these assertions need).
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION_PATH="$(pwd)"; export ACTION_PATH
REPO="${REPO:-nullvoidx/nullvoidx}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN (e.g. GITHUB_TOKEN=\$(gh auth token))}"

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; exit 1; }

render() {  # $1=OUTPUT_DIR  $2=GITHUB_OUTPUT file
  GITHUB_TOKEN="$GITHUB_TOKEN" REPOS="$REPO" OUTPUT_DIR="$1" TYPE=Date \
  THEMES="light,dark" WIDTH=800 ACTION_PATH="$ACTION_PATH" GITHUB_OUTPUT="$2" \
  bash "$ACTION_PATH/scripts/render-charts.sh" >/dev/null 2>&1
}

echo "== Scenario A: fresh repo (first run) =="
A="$(mktemp -d)/assets"; GOA="$(mktemp)"
render "$A" "$GOA"
grep -q '^changed=true$' "$GOA"                  && pass "changed=true" || fail "expected changed=true"
test -f "$A/star-history-light.svg"              && pass "light svg"    || fail "no light svg"
test -f "$A/star-history-dark.svg"               && pass "dark svg"     || fail "no dark svg"
test -f "$A/star-history.png"                    && pass "png"          || fail "no png"
test -f "$A/.star-history.sig"                   && pass "sig"          || fail "no sig"
ls "$A"/star-history-*-*.svg >/dev/null 2>&1 && fail "unexpected timestamped file" || pass "no timestamped files"

echo "== Scenario B: re-run, no star change =="
GOB="$(mktemp)"
render "$A" "$GOB"
grep -q '^changed=false$' "$GOB"                 && pass "changed=false (skipped)" || fail "expected changed=false"

echo "== Scenario C: upgrade from timestamped naming (backward compat) =="
C="$(mktemp -d)/assets"; mkdir -p "$C"; GOC="$(mktemp)"
# Seed an OLD timestamped pair + a signature that MATCHES current data.
: > "$C/star-history-light-20250101000000.svg"
: > "$C/star-history-dark-20250101000000.svg"
cp "$A/.star-history.sig" "$C/.star-history.sig"   # same data -> sig would match
render "$C" "$GOC"
grep -q '^changed=true$' "$GOC"                  && pass "regenerated despite matching sig" || fail "should regen when stable files absent"
test -f "$C/star-history-light.svg"              && pass "stable light created" || fail "no stable light"
test -f "$C/star-history.png"                    && pass "stable png created"   || fail "no stable png"
test -f "$C/star-history-light-20250101000000.svg" && pass "legacy file kept"   || fail "legacy file deleted (should be kept)"

echo "== Scenario D: readme-embed png format =="
RD="$(mktemp).md"; printf '# X\n<!-- star-history:start -->\nOLD\n<!-- star-history:end -->\n' > "$RD"
README="$RD" LIGHT="assets/star-history/star-history-light.svg" \
DARK="assets/star-history/star-history-dark.svg" PNG="assets/star-history/star-history.png" \
README_FORMAT=png REPO="owner/repo" BRANCH=main OUTPUT_DIR="assets/star-history" \
python3 "$ACTION_PATH/scripts/readme-embed.py" >/dev/null
grep -q 'https://raw.githubusercontent.com/owner/repo/main/assets/star-history/star-history.png' "$RD" && pass "absolute raw png url" || fail "no raw png url"
grep -q '!\[Star History\]' "$RD"                && pass "plain markdown image" || fail "not plain markdown"
grep -q '<picture>' "$RD" && fail "png format used <picture>" || pass "no <picture> in png block"

echo "== Scenario E: readme-embed picture format =="
RE="$(mktemp).md"; printf '# X\n<!-- star-history:start -->\nOLD\n<!-- star-history:end -->\n' > "$RE"
README="$RE" LIGHT="assets/star-history/star-history-light.svg" \
DARK="assets/star-history/star-history-dark.svg" PNG="assets/star-history/star-history.png" \
README_FORMAT=picture REPO="owner/repo" BRANCH=main OUTPUT_DIR="assets/star-history" \
python3 "$ACTION_PATH/scripts/readme-embed.py" >/dev/null
grep -q '<picture>' "$RE"                        && pass "<picture> block" || fail "no <picture>"
grep -q 'srcset="assets/star-history/star-history-dark.svg"' "$RE" && pass "relative dark svg" || fail "no relative dark svg"

echo "== Scenario F: files are commit-able in a git repo =="
G="$(mktemp -d)"; ( cd "$G" && git init -q && git config user.email t@t && git config user.name t )
cp -r "$A" "$G/assets"
printf '# X\n<!-- star-history:start -->\nOLD\n<!-- star-history:end -->\n' > "$G/README.md"
( cd "$G" && git add assets README.md && git commit -q -m "test" && test -f assets/star-history.png )
( cd "$G" && git log --oneline | grep -q test ) && pass "committed chart files" || fail "commit failed"

echo "ALL INTEGRATION SCENARIOS PASSED"
