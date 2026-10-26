"""The sky side by side (owner Oct 19: "try making the skybox better for the better lighting experience"): the
reference game's sky next to a MODEL of our sky under the old and the new Config/Look. Not a Studio render: only
Studio shows the real thing.

What the model assumes (say so when showing it):
  * the skybox is Roblox's built-in sky (his place sets no skybox IDs). Its colours are taken from the reference's
    clear sky (the reference's blue gradient and puffy clouds look like the same built-in sky); the clouds painted in
    the skybox are left out, so every cloud in "ours" comes from Terrain Clouds.
  * Atmosphere: near the horizon the sky is covered by the haze colour (Color at the horizon, Decay higher up); how
    much grows with Density and shrinks with Offset; Haze greys it. Roblox's real formula isn't public.
  * Terrain Clouds: one flat layer of soft noise blobs, as much sky covered as Cover asks, as thick as Density asks,
    white on top and a little blue underneath, fading into the haze far away.
  * then the colour grade (Config/Look ColorCorrection and ExposureCompensation), as the game applies it.
Usage (from huzz-valley/):
  python3 -I tools/preview/light/sky_model.py <old Look.lua> <new Look.lua> <out.jpg> [frame.png]
  (frame.png: also save "ours, new" alone at the reference's size, for a fresh look)
"""
import math
import os
import re
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REF = 'design/lobby-ref/oct19-lighting-ref.png'
FONT = os.path.join(HERE, '..', 'fonts', 'Montserrat-Variable.ttf')
# the reference at 1512 x 867: the sea's edge is at row 280; Roblox's default 70 degree vertical field of view
RW, RH, HORIZON, FOV = 1512, 867, 280, 70.0
TOP, BOTTOM = 0, 278  # the strip compared: sky only, down to just above the sea


def font(size):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name('Bold')
    except Exception:
        pass
    return f


def parse_look(path):
    src = open(path).read()

    def table(name):
        m = re.search(r'\n\t' + name + r' = \{(.*?)\},?\s*(--[^\n]*)?\n', src)
        out = {}
        if not m:
            return out
        body = m.group(1)
        for k, r, g, b in re.findall(r'(\w+) = Color3\.fromRGB\((\d+), (\d+), (\d+)\)', body):
            out[k] = np.array([int(r), int(g), int(b)], float) / 255
        for k, v in re.findall(r'(\w+) = (-?[\d.]+)(?=[,\s}])', body):
            out.setdefault(k, float(v))
        return out

    look = {'Atmosphere': table('Atmosphere'), 'Clouds': table('Clouds'), 'Grade': table('ColorCorrection')}
    m = re.search(r'ExposureCompensation = (-?[\d.]+)', src)
    look['Exposure'] = float(m.group(1)) if m else 0.0
    return look


def rays(w, h):
    """View directions for every pixel of the compared strip, at the reference camera's pitch."""
    f = (RH / 2) / math.tan(math.radians(FOV / 2))
    pitch = math.atan(((RH / 2) - HORIZON) / f)  # the camera looks this far above the horizon... (negative: down)
    pitch = -pitch
    sx, sy = RW / w, (BOTTOM - TOP) / h
    xs = (np.arange(w) + 0.5) * sx - RW / 2
    ys = RH / 2 - (TOP + (np.arange(h) + 0.5) * sy)
    X, Y = np.meshgrid(xs, ys)
    Z = np.full_like(X, f)
    c, s = math.cos(pitch), math.sin(pitch)
    y2 = Y * c + Z * s
    z2 = -Y * s + Z * c
    n = np.sqrt(X * X + y2 * y2 + z2 * z2)
    return X / n, y2 / n, z2 / n


def skybox_gradient():
    """The built-in sky's colour by elevation, read off the reference's clear sky (columns between the clouds)."""
    im = np.asarray(Image.open(REF).convert('RGB').resize((RW, RH)), float) / 255
    f = (RH / 2) / math.tan(math.radians(FOV / 2))
    pitch = -math.atan(((RH / 2) - HORIZON) / f)
    elev, cols = [], []
    for y in range(8, 270, 4):
        px = im[y, [560, 700, 1080]]
        px = px[(px[:, 2] > 0.9) & (px[:, 0] < 0.7)]  # blue sky only (no text, boards or clouds)
        if len(px) == 0:
            continue
        e = pitch + math.atan(((RH / 2) - y) / f)
        elev.append(math.degrees(e))
        cols.append(px.mean(0))
    elev, cols = np.array(elev[::-1]), np.array(cols[::-1])
    return elev, cols


def noise(x, z, seed=3):
    """Smooth value noise, several octaves (soft cloud blobs)."""
    rng = np.random.default_rng(seed)
    total, amp, norm = 0.0, 1.0, 0.0
    for octave in range(5):
        g = rng.random((64, 64))
        fx, fz = x * (2 ** octave), z * (2 ** octave)
        ix, iz = np.floor(fx).astype(int), np.floor(fz).astype(int)
        tx, tz = fx - ix, fz - iz
        tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
        a = g[ix % 64, iz % 64]
        b = g[(ix + 1) % 64, iz % 64]
        c = g[ix % 64, (iz + 1) % 64]
        d = g[(ix + 1) % 64, (iz + 1) % 64]
        total = total + amp * ((a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz)
        norm += amp
        amp *= 0.42  # little fine detail: soft round puffs, not streaks
    return total / norm


def grade(rgb, look):
    g = look['Grade']
    out = rgb * (2 ** look['Exposure'])
    out = out + g.get('Brightness', 0)
    out = (out - 0.5) * (1 + g.get('Contrast', 0)) + 0.5
    lum = (out * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
    out = lum + (out - lum) * (1 + g.get('Saturation', 0))
    out = out * g.get('TintColor', np.ones(3))
    return np.clip(out, 0, 1)


def render(look, w, h):
    dx, dy, dz = rays(w, h)
    elev = np.degrees(np.arcsin(np.clip(dy, -1, 1)))
    e_ref, c_ref = skybox_gradient()
    sky = np.stack([np.interp(elev, e_ref, c_ref[:, i]) for i in range(3)], -1)

    a = look['Atmosphere']
    density, offset, haze = a.get('Density', 0.3), a.get('Offset', 0.25), a.get('Haze', 0)
    horizonness = np.exp(-np.clip(elev, 0, 90) / 9.0)[..., None]  # 1 at the horizon, ~0 by 25 degrees up
    tint = a['Color'] * horizonness + a['Decay'] * (1 - horizonness)
    lum = (tint * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
    tint = tint + (lum * 0.95 - tint) * min(haze / 3, 1) * 0.6  # haze: greyer
    cover = np.clip(density * 2.6, 0, 1) * (1 - np.clip(offset, 0, 1) * 0.6)  # how much haze hides the skybox
    weight = cover * np.exp(-np.clip(elev, 0, 90) / (6 + 10 * density))[..., None]
    out = sky * (1 - weight) + tint * weight
    alpha_total = np.zeros(out.shape[:2])

    cl = look['Clouds']
    if cl and cl.get('Cover', 0) > 0:
        up = np.clip(dy, 0.004, 1)
        t = 1.0 / up  # a flat cloud layer one unit up
        px, pz = dx * t * 0.22, dz * t * 0.22  # big blobs: a cloud is about 4 units of sky across
        n = noise(px + 7.3, pz + 2.1)
        lo = 0.78 - (cl['Cover'] - 0.3) * 0.8  # Cover 0.4: about a fifth of the strip
        soft = 0.05 + 0.04 * (1 - cl.get('Density', 0.5))  # thicker clouds, crisper puffs
        m = np.clip((n - lo) / soft, 0, 1)
        m = m * m * (3 - 2 * m)
        alpha = m * (0.55 + 0.45 * cl.get('Density', 0.5))
        far = np.clip(t / 40, 0, 1)  # far away the clouds melt into the haze
        alpha = alpha * (1 - far ** 1.5)
        core = np.clip((n - lo - soft) / (soft * 2), 0, 1)[..., None]
        white = cl.get('Color', np.ones(3))
        shade = white * np.array([0.86, 0.90, 0.97])  # undersides a little blue-grey
        cc = shade * (1 - core) + white * core
        cc = cc * (1 - far[..., None] * 0.4) + tint * far[..., None] * 0.4
        out = out * (1 - alpha[..., None]) + cc * alpha[..., None]
        alpha_total = alpha

    return grade(out, look), alpha_total


def band(img, y0, y1):
    """Mean colour of the clear-sky columns in a band of rows (strip coordinates)."""
    sl = img[y0:y1, :, :].reshape(-1, 3)
    return sl.mean(0)


def main():
    old_path, new_path, out_path = sys.argv[1:4]
    frame_path = sys.argv[4] if len(sys.argv) > 4 else None
    old, new = parse_look(old_path), parse_look(new_path)
    W = 1200
    H = round(W * (BOTTOM - TOP) / RW)
    ref = Image.open(REF).convert('RGB').resize((RW, RH)).crop((0, TOP, RW, BOTTOM)).resize((W, H), Image.LANCZOS)
    ours_old, cov_old = render(old, W, H)
    ours_new, cov_new = render(new, W, H)
    # the sky's own colour is read with the clouds left out (so a cloud edge can't pale the number)
    clear_old = render(dict(old, Clouds={}), W, H)[0]
    clear_new = render(dict(new, Clouds={}), W, H)[0]
    if frame_path:
        Image.fromarray((render(new, RW, BOTTOM - TOP)[0] * 255).astype(np.uint8)).save(frame_path)

    # the numbers: the same clear-sky spots as skybox_gradient, high up and near the horizon
    refa = np.asarray(ref, float) / 255

    def spots(img, rows):
        xs = [int(x * W / RW) for x in (560, 700, 1080)]
        vals = []
        for r in rows:
            y = int((r - TOP) * H / (BOTTOM - TOP))
            for x in xs:
                p = img[y, x]
                vals.append(p)
        return np.array(vals)

    def clear(img_vals):
        keep = img_vals[(img_vals[:, 2] > 0.85) & (img_vals[:, 0] < 0.8)]
        return (keep if len(keep) else img_vals).mean(0)

    def sat(c):
        return (c.max() - c.min()) / max(c.max(), 1e-6)

    rows = {'high': [20, 40, 60, 85], 'low': [235, 250, 262]}
    lines = []
    # the reference's clouds: whitish, unsaturated pixels in its sky-only box (left of the title, above the props)
    box = refa[int(60 * H / BOTTOM):int(240 * H / BOTTOM), :int(380 * W / RW)]
    ref_cov = float(((box.min(-1) > 0.75) & (box.max(-1) - box.min(-1) < 0.12)).mean())
    for name, img, cov in (('reference', refa, None), ('ours, before', clear_old, cov_old), ('ours, new', clear_new, cov_new)):
        hi, lo = clear(spots(img, rows['high'])), clear(spots(img, rows['low']))
        share = (f"clouds {ref_cov * 100:.0f}% of its left third" if cov is None
                 else f"clouds {(cov > 0.5).mean() * 100:.0f}% of the strip")
        lines.append(f"high sky {tuple(int(v * 255) for v in hi)} sat {sat(hi):.2f}   "
                     f"near horizon {tuple(int(v * 255) for v in lo)} sat {sat(lo):.2f}   {share}")
        print(name + ': ' + lines[-1])

    pad, lab = 16, 44
    sheet = Image.new('RGB', (W + pad * 2, (H + lab + pad) * 3 + pad + 40), (24, 24, 30))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 10), 'Sky: reference vs a MODEL of ours (not a Studio render; only Studio shows the real thing)',
           font=font(20), fill=(255, 255, 255))
    panels = [('Reference (his Oct 19 screenshot, sky strip)', ref),
              ('Ours BEFORE (model): Oct 19 morning Config/Look, no clouds', Image.fromarray((ours_old * 255).astype(np.uint8))),
              ('Ours NEW (model): bluer Atmosphere + Terrain Clouds', Image.fromarray((ours_new * 255).astype(np.uint8)))]
    y = 40 + pad
    for (title, img), line in zip(panels, lines):
        d.text((pad, y), title, font=font(18), fill=(255, 230, 120))
        d.text((pad, y + 22), line, font=font(14), fill=(200, 205, 215))
        sheet.paste(img, (pad, y + lab))
        y += H + lab + pad
    sheet.save(out_path, quality=88)
    print('saved ' + out_path)


if __name__ == '__main__':
    main()
