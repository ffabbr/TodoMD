#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="TodoMD.app"
EXEC="TodoMD"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/TodoMD.icns "$APP/Contents/Resources/TodoMD.icns"

swiftc -O \
    -target arm64-apple-macos14.0 \
    -parse-as-library \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/$EXEC"

strip -x "$APP/Contents/MacOS/$EXEC"

# Ad-hoc sign so Gatekeeper accepts the local build.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built ./$APP"
echo "Run with: open ./$APP"
