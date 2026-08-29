#!/bin/bash
# Build the release binary and assemble dist/CmdTab.app (unsigned).
# Shared by build.sh (local dev) and GitHub Actions (CI).
set -euo pipefail
cd "$(dirname "$0")/.."

# Prefer a universal (arm64 + x86_64) binary so both Apple Silicon and Intel
# Macs can run it. Needs full Xcode (macOS CI runners have it); falls back to
# the native arch when unavailable (e.g. local Command Line Tools only).
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
  BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/CmdTab"
else
  echo "Universal build not available, falling back to native arch"
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/CmdTab"
fi

APP="dist/CmdTab.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CmdTab"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/CmdTab.icns "$APP/Contents/Resources/CmdTab.icns"
echo "App at: $APP"
