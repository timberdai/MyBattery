#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release >/dev/null
BIN="$(swift build -c release --show-bin-path)/MyBattery"
APP="$HOME/Applications/MyBattery.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Update Info.plist
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>MyBattery</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.timberdai.MyBattery</string>
	<key>CFBundleName</key>
	<string>MyBattery</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>0.1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF

# Copy icon if available
if [ -f "$HOME/Applications/Battery Time.app/Contents/Resources/AppIcon.icns" ]; then
    cp "$HOME/Applications/Battery Time.app/Contents/Resources/AppIcon.icns" "$APP/Contents/Resources/" 2>/dev/null || true
fi

cp "$BIN" "$APP/Contents/MacOS/MyBattery"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
pkill -x BatteryTime || true
pkill -x MyBattery || true
sleep 0.5
/usr/bin/open "$APP"
echo "✓ Dev reload complete in <2s (MyBattery)"
