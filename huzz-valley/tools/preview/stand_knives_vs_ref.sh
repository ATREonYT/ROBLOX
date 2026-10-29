#!/bin/sh
# The lobby stands' knives next to the owner's Oct 19 reference (design/lobby-ref/oct19-stands-ref.mp4), 30 fps:
# top = his reference (its three stands: PUMPKIN CLEAVER, VIP DAGGER, VOWBREAKER), bottom = ours
# (motion3d/stand_knives_scene.luau: Inferno, Sunrise and Hunter Knife, same row, same framing), plus a still sheet.
# Usage (from huzz-valley/): sh tools/preview/stand_knives_vs_ref.sh <ours.mp4> <out.mp4> <sheet.jpg>
set -e
REF=design/lobby-ref/oct19-stands-ref.mp4
OURS=$1
OUT=$2
SHEET=$3
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
# reference: his three stands (x 230..1270, y 60..450 of 1510 x 942), looped to 10 s, 960 x 360 like ours
ffmpeg -loglevel error -y -stream_loop 1 -i "$REF" -i "$OURS" -filter_complex \
"[0:v]fps=30,trim=0:10,setpts=PTS-STARTPTS,crop=1040:390:230:60,scale=960:360,drawtext=fontfile=$FONT:text='REFERENCE':x=10:y=10:fontsize=18:fontcolor=white:borderw=2:bordercolor=black[a];\
[1:v]fps=30,trim=0:10,setpts=PTS-STARTPTS,scale=960:360,drawtext=fontfile=$FONT:text='OURS (game code, his knife meshes)':x=10:y=10:fontsize=18:fontcolor=white:borderw=2:bordercolor=black[b];\
[a][b]vstack=inputs=2[v]" -map "[v]" -r 30 -c:v libx264 -pix_fmt yuv420p -crf 20 "$OUT"
# still sheet: 6 moments, two columns
ffmpeg -loglevel error -y -i "$OUT" -vf "select='eq(n\,30)+eq(n\,75)+eq(n\,120)+eq(n\,165)+eq(n\,210)+eq(n\,255)',scale=640:-1,tile=2x3" -frames:v 1 -q:v 3 "$SHEET"
echo "$OUT $SHEET"
