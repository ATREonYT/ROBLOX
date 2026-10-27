#!/bin/sh
# shoot.sh: pictures of the game's windows, offline. Runs the real game for one player in the Lune harness, opens each
# window (windows.luau), dumps its ScreenGui to JSON (dump.luau) and draws each dump at 1280x720 in Chromium (index.html,
# shoot.js). See README.md.
#   LUNE=<path to lune> sh hood/tools/preview/ui/shoot.sh [out dir]      (from the repo root; out dir default: hood/tools/preview/ui/out)
set -e
L=${LUNE:-lune}
D=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$D/../../../.." && pwd)
T=$R/hood/tools/checks
O=${1:-$D/out}
mkdir -p "$O"
O=$(cd "$O" && pwd)
S=$O/scenario.luau
# the scenario: the dumper, the image prelude, feel_base's set-up (the screen made 1280x720), then windows.luau
N=$(grep -n "^-------.*0\. spawn" "$T/feel_base.luau" | head -1 | cut -d: -f1)
echo "UI_OUT = '$O'" > "$S"
cat "$D/dump.luau" "$D/prelude.luau" >> "$S"
head -$((N - 1)) "$T/feel_base.luau" | sed \
  -e 's/__screenSize = Vector2.new(1200, 617)/__screenSize = Vector2.new(1280, 662)/' \
  -e 's/__fullSize = Vector2.new(1200, 675)/__fullSize = Vector2.new(1280, 720)/' \
  -e 's/__safeSize = Vector2.new(1200, 675)/__safeSize = Vector2.new(1280, 720)/' \
  -e 's/ViewportSize = Vector2.new(1200, 675)/ViewportSize = Vector2.new(1280, 720)/' >> "$S"
cat "$D/windows.luau" >> "$S"
cd "$R"
timeout 900 "$L" run "$T/harness_live.luau" hood/src - "EXPORT=nil REPORT_DIR='$O' $(cat "$S")" > "$O/log.txt" 2>&1 || true
grep "^\[ui\]" "$O/log.txt" || { echo "no [ui] lines; see $O/log.txt"; tail -20 "$O/log.txt"; exit 1; }
node "$D/shoot.js" "$O"
