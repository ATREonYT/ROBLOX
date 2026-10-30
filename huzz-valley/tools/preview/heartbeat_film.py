"""The heartbeat film: Gameplay/Heartbeat's red edge glow drawn over a still of the field, at 30 fps, from the frames
heartbeat_film.luau prints (the module's own maths). The four edges are drawn the way the module builds them: a red
frame Edge of the screen deep on top and bottom (Edge x 0.62 at the sides), its UIGradient opaque `alpha` at the
screen's edge, 1 - alpha*0.35 at 45 %, clear at the inner side. A strip under it plots the glow and marks each beat,
so "at most one swell a second" can be counted. No sound (the heartbeat sound is a stand-in until a licensed one is
picked).
Usage (from huzz-valley/):
  lune run tools/preview/heartbeat_film.luau > <frames.jsonl>
  python3 tools/preview/heartbeat_film.py <frames.jsonl> <background.png> <out.mp4>"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

FRAMES, BG, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
rows = [json.loads(line) for line in open(FRAMES) if line.startswith('{')]
bg = Image.open(BG).convert('RGB').resize((1280, 720))
W, H = bg.size
STRIP = 120
base = np.asarray(bg).astype(np.float32)


def ramp(n, alpha):
    """Opacity along a gradient of n px from the screen's edge inward (the module's three keypoints, linear between)."""
    x = np.linspace(0, 1, n)
    trans = np.interp(x, [0, 0.45, 1], [1 - alpha, 1 - alpha * 0.35, 1])
    return 1 - trans


tmp = tempfile.mkdtemp()
beats = [r['t'] for r in rows if r['beat']]
for i, r in enumerate(rows):
    a = r['alpha']
    col = np.array(r['color'], dtype=np.float32)
    op = np.zeros((H, W), dtype=np.float32)
    eh, ew = int(H * r['edge']), int(W * r['edge'] * 0.62)
    if a > 0:
        v, h = ramp(eh, a), ramp(ew, a)
        # each edge frame paints over what's under it (frames overlap in the corners: Roblox stacks them the same way)
        top = np.zeros((H, W), np.float32); top[:eh, :] = v[:, None]
        bot = np.zeros((H, W), np.float32); bot[H - eh:, :] = v[::-1][:, None]
        lef = np.zeros((H, W), np.float32); lef[:, :ew] = h[None, :]
        rig = np.zeros((H, W), np.float32); rig[:, W - ew:] = h[::-1][None, :]
        trans = (1 - top) * (1 - bot) * (1 - lef) * (1 - rig)
        op = 1 - trans
    img = base * (1 - op[..., None]) + col * op[..., None]
    frame = Image.new('RGB', (W, H + STRIP), (14, 12, 26))
    frame.paste(Image.fromarray(img.clip(0, 255).astype(np.uint8)), (0, 0))
    d = ImageDraw.Draw(frame)
    # the strip: glow over the last 12 s, beats as ticks
    x0, x1, y0, y1 = 20, W - 20, H + 18, H + STRIP - 24
    pts = [(x0 + (x1 - x0) * q['t'] / 12, y1 - (y1 - y0) * q['alpha'] / 0.6) for q in rows[:i + 1]]
    if len(pts) > 1:
        d.line(pts, fill=(255, 80, 100), width=2)
    for bt in beats:
        if bt <= r['t']:
            bx = x0 + (x1 - x0) * bt / 12
            d.line([(bx, y1 + 2), (bx, y1 + 10)], fill=(255, 255, 255), width=2)
    d.text((20, H + 2), f"{r['t']:.1f} s   nearest catcher {r['d']:.0f} studs   glow {a:.2f}   beats so far {sum(1 for b in beats if b <= r['t'])}"
           f"   (Far 30: nothing beyond, Near 8: full)", fill=(255, 255, 255))
    frame.save(os.path.join(tmp, f'f{i:04d}.png'))
subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', '30', '-i', os.path.join(tmp, 'f%04d.png'),
                '-pix_fmt', 'yuv420p', '-vf', 'scale=1280:-2', OUT], check=True)
gaps = np.diff(beats)
print(f'{OUT}: {len(rows)} frames, {len(beats)} beats, shortest gap {gaps.min():.2f} s' if len(gaps) else f'{OUT}: {len(beats)} beats')
