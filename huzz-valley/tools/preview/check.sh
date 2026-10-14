#!/bin/sh
# Runs every functional check offline (rules, Index/Tiers buttons, Dances/Progression buttons). Needs Lune (LUNE=path).
cd "$(dirname "$0")" || exit 1
for f in check.luau check_index_tiers.luau check_dances_progression.luau; do
	"${LUNE:-lune}" run harness.luau ../../src - "$(cat "$f")" setup_ui.luau | grep -E "FAIL|checks:|ok, [0-9]+ failed"
done
