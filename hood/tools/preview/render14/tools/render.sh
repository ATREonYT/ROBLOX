#!/bin/sh
# render.sh <scene.json> <views.json> <out dir> [W H]: render14 stills (one PNG per view). Run `npm install` in
# render14 first (three.js + Playwright); CHROME=/path/to/chrome if Playwright's own browser isn't installed.
T=$(cd "$(dirname "$0")" && pwd)
cd "$T/.." && W=${4:-1200} H=${5:-754} node shoot.js "$1" "$2" "$3" 2>&1 | grep -v "^loaded" | tail -6
