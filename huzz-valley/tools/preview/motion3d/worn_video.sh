#!/bin/sh
# Films worn_scene.luau (the worn auras and a Secret girl's look) to docs/previews/worn-auras.mp4 (960x540, 30 fps)
# and tiles the best frame of each shot (captioned) into docs/previews/worn-auras.png.
# Usage (from anywhere in the repo): sh huzz-valley/tools/preview/motion3d/worn_video.sh
# Needs Lune (LUNE=path, default /root/bin/lune), NODE_PATH with playwright, ffmpeg, python3 with Pillow.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(cd "$HERE/../../../docs/previews" && pwd)
export MOTION3D_DIR=$(mktemp -d)
export MOTION3D_KEEP="$MOTION3D_DIR/stills"
export NODE_PATH="${NODE_PATH:-/opt/node22/lib/node_modules}"
cd "$HERE"
"${LUNE:-/root/bin/lune}" run worn_scene.luau
node render.mjs "$MOTION3D_DIR/frames.json" "$OUT/worn-auras.mp4"
python3 - "$MOTION3D_DIR" "$OUT/worn-auras.png" <<'EOF'
import json, os, sys
from PIL import Image
d, out = sys.argv[1], sys.argv[2]
shots = json.load(open(os.path.join(d, 'stills.json')))
TW, TH, COLS = 640, 360, 3  # (each frame carries its own caption)
rows = (len(shots) + COLS - 1) // COLS
sheet = Image.new('RGB', (COLS * TW, rows * TH), (12, 16, 32))
for i, s in enumerate(shots):
    im = Image.open(os.path.join(d, 'stills', 'still_%d.png' % s['frame'])).convert('RGB').resize((TW, TH), Image.LANCZOS)
    sheet.paste(im, ((i % COLS) * TW, (i // COLS) * TH))
sheet.save(out)
print('saved', out)
EOF
rm -rf "$MOTION3D_DIR"
