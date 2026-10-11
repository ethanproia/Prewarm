#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build assets/Prewarm.iconset
swiftc Sources/Prewarm/IconArtwork.swift scripts/IconRenderer/main.swift -o build/render-icons
build/render-icons "$PWD"
iconutil -c icns assets/Prewarm.iconset -o assets/Prewarm.icns
