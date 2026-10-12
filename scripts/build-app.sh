#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
. ./version.env
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
if [[ "${sdk_version%%.*}" -lt 27 ]]; then
  printf '%s\n' "Prewarm requires Xcode with the macOS 27 SDK (selected: $sdk_version)." >&2
  exit 1
fi
xcrun --find actool >/dev/null
./scripts/render-icons.sh
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
staging="$(mktemp -d "$PWD/build/app-staging.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
app_dir="$staging/Prewarm.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Prewarm" "$app_dir/Contents/MacOS/Prewarm"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
cp README.md "$app_dir/Contents/Resources/README.md"
cp assets/Prewarm.icns "$app_dir/Contents/Resources/Prewarm.icns"
xcrun actool build/Prewarm.xcassets --compile "$app_dir/Contents/Resources" \
  --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon \
  --output-partial-info-plist build/icon-info.plist --output-format human-readable-text
cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.ethan.Prewarm</string>
<key>CFBundleName</key><string>Prewarm</string>
<key>CFBundleDisplayName</key><string>Prewarm</string>
<key>CFBundleExecutable</key><string>Prewarm</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$PREWARM_VERSION</string>
<key>CFBundleVersion</key><string>$PREWARM_BUILD</string>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Ethan Proia. Based on macos-mic-keepwarm by Drew Burchfield (MIT).</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Prewarm keeps your selected microphone warm. Audio is immediately discarded, never saved or transmitted.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Merge build/icon-info.plist" "$app_dir/Contents/Info.plist"
codesign --force --sign "${PREWARM_SIGNING_IDENTITY:--}" --identifier com.ethan.Prewarm "$app_dir"
codesign --verify --strict "$app_dir"
plutil -lint "$app_dir/Contents/Info.plist"
rm -rf build/Prewarm.app
mv "$app_dir" build/Prewarm.app
printf '%s\n' "$PWD/build/Prewarm.app"
