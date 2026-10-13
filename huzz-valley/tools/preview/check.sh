#!/bin/sh
# Runs the functional checks offline. Needs Lune (LUNE=path).
cd "$(dirname "$0")" || exit 1
"${LUNE:-lune}" run harness.luau ../../src - "$(cat check.luau)" setup_ui.luau
