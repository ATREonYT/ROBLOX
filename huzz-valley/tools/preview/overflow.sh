#!/bin/sh
# The overflow check over every screen in shots.sh (plus its long-name / every-rarity shots): exports each one,
# then overflow.js finds text past its box, its window, its panel or the screen, and text drawn over text.
# Usage: sh overflow.sh [name ...]   Needs Lune (LUNE=path) and Playwright (NODE_PATH, else the global one).
# Prints FAIL lines and "overflow: N ok, M failed". Run by check.sh.
cd "$(dirname "$0")" || exit 1
OUT=$(mktemp -d)
# (built from nothing: what the code makes, i.e. what the next saved StarterGui UI will hold)
HUZZ_FRESH=1 EXPORT_ONLY=1 sh shots.sh "$OUT" "$@"
NODE_PATH=${NODE_PATH:-$(npm root -g 2>/dev/null)} node overflow.js "$OUT/manifest.txt"
rm -rf "$OUT"
