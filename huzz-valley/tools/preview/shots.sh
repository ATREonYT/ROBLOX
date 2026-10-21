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
# The Shop: one page since Oct 20 14:31 (his reference video 1425-shop-reference.mp4, 1280 x 704 when halved: tools/preview/shop_vs_video.py);
# TAB = the section it opens scrolled to (Crates, Knives, Passes, Aura, Coins, Cosmetics, or a crate id), none = the top.
shot shop-top none 2560 1408 '{SCREEN="Shop", SCALE=2.5, GEMS=320}' # (vs his video at 0.3 s)
shot shop-crates none 2560 1408 '{SCREEN="Shop", TAB="Crates", SCALE=2.5, GEMS=320, CRATEPITY=7}'
shot shop-halloween none 2560 1408 '{SCREEN="Shop", TAB="Witch", SCALE=2.5, GEMS=12000, OWN="CandyReaper"}' # (where WITCH'S BREW opens it: the Witch Crate's panel in)
shot shop-dances none 2560 1408 '{SCREEN="Shop", TAB="Dances", SCALE=2.5, COINS=900}' # (Oct 20 20:34: every dance for coins, the Dance Pack on top)
shot shop-dance-panel none 2560 1408 '{SCREEN="Shop", TAB="Dances", SCALE=2.5, COINS=900, SELECT="DanceShowstopper"}' # (a dance's panel: preview and BUY)
shot shop-knives none 2560 1408 '{SCREEN="Shop", TAB="Knives", SCALE=2.5, OWN="SpinKnife,IceKnife", COINS=1500}'
shot shop-filter-knives none 2560 1408 '{SCREEN="Shop", TAB="Knives", SCALE=2.5, OWN="SpinKnife,IceKnife", COINS=1500, SELECT="KnivesRarityEpic"}' # (the filters, Oct 20 15:13: EPIC picked)
shot shop-abilities none 2560 1408 '{SCREEN="Shop", TAB="Abilities", SCALE=2.5, COINS=700, ABILITIES="Invisible,Radar", LOADOUT="Runner=Invisible,CatcherQ=Radar"}' # (bought abilities, Oct 20: buy and pick them here, UI/AbilityCards)
shot shop-filter-cosmetics none 2560 1408 '{SCREEN="Shop", TAB="Cosmetics", SCALE=2.5, SELECT="CosmeticsTypeTrail"}' # (TRAILS picked)
shot shop-passes none 2560 1408 '{SCREEN="Shop", TAB="Passes", SCALE=2.5, PASSES="VIP"}' # (vs his video at 2.5 s)
shot shop-aura none 2560 1408 '{SCREEN="Shop", TAB="Aura", SCALE=2.5, GEMS=320}'
shot shop-coins none 2560 1408 '{SCREEN="Shop", TAB="Coins", SCALE=2.5}' # (vs his video at 1.3 s)
shot shop-cosmetics none 2560 1408 '{SCREEN="Shop", TAB="Cosmetics", SCALE=2.5, OWN="MidnightOutfit"}'
shot crate-spin none 1536 864 '{SCREEN="CrateOpen", TAB="Sweets", SCALE=1.2, CRATE_T=3.2}' # (the reel mid-spin)
shot crate-prize none 1536 864 '{SCREEN="CrateOpen", TAB="Sweets", SCALE=1.2, CRATEPITY=39, CRATE_T=8}' # (a Legendary: pity)
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
shot power-bar none 1536 694 '{SCREEN="Hud", SCALE=2, POWERS="Runner"}' # (vs his pic c: tools/preview/side_by_side_bar.py)
shot power-bar-catcher none 1536 694 '{SCREEN="Hud", SCALE=2, POWERS="Catcher"}' # (vs his pic b)
shot power-bar-stunned none 1536 694 '{SCREEN="Hud", SCALE=2, POWERS="Catcher", POWERSTATE="Stunned"}'
shot power-bar-carrying none 1536 694 '{SCREEN="Hud", SCALE=2, POWERS="Runner", POWERSTATE="Carrying", ABILITY="BodyDouble"}'
shot power-bar-cooldown none 1536 694 '{SCREEN="Hud", SCALE=2, POWERS="Catcher", POWERSTATE="Cooldown"}'
shot power-bar-banana none 1536 694 '{SCREEN="Hud", SCALE=2, POWERS="Runner", POWERSTATE="Carrying", ABILITY="BananaPeel"}' # (his power pictures, Oct 20 20:34)
shot hero-choice 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, HERO=true}'
shot next-map 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, NEXTMAP=true, VOTE="Base_Map,Halloween_Map,3,5,Halloween_Map"}'
shot dance-wheel 13-lobby-hud 1536 694 '{SCREEN="Hud", SCALE=2, WHEEL=true}'
shot how-to-play none 1536 694 '{SCREEN="HowToPlay", SCALE=2}' # (vs the Oct 17 mockup: side_by_side.py how-to-play)
shot results none 1536 694 '{SCREEN="Results", SCALE=2, RESULTS="Win", XP=1073}' # (the winner page vs his picture a: side_by_side.py winner)
shot results-catchers none 1536 694 '{SCREEN="Results", SCALE=2, RESULTS="Win", TEAM="Catchers", XP=1073}'
shot daily-quests none 1536 980 '{SCREEN="DailyQuests", SCALE=2}' # (vs his picture d: side_by_side.py daily-quests)
shot combine none 1536 1200 '{SCREEN="Combine", SCALE=2, GIRLS=true, COPIES="t_kurumi:Normal=3,Silver=1;t_zero:Normal=1;t_rem:Gold=2", TAB="t_kurumi"}' # (the Combine machine's window, Oct 20)
shot index-prestige none 1536 700 '{SCREEN="Index", SCALE=2, GIRLS=true, SELECT="t_kurumi", DUPES="t_kurumi=2", PRESTIGE="t_kurumi=1"}'
shot lobby-hud-friend none 1536 694 '{SCREEN="Hud", SCALE=2, ROUND=17, FRIEND=true}' # (INVITE, SPIN, QUESTS; "+10% COINS" with a friend in)
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
