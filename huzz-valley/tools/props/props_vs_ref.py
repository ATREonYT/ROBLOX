# The side by side for the owner's lobby props (owner, Oct 18: "make it look good just like in the pictures"):
# our props on their pads (tools/props/render_props.mjs: his meshes as SetupLobbyProps sets them up) with what the
# renderer can't draw added here the way the game draws it (Shared/LobbyPropBuild): the titles (Fredoka for Roblox's
# FredokaOne, a dark 3 px outline, a white lift at the top of the letters; the small line under them in Gotham Bold:
# Montserrat here), a few sparkles round each prop, Roblox's bloom on Neon (a blur of the glow pass) and the game's
# colour grade (Config/Look ColorCorrection). Next to his references, same size; a strip of the stand-ins (plain
# parts) the pads show until he imports his meshes.
# Usage (from huzz-valley/): python3 -I tools/props/props_vs_ref.py <render dir> <out.jpg>
import json, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, '..', 'preview', 'fonts')
REFS = {'three': 'design/lobby/ref-halloween-shop.png', 'two': 'design/lobby/ref-shop-like-reward.png'}
GRADE = dict(contrast=0.16, saturation=0.4)  # Config/Look ColorCorrection (Oct 18)
# Config/LobbyProps titles (kept in step by hand)
TITLES = {
    'Shop_Stall': ('SHOP', (86, 226, 255), ''),
    'Like_Reward_Gift': ('LIKE THE GAME!', (110, 226, 72), 'Thumbs up on the game page!'),
    'Pumpkin_Patch_Chest': ('FREE SPIN', (255, 154, 40), 'Next free spin in 12m 33s'),
    'Witch_Brew_Cauldron': ("WITCH'S\nBREW", (196, 120, 255), ''),
    'Sweets_Treats_Coffin': ('SWEETS &\nTREATS', (255, 128, 196), ''),
}
GLOW = {'Shop_Stall': (255, 176, 64), 'Like_Reward_Gift': (255, 240, 150), 'Pumpkin_Patch_Chest': (255, 196, 64),
        'Witch_Brew_Cauldron': (200, 106, 255), 'Sweets_Treats_Coffin': (255, 160, 220)}
DARK = (22, 14, 34)
# Config/LobbyProps title layout (studs)
BOB, TITLE_ABOVE, TITLE_H, TITLE_W, LINE_H = 0.35, 0.8, 1.25, 12, 0.5


def font(name, size, var=None):
    f = ImageFont.truetype(os.path.join(FONTS, name), max(6, int(size)))
    if var:
        try:
            f.set_variation_by_name(var)
        except Exception:
            pass
    return f


def grade(img):
    a = np.asarray(img.convert('RGB')).astype(float) / 255
    a = (a - 0.5) * (1 + GRADE['contrast']) + 0.5
    l = (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2])[..., None]
    a = l + (a - l) * (1 + GRADE['saturation'])
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def bloom(lit, glow, radius):
    g = glow.convert('RGB').filter(ImageFilter.GaussianBlur(radius))
    a = np.asarray(lit.convert('RGB')).astype(float) + np.asarray(g).astype(float) * 0.9
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def star(d, x, y, r, col):
    for k, w in ((1.0, 0.18), (0.55, 0.5)):
        rr = r * k
        d.polygon([(x, y - rr * 2), (x + rr * w, y - rr * w), (x + rr * 2, y), (x + rr * w, y + rr * w), (x, y + rr * 2),
                   (x - rr * w, y + rr * w), (x - rr * 2, y), (x - rr * w, y - rr * w)], fill=col + (200 if k == 1 else 255,))


def text_block(img, cx, cy, text, fnt, fill, stroke, lift=False):
    """Centred text with an outline; `lift` = a white lift over the top of the letters (the UIGradient)."""
    d = ImageDraw.Draw(img)
    l, t, r, b = d.textbbox((0, 0), text, font=fnt, stroke_width=stroke)
    x, y = cx - (r - l) / 2 - l, cy - (b - t) / 2 - t
    d.text((x, y), text, font=fnt, fill=DARK, stroke_width=stroke, stroke_fill=DARK)
    if not lift:
        d.text((x, y), text, font=fnt, fill=fill)
        return
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=fnt, fill=255)
    top, bot = y + t, y + b
    grad = Image.new('RGB', img.size, fill)
    gd = ImageDraw.Draw(grad)
    light = tuple(int(c + (255 - c) * 0.45) for c in fill)
    for yy in range(int(top), int(top + (bot - top) * 0.45) + 1):
        k = (yy - top) / max(1, (bot - top) * 0.45)
        gd.line([(0, yy), (img.size[0], yy)], fill=tuple(int(light[i] + (fill[i] - light[i]) * k) for i in range(3)))
    img.paste(grad, (0, 0), mask)


def finish(rdir, name, titles=True):
    lit = Image.open(os.path.join(rdir, name + '.png')).convert('RGB')
    glow = Image.open(os.path.join(rdir, name + '_glow.png')).convert('RGB')
    img = grade(bloom(lit, glow, max(4, lit.size[0] // 160)))
    anchors = json.load(open(os.path.join(rdir, name + '.json')))
    over = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    rnd = random.Random(7)
    for a in anchors:
        xs = [p[0] for p in a['box']]
        ys = [p[1] for p in a['box']]
        col = GLOW[a['key']]
        for _ in range(8):
            star(d, rnd.uniform(min(xs), max(xs)), rnd.uniform(min(ys) - 0.1 * (max(ys) - min(ys)), max(ys)), a['pxPerStud'] * rnd.uniform(0.08, 0.16),
                 tuple(int(c + (255 - c) * 0.35) for c in col))
    over = over.filter(ImageFilter.GaussianBlur(0.6))
    img = Image.alpha_composite(img.convert('RGBA'), over).convert('RGB')
    if titles:
        for a in anchors:
            title, col, line = TITLES[a['key']]
            pps = a['pxPerStud']
            rows = title.split('\n')
            # the BillboardGui (Shared/LobbyPropBuild): its bottom TITLE_ABOVE over the prop's highest bob; the title
            # rows TITLE_H * 1.15 studs each (TextScaled), the small line under them
            title_h = len(rows) * TITLE_H * 1.15 * pps
            line_h = LINE_H * 1.2 * pps if line or a['key'] == 'Pumpkin_Patch_Chest' else 0
            bottom = a['top'][1] - (BOB + TITLE_ABOVE) * pps
            top = bottom - title_h - line_h
            size = TITLE_H * 1.15 * pps * 0.9
            f = font('Fredoka.ttf', size, 'Bold')
            while max(ImageDraw.Draw(img).textlength(r, font=f) for r in rows) > TITLE_W * pps and size > 6:
                size *= 0.94
                f = font('Fredoka.ttf', size, 'Bold')
            for i, r in enumerate(rows):
                text_block(img, a['top'][0], top + (i + 0.5) * TITLE_H * 1.15 * pps, r, f, col, 3, lift=True)
            if line:
                lf = font('Montserrat-Variable.ttf', LINE_H * 1.2 * pps * 0.8, 'Bold')
                text_block(img, a['top'][0], top + title_h + line_h / 2, line, lf, (255, 255, 255), 2)
    return img


def label(img, text, size=22, bottom=False):
    d = ImageDraw.Draw(img)
    f = font('Montserrat-Variable.ttf', size, 'Bold')
    w = d.textlength(text, font=f)
    y = img.size[1] - size - 14 if bottom else 0
    d.rectangle([0, y, w + 20, y + size + 14], fill=(20, 14, 26))
    d.text((10, y + 6), text, font=f, fill=(255, 255, 255))


def main(rdir, out):
    W = 910
    rows = []
    for name, ref_title in (('three', 'REFERENCE: ref-halloween-shop.png'), ('two', 'REFERENCE: ref-shop-like-reward.png')):
        ours = finish(rdir, name)
        ref = Image.open(REFS[name]).convert('RGB')
        h = int(ref.size[1] * W / ref.size[0])
        ours, ref = ours.resize((W, h), Image.LANCZOS), ref.resize((W, h), Image.LANCZOS)
        label(ours, 'OURS: his props on his pads (his meshes, after the Studio import)', bottom=True)
        label(ref, ref_title, bottom=True)
        row = Image.new('RGB', (2 * W + 10, h), (12, 8, 18))
        row.paste(ours, (0, 0))
        row.paste(ref, (W + 10, 0))
        rows.append(row)
    keys = ['Witch_Brew_Cauldron', 'Sweets_Treats_Coffin', 'Pumpkin_Patch_Chest', 'Shop_Stall', 'Like_Reward_Gift']
    tw = (2 * W + 10 - 4 * 10) // 5
    strip = Image.new('RGB', (2 * W + 10, tw + 44), (12, 8, 18))
    for i, k in enumerate(keys):
        t = finish(rdir, 'standin_' + k, titles=False).resize((tw, tw), Image.LANCZOS)
        strip.paste(t, (i * (tw + 10), 44))
    label(strip, 'UNTIL HE IMPORTS HIS MESHES: the stand-in from plain parts (no stud textures, no SHOP / LIKE pictures, no rings or vines)', 20)
    rows.append(strip)
    H = sum(r.size[1] for r in rows) + 10 * (len(rows) - 1)
    img = Image.new('RGB', (2 * W + 10, H), (12, 8, 18))
    y = 0
    for r in rows:
        img.paste(r, (0, y))
        y += r.size[1] + 10
    img.save(out, quality=88)
    print('saved', out, img.size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
