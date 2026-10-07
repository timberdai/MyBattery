#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
cd "$(dirname "$0")/.."
DMG="${1:?Usage: scripts/verify-dmg.sh path/to/MyBattery.dmg}"
TASK_MOUNT_DIR="$(mktemp -d)"
TASK_ATTACHED=0
cleanup() {
    if [[ "$TASK_ATTACHED" == 1 ]]; then hdiutil detach "$TASK_MOUNT_DIR" >/dev/null; fi
    rmdir "$TASK_MOUNT_DIR"
}
trap cleanup EXIT
hdiutil verify "$DMG"
hdiutil attach -readonly -nobrowse -mountpoint "$TASK_MOUNT_DIR" "$DMG" >/dev/null
TASK_ATTACHED=1
APP="$TASK_MOUNT_DIR/MyBattery.app"
[[ "$(readlink "$TASK_MOUNT_DIR/Applications")" == /Applications ]]
[[ "$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")" == "$(cat VERSION)" ]]
codesign --verify --strict "$APP"
cmp build/MyBattery.app/Contents/MacOS/MyBattery "$APP/Contents/MacOS/MyBattery"
echo "DMG app, version, signature and Applications shortcut verified"
