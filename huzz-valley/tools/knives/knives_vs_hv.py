# The owner's knives in the game's own mounts next to Huss Valley's (docs/knife-study.md frames, same framing):
# top, four knives on the back from behind vs HV's 5.0 s skins shot; bottom, the slash's hold in hand vs HV's 43.47 s.
# Stills from motion3d/knife_scene.luau (KNIFE_MODE=stills MOTION3D_KEEP=<dir>).
# Usage (from huzz-valley/): python3 -I tools/knives/knives_vs_hv.py <stills dir> docs/previews/knives-vs-hv.jpg
import sys
from PIL import Image, ImageDraw, ImageFont

stills, out = sys.argv[1], sys.argv[2]
back = Image.open('docs/previews/knife-study-back.jpg').convert('RGB')
slash = Image.open('docs/previews/knife-study-slash.jpg').convert('RGB')


def font(size, want='Bold'):
    f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
    try:
        f.set_variation_by_name(want)
    except Exception:
        pass
    return f


def ours(i, box, size):
    return Image.open(f'{stills}/still_{i}.png').convert('RGB').crop(box).resize(size, Image.LANCZOS)


W, TOP, CAP = 1760, 46, 30
row1, row2 = 440, 340
sheet = Image.new('RGB', (W, TOP + CAP + row1 + CAP + row2), (16, 16, 22))
d = ImageDraw.Draw(sheet)
d.text((12, 10), "The owner's knives in our mounts (right) vs Huss Valley (left), same framing", font=font(24), fill='white')

y = TOP
d.text((12, y + 4), 'HUSS VALLEY 5.0 s: on the back at the belt', font=font(17), fill=(255, 220, 90))
d.text((772, y + 4), 'OURS: Rusty Shiv, Sakura Blade, Solar Reaper, Abyss Eclipse (KnifeLook.backC0)', font=font(17), fill=(120, 230, 140))
y += CAP
sheet.paste(back.crop((760, 44, 1520, 484)), (0, y))
sheet.paste(ours(0, (18, 0, 1262, 720), (760, 440)), (760, y))
d.rectangle((1520, y, W, y + row1), fill=(24, 24, 32))
for j, line in enumerate(['Same belt mount on', 'every skin: grip on the', 'right hip, blade to the', 'left, 12-20 deg down,', 'flat side out.', '', 'Legendary and Mythic', 'keep their glow on the', 'back; the rest go quiet.', '', 'Sparkles and embers', 'show in Studio only.', '', 'Still worse than HV:', 'in hand our blades read', 'thinner (seen end-on).']):
    d.text((1534, y + 14 + j * 25), line, font=font(15, 'Medium'), fill=(220, 220, 230))
y += row1

d.text((12, y + 4), 'HUSS VALLEY 43.47 s: slash hold', font=font(17), fill=(255, 220, 90))
d.text((452, y + 4), 'OURS 0.15 s in (StabMotion): Sakura Blade, Hollow Moon, Celestial Edge', font=font(17), fill=(120, 230, 140))
y += CAP
sheet.paste(slash.crop((0, 384, 440, 724)), (0, y))
for n, i in enumerate((1, 2, 3)):
    sheet.paste(ours(i, (380, 250, 980, 714), (440, 340)), (440 * (n + 1), y))
sheet.save(out, quality=88)
print('wrote', out)
