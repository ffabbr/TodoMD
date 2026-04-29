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
mkdir -p "$MOUNT_DIR/.background"

python3 - <<'PY' "$MOUNT_DIR/.background/background.png"
from pathlib import Path
import sys
from PIL import Image, ImageDraw

out = Path(sys.argv[1])
width, height = 720, 430
img = Image.new("RGB", (width, height), (255, 255, 255))
draw = ImageDraw.Draw(img)

arrow = (37, 45, 56)
center_y = 210
start_x = 250
end_x = 470
line_width = 24
head = 70

draw.line((start_x, center_y, end_x - head, center_y), fill=arrow, width=line_width)
draw.polygon(
    [
        (end_x - head, center_y - 60),
        (end_x + 54, center_y),
        (end_x - head, center_y + 60),
    ],
    fill=arrow,
)

img.save(out)
PY

SetFile -a V "$MOUNT_DIR/.background"

osascript <<APPLESCRIPT
set dmgFolder to POSIX file "$MOUNT_DIR" as alias
set bgPic to POSIX file "$MOUNT_DIR/.background/background.png" as alias
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
    set background picture of viewOptions to bgPic
    set position of item "$APP" of dmgWindow to {145, 210}
    set position of item "Applications" of dmgWindow to {575, 210}
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
