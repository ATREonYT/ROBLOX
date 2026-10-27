#!/bin/sh
# render_items.sh: a picture for every item the UI shows that has none in hood/art/icons3d (shoes, shoe boxes), rendered
# offline from the game's own models (render14: the harness builds them, three.js draws them on a transparent
# background), then framed like the other icons (fit_icons.py: 512 canvas, content centred, longer side 86%).
#   LUNE=<lune> sh hood/tools/ui/render_items.sh [out dir]        (from the repo root; npm install in render14 first)
#   ALL=true ... renders every shoe and box again, not only the missing ones.
set -e
L=${LUNE:-lune}
D=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$D/../../.." && pwd)
O=${1:-$R/hood/tools/ui/out_items}
mkdir -p "$O"
O=$(cd "$O" && pwd)
SNIP="VIEWS = '$O/views.json'
ICONS = '$R/hood/art/icons3d'
ALL = ${ALL:-false}
$(cat "$D/items_scene.luau")"
T=$R/hood/tools/preview/render14/tools
(cd "$T" && timeout 900 "$L" run harness.luau "$R/hood/src" "$O/scene.json" "$SNIP" 2>&1 | grep -a "items\|rror" | head -20)
(cd "$R/hood/tools/preview/render14" && W=512 H=512 node shoot.js "$O/scene.json" "$O/views.json" "$O/raw" 2>&1 | grep -v "^loaded\|^wrote" | tail -5)
python3 -I "$D/fit_icons.py" "$O/raw" "$R/hood/art/icons3d"
