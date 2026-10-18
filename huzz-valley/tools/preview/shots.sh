#!/bin/sh
# Renders every built screen next to its reference page (2x). Usage: sh shots.sh <outDir> [name ...]
# Needs Lune (LUNE=path) and Playwright (NODE_PATH pointing at a global node_modules that has it).
# EXPORT_ONLY=1: only the JSON exports and <outDir>/manifest.txt, no pictures (overflow.sh checks them).
cd "$(dirname "$0")" || exit 1
OUT=$1; shift; mkdir -p "$OUT"
REF=../../design/pages
shot() { # name, reference page, width, height, options
	[ -n "$ONLY" ] && case " $ONLY " in *" $1 "*) ;; *) return ;; esac
	if [ -n "$EXPORT_ONLY" ]; then
		sh run.sh "$OUT/$1.json" "$5" 2>&1 | grep -iE 'error|\[warn\]' | grep -v "icons can't be drawn" && echo "($1 had errors)"
		echo "$1 $3 $4 $OUT/$1.json" >> "$OUT/manifest.txt"
		return
	fi
	sh run.sh "$OUT/$1.json" "$5" 2>&1 | grep -iE 'error|\[warn\]' && echo "($1 had errors)"
	case $2 in none) R= ;; */*) R=$2 ;; *) R=$REF/$2.png ;; esac # (a path: a reference outside design/pages; none: ours alone, for side_by_side.py)
	node shoot.js "$OUT/$1.json" "$OUT/$1.png" "$3" "$4" "$R"
}
ONLY="$*"
shot shop-passes 01-shop-passes 1536 710 '{SCREEN="Shop", TAB="Passes", SCALE=2, PASSES="VIP"}'
shot shop-cosmetics 07-shop-cosmetics 1536 730 '{SCREEN="Shop", TAB="Cosmetics", SCALE=2, OWN="MidnightOutfit"}'
shot shop-items 07-shop-cosmetics 1536 730 '{SCREEN="Shop", TAB="Items", SCALE=2, OWN="MintTrail"}'
shot shop-knives none 1536 730 '{SCREEN="Shop", TAB="Items", SCALE=2, OWN="SpinKnife,IceKnife", COINS=1500, SCROLL=890}' # (the owner's knives, Oct 18)
shot shop-coins none 1536 730 '{SCREEN="Shop", TAB="Coins", SCALE=2}' # (vs the Oct 17 mockup: side_by_side.py coins)
shot settings-social 06-settings-social 1536 640 '{SCREEN="Settings", TAB="Social", SCALE=2}'
shot settings-audio 09-settings-audio 1536 636 '{SCREEN="Settings", TAB="Audio", SCALE=2}'
shot settings-controls 10-settings-controls 1536 636 '{SCREEN="Settings", TAB="Controls", SCALE=2}'
shot menu 12-main-menu 1536 658 '{SCREEN="Menu", SCALE=2}'
shot lobby-hud 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, ROUND=17}'
shot dances none 1536 700 '{SCREEN="Dances", SCALE=2}' # (vs the Oct 17 mockup: side_by_side.py dances)
shot index 02-character-index 1536 700 '{SCREEN="Index", SCALE=2}'
shot progression 04-progression-rewards 1536 700 '{SCREEN="Progression", TAB="Rewards", SCALE=2}'
shot tiers 11-tier-index 1536 700 '{SCREEN="Tiers", SCALE=2}'
shot quests 05-progression-quests 1536 700 '{SCREEN="Progression", TAB="Quests", SCALE=2}'
shot map-vote 15-map-vote 1536 656 '{SCREEN="MapVote", SCALE=2, VOTE="Base_Map,Halloween_Map,3,5,Halloween_Map"}'
shot girl-roll 15-map-vote 1536 656 '{SCREEN="Hud", SCALE=2, ROLL=6.5}'
shot power-bar 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, POWERS="Runner"}'
shot hero-choice 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, HERO=true}'
shot next-map 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, NEXTMAP=true, VOTE="Base_Map,Halloween_Map,3,5,Halloween_Map"}'
shot dance-wheel 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, WHEEL=true}'
shot how-to-play none 1536 694 '{SCREEN="HowToPlay", SCALE=2}' # (vs the Oct 17 mockup: side_by_side.py how-to-play)
shot results 13-lobby-hud 1536 694 '{SCREEN="Results", SCALE=2, RESULTS="Win"}'
shot round-hud 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, ROUNDHUD="Hero"}'
shot round-hud-runner none 1536 694 '{SCREEN="Hud", SCALE=2, ROUNDHUD="Runner", MESSAGE="Messi reached safety!"}' # (feel-ui-after.jpg)
shot round-count none 1536 694 '{SCREEN="Hud", SCALE=2, ROUNDHUD="Runner", COUNT=2.6}' # (3-2-1: "3" settled)
shot spin-wheel ../../design/spin-wheel-reference.webp 1536 936 '{SCREEN="SpinWheel", SCALE=1.2, SPINS=25, FREEIN=887, PITY=28}'
# Long names and every rarity (the overflow check; owner: "the rarities ... go out of the uis borders")
shot index-girls none 1536 700 '{SCREEN="Index", SCALE=2, GIRLS=true, SELECT="t_kurumi"}'
shot index-girls-uncommon none 1536 700 '{SCREEN="Index", SCALE=2, GIRLS=true, SELECT="t_unc"}'
shot index-girls-common none 1536 700 '{SCREEN="Index", SCALE=2, GIRLS=true, SELECT="t_akane"}'
shot index-girls-secret none 1536 700 '{SCREEN="Index", SCALE=2, GIRLS=true, SELECT="t_mitsuri"}'
shot index-girls-scrolled none 1536 700 '{SCREEN="Index", SCALE=2, GIRLS=true, SELECT="t_zero", SCROLL=246}'
shot tiers-girls none 1536 700 '{SCREEN="Tiers", SCALE=2, GIRLS=true}'
shot girl-roll-long none 1536 656 '{SCREEN="Hud", SCALE=2, ROLL=6.5, GIRL="Kurumi Tokisaki"}'
shot round-hud-long none 1536 694 '{SCREEN="Hud", SCALE=2, ROUNDHUD="Runner", GIRL="Kurumi Tokisaki", MESSAGE="Mitsuri Kanroji got Uncommon Girl 10 back up!"}'
shot results-long none 1536 694 '{SCREEN="Results", SCALE=2, RESULTS="Win", GIRL="Kurumi Tokisaki"}'
