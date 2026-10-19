"""Huss Valley's huss frame by frame (docs/previews/feel-huss.jpg, 30 fps) over ours at the same moments.

Ours comes from `HUSS_ONLY=1 sh video.sh ramp_scene.luau huss.mp4` (Space at 1.0 s); each tile is cropped round the
character the way the HV tiles are. Usage:
  python3 huss_sheet.py <hv sheet jpg> <our mp4> <out jpg> [press seconds, default 1.0]
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

HV_PRESS = 36.80  # HV's crouch starts on this frame
FIRST = 36.70  # HV's first tile
TILES, COLS = 24, 12


def font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def main():
    hv_path, mp4, out = sys.argv[1], sys.argv[2], sys.argv[3]
    press = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
    hv = Image.open(hv_path).convert("RGB")
    W = hv.size[0]
    tile_w = W // COLS
    title_h, row_h = 34, (hv.size[1] - 34) // 2
    tmp = tempfile.mkdtemp()
    start = press - (HV_PRESS - FIRST)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-ss", f"{start:.4f}", "-i", mp4, "-frames:v", str(TILES),
                    "-vsync", "0", os.path.join(tmp, "f_%02d.png")], check=True)
    ours = Image.new("RGB", (W, title_h + 2 * row_h), (12, 12, 16))
    d = ImageDraw.Draw(ours)
    d.text((8, 6), "Ours, same moments (Space on the 36.80 column): push 120 to 16 studs/s in 0.28 s, lean in 0.09 s, ready again at 2 s",
           fill="white", font=font(17))
    small = font(14)
    for i in range(TILES):
        im = Image.open(os.path.join(tmp, "f_%02d.png" % (i + 1))).convert("RGB")
        w, h = im.size
        ch = int(h * 0.53)  # crop round the character (it sits at ~44% across, ~60% down: the round camera)
        cw = int(ch * tile_w / row_h)
        cx, cy = int(w * 0.42), int(h * 0.6)
        crop = im.crop((cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2)).resize((tile_w - 2, row_h - 2))
        x, y = (i % COLS) * tile_w + 1, title_h + (i // COLS) * row_h + 1
        ours.paste(crop, (x, y))
        d.text((x + 3, y + 2), "%.2f" % (FIRST + i / 30), fill=(255, 230, 0), font=small, stroke_width=2,
               stroke_fill="black")
    sheet = Image.new("RGB", (W, hv.size[1] + ours.size[1]), (0, 0, 0))
    sheet.paste(hv, (0, 0))
    sheet.paste(ours, (0, hv.size[1]))
    sheet.save(out, quality=88)
    print("saved", out)


if __name__ == "__main__":
    main()
