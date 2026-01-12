#!/bin/bash
# Build Sticky Notes app

APP_NAME="Sticky Notes"
APP_DIR="/Users/aftab/Documents/bob-the/micky-notes"
SRC_DIR="$APP_DIR/StickyNotesMac"
BUILD_DIR="$APP_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"

echo "🔨 Building $APP_NAME..."

# Clean
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

# Compile
cd "$SRC_DIR"
swiftc -o "$MACOS_DIR/$APP_NAME" \
    StickyNotesAppMain.swift \
    Models/*.swift \
    Views/*.swift \
    ViewModels/*.swift \
    Services/*.swift \
    Documents/*.swift \
    -parse-as-library \
    -framework SwiftUI \
    -framework AppKit \
    -framework Foundation \
    -framework Network \
    -lsqlite3

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Sticky Notes</string>
    <key>CFBundleIdentifier</key>
    <string>com.stickynotes.mac</string>
    <key>CFBundleName</key>
    <string>Sticky Notes</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Required to sync notes with Windows devices.</string>
</dict>
</plist>
PLIST

echo "✅ Build complete!"
echo "📍 Location: $APP_BUNDLE"
