#!/bin/sh
# shoot.sh: pictures of the game's windows, offline. Runs the real game for one player in the Lune harness, opens each
# window (windows.luau), dumps its ScreenGui to JSON (dump.luau) and draws each dump at 1280x720 in Chromium (index.html,
# shoot.js). See README.md.
#   LUNE=<path to lune> sh hood/tools/preview/ui/shoot.sh [out dir]      (from the repo root; out dir default: hood/tools/preview/ui/out)
# Options (environment): SCENE=hud (the HUD alone, hud.luau, instead of the windows); SW, SH (the screen, default 1280 x
# 720), NOTCH (px kept clear on each side, a phone's notch), TOUCH=1 (a touch screen, no mouse or keyboard), FALLBACK=1
# (Roblox refuses every packed picture, as without Studio's "Allow Mesh / Image APIs": the old drawn look). A phone:
#   SCENE=hud SW=844 SH=390 NOTCH=47 TOUCH=1 LUNE=<lune> sh hood/tools/preview/ui/shoot.sh <out dir>
set -e
L=${LUNE:-lune}
D=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$D/../../../.." && pwd)
T=$R/hood/tools/checks
O=${1:-$D/out}
mkdir -p "$O"
O=$(cd "$O" && pwd)
S=$O/scenario.luau
SW=${SW:-1280}; SH=${SH:-720}; NOTCH=${NOTCH:-0}; SCENE=${SCENE:-windows}
GW=$((SW - 2 * NOTCH)); GH=$((SH - 58))
TOUCHES='false, true, true, false'
[ "${TOUCH:-0}" = 1 ] && TOUCHES='true, false, false, false'
export SW SH NOTCH
# the scenario: the dumper, the image prelude, feel_base's set-up (the screen made SW x SH), then $SCENE.luau
N=$(grep -n "^-------.*0\. spawn" "$T/feel_base.luau" | head -1 | cut -d: -f1)
echo "UI_OUT = '$O'" > "$S"
[ "${FALLBACK:-0}" = 1 ] && echo 'UI_FALLBACK = true' >> "$S"
cat "$D/dump.luau" "$D/prelude.luau" >> "$S"
head -$((N - 1)) "$T/feel_base.luau" | sed \
  -e "s/__screenSize = Vector2.new(1200, 617)/__screenSize = Vector2.new($GW, $GH)/" \
  -e "s/__fullSize = Vector2.new(1200, 675)/__fullSize = Vector2.new($SW, $SH)/" \
  -e "s/__safeSize = Vector2.new(1200, 675)/__safeSize = Vector2.new($GW, $SH)/" \
  -e "s/ViewportSize = Vector2.new(1200, 675)/ViewportSize = Vector2.new($SW, $SH)/" \
  -e "s/U.TouchEnabled, U.MouseEnabled, U.KeyboardEnabled, U.GamepadEnabled = false, true, true, false/U.TouchEnabled, U.MouseEnabled, U.KeyboardEnabled, U.GamepadEnabled = $TOUCHES/" >> "$S"
cat "$D/$SCENE.luau" >> "$S"
cd "$R"
timeout 900 "$L" run "$T/harness_live.luau" hood/src - "EXPORT=nil REPORT_DIR='$O' $(cat "$S")" > "$O/log.txt" 2>&1 || true
grep "^\[ui\]" "$O/log.txt" || { echo "no [ui] lines; see $O/log.txt"; tail -20 "$O/log.txt"; exit 1; }
node "$D/shoot.js" "$O"
