#!/bin/sh
# Films the crate opening (crate_film.luau) to an MP4 at 30 fps, and saves one still of the prize moment.
# Usage: sh crate_film.sh <out.mp4> [still.jpg]   Needs Lune (LUNE=path), Playwright (NODE_PATH) and ffmpeg.
cd "$(dirname "$0")" || exit 1
TMP=$(mktemp -d)
"${LUNE:-lune}" run harness.luau ../../src - "__framesDir = '$TMP'
$(cat crate_film.luau)" setup_ui.luau | grep -E "frames:|rror"
node shoot_frames.js "$TMP" 1920 1080
ffmpeg -loglevel error -y -framerate 30 -i "$TMP/frame_%04d.png" -vf scale=1280:-2 -c:v libx264 -crf 24 -pix_fmt yuv420p "$1"
# the still: the Legendary card a moment after it lands (frame 290 = 9.7 s)
[ -n "$2" ] && ffmpeg -loglevel error -y -i "$TMP/frame_0290.png" -vf scale=1280:-2 -q:v 3 "$2"
rm -rf "$TMP"
echo "wrote $1 $2"
