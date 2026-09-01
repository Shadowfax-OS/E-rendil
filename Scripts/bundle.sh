#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/GlowCursor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/GlowCursor "$APP/Contents/MacOS/GlowCursor"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"

echo "Klaar: $APP"
echo "Sleep naar /Applications (of draai Scripts/install.sh) en zet in het menu"
echo "'Start bij inloggen' aan."
