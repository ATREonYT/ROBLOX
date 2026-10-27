#!/bin/sh
# assemble.sh: rebuild hood/src/ServerStorage/TheBlockV2.lua (the whole lobby + stages map) from the pieces.
# Edit the pieces, never TheBlockV2.lua by hand; the order is in pieces/ASSEMBLE.txt.
D=$(cd "$(dirname "$0")" && pwd)
cd "$D/pieces" && cat $(cat ASSEMBLE.txt) > "$D/../../src/ServerStorage/TheBlockV2.lua" && echo "assembled TheBlockV2.lua"
