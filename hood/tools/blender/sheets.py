"""Contact sheets from the finished renders (needs ImageMagick's convert/montage).

  python3 hood/tools/blender/sheets.py
Writes hood/art/renders/guns_ladder.png (armory cards in tier order) and icons_sheet.png (each icon on a
HUD-style button at 128 px and 64 px, the readability test). guns_turntable.png (four angles per gun) is
assembled by `render.py turntable`, which renders the frames first.
"""
import os
import re
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
RENDERS = os.path.join(HOOD, 'art', 'renders')
GUNS_DIR = os.path.join(RENDERS, 'guns')
ICONS_DIR = os.path.join(HOOD, 'art', 'icons3d')
FONT = 'DejaVu-Sans-Bold'

ICON_IDS = ['Shop', 'Rebirth', 'Rewards', 'PVP', 'Evolve', 'Cash', 'Power', 'Trophy', 'Gun']
# HUD button gradients (top, bottom), echoing the reference HUD (yellow Shop, red Rebirth, cyan Rewards...).
BUTTONS = {
	'Shop': ('#ffe35a', '#f0a400'), 'Rebirth': ('#ff6b7a', '#d01e3c'), 'Rewards': ('#6ae6ff', '#139fd6'),
	'PVP': ('#a58bff', '#5a3ed6'), 'Evolve': ('#c77bff', '#7b2fd0'), 'Cash': ('#86ee62', '#2ca83a'),
	'Power': ('#ffab55', '#e05a16'), 'Trophy': ('#62a8ff', '#2a5bd6'), 'Gun': ('#98a8c8', '#4c5a7a'),
}


def run(*args):
	subprocess.run([str(a) for a in args], check=True)


def guns_config():
	"""(Id, Name, Multiplier, Cost, (r, g, b)) rows straight from Config/Guns.lua."""
	text = open(os.path.join(HOOD, 'src', 'ReplicatedStorage', 'Shared', 'Config', 'Guns.lua')).read()
	rows = re.findall(r"\{ '(\w+)', '([^']+)', (\d+), (\d+), C\((\d+), (\d+), (\d+)\)", text)
	return [(r[0], r[1], int(r[2]), int(r[3]), (int(r[4]), int(r[5]), int(r[6]))) for r in rows]


def price(n):
	return 'FREE' if n == 0 else '$' + short(n)


def short(n):
	if n >= 1000:
		v = n / 1000
		return ('%dK' % v) if v == int(v) else ('%.1fK' % v)
	return str(n)


def card(tmp, tier, gid, name, mult, cost, rgb):
	"""Armory card: dark rounded panel, tier-coloured glow strip, the render, name, multiplier and price."""
	w, h = 400, 470
	hexc = '#%02x%02x%02x' % rgb
	out = os.path.join(tmp, 'card_%02d.png' % tier)
	run('convert', '-size', '%dx%d' % (w, h), 'xc:none',
		'-fill', '#1d2133', '-draw', 'roundrectangle 0,0 %d,%d 30,30' % (w - 1, h - 1),
		'(', '-size', '%dx%d' % (w, h), 'radial-gradient:%s-none' % hexc, '-channel', 'A', '-evaluate', 'multiply', '0.55', '+channel', ')',
		'-compose', 'atop', '-composite', '-compose', 'over',
		'-fill', 'none', '-stroke', hexc, '-strokewidth', '6', '-draw', 'roundrectangle 3,3 %d,%d 28,28' % (w - 4, h - 4),
		'(', os.path.join(GUNS_DIR, gid + '.png'), '-resize', '360x360', ')', '-gravity', 'north', '-geometry', '+0+28', '-composite',
		'-font', FONT, '-stroke', '#0c0d14', '-strokewidth', '6', '-pointsize', '34', '-fill', 'white',
		'-gravity', 'south', '-annotate', '+0+62', name,
		'-stroke', 'none', '-annotate', '+0+62', name,
		'-pointsize', '28', '-stroke', '#0c0d14', '-strokewidth', '5', '-annotate', '+0+20', 'x%d   %s' % (mult, price(cost)),
		'-fill', '#ffd84a', '-stroke', 'none', '-annotate', '+0+20', 'x%d   %s' % (mult, price(cost)),
		'-gravity', 'northwest', '-pointsize', '26', '-fill', hexc, '-stroke', '#0c0d14', '-strokewidth', '5', '-annotate', '+22+16', 'T%d' % tier,
		'-stroke', 'none', '-annotate', '+22+16', 'T%d' % tier, out)
	return out


def ladder(tmp):
	cards = [card(tmp, i + 1, *row) for i, row in enumerate(guns_config())]
	out = os.path.join(RENDERS, 'guns_ladder.png')
	run('montage', *cards, '-tile', '5x2', '-geometry', '+14+14', '-background', '#0f1220', out)
	run('convert', out, '-gravity', 'north', '-background', '#0f1220', '-splice', '0x70', '-font', FONT, '-pointsize', '40',
		'-fill', 'white', '-annotate', '+0+14', 'HOOD ARMORY  -  gun ladder, tier 1 to 10', out)
	return out


def turntable(tmp, frames_dir):
	"""Rows of four angles per gun, from frames rendered by `render.py turntable`."""
	rows = []
	for gid, name, mult, cost, rgb in guns_config():
		frames = [os.path.join(frames_dir, '%s_%d.png' % (gid, k)) for k in range(4)]
		if not all(os.path.exists(f) for f in frames):
			continue
		row = os.path.join(tmp, 'tt_%s.png' % gid)
		run('montage', *frames, '-tile', '4x1', '-geometry', '260x260+4+4', '-background', '#262b40', row)
		run('convert', row, '-gravity', 'west', '-background', '#262b40', '-splice', '270x0', '-font', FONT, '-pointsize', '25',
			'-fill', '#%02x%02x%02x' % rgb, '-annotate', '+16-14', name, '-fill', 'white', '-pointsize', '20', '-annotate', '+16+18', 'x%d  %s' % (mult, price(cost)), row)
		rows.append(row)
	if not rows:
		return None
	out = os.path.join(RENDERS, 'guns_turntable.png')
	run('montage', *rows, '-tile', '1x', '-geometry', '+0+3', '-background', '#11141f', out)
	shrink(out)
	print('wrote', out)
	return out


def button(tmp, iid, size):
	top, bottom = BUTTONS[iid]
	r = int(size * 0.16)
	sw = max(2, int(size * 0.05))
	out = os.path.join(tmp, 'btn_%s_%d.png' % (iid, size))
	icon = os.path.join(ICONS_DIR, iid + '.png')
	inner = int(size * 0.96)
	run('convert', '-size', '%dx%d' % (size, size), 'gradient:%s-%s' % (top, bottom),
		'(', '-size', '%dx%d' % (size, size), 'xc:black', '-fill', 'white', '-draw', 'roundrectangle 0,0 %d,%d %d,%d' % (size - 1, size - 1, r, r), ')',
		'-alpha', 'off', '-compose', 'CopyOpacity', '-composite', '-compose', 'over',
		'-fill', 'none', '-stroke', '#15142a', '-strokewidth', str(sw),
		'-draw', 'roundrectangle %d,%d %d,%d %d,%d' % (sw // 2, sw // 2, size - 1 - sw // 2, size - 1 - sw // 2, r, r),
		'(', icon, '-resize', '%dx%d' % (inner, inner), ')', '-gravity', 'center', '-geometry', '+0-%d' % int(size * 0.02), '-composite', out)
	return out


def icons_sheet(tmp):
	big = [os.path.join(ICONS_DIR, i + '.png') for i in ICON_IDS]
	row1 = os.path.join(tmp, 'icons_big.png')
	run('montage', '-label', '%t', *big, '-tile', '9x1', '-geometry', '220x220+6+6', '-background', '#2b3150',
		'-fill', 'white', '-font', FONT, '-pointsize', '22', row1)
	row2 = os.path.join(tmp, 'icons_128.png')
	run('montage', *[button(tmp, i, 128) for i in ICON_IDS], '-tile', '9x1', '-geometry', '+52+10', '-background', '#2b3150', row2)
	row3 = os.path.join(tmp, 'icons_64.png')
	run('montage', *[button(tmp, i, 64) for i in ICON_IDS], '-tile', '9x1', '-geometry', '+84+10', '-background', '#2b3150', row3)
	out = os.path.join(RENDERS, 'icons_sheet.png')
	run('convert', row1, row2, row3, '-background', '#2b3150', '-gravity', 'center', '-append',
		'-gravity', 'north', '-splice', '0x60', '-font', FONT, '-pointsize', '34', '-fill', 'white',
		'-annotate', '+0+12', 'HUD icons: 512 px renders, then on buttons at 128 px and 64 px', out)
	return out


def shrink(path):
	"""Sheets are for looking at: flatten to 8-bit RGB to keep the repo light."""
	run('convert', path, '-background', '#0f1220', '-flatten', '-alpha', 'off', '-depth', '8', '-strip',
		'-define', 'png:compression-level=9', path)


def make_all():
	tmp = tempfile.mkdtemp(prefix='bk_sheets_')
	made = [ladder(tmp), icons_sheet(tmp)]
	for m in made:
		if m:
			shrink(m)
			print('wrote', m)


if __name__ == '__main__':
	make_all()
