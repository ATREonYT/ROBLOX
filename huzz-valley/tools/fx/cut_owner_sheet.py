# Cuts the owner's 9 effect pictures (design/vfx/owner-vfx-sheet-oct17.png, one 1536x1024 sheet from their other AI,
# "Secret cutscene effect pictures", docs/PICTURES-TO-MAKE.md section 8) into our assets/fx files, replacing our
# own drawings. Each panel is cut inside its grey border and above its printed label; the picture's brightness
# becomes the alpha on white, so ParticleEmitter/Beam colours tint it like before. Beam textures run along their
# length in Roblox, so the tall beams and the lightning are turned on their side (our files were wide too).
# The panels are small (about 300 x 460 px each), so these are softer than separate 512 px PNGs would be.
# Usage (from huzz-valley/): python3 tools/fx/cut_owner_sheet.py   then python3 tools/icons/pack_images.py
import os
import numpy as np
from PIL import Image

SRC = 'design/vfx/owner-vfx-sheet-oct17.png'
OUT = 'assets/fx'
TOP, BOT = (6, 470), (516, 976)  # rows of the two bands, above the labels
# name: (x0, x1, band, out size, turn)
PANELS = {
    'beam-glow': (7, 375, TOP, (512, 128), True),
    'beam-ladder': (382, 749, TOP, (512, 128), True),
    'lightning': (756, 1065, TOP, (512, 128), True),
    'butterfly': (1072, 1529, TOP, (512, 512), False),
    'crystal': (7, 276, BOT, (256, 256), False),
    'star-flare': (283, 585, BOT, (256, 256), False),
    'rays': (592, 891, BOT, (512, 512), False),
    'nebula': (898, 1239, BOT, (256, 256), False),
    'bokeh': (1246, 1529, BOT, (256, 256), False),
}


def to_alpha(img):
    a = np.asarray(img.convert('RGB')).astype(float)
    lum = a.max(2)
    lum = np.clip((lum - 10) / 245, 0, 1)  # (the black isn't quite black: lift it to clear)
    out = np.zeros(a.shape[:2] + (4,), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (lum * 255).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


def fit(img, size):
    # keep the shape's proportions on a transparent square/strip of `size`
    w, h = img.size
    s = min(size[0] / w, size[1] / h)
    img = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    canvas = Image.new('RGBA', size, (255, 255, 255, 0))
    canvas.paste(img, ((size[0] - img.size[0]) // 2, (size[1] - img.size[1]) // 2))
    return canvas


def butterfly(img):
    # their 4 frames sit in a 2x2 grid: square each quarter on its own centre so the flipbook doesn't jump
    w, h = img.size
    sheet = Image.new('RGBA', (512, 512), (255, 255, 255, 0))
    for i in range(4):
        cx, cy = i % 2, i // 2
        q = img.crop((cx * w // 2, cy * h // 2, (cx + 1) * w // 2, (cy + 1) * h // 2))
        sheet.paste(fit(q, (256, 256)), (cx * 256, cy * 256))
    return sheet


sheet = Image.open(SRC)
for name, (x0, x1, (y0, y1), size, turn) in PANELS.items():
    img = to_alpha(sheet.crop((x0, y0, x1, y1)))
    bbox = img.getchannel('A').point(lambda v: 255 if v > 6 else 0).getbbox()
    if name == 'butterfly':
        out = butterfly(img)
    else:
        img = img.crop(bbox)
        if turn:
            img = img.rotate(90, expand=True)
            out = img.resize(size, Image.LANCZOS)  # (stretched along the beam: it is drawn that way in Roblox)
        else:
            out = fit(img, size)
    out.save(os.path.join(OUT, name + '.png'))
    print(name, out.size)
