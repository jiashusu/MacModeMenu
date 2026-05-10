#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Mac模式.app"
APP_DIR="$ROOT/build/$APP_NAME"
BIN_DIR="$APP_DIR/Contents/MacOS"

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR"
cp "$ROOT/.build/release/MacModeMenu" "$BIN_DIR/MacModeMenu"
cp "$ROOT/Bundle/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "$APP_DIR"
