#!/bin/sh
# Runs every functional check offline (rules, Index/Tiers buttons, Dances/Progression buttons). Needs Lune (LUNE=path).
# The checks run on the UI saved in StarterGui (as in the game); the first file also runs once with HUZZ_FRESH=1,
# where the scripts build the whole UI themselves.
cd "$(dirname "$0")" || exit 1
for f in check.luau check_index_tiers.luau check_dances_progression.luau check_girl_index.luau check_girl_fx.luau check_oct17.luau check_round_hud.luau check_countdown.luau check_lobby_boards.luau; do
	"${LUNE:-lune}" run harness.luau ../../src - "$(cat "$f")" setup_ui.luau | grep -E "FAIL|checks:|ok, [0-9]+ failed|snippet error"
done
HUZZ_FRESH=1 "${LUNE:-lune}" run harness.luau ../../src - "$(cat check.luau)" setup_ui.luau | grep -E "FAIL|checks:" | sed 's/^checks:/built from nothing:/'
# Text out of its box, its window or the screen, and text on text, on every shots.sh screen (needs node + Playwright).
if command -v node >/dev/null 2>&1 && NODE_PATH="${NODE_PATH:-$(npm root -g 2>/dev/null)}" node -e "require('playwright')" 2>/dev/null; then
	NODE_PATH="${NODE_PATH:-$(npm root -g)}" sh overflow.sh | grep -E "FAIL|overflow:|had errors"
else
	echo "overflow: skipped (needs node and Playwright)"
fi
