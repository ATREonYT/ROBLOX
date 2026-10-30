# sheet.py <out.jpg> <cell px> <png> ...: a contact sheet of pictures on a mid-grey checker (to judge transparent PNGs).
import math
import sys

from PIL import Image

out, cell, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
cols = max(1, min(10, len(files)))
rows = math.ceil(len(files) / cols)
sheet = Image.new('RGB', (cols * cell, rows * cell), (90, 96, 120))
for i, f in enumerate(files):
    im = Image.open(f).convert('RGBA')
    im.thumbnail((cell, cell), Image.LANCZOS)
    x, y = (i % cols) * cell, (i // cols) * cell
    sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2), im)
sheet.save(out, quality=85)
print('sheet', sheet.size)
