#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
. ./version.env
if [[ -n "$(git status --porcelain)" ]]; then
  printf '%s\n' 'Release packaging requires a clean Git worktree.' >&2
  exit 1
fi
./scripts/build-app.sh
app_dir="$PWD/build/Prewarm.app"
plist="$app_dir/Contents/Info.plist"
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
[[ "$(read_plist CFBundleShortVersionString)" == "$PREWARM_VERSION" ]]
[[ "$(read_plist CFBundleVersion)" == "$PREWARM_BUILD" ]]
[[ "$(read_plist CFBundleIdentifier)" == com.ethan.Prewarm ]]
[[ "$(read_plist CFBundleIconName)" == AppIcon ]]
for resource in LICENSE README.md Prewarm.icns AppIcon.icns Assets.car; do
  [[ -s "$app_dir/Contents/Resources/$resource" ]]
done
architectures="$(lipo -archs "$app_dir/Contents/MacOS/Prewarm")"
archive_arch="${architectures// /-}"
release_dir="$PWD/build/releases"
mkdir -p "$release_dir"
archive="$release_dir/Prewarm-$PREWARM_VERSION-$archive_arch.zip"
ditto --noqtn --norsrc -c -k --keepParent "$app_dir" "$archive"
extraction="$(mktemp -d "$PWD/build/release-check.XXXXXX")"
trap 'rm -rf "$extraction"' EXIT
ditto -x -k "$archive" "$extraction"
codesign --verify --strict "$extraction/Prewarm.app"
diff -qr "$app_dir" "$extraction/Prewarm.app"
(
  cd "$release_dir"
  shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256"
)
{
  printf 'Prewarm %s (%s)\nSource: %s\nArchitecture: %s\n' "$PREWARM_VERSION" "$PREWARM_BUILD" "$(git rev-parse HEAD)" "$architectures"
  printf 'SDK: %s\n' "$(xcrun --sdk macosx --show-sdk-version)"
  swift --version
  shasum -a 256 "$app_dir/Contents/MacOS/Prewarm" | sed 's|  .*|  Contents/MacOS/Prewarm|'
  codesign -d --verbose=2 "$app_dir" 2>&1 | sed '/^Executable=/d'
  printf '%s\n' 'Not notarized. Archive/extracted signature and tree equality verified.'
} > "$archive.receipt.txt"
printf '%s\n' "$archive" "$archive.sha256" "$archive.receipt.txt"
