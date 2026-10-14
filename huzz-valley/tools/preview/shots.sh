#!/bin/sh
# Renders every built screen next to its reference page (2x). Usage: sh shots.sh <outDir> [name ...]
# Needs Lune (LUNE=path) and Playwright (NODE_PATH pointing at a global node_modules that has it).
cd "$(dirname "$0")" || exit 1
OUT=$1; shift; mkdir -p "$OUT"
REF=../../design/pages
shot() { # name, reference page, width, height, options
	[ -n "$ONLY" ] && case " $ONLY " in *" $1 "*) ;; *) return ;; esac
	sh run.sh "$OUT/$1.json" "$5" 2>&1 | grep -iE 'error|\[warn\]' && echo "($1 had errors)"
	node shoot.js "$OUT/$1.json" "$OUT/$1.png" "$3" "$4" "$REF/$2.png"
}
ONLY="$*"
shot shop-passes 01-shop-passes 1536 710 '{SCREEN="Shop", TAB="Passes", SCALE=2, PASSES="VIP"}'
shot shop-cosmetics 07-shop-cosmetics 1536 730 '{SCREEN="Shop", TAB="Cosmetics", SCALE=2, OWN="MidnightOutfit"}'
shot shop-coins 08-shop-coins 1536 730 '{SCREEN="Shop", TAB="Coins", SCALE=2}'
shot settings-social 06-settings-social 1536 640 '{SCREEN="Settings", TAB="Social", SCALE=2}'
shot settings-audio 09-settings-audio 1536 636 '{SCREEN="Settings", TAB="Audio", SCALE=2}'
shot settings-controls 10-settings-controls 1536 636 '{SCREEN="Settings", TAB="Controls", SCALE=2}'
shot menu 12-main-menu 1536 658 '{SCREEN="Menu", SCALE=2}'
shot lobby-hud 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, ROUND=17}'
shot dances 03-dances 1536 700 '{SCREEN="Dances", SCALE=2}'
