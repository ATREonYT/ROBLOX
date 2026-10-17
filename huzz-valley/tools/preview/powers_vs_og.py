"""One side-by-side for the powers: the other game's Soul Reaper slash (docs/previews/feel-ability.jpg, its big frame)
next to our four powers at their peak (stills from motion3d/power_scene.luau), same height, plus the prize girl's
stand before and after.
Usage (from huzz-valley/): python3 tools/preview/powers_vs_og.py <stills dir> [out.jpg]
  The stills dir is MOTION3D_KEEP from `sh video.sh power_scene.luau ...` (still_<frame>.png).
"""
import sys
import glob
import os
from PIL import Image, ImageDraw, ImageFont

H = 360  # each tile's height


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
	names = ['Heart Shield', 'Rizz Rush', 'Love Trap', 'Charm Wave', 'Prize girl: before', 'Prize girl: after']
	ours = [Image.open(f) for f in files]
	og = Image.open('docs/previews/feel-ability.jpg').crop((0, 160, 800, 610))
	og_t = tile(og, 'Other game: Soul Reaper slash (reference)')
	# our stills are 1280 x 720: crop round the action so the framing is close to the reference's
	def crop(im, box):
		return im.crop(box)
	peak = [
		crop(ours[0], (0, 120, 900, 626)), crop(ours[1], (190, 120, 1090, 626)), crop(ours[2], (380, 120, 1280, 626)),
		crop(ours[3], (190, 120, 1090, 626)),
	]
	row1 = [og_t, tile(peak[3], 'Ours: Charm Wave (peak)')]
	row2 = [tile(p, n) for p, n in zip(peak[:3], names[:3])]
	row3 = [tile(crop(ours[4], (340, 160, 940, 560)), names[4]), tile(crop(ours[5], (340, 160, 940, 560)), names[5])]
	rows = [row1, row2, row3]
	width = max(sum(t.width for t in r) + 8 * (len(r) - 1) for r in rows)
	title_h = 44
	sheet = Image.new('RGB', (width, title_h + len(rows) * (H + 8)), (12, 10, 28))
	d = ImageDraw.Draw(sheet)
	d.text((12, 8), 'Powers: wind-up 0.15-0.25 s, one bright frame, 0.35 s effect, 0.15 s fade (white core, pink, purple)', font=font(24), fill=(255, 255, 255))
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
	main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'docs/previews/feel-powers-after.jpg')
