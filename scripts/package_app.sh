#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/outputs/SolixBar.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
cp "$ROOT/Bundle/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/.build/debug/SolixBar" "$MACOS/SolixBar"
if [ -f "$ROOT/Assets/SolixBar.icns" ]; then
  cp "$ROOT/Assets/SolixBar.icns" "$RESOURCES/SolixBar.icns"
fi
if [ -f "$ROOT/Assets/SolixBar.png" ]; then
  cp "$ROOT/Assets/SolixBar.png" "$RESOURCES/SolixBar.png"
fi
chmod +x "$MACOS/SolixBar"
printf "APPL????" > "$CONTENTS/PkgInfo"
touch "$APP"

echo "$APP"
