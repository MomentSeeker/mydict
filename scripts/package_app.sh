#!/bin/bash
# Build MyDict.app — a real, double-clickable macOS app bundle with an icon.
#
#   ./scripts/package_app.sh [output-dir]
#
# Produces <output-dir>/MyDict.app (default: ./dist). Offline, no signing
# identity required (uses an ad-hoc signature so it launches locally).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT_DIR="${1:-dist}"
APP="$OUT_DIR/MyDict.app"
BUILD_TMP="build"

EXECUTABLE_NAME="MyDictApp"
RESOURCE_BUNDLE="MyDict_MyDictCore.bundle"

echo "==> Building release binary"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> Generating app icon"
ICONSET="$BUILD_TMP/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
swift "scripts/make_appicon.swift" "$ICONSET"
mkdir -p "$BUILD_TMP"
iconutil -c icns "$ICONSET" -o "$BUILD_TMP/AppIcon.icns"

echo "==> Assembling bundle at $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN_DIR/$EXECUTABLE_NAME" "$APP/Contents/MacOS/$EXECUTABLE_NAME"
cp -R "$BIN_DIR/$RESOURCE_BUNDLE" "$APP/Contents/Resources/$RESOURCE_BUNDLE"
cp "$BUILD_TMP/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MyDict</string>
    <key>CFBundleDisplayName</key>
    <string>MyDict</string>
    <key>CFBundleIdentifier</key>
    <string>com.mydict.app</string>
    <key>CFBundleExecutable</key>
    <string>MyDictApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.reference</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "   (codesign skipped)"

echo "==> Done: $APP"
echo "    Launch with: open \"$APP\""
