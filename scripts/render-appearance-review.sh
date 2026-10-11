#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
binary_dir="$(swift build --show-bin-path)"
fixture_binary="$(mktemp -t prewarm-appearance)"
trap 'rm -f "$fixture_binary"' EXIT
swiftc -I "$binary_dir" "$binary_dir/PrewarmCore.o" \
  Sources/Prewarm/CaptureEngine.swift Sources/Prewarm/IconArtwork.swift \
  Sources/Prewarm/AboutController.swift \
  Sources/Prewarm/PrewarmPanel.swift Sources/Prewarm/PrewarmPanelHost.swift \
  scripts/AppearanceReview/main.swift -o "$fixture_binary"
"$fixture_binary" "$PWD"
