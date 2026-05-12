#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Mac模式.app"
APP_DIR="$ROOT/build/$APP_NAME"
BIN_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RESOURCES_DIR"
cp "$ROOT/.build/release/MacModeMenu" "$BIN_DIR/MacModeMenu"
cp "$ROOT/Bundle/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Bundle/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

SIGN_IDENTITY="${MACMODEMENU_CODESIGN_IDENTITY:-MacModeMenu Local Code Signing}"
if security find-identity -v -p codesigning | grep -Fq "$SIGN_IDENTITY"; then
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    codesign --force --deep --sign - "$APP_DIR"
    echo "warning: code signing identity '$SIGN_IDENTITY' not found; used full ad-hoc app signing instead." >&2
    echo "warning: for the most stable Screen Recording permission, create a persistent local or Apple code signing certificate." >&2
    echo "warning: run scripts/create_local_codesign_identity.sh once, then rebuild." >&2
fi

echo "$APP_DIR"
