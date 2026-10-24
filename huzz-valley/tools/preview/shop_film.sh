#!/bin/sh
# Films the Shop's motion (shop_film.luau) to an MP4 at 30 fps, and saves one still with a crate's panel open.
# Usage: sh shop_film.sh <out.mp4> [still.jpg]   Needs Lune (LUNE=path), Playwright (NODE_PATH) and ffmpeg.
cd "$(dirname "$0")" || exit 1
TMP=$(mktemp -d)
"${LUNE:-lune}" run harness.luau ../../src - "__framesDir = '$TMP'
$(cat shop_film.luau)" setup_ui.luau | grep -E "frames:|rror"
node shoot_frames.js "$TMP" 1920 1080
ffmpeg -loglevel error -y -framerate 30 -i "$TMP/frame_%04d.png" -vf scale=1280:-2 -c:v libx264 -crf 24 -pix_fmt yuv420p "$1"
# the still: the Candy Crate's panel just in (frame 125)
[ -n "$2" ] && ffmpeg -loglevel error -y -i "$TMP/frame_0125.png" -vf scale=1280:-2 -q:v 3 "$2"
rm -rf "$TMP"
echo "wrote $1 $2"
