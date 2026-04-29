#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="TodoMD"
APP="$APP_NAME.app"
VOL_NAME="TodoMD"
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
from PIL import Image, ImageDraw, ImageFont

out = Path(sys.argv[1])
width, height = 720, 430
img = Image.new("RGB", (width, height), (31, 36, 44))
draw = ImageDraw.Draw(img)

for y in range(height):
    t = y / max(height - 1, 1)
    r = int(35 + 12 * t)
    g = int(42 + 14 * t)
    b = int(52 + 18 * t)
    draw.line([(0, y), (width, y)], fill=(r, g, b))

draw.rounded_rectangle((32, 30, width - 32, height - 30), radius=26, outline=(76, 86, 101), width=1)
draw.rounded_rectangle((285, 132, 435, 282), radius=42, fill=(43, 50, 60), outline=(84, 95, 111), width=1)
draw.line((340, 207, 380, 207), fill=(116, 125, 139), width=8)
draw.polygon([(388, 186), (418, 207), (388, 228)], fill=(28, 185, 142))

title_font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 30)
body_font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 16)
small_font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 13)

draw.text((42, 44), "TodoMD", fill=(245, 247, 250), font=title_font)
draw.text((42, 84), "Drag the app into Applications", fill=(177, 187, 199), font=body_font)
draw.text((144, 326), "TodoMD", fill=(219, 225, 232), font=small_font, anchor="mm")
draw.text((576, 326), "Applications", fill=(219, 225, 232), font=small_font, anchor="mm")

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
    set icon size of viewOptions to 96
    set background picture of viewOptions to bgPic
    set position of item "$APP" of dmgWindow to {144, 214}
    set position of item "Applications" of dmgWindow to {576, 214}
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
