#!/usr/bin/env bash
# Render star history charts and write stable, overwrite-in-place files.
#
# Called by action.yml's "Render star history charts" step and by
# test-integration.sh, so both exercise the identical logic. Reads its config
# from the environment (same names action.yml sets) and appends step outputs to
# $GITHUB_OUTPUT:
#
#   GITHUB_TOKEN  token with stargazers access to REPOS
#   REPOS         comma-separated owner/repo list
#   OUTPUT_DIR    where chart files are written
#   TYPE          Date | Timeline
#   THEMES        comma-separated theme names (light,dark)
#   WIDTH         image width in px
#   ACTION_PATH   action root (contains renderer/)
#   GITHUB_OUTPUT file to append changed/light/dark/png/files to
set -euo pipefail

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "::error::token input is empty. Provide a GitHub token with access to the target repos."
  exit 1
fi

R="$ACTION_PATH/renderer"
mkdir -p "$OUTPUT_DIR"
TMP="$(mktemp -d)"

# Collect trimmed, validated theme names. Themes are used in file paths and
# delete globs, so restrict them to a safe charset to prevent path traversal or
# glob collisions.
themes=()
IFS=',' read -ra THEME_LIST <<< "$THEMES"
for raw_theme in "${THEME_LIST[@]}"; do
  # Trim leading/trailing whitespace with pure bash (no word splitting).
  theme="${raw_theme#"${raw_theme%%[![:space:]]*}"}"
  theme="${theme%"${theme##*[![:space:]]}"}"
  [ -z "$theme" ] && continue
  if ! [[ "$theme" =~ ^[a-z0-9]+$ ]]; then
    echo "::error::Invalid theme name '$theme'. Themes must match [a-z0-9]."
    exit 1
  fi
  themes+=("$theme")
done

if [ "${#themes[@]}" -eq 0 ]; then
  echo "::error::No valid themes in input '$THEMES'."
  exit 1
fi

# Change detection is by star data, not rendered pixels: the SVG has sub-pixel
# float jitter every run, so comparing SVGs would always look changed. render.ts
# writes a signature over the star data (day-level dates + counts). We render the
# first theme as a probe, compare its signature to the stored one, and only
# continue if it moved.
probe="${themes[0]}"
SIGFILE="$OUTPUT_DIR/.star-history.sig"
echo "Rendering $REPOS ($probe) as change probe"
# The token is passed via the GITHUB_TOKEN env var (set on this step), not on
# argv, so it does not appear in the process list.
"$R/node_modules/.bin/tsx" "$R/render.ts" \
  --repos "$REPOS" \
  --theme "$probe" \
  --type "$TYPE" \
  --width "$WIDTH" \
  --output "$TMP/$probe.svg" \
  --png "$TMP/star-history.png" \
  --signature "$TMP/new.sig"

if [ ! -s "$TMP/$probe.svg" ]; then
  echo "::error::Rendered SVG is empty for theme $probe"
  exit 1
fi

newsig="$(cat "$TMP/new.sig")"
oldsig="$(cat "$SIGFILE" 2>/dev/null || true)"

# Backward compat: a repo upgrading from the old timestamped naming has a
# matching signature but no stable files yet. Only skip when the data is
# unchanged AND every stable target already exists.
have_stable=true
for theme in "${themes[@]}"; do
  [ -f "$OUTPUT_DIR/star-history-$theme.svg" ] || have_stable=false
done
[ -f "$OUTPUT_DIR/star-history.png" ] || have_stable=false

if [ -n "$oldsig" ] && [ "$newsig" = "$oldsig" ] && [ "$have_stable" = true ]; then
  echo "No star history change and stable files present; keeping existing charts."
  echo "changed=false" >> "$GITHUB_OUTPUT"
  exit 0
fi
if [ "$have_stable" != true ]; then
  echo "Stable chart files missing (first run or upgrade from timestamped naming); regenerating."
fi

# Changed: render the remaining themes too.
for theme in "${themes[@]}"; do
  [ "$theme" = "$probe" ] && continue
  echo "Rendering $REPOS ($theme)"
  "$R/node_modules/.bin/tsx" "$R/render.ts" \
    --repos "$REPOS" \
    --theme "$theme" \
    --type "$TYPE" \
    --width "$WIDTH" \
    --output "$TMP/$theme.svg"
  if [ ! -s "$TMP/$theme.svg" ]; then
    echo "::error::Rendered SVG is empty for theme $theme"
    exit 1
  fi
done

# Changed: write stable, overwrite-in-place filenames. External consumers (npm,
# pub.dev) freeze the README URL, so a moving filename 404s once the old file is
# deleted. A fixed path is always valid; the main-repo README still refreshes
# because a push purges GitHub's image cache.
light=""
dark=""
files=""
for theme in "${themes[@]}"; do
  final="$OUTPUT_DIR/star-history-$theme.svg"
  cp "$TMP/$theme.svg" "$final"
  [ "$theme" = "light" ] && light="$final"
  [ "$theme" = "dark" ] && dark="$final"
  files="${files}${final}"$'\n'
done
# If no explicit "light" theme, use the first theme as the <img> source.
[ -z "$light" ] && light="$OUTPUT_DIR/star-history-${themes[0]}.svg"

# Single PNG (follows the probe/first theme) for registries that cannot render
# SVG.
png="$OUTPUT_DIR/star-history.png"
cp "$TMP/star-history.png" "$png"
files="${files}${png}"$'\n'

# Persist the new signature so the next run can detect no-change.
cp "$TMP/new.sig" "$SIGFILE"

echo "changed=true" >> "$GITHUB_OUTPUT"
echo "light=$light" >> "$GITHUB_OUTPUT"
echo "dark=$dark" >> "$GITHUB_OUTPUT"
echo "png=$png" >> "$GITHUB_OUTPUT"
{
  echo "files<<STAR_HISTORY_EOF"
  printf '%s' "$files"
  echo "STAR_HISTORY_EOF"
} >> "$GITHUB_OUTPUT"
