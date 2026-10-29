"""Our set-off (walk into run) next to Huss Valley's, frame by frame at the same moments after W is pressed.

Top row: HV (the owner's video f1c7bb86, 33.57 s on: their character standing, then running), cropped round the
character, every 1/15 s. Bottom row: ours from `STILLS=1 MOTION3D_KEEP=<dir> sh video.sh remote_walk_scene.luau x.mp4`
(the NOW body from behind, W pressed at 10.0 s; stills 296.. = 0.1 s before the press, every 2 frames).
Usage: python3 walk_sheet.py <hv mp4> <stills dir> <out jpg>
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

HV_PRESS = 33.667  # HV's first moving frame is ~0.1 s after this (they stand still before it)
TILES = 13
STEP = 1 / 15
TILE = 190


def font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def main():
    hv_mp4, stills, out = sys.argv[1], sys.argv[2], sys.argv[3]
    tmp = tempfile.mkdtemp()
    label_w = 120
    sheet = Image.new("RGB", (label_w + TILES * TILE, 30 + 2 * TILE), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    small = font(15)
    for i in range(TILES):
        rel = -0.1 + i * STEP
        hv_png = os.path.join(tmp, f"hv{i}.png")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{HV_PRESS + rel:.3f}", "-i", hv_mp4, "-vf", "crop=700:700:1000:850",
                        "-frames:v", "1", hv_png], check=True)
        hv = Image.open(hv_png).convert("RGB").resize((TILE, TILE), Image.LANCZOS)
        ours = Image.open(os.path.join(stills, f"still_{296 + 2 * i}.png")).convert("RGB").crop((505, 255, 775, 525)).resize((TILE, TILE), Image.LANCZOS)
        x = label_w + i * TILE
        sheet.paste(hv, (x, 30))
        sheet.paste(ours, (x, 30 + TILE))
        d.text((x + 6, 8), f"{rel:+.2f} s", fill=(255, 255, 255), font=small)
    big = font(22)
    d.text((10, 30 + TILE // 2 - 12), "Huss\nValley", fill=(255, 255, 255), font=big)
    d.text((10, 30 + TILE + TILE // 2 - 12), "Ours\n(pack)", fill=(255, 220, 120), font=big)
    d.text((10, 8), "W pressed", fill=(180, 180, 180), font=small)
    sheet.save(out, quality=78)
    print(out, os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
