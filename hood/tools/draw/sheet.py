"""sheet.py: side-by-side sheets of the drawn icons against the reference crops (brief 26).

Each icon gets a block: the reference crop | ours on the same slot colour at 256 px, and below both again at 128 and
48 px. Two blocks per row; a sheet is at most 1200 px tall (more icons spill into _2, _3 sheets).

  python3 hood/tools/draw/sheet.py --brief <dir with ref17/ ref22/> --png <dir of our PNGs> --out sheet.jpg Name ...
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

# name -> (reference image relative to --brief, square crop box, slot colour top, slot colour bottom)
REFS = {
	'Power': ('ref17/user_27.png', (230, 413, 345, 528), '#56ecea', '#2a95cc'),
	'Muscle': ('ref17/user_27.png', (230, 413, 345, 528), '#56ecea', '#2a95cc'),
	'Basket': ('ref22/ref22_hud_buttons.png', (134, 0, 332, 198), '#fdc33c', '#fdb52c'),
	'BasketRed': ('ref22/ref22_store_packs.png', (40, 12, 215, 187), '#fdb62c', '#fca422'),
	'World': ('ref22/ref22_hud_buttons.png', (46, 204, 229, 387), '#7fd63a', '#66cf18'),
	'Rebirth': ('ref17/user_27.png', (96, 107, 255, 266), '#13bde6', '#0a8ee6'),
	'RebirthSkip': ('ref17/user_27.png', (835, 875, 935, 975), '#13bde6', '#0a8ee6'),
	'Backpack': ('ref22/ref22_hud_buttons.png', (48, 631, 217, 800), '#fdc64a', '#fdb83a'),
	'PotionRed': ('ref22/ref22_store_boosts.png', (115, 700, 445, 1030), '#d4505a', '#c8414a'),
	'Quest': ('ref22/ref22_hud_buttons.png', (262, 627, 437, 802), '#e8936a', '#dd8458'),
	'Rewards': ('ref17/user_26.png', (1468, 22, 1628, 182), '#b8e86a', '#a8dc58'),
	'Trophy': ('ref22/ref22_store_packs.png', (120, 410, 410, 700), '#fdb52c', '#fca422'),
	'CashTiny': ('ref22/ref22_store_packs.png', (120, 410, 410, 700), '#fdb52c', '#fca422'),  # nearest: the trophy packs
	'CashSmall': ('ref22/ref22_store_packs.png', (800, 420, 1090, 710), '#fdb52c', '#fca422'),
	'Cash': ('ref22/ref22_store_packs.png', (120, 410, 410, 700), '#7a7f8c', '#6a6f7c'),
	'BoostBundle': ('ref22/ref22_store_boosts.png', (120, 270, 420, 570), '#c63ad8', '#e8304a'),
	'CashMedium': ('ref22/ref22_store_packs.png', (120, 700, 420, 1000), '#fdb52c', '#fca422'),
	'CashLarge': ('ref22/ref22_store_packs.png', (810, 700, 1110, 1000), '#fdb52c', '#fca422'),
	'PowerTiny': ('ref22/ref22_store_packs.png', (120, 410, 410, 700), '#fdb52c', '#fca422'),
	'PowerSmall': ('ref22/ref22_store_packs.png', (800, 420, 1090, 710), '#fdb52c', '#fca422'),
	'PowerMedium': ('ref22/ref22_store_packs.png', (120, 700, 420, 1000), '#fdb52c', '#fca422'),
	'PowerLarge': ('ref22/ref22_store_packs.png', (810, 700, 1110, 1000), '#fdb52c', '#fca422'),
	'TenXCash': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'DoubleCash': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'DoublePower': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'VIP': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'AutoFight': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'Lucky': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'TripleOpen': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'ExtraEquip': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'ProBay': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'GoldBay': ('ref17/user_28.png', (392, 290, 842, 740), '#fdb52c', '#fca422'),
	'BlockParty': ('ref17/user_28.png', (1110, 290, 1560, 740), '#c040e0', '#a830d0'),
	'Arrow': ('ref17/user_27.png', (670, 370, 860, 560), '#9ad04a', '#6cb83a'),
	'Evolve': ('ref17/user_27.png', (670, 370, 860, 560), '#9ad04a', '#6cb83a'),
	'Robux': ('ref22/ref22_store_packs.png', (540, 585, 610, 655), '#9be03a', '#7cd030'),
	'XP': ('ref17/user_27.png', (160, 660, 350, 850), '#7ad8f0', '#4ab8e8'),
	'Delete': ('ref22/ref22_store_packs.png', (1385, 30, 1515, 160), '#fdb52c', '#fca422'),
	'PotionGold': ('ref22/ref22_store_boosts.png', (840, 700, 1170, 1030), '#fdb32c', '#fca422'),
}

W, GAP, PAD = 256, 6, 6


def slot(size, top, bottom):
	im = Image.new('RGB', (size, size), top)
	if top != bottom:
		t, b = Image.new('RGB', (1, 1), top).getpixel((0, 0)), Image.new('RGB', (1, 1), bottom).getpixel((0, 0))
		d = ImageDraw.Draw(im)
		for y in range(size):
			u = y / max(1, size - 1)
			d.line([(0, y), (size, y)], fill=tuple(int(t[i] + (b[i] - t[i]) * u) for i in range(3)))
	return im


def ours(png, size, top, bottom):
	ic = Image.open(png).convert('RGBA').resize((size, size), Image.LANCZOS)
	bg = slot(size, top, bottom).convert('RGBA')
	bg.alpha_composite(ic)
	return bg.convert('RGB')


def block(name, args, font):
	ref = REFS.get(name)
	top, bottom = (ref[2], ref[3]) if ref else ('#7a7f8c', '#6a6f7c')
	bw, bh = 2 * W + GAP, W + GAP + 128
	im = Image.new('RGB', (bw, bh), '#1d2027')
	png = os.path.join(args.png, name + '.png')
	if ref:
		src = Image.open(os.path.join(args.brief, ref[0])).convert('RGB').crop(ref[1])
		for s, (x, y) in ((W, (0, 0)), (128, (0, W + GAP)), (48, (2 * 128 + 2 * GAP, W + GAP))):
			im.paste(src.resize((s, s), Image.LANCZOS), (x, y))
	for s, (x, y) in ((W, (W + GAP, 0)), (128, (128 + GAP, W + GAP)), (48, (2 * 128 + 3 * GAP + 48, W + GAP))):
		im.paste(ours(png, s, top, bottom), (x, y))
	d = ImageDraw.Draw(im)
	tx = 2 * 128 + 2 * GAP
	d.text((tx, W + GAP + 56), name, fill='#ffe680', font=font)
	d.text((tx, W + GAP + 78), 'ref | ours' if ref else '(no ref) | ours', fill='#c0c4cc', font=font)
	return im


def counters_block(args, font):
	"""The HUD counters: the ref's bottom-left counters | our Rebirth and Cash at the same size, with numbers."""
	bw, bh = 2 * W + GAP, W + GAP + 128
	im = Image.new('RGB', (bw, bh), '#1d2027')
	ref = Image.open(os.path.join(args.brief, 'ref17/user_26.png')).convert('RGB').crop((20, 860, 320, 1070))
	ref = ref.resize((W, int(W * ref.height / ref.width)), Image.LANCZOS)
	im.paste(ref, (0, 0))
	# ours on the ref's grey floor colour, icons the same size as the ref's (about 0.19 of the crop width)
	panel = Image.new('RGBA', ref.size, '#b9c0cc')
	try:
		big = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 34)
	except OSError:
		big = font
	d = ImageDraw.Draw(panel)
	ic = int(W * 0.19)
	for (name, num, fill, y) in (('Rebirth', '8', '#ffe0e0', 18), ('Cash', '67.2K', '#ffe84a', 120)):
		p = os.path.join(args.png, name + '.png')
		if os.path.exists(p):
			icon = Image.open(p).convert('RGBA').resize((ic, ic), Image.LANCZOS)
			panel.alpha_composite(icon, (12, y))
		d.text((12 + ic + 10, y + ic // 2), num, fill=fill, font=big, anchor='lm', stroke_width=4, stroke_fill='#1a1020')
	im.paste(panel.convert('RGB'), (W + GAP, 0))
	d = ImageDraw.Draw(im)
	d.text((8, W + GAP + 40), 'HUD counters: ref (left) | ours, Rebirth and Cash at the ref icon size', fill='#ffe680', font=font)
	return im


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('--brief', required=True)
	ap.add_argument('--png', required=True)
	ap.add_argument('--out', required=True)
	ap.add_argument('--counters', action='store_true', help='add the HUD counters block')
	ap.add_argument('names', nargs='+')
	args = ap.parse_args()
	try:
		font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 17)
	except OSError:
		font = ImageFont.load_default()
	blocks = [block(n, args, font) for n in args.names]
	if args.counters:
		blocks.append(counters_block(args, font))
	bw, bh = blocks[0].size
	rows_per_sheet = max(1, (1200 - 2 * PAD + GAP) // (bh + GAP))
	per = rows_per_sheet * 2
	sheets = [blocks[i:i + per] for i in range(0, len(blocks), per)]
	for si, group in enumerate(sheets):
		rows = (len(group) + 1) // 2
		cols = 2 if len(group) > 1 else 1
		sheet = Image.new('RGB', (2 * PAD + cols * bw + (cols - 1) * 3 * GAP, 2 * PAD + rows * bh + (rows - 1) * GAP), '#14161b')
		for i, b in enumerate(group):
			sheet.paste(b, (PAD + (i % 2) * (bw + 3 * GAP), PAD + (i // 2) * (bh + GAP)))
		out = args.out if len(sheets) == 1 else args.out.replace('.jpg', '_%d.jpg' % (si + 1))
		sheet.save(out, quality=92)
		print(out, sheet.size)


if __name__ == '__main__':
	main()
