# Draws the header stud texture (assets/icons/stud-tile.png): one raised square stud in the bottom-left of a 22 x 12
# tile (reference px), drawn at 4x. Kit.studs repeats it across each stud strip as a single tiled image (ScaleType
# Tile), instead of one part per stud. Measured from the headers in design/pages: 9 px studs on a 22 px pitch, a
# lighter face (#9576F9 -> #8A6CF4), a darker foot (#7D61EB) and a faint shadow (#6951D0).
# Usage (from huzz-valley/): python3 tools/icons/make_stud_tile.py   (then pack_images.py)
from PIL import Image, ImageDraw

K, SS = 4, 4  # 4x the reference size, drawn 4x larger again and shrunk for smooth edges
W, H = 22, 12
big = Image.new('RGBA', (W * K * SS, H * K * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
u = K * SS  # one reference px


def rect(x0, y0, x1, y1, fill, r=0.8):
    d.rounded_rectangle((x0 * u, y0 * u, x1 * u - 1, y1 * u - 1), radius=r * u, fill=fill)


rect(0.3, 1.0, 9.7, 12.0, (0x69, 0x51, 0xD0, 110))      # soft shadow under and around the stud
rect(0, 0.5, 9, 11.2, (0x7D, 0x61, 0xEB, 255))         # the foot (darker bottom edge)
top, bottom = (0x95, 0x76, 0xF9), (0x8A, 0x6C, 0xF4)
face = Image.new('RGBA', big.size, (0, 0, 0, 0))
fd = ImageDraw.Draw(face)
for row in range(int(0.5 * u), int(10 * u)):            # the face: lighter at the top
    t = (row - 0.5 * u) / (9.5 * u)
    fd.line((0, row, 9 * u, row), fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
mask = Image.new('L', big.size, 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0.5 * u, 9 * u - 1, 10 * u - 1), radius=0.8 * u, fill=255)
big.paste(face, (0, 0), mask)
d.line((0.8 * u, 0.5 * u + u // 2, 8.2 * u, 0.5 * u + u // 2), fill=(0xA8, 0x8E, 0xFB, 255), width=u // 2)  # top glint
big.resize((W * K, H * K), Image.LANCZOS).save('assets/icons/stud-tile.png')
print('stud tile', W * K, 'x', H * K)
