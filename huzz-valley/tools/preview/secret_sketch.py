# A rough sketch of the Secret cutscene's build-up from the game's own numbers (Shared/SecretReveal's timeline and
# camera, Gameplay/SecretReveal's crescents, slashes, eyes and orb), drawn from the cutscene camera, next to the
# owner's reference (design/vfx/ref3). It checks framing and timing only: glow, textures and particles are guesses
# and only Studio shows the real thing.
# Usage (from huzz-valley/): python3 tools/preview/secret_sketch.py out.png
import math
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 640, 360
K = 1.0
GIRL = (6.0, 15.0)  # a 3x girl's bounding box (studs, wide x tall), roughly
BUILD, HOLD, IMPACT, LAND = 0.4, 2.6, 2.72, 3.1
CRESCENTS, SLASHES, EYES, FRAME, ORB = 1.2, (1.75, 1.95, 2.15, 2.35), 2.05, 0.09, 8


def smooth(x):
    x = min(max(x, 0), 1)
    return x * x * (3 - 2 * x)


def ease_in(x):
    x = min(max(x, 0), 1)
    return x * x * x


def camera(t):
    # Shared/SecretReveal.camera and .fov before the impact; the camera looks along -dir (dir = +z), side = dir x up
    x = smooth((t - BUILD) / (HOLD - BUILD))
    dist = (44 - 14 * x) * K
    side = np.array([-1.0, 0, 0])  # (0,0,1) x (0,1,0)
    at = np.array([0, 0.5, 0])
    eye = at + np.array([0, 0, 1.0]) * dist + np.array([0, 1.0, 0]) * (10 + 2 * x) * K + side * 4 * K
    look = at + np.array([0, ORB * K, 0])
    fov = 70 - 12 * x
    return eye, look, fov


def projector(t):
    eye, look, fov = camera(t)
    f = look - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    s = (H / 2) / math.tan(math.radians(fov / 2))

    def p(v):
        d = np.asarray(v, float) - eye
        z = d @ f
        return (W / 2 + (d @ r) / z * s, H / 2 - (d @ u) / z * s), s / z
    return p


def bezier(p0, p1, p2, p3, n=40):
    return [((1 - a) ** 3) * p0 + 3 * ((1 - a) ** 2) * a * p1 + 3 * (1 - a) * a * a * p2 + a ** 3 * p3
            for a in np.linspace(0, 1, n)]


def stroke(layer, proj, pts, w0, w1, col):
    d = ImageDraw.Draw(layer)
    for i in range(len(pts) - 1):
        a, sa = proj(pts[i])
        b, _ = proj(pts[i + 1])
        w = w0 + (w1 - w0) * i / (len(pts) - 1)
        d.line([a, b], fill=col, width=max(1, int(w * sa)))


def frame(t):
    proj = projector(t)
    ground = np.zeros(3)
    orb_at = ground + [0, ORB * K + GIRL[1] * 0.5, 0]
    up, side = np.array([0, 1.0, 0]), np.array([-1.0, 0, 0])
    img = Image.new('RGB', (W, H), (14, 8, 30))
    sky = ImageDraw.Draw(img)
    for y in range(H // 2, H):
        sky.line([(0, y), (W, y)], fill=(18, 12, 28))
    glow = Image.new('RGB', (W, H))
    core = Image.new('RGB', (W, H))
    # the crescents
    grow = min(max((t - CRESCENTS) / 0.45, 0), 1)
    cw = 1 - (1 - grow) ** 3
    tall = 46 * K * max(grow, 0.02)
    lean = math.radians(12)
    for sgn in (-1, 1):
        out = side * sgn
        foot = ground + out * 3.8 * K
        x0 = up * math.cos(lean) + out * math.sin(lean)
        x1 = up * math.cos(lean) - out * math.sin(lean)
        top = foot + up * tall - side * 0.12 * tall
        pts = bezier(foot, foot + x0 * tall * 0.3, top - x1 * tall * 0.3, top)
        if cw > 0:
            stroke(glow, proj, pts, 6 * cw, 3 * cw, (112, 82, 190))
            stroke(core, proj, pts, 1.2 * cw, 0.6 * cw, (255, 255, 255))
    # the slashes (Shared/SecretReveal.slash: on in 0.04 s, fading over 0.36 s)
    for i, at in enumerate(SLASHES, 1):
        dt = t - at
        v = 0 if dt < 0 else (dt / 0.04 if dt < 0.04 else max(0, 1 - (dt - 0.04) / 0.36))
        if v <= 0:
            continue
        flip = -1 if i % 2 == 0 else 1
        mid = orb_at + up * (2.5, -1.5, 4.2, -3.2)[i - 1] * K + side * max(0, dt) * 30 * K * flip
        a = mid - side * 24 * K + up * 4 * K * flip
        b = mid + side * 24 * K - up * 4 * K * flip
        seg = [a + (b - a) * f for f in (0.18, 0.3, 0.7, 0.82)]  # (the ends fade: drawn shorter)
        stroke(glow, proj, seg, 1.8 * v, 1.8 * v, (255, 70, 150))
        stroke(core, proj, seg, 0.4 * v, 0.4 * v, (255, 255, 255))
    # the orb (white core, violet shell)
    if BUILD <= t < IMPACT:
        r = 0.5 + 3 * ease_in((t - BUILD) / (HOLD - BUILD))
        (cx, cy), sc = proj(orb_at)
        ImageDraw.Draw(glow).ellipse([cx - r * 0.62 * sc, cy - r * 0.62 * sc, cx + r * 0.62 * sc, cy + r * 0.62 * sc], fill=(150, 110, 255))
        ImageDraw.Draw(core).ellipse([cx - r * 0.5 * sc, cy - r * 0.5 * sc, cx + r * 0.5 * sc, cy + r * 0.5 * sc], fill=(255, 255, 255))
    # the eyes
    ev = min(max((t - EYES) / 0.25, 0), 1) if EYES <= t < IMPACT else 0
    if ev > 0:
        eye_at = orb_at + up * GIRL[1] * 0.28
        gap = max(GIRL[0] * 0.12, 0.6 * K)
        for sgn in (-1, 1):
            p = eye_at + side * sgn * gap
            (cx, cy), sc = proj(p)
            rr = 0.45 * K * sc
            ImageDraw.Draw(core).ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(255, 120, 210))
            stroke(glow, proj, [p - side * 1.75 * ev, p + side * 1.75 * ev], 0.7, 0.7, (255, 160, 225))
    out = np.asarray(img, float)
    out += np.asarray(glow.filter(ImageFilter.GaussianBlur(9)), float) * 1.3
    out += np.asarray(glow.filter(ImageFilter.GaussianBlur(2)), float) * 0.6
    out += np.asarray(core.filter(ImageFilter.GaussianBlur(1)), float)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


def impact_frame():
    # the HuzzImpactFrame ScreenGui: dark lines from the screen's edge, fading before the middle, on white
    img = Image.new('RGB', (W, H), (250, 246, 255))
    rnd = np.random.default_rng(7)
    lines = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(lines)
    s = H / 1080
    for i in range(26):
        a = math.radians(i / 26 * 360 + rnd.uniform(-5, 5))
        w = rnd.integers(8, 46) * s
        ln = rnd.integers(820, 1180) * s
        r0, r1 = 1200 * s - ln, 1200 * s
        for j in range(20):
            k0, k1 = r1 - (r1 - r0) * j / 20, r1 - (r1 - r0) * (j + 1) / 20
            alpha = 1 - max(0, (j / 20 - 0.55) / 0.45)
            pts = [(W / 2 + math.sin(a) * rr, H / 2 - math.cos(a) * rr) for rr in (k0, k1)]
            d.line(pts, fill=int(255 * min(1, alpha)), width=max(1, int(w)))
    ink = Image.new('RGB', (W, H), (24, 10, 40))
    return Image.composite(ink, img, lines)


def ref(t):
    out = subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(t), '-i', 'design/vfx/ref3/vfx-reference-oct17.mp4',
                          '-frames:v', '1', '-vf', 'crop=760:400:0:120,scale=%d:%d' % (W, H), '-f', 'image2pipe',
                          '-vcodec', 'png', '-'], capture_output=True, check=True).stdout
    import io
    return Image.open(io.BytesIO(out)).convert('RGB')


SHOTS = [(1.5, 1.0, 'crescents rise'), (1.85, 1.6, 'slashes'), (2.4, 2.2, 'eyes open'), (2.75, None, 'impact frame (0.09 s)')]
sheet = Image.new('RGB', (W * 2 + 12, (H + 28) * len(SHOTS)), (8, 8, 12))
d = ImageDraw.Draw(sheet)
for row, (t, rt, label) in enumerate(SHOTS):
    y = row * (H + 28)
    ours = impact_frame() if label.startswith('impact') else frame(t)
    sheet.paste(ours, (0, y + 24))
    if rt is not None:
        sheet.paste(ref(rt), (W + 12, y + 24))
        d.text((W + 18, y + 6), 'reference %.1f s' % rt, fill=(200, 200, 210))
    d.text((6, y + 6), 'ours (sketch) %.2f s: %s' % (t, label), fill=(200, 200, 210))
sheet.save(sys.argv[1] if len(sys.argv) > 1 else 'secret-sketch.png')
print('sketch made')
