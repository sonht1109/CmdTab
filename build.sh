#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./scripts/package-app.sh

APP="dist/CmdTab.app"
# Local ad-hoc signature (self-signed cert in the local keychain). Not for
# distribution — CI handles Developer ID signing/notarization for releases.
codesign --force --sign "CmdTab Codesign" --keychain "$HOME/Library/Keychains/cmdtab-signing.keychain-db" "$APP" >/dev/null 2>&1 || true

echo "Run with: open $APP"
