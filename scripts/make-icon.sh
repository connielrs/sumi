#!/bin/bash
# Genera Resources/AppIcon.icns a partir de Resources/icon.svg.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

qlmanage -t -s 1024 -o "$TMP" Resources/icon.svg >/dev/null 2>&1
BASE="$TMP/icon.svg.png"
if [ ! -f "$BASE" ]; then
  echo "No se pudo convertir el SVG a PNG" >&2
  exit 1
fi

SET="$TMP/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$BASE" --out "$SET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$BASE" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Ícono listo: Resources/AppIcon.icns"
