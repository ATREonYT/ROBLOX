#!/bin/bash
# sheet.sh <input> <start> <dur> <fps> <cols>x<rows> <width> <out> [prefilter]
IN="$1"; SS="$2"; D="$3"; FPS="$4"; T="$5"; W="$6"; OUT="$7"; PRE="${8:-null}"
F=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
ffmpeg -v error -y -ss "$SS" -i "$IN" -t "$D" -vf "$PRE,fps=$FPS,scale=$W:-2,drawtext=fontfile=$F:text='%{eif\:t+$SS\:d}.%{eif\:mod((t+$SS)*1000,1000)\:d\:3} f%{n}':x=3:y=3:fontsize=15:fontcolor=yellow:box=1:boxcolor=black@0.7,tile=$T" -frames:v 1 -q:v 5 "$OUT"
ls -la "$OUT"
