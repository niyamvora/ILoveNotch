#!/bin/bash
# Assemble a proper OpenNotch.app (LSUIElement, no Dock icon).
# Needed once we add Reminders/Notes/Camera features that require usage strings.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/OpenNotch"
APP="OpenNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/OpenNotch"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>OpenNotch</string>
  <key>CFBundleIdentifier</key><string>cafe.opennotch.app</string>
  <key>CFBundleExecutable</key><string>OpenNotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSRemindersFullAccessUsageDescription</key><string>OpenNotch shows and edits your reminders in the notch.</string>
  <key>NSAppleEventsUsageDescription</key><string>OpenNotch reads and writes your notes via the Notes app.</string>
  <key>NSCameraUsageDescription</key><string>OpenNotch shows a quick camera mirror.</string>
</dict></plist>
PLIST
echo "Built $APP"
