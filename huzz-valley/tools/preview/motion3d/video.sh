#!/bin/sh
# Runs a motion3d scene with Lune, then renders its frames to a 30 fps MP4. Usage: sh video.sh <scene.luau> <out.mp4>
# The scene saves with scene:save(nil, ...), which writes $MOTION3D_DIR/frames.json.
# Needs Lune (LUNE=path, default /root/bin/lune), NODE_PATH with playwright, and ffmpeg.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SCENE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
export MOTION3D_DIR=$(mktemp -d)
export NODE_PATH="${NODE_PATH:-/opt/node22/lib/node_modules}"
"${LUNE:-/root/bin/lune}" run "$SCENE"
node "$HERE/render.mjs" "$MOTION3D_DIR/frames.json" "$OUT"
rm -rf "$MOTION3D_DIR"
