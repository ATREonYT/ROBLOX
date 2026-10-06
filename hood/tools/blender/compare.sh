#!/usr/bin/env bash
# Side-by-side proof that the generated Luau modules build exactly what Blender rendered.
#   1. Blender renders every model with a plain camera (render.py compare) and saves that camera.
#   2. The Lune preview harness builds every model from GunModels/IconModels (hood/src) and exports parts.
#   3. The three.js preview renderer replays the same cameras on those Luau-built parts.
#   4. ImageMagick pastes each pair side by side: Blender left, Roblox parts right.
# Models sit 400 studs apart so no neighbour shows up in a shot.
# Env: SKIP_BLENDER=1 reuses existing Blender shots; BLENDER_PY (python with bpy), LUNE, HARNESS_DIR (preview harness,
# default hood/tools/preview), RENDER_DIR (three.js renderer, default hood/tools/preview/render).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
HOOD=$(cd "$HERE/../.." && pwd)
PY=${BLENDER_PY:-python}
LUNE=${LUNE:-lune}
HARNESS=${HARNESS_DIR:-$HOOD/tools/preview}
RENDERER=${RENDER_DIR:-$HOOD/tools/preview/render}
OUT=${OUT:-${TMPDIR:-/tmp}/bk_compare}
SCALE=8
mkdir -p "$OUT"

[ -n "${SKIP_BLENDER:-}" ] || "$PY" "$HERE/render.py" compare --out "$OUT/blender"

SNIPPET="
local G = require(game.ReplicatedStorage.Shared.Models.GunModels)
local I = require(game.ReplicatedStorage.Shared.Models.IconModels)
local function place(M, ids, z)
	for i, id in ids do
		local m = M.build(id, $SCALE)
		for _, p in m:GetDescendants() do
			if p:IsA('BasePart') then p.CFrame = CFrame.new((i - 1) * 400, 0, z) * p.CFrame end
		end
		m.Parent = workspace
	end
end
place(G, G.Ids, 0)
place(I, I.Ids, 1000)
return #G.Ids + #I.Ids"
(cd "$HARNESS" && "$LUNE" run harness.luau "$HOOD/src" "$OUT/parts.json" "$SNIPPET")

python3 - "$OUT" "$SCALE" <<'EOF'
import json, os, sys
out, scale = sys.argv[1], float(sys.argv[2])
guns = ['Pistol', 'Revolver', 'Uzi', 'Shotgun', 'Tommy', 'AK', 'Deagle', 'Minigun', 'Blaster', 'Diamond']
icons = ['Shop', 'Rebirth', 'Rewards', 'PVP', 'Evolve', 'Cash', 'Power', 'Trophy', 'Gun']
views = []
for ids, z in ((guns, 0), (icons, 1000)):
	for i, mid in enumerate(ids):
		cam = json.load(open(os.path.join(out, 'blender', mid + '.cam.json')))
		k = cam['unit'] * scale
		off = (i * 400, 0, z)
		tr = lambda v: [v[j] * k + off[j] for j in range(3)]
		views.append({'name': mid, 'pos': tr(cam['pos']), 'look': tr(cam['look']), 'up': cam['up'], 'fov': cam['fov']})
json.dump({'options': {'transparent': True, 'noFog': True, 'time': 0, 'focus': [0, 0, 0]}, 'views': views}, open(os.path.join(out, 'views.json'), 'w'), indent=1)
EOF

(cd "$RENDERER" && W=400 H=400 node shoot.js "$OUT/parts.json" "$OUT/views.json" "$OUT/threejs")

pairs=()
for id in Pistol Revolver Uzi Shotgun Tommy AK Deagle Minigun Blaster Diamond Shop Rebirth Rewards PVP Evolve Cash Power Trophy Gun; do
	montage "$OUT/blender/$id.png" "$OUT/threejs/$id.png" -tile 2x1 -geometry 300x300+2+2 -title "$id: Blender | Roblox parts" \
		-background '#8090b0' -font DejaVu-Sans-Bold -pointsize 14 "$OUT/pair_$id.png"
	pairs+=("$OUT/pair_$id.png")
done
montage "${pairs[@]}" -tile 4x -geometry +6+6 -background '#2a3048' -depth 8 "$HOOD/art/renders/compare_blender_vs_roblox.png"
convert "$HOOD/art/renders/compare_blender_vs_roblox.png" -alpha off -depth 8 -strip "$HOOD/art/renders/compare_blender_vs_roblox.png"
echo "wrote $HOOD/art/renders/compare_blender_vs_roblox.png"
