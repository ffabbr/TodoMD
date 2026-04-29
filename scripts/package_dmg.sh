#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="TodoMD"
APP="$APP_NAME.app"
VOL_NAME="TodoMD Installer"
OUT_DIR="dist"
OUT_DMG="$OUT_DIR/$APP_NAME.dmg"

./build.sh

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

TMP_DIR="$(mktemp -d)"
RW_DMG="$TMP_DIR/$APP_NAME-rw.dmg"
MOUNT_DIR="$TMP_DIR/mount"

cleanup() {
    if mount | grep -q "$MOUNT_DIR"; then
        hdiutil detach "$MOUNT_DIR" -quiet || true
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

hdiutil create \
    -size 24m \
    -fs HFS+ \
    -volname "$VOL_NAME" \
    "$RW_DMG" \
    -quiet

mkdir -p "$MOUNT_DIR"
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

cp -R "$APP" "$MOUNT_DIR/"
ln -s /Applications "$MOUNT_DIR/Applications"

osascript <<APPLESCRIPT
set dmgFolder to POSIX file "$MOUNT_DIR" as alias
tell application "Finder"
    open dmgFolder
    delay 1
    set dmgWindow to container window of dmgFolder
    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
        set the bounds of dmgWindow to {120, 120, 840, 550}
    set viewOptions to the icon view options of dmgWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 144
    set position of item "$APP" of dmgWindow to {145, 185}
    set position of item "Applications" of dmgWindow to {575, 185}
    delay 2
    close dmgWindow
end tell
APPLESCRIPT

sync
test -f "$MOUNT_DIR/.DS_Store"
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUT_DMG" \
    -quiet

hdiutil verify "$OUT_DMG"
echo "Built $OUT_DMG"
