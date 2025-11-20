#!/bin/bash

# Build script for Dropzone Clone macOS app

echo "🔨 Building Dropzone app..."

# Clean previous builds
rm -rf .build/release
rm -rf "Dropzone Clone.app"

# Build the release version
echo "📦 Building release version..."
swift build -c release

# Create app bundle structure
echo "🎨 Creating app bundle..."
APP_NAME="Dropzone"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the executable
cp .build/release/Dropzone_clone "$MACOS_DIR/Dropzone_clone"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Dropzone_clone</string>
    <key>CFBundleIdentifier</key>
    <string>com.dropzone.clone</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Dropzone</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
EOF

# Create a simple icon (you can replace this with a real icon later)
# For now, we'll use the system's generic app icon
touch "$RESOURCES_DIR/AppIcon.icns"

echo "✅ Build complete!"
echo ""
echo "📍 App location: $(pwd)/$APP_BUNDLE"
echo ""
echo "To install:"
echo "1. Drag '$APP_BUNDLE' to your Applications folder"
echo "2. Double-click to launch"
echo ""
echo "Note: On first launch, you may need to:"
echo "- Right-click the app and select 'Open'"
echo "- Go to System Settings > Privacy & Security and allow the app to run"