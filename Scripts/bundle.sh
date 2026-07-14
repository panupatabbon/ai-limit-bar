#!/bin/bash
# Builds AILimitBar.app from the SwiftPM release build.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="AILimitBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp Scripts/Info.plist "$APP/Contents/Info.plist"
cp .build/release/AILimitBar "$APP/Contents/MacOS/AILimitBar"
# SwiftPM resource bundle (pixel font) must sit next to Resources for Bundle.module.
cp -R .build/release/ai-limit-bar_AILimitBarKit.bundle "$APP/Contents/Resources/"

codesign --force --deep --sign - "$APP"
echo "Built $APP (ad-hoc signed)"
