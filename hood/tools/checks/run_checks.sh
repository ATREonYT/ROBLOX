#!/bin/sh
# run_checks.sh [repo_root] [out_dir]: the full check suite every change must pass before a commit.
#   locals, unit tests, wave and lobby integration, the 82-check play run, live shoes and box reveal,
#   the first-30-seconds new-player run (8/8, 0 purchase prompts), the last stage and the World Boss; World 2's map
#   (TheCity) builds with its contracts (city_contracts: "[city] N checks / 0 failed") and plays through its whole track
#   on the real stage, wave, goal and travel services (city_play: "[play] 10 checks, 0 failed"); both built place files
#   keep every gate's Required Power exactly (place_gates: "[places] 34 checks / 0 failed"); a fresh World 2 player
#   can walk to every place they need and never get stuck (city_reach: "[reach] 56 checks / 0 failed", incl. no way round a shut gate), and so can a
#   World 1 player (block_reach, the same script on TheBlockV2: "[reach1] 56 checks / 0 failed").
# Needs Lune (https://lune-org.github.io): set LUNE=/path/to/lune or have `lune` on PATH.
R=${1:-$(cd "$(dirname "$0")/../../.." && pwd)}; O=${2:-${TMPDIR:-/tmp}/hood_checks}
L=${LUNE:-lune}; T=$(cd "$(dirname "$0")" && pwd); SRC=$R/hood/src
mkdir -p "$O"; cd "$O" || exit 1
echo "== check_locals"; (cd "$R" && $L run hood/tools/preview/check_locals.luau 2>&1 | tail -1)
echo "== unit"; timeout 900 $L run $T/harness_unit.luau $SRC - 'local r=require(game.ServerStorage.UnitTest.RunUnitTest)() return {run=r.run,passed=r.passed,failed=r.failed,failures=r.failures}' 2>&1 | grep -a "SUMMARY\|FAIL\]" | tail -6
echo "== integ_waves"; timeout 900 $L run $T/harness_combat.luau $SRC - "require(game.ServerStorage.TheBlockV2).Build() $(cat $T/integ_waves.luau)" 2>&1 | grep -a "snippet returned\|rror" | grep -o '"issues":"[^"]*"\|"clashes":"[^"]*"\|rror.*'
echo "== integ_lobby"; timeout 900 $L run $T/harness_unit.luau $SRC - "require(game.ServerStorage.TheBlockV2).Build() $(cat $T/integ_lobby.luau)" 2>&1 | grep -a "snippet returned\|rror" | grep -o '"teleports":[0-9]*\|"walk1000":"[^"]*"\|rror.*'
echo "== city_contracts"; timeout 900 $L run $T/harness_unit.luau $SRC - "$(cat $T/city_contracts.luau)" 2>&1 | grep -a "\[city\]\|rror" | head -3
echo "== city_play"; timeout 1200 $L run $T/harness_play.luau $SRC - "$(cat $T/city_play.luau)" 2>&1 | grep -a "\[play\] .*checks\|FAIL" | head -5
echo "== city_reach"; timeout 900 $L run $T/harness_unit.luau $SRC - "$(cat $T/city_reach.luau)" 2>&1 | grep -a "\[reach\] .*checks\|FAIL\|rror" | head -5
echo "== block_reach"; timeout 900 $L run $T/harness_unit.luau $SRC - "REACH_MAP='TheBlockV2' $(cat $T/city_reach.luau)" 2>&1 | grep -a "\[reach1\] .*checks\|FAIL\|rror" | head -5
echo "== place_gates"; timeout 900 $L run $T/harness_unit.luau $SRC - "PLACES_DIR='$R/hood/places' $(cat $T/place_gates.luau)" 2>&1 | grep -a "\[places\] .*checks\|FAIL\|rror" | head -5
echo "== play_run"; timeout 1200 $L run $T/harness_play.luau $SRC - "$(cat $T/play_run.luau)" > $O/play.log 2>&1; grep -a "\[play\] .*checks" $O/play.log
echo "== live_shoes"; timeout 900 $L run $T/harness_live.luau $SRC - "$(cat $T/live_shoes.luau)" > $O/live.log 2>&1; echo "live exit $?"
echo "== live_reveal"; timeout 900 $L run $T/harness_live.luau $SRC - "$(cat $T/live_reveal.luau)" > $O/reveal.log 2>&1; echo "reveal exit $?"
echo "== first30"; F=$O/first30; rm -rf $F; mkdir -p $F
N=$(grep -n "^-------.*0\. spawn" $T/feel_base.luau | head -1 | cut -d: -f1); head -$((N - 1)) $T/feel_base.luau > $O/first30.luau; cat $T/route.luau >> $O/first30.luau
timeout 1500 $L run $T/harness_live.luau $SRC - "EXPORT=nil REPORT_DIR='$F' $(cat $O/first30.luau)" > $F/log.txt 2>&1
grep -c "\[ok" $F/first30_report.txt; grep -E "BORED|purchase prompts" $F/first30_report.txt
for t in finale_play wb_play; do echo "== $t"; timeout 1200 $L run $T/harness_play.luau $SRC - "$(cat $T/$t.luau)" 2>&1 | grep -a "\[play\] .*checks\|FAIL" | head -5; done
echo "== all done"
