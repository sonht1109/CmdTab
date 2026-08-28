#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/CmdTab"

APP="dist/CmdTab.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/CmdTab"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "CmdTab Codesign" --keychain "$HOME/Library/Keychains/cmdtab-signing.keychain-db" "$APP" >/dev/null 2>&1 || true

echo "Done. App at: $APP"
echo "Run with: open $APP"
