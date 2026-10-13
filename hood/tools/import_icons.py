#!/usr/bin/env python3
"""Import the AI-made UI pictures (hood/art/AI_ICONS.md) into the game's icon set.

Needs: Python 3.8+ and Pillow (PIL), nothing else (no numpy). Run from the repo root:

  python3 hood/tools/import_icons.py --dry-run     # report + hood/art/incoming/_check.png, writes no icon
  python3 hood/tools/import_icons.py               # import every PNG in hood/art/incoming/
  python3 hood/tools/import_icons.py --only World,Basket

Input: hood/art/incoming/<Name>.png (any size; the name must match an id in IconModels.Images, e.g. World.png). Files
starting with '_' are ignored (the check sheet). The originals are never changed.

For each file:
  1. Background. If the picture has real transparency it is kept (a faint haze, alpha below 12, is cleared and
     reported). Otherwise the background is removed:
     - a background model is fitted to the border (a bilinear blend of the four corners' colours, so flat, near-flat
       and gradient backgrounds all work);
     - everything within --tol of that model and connected to the border is background (a flood fill from every
       border pixel), so it stops at the object's dark outline and never eats into the object;
     - enclosed holes (the gap under a basket handle, the middle of a ring) are cleared only when they are flat and
       very close to the background colour (--hole-tol) and at least 0.15% of the picture;
     - the edge is anti-aliased: on the object's 2 px rim, each pixel's alpha comes from how far its colour is from
       the background (relative to the outline's), and the background's tint is taken out of its colour (no halo).
  2. Islands. Specks and watermark islands smaller than --speck (0.5%) of the object's area are dropped.
  3. Framing. The object is trimmed, scaled so its longest side is 0.879 of the 512 canvas, centred, and saved as
     hood/art/icons3d/<Name>.png (the framing every icon shares; see hood/art/README_upload.md).
  4. Report. Unknown names, inputs that are badly off-square or under 256 px (or whose object is under 256 px),
     background haze left in a transparent input, and big removed holes are listed.
Labels: a picture with text baked in (a "2x" disc, say) is listed in IconModels.M.Labelled (id -> the text), so the Store
doesn't add its own sticker on top. Say which imported pictures carry text in hood/art/incoming/labels.txt (one
"Name: text" per line, e.g. "DoublePower: 2x"; # starts a comment) or with --label Name=text. Every imported picture
not listed there is removed from M.Labelled (its new picture has no text: AI_ICONS.md asks for none).
Then it refreshes IconModels.M.Bounds (hood/tools/blender/icon_bounds.py) and writes the contact sheet
hood/art/incoming/_check.png: every imported icon at 128 and 48 px on the three HUD button colours, with its name.
Upload as usual afterwards (hood/tools/upload_assets.py uploads only the changed PNGs).
"""
import argparse
import os
import re
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
HOOD = os.path.abspath(os.path.join(HERE, '..'))
INCOMING = os.path.join(HOOD, 'art', 'incoming')
ICONS = os.path.join(HOOD, 'art', 'icons3d')
MODULE = os.path.join(HOOD, 'src', 'ReplicatedStorage', 'Shared', 'Models', 'IconModels.lua')
CANVAS = 512
FRAME = 0.879  # the longest side of every icon's drawn content, as a fraction of the canvas (alpha > 50%)
HUD_COLOURS = [(250, 176, 40), (130, 210, 60), (200, 70, 220)]  # the Store, World and Shoes buttons
WORK_MAX = 1024  # bigger inputs are scaled down to this first (the output is 512)


# ------------------------------------------------------------------------------------------------- helpers
def known_ids(module=MODULE):
	"""The ids in IconModels.Images (the file names the game knows)."""
	try:
		text = open(module).read()
	except OSError:
		return set()
	m = re.search(r'M\.Images = \{\n(.*?)\n\}', text, re.S)
	return set(re.findall(r'^\s*(\w+)\s*=', m.group(1), re.M)) if m else set()


def maxdiff(a, b):
	"""Per pixel max |a - b| over R, G, B (mode L)."""
	d = ImageChops.difference(a.convert('RGB'), b.convert('RGB')).split()
	return ImageChops.lighter(ImageChops.lighter(d[0], d[1]), d[2])


def pixels(im):
	"""The pixel values as a flat list (Pillow 12+ get_flattened_data, else getdata)."""
	f = getattr(im, 'get_flattened_data', None)
	return list(f() if f else im.getdata())


def median(values):
	values = sorted(values)
	return values[len(values) // 2] if values else 0


def corner_colour(im, x0, y0, x1, y1):
	px = pixels(im.crop((x0, y0, x1, y1)))
	return tuple(median([p[c] for p in px]) for c in range(3))


def background_model(rgb):
	"""A bilinear background: each corner's median colour (over a 4% square), blended across the picture."""
	w, h = rgb.size
	k = max(2, int(min(w, h) * 0.04))
	tl = corner_colour(rgb, 0, 0, k, k)
	tr = corner_colour(rgb, w - k, 0, w, k)
	bl = corner_colour(rgb, 0, h - k, k, h)
	br = corner_colour(rgb, w - k, h - k, w, h)
	tiny = Image.new('RGB', (2, 2))
	tiny.putdata([tl, tr, bl, br])
	# resize a 2x2 with BILINEAR: the pixel centres of the 2x2 map to the corners' 4% squares
	return tiny.resize((w, h), Image.BILINEAR, box=(0.5, 0.5, 1.5, 1.5)), (tl, tr, bl, br)


class Comp:
	"""A connected region of a mask: its runs [(y, x0, x1)], size and whether it touches the picture's border."""
	__slots__ = ('runs', 'size', 'border')

	def __init__(self):
		self.runs, self.size, self.border = [], 0, False

	def draw(self, w, h, value=255):
		im = Image.new('L', (w, h), 0)
		d = ImageDraw.Draw(im)
		for (y, x0, x1) in self.runs:
			d.line((x0, y, x1 - 1, y), fill=value)
		return im


def label(mask):
	"""8-connected components of the 255 pixels of an L mask, by run-length union-find (fast in pure Python: a few
	runs per row, found with bytes.find). Returns [Comp]."""
	w, h = mask.size
	data = mask.point(lambda v: 255 if v == 255 else 0).tobytes()
	parent = []

	def find(a):
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a
	runs = []  # (y, x0, x1, id)
	prev = []
	for y in range(h):
		row = data[y * w:(y + 1) * w]
		cur = []
		x = row.find(b'\xff')
		while x != -1:
			e = row.find(b'\x00', x)
			if e == -1:
				e = w
			rid = len(parent)
			parent.append(rid)
			for (px0, px1, pid) in prev:  # 8-connected: overlap with the row above, one pixel either side
				if px0 <= e and px1 >= x:
					ra, rb = find(pid), find(rid)
					if ra != rb:
						parent[rb] = ra
			cur.append((x, e, rid))
			runs.append((y, x, e, rid))
			x = row.find(b'\xff', e)
		prev = cur
	comps = {}
	for (y, x0, x1, rid) in runs:
		c = comps.get(find(rid))
		if c is None:
			c = comps[find(rid)] = Comp()
		c.runs.append((y, x0, x1))
		c.size += x1 - x0
		if y == 0 or y == h - 1 or x0 == 0 or x1 == w:
			c.border = True
	return list(comps.values())


def paint(comps, w, h):
	im = Image.new('L', (w, h), 0)
	d = ImageDraw.Draw(im)
	for c in comps:
		for (y, x0, x1) in c.runs:
			d.line((x0, y, x1 - 1, y), fill=255)
	return im


def flood_from_border(mask):
	"""mask: L, 255 = may be background. Returns L: 255 where the region is connected to the border."""
	w, h = mask.size
	return paint([c for c in label(mask) if c.border], w, h)


def keep_components(mask, keep):
	"""mask L (0/255): only the components for which keep(comp) is true remain. Returns (mask, dropped sizes)."""
	w, h = mask.size
	comps = label(mask)
	kept = [c for c in comps if keep(c)]
	return paint(kept, w, h), [c.size for c in comps if not keep(c)]


# ------------------------------------------------------------------------------------------------- one picture
class Result:
	def __init__(self, name):
		self.name = name
		self.notes = []
		self.image = None
		self.size = None
		self.mode = ''


def remove_background(rgb, tol, hole_tol, res):
	"""Returns an L alpha for an opaque picture."""
	w, h = rgb.size
	bg, corners = background_model(rgb)
	diff = maxdiff(rgb, bg)
	near = diff.point(lambda v: 255 if v <= tol else 0)
	bgmask = flood_from_border(near)
	spread = max(max(c[i] for c in corners) - min(c[i] for c in corners) for i in range(3))
	res.mode = 'background removed (%s, corners differ by %d)' % ('gradient' if spread > 12 else 'flat', spread)
	# enclosed holes (a gap under a handle, the middle of a ring): flat regions very close to the background colour, not
	# connected to the border, at least 0.15% of the picture, and ringed by the dark outline (2/3 of the ring or more). They are cleared
	# only when the background colour isn't also used by the object itself (a white skull on a white background keeps
	# its white); otherwise they are reported.
	tight = diff.point(lambda v: 255 if v <= hole_tol else 0)
	inner = ImageChops.subtract(tight, bgmask)
	min_hole = 0.0015 * w * h
	dark = rgb.convert('L').point(lambda v: 255 if v < 110 else 0)
	holes = Image.new('L', (w, h), 0)
	n_holes = 0
	for c in label(inner):
		if c.size < min_hole:
			continue
		one = c.draw(w, h)
		ring = ImageChops.subtract(one.filter(ImageFilter.MaxFilter(9)), one)
		rn = ring.histogram()[255]
		dk = ImageChops.multiply(ring, dark).histogram()[255]
		if rn and dk >= 0.65 * rn:
			holes = ImageChops.lighter(holes, one)
			n_holes += 1
	hole_px = holes.histogram()[255]
	obj = ImageChops.subtract(ImageChops.invert(bgmask), holes)
	shared = ImageChops.multiply(obj, tight).histogram()[255]
	if hole_px and shared > 0.003 * max(1, obj.histogram()[255]):
		res.notes.append('possible enclosed hole(s) (%.1f%% of the picture) LEFT IN: the background colour is also used by the '
			'object; give the AI a transparent or a strongly coloured background' % (100.0 * hole_px / (w * h)))
		hole_px = 0
	if hole_px:
		# grow each hole up to the loose tolerance, like the outer background (its anti-aliased rim)
		grown = ImageChops.multiply(near, holes.filter(ImageFilter.MaxFilter(5)))
		bgmask = ImageChops.lighter(bgmask, grown)
		res.notes.append('cleared %d enclosed hole(s), %.1f%% of the picture: check the sheet' % (n_holes, 100.0 * hole_px / (w * h)))
	alpha = ImageChops.invert(bgmask)
	return antialias(rgb, bg, diff, alpha, tol)


def antialias(rgb, bg, diff, alpha, tol):
	"""On the object's 2 px rim: alpha from the colour distance to the background, relative to the outline's, and
	the background's tint taken out of the colour. Returns (rgb, alpha)."""
	w, h = rgb.size
	inner = alpha.filter(ImageFilter.MinFilter(5))  # 2 px in from the edge
	rim = ImageChops.subtract(alpha, inner)
	band = ImageChops.subtract(inner, inner.filter(ImageFilter.MinFilter(7)))  # the next 3 px in: the outline
	dvals = [d for d, b in zip(pixels(diff), pixels(band)) if b]
	ref = max(tol + 1, median(dvals) if dvals else 255)
	apx, rpx, gpx, dpx = alpha.load(), rgb.load(), bg.load(), diff.load()
	for i, v in enumerate(pixels(rim)):
		if not v:
			continue
		x, y = i % w, i // w
		d = dpx[x, y]
		a = min(1.0, max(0.0, (d - tol * 0.5) / max(1.0, ref - tol * 0.5)))
		apx[x, y] = int(round(a * 255))
		if 0.0 < a < 1.0:
			p, b = rpx[x, y], gpx[x, y]
			rpx[x, y] = tuple(int(max(0, min(255, round(b[c] + (p[c] - b[c]) / a)))) for c in range(3))
	return rgb, alpha


def import_one(path, args, ids):
	name = os.path.splitext(os.path.basename(path))[0]
	res = Result(name)
	src = Image.open(path)
	res.size = src.size
	w, h = src.size
	if ids and name not in ids:
		res.notes.append('UNKNOWN NAME: not in IconModels.Images (check the spelling in hood/art/AI_ICONS.md)')
	if max(w, h) > 1.1 * min(w, h):
		res.notes.append('off-square input: %dx%d' % (w, h))
	if min(w, h) < 256:
		res.notes.append('low resolution input: %dx%d (want 512+)' % (w, h))
	im = src.convert('RGBA')
	if max(w, h) > WORK_MAX:
		k = WORK_MAX / max(w, h)
		im = im.convert('RGBa').resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS).convert('RGBA')
		w, h = im.size
	a0 = im.getchannel('A')
	transparent = a0.histogram()
	clear = sum(transparent[:16])
	border = [a0.getpixel((x, 0)) for x in range(w)] + [a0.getpixel((x, h - 1)) for x in range(w)] + \
		[a0.getpixel((0, y)) for y in range(h)] + [a0.getpixel((w - 1, y)) for y in range(h)]
	if clear > 0.01 * w * h and median(border) < 16:
		res.mode = 'transparent input kept'
		# haze: semi-transparent pixels away from the object
		solid = a0.point(lambda v: 255 if v > 127 else 0)
		near_obj = solid.filter(ImageFilter.MaxFilter(9))
		haze = ImageChops.subtract(a0.point(lambda v: 255 if 12 <= v <= 127 else 0), near_obj)
		hz = haze.histogram()[255]
		if hz > 0.005 * w * h:
			res.notes.append('background haze: %.1f%% of the picture is semi-transparent away from the object' % (100.0 * hz / (w * h)))
		alpha = a0.point(lambda v: 0 if v < 12 else v)
		if hz:  # clear the haze away from the object (its own soft edge, within 4 px, is kept)
			alpha = ImageChops.multiply(alpha, near_obj)
		rgb = im.convert('RGB')
	else:
		rgb, alpha = remove_background(im.convert('RGB'), args.tol, args.hole_tol, res)
	# islands: drop specks smaller than --speck of the object's area
	solid = alpha.point(lambda v: 255 if v > 127 else 0)
	area = solid.histogram()[255]
	if area == 0:
		res.notes.append('EMPTY: nothing left after removing the background')
		return res
	keep_mask, dropped = keep_components(solid, lambda c: c.size >= args.speck * area)
	if dropped:
		gone = ImageChops.subtract(solid, keep_mask).filter(ImageFilter.MaxFilter(5))
		alpha = ImageChops.subtract(alpha, gone)
		res.notes.append('dropped %d speck(s) / island(s) (%d px)' % (len(dropped), sum(dropped)))
	box = alpha.point(lambda v: 255 if v > 127 else 0).getbbox()
	if not box:
		res.notes.append('EMPTY after cleaning')
		return res
	# the style has a dark outline all round: an edge that is mostly not dark means background was left on (or eaten)
	solid = alpha.point(lambda v: 255 if v > 127 else 0)
	edge = ImageChops.subtract(solid, solid.filter(ImageFilter.MinFilter(7)))
	en = edge.histogram()[255]
	dk = ImageChops.multiply(edge, rgb.convert('L').point(lambda v: 255 if v < 110 else 0)).histogram()[255]
	if en and dk < 0.9 * en:
		res.notes.append('only %d%% of the edge is a dark outline: background may be left on, check the sheet' % (100 * dk // en))
	ow, oh = box[2] - box[0], box[3] - box[1]
	if max(ow, oh) < 256:
		res.notes.append('low resolution object: %dx%d px (it is scaled up %.1fx)' % (ow, oh, FRAME * CANVAS / max(ow, oh)))
	# framing: longest side FRAME of the canvas, centred
	rgba = rgb.convert('RGBA')
	rgba.putalpha(alpha)
	k = FRAME * CANVAS / max(ow, oh)
	cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
	half = CANVAS / 2 / k
	# room round the picture, so the framing box never leaves it (an object that fills its picture)
	pad = int(max(0, half - cx, half - cy, cx + half - w, cy + half - h)) + 4
	padded = Image.new('RGBa', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
	padded.paste(rgba.convert('RGBa'), (pad, pad))
	cx, cy = cx + pad, cy + pad
	out = padded.resize((CANVAS, CANVAS), Image.LANCZOS, box=(cx - half, cy - half, cx + half, cy + half)).convert('RGBA')
	res.image = out
	return res


# ------------------------------------------------------------------------------------------------- M.Labelled
LABELLED = re.compile(r'(M\.Labelled = \{\n)(.*?)(\}\n)', re.S)


def read_labels(src, extra):
	"""{name: text} from <src>/labels.txt ("Name: text" lines) and --label Name=text."""
	labels = {}
	path = os.path.join(src, 'labels.txt')
	if os.path.exists(path):
		for line in open(path):
			line = line.split('#', 1)[0].strip()
			if ':' in line:
				k, v = line.split(':', 1)
				if k.strip() and v.strip():
					labels[k.strip()] = v.strip()
	for item in extra:
		if '=' in item:
			k, v = item.split('=', 1)
			labels[k.strip()] = v.strip()
	return labels


def update_labelled(names, labels, module=MODULE, dry=False):
	"""Set M.Labelled[name] = labels[name] for each imported name that has a label, and remove the others. Returns the
	changes as text lines."""
	text = open(module).read()
	m = LABELLED.search(text)
	if not m:
		return ['IconModels.lua has no M.Labelled block: not updated']
	rows = {}
	for line in m.group(2).splitlines():
		mm = re.match(r"^\s*(\w+)\s*=\s*'([^']*)',?", line)
		if mm:
			rows[mm.group(1)] = mm.group(2)
	changes = []
	for n in names:
		want = labels.get(n)
		if want is None and n in rows:
			changes.append('M.Labelled.%s removed (was %r)' % (n, rows.pop(n)))
		elif want is not None and rows.get(n) != want:
			changes.append('M.Labelled.%s = %r' % (n, want))
			rows[n] = want.replace("'", '')
	if changes and not dry:
		body = ''.join("\t%s = '%s',\n" % (k, rows[k]) for k in sorted(rows))
		text = text[:m.start()] + m.group(1) + body + m.group(3) + text[m.end():]
		open(module, 'w').write(text)
	return changes


# ------------------------------------------------------------------------------------------------- sheet + main
def contact_sheet(results, out, dry):
	cell = 128 + 8 + 48 + 8
	cols = len(HUD_COLOURS)
	row_h = 128 + 24
	ok = [r for r in results if r.image is not None]
	W = 180 + cols * cell
	H = 30 + max(1, len(ok)) * row_h
	sheet = Image.new('RGB', (W, H), (30, 32, 44))
	dr = ImageDraw.Draw(sheet)
	dr.text((8, 8), ('DRY RUN: ' if dry else '') + 'imported icons at 128 and 48 px on the HUD button colours', fill=(255, 255, 255))
	for i, r in enumerate(ok):
		y = 30 + i * row_h
		dr.text((8, y + 50), r.name, fill=(255, 255, 255))
		if r.notes:
			dr.text((8, y + 66), '! see report', fill=(255, 190, 80))
		for c, col in enumerate(HUD_COLOURS):
			x = 180 + c * cell
			big = Image.new('RGB', (128, 128), col)
			im = r.image.resize((128, 128), Image.LANCZOS)
			big.paste(im, (0, 0), im)
			sheet.paste(big, (x, y))
			small = Image.new('RGB', (48, 48), col)
			im = r.image.resize((48, 48), Image.LANCZOS)
			small.paste(im, (0, 0), im)
			sheet.paste(small, (x + 136, y + 80))
	sheet.save(out)


def main(argv=None):
	ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
	ap.add_argument('--dry-run', action='store_true', help='report and write the check sheet only; no icon is written')
	ap.add_argument('--only', default='', help='comma-separated names without .png')
	ap.add_argument('--src', default=INCOMING, help='the folder with the incoming PNGs')
	ap.add_argument('--out', default=ICONS, help='where the icons go (default hood/art/icons3d)')
	ap.add_argument('--sheet', default=None, help='the contact sheet path (default <src>/_check.png)')
	ap.add_argument('--tol', type=int, default=48, help='background colour tolerance (max channel difference)')
	ap.add_argument('--hole-tol', type=int, default=10, help='tolerance for enclosed background holes (flat only)')
	ap.add_argument('--speck', type=float, default=0.005, help='islands under this fraction of the object area are dropped')
	ap.add_argument('--no-bounds', action='store_true', help="don't refresh IconModels.M.Bounds or M.Labelled")
	ap.add_argument('--label', action='append', default=[], help='Name=text: this picture has text baked in (repeatable)')
	args = ap.parse_args(argv)
	only = set(x.strip() for x in args.only.split(',') if x.strip())
	files = sorted(f for f in os.listdir(args.src) if f.lower().endswith('.png') and not f.startswith('_'))
	if only:
		files = [f for f in files if os.path.splitext(f)[0] in only]
	if not files:
		print('nothing to import: no PNGs in %s' % args.src)
		return 0
	ids = known_ids()
	results = []
	for f in files:
		try:
			r = import_one(os.path.join(args.src, f), args, ids)
		except Exception as e:  # a broken file must not stop the batch
			r = Result(os.path.splitext(f)[0])
			r.notes.append('ERROR: %s' % e)
		results.append(r)
		status = 'ok' if r.image is not None else 'SKIPPED'
		print('%-16s %-7s %s%s' % (r.name, status, '%dx%d, ' % r.size if r.size else '', r.mode))
		for n in r.notes:
			print('    ! ' + n)
		if r.image is not None and not args.dry_run:
			os.makedirs(args.out, exist_ok=True)
			r.image.save(os.path.join(args.out, r.name + '.png'))
	sheet = args.sheet or os.path.join(args.src, '_check.png')
	contact_sheet(results, sheet, args.dry_run)
	print('check sheet: %s' % sheet)
	n_ok = sum(1 for r in results if r.image is not None)
	n_warn = sum(1 for r in results if r.notes)
	print('%d imported%s, %d with notes' % (n_ok, ' (dry run: nothing written)' if args.dry_run else ' into ' + args.out, n_warn))
	labels = read_labels(args.src, args.label)
	imported = [r.name for r in results if r.image is not None]
	unknown = sorted(set(labels) - set(r.name for r in results))
	if unknown:
		print('labels for pictures not in this import (ignored): %s' % ', '.join(unknown))
	into_game = os.path.abspath(args.out) == os.path.abspath(ICONS) and not args.no_bounds
	if into_game or args.dry_run:
		for c in update_labelled(imported, labels, dry=args.dry_run or not into_game):
			print(('would set ' if args.dry_run else '') + c)
	if not args.dry_run and into_game:
		sys.path.insert(0, os.path.join(HERE, 'blender'))
		import icon_bounds
		icon_bounds.main([])
	return 0


if __name__ == '__main__':
	sys.exit(main())
