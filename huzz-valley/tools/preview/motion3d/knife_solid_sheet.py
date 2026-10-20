# The solid stand-in knives as worn, close up (docs/previews/knife-solid-worn.jpg): knife_wear_scene.luau with
# KNIFE_SET=solid films 11 bodies, each knife from about 3 studs at two angles (22 stills); this lays
# them out two knives a row, to look for seams between wedges and coloured layers fighting the blade.
# Usage (from huzz-valley/): python3 -I tools/preview/motion3d/knife_solid_sheet.py <MOTION3D_KEEP dir> [out.jpg]
import glob
import os
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
KEYS = ['Crimson Requiem (pass)', 'Hollow Eclipse (pass)', 'Celestial Seraph (pass)', "Dragon's Maw (pass)",
        'Frostbound Oath (pass)', 'Candy Reaper', 'Thorn Karambit', 'Toadstool Sickle', 'Grand Witch Scythe',
        'Taffy Karambit', 'Cupcake Cleaver']


def font(n):
    try:
        return ImageFont.truetype(FONT, n)
    except OSError:
        return ImageFont.load_default()


def main(src, out='docs/previews/knife-solid-worn.jpg'):
    stills = sorted(glob.glob(os.path.join(src, 'still_*.png')), key=lambda p: int(p.rsplit('_', 1)[1].split('.')[0]))
    assert len(stills) >= 2 * len(KEYS), 'expected %d stills, got %d' % (2 * len(KEYS), len(stills))
    tw, th, gap, bar = 480, 360, 6, 30
    cols = 4
    rows = (len(KEYS) + 1) // 2
    sheet = Image.new('RGB', (cols * (tw + gap), 40 + rows * (th + bar + gap)), (22, 22, 30))
    d = ImageDraw.Draw(sheet)
    d.text((sheet.width // 2, 20), 'Solid stand-in knives as worn, from about 3 studs, two angles each', fill=(255, 255, 255),
           font=font(22), anchor='mm')
    for i, name in enumerate(KEYS):
        r, c = i // 2, (i % 2) * 2
        y = 40 + r * (th + bar + gap)
        x = c * (tw + gap)
        d.text((x + tw + gap // 2, y + bar // 2), name, fill=(255, 226, 138), font=font(18), anchor='mm')
        for k in range(2):
            im = Image.open(stills[2 * i + k]).convert('RGB').resize((tw, th), Image.LANCZOS)
            sheet.paste(im, (x + k * (tw + gap), y + bar))
    sheet.save(out, quality=86)
    print(out, sheet.size)


if __name__ == '__main__':
    main(*sys.argv[1:])
