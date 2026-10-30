#!/bin/sh
# New Game Kit: start a new game from the kit.
# Usage (from the repo root): sh new-game-kit/tools/new_game.sh <folder> <PlaceName>
#   e.g.  sh new-game-kit/tools/new_game.sh egg-run EggRun
# Copies the kit (without its built place), renames the project and the data
# store, and builds <folder>/places/<PlaceName>.rbxl.
set -e
FOLDER=$1
NAME=$2
if [ -z "$FOLDER" ] || [ -z "$NAME" ]; then
	echo "usage: sh new-game-kit/tools/new_game.sh <folder> <PlaceName>"; exit 1
fi
case $NAME in *[!A-Za-z0-9]*) echo "PlaceName: letters and digits only"; exit 1 ;; esac
if [ -e "$FOLDER" ]; then
	echo "$FOLDER already exists"; exit 1
fi
KIT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$FOLDER"
(cd "$KIT" && tar cf - --exclude=./places .) | (cd "$FOLDER" && tar xf -)
cd "$FOLDER"
sed -i.bak "s/\"name\": \"NewGame\"/\"name\": \"$NAME\"/; s/\"name\": \"NewGameTest\"/\"name\": \"${NAME}Test\"/" default.project.json test.project.json
sed -i.bak "s/storeName = \"PlayerData_v1\"/storeName = \"${NAME}_PlayerData_v1\"/" src/Config/GameConfig.luau
rm -f default.project.json.bak test.project.json.bak src/Config/GameConfig.luau.bak
"${LUNE:-lune}" run tools/build_place.luau
echo "[new game] $FOLDER is ready. Next: README.md, 'Start a new game in 10 steps', step 2."
