#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FONT_DIR="$ROOT_DIR/assets/fonts"
mkdir -p "$FONT_DIR"

# Explicitly supplied font files take precedence over pinned clean-runner copies.
fetch_font() {
  local target="$1" sha="$2" url="$3"
  local path="$FONT_DIR/$target"
  if [[ ! -f "$path" ]]; then
    curl --fail --location --retry 3 "$url" --output "$path"
    [[ "$(git hash-object "$path")" == "$sha" ]] || {
      echo "Font integrity check failed: $target" >&2
      exit 1
    }
  fi
  python3 - "$path" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
if p.stat().st_size < 20000 or p.read_bytes()[:4] not in (b'\x00\x01\x00\x00', b'OTTO', b'true'):
    raise SystemExit('Not a valid TTF/OTF font: ' + p.name)
PY
}

fetch_font "Vazir-Regular.ttf" \
  "7fd8033aecca4c5946ebd91bd3ac8af380839be4" \
  "https://raw.githubusercontent.com/JohnAdib/vazir-font/68833b2c255d96d38b517acdf327b6367e9e8d67/dist/Vazir-Regular.ttf"
fetch_font "Far_TitrBd.ttf" \
  "f8e7c5e4e992744de431426387997f27f8c5797e" \
  "https://raw.githubusercontent.com/negin-amiri/my-dijikala-clone/a4eead8038bb56a38bc01ec8836b0b169415ebae/fonts/titr/Far_TitrBd.ttf"
fetch_font "Far_Nazanin.ttf" \
  "39635643bf2557daa56dcb962ac5a9593cecf42b" \
  "https://raw.githubusercontent.com/mohammadhasananisi/personal_accountant/26f09ce3e414f5d6293f47296ab0dfd9af283d7e/assets/fonts/Far_Nazanin.ttf"
fetch_font "Rooznameh.ttf" \
  "0ebdf5d7639c5c87c477cc34751b224729f0749a" \
  "https://raw.githubusercontent.com/matinking82/mercyleftbehind/67ff64fe49a41efacaaa2bab45eda9ff5273aa5c/assets/fonts/Rooznameh.ttf"

if [[ ! -f "$FONT_DIR/OFL-Vazir.txt" ]]; then
  curl --fail --location --retry 3 \
    "https://raw.githubusercontent.com/JohnAdib/vazir-font/68833b2c255d96d38b517acdf327b6367e9e8d67/OFL.txt" \
    --output "$FONT_DIR/OFL-Vazir.txt"
fi
echo "All four Persian font assets are available."
