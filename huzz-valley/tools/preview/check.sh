#!/bin/sh
# Runs every functional check offline (rules, Index/Tiers buttons, Dances/Progression buttons). Needs Lune (LUNE=path).
# The checks run on the UI saved in StarterGui (as in the game); the first file also runs once with HUZZ_FRESH=1,
# where the scripts build the whole UI themselves.
cd "$(dirname "$0")" || exit 1
for f in check.luau check_index_tiers.luau check_dances_progression.luau check_girl_index.luau; do
	"${LUNE:-lune}" run harness.luau ../../src - "$(cat "$f")" setup_ui.luau | grep -E "FAIL|checks:|ok, [0-9]+ failed"
done
HUZZ_FRESH=1 "${LUNE:-lune}" run harness.luau ../../src - "$(cat check.luau)" setup_ui.luau | grep -E "FAIL|checks:" | sed 's/^checks:/built from nothing:/'
