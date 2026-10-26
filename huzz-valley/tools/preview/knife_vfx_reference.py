"""Huss Valley's knife skins, close up (docs/previews/knife-vfx-hv-reference.jpg): the high-end skins in their
recording f1c7bb86 (the only HV round recording in the uploads; 32fe8d21 and 87565d66 aren't there), each the same
crop at two or three moments so the drifting motes and sparkles show. Notes on what each one does are in
docs/notes/knives.md ("Knife effects: the Huss Valley study").
Usage (from huzz-valley/): python3 -I tools/preview/knife_vfx_reference.py [out.jpg]
(needs ffmpeg and the upload in /mnt/project-files/uploads/hearth/)"""
import glob
import os
import subprocess
import sys
import tempfile
from PIL import Image, ImageDraw, ImageFont

VID = 'f1c7bb86'
# (label, box in the video's 3020 x 1882 pixels, times)
ROWS = [
    ('Purple and gold, pink gem (cxsh), worn', (1560, 1150, 1960, 1330), ['4.6', '5.0', '5.4']),
    ('Cyan and gold halo, cyan gem (MELON5MAN), worn', (1960, 1150, 2360, 1330), ['4.6', '5.0', '5.4']),
    ('Cyan blades, cyan gems (XxSanVetxX), worn', (330, 1160, 690, 1360), ['4.8', '5.0', '5.2']),
    ('Red and white wing blade, blue gem (Mrsmagic), worn', (2430, 1150, 2860, 1350), ['4.8', '5.0', '5.2']),
    ('Pink skin in hand (Danilo): rest, swing, after', (2080, 700, 2440, 940), ['44.2', '44.4', '44.5']),
]
H = 230


def font(n):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', n)
    except OSError:
        return ImageFont.load_default()


def frame(src, t, tmp):
    f = os.path.join(tmp, 'f_%s.png' % t)
    if not os.path.exists(f):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', t, '-i', src, '-frames:v', '1', f], check=True)
    return Image.open(f).convert('RGB')


def main(out='docs/previews/knife-vfx-hv-reference.jpg'):
    src = glob.glob('/mnt/project-files/uploads/hearth/' + VID + '*')[0]
    tmp = tempfile.mkdtemp()
    rows = []
    for label, box, ts in ROWS:
        tiles = []
        for t in ts:
            im = frame(src, t, tmp).crop(box)
            im = im.resize((round(im.width * H / im.height), H), Image.LANCZOS)
            ImageDraw.Draw(im).text((8, 6), t + ' s', fill=(255, 255, 0), font=font(18))
            tiles.append(im)
        rows.append((label, tiles))
    W = max(sum(t.width + 6 for t in tiles) for _, tiles in rows)
    bar = 30
    sheet = Image.new('RGB', (W, 46 + len(rows) * (H + bar + 6)), (22, 22, 30))
    d = ImageDraw.Draw(sheet)
    d.text((W // 2, 23), "Huss Valley's knife skins, close up (their video f1c7bb86)", fill=(255, 255, 255), font=font(24), anchor='mm')
    y = 46
    for label, tiles in rows:
        d.text((8, y + 4), label, fill=(255, 226, 138), font=font(20))
        x = 0
        for t in tiles:
            sheet.paste(t, (x, y + bar))
            x += t.width + 6
        y += H + bar + 6
    sheet.save(out, quality=86)
    print(out, sheet.size)


if __name__ == '__main__':
    main(*sys.argv[1:])
