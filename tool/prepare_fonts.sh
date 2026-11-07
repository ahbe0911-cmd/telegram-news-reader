#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONT_DIR="$ROOT_DIR/assets/fonts"
FONT_COMMIT="68833b2c255d96d38b517acdf327b6367e9e8d67"
FONT_BLOB_SHA="7fd8033aecca4c5946ebd91bd3ac8af380839be4"

mkdir -p "$FONT_DIR"

curl --fail --location --retry 3 \
  "https://raw.githubusercontent.com/JohnAdib/vazir-font/$FONT_COMMIT/dist/Vazir-Regular.ttf" \
  --output "$FONT_DIR/Vazir-Regular.ttf"

ACTUAL_BLOB_SHA="$(git hash-object "$FONT_DIR/Vazir-Regular.ttf")"
if [[ "$ACTUAL_BLOB_SHA" != "$FONT_BLOB_SHA" ]]; then
  echo "Vazir font integrity check failed." >&2
  exit 1
fi

curl --fail --location --retry 3 \
  "https://raw.githubusercontent.com/JohnAdib/vazir-font/$FONT_COMMIT/OFL.txt" \
  --output "$FONT_DIR/OFL-Vazir.txt"

echo "Vazir font prepared and verified."
