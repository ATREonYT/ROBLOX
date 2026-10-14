#!/bin/sh
# Builds huzz-valley/places/HuzzValley.rbxl: every script from src/ plus a simple baseplate and spawn, so the owner
# can open it in Studio (File > Open) and press Play without Rojo. Needs Lune (LUNE=path).
cd "$(dirname "$0")/../preview" || exit 1
HOOD_PLACE_OUT=../../places/HuzzValley.rbxl "${LUNE:-lune}" run harness.luau ../../src - "$(cat ../place/world.luau)"
