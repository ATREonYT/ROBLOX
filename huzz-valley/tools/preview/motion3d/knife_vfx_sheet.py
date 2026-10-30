"""The knife effects' pictures from knife_vfx_scene.luau's stills (MODE=sheet, MOTION3D_KEEP=<dir>):
  docs/previews/knife-vfx-sheet.jpg  8 knives across the tiers, in a body's hand (top) and on a lobby stand (bottom);
  docs/previews/knife-vfx-vs-hv.jpg  Huss Valley's MELON5MAN skin worn (their video f1c7bb86, 5.0 s) next to our
                                     Celestial Seraph worn, the knife the same height in both.
Usage (from huzz-valley/): python3 -I tools/preview/motion3d/knife_vfx_sheet.py <stills dir>
(the side by side needs ffmpeg and the upload in /mnt/project-files/uploads/hearth/)"""
import glob
import os
import subprocess
import sys
import tempfile
from PIL import Image, ImageDraw, ImageFont

KNIVES = [  # (key as the scene's KEYS, shown name, tier line)
    ('RustyShiv', 'Rusty Shiv', 'Common: plain'),
    ('CandyKnife', 'Candy Knife', 'Rare: petal motes'),
    ('StormKunai', 'Storm Kunai', 'Epic: motes + sparks'),
    ('BloodMoonTanto', 'Blood Moon Tanto', 'Epic: motes + red drips'),
    ('SolarReaper', 'Solar Reaper', 'Legendary: fire'),
    ('VoidFang', 'Void Fang', 'Legendary: void'),
    ('AbyssEclipse', 'Abyss Eclipse', 'Mythic: void'),
    ('CelestialSeraph', 'Celestial Seraph', 'Pass: celestial'),
]
T = 300  # tile size


def font(n):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', n)
    except OSError:
        return ImageFont.load_default()


def tile(path, box):
    return Image.open(path).convert('RGB').crop(box).resize((T, round(T * (box[3] - box[1]) / (box[2] - box[0]))), Image.LANCZOS)


def sheet(d, out):
    head, lab = 44, 46
    W = len(KNIVES) * (T + 6)
    th = round(T * 600 / 440)
    im = Image.new('RGB', (W, head + 2 * (th + lab)), (22, 22, 30))
    dr = ImageDraw.Draw(im)
    dr.text((W // 2, head // 2), 'Knife effects by tier: in hand (top), on a lobby stand (bottom). Offline preview, Roblox pictures drawn with look-alikes',
            fill=(255, 255, 255), font=font(20), anchor='mm')
    for i, (key, name, tier) in enumerate(KNIVES):
        x = i * (T + 6)
        for row in range(2):
            y = head + row * (th + lab)
            dr.text((x + 6, y + 4), name, fill=(255, 226, 138), font=font(18))
            dr.text((x + 6, y + 24), tier, fill=(200, 200, 210), font=font(15))
            im.paste(tile(os.path.join(d, 'still_%d.png' % (2 * i + row)), (260, 60, 700, 660)), (x, y + lab))
    im.save(out, quality=88)
    print('wrote', out)


def side_by_side(d, out):
    src = glob.glob('/mnt/project-files/uploads/hearth/f1c7bb86*')
    if not src:
        print('no f1c7bb86 upload: skipped', out)
        return
    tmp = tempfile.mkdtemp()
    f = os.path.join(tmp, 'f.png')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', '5.0', '-i', src[0], '-frames:v', '1', f], check=True)
    H = 520
    hv = Image.open(f).convert('RGB').crop((1960, 1110, 2360, 1370))
    hv = hv.resize((round(hv.width * H / hv.height), H), Image.LANCZOS)
    ours = Image.open(os.path.join(d, 'still_16.png')).convert('RGB').crop((100, 0, 960, 560))
    ours = ours.resize((round(ours.width * H / ours.height), H), Image.LANCZOS)
    lab = 40
    im = Image.new('RGB', (hv.width + ours.width + 10, H + lab), (22, 22, 30))
    dr = ImageDraw.Draw(im)
    dr.text((8, 8), "Huss Valley: MELON5MAN's skin worn (f1c7bb86, 5.0 s)", fill=(255, 226, 138), font=font(20))
    dr.text((hv.width + 18, 8), 'Ours: Celestial Seraph worn (offline preview)', fill=(255, 226, 138), font=font(20))
    im.paste(hv, (0, lab))
    im.paste(ours, (hv.width + 10, lab))
    im.save(out, quality=88)
    print('wrote', out)


if __name__ == '__main__':
    d = sys.argv[1]
    sheet(d, 'docs/previews/knife-vfx-sheet.jpg')
    side_by_side(d, 'docs/previews/knife-vfx-vs-hv.jpg')
