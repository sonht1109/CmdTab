#!/bin/bash
# Regenerate Resources/CmdTab.icns from docs/logo-v2.png and the menu bar icons
# from docs/menu-bar-icon-*.png. Run whenever any logo changes, then commit.
set -euo pipefail
cd "$(dirname "$0")/.."

# --- App icon (.icns) ---
SRC="docs/logo-v2.png"
ICONSET="$(mktemp -d)/CmdTab.iconset"
mkdir -p "$ICONSET"
SQUARE="$(mktemp -d)/logo-square.png"
OUT="Resources/CmdTab.icns"

# The logo art sits on a transparent 3:2 canvas with empty margins — crop to
# the visible content (plus a small breathing margin) and pad to a square
# canvas, since .icns slots are square.
python3 - "$SRC" "$SQUARE" <<'PY'
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGBA')
px = im.load()
w, h = im.size
minx, miny, maxx, maxy = w, h, 0, 0
for y in range(h):
    for x in range(w):
        if px[x, y][3] > 8:
            minx, miny = min(minx, x), min(miny, y)
            maxx, maxy = max(maxx, x), max(maxy, y)
m = round((maxx - minx + 1) * 0.02)  # small margin so edges don't clip
box = (max(0, minx - m), max(0, miny - m), min(w, maxx + m), min(h, maxy + m))
im = im.crop(box)
size = max(im.size)
canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
canvas.paste(im, ((size - im.size[0]) // 2, (size - im.size[1]) // 2))
canvas.save(out)
print(f"Wrote {out} ({size}x{size})")
PY

sips -z 16 16   "$SQUARE" --out "$ICONSET/icon_16x16.png"        >/dev/null
sips -z 32 32   "$SQUARE" --out "$ICONSET/icon_16x16@2x.png"     >/dev/null
sips -z 32 32   "$SQUARE" --out "$ICONSET/icon_32x32.png"        >/dev/null
sips -z 64 64   "$SQUARE" --out "$ICONSET/icon_32x32@2x.png"     >/dev/null
sips -z 128 128 "$SQUARE" --out "$ICONSET/icon_128x128.png"      >/dev/null
sips -z 256 256 "$SQUARE" --out "$ICONSET/icon_128x128@2x.png"   >/dev/null
sips -z 256 256 "$SQUARE" --out "$ICONSET/icon_256x256.png"      >/dev/null
sips -z 512 512 "$SQUARE" --out "$ICONSET/icon_256x256@2x.png"   >/dev/null
sips -z 512 512 "$SQUARE" --out "$ICONSET/icon_512x512.png"      >/dev/null
sips -z 1024 1024 "$SQUARE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"

# --- Menu bar icons ---
# Trim padding, strip the black background from the white export (white glyph
# on black -> white glyph with alpha), and size to 36px tall (@2x of 18pt).
python3 - docs/menu-bar-icon-dark.png docs/menu-bar-icon-white.png <<'PY'
import sys
from PIL import Image

TARGET_H = 36

def process(src, out, is_alpha):
    im = Image.open(src)
    im = im.convert('RGBA' if is_alpha else 'RGB')
    px = im.load()
    w, h = im.size
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            if is_alpha:
                r, g, b, a = px[x, y]
                visible = a > 40 and (r < 245 or g < 245 or b < 245)
            else:
                r, g, b = px[x, y]
                visible = max(r, g, b) > 40  # white glyph on black
            if visible:
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)
    m = int((maxy - miny) * 0.04)  # small margin so edges don't touch the bar
    box = (max(0, minx - m), max(0, miny - m), min(w, maxx + m), min(h, maxy + m))
    im = im.crop(box)
    if not is_alpha:
        lum = im.convert('L')
        im = Image.new('RGBA', im.size, (255, 255, 255, 0))
        im.putalpha(lum)
    im = im.resize((round(TARGET_H * im.size[0] / im.size[1]), TARGET_H), Image.LANCZOS)
    im.save(out)
    print(f"Wrote {out} ({im.size[0]}x{im.size[1]})")

process(sys.argv[1], 'Resources/MenuBarIcon-Dark.png', True)
process(sys.argv[2], 'Resources/MenuBarIcon-White.png', False)
PY
