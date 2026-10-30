#!/bin/sh
# Huss Valley's one full-speed stop next to our halt, 30 fps, same framing (owner, Oct 20 07:55: "after they randomly
# stop after fully running they move a little forward as a sort of "hault" like in the game Huss valley").
#   sh halt_side.sh <hv f1c7bb86.mp4> <out.mp4> <out.jpg>      (run from the repo root; needs Lune, node + Playwright, ffmpeg)
# Films ours with halt_scene.luau (HALT_ONLY=after), lines our let-go (1.80 s) up with the moment HV's ground starts
# slowing hard (41.19 s, tools/preview/motion3d/ground_flow.py), puts them side by side and saves a contact sheet of
# the stop (+0.50 to +1.00 s).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
HALT_ONLY=after sh "$HERE/video.sh" "$HERE/halt_scene.luau" "$TMP/ours.mp4"
ffmpeg -v error -y -ss 40.59 -t 1.3 -i "$1" -ss 1.2 -t 1.3 -i "$TMP/ours.mp4" -filter_complex \
	"[0:v]fps=30,crop=1100:1100:950:480,scale=720:720,setpts=PTS-STARTPTS,drawtext=text='Huss Valley (f1c7bb86 from 40.59 s)':x=10:y=10:fontsize=24:fontcolor=white:borderw=2[a];[1:v]fps=30,setpts=PTS-STARTPTS,drawtext=text='Ours (let go at +0.60 s)':x=10:y=10:fontsize=24:fontcolor=white:borderw=2[b];[a][b]hstack=inputs=2,drawtext=text='+%{eif\:t\:d}.%{eif\:mod(t*100\,100)\:d\:2} s':x=640:y=680:fontsize=26:fontcolor=yellow:borderw=2" \
	-r 30 -c:v libx264 -crf 22 -pix_fmt yuv420p "$2"
ffmpeg -v error -y -i "$2" -vf "select='between(n\,15\,30)',scale=480:240,tile=4x4" -frames:v 1 -q:v 4 "$3"
rm -rf "$TMP"
echo "saved $2 and $3"
