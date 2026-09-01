#!/bin/bash
# Bouwt GlowCursor.app en installeert 'm in /Applications, zodat Spotlight en
# Raycast 'm als gewone app vinden (en je er een alias/hotkey aan kunt hangen).
# Draait bundle.sh voor de build; kopieert daarna naar /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

Scripts/bundle.sh

DEST="/Applications/GlowCursor.app"
rm -rf "$DEST"
cp -R "build/GlowCursor.app" "$DEST"

echo "Geïnstalleerd: $DEST"
echo "Tip: open 'm één keer (open -a GlowCursor) en zet daarna in het menubalk-menu"
echo "     'Start bij inloggen' aan — dan hoef je 'm nooit meer handmatig te starten."
