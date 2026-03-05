#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="ClaudeSessionTaskbar"

# Find a compatible SDK (prefer 15.x over 26.x for Swift 6.1 compatibility)
SDK_DIR="/Library/Developer/CommandLineTools/SDKs"
SDK=$(ls -d "${SDK_DIR}"/MacOSX15*.sdk 2>/dev/null | sort -V | tail -1)
if [ -z "$SDK" ]; then
    SDK=$(xcrun --show-sdk-path 2>/dev/null)
fi

echo "Building Claude Session Taskbar..."
echo "  SDK: $(basename "$SDK")"
echo ""

swiftc \
  -O \
  -module-name "$APP_NAME" \
  -swift-version 5 \
  -sdk "$SDK" \
  -target arm64-apple-macosx13.0 \
  -framework Security \
  Sources/Theme.swift \
  Sources/UsageTracker.swift \
  Sources/PopoverView.swift \
  Sources/AppDelegate.swift \
  Sources/main.swift \
  -o "$APP_NAME"

# Create .app bundle
APP_DIR="${APP_NAME}.app/Contents"

rm -rf "${APP_NAME}.app"
mkdir -p "${APP_DIR}/MacOS"
mkdir -p "${APP_DIR}/Resources"

# Copy executable
cp "${APP_NAME}" "${APP_DIR}/MacOS/"
rm -f "${APP_NAME}"

# Create Info.plist
cat > "${APP_DIR}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Claude Session Taskbar</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Session Taskbar</string>
    <key>CFBundleIdentifier</key>
    <string>com.claude.session-taskbar</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeSessionTaskbar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo ""
echo "================================================"
echo "  Claude Session Taskbar - Build Complete"
echo "================================================"
echo ""
echo "  Run now:     open ${APP_NAME}.app"
echo ""

# Install option
if [ "$1" = "--install" ]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
    cp -R "${APP_NAME}.app" "$INSTALL_DIR/"
    echo "  Installed to: ~/Applications/${APP_NAME}.app"
    echo ""

    # Add to Login Items via AppleScript
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"${INSTALL_DIR}/${APP_NAME}.app\", hidden:false}" 2>/dev/null && \
        echo "  Added to Login Items (starts on boot)" || \
        echo "  Note: Add to Login Items manually via System Settings > General > Login Items"
    echo ""
fi
