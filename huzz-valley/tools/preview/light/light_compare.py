"""The lighting side by side (owner Oct 19: "can you make the lighting be one to one as the game ... even, nice,
cartoony lighting over the map"): the reference game's lobby next to our lobby under the model of the old and new
Config/Look (render_light.mjs: a model, not a Studio render), each with its colour grade and a simple bloom, and
under each the numbers that tell the looks apart, read off the calibration scene (calibrate.py) for ours and off
the frame (light_measure.py boxes) for the reference.
Usage (from huzz-valley/): python3 -I tools/preview/light/light_compare.py <render dir> <looks.json> <out.jpg>
"""
import json
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'feel'))
import calibrate  # noqa: E402
import light_measure  # noqa: E402

REF = 'design/lobby-ref/oct19-lighting-ref.png'
REF_BOXES = 'tools/preview/feel/boxes_ref_oct19.json'
FONT = os.path.join(HERE, '..', 'fonts', 'Montserrat-Variable.ttf')
W, H = 960, 540


def font(size):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name('Bold')
    except Exception:
        pass
    return f


def grade(img, g):
    """Roblox's ColorCorrection, roughly: brightness added, contrast round mid-grey, saturation from luma, tint."""
    a = np.asarray(img.convert('RGB')).astype(float) / 255
    a = a + g.get('Brightness', 0)
    a = (a - 0.5) * (1 + g.get('Contrast', 0)) + 0.5
    l = (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2])[..., None]
    a = l + (a - l) * (1 + g.get('Saturation', 0))
    a = a * (np.array(g.get('Tint', [255, 255, 255])) / 255)
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def bloom(img, b):
    a = np.asarray(img).astype(float) / 255
    lum = a.max(-1, keepdims=True)
    hot = np.clip((lum - 0.9 * b.get('Threshold', 1.5) / 1.5) / 0.1, 0, 1) * a
    glow = np.asarray(Image.fromarray((hot * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))).astype(float) / 255
    return Image.fromarray((np.clip(a + glow * b.get('Intensity', 0.5), 0, 1) * 255).astype(np.uint8))


def panel(img, title, lines):
    img = img.resize((W, H), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    f, s = font(24), font(17)
    d.rectangle([0, 0, d.textlength(title, font=f) + 24, 40], fill=(16, 12, 24))
    d.text((12, 7), title, font=f, fill=(255, 255, 255))
    y = H - 14 - 24 * len(lines)
    d.rectangle([0, y - 8, max(d.textlength(t, font=s) for t in lines) + 24, H], fill=(16, 12, 24))
    for i, t in enumerate(lines):
        d.text((12, y + 24 * i), t, font=s, fill=(235, 235, 235))
    return img


def main(rdir, looks_path, out):
    looks = json.load(open(looks_path))
    _, rm, rr = light_measure.measure(REF, json.load(open(REF_BOXES)))
    ref = Image.open(REF).convert('RGB')
    w, h = ref.size
    ref = ref.crop((0, int(h * 0.02), w, int(h * 0.02) + int(w * 9 / 16)))
    panels = [panel(ref, 'REFERENCE (his Oct 19 screenshot)', [
        f"cast shadow / sun on the floor: {rr['cast shadow/sun']:.2f}",
        f"shaded side / lit top of a block: {rr['bench shade/lit']:.2f}   shade tint: blue +{rr['bench shade blue-red']}",
    ])]
    casts = {}
    for name, title in (('before', 'OURS BEFORE (Future, Oct 18 look) - model'), ('after', 'OURS AFTER (ShadowMap, Oct 19 look) - model')):
        look = looks[name]
        img = bloom(grade(Image.open(os.path.join(rdir, name + '.png')), look.get('grade', {})), look.get('bloom', {}))
        lines = [f"Brightness {look['Brightness']}  OutdoorAmbient {look['OutdoorAmbient'][0]}  EnvDiffuse {look['EnvironmentDiffuseScale']}  "
                 f"Contrast {look['grade']['Contrast']}  Sat {look['grade']['Saturation']}"]
        cal = os.path.join(rdir, 'calib_' + name + '.png')
        if os.path.exists(cal):
            m = calibrate.measure(cal)
            casts[name] = (m['slate cast'] + m['cream cast']) / 2
            lines.append(f"cast shadow / sun: {m['slate cast']:.2f} (dark floor), {m['cream cast']:.2f} (light floor)")
        panels.append(panel(img, title, lines))
    note = Image.new('RGB', (W, H), (16, 12, 24))
    d = ImageDraw.Draw(note)
    text = [
        'How to read this',
        '- The reference is a real screenshot. Ours are a MODEL of',
        "  Roblox's light (three.js, parts as boxes, no stud textures),",
        '  tuned so our Oct 17 look gives the shadow we measured on',
        "  his Oct 17 recording. Only Studio shows the real look.",
        '- What to compare: how dark the shadow sides and cast',
        '  shadows are next to the sunlit parts (1.0 = no shadow).',
        f"- Reference {rr['cast shadow/sun']:.2f}, ours before {casts.get('before', 0):.2f}, after {casts.get('after', 0):.2f}",
        '  (ours: the dark and light floor, averaged).',
        '- Lamps: Future lit pools round every PointLight; ShadowMap',
        '  and our lights turned down keep the glow on the object.',
    ]
    for i, t in enumerate(text):
        d.text((24, 24 + 44 * i), t, font=font(26 if i == 0 else 21), fill=(255, 255, 255) if i == 0 else (225, 225, 225))
    grid = Image.new('RGB', (2 * W + 10, 2 * H + 10), (8, 6, 12))
    for i, p in enumerate([panels[0], panels[2], panels[1], note]):
        grid.paste(p, ((i % 2) * (W + 10), (i // 2) * (H + 10)))
    grid.save(out, quality=88)
    print('saved', out, grid.size)


if __name__ == '__main__':
    main(*sys.argv[1:4])
