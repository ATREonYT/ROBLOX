#!/bin/sh
# Builds huzz-valley/places/HuzzValley.rbxl so the owner can open it in Studio (File > Open) and press Play without
# Rojo. Two steps:
#   1. builds the UI from the scripts and saves it as src/StarterGui/HuzzUI.rbxm (real, editable UI parts);
#   2. saves every script from src/, that StarterGui UI, and a simple baseplate and spawn into the place.
# Needs Lune (LUNE=path).
cd "$(dirname "$0")/../preview" || exit 1
mkdir -p ../../src/StarterGui
HUZZ_FRESH=1 HUZZ_UI_OUT=../../src/StarterGui/HuzzUI.rbxm "${LUNE:-lune}" run harness.luau ../../src - "$(cat ../place/export_ui.luau)" setup_ui.luau | grep -E "saved UI|error|FAIL"
HOOD_PLACE_OUT=../../places/HuzzValley.rbxl "${LUNE:-lune}" run harness.luau ../../src - "$(cat ../place/world.luau)"
