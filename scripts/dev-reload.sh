#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

START_TIME=$(python3 -c 'import time; print(time.time())')
# Build/sign once, then install that exact bundle so versions and hashes agree.
./scripts/build-app.sh
BUILT_APP="build/MyBattery.app"
APP="$HOME/Applications/MyBattery.app"
codesign --verify --strict "$BUILT_APP"
pkill -x MyBattery || true
mkdir -p "$HOME/Applications"
ditto "$BUILT_APP" "$APP"
codesign --verify --strict "$APP"
/usr/bin/open "$APP"
END_TIME=$(python3 -c 'import time; print(time.time())')
ELAPSED=$(python3 -c "print(f'{$END_TIME - $START_TIME:.2f}')")
echo "Dev reload complete in ${ELAPSED}s (MyBattery; copied signed build bundle)"
