#!/bin/sh
# New Game Kit: run every offline check, then rebuild the HUD and the place.
# Usage (from the game folder): PATH=/root/bin:$PATH sh tools/check.sh
# Needs Lune 0.10.5 (install line in README.md). About 30 seconds.
cd "$(dirname "$0")/.." || exit 1
LUNE=${LUNE:-lune}
"$LUNE" run tools/test.luau || exit 1
"$LUNE" run tools/sim.luau || exit 1
"$LUNE" run tools/pace.luau || exit 1
"$LUNE" run tools/build_place.luau || exit 1
# The repo-wide kid-safe check (vault note 14 §8), when this game sits in the repo
if [ -f ../tools/kidsafe_check.py ]; then
	python3 ../tools/kidsafe_check.py "$(basename "$(pwd)")" || exit 1
fi
echo "[check] all green"
