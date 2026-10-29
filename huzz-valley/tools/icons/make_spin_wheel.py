# Draws the spin wheel's two pictures (ours, not the owner's art; the UI wheel is built from real parts):
#   assets/art/spin-wedge.png   one 45-degree slice of the wheel, pointing up, its tip at the bottom middle. White,
#                               a little darker towards the tip, so ImageColor3 tints it to each slice's colour
#                               (Screens/SpinWheel lays 8 of them round the centre). Its edges sit under the
#                               dividers and the rim, so it can stay small.
#   assets/icons/spin-wheel.png the lobby HUD's SPIN button icon: a little wheel in the same colours.
# Usage (from huzz-valley/): python3 tools/icons/make_spin_wheel.py   (then python3 tools/icons/pack_images.py)
import math
from PIL import Image, ImageDraw

SS = 4

# --- the slice -------------------------------------------------------------------------------------------------
R = 192                     # radius in px
HALF = math.radians(22.5 + 0.6)  # a hair wider than 45 degrees, so neighbours overlap (no seams)
W = int(round(2 * R * math.sin(math.radians(22.5)))) + 1
big = Image.new('RGBA', (W * SS, R * SS), (0, 0, 0, 0))
px = big.load()
cx, cy = W * SS / 2.0, R * SS
for y in range(R * SS):
    for x in range(W * SS):
        dx, dy = x + 0.5 - cx, cy - (y + 0.5)
        r = math.hypot(dx, dy)
        if r > R * SS or dy <= 0:
            continue
        if abs(math.atan2(dx, dy)) > HALF:
            continue
        t = r / (R * SS)
        v = int(255 * (0.78 + 0.22 * t ** 0.7))
        px[x, y] = (v, v, v, 255)
wedge = big.resize((W, R), Image.LANCZOS)
wedge.save('assets/art/spin-wedge.png')
print('wedge', wedge.size)

# --- the HUD icon ----------------------------------------------------------------------------------------------
COLORS = ['FF4FAE', '2F9BFF', '7A4DFF', '2F9BFF', '7A4DFF', '2F9BFF', '7A4DFF', '2F9BFF']  # as Config/SpinWheel
S = 192 * SS
icon = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(icon)
c = S / 2
rad = S * 0.40
cy2 = c + S * 0.04
d.ellipse((c - rad - S * 0.04, cy2 - rad - S * 0.04, c + rad + S * 0.04, cy2 + rad + S * 0.04), fill=(10, 20, 51, 255))
d.ellipse((c - rad - S * 0.015, cy2 - rad - S * 0.015, c + rad + S * 0.015, cy2 + rad + S * 0.015), fill=(255, 255, 255, 255))
for i, hexc in enumerate(COLORS):
    col = tuple(int(hexc[j:j + 2], 16) for j in (0, 2, 4)) + (255,)
    start = -90 - 22.5 + i * 45
    d.pieslice((c - rad, cy2 - rad, c + rad, cy2 + rad), start, start + 45, fill=col)
for i in range(8):
    a = math.radians(-90 - 22.5 + i * 45)
    d.line((c, cy2, c + math.cos(a) * rad, cy2 + math.sin(a) * rad), fill=(10, 20, 51, 255), width=int(S * 0.018))
hub = S * 0.09
d.ellipse((c - hub, cy2 - hub, c + hub, cy2 + hub), fill=(10, 20, 51, 255))
d.ellipse((c - hub * 0.55, cy2 - hub * 0.55, c + hub * 0.55, cy2 + hub * 0.55), fill=(255, 255, 255, 255))
# the pointer at the top, pointing down
pw, top = S * 0.11, cy2 - rad - S * 0.10
d.polygon([(c - pw - S * 0.025, top - S * 0.02), (c + pw + S * 0.025, top - S * 0.02), (c, top + S * 0.20)], fill=(10, 20, 51, 255))
d.polygon([(c - pw, top), (c + pw, top), (c, top + S * 0.165)], fill=(255, 255, 255, 255))
icon = icon.resize((192, 192), Image.LANCZOS)
icon.save('assets/icons/spin-wheel.png')
print('icon', icon.size)
