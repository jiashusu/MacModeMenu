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

echo "$APP_DIR"
