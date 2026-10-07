#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Invalid VERSION: $VERSION" >&2; exit 1
fi
if [[ "${MYBATTERY_RELEASE:-0}" == 1 ]]; then
    TAG="$(git describe --exact-match --tags --match "mybattery-v$VERSION" HEAD 2>/dev/null || true)"
    [[ "$TAG" == "mybattery-v$VERSION" && -z "$(git status --porcelain)" ]] || {
        echo "Release requires a clean checkout at mybattery-v$VERSION" >&2; exit 1;
    }
fi
swift build -c release
BIN="$(swift build -c release --show-bin-path)/MyBattery"
APP="build/MyBattery.app"
# Only replace the generated bundle belonging to this script.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MyBattery"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/bundle/. "$APP/Contents/Resources/"
REV="$(git rev-parse --short HEAD)"
BUILD="$(git rev-list --count HEAD)"
FULL_VERSION="$VERSION"
if [[ "${MYBATTERY_RELEASE:-0}" != 1 ]]; then
    FULL_VERSION="$VERSION+g$REV"
    [[ -z "$(git status --porcelain)" ]] || FULL_VERSION="$FULL_VERSION.dirty"
fi
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$APP/Contents/Info.plist"
plutil -replace StatusItemKitVersion -string "$FULL_VERSION" "$APP/Contents/Info.plist"
SIGN_ID="${MYBATTERY_SIGN_ID:-${STATUSITEMKIT_SIGN_ID:-}}"
if [[ -z "$SIGN_ID" ]]; then
    SIGN_ID="$(security find-identity -p codesigning 2>/dev/null | awk '/StatusItemKit Local Signing/ {print $2; exit}')" || true
fi
codesign --force --sign "${SIGN_ID:--}" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP ($FULL_VERSION)"
