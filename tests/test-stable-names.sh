#!/usr/bin/env bash
# Verifies the render logic writes stable, non-timestamped filenames + a PNG.
# Render logic lives in scripts/render-charts.sh; the png output is declared in action.yml.
set -euo pipefail
cd "$(dirname "$0")/.."

# Fail if the render script still contains timestamped naming or the delete glob.
if grep -q 'star-history-\$theme-\$TS' scripts/render-charts.sh; then
  echo "FAIL: timestamped filename still present"; exit 1
fi
if grep -q 'TS="\$(date -u' scripts/render-charts.sh; then
  echo "FAIL: timestamp variable still present"; exit 1
fi
if grep -q -- '-name "star-history-\$theme-\*\.svg"' scripts/render-charts.sh; then
  echo "FAIL: delete-old glob still present"; exit 1
fi
# Require the stable png wiring in the render script.
grep -q 'star-history.png' scripts/render-charts.sh || { echo "FAIL: no png in render script"; exit 1; }
grep -q 'png=' scripts/render-charts.sh || { echo "FAIL: no png step output"; exit 1; }
# Require the png output declared in action.yml.
grep -q 'steps.render.outputs.png' action.yml || { echo "FAIL: no png output in action.yml"; exit 1; }

echo "stable-names checks OK"
