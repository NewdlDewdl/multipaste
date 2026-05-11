#!/usr/bin/env bash
# Generate the .icns from icon-1024.png using sips + iconutil. Output:
# Resources/Multipaste.icns
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SRC="Resources/icon-1024.png"
if [[ ! -f "$SRC" ]]; then
    echo "==> generating icon-1024.png"
    swift scripts/make-icon.swift
fi

ICONSET="Resources/Multipaste.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

for SIZE in 16 32 128 256 512; do
    sips -z $SIZE $SIZE "$SRC" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z $DOUBLE $DOUBLE "$SRC" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/Multipaste.icns
rm -rf "$ICONSET"

echo "✓ Resources/Multipaste.icns"
ls -lh Resources/Multipaste.icns
