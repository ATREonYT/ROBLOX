"""The powers' look before the Oct 19 renames, as the Oct 19 batch left it, and now (owner, Oct 20: "bring back the nice
effects with the power ups, because right now it just looks like a bare copy, i mean just keep the same effects,
change the name"): one row per power, its peak still from motion3d/power_scene.luau in each version.
Usage (from huzz-valley/): python3 tools/preview/powers_old_vs_now.py <old dir> <oct19 dir> <now dir> [out.jpg]
  old dir:   MOTION3D_KEEP of the power_scene at ed870f6 (POWER_STILLS=1: Heart Shield, Rizz Rush, Love Trap, Charm Wave)
  oct19 dir: MOTION3D_KEEP of the power_scene at d6db14f..f8c95c9 (8 stills, the order below)
  now dir:   MOTION3D_KEEP of today's power_scene (the same 8)
"""
import glob
import os
import sys
from PIL import Image, ImageDraw, ImageFont

H = 230
ROWS = ['Shield (was Heart Shield)', 'Invisible (new Oct 19)', 'Glitchy (new Oct 19)', 'Body Double (new Oct 19)',
        'Speed Boost (was Rizz Rush)', 'Bear Trap: thrown, lands (was Love Trap)', 'Bear Trap: snapped', 'Slow Wave (was Charm Wave)']
OLD_OF = {0: 0, 4: 1, 5: 2, 7: 3}  # row -> index of the old film's stills


def font(size):
    try:
        f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
        f.set_variation_by_axes([800])
        return f
    except (OSError, AttributeError):
        return ImageFont.load_default()


def stills(d):
    return sorted(glob.glob(os.path.join(d, 'still_*.png')), key=lambda p: int(p.rsplit('_', 1)[1].split('.')[0]))


def tile(path, w):
    if not path:
        t = Image.new('RGB', (w, H), (40, 40, 52))
        ImageDraw.Draw(t).text((w // 2, H // 2), 'no old version', fill=(170, 170, 185), font=font(22), anchor='mm')
        return t
    im = Image.open(path).convert('RGB')
    return im.resize((int(im.width * H / im.height), H), Image.LANCZOS)


def main():
    old, oct19, now = (stills(d) for d in sys.argv[1:4])
    out = sys.argv[4] if len(sys.argv) > 4 else 'docs/previews/powers-old-vs-now.jpg'
    w = int(1280 * H / 720)
    label_w, gap, head = 250, 6, 44
    sheet = Image.new('RGB', (label_w + 3 * (w + gap), head + len(ROWS) * (H + gap)), (22, 22, 30))
    d = ImageDraw.Draw(sheet)
    for i, t in enumerate(['before the renames (old)', 'Oct 19 batch (plain)', 'now (Oct 20)']):
        d.text((label_w + i * (w + gap) + w // 2, head // 2), t, fill=(255, 255, 255), font=font(24), anchor='mm')
    for r, name in enumerate(ROWS):
        y = head + r * (H + gap)
        words, line, lines = name.split(), '', []
        for wd in words:
            if len(line + ' ' + wd) > 18:
                lines.append(line)
                line = wd
            else:
                line = (line + ' ' + wd).strip()
        lines.append(line)
        for k, l in enumerate(lines):
            d.text((12, y + H // 2 - 14 * len(lines) + 28 * k), l, fill=(255, 226, 138), font=font(21))
        paths = [old[OLD_OF[r]] if r in OLD_OF and OLD_OF[r] < len(old) else None,
                 oct19[r] if r < len(oct19) else None, now[r] if r < len(now) else None]
        for c, p in enumerate(paths):
            sheet.paste(tile(p, w), (label_w + c * (w + gap), y))
    sheet.save(out, quality=84)
    print(out, sheet.size)


if __name__ == '__main__':
    main()
