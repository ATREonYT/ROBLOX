"""shoesheet.py: the drawn shoes on their rarity splats (as the inventory and the reveal show them), at 128 and 48 px.
  python3 shoesheet.py --png <dir> --out sheet.jpg [--old <dir of the old renders>] Name ...
"""
import argparse, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageChops

SPLAT = '/home/user/ROBLOX/hood/art/ui/splat.png'
SPLAT_RAINBOW = '/home/user/ROBLOX/hood/art/ui/splat_rainbow.png'
RARITY = [(178, 186, 198), (61, 155, 255), (166, 77, 255), (255, 150, 32), (255, 59, 92), (255, 236, 120)]
NAMES = ['Common', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Secret']


def on_splat(png, size, rank, bg='#2a2d36'):
	cell = Image.new('RGBA', (size, size), bg)
	sp = Image.open(SPLAT_RAINBOW if rank == 6 else SPLAT).convert('RGBA').resize((int(size * 0.98), int(size * 0.98)), Image.LANCZOS)
	if rank != 6:
		tint = Image.new('RGBA', sp.size, RARITY[rank - 1] + (255,))
		sp = ImageChops.multiply(sp, tint)
	cell.alpha_composite(sp, (int(size * 0.01), int(size * 0.03)))
	ic = Image.open(png).convert('RGBA').resize((int(size * 0.86), int(size * 0.86)), Image.LANCZOS)
	cell.alpha_composite(ic, (int(size * 0.07), int(size * 0.05)))
	return cell.convert('RGB')


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('--png', required=True)
	ap.add_argument('--out', required=True)
	ap.add_argument('--old')
	ap.add_argument('--ranks', required=True, help='Name=rank,...')
	ap.add_argument('names', nargs='+')
	a = ap.parse_args()
	ranks = dict(x.split('=') for x in a.ranks.split(','))
	font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 13)
	cols = 3
	bw = 128 + 6 + 48 + 6 + (128 + 6 if a.old else 0) + 130
	bh = 128 + 6
	rows = (len(a.names) + cols - 1) // cols
	sheet = Image.new('RGB', (cols * (bw + 8) + 8, rows * (bh + 4) + 8), '#14161b')
	for i, n in enumerate(a.names):
		x0, y0 = 8 + (i % cols) * (bw + 8), 8 + (i // cols) * (bh + 4)
		r = int(ranks[n])
		x = x0
		if a.old:
			sheet.paste(on_splat(os.path.join(a.old, 'Shoe_%s.png' % n), 128, r), (x, y0)); x += 134
		sheet.paste(on_splat(os.path.join(a.png, 'Shoe_%s.png' % n), 128, r), (x, y0)); x += 134
		sheet.paste(on_splat(os.path.join(a.png, 'Shoe_%s.png' % n), 48, r), (x, y0 + 40)); x += 54
		d = ImageDraw.Draw(sheet)
		d.text((x + 4, y0 + 46), n, fill='#ffe680', font=font)
		d.text((x + 4, y0 + 64), NAMES[r - 1], fill='#c0c4cc', font=font)
	sheet.save(a.out, quality=92)
	print(a.out, sheet.size)


if __name__ == '__main__':
	main()
