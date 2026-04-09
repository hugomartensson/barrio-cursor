#!/usr/bin/env bash
# Fetches DM Sans family TTFs used by the app (display Black, weights, Italic).
# Run from this directory: ./fetch-portal-fonts.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

EXPORTS="https://raw.githubusercontent.com/googlefonts/dm-fonts/main/Sans/Exports"
FONTS_TTF="https://raw.githubusercontent.com/googlefonts/dm-fonts/main/Sans/fonts/ttf"

for name in DMSans-Regular DMSans-Medium DMSans-Bold DMSans-Italic; do
  curl -sL -o "${name}.ttf" "$EXPORTS/${name}.ttf"
  echo "Downloaded ${name}.ttf"
done
curl -sL -o "DMSans-Black.ttf" "$FONTS_TTF/DMSans-Black.ttf"
echo "Downloaded DMSans-Black.ttf"
