"""The 3-2-1-GO after a CHICKEN pick as one strip (docs/previews/chicken-countdown.jpg).
Frames come from check_countdown.luau with __frames set (times after the CHICKEN shot ends), drawn by
shoot_frames.js at 960 x 540 (UIPreviewScale 1.25). Usage:
  python3 countdown_strip.py <framesDir> <out.jpg>
"""
import sys
from PIL import Image, ImageDraw, ImageFont

FRAMES = [  # (seconds after the CHICKEN shot ends, what the camera does, what shows)
    (0.10, "camera swinging back", "nothing drawn"),
    (0.45, "camera back", "nothing yet (lead)"),
    (0.70, "", "3 pops in"),
    (1.20, "", "3"),
    (1.90, "", "2"),
    (2.90, "", "1"),
    (3.90, "run started at 3.6 s", "GO!"),
]
CROP = (240, 0, 720, 260)  # the top cluster and the middle words
SCALE = 0.75

def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)

def main(src, out):
    w = int((CROP[2] - CROP[0]) * SCALE)
    h = int((CROP[3] - CROP[1]) * SCALE)
    pad, head, cap = 8, 46, 44
    sheet = Image.new("RGB", (pad + len(FRAMES) * (w + pad), head + h + cap + pad), (18, 20, 34))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), "After a CHICKEN pick (same when nobody answers): seconds after the CHICKEN shot ends. "
           "The count waits 0.6 s for the camera to come back, then 3, 2, 1 each get a full second.",
           fill=(235, 235, 245), font=font(15, True))
    for i, (t, cam, what) in enumerate(FRAMES):
        im = Image.open(f"{src}/frame_{i + 1:04d}.png").convert("RGB").crop(CROP)
        im = im.resize((w, h), Image.LANCZOS)
        x = pad + i * (w + pad)
        sheet.paste(im, (x, head))
        d.text((x + 4, head + h + 4), f"{t:.2f} s  {what}", fill=(255, 255, 255), font=font(15, True))
        if cam:
            d.text((x + 4, head + h + 24), cam, fill=(170, 176, 200), font=font(13))
    sheet.save(out, quality=88)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
