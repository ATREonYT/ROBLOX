#!/bin/sh
# Builds a Roblox place file you can open straight in Studio: every script from hood/src (laid out the way Rojo
# syncs them) plus The Block V2 already built in Workspace and its lighting applied. Needs Lune
# (https://lune-org.github.io/docs, e.g. `brew install lune` or `rokit add lune-org/lune`).
#   sh hood/tools/place/build_place.sh                 -> hood/places/HoodEvolution.rbxl
#   sh hood/tools/place/build_place.sh out.rbxlx       -> any path (.rbxlx for the XML format)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
HOOD=$(cd "$HERE/../.." && pwd)
OUT=${1:-$HOOD/places/HoodEvolution.rbxl}
case "$OUT" in /*) ;; *) OUT=$(pwd)/$OUT ;; esac
mkdir -p "$(dirname "$OUT")"
LUNE=${LUNE:-lune}
cd "$HOOD/tools/preview"
HOOD_PLACE_OUT="$OUT" "$LUNE" run harness.luau "$HOOD/src" - "require(game.ServerStorage.TheBlockV2).Build()"
