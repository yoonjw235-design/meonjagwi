#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
mkdir -p dist/ChiikawaDesk.app/Contents/MacOS
cp .build/release/ChiikawaDesk dist/ChiikawaDesk.app/Contents/MacOS/ChiikawaDesk
mkdir -p dist/ChiikawaDesk.app/Contents/Resources
cp -R .build/release/ChiikawaDesk_ChiikawaDesk.bundle/Resources dist/ChiikawaDesk.app/Contents/Resources/
swift scripts/make-app-icon.swift Sources/ChiikawaDesk/Resources/MenuBarBanner.png .build/Meonjakgwi.iconset
iconutil -c icns .build/Meonjakgwi.iconset -o dist/ChiikawaDesk.app/Contents/Resources/AppIcon.icns
cat > dist/ChiikawaDesk.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ChiikawaDesk</string>
<key>CFBundleIdentifier</key><string>local.chiikawa.desk</string>
<key>CFBundleName</key><string>먼작귀</string>
<key>CFBundleDisplayName</key><string>먼작귀</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - dist/ChiikawaDesk.app
echo "완료: dist/ChiikawaDesk.app"
