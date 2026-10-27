#!/bin/sh
# firstvideo.sh <out dir>: a fresh save's first 40 seconds as a 30 fps MP4 (Oct 27, flow round), offline.
#   1. the game in the Lune harness, the kid on first30's route (tools/checks/route.luau), every ScreenGui dumped each
#      1/30 s of game time and the camera, the kid and the scripts' world parts every VSTEP-th frame (firstvideo.luau);
#   2. the screens drawn see-through (video.js), the hall drawn by render14 from the recorded cameras (walk.js CAMS=, at
#      30 / VSTEP fps: a 3D frame takes ~11 s), the two laid together by ffmpeg -> <out>/first40.mp4.
#   LUNE=<lune> sh hood/tools/preview/ui/firstvideo.sh <out>       (from the repo root; render14 needs `npm install` first)
# Options: VFRAMES (1200), VSTEP (6: the hall at 5 fps), JOBS (3 render14 browsers at once), SKIP3D=1 (screens only,
# over a plain backdrop). What it can't show: billboards over the world (the gate signs, "+1 POWER"), the kid's real
# avatar and animations (a blocky stand-in), particles, and sound (off in the game anyway).
set -e
L=${LUNE:-lune}
D=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$D/../../../.." && pwd)
T=$R/hood/tools/checks
O=${1:?out dir}
mkdir -p "$O"; O=$(cd "$O" && pwd)
VFRAMES=${VFRAMES:-1200}; VSTEP=${VSTEP:-6}; JOBS=${JOBS:-3}
S=$O/scenario.luau
N=$(grep -n "^-------.*0\. spawn" "$T/feel_base.luau" | head -1 | cut -d: -f1)
{ echo "UI_OUT = '$O'; VFRAMES = $VFRAMES; VSTEP = $VSTEP"; cat "$D/dump.luau" "$D/prelude.luau" "$D/firstvideo.luau"
  head -$((N - 1)) "$T/feel_base.luau" | sed \
    -e "s/__screenSize = Vector2.new(1200, 617)/__screenSize = Vector2.new(1280, 662)/" \
    -e "s/__fullSize = Vector2.new(1200, 675)/__fullSize = Vector2.new(1280, 720)/" \
    -e "s/__safeSize = Vector2.new(1200, 675)/__safeSize = Vector2.new(1280, 720)/" \
    -e "s/ViewportSize = Vector2.new(1200, 675)/ViewportSize = Vector2.new(1280, 720)/" \
    -e "s|^\t\ttask.wait(1 / 30)$|\t\ttask.wait(1 / 30); _G.__vclock += 1 / 30; __videoStep()|"
  cat "$T/route.luau"; } > "$S"
grep -q "__videoStep()" "$S" || { echo "feel_base's frame step not found"; exit 1; }
if [ ! -f "$O/cams.json" ] || [ -n "$REDO" ]; then
  (cd "$R" && timeout 3000 "$L" run "$T/harness_live.luau" hood/src - "EXPORT=nil REPORT_DIR='$O' $(cat "$S")" > "$O/log.txt" 2>&1 || true)
fi
grep -a "\[video\] $VFRAMES frames" "$O/log.txt" > /dev/null || { echo "the recording stopped short; see $O/log.txt"; grep -a "\[video\]" "$O/log.txt" | tail -3; }
node "$D/video.js" "$O"
if [ "${SKIP3D:-0}" = 1 ]; then
  ffmpeg -y -loglevel error -f lavfi -i "color=c=0x6f8fae:s=1280x720:r=30" -framerate 30 -i "$O/u_%04d.png" \
    -filter_complex "[0][1]overlay=shortest=1" -c:v libx264 -pix_fmt yuv420p "$O/first40.mp4"
  echo "$O/first40.mp4 (screens only)"; exit 0
fi
R14=$R/hood/tools/preview/render14
[ -f "$O/scene/scene.json" ] || (cd "$R14" && LUNE=$L sh tools/export.sh "$O/scene")
F=$(python3 -c "import json;print(len(json.load(open('$O/cams.json'))['frames']))")
C=$(( (F + JOBS - 1) / JOBS )); i=0
while [ $i -lt $JOBS ]; do
  (cd "$R14" && START=$((i * C)) END=$(((i + 1) * C)) CAMS="$O/cams.json" FPS=$((30 / VSTEP)) node walk.js "$O/scene/scene.json" "$O/h" 960 540 > "$O/walk_$i.log" 2>&1) &
  i=$((i + 1))
done
wait
ffmpeg -y -loglevel error -framerate $((30 / VSTEP)) -i "$O/h/f_%04d.png" -framerate 30 -i "$O/u_%04d.png" \
  -filter_complex "[0]fps=30,scale=1280:720[bg];[bg][1]overlay=shortest=1" -c:v libx264 -pix_fmt yuv420p -r 30 "$O/first40.mp4"
echo "$O/first40.mp4"
