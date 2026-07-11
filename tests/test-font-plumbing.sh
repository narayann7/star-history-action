#!/usr/bin/env bash
# Verifies FONT_FAMILY flows through render-charts.sh into the PNG render.
set -euo pipefail
cd "$(dirname "$0")/.."
ACTION_PATH="$(pwd)"; export ACTION_PATH
REPO="${REPO:-nullvoidx/nullvoidx}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN}"
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; exit 1; }
A="$(mktemp -d)/assets"; GO="$(mktemp)"; ERR="$(mktemp)"

GITHUB_TOKEN="$GITHUB_TOKEN" REPOS="$REPO" OUTPUT_DIR="$A" TYPE=Date \
THEMES="light" WIDTH=800 ACTION_PATH="$ACTION_PATH" GITHUB_OUTPUT="$GO" \
FONT_FAMILY="Patrick Hand" \
bash "$ACTION_PATH/scripts/render-charts.sh" 2>"$ERR" >/dev/null

test -f "$A/star-history.png"           && pass "png produced" || fail "no png"
grep -q 'Using Google font' "$ERR"      && pass "font-family plumbed through" || fail "FONT_FAMILY not passed"
echo "PLUMBING TEST PASSED"
