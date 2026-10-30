"""Ours next to Huss Valley, frame by frame at 30 fps: setting off, stopping and turning (owner, Oct 19 18:16).

  python3 feel_sheet.py <hv.mp4> <ours.mp4 from feel_scene.luau> <out.jpg>

Rows (each 12 frames, 1/30 s apart, cropped to the runner at about the same size):
  HV set-off from 30.73 s (first leg moving)        / ours from 0.50 s (W)       (AFTER runner)
  HV stop from 52.13 s (the ground stops: ground_flow.py) / ours from 2.00 s (let go)
  HV running side-on, head ahead, 51.97 s           / ours D without shift lock from 2.80 s, BEFORE then AFTER
Needs ffmpeg and Pillow.
"""
import subprocess
import sys
import tempfile
import os

from PIL import Image, ImageDraw, ImageFont

W = 200  # each frame's width in the sheet
N = 12


def strip(video, start, crop, out):
    vf = f"fps=30,crop={crop},scale={W}:{W}"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{start:.3f}", "-t", f"{N / 30 + 0.02:.3f}", "-i", video,
                    "-vf", vf + f",tile={N}x1", "-frames:v", "1", out], check=True)
    return Image.open(out).convert("RGB")


def main():
    hv, ours, out = sys.argv[1], sys.argv[2], sys.argv[3]
    HV = "700:700:1160:860"
    AFTER, BEFORE = "260:260:630:190", "260:260:382:190"
    rows = [
        ("Huss Valley set-off (30.73 s, first step)", hv, 30.73, HV),
        ("Ours set-off: W at 0.50 s (after)", ours, 0.50, AFTER),
        ("Huss Valley stop (52.13 s, ground stopped)", hv, 52.13, HV),
        ("Ours stop: let go at 2.00 s (after)", ours, 2.00, AFTER),
        ("Ours stop BEFORE (morning): legs run on in place", ours, 2.00, BEFORE),
        ("Huss Valley side-on run, head ahead (51.97 s)", hv, 51.97, HV),
        ("Ours D, no shift lock, 2.80 s: BEFORE (head turns with body)", ours, 2.80, BEFORE),
        ("Ours D, no shift lock, 2.80 s: AFTER (head stays ahead, red brim hidden)", ours, 2.80, AFTER),
    ]
    font = None
    for path in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(path):
            font = ImageFont.truetype(path, 18)
    font = font or ImageFont.load_default()
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13) if font else font
    LABEL = 26
    sheet = Image.new("RGB", (W * N, len(rows) * (W + LABEL)), (16, 16, 20))
    d = ImageDraw.Draw(sheet)
    with tempfile.TemporaryDirectory() as tmp:
        for i, (label, video, start, crop) in enumerate(rows):
            img = strip(video, start, crop, os.path.join(tmp, f"r{i}.png"))
            y = i * (W + LABEL)
            d.text((6, y + 4), label, fill=(255, 255, 255), font=font)
            sheet.paste(img, (0, y + LABEL))
            for k in range(N):
                d.text((k * W + 3, y + LABEL + 2), f"+{k / 30:.2f}", fill=(255, 230, 0), font=small,
                       stroke_width=2, stroke_fill=(0, 0, 0))
    sheet.save(out, quality=88)
    print("saved", out)


if __name__ == "__main__":
    main()
