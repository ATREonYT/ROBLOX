#!/bin/sh
# Exports one UI state to JSON for render.js.
# Usage: sh run.sh <out.json> '<lua table of options>'   e.g.  sh run.sh shop.json '{SCREEN="Shop", TAB="Passes"}'
# Options: SCREEN (Shop / Settings / Menu / Hud), TAB, SCALE, COINS, GEMS, OWN / PASSES (comma lists), ROUND
# (seconds to the next round), SETTINGS (a table of setting values).
cd "$(dirname "$0")" || exit 1
"${LUNE:-lune}" run harness.luau ../../src "$1" "__previewConfig = $2
$(cat scene.luau)" setup_ui.luau
