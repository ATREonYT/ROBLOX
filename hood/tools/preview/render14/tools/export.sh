#!/bin/sh
# export.sh <out dir> [fake|nofake] [avatar "x,z,yaw;..."]: build TheBlockV2 from hood/src, export it, crop to the lobby.
#   fake (default): the owner's designs (hood/art/models/items, the 4 GLBs + manifest) faked into
#   ReplicatedStorage.HoodItemMeshes the way the Studio import leaves them, so render14 draws the real GLB meshes.
#   nofake: our Part fallbacks only (what Studio shows before the import).
# -> <out>/scene.json (lobby + forecourt + first stages) and <out>/plan.json (no roof, for top-down views).
# Needs LUNE=/path/to/lune (or lune on PATH). SRC=... overrides hood/src; SOUTH=<z> is the hall's south wall (crop).
# MAP=TheCity exports World 2's map instead (default TheBlockV2).
T=$(cd "$(dirname "$0")" && pwd); R=$(cd "$T/../../../../.." && pwd); L=${LUNE:-lune}; O=$1; mkdir -p "$O"; O=$(cd "$O" && pwd)
BUILD="return require(game.ServerStorage.${MAP:-TheBlockV2}).Build()"
if [ "$2" = nofake ]; then SNIP="$BUILD"; else
SNIP="MANIFEST='$R/hood/art/models/items/manifest.json'
$(cat "$T/fake_items.luau")
__fakeItemMeshes(MANIFEST)
$BUILD"; fi
(cd "$T" && timeout 900 $L run harness.luau "${SRC:-$R/hood/src}" "$O/full.json" "$SNIP" 2>&1 | grep -ai "error\|warn\|exported" | head -12)
python3 "$T/crop.py" "$O/full.json" "$O/scene.json" "$O/plan.json" "${SOUTH:-122}" && rm -f "$O/full.json"
if [ -n "$3" ]; then python3 "$T/avatar.py" "$O/scene.json" "$O/scene.json" "$3"; fi
