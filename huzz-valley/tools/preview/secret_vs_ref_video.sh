#!/bin/sh
# Side-by-side video: our filmed Secret cutscene (left) next to the owner's reference (right), time-aligned (our shot
# list follows the reference's seconds: docs/secret-beats.md). Both cropped to the reference's 3D-view shape.
# Usage (from huzz-valley/): sh tools/preview/secret_vs_ref_video.sh <ours.mp4 from secret_scene> <out.mp4>
# (secret_scene films 1 s before the cutscene: ours starts at 1 s.)
set -e
OURS=$1; OUT=$2
REF=design/vfx/ref3/vfx-reference-oct17.mp4
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
LABEL="fontfile=$FONT:fontsize=20:fontcolor=white:borderw=2:bordercolor=black:x=10:y=8"
ffmpeg -loglevel error -y -ss 1 -t 14 -i "$OURS" -t 14 -i "$REF" -filter_complex "\
[0:v]crop=1280:619:0:50,scale=640:310,setsar=1,drawtext=text='OURS (game code, filmed offline)':$LABEL[a];\
[1:v]crop=897:434:8:88,scale=640:310,setsar=1,fps=30,drawtext=text='REFERENCE':$LABEL[b];\
[a][b]hstack=inputs=2[v]" -map "[v]" -an -c:v libx264 -pix_fmt yuv420p -r 30 "$OUT"
echo "-> $OUT"
