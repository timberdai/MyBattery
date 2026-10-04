#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release >/dev/null
BIN="$(swift build -c release --show-bin-path)/BatteryTime"
APP="$HOME/Applications/Battery Time.app"
cp "$BIN" "$APP/Contents/MacOS/BatteryTime"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
pkill -x BatteryTime || true
sleep 0.5
/usr/bin/open "$APP"
echo "✓ Dev reload complete in <2s"
