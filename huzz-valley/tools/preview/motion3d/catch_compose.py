#!/usr/bin/env python3
"""Knife pass 2 (Oct 19): docs/previews/catch-before-after.mp4 + .jpg from six catch_scene.luau renders.

usage: python3 -I catch_compose.py <dir> <out.mp4> <out.jpg>
  <dir> holds old_side.mp4, new_side.mp4, old_catcher.mp4, new_catcher.mp4, old_runner.mp4, new_runner.mp4
  (KNIFE_MESHES=... CATCH_VIEW=<view> [CATCH_OLD=1] sh video.sh catch_scene.luau <dir>/<old|new>_<view>.mp4).
The film: each view before (left) and after (right), full speed then the catch again at 1/4 speed, 30 fps.
The sheet: the side view and the catcher's camera at six moments of the leap (before row above after row).
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

src, out_mp4, out_jpg = sys.argv[1], sys.argv[2], sys.argv[3]
VIEWS = ["side", "catcher", "runner"]
tmp = tempfile.mkdtemp()

# the film: hstack each pair, then concatenate the views
parts = []
for v in VIEWS:
    o, n = os.path.join(src, f"old_{v}.mp4"), os.path.join(src, f"new_{v}.mp4")
    part = os.path.join(tmp, f"{v}.mp4")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", o, "-i", n, "-filter_complex",
                    "[0:v][1:v]hstack=inputs=2,fps=30,format=yuv420p[v]", "-map", "[v]", "-c:v", "libx264", "-crf", "22",
                    "-preset", "medium", part], check=True)
    parts.append(part)
lst = os.path.join(tmp, "list.txt")
with open(lst, "w") as f:
    for p in parts:
        f.write(f"file '{p}'\n")
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy",
                "-movflags", "+faststart", out_mp4], check=True)

# the sheet: frames of the 1/4-speed replay (frame = 99.6 + 120 x seconds into the leap)
MOMENTS = [(0.03, "take-off"), (0.08, "knife leads"), (0.13, "slash lands"), (0.2, "the hit"), (0.33, "landing"),
           (0.55, "down")]


def frame(path, n):
    f = os.path.join(tmp, f"{os.path.basename(path)}_{n}.png")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-vf", f"select=eq(n\\,{n})", "-vsync", "0",
                    "-frames:v", "1", f], check=True)
    return Image.open(f).convert("RGB")


TW, TH = 400, 225
LABEL = 200
rows = [("BEFORE side", "old_side"), ("AFTER side", "new_side"), ("BEFORE catcher cam", "old_catcher"),
        ("AFTER catcher cam", "new_catcher")]
sheet = Image.new("RGB", (LABEL + TW * len(MOMENTS), 28 + TH * len(rows)), (18, 18, 22))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
except OSError:
    font = ImageFont.load_default()
for i, (sec, name) in enumerate(MOMENTS):
    d.text((LABEL + i * TW + 8, 6), f"{sec:.2f} s  {name}", fill=(255, 230, 120), font=font)
for r, (label, stem) in enumerate(rows):
    y = 28 + r * TH
    d.text((10, y + TH // 2 - 10), label, fill=(255, 255, 255) if "AFTER" in label else (190, 190, 200), font=font)
    for i, (sec, _) in enumerate(MOMENTS):
        im = frame(os.path.join(src, stem + ".mp4"), int(round(99.6 + 120 * sec)))
        w, h = im.size
        crop = im.crop((int(w * 0.12), int(h * 0.12), int(w * 0.88), int(h * 0.88)))  # (a little closer)
        sheet.paste(crop.resize((TW, TH), Image.LANCZOS), (LABEL + i * TW, y))
sheet.save(out_jpg, quality=88)
print(out_mp4, out_jpg, sheet.size)
