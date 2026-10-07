#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
VERSION="$(cat VERSION)"
ARCH="$(uname -m)"
DMG="build/MyBattery-$VERSION-$ARCH.dmg"
TASK_STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$TASK_STAGE_DIR"' EXIT

ditto build/MyBattery.app "$TASK_STAGE_DIR/MyBattery.app"
ln -s /Applications "$TASK_STAGE_DIR/Applications"
cat > "$TASK_STAGE_DIR/Read Me.txt" <<'TEXT'
MyBattery

将 MyBattery.app 拖入 Applications，然后从“应用程序”打开。
Drag MyBattery.app onto Applications, then open it from Applications.

若首次打开被拦截：系统设置 > 隐私与安全性 > 仍要打开。
If macOS blocks the first launch: System Settings > Privacy & Security > Open Anyway.

https://github.com/timberdai/MyBattery
TEXT
hdiutil create -volname "MyBattery $VERSION" -srcfolder "$TASK_STAGE_DIR" -format UDZO -ov "$DMG"
(cd build && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
./scripts/verify-dmg.sh "$DMG"
echo "Packaged $DMG"
