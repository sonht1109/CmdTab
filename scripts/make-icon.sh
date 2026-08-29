#!/bin/bash
# Regenerate Resources/CmdTab.icns from docs/logo.png.
# Run this whenever the logo changes, then commit the new .icns.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="docs/logo.png"
ICONSET="$(mktemp -d)/CmdTab.iconset"
mkdir -p "$ICONSET"
OUT="Resources/CmdTab.icns"

sips -z 16 16   "$SRC" --out "$ICONSET/icon_16x16.png"        >/dev/null
sips -z 32 32   "$SRC" --out "$ICONSET/icon_16x16@2x.png"     >/dev/null
sips -z 32 32   "$SRC" --out "$ICONSET/icon_32x32.png"        >/dev/null
sips -z 64 64   "$SRC" --out "$ICONSET/icon_32x32@2x.png"     >/dev/null
sips -z 128 128 "$SRC" --out "$ICONSET/icon_128x128.png"      >/dev/null
sips -z 256 256 "$SRC" --out "$ICONSET/icon_128x128@2x.png"   >/dev/null
sips -z 256 256 "$SRC" --out "$ICONSET/icon_256x256.png"      >/dev/null
sips -z 512 512 "$SRC" --out "$ICONSET/icon_256x256@2x.png"   >/dev/null
sips -z 512 512 "$SRC" --out "$ICONSET/icon_512x512.png"      >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"
