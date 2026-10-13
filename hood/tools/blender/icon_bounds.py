"""icon_bounds.py: write M.Bounds into Shared/Models/IconModels.lua from the PNGs in hood/art/icons3d (brief 25, for UI6).

M.Bounds[id] = { x0, y0, x1, y1 }: the PNG's drawn content (alpha > 10%) as fractions of the canvas, top-left origin,
3 decimals. UIKit places each picture by it (a wide shoe and a tall backpack both fill a HUD square). Run it after every
render batch or import (hood/tools/import_icons.py runs it); plain python3 + Pillow, no numpy:
  python3 hood/tools/blender/icon_bounds.py            # rewrites the M.Bounds block (adds it after M.Fallback if missing)
  python3 hood/tools/blender/icon_bounds.py --check    # prints what would change, writes nothing
"""
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
ICONS = os.path.join(HOOD, 'art', 'icons3d')
MODULE = os.path.join(HOOD, 'src', 'ReplicatedStorage', 'Shared', 'Models', 'IconModels.lua')
BLOCK = re.compile(r'-- \(brief 25\) Each PNG\'s drawn content.*?\nM\.Bounds = \{\n.*?\n\}\n', re.S)


def bounds(path):
	im = Image.open(path).convert('RGBA')
	w, h = im.size
	box = im.getchannel('A').point(lambda v: 255 if v > 25 else 0).getbbox()
	if not box:
		return None
	return (box[0] / w, box[1] / h, box[2] / w, box[3] / h)


def block():
	rows = []
	for f in sorted(os.listdir(ICONS)):
		if not f.endswith('.png'):
			continue
		b = bounds(os.path.join(ICONS, f))
		if b:
			rows.append('\t%s = { %.3f, %.3f, %.3f, %.3f },' % ((f[:-4],) + b))
	return ("-- (brief 25) Each PNG's drawn content: { x0, y0, x1, y1 } as fractions of the 512 canvas (alpha > 10%, top-left\n"
		"-- origin), written by hood/tools/blender/icon_bounds.py after each render batch. UIKit places pictures by it.\n"
		"M.Bounds = {\n" + '\n'.join(rows) + '\n}\n')


def main(argv):
	global ICONS
	if '--icons' in argv:
		ICONS = argv[argv.index('--icons') + 1]
	src = open(MODULE).read()
	new = block()
	if BLOCK.search(src):
		out = BLOCK.sub(lambda m: new, src)
	else:
		i = src.index('\nM.BoxLidLine')
		out = src[:i + 1] + new + src[i + 1:]
	if '--check' in argv:
		print('unchanged' if out == src else 'would update M.Bounds (%d rows)' % new.count(' = {'))
		return 0
	if out != src:
		open(MODULE, 'w').write(out)
	print('M.Bounds: %d rows' % (new.count(' = {') - 0))
	return 0


if __name__ == '__main__':
	sys.exit(main(sys.argv[1:]))
