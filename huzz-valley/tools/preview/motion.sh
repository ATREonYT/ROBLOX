#!/bin/sh
# Renders the scripted motion preview to an MP4 at 30 fps. Usage: sh motion.sh <out.mp4>
# Needs Lune (LUNE=path), Playwright (NODE_PATH) and ffmpeg.
cd "$(dirname "$0")" || exit 1
TMP=$(mktemp -d)
"${LUNE:-lune}" run harness.luau ../../src - "__framesDir = '$TMP'
$(cat motion.luau)" setup_ui.luau | grep -E "frames:|error"
node shoot_frames.js "$TMP" 1920 1080 ../../design/pages/13-lobby-hud.png
ffmpeg -loglevel error -y -framerate 30 -i "$TMP/frame_%04d.png" -vf scale=960:-2 -c:v libx264 -pix_fmt yuv420p "$1"
rm -rf "$TMP"
echo "wrote $1"
