#!/bin/sh
# Side-by-side video: our filmed Secret cutscene (left) next to the owner's reference (right), both cropped to the
# reference's 3D-view shape. Since Oct 19 ours is 10 s and the reference ~14 s, so the reference is RE-TIMED to our
# beats: each of its stretches below is sped up or slowed to fill the same stretch of ours (docs/secret-beats.md).
# Ours plays at its real speed. Usage (from huzz-valley/): sh tools/preview/secret_vs_ref_video.sh <ours.mp4> <out.mp4>
# (secret_scene films 1 s before the cutscene: ours starts at 1 s.)
set -e
OURS=$1; OUT=$2
REF=design/vfx/ref3/vfx-reference-oct17.mp4
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
LABEL="fontfile=$FONT:fontsize=20:fontcolor=white:borderw=2:bordercolor=black:x=10:y=8"
# ours_from ours_to ref_from ref_to  (the same beat in both)
SEGS="0 0.95 0 0.75
0.95 1.7 0.75 1.95
1.7 2.5 1.95 2.25
2.5 3.42 2.25 2.75
3.42 3.8 2.75 3.2
3.8 4.5 3.2 4.4
4.5 5.1 4.4 5.7
5.1 6.4 7.0 9.95
6.4 6.85 9.95 11.0
6.85 7.6 11.0 12.25
7.6 8.3 12.25 13.3
8.3 10.0 13.3 14.0"
FILTER=""
CONCAT=""
N=0
while read -r oa ob ra rb; do
	F=$(python3 -c "print(($ob - $oa) / ($rb - $ra))")
	FILTER="$FILTER[1:v]trim=start=$ra:end=$rb,setpts=(PTS-STARTPTS)*$F,fps=30,crop=897:434:8:88,scale=640:310,setsar=1[r$N];"
	CONCAT="$CONCAT[r$N]"
	N=$((N + 1))
done <<EOF
$SEGS
EOF
ffmpeg -loglevel error -y -ss 1 -t 10 -i "$OURS" -i "$REF" -filter_complex "\
[0:v]crop=1280:619:0:50,scale=640:310,setsar=1,drawtext=text='OURS (game code, filmed offline, real speed)':$LABEL[a];\
${FILTER}${CONCAT}concat=n=$N:v=1:a=0,drawtext=text='REFERENCE (re-timed to our beats)':$LABEL[b];\
[a][b]hstack=inputs=2:shortest=1[v]" -map "[v]" -an -c:v libx264 -pix_fmt yuv420p -r 30 "$OUT"
echo "-> $OUT"
