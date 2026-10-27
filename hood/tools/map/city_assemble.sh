#!/bin/sh
# city_assemble.sh: rebuild hood/src/ServerStorage/TheCity.lua (World 2's map: the Business District plaza lobby and its avenue)
# from World 1's shared pieces plus the city's own (tools/map/city). Edit the pieces, never TheCity.lua by hand; the
# order is in city/ASSEMBLE.txt (paths from tools/map). World 1's map is assemble.sh.
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" && cat $(cat city/ASSEMBLE.txt) > "$D/../../src/ServerStorage/TheCity.lua" && echo "assembled TheCity.lua"
