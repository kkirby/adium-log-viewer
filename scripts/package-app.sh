#!/usr/bin/env bash
# Builds a universal (arm64 + x86_64) release binary and wraps it in an .app bundle,
# then zips it. Usage: scripts/package-app.sh [version]   (default: 0.0.0-dev)
set -euo pipefail

VERSION="${1:-0.0.0-dev}"
VERSION="${VERSION#v}"
APP_NAME="AdiumLogViewer"
DISPLAY_NAME="Adium Log Viewer"
BUNDLE_ID="com.kkirby.AdiumLogViewer"
DIST="dist"

cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="$DIST/$APP_NAME.app"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature (no Developer ID); required for arm64 binaries to launch.
codesign --force --deep --sign - "$APP"

ZIP="$DIST/$APP_NAME-$VERSION-macOS.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP"
