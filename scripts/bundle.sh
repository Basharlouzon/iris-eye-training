#!/bin/bash
# Builds Iris.release and assembles Iris.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Iris.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Iris "$APP/Contents/MacOS/Iris"

if [ -f resources/AppIcon.icns ]; then
  cp resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Iris</string>
    <key>CFBundleDisplayName</key>
    <string>Iris</string>
    <key>CFBundleIdentifier</key>
    <string>com.basharlouzon.irisblinkeyetraining</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Iris</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Iris needs to control the Music app so you can play, pause and skip tracks from your notch.</string>
</dict>
</plist>
PLIST

codesign --force -s - "$APP"
echo "Built $APP"
