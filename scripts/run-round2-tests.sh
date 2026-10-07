#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TASK_TEST_DIR"' EXIT
swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" -D DIRECT_REGRESSION -parse-as-library \
    Sources/BatteryTimeCore/*.swift \
    Sources/MyBattery/SMCFansReader.swift Sources/MyBattery/PlugInGlowController.swift Sources/MyBattery/ReadOnlyRowView.swift \
    Tests/BatteryTimeCoreTests/Round2Cases.swift Tests/BatteryTimeCoreTests/LocalizationCases.swift Tests/MyBatteryTests/SMCCases.swift Tests/MyBatteryTests/GlowCases.swift \
    scripts/regression-main.swift -o "$TASK_TEST_DIR/Round2Regression"
"$TASK_TEST_DIR/Round2Regression" "$@"
