#!/bin/bash
# Builds tools/AppIcon.icns from tools/icon_1024.png (must be >=1024px).
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="tools/icon_1024.png"
SET="tools/AppIcon.iconset"

rm -rf "$SET"
mkdir -p "$SET"

# Required sizes for a macOS .icns.
sips -z 16 16     "$SRC" --out "$SET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$SRC" --out "$SET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$SRC" --out "$SET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$SRC" --out "$SET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$SRC" --out "$SET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$SRC" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$SET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$SRC" --out "$SET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$SET/icon_512x512.png"    >/dev/null
sips -z 1024 1024 "$SRC" --out "$SET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$SET" -o tools/AppIcon.icns
rm -rf "$SET"
echo "wrote tools/AppIcon.icns"
