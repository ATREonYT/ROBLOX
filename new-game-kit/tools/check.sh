#!/bin/sh
# New Game Kit: run every offline check, then rebuild the HUD and the place.
# Usage (from the game folder): PATH=/root/bin:$PATH sh tools/check.sh
# Needs Lune 0.10.5 (install line in README.md). About 30 seconds.
cd "$(dirname "$0")/.." || exit 1
LUNE=${LUNE:-lune}
"$LUNE" run tools/test.luau || exit 1
"$LUNE" run tools/sim.luau || exit 1
"$LUNE" run tools/build_place.luau || exit 1
echo "[check] all green"
