import sys
from PIL import Image, ImageDraw
src, x0, y0, x1, y1, step, out = sys.argv[1], *map(int, sys.argv[2:7]), sys.argv[7]
im = Image.open(src).convert("RGB").crop((x0, y0, x1, y1))
s = 1300 / im.width; im = im.resize((1300, int(im.height * s))); d = ImageDraw.Draw(im)
for x in range(x0 - x0 % step + step, x1, step):
    X = (x - x0) * s; d.line((X, 0, X, im.height), fill=(255, 0, 255)); d.text((X + 2, 2), str(x), fill=(255, 255, 255))
for y in range(y0 - y0 % step + step, y1, step):
    Y = (y - y0) * s; d.line((0, Y, im.width, Y), fill=(255, 0, 255)); d.text((2, Y + 2), str(y), fill=(255, 255, 255))
im.save(out)
