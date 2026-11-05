"""Turn a picture into a banner background: py prepare_background.py in.png out.png [--blur 5] [--crop L T R B]

A Roblox GUI cannot blur an image, so the blur is baked in before upload. Saturation is raised so the result stays vivid.
--crop removes pixels from each edge, for screenshots with buttons or dark corners. The blur is measured at 1024 px wide."""
import argparse
from PIL import Image, ImageEnhance, ImageFilter

p = argparse.ArgumentParser()
p.add_argument("src"); p.add_argument("out")
p.add_argument("--blur", type=float, default=5)
p.add_argument("--crop", type=int, nargs=4, default=[0, 0, 0, 0], metavar=("L", "T", "R", "B"))
p.add_argument("--saturation", type=float, default=1.35)
a = p.parse_args()

im = Image.open(a.src).convert("RGB")
l, t, r, b = a.crop
im = im.crop((l, t, im.width - r, im.height - b))
im = im.resize((1024, round(1024 * im.height / im.width)), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(a.blur))
im = ImageEnhance.Color(im).enhance(a.saturation)
im = ImageEnhance.Brightness(im).enhance(1.05)
im.save(a.out)
print(a.out, im.size)
