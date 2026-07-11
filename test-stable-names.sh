#!/usr/bin/env bash
# Verifies the render step writes stable, non-timestamped filenames + a PNG.
set -euo pipefail
cd "$(dirname "$0")"

# Fail if action.yml still contains timestamped naming or the delete glob.
if grep -q 'star-history-\$theme-\$TS' action.yml; then
  echo "FAIL: timestamped filename still present"; exit 1
fi
if grep -q 'TS="\$(date -u' action.yml; then
  echo "FAIL: timestamp variable still present"; exit 1
fi
if grep -q -- '-name "star-history-\$theme-\*\.svg"' action.yml; then
  echo "FAIL: delete-old glob still present"; exit 1
fi
# Require the stable png output wiring.
grep -q 'star-history.png' action.yml || { echo "FAIL: no png output"; exit 1; }
grep -q 'png=' action.yml || { echo "FAIL: no png step output"; exit 1; }

echo "stable-names checks OK"
