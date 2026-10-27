#!/usr/bin/env python3
"""Cut the owner's icon sheet (Oct 27: a grid of cartoon icons, each over its file name, on a dark blurred background)
into one transparent 512 x 512 PNG per icon, named as the sheet says, in the framing hood/art/icons3d uses (the art
centred, its longer side 88% of the square).

  python3 hood/tools/icons/cut_sheet.py <sheet.png> <out dir> [--checker <name1,name2> <image.png>]

How: the background is a smooth blur and every icon wears a thick dark outline, so the background is the smooth
(low-gradient) area that touches a band's edge; everything it doesn't reach is the icon. The rows' bands and their
file names are below (the label strip under each icon is cut off). --checker: an image of icons on a drawn grey and
white checkerboard (left to right, names given): there the light, grey pixels reached from the edge are the background.
Needs numpy, scipy and Pillow.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

TEN = [round(76.8 + 153.6 * i) for i in range(10)]  # the four full rows' column centres
ROWS = [  # (top, bottom of the icons, above the labels), names left to right, the icons' centres (x)
	((18, 150), 'Shop Rebirth Rewards Backpack World Missions Quest SkinsPistol Trophy Evolve', TEN),
	((190, 322), 'Sneaker ShoeBox ShoePile Gun Muscle Basket Shield Skull XP VIP', TEN),
	((368, 490), 'Arrow RebirthSkip Cash Power Robux CashTiny CashSmall CashMedium CashLarge PowerMedium', TEN),
	((534, 660), 'PowerLarge PowerPack1 PowerPack2 PowerPack3 DoublePower DoubleCash TenXCash Lucky TripleOpen ExtraEquip', TEN),
	((702, 842), 'AutoCollect BoostBundle PotionRed PotionGold BlockParty SpinWheel SpinWheelDisc PlaytimeGift StarterCrate',
		[85, 240, 393, 543, 699, 860, 1028, 1223, 1423]),
	((878, 972), 'Delete Favorite Search', [92, 243, 393]),
]


def frame(rgba, size=512, fill=0.88):
	a = rgba[:, :, 3]
	ys, xs = np.nonzero(a > 8)
	crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
	k = size * fill / max(crop.size)
	crop = crop.resize((max(1, round(crop.size[0] * k)), max(1, round(crop.size[1] * k))), Image.LANCZOS)
	out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
	out.paste(crop, ((size - crop.size[0]) // 2, (size - crop.size[1]) // 2), crop)
	return out


def background(smooth):
	"""The smooth pixels connected to the image's edge."""
	lab, _ = ndimage.label(smooth)
	edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
	return np.isin(lab, list(edge))


def pieces(fg, expect, gap):
	"""Split the foreground into `expect` icons, left to right (sparkles and parts join their icon)."""
	cols = fg.any(0)
	grown = ndimage.binary_dilation(cols, iterations=gap)
	lab, n = ndimage.label(grown)
	spans = []
	for i in range(1, n + 1):
		xs = np.nonzero(lab == i)[0]
		if xs.max() - xs.min() > 2 * gap + 8:
			spans.append((xs.min(), xs.max()))
	spans.sort()
	while len(spans) > expect:  # join the closest neighbours until the count matches
		gaps = [spans[i + 1][0] - spans[i][1] for i in range(len(spans) - 1)]
		i = int(np.argmin(gaps))
		spans[i:i + 2] = [(spans[i][0], spans[i + 1][1])]
	return [(a + gap, b - gap) for a, b in spans]


def save(band, keep, x0, name, out, blur):
	alpha = ndimage.gaussian_filter(keep.astype(float), blur)
	rgba = np.dstack([band[:, x0:x0 + keep.shape[1]], alpha * 255]).clip(0, 255).astype(np.uint8)
	frame(rgba).save(f'{out}/{name}.png')


def cut_sheet(path, out):
	im = np.array(Image.open(path).convert('RGB')).astype(float)
	done = []
	for (top, bottom), names, centres in ROWS:
		names = names.split()
		band = im[top:bottom]
		g = np.abs(np.diff(band, axis=0, prepend=band[:1])).sum(2) + np.abs(np.diff(band, axis=1, prepend=band[:, :1])).sum(2)
		bg = background(ndimage.binary_erosion(g < 14, iterations=1, border_value=1))
		fg = ndimage.binary_fill_holes(ndimage.binary_opening(~bg, iterations=2))
		# every piece of foreground (an icon, its sparkles) goes to the icon whose centre is nearest
		lab, n = ndimage.label(fg)
		if n == 0:
			continue
		sizes = ndimage.sum(fg, lab, range(1, n + 1))
		cx = [c[1] for c in ndimage.center_of_mass(fg, lab, range(1, n + 1))]
		owner = [int(np.argmin([abs(x - c) for c in centres])) for x in cx]
		for k, name in enumerate(names):
			mine = [i + 1 for i in range(n) if owner[i] == k]
			if not mine:
				continue
			big = max(sizes[i - 1] for i in mine)
			keep = np.isin(lab, [i for i in mine if sizes[i - 1] >= 0.02 * big])
			xs = np.nonzero(keep.any(0))[0]
			x0, x1 = xs.min(), xs.max() + 1
			save(band, keep[:, x0:x1], x0, name, out, 0.6)
			done.append(name)
	return done


def cut_checker(path, names, out):
	im = np.array(Image.open(path).convert('RGB')).astype(float)
	sat = im.max(2) - im.min(2)
	bg = background((im.mean(2) > 150) & (sat < 30))
	fg = ndimage.binary_fill_holes(ndimage.binary_opening(~bg, iterations=2))
	done = []
	for name, (x0, x1) in zip(names, pieces(fg, len(names), 8)):
		save(im, fg[:, x0:x1 + 1], x0, name, out, 0.8)
		done.append(name)
	return done


if __name__ == '__main__':
	sheet, out = sys.argv[1], sys.argv[2]
	print('sheet:', ' '.join(cut_sheet(sheet, out)))
	if len(sys.argv) > 3 and sys.argv[3] == '--checker':
		print('checker:', ' '.join(cut_checker(sys.argv[5], sys.argv[4].split(','), out)))
