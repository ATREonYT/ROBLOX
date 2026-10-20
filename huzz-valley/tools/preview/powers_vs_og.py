"""One sheet for the round abilities (Oct 19 names): the other game's Soul Reaper slash (docs/previews/feel-ability.jpg,
its big frame, the Oct 17 reference for how a power should pop) next to each of ours at its peak (stills from
motion3d/power_scene.luau), same height.
Usage (from huzz-valley/): python3 tools/preview/powers_vs_og.py <stills dir> [out.jpg]
  The stills dir is MOTION3D_KEEP from `sh video.sh power_scene.luau ...` (still_<frame>.png, in the scene's order).
"""
import sys
import glob
import os
from PIL import Image, ImageDraw, ImageFont

H = 300  # each tile's height
NAMES = ['Shield', 'Invisible (as others see it)', 'Glitchy', 'Body Double', 'Speed Boost (carrying)',
	'Bear Trap: the throw', 'Bear Trap: snapped', 'Slow Wave', 'Banana Peel: dropped', 'Banana Peel: the slip',
	'Smoke Bomb', 'Radar', 'Lasso: the pull']


def font(size):
	try:
		f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
		f.set_variation_by_axes([800])
		return f
	except (OSError, AttributeError):
		return ImageFont.load_default()


def tile(im, label):
	im = im.convert('RGB')
	im = im.resize((round(im.width * H / im.height), H))
	d = ImageDraw.Draw(im)
	d.rectangle((0, H - 34, im.width, H), fill=(12, 10, 28))
	d.text((10, H - 30), label, font=font(20), fill=(255, 255, 255))
	return im


def main(stills, out):
	files = sorted(glob.glob(os.path.join(stills, 'still_*.png')), key=lambda f: int(f.split('_')[-1].split('.')[0]))
	ours = [Image.open(f).crop((140, 60, 1140, 660)) for f in files]  # (1280 x 720 frames: the middle of the field)
	og = Image.open('docs/previews/feel-ability.jpg').crop((0, 160, 800, 610))
	tiles = [tile(og, 'Other game: Soul Reaper (reference)')] + [tile(im, n) for im, n in zip(ours, NAMES)]
	cols = 3
	rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
	width = max(sum(t.width for t in r) + 8 * (len(r) - 1) for r in rows)
	title_h = 44
	sheet = Image.new('RGB', (width, title_h + len(rows) * (H + 8)), (12, 10, 28))
	d = ImageDraw.Draw(sheet)
	d.text((12, 8), 'Abilities: wind-up, one bright frame (at most one a second), the effect, a short fade', font=font(24), fill=(255, 255, 255))
	y = title_h
	for r in rows:
		x = 0
		for t in r:
			sheet.paste(t, (x, y))
			x += t.width + 8
		y += H + 8
	sheet.save(out, quality=88)
	print(out, sheet.size)


if __name__ == '__main__':
	main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'docs/previews/abilities-sheet.jpg')
